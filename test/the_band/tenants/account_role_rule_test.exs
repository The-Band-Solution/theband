defmodule TheBand.Tenants.AccountRoleRuleTest do
  @moduledoc "O vocabulário da marca de administrador vem da base — spec 072, T005 (R6)."
  use ExUnit.Case, async: true

  alias TheBand.Tenants.AccountRole

  test "os dois papéis têm rótulo declarado, e batem com o CHECK do banco" do
    assert Enum.sort(AccountRole.codigos()) == ["admin", "member"]
    assert AccountRole.rotulo("admin") == "administrator"
    assert AccountRole.rotulo("member") == "member"
  end

  test "um código que a base não conhece aparece como é, e não com rótulo inventado" do
    assert AccountRole.rotulo("owner") == "owner"
  end

  test "as frases da recusa e da ausência vêm da base" do
    assert AccountRole.frase_ultimo_admin() ==
             "the organisation would have no active administrator"

    assert AccountRole.frase_sem_registro() == "no role change recorded"
  end
end
