defmodule TheBand.Telemetria.DependenciasTest do
  # Spec 074, T004 — as dependências do OpenTelemetry fixadas como a D5 aceitou (seguranca.md,
  # S9; ADR 0005, E6). Lê a configuração do projeto e o lock, e não o texto do `mix.exs`.
  use ExUnit.Case, async: true

  alias Mix.Dep.Lock

  @exatas %{
    opentelemetry_api: "== 1.5.0",
    opentelemetry: "== 1.7.0",
    opentelemetry_exporter: "== 1.11.0"
  }

  defp requisito(nome) do
    Mix.Project.config()[:deps]
    |> Enum.find(&(elem(&1, 0) == nome))
    |> case do
      {^nome, requisito} when is_binary(requisito) -> requisito
      {^nome, requisito, _opcoes} when is_binary(requisito) -> requisito
      outro -> flunk("#{nome} não está declarado como esperado: #{inspect(outro)}")
    end
  end

  test "as três diretas têm versão exata" do
    for {nome, esperado} <- @exatas, do: assert(requisito(nome) == esperado)
  end

  test "grpcbox está declarado direto, só pelo teto 0.18.x" do
    assert requisito(:grpcbox) == "~> 0.18.0"
  end

  test "nenhum instrumentador automático entrou no lock" do
    lock = Lock.read()

    instrumentadores =
      lock
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)
      |> Enum.filter(&String.starts_with?(&1, "opentelemetry_"))

    assert Enum.sort(instrumentadores) == ["opentelemetry_api", "opentelemetry_exporter"]
  end

  test "o SDK é :temporary na release: uma falha dele não derruba o nó" do
    applications = get_in(Mix.Project.config(), [:releases, :the_band, :applications])
    assert applications[:opentelemetry] == :temporary
  end
end
