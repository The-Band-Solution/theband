defmodule TheBand.MCP.EnvelopeTest do
  @moduledoc """
  O envelope de proveniência — feature 062, T004.

  A asserção que importa é que **as ressalvas vêm da base**, e não do código. Por isso o teste as
  compara com o que a `KnowledgeBase` devolve para o mesmo id: um envelope que escrevesse um
  texto fixo passaria num teste que só conferisse `limitations != []`.

  **SC-001, "100% das respostas de medida carregam proveniência", é medido quando as ferramentas
  existirem**: a varredura por todas as ferramentas registradas entra com o registro (T006) e com
  as quatro ferramentas (T010–T013). Aqui se prova a peça que elas vão usar.
  """
  use ExUnit.Case, async: true

  alias TheBand.MCP.Envelope
  alias TheBand.Ontology.KnowledgeBase

  @medida "review.time_to_first_review.duration"
  @mapeamento "github.team_member.to.eo.person"

  defp base(extra) do
    Keyword.merge(
      [
        value: 1,
        composition: %{is_composed: false},
        window: nil,
        origin: "observed",
        collected_at: nil
      ],
      extra
    )
  end

  test "as ressalvas de uma medida são as que a base declara, e não outras" do
    {:ok, medida} = KnowledgeBase.measurement(@medida)

    e = Envelope.montar(base(ressalvas: {:medida, @medida}, origin: "derived"))

    assert e.measurement_id == @medida
    assert [_ | _] = e.limitations
    assert e.limitations == medida["limitations"]
    assert e.misinterpretations == medida["misinterpretations"]
  end

  test "de um mapeamento vêm as limitations, e misinterpretations é [] dito, e não ausente" do
    {:ok, mapeamento} = KnowledgeBase.mapping(@mapeamento)

    e = Envelope.montar(base(ressalvas: {:mapeamento, @mapeamento}))

    assert e.limitations == mapeamento["limitations"]
    assert Map.has_key?(e, :misinterpretations)
    assert e.misinterpretations == []
    assert e.measurement_id == nil
  end

  test "window: nil aparece como chave, e não é omitido" do
    e = Envelope.montar(base(ressalvas: {:mapeamento, @mapeamento}))

    assert Map.has_key?(e, :window)
    assert e.window == nil
  end

  test "window não passado é erro, e não um nil presumido" do
    sem_janela = Keyword.delete(base(ressalvas: {:mapeamento, @mapeamento}), :window)
    assert_raise KeyError, fn -> Envelope.montar(sem_janela) end
  end

  test "rule vem preenchida só quando a origem é derivada" do
    e =
      Envelope.montar(
        base(ressalvas: {:medida, @medida}, origin: "derived", regra: "profile.thresholds")
      )

    assert e.rule == %{id: "profile.thresholds", version: 1}

    assert Envelope.montar(base(ressalvas: {:medida, @medida}, origin: "derived")).rule == nil

    assert_raise ArgumentError, ~r/só um valor derivado tem regra/, fn ->
      Envelope.montar(base(ressalvas: {:medida, @medida}, regra: "profile.thresholds"))
    end
  end

  test "id que a base não tem levanta erro, e não produz resposta sem ressalva" do
    assert_raise ArgumentError, ~r/não tem a medida/, fn ->
      Envelope.montar(base(ressalvas: {:medida, "nao.existe"}))
    end

    assert_raise ArgumentError, ~r/não tem a regra/, fn ->
      Envelope.montar(base(ressalvas: {:medida, @medida}, origin: "derived", regra: "nao.existe"))
    end
  end

  test "origem fora da casa é recusada" do
    assert_raise ArgumentError, ~r/não é da casa/, fn ->
      Envelope.montar(base(ressalvas: {:medida, @medida}, origin: "inferred"))
    end
  end

  test "o envelope traz os nove campos do data-model, nenhum a mais e nenhum a menos" do
    e = Envelope.montar(base(ressalvas: {:medida, @medida}))

    assert e |> Map.keys() |> Enum.sort() ==
             Enum.sort(~w(value composition window origin rule measurement_id limitations
                         misinterpretations collected_at)a)
  end
end
