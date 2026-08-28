defmodule TheBandWeb.Live.Hooks do
  @moduledoc """
  Leva o tenant e a pessoa usuária da sessão para dentro do LiveView.

  Sem isso o LiveView teria de buscar o tenant por conta própria a cada evento —
  e a primeira vez que alguém esquecesse, a consulta rodaria sem filtro.
  """

  use Gettext, backend: TheBandWeb.Gettext

  import Phoenix.Component
  import Phoenix.LiveView

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  # Sete dias de inatividade encerram a sessão (assumption da spec 045).
  @validade_dias 7

  def on_mount(:current_scope, _params, session, socket) do
    with {:ok, user} <- buscar(session["user_id"]),
         :ok <- token_confere(user, session["session_token"]),
         :ok <- dentro_da_validade(user) do
      case gate_de_senha(user, socket) do
        :ok ->
          {:cont,
           socket
           |> assign(:current_user, user)
           |> assign(:current_tenant, user.tenant)
           # O menu pergunta uma vez por mount: Operação aparece para admin OU
           # organization (FR-023) — a condição vive em Access.operacional?/2,
           # o ponto único que a 046 previu.
           |> assign(:operacao_menu, TheBand.Tenants.operacional?(user.tenant, user) != false)
           |> attach_hook(:nav_area, :handle_params, &nav_area_hook/3)}

        {:redirect, destino} ->
          {:halt, redirect(socket, to: destino)}
      end
    else
      # Sessão ausente, token girado (senha trocada em outro navegador — FR-015)
      # ou validade vencida: o caminho é a entrada. O destino pretendido foi
      # guardado pelo plug `salvar_destino` do roteador (FR-005).
      _ -> {:halt, redirect(socket, to: "/sign-in")}
    end
  end

  def on_mount(:require_operacao, params, session, socket) do
    case on_mount(:current_scope, params, session, socket) do
      {:cont, socket} ->
        case TheBand.Tenants.operacional?(
               socket.assigns.current_tenant,
               socket.assigns.current_user
             ) do
          {true, recorte} ->
            {:cont, assign(socket, :operacao, recorte)}

          false ->
            {:halt,
             socket
             |> put_flash(
               :error,
               dgettext(
                 "errors",
                 "Syncs e Tools pedem administração ou escopo organization — o seu acesso não os alcança."
               )
             )
             |> redirect(to: "/people")}
        end

      halted ->
        halted
    end
  end

  def on_mount(:require_admin, params, session, socket) do
    case on_mount(:current_scope, params, session, socket) do
      {:cont, socket} ->
        if User.admin?(socket.assigns.current_user) do
          {:cont, socket}
        else
          {:halt,
           socket
           |> put_flash(:error, dgettext("errors", "Only organisation administrators can do that."))
           |> redirect(to: "/people")}
        end

      halted ->
        halted
    end
  end

  # A área ativa do menu vem do caminho da request (spec 046, FR-006). Vive na
  # hook, e não em cada LiveView, pelo mesmo motivo do tenant acima: a primeira
  # tela que esquecesse de declarar ficaria sem marcação em silêncio.
  defp nav_area_hook(_params, uri, socket) do
    {:cont, assign(socket, :nav_area, TheBandWeb.Layouts.nav_area(URI.parse(uri).path))}
  end

  defp buscar(nil), do: :sem_sessao
  defp buscar(user_id), do: Tenants.fetch_user(user_id)

  # O token é a versão da sessão (research R2): trocar a senha o gira, e toda
  # sessão com o token antigo cai AQUI, na próxima ação — não no próximo login.
  defp token_confere(%User{session_token: da_conta}, da_sessao)
       when da_conta == da_sessao,
       do: :ok

  defp token_confere(_, _), do: :token_girado

  defp dentro_da_validade(%User{logged_in_at: nil}), do: :ok

  defp dentro_da_validade(%User{logged_in_at: em}) do
    if DateTime.diff(DateTime.utc_now(:second), em, :day) < @validade_dias,
      do: :ok,
      else: :expirada
  end

  # Quem entrou com a temporária define a senha ANTES de qualquer tela (FR-013).
  defp gate_de_senha(%User{must_change_password: true}, socket)
       when socket.view != TheBandWeb.SessionLive.SetPassword,
       do: {:redirect, "/set-password"}

  defp gate_de_senha(_, _), do: :ok
end
