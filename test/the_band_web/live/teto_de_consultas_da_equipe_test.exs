defmodule TheBandWeb.TetoDeConsultasDaEquipeTest do
  @moduledoc """
  O custo das duas telas de equipe — feature 057, T031.

  **O teto é teste, e não anotação.** Anotado no plano, ele não impede nada: a
  próxima seção acrescentada passa despercebida, e a página começa a consultar
  por linha sem ninguém notar. É o defeito que a feature 007 pagou com 135
  consultas por render.

  ## As duas asserções, e qual delas importa mais

  1. **o número não cresce com o dado** — a mais importante. Uma tela que
     consulta por subequipe ou por pessoa passa com três e derruba com trinta;
  2. **o número tem teto declarado** — "um número que não cresce" passa com 8 e
     com 80.

  ## A medida é a DIFERENÇA, e não o total

  `live/2` faz consultas de framework e autenticação em dois renders. Medir o
  total mediria o Phoenix; a diferença contra a listagem de equipes isola o custo
  **destas telas**.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  # Medidos em 2026-09-02. Subir qualquer um dos dois é decisão, e a decisão
  # aparece aqui em vez de passar num diff de template.
  #
  # ## O que o teto do detalhe cobre, e por que não é 9
  #
  # O `plan.md` declarou "no máximo 9 consultas por render" para a tela da
  # subequipe. **As seções da feature 057 custam 5**: duas da série, uma da linha
  # de base, uma das tarefas por pessoa e uma dos membros.
  #
  # Este número é maior porque mede a página INTEIRA contra a listagem, e a
  # página já trazia estrutura, membros, evidência pendente, projetos, avisos de
  # processo e competências — tudo anterior a esta feature. Medir só as seções
  # novas exigiria um marcador por seção, e o marcador mentiria assim que alguém
  # movesse uma consulta de lugar.
  #
  # **Sem folga de propósito.** Qualquer consulta a mais quebra, e é isso que se
  # quer: a decisão de gastar mais uma aparece neste arquivo.
  #
  # **16 → 17 em 2026-09-03**, pela T014 da feature 055: `membership_disagreements/2`,
  # a seção que mostra as duas afirmações quando a coleta e a declaração discordam
  # (FR-012). A consulta é **uma só e constante** — agrega os vínculos por pessoa
  # numa subconsulta em vez de perguntar por linha, então o número não cresce com o
  # tamanho da equipe. O teste do crescimento adiante continua valendo.
  #
  # A alternativa era derivar a discordância das listas já carregadas. Ela não
  # serve: a lista de membros observados é **paginada**, e a discordância de quem
  # está na página 2 desapareceria da tela sem que nada avisasse.
  #
  # **17 → 18 em 2026-09-03**, pela US2 da feature 058: `team_projects_with_period/2`,
  # os projetos por que a equipe passou. Ela é constante — uma consulta, independente
  # de quantos projetos existam.
  #
  # As duas consultas de `who_worked_on_many/3` só nascem quando há projeto, e por
  # isso não aparecem neste cenário. O teste do acréscimo das três seções mede o
  # caso COM projeto, e vive adiante neste mesmo arquivo.
  #
  # **18 → 19 em 2026-09-03**, pela US1 da feature 058:
  # `team_time_to_first_review/3`, a espera por revisão. É **uma** consulta para as
  # duas leituras da seção — a da equipe e a por pessoa —, agrupada em memória por
  # `agrupar_por_pessoa/1`. Uma segunda consulta com o mesmo filtro produziria dois
  # números com o mesmo rótulo, que é a L67.
  #
  # **19 → 21 em 2026-09-04**, pela revisão de segurança do PR #798. A taxa do
  # pipeline reusava a lista de vínculos que a seção de quem trabalhou já carregava,
  # por uma opção `:vinculos` — e com a lista vindo de fora, `team_id` deixava de
  # decidir qualquer coisa: a taxa de uma equipe podia sair com o rótulo de outra.
  #
  # A opção saiu, e com ela `:nome`. As duas consultas de volta são o preço da
  # garantia morar dentro da função, e não no chamador. **Subir por segurança é a
  # única razão que não precisa de justificativa de desempenho.**
  @teto_do_detalhe 21

  # O acréscimo do caminho COM PROJETO sobre o caminho sem projeto nenhum — as duas
  # consultas de `who_worked_on_many/3` e a dos repositórios, menos a que se cancela.
  #
  # **Era 6 e é 3.** O 6 foi estimado do `tasks.md`; o 3 foi medido em 2026-09-04,
  # depois de a revisão de QA apontar que o número não vinha de medição. Estimativa
  # deixa folga, e folga é onde consulta nova entra sem ninguém ver.
  #
  # **Ele NÃO mede "as três seções"** — a consulta da US1 roda nos dois lados e se
  # cancela na diferença. Quem cobre a US1 é o teto da página, acima. O nome diz o
  # que a medida é.
  @teto_do_caminho_com_projeto 3
  @teto_da_composta_por_subequipe 6

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      papel: papel,
      repo_id: cenario.observed_repository_id
    }
  end

  defp equipe(ctx, nome) do
    {:ok, t} = EO.declare_structural_team(ctx.tenant, ctx.org.id, nome, ctx.admin.id)
    t
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  defp vincular(ctx, equipe, pessoa) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -300, :day)
      })
  end

  defp issue(ctx, externo, pessoa, dias) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 1_000_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(DateTime.utc_now(:second), -dias, :day),
        collected_at: DateTime.utc_now(:second)
      })

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: pessoa.login,
      person_id: pessoa.id
    })
  end

  defp contar(fun) do
    TheBand.ContadorDeConsultas.listar(fn -> {:ok, _live, _html} = fun.() end)
  end

  defp por_render(consultas), do: div(length(consultas), 2)

  defp diferenca(antes, depois) do
    a = Enum.frequencies(antes)
    d = Enum.frequencies(depois)

    (Map.keys(a) ++ Map.keys(d))
    |> Enum.uniq()
    |> Enum.map(fn k -> {k, Map.get(d, k, 0) - Map.get(a, k, 0)} end)
    |> Enum.reject(fn {_k, delta} -> delta == 0 end)
    |> Enum.sort_by(fn {_k, delta} -> -abs(delta) end)
    |> Enum.map_join("\n", fn {k, delta} ->
      "  #{String.pad_leading("#{if delta > 0, do: "+", else: ""}#{delta}", 4)}  #{k}"
    end)
  end

  describe "a tela do detalhe da subequipe" do
    test "o número de consultas não cresce com o dado", ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      vincular(ctx, time, ana)
      for n <- 1..3, do: issue(ctx, "p#{n}", ana, n * 4)

      poucas = contar(fn -> live(ctx.conn, ~p"/teams/#{time.id}") end)

      # Agora com muito mais: dez pessoas e trinta itens abertos.
      for i <- 1..10 do
        p = pessoa(ctx, "pessoa#{i}")
        vincular(ctx, time, p)
        for n <- 1..3, do: issue(ctx, "m#{i}_#{n}", p, n * 5)
      end

      muitas = contar(fn -> live(ctx.conn, ~p"/teams/#{time.id}") end)

      assert length(poucas) == length(muitas), """
      A tela fez #{length(poucas)} consultas com 1 pessoa e 3 itens, e #{length(muitas)} com
      11 pessoas e 33 itens — ela consulta por linha.

      É a asserção que mais importa das duas: "um número que não cresce" passa com 8 e com 80,
      mas uma tela que consulta por pessoa derruba a página quando a equipe cresce.

      O que mudou entre as duas medições:

      #{diferenca(poucas, muitas)}
      """
    end

    test "o custo da tela tem teto declarado", ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      vincular(ctx, time, ana)
      for n <- 1..16, do: issue(ctx, "h#{n}", ana, n * 3)

      lista = por_render(contar(fn -> live(ctx.conn, ~p"/teams") end))
      detalhe = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{time.id}") end))
      acrescentadas = detalhe - lista

      assert acrescentadas <= @teto_do_detalhe, """
      A página da equipe acrescenta #{acrescentadas} consultas por render sobre a listagem, e o
      teto declarado é #{@teto_do_detalhe}.

      O teto cobre a página INTEIRA — estrutura, membros, evidência pendente, projetos, avisos
      de processo, competências, as seções da feature 057 e a discordância da 055 (FR-012). As
      seções da 057 custam 5 dessas, e a discordância custa 1.

      Subir o teto é decisão, e a decisão aparece neste arquivo em vez de passar num diff de
      template. Se a seção nova vale a consulta, mude o número aqui e diga por quê.
      """
    end
  end

  describe "o caminho com projeto, da feature 058" do
    test "custa no máximo o teto declarado, e o número não cresce com o dado", ctx do
      sem_projeto = equipe(ctx, "Sem projeto")
      ana = pessoa(ctx, "ana")
      vincular(ctx, sem_projeto, ana)

      com_projeto = equipe(ctx, "Com projeto")
      bia = pessoa(ctx, "bia")
      vincular(ctx, com_projeto, bia)
      ligar(ctx, com_projeto, "Alfa")

      base = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{sem_projeto.id}") end))
      com_uma = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{com_projeto.id}") end))

      # A guarda que faltava: sem ela, se as seções sumissem da tela o delta seria 0 e
      # o teto passaria — o teste celebraria a ausência do que veio medir.
      assert com_uma - base > 0, """
      O caminho com projeto não custou consulta nenhuma a mais. Ou as seções sumiram da
      tela, ou a fixture não ligou o projeto — e nos dois casos este teste não está
      medindo o que diz medir.
      """

      assert com_uma - base <= @teto_do_caminho_com_projeto, """
      O caminho com projeto acrescenta #{com_uma - base} consultas sobre o caminho sem
      projeto, e o teto declarado é #{@teto_do_caminho_com_projeto}.

      Subir é decisão, e ela aparece neste arquivo.
      """

      # Agora com CINCO projetos e mais gente: o custo não pode acompanhar.
      for n <- 2..5, do: ligar(ctx, com_projeto, "Projeto #{n}")

      for i <- 1..5 do
        p = pessoa(ctx, "p058_#{i}")
        vincular(ctx, com_projeto, p)
      end

      com_cinco = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{com_projeto.id}") end))

      assert com_cinco == com_uma, """
      A página fez #{com_uma} consultas com 1 projeto e #{com_cinco} com 5 — ela consulta por
      projeto. `who_worked_on_many/3` e `project_repositories_with_period_many/2` existem
      exatamente para que esse número não se mexa.
      """
    end
  end

  defp ligar(ctx, equipe, nome_do_projeto) do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: nome_do_projeto}, ctx.admin.id)
    {:ok, _} = SPO.link_team(ctx.tenant, projeto.id, equipe.id, ctx.admin.id)
    {:ok, _} = SPO.link_repository(ctx.tenant, projeto.id, ctx.repo_id, ctx.admin.id)
    projeto
  end

  describe "a tela da equipe composta" do
    test "o custo cresce por subequipe, e o passo tem teto", ctx do
      mae = equipe(ctx, "Plataforma")

      duas =
        for n <- 1..2 do
          f = equipe(ctx, "Sub#{n}")
          {:ok, _} = EO.compose_teams(ctx.tenant, f.id, mae.id, ctx.admin.id)
          p = pessoa(ctx, "d#{n}")
          vincular(ctx, f, p)
          issue(ctx, "i#{n}", p, 10)
          f
        end

      com_duas = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{mae.id}") end))

      for n <- 3..6 do
        f = equipe(ctx, "Sub#{n}")
        {:ok, _} = EO.compose_teams(ctx.tenant, f.id, mae.id, ctx.admin.id)
        p = pessoa(ctx, "d#{n}")
        vincular(ctx, f, p)
        issue(ctx, "i#{n}", p, 10)
      end

      com_seis = por_render(contar(fn -> live(ctx.conn, ~p"/teams/#{mae.id}") end))
      passo = (com_seis - com_duas) / 4

      assert length(duas) == 2

      assert passo <= @teto_da_composta_por_subequipe, """
      Cada subequipe custa #{Float.round(passo, 1)} consultas por render, e o teto declarado é
      #{@teto_da_composta_por_subequipe}.

      Aqui o crescimento por linha é ESPERADO — a tela mede cada subequipe separadamente porque
      somar contaria a mesma pessoa duas vezes. O que não pode crescer é o custo POR subequipe.
      """
    end
  end
end
