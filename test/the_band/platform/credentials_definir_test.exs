defmodule TheBand.Platform.CredentialsDefinirTest do
  @moduledoc """
  Os três passos do cadastro do operador — spec 070, T026 (FR-016, A5, A14; emenda T012). Só o
  terceiro passo habilita a entrada. Um caso por frase do "Feita quando" da tarefa.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Platform.{Credentials, Grant, Operator, RecoveryCode}
  alias TheBand.Segredo

  @senha "a-senha-nova-do-operador"

  # Um operador novo, como o comando de release o deixa: sem senha, com concessão e com o código
  # de definição emitido.
  defp operador_novo(concessao? \\ true) do
    op =
      Repo.insert!(%Operator{
        email: "op-#{System.unique_integer([:positive])}@example.org",
        name: "Op"
      })

    if concessao? do
      Repo.insert!(%Grant{
        operator_id: op.id,
        granted_at: DateTime.utc_now(:second),
        granted_via: "release_command",
        granted_by_declared: "quem rodou",
        email_at_grant: op.email
      })
    end

    {:ok, codigo} = Credentials.emitir_codigo(op)
    {op, codigo}
  end

  defp quieto(fun) do
    ref = make_ref()
    capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> r)
  end

  defp totp(segredo), do: Segredo.novo(NimbleTOTP.verification_code(Segredo.expor(segredo)))

  defp entrar(op, segundo_fator),
    do: quieto(fn -> Credentials.autenticar(op.email, Segredo.novo(@senha), segundo_fator) end)

  defp passo1(op, codigo),
    do: quieto(fn -> Credentials.definir_senha(op.email, codigo, Segredo.novo(@senha)) end)

  defp passo2(op, token, segredo),
    do: quieto(fn -> Credentials.confirmar_segundo_fator(op.email, token, totp(segredo)) end)

  defp passo3(op, guarda), do: quieto(fn -> Credentials.concluir_cadastro(op.email, guarda) end)

  test "depois só do primeiro passo, a entrada recusa" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo}}} = passo1(op, codigo)

    assert entrar(op, totp(segredo)) == {:error, :invalid_credentials}
  end

  test "depois do segundo, a entrada ainda recusa, com o TOTP certo e com um código de recuperação, que continua sem used_at" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: token}}} = passo1(op, codigo)
    {:ok, {_, [recuperacao | _], _guarda}} = passo2(op, token, segredo)

    # O passo do TOTP do passo 2 já foi usado; o seguinte é outro código, e mesmo assim recusa.
    assert entrar(op, totp(segredo)) == {:error, :invalid_credentials}
    assert entrar(op, recuperacao) == {:error, :invalid_credentials}

    assert Repo.all(
             from r in RecoveryCode, where: r.operator_id == ^op.id and not is_nil(r.used_at)
           ) == []
  end

  test "depois do terceiro, entra com um código de recuperação e, num passo seguinte, com o TOTP" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: token}}} = passo1(op, codigo)
    {:ok, {_, [recuperacao | _], guarda}} = passo2(op, token, segredo)
    assert {:ok, %Operator{totp_confirmed_at: confirmado}} = passo3(op, guarda)
    assert confirmado != nil

    assert {:ok, _} = entrar(op, recuperacao)

    # O TOTP do instante seguinte: o do passo 2 já é reuso.
    proximo =
      Segredo.novo(
        NimbleTOTP.verification_code(Segredo.expor(segredo), time: System.os_time(:second) + 30)
      )

    assert {:ok, _} = entrar(op, proximo)
  end

  test "o código de definição usado uma vez é recusado na segunda" do
    {op, codigo} = operador_novo()
    assert {:ok, _} = passo1(op, codigo)
    assert passo1(op, codigo) == {:error, :invalid_credentials}
  end

  test "o código de cadastro não abre o passo 3" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: token}}} = passo1(op, codigo)
    {:ok, _} = passo2(op, token, segredo)

    assert passo3(op, token) == {:error, :invalid_credentials}
  end

  test "sem concessão vigente, a recusa única no primeiro passo e no terceiro" do
    {op, codigo} = operador_novo(false)
    assert passo1(op, codigo) == {:error, :invalid_credentials}

    {op2, codigo2} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: token}}} = passo1(op2, codigo2)
    {:ok, {_, _, guarda}} = passo2(op2, token, segredo)

    Repo.update_all(from(g in Grant, where: g.operator_id == ^op2.id),
      set: [
        revoked_at: DateTime.utc_now(:second),
        revoked_via: "release_command",
        revoked_by_declared: "quem"
      ]
    )

    assert passo3(op2, guarda) == {:error, :invalid_credentials}
  end

  test "um código de definição errado produz operador_definicao_recusada com :codigo_errado" do
    {op, _codigo} = operador_novo()

    log =
      capture_log(fn ->
        assert Credentials.definir_senha(
                 op.email,
                 Segredo.novo("codigo-errado-de-fixture"),
                 Segredo.novo(@senha)
               ) ==
                 {:error, :invalid_credentials}
      end)

    assert log =~ "operador definição recusada" and log =~ "motivo=:codigo_errado"
    refute log =~ "codigo-errado-de-fixture"
  end

  test "a senha fora da política devolve o changeset, e o código continua valendo" do
    {op, codigo} = operador_novo()

    assert {:error, %Ecto.Changeset{}} =
             quieto(fn -> Credentials.definir_senha(op.email, codigo, Segredo.novo("curta")) end)

    assert {:ok, _} = passo1(op, codigo)
  end

  # Lacunas apontadas pelo agente de modelos (T063): o vencimento de cada código e o TOTP errado no
  # segundo passo.
  defp vencer(op, campo) do
    Repo.update_all(from(o in Operator, where: o.id == ^op.id),
      set: [{campo, DateTime.add(DateTime.utc_now(:second), -1, :second)}]
    )
  end

  test "o código de definição vencido é recusado, e a senha não é definida" do
    {op, codigo} = operador_novo()
    vencer(op, :setup_code_expires_at)

    assert passo1(op, codigo) == {:error, :invalid_credentials}
    assert Repo.get!(Operator, op.id).password_hash == nil
  end

  test "o código de cadastro vencido é recusado, e o segundo fator não vai a confirmado" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: cadastro}}} = passo1(op, codigo)
    vencer(op, :enrollment_code_expires_at)

    assert passo2(op, cadastro, segredo) == {:error, :invalid_credentials}
    assert Repo.all(from r in RecoveryCode, where: r.operator_id == ^op.id) == []
  end

  test "o TOTP errado no segundo passo não consome o código de cadastro: o certo, depois, passa" do
    {op, codigo} = operador_novo()
    {:ok, {_, %{segredo: segredo, enrollment_token: cadastro}}} = passo1(op, codigo)

    errado =
      Segredo.novo(
        NimbleTOTP.verification_code(Segredo.expor(segredo), time: System.os_time(:second) + 600)
      )

    assert quieto(fn -> Credentials.confirmar_segundo_fator(op.email, cadastro, errado) end) ==
             {:error, :invalid_credentials}

    assert {:ok, {_, codigos, _guarda}} = passo2(op, cadastro, segredo)
    assert length(codigos) == 10
  end
end
