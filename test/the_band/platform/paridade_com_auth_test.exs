defmodule TheBand.Platform.ParidadeComAuthTest do
  @moduledoc """
  As duas autenticações esperam igual — spec 070, T034 (quickstart §3; research R2).

  `Platform.Credentials` é a cópia deliberada de `Tenants.Auth` depois das correções da #1046 e da
  #1047. Mudou lá, tem de mudar aqui, e este teste reprova no dia em que as duas divergirem. Compara
  os valores **calculados** pelas duas, e não literais copiados para cá.

  A forma da serialização (o `FOR UPDATE`) tem a guarda própria em cada lado: a captura do SQL em
  `test/the_band/tenants/auth_test.exs` e em `espera_paralela_test.exs`.
  """
  use ExUnit.Case, async: true

  alias TheBand.Platform.Credentials
  alias TheBand.Tenants.Auth

  test "a espera de 0 a 12 falhas é a mesma nas duas" do
    auth = Auth.tabela_da_espera()
    assert auth == Credentials.tabela_da_espera()

    # A guarda de que mediu: a tabela tem as livres, o crescimento e o teto.
    assert Enum.take(auth, 3) == [0, 0, 0]
    assert Enum.max(auth) > 0
    assert List.last(auth) == Enum.max(auth)
  end
end
