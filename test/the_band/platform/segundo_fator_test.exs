defmodule TheBand.Platform.SegundoFatorTest do
  @moduledoc """
  O segundo fator TOTP — spec 070, T022 (FR-016). Funções puras, com o relógio fixado.
  """
  use ExUnit.Case, async: true

  alias TheBand.Platform.SegundoFator
  alias TheBand.Segredo

  # RFC 6238, apêndice B, SHA-1: o segredo é o ASCII "12345678901234567890". Os vetores têm oito
  # dígitos, e NimbleTOTP fixa seis: confere-se os seis últimos.
  @segredo_rfc Segredo.novo("12345678901234567890")
  @vetores [
    {59, "94287082"},
    {1_111_111_109, "07081804"},
    {1_111_111_111, "14050471"},
    {1_234_567_890, "89005924"},
    {2_000_000_000, "69279037"},
    {20_000_000_000, "65353130"}
  ]

  defp em(t), do: DateTime.from_unix!(t)
  defp codigo(c), do: Segredo.novo(c)

  test "os vetores do RFC 6238 conferem, e o passo devolvido é o do instante" do
    for {t, oito} <- @vetores do
      seis = String.slice(oito, -6, 6)
      assert {:ok, passo} = SegundoFator.conferir(@segredo_rfc, codigo(seis), nil, em(t))
      assert passo == div(t, 30), "vetor #{t}"
    end
  end

  test "a janela é ±1: o código de um passo antes ou depois passa, o de dois depois não" do
    segredo = SegundoFator.gerar_segredo()
    t = 1_900_000_000

    do_passo = fn instante ->
      NimbleTOTP.verification_code(Segredo.expor(segredo), time: instante)
    end

    assert {:ok, _} = SegundoFator.conferir(segredo, codigo(do_passo.(t - 30)), nil, em(t))
    assert {:ok, _} = SegundoFator.conferir(segredo, codigo(do_passo.(t + 30)), nil, em(t))

    assert {:error, :codigo_errado} =
             SegundoFator.conferir(segredo, codigo(do_passo.(t + 60)), nil, em(t))
  end

  test "o mesmo código com o passo dele já usado é :reusado" do
    segredo = SegundoFator.gerar_segredo()
    t = 1_900_000_000
    c = codigo(NimbleTOTP.verification_code(Segredo.expor(segredo), time: t))

    assert {:ok, passo} = SegundoFator.conferir(segredo, c, nil, em(t))
    assert {:error, :reusado} = SegundoFator.conferir(segredo, c, passo, em(t))
  end

  test "C2: dez códigos distintos de 16 bytes, e classificar reconhece só os 26 caracteres" do
    codigos = SegundoFator.gerar_codigos_de_recuperacao()

    assert length(codigos) == 10
    assert codigos |> Enum.map(&Segredo.expor/1) |> Enum.uniq() |> length() == 10

    for c <- codigos do
      com_hifen = Segredo.expor(c)
      sem_hifen = String.replace(com_hifen, "-", "")

      assert byte_size(Base.decode32!(sem_hifen, case: :lower, padding: false)) == 16
      assert SegundoFator.classificar(codigo(com_hifen)) == :recuperacao
      assert SegundoFator.classificar(codigo(String.upcase(sem_hifen))) == :recuperacao
    end

    assert SegundoFator.classificar(codigo("abcdefghijklmnop")) == :malformado
  end

  test "T6: classificar só aceita ASCII, e um \\n final não passa" do
    assert SegundoFator.classificar(codigo("123 456")) == :totp
    assert SegundoFator.classificar(codigo("١٢٣٤٥٦")) == :malformado
    assert SegundoFator.classificar(codigo("123456\n")) == :malformado
    # O sinal de Kelvin (U+212A) não é a letra k.
    assert SegundoFator.classificar(codigo("abcd-efgh-ijkl-mnop-qrst-uvwK")) == :malformado
  end

  test "o resumo é do código normalizado, com ou sem hífen e caixa" do
    assert SegundoFator.resumo(codigo("ABCD-EFGH")) == SegundoFator.resumo(codigo("abcdefgh"))
  end

  test "a URI carrega o segredo e o emissor, e sai como Segredo" do
    uri = SegundoFator.uri(@segredo_rfc, "op@example.org")
    assert Segredo.segredo?(uri)
    assert Segredo.expor(uri) =~ ~r{^otpauth://totp/The%20Band%20Platform:op@example.org\?secret=}
  end
end
