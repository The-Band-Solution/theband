defmodule TheBand.Profiles.RunWorkerTest do
  @moduledoc """
  A rodada percorrida em sequência — feature 027, T013, T015, T016, T016a, T017 e T017a.

  ## As quatro asserções que carregam este arquivo

  1. **rodar duas vezes não duplica** — o checkpoint é a entrada, e a tabela de perfis é
     somente-acréscimo: sem guarda, a retentativa do Oban gravaria um segundo texto sobre o
     mesmo material;
  2. **falha de credencial encerra, limite de taxa não** — com a chave recusada a próxima
     pessoa falharia igual, e insistir gastaria trinta tentativas para chegar ao mesmo lugar;
  3. **as contagens saem das entradas**, e não de contador — contador diverge da realidade sob
     retentativa, que é o defeito que este repositório já teve duas vezes;
  4. **subir a versão não gera nada** — sem evento de automação, o cron não enfileira ninguém.
  """
  use TheBand.DataCase, async: false

  import Mox
  import TheBand.ProfileRunFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0, tenant_with_admin: 1]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.{Automation, MonthlyWorker, RunEntry, Runs, RunWorker}
  alias TheBand.Repo

  setup :verify_on_exit!

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario(tenant)
    tenant_com_credencial(tenant)

    %{tenant: tenant, admin: admin, pessoa: cenario.pessoa, repo_id: cenario.repo_id}
  end

  defp resposta do
    %{
      "habilidades" => ["observabilidade com OpenTelemetry"],
      "resumo" => %{"forcas" => "f", "evolucao" => "e", "atencao" => "a"},
      "trajetoria" => [],
      "destaques" => [],
      "lacunas" => [],
      "alocacao" => [],
      "recomendacoes" => [],
      "do_time_nao_da_pessoa" => "x",
      "nao_alcanca" => "y"
    }
  end

  # O `usage` traz as DUAS contagens, como o provedor traz. Um mock que só devolvesse a
  # entrada tornaria a issue #454 invisível a teste: a função leria a chave que existe e a
  # ausência da outra pareceria "o provedor não informou".
  defp gera_ok(entrada \\ 4321, saida \\ 876) do
    expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
      {:ok,
       %{
         text: Jason.encode!(resposta()),
         model: "m1",
         usage: %{"prompt_tokens" => entrada, "completion_tokens" => saida}
       }}
    end)
  end

  defp abrir(tenant, admin) do
    {:ok, run} = Runs.start(tenant, trigger: :manual, requested_by: admin)
    run
  end

  defp executar(tenant, run) do
    RunWorker.perform(%Oban.Job{args: %{"tenant_id" => tenant.id, "run_id" => run.id}})
  end

  describe "a rodada completa" do
    test "gera, grava o consumo, e fecha como concluída", ctx do
      gera_ok(4321)
      run = abrir(ctx.tenant, ctx.admin)

      assert :ok = executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)
      assert fechada.outcome == "completed"
      assert fechada.finished_at

      resumo = Runs.summary(fechada)
      assert resumo.considered == 1
      assert resumo.generated == 1
      assert resumo.failed == 0
      assert resumo.input_tokens == 4321

      # **A outra metade da conta** — issue #454. A `FR-021` pede custo, e a entrada sozinha
      # não responde: a saída é cobrada a taxa mais alta.
      assert resumo.output_tokens == 876, """
      A contagem de saída chega no mesmo mapa `usage` que a de entrada. A versão anterior
      lia uma chave e descartava o resto, e nenhum teste reprovava porque o mock também só
      devolvia uma.
      """
    end

    test "o provedor que não informa a saída deixa nulo, e nunca zero", ctx do
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:ok, %{text: Jason.encode!(resposta()), model: "m1", usage: %{"prompt_tokens" => 100}}}
      end)

      run = abrir(ctx.tenant, ctx.admin)
      assert :ok = executar(ctx.tenant, run)

      [entrada] =
        TheBand.Repo.all(
          Ecto.Query.from(e in TheBand.Profiles.RunEntry,
            where: e.profile_run_id == ^run.id,
            select: %{input: e.input_tokens, output: e.output_tokens}
          )
        )

      assert entrada.input == 100

      assert is_nil(entrada.output), """
      Zero significaria "chamou e não gerou saída", que nunca é verdade numa geração
      bem-sucedida. Ausência de informação é nula — a mesma regra que o `input_tokens` já
      seguia.
      """
    end

    test "a credencial usada fica registrada, e é a da própria organização", ctx do
      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)

      assert fechada.credential_last_four == "eres",
             "os quatro últimos da chave da organização — é o que torna a SC-006 verificável"
    end
  end

  describe "o checkpoint" do
    test "executar duas vezes não gera um segundo perfil da mesma pessoa", ctx do
      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, run)

      antes = Repo.aggregate("eo_person_profiles", :count)

      # Nenhuma expectativa nova de `complete` — se a segunda execução chamasse o provedor,
      # o Mox reprovaria aqui, e é justamente esse o defeito que o checkpoint impede.
      assert :ok = executar(ctx.tenant, run)

      assert Repo.aggregate("eo_person_profiles", :count) == antes
    end

    test "a pessoa já registrada não é reconsiderada", ctx do
      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, run)

      assert Repo.aggregate("profile_run_entries", :count) == 1
    end
  end

  describe "as duas falhas, e elas não são a mesma" do
    test "chave recusada encerra a rodada no meio", ctx do
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:error, {:http, 401, "Incorrect API key"}}
      end)

      run = abrir(ctx.tenant, ctx.admin)
      assert :ok = executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)
      assert fechada.outcome == "ended_early"
      assert fechada.ended_reason =~ "401"
      assert Runs.summary(fechada).failed == 1
    end

    test "limite de taxa não encerra: a pessoa falha e a rodada segue", ctx do
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:error, {:http, 429, "rate limited"}}
      end)

      run = abrir(ctx.tenant, ctx.admin)
      assert :ok = executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)

      assert fechada.outcome == "completed",
             """
             O limite de taxa encerrou a rodada.

             Com a chave recusada a próxima pessoa falharia igual — com `429`, não: é do
             momento, e encerrar deixaria de gerar quem ainda daria certo.
             """
    end

    test "exceção ao gerar é falha DAQUELA pessoa — a rodada nunca fica muda", ctx do
      # A rodada real de 2026-08-17: um ArithmeticError no material derrubou o job três
      # vezes, o Oban descartou, e a tela disse "running" por sete horas. A exceção tem
      # que virar entrada "failed" com o motivo, e a rodada tem que FECHAR.
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        raise ArithmeticError, message: "bad argument in arithmetic expression"
      end)

      run = abrir(ctx.tenant, ctx.admin)
      assert :ok = executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)

      assert fechada.outcome == "completed",
             "a exceção derrubou a rodada inteira — era para ser falha de uma pessoa só"

      resumo = Runs.summary(fechada)
      assert resumo.failed == 1, "a falha sumiu do resumo — sucesso silencioso de novo"
    end

    test "quem falhou volta na rodada seguinte", ctx do
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:error, {:http, 429, "rate limited"}}
      end)

      primeira = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, primeira)

      gera_ok()
      segunda = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, segunda)

      {:ok, fechada} = Runs.get(ctx.tenant, segunda.id)

      assert Runs.summary(fechada).generated == 1,
             "falha não cria fila própria: a pessoa volta pelo critério normal da FR-006"
    end
  end

  describe "duas rodadas ao mesmo tempo" do
    test "a segunda é recusada com motivo, e não enfileirada em silêncio", ctx do
      _run = abrir(ctx.tenant, ctx.admin)

      assert {:error, :already_running} =
               Runs.start(ctx.tenant, trigger: :manual, requested_by: ctx.admin)
    end

    test "a recusa vale também para a automática", ctx do
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)

      assert {:error, :already_running} = Runs.start(ctx.tenant, trigger: :cron)
    end
  end

  describe "o cron mensal" do
    test "sem evento de automação, nenhuma rodada é enfileirada", ctx do
      assert :ok = MonthlyWorker.perform(%Oban.Job{args: %{}})

      assert Runs.list(ctx.tenant) == [],
             """
             Uma rodada nasceu de um deploy.

             A `FR-018a` existe para que subir a versão não faça texto passar a existir sobre
             ninguém: sem ato humano, não há autor para a `FR-019` registrar.
             """
    end

    test "com a automação ligada, uma rodada por organização elegível", ctx do
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)
      {:ok, aberta} = Runs.running(ctx.tenant)
      {:ok, _} = Runs.finish(aberta, :completed)

      {sem_chave, admin2} = tenant_with_admin("sem-chave")

      assert :ok = MonthlyWorker.perform(%Oban.Job{args: %{}})

      assert length(Runs.list(ctx.tenant)) == 2
      assert Runs.list(sem_chave) == []
      refute Automation.enabled?(sem_chave)
      assert admin2.tenant_id == sem_chave.id
    end
  end

  describe "a rodada manual gera para todo mundo — emenda de 2026-08-16 à FR-004" do
    test "quem o cron pularia por falta de trabalho novo gera na rodada a mão", ctx do
      # Primeira rodada escreve o perfil; sem trabalho novo depois dela, o critério de
      # mudança pularia a pessoa — e é exatamente quem a rodada a mão tem de alcançar.
      gera_ok()
      primeira = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, primeira)

      Process.sleep(1100)

      gera_ok()
      segunda = abrir(ctx.tenant, ctx.admin)
      assert :ok = executar(ctx.tenant, segunda)

      {:ok, fechada} = Runs.get(ctx.tenant, segunda.id)
      resumo = Runs.summary(fechada)

      assert resumo.generated == 1

      assert resumo.skipped.no_new_work == 0,
             "a regra de mudança valeu numa rodada pedida a mão — ela é só do cron"
    end

    test "o plano é gravado, e é o denominador da barra de progresso", ctx do
      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)

      assert run.people_selected == nil, "o plano só existe depois da seleção"

      executar(ctx.tenant, run)

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)
      assert fechada.people_selected == 1

      assert Runs.summary(fechada).considered == fechada.people_selected,
             "rodada completa: todo selecionado tem desfecho"
    end

    test "cada checkpoint avisa quem assina, e o aviso carrega só o id", ctx do
      :ok = Runs.subscribe(ctx.tenant)

      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)
      run_id = run.id

      executar(ctx.tenant, run)

      # Abertura, plano, checkpoint e encerramento — pelo menos estes; a tela recarrega do
      # banco a cada um, então receber "demais" é inofensivo e receber de menos é a barra
      # parada.
      assert_received {:rodada, ^run_id}
      assert_received {:rodada, ^run_id}
      assert_received {:rodada, ^run_id}
    end
  end

  describe "o isolamento entre organizações" do
    test "a rodada de uma não aparece na listagem da outra", ctx do
      {outro, _} = tenant_with_admin("outro")
      run = abrir(ctx.tenant, ctx.admin)

      assert Runs.list(outro) == []
      assert {:error, :not_found} = Runs.get(outro, run.id)
      assert {:error, :never_ran} = Runs.latest(outro)
    end
  end

  describe "as combinações inválidas da entrada" do
    test "pulado sem motivo e gerado com motivo são recusados", ctx do
      run = abrir(ctx.tenant, ctx.admin)

      assert {:error, %Ecto.Changeset{}} =
               Runs.record(run, ctx.pessoa.id, %{outcome: "skipped"})

      assert {:error, %Ecto.Changeset{}} =
               Runs.record(run, ctx.pessoa.id, %{outcome: "generated", reason: "no_material"})

      assert {:error, %Ecto.Changeset{}} =
               Runs.record(run, ctx.pessoa.id, %{outcome: "failed"})
    end

    test "o mesmo desfecho gravado duas vezes é recusado pelo banco", ctx do
      run = abrir(ctx.tenant, ctx.admin)

      {:ok, _} = Runs.record(run, ctx.pessoa.id, %{outcome: "skipped", reason: "no_new_work"})

      assert {:error, :already_recorded} =
               Runs.record(run, ctx.pessoa.id, %{outcome: "skipped", reason: "no_new_work"})
    end

    test "os três motivos de pulo são a lista fechada", _ctx do
      assert RunEntry.reasons() == ~w(no_material no_new_work observation_ended)

      refute "failed" in RunEntry.reasons(),
             "falhar é desfecho, e não motivo de pulo: pular é decidir não escrever"
    end
  end

  describe "o material continua sendo o histórico inteiro" do
    # Este teste reprovou no CI **com o produto certo**, e os dois defeitos eram dele.
    #
    # A fixture numerava o segundo lote de 1, colidindo com os `external_id` do primeiro: a
    # coleta faz upsert, então em vez de 15 tarefas novas o teste **movia 15 antigas** para
    # 2026, e o início do histórico andava de verdade. E localmente ninguém via, porque as
    # duas gerações caíam no mesmo segundo, o índice único `[pessoa, generated_at]` recusava
    # a segunda, e a asserção comparava o perfil um com ele mesmo — verde vazio. No CI, mais
    # lento sob cobertura, a segunda geração cruzava o segundo, era gravada, e a comparação
    # rodava de verdade contra o histórico reescrito.
    test "o recorte de duas gerações consecutivas não anda para frente", ctx do
      gera_ok()
      primeira = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, primeira)

      {:ok, perfil_um} = EO.current_profile(ctx.tenant, ctx.pessoa.id)

      # Trabalho novo o bastante para a regra de mudança deixar gerar de novo — e `desde: 31`
      # porque tarefa nova é tarefa que não existia, nunca uma antiga com data nova.
      pessoa_com_material(ctx.tenant, ctx.repo_id, "gerada",
        tarefas: 15,
        base: ~U[2026-06-01 12:00:00Z],
        desde: 31
      )

      # `generated_at` tem resolução de segundo, e o índice único não admite duas gerações da
      # mesma pessoa no mesmo segundo. Cruzar a fronteira é a condição para a segunda geração
      # existir — sem isto, o teste passa comparando o perfil um com ele mesmo.
      Process.sleep(1100)

      gera_ok()
      segunda = abrir(ctx.tenant, ctx.admin)
      executar(ctx.tenant, segunda)

      # A geração aconteceu — a asserção de baixo não significa nada se a rodada pulou ou
      # falhou e o "perfil dois" for o um de novo.
      {:ok, fechada} = Runs.get(ctx.tenant, segunda.id)
      assert Runs.summary(fechada).generated == 1

      {:ok, perfil_dois} = EO.current_profile(ctx.tenant, ctx.pessoa.id)
      assert perfil_dois.id != perfil_um.id

      assert perfil_dois.period_from == perfil_um.period_from,
             """
             O início do recorte andou para frente entre duas gerações.

             A decisão de 2026-08-16 é que cada geração lê o histórico inteiro da pessoa, e
             não o que entrou desde o perfil anterior — `FR-022`. Um texto escrito só sobre os
             últimos meses falaria de um recorte, não de uma trajetória.
             """
    end
  end

  describe "o registro operacional — T023" do
    # FR-027 e FR-013: o log conta o que a rodada fez, e não carrega nem a chave nem o
    # material — o material é texto de tarefas de pessoas reais, e a chave é dinheiro.
    test "o log de uma rodada completa não contém a chave nem o material", ctx do
      import ExUnit.CaptureLog

      gera_ok()
      run = abrir(ctx.tenant, ctx.admin)

      log =
        capture_log(fn ->
          assert :ok = executar(ctx.tenant, run)
        end)

      # A chave gravada na credencial da organização, e o corpo que a fixture põe em toda
      # tarefa — se qualquer um vazar para o log, é ele que este teste segura.
      refute log =~ "sk-chave-de-teste", "a chave do provedor apareceu no log da rodada"
      refute log =~ "contexto. contexto.", "o material enviado ao provedor apareceu no log"
    end

    test "a falha registrada no log e na coluna carrega a mensagem já redigida", ctx do
      import ExUnit.CaptureLog

      # O provedor às vezes ecoa a chave na mensagem de erro. Quem a tira é a **borda** —
      # `req.ex` passa todo ramo de erro por `HTTP.redigir/2`, e isso tem teste próprio em
      # `generate_worker_test`. O que ESTE caso guarda é o resto do caminho: a mensagem que
      # a borda devolve atravessa o worker até o log e até `ended_reason` — que a tela
      # exibe — sem ninguém reconstruir o texto cru no meio.
      expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:error, {:http, 401, "Incorrect API key «API_KEY»"}}
      end)

      run = abrir(ctx.tenant, ctx.admin)

      log =
        capture_log(fn ->
          assert :ok = executar(ctx.tenant, run)
        end)

      assert log =~ "encerrada no meio"
      refute log =~ "sk-chave-de-teste", "a chave apareceu no log do encerramento"

      {:ok, fechada} = Runs.get(ctx.tenant, run.id)
      assert fechada.ended_reason =~ "«API_KEY»"
      refute fechada.ended_reason =~ "sk-chave-de-teste"
    end
  end
end
