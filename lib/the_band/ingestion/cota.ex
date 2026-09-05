defmodule TheBand.Ingestion.Cota do
  @moduledoc """
  O gestor de cotas — ADR 0007, parte 2.

  Um processo por **identidade de cota**, e a identidade é o usuário do GitHub, não o token:
  todos os tokens do mesmo usuário contam no mesmo saldo de 5 000 requisições por hora
  (documentação do GitHub, lida em 2026-09-05). Dois tenants com PATs do mesmo usuário
  passam pelo mesmo processo — e isso é correto, porque é assim que a origem conta.

  ## O que ele sabe, e de onde

  Por balde (`:core` para a REST, `:graphql`): `limit`, `remaining`, `reset`, `em_voo`,
  `recusados_na_janela`, `visto_em`, `ultimo_custo`.

  **A verdade são os cabeçalhos da última resposta, e não a contagem própria.** O dono do
  token gasta cota no navegador, no `gh`, em outro sistema; contar sozinho erraria em todos
  esses casos. `observar/3` substitui o que se sabe pelo que a origem acabou de dizer, e o
  `em_voo` corrige pelo que ainda não voltou.

  ## A regra de concessão

      concede se  remaining  ≥  custo × (em_voo + 1 + teto)

  Em **unidades do balde**: na REST cada requisição custa 1, e a regra vira
  `remaining − em_voo − 1 ≥ teto`; na GraphQL uma consulta custa pontos (100 é comum), e
  as `em_voo` vão gastar `em_voo × custo`. O custo de uma consulta só se conhece depois
  dela: o gestor usa o **maior** entre o que o cliente estimou e o último custo visto na
  identidade. O teto (padrão 10) é a folga em requisições — a concorrência total permitida.

  `em_voo` já está na conta — por isso a margem é a concorrência, e não o dobro dela como
  fazia a pausa local das verificações.

  ## O que ele NÃO faz

  - **Não dorme.** Quem não é concedido recebe `{:espera, %{reset, segundos}}` e devolve
    isso ao Oban como `{:snooze}` — ADR 0006 §5.
  - **Não guarda o token.** A chave é `{instance_url, dono}`, e nada mais entra no estado.
  - **Não consulta a origem.** Quando o `reset` passa, o saldo volta a "desconhecido" e a
    primeira resposta o corrige. (A ADR 0007 propunha uma chamada a `/rate_limit` aqui; ela
    exigiria o token dentro do processo, e o custo de não fazê-la é, no pior caso, um punhado
    de 403 tratados como hoje. Emenda registrada na ADR.)
  - **Não vale para dois nós.** Estado em memória de uma VM — ADR 0007, Consequências.
  """

  use GenServer

  alias Phoenix.PubSub

  @baldes [:core, :graphql]
  @registry TheBand.Ingestion.Cota.Registry
  @supervisor TheBand.Ingestion.Cota.Supervisor
  @ociosidade :timer.hours(1)
  @folga_segundos 60
  @espera_padrao_segundos 900

  @type balde :: :core | :graphql
  @type chave :: {String.t(), String.t() | {:credencial, String.t()}}
  @type leitura :: %{
          optional(:remaining) => non_neg_integer() | nil,
          optional(:reset) => DateTime.t() | nil,
          optional(:limit) => non_neg_integer() | nil,
          optional(:cost) => non_neg_integer() | nil
        }

  # ------------------------------------------------------------------ a chave

  @doc """
  A identidade da cota: `{instance_url, dono}`.

  O dono é o `owner_login` da credencial. Quando ele ainda não foi descoberto (credencial
  cadastrada antes da ADR 0007), a chave cai para `{:credencial, id}` — uma identidade
  por credencial, que é **menos** correta (dois tokens do mesmo usuário virariam duas
  cotas) e é por isso que o job tenta descobrir o dono antes de coletar.
  """
  # `%{instance_url: ...}` sozinho seria um mapa com SÓ essa chave para o Dialyzer, e a
  # ferramenta conectada é uma struct inteira — a chamada "nunca sucederia" e todo o job
  # virava código morto na análise.
  @spec chave(%{required(:instance_url) => String.t(), optional(atom()) => term()}, map() | nil) ::
          chave()
  def chave(%{instance_url: instance_url}, credencial) do
    dono =
      case credencial do
        %{owner_login: login} when is_binary(login) and login != "" -> login
        %{id: id} when is_binary(id) -> {:credencial, id}
        _ -> {:credencial, "sem-credencial"}
      end

    {instance_url, dono}
  end

  @doc "O tópico do PubSub em que o estado desta identidade é publicado."
  @spec topico(chave()) :: String.t()
  def topico({instance_url, dono}) do
    "cota:" <> instance_url <> ":" <> dono_texto(dono)
  end

  defp dono_texto({:credencial, id}), do: "credencial-" <> id
  defp dono_texto(login) when is_binary(login), do: login

  # -------------------------------------------------------------------- a API

  @doc """
  Pede licença para UMA requisição no balde. `:ok` concede e conta em voo;
  `{:espera, %{reset: DateTime | nil, segundos: integer}}` recusa, e a espera é para o Oban.
  """
  @spec pedir(chave(), balde(), pos_integer()) ::
          :ok | {:espera, %{reset: DateTime.t() | nil, segundos: pos_integer()}}
  def pedir(chave, balde, custo \\ 1) when balde in @baldes and is_integer(custo) do
    GenServer.call(processo(chave), {:pedir, balde, custo})
  end

  @doc """
  Informa o que a resposta disse sobre a cota, e devolve a requisição em voo.

  `leitura` é o que o cliente extraiu: dos cabeçalhos `x-ratelimit-*` na REST, do objeto
  `rateLimit` na GraphQL, ou `%{remaining: 0, reset: ...}` quando a origem recusou por cota.
  `nil` quando a resposta não trouxe leitura nenhuma (falha de transporte): só devolve o
  em voo.
  """
  @spec observar(chave(), balde(), leitura() | nil) :: :ok
  def observar(chave, balde, leitura) when balde in @baldes do
    GenServer.cast(processo(chave), {:observar, balde, leitura})
  end

  @doc """
  O balde tem janela para UMA requisição agora? — sem contar nada em voo.

  É a pergunta do job ao escolher a próxima etapa (ADR 0007, parte 6): com a GraphQL
  fechada e a REST aberta, a etapa REST pronta roda em vez de o job hibernar. Devolve
  `:aberta` ou `{:fechada, %{reset, segundos}}`; identidade que nunca pediu está aberta.
  """
  @spec janela_aberta?(chave(), balde()) ::
          :aberta | {:fechada, %{reset: DateTime.t() | nil, segundos: pos_integer()}}
  def janela_aberta?(chave, balde) when balde in @baldes do
    case Registry.lookup(@registry, chave) do
      [{pid, _}] -> GenServer.call(pid, {:janela?, balde})
      [] -> :aberta
    end
  end

  @doc "O estado dos dois baldes, para a tela e para os testes. `nil` se a identidade nunca pediu."
  @spec estado(chave()) :: %{core: map(), graphql: map()} | nil
  def estado(chave) do
    case Registry.lookup(@registry, chave) do
      [{pid, _}] -> GenServer.call(pid, :estado)
      [] -> nil
    end
  end

  @doc "Assina o tópico desta identidade: recebe `{:cota, chave, estado}` a cada observação."
  @spec subscribe(chave()) :: :ok | {:error, term()}
  def subscribe(chave), do: PubSub.subscribe(TheBand.PubSub, topico(chave))

  @doc "O teto de requisições em voo por identidade — a margem da concessão."
  @spec teto_em_voo() :: pos_integer()
  def teto_em_voo, do: Application.get_env(:the_band, :teto_em_voo_da_cota, 10)

  # --------------------------------------------------------------- o processo

  @doc false
  def start_link(chave) do
    GenServer.start_link(__MODULE__, chave, name: {:via, Registry, {@registry, chave}})
  end

  # Nasce no primeiro pedido. Dois pedidos simultâneos para a mesma chave: o segundo
  # `start_child` devolve `{:error, {:already_started, pid}}`, e os dois seguem no mesmo.
  defp processo(chave) do
    case Registry.lookup(@registry, chave) do
      [{pid, _}] ->
        pid

      [] ->
        case DynamicSupervisor.start_child(@supervisor, {__MODULE__, chave}) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end

  @impl true
  def init(chave) do
    {:ok, %{chave: chave, baldes: Map.new(@baldes, &{&1, balde_vazio()})}, @ociosidade}
  end

  defp balde_vazio do
    %{
      limit: nil,
      remaining: nil,
      reset: nil,
      em_voo: 0,
      recusados_na_janela: 0,
      visto_em: nil,
      ultimo_custo: 1
    }
  end

  @impl true
  def handle_call({:pedir, nome, custo}, _de, estado) do
    balde = estado.baldes[nome] |> reabrir_se_passou(DateTime.utc_now())
    # O cliente estima 1; a identidade já pode ter visto consultas de 100 pontos.
    custo = max(custo, balde.ultimo_custo)

    if concede?(balde, custo) do
      balde = %{balde | em_voo: balde.em_voo + 1}
      {:reply, :ok, guardar(estado, nome, balde), @ociosidade}
    else
      balde = %{balde | recusados_na_janela: balde.recusados_na_janela + 1}
      estado = guardar(estado, nome, balde)
      publicar(estado)
      {:reply, {:espera, espera(balde)}, estado, @ociosidade}
    end
  end

  def handle_call(:estado, _de, estado) do
    {:reply, estado.baldes, estado, @ociosidade}
  end

  def handle_call({:janela?, nome}, _de, estado) do
    balde = estado.baldes[nome] |> reabrir_se_passou(DateTime.utc_now())
    estado = guardar(estado, nome, balde)

    if concede?(balde, balde.ultimo_custo),
      do: {:reply, :aberta, estado, @ociosidade},
      else: {:reply, {:fechada, espera(balde)}, estado, @ociosidade}
  end

  @impl true
  def handle_cast({:observar, nome, leitura}, estado) do
    balde =
      estado.baldes[nome]
      |> devolver_em_voo()
      |> aplicar_leitura(leitura, DateTime.utc_now())

    estado = guardar(estado, nome, balde)
    publicar(estado)
    {:noreply, estado, @ociosidade}
  end

  @impl true
  def handle_info(:timeout, estado) do
    # Uma hora sem pedido nem resposta: a janela já virou, e o estado não vale mais nada.
    {:stop, :normal, estado}
  end

  # ------------------------------------------------------------------- regras

  # Saldo desconhecido concede: é o estado antes da primeira resposta e depois do reset, e
  # a primeira resposta corrige. Recusar no escuro pararia a coleta sem motivo.
  defp concede?(%{remaining: nil}, _custo), do: true

  defp concede?(%{remaining: restante, em_voo: em_voo}, custo) do
    restante >= custo * (em_voo + 1 + teto_em_voo())
  end

  # O reset passou: o que se sabia era da janela anterior. Volta a desconhecido; a
  # contagem de recusas zera porque era daquela janela.
  defp reabrir_se_passou(%{reset: %DateTime{} = reset} = balde, agora) do
    if DateTime.compare(agora, reset) in [:gt, :eq] do
      %{balde | remaining: nil, reset: nil, recusados_na_janela: 0}
    else
      balde
    end
  end

  defp reabrir_se_passou(balde, _agora), do: balde

  defp devolver_em_voo(%{em_voo: n} = balde), do: %{balde | em_voo: max(n - 1, 0)}

  defp aplicar_leitura(balde, nil, _agora), do: balde

  defp aplicar_leitura(balde, leitura, agora) do
    reset = Map.get(leitura, :reset)
    remaining = Map.get(leitura, :remaining)

    %{
      balde
      | limit: Map.get(leitura, :limit) || balde.limit,
        # **O menor `remaining` da MESMA janela vence.** Respostas concorrentes chegam fora de
        # ordem: a que saiu antes pode voltar depois, com um saldo maior que já não existe.
        # Dentro de uma janela o saldo só cai, então o mínimo é o mais recente de fato.
        remaining: menor_da_janela(balde, remaining, reset),
        reset: reset || balde.reset,
        visto_em: agora,
        ultimo_custo: Map.get(leitura, :cost) || balde.ultimo_custo
    }
  end

  defp menor_da_janela(_balde, nil, _reset), do: nil

  defp menor_da_janela(%{remaining: atual, reset: reset_atual}, novo, reset)
       when is_integer(atual) and not is_nil(reset_atual) and not is_nil(reset) do
    if DateTime.compare(reset_atual, reset) == :eq, do: min(atual, novo), else: novo
  end

  defp menor_da_janela(_balde, novo, _reset), do: novo

  # Um minuto de folga sobre o reset: reabrir no instante exato às vezes ainda recusa. Sem
  # reset conhecido — a GraphQL recusa sem dizer quando volta —, quinze minutos, que é o
  # padrão que `Client.segundos_ate_reabrir/3` já usava.
  defp espera(%{reset: %DateTime{} = reset}) do
    segundos = DateTime.diff(reset, DateTime.utc_now(), :second) + @folga_segundos
    %{reset: reset, segundos: max(segundos, @folga_segundos)}
  end

  defp espera(_balde), do: %{reset: nil, segundos: @espera_padrao_segundos}

  defp guardar(estado, nome, balde), do: put_in(estado, [:baldes, nome], balde)

  defp publicar(%{chave: chave, baldes: baldes}) do
    PubSub.broadcast(TheBand.PubSub, topico(chave), {:cota, chave, baldes})
  end
end
