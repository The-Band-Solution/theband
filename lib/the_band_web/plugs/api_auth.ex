defmodule TheBandWeb.Plugs.ApiAuth do
  @moduledoc """
  O veredito único da API pública — feature 061, FR-013 a FR-016.

  ## Uma recusa só, e o motivo real no log

  Token inexistente, malformado, revogado, expirado, e conta dona desativada produzem a
  **mesma resposta**. Distinguir para fora confirma a quem testa credencial roubada que ela
  existiu — e `401 "token expired"` diz até quando.

  O motivo real vai para o **log interno**, recuperável pelo identificador da requisição.
  Calar para o cliente não é calar para quem opera; é o princípio XI.

  ## Só o cabeçalho `Authorization`

  Em query string, em corpo ou em cookie o token **não é lido**. Query string vaza para log
  de servidor, para histórico de navegador e para o `Referer` de qualquer link que a página
  carregue depois.

  ## O que este plug NÃO faz

  Não decide o que a requisição alcança. Isso é `Tenants.Access`, chamado **a cada
  requisição** pelo controlador — nada de escopo vive no token, e nada é cacheado aqui.
  """
  import Plug.Conn

  require Logger

  alias TheBand.Tenants
  alias TheBand.Tenants.User
  alias TheBandWeb.Api.V1.Erro

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> valor] -> autenticar(conn, valor)
      ["bearer " <> valor] -> autenticar(conn, valor)
      [] -> recusar(conn, :sem_cabecalho)
      _ -> recusar(conn, :cabecalho_malformado)
    end
  end

  defp autenticar(conn, valor) do
    case Tenants.authenticate_api_token(valor) do
      {:ok, token} -> com_tenant(conn, token)
      {:error, :recusado} -> recusar(conn, :credencial_recusada)
    end
  end

  # O tenant e a conta dona vêm da LINHA do token, nunca de parâmetro da requisição. É o que
  # torna impossível pedir dado de outro tenant mudando a URL.
  defp com_tenant(conn, token) do
    with {:ok, tenant} <- Tenants.fetch(token.tenant_id),
         {:ok, dono} <- Tenants.fetch_user(token.user_id),
         true <- dono.tenant_id == tenant.id,
         true <- User.ativa?(dono) do
      conn
      |> assign(:api_token, token)
      |> assign(:current_tenant, tenant)
      |> assign(:current_user, dono)
    else
      _ -> recusar(conn, :conta_dona_indisponivel)
    end
  end

  # O `request_id` já está no `conn` pelo `Plug.RequestId` do endpoint, e é ele que liga a
  # recusa muda que o cliente vê ao motivo que quem opera precisa.
  defp recusar(conn, motivo) do
    id = Logger.metadata()[:request_id] || "sem-id"

    Logger.warning("api: credencial recusada · motivo=#{motivo} request_id=#{id}")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(Erro.corpo(:unauthorized, id)))
    |> halt()
  end
end
