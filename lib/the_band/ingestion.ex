defmodule TheBand.Ingestion do
  @moduledoc """
  Orquestra a coleta: abre a sincronização, acompanha o progresso e fecha com o
  relatório de FR-028.

  Uma sincronização por ferramenta de cada vez (FR-018), garantida em dois
  níveis: índice único parcial no banco e `unique` no worker Oban. A corrida
  existe nos dois — a segunda requisição HTTP e o segundo job enfileirado.
  """

  import Ecto.Query

  require Logger

  alias TheBand.Ingestion.Checkpoint
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.SyncGitHubEO
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @topic "syncs"

  @doc "Assina as atualizações de progresso de um tenant, para a tela acompanhar ao vivo."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, @topic <> ":" <> tenant_id)

  @spec broadcast(Ecto.UUID.t(), term()) :: :ok
  def broadcast(tenant_id, message),
    do: Phoenix.PubSub.broadcast(TheBand.PubSub, @topic <> ":" <> tenant_id, message)

  @doc """
  Abre uma sincronização e enfileira o trabalho.

  Devolve `{:error, :already_running}` quando já existe uma em curso — a segunda
  **não** inicia em paralelo, e quem chamou é informado em vez de ver duas
  coletas disputando a mesma janela de API.
  """
  @spec start_sync(Tenant.t(), ConnectedTool.t(), keyword()) ::
          {:ok, Sync.t()}
          | {:error, :already_running | :no_active_credential | :enqueue_failed | term()}
  def start_sync(%Tenant{id: tenant_id} = tenant, %ConnectedTool{} = tool, opts \\ []) do
    # Origem encerrada não é coletada (FR-008). O filtro passa por
    # `observation_ended?/1`, que é o mesmo caminho que a tela usa — dois caminhos
    # discordariam, e a plataforma coletaria do que a tela mostra como encerrado.
    if Sources.observation_ended?(tool) do
      {:error, :observation_ended}
    else
      do_start_sync(tenant_id, tenant, tool, Keyword.get(opts, :worker, SyncGitHubEO))
    end
  end

  defp do_start_sync(tenant_id, tenant, tool, worker) do
    case Sources.active_credential(tool) do
      nil ->
        {:error, :no_active_credential}

      credential ->
        attrs = %{
          tenant_id: tenant_id,
          connected_tool_id: tool.id,
          credential_id: credential.id,
          status: "running",
          started_at: DateTime.utc_now(:second)
        }

        %Sync{}
        |> Sync.changeset(attrs)
        |> Repo.insert()
        |> handle_open(tenant, worker)
    end
  end

  # O resultado da criação do trabalho é **conferido**, e antes não era: ele ia para o
  # vazio. Se a criação falha, o registro fica `running` sem nada para executá-lo — e o
  # índice único passa a bloquear a ferramenta, que é o defeito da issue #175 por outra
  # porta. Ninguém saberia se já aconteceu, porque o retorno era descartado.
  #
  # Encerra **na hora**, e não espera a reconciliação: o motivo dela seria errado. "O
  # processo que a executava não existe mais" afirma que houve processo, e aqui ele nunca
  # existiu.
  defp handle_open({:ok, sync}, tenant, worker) do
    case enqueue(tenant, sync, worker) do
      {:ok, _job} ->
        {:ok, sync}

      {:error, reason} ->
        Logger.error("não foi possível enfileirar a coleta #{sync.id}: #{inspect(reason)}")

        finish(sync, :interrupted,
          error_reason: "o trabalho que a executaria não pôde ser criado"
        )

        {:error, :enqueue_failed}
    end
  end

  # O índice único parcial é a defesa que impede duas coletas simultâneas; aqui
  # ele é traduzido no motivo que a tela precisa exibir.
  defp handle_open({:error, %Ecto.Changeset{errors: errors}}, _tenant, _worker) do
    if Keyword.has_key?(errors, :connected_tool_id),
      do: {:error, :already_running},
      else: {:error, :invalid}
  end

  # O worker é escolha de quem chama, e não vive no registro do `sync`: o que o payload
  # preservado carrega é `raw_entity_type`, e é ele que diz o que foi coletado. Uma
  # coluna de worker guardaria o **como** em vez do **quê**, e envelheceria a cada
  # renomeação de módulo.
  defp enqueue(%Tenant{id: tenant_id}, %Sync{id: sync_id}, worker) do
    %{"tenant_id" => tenant_id, "sync_id" => sync_id}
    |> worker.new()
    |> Oban.insert()
  rescue
    # `Oban.insert/1` levanta quando o worker não é worker — dois dos cinco descartes no
    # dado real vêm de `module is not a worker`. Levantar aqui deixaria o registro `running`,
    # que é exatamente o que esta feature existe para impedir.
    error -> {:error, error}
  end

  # ------------------------------------------------------------------- leitura

  @doc """
  O que **aquela** sincronização trouxe de repositórios e issues.

  Conta por `sync_id` em `raw_payloads`, e não o total do tenant. A primeira versão desta
  função somava o tenant inteiro e exibia o número dentro do cartão de cada sync — o que
  fazia uma coleta de 14 repositórios aparecer com 135 ao lado, porque outra organização
  havia sido coletada depois.

  Contar o estado atual e mostrá-lo como resultado de uma execução é o mesmo erro que a
  coluna `impact` do evento de observação evita: o que interessa é o que foi observado
  **naquele** momento.
  """
  @spec work_summary(Sync.t()) :: %{repositorios: non_neg_integer(), issues: non_neg_integer()}
  def work_summary(%Sync{id: sync_id}) do
    contagens =
      Repo.all(
        from p in "raw_payloads",
          where: p.sync_id == type(^sync_id, :binary_id),
          where: p.raw_entity_type in ["github.repository", "github.issue"],
          group_by: p.raw_entity_type,
          select: {p.raw_entity_type, count(p.id)}
      )
      |> Map.new()

    %{
      repositorios: Map.get(contagens, "github.repository", 0),
      issues: Map.get(contagens, "github.issue", 0)
    }
  end

  @spec list_syncs(Tenant.t(), keyword()) :: [Sync.t()]
  def list_syncs(%Tenant{id: tenant_id}, opts \\ []) do
    query =
      from s in Sync,
        where: s.tenant_id == ^tenant_id,
        order_by: [desc: s.started_at]

    query = if opts[:limit], do: limit(query, ^opts[:limit]), else: query
    Repo.all(query)
  end

  @spec fetch_sync(Tenant.t(), Ecto.UUID.t()) :: {:ok, Sync.t()} | {:error, :not_found}
  def fetch_sync(%Tenant{id: tenant_id}, id) do
    case Repo.one(from s in Sync, where: s.tenant_id == ^tenant_id and s.id == ^id) do
      nil -> {:error, :not_found}
      sync -> {:ok, sync}
    end
  end

  @spec running_sync(ConnectedTool.t()) :: Sync.t() | nil
  def running_sync(%ConnectedTool{id: tool_id}) do
    Repo.one(from s in Sync, where: s.connected_tool_id == ^tool_id and s.status == "running")
  end

  @spec list_checkpoints(Sync.t()) :: [Checkpoint.t()]
  def list_checkpoints(%Sync{id: sync_id}) do
    Repo.all(from c in Checkpoint, where: c.sync_id == ^sync_id, order_by: c.entity_type)
  end

  # ------------------------------------------------------------------ progresso

  @doc """
  Grava o checkpoint de uma página **já processada** (R5, SC-006).

  Chamado depois do processamento, nunca antes.
  """
  @spec checkpoint_page(
          Sync.t(),
          String.t(),
          String.t() | nil,
          non_neg_integer(),
          non_neg_integer() | nil
        ) :: {:ok, Checkpoint.t()} | {:error, Ecto.Changeset.t()}
  def checkpoint_page(%Sync{} = sync, entity_type, cursor, record_count, expected \\ nil) do
    existing =
      Repo.one(
        from c in Checkpoint, where: c.sync_id == ^sync.id and c.entity_type == ^entity_type
      )

    attrs = %{
      tenant_id: sync.tenant_id,
      sync_id: sync.id,
      entity_type: entity_type,
      cursor: cursor,
      page_count: acumular(existing, :page_count, 1),
      record_count: acumular(existing, :record_count, record_count),
      last_page_at: DateTime.utc_now(:second),
      # O esperado ACUMULA, e não guarda o primeiro. Cada chamada corresponde a UMA
      # origem já paginada por inteiro: repositórios vêm numa chamada com o total da
      # organização; issues vêm numa chamada por repositório, cada uma com o total dele.
      #
      # Guardar o primeiro dava `194 de 0`, porque o primeiro repositório coletado é o
      # `.github`, que tem zero issues — e `0 || novo` devolve 0 em Elixir.
      expected_count: acumular_esperado(existing, expected),
      status: if(cursor, do: "running", else: "completed")
    }

    (existing || %Checkpoint{})
    |> Checkpoint.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Cursor de onde retomar, quando a coleta foi interrompida (FR-015)."
  @spec resume_cursor(Sync.t(), String.t()) :: String.t() | nil
  def resume_cursor(%Sync{id: sync_id}, entity_type) do
    Repo.one(
      from c in Checkpoint,
        where: c.sync_id == ^sync_id and c.entity_type == ^entity_type,
        select: c.cursor
    )
  end

  @doc "Acumula o resultado de uma escrita no relatório da sincronização (FR-028)."
  @spec tally(
          Sync.t(),
          :created | :updated | :unchanged | :repository_unreachable | {:skipped, String.t()}
        ) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def tally(%Sync{} = sync, outcome) do
    attrs =
      case outcome do
        :created ->
          %{
            records_collected: sync.records_collected + 1,
            records_created: sync.records_created + 1
          }

        :updated ->
          %{
            records_collected: sync.records_collected + 1,
            records_updated: sync.records_updated + 1
          }

        :unchanged ->
          %{records_collected: sync.records_collected + 1}

        # Conta **repositório**, e por isso não passa por `records_*`: aqueles contam registros,
        # e somar 39 repositórios ali faria a soma que a tela exibe mentir.
        #
        # Incrementado **a cada falha**, nunca no fim da fase: coleta interrompida antes do fim
        # ficaria com zero, e zero afirma que tudo foi alcançado. É a mesma regra do checkpoint —
        # registrar depois de processar, por item.
        :repository_unreachable ->
          %{repositories_unreachable: sync.repositories_unreachable + 1}

        {:skipped, reason} ->
          %{
            records_collected: sync.records_collected + 1,
            records_skipped: sync.records_skipped + 1,
            skip_reasons: Map.update(sync.skip_reasons, reason, 1, &(&1 + 1))
          }
      end

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  @spec finish(Sync.t(), :completed | :failed | :interrupted, keyword()) ::
          {:ok, Sync.t()} | {:error, Ecto.Changeset.t()}
  def finish(%Sync{} = sync, status, opts \\ []) do
    attrs =
      %{
        status: to_string(status),
        finished_at: DateTime.utc_now(:second),
        error_reason: opts[:error_reason]
      }
      |> then(fn attrs ->
        case opts[:memberships_pending_role] do
          nil -> attrs
          n -> Map.put(attrs, :memberships_pending_role, n)
        end
      end)
      |> then(fn attrs ->
        # Ausente quando quem encerrou foi a plataforma, e a ausência é a afirmação.
        case opts[:interrupted_by_user_id] do
          nil -> attrs
          id -> Map.put(attrs, :interrupted_by_user_id, id)
        end
      end)

    sync |> Sync.changeset(attrs) |> Repo.update()
  end

  defp acumular(nil, _campo, incremento), do: incremento
  defp acumular(existing, campo, incremento), do: Map.fetch!(existing, campo) + incremento

  defp acumular_esperado(_existing, nil), do: nil
  defp acumular_esperado(nil, novo), do: novo
  defp acumular_esperado(%{expected_count: nil}, novo), do: novo
  defp acumular_esperado(%{expected_count: atual}, novo), do: atual + novo

  @spec reload(Sync.t()) :: Sync.t()
  def reload(%Sync{id: id}), do: Repo.get!(Sync, id)

  # ------------------------------------------------- execução presa (feature 008)

  # Duas noções de "vivo", e confundi-las é o defeito que a execução no dado real revelou.
  #
  # `@ativos` — o que **impede o encerramento automático**. Inclui `executing`, porque a
  # plataforma não pode encerrar por conta própria uma execução que talvez esteja rodando:
  # encerrar libera o índice, e uma coleta nova rodaria **em paralelo** com a que continua.
  #
  # `@vai_executar` — o que a plataforma consegue **provar**. A fila vai pegar o trabalho em
  # `available`, `scheduled`, `retryable` e `suspended`, e isso é verificável. `executing`
  # **não** é prova de vida: é um claim que sobrevive ao processo que o fez. O job 5 do banco
  # de desenvolvimento está `executing` desde 2026-08-09, num nó que não existe mais.
  #
  # É por isso que a ação humana existe (US3): só uma pessoa sabe que reiniciou a aplicação,
  # e a plataforma não tem como saber.
  #
  # As duas listas são **derivadas** de `Oban.Job.states/0`, nunca copiadas: uma versão nova
  # do Oban que acrescente estado entraria em silêncio numa lista literal — e a primeira
  # versão desta feature já errou assim, esquecendo `suspended`.
  @terminais ~w(completed discarded cancelled)
  @ativos Enum.map(Oban.Job.states(), &to_string/1) -- @terminais
  @vai_executar @ativos -- ["executing"]

  # A execução recém-aberta não é candidata. Abrir o registro e criar o trabalho são duas
  # operações, e no intervalo a execução tem a assinatura exata de "presa" — `running` e sem
  # trabalho. O intervalo real é de milissegundos; um minuto é margem de três ordens de
  # grandeza. Falha na criação **não** espera a carência: `start_sync/3` encerra na hora.
  @carencia_segundos 60

  @doc """
  Encerra toda execução `running` cujo trabalho não existe mais.

  **Atravessa tenants de propósito**: é manutenção da plataforma, não consulta de tenant, e
  nenhum dado de um tenant chega a outro. A ação **por pessoa** continua escopada, em
  `interrupt_sync/3`.

  Devolve as execuções que encerrou. Lista vazia é o caso normal, e **não** produz log:
  ruído periódico treina quem lê a ignorar o log, e aí o log que importa passa batido.

  A decisão é **ausência de trabalho ativo**, nunca idade. Uma coleta de 16 minutos é
  indistinguível de uma coleta morta pela idade, e encerrar coleta viva derruba trabalho em
  andamento — pior que o bloqueio que esta função existe para resolver.
  """
  @spec reconcile_stuck_syncs() :: {:ok, [Sync.t()]}
  def reconcile_stuck_syncs do
    limite = DateTime.add(DateTime.utc_now(:second), -@carencia_segundos, :second)

    encerradas =
      from(s in Sync, where: s.status == "running" and s.started_at <= ^limite)
      |> Repo.all()
      |> Enum.reject(&trabalho_ativo?/1)
      |> Enum.flat_map(fn sync ->
        case finish(sync, :interrupted, error_reason: motivo(sync)) do
          {:ok, encerrada} ->
            Logger.warning(
              "sincronização #{sync.id} encerrada pela plataforma: #{encerrada.error_reason}"
            )

            [encerrada]

          {:error, _} ->
            []
        end
      end)

    {:ok, encerradas}
  end

  @doc """
  Encerra por **decisão humana**, e grava o autor.

  `:job_alive` é a defesa que o `:not_found` não dá: sem ela, a ação da tela seria o caminho
  para derrubar uma coleta viva por engano. A tela reconfere aqui, e não confia no próprio
  botão — entre desenhar e clicar, a coleta pode ter voltado a executar.
  """
  @spec interrupt_sync(Tenant.t(), Ecto.UUID.t(), User.t()) ::
          {:ok, Sync.t()} | {:error, :not_found | :not_running | :job_alive}
  def interrupt_sync(%Tenant{} = tenant, sync_id, %User{} = user) do
    with {:ok, sync} <- fetch_sync(tenant, sync_id),
         :ok <- confirmar_running(sync),
         :ok <- confirmar_sem_trabalho(sync) do
      finish(sync, :interrupted,
        error_reason: motivo_humano(sync, user),
        interrupted_by_user_id: user.id
      )
    end
  end

  @doc """
  Se o que sustenta esta execução é um trabalho **em execução** que a plataforma não pode
  verificar.

  Existe para a tela avisar o risco certo: encerrar aqui é decisão de quem sabe que o
  processo morreu, e se a coleta estiver de fato rodando uma segunda começa em paralelo.
  """
  @spec claimed_by_dead_process?(Sync.t()) :: boolean()
  def claimed_by_dead_process?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state == "executing")
  end

  @doc """
  Se a tela deve **oferecer** a ação de encerrar.

  Consulta de exibição, e não a decisão: quem decide é `interrupt_sync/3`, que reconfere.
  """
  @spec interruptible?(Sync.t()) :: boolean()
  def interruptible?(%Sync{status: "running"} = sync), do: not vai_executar?(sync)
  def interruptible?(%Sync{}), do: false

  # O motivo diz **o que a pessoa afirmou**, e não o que a plataforma observou. Quando há
  # trabalho `executing`, ela está afirmando que o processo morreu — informação que só ela
  # tem, e que o registro precisa carregar para quem lê depois.
  defp motivo_humano(sync, user) do
    quem = user.name || user.email

    if Repo.exists?(from j in trabalhos(sync.id), where: j.state == "executing") do
      "encerrada por #{quem}: o trabalho constava em execução, e o processo não existe mais"
    else
      "encerrada por #{quem}"
    end
  end

  defp confirmar_running(%Sync{status: "running"}), do: :ok
  defp confirmar_running(%Sync{}), do: {:error, :not_running}

  # A pessoa pode encerrar o que a plataforma não consegue provar vivo — inclusive o caso do
  # trabalho `executing` num nó que morreu, que é o que aconteceu duas vezes e motivou a issue
  # #175. O que ela **não** pode encerrar é trabalho que a fila vai pegar: aí a coleta começa
  # sozinha, e encerrar o registro faria duas rodarem juntas.
  defp confirmar_sem_trabalho(sync) do
    if vai_executar?(sync), do: {:error, :job_alive}, else: :ok
  end

  defp trabalho_ativo?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state in @ativos)
  end

  defp vai_executar?(%Sync{id: sync_id}) do
    Repo.exists?(from j in trabalhos(sync_id), where: j.state in @vai_executar)
  end

  # A ligação é pelos args porque o sync **não guarda** id de job: pôr um lá seria
  # identificador de fila dentro do registro de domínio. Os args são escritos por
  # `enqueue/3`, no mesmo módulo que os lê.
  defp trabalhos(sync_id) do
    from j in Oban.Job, where: fragment("? ->> 'sync_id' = ?", j.args, ^sync_id)
  end

  # O motivo depende da causa, e **nunca inventa falha que ninguém observou**. Ausência de
  # trabalho é dita como ausência: dizer "erro" ali afirmaria uma falha que a plataforma não
  # viu, e apagaria a diferença entre falha transitória e permanente — a L29.
  defp motivo(%Sync{id: sync_id}) do
    consulta =
      from j in trabalhos(sync_id),
        where: j.state == "discarded",
        order_by: [desc: j.attempted_at, desc: j.id],
        limit: 1

    case Repo.one(consulta) do
      nil ->
        "o processo que a executava não existe mais"

      job ->
        "as tentativas se esgotaram (#{job.attempt} de #{job.max_attempts}): #{ultimo_erro(job)}"
    end
  end

  defp ultimo_erro(%Oban.Job{errors: errors}) when is_list(errors) and errors != [] do
    errors
    |> List.last()
    |> Map.get("error", "sem detalhe registrado")
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 300)
  end

  defp ultimo_erro(%Oban.Job{}), do: "sem detalhe registrado"
end
