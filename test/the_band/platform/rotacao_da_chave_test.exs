defmodule TheBand.Platform.RotacaoDaChaveTest do
  @moduledoc """
  A rotação da chave mestra alcança o segredo TOTP do operador — spec 070, T023a, cenário **C10** de
  `seguranca-totp.md` (achado T3). **Bloqueia a release**, e é o critério "C10 verde" de T064.

  Sem isso, depois de uma rotação o `totp_secret` fica ilegível e o operador perde a entrada: a
  conta mais poderosa trancada do lado de fora, no momento em que alguém pode precisar dela.

  `async: false`, porque o `Vault` é global e o teste o reinicia com outras chaves.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.Credentials
  alias TheBand.Rotacao
  alias TheBand.Segredo

  setup do
    original = Application.get_env(:the_band, TheBand.Vault)

    on_exit(fn ->
      Application.put_env(:the_band, TheBand.Vault, original)
      reiniciar_vault()
    end)

    %{original: original}
  end

  test "C10: rotacionar para a chave nova, retirar a antiga, e o operador entra com o TOTP", %{
    original: original
  } do
    {op, segredo} = operador_pronto()

    antiga = Keyword.fetch!(original, :master_key)
    nova = Base.encode64(:crypto.strong_rand_bytes(32))

    trocar_chaves(original, master_key: nova, previous_key: antiga)
    assert {:ok, contagens} = Rotacao.recifrar(false)
    assert contagens["platform_operators"] >= 1

    # Só a chave nova: é o estado depois de retirar a anterior do ambiente.
    trocar_chaves(original, master_key: nova, previous_key: nil)

    resultado =
      capture_log(fn ->
        send(
          self(),
          {:r, Credentials.autenticar(op.email, Segredo.novo(senha_do_operador()), totp(segredo))}
        )
      end)
      |> then(fn _ -> receive(do: ({:r, r} -> r)) end)

    assert {:ok, entrou} = resultado
    assert entrou.id == op.id
  end

  defp trocar_chaves(original, chaves) do
    Application.put_env(:the_band, TheBand.Vault, Keyword.merge(original, chaves))
    reiniciar_vault()
  end

  defp reiniciar_vault do
    :ok = Supervisor.terminate_child(TheBand.Supervisor, TheBand.Vault)
    {:ok, _} = Supervisor.restart_child(TheBand.Supervisor, TheBand.Vault)
  end
end
