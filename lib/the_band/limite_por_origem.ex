defmodule TheBand.LimitePorOrigem do
  @moduledoc """
  Conta as falhas por origem nas portas que verificam segredo sem sessão — spec 077, contrato
  `contracts/limite-por-origem.md` §4. Defeito #1229; tarefa #1106.

  Depende de: nenhuma ontologia.

  ## Conta falhas, sem abrir corrida (seguranca.md, L8)

  "Só falhas" só se sabe depois de verificar, e conferir depois de verificar deixaria N tentativas
  paralelas passarem juntas. Então: o incremento é **atômico, incondicional e anterior** a
  qualquer verificação — inclusive na tentativa que vai ser recusada, para que quem martela
  continue fora enquanto martela —, e a soma é lida a partir do valor que o próprio incremento
  devolveu. No **sucesso**, e só nele, `devolver/1` tira **um**, da fatia em que incrementou.

  Zerar no sucesso daria tentativas ilimitadas a quem tem uma conta própria: nove falhas contra
  outras contas, uma entrada na própria, e de novo.

  ## Janela deslizante em fatias, e a varredura é global (L6)

  O mecanismo das fatias é o da `TheBandWeb.Plugs.ApiRateLimit`, mas a poda não: lá ela limpa só a
  chave tocada, o que basta para tokens, que são poucos e voltam. Origens não voltam, e cada
  endereço que tentou uma vez ficaria na tabela para sempre. Este processo é o **dono** da tabela
  e, a cada largura de fatia, apaga as fatias velhas de **todas** as origens.

  ## A recusa não se anuncia (L9)

  Nada aqui devolve a soma, o limite ou quanto falta: quem chama não tem o que pôr num
  `retry-after`. A recusa por limite sai pela mesma recusa de credencial errada de cada porta.

  ## O que vai para o log (L10)

  Uma linha por **transição** — a falha que leva a soma para além do limite —, com o balde, o
  estado e o **prefixo** truncado. Nunca a chave, nunca em `Logger.metadata/1`. A decisão volta
  no retorno, e é sobre ele que o teste afere (L69).
  """

  use GenServer

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Origem

  require Logger

  @tabela :limite_por_origem
  @regra "access.origin_limit"

  @type balde :: :contas | :operador
  @opaque ficha :: {balde(), String.t(), integer()}
  @type decisao ::
          {:segue, ficha()}
          | {:observado, :transicao | :dentro | :abaixo, ficha()}
          | {:recusa, :transicao | :dentro}

  @doc false
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Incrementa a falha desta origem neste balde e decide. Ver o contrato §4.
  """
  @spec conferir(balde(), Origem.t()) :: decisao()
  @spec conferir(balde(), Origem.t(), integer()) :: decisao()
  def conferir(balde, %Origem{} = origem, agora \\ System.system_time(:second))
      when balde in [:contas, :operador] do
    %{limite: limite, fatias: fatias, largura: largura} = numeros()
    atual = div(agora, largura)
    chave = {balde, origem.chave, atual}

    # ATÔMICO, e a soma sai do valor que ele devolveu: as fatias anteriores estão fechadas e não
    # recebem incremento, então duas tentativas simultâneas nunca leem a mesma soma.
    nesta_fatia = :ets.update_counter(@tabela, chave, {2, 1}, {chave, 0})
    soma = nesta_fatia + anteriores(balde, origem.chave, atual, fatias)

    decidir(soma, limite, origem, balde, chave)
  end

  defp decidir(soma, limite, %Origem{estado: estado}, _balde, chave) when soma <= limite do
    if estado == :nao_declarada, do: {:observado, :abaixo, chave}, else: {:segue, chave}
  end

  defp decidir(soma, limite, %Origem{} = origem, balde, chave) do
    momento = if soma == limite + 1, do: :transicao, else: :dentro
    if momento == :transicao, do: registrar_transicao(balde, origem, soma)

    case origem.estado do
      :nao_declarada -> {:observado, momento, chave}
      _ -> {:recusa, momento}
    end
  end

  defp registrar_transicao(balde, %Origem{estado: estado, prefixo: prefixo}, soma) do
    Logger.warning(
      "limite por origem: #{balde} passou do limite · estado=#{estado} " <>
        "prefixo=#{prefixo} falhas=#{soma}"
    )
  end

  defp anteriores(balde, chave_origem, atual, fatias) do
    Enum.reduce((atual - fatias + 1)..(atual - 1)//1, 0, fn i, total ->
      case :ets.lookup(@tabela, {balde, chave_origem, i}) do
        [{_, n}] -> total + n
        [] -> total
      end
    end)
  end

  @doc """
  Devolve **uma** falha, na fatia em que a ficha incrementou — só no sucesso. Piso zero, e sem
  criar a chave se a varredura já a apagou: `update_counter/4` com valor padrão criaria a chave
  em `-1`, um crédito que se acumula (L8, Q8).
  """
  @spec devolver(ficha()) :: :ok
  def devolver({_balde, _origem, _fatia} = chave) do
    # `select_replace` é atômico por objeto, só troca o que casa (a chave existe e vale mais que
    # zero), e nunca insere.
    :ets.select_replace(@tabela, [
      {{chave, :"$1"}, [{:>, :"$1", 0}], [{{{:const, chave}, {:-, :"$1", 1}}}]}
    ])

    :ok
  end

  @doc false
  # Apaga as fatias fora da janela, de TODAS as origens e baldes, e devolve quantas. O processo a
  # chama a cada largura de fatia; o teste, com o relógio que quiser (Q21).
  @spec varrer(integer()) :: non_neg_integer()
  def varrer(agora) do
    %{fatias: fatias, largura: largura, teto: teto} = numeros()
    mais_velha_que_conta = div(agora, largura) - fatias + 1

    apagadas =
      :ets.select_delete(@tabela, [
        {{{:_, :_, :"$1"}, :_}, [{:<, :"$1", mais_velha_que_conta}], [true]}
      ])

    tamanho = :ets.info(@tabela, :size)

    if tamanho > teto do
      Logger.warning(
        "limite por origem: #{tamanho} entradas depois da varredura, acima do teto de #{teto}"
      )
    end

    apagadas
  end

  @impl GenServer
  def init(_opts) do
    # O DONO DA TABELA É ESTE PROCESSO (L11). Se ele morre, a tabela some com ele, e
    # `conferir/3` levanta — a entrada responde erro, e nunca "permitido" em silêncio. Ao
    # renascer, a tabela nasce vazia, e isso fica dito.
    :ets.new(@tabela, [:set, :public, :named_table, write_concurrency: true])
    Logger.info("limite por origem: tabela criada, vazia")
    agendar()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:varrer, estado) do
    varrer(System.system_time(:second))
    agendar()
    {:noreply, estado}
  end

  defp agendar do
    %{largura: largura} = numeros()
    Process.send_after(self(), :varrer, largura * 1000)
  end

  # Da base de conhecimento, a cada chamada (vive em ETS desde o boot). Regra ausente é base
  # incompleta, e quebra alto: nunca vira limite silencioso de zero ou de infinito.
  defp numeros do
    case KnowledgeBase.rule(@regra) do
      {:ok,
       %{"rules" => %{"failure_limit" => %{"values" => f}, "table_ceiling" => %{"values" => t}}}} ->
        %{
          limite: f["failures"],
          fatias: f["slices"],
          largura: max(div(f["window_seconds"], f["slices"]), 1),
          teto: t["entries"]
        }

      _ ->
        raise "regra #{@regra} ausente da base de conhecimento"
    end
  end
end
