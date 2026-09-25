defmodule TheBandWeb.MCP.Servidor do
  @moduledoc """
  O handler MCP — o adaptador entre a `ex_mcp` e o registro de ferramentas (feature 062, T007).

  **É fino de propósito.** As respostas vivem em `TheBand.MCP.Ferramentas`, que não conhece a
  biblioteca. Aqui só se traduz: a lista do registro vira `tools/list`, e a chamada vira
  `Ferramentas.chamar/4`. Trocar a biblioteca é reescrever este módulo, e nada além dele.

  ## O estado nasce a cada requisição (R7 da revisão independente)

  A `ex_mcp` sobe **um processo por requisição** para o handler, e o `init/1` recebe o que
  `estado/2` calcula a partir do `conn` daquela requisição. O estado leva **só identificadores**:
  o tenant, a conta dona, o `public_id` do token e o `request_id`. Nunca o token inteiro, e
  nunca os cabeçalhos, que carregam o `Authorization`: a biblioteca registra falha de handler
  com `Exception.format/3`, e um `FunctionClauseError` imprime os argumentos.

  ## A correlação atravessa o processo (R8)

  O `Logger.metadata` não se herda entre processos. Sem o `init/1` o repor, todo log da
  ferramenta, incluindo a recusa, sairia sem `request_id`, e a ligação entre *"o cliente viu
  recusa"* e *"o log diz por quê"* se perderia.

  ## O `_meta` sai antes do registro

  O cliente manda o `_meta` do protocolo **dentro** dos argumentos. O registro recusa qualquer
  chave além de `team_id`, e é assim que deve ser, mas o `_meta` não é argumento da ferramenta:
  é do protocolo. Ele é separado aqui, e a ferramenta nunca o vê.
  """
  use ExMCP.Server.Handler

  alias TheBand.MCP.Ferramentas

  @doc """
  O estado de uma requisição, calculado pela `ex_mcp` a cada chamada, por MFA. A pipeline
  `:api_autenticada` já pôs o tenant, a conta e o token no `conn`: se não houvesse token, a
  requisição nem chegaria aqui.
  """
  @spec estado(Plug.Conn.t(), map()) :: map()
  def estado(%Plug.Conn{assigns: assigns}, _pedido) do
    %{
      tenant: assigns.current_tenant,
      user: assigns.current_user,
      token_public_id: assigns.api_token.public_id,
      request_id: Logger.metadata()[:request_id]
    }
  end

  @impl GenServer
  def init(estado) do
    Logger.metadata(request_id: estado.request_id, tenant_id: estado.tenant.id)
    {:ok, estado}
  end

  @impl ExMCP.Server.Handler
  def handle_list_tools(_cursor, estado) do
    ferramentas =
      for f <- Ferramentas.listar() do
        %{name: f.nome, description: f.descricao, inputSchema: Ferramentas.esquema_de_entrada()}
      end

    {:ok, ferramentas, nil, estado}
  end

  @impl ExMCP.Server.Handler
  def handle_call_tool(nome, argumentos, estado) do
    {_meta, argumentos} = Map.pop(argumentos, "_meta")

    case Ferramentas.chamar(estado.tenant, estado.user, nome, argumentos) do
      {:error, :ferramenta_inexistente} ->
        {:error, ExMCP.Error.protocol_error(-32_602, "Unknown tool"), estado}

      {:error, {:argumento_invalido, motivo}} ->
        {:error, ExMCP.Error.protocol_error(-32_602, motivo), estado}

      # A recusa também chega aqui, e é resposta, e não erro (FR-013): um agente que recebe
      # erro de protocolo não distingue "não pode ver" de "o servidor caiu".
      resposta when is_map(resposta) ->
        {:ok,
         %{
           content: [%{type: "text", text: Jason.encode!(resposta)}],
           structuredContent: resposta
         }, estado}
    end
  end
end
