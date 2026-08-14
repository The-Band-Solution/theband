defmodule TheBand.Ontology.SEON.EO.Commands do
  @moduledoc """
  Escritas do módulo EO. Chamadas apenas por `TheBand.Ontology.SEON.EO`.

  Todas as funções são `upsert_*_from_source` e não `create_*`. Entidade ingerida
  não é criada por alguém: é **observada**. A função recebe o tenant e os
  atributos com proveniência, resolve a Application Reference e decide entre
  inserir e atualizar.

  ## Idempotência (FR-014, SC-003)

  A segunda execução com a mesma origem e os mesmos atributos **não escreve**:
  devolve o registro existente com `record_version` intocado. É isso que faz a
  segunda sincronização criar 0 e atualizar 0.

  O resultado de cada chamada vem no campo virtual `:outcome` —
  `:created`, `:updated` ou `:unchanged` —, que é o que alimenta o relatório de
  FR-028 sem precisar de uma segunda consulta.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Queries
  alias TheBand.Ontology.SEON.EO.Schemas.Organization
  alias TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Ontology.SEON.EO.Schemas.Team
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @comparable %{
    Organization => [:name, :login, :parent_organization_id],
    Person => [:name, :email, :login, :account_type],
    Team => [:type, :name, :slug, :organization_id, :external_created_at]
  }

  @spec upsert_organization_from_source(Tenant.t(), map()) ::
          {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def upsert_organization_from_source(tenant, attrs),
    do: upsert(Organization, tenant, attrs)

  @spec upsert_person_from_source(Tenant.t(), map()) ::
          {:ok, Person.t()} | {:error, Ecto.Changeset.t()}
  def upsert_person_from_source(tenant, attrs), do: upsert(Person, tenant, attrs)

  @doc """
  Grava a equipe, resolvendo a organização pelo identificador externo dela.

  `organization_external_id` chega do mapeamento, que o lê do payload. A resolução
  para `organization_id` acontece **aqui**, e não no conector, por uma razão que
  importa: o reprocessamento (FR-017) roda a partir do payload preservado, sem
  contexto de coleta e sem consultar a origem. Resolver no conector faria a coleta
  produzir a organização e o reprocessamento produzir nulo, para o mesmo payload.

  Organização não encontrada deixa `organization_id` nulo em vez de falhar. A equipe
  existe e foi observada; o que falta é o vínculo, e a restrição do banco é quem
  decide se essa ausência é tolerável — ela é, para `project_team`, e não é para
  `organizational_team`.
  """
  @spec upsert_team_from_source(Tenant.t(), map()) ::
          {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
  def upsert_team_from_source(tenant, attrs) do
    attrs = attrs |> normalize() |> resolve_organization(tenant)
    upsert(Team, tenant, attrs)
  end

  defp resolve_organization(%{organization_external_id: external_id} = attrs, %Tenant{id: tid})
       when is_binary(external_id) do
    org_id =
      Repo.one(
        from o in Organization,
          where:
            o.tenant_id == ^tid and o.external_id == ^external_id and
              o.source_system == ^attrs[:source_system],
          select: o.id
      )

    attrs |> Map.delete(:organization_external_id) |> Map.put(:organization_id, org_id)
  end

  defp resolve_organization(attrs, _tenant), do: Map.delete(attrs, :organization_external_id)

  @doc """
  Atribui a organização a uma equipe já coletada (T011).

  Existe separada de `upsert_team_from_source/2` porque não é coleta: nada foi
  observado agora, e a proveniência da equipe não muda. Só o vínculo passa a existir,
  a partir de dado que já estava preservado.

  Não aceita `nil`: apagar o vínculo não é retrofito, e a assinatura recusar já evita
  o uso errado.
  """
  @spec assign_team_organization(Tenant.t(), Team.t(), Ecto.UUID.t()) ::
          {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
  def assign_team_organization(%Tenant{}, %Team{} = team, organization_id)
      when is_binary(organization_id) do
    team
    |> Team.from_source_changeset(%{organization_id: organization_id})
    |> Repo.update()
  end

  @derived_source "the_band"
  @derived_prefix "derived:default_team:"

  @doc """
  A equipe derivada de uma organização — regra `github.default_team` (FR-004, FR-005).

  Recebe a **organização já persistida**, e não o identificador externo dela, porque a
  equipe derivada só existe em função da organização: sem organização não há o que
  derivar, e receber o struct torna isso erro de compilação em vez de um `nil`
  descoberto no banco.

  **Quem chama não decide a proveniência.** `source_system` e `external_id` são
  montados aqui, e é o que impede o único jeito de esta feature mentir — gravar uma
  equipe derivada como se fosse observada. Não há parâmetro que permita isso.

  O `external_id` é determinístico a partir da organização, então reprocessar produz o
  mesmo identificador, o upsert reconhece, e nada duplica.
  """
  @spec upsert_derived_team(Tenant.t(), Organization.t(), map()) ::
          {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
  def upsert_derived_team(%Tenant{} = tenant, %Organization{} = organization, attrs \\ %{}) do
    now = DateTime.utc_now(:second)

    attrs =
      attrs
      |> normalize()
      |> Map.merge(%{
        type: "organizational_team",
        name: organization.name || organization.login,
        organization_id: organization.id,
        source_system: @derived_source,
        source_instance: organization.source_instance,
        external_id: @derived_prefix <> organization.external_id,
        collected_at: now,
        last_observed_at: now,
        no_longer_observed_at: nil
      })

    upsert(Team, tenant, attrs)
  end

  @doc """
  Vínculo de uma pessoa com a equipe derivada (FR-006).

  Sem nível de acesso, e a função **não aceita um**: a origem não conhece este
  vínculo, então não há o que ela informe sobre ele. `MAINTAINER` e `MEMBER` são o que
  ela diz de vínculos que conhece.
  """
  @spec record_derived_team_membership(Tenant.t(), map()) ::
          {:ok, TeamMembershipEvidence.t()} | {:error, Ecto.Changeset.t()}
  def record_derived_team_membership(%Tenant{} = tenant, attrs) do
    attrs =
      attrs
      |> normalize()
      |> Map.merge(%{
        platform_access_level: nil,
        source_system: @derived_source
      })

    record_team_membership_evidence(tenant, attrs)
  end

  @doc """
  A equipe derivada que ficou sem integrantes é **marcada**, nunca apagada (T023, FR-008).

  Uma equipe que existiu e esvaziou é informação: diz que aquela organização mantinha
  gente fora de qualquer time, e deixou de manter. Apagar perderia isso, e a próxima
  coleta recriaria a equipe como se fosse nova.

  Os vínculos dela também não são apagados — ficam marcados como não mais observados
  pelo mesmo mecanismo que trata a ausência em equipe observada. Ausência não é
  remoção, e a regra não muda por a equipe ser derivada.
  """
  @spec retire_derived_team(Tenant.t(), Team.t()) ::
          {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
  def retire_derived_team(%Tenant{id: tenant_id}, %Team{} = team) do
    now = DateTime.utc_now(:second)

    Repo.update_all(
      from(e in TeamMembershipEvidence,
        where:
          e.tenant_id == ^tenant_id and e.team_id == ^team.id and
            is_nil(e.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: now]
    )

    team
    |> Team.from_source_changeset(%{no_longer_observed_at: now})
    |> Repo.update()
  end

  @doc "Se a equipe é derivada, pela proveniência — nenhuma coluna nova responde isto."
  @spec derived_team?(Team.t()) :: boolean()
  def derived_team?(%Team{source_system: @derived_source, external_id: external_id}),
    do: String.starts_with?(external_id || "", @derived_prefix)

  def derived_team?(%Team{}), do: false

  @doc "Prefixo do identificador de equipe derivada, para consultas e invariantes."
  @spec derived_prefix() :: String.t()
  def derived_prefix, do: @derived_prefix

  @doc "Sistema de origem das entidades que a plataforma deriva."
  @spec derived_source() :: String.t()
  def derived_source, do: @derived_source

  # ------------------------------------------------------------------ evidência

  @spec record_team_membership_evidence(Tenant.t(), map()) ::
          {:ok, TeamMembershipEvidence.t()} | {:error, Ecto.Changeset.t()}
  def record_team_membership_evidence(%Tenant{id: tenant_id}, attrs) do
    attrs = normalize(attrs)
    now = attrs[:observed_at] || DateTime.utc_now(:second)

    attrs =
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:observed_at, now)
      |> Map.put(:last_observed_at, now)

    existing =
      Repo.one(
        from e in TeamMembershipEvidence,
          where:
            e.tenant_id == ^tenant_id and
              e.source_system == ^attrs[:source_system] and
              e.source_instance == ^attrs[:source_instance] and
              e.person_external_id == ^attrs[:person_external_id] and
              e.team_external_id == ^attrs[:team_external_id]
      )

    case existing do
      nil ->
        %TeamMembershipEvidence{}
        |> TeamMembershipEvidence.changeset(attrs)
        |> Repo.insert()
        |> with_outcome(:created)

      record ->
        # Reobservar não é um vínculo novo: atualiza a última observação e
        # limpa a marca de ausência, preservando observed_at original.
        record
        |> TeamMembershipEvidence.changeset(%{
          last_observed_at: now,
          no_longer_observed_at: nil,
          platform_access_level: attrs[:platform_access_level]
        })
        |> Repo.update()
        |> with_outcome(:unchanged)
    end
  end

  @doc """
  Marca como não mais observados os vínculos que não apareceram nesta coleta.

  Ausência não é remoção: a plataforma não recebe evento de remoção, apenas percebe a
  ausência por comparação entre coletas. Nada é apagado.

  ## O escopo da organização não é opcional (L19)

  `organization_id` é obrigatório, e a versão anterior desta função não o tinha — filtrava
  só por tenant. O efeito era que **coletar uma organização marcava os vínculos das
  outras**, porque eles não haviam aparecido *naquela* coleta. E não apareceriam: são de
  outra organização.

  Medido no banco de desenvolvimento antes da correção: os 7 vínculos de
  `The-Band-Solution` e 55 dos 70 de `leds-conectafapes` marcados **no mesmo instante**, e
  `EduardoNFraiz` aparecendo com zero organizações vigentes estando em duas observadas.

  "Não apareceu" só significa algo em relação **ao que foi olhado**. A coleta olha uma
  organização por vez, então a comparação também é por organização.
  """
  @spec mark_evidence_no_longer_observed(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, non_neg_integer()}
  def mark_evidence_no_longer_observed(
        %Tenant{id: tenant_id},
        organization_id,
        collection_started_at
      )
      when is_binary(organization_id) do
    equipes_da_org =
      from t in Team,
        where: t.tenant_id == ^tenant_id and t.organization_id == ^organization_id,
        select: t.id

    {count, _} =
      Repo.update_all(
        from(e in TeamMembershipEvidence,
          where:
            e.tenant_id == ^tenant_id and
              e.team_id in subquery(equipes_da_org) and
              e.last_observed_at < ^collection_started_at and
              is_nil(e.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: DateTime.utc_now(:second)]
      )

    {:ok, count}
  end

  @doc """
  Marca como não mais observado o que dependia de uma organização encerrada (T007).

  **A ordem é a razão de esta função existir num lugar só**: equipes, depois vínculos,
  depois pessoas. As pessoas por último porque a decisão depende dos vínculos já
  marcados — uma pessoa é marcada quando não lhe resta nenhum vínculo vigente, e isso só
  é verdade depois de os vínculos terem sido marcados.

  Inverter marcaria pessoa que ainda tinha vínculo. Em `ifesserra-lab` marcaria `Paulo`,
  que continua observado em `The-Band-Solution` e `leds-conectafapes` — e é exatamente o
  defeito que a primeira versão da especificação tinha.

  **Nada é apagado.** A equipe derivada é marcada como qualquer outra: ela existiu, e a
  contagem de equipes derivadas é informação sobre a origem (FR-010).

  A pessoa não tem proveniência por ferramenta — uma linha, uma proveniência, e
  `source_instance` é o mesmo para todas as organizações do mesmo GitHub. O que pertence
  a cada ferramenta é o vínculo (research.md R2).
  """
  @spec mark_organization_no_longer_observed(Tenant.t(), String.t()) ::
          {:ok, %{teams: non_neg_integer(), links: non_neg_integer(), people: non_neg_integer()}}
  def mark_organization_no_longer_observed(%Tenant{id: tenant_id} = tenant, organization_login) do
    now = DateTime.utc_now(:second)

    case Queries.fetch_organization_by_login(tenant_id, organization_login) do
      nil ->
        {:ok, %{teams: 0, links: 0, people: 0}}

      organization ->
        {teams, links, people} = do_mark(tenant, organization, now)
        {:ok, %{teams: teams, links: links, people: people}}
    end
  end

  # Uma função por etapa, e a ordem das chamadas **é** a regra: equipes, vínculos,
  # pessoas. As pessoas por último porque a decisão delas depende dos vínculos já
  # marcados.
  defp do_mark(%Tenant{id: tenant_id}, organization, now) do
    equipes = equipes_da_organizacao(tenant_id, organization.id)

    {
      mark_teams(tenant_id, organization.id, now),
      mark_links(tenant_id, equipes, now),
      mark_people(tenant_id, equipes, now)
    }
  end

  defp equipes_da_organizacao(tenant_id, organization_id) do
    from t in Team,
      where: t.tenant_id == ^tenant_id and t.organization_id == ^organization_id,
      select: t.id
  end

  defp mark_teams(tenant_id, organization_id, now) do
    {count, _} =
      Repo.update_all(
        from(t in Team,
          where:
            t.tenant_id == ^tenant_id and t.organization_id == ^organization_id and
              is_nil(t.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: now]
      )

    count
  end

  defp mark_links(tenant_id, equipes, now) do
    {count, _} =
      Repo.update_all(
        from(e in TeamMembershipEvidence,
          where:
            e.tenant_id == ^tenant_id and e.team_id in subquery(equipes) and
              is_nil(e.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: now]
      )

    count
  end

  # Chamada **depois** de `mark_links/3`: uma pessoa é marcada quando não lhe resta
  # nenhum vínculo vigente, e isso só é verdade depois de os vínculos terem sido
  # marcados. Inverter marcaria pessoa que ainda tinha vínculo.
  defp mark_people(tenant_id, equipes, now) do
    com_vinculo_vigente =
      from e in TeamMembershipEvidence,
        where: e.tenant_id == ^tenant_id and is_nil(e.no_longer_observed_at),
        select: e.person_id

    pessoas_da_org =
      from e in TeamMembershipEvidence,
        where: e.tenant_id == ^tenant_id and e.team_id in subquery(equipes),
        select: e.person_id

    {count, _} =
      Repo.update_all(
        from(p in Person,
          where:
            p.tenant_id == ^tenant_id and p.id in subquery(pessoas_da_org) and
              p.id not in subquery(com_vinculo_vigente) and is_nil(p.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: now]
      )

    count
  end

  # ---------------------------------------------------------------------- upsert

  defp upsert(schema, %Tenant{id: tenant_id}, attrs) do
    attrs =
      attrs
      |> normalize()
      |> Map.put(:tenant_id, tenant_id)

    attrs = Map.put_new(attrs, :internal_id, internal_id(tenant_id, attrs))

    # A proveniência é conferida **antes** da consulta. Sem isso a busca pela
    # Application Reference compararia colunas com nil, o que o Ecto proíbe — e o
    # resultado seria uma exceção de query no lugar do erro de changeset que quem
    # chamou espera tratar.
    if complete_application_reference?(attrs) do
      case find_by_application_reference(schema, tenant_id, attrs) do
        nil ->
          struct(schema)
          |> schema.from_source_changeset(attrs)
          |> Repo.insert()
          |> with_outcome(:created)

        record ->
          update_existing(schema, record, attrs)
      end
    else
      {:error, schema.from_source_changeset(struct(schema), attrs)}
    end
  end

  defp complete_application_reference?(attrs) do
    Enum.all?([:source_system, :source_instance, :external_id, :collected_at], fn field ->
      Map.get(attrs, field) not in [nil, ""]
    end)
  end

  defp update_existing(schema, record, attrs) do
    if changed?(schema, record, attrs) do
      record
      |> schema.from_source_changeset(Map.put(attrs, :record_version, record.record_version + 1))
      |> Repo.update()
      |> with_outcome(:updated)
    else
      # Nada mudou na origem: não se escreve, e record_version fica onde está.
      # É o que SC-003 verifica.
      {:ok, %{record | outcome: :unchanged}}
    end
  end

  defp changed?(schema, record, attrs) do
    @comparable
    |> Map.fetch!(schema)
    |> Enum.any?(fn field ->
      Map.has_key?(attrs, field) and Map.get(attrs, field) != Map.get(record, field)
    end)
  end

  defp find_by_application_reference(schema, tenant_id, attrs) do
    Repo.one(
      from r in schema,
        where:
          r.tenant_id == ^tenant_id and
            r.source_system == ^attrs[:source_system] and
            r.source_instance == ^attrs[:source_instance] and
            r.external_id == ^attrs[:external_id]
    )
  end

  # Identidade estável entre módulos ontológicos, derivada da Application
  # Reference. Determinística de propósito: a mesma entidade de origem produz o
  # mesmo internal_id em qualquer reprocessamento.
  defp internal_id(tenant_id, attrs) do
    [tenant_id, attrs[:source_system], attrs[:source_instance], attrs[:external_id]]
    |> Enum.map_join("|", &to_string/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp with_outcome({:ok, record}, outcome), do: {:ok, %{record | outcome: outcome}}
  defp with_outcome(other, _outcome), do: other

  defp normalize(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  # ------------------------------------------------------- papéis e alocação (feature 021)

  @doc """
  Cadastra um papel organizacional reconhecido pelo tenant (FR-001, FR-002).

  **O código é a identidade**, e o índice único por `(tenant_id, code)` já existia. O mesmo
  código em outro tenant é aceito: papel é reconhecimento de uma organização, e duas
  organizações reconhecerem "developer" não é conflito.
  """
  @spec create_role(Tenant.t(), map()) ::
          {:ok, OrganizationalRole.t()} | {:error, Ecto.Changeset.t()}
  def create_role(%Tenant{id: tenant_id}, attrs) do
    attrs = normalize(attrs)
    codigo = attrs |> Map.get(:code) |> to_string() |> String.trim()

    %OrganizationalRole{}
    |> OrganizationalRole.changeset(%{
      tenant_id: tenant_id,
      code: codigo,
      name: attrs[:name],
      internal_id: papel_internal_id(tenant_id, codigo)
    })
    |> Repo.insert()
  end

  @doc """
  Renomeia o papel, **sem tocar no código** (FR-004).

  É pelo código que os vínculos referenciam o papel. Trocá-lo seria trocar a identidade, e a
  renomeação é do rótulo.
  """
  @spec rename_role(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, OrganizationalRole.t()} | {:error, :not_found | :blank_name}
  def rename_role(%Tenant{} = tenant, role_id, name) do
    with {:ok, papel} <- Queries.fetch_role(tenant, role_id),
         {:ok, nome} <- nome_preenchido(name) do
      {1, _} =
        Repo.update_all(
          from(r in OrganizationalRole, where: r.id == ^papel.id),
          set: [name: nome, updated_at: DateTime.utc_now(:second)]
        )

      {:ok, %{papel | name: nome}}
    end
  end

  @doc """
  Remove um papel, e **recusa** quando há vínculo apontando para ele (FR-005).

  A recusa devolve **quantos** são, e não só o erro: quem lê precisa saber o tamanho do que a
  impede. É a mesma regra do impacto exibido antes de encerrar uma observação.
  """
  @spec delete_role(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, OrganizationalRole.t()} | {:error, :not_found | {:in_use, pos_integer()}}
  def delete_role(%Tenant{} = tenant, role_id) do
    with {:ok, papel} <- Queries.fetch_role(tenant, role_id) do
      case Queries.count_memberships_of_role(tenant, papel.id) do
        0 ->
          {:ok, _} = Repo.delete(papel)
          {:ok, papel}

        quantos ->
          {:error, {:in_use, quantos}}
      end
    end
  end

  @doc """
  Aloca uma pessoa a um papel dentro de uma equipe (FR-006, FR-007, FR-009).

  ## O que ela recusa, e o que ela permite

  `{:error, :already_allocated}` é a mesma pessoa, mesmo papel, mesma equipe, com período
  vigente. **Dois papéis diferentes ao mesmo tempo são permitidos** — acumular Developer e
  Scrum Master é comum em Scrum, e recusar produziria uma plataforma incapaz de descrever
  times reais.

  ## `started_at` ausente grava nulo

  E nunca a data de hoje. Inventá-la afirmaria que a alocação começou agora, e o que se sabe é
  que ninguém disse quando.

  ## A evidência aponta para o vínculo

  Quando `evidence_id` vem junto, `promoted_membership_id` passa a apontar — e a evidência
  **continua existindo**, com tudo o que ela tinha.
  """
  @spec allocate(Tenant.t(), map()) ::
          {:ok, TeamMembership.t()}
          | {:error, :period_inverted | :already_allocated | Ecto.Changeset.t()}
  def allocate(%Tenant{id: tenant_id} = tenant, attrs) do
    attrs = normalize(attrs)

    changeset =
      TeamMembership.changeset(%TeamMembership{}, %{
        tenant_id: tenant_id,
        person_id: attrs[:person_id],
        team_id: attrs[:team_id],
        organizational_role_id: attrs[:organizational_role_id],
        started_at: attrs[:started_at],
        ended_at: attrs[:ended_at],
        declared_by_user_id: attrs[:declared_by_user_id],
        internal_id:
          alocacao_internal_id(
            tenant_id,
            attrs[:person_id],
            attrs[:team_id],
            attrs[:organizational_role_id]
          )
      })

    case Repo.insert(changeset) do
      {:ok, vinculo} ->
        apontar_evidencia(tenant, attrs[:evidence_id], vinculo.id)
        {:ok, vinculo}

      {:error, %Ecto.Changeset{errors: erros} = changeset} ->
        cond do
          Keyword.has_key?(erros, :ended_at) -> {:error, :period_inverted}
          duplicata?(changeset) -> {:error, :already_allocated}
          true -> {:error, changeset}
        end
    end
  end

  @doc """
  Encerra a alocação gravando a data de fim (FR-010).

  **Não apaga.** A pessoa desempenhou aquele papel, e isso continua verdade depois de ela sair.

  Encerrar de novo devolve `{:error, :already_ended}` e **não reescreve** a data da primeira: a
  segunda tentativa é engano de quem opera, e sobrescrever perderia quando de fato terminou.
  """
  @spec end_allocation(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, TeamMembership.t()} | {:error, :not_found | :already_ended}
  def end_allocation(%Tenant{} = tenant, membership_id, quando) do
    with {:ok, vinculo} <- Queries.fetch_membership(tenant, membership_id) do
      if vinculo.ended_at do
        {:error, :already_ended}
      else
        {1, _} =
          Repo.update_all(
            from(m in TeamMembership, where: m.id == ^vinculo.id),
            set: [ended_at: quando, updated_at: DateTime.utc_now(:second)]
          )

        {:ok, %{vinculo | ended_at: quando}}
      end
    end
  end

  defp apontar_evidencia(_tenant, nil, _membership_id), do: :ok

  defp apontar_evidencia(%Tenant{id: tenant_id}, evidence_id, membership_id) do
    Repo.update_all(
      from(e in TeamMembershipEvidence,
        where: e.tenant_id == ^tenant_id and e.id == ^evidence_id
      ),
      set: [promoted_membership_id: membership_id, updated_at: DateTime.utc_now(:second)]
    )

    :ok
  end

  # A duplicata vem do índice parcial, e não de validação: só o banco sabe o que está vigente
  # no instante da escrita.
  defp duplicata?(%Ecto.Changeset{errors: erros}) do
    Enum.any?(erros, fn {_campo, {_msg, opts}} ->
      Keyword.get(opts, :constraint) == :unique
    end)
  end

  defp nome_preenchido(nome) do
    case String.trim(to_string(nome)) do
      "" -> {:error, :blank_name}
      trimmed -> {:ok, trimmed}
    end
  end

  # Determinístico, como o dos observados — mas a chave é o que identifica o papel dentro do
  # tenant, porque não há origem externa: o papel é declaração.
  defp papel_internal_id(tenant_id, codigo) do
    hash_de([tenant_id, "role", codigo])
  end

  defp alocacao_internal_id(tenant_id, person_id, team_id, role_id) do
    hash_de([tenant_id, "membership", person_id, team_id, role_id])
  end

  defp hash_de(partes) do
    partes
    |> Enum.map_join("|", &to_string/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end
end
