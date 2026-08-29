defmodule TheBandWeb.IdiomaTest do
  @moduledoc """
  US3 da 047: o idioma configurado decide o que a tela diz, e a frase vem do
  catálogo — a mesma recusa, dois idiomas, trocando SÓ a configuração (FR-005).
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, _admin} = tenant_with_admin()

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "idioma-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: log_in(conn, member), member: member}
  end

  test "a recusa de administração sai no idioma configurado, vinda do catálogo", ctx do
    # No padrão (en), o msgid é a frase.
    assert {:error, {:redirect, %{flash: flash}}} = live(ctx.conn, ~p"/accounts")
    assert flash["error"] == "Only organisation administrators can do that."

    # Trocar a plataforma de idioma é trocar UMA config (FR-005) — a do app
    # :gettext, a única lida em runtime — e a frase nova veio do
    # priv/gettext/pt/LC_MESSAGES/errors.po, não de código.
    original = Application.get_env(:gettext, :default_locale)
    on_exit(fn -> Application.put_env(:gettext, :default_locale, original) end)
    Application.put_env(:gettext, :default_locale, "pt")

    # Conn NOVA: reusar a primeira arrastaria o flash inglês dela na reciclagem,
    # e o teste compararia a mensagem velha consigo mesmo.
    conn = log_in(Phoenix.ConnTest.build_conn(), ctx.member)
    assert {:error, {:redirect, %{flash: flash}}} = live(conn, ~p"/accounts")
    assert flash["error"] == "Só quem administra a organização pode fazer isso."
  end

  test "chave sem tradução em pt cai no msgid — nunca chave crua nem tela vazia" do
    Gettext.put_locale(TheBandWeb.Gettext, "pt")
    on_exit(fn -> Gettext.put_locale(TheBandWeb.Gettext, "en") end)

    # "The tool refused the credential." tem tradução; uma frase sem tradução volta ela mesma.
    assert Gettext.dgettext(
             TheBandWeb.Gettext,
             "errors",
             "The tool refused the credential. Nothing was saved."
           ) ==
             "A ferramenta recusou a credencial. Nada foi salvo."

    assert Gettext.dgettext(TheBandWeb.Gettext, "sistema", "Sync started.") == "Sync started."
  end
end
