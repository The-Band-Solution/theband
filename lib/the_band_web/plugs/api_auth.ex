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
      {:ok, token} ->
        com_tenant(conn, token)

      # **O motivo específico vai ao LOG, e nunca ao corpo.**
      #
      # `:inexistente`, `:revogado`, `:expirado`, `:segredo_errado` e `:malformado` são
      # investigações diferentes: alguém tentando um token que nunca existiu é varredura;
      # alguém usando um revogado é credencial que vazou antes da revogação. Antes disto,
      # as cinco chegavam como `credencial_recusada` e as duas perguntas começavam iguais.
      #
      # A resposta ao cliente continua **idêntica** nas cinco — SC-003 —, e há teste que
      # afirma as duas coisas juntas, porque provar uma sem a outra deixaria passar o
      # conserto que quebra a outra.
      {:error, motivo} ->
        recusar(conn, motivo)
    end
  end

  # O tenant e a conta dona vêm da LINHA do token, nunca de parâmetro da requisição. É o que
  # torna impossível pedir dado de outro tenant mudando a URL.
  #
  # **A organização suspensa não autentica por token** — achado N5, 2026-09-24. As três portas
  # de sessão já liam `tenant.status` desde o H3 (`auth.ex`, `current_scope.ex`, `hooks.ex`), e
  # esta não: suspender uma organização cortava a entrada de quem usa a tela e deixava os tokens
  # dela respondendo `200`. Quem suspendesse acharia que suspendeu.
  #
  # O motivo próprio vai ao LOG; o corpo continua o mesmo das outras recusas (SC-003).
  defp com_tenant(conn, token) do
    with {:ok, tenant} <- Tenants.fetch(token.tenant_id),
         {:organizacao, "active"} <- {:organizacao, tenant.status},
         {:ok, dono} <- Tenants.fetch_user(token.user_id),
         true <- dono.tenant_id == tenant.id,
         true <- User.ativa?(dono) do
      conn
      |> assign(:api_token, token)
      |> assign(:current_tenant, tenant)
      |> assign(:current_user, dono)
    else
      {:organizacao, _} -> recusar(conn, :organizacao_suspensa)
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
