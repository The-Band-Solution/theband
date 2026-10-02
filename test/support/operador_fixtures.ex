defmodule TheBand.OperadorFixtures do
  @moduledoc """
  Operadores da plataforma para os testes da spec 070. Escreve direto pelos schemas, porque os
  caminhos que criam operador (o comando de release e a definição de senha) são tarefas próprias,
  com teste próprio.
  """
  alias TheBand.Platform.{Grant, Operator, SegundoFator}
  alias TheBand.Repo
  alias TheBand.Segredo

  @senha "senha-do-operador-bem-comprida"

  def senha_do_operador, do: @senha

  @doc "Um operador com senha, segundo fator confirmado e concessão vigente, e o segredo dele."
  def operador_pronto(campos \\ []) do
    segredo = SegundoFator.gerar_segredo()

    op =
      Repo.insert!(
        struct(
          %Operator{
            email: "op-#{System.unique_integer([:positive])}@example.org",
            name: "Op",
            password_hash: Bcrypt.hash_pwd_salt(@senha),
            totp_secret: Segredo.expor(segredo),
            totp_confirmed_at: DateTime.utc_now(:second)
          },
          campos
        )
      )

    Repo.insert!(%Grant{
      operator_id: op.id,
      granted_at: DateTime.utc_now(:second),
      granted_via: "release_command",
      granted_by_declared: "quem rodou",
      email_at_grant: op.email
    })

    {op, segredo}
  end

  @doc """
  Um operador concedido pelo caminho real (`Grants.conceder/3`), com os passos do cadastro feitos
  até `ate` (`:concedido`, `:passo1`, `:passo2` ou `:completo`). Devolve o que cada passo entregou.
  """
  def pelo_caminho_real(ate \\ :completo) do
    alias TheBand.Platform.{Credentials, Grants}
    email = "op-#{System.unique_integer([:positive])}@example.org"
    {:ok, {op, _grant, definicao}} = Grants.conceder(email, "Op", "quem rodou")
    r = %{op: op, email: email, definicao: definicao}

    if ate == :concedido do
      r
    else
      {:ok, {_, %{segredo: segredo, enrollment_token: cadastro}}} =
        Credentials.definir_senha(email, definicao, Segredo.novo(@senha))

      r = Map.merge(r, %{segredo: segredo, cadastro: cadastro})

      if ate == :passo1 do
        r
      else
        {:ok, {_, codigos, guarda}} =
          Credentials.confirmar_segundo_fator(email, cadastro, totp(segredo))

        r = Map.merge(r, %{codigos: codigos, guarda: guarda})

        if ate == :passo2 do
          r
        else
          {:ok, op} = Credentials.concluir_cadastro(email, guarda)
          Map.put(r, :op, op)
        end
      end
    end
  end

  @doc "O código TOTP do segredo no instante dado."
  def totp(segredo, t \\ System.os_time(:second)),
    do: Segredo.novo(NimbleTOTP.verification_code(Segredo.expor(segredo), time: t))
end
