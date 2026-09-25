defmodule TheBandWeb.Plugs.ApiReadLog do
  @moduledoc """
  Registra toda leitura **bem-sucedida** da API — achado A1, 2026-09-22.

  ## Por que um plug, e não uma chamada em cada controlador

  Seis rotas hoje, e mais depois. Uma chamada por controlador é uma que alguém esquece na
  sétima — e o registro que falta é justamente o da rota nova, que ninguém ainda olhou.

  O plug se registra em `register_before_send/2`: a gravação acontece **depois** de a
  resposta estar pronta, e por isso não entra no caminho do que quem chama espera.

  ## Só sucesso, e de propósito

  A recusa é registrada por quem recusa: `ApiAuth` recusa a credencial,
  `AccessEvents.painel_recusado/4` a pessoa, e `AccessEvents.equipe_recusada/4` a equipe.
  Duplicá-la aqui encheria a tabela do que já está no log, e o que faltava era o outro lado:
  **o acesso concedido**, que não deixava rastro nenhum.

  *Corrigido em 2026-09-25:* até o T022 da feature 062, este parágrafo dizia que a recusa já
  era registrada, e para **equipe** não era (achado N6). A API caía num `404` sem registro.

  **O MCP não passa por aqui**: a porta marca a requisição como `:delegado`, e o registro de
  ferramentas grava a leitura no ponto do veredito. Ver `TheBand.MCP.Ferramentas`.

  `status in 200..299` é o corte. Um `404` não é leitura; um `405` também não.

  ## Nunca derruba a resposta

  Registro que quebra a requisição que ele observa troca um problema de auditoria por um de
  disponibilidade. `ApiAccessLog.registrar/1` resgata e segue.
  """
  import Plug.Conn

  alias TheBand.Tenants.ApiAccessLog

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, &gravar/1)
  end

  # **O MCP é gravado por outro, no ponto do veredito** — feature 062, T021. A ferramenta roda
  # num processo da biblioteca, e daqui não se sabe nem qual ferramenta foi, nem sobre qual
  # equipe, nem se foi recusa: a recusa do MCP sai em `200`. Gravar aqui seria gravar `/mcp`
  # com `target_id` vazio, e gravar recusa como leitura. A porta do MCP marca a requisição, e o
  # registro de ferramentas grava a linha certa.
  defp gravar(%Plug.Conn{private: %{api_read_log: :delegado}} = conn), do: conn

  defp gravar(%Plug.Conn{status: status} = conn) when status in 200..299 do
    case {conn.assigns[:api_token], conn.assigns[:current_tenant]} do
      {%{public_id: publico}, %{id: tenant_id}} ->
        ApiAccessLog.registrar(%{
          tenant_id: tenant_id,
          token_public_id: publico,
          route: rota(conn),
          target_id: alvo(conn)
        })

      _ ->
        # Sem token não há o que registrar: a descrição OpenAPI é servida aberta, e ela não
        # traz dado. Registrar aqui encheria a tabela de chamadas sem sujeito.
        :ok
    end

    conn
  end

  defp gravar(conn), do: conn

  # O MOLDE da rota, e não o caminho concreto: `/api/v1/people/:id` agrupa, e
  # `/api/v1/people/<uuid>` produziria uma linha por pessoa lida — que é contagem por alvo
  # disfarçada de contagem por rota. O alvo vai em `target_id`, no campo dele.
  defp rota(conn), do: conn.private[:phoenix_route_path] || molde(conn)

  defp molde(conn) do
    case Phoenix.Router.route_info(TheBandWeb.Router, conn.method, conn.request_path, "") do
      %{route: caminho} -> caminho
      _ -> conn.request_path
    end
  end

  defp alvo(conn) do
    case conn.params["id"] do
      id when is_binary(id) ->
        case Ecto.UUID.cast(id) do
          {:ok, uuid} -> uuid
          :error -> nil
        end

      _ ->
        nil
    end
  end
end
