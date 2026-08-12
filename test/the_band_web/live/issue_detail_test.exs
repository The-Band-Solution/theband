defmodule TheBandWeb.IssueDetailTest do
  @moduledoc """
  As telas de detalhe da issue e do repositório (feature 006).

  O que estes testes protegem não é a existência das seções: é a **separação** entre
  composição e atendimento. Uma tela que soma as duas fica mais curta e apaga a distinção
  que a plataforma existe para preservar — por isso o teste que mais importa aqui é o que
  **recusa** o número somado.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "chegar ao detalhe" do
    test "o título da issue na listagem leva ao detalhe dela",
         %{conn: conn, cenario: c} do
      {:ok, live, _html} = live(conn, ~p"/trabalho")

      assert live
             |> element("a[href='/trabalho/issues/#{c.issues[1].pai.id}']")
             |> has_element?(),
             "o número e o título da issue precisam ser navegáveis a partir de /trabalho"
    end

    test "o nome do repositório leva às issues dele, não à origem",
         %{conn: conn, cenario: c} do
      {:ok, live, _html} = live(conn, ~p"/trabalho")

      assert live
             |> element("a[href='/trabalho/repositorios/#{c.observed_repository_id}']")
             |> has_element?()
    end
  end

  describe "composição e atendimento na tela do épico" do
    test "mostra 9 e 30 em seções separadas, e nunca 39",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{c.issues[1].pai.id}")

      assert html =~ "Composição"
      assert html =~ "Atendimento"
      assert html =~ "sro.epic_composed_of_user_story"
      assert html =~ "sro.intended_task_planned_to_meet_user_story"

      # É o SC-004. O número somado não pode aparecer em lugar nenhum da página — nem
      # como total, nem como "partes". Se alguém trocar as duas seções por uma contagem
      # de filhas, este é o teste que quebra.
      refute html =~ ">39<"
    end

    test "a user story com nove tarefas aparece como atômica",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{c.issues[3].pai.id}")

      assert html =~ "atômica"
      assert html =~ "Nenhuma."
      refute html =~ "épico — tem partes"
    end
  end

  describe "o aviso do axioma" do
    test "a tarefa cujo pai é épico traz o aviso nomeando sro.rule07, e segue promovida",
         %{conn: conn, tenant: tenant} do
      violacao =
        tenant |> WorkItems.rule07_violations() |> Map.fetch!(:task_parent_is_epic) |> hd()

      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{violacao.id}")

      assert html =~ "sro.rule07"
      assert html =~ "o inválido é o vínculo"
      # A issue continua promovida: o aviso não a esconde nem a despromove.
      assert html =~ "tarefa pretendida"
    end

    test "a tarefa sem pai traz o mesmo axioma com outro texto",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{c.issues[201].pai.id}")

      assert html =~ "sro.rule07"
      assert html =~ "não tem pai"
    end
  end

  describe "campo ausente" do
    test "corpo nunca coletado é declarado como não coletado, não como vazio",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{c.issues[1].pai.id}")

      assert html =~ "Corpo não coletado"
      refute html =~ "não tem descrição na origem"
    end

    test "ausência de designado e de marco aparece nomeada",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{c.issues[1].pai.id}")

      assert html =~ "ninguém designado"
      assert html =~ "fora de marco"
      assert html =~ "fora de quadro"
    end
  end

  describe "o histórico" do
    test "mostra a decisão vigente e a anterior", %{conn: conn, tenant: tenant, cenario: c} do
      issue = c.issues[5].pai

      {:ok, _} =
        WorkItems.record_promotion(tenant, %{
          collected_issue_id: issue.id,
          derived_concept: "sro.epic",
          rule_id: "regra.nova",
          rule_version: 2
        })

      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{issue.id}")

      assert html =~ "Histórico de promoção"
      assert html =~ "vigente"
      assert html =~ "regra.nova"
    end
  end

  describe "isolamento entre tenants" do
    test "issue de outro tenant não abre, e a mensagem não confirma que existe",
         %{cenario: c, conn: conn} do
      {_outro_tenant, outro_user} = tenant_with_admin()
      conn = log_in(conn, outro_user)

      assert {:error, {:live_redirect, %{to: "/trabalho", flash: flash}}} =
               live(conn, ~p"/trabalho/issues/#{c.issues[1].pai.id}")

      assert flash["error"] =~ "não encontrada"
      refute flash["error"] =~ "permissão"
    end
  end

  describe "a tela do repositório" do
    test "lista as issues e a contagem do cabeçalho soma o total",
         %{conn: conn, tenant: tenant, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")

      assert html =~ "theband"
      assert html =~ "Por conceito"
      refute html =~ "As contagens não somam"

      total = WorkItems.count_collected(tenant, observed_repository_id: c.observed_repository_id)
      assert html =~ "de #{total}"
    end

    test "as issues do repositório são navegáveis pelo título",
         %{conn: conn, cenario: c} do
      {:ok, live, _html} = live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")

      assert live |> element("a[href='/trabalho/issues/#{c.issues[1].pai.id}']") |> has_element?()
    end

    test "a paginação é estável entre duas leituras da mesma página",
         %{conn: conn, cenario: c} do
      {:ok, _live, primeira} = live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")
      {:ok, _live, segunda} = live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")

      assert numeros(primeira) == numeros(segunda), """
      A ordem mudou entre duas leituras. Sem ordem estável, uma issue aparece em duas
      páginas e outra em nenhuma — SC-009.
      """
    end

    test "os avisos do axioma aparecem no repositório, separados por forma",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")

      assert html =~ "Tarefas cujo pai é épico"
      assert html =~ "Tarefas sem user story"
    end

    test "repositório de outro tenant não abre", %{conn: conn, cenario: c} do
      {_outro_tenant, outro_user} = tenant_with_admin()
      conn = log_in(conn, outro_user)

      assert {:error, {:live_redirect, %{to: "/trabalho", flash: flash}}} =
               live(conn, ~p"/trabalho/repositorios/#{c.observed_repository_id}")

      assert flash["error"] =~ "não encontrado"
      refute flash["error"] =~ "permissão"
    end
  end

  defp numeros(html) do
    Regex.scan(~r{/trabalho/issues/([0-9a-f-]+)}, html) |> Enum.map(&List.last/1)
  end

  describe "o alerta de discordância" do
    test "a divergência aparece como alerta, e diz que o conceito foi mantido",
         %{conn: conn, tenant: t, cenario: c} do
      # #98 é `Feature` com duas partes `Feature`: a regra decide épico, e o rótulo não
      # afirmava épico — logo não há divergência. Forço uma: gravo promoção com motivo.
      issue = c.issues[98].pai

      {:ok, _} =
        TheBand.WorkItems.record_promotion(t, %{
          collected_issue_id: issue.id,
          derived_concept: "sro.intended_scrum_development_task",
          divergence_reason: "classificada como tarefa e tem 2 partes coletadas",
          rule_id: "github.issue_structure_routing",
          rule_version: 1
        })

      {:ok, _live, html} = live(conn, ~p"/trabalho/issues/#{issue.id}")

      assert html =~ "O rótulo e a estrutura discordam"
      assert html =~ "tem 2 partes coletadas"

      assert html =~ "O conceito foi mantido", """
      A tela precisa dizer que nada foi corrigido. Sem isso, quem lê supõe que a
      plataforma ajustou o conceito — e a plataforma não decide por quem escreveu a issue.
      """
    end
  end
end
