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

  alias TheBand.Ontology.SEON.EO.Schemas.Organization
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Ontology.SEON.EO.Schemas.Team
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

  Ausência não é remoção: a plataforma não recebe evento de remoção, apenas
  percebe a ausência por comparação entre coletas. Nada é apagado.
  """
  @spec mark_evidence_no_longer_observed(Tenant.t(), DateTime.t()) :: {:ok, non_neg_integer()}
  def mark_evidence_no_longer_observed(%Tenant{id: tenant_id}, collection_started_at) do
    {count, _} =
      Repo.update_all(
        from(e in TeamMembershipEvidence,
          where:
            e.tenant_id == ^tenant_id and
              e.last_observed_at < ^collection_started_at and
              is_nil(e.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: DateTime.utc_now(:second)]
      )

    {:ok, count}
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
end
