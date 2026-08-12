defmodule TheBandWeb.IssueParentTest do
  @moduledoc """
  A coluna `part of` na lista de issues do repositório (T003 a T009).

  ## O teste que mais importa é um `refute`

  `Axioms.rule07/2` trata "tarefa sem pai" como violação, e chamá-lo com o pai ausente é o caminho
  óbvio. Seriam **2 091 das 2 899** células com aviso, afogando as **293** que são o caso
  interessante — e a suíte passaria, porque cada peça funciona.

  A pergunta que pega é *o que a célula diz numa tarefa sem pai?*, e é o R6 da pesquisa.

  ## E o segundo é o do conceito do pai

  Os textos da relação — `attends`, `composes` — não dizem **o que** o pai é. Sem o conceito, os 12
  vínculos cujo pai é defeito ficam sem nome, que é exatamente a redução que o pedido original
  fazia. A análise achou isso: FR-003 não tinha tarefa nenhuma.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.DecompositionLink

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "o pai na linha" do
    test "a issue com pai mostra número, título e conceito dele", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]

      celula = celula_de(ctx, parte.number)

      assert celula =~ "##{pai.number}"
      assert celula =~ "issue ##{pai.number}"
      # FR-003: o conceito, e não "US ou épico".
      assert celula =~ "atomic user story"
    end

    test "a issue sem pai diz isso em texto, e a célula não fica vazia", ctx do
      %{pai: pai} = ctx.cenario.issues[200]

      assert celula_de(ctx, pai.number) =~ "not part of anything"
    end

    test "o pai é navegável", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]

      assert celula_de(ctx, parte.number) =~ ~s(href="/work/issues/#{pai.id}")
    end
  end

  describe "qual relação é" do
    test "atendimento e composição têm textos diferentes na mesma lista", ctx do
      # A parte `Task` do épico #1 **atende**; a parte `Feature` dele **compõe**.
      %{partes: partes} = ctx.cenario.issues[1]
      tarefa = Enum.find(partes, &(&1.issue_type == "Task"))
      historia = Enum.find(partes, &(&1.issue_type == "Feature"))

      assert celula_de(ctx, tarefa.number) =~ "violates sro.rule07"
      assert celula_de(ctx, historia.number) =~ "composes"
      refute celula_de(ctx, historia.number) =~ "violates"
    end

    test "tarefa sob user story atende, e não avisa nada", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]

      celula = celula_de(ctx, parte.number)

      assert celula =~ "attends"
      refute celula =~ "violates sro.rule07"
    end

    test "tarefa sob épico diz que viola, e o texto é diferente do de atendimento", ctx do
      %{partes: partes} = ctx.cenario.issues[1]
      tarefa = Enum.find(partes, &(&1.issue_type == "Task"))
      %{partes: [sob_historia | _]} = ctx.cenario.issues[3]

      viola = celula_de(ctx, tarefa.number)
      em_ordem = celula_de(ctx, sob_historia.number)

      assert viola =~ "violates sro.rule07"
      refute em_ordem =~ "violates sro.rule07"
      refute texto(viola) == texto(em_ordem)
    end

    test "a tarefa SEM pai não recebe aviso na célula, e o painel continua na tela", ctx do
      %{pai: solta} = ctx.cenario.issues[201]

      celula = celula_de(ctx, solta.number)

      # O caso que a medida achou: 2 091 tarefas sem pai, e o axioma as trata como violação.
      assert celula =~ "not part of anything"
      refute celula =~ "sro.rule07"

      {:ok, _live, html} = abrir(ctx)
      assert html =~ "Tasks with no user story"
    end
  end

  describe "o que a ontologia não nomeia" do
    test "filha promovida a defeito não é composição nem atendimento", ctx do
      %{pai: pai} = ctx.cenario.issues[3]
      defeito = defeito_sob(ctx, pai)

      celula = celula_de(ctx, defeito.number)

      assert celula =~ "the ontology network does not name this relation"
      refute celula =~ "composes"
      refute celula =~ "attends"
    end
  end

  describe "mais de um pai" do
    test "os dois aparecem, e a tela diz que há mais de um", ctx do
      %{pai: um, partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      celula = celula_de(ctx, parte.number)

      assert celula =~ "2 parents at the source"
      assert celula =~ "##{um.number}"
      assert celula =~ "##{outro.number}"
    end

    test "a mesma página desenhada duas vezes mostra a mesma coisa", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      assert celula_de(ctx, parte.number) == celula_de(ctx, parte.number)
    end

    test "um pai vigente e um vínculo que acabou é UM pai, não dois", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      ausentar(outro.id, parte.id, ~U[2026-08-01 00:00:00Z])

      refute celula_de(ctx, parte.number) =~ "parents at the source"
    end
  end

  describe "o repositório do pai" do
    test "pai em outro repositório vem com o nome dele", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      {outro_id, nome} = outro_repositorio(ctx)
      fora = issue_em(ctx, outro_id, 9001)

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: fora.id,
          child_issue_id: parte.id
        })

      assert celula_de(ctx, parte.number) =~ nome
    end

    test "pai no mesmo repositório não repete o nome", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]

      refute celula_de(ctx, parte.number) =~ "The-Band-Solution/theband"
    end
  end

  describe "o vínculo ausente" do
    test "aparece com a data, e não como atual", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      ausentar(pai.id, parte.id, ~U[2026-08-01 00:00:00Z])

      celula = celula_de(ctx, parte.number)

      assert celula =~ "no longer observed since 01 Aug 2026"
      assert celula =~ "border-dashed"
      assert celula =~ "absent: this link existed and is not present now"
    end
  end

  describe "o pai sem conceito" do
    test "é dito como sem conceito, e nenhum é inventado", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      sem_promocao = issue_em(ctx, ctx.cenario.observed_repository_id, 9100)

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: sem_promocao.id,
          child_issue_id: parte.id
        })

      celula = celula_de(ctx, parte.number)

      assert celula =~ "the parent has no concept"
      refute celula =~ "not part of anything"
    end
  end

  describe "a cor removida" do
    test "os casos continuam distinguíveis por texto", ctx do
      %{partes: partes} = ctx.cenario.issues[1]
      tarefa = Enum.find(partes, &(&1.issue_type == "Task"))
      historia = Enum.find(partes, &(&1.issue_type == "Feature"))
      %{pai: solta} = ctx.cenario.issues[201]

      textos =
        [tarefa.number, historia.number, solta.number]
        |> Enum.map(&texto(celula_de(ctx, &1)))

      assert length(Enum.uniq(textos)) == 3
    end
  end

  describe "o custo do render" do
    test "doze consultas por render, e o número não cresce com o dado", ctx do
      # **A constância é a asserção que mais importa**, e ela precisa de duas páginas **diferentes**:
      # comparar a mesma página com ela mesma daria igualdade sempre, e o teste passaria sem medir
      # nada. Duas issues com vínculo contra cinquenta.
      pequeno = repositorio_com_dois_vinculos(ctx)

      poucas =
        por_render(contar_consultas(fn -> live(ctx.conn, ~p"/work/repositories/#{pequeno}") end))

      muitas = por_render(contar_consultas(fn -> abrir(ctx) end))

      assert poucas == muitas, """
      A página fez #{poucas} consultas com 2 issues e #{muitas} com 50 — ela consulta por linha, que
      é o defeito que a feature 007 pagou com 135 por render.
      """

      # **Doze, e o número está escrito aqui de propósito.** Medido em 2026-08-12: a mesma página
      # **antes** desta coluna fazia **dez** por render, contra `main`. As duas acrescentadas são uma
      # por fronteira — `list_parents/2` em WorkItems, e `list_observed/2` em CMPO, cujo mapa resolve
      # o nome do repositório do pai.
      #
      # "Um número que não cresce" passa com 12 e passa com 120: por isso o teto é asserido.
      assert muitas == 12, """
      A página faz #{muitas} consultas por render, e o plano declara **doze** — dez que ela já fazia
      mais duas da coluna. Um número diferente significa consulta nova sem decisão registrada.
      """
    end
  end

  describe "o escopo do tenant" do
    test "repositório de outro tenant devolve não encontrado", ctx do
      {outro_tenant, outro_user} = tenant_with_admin()
      _ = cenario_real(outro_tenant, "Outra-Org")

      conn = log_in(build_conn(), outro_user)

      assert {:error, {:live_redirect, %{to: "/work", flash: flash}}} =
               live(conn, ~p"/work/repositories/#{ctx.cenario.observed_repository_id}")

      assert flash["error"] =~ "not found"
      refute flash["error"] =~ "permission"
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp abrir(ctx),
    do: live(ctx.conn, ~p"/work/repositories/#{ctx.cenario.observed_repository_id}")

  # A célula `part of` da linha daquela issue. O recorte por linha importa: sem ele um `assert` no
  # HTML inteiro passaria por causa de outra linha da tabela.
  defp celula_de(ctx, numero) do
    {:ok, _live, html} = abrir(ctx)

    linha =
      html
      |> then(&Regex.scan(~r{<tr>(?:(?!</tr>).)*?</tr>}s, &1))
      |> Enum.map(&hd/1)
      |> Enum.find(&(&1 =~ ~r{data-label="\#"[^>]*>\s*#{numero}\s*<}))

    case linha && Regex.run(~r{data-label="part of"(.*?)</td>}s, linha) do
      [_, celula] -> celula
      _ -> flunk("não achei a célula `part of` da issue ##{numero}")
    end
  end

  defp texto(celula), do: celula |> String.replace(~r/<[^>]+>/, " ") |> normalizar()

  defp normalizar(s), do: s |> String.replace(~r/\s+/, " ") |> String.trim()

  defp ausentar(pai_id, filha_id, quando) do
    Repo.update_all(
      from(l in DecompositionLink,
        where: l.parent_issue_id == ^pai_id and l.child_issue_id == ^filha_id
      ),
      set: [no_longer_observed_at: quando]
    )
  end

  # O número é **baixo** de propósito: a página mostra 50 issues ordenadas por número, e um 9200
  # cairia na segunda página — o teste falharia por paginação, não por defeito.
  defp defeito_sob(ctx, pai) do
    defeito = issue_em(ctx, ctx.cenario.observed_repository_id, 6, "Bug")

    {:ok, _} =
      WorkItems.record_promotion(ctx.tenant, %{
        collected_issue_id: defeito.id,
        declared_concept: "osdef.defect",
        derived_concept: "osdef.defect",
        rule_id: "github.issue_type_routing",
        rule_version: 1
      })

    {:ok, _} =
      WorkItems.record_decomposition_link(ctx.tenant, %{
        parent_issue_id: pai.id,
        child_issue_id: defeito.id
      })

    defeito
  end

  defp issue_em(ctx, observado_id, numero, tipo \\ "Task") do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: observado_id,
        number: numero,
        title: "issue ##{numero}",
        state: "OPEN",
        issue_type: tipo,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{numero}"
      })

    issue
  end

  defp outro_repositorio(ctx) do
    nome = "outro-repo"
    {:ok, repo} = repo_fixture(ctx, nome)
    {:ok, observado} = CMPO.observe_repository(ctx.tenant, ctx.cenario.tool.id, repo.id)
    {observado.id, "The-Band-Solution/#{nome}"}
  end

  defp repositorio_vazio(ctx, nome) do
    {:ok, repo} = repo_fixture(ctx, nome)
    {:ok, observado} = CMPO.observe_repository(ctx.tenant, ctx.cenario.tool.id, repo.id)
    observado.id
  end

  # `live/2` faz **dois** renders — mount desconectado e conectado —, e a contagem bruta vem
  # dobrada. Dividir é o que a feature 010 já faz, e esquecer isso mediria 24 e reprovaria sem
  # defeito nenhum.
  defp por_render(total), do: div(total, 2)

  # Um repositório com duas issues e um vínculo entre elas: a coluna tem trabalho, e é pouco.
  defp repositorio_com_dois_vinculos(ctx) do
    observado = repositorio_vazio(ctx, "dois-vinculos")
    pai = issue_em(ctx, observado, 1, "Feature")
    filha = issue_em(ctx, observado, 2, "Task")

    {:ok, _} =
      WorkItems.record_decomposition_link(ctx.tenant, %{
        parent_issue_id: pai.id,
        child_issue_id: filha.id
      })

    observado
  end

  defp repo_fixture(ctx, nome) do
    CMPO.upsert_source_repository_from_source(ctx.tenant, %{
      organization_id: ctx.cenario.organization.id,
      name: nome,
      qualified_name: "The-Band-Solution/#{nome}",
      url: "https://github.com/The-Band-Solution/#{nome}",
      default_branch: "main",
      source_system: "github",
      source_instance: "https://github.com",
      external_id: "R_#{nome}"
    })
  end

  # **Esvaziar a caixa antes de anexar.** Sem isso, mensagem atrasada da medição anterior entra na
  # contagem desta — e foi exatamente o que produziu um 22 onde a página faz 20, durante a medição
  # do baseline. Número que muda entre execuções não mede nada.
  defp contar_consultas(fun) do
    ref = make_ref()
    pai = self()
    esvaziar()

    handler = fn _evento, _medidas, %{query: query}, _config ->
      if String.starts_with?(query, "SELECT"), do: send(pai, {ref, :consulta})
    end

    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], handler, nil)
    {:ok, _live, _html} = fun.()
    :telemetry.detach({__MODULE__, ref})

    contar(ref, 0)
  end

  defp contar(ref, total) do
    receive do
      {^ref, :consulta} -> contar(ref, total + 1)
    after
      0 -> total
    end
  end

  defp esvaziar do
    receive do
      _qualquer -> esvaziar()
    after
      0 -> :ok
    end
  end
end
