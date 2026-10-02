defmodule TheBand.Platform.SuspensionReasonsTest do
  @moduledoc """
  As razões de suspender e de reativar, lidas da base — spec 070, T048 (FR-003).
  """
  use ExUnit.Case, async: false

  alias TheBand.Platform.SuspensionReasons

  defp codigos(razoes), do: Enum.map(razoes, & &1["code"])

  test "as de suspender são as quatro aprovadas, sem not_recorded" do
    assert codigos(SuspensionReasons.de_suspensao()) ==
             ~w(suspected_compromise contract_ended requested_by_the_organisation other)

    assert SuspensionReasons.so_registradas() == ["not_recorded"]
  end

  test "investigation_closed_no_compromise só contra suspected_compromise" do
    contra_comprometimento = codigos(SuspensionReasons.de_reativacao("suspected_compromise"))
    contra_contrato = codigos(SuspensionReasons.de_reativacao("contract_ended"))

    assert "investigation_closed_no_compromise" in contra_comprometimento
    refute "investigation_closed_no_compromise" in contra_contrato
    assert contra_contrato == ~w(contract_resumed suspended_by_mistake other)
  end

  test "a nota é obrigatória onde a base diz, e a frase da ausência vem dela" do
    assert SuspensionReasons.nota_obrigatoria?(:suspender, "suspected_compromise")
    assert SuspensionReasons.nota_obrigatoria?(:suspender, "other")
    refute SuspensionReasons.nota_obrigatoria?(:suspender, "contract_ended")
    assert SuspensionReasons.nota_obrigatoria?(:reativar, "other")
    refute SuspensionReasons.nota_obrigatoria?(:reativar, "contract_resumed")
    assert SuspensionReasons.frase_sem_nota() == "no note"
  end

  test "o rótulo vem da base, inclusive o de not_recorded; código sem rótulo imprime o código" do
    assert SuspensionReasons.rotulo("not_recorded") == "The reason was not recorded"
    assert SuspensionReasons.rotulo("contract_ended") == "The contract ended"
    assert SuspensionReasons.rotulo("inventado") == "inventado"
  end

  test "a base sem a regra: listas vazias, e o vocabulário não declarado" do
    Application.put_env(:the_band, SuspensionReasons, regra: "platform.regra_que_nao_existe")
    on_exit(fn -> Application.delete_env(:the_band, SuspensionReasons) end)

    assert SuspensionReasons.de_suspensao() == []
    assert SuspensionReasons.de_reativacao("suspected_compromise") == []
    assert SuspensionReasons.so_registradas() == []
    refute SuspensionReasons.vocabulario_declarado?()
  end
end
