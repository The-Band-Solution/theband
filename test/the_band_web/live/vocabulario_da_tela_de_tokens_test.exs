defmodule TheBandWeb.VocabularioDaTelaDeTokensTest do
  @moduledoc """
  A tela de tokens e a base de conhecimento dizem **a mesma palavra** para o mesmo estado.

  ## O defeito

  A coluna `state` imprimia o átomo que `Token.estado/2` devolve — e esses átomos são em
  português. A tela servia **"ativo"**, **"revogado"**, **"expirado"** numa interface em
  inglês, enquanto `api.access.token_state` e a API diziam `active`, `revoked`, `expired`.

  Duas palavras para o mesmo estado: quem integra lê uma na tela e programa contra a outra.

  Arquivo separado de propósito: `tela_de_tokens_test.exs` está sendo mexido em outra branch,
  e um teste que não conflita é um teste que não é resolvido às pressas num merge.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  # As palavras vêm da BASE, e não daqui: escrevê-las neste teste o faria passar no dia em que
  # a tela e a regra divergissem — que é exatamente o defeito que ele existe para pegar.
  defp palavras_declaradas do
    {:ok, regra} = KnowledgeBase.rule("api.access.thresholds")

    regra
    |> get_in(["vocabulary", "token_state", "values"])
    |> Map.keys()
    |> Enum.sort()
  end

  test "a coluna de estado imprime a palavra declarada, e nunca o átomo", ctx do
    {:ok, _token, _valor} =
      Tenants.create_api_token(
        ctx.tenant,
        ctx.admin,
        %{label: "vocabulário"},
        ctx.admin
      )

    {:ok, _view, html} = live(ctx.conn, ~p"/api-tokens")

    [celula] = Regex.run(~r/<td data-label="state".*?<\/td>/s, html)

    assert celula =~ "active", """
    A célula de estado não traz a palavra declarada em `api.access.token_state`.

    célula: #{celula}
    """

    for portugues <- ~w(ativo revogado expirado) do
      refute celula =~ portugues, """
      A tela imprimiu o átomo em português — `#{portugues}`.

      A interface serve em inglês, e a API diz `active`/`revoked`/`expired`. Duas palavras
      para o mesmo estado fazem quem integra ler uma e programar contra a outra.
      """
    end
  end

  test "as três palavras da base têm o elo com o átomo que a tela compara" do
    assert palavras_declaradas() == ~w(active expired revoked)

    # O elo é o campo `atom` de cada estado. Sem ele, `palavra_do_estado/1` devolve o próprio
    # átomo — e a tela volta a falar português sem ninguém reparar.
    for {atomo, palavra} <- [ativo: "active", revogado: "revoked", expirado: "expired"] do
      assert Tenants.api_token_state_word(atomo) == palavra, """
      O estado `#{atomo}` não resolve para `#{palavra}`.

      O elo mora em `api.access.token_state`, no campo `atom` de cada valor. Se ele sumir, a
      função devolve o átomo cru e a tela serve português.
      """
    end
  end
end
