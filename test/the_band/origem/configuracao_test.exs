defmodule TheBand.Origem.ConfiguracaoTest do
  @moduledoc """
  Os três estados da origem, e a configuração errada que não sobe — spec 077, T004 e T010
  (FR-005, FR-009; seguranca.md, L1, L3; Q17).
  """
  use ExUnit.Case, async: true

  alias TheBand.Origem.Configuracao

  defp proxy(lista, cabecalho \\ "x-forwarded-for") do
    %{
      "THE_BAND_ORIGEM" => "proxy",
      "THE_BAND_ORIGEM_CABECALHO" => cabecalho,
      "THE_BAND_ORIGEM_PROXIES" => lista
    }
  end

  describe "os três estados" do
    test "sem THE_BAND_ORIGEM, o estado é não declarado — o limite só observa" do
      assert Configuracao.ler!(%{}) == %{estado: :nao_declarada}

      assert Configuracao.ler!(%{"THE_BAND_ORIGEM_PROXIES" => "10.0.0.0/8"}).estado ==
               :nao_declarada
    end

    test "socket declarado" do
      assert Configuracao.ler!(%{"THE_BAND_ORIGEM" => "socket"}) == %{estado: :socket}
    end

    test "proxy com cabeçalho e blocos de rede local" do
      assert Configuracao.ler!(proxy("10.0.1.0/24, 172.18.0.0/16,fd00::/8")) == %{
               estado: :proxy,
               cabecalho: "x-forwarded-for",
               proxies: [
                 {{10, 0, 1, 0}, 24},
                 {{172, 18, 0, 0}, 16},
                 {{0xFD00, 0, 0, 0, 0, 0, 0, 0}, 8}
               ]
             }
    end
  end

  describe "a configuração errada não sobe, e a mensagem não leva o valor (Q17)" do
    test "/0, faixa pública, malformado e lista vazia levantam" do
      for {lista, variavel} <- [
            {"0.0.0.0/0", "THE_BAND_ORIGEM_PROXIES"},
            {"::/0", "THE_BAND_ORIGEM_PROXIES"},
            {"8.8.8.0/24", "THE_BAND_ORIGEM_PROXIES"},
            {"10.0.0.0/8,198.51.100.0/24", "THE_BAND_ORIGEM_PROXIES"},
            {"abc", "THE_BAND_ORIGEM_PROXIES"},
            {"", "THE_BAND_ORIGEM_PROXIES"},
            {" , ", "THE_BAND_ORIGEM_PROXIES"}
          ] do
        erro = assert_raise ArgumentError, fn -> Configuracao.ler!(proxy(lista)) end
        assert erro.message =~ variavel, lista

        for pedaco <- String.split(lista, ",", trim: true), String.trim(pedaco) != "" do
          refute erro.message =~ String.trim(pedaco), "a mensagem levou o valor #{pedaco}"
        end
      end
    end

    test "um bloco local maior que a rede local (10.0.0.0/7) é recusado" do
      assert_raise ArgumentError, fn -> Configuracao.ler!(proxy("10.0.0.0/7")) end
    end

    test "cabeçalho ausente ou com maiúsculas levanta pela variável do cabeçalho" do
      for cabecalho <- ["", "X-Forwarded-For", "x forwarded"] do
        erro =
          assert_raise ArgumentError, fn -> Configuracao.ler!(proxy("10.0.0.0/8", cabecalho)) end

        assert erro.message =~ "THE_BAND_ORIGEM_CABECALHO"
      end
    end

    test "estado desconhecido levanta" do
      erro =
        assert_raise ArgumentError, fn -> Configuracao.ler!(%{"THE_BAND_ORIGEM" => "header"}) end

      assert erro.message =~ "THE_BAND_ORIGEM"
      refute erro.message =~ "header"
    end
  end

  describe "a linha do log de subida (T010, FR-009)" do
    test "socket e proxy dizem que o limite está ligado, e de onde" do
      assert Configuracao.frase(%{estado: :socket}) =~ "ligado, pela origem do socket"

      frase = Configuracao.frase(Configuracao.ler!(proxy("10.0.1.0/24")))
      assert frase =~ "ligado, pelo cabeçalho x-forwarded-for vindo de 10.0.1.0/24"
    end

    test "o não declarado diz que o limite só observa e não recusa" do
      frase = Configuracao.frase(%{estado: :nao_declarada})

      assert frase =~ "só observado"
      assert frase =~ "nenhuma tentativa é recusada"
      refute frase =~ "ligado"
    end
  end
end
