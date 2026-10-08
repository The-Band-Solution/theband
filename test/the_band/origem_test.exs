defmodule TheBand.OrigemTest do
  @moduledoc """
  A origem normalizada — spec 077, T003 (FR-007, FR-011; seguranca.md, L2, L10, L12; Q13–Q15).
  Só endereços de documentação (RFC 5737, RFC 3849).
  """
  use ExUnit.Case, async: true

  alias TheBand.Origem

  # `::ffff:198.51.100.7` e `::ffff:198.51.100.8`, como o Bandit entrega um par IPv4 quando
  # escuta em `::` (seguranca.md, L2).
  @mapeado_7 {0, 0, 0, 0, 0, 0xFFFF, 0xC633, 0x6407}
  @mapeado_8 {0, 0, 0, 0, 0, 0xFFFF, 0xC633, 0x6408}

  describe "normalizar e contar (Q13, Q14)" do
    test "dois IPv4 diferentes chegando mapeados são DUAS origens, cada uma o IPv4" do
      a = Origem.de_endereco(@mapeado_7, :socket)
      b = Origem.de_endereco(@mapeado_8, :socket)

      assert a.chave == "198.51.100.7"
      assert b.chave == "198.51.100.8"
      refute a.chave == b.chave
    end

    test "o mapeado e o IPv4 cru são a mesma origem" do
      assert Origem.de_endereco(@mapeado_7, :socket).chave ==
               Origem.de_endereco({198, 51, 100, 7}, :socket).chave
    end

    test "dois IPv6 do mesmo /64 são uma origem; de /64 diferentes, duas" do
      a = Origem.de_endereco({0x2001, 0xDB8, 1, 2, 0, 0, 0, 1}, :socket)
      b = Origem.de_endereco({0x2001, 0xDB8, 1, 2, 0xABCD, 0, 0, 9}, :socket)
      c = Origem.de_endereco({0x2001, 0xDB8, 1, 3, 0, 0, 0, 1}, :socket)

      assert a.chave == "2001:db8:1:2::/64"
      assert a.chave == b.chave
      refute a.chave == c.chave
    end

    test "o que não é endereço tem uma origem fixa nomeada, sem levantar" do
      for socket <- [{:local, "/tmp/x.sock"}, :unspec, nil, {300, 1, 1, 1}] do
        assert %Origem{chave: "sem-endereco", prefixo: "sem-endereco"} =
                 Origem.de_endereco(socket, :socket)
      end
    end

    test "o estado vai na struct" do
      assert Origem.de_endereco({192, 0, 2, 1}, :nao_declarada).estado == :nao_declarada
    end
  end

  describe "o prefixo é a única forma do endereço para o log (L10)" do
    test "IPv4 pelo /24 e IPv6 pelo /48, e a struct não guarda o endereço inteiro" do
      v4 = Origem.de_endereco({198, 51, 100, 23}, :socket)
      v6 = Origem.de_endereco({0x2001, 0xDB8, 0xAB, 0xCD, 0, 0, 0, 1}, :socket)

      assert v4.prefixo == "198.51.100.0/24"
      assert v6.prefixo == "2001:db8:ab::/48"
      assert Map.keys(Map.from_struct(v4)) |> Enum.sort() == [:chave, :estado, :prefixo]
    end
  end

  describe "a análise é estrita (Q15, L12)" do
    test "aceita endereço completo, com espaço em volta" do
      assert Origem.analisar_estrito(" 198.51.100.9 ") == {:ok, {198, 51, 100, 9}}
      assert Origem.analisar_estrito("2001:db8::1") == {:ok, {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}}
    end

    test "o mapeado em texto sai já normalizado" do
      assert Origem.analisar_estrito("::ffff:198.51.100.7") == {:ok, {198, 51, 100, 7}}
    end

    test "recusa forma curta, hexadecimal, zona, porta, colchetes e vazio" do
      for texto <- [
            "127.1",
            "0x7f.0.0.1",
            "fe80::1%eth0",
            "198.51.100.9:443",
            "[2001:db8::1]:443",
            "[2001:db8::1]",
            "",
            "  ",
            "abc"
          ] do
        assert Origem.analisar_estrito(texto) == :error, texto
      end
    end
  end

  describe "pertence?/2" do
    test "o socket mapeado casa a lista IPv4" do
      assert Origem.pertence?({0, 0, 0, 0, 0, 0xFFFF, 0x0A00, 0x0001}, {{10, 0, 0, 0}, 8})
    end

    test "fora do bloco, e família diferente, não casa" do
      refute Origem.pertence?({11, 0, 0, 1}, {{10, 0, 0, 0}, 8})
      refute Origem.pertence?({0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}, {{10, 0, 0, 0}, 8})
    end

    test "analisar_cidr lê endereço/bits, e sem bits é o endereço sozinho" do
      assert Origem.analisar_cidr("10.0.1.0/24") == {:ok, {{10, 0, 1, 0}, 24}}
      assert Origem.analisar_cidr("10.0.1.5") == {:ok, {{10, 0, 1, 5}, 32}}
      assert Origem.analisar_cidr("10.0.1.0/33") == :error
      assert Origem.analisar_cidr("10.0.1.0/x") == :error
    end
  end
end
