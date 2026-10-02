defmodule TheBandWeb.Plataforma.CadastroController do
  @moduledoc """
  Os três passos do cadastro do operador — spec 070, T039 (FR-016; T5 de `seguranca-totp.md`).
  Contrato em `specs/070-operador-da-plataforma/contracts/rotas-da-plataforma.md`.

  Depende de: nenhuma ontologia.

  ## A exibição única

  O segredo, a URI e os dez códigos existem em claro **só no corpo da resposta** do `POST` que os
  produziu, renderizada aqui com `render/3`. Nunca por `put_flash/3` (o flash mora no cookie de
  sessão, que é só assinado), `put_session/3`, `redirect/2` ou `GET`. As recusas re-renderizam o
  formulário **sem** eles, com o código do passo recebido de volta no campo oculto.
  """
  use TheBandWeb, :controller

  alias TheBand.Platform.Credentials
  alias TheBand.Segredo
  alias TheBandWeb.Plataforma.TelasHTML

  plug :put_view, html: TelasHTML

  @doc "GET /platform/setup"
  def new(conn, _params), do: render(conn, :definicao, recusa: nil, email: "")

  @doc "POST /platform/setup: o passo 1."
  def create(conn, params) do
    email = texto(params, "email")
    senha = texto(params, "password")

    # A confirmação é conferida ANTES do contexto: diferente, o código de definição não é gasto.
    if senha == texto(params, "password_confirmation") do
      case Credentials.definir_senha(
             email,
             Segredo.novo(texto(params, "setup_token")),
             Segredo.novo(senha)
           ) do
        {:ok, {op, %{segredo: segredo, uri: uri, enrollment_token: cadastro}}} ->
          render(conn, :cadastro,
            email: op.email,
            segredo: segredo,
            uri: uri,
            enrollment_token: cadastro,
            expira_em: op.enrollment_code_expires_at
          )

        {:error, %Ecto.Changeset{}} ->
          recusar(conn, :definicao, recusa: :senha, email: email)

        {:error, _} ->
          recusar(conn, :definicao, recusa: :codigo, email: email)
      end
    else
      recusar(conn, :definicao, recusa: :confirmacao, email: email)
    end
  end

  @doc "POST /platform/setup/second-factor: o passo 2."
  def second_factor(conn, params) do
    email = texto(params, "email")
    cadastro = Segredo.novo(texto(params, "enrollment_token"))

    case Credentials.confirmar_segundo_fator(
           email,
           cadastro,
           Segredo.novo(texto(params, "second_factor_token"))
         ) do
      {:ok, {op, codigos, guarda}} ->
        render(conn, :codigos,
          email: op.email,
          codigos: codigos,
          acknowledgement_token: guarda,
          expira_em: op.ack_code_expires_at
        )

      {:error, _} ->
        # Sem o segredo: `confirmar_segundo_fator/3` não o devolve, e reenviá-lo num campo oculto o
        # poria no corpo de um segundo `POST` (D2 do protótipo).
        recusar(conn, :cadastro, email: email, segredo: nil, uri: nil, enrollment_token: cadastro)
    end
  end

  @doc "POST /platform/setup/recovery-codes: o passo 3, o único que habilita a entrada."
  def recovery_codes(conn, params) do
    email = texto(params, "email")
    guarda = Segredo.novo(texto(params, "acknowledgement_token"))

    # A caixa é conferida ANTES do contexto: sem ela, nada é consumido nem conta como falha, e os
    # códigos não reaparecem.
    if params["codes_stored"] == "true" do
      case Credentials.concluir_cadastro(email, guarda) do
        {:ok, _op} -> render(conn, :concluido, concluido: true)
        {:error, _} -> recusar(conn, :concluido, concluido: false)
      end
    else
      recusar(conn, :codigos, email: email, codigos: nil, acknowledgement_token: guarda)
    end
  end

  defp recusar(conn, tela, assigns),
    do: conn |> put_status(:unprocessable_entity) |> render(tela, assigns)

  defp texto(params, campo) do
    case params[campo] do
      valor when is_binary(valor) -> valor
      _ -> ""
    end
  end
end
