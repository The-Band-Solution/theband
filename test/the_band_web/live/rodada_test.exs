defmodule TheBandWeb.RodadaTest do
  @moduledoc """
  A tela `/profiles` — feature 027, T018 a T021.

  ## As três asserções que carregam este arquivo

  1. **os três estados dizem coisas diferentes** — nunca ligada, ligada e desligada pedem
     ações diferentes de quem lê, e a primeira é a que engana: uma organização que nunca
     ligou não é uma organização sem quem gerar;
  2. **os motivos de pulo aparecem separados** — um total agregaria o que a `FR-014` manda
     distinguir, e cada motivo pede ação diferente;
  3. **uma organização não vê a rodada da outra** — consulta sem filtro de tenant é bug de
     segurança, e não de correção.
  """
  use TheBandWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest
  import TheBand.ProfileRunFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.{Automation, Runs, RunWorker}
  alias TheBand.Tenants

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario(tenant)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, pessoa: cenario.pessoa}
  end

  describe "quem alcança a tela" do
    test "perfil member não alcança", %{conn: conn, tenant: tenant} do
      {:ok, member} =
        Tenants.create_user(tenant, %{"email" => "m@example.test", "role" => "member"})

      assert {:error, {:redirect, %{to: "/people"}}} = live(log_in(conn, member), ~p"/profiles")
    end
  end

  describe "os três estados" do
    test "nunca ligada é ausência nomeada, e diz o que deixa de acontecer", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/profiles")

      assert html =~ "Never turned on"
      assert html =~ "no profile is written on its own"
      assert html =~ "No run yet"
    end

    test "ligar sem credencial recusa, e a frase diz de quem é a conta", ctx do
      {:ok, live, _} = live(ctx.conn, ~p"/profiles")
      html = live |> element("button", "Turn on") |> render_click()

      assert html =~ "no provider key of its own"
      assert html =~ "another&#39;s bill"
      assert Automation.state(ctx.tenant) == :never_enabled
    end

    test "ligada mostra quem ligou e quando, e dispara a rodada na hora", ctx do
      tenant_com_credencial(ctx.tenant)

      {:ok, live, _} = live(ctx.conn, ~p"/profiles")
      html = live |> element("button", "Turn on") |> render_click()

      assert html =~ "A first run started right away"
      assert html =~ ctx.admin.email
      assert length(Runs.list(ctx.tenant)) == 1
    end

    test "desligada guarda o autor, e é frase diferente de nunca ligada", ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, _} = Automation.enable(ctx.tenant, ctx.admin)

      {:ok, live, _} = live(ctx.conn, ~p"/profiles")
      html = live |> element("button", "Turn off") |> render_click()

      assert html =~ "off from the next run on"
      assert html =~ "Turned off by #{ctx.admin.email}"
      refute html =~ "Never turned on"
    end
  end

  describe "os números da rodada" do
    setup ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, %{run: run}} = Automation.enable(ctx.tenant, ctx.admin)

      {:ok, _} = Runs.record(run, ctx.pessoa.id, %{outcome: "skipped", reason: "no_new_work"})
      {:ok, _} = Runs.finish(run, :completed)

      %{run: run}
    end

    test "os três motivos aparecem separados, nunca somados", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/profiles")

      assert html =~ "no material: 0"
      assert html =~ "no new work: 1"
      assert html =~ "observation ended: 0"
    end

    test "a origem da rodada é legível, e mora aqui e não na aba da pessoa", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/profiles")

      assert html =~ "asked for"
      assert html =~ "completed"
    end

    test "o segundo disparo com rodada aberta é recusado com a frase", ctx do
      {:ok, run} = Runs.get(ctx.tenant, ctx.run.id)
      {:ok, _} = Runs.start(ctx.tenant, trigger: :manual, requested_by: ctx.admin)
      assert run.outcome == "completed"

      {:ok, live, _} = live(ctx.conn, ~p"/profiles")
      html = live |> element("button", "run now") |> render_click()

      assert html =~ "already in progress"
      assert html =~ "the table keeps both"
    end
  end

  describe "isolamento entre organizações" do
    test "a rodada de uma organização não aparece na tela da outra", ctx do
      tenant_com_credencial(ctx.tenant)
      {:ok, %{run: run}} = Automation.enable(ctx.tenant, ctx.admin)

      {_outro, admin_do_outro} = tenant_with_admin("outro")

      {:ok, _live, html} = live(log_in(build_conn(), admin_do_outro), ~p"/profiles")

      assert html =~ "Never turned on"
      refute html =~ run.id
    end
  end

  describe "o report — por que não gerou para todos" do
    test "pessoa a pessoa, com o motivo fino do AGORA", ctx do
      tenant_com_credencial(ctx.tenant)
      # Uma rodada com uma pulada por no_material (sem designação alguma).
      {:ok, sem} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "sem-designacao",
          name: "Sem Designação",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          source_endpoint: "/users/sem",
          external_id: "U_sem",
          collected_at: DateTime.utc_now(:second),
          payload: %{}
        })

      Mox.expect(TheBand.LLMHTTPMock, :complete, fn _p, _m, _o ->
        {:ok,
         %{
           text:
             Jason.encode!(%{
               "habilidades" => ["x"],
               "resumo" => %{"forcas" => "f", "evolucao" => "e", "atencao" => "a"},
               "trajetoria" => [],
               "destaques" => [],
               "lacunas" => [],
               "alocacao" => [],
               "recomendacoes" => [],
               "do_time_nao_da_pessoa" => "t",
               "nao_alcanca" => "n"
             }),
           model: "m1",
           usage: %{"prompt_tokens" => 10}
         }}
      end)

      {:ok, run} = Runs.start(ctx.tenant, trigger: :manual, requested_by: ctx.admin)

      assert :ok =
               RunWorker.perform(%Oban.Job{
                 args: %{"tenant_id" => ctx.tenant.id, "run_id" => run.id}
               })

      {:ok, live, _} = live(ctx.conn, ~p"/profiles")

      html = live |> element("button", "why not everyone?") |> render_click()

      assert html =~ "Sem Designação"
      assert html =~ "no_assignment"
      assert html =~ "nenhuma issue designada", "o motivo fino não veio com a dica de ação"
      assert html =~ "as of now"

      # #398: agrupado por motivo, com contagem no cabeçalho e o texto comum dito UMA
      # vez — repetido por pessoa não é leitura, é despejo.
      assert html =~ "1 person"

      repeticoes = length(String.split(html, "nenhuma issue designada")) - 1

      assert repeticoes == 1,
             "o texto do motivo apareceu #{repeticoes} vezes — era para ser subtítulo do grupo"

      _ = sem
    end
  end
end
