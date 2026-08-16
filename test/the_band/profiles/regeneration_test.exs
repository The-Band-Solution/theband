defmodule TheBand.Profiles.RegenerationTest do
  @moduledoc """
  Quem entra na rodada, e por qual motivo não — feature 027, T010 e T011.

  ## O que este arquivo protege

  **O motivo é metade da resposta.** `due?/3` devolve `:generate` ou `{:skip, motivo}`, nunca
  booleano: a `FR-014` conta por motivo, e um booleano obrigaria quem chama a redescobrir o
  porquê.

  **Os dois ramos da `FR-006` alcançam gente diferente**, e a fronteira de cada um tem caso
  próprio — N−1 tarefas novas não gera, N gera.

  **Não há limiar embutido no código.** Base sem a regra devolve erro, e a rodada não executa.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import Mox
  import TheBand.ProfileRunFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.YamlLoader
  alias TheBand.Profiles.Regeneration
  alias TheBand.Repo

  setup :verify_on_exit!

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, _admin} = tenant_with_admin()
    cenario = cenario(tenant)
    limiares = %{n: 10, m_months: 3}

    %{tenant: tenant, pessoa: cenario.pessoa, repo_id: cenario.repo_id, limiares: limiares}
  end

  # A forma mínima que o schema aceita — o conteúdo não importa para estes testes, e a
  # validação de chaves existe porque perfil incompleto na tela é pior que perfil ausente.
  defp conteudo do
    %{
      "habilidades" => ["observabilidade com OpenTelemetry"],
      "destaques" => [],
      "lacunas" => [],
      "resumo" => %{"forcas" => "x", "evolucao" => "y", "atencao" => "z"},
      "trajetoria" => [],
      "alocacao" => [],
      "recomendacoes" => []
    }
  end

  defp perfil(tenant, pessoa, attrs) do
    {:ok, p} =
      EO.record_profile(
        tenant,
        Map.merge(
          %{
            person_id: pessoa.id,
            generated_at: DateTime.utc_now(:second),
            model: "m1",
            content: conteudo(),
            tasks_closed: 30,
            tasks_open: 0,
            tasks_with_body: 30,
            tasks_authored_by_other: 0,
            tasks_shared: 0
          },
          attrs
        )
      )

    p
  end

  describe "os limiares vêm da base, e não do código" do
    test "com a regra presente, os dois números são lidos" do
      assert {:ok, %{n: 10, m_months: 3}} = Regeneration.thresholds()
    end

    test "sem a regra, é erro — e nenhum padrão embutido a substitui" do
      # A base carregada em ETS é a boa; o teste exercita o ramo do erro pela ausência da
      # chave dentro da regra, que é a forma que a `FR-009` proíbe silenciar.
      assert {:error, _} = Regeneration.thresholds_de(%{"rules" => %{}})
    end
  end

  describe "os seis ramos da due?/3" do
    test "observação encerrada é pulada com o motivo dela", ctx do
      {1, _} =
        Repo.update_all(
          from(p in "eo_people", where: p.id == type(^ctx.pessoa.id, :binary_id)),
          set: [no_longer_observed_at: DateTime.utc_now(:second)]
        )

      pessoa = Repo.get!(TheBand.Ontology.SEON.EO.Schemas.Person, ctx.pessoa.id)

      assert {:skip, :observation_ended} = Regeneration.due?(ctx.tenant, pessoa, ctx.limiares)
    end

    test "sem material que passe nos pisos, o motivo é o material", ctx do
      # Com a regra da primeira geração (2026-08-16), pouco texto SEM perfil gera; o piso
      # volta quando existe perfil anterior — é esse o caminho que este caso guarda.
      rala =
        TheBand.ProfileRunFixtures.pessoa_com_material(ctx.tenant, ctx.repo_id, "rala",
          tarefas: 2
        )

      perfil(ctx.tenant, rala, %{period_to: ~D[2020-01-01]})

      assert {:skip, :no_material} = Regeneration.due?(ctx.tenant, rala, ctx.limiares)
    end

    test "quem nunca teve perfil gera, sem passar pela regra de mudança", ctx do
      assert :generate = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares)
    end

    test "perfil recente sem trabalho novo não gera", ctx do
      perfil(ctx.tenant, ctx.pessoa, %{period_to: ~D[2030-01-01]})

      assert {:skip, :no_new_work} = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares)
    end

    test "a fronteira do N: abaixo não gera, no limiar gera", ctx do
      # O recorte termina antes das últimas tarefas: o que sobra depois dele é o "trabalho
      # novo". Nove tarefas não bastam; dez bastam — e é a fronteira que decide quem entra.
      perfil(ctx.tenant, ctx.pessoa, %{period_to: ~D[2026-01-06]})

      assert {:skip, :no_new_work} = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares)

      # Momento distinto porque a tabela é somente-acréscimo e tem índice único por
      # `[pessoa, generated_at]`: dois perfis no mesmo segundo seriam a mesma geração.
      perfil(ctx.tenant, ctx.pessoa, %{
        period_to: ~D[2025-12-01],
        generated_at: DateTime.add(DateTime.utc_now(:second), 1, :second)
      })

      assert :generate = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares)
    end

    test "perfil velho gera mesmo sem trabalho novo — é o ramo do M", ctx do
      perfil(ctx.tenant, ctx.pessoa, %{
        period_to: ~D[2030-01-01],
        generated_at: DateTime.add(DateTime.utc_now(:second), -200, :day)
      })

      assert :generate = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares),
             """
             O ramo do M não alcançou.

             Sem ele, quem trabalha pouco ficaria com o mesmo texto para sempre — e são 14 das
             34 pessoas medidas em 2026-08-16.
             """
    end
  end

  describe "select/1" do
    test "devolve também quem será pulado, porque a contagem por motivo depende disso", ctx do
      {:ok, _} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "sem-designacao",
          name: "SEM",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          source_endpoint: "/users/sem",
          external_id: "U_sem",
          collected_at: DateTime.utc_now(:second),
          payload: %{}
        })

      assert {:ok, vereditos} = Regeneration.select(ctx.tenant)
      assert length(vereditos) == 2

      motivos = Enum.map(vereditos, fn {_p, v} -> v end)
      assert :generate in motivos
      assert {:skip, :no_material} in motivos
    end
  end

  describe "o escopo :todas — a rodada manual gera para todo mundo com material" do
    # Emenda de 2026-08-16 à FR-004: pedir a mão já é a decisão de escrever, e a regra de
    # mudança existe para a rodada que ninguém pediu.

    test "quem seria pulado por falta de trabalho novo gera", ctx do
      perfil(ctx.tenant, ctx.pessoa, %{period_to: ~D[2030-01-01]})

      assert {:skip, :no_new_work} =
               Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares, :mudou)

      assert :generate = Regeneration.due?(ctx.tenant, ctx.pessoa, ctx.limiares, :todas)
    end

    test "os pulos de fato continuam: sem material e observação encerrada", ctx do
      # O pulo de material que sobrevive à primeira geração é o de quem não tem NADA
      # designado — texto pouco já não pula (regra de 2026-08-16).
      {:ok, sem_nada} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "sem-designacao",
          name: "SEM",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          source_endpoint: "/users/sem",
          external_id: "U_sem",
          collected_at: DateTime.utc_now(:second),
          payload: %{}
        })

      assert {:skip, :no_material} =
               Regeneration.due?(ctx.tenant, sem_nada, ctx.limiares, :todas)

      Repo.update_all(
        from(p in TheBand.Ontology.SEON.EO.Schemas.Person, where: p.id == ^ctx.pessoa.id),
        set: [no_longer_observed_at: DateTime.utc_now(:second)]
      )

      encerrada = Repo.get!(TheBand.Ontology.SEON.EO.Schemas.Person, ctx.pessoa.id)

      assert {:skip, :observation_ended} =
               Regeneration.due?(ctx.tenant, encerrada, ctx.limiares, :todas)
    end

    test "sem o argumento, o escopo é :mudou — o cron não muda de comportamento", ctx do
      perfil(ctx.tenant, ctx.pessoa, %{period_to: ~D[2030-01-01]})

      assert {:ok, vereditos} = Regeneration.select(ctx.tenant)
      assert [{_, {:skip, :no_new_work}}] = vereditos
    end
  end

  describe "o limiar novo vale na rodada seguinte — T022, US3" do
    # O teste percorre o caminho INTEIRO da FR-009: uma base com N diferente, o GenServer
    # reiniciado sobre ela, e a seleção mudando — sem recompilar nada. Testar `due?/4` com
    # dois mapas de limiares provaria menos: o risco não é a comparação, é alguém um dia
    # mover a leitura para atributo de módulo, onde ela congela no build.
    test "mudar N de 10 para 3 muda quem é selecionado, sem recompilar", ctx do
      # Oito tarefas fechadas depois do recorte: abaixo de N=10, acima de N=3.
      perfil(ctx.tenant, ctx.pessoa, %{period_to: ~D[2026-01-13]})

      assert {:ok, [{_, {:skip, :no_new_work}}]} = Regeneration.select(ctx.tenant)

      raiz = Path.join(System.tmp_dir!(), "kb_n3_#{System.unique_integer([:positive])}")
      File.cp_r!(YamlLoader.root(), raiz)

      limiar = Path.join(raiz, "rules/profile_thresholds.yaml")

      File.write!(
        limiar,
        String.replace(File.read!(limiar), "min_new_closed_tasks: 10", "min_new_closed_tasks: 3")
      )

      original = Application.get_env(:the_band, KnowledgeBase)
      Application.put_env(:the_band, KnowledgeBase, path: raiz)

      on_exit(fn ->
        Application.put_env(:the_band, KnowledgeBase, original || [])
        GenServer.stop(KnowledgeBase)
        # **Esperar a base voltar é parte da limpeza.** Sem isto, o teste seguinte corre
        # contra o restart do supervisor e encontra a ETS vazia — foi exatamente assim
        # que seis testes de reprocessamento reprovaram no CI num gatilho e passaram no
        # outro (a forma da L59: o veredito dependia do seed que ordenava os arquivos).
        aguardar_base()
        File.rm_rf!(raiz)
      end)

      # O supervisor reergue o GenServer, e o init lê a raiz do Application env — que agora
      # aponta para a base com N=3. É o mesmo caminho de um deploy.
      GenServer.stop(KnowledgeBase)
      aguardar_base()

      assert {:ok, %{n: 3}} = Regeneration.thresholds()
      assert {:ok, [{_, :generate}]} = Regeneration.select(ctx.tenant)
    end

    defp aguardar_base do
      # O restart do supervisor é assíncrono; a base está de volta quando a consulta
      # responde. `raise`, e não `flunk`: isto roda também em `on_exit`, fora do processo
      # do teste.
      Enum.find(1..100, fn _ ->
        Process.sleep(20)
        match?({:ok, _}, Regeneration.thresholds())
      end) || raise "a base de conhecimento não voltou depois do restart"
    end
  end

  describe "a primeira geração pega tudo — decisão de 2026-08-16" do
    test "sem perfil anterior, quem tem pouco texto GERA; com perfil, os pisos voltam", ctx do
      # Duas tarefas só — muito abaixo do piso de 15. Sem perfil anterior: gera.
      rala =
        TheBand.ProfileRunFixtures.pessoa_com_material(ctx.tenant, ctx.repo_id, "rala",
          tarefas: 2
        )

      assert :generate = Regeneration.due?(ctx.tenant, rala, ctx.limiares),
             "a primeira geração foi barrada pelo piso — o piso protege a comparação, e não há o que comparar"

      # Com perfil vigente, os pisos inteiros voltam: 2 tarefas é below_floor.
      perfil(ctx.tenant, rala, %{period_to: ~D[2020-01-01]})

      assert {:skip, :no_material} = Regeneration.due?(ctx.tenant, rala, ctx.limiares),
             "os pisos não voltaram na segunda geração"
    end
  end
end
