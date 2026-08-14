defmodule TheBandWeb.MigalhaTest do
  @moduledoc """
  A migalha de pão (feature 016).

  ## O teste percorre as telas, e não uma amostra

  O risco desta feature é uma tela **esquecer** de declarar o caminho — e nada avisar: ela abre,
  funciona, e só não diz onde está. Por isso a lista de rotas aqui é a lista inteira: as de detalhe
  precisam ter migalha, e as raiz precisam **não** ter.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "quem tem e quem não tem" do
    test "as telas de detalhe têm migalha", ctx do
      %{pai: issue} = ctx.cenario.issues[3]
      pessoa = pessoa(ctx.tenant)

      rotas = [
        {~p"/people/#{pessoa.id}", "People"},
        {~p"/work/issues/#{issue.id}", "Work"},
        {~p"/work/repositories/#{ctx.cenario.observed_repository_id}", "Work"}
      ]

      for {rota, primeiro} <- rotas do
        {:ok, _live, html} = live(ctx.conn, rota)

        assert html =~ ~s(aria-label="You are in"), """
        #{rota} não tem migalha.

        Tela de detalhe sem caminho abre, funciona, e só não diz onde está — e nada avisa.
        """

        assert html =~ primeiro
      end
    end

    test "as telas raiz não têm migalha", ctx do
      for rota <- [~p"/people", ~p"/teams", ~p"/work", ~p"/syncs"] do
        {:ok, _live, html} = live(ctx.conn, rota)

        refute html =~ ~s(aria-label="You are in"), """
        #{rota} ganhou migalha, e não há nível acima dela.

        Migalha de um nível só é decoração: ela diz onde a pessoa está sem oferecer para onde ir.
        """
      end
    end
  end

  describe "o nível atual" do
    test "não é ligação, e é anunciado como o lugar atual", ctx do
      pessoa = pessoa(ctx.tenant)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{pessoa.id}")

      assert html =~ ~s(aria-current="page")

      refute html =~ ~r{<a[^>]*aria-current="page"}, """
      O nível atual virou ligação.

      Quem já está ali não precisa de um clique que recarrega a mesma tela — e um leitor de tela
      anunciaria como destino o lugar onde a pessoa já se encontra.
      """
    end
  end

  describe "os jeitos antigos de voltar" do
    test "o botão em português não existe mais", ctx do
      equipe = equipe(ctx.tenant)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{equipe.id}")

      refute html =~ ">voltar<", """
      O botão `voltar` continua na tela.

      Ele estava **em português**, no meio de uma interface em inglês — três telas resolviam a
      mesma necessidade de três jeitos, e a migalha existe para que passe a haver um.
      """

      assert html =~ ~s(aria-label="You are in")
    end

    test "o back to people saiu do detalhe da pessoa", ctx do
      pessoa = pessoa(ctx.tenant)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{pessoa.id}")

      refute html =~ "back to people"
      assert html =~ "People"
    end
  end

  describe "o caminho da issue" do
    test "inclui o repositório, que é o dono dela", ctx do
      %{pai: issue} = ctx.cenario.issues[3]

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{issue.id}")

      assert html =~ ctx.cenario.repo.name, """
      O caminho da issue não menciona o repositório.

      Sem percurso conhecido — endereço colado, ou recarregar — vale o caminho **estrutural**: o
      repositório é o dono da issue, e é a resposta verdadeira quando não se sabe a outra.
      """

      assert html =~ "##{issue.number}"
    end
  end

  defp pessoa(tenant) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        name: "Alguém",
        login: "alguem",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_alguem",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  defp equipe(tenant) do
    {:ok, _} =
      EO.upsert_organization_from_source(tenant, %{
        name: "acme",
        login: "acme",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "acme",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, equipe} =
      EO.upsert_team_from_source(tenant, %{
        name: "equipe do teste",
        slug: "equipe-do-teste",
        type: "organizational_team",
        organization_external_id: "acme",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_migalha",
        collected_at: DateTime.utc_now(:second)
      })

    equipe
  end
end
