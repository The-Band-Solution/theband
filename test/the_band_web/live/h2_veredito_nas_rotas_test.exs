defmodule TheBandWeb.H2VereditoNasRotasTest do
  @moduledoc """
  O veredito de acesso nas duas rotas que não o consultavam — achado **H2**,
  2026-09-09.

  ## A decisão que este arquivo mede

  Da pessoa mantenedora, em 2026-09-09:

  > *"Quem tem o escopo de team, organization e admin podem ver. E a pessoa vê o seu
  > perfil."*

  Não é regime novo: são os caminhos que `Tenants.pode_ver/3` já decide. O defeito era
  **duas rotas sobre pessoa nomeada não perguntarem**:

  1. `/people/:id/commits` — os commits de uma pessoa, filtrados só por tenant;
  2. `/work/verifications/people` — um **ranking nominal** de quem integrou com a
     verificação vermelha, cujo próprio título é *"Who merged red"*, aberto a qualquer
     conta autenticada do tenant.

  ## As duas metades, e por que as duas precisam de teste

  Um conserto que só fechasse deixaria a plataforma segura e inútil: quem tem escopo
  perderia a leitura que a decisão lhe dá. Um que só abrisse não consertaria nada. Cada
  asserção de recusa aqui tem a asserção de permissão ao lado.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, alvo} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo",
        name: "Pessoa Alvo",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/alvo",
        external_id: "U_alvo",
        collected_at: DateTime.utc_now(:second)
      })

    # Uma integrada VERMELHA em nome da pessoa alvo: é o que a faz aparecer no ranking.
    {:ok, _} =
      ChangeCommands.record_change_request(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: 4242,
        title: "pr vermelho",
        state: "MERGED",
        author_login: "alvo",
        author_person_id: alvo.id,
        merged_check_state: "FAILURE",
        merged_check_contexts: 2,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_4242"
      })

    # A conta ESTRANHA: `member`, sem elo declarado e sem concessão nenhuma.
    {:ok, estranha} =
      Tenants.create_user(tenant, %{
        "email" => "estranha-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, estranha} = Tenants.set_password(tenant, estranha.id, "senha-bem-comprida-123")

    %{conn: conn, tenant: tenant, admin: admin, alvo: alvo, estranha: estranha}
  end

  describe "a guarda do cenário — sem ela nenhuma asserção abaixo mede nada" do
    test "a conta estranha é de facto recusada pelo veredito", ctx do
      assert {:nao, _motivo} = Tenants.pode_ver(ctx.tenant, ctx.estranha, ctx.alvo.id), """
      Se esta conta alcançasse a pessoa alvo, os testes de recusa abaixo estariam
      medindo o caminho permitido e passariam verde afirmando o contrário.
      """
    end

    test "e o ranking de facto tem a pessoa alvo — senão a lista vazia não prova nada", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/work/verifications/people")

      assert html =~ "alvo", """
      A administração vê o ranking inteiro. Se a pessoa alvo não aparecesse aqui, o
      `refute` do teste seguinte passaria por a lista estar vazia, e não por o filtro
      funcionar.
      """
    end
  end

  describe "/work/verifications/people — o ranking nominal" do
    test "a conta sem escopo NÃO vê o login de quem integrou vermelho", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.estranha), ~p"/work/verifications/people")

      assert html =~ "Who merged red", "a página continua existindo — o que muda é o conteúdo"

      refute html =~ "alvo", """
      Um ranking nominal de quem integrou com a verificação vermelha, aberto a qualquer
      conta autenticada do tenant, é leitura de desempenho de gente nomeada por quem
      não tem escopo sobre ela.
      """
    end

    test "e a administração continua vendo — o par que impede o conserto de fechar demais", ctx do
      {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/work/verifications/people")

      assert html =~ "alvo", """
      Se este `assert` falhar, o conserto do H2 fechou a tela para quem a decisão diz
      que pode ver — e a suíte ficaria verde afirmando segurança onde há uma leitura
      legítima trancada.
      """
    end

    test "a pessoa vê o SEU — a segunda metade da decisão", ctx do
      # A conta da própria pessoa alvo: elo declarado, e nenhum escopo além do piso.
      {:ok, dela} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "dela-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {:ok, _} = Tenants.declare_person(ctx.tenant, dela.id, ctx.alvo.id, ctx.admin.id)
      {:ok, dela} = Tenants.fetch_user(dela.id)

      {:ok, _live, html} = live(log_in(ctx.conn, dela), ~p"/work/verifications/people")

      assert html =~ "alvo", """
      *"E a pessoa vê o seu perfil"* — sem esta asserção, o conserto poderia esconder de
      alguém o próprio trabalho, que é a metade da decisão mais fácil de perder.
      """
    end
  end

  describe "/people/:id/commits — os commits de uma pessoa nomeada" do
    test "a conta sem escopo é devolvida à lista", ctx do
      conn = log_in(ctx.conn, ctx.estranha)

      assert {:error, {:live_redirect, %{to: "/people"}}} =
               live(conn, ~p"/people/#{ctx.alvo.id}/commits")
    end

    test "e a recusa NÃO distingue 'existe e você não alcança' de 'não existe'", ctx do
      conn = log_in(ctx.conn, ctx.estranha)

      inexistente = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: destino_recusa}}} =
        live(conn, ~p"/people/#{ctx.alvo.id}/commits")

      {:error, {:live_redirect, %{to: destino_ausente}}} =
        live(conn, ~p"/people/#{inexistente}/commits")

      assert destino_recusa == destino_ausente, """
      Distinguir os dois diria a quem tenta que aquela pessoa está no tenant. É a mesma
      razão pela qual a tela da equipe responde "Team not found" para equipe de outro
      tenant.
      """
    end

    test "e a administração abre — o par", ctx do
      conn = log_in(ctx.conn, ctx.admin)

      {:ok, _live, html} = live(conn, ~p"/people/#{ctx.alvo.id}/commits")

      assert html =~ "Pessoa Alvo"
    end
  end
end
