defmodule TheBand.WorkItems.RotulosNaListagemTest do
  @moduledoc """
  Os rótulos na listagem de itens de trabalho — spec 065, T002, T003 e T004.

  Três coisas são medidas aqui, e a segunda e a terceira são as que dão sentido à primeira:

    1. os rótulos chegam à listagem, na mesma ordem a cada leitura;
    2. o **custo não cresce** com o número de itens — uma listagem de 100 custa o mesmo
       número de consultas que uma de 10. Contar consultas, e não medir tempo: tempo varia
       com a máquina e esconde o 1+N atrás de um banco rápido;
    3. o rótulo **não vira conceito**. É a regra que este campo pode quebrar — um campo de
       rótulo ao lado do conceito é exatamente a situação em que alguém, meses depois,
       "melhora" a classificação lendo o rótulo.
  """

  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    %{tenant: tenant, cenario: cenario_real(tenant)}
  end

  defp rotulos_de(tenant, issue_id) do
    tenant
    |> WorkItems.list_issues(limit: 500)
    |> Enum.find(&(&1.id == issue_id))
    |> Map.get(:rotulos_do_campo)
  end

  describe "os rótulos chegam à listagem" do
    test "os nomes aparecem no item certo", %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      {:ok, 2} =
        WorkItems.replace_labels(tenant, issue.id, [
          %{name: "prioridade:alta", color: "d73a4a"},
          %{name: "backend", color: "0e8a16"}
        ])

      assert rotulos_de(tenant, issue.id) == ["backend", "prioridade:alta"]
    end

    test "item sem rótulo devolve nulo, e a tela é quem escreve a ausência",
         %{tenant: tenant, cenario: c} do
      # `array_agg` sobre conjunto vazio devolve NULL, não lista vazia. A consulta NÃO
      # disfarça isso: quem escreve a ausência em palavras é a tela (FR-010), e converter
      # aqui esconderia de quem lê a consulta que o caso existe.
      assert rotulos_de(tenant, c.issues[1].pai.id) == nil
    end

    test "a ordem é a mesma a cada leitura", %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      {:ok, 3} =
        WorkItems.replace_labels(tenant, issue.id, [
          %{name: "zeta", color: "111111"},
          %{name: "alfa", color: "222222"},
          %{name: "meio", color: "333333"}
        ])

      assert rotulos_de(tenant, issue.id) == ["alfa", "meio", "zeta"]
      assert rotulos_de(tenant, issue.id) == ["alfa", "meio", "zeta"]
    end

    test "rótulo que a origem deixou de mostrar sai do campo", %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      {:ok, 2} =
        WorkItems.replace_labels(tenant, issue.id, [
          %{name: "fica", color: "111111"},
          %{name: "sai", color: "222222"}
        ])

      {:ok, 1} = WorkItems.replace_labels(tenant, issue.id, [%{name: "fica", color: "111111"}])

      assert rotulos_de(tenant, issue.id) == ["fica"]
    end
  end

  describe "o custo não cresce com o número de itens (T003)" do
    @tag :custo
    test "uma listagem de 100 custa o mesmo que uma de 10", %{tenant: tenant} do
      dez = conta_consultas(fn -> WorkItems.list_issues(tenant, limit: 10) end)
      cem = conta_consultas(fn -> WorkItems.list_issues(tenant, limit: 100) end)

      assert dez == cem, """
      A listagem passou a custar por linha.

      10 itens: #{dez} consultas · 100 itens: #{cem} consultas

      É a L38. Trocar a junção lateral agregada por `Repo.preload` produz exatamente este
      resultado — e é assim que a reinjeção deste teste se faz.
      """

      # O número em si, para que uma regressão silenciosa apareça: se alguém acrescentar
      # uma consulta por listagem, este número muda e o teste diz qual era.
      assert cem == 1, "a listagem passou a fazer #{cem} consultas; era 1"
    end

    # O QUE ESTE TESTE NÃO PEGA, medido em 2026-09-13 ao reinjetar dois defeitos.
    #
    # Ele conta consultas **do Ecto**, e há uma forma de custo por linha que não é uma
    # consulta do Ecto: a **subconsulta correlacionada** no `select`. Troquei a junção
    # lateral por `fragment("(select array_agg(...) where collected_issue_id = ?)", i.id)`
    # e os sete testes continuaram verdes — porque continua sendo **uma** instrução SQL,
    # ainda que o banco a execute uma vez por linha.
    #
    # A forma que ele PEGA é a que mais aparece na prática: uma consulta separada por item,
    # com `Repo.all` dentro de um `Enum.map`. Reinjetada, derruba quatro dos sete.
    #
    # Fica escrito porque um teste de custo que não diz o que não mede convida a confiar
    # nele mais do que ele merece. Quem trocar esta consulta por uma correlacionada precisa
    # saber que este arquivo não vai reclamar.
  end

  describe "o rótulo NÃO vira conceito (T004)" do
    test "rótulo `bug` não muda o conceito derivado", %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      antes = conceito_de(tenant, issue.id)

      {:ok, 1} = WorkItems.replace_labels(tenant, issue.id, [%{name: "bug", color: "d73a4a"}])

      depois = conceito_de(tenant, issue.id)

      # `Commands.replace_labels/3`, por escrito: "o rótulo é preservado e não promovido —
      # um rótulo `bug` não faz a issue um defeito". A ontologia decide por `issueType` e
      # pela estrutura de sub-issues; o rótulo é declaração do time, e fica ao lado.
      assert depois == antes

      refute depois == "osdef.defect",
             "o conceito passou a seguir o rótulo — é exatamente o que a regra proíbe"
    end

    test "os dois chegam juntos, e dá para ver que divergem", %{tenant: tenant, cenario: c} do
      issue = c.issues[1].pai

      {:ok, 1} = WorkItems.replace_labels(tenant, issue.id, [%{name: "task", color: "0e8a16"}])

      linha =
        tenant |> WorkItems.list_issues(limit: 500) |> Enum.find(&(&1.id == issue.id))

      # Quem lê consegue dizer as duas coisas: o time chamou de `task`, e a ontologia
      # derivou outra. A divergência é informação, e some se um dos lados não chega.
      assert "task" in linha.rotulos_do_campo
      assert linha.derived_concept
    end
  end

  defp conceito_de(tenant, issue_id) do
    tenant
    |> WorkItems.list_issues(limit: 500)
    |> Enum.find(&(&1.id == issue_id))
    |> Map.get(:derived_concept)
  end

  # Conta as consultas que `fun` dispara, por telemetria do Ecto — e não por tempo. Tempo
  # varia com a máquina e esconde o 1+N atrás de um banco rápido.
  defp conta_consultas(fun) do
    referencia = make_ref()
    pai = self()

    :telemetry.attach(
      "conta-#{inspect(referencia)}",
      [:the_band, :repo, :query],
      fn _evento, _medidas, _meta, _cfg -> send(pai, {referencia, :consulta}) end,
      nil
    )

    fun.()
    :telemetry.detach("conta-#{inspect(referencia)}")

    drenar(referencia, 0)
  end

  defp drenar(referencia, total) do
    receive do
      {^referencia, :consulta} -> drenar(referencia, total + 1)
    after
      0 -> total
    end
  end
end
