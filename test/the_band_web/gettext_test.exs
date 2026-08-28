defmodule TheBandWeb.GettextTest do
  @moduledoc """
  O contrato do catálogo (feature 047): dois idiomas conhecidos, "en" como padrão
  (research R2 — o msgid é a frase da tela), e lacuna devolvendo o msgid, nunca
  chave crua.
  """
  use ExUnit.Case, async: true

  use Gettext, backend: TheBandWeb.Gettext

  test "os dois idiomas são conhecidos, e o padrão é en" do
    assert Enum.sort(Gettext.known_locales(TheBandWeb.Gettext)) == ["en", "pt"]
    assert Gettext.get_locale(TheBandWeb.Gettext) == "en"
  end

  test "chave sem tradução devolve o próprio msgid — nunca chave crua na tela" do
    # FR-005: a frase fonte É o fallback, por design do gettext.
    assert dgettext("errors", "uma frase que não existe no catálogo") ==
             "uma frase que não existe no catálogo"
  end
end
