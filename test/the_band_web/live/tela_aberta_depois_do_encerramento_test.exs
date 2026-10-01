defmodule TheBandWeb.TelaAbertaDepoisDoEncerramentoTest do
  @moduledoc """
  A tela já aberta cai quando a sessão dela cai — issue #1042.

  Medido em 2026-10-01, antes da correção: a conta desativada com `/people` aberto seguia
  recebendo resposta a eventos (11 431 bytes de HTML). A hook conferia a sessão só no `mount`,
  e nada derrubava o socket já conectado.

  O aviso é gatilho, e quem decide é a reconferência no banco. Por isso o último teste manda
  um aviso **espúrio** a uma sessão que ainda vale, e ela precisa continuar de pé.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias TheBand.Tenants
  alias TheBand.Tenants.Sessions

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, outra} =
      Tenants.create_user(tenant, %{
        "email" => "outra-#{System.unique_integer([:positive])}@x.io",
        "role" => "admin",
        "password" => "senha-forte-de-teste-123"
      })

    {:ok, view, _html} = conn |> log_in(outra) |> live(~p"/people")
    %{tenant: tenant, admin: admin, outra: outra, view: view}
  end

  defp evento(view), do: render_change(view, "buscar", %{"q" => "", "tabela" => "people"})

  test "a conta desativada com a tela aberta é levada à entrada, e o evento seguinte não responde",
       ctx do
    {:ok, _} =
      Tenants.disable_user(ctx.tenant, ctx.outra.id, ctx.admin.id, %{
        "reason" => "left_the_organisation"
      })

    assert_redirect(ctx.view, "/sign-in")
    catch_exit(evento(ctx.view))
  end

  test "a senha definida por outra pessoa derruba a tela aberta", ctx do
    {:ok, _temporaria} = Tenants.reset_password(ctx.tenant, ctx.outra.id, ctx.admin.id)

    assert_redirect(ctx.view, "/sign-in")
  end

  test "o giro de todas as sessões derruba a tela aberta no mesmo nó", ctx do
    {:ok, _n} = Sessions.girar_todas()

    assert_redirect(ctx.view, "/sign-in")
  end

  test "sair em outra aba derruba a tela aberta com a mesma sessão", ctx do
    sessao =
      Repo.one!(
        from(s in TheBand.Tenants.Schemas.UserSession,
          where: s.user_id == ^ctx.outra.id and is_nil(s.ended_at)
        )
      )

    :ok = Sessions.encerrar(sessao)

    assert_redirect(ctx.view, "/sign-in")
  end

  test "aviso espúrio não derruba quem ainda vale: a decisão é do banco", ctx do
    Sessions.avisar_encerramento({:conta, ctx.outra.id})

    assert evento(ctx.view) =~ "people"
  end
end
