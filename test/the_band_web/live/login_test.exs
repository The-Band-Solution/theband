defmodule TheBandWeb.LoginTest do
  @moduledoc """
  A porta — feature 045, US1 (login_test cobre T006 e T007).

  ## As asserções que carregam este arquivo

  1. **a tela não lista conta nenhuma** — a lacuna declarada morreu;
  2. **as recusas são indistintas** na resposta HTTP — flash e destino idênticos;
  3. **quem entra com a temporária não alcança tela nenhuma** antes de definir a
     senha (FR-013), e a definição libera;
  4. **trocar a senha derruba a outra sessão na próxima ação** (FR-015);
  5. **o destino pretendido sobrevive ao login** (FR-005).
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  @senha "senha-bem-comprida-123"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "m-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, member} = Tenants.set_password(tenant, member.id, @senha)

    %{conn: conn, tenant: tenant, admin: admin, member: member}
  end

  test "a tela de entrada não lista conta nenhuma", %{conn: conn, member: member} do
    {:ok, _view, html} = live(conn, ~p"/sign-in")

    refute html =~ member.email
    refute html =~ "card w-full bg-base-200 hover:bg-base-300"
    assert html =~ ~s(name="identifier")
    assert html =~ ~s(name="password")
    assert html =~ "Notas não são"
  end

  test "entrar por e-mail abre a sessão e navega", %{conn: conn, member: member} do
    conn = post(conn, ~p"/session", %{"identifier" => member.email, "password" => @senha})

    assert redirected_to(conn) == ~p"/people"
    assert get_session(conn, :user_id) == member.id
    assert get_session(conn, :session_token)
  end

  test "as quatro recusas respondem idêntico", %{member: member} do
    sem_senha_tenant = tenant_fixture()

    {:ok, sem_senha} =
      Tenants.create_user(sem_senha_tenant, %{
        "email" => "s-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    tentativas = [
      %{"identifier" => member.email, "password" => "senha-errada-e-longa"},
      %{"identifier" => "nao-existe@example.test", "password" => @senha},
      %{"identifier" => sem_senha.email, "password" => @senha},
      %{"identifier" => "username-sem-elo", "password" => @senha}
    ]

    respostas =
      for params <- tentativas do
        c = post(build_conn(), ~p"/session", params)
        {redirected_to(c), Phoenix.Flash.get(c.assigns.flash, :error), get_session(c, :user_id)}
      end

    assert [{"/sign-in", "Credenciais inválidas.", nil}] = Enum.uniq(respostas)
  end

  test "a temporária tranca toda tela até a senha definitiva (FR-013)", %{
    conn: conn,
    tenant: tenant,
    admin: admin,
    member: member
  } do
    {:ok, temporaria} = Tenants.reset_password(tenant, member.id, admin.id)

    conn = post(conn, ~p"/session", %{"identifier" => member.email, "password" => temporaria})
    assert redirected_to(conn) == ~p"/set-password"

    # Qualquer tela protegida devolve à definição de senha.
    assert {:error, {:redirect, %{to: "/set-password"}}} = live(conn, ~p"/people")

    conn =
      post(conn, ~p"/set-password", %{
        "password" => "definitiva-comprida-1",
        "password_confirmation" => "definitiva-comprida-1"
      })

    assert redirected_to(conn) == ~p"/people"
    assert {:ok, _view, _html} = live(conn, ~p"/people")
  end

  test "trocar a senha derruba a outra sessão na próxima ação (FR-015)", %{
    conn: conn,
    tenant: tenant,
    member: member
  } do
    # Sessão A aberta.
    conn_a = post(conn, ~p"/session", %{"identifier" => member.email, "password" => @senha})
    assert {:ok, _view, _} = live(conn_a, ~p"/people")

    # A senha muda (noutro navegador, digamos).
    {:ok, _} = Tenants.change_password(tenant, member.id, @senha, "novissima-comprida-1")

    # A sessão A cai na PRÓXIMA ação — token girado.
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn_a, ~p"/people")
  end

  test "o destino pretendido sobrevive ao login (FR-005)", %{conn: conn, member: member} do
    # Sem sessão, a rota protegida guarda o destino e manda à entrada.
    conn = get(conn, ~p"/teams")
    assert redirected_to(conn) == ~p"/sign-in"

    conn = post(conn, ~p"/session", %{"identifier" => member.email, "password" => @senha})
    assert redirected_to(conn) == ~p"/teams"
  end

  test "logout encerra: nenhuma tela protegida responde", %{conn: conn, member: member} do
    conn = post(conn, ~p"/session", %{"identifier" => member.email, "password" => @senha})
    conn = delete(conn, ~p"/session")
    assert redirected_to(conn) == ~p"/sign-in"

    conn = get(conn, ~p"/people")
    assert redirected_to(conn) == ~p"/sign-in"
  end
end
