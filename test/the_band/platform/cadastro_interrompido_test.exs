defmodule TheBand.Platform.CadastroInterrompidoTest do
  @moduledoc """
  A revogação e o reinício no meio do cadastro — spec 070, T030a (cenários C6, C7, C16 e C18 de
  `seguranca-totp.md`; FR-016, A14).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Grants, Operator}
  alias TheBand.Segredo

  defp quieto(fun) do
    ref = make_ref()
    capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> r)
  end

  test "C6: revogar depois do passo 1; o par antigo não confirma, nem depois de conceder de novo" do
    r = quieto(fn -> pelo_caminho_real(:passo1) end)
    quieto(fn -> {:ok, _} = Grants.revogar(r.email, "quem", nil) end)

    assert quieto(fn ->
             Credentials.confirmar_segundo_fator(r.email, r.cadastro, totp(r.segredo))
           end) ==
             {:error, :invalid_credentials}

    quieto(fn -> {:ok, _} = Grants.conceder(r.email, "Op", "quem") end)

    assert quieto(fn ->
             Credentials.confirmar_segundo_fator(r.email, r.cadastro, totp(r.segredo))
           end) ==
             {:error, :invalid_credentials}

    depois = Repo.get!(Operator, r.op.id)
    refute depois.totp_confirmed_at
    assert Repo.one!(from o in Operator, where: o.id == ^r.op.id, select: o.totp_secret) == nil
  end

  test "C7: reiniciar depois do passo 1; o código de cadastro antigo é recusado" do
    r = quieto(fn -> pelo_caminho_real(:passo1) end)
    {:ok, _} = quieto(fn -> Grants.reiniciar_credencial(r.email, "quem") end)

    assert quieto(fn ->
             Credentials.confirmar_segundo_fator(r.email, r.cadastro, totp(r.segredo))
           end) ==
             {:error, :invalid_credentials}

    refute Repo.get!(Operator, r.op.id).totp_confirmed_at
  end

  test "C16: o código de guarda vencido é recusado, e o cadastro refeito entra" do
    r = quieto(fn -> pelo_caminho_real(:passo2) end)

    Repo.update_all(from(o in Operator, where: o.id == ^r.op.id),
      set: [ack_code_expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)]
    )

    assert quieto(fn -> Credentials.concluir_cadastro(r.email, r.guarda) end) ==
             {:error, :invalid_credentials}

    refute Repo.get!(Operator, r.op.id).totp_confirmed_at

    {:ok, definicao} = quieto(fn -> Grants.reiniciar_credencial(r.email, "quem") end)

    {:ok, {_, %{segredo: segredo, enrollment_token: cadastro}}} =
      quieto(fn ->
        Credentials.definir_senha(r.email, definicao, Segredo.novo(senha_do_operador()))
      end)

    {:ok, {_, _, guarda}} =
      quieto(fn -> Credentials.confirmar_segundo_fator(r.email, cadastro, totp(segredo)) end)

    assert {:ok, %Operator{totp_confirmed_at: confirmado}} =
             quieto(fn -> Credentials.concluir_cadastro(r.email, guarda) end)

    assert confirmado
  end

  for ato <- [:revogar, :reiniciar] do
    @ato ato
    test "C18: #{ato} entre os passos 2 e 3; o código de guarda é recusado, e nenhum código de recuperação vale" do
      r = quieto(fn -> pelo_caminho_real(:passo2) end)

      quieto(fn ->
        case @ato do
          :revogar -> {:ok, _} = Grants.revogar(r.email, "quem", nil)
          :reiniciar -> {:ok, _} = Grants.reiniciar_credencial(r.email, "quem")
        end
      end)

      assert Repo.get!(Operator, r.op.id).ack_code_hash == nil

      assert quieto(fn -> Credentials.concluir_cadastro(r.email, r.guarda) end) ==
               {:error, :invalid_credentials}

      refute Repo.get!(Operator, r.op.id).totp_confirmed_at

      # Recusa por espera também é recusa: depois de várias seguidas, a espera entra. O que importa é
      # que nenhum código de recuperação entra, e que nenhum é gasto.
      for c <- r.codigos do
        assert {:error, _} =
                 quieto(fn ->
                   Credentials.autenticar(r.email, Segredo.novo(senha_do_operador()), c)
                 end)
      end

      assert Repo.aggregate(
               from(rc in TheBand.Platform.RecoveryCode,
                 where: rc.operator_id == ^r.op.id and not is_nil(rc.used_at)
               ),
               :count
             ) == 0
    end
  end
end
