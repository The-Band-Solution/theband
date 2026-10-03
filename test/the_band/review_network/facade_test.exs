defmodule TheBand.ReviewNetwork.FacadeTest do
  @moduledoc """
  A fachada ligada à base — feature 073, T017.

  1. `windows/0` devolve o que a regra diz;
  2. nenhum valor de janela, k, amostra ou estado está escrito no código de
     `lib/the_band/review_network/` — o código é lido **sem comentários** (a explicação da
     proibição não pode reprovar o teste);
  3. a fachada só delega;
  4. `read/4` lê com os parâmetros da base.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.ReviewNetwork

  test "windows/0 devolve o que a regra diz" do
    assert ReviewNetwork.windows() == %{allowed: [30, 90, 180], default: 90}
  end

  test "nenhum parâmetro da base está escrito no código do módulo" do
    codigo =
      ["lib/the_band/review_network.ex" | Path.wildcard("lib/the_band/review_network/**/*.ex")]
      |> Enum.map_join("\n", fn arquivo ->
        arquivo
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
        |> Enum.join("\n")
      end)

    assert codigo =~ "defmodule TheBand.ReviewNetwork.Parameters"

    for proibido <- [
          ~r/\[\s*30\s*,\s*90\s*,\s*180\s*\]/,
          ~r/\[\s*1\s*,\s*2\s*,\s*3\s*\]/,
          ~r/"APPROVED"|~w\(APPROVED/
        ] do
      refute codigo =~ proibido, "valor da base escrito no código: #{inspect(proibido)}"
    end
  end

  test "a fachada só delega" do
    linhas =
      "lib/the_band/review_network.ex"
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&String.starts_with?(&1, ["def ", "defp "]))

    assert linhas == []
  end

  test "read/4 lê com os parâmetros da base" do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    org = organizacao_com_repositorio(tenant)

    assert ReviewNetwork.read(tenant, admin, org.organization.id, "90") ==
             {:ausente, :not_computed}

    assert ReviewNetwork.read(tenant, admin, org.organization.id, "45") ==
             {:error, :janela_invalida}
  end
end
