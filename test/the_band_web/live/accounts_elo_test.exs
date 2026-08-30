defmodule TheBandWeb.AccountsEloTest do
  @moduledoc """
  Feature 051 — a área única do onboarding (T004–T007).

  As violações primeiro (L03): pessoa já associada recusa NOMEANDO a conta dona;
  e-mail duplicado não cria nada. E a assimetria que carrega a US2: associou,
  entra pelo username; revogou, só pelo e-mail.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  defp pessoa(tenant, login, nome \\ nil) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: nome || String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  defp conta(tenant, email) do
    {:ok, user} =
      Tenants.create_user(tenant, %{"email" => email, "name" => "Conta", "role" => "member"})

    user
  end

  describe "T004 — o cadastro na tela" do
    test "duplicado recusa com a frase do catálogo, e não cria nada", ctx do
      antes = length(Tenants.list_users(ctx.tenant))

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      html = render_submit(view, "criar", %{"email" => ctx.admin.email, "name" => "Dup"})

      assert html =~ "Conta não criada"
      assert length(Tenants.list_users(ctx.tenant)) == antes
    end
  end

  describe "T005 — a lista diz quem tem GitHub" do
    test "linha com elo mostra o login; sem elo, a ausência nomeada", ctx do
      alvo = pessoa(ctx.tenant, "vinculada")
      com = conta(ctx.tenant, "com-elo@example.test")
      _sem = conta(ctx.tenant, "sem-elo@example.test")
      {:ok, _} = Tenants.declare_person(ctx.tenant, com.id, alvo.id, ctx.admin.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

      assert html =~ "vinculada"
      assert html =~ "no GitHub account linked"
    end
  end

  describe "T006 — associar com busca, e o conflito nomeado" do
    test "a violação: pessoa já associada recusa NOMEANDO a conta dona", ctx do
      alvo = pessoa(ctx.tenant, "disputada")
      dona = conta(ctx.tenant, "dona@example.test")
      outra = conta(ctx.tenant, "outra@example.test")
      {:ok, _} = Tenants.declare_person(ctx.tenant, dona.id, alvo.id, ctx.admin.id)

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")

      html =
        render_click(view, "associar", %{"user-id" => outra.id, "person-id" => alvo.id})

      assert html =~ "já está associada à conta dona@example.test"
      # Nada mudou: a dona continua dona, a outra continua sem elo.
      assert Tenants.user_of_person(ctx.tenant, alvo.id).id == dona.id
    end

    test "o feliz: buscar, associar, e a pessoa entra pelo username", ctx do
      pessoa(ctx.tenant, "achavel", "Fulana Achável")
      nova = conta(ctx.tenant, "achavel@example.test")
      {:ok, senha} = Tenants.reset_password(ctx.tenant, nova.id, ctx.admin.id)

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      render_click(view, "abrir_busca", %{"user-id" => nova.id})
      html = render_change(view, "buscar_pessoa", %{"q" => "achav"})
      assert html =~ "Fulana Achável"

      [pessoa_id] =
        Regex.run(~r/phx-value-person-id="([0-9a-f-]+)"/, html, capture: :all_but_first)

      html = render_click(view, "associar", %{"user-id" => nova.id, "person-id" => pessoa_id})
      assert html =~ "achavel"

      # A associação vale na entrada: username + a temporária do reset.
      assert {:ok, autenticada} = Tenants.authenticate("achavel", senha)
      assert autenticada.id == nova.id
    end

    test "o resultado diz a organização — o edge case dos homônimos (T009)", ctx do
      # Duas pessoas de MESMO nome em organizações diferentes: quem administra
      # decide pelo identificador COM contexto — spec.md:93, recusado na
      # aceitação do 025 e entregue aqui.
      org = organization_fixture(ctx.tenant, "org-da-gemea")

      {:ok, time} =
        EO.upsert_team_from_source(ctx.tenant, %{
          organization_id: org.id,
          name: "Time Gêmeo",
          slug: "time-gemeo",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "T_gemeo",
          collected_at: DateTime.utc_now(:second)
        })

      gemea = pessoa(ctx.tenant, "gemea-a", "Gêmea Silva")
      _outra = pessoa(ctx.tenant, "gemea-b", "Gêmea Silva")

      {:ok, _} =
        EO.record_team_membership_evidence(ctx.tenant, %{
          person_id: gemea.id,
          team_id: time.id,
          person_external_id: gemea.external_id,
          team_external_id: time.external_id,
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second),
          last_observed_at: DateTime.utc_now(:second)
        })

      conta_alvo = conta(ctx.tenant, "quem-liga@example.test")

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      render_click(view, "abrir_busca", %{"user-id" => conta_alvo.id})
      html = render_change(view, "buscar_pessoa", %{"q" => "Gêmea"})

      assert html =~ "gemea-a"
      assert html =~ "gemea-b"
      assert html =~ "org-da-gemea"
    end

    test "a observação terminada é dita no resultado (T009)", ctx do
      encerrada = pessoa(ctx.tenant, "que-saiu")

      encerrada_id = encerrada.id

      {1, _} =
        TheBand.Repo.update_all(
          Ecto.Query.from(pe in TheBand.Ontology.SEON.EO.Schemas.Person,
            where: pe.id == ^encerrada_id
          ),
          set: [no_longer_observed_at: DateTime.utc_now(:second)]
        )

      alvo = conta(ctx.tenant, "liga-encerrada@example.test")

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      render_click(view, "abrir_busca", %{"user-id" => alvo.id})
      html = render_change(view, "buscar_pessoa", %{"q" => "que-saiu"})

      assert html =~ "que-saiu"
      assert html =~ "no longer observed"
    end

    test "busca sem resultado é ausência nomeada", ctx do
      alvo = conta(ctx.tenant, "buscadora@example.test")

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      render_click(view, "abrir_busca", %{"user-id" => alvo.id})
      html = render_change(view, "buscar_pessoa", %{"q" => "ninguem-com-esse-nome"})

      assert html =~ "nenhuma pessoa coletada bate com"
    end
  end

  describe "T007 — revogar na área, e o login acompanha" do
    test "o ciclo: associar → revogar → username recusa, e-mail segue", ctx do
      alvo = pessoa(ctx.tenant, "revogavel")
      user = conta(ctx.tenant, "revogavel@example.test")
      {:ok, senha} = Tenants.reset_password(ctx.tenant, user.id, ctx.admin.id)
      {:ok, _} = Tenants.declare_person(ctx.tenant, user.id, alvo.id, ctx.admin.id)

      assert {:ok, _} = Tenants.authenticate("revogavel", senha)

      {:ok, view, _} = live(ctx.conn, ~p"/accounts")
      html = render_click(view, "revogar_elo", %{"user-id" => user.id})
      assert html =~ "no GitHub account linked"

      # A auditoria fica: declared_at preservado, revoked_at preenchido.
      {:ok, depois} = Tenants.fetch_user(user.id)
      assert depois.person_id == alvo.id
      assert depois.person_declared_at
      assert depois.person_revoked_at

      # Username recusa com a recusa única; e-mail continua entrando.
      assert {:error, _} = Tenants.authenticate("revogavel", senha)
      assert {:ok, _} = Tenants.authenticate("revogavel@example.test", senha)
    end
  end
end
