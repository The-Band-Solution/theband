defmodule TheBand.Platform.LogDoOperadorTest do
  @moduledoc """
  O log diz quem é o operador e cala os segredos dele — spec 070, T016 (O14, A10; cenário 9 de
  `seguranca-autenticacao.md`).
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  require Logger

  test "os códigos e o segredo do operador saem filtrados dos parâmetros" do
    filtrado =
      Phoenix.Logger.filter_values(%{
        "setup_token" => "codigo-de-definicao",
        "second_factor_token" => "codigo-de-guarda",
        "code" => "123456",
        "recovery_code" => "abcdefghijklmnopqrstuvwxyz",
        "totp_secret" => "JBSWY3DPEHPK3PXP",
        "email" => "op@example.org"
      })

    for campo <- ~w(setup_token second_factor_token code recovery_code totp_secret) do
      assert filtrado[campo] == "[FILTERED]", "#{campo} vazou para o log"
    end

    assert filtrado["email"] == "op@example.org", "o filtro não pode engolir o que não é segredo"
  end

  test "a linha de log de um ato do operador diz o operator_id" do
    formato = Logger.Formatter.new(format: "$metadata$message", metadata: formatador_metadata())

    log =
      capture_log([formatter: formato, metadata: :all], fn ->
        Logger.metadata(operator_id: "operador-1")
        # `warning`, e não `info`: o ambiente de teste corta o que está abaixo dele.
        Logger.warning("suspendeu")
      end)

    assert log =~ "operator_id=operador-1"
  end

  defp formatador_metadata,
    do: Application.get_env(:logger, :default_formatter) |> Keyword.fetch!(:metadata)
end
