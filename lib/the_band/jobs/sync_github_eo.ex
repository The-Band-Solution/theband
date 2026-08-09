defmodule TheBand.Jobs.SyncGitHubEO do
  @moduledoc """
  Coleta organização, pessoas e equipes do GitHub para a Enterprise Ontology.

  Percorre quatro entidades em ordem, com checkpoint por entidade: a organização,
  os membros da organização, os times, e os integrantes de cada time. Os dois
  conjuntos de pessoas não coincidem, e coletar só um daria visão parcial sem que
  a pessoa usuária soubesse.

  ## Como as garantias são obtidas

    * **idempotência** (FR-014) — vem do upsert por Application Reference no
      módulo EO, não daqui;
    * **retomada** (FR-015) — o cursor é gravado depois de cada página, e o job
      retoma do checkpoint;
    * **rate limit** (FR-016) — `{:snooze, segundos}` devolve o job à fila até a
      janela reabrir. Nunca `Process.sleep`: segurar o processo bloquearia a fila
      inteira e faria a pausa parecer travamento;
    * **uma por ferramenta** (FR-018) — `unique` aqui, mais o índice parcial no
      banco.
  """

  use Oban.Worker, queue: :ingestion, max_attempts: 5, unique: [period: 300, fields: [:args]]

  require Logger

  alias TheBand.Ingestion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.SemanticIntegration.Mapper
  alias TheBand.Sources
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants

  @page_size 50

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "sync_id" => sync_id}}) do
    # O tenant vem nos args e é validado antes de qualquer coisa acontecer.
    with {:ok, tenant} <- Tenants.fetch(tenant_id),
         {:ok, sync} <- Ingestion.fetch_sync(tenant, sync_id),
         {:ok, tool} <- Sources.fetch_connected_tool(tenant, sync.connected_tool_id),
         %ToolCredential{} = credential <- Sources.active_credential(tool) do
      run(tenant, sync, tool, credential)
    else
      nil ->
        {:error, :no_active_credential}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run(tenant, sync, tool, credential) do
    started_at = sync.started_at

    ctx = %{
      tenant: tenant,
      sync: sync,
      tool: tool,
      token: credential.secret,
      org: tool.organization_login
    }

    case collect(ctx) do
      :ok ->
        {:ok, _} = EO.mark_evidence_no_longer_observed(tenant, started_at)
        pending = EO.count_evidence_pending_role(tenant)

        sync
        |> Ingestion.reload()
        |> Ingestion.finish(:completed, memberships_pending_role: pending)

        Sources.touch_last_sync(tool)
        Sources.clear_needs_attention(tool)
        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        :ok

      {:snooze, seconds} ->
        Ingestion.broadcast(tenant.id, {:sync_paused, sync.id, seconds})
        {:snooze, seconds}

      {:error, :unauthorized} ->
        # Credencial revogada no meio da coleta: interrupção controlada, progresso
        # parcial preservado, ferramenta marcada. As demais seguem normais.
        Sources.mark_needs_attention(tool, "credencial recusada pela ferramenta durante a coleta")

        sync
        |> Ingestion.reload()
        |> Ingestion.finish(:interrupted, error_reason: "credencial recusada durante a coleta")

        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        {:error, :unauthorized}

      {:error, reason} ->
        sync |> Ingestion.reload() |> Ingestion.finish(:failed, error_reason: inspect(reason))
        Ingestion.broadcast(tenant.id, {:sync_finished, sync.id})
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------ coleta

  defp collect(ctx) do
    with :ok <- collect_organization(ctx),
         :ok <- paginate(ctx, "github.user", "organization_members", &handle_member/2),
         :ok <- paginate(ctx, "github.team", "teams", &handle_team/2) do
      collect_team_members(ctx)
    end
  end

  defp collect_organization(ctx) do
    case query(ctx, "organization", %{organization: ctx.org}) do
      {:ok, %{data: %{"organization" => nil}}} ->
        {:error, {:organization_not_found, ctx.org}}

      {:ok, %{data: %{"organization" => node}}} ->
        store_and_upsert(
          ctx,
          node,
          "github.organization",
          "github.organization.to.eo.organization"
        )

        Ingestion.checkpoint_page(ctx.sync, "github.organization", nil, 1)
        :ok

      other ->
        normalize_error(other)
    end
  end

  defp collect_team_members(ctx) do
    ctx.tenant
    |> EO.list_teams()
    |> Enum.reduce_while(:ok, fn team, _acc ->
      case paginate(
             ctx,
             "github.team_member:#{team.slug}",
             "team_members",
             &handle_team_member(&1, &2, team),
             extra: %{team_slug: team.slug}
           ) do
        :ok -> {:cont, :ok}
        other -> {:halt, other}
      end
    end)
  end

  # Paginação genérica: uma página por vez, checkpoint depois de processar.
  defp paginate(ctx, entity_type, query_name, handler, opts \\ []) do
    cursor = Ingestion.resume_cursor(ctx.sync, entity_type)
    do_paginate(ctx, entity_type, query_name, handler, cursor, opts)
  end

  defp do_paginate(ctx, entity_type, query_name, handler, cursor, opts) do
    variables =
      %{organization: ctx.org, page_size: @page_size}
      |> Map.merge(Keyword.get(opts, :extra, %{}))
      |> then(fn vars -> if cursor, do: Map.put(vars, :after, cursor), else: vars end)

    case query(ctx, query_name, variables) do
      {:ok, %{data: data, rate_limit: rate_limit}} ->
        {nodes, page_info} = extract(data, query_name)
        Enum.each(nodes, &handler.(ctx, &1))

        next_cursor = if page_info["hasNextPage"], do: page_info["endCursor"], else: nil
        # Depois de processar, nunca antes. Reprocessar a última página é seguro
        # porque a ingestão é idempotente; perdê-la não seria.
        Ingestion.checkpoint_page(ctx.sync, entity_type, next_cursor, length(nodes))

        Ingestion.broadcast(
          ctx.tenant.id,
          {:sync_progress, ctx.sync.id, entity_type, length(nodes)}
        )

        cond do
          is_nil(next_cursor) ->
            :ok

          match?({:pause_until, _}, Client.pause_needed?(rate_limit)) ->
            {:pause_until, reset_at} = Client.pause_needed?(rate_limit)
            {:snooze, max(DateTime.diff(reset_at, DateTime.utc_now()), 1)}

          true ->
            do_paginate(ctx, entity_type, query_name, handler, next_cursor, opts)
        end

      other ->
        normalize_error(other)
    end
  end

  # ------------------------------------------------------------- transformação

  defp handle_member(ctx, node) do
    store_and_upsert(ctx, node, "github.user", "github.user.to.eo.person")
  end

  defp handle_team(ctx, node) do
    store_and_upsert(ctx, node, "github.team", "github.team.to.eo.organizational_team")
  end

  defp handle_team_member(ctx, edge, team) do
    node = edge["node"]
    level = edge["role"]

    with {:ok, person} <-
           store_and_upsert(ctx, node, "github.team_member", "github.team_member.to.eo.person"),
         :ok <- EO.check_evidence(%{platform_access_level: level}) do
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: person.id,
        team_id: team.id,
        person_external_id: node["id"],
        team_external_id: team.external_id,
        # Nível de acesso na plataforma. Não vira papel organizacional, e a
        # invariante acima é o que impede que vire por descuido futuro.
        platform_access_level: level,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        observed_at: DateTime.utc_now(:second)
      })
    else
      {:error, reason} ->
        ctx.sync |> Ingestion.reload() |> Ingestion.tally({:skipped, to_string(inspect(reason))})
        {:error, reason}
    end
  end

  defp store_and_upsert(ctx, node, raw_entity_type, mapping_id) do
    now = DateTime.utc_now(:second)

    RawData.store(%{
      tenant_id: ctx.tenant.id,
      sync_id: ctx.sync.id,
      raw_entity_type: raw_entity_type,
      external_id: node["id"],
      payload: node,
      mapping_id: mapping_id,
      mapping_version: Mapper.version(mapping_id),
      source_system: "github",
      source_instance: ctx.tool.instance_url,
      collected_at: now
    })

    with {:ok, mapped} <- Mapper.apply_mapping(mapping_id, node) do
      attrs =
        mapped
        |> Map.merge(%{
          source_system: "github",
          source_instance: ctx.tool.instance_url,
          external_id: node["id"],
          collected_at: now,
          last_observed_at: now,
          no_longer_observed_at: nil
        })
        |> put_defaults(raw_entity_type, node)

      result = write(ctx, raw_entity_type, attrs)

      case result do
        {:ok, record} ->
          ctx.sync |> Ingestion.reload() |> Ingestion.tally(record.outcome || :unchanged)
          {:ok, record}

        {:error, changeset} ->
          reason = changeset_reason(changeset)
          ctx.sync |> Ingestion.reload() |> Ingestion.tally({:skipped, reason})
          Logger.warning("registro ignorado em #{raw_entity_type}: #{reason}")
          {:error, reason}
      end
    end
  end

  defp write(ctx, "github.organization", attrs),
    do: EO.upsert_organization_from_source(ctx.tenant, attrs)

  defp write(ctx, "github.team", attrs), do: EO.upsert_team_from_source(ctx.tenant, attrs)
  defp write(ctx, _person_like, attrs), do: EO.upsert_person_from_source(ctx.tenant, attrs)

  # Complementos que o mapeamento não declara porque não são atributos do
  # conceito: o login usado como nome quando a conta não tem nome preenchido, e a
  # classificação de automação, que vem do __typename e não de um campo.
  defp put_defaults(attrs, "github.organization", node) do
    attrs
    |> Map.put(:login, node["login"])
    |> Map.put_new(:name, node["login"])
  end

  defp put_defaults(attrs, "github.team", node) do
    attrs
    |> Map.put(:type, "organizational_team")
    |> Map.put_new(:name, node["name"] || node["slug"])
    |> Map.put(:external_created_at, parse_datetime(node["createdAt"]))
  end

  defp put_defaults(attrs, _person_like, node) do
    attrs
    |> Map.put(:login, node["login"])
    # Conta sem nome preenchido é registrada mesmo assim, identificada pelo login.
    |> Map.put(:name, node["name"] || node["login"])
    |> Map.put(:account_type, account_type(node))
  end

  defp account_type(%{"__typename" => "Bot"}), do: "bot"
  defp account_type(%{"__typename" => "App"}), do: "app"

  defp account_type(%{"login" => login}) when is_binary(login) do
    if String.ends_with?(login, "[bot]"), do: "bot", else: "person"
  end

  defp account_type(_), do: "person"

  # ------------------------------------------------------------------ auxiliares

  defp query(ctx, name, variables) do
    Client.graphql(ctx.tool.instance_url, ctx.token, read_query(name), variables)
  end

  defp read_query(name) do
    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{name}.graphql")
    |> File.read!()
  end

  defp extract(data, "organization_members") do
    page = get_in(data, ["organization", "membersWithRole"]) || %{}
    {page["nodes"] || [], page["pageInfo"] || %{}}
  end

  defp extract(data, "teams") do
    page = get_in(data, ["organization", "teams"]) || %{}
    {page["nodes"] || [], page["pageInfo"] || %{}}
  end

  defp extract(data, "team_members") do
    page = get_in(data, ["organization", "team", "members"]) || %{}
    {page["edges"] || [], page["pageInfo"] || %{}}
  end

  defp normalize_error({:error, :unauthorized}), do: {:error, :unauthorized}
  defp normalize_error({:error, reason}), do: {:error, reason}
  defp normalize_error(other), do: {:error, other}

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp changeset_reason(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
