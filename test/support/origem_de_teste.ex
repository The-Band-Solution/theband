defmodule TheBand.OrigemDeTeste do
  @moduledoc """
  Origens de teste — spec 077, T007.

  Cada chamada é um visitante novo: um `/64` próprio de `2001:db8::/32` (RFC 3849, só
  documentação). Sem isso, toda tentativa de teste viria de `127.0.0.1` e os testes assíncronos
  que entram e erram dividiriam o contador do limite por origem, reprovando conforme a ordem.
  Os testes do limite fixam a origem que querem.
  """

  alias TheBand.Origem

  @doc "Um endereço de documentação novo, um `/64` por chamada."
  @spec endereco() :: :inet.ip6_address()
  def endereco do
    n = System.unique_integer([:positive])
    {0x2001, 0x0DB8, rem(div(n, 65_536), 65_536), rem(n, 65_536), 0, 0, 0, 1}
  end

  @doc "Uma origem nova, no estado `:socket` (o de `config/test.exs`)."
  @spec nova() :: Origem.t()
  def nova, do: Origem.de_endereco(endereco(), :socket)
end
