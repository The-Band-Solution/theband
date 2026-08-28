defmodule TheBandWeb.SessionController do
  @moduledoc """
  Entrada, saída e a definição forçada de senha — feature 045 (US1).

  A sessão guarda `user_id` E `session_token`: o token é a versão da sessão
  (research R2) — trocar a senha o gira, e as outras sessões caem na hook.
  Por isso os dois POSTs daqui reescrevem o token na sessão que fica.

  A recusa de login é UMA frase (FR-002), e o `{:throttled, _}` mostra a MESMA:
  distinguir daria ao ataque o relógio que a espera crescente existe para tirar.
  """

  use TheBandWeb, :controller

  alias TheBand.Tenants

  @mensagem_unica "Credenciais inválidas."

  def create(conn, %{"identifier" => identificador, "password" => senha}) do
    case Tenants.authenticate(identificador, senha) do
      {:ok, user} ->
        destino = get_session(conn, :redirect_to) || ~p"/people"

        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_session(:session_token, user.session_token)
        |> delete_session(:redirect_to)
        |> redirect(to: if(user.must_change_password, do: ~p"/set-password", else: destino))

      {:error, _qualquer} ->
        conn |> put_flash(:error, @mensagem_unica) |> redirect(to: ~p"/sign-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/sign-in")
  end

  @doc """
  Troca de senha pela própria pessoa (FR-012/015) — no controller pelo mesmo
  motivo de `set_password/2`: o token gira, e a sessão que fica precisa dele.
  """
  def update_password(conn, %{"current" => atual, "password" => nova}) do
    user = conn.assigns.current_user

    case Tenants.change_password(user.tenant, user.id, atual, nova) do
      {:ok, atualizada} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, atualizada.id)
        |> put_session(:session_token, atualizada.session_token)
        |> put_flash(:info, "Senha trocada. As outras sessões foram encerradas.")
        |> redirect(to: ~p"/profile")

      {:error, :invalid_current} ->
        conn
        |> put_flash(:error, "A senha atual não confere.")
        |> redirect(to: ~p"/profile")

      {:error, _} ->
        conn
        |> put_flash(:error, "A senha precisa de pelo menos 12 caracteres.")
        |> redirect(to: ~p"/profile")
    end
  end

  @doc """
  Primeira definição de senha (fluxo da temporária, FR-013).

  Vive num controller, e não em LiveView, porque `set_password` gira o token e a
  SESSÃO precisa receber o token novo — LiveView não escreve cookie de sessão.
  """
  def set_password(conn, %{"password" => senha, "password_confirmation" => confirmacao}) do
    with user_id when is_binary(user_id) <- get_session(conn, :user_id),
         {:ok, user} <- Tenants.fetch_user(user_id),
         true <- user.session_token == get_session(conn, :session_token) do
      if senha == confirmacao do
        aplicar_definicao(conn, user, senha)
      else
        conn
        |> put_flash(:error, "A confirmação não confere com a senha.")
        |> redirect(to: ~p"/set-password")
      end
    else
      _ -> conn |> configure_session(drop: true) |> redirect(to: ~p"/sign-in")
    end
  end

  defp aplicar_definicao(conn, user, senha) do
    case Tenants.set_password(user.tenant, user.id, senha) do
      {:ok, atualizada} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, atualizada.id)
        |> put_session(:session_token, atualizada.session_token)
        |> put_flash(:info, "Senha definida.")
        |> redirect(to: ~p"/people")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "A senha precisa de pelo menos 12 caracteres.")
        |> redirect(to: ~p"/set-password")
    end
  end
end
