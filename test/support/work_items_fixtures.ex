defmodule TheBand.WorkItemsFixtures do
  @moduledoc """
  Cenário de issues com a **forma do dado real**, medida pela API em 2026-08-11.

  Não é dado sintético conveniente: é o que a organização `The-Band-Solution` tem no
  repositório `theband`, e inclui os casos que a regra de roteamento avisa serem os mais
  fáceis de errar — três `Feature` com sub-issues que **não** são épicos, porque as
  partes são tarefas.

  Um cenário inventado teria épicos com partes que são user stories e nada mais, e a
  suíte passaria sem exercitar a distinção entre composição e atendimento.
  """

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential
  alias TheBand.WorkItems

  import TheBand.DataCase, only: [organization_fixture: 2]

  @doc """
  Monta ferramenta, organização, um repositório e as issues dos seis casos reais.

  Devolve o que os testes precisam para consultar sem alcançar schemas privados.
  """
  def cenario_real(tenant, login \\ "The-Band-Solution") do
    organization = organization_fixture(tenant, login)
    tool = ferramenta(tenant, login)

    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: organization.id,
        name: "theband",
        qualified_name: "#{login}/theband",
        url: "https://github.com/#{login}/theband",
        description: "Semantic data integration platform",
        primary_language: "Elixir",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_theband"
      })

    {:ok, observado} = CMPO.observe_repository(tenant, tool.id, repo.id)

    issues = Map.new(casos(), fn caso -> {caso.number, gravar(tenant, observado.id, caso)} end)
    vincular(tenant, issues)
    promover(tenant, issues)

    %{
      tenant: tenant,
      tool: tool,
      organization: organization,
      repo: repo,
      observed_repository_id: observado.id,
      issues: issues
    }
  end

  # Os seis casos estruturais, com os números reais. As partes são criadas junto, porque
  # é o tipo delas que decide épico contra atômica.
  defp casos do
    [
      %{
        number: 1,
        tipo: "Feature",
        partes: List.duplicate("Task", 30) ++ List.duplicate("Feature", 9)
      },
      %{number: 3, tipo: "Feature", partes: List.duplicate("Task", 9)},
      %{number: 4, tipo: "Feature", partes: List.duplicate("Task", 20)},
      %{number: 5, tipo: "Feature", partes: List.duplicate("Task", 8)},
      %{number: 79, tipo: "Feature", partes: ["Feature", "Task", "Task"]},
      %{number: 98, tipo: "Feature", partes: ["Feature", "Feature"]},
      %{number: 200, tipo: "Bug", partes: []},
      %{number: 201, tipo: "Task", partes: []},
      # Uma issue de tipo próprio da organização, que nenhuma rota reconhece. Existe
      # para a lacuna aparecer com o nome — sem ela, a tela mostraria zero lacunas e o
      # caminho não seria exercitado.
      %{number: 202, tipo: "Spike", partes: []},
      # E uma sem tipo, que é o outro motivo de lacuna.
      %{number: 203, tipo: nil, partes: []}
    ]
  end

  defp gravar(tenant, observado_id, caso) do
    {:ok, pai} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: observado_id,
        number: caso.number,
        title: "issue ##{caso.number}",
        state: "OPEN",
        issue_type: caso.tipo,
        issue_type_external_id: caso.tipo && "IT_#{caso.tipo}",
        sub_issue_count: length(caso.partes),
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{caso.number}"
      })

    partes =
      caso.partes
      |> Enum.with_index(1)
      |> Enum.map(fn {tipo, i} ->
        numero = caso.number * 1000 + i

        {:ok, parte} =
          WorkItems.record_collected_issue(tenant, %{
            observed_repository_id: observado_id,
            number: numero,
            title: "parte #{numero} de ##{caso.number}",
            state: "OPEN",
            issue_type: tipo,
            issue_type_external_id: "IT_#{tipo}",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "I_#{numero}"
          })

        parte
      end)

    %{pai: pai, partes: partes}
  end

  defp vincular(tenant, issues) do
    for {_numero, %{pai: pai, partes: partes}} <- issues, parte <- partes do
      WorkItems.record_decomposition_link(tenant, %{
        parent_issue_id: pai.id,
        child_issue_id: parte.id
      })
    end
  end

  # A promoção vem **depois** dos vínculos, e é a ordem que importa: classificar antes
  # de conhecer as partes daria atômica para tudo.
  defp promover(tenant, issues) do
    tipos =
      Map.new(issues, fn {_n, %{pai: pai, partes: partes}} ->
        {pai.id, Enum.map(partes, & &1.issue_type)}
      end)

    todas =
      Enum.flat_map(issues, fn {_n, %{pai: pai, partes: partes}} -> [pai | partes] end)

    for issue <- todas do
      decisao =
        WorkItems.decide(
          %{issue_type: issue.issue_type, sub_issue_types: Map.get(tipos, issue.id, [])},
          tenant_rule_id: "github.issue_type_routing.the_band_solution"
        )

      WorkItems.record_promotion(tenant, %{
        collected_issue_id: issue.id,
        declared_concept: decisao.declared,
        derived_concept: decisao.derived,
        divergence_reason: decisao.divergence,
        skip_reason: decisao.skip_reason,
        skip_detail: decisao.skip_detail,
        rule_id: decisao.rule_id,
        rule_version: decisao.rule_version
      })
    end
  end

  @doc """
  Uma ferramenta conectada com credencial, sem repositório nem issue.

  Pública porque o cenário de quadro (issue #514) precisa da ferramenta e de mais nada:
  montar os seis casos de issue só para ter um `connected_tool_id` amarraria o teste de
  papel de campo a dados que ele não lê.
  """
  def ferramenta(tenant, login \\ "The-Band-Solution") do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> TheBand.Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "principal",
        secret: "ghp_cenario",
        last_four: "ario",
        scopes: ["read:org"],
        validated_at: DateTime.utc_now(:second)
      })
      |> TheBand.Repo.insert()

    Sources.fetch_connected_tool(tenant, tool.id) |> then(fn {:ok, t} -> t end)
  end
end
