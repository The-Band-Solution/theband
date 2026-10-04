defmodule TheBand.Telemetria.ComposeSignozTest do
  # #1313 — o compose do SigNoz que o Dokploy implanta, lido como dado (spec 074; ADR 0005, D3,
  # E7; seguranca.md, S6 e S7).
  #
  # Os três defeitos que este arquivo guarda passaram pela revisão porque viviam em dois lugares
  # que ninguém comparava: o host que a aplicação aceita (`Configuracao`) e o nome que o coletor
  # tem na rede (P2); o profile que o Dokploy não passa (P4); e a rede que um serviço Swarm não
  # consegue usar (P3). O YAML é lido pelo parser, e não por regex — comentário não conta.
  use ExUnit.Case, async: true

  alias TheBand.Telemetria.Configuracao

  @producao "deploy/signoz/compose.yaml"
  @desenvolvimento "deploy/signoz/compose.local.yaml"
  @hosts_locais ["127.0.0.1", "localhost"]

  defp ler(caminho), do: YamlElixir.read_from_file!(caminho)

  # Toda chave `nome` em qualquer profundidade, com o caminho até ela — inclusive dentro das
  # âncoras `x-*` e dos `<<:`, que é onde o profile morava.
  defp chaves(no, nome, caminho \\ [])

  defp chaves(no, nome, caminho) when is_map(no) do
    Enum.flat_map(no, fn {k, v} ->
      aqui = if k == nome, do: [Enum.reverse([k | caminho])], else: []
      aqui ++ chaves(v, nome, [k | caminho])
    end)
  end

  defp chaves(no, nome, caminho) when is_list(no),
    do: no |> Enum.with_index() |> Enum.flat_map(fn {v, i} -> chaves(v, nome, [i | caminho]) end)

  defp chaves(_no, _nome, _caminho), do: []

  # Os nomes por que o coletor responde na rede `telemetria`: o do serviço e os aliases dela.
  defp nomes_do_coletor_na_rede_telemetria(compose) do
    redes = get_in(compose, ["services", "otel-collector", "networks"])

    case redes do
      %{"telemetria" => config} -> ["otel-collector" | List.wrap((config || %{})["aliases"])]
      lista when is_list(lista) -> if "telemetria" in lista, do: ["otel-collector"], else: []
      _ -> []
    end
  end

  # O `yaml_elixir` entrega cada `<<:` como uma chave "<<1", "<<2"…, com o mapa da âncora.
  defp profiles_do_servico(servico) when is_map(servico) do
    herdados =
      servico
      |> Enum.filter(fn {chave, _} -> String.starts_with?(chave, "<<") end)
      |> Enum.flat_map(fn {_, ancora} -> List.wrap(ancora) end)
      |> Enum.flat_map(&List.wrap(&1["profiles"]))

    List.wrap(servico["profiles"]) ++ herdados
  end

  test "todo host de produção que a aplicação aceita é um nome do coletor na rede telemetria (P2)" do
    hosts_de_producao = Configuracao.hosts_permitidos() -- @hosts_locais
    nomes = nomes_do_coletor_na_rede_telemetria(ler(@producao))

    assert hosts_de_producao != [], "a lista não tem host de produção nenhum"

    for host <- hosts_de_producao do
      assert host in nomes,
             "a aplicação aceita #{host}, mas na rede telemetria o coletor só responde por " <>
               inspect(nomes)
    end
  end

  test "o compose de produção não tem profile em lugar nenhum: o Dokploy não passa --profile (P4)" do
    assert chaves(ler(@producao), "profiles") == []
  end

  test "o override de desenvolvimento põe no profile telemetria cada serviço do compose" do
    servicos = ler(@producao)["services"] |> Map.keys()
    locais = ler(@desenvolvimento)["services"]

    for servico <- servicos do
      assert "telemetria" in profiles_do_servico(Map.get(locais, servico, %{})),
             "#{servico} subiria com `docker compose up` na raiz, junto com o Postgres"
    end
  end

  test "o compose de produção não publica porta nenhuma (S6)" do
    assert chaves(ler(@producao), "ports") == []
  end

  test "a rede telemetria é externa e de nome fixo, para a overlay attachable do VPS (P3)" do
    rede = get_in(ler(@producao), ["networks", "telemetria"])

    assert rede["external"] == true
    assert rede["name"] == "the-band-telemetria"
  end

  test "em desenvolvimento, a rede telemetria deixa de ser externa e o compose a cria" do
    assert get_in(ler(@desenvolvimento), ["networks", "telemetria", "external"]) == false
  end
end
