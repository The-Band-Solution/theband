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

    # O axioma da marca é conferido PELO CATÁLOGO, e não por literal. A copy foi
    # para o gettext em 2026-08-31 (o painel estava em português ao lado de um
    # formulário em inglês, com locale padrão `en`); um literal aqui prenderia o
    # teste a um idioma, e ele cairia de novo na próxima tradução — sem que nada
    # de comportamento tivesse mudado.
    assert html =~ Gettext.dgettext(TheBandWeb.Gettext, "sistema", "Notes aren’t music.")
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

  test "H1: /set-password NÃO troca a senha de conta em regime normal", ctx do
    # A GUARDA DO CENÁRIO, e sem ela este teste mediria o fluxo legítimo da
    # temporária — que é justamente o que o teste acima cobre.
    refute ctx.member.must_change_password, """
    O cenário deste teste é a conta em REGIME NORMAL. Se `must_change_password`
    fosse verdadeiro aqui, o POST abaixo estaria certo em funcionar, e o teste
    passaria a verde afirmando o contrário do que diz.
    """

    conn = log_in(ctx.conn, ctx.member)

    # O caminho do achado H1: quem alcança uma sessão válida — navegador esquecido
    # aberto, máquina compartilhada, cookie capturado — postava aqui e trocava a
    # senha SEM apresentar a antiga em momento nenhum. E o giro do `session_token`
    # derrubava a pessoa legítima: acesso temporário virava posse da conta.
    conn =
      post(conn, ~p"/set-password", %{
        "password" => "tomada-de-conta-123456",
        "password_confirmation" => "tomada-de-conta-123456"
      })

    assert redirected_to(conn) == ~p"/sign-in", """
    A recusa derruba a sessão e manda para a entrada. Redirecionar para `/profile`
    com uma frase seria o caminho gentil, e daria a quem chegou com a sessão de
    outra pessoa uma dica do que tentar em seguida.
    """

    # E A ASSERÇÃO QUE IMPORTA, que não é o destino: o destino podia estar certo e
    # a senha ter mudado do mesmo jeito.
    assert {:error, :invalid_credentials} =
             Tenants.authenticate(ctx.member.email, "tomada-de-conta-123456"),
           "a senha nova passou a valer — a troca aconteceu apesar da recusa"

    assert {:ok, _} = Tenants.authenticate(ctx.member.email, @senha),
           "a senha original deixou de valer — a conta foi tomada"
  end

  test "H1: e a porta legítima continua abrindo — o par que impede o conserto de mais", ctx do
    # SEM ESTE PAR, o conserto do H1 podia ter fechado o fluxo da temporária
    # (FR-013) e ninguém saberia: a suíte ficaria verde afirmando segurança onde
    # havia uma porta legítima trancada.
    {:ok, temporaria} = Tenants.reset_password(ctx.tenant, ctx.member.id, ctx.admin.id)

    {:ok, recarregada} = Tenants.fetch_user(ctx.member.id)

    assert recarregada.must_change_password, """
    O reinício de senha põe a conta no fluxo da temporária. Se isto falhar, o teste
    abaixo não está medindo a porta legítima.
    """

    conn =
      post(ctx.conn, ~p"/session", %{
        "identifier" => ctx.member.email,
        "password" => temporaria
      })

    conn =
      post(conn, ~p"/set-password", %{
        "password" => "definitiva-bem-comprida-9",
        "password_confirmation" => "definitiva-bem-comprida-9"
      })

    assert redirected_to(conn) == ~p"/people", "o fluxo da temporária foi fechado pelo conserto"

    assert {:ok, _} = Tenants.authenticate(ctx.member.email, "definitiva-bem-comprida-9")
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
