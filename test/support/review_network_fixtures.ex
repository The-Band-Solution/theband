defmodule TheBand.ReviewNetworkFixtures do
  @moduledoc """
  O dado mínimo da rede de revisão — feature 073: uma organização observada com um repositório
  observado, pessoas de EO, solicitações e avaliações coletadas.

  Mais leve que `WorkItemsFixtures.cenario_real/2`, que monta os seis casos de issue que a rede não
  lê. Grava pelas APIs de coleta de cada dono (`CMPO`, `EO`, `Changes.Commands`,
  `Quality.Commands`), como a coleta real grava.
  """

  import TheBand.DataCase, only: [organization_fixture: 2, source_attrs: 2]
  import TheBand.WorkItemsFixtures, only: [ferramenta: 2]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Quality.Commands, as: QualityCommands

  @doc "Uma organização observada e um repositório observado dela."
  def organizacao_com_repositorio(tenant, login \\ nil) do
    login = login || "org-#{System.unique_integer([:positive])}"
    organization = organization_fixture(tenant, login)
    tool = ferramenta(tenant, login)
    observed_repository_id = repositorio(tenant, organization, tool, "repo")

    %{organization: organization, tool: tool, observed_repository_id: observed_repository_id}
  end

  @doc "Mais um repositório observado da mesma organização."
  def repositorio(tenant, organization, tool, nome) do
    externo = "R_#{nome}_#{System.unique_integer([:positive])}"

    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: organization.id,
        name: nome,
        qualified_name: "#{organization.login}/#{nome}",
        url: "https://github.com/#{organization.login}/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: externo
      })

    {:ok, observado} = CMPO.observe_repository(tenant, tool.id, repo.id)
    observado.id
  end

  @doc "Uma pessoa observada, com o tipo de conta dado."
  def pessoa(tenant, nome, account_type \\ "person") do
    login = "#{String.downcase(nome)}-#{System.unique_integer([:positive])}"

    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_#{login}", %{name: nome, login: login, account_type: account_type})
      )

    p
  end

  @doc """
  Uma solicitação de mudança aberta por `autor`: uma pessoa de EO, `{:login, login}` (conta sem
  pessoa ligada) ou `nil` (conta apagada na origem).
  """
  def solicitacao(tenant, observed_repository_id, autor, aberta_em) do
    numero = System.unique_integer([:positive])

    {login, person_id} =
      case autor do
        nil -> {nil, nil}
        {:login, login} -> {login, nil}
        %{id: id, login: login} -> {login, id}
      end

    {:ok, cr} =
      ChangeCommands.record_change_request(tenant, %{
        observed_repository_id: observed_repository_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "OPEN",
        external_created_at: aberta_em,
        author_login: login,
        author_person_id: person_id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    cr
  end

  @doc """
  Uma avaliação de `revisor` sobre `cr`. `revisor` é uma pessoa de EO (`__typename` `User`),
  `{:login, login, typename}` (conta sem pessoa ligada) ou `nil` (conta apagada).
  """
  def revisao(tenant, cr, revisor, enviada_em, attrs \\ %{}) do
    {login, tipo, person_id} =
      case revisor do
        nil -> {nil, nil, nil}
        {:login, login, tipo} -> {login, tipo, nil}
        %{id: id, login: login} -> {login, "User", id}
      end

    {:ok, a} =
      QualityCommands.record_evaluation(
        tenant,
        Map.merge(
          %{
            collected_change_request_id: cr.id,
            state: "APPROVED",
            author_login: login,
            author_type: tipo,
            author_person_id: person_id,
            external_submitted_at: enviada_em,
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "PRR_#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )

    a
  end
end
