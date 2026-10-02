defmodule TheBandWeb.Plataforma.EntradaController do
  @moduledoc """
  A entrada e a saída do operador — spec 070, T039 (FR-011, FR-016). Contrato em
  `specs/070-operador-da-plataforma/contracts/rotas-da-plataforma.md`.

  Depende de: nenhuma ontologia.

  A recusa é **uma** página: `:invalid_credentials` e `{:throttled, _}` re-renderizam a mesma frase,
  com o mesmo status (A3). Distinguir daria ao ataque o relógio que a espera existe para tirar.
  """
  use TheBandWeb, :controller

  alias TheBand.Platform.{Credentials, Sessions}
  alias TheBand.Segredo
  alias TheBandWeb.Plataforma.{SessaoDoOperador, TelasHTML}

  plug :put_view, html: TelasHTML

  @doc "GET /platform/sign-in"
  def new(conn, _params), do: render(conn, :entrada, recusada: false, email: "")

  @doc "POST /platform/session"
  def create(conn, params) do
    email = texto(params, "email")

    case Credentials.autenticar(
           email,
           Segredo.novo(texto(params, "password")),
           Segredo.novo(texto(params, "second_factor_token"))
         ) do
      {:ok, op} ->
        conn |> SessaoDoOperador.abrir(op) |> redirect(to: ~p"/platform/organizations")

      {:error, _qualquer} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:entrada, recusada: true, email: email)
    end
  end

  @doc "DELETE /platform/session: encerra no servidor, e só então solta o cookie."
  def delete(conn, _params) do
    Sessions.encerrar(conn.assigns.current_operator_session)
    conn |> SessaoDoOperador.soltar() |> redirect(to: ~p"/platform/sign-in")
  end

  # Campo ausente ou que não é texto vira "", e cai na mesma recusa: nunca `raise`, nunca outra
  # resposta que distinga o formulário mal montado do formulário errado.
  defp texto(params, campo) do
    case params[campo] do
      valor when is_binary(valor) -> valor
      _ -> ""
    end
  end
end
