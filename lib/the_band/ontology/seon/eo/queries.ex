defmodule TheBand.Ontology.SEON.EO.Queries do
  @moduledoc """
  Leituras do módulo EO. Todas recebem o tenant explicitamente.

  `list_*` e `count_*` aceitam **exatamente as mesmas** `opts`, e isso não é
  preferência de estilo: uma contagem que ignora o filtro que a listagem aplica
  exibe "41 pessoas" acima de uma lista de 10, e o defeito permanece invisível
  enquanto não houver consumidor. O filtro é montado uma vez, em `scope/3`, e as
  duas funções o compartilham.

  Nenhuma função devolve `Ecto.Query`: devolver query vazaria o schema interno e
  permitiria compor fora da fronteira, contornando o filtro de tenant.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO.RoleCatalog
  alias TheBand.Ontology.SEON.EO.Schemas.Organization
  alias TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Ontology.SEON.EO.Schemas.RoleVisibilityGrant
  alias TheBand.Ontology.SEON.EO.Schemas.Team
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence
  alias TheBand.RawData
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  # ------------------------------------------------------------------- pessoas

  @spec list_people(Tenant.t(), keyword()) :: [Person.t()]
  def list_people(tenant, opts \\ []) do
    Person
    |> scope(tenant, opts)
    |> ordenar(opts[:order_by], [:name, :login, :account_type, :source_system, :collected_at])
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Identificador da pessoa por `login`, para quem precisa ligar em lote.

  Existe porque a coleta de issues precisa resolver autor e designados de milhares de
  issues: uma consulta por login faria uma ida ao banco por pessoa por issue. Aqui o
  mapa vem numa consulta e a ligação é em memória.

  Pessoa não coletada simplesmente **não está no mapa** — e quem chama grava o login com
  vínculo ausente, em vez de criar pessoa sem proveniência.
  """
  @spec person_ids_by_login(Tenant.t()) :: %{String.t() => Ecto.UUID.t()}
  def person_ids_by_login(%Tenant{id: tenant_id}) do
    Repo.all(
      from p in Person,
        where: p.tenant_id == ^tenant_id and not is_nil(p.login),
        select: {p.login, p.id}
    )
    |> Map.new()
  end

  @doc """
  Nome de cada pessoa pelos identificadores informados.

  É como a tela de issue mostra o nome do autor sem que `WorkItems` alcance
  `eo_people`: WorkItems guarda a **referência**, e o nome vem pela API pública de EO —
  a regra da fronteira do princípio IX aplicada em leitura.
  """
  @spec people_names(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t()}
  def people_names(_tenant, []), do: %{}

  def people_names(%Tenant{id: tenant_id}, ids) do
    Repo.all(
      from p in Person,
        where: p.tenant_id == ^tenant_id and p.id in ^ids,
        select: {p.id, p.name}
    )
    |> Map.new()
  end

  @spec count_people(Tenant.t(), keyword()) :: non_neg_integer()
  def count_people(tenant, opts \\ []) do
    Person |> scope(tenant, opts) |> Repo.aggregate(:count, :id)
  end

  # ------------------------------------------------------------------- equipes

  @spec list_teams(Tenant.t(), keyword()) :: [Team.t()]
  def list_teams(tenant, opts \\ []) do
    Team
    |> scope(tenant, opts)
    |> ordenar(opts[:order_by], [:name, :slug, :source_system, :collected_at])
    |> paginate(opts)
    |> Repo.all()
  end

  @spec count_teams(Tenant.t(), keyword()) :: non_neg_integer()
  def count_teams(tenant, opts \\ []) do
    Team |> scope(tenant, opts) |> Repo.aggregate(:count, :id)
  end

  @doc """
  Integrantes observados de uma equipe.

  Devolve o nível de acesso **na plataforma**, nunca um papel. A distinção é
  preservada até no nome do campo, porque desfazê-la na camada de leitura
  anularia o cuidado tomado no modelo.
  """
  @spec list_team_members(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def list_team_members(%Tenant{id: tenant_id}, team_id, opts \\ []) do
    include_absent? = Keyword.get(opts, :include_no_longer_observed, true)

    query =
      from e in TeamMembershipEvidence,
        join: p in Person,
        on: p.id == e.person_id,
        where: e.tenant_id == ^tenant_id and e.team_id == ^team_id,
        select: %{
          person: p,
          platform_access_level: e.platform_access_level,
          observed_at: e.observed_at,
          last_observed_at: e.last_observed_at,
          no_longer_observed_at: e.no_longer_observed_at,
          pending_role: is_nil(e.promoted_membership_id)
        }

    query
    |> then(fn q ->
      if include_absent?, do: q, else: where(q, [e], is_nil(e.no_longer_observed_at))
    end)
    |> busca_por_pessoa(opts[:search])
    |> ordenar_integrantes(opts[:order_by])
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Quantos integrantes a equipe tem, **com as mesmas opts** da listagem.

  A contagem e a listagem compartilham filtro porque um cabeçalho dizendo 64 sobre uma lista
  de 10 é o defeito que este módulo inteiro se organiza para não ter.
  """
  @spec count_team_members(Tenant.t(), Ecto.UUID.t(), keyword()) :: non_neg_integer()
  def count_team_members(%Tenant{id: tenant_id}, team_id, opts \\ []) do
    include_absent? = Keyword.get(opts, :include_no_longer_observed, true)

    from(e in TeamMembershipEvidence,
      join: p in Person,
      on: p.id == e.person_id,
      where: e.tenant_id == ^tenant_id and e.team_id == ^team_id
    )
    |> then(fn q ->
      if include_absent?, do: q, else: where(q, [e], is_nil(e.no_longer_observed_at))
    end)
    |> busca_por_pessoa(opts[:search])
    |> Repo.aggregate(:count, :id)
  end

  defp busca_por_pessoa(query, termo) when termo in [nil, ""], do: query

  defp busca_por_pessoa(query, termo) do
    like = "%#{termo}%"
    where(query, [_e, p], ilike(p.name, ^like) or ilike(p.login, ^like))
  end

  # A ordenação atravessa duas tabelas: nome e login são da pessoa, o nível de acesso e as
  # datas são da evidência. Por isso a lista permitida não é uma só — cada campo sabe de onde
  # sai, e o que não estiver aqui cai no padrão.
  defp ordenar_integrantes(query, {:name, dir}), do: order_by(query, [_e, p], [{^dir, p.name}])

  defp ordenar_integrantes(query, {:platform_access_level, dir}),
    do: order_by(query, [e, p], [{^dir, e.platform_access_level}, asc: p.name])

  defp ordenar_integrantes(query, {:observed_at, dir}),
    do: order_by(query, [e, p], [{^dir, e.observed_at}, asc: p.name])

  defp ordenar_integrantes(query, {:last_observed_at, dir}),
    do: order_by(query, [e, p], [{^dir, e.last_observed_at}, asc: p.name])

  defp ordenar_integrantes(query, _outra), do: order_by(query, [_e, p], asc: p.name)

  # --------------------------------------------------------------- organizações

  @spec list_organizations(Tenant.t(), keyword()) :: [Organization.t()]
  def list_organizations(%Tenant{id: tenant_id}, _opts \\ []) do
    Repo.all(from o in Organization, where: o.tenant_id == ^tenant_id, order_by: o.name)
  end

  @doc """
  A visão agregada da organização: equipes vigentes e responsáveis, por organização —
  contrato em `specs/046-menu-por-entidades/contracts/eo-organization-overview.md`.

  Uma passada por coleção, nunca consulta por linha (lição L38). "Responsável" tem a
  definição única da regra de visibilidade (#369): pessoa com vínculo vigente cujo
  papel carrega concessão de escopo `organization` não revogada — declaração, jamais
  inferência por nome de papel. Projetos NÃO entram aqui: pertencem ao contexto
  Projects, e a tela os agrupa por `source_instance` ↔ `login` — atravessar a
  fronteira para poupar um `Enum.group_by` na view furaria o módulo (AGENTS §7.1).
  """
  @spec organization_overview(Tenant.t()) :: [
          %{
            organization: Organization.t(),
            teams: [Team.t()],
            responsibles: [%{person: Person.t(), role_name: String.t()}]
          }
        ]
  def organization_overview(%Tenant{id: tenant_id} = tenant) do
    equipes =
      Repo.all(
        from t in Team,
          where:
            t.tenant_id == ^tenant_id and is_nil(t.no_longer_observed_at) and
              not is_nil(t.organization_id),
          order_by: t.name
      )
      |> Enum.group_by(& &1.organization_id)

    responsaveis =
      Repo.all(
        from m in TeamMembership,
          join: g in RoleVisibilityGrant,
          on:
            g.organizational_role_id == m.organizational_role_id and
              g.tenant_id == m.tenant_id and is_nil(g.revoked_at) and
              g.scope == "organization",
          join: t in Team,
          on: t.id == m.team_id,
          join: p in Person,
          on: p.id == m.person_id,
          join: r in OrganizationalRole,
          on: r.id == m.organizational_role_id,
          where:
            m.tenant_id == ^tenant_id and is_nil(m.ended_at) and
              not is_nil(t.organization_id),
          distinct: [t.organization_id, p.id, r.id],
          select: %{organization_id: t.organization_id, person: p, role_name: r.name},
          order_by: [asc: p.name]
      )
      |> Enum.group_by(& &1.organization_id, &Map.take(&1, [:person, :role_name]))

    for org <- list_organizations(tenant) do
      %{
        organization: org,
        teams: Map.get(equipes, org.id, []),
        responsibles: Map.get(responsaveis, org.id, [])
      }
    end
  end

  @doc """
  A organização observada com aquele `login`, ou `nil`.

  Usada pelo retrofito para fechar a corrente `connected_tools.organization_login →
  eo_organizations.login`. Devolve `nil` em vez de erro: organização de origem que
  não está na base é lacuna a registrar no relatório, não exceção.
  """
  @spec fetch_organization_by_login(Ecto.UUID.t(), String.t()) :: Organization.t() | nil
  def fetch_organization_by_login(tenant_id, login) do
    Repo.one(
      from o in Organization,
        where: o.tenant_id == ^tenant_id and o.login == ^login,
        limit: 1
    )
  end

  @doc """
  As organizações de uma pessoa, pelo caminho pessoa → equipe → organização.

  **Não existe aresta direta entre pessoa e organização**, e criar uma seria o
  segundo caminho que a especificação rejeitou: EO faz o vínculo passar por papel
  organizacional, que o GitHub não fornece. O caminho aqui é o declarado em
  `eo.cq02` — a evidência de participação em equipe, e a organização da equipe.

  Três consequências que a assinatura não mostra:

  - **quem não está em equipe alguma devolve lista vazia**, não erro. É informação:
    a organização é conhecida e o vínculo não;
  - **duas equipes da mesma organização devolvem uma organização.** A distinção é
    por organização, não por vínculo;
  - **vínculo que deixou de ser observado continua contando** (FR-009). Ausência
    numa coleta não é remoção: a pessoa esteve naquela organização, e apagar o
    vínculo ao primeiro silêncio da origem perderia isso. Quem quiser só o vigente
    passa `only_observed: true`.
  """
  @spec list_person_organizations(Tenant.t(), Ecto.UUID.t(), keyword()) :: [Organization.t()]
  def list_person_organizations(%Tenant{id: tenant_id}, person_id, opts \\ []) do
    query =
      from o in Organization,
        join: t in Team,
        on: t.organization_id == o.id and t.tenant_id == o.tenant_id,
        join: e in TeamMembershipEvidence,
        on: e.team_id == t.id and e.tenant_id == t.tenant_id,
        where: o.tenant_id == ^tenant_id and e.person_id == ^person_id,
        distinct: true,
        order_by: o.name,
        select: o

    query
    |> then(fn q ->
      if opts[:only_observed], do: where(q, [_o, _t, e], is_nil(e.no_longer_observed_at)), else: q
    end)
    |> Repo.all()
  end

  @doc """
  A organização daquele id, ou levanta.

  Levanta de propósito: quem chama já a coletou nesta mesma sincronização, então
  ausência aqui é defeito de programação e não estado do mundo.
  """
  @spec fetch_organization!(Tenant.t(), Ecto.UUID.t()) :: Organization.t()
  def fetch_organization!(%Tenant{id: tenant_id}, organization_id) do
    Repo.one!(
      from o in Organization,
        where: o.tenant_id == ^tenant_id and o.id == ^organization_id
    )
  end

  @doc """
  As pessoas de uma organização que **não** estão em nenhuma equipe observada dela.

  É a entrada da regra `github.default_team`: exatamente quem a equipe derivada
  existe para acolher.

  **"De uma organização" precisa de definição, e a primeira versão desta função não a
  tinha.** Ela devolvia toda pessoa do tenant fora das equipes daquela organização, o
  que é coisa diferente: medido no banco real, `ifesserra-lab` — 5 membros — recebeu
  **72** pessoas, o tenant inteiro. A equipe derivada teria afirmado que todos são de
  todas as organizações.

  A definição correta é **membro observado da organização**, e a observação existe:
  a conta apareceu em `organization.membersWithRole`, e o payload está preservado.
  `RawData.organization_member_external_ids/2` a lê, atravessando a mesma corrente do
  retrofito. Não é aresta nova em EO — é leitura da coleta.

  Automação fica fora: conta de bot não é pessoa, e acolhê-la inflaria o quadro que a
  equipe derivada existe para completar.
  """
  @spec list_people_without_team(Tenant.t(), Ecto.UUID.t()) :: [Person.t()]
  def list_people_without_team(%Tenant{id: tenant_id} = tenant, organization_id) do
    organization = fetch_organization!(tenant, organization_id)
    membros = RawData.organization_member_external_ids(tenant_id, organization.login)

    em_equipe_observada =
      from e in TeamMembershipEvidence,
        join: t in Team,
        on: t.id == e.team_id and t.tenant_id == e.tenant_id,
        where: t.organization_id == ^organization_id and t.source_system != "the_band",
        select: e.person_id

    Repo.all(
      from p in Person,
        where:
          p.tenant_id == ^tenant_id and p.account_type == "person" and
            is_nil(p.no_longer_observed_at) and
            p.external_id in ^membros and
            p.id not in subquery(em_equipe_observada),
        order_by: p.name
    )
  end

  @doc "A equipe derivada de uma organização, se existir."
  @spec fetch_derived_team(Tenant.t(), Ecto.UUID.t()) :: Team.t() | nil
  def fetch_derived_team(%Tenant{id: tenant_id}, organization_id) do
    Repo.one(
      from t in Team,
        where:
          t.tenant_id == ^tenant_id and t.organization_id == ^organization_id and
            t.source_system == "the_band",
        limit: 1
    )
  end

  @doc """
  As organizações de várias pessoas de uma vez: `%{person_id => [organizações]}`.

  Existe porque a tela de pessoas precisa da organização de **cada linha**, e chamar
  `list_person_organizations/3` por linha faria uma consulta por pessoa — 72 idas ao
  banco para desenhar uma página, e o custo cresce com a coleta.

  Pessoa sem equipe alguma **não aparece no mapa**. Quem usa trata a ausência com
  `Map.get(mapa, id, [])`: devolver a chave com lista vazia sugeriria que a ausência
  foi verificada pessoa a pessoa, quando ela é consequência de não haver vínculo.
  """
  @spec organizations_by_person(Tenant.t(), [Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => [Organization.t()]
        }
  def organizations_by_person(_tenant, []), do: %{}

  def organizations_by_person(%Tenant{id: tenant_id}, person_ids) do
    from(o in Organization,
      join: t in Team,
      on: t.organization_id == o.id and t.tenant_id == o.tenant_id,
      join: e in TeamMembershipEvidence,
      on: e.team_id == t.id and e.tenant_id == t.tenant_id,
      where: o.tenant_id == ^tenant_id and e.person_id in ^person_ids,
      distinct: true,
      order_by: o.name,
      select: {e.person_id, o}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  O que será marcado se a observação de uma organização for encerrada (T006, FR-002).

  Devolve os seis números que a tela mostra antes de confirmar, e é a **mesma** função
  que o encerramento usa para gravar `impact` no evento — uma segunda contagem
  divergiria da que age.

  `people_exclusive` e `people_shared` são separados porque juntá-los esconde a única
  contagem que assusta: quem tem vínculo apenas nesta organização perde a vigência, quem
  tem em outra permanece.

  `preserved_payloads` está aqui para dizer **zero apagados** — o número existe na tela
  para que ninguém suponha que encerrar destrói o histórico de coleta.
  """
  @spec observation_impact(Tenant.t(), String.t()) :: map()
  def observation_impact(%Tenant{id: tenant_id} = tenant, organization_login) do
    case fetch_organization_by_login(tenant_id, organization_login) do
      nil ->
        zero_impact()

      organization ->
        equipes_da_org =
          from t in Team,
            where: t.tenant_id == ^tenant_id and t.organization_id == ^organization.id,
            select: t.id

        pessoas_da_org =
          from e in TeamMembershipEvidence,
            where: e.tenant_id == ^tenant_id and e.team_id in subquery(equipes_da_org),
            select: e.person_id

        # Vínculo vigente FORA desta organização é o que mantém a pessoa observada.
        com_vinculo_fora =
          from e in TeamMembershipEvidence,
            where:
              e.tenant_id == ^tenant_id and is_nil(e.no_longer_observed_at) and
                e.team_id not in subquery(equipes_da_org),
            select: e.person_id

        pessoas =
          Repo.all(from p in Person, where: p.id in subquery(pessoas_da_org), select: p.id)

        fora = Repo.all(from p in Person, where: p.id in subquery(com_vinculo_fora), select: p.id)
        compartilhadas = MapSet.intersection(MapSet.new(pessoas), MapSet.new(fora))

        %{
          teams:
            Repo.aggregate(from(t in Team, where: t.id in subquery(equipes_da_org)), :count, :id),
          derived_teams:
            Repo.aggregate(
              from(t in Team,
                where: t.id in subquery(equipes_da_org) and t.source_system == "the_band"
              ),
              :count,
              :id
            ),
          evidence_links:
            Repo.aggregate(
              from(e in TeamMembershipEvidence, where: e.team_id in subquery(equipes_da_org)),
              :count,
              :id
            ),
          people_exclusive: length(pessoas) - MapSet.size(compartilhadas),
          people_shared: MapSet.size(compartilhadas),
          preserved_payloads: RawData.count_for_organization(tenant, organization_login)
        }
    end
  end

  @doc """
  Nomes das pessoas desta organização que têm vínculo vigente em **outra**.

  São exatamente as que permanecem se a observação for encerrada, e a tela as mostra
  pelo nome.
  """
  @spec shared_people_names(Tenant.t(), String.t()) :: [String.t()]
  def shared_people_names(%Tenant{id: tenant_id}, organization_login) do
    case fetch_organization_by_login(tenant_id, organization_login) do
      nil ->
        []

      organization ->
        equipes_da_org =
          from t in Team,
            where: t.tenant_id == ^tenant_id and t.organization_id == ^organization.id,
            select: t.id

        pessoas_da_org =
          from e in TeamMembershipEvidence,
            where: e.tenant_id == ^tenant_id and e.team_id in subquery(equipes_da_org),
            select: e.person_id

        com_vinculo_fora =
          from e in TeamMembershipEvidence,
            where:
              e.tenant_id == ^tenant_id and is_nil(e.no_longer_observed_at) and
                e.team_id not in subquery(equipes_da_org),
            select: e.person_id

        Repo.all(
          from p in Person,
            where: p.id in subquery(pessoas_da_org) and p.id in subquery(com_vinculo_fora),
            order_by: p.name,
            select: p.name
        )
    end
  end

  defp zero_impact do
    %{
      teams: 0,
      derived_teams: 0,
      evidence_links: 0,
      people_exclusive: 0,
      people_shared: 0,
      preserved_payloads: 0
    }
  end

  # ------------------------------------------------------------------- lacunas

  @doc """
  FR-021 e SC-010 — quantos vínculos observados ainda não têm papel atribuído.

  É medida de lacuna de conhecimento, não erro: diz quanto da estrutura
  organizacional o sistema ainda não conhece.
  """
  @spec count_evidence_pending_role(Tenant.t(), keyword()) :: non_neg_integer()
  def count_evidence_pending_role(%Tenant{id: tenant_id}, opts \\ []) do
    query =
      from e in TeamMembershipEvidence,
        where: e.tenant_id == ^tenant_id and is_nil(e.promoted_membership_id)

    query =
      case Keyword.get(opts, :team_id) do
        nil -> query
        team_id -> where(query, [e], e.team_id == ^team_id)
      end

    Repo.aggregate(query, :count, :id)
  end

  # --------------------------------------------------------------------- escopo

  # O filtro de tenant não é opcional nem parametrizável: entra sempre, e é a
  # primeira cláusula. Query sem ele é bug de segurança, não de correção.
  defp scope(schema, %Tenant{id: tenant_id}, opts) do
    schema
    |> where([r], r.tenant_id == ^tenant_id)
    |> filter_account_type(opts[:account_type])
    |> filter_search(opts[:search])
    |> filter_observed(opts[:only_observed])
    |> filter_missing_organization(opts[:missing_organization])
    |> filter_organization(opts[:organization_id])
    |> filter_origin(opts[:origin])
  end

  # `:organization_id` sobre equipes é direto; sobre pessoas atravessa as equipes,
  # porque não existe aresta direta pessoa↔organização (eo.cq02).
  defp filter_organization(query, nil), do: query

  defp filter_organization(%Ecto.Query{from: %{source: {_, Person}}} = query, organization_id) do
    where(
      query,
      [p],
      p.id in subquery(
        from e in TeamMembershipEvidence,
          join: t in Team,
          on: t.id == e.team_id and t.tenant_id == e.tenant_id,
          where: t.organization_id == ^organization_id,
          select: e.person_id
      )
    )
  end

  defp filter_organization(query, organization_id),
    do: where(query, [r], r.organization_id == ^organization_id)

  # A origem é lida de `source_system`, e nenhuma coluna nova responde isto: a
  # proveniência é obrigatória em toda linha por exigência do princípio III.
  defp filter_origin(query, :observed), do: where(query, [r], r.source_system != "the_band")
  defp filter_origin(query, :derived), do: where(query, [r], r.source_system == "the_band")
  defp filter_origin(query, _), do: query

  # Só para o retrofito: quais equipes ainda não têm organização. Não vira opção
  # pública de listagem porque a pergunta é de manutenção, não de consulta — e uma
  # opção pública convidaria a tela a exibir "equipes sem organização" como se fosse
  # categoria do domínio, quando é lacuna a fechar.
  defp filter_missing_organization(query, true),
    do: where(query, [r], is_nil(r.organization_id))

  defp filter_missing_organization(query, _), do: query

  defp filter_account_type(query, nil), do: query

  defp filter_account_type(query, types) when is_list(types),
    do: where(query, [r], r.account_type in ^types)

  defp filter_account_type(query, type), do: where(query, [r], r.account_type == ^type)

  defp filter_search(query, nil), do: query
  defp filter_search(query, ""), do: query

  # **A segunda coluna depende do schema.** Pessoa tem `login`; equipe tem `slug`, e não tem
  # `login` — a versão única quebrava com `column e0.login does not exist` no dia em que
  # alguém passasse busca para equipes. Ficou latente enquanto ninguém passava.
  defp filter_search(%Ecto.Query{from: %{source: {_, Team}}} = query, term) do
    like = "%#{term}%"
    where(query, [r], ilike(r.name, ^like) or ilike(r.slug, ^like))
  end

  defp filter_search(query, term) do
    like = "%#{term}%"
    where(query, [r], ilike(r.name, ^like) or ilike(r.login, ^like))
  end

  defp filter_observed(query, true), do: where(query, [r], is_nil(r.no_longer_observed_at))
  defp filter_observed(query, _), do: query

  # A ordenação que a tela pediu, **conferida contra a lista de colunas permitidas**.
  #
  # A conferência não é zelo: `order_by` recebe átomo, e um átomo vindo do parâmetro
  # ordenaria por coluna que a tela não declarou — ou por nenhuma, silenciosamente. Coluna
  # fora da lista cai no padrão, que é o nome, e a tela já avisou quem pediu (feature 019).
  #
  # O desempate por `id` existe porque paginar sobre ordem não determinística repete e some
  # com linhas entre páginas: dois nomes iguais mudam de lado a cada consulta.
  defp ordenar(query, nil, _permitidas), do: order_by(query, [r], asc: r.name, asc: r.id)

  defp ordenar(query, {campo, direcao}, permitidas) when direcao in [:asc, :desc] do
    if campo in permitidas do
      order_by(query, [r], [{^direcao, field(r, ^campo)}, asc: r.id])
    else
      order_by(query, [r], asc: r.name, asc: r.id)
    end
  end

  defp ordenar(query, _outra, _permitidas), do: order_by(query, [r], asc: r.name, asc: r.id)

  defp paginate(query, opts) do
    query
    |> then(fn q -> if opts[:limit], do: limit(q, ^opts[:limit]), else: q end)
    |> then(fn q -> if opts[:offset], do: offset(q, ^opts[:offset]), else: q end)
  end

  @doc """
  A pessoa, por identificador **interno**.

  Login não serve: é da origem, muda quando a pessoa o troca, e não é único entre instâncias —
  a L25. Pessoa de outro tenant devolve `:not_found`, nunca "sem permissão": confirmar
  existência já é vazamento.
  """
  @spec fetch_person(Tenant.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, :not_found}
  def fetch_person(%Tenant{id: tenant_id}, person_id) do
    consulta =
      from p in Person,
        where: p.tenant_id == ^tenant_id and p.id == ^person_id,
        select: %{
          id: p.id,
          name: p.name,
          login: p.login,
          account_type: p.account_type,
          source_system: p.source_system,
          source_instance: p.source_instance,
          external_id: p.external_id,
          collected_at: p.collected_at,
          last_observed_at: p.last_observed_at,
          no_longer_observed_at: p.no_longer_observed_at
        }

    case Repo.one(consulta) do
      nil -> {:error, :not_found}
      pessoa -> {:ok, pessoa}
    end
  end

  @doc """
  As equipes com vínculo VIGENTE da pessoa — feature 045 (contrato access-scopes.md).

  Vínculo, e não evidência: `list_person_teams/2` conta o que a origem afirmou;
  esta conta o que a organização declarou e não encerrou (`ended_at` nulo). É a
  leitura de que o escopo derivado nasce — e por isso vínculo encerrado some daqui.
  """
  @spec person_active_teams(Tenant.t(), Ecto.UUID.t()) :: [
          %{team_id: Ecto.UUID.t(), team_name: String.t(), organization_id: Ecto.UUID.t() | nil}
        ]
  def person_active_teams(%Tenant{id: tenant_id}, person_id) do
    Repo.all(
      from m in TeamMembership,
        join: t in Team,
        on: t.id == m.team_id,
        where:
          m.tenant_id == ^tenant_id and m.person_id == ^person_id and is_nil(m.ended_at) and
            is_nil(t.no_longer_observed_at),
        distinct: t.id,
        order_by: [asc: t.name],
        select: %{team_id: t.id, team_name: t.name, organization_id: t.organization_id}
    )
  end

  @doc """
  Os logins das pessoas pedidas, num mapa — feature 051 (contrato contas-e-elo.md).

  Existe para a lista de contas dizer o GitHub associado de TODAS as linhas numa
  consulta (L38) — uma por linha seria N+1 na tela de administração.
  """
  @spec person_logins(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t() | nil}
  def person_logins(%Tenant{id: tenant_id}, person_ids) when is_list(person_ids) do
    from(p in Person,
      where: p.tenant_id == ^tenant_id and p.id in ^person_ids,
      select: {p.id, p.login}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Os logins das organizações OBSERVADAS de várias pessoas, num mapa — 051/T009
  (contrato contas-e-elo.md, correção da aceitação do sprint 025).

  Existe para a busca de pessoas em /accounts dizer a organização de cada
  resultado (o edge case dos homônimos) em UMA consulta para a página de
  resultados — por pessoa seria N+1 (L38). Mesmo desenho da leitura singular
  abaixo: evidência vigente, organização da equipe.
  """
  @spec observed_org_logins_of_people(Tenant.t(), [Ecto.UUID.t()]) ::
          %{Ecto.UUID.t() => [String.t()]}
  def observed_org_logins_of_people(_tenant, []), do: %{}

  def observed_org_logins_of_people(%Tenant{id: tenant_id}, person_ids) do
    Repo.all(
      from e in TeamMembershipEvidence,
        join: t in Team,
        on: t.id == e.team_id,
        join: o in Organization,
        on: o.id == t.organization_id,
        where:
          e.tenant_id == ^tenant_id and e.person_id in ^person_ids and
            is_nil(e.no_longer_observed_at) and not is_nil(t.organization_id),
        distinct: true,
        select: {e.person_id, o.login}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  As organizações em que a pessoa é OBSERVADA — feature 045 (contrato access-scopes.md).

  Pela evidência vigente da origem (`no_longer_observed_at` nulo): é o que o GitHub
  afirma sobre pertencer, e existe porque o vínculo promovido quase não existe no
  dado real (101 evidências, 0 promoções — a história da tela de papéis). O escopo
  organization alcança quem a organização-alvo OBSERVA, não só quem ela promoveu.
  """
  @spec person_observed_organization_ids(Tenant.t(), Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def person_observed_organization_ids(%Tenant{id: tenant_id}, person_id) do
    Repo.all(
      from e in TeamMembershipEvidence,
        join: t in Team,
        on: t.id == e.team_id,
        where:
          e.tenant_id == ^tenant_id and e.person_id == ^person_id and
            is_nil(e.no_longer_observed_at) and not is_nil(t.organization_id),
        distinct: true,
        select: t.organization_id
    )
  end

  @doc "Nomes de equipes por id — feature 045, para rotular concessões sem consulta por linha."
  @spec teams_by_ids(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t()}
  def teams_by_ids(%Tenant{id: tenant_id}, ids) when is_list(ids) do
    Repo.all(
      from t in Team,
        where: t.tenant_id == ^tenant_id and t.id in ^ids,
        select: {t.id, t.name}
    )
    |> Map.new()
  end

  @doc """
  As equipes que **a origem declara** para a pessoa, numa consulta.

  O que ela devolve é **evidência**, não vínculo: `promoted?` diz se a plataforma promoveu, e
  no dado real de 2026-08-12 são 88 evidências e **zero** promoções.

  `platform_access_level` é dado **da ferramenta** — `MEMBER`, `MAINTAINER`. **Não é papel**, e
  nenhum campo aqui se chama `role` de propósito: derivar papel de permissão seria mapear por
  semelhança de nome, o que contamina toda medida derivada.

  `no_longer_observed_at` preenchido significa que **houve** vínculo e ele não está presente —
  diferente de nunca ter havido, e a tela precisa mostrar os dois de formas diferentes.
  """
  @spec list_person_teams(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_person_teams(%Tenant{id: tenant_id}, person_id) do
    Repo.all(
      from e in TeamMembershipEvidence,
        join: t in Team,
        on: t.id == e.team_id,
        left_join: o in Organization,
        on: o.id == t.organization_id,
        where: e.tenant_id == ^tenant_id and e.person_id == ^person_id,
        order_by: [asc: t.name],
        select: %{
          team_id: t.id,
          team_name: t.name,
          organization_login: o.login,
          platform_access_level: e.platform_access_level,
          observed_at: e.observed_at,
          last_observed_at: e.last_observed_at,
          no_longer_observed_at: e.no_longer_observed_at,
          promoted?: not is_nil(e.promoted_membership_id)
        }
    )
  end

  @doc """
  Quantos papéis o tenant cadastrou.

  Existe para a tela **explicar** a não promoção com base no dado, e não em texto fixo. A
  distinção que ela sustenta:

    * **zero papéis** — promover é impossível para qualquer pessoa, e a causa é essa;
    * **com papéis**, e a evidência não promovida — a causa é que ninguém alocou papel àquela
      pessoa naquela equipe, que é outra feature.

  Um texto fixo dizendo "nenhum papel foi cadastrado" passaria a mentir no dia em que alguém
  cadastrasse papel, e ninguém notaria: a frase continuaria plausível.
  """
  @spec count_roles(Tenant.t()) :: non_neg_integer()
  def count_roles(%Tenant{id: tenant_id}) do
    Repo.one(from r in OrganizationalRole, where: r.tenant_id == ^tenant_id, select: count(r.id))
  end

  # ------------------------------------------------------- papéis e alocação (feature 021)

  @doc """
  As evidências desta equipe **esperando confirmação** — issue #317.

  ## O que ela devolve, e o que ela NÃO devolve

  Pessoa e equipe. **Não devolve `platform_access_level`.**

  A garantia fica aqui, no contrato, e não na tela: se o valor não chega à camada de
  apresentação, nenhum template pode exibi-lo por descuido. `MAINTAINER`, `MEMBER` e nulo
  afirmam **a mesma coisa** — que a pessoa é membro da equipe —, e a diferença entre eles é
  permissão na ferramenta, não função.

  Exibi-lo ao lado de um seletor de papel faria dele uma dica, por mais que o texto negasse.
  E ele não acrescenta nada à decisão: das 101 evidências medidas em 2026-08-24, **33 têm o
  nível nulo** e sustentam a promoção exatamente como as outras 68.

  `EO.Constraints.platform_access_level_is_not_a_role/1` já recusa o nível como papel desde a
  feature 021, com a justificativa medida: promovê-lo faria `CQ12`, `CQ14` e `CQ16` devolverem
  **resposta falsa em vez de nenhuma**.

  ## Quem fica de fora

  Evidência **já promovida** — `promoted_membership_id` preenchido — e evidência cuja
  observação terminou. A segunda continua existindo, e o vínculo que veio dela permanece; ela
  só não é oferecida de novo.
  """
  @spec pending_evidence(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def pending_evidence(%Tenant{id: tenant_id}, team_id) do
    Repo.all(
      from e in TeamMembershipEvidence,
        join: p in Person,
        on: p.id == e.person_id,
        join: t in Team,
        on: t.id == e.team_id,
        where:
          e.tenant_id == type(^tenant_id, :binary_id) and
            e.team_id == type(^team_id, :binary_id) and
            is_nil(e.promoted_membership_id) and is_nil(e.no_longer_observed_at),
        order_by: [asc: p.name],
        select: %{
          id: e.id,
          person_id: p.id,
          person_name: p.name,
          person_login: p.login,
          team_id: t.id,
          team_name: t.name,
          organization_id: t.organization_id
        }
    )
  end

  @doc """
  Os papéis **desta organização**, compostos com o catálogo da rede — issue #317.

  Nome próprio, e não `list_roles/2`: aquela é da feature 021 e devolve as linhas do tenant
  inteiro. As duas coexistem enquanto houver chamador da antiga — e o nome desta diz o escopo,
  que é justamente o que a 021 não tinha.

  Devolve os quatro do Scrum sempre, com `id: nil` enquanto ninguém os usou, mais os
  declarados pela organização. Ver `EO.RoleCatalog` para por que o catálogo não é tabela.
  """
  @spec list_organization_roles(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_organization_roles(%Tenant{id: tenant_id}, organization_id) do
    from(r in OrganizationalRole,
      where:
        r.tenant_id == type(^tenant_id, :binary_id) and
          r.organization_id == type(^organization_id, :binary_id),
      select: %{
        id: r.id,
        code: r.code,
        name: r.name,
        catalog_concept_id: r.catalog_concept_id,
        declared_by_user_id: r.declared_by_user_id,
        hidden_at: r.hidden_at
      }
    )
    |> Repo.all()
    |> RoleCatalog.compose()
  end

  @doc "A linha de um papel de catálogo nesta organização, ou `nil`."
  @spec role_by_concept(Tenant.t(), Ecto.UUID.t(), String.t()) :: OrganizationalRole.t() | nil
  def role_by_concept(%Tenant{id: tenant_id}, organization_id, concept_id) do
    Repo.one(
      from r in OrganizationalRole,
        where:
          r.tenant_id == type(^tenant_id, :binary_id) and
            r.organization_id == type(^organization_id, :binary_id) and
            r.catalog_concept_id == ^concept_id
    )
  end

  @doc """
  Quantas **pessoas distintas** a equipe tem — e nunca quantos vínculos.

  Uma pessoa com Product Owner e Developer na mesma equipe é **uma** pessoa. Somar vínculos
  faria a equipe parecer maior do que é, e o erro passa despercebido porque o número fica
  plausível. Existe como função própria para que ninguém escreva `length(vinculos)`.
  """
  @spec team_size(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def team_size(%Tenant{id: tenant_id}, team_id) do
    Repo.aggregate(
      from(m in TeamMembership,
        where:
          m.tenant_id == type(^tenant_id, :binary_id) and
            m.team_id == type(^team_id, :binary_id) and is_nil(m.ended_at),
        distinct: m.person_id
      ),
      :count,
      :person_id
    )
  end

  @doc "Os papéis que este tenant reconhece, por nome."
  @spec list_roles(Tenant.t(), keyword()) :: [OrganizationalRole.t()]
  def list_roles(%Tenant{id: tenant_id}, _opts \\ []) do
    Repo.all(from r in OrganizationalRole, where: r.tenant_id == ^tenant_id, order_by: r.name)
  end

  @doc "O papel daquele id. Id de outro tenant devolve `:not_found`, nunca o registro."
  @spec fetch_role(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, OrganizationalRole.t()} | {:error, :not_found}
  def fetch_role(%Tenant{id: tenant_id}, role_id) do
    case Repo.one(
           from r in OrganizationalRole, where: r.tenant_id == ^tenant_id and r.id == ^role_id
         ) do
      nil -> {:error, :not_found}
      papel -> {:ok, papel}
    end
  rescue
    # Id que não é UUID vem da URL ou de formulário adulterado, e a resposta é a mesma: não
    # encontrado. Levantar derrubaria a tela por dado de entrada.
    Ecto.Query.CastError -> {:error, :not_found}
  end

  @doc "A evidência daquele id, com escopo de tenant — issue #317."
  @spec fetch_evidence(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, TeamMembershipEvidence.t()} | {:error, :not_found}
  def fetch_evidence(%Tenant{id: tenant_id}, evidence_id) do
    case Repo.one(
           from e in TeamMembershipEvidence,
             where: e.tenant_id == ^tenant_id and e.id == ^evidence_id
         ) do
      nil -> {:error, :not_found}
      evidencia -> {:ok, evidencia}
    end
  rescue
    Ecto.Query.CastError -> {:error, :not_found}
  end

  @doc "A equipe daquele id, com escopo de tenant. Traz `organization_id`, que a promoção usa."
  @spec fetch_team(Tenant.t(), Ecto.UUID.t()) :: {:ok, Team.t()} | {:error, :not_found}
  def fetch_team(%Tenant{id: tenant_id}, team_id) do
    case Repo.one(from t in Team, where: t.tenant_id == ^tenant_id and t.id == ^team_id) do
      nil -> {:error, :not_found}
      equipe -> {:ok, equipe}
    end
  rescue
    Ecto.Query.CastError -> {:error, :not_found}
  end

  @doc "Quantos vínculos apontam para este papel — é o número que a recusa de remoção exibe."
  @spec count_memberships_of_role(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def count_memberships_of_role(%Tenant{id: tenant_id}, role_id) do
    Repo.aggregate(
      from(m in TeamMembership,
        where: m.tenant_id == ^tenant_id and m.organizational_role_id == ^role_id
      ),
      :count
    )
  end

  @doc "O vínculo daquele id, com escopo de tenant."
  @spec fetch_membership(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, TeamMembership.t()} | {:error, :not_found}
  def fetch_membership(%Tenant{id: tenant_id}, membership_id) do
    case Repo.one(
           from m in TeamMembership, where: m.tenant_id == ^tenant_id and m.id == ^membership_id
         ) do
      nil -> {:error, :not_found}
      vinculo -> {:ok, vinculo}
    end
  end

  @doc """
  Os papéis declarados de uma pessoa, com equipe, período e autor.

  **Devolve o vigente e o encerrado.** Quem saiu do papel continua tendo desempenhado, e a tela
  distingue os dois pela data — esconder o encerrado apagaria história.
  """
  @spec list_person_roles(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_person_roles(%Tenant{id: tenant_id}, person_id) do
    Repo.all(
      from m in TeamMembership,
        join: r in OrganizationalRole,
        on: r.id == m.organizational_role_id,
        join: t in Team,
        on: t.id == m.team_id,
        left_join: u in "users",
        on: u.id == m.declared_by_user_id,
        where: m.tenant_id == ^tenant_id and m.person_id == ^person_id,
        order_by: [desc: is_nil(m.ended_at), asc: r.name],
        select: %{
          id: m.id,
          role_code: r.code,
          role_name: r.name,
          team_name: t.name,
          team_id: t.id,
          started_at: m.started_at,
          ended_at: m.ended_at,
          declared_by: u.email
        }
    )
  end

  @doc "Quantos vínculos existem no tenant — o número que sai de zero quando a feature funciona."
  @spec count_memberships(Tenant.t()) :: non_neg_integer()
  def count_memberships(%Tenant{id: tenant_id}) do
    Repo.aggregate(from(m in TeamMembership, where: m.tenant_id == ^tenant_id), :count)
  end

  @doc """
  Os papéis que a ontologia nomeia, como **sugestão de preenchimento** (FR-003).

  Devolve lista e **não grava nada**. `eo.organizational_role` está definido como papel social
  **reconhecido pela organização** — cadastrar automaticamente faria a plataforma reconhecer no
  lugar dela, e produziria papéis que talvez nenhuma equipe use.

  A leitura é da base de conhecimento pela API pública, e nunca por caminho de arquivo: a
  semântica vive no YAML, e quem pergunta "quais papéis existem?" pergunta a ela (princípio IV
  e IX).

  O código sugerido é o sufixo do identificador — `sro.developer_role` vira `developer_role` —
  porque o prefixo é da ontologia, e o catálogo é da organização.
  """
  @spec suggested_roles() :: [%{code: String.t(), name: String.t()}]
  def suggested_roles do
    :module
    |> KnowledgeBase.list()
    |> Enum.flat_map(&Map.get(&1, "concepts", []))
    |> Enum.filter(&papel_de_scrum?/1)
    |> Enum.map(fn conceito ->
      %{
        code: conceito |> Map.get("id") |> String.split(".") |> List.last(),
        name: Map.get(conceito, "name")
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  # Os quatro que herdam de `sro.scrum_role` — e não o próprio, que é o pai abstrato.
  defp papel_de_scrum?(conceito) do
    get_in(conceito, ["classification", "parent"]) == "sro.scrum_role"
  end
end
