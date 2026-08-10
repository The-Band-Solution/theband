defmodule TheBand.Ontology.SEON.EO.Constraints do
  @moduledoc """
  Invariantes semânticas de EO.

  Cada uma deriva de uma limitação **declarada na base de conhecimento** — não
  são invenção do código. Estão aqui, e não espalhadas pelos comandos, para que
  a revisão semântica encontre todas num lugar só.
  """

  alias TheBand.Ontology.SEON.EO.Schemas.Team
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence

  @platform_access_levels ~w(MAINTAINER MEMBER)

  @doc """
  Nível de acesso na plataforma **não** é papel organizacional.

  Origem: regra `github.team_membership_evidence`. `MAINTAINER` e `MEMBER` dizem
  quem pode gerir membros e permissões do time; não dizem se a pessoa é
  programadora, testadora, designer ou gerente. Promovê-los a papel produziria um
  catálogo que não corresponde a função nenhuma, e faria CQ12, CQ14 e CQ16
  devolverem resposta falsa em vez de nenhuma.
  """
  @spec platform_access_level_is_not_a_role(String.t()) :: :ok | {:error, String.t()}
  def platform_access_level_is_not_a_role(value) when value in @platform_access_levels, do: :ok

  def platform_access_level_is_not_a_role(value) do
    {:error,
     "#{inspect(value)} não é nível de acesso conhecido na origem. " <>
       "Só MAINTAINER e MEMBER existem, e nenhum dos dois é papel organizacional."}
  end

  @doc """
  Alocação em equipe exige papel.

  Origem: `eo.team_membership` é o relator de três termos — pessoa, equipe e
  papel. Uma alocação sem papel não responde nenhuma das perguntas que a alocação
  existe para responder, e gravá-la com papel nulo espalharia por toda consulta
  de papel o tratamento do caso nulo.
  """
  @spec membership_requires_role(map()) :: :ok | {:error, String.t()}
  def membership_requires_role(%{organizational_role_id: id}) when not is_nil(id), do: :ok

  def membership_requires_role(_) do
    {:error,
     "eo.team_membership sem papel organizacional. O GitHub fornece pessoa e equipe, " <>
       "e não o papel — o vínculo fica como evidência em eo_team_membership_evidence."}
  end

  @doc """
  Equipe vinda do GitHub é organizacional.

  Origem: mapeamento `github.team.to.eo.organizational_team`. Time do GitHub é
  agrupamento de permissão de acesso; que seus membros trabalhem juntos num
  projeto é suposição. A promoção a `project_team` exige vínculo efetivo com
  repositório ou projeto, ou declaração do tenant — nome coincidente não basta.
  """
  @spec github_team_is_organizational(map()) :: :ok | {:error, String.t()}
  def github_team_is_organizational(%{type: "project_team", granted_repositories: []}) do
    {:error,
     "equipe marcada como project_team sem nenhum repositório ou projeto vinculado. " <>
       "Na ausência de vínculo, a equipe é organizacional."}
  end

  def github_team_is_organizational(_), do: :ok

  @doc """
  Conta de automação não conta como pessoa.

  Origem: mapeamento `github.user.to.eo.person`, limitação 1. Bots e apps são
  registrados e classificados separadamente — descartá-los perderia o vínculo com
  a equipe onde aparecem, mas contá-los como pessoas inflaria o quadro.
  """
  @spec countable_as_person?(map()) :: boolean()
  def countable_as_person?(%{account_type: "person"}), do: true
  def countable_as_person?(_), do: false

  @doc """
  Identidade não se unifica por heurística.

  Origem: mapeamento `github.user.to.eo.person`, limitação 2. Duas contas da
  mesma pessoa são duas linhas em `eo_people`. A unificação exige regra
  explícita, nunca semelhança de nome ou e-mail — e está fora do escopo da
  feature 001.
  """
  @spec identity_reconciliation_allowed?() :: false
  def identity_reconciliation_allowed?, do: false

  @doc """
  Aplica as invariantes que valem sobre um vínculo observado.

  Aceita tanto os atributos crus vindos da transformação quanto o registro já
  persistido — o struct casa com o mesmo padrão de mapa.
  """
  @spec check_evidence(map() | TeamMembershipEvidence.t()) :: :ok | {:error, String.t()}
  def check_evidence(%{platform_access_level: level}),
    do: platform_access_level_is_not_a_role(level)

  @doc "Aplica as invariantes que valem sobre uma equipe."
  @spec check_team(map() | Team.t()) :: :ok | {:error, String.t()}
  def check_team(team), do: github_team_is_organizational(Map.new(team_attrs(team)))

  defp team_attrs(%Team{type: type}), do: [type: type, granted_repositories: []]
  defp team_attrs(map) when is_map(map), do: Map.to_list(map)

  @doc """
  Equipe derivada nunca se apresenta como observada (T022, FR-005).

  Origem: contrato `derived-team.md`, seção Garantias. A equipe derivada não existe na
  ferramenta de origem, e afirmar que existe é o único jeito de esta feature produzir
  dado falso — quem comparasse o número da plataforma com o do GitHub encontraria uma
  equipe a mais sem explicação.

  A invariante olha as duas direções, porque as duas são mentiras diferentes:
  identificador de derivação com proveniência do GitHub, e proveniência da plataforma
  sem identificador de derivação.
  """
  @spec derived_team_declares_itself(map()) :: :ok | {:error, String.t()}
  def derived_team_declares_itself(%{external_id: external_id, source_system: source})
      when is_binary(external_id) do
    derivada_pelo_id? = String.starts_with?(external_id, "derived:default_team:")
    derivada_pela_origem? = source == "the_band"

    cond do
      derivada_pelo_id? and not derivada_pela_origem? ->
        {:error,
         "equipe com identificador de derivação e proveniência '#{source}': " <>
           "seria uma equipe derivada se apresentando como observada na origem."}

      derivada_pela_origem? and not derivada_pelo_id? ->
        {:error,
         "equipe com proveniência da plataforma e sem identificador de derivação: " <>
           "a plataforma só produz equipe pela regra github.default_team."}

      true ->
        :ok
    end
  end

  def derived_team_declares_itself(_), do: :ok

  @doc """
  Vínculo derivado não carrega nível de acesso (FR-006).

  Origem: regra `github.default_team`, `observed_link.platform_access_level`. Um nível
  preenchido em vínculo que a origem não conhece seria dado inventado, e faria
  "observado como membro comum" e "a origem não sabe deste vínculo" ficarem
  indistinguíveis.
  """
  @spec derived_link_has_no_access_level(map()) :: :ok | {:error, String.t()}
  def derived_link_has_no_access_level(%{source_system: "github"}), do: :ok

  def derived_link_has_no_access_level(%{platform_access_level: level, source_system: source})
      when not is_nil(level) do
    {:error,
     "vínculo de origem '#{source}' com nível de acesso '#{level}': " <>
       "a origem não conhece este vínculo, então não informa nível — ausência é nula."}
  end

  def derived_link_has_no_access_level(_), do: :ok
end
