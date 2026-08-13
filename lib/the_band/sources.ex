defmodule TheBand.Sources do
  @moduledoc """
  Ferramentas conectadas e credenciais (US1).

  A credencial é **validada contra a ferramenta antes de ser gravada** (FR-006).
  Quando a validação falha, nada é gravado — nem a ferramenta, nem a credencial.
  Gravar a ferramenta e deixar a credencial para depois produziria uma conexão
  meio-feita que ninguém sabe se funciona.
  """

  import Ecto.Query

  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ObservationEvent
  alias TheBand.Sources.ToolCredential
  alias TheBand.Tenants.Tenant

  # ---------------------------------------------------------------------- leitura

  @spec list_connected_tools(Tenant.t()) :: [ConnectedTool.t()]
  def list_connected_tools(%Tenant{id: tenant_id}) do
    Repo.all(
      from t in ConnectedTool,
        where: t.tenant_id == ^tenant_id,
        order_by: [asc: t.tool_type, asc: t.instance_url],
        preload: [:credentials]
    )
  end

  @spec fetch_connected_tool(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, ConnectedTool.t()} | {:error, :not_found}
  def fetch_connected_tool(%Tenant{id: tenant_id}, id) do
    query =
      from t in ConnectedTool,
        where: t.tenant_id == ^tenant_id and t.id == ^id,
        preload: [:credentials]

    case Repo.one(query) do
      # FR-027 — id de outro tenant devolve :not_found, nunca o registro.
      nil -> {:error, :not_found}
      tool -> {:ok, tool}
    end
  end

  @doc """
  A credencial que a coleta usa, entre as ativas.

  A ordem é a validada mais recentemente, e os dois desempates existem para
  tornar a escolha **determinística** — não para expressar preferência.

  Sem eles, duas credenciais cadastradas no mesmo segundo empatavam em
  `validated_at`, e o banco resolvia o empate na ordem que quisesse: o mesmo
  estado escolhia credenciais diferentes entre execuções. Credenciais diferentes
  enxergam conjuntos diferentes, então a mesma sincronização traria dados
  diferentes sem nada ter mudado na origem.

  Quem quer controlar qual credencial é usada desativa as outras.
  """
  @spec active_credential(ConnectedTool.t()) :: ToolCredential.t() | nil
  def active_credential(%ConnectedTool{id: tool_id}) do
    Repo.one(
      from c in ToolCredential,
        where: c.connected_tool_id == ^tool_id and c.active == true,
        order_by: [desc: c.validated_at, desc: c.inserted_at, asc: c.id],
        limit: 1
    )
  end

  # ------------------------------------------------------ ciclo de observação

  @doc """
  A observação desta ferramenta foi encerrada? (T004, FR-008, FR-022)

  Derivada do **último evento**, e não de uma coluna: encerrar e retomar são eventos, e
  o estado é situação — ADR 0004 D7. Uma coluna guardaria um ciclo, e encerrar e
  reconectar no mesmo dia produz três transições.

  **Sem evento é vigente.** É o que faz as ferramentas já cadastradas continuarem
  observadas sem migração de dado: estado ausente significa "nunca foi encerrada", que
  é a verdade.

  Esta função é o **único** caminho de derivação. A tela e o filtro de coleta a usam, e
  dois caminhos discordariam — a plataforma coletaria do que a tela mostra como
  encerrado.
  """
  @spec observation_ended?(ConnectedTool.t()) :: boolean()
  def observation_ended?(%ConnectedTool{id: tool_id}) do
    Repo.one(
      from e in ObservationEvent,
        where: e.connected_tool_id == ^tool_id,
        order_by: [desc: e.occurred_at, desc: e.inserted_at],
        limit: 1,
        select: e.event
    ) == "ended"
  end

  @doc """
  A situação da ferramenta, **derivada** — issue #178.

  ## Por que a coluna saiu

  `connected_tools.status` materializava o que os eventos já dizem, contra a ADR 0004 D7 — e
  **discordava deles**. Medido em 2026-08-13: `ifesserra-lab` tem cinco eventos de observação, o
  último `ended`, e a coluna dizia `active`. `end_observation/3` grava o evento, destrói as
  credenciais e marca a organização — e nunca tocou nela.

  **A tela não chegou a mentir**, e é por isso que ninguém notou: ela já derivava o encerramento
  por `observation_ended?/1` e só lia a coluna no resto. A coluna era um terceiro lugar guardando o
  mesmo fato, esperando alguém confiar nela.

  ## A ordem das três respostas

  1. **encerrada** vence tudo — quem encerrou não precisa de atenção, precisa retomar;
  2. **precisa de atenção** sai de `needs_attention_since`, que é fato datado — a coluna registra
     **quando** se notou, e a situação vem dela;
  3. **ativa** é o resto.

  `disabled` sai do vocabulário: **nenhuma linha do código o escrevia**. Estado que nunca acontece é
  estado que quem lê precisa considerar à toa.
  """
  @spec situacao(ConnectedTool.t()) :: :ended | :needs_attention | :active
  def situacao(%ConnectedTool{} = tool) do
    cond do
      observation_ended?(tool) -> :ended
      not is_nil(tool.needs_attention_since) -> :needs_attention
      true -> :active
    end
  end

  @doc """
  Quando a observação foi encerrada, ou `nil` se estiver vigente.

  Existe para a tela, que precisa dizer **desde quando** — e usa a mesma leitura do
  último evento que `observation_ended?/1`, para não haver duas derivações.
  """
  @spec observation_ended_at(ConnectedTool.t()) :: DateTime.t() | nil
  def observation_ended_at(%ConnectedTool{id: tool_id}) do
    Repo.one(
      from e in ObservationEvent,
        where: e.connected_tool_id == ^tool_id,
        order_by: [desc: e.occurred_at, desc: e.inserted_at],
        limit: 1,
        select: {e.event, e.occurred_at}
    )
    |> case do
      {"ended", at} -> at
      _ -> nil
    end
  end

  @doc """
  Os nomes das pessoas que **permanecem vigentes** se esta observação for encerrada.

  A tela mostra os nomes, e não um contador: "1 pessoa permanece" não deixa reconhecer
  quem é. É a informação que impede o mal-entendido central — quem não a vê supõe que
  encerrar remove a pessoa de todas as organizações.
  """
  @spec shared_people_names(Tenant.t(), ConnectedTool.t()) :: [String.t()]
  def shared_people_names(%Tenant{} = tenant, %ConnectedTool{} = tool) do
    EO.shared_people_names(tenant, tool.organization_login)
  end

  @doc "As transições desta ferramenta, na ordem em que ocorreram (FR-014)."
  @spec observation_history(Tenant.t(), ConnectedTool.t()) :: [ObservationEvent.t()]
  def observation_history(%Tenant{id: tenant_id}, %ConnectedTool{id: tool_id}) do
    Repo.all(
      from e in ObservationEvent,
        where: e.tenant_id == ^tenant_id and e.connected_tool_id == ^tool_id,
        order_by: [asc: e.occurred_at, asc: e.inserted_at]
    )
  end

  @doc """
  As ferramentas cuja observação está vigente (FR-008).

  É o que o enfileiramento de coleta usa. Ferramenta encerrada não entra, e o filtro
  passa por `observation_ended?/1` — o mesmo caminho da tela.
  """
  @spec list_observed_tools(Tenant.t()) :: [ConnectedTool.t()]
  def list_observed_tools(%Tenant{} = tenant) do
    tenant |> list_connected_tools() |> Enum.reject(&observation_ended?/1)
  end

  @doc """
  O que será marcado se a observação desta ferramenta for encerrada (T006, FR-002).

  É a **mesma função** que o encerramento usa para gravar `impact` no evento. Uma
  segunda contagem escrita para a tela divergiria da que age, e o número que a pessoa vê
  antes de confirmar tem de ser o que acontece.

  `people_exclusive` e `people_shared` são separados porque juntá-los esconde a única
  contagem que assusta. E `preserved_payloads` existe para dizer **zero apagados**.
  """
  @spec observation_impact(Tenant.t(), ConnectedTool.t()) :: map()
  def observation_impact(%Tenant{} = tenant, %ConnectedTool{} = tool) do
    EO.observation_impact(tenant, tool.organization_login)
  end

  @doc """
  Encerra a observação desta ferramenta (T009, FR-001 a FR-010).

  Na ordem, e a ordem não é arbitrária:

      1. confere a confirmação contra o organization_login
      2. calcula o impacto — a mesma função da tela
      3. numa única transação:
         a. grava o evento `ended`, com o impacto, o autor e o motivo
         b. marca equipes, vínculos e pessoas — nesta ordem
         c. destrói as credenciais
      4. interrompe a coleta em curso, se houver

  **As pessoas são marcadas por último** porque a decisão depende dos vínculos já
  marcados: uma pessoa é marcada quando não lhe resta nenhum vínculo vigente, e isso só
  é verdade depois de (b) ter marcado os vínculos. Inverter marcaria pessoa que ainda
  tinha vínculo — em `ifesserra-lab`, marcaria `Paulo`, que continua observado em duas
  outras organizações.

  **Tudo numa transação.** Um encerramento parcial — credencial destruída e registros
  não marcados — deixaria a plataforma coletando de ferramenta sem credencial e
  afirmando observar o que não observa.

  Encerrar ferramenta já encerrada devolve `{:ok, ...}` com impacto zerado e grava um
  segundo evento: alguém tentou, e o registro diz que tentou.
  """
  @spec end_observation(Tenant.t(), ConnectedTool.t(), map()) ::
          {:ok, map()} | {:error, :confirmation_mismatch | Ecto.Changeset.t()}
  def end_observation(%Tenant{} = tenant, %ConnectedTool{} = tool, attrs \\ %{}) do
    if field(attrs, "confirmation") == tool.organization_login do
      do_end_observation(tenant, tool, attrs)
    else
      {:error, :confirmation_mismatch}
    end
  end

  defp do_end_observation(%Tenant{id: tenant_id} = tenant, tool, attrs) do
    impact = observation_impact(tenant, tool)
    now = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      {:ok, event} =
        %ObservationEvent{}
        |> ObservationEvent.changeset(%{
          tenant_id: tenant_id,
          connected_tool_id: tool.id,
          event: "ended",
          occurred_at: now,
          actor_user_id: field(attrs, "actor_user_id"),
          reason: field(attrs, "reason"),
          impact: impact
        })
        |> Repo.insert()

      {:ok, marked} = EO.mark_organization_no_longer_observed(tenant, tool.organization_login)

      destroyed = destroy_all_credentials(tool)

      %{
        tool: tool,
        event: event,
        impact: impact,
        marked: marked,
        credentials_destroyed: destroyed
      }
    end)
  end

  @doc """
  Retoma uma observação encerrada, reusando a ferramenta existente (T012, FR-011 a FR-013).

  A identidade da ferramenta é tipo, instância e organização, e o índice de unicidade já
  garante — o que faltava era o evento. Reconectar não cria uma segunda linha: criaria
  duas proveniências para o mesmo dado.

  **Credencial nova é obrigatória**, porque a anterior foi destruída no encerramento. Não
  há parâmetro para reusar o que não existe.

  **A retomada não desmarca nada por si.** Só a coleta pode dizer se a origem ainda mostra
  o registro; desmarcar aqui ressuscitaria vínculo que a origem já não tem, e a plataforma
  afirmaria observação que não ocorreu. Quem devolve vigência é a coleta seguinte, ao
  reobservar.
  """
  @spec resume_observation(Tenant.t(), ConnectedTool.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def resume_observation(%Tenant{id: tenant_id}, %ConnectedTool{} = tool, attrs) do
    with {:ok, %{scopes: scopes}} <-
           Client.verify_credential(tool.instance_url, field(attrs, "secret")) do
      Repo.transaction(fn ->
        {:ok, event} =
          %ObservationEvent{}
          |> ObservationEvent.changeset(%{
            tenant_id: tenant_id,
            connected_tool_id: tool.id,
            event: "resumed",
            occurred_at: DateTime.utc_now(:second),
            actor_user_id: field(attrs, "actor_user_id"),
            reason: field(attrs, "reason")
          })
          |> Repo.insert()

        credential = insert_credential_or_rollback(tenant_id, tool, attrs, scopes)

        # A ferramenta volta ao estado ativo: o motivo de atenção, se havia, era da
        # credencial destruída — e ela não existe mais.
        {:ok, _} = clear_needs_attention(tool)

        %{tool: tool, event: event, credential: credential}
      end)
    end
  end

  # `Repo.rollback` e não `{:ok, _} =`: um changeset inválido é resposta da aplicação,
  # e derrubar o processo tiraria da tela a chance de dizer o que está errado.
  defp insert_credential_or_rollback(tenant_id, %ConnectedTool{} = tool, attrs, scopes) do
    case tenant_id |> credential_changeset(tool.id, attrs, scopes) |> Repo.insert() do
      {:ok, credential} -> credential
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp destroy_all_credentials(%ConnectedTool{id: tool_id}) do
    {count, _} = Repo.delete_all(from c in ToolCredential, where: c.connected_tool_id == ^tool_id)
    count
  end

  # --------------------------------------------------------------------- escrita

  @doc """
  Conecta uma ferramenta validando a credencial antes de gravar (FR-006).

  Devolve `{:error, :unauthorized}` ou `{:error, {:missing_scopes, escopos}}`
  quando a validação falha — e **nada** é gravado nesses casos.
  """
  @spec connect_tool(Tenant.t(), map()) ::
          {:ok, %{tool: ConnectedTool.t(), credential: ToolCredential.t()}}
          | {:error, term()}
  def connect_tool(%Tenant{} = tenant, attrs) do
    with {:ok, %{scopes: scopes}} <-
           Client.verify_credential(field(attrs, "instance_url"), field(attrs, "secret")) do
      insert_tool_and_credential(tenant, attrs, scopes)
    end
  end

  @doc """
  Acrescenta outra credencial a uma ferramenta já conectada (FR-004).

  As credenciais coexistem e são ativáveis e desativáveis de forma independente,
  porque credenciais diferentes enxergam conjuntos diferentes.
  """
  @spec add_credential(Tenant.t(), ConnectedTool.t(), map()) ::
          {:ok, ToolCredential.t()} | {:error, term()}
  def add_credential(%Tenant{id: tenant_id}, %ConnectedTool{} = tool, attrs) do
    secret = field(attrs, "secret")

    with {:ok, %{scopes: scopes}} <- Client.verify_credential(tool.instance_url, secret) do
      tenant_id
      |> credential_changeset(tool.id, attrs, scopes)
      |> Repo.insert()
    end
  end

  @spec set_credential_active(ToolCredential.t(), boolean()) ::
          {:ok, ToolCredential.t()} | {:error, Ecto.Changeset.t()}
  def set_credential_active(%ToolCredential{} = credential, active?) do
    credential |> ToolCredential.changeset(%{active: active?}) |> Repo.update()
  end

  @doc """
  Marca a ferramenta como precisando de atenção (FR-009).

  Registra data e motivo, e **não** toca nas demais ferramentas do tenant — a
  falha de uma credencial não é motivo para interromper as outras coletas.
  """
  @spec mark_needs_attention(ConnectedTool.t(), String.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def mark_needs_attention(%ConnectedTool{} = tool, reason) do
    tool
    |> ConnectedTool.changeset(%{
      needs_attention_since: DateTime.utc_now(:second),
      needs_attention_reason: reason
    })
    |> Repo.update()
  end

  @spec clear_needs_attention(ConnectedTool.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def clear_needs_attention(%ConnectedTool{} = tool) do
    tool
    |> ConnectedTool.changeset(%{
      needs_attention_since: nil,
      needs_attention_reason: nil
    })
    |> Repo.update()
  end

  @spec touch_last_sync(ConnectedTool.t()) ::
          {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
  def touch_last_sync(%ConnectedTool{} = tool) do
    tool
    |> ConnectedTool.changeset(%{last_sync_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  defp insert_tool_and_credential(%Tenant{id: tenant_id}, attrs, scopes) do
    tool_attrs = %{
      tenant_id: tenant_id,
      tool_type: field(attrs, "tool_type", "github"),
      instance_url: field(attrs, "instance_url"),
      organization_login: field(attrs, "organization_login")
    }

    # Ferramenta e credencial entram na mesma transação: gravar a ferramenta e
    # deixar a credencial para depois produziria uma conexão meio-feita que
    # ninguém sabe se funciona.
    Repo.transaction(fn ->
      with {:ok, tool} <- insert_tool(tool_attrs),
           {:ok, credential} <-
             Repo.insert(credential_changeset(tenant_id, tool.id, attrs, scopes)) do
        %{tool: tool, credential: credential}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_tool(tool_attrs) do
    %ConnectedTool{}
    |> ConnectedTool.changeset(tool_attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:updated_at]},
      conflict_target: [:tenant_id, :tool_type, :instance_url, :organization_login],
      returning: true
    )
  end

  defp credential_changeset(tenant_id, tool_id, attrs, scopes) do
    secret = field(attrs, "secret")

    ToolCredential.changeset(%ToolCredential{}, %{
      tenant_id: tenant_id,
      connected_tool_id: tool_id,
      # `""` e `nil` são a mesma coisa aqui: a tela manda campo vazio, não campo
      # ausente, e só o ausente pegava o padrão. Mesma classe da L13.
      label: blank_to_default(field(attrs, "label"), "credencial principal"),
      secret: secret,
      last_four: ToolCredential.last_four(secret),
      scopes: scopes,
      validated_at: DateTime.utc_now(:second)
    })
  end

  defp blank_to_default(value, default) when value in [nil, ""], do: default
  defp blank_to_default(value, _default), do: value

  # Os atributos chegam da tela com chave string e dos testes com átomo. Ler os
  # dois formatos num lugar só evita espalhar `attrs["x"] || attrs[:x]`.
  defp field(attrs, key, default \\ nil) do
    case Map.get(attrs, key) do
      nil -> Map.get(attrs, String.to_existing_atom(key), default)
      value -> value
    end
  end
end
