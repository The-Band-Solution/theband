defmodule TheBand.Telemetria.ConfiguracaoTest do
  # Spec 074, T005 — o SDK configurado explicitamente, e desligado por padrão (FR-015;
  # seguranca.md, S10). Um caso por situação, chamando a função que monta a configuração.
  use ExUnit.Case, async: false

  alias TheBand.Telemetria.Configuracao
  alias TheBand.Telemetria.Exportador

  defp destino({:ligada, sdk}) do
    {Exportador, %{destino: {:opentelemetry_exporter, %{endpoints: endpoints}}}} =
      Keyword.fetch!(sdk, :traces_exporter)

    endpoints
  end

  test "sem a variável, a telemetria fica desligada, e o motivo nomeia a variável" do
    assert Configuracao.montar(%{}) == {:desligada, "THE_BAND_OTLP_ENDPOINT ausente"}

    assert Configuracao.montar(%{"THE_BAND_OTLP_ENDPOINT" => ""}) ==
             {:desligada, "THE_BAND_OTLP_ENDPOINT ausente"}
  end

  test "com um host fora da lista, fica desligada, e o motivo NÃO traz o valor" do
    valor = "http://coletor.terceiro.example:4318"

    assert {:desligada, motivo} = Configuracao.montar(%{"THE_BAND_OTLP_ENDPOINT" => valor})
    assert motivo == "THE_BAND_OTLP_ENDPOINT fora dos hosts permitidos"
    refute motivo =~ "terceiro"
  end

  test "esquema, porta, credencial, caminho e consulta fora da forma também desligam" do
    for valor <- [
          "https://127.0.0.1:4318",
          "http://127.0.0.1:9999",
          "http://usuario:senha@127.0.0.1:4318",
          "http://127.0.0.1:4318/outro",
          "http://127.0.0.1:4318?x=1",
          "127.0.0.1:4318"
        ] do
      assert {:desligada, _} = Configuracao.montar(%{"THE_BAND_OTLP_ENDPOINT" => valor}),
             "ligou com #{valor}"
    end
  end

  test "com o coletor da rede interna, liga com o filtro no caminho, http_protobuf e sem amostragem" do
    estado =
      Configuracao.montar(%{
        "THE_BAND_OTLP_ENDPOINT" => "http://signoz-otel-collector:4318",
        "THE_BAND_AMBIENTE" => "prod"
      })

    assert {:ligada, sdk} = estado
    assert destino(estado) == ["http://signoz-otel-collector:4318"]
    assert Keyword.fetch!(sdk, :sampler) == :always_on
    assert [{:otel_batch_processor, _}] = Keyword.fetch!(sdk, :processors)

    {Exportador, opcoes} = Keyword.fetch!(sdk, :traces_exporter)
    assert {:opentelemetry_exporter, %{protocol: :http_protobuf}} = opcoes.destino
    assert opcoes.ambiente == "prod"
  end

  test "OTEL_EXPORTER_OTLP_ENDPOINT apontando para fora não vira destino" do
    ambiente = %{
      "THE_BAND_OTLP_ENDPOINT" => "http://127.0.0.1:4318",
      "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://coletor.terceiro.example:4318",
      "OTEL_TRACES_EXPORTER" => "otlp"
    }

    assert destino(Configuracao.montar(ambiente)) == ["http://127.0.0.1:4318"]

    assert Configuracao.variaveis_otel(ambiente) ==
             ["OTEL_EXPORTER_OTLP_ENDPOINT", "OTEL_TRACES_EXPORTER"]

    # Sozinha, a variável do SDK não liga nada.
    assert {:desligada, _} =
             Configuracao.montar(Map.delete(ambiente, "THE_BAND_OTLP_ENDPOINT"))
  end

  test "as variáveis OTEL_* são apagadas do ambiente do processo, e só os nomes voltam" do
    System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://coletor.terceiro.example:4318")
    on_exit(fn -> System.delete_env("OTEL_EXPORTER_OTLP_ENDPOINT") end)

    assert "OTEL_EXPORTER_OTLP_ENDPOINT" in Configuracao.neutralizar_ambiente_otel()
    assert System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") == nil
  end

  test "um ambiente com forma estranha vira prod no recurso" do
    {:ligada, sdk} =
      Configuracao.montar(%{
        "THE_BAND_OTLP_ENDPOINT" => "http://127.0.0.1:4318",
        "THE_BAND_AMBIENTE" => "prod; host=vps-123"
      })

    {Exportador, opcoes} = Keyword.fetch!(sdk, :traces_exporter)
    assert opcoes.ambiente == "prod"
  end
end
