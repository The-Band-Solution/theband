defmodule TheBand.Ingestion.ReconcileStuckSyncsTest do
  @moduledoc """
  A execução presa, e o defeito oposto (T002 a T005).

  ## O teste que mais importa é o que NÃO encerra

  Encerrar coleta viva é pior que o bloqueio que esta feature resolve: destrava a ferramenta e
  derruba trabalho em andamento. Por isso os jobs aqui são inseridos **de verdade** em
  `oban_jobs` — simular a consulta faria o teste passar sem medir nada.

  E os estados ativos são comparados com `Oban.Job.states/0` em vez de repetidos: a primeira
  versão desta feature listou quatro e esqueceu `suspended`, que é trabalho pausado e vai
  executar.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Sources.ConnectedTool

  @terminais ~w(completed discarded cancelled)

  setup do
    tenant = tenant_fixture()
    %{tenant: tenant, tool: ferramenta(tenant)}
  end

  describe "o que conta como trabalho vivo" do
    test "os cinco estados ativos impedem o encerramento", ctx do
      # Uma ferramenta por estado, e não é detalhe: o índice único parcial permite **uma**
      # execução `running` por ferramenta, e é a defesa que esta feature preserva. Reusar a
      # mesma ferramenta faria o teste falhar por violar a restrição que ele não está medindo.
      for estado <- Enum.map(Oban.Job.states(), &to_string/1) -- @terminais do
        sync =
          sync_presa(%{ctx | tool: ferramenta(ctx.tenant, "org-#{estado}")}, minutos_atras: 10)

        job(sync, estado)

        assert {:ok, []} = Ingestion.reconcile_stuck_syncs()

        assert Ingestion.reload(sync).status == "running", """
        A execução foi encerrada, e o trabalho dela está em `#{estado}` — que significa que
        vai executar.

        Encerrar aqui derruba trabalho em andamento, e é o defeito oposto ao da issue #175:
        pior que o bloqueio, porque o bloqueio não perde coleta.
        """
      end
    end

    test "a lista de ativos não pode ser literal", _ctx do
      # Não é teste de comportamento: é o que impede a lista de envelhecer. Uma versão nova do
      # Oban que acrescente estado entraria em silêncio numa lista copiada — e a primeira
      # versão desta feature já errou assim, omitindo `suspended`.
      assert Enum.sort(Oban.Job.states()) ==
               Enum.sort(
                 ~w(suspended scheduled available executing retryable)a ++
                   [
                     :completed,
                     :discarded,
                     :cancelled
                   ]
               ),
             """
             `Oban.Job.states/0` mudou: #{inspect(Oban.Job.states())}.

             Cada estado novo precisa ser classificado como ativo — "vai executar" — ou
             terminal. Sem classificar, a reconciliação decide sobre um estado que ninguém
             examinou.
             """
    end
  end

  describe "o que é encerrado" do
    test "sem trabalho nenhum, a execução é encerrada", ctx do
      sync = sync_presa(ctx, minutos_atras: 10)

      assert {:ok, [encerrada]} = Ingestion.reconcile_stuck_syncs()
      assert encerrada.id == sync.id
      assert encerrada.status == "interrupted"
      assert encerrada.finished_at
    end

    test "trabalho terminal não é vivo", ctx do
      for estado <- @terminais do
        sync = sync_presa(ctx, minutos_atras: 10)
        job(sync, estado)

        assert {:ok, [encerrada]} = Ingestion.reconcile_stuck_syncs()
        assert encerrada.id == sync.id
      end
    end

    test "a ferramenta volta a aceitar coleta", ctx do
      sync_presa(ctx, minutos_atras: 10)

      # É o índice único parcial que bloqueia, e é ele que o teste exercita: abrir uma segunda
      # execução com a primeira `running` violaria a restrição.
      {:ok, _} = Ingestion.reconcile_stuck_syncs()

      assert {:ok, _nova} =
               %Sync{}
               |> Sync.changeset(%{
                 tenant_id: ctx.tenant.id,
                 connected_tool_id: ctx.tool.id,
                 status: "running",
                 started_at: DateTime.utc_now(:second)
               })
               |> Repo.insert(),
             """
             A ferramenta continua bloqueada depois da reconciliação.

             É o problema inteiro da issue #175: o índice único parcial impede a segunda
             coleta enquanto a primeira estiver `running`, e a primeira morreu.
             """
    end
  end

  describe "a carência da execução recém-aberta" do
    test "execução aberta há segundos continua running", ctx do
      sync = sync_presa(ctx, minutos_atras: 0)

      assert {:ok, []} = Ingestion.reconcile_stuck_syncs()

      assert Ingestion.reload(sync).status == "running", """
      A execução foi encerrada segundos depois de ser aberta.

      Abrir o registro e criar o trabalho são duas operações, e no intervalo a execução tem a
      assinatura exata de "presa" — `running` e sem trabalho. Sem carência, a reconciliação
      derruba coleta que acabou de começar.
      """
    end
  end

  describe "o motivo, por causa" do
    test "trabalho descartado carrega a falha que ele registrou", ctx do
      sync = sync_presa(ctx, minutos_atras: 10)

      job(sync, "discarded",
        attempt: 3,
        max_attempts: 3,
        errors: [%{"error" => "** (Req.TransportError) :nxdomain", "attempt" => 3}]
      )

      assert {:ok, [encerrada]} = Ingestion.reconcile_stuck_syncs()

      assert encerrada.error_reason =~ "nxdomain"
      assert encerrada.error_reason =~ "3 de 3"
    end

    test "sem trabalho, o motivo não inventa falha", ctx do
      sync_presa(ctx, minutos_atras: 10)

      assert {:ok, [encerrada]} = Ingestion.reconcile_stuck_syncs()

      assert encerrada.error_reason == "o processo que a executava não existe mais"

      refute encerrada.error_reason =~ ~r/erro|error|falha/i, """
      O motivo afirma falha, e nenhuma foi observada: o trabalho simplesmente não existe.

      Dizer "erro" aqui apagaria a diferença entre falha transitória e permanente — a mesma
      que custou 899 issues fora de circulação (L29).
      """
    end

    test "os motivos das duas causas são diferentes", ctx do
      com_descarte = sync_presa(ctx, minutos_atras: 10)
      job(com_descarte, "discarded", errors: [%{"error" => "boom", "attempt" => 1}])

      outra = ferramenta(ctx.tenant, "outra-org")
      sem_trabalho = sync_presa(%{ctx | tool: outra}, minutos_atras: 10)

      assert {:ok, encerradas} = Ingestion.reconcile_stuck_syncs()
      motivos = Map.new(encerradas, &{&1.id, &1.error_reason})

      refute motivos[com_descarte.id] == motivos[sem_trabalho.id], """
      As duas causas produziram o mesmo motivo.

      Quem lê precisa saber se tenta de novo — DNS que não resolveu se cura, credencial
      revogada não. Um motivo só para as duas apaga a decisão seguinte.
      """
    end
  end

  describe "não mudar o encerramento já feito" do
    test "reconciliar depois de encerrar por pessoa preserva o autor", ctx do
      user = user_fixture(ctx.tenant)
      sync = sync_presa(ctx, minutos_atras: 10)

      assert {:ok, encerrada} = Ingestion.interrupt_sync(ctx.tenant, sync.id, user)
      assert encerrada.interrupted_by_user_id == user.id

      assert {:ok, []} = Ingestion.reconcile_stuck_syncs()

      depois = Ingestion.reload(sync)

      assert depois.interrupted_by_user_id == user.id, """
      O gatilho automático apagou o autor da decisão humana.

      A reconciliação age só sobre `running`. Se ela tocar execução já encerrada, quem
      encerrou desaparece do registro — e dois gatilhos podem disparar no mesmo instante.
      """

      assert depois.error_reason == encerrada.error_reason
    end

    test "encerrar duas vezes devolve not_running", ctx do
      user = user_fixture(ctx.tenant)
      sync = sync_presa(ctx, minutos_atras: 10)

      assert {:ok, _} = Ingestion.interrupt_sync(ctx.tenant, sync.id, user)
      assert {:error, :not_running} = Ingestion.interrupt_sync(ctx.tenant, sync.id, user)
    end
  end

  describe "a ação humana" do
    test "trabalho que a fila VAI pegar é recusado, mesmo sem botão", ctx do
      user = user_fixture(ctx.tenant)
      sync = sync_presa(ctx, minutos_atras: 10)
      job(sync, "available")

      refute Ingestion.interruptible?(sync)

      assert {:error, :job_alive} = Ingestion.interrupt_sync(ctx.tenant, sync.id, user), """
      A requisição direta encerrou uma execução cujo trabalho está `available`.

      A fila vai pegar esse trabalho, e isso a plataforma **prova**. Encerrar o registro
      liberaria o índice, e a coleta começaria em paralelo com uma segunda — e a tela não pode
      ser a única defesa, porque entre desenhar o botão e alguém clicar o estado muda.
      """
    end

    test "trabalho `executing` num nó morto PODE ser encerrado por pessoa", ctx do
      user = user_fixture(ctx.tenant)
      sync = sync_presa(ctx, minutos_atras: 10)
      job(sync, "executing")

      # É o caso que aconteceu duas vezes e motivou a issue #175: o job 5 do banco de
      # desenvolvimento está `executing` desde 2026-08-09, num nó que não existe mais.
      #
      # `executing` **não é prova de vida** — é um claim que sobrevive ao processo. A
      # plataforma não consegue distinguir coleta rodando de nó morto, e por isso não encerra
      # sozinha. Quem reiniciou a aplicação sabe, e é essa pessoa que decide.
      assert Ingestion.interruptible?(sync), """
      A ação não foi oferecida para o caso que a feature existe para resolver.

      Se `executing` bloquear a pessoa também, o órfão de nó morto fica preso para sempre — e
      a única saída volta a ser SQL, que é o que a issue #175 pede para eliminar.
      """

      assert {:ok, encerrada} = Ingestion.interrupt_sync(ctx.tenant, sync.id, user)
      assert encerrada.interrupted_by_user_id == user.id

      assert encerrada.error_reason =~ "o processo não existe mais", """
      O motivo precisa registrar **o que a pessoa afirmou** — que o processo morreu —, e não o
      que a plataforma observou, porque ela não observou nada.
      """
    end

    test "a plataforma NÃO encerra sozinha o que consta em execução", ctx do
      sync = sync_presa(ctx, minutos_atras: 10)
      job(sync, "executing")

      assert {:ok, []} = Ingestion.reconcile_stuck_syncs()

      assert Ingestion.reload(sync).status == "running", """
      A reconciliação automática encerrou uma execução cujo trabalho consta em execução.

      Ela não pode: se a coleta estiver de fato rodando, encerrar o registro libera o índice e
      uma segunda coleta começa **em paralelo** — a L02, com número duplicado passando por
      correto. Quem decide nesse caso é a pessoa, que sabe se reiniciou a aplicação.
      """
    end

    test "execução de outro tenant responde não encontrado", ctx do
      outro = tenant_fixture()
      user = user_fixture(outro)
      sync = sync_presa(ctx, minutos_atras: 10)

      assert {:error, :not_found} = Ingestion.interrupt_sync(outro, sync.id, user), """
      A resposta precisa ser **não encontrado**, nunca "sem permissão": confirmar existência
      já é vazamento entre tenants.
      """
    end

    test "interruptible? é falso para execução já encerrada", ctx do
      sync = sync_presa(ctx, minutos_atras: 10)
      {:ok, encerrada} = Ingestion.finish(sync, :completed)

      refute Ingestion.interruptible?(encerrada)
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp sync_presa(ctx, minutos_atras: minutos) do
    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: ctx.tenant.id,
        connected_tool_id: ctx.tool.id,
        status: "running",
        started_at: DateTime.add(DateTime.utc_now(:second), -minutos * 60, :second)
      })
      |> Repo.insert()

    sync
  end

  # O job vai **para a tabela**, e não para um mock: a decisão consulta `oban_jobs`, e um mock
  # aqui testaria o mock.
  defp job(%Sync{id: sync_id}, estado, opts \\ []) do
    Repo.insert!(%Oban.Job{
      state: estado,
      queue: "ingestion",
      worker: "TheBand.Jobs.SyncGitHubEO",
      args: %{"sync_id" => sync_id, "tenant_id" => Ecto.UUID.generate()},
      attempt: Keyword.get(opts, :attempt, 1),
      max_attempts: Keyword.get(opts, :max_attempts, 5),
      errors: Keyword.get(opts, :errors, []),
      # `oban_jobs` guarda microssegundo; truncar aqui levanta na inserção.
      attempted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now()
    })
  end

  defp ferramenta(tenant, login \\ "acme") do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> Repo.insert()

    tool
  end
end
