defmodule TheBandWeb.WorkMarkTest do
  @moduledoc """
  A marca de trabalho na lista de repositórios (T005, T006, T007).

  ## O teste que mais importa é o da ordem de decisão

  Depois da migração, **todos** os repositórios observados têm `issues_collected_at` nulo,
  porque nenhuma coleta anterior registrou a data — e 41 deles têm issues dentro, um com
  2 514. Uma marca que decidisse pela data antes da contagem diria `no collection recorded`
  sobre esses 41: a plataforma afirmando que nunca olhou um repositório de que ela tem
  2 514 issues coletadas.

  Nenhum teste de unidade pega isso, porque cada peça funciona. A pergunta que pega é *o
  que a tela diz no dia da migração?*, e é o achado A1 da análise.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "os três estados" do
    test "com issues, a marca diz quantas", %{conn: conn, tenant: tenant, cenario: c} do
      n = WorkItems.count_collected(tenant, observed_repository_id: c.observed_repository_id)

      assert linha(conn, "theband") =~ "#{n} issues"
    end

    test "coletado e vazio diz que a coleta rodou", %{conn: conn, tenant: tenant, cenario: c} do
      vazio = repositorio(tenant, c, "vazio-coletado")
      {:ok, _} = CMPO.mark_issues_collected(tenant, vazio, DateTime.utc_now(:second))

      assert linha(conn, "vazio-coletado") =~ "collected, no issues"
    end

    test "nunca coletado diz que não se sabe", %{conn: conn, tenant: tenant, cenario: c} do
      repositorio(tenant, c, "nunca-coletado")

      assert linha(conn, "nunca-coletado") =~ "no collection recorded"
    end

    test "os textos de vazio e desconhecido são diferentes", %{
      conn: conn,
      tenant: tenant,
      cenario: c
    } do
      vazio = repositorio(tenant, c, "vazio-coletado")
      {:ok, _} = CMPO.mark_issues_collected(tenant, vazio, DateTime.utc_now(:second))
      repositorio(tenant, c, "nunca-coletado")

      texto_vazio = linha(conn, "vazio-coletado")
      texto_desconhecido = linha(conn, "nunca-coletado")

      refute marca_de(texto_vazio) == marca_de(texto_desconhecido), """
      A tela usa o mesmo texto para "coletado e vazio" e para "nunca coletado".

      Zero e desconhecido são fatos diferentes: um diz que a plataforma olhou e não achou,
      o outro diz que ela não olhou. Um texto só para os dois é ausência desenhada como
      quantidade, e é o defeito que esta feature existe para não ter — FR-005.
      """
    end
  end

  describe "a ordem de decisão é a contagem primeiro" do
    test "repositório com issues e sem data de coleta aparece com trabalho", %{
      conn: conn,
      tenant: tenant,
      cenario: c
    } do
      # É o estado real dos 135 repositórios logo depois da migração: issues dentro, e
      # nenhuma data — porque nenhuma coleta anterior a registrou.
      assert nil ==
               tenant
               |> CMPO.list_observed()
               |> Enum.find(&(&1.name == "theband"))
               |> Map.fetch!(:issues_collected_at),
             "o cenário precisa ter a data nula, senão o teste não mede a ordem"

      n = WorkItems.count_collected(tenant, observed_repository_id: c.observed_repository_id)
      linha = linha(conn, "theband")

      assert linha =~ "#{n} issues", """
      O repositório tem #{n} issues coletadas e a marca não disse que há trabalho.

      Se a tela decidiu pela data antes da contagem, ela está dizendo "no collection recorded"
      sobre um repositório de que a plataforma tem #{n} issues no banco. No dado real são
      41 repositórios nesse estado, um deles com 2514 issues — e a tela afirmaria não ter
      olhado nenhum deles.

      A ordem é: contagem > 0 decide primeiro; a data só decide quando a contagem é zero.
      É FR-005a.
      """

      refute linha =~ "no collection recorded"
    end
  end

  describe "sem cor, a distinção sobrevive" do
    test "os três estados se distinguem por forma e texto", %{
      conn: conn,
      tenant: tenant,
      cenario: c
    } do
      vazio = repositorio(tenant, c, "vazio-coletado")
      {:ok, _} = CMPO.mark_issues_collected(tenant, vazio, DateTime.utc_now(:second))
      repositorio(tenant, c, "nunca-coletado")

      formas =
        ["theband", "vazio-coletado", "nunca-coletado"]
        |> Enum.map(&forma_de(linha(conn, &1)))
        |> Enum.uniq()

      assert length(formas) == 3, """
      Os três estados não têm três formas distintas: #{inspect(formas)}.

      Cor não conta como canal — WCAG 1.4.1, e é regra do design system. Removida a cor,
      quem não a distingue precisa continuar vendo a diferença: preenchida, vazia,
      tracejada.
      """
    end
  end

  describe "o quarto texto" do
    test "houve trabalho e não há vigente", %{conn: conn, tenant: tenant, cenario: c} do
      # Um segundo à frente: a marca de ausência atinge o que foi observado **antes** de
      # `desde`, e a coluna tem granularidade de segundo. Com o instante atual, o cenário
      # gravado no mesmo segundo não seria marcado, e o teste passaria por não medir.
      depois = DateTime.add(DateTime.utc_now(:second), 1, :second)

      {:ok, marcadas} =
        WorkItems.mark_issues_no_longer_observed(tenant, c.observed_repository_id, depois)

      assert marcadas > 0

      {:ok, _} =
        CMPO.mark_issues_collected(tenant, c.observed_repository_id, DateTime.utc_now(:second))

      linha = linha(conn, "theband")

      assert linha =~ "no current work", """
      O repositório tinha #{marcadas} issues e todas foram marcadas como não mais
      observadas. A tela diz "collected, no issues", que afirma que nunca houve trabalho.

      Houve, e não está presente — são fatos diferentes, e é a mesma distinção que
      `no_longer_observed_at` carrega no banco.
      """

      refute linha =~ "collected, no issues"
    end
  end

  describe "a marca não substitui o link" do
    test "todo repositório continua clicável, inclusive os vazios", %{
      conn: conn,
      tenant: tenant,
      cenario: c
    } do
      repositorio(tenant, c, "nunca-coletado")
      vazio = repositorio(tenant, c, "vazio-coletado")
      {:ok, _} = CMPO.mark_issues_collected(tenant, vazio, DateTime.utc_now(:second))

      {:ok, _live, html} = live(conn, ~p"/work")

      for nome <- ["theband", "nunca-coletado", "vazio-coletado"] do
        assert linha(html, nome) =~ "/work/repositories/", """
        O repositório #{nome} não tem link.

        Os vazios precisam continuar clicáveis: a tela deles explica **por que** estão
        vazios, e é isso que alguém procura ao clicar num vazio — FR-007.
        """
      end
    end
  end

  describe "a coluna e a marca mostram o mesmo número" do
    test "não há contagem ao lado de marca vazia", %{conn: conn, tenant: tenant, cenario: c} do
      n = WorkItems.count_collected(tenant, observed_repository_id: c.observed_repository_id)
      vazio = repositorio(tenant, c, "vazio-coletado")
      {:ok, _} = CMPO.mark_issues_collected(tenant, vazio, DateTime.utc_now(:second))

      com_trabalho = linha(conn, "theband")
      sem_trabalho = linha(conn, "vazio-coletado")

      assert com_trabalho =~ "#{n} issues"
      assert com_trabalho =~ ~r/data-label="issues"[^>]*>\s*#{n}\s*</

      assert sem_trabalho =~ ~r/data-label="issues"[^>]*>\s*0\s*</, """
      A coluna de contagem e a marca discordam na mesma linha.

      Um número, dois consumidores — FR-010. Ver "2514 issues" ao lado de uma marca vazia
      faria quem lê não saber em qual acreditar.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp linha(%Plug.Conn{} = conn, nome) do
    {:ok, _live, html} = live(conn, ~p"/work")
    linha(html, nome)
  end

  defp linha(html, nome) when is_binary(html) do
    html
    |> then(&Regex.scan(~r{<tr>(?:(?!</tr>).)*?</tr>}s, &1))
    |> Enum.map(&hd/1)
    |> Enum.find(&(&1 =~ ~r/>\s*#{Regex.escape(nome)}\s*</))
    |> case do
      nil -> flunk("não achei a linha do repositório #{nome} na lista")
      linha -> linha
    end
  end

  # O texto da célula `work`, sem a forma: é o que alguém lê.
  defp marca_de(linha) do
    case Regex.run(~r{data-label="work".*?<span[^>]*>(.*?)</span>\s*</span>}s, linha) do
      [_, texto] -> texto |> String.replace(~r/<[^>]+>/, "") |> String.trim()
      nil -> flunk("a linha não tem a célula da marca")
    end
  end

  # As classes da forma, com a cor removida: o que sobra é o que distingue os estados para
  # quem não vê cor. Se os três estados dependessem de cor, os três resultados seriam iguais.
  defp forma_de(linha) do
    [_, celula] = Regex.run(~r{data-label="work"(.*?)</td>}s, linha)
    [_, classes] = Regex.run(~r{class="([^"]*size-2\.5[^"]*)"}, celula)

    classes
    |> String.split()
    |> Enum.reject(&String.starts_with?(&1, ["text-", "bg-current"]))
    |> Enum.sort()
  end

  defp repositorio(tenant, cenario, nome) do
    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: cenario.organization.id,
        name: nome,
        qualified_name: "The-Band-Solution/#{nome}",
        url: "https://github.com/The-Band-Solution/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{nome}"
      })

    {:ok, observado} = CMPO.observe_repository(tenant, cenario.tool.id, repo.id)
    observado.id
  end
end
