defmodule TheBand.Platform.CredentialsAutenticarTest do
  @moduledoc """
  A entrada do operador — spec 070, T023 (FR-011, FR-016). Um caso por motivo: para quem chama, a
  recusa é sempre a mesma, e o motivo interno sai só no evento.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Platform.{Credentials, Grant, Operator, RecoveryCode, SegundoFator}
  alias TheBand.Segredo

  @senha "senha-do-operador-bem-comprida"

  defp operador(opcoes \\ []) do
    segredo = SegundoFator.gerar_segredo()

    op =
      Repo.insert!(%Operator{
        email: "op-#{System.unique_integer([:positive])}@example.org",
        name: "Op",
        password_hash: if(Keyword.get(opcoes, :senha, true), do: Bcrypt.hash_pwd_salt(@senha)),
        totp_secret: Segredo.expor(segredo),
        totp_confirmed_at:
          if(Keyword.get(opcoes, :confirmado, true), do: DateTime.utc_now(:second)),
        totp_last_used_step: if(Keyword.get(opcoes, :confirmado, true), do: nil, else: 1)
      })

    if Keyword.get(opcoes, :concessao, true) do
      Repo.insert!(%Grant{
        operator_id: op.id,
        granted_at: DateTime.utc_now(:second),
        granted_via: "release_command",
        granted_by_declared: "quem rodou",
        email_at_grant: op.email
      })
    end

    {op, segredo}
  end

  defp totp(segredo, t \\ System.os_time(:second)),
    do: Segredo.novo(NimbleTOTP.verification_code(Segredo.expor(segredo), time: t))

  defp codigo_de_recuperacao(op) do
    [c | _] = SegundoFator.gerar_codigos_de_recuperacao()
    Repo.insert!(%RecoveryCode{operator_id: op.id, code_hash: SegundoFator.resumo(c)})
    c
  end

  defp entrar(op, senha, segundo_fator),
    do: Credentials.autenticar(op.email, Segredo.novo(senha), segundo_fator)

  defp com_log(fun) do
    ref = make_ref()
    log = capture_log(fn -> send(self(), {ref, fun.()}) end)
    assert_received {^ref, resultado}
    {resultado, log}
  end

  test "o caminho feliz devolve o operador, grava o passo e zera as falhas" do
    {op, segredo} = operador()
    Repo.update_all(from(o in Operator, where: o.id == ^op.id), set: [failed_attempts: 2])

    assert {{:ok, %Operator{id: id}}, log} = com_log(fn -> entrar(op, @senha, totp(segredo)) end)
    assert id == op.id
    assert log =~ "operador entrada aceita" and log =~ "falhas_apagadas=2"

    depois = Repo.get!(Operator, op.id)
    assert depois.failed_attempts == 0 and depois.totp_last_used_step != nil
    assert depois.logged_in_at != nil
  end

  for {nome, motivo} <- [
        {"e-mail inexistente", :identificador_nao_resolveu},
        {"sem concessão vigente", :sem_concessao},
        {"sem senha definida", :sem_senha},
        {"senha errada", :senha_errada},
        {"TOTP errado", :segundo_fator_errado},
        {"TOTP reusado", :segundo_fator_reusado},
        {"código de recuperação já usado", :recuperacao_usada}
      ] do
    @motivo motivo
    test "#{nome}: a recusa única, e o motivo #{motivo} no evento" do
      {resultado, log} = com_log(fn -> caso(@motivo) end)

      assert resultado == {:error, :invalid_credentials}
      assert log =~ "operador entrada recusada"
      assert log =~ "motivo=#{inspect(@motivo)}"
    end
  end

  defp caso(:identificador_nao_resolveu),
    do:
      Credentials.autenticar("ninguem@example.org", Segredo.novo(@senha), Segredo.novo("123456"))

  defp caso(:sem_concessao) do
    {op, segredo} = operador(concessao: false)
    entrar(op, @senha, totp(segredo))
  end

  defp caso(:sem_senha) do
    # Sem senha é antes da definição: o segundo fator também não está confirmado, e o banco recusa
    # o contrário (`platform_operators_confirmado_tem_senha`).
    {op, segredo} = operador(senha: false, confirmado: false)
    entrar(op, @senha, totp(segredo))
  end

  defp caso(:senha_errada) do
    {op, segredo} = operador()
    entrar(op, "outra-senha-bem-comprida", totp(segredo))
  end

  defp caso(:segundo_fator_errado) do
    {op, segredo} = operador()
    entrar(op, @senha, totp(segredo, System.os_time(:second) + 600))
  end

  defp caso(:segundo_fator_reusado) do
    {op, segredo} = operador()
    c = totp(segredo)
    {:ok, _} = entrar(op, @senha, c)
    entrar(op, @senha, c)
  end

  defp caso(:recuperacao_usada) do
    {op, _} = operador()
    c = codigo_de_recuperacao(op)
    {:ok, _} = entrar(op, @senha, c)
    entrar(op, @senha, c)
  end

  test "sem o terceiro passo do cadastro, nem o TOTP certo nem o código de recuperação entram, e o código não é gasto" do
    {op, segredo} = operador(confirmado: false)
    c = codigo_de_recuperacao(op)

    for segundo_fator <- [totp(segredo), c] do
      {resultado, log} = com_log(fn -> entrar(op, @senha, segundo_fator) end)
      assert resultado == {:error, :invalid_credentials}
      assert log =~ "motivo=:sem_segundo_fator"
    end

    assert Repo.one!(from r in RecoveryCode, where: r.operator_id == ^op.id, select: r.used_at) ==
             nil

    assert Repo.get!(Operator, op.id).second_factor_failures == 0
  end

  test "T1: dez segundos fatores errados com a senha certa travam, mesmo com o código certo depois" do
    {op, segredo} = operador()
    errado = totp(segredo, System.os_time(:second) + 600)

    log =
      capture_log(fn ->
        for _ <- 1..10 do
          Repo.update_all(from(o in Operator, where: o.id == ^op.id), set: [failed_attempts: 0])
          {:error, :invalid_credentials} = entrar(op, @senha, errado)
        end
      end)

    assert log =~ "operador segundo fator travado"
    assert Repo.get!(Operator, op.id).second_factor_failures == 10

    Repo.update_all(from(o in Operator, where: o.id == ^op.id), set: [failed_attempts: 0])
    {resultado, log} = com_log(fn -> entrar(op, @senha, totp(segredo)) end)
    assert resultado == {:error, :invalid_credentials}
    assert log =~ "motivo=:segundo_fator_travado"
  end

  test "a senha errada não toca o contador do segundo fator" do
    {op, segredo} = operador()
    capture_log(fn -> entrar(op, "outra-senha-bem-comprida", totp(segredo)) end)
    assert Repo.get!(Operator, op.id).second_factor_failures == 0
  end
end
