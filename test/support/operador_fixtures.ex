defmodule TheBand.OperadorFixtures do
  @moduledoc """
  Operadores da plataforma para os testes da spec 070. Escreve direto pelos schemas, porque os
  caminhos que criam operador (o comando de release e a definição de senha) são tarefas próprias,
  com teste próprio.
  """
  alias TheBand.Platform.{Credentials, Grant, Grants, Operator, SegundoFator}
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
    email = "op-#{System.unique_integer([:positive])}@example.org"
    {:ok, {op, _grant, definicao}} = Grants.conceder(email, "Op", "quem rodou")

    [:passo1, :passo2, :completo]
    |> Enum.take_while(&(ordem(&1) <= ordem(ate)))
    |> Enum.reduce(%{op: op, email: email, definicao: definicao}, &passo/2)
  end

  defp ordem(:concedido), do: 0
  defp ordem(:passo1), do: 1
  defp ordem(:passo2), do: 2
  defp ordem(:completo), do: 3

  defp passo(:passo1, r) do
    {:ok, {_, %{segredo: segredo, enrollment_token: cadastro}}} =
      Credentials.definir_senha(
        r.email,
        r.definicao,
        Segredo.novo(@senha),
        TheBand.OrigemDeTeste.nova()
      )

    Map.merge(r, %{segredo: segredo, cadastro: cadastro})
  end

  defp passo(:passo2, r) do
    {:ok, {_, codigos, guarda}} =
      Credentials.confirmar_segundo_fator(
        r.email,
        r.cadastro,
        totp(r.segredo),
        TheBand.OrigemDeTeste.nova()
      )

    Map.merge(r, %{codigos: codigos, guarda: guarda})
  end

  defp passo(:completo, r) do
    {:ok, op} = Credentials.concluir_cadastro(r.email, r.guarda, TheBand.OrigemDeTeste.nova())
    Map.put(r, :op, op)
  end

  @doc "O código TOTP do segredo no instante dado."
  def totp(segredo, t \\ System.os_time(:second)),
    do: Segredo.novo(NimbleTOTP.verification_code(Segredo.expor(segredo), time: t))
end
