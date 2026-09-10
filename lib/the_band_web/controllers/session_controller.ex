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

  # A recusa única da 045 (FR-002 de lá): byte-idêntica entre identificador
  # inexistente, senha errada e conta sem senha — provada em login_test.exs por
  # Enum.uniq. Vive numa função (gettext é runtime; atributo congelaria a língua
  # na compilação) e num único ponto, para continuar única por construção.
  defp mensagem_unica, do: dgettext("errors", "Credenciais inválidas.")

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
        conn |> put_flash(:error, mensagem_unica()) |> redirect(to: ~p"/sign-in")
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
        |> put_flash(
          :info,
          dgettext("sistema", "Senha trocada. As outras sessões foram encerradas.")
        )
        |> redirect(to: ~p"/profile")

      {:error, :invalid_current} ->
        conn
        |> put_flash(:error, dgettext("errors", "A senha atual não confere."))
        |> redirect(to: ~p"/profile")

      {:error, _} ->
        conn
        |> put_flash(:error, dgettext("errors", "A senha precisa de pelo menos 12 caracteres."))
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
         true <- user.session_token == get_session(conn, :session_token),
         # ESTA PORTA SERVE **SÓ** AO FLUXO DA TEMPORÁRIA — achado H1, 2026-09-09.
         #
         # Sem esta cláusula, quem alcança uma sessão válida por alguns minutos — o
         # navegador esquecido aberto, a máquina compartilhada, o cookie capturado —
         # trocava a senha **sem apresentar a antiga em momento nenhum**, e o giro do
         # `session_token` derrubava a pessoa legítima. Acesso temporário virava posse
         # permanente da conta.
         #
         # A guarda de `/profile/password` já exigia a senha atual, e estava certa. O
         # defeito era haver uma SEGUNDA porta sem ela — o antipadrão que este
         # repositório persegue nos próprios dados, dentro de casa.
         #
         # A conta em regime normal cai no `else` que já existia: sessão derrubada e
         # `/sign-in`. Derrubar, e não redirecionar para `/profile` com uma frase, é a
         # escolha segura — quem chegou aqui com sessão de outra pessoa não deve ganhar
         # uma dica do que tentar em seguida. Se o gentil for preferido, é decisão de
         # produto, e está registrada no achado.
         true <- user.must_change_password do
      if senha == confirmacao do
        aplicar_definicao(conn, user, senha)
      else
        conn
        |> put_flash(:error, dgettext("errors", "A confirmação não confere com a senha."))
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
        |> put_flash(:info, dgettext("sistema", "Senha definida."))
        |> redirect(to: ~p"/people")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, dgettext("errors", "A senha precisa de pelo menos 12 caracteres."))
        |> redirect(to: ~p"/set-password")
    end
  end
end
