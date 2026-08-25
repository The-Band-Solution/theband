defmodule TheBandWeb.PromocaoNaTelaTest do
  @moduledoc """
  A tela de promoção — feature 043, `SC-005` e `SC-005a`.

  ## O caso que mais importa é o que NÃO aparece

  `refute html =~ "MAINTAINER"` prova mais que qualquer asserção positiva. Afirmar que o
  seletor de papel está lá não impede que o nível de acesso esteja ao lado dele — e é
  exatamente isso que transformaria a proibição da `FR-012` em letra morta.

  A garantia real é do contrato: `pending_evidence/2` não devolve o campo. Este teste é a
  confirmação de que a tela não o busca por outro caminho.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()

    organizacao = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_a", %{organization: organizacao})

    {:ok, pessoa} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_1", %{name: "Alguém", login: "alguem"})
      )

    {:ok, evidencia} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MAINTAINER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    {:ok, outra_pessoa} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_2", %{name: "Outra", login: "outra"})
      )

    {:ok, outra_evidencia} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: outra_pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_2",
        team_external_id: "T_a",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    %{
      conn: log_in(conn, user),
      tenant: tenant,
      outra_pessoa: outra_pessoa,
      outra_evidencia: outra_evidencia,
      user: user,
      organizacao: organizacao,
      equipe: equipe,
      pessoa: pessoa,
      evidencia: evidencia
    }
  end

  describe "a seção de promoção" do
    test "diz quantas participações esperam confirmação", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "2 participation(s) waiting for confirmation", """
      **A FR-014.** A equipe sem vínculo não é a mesma coisa que equipe sem ninguém — e
      mostrar "0 membros" seco esconderia trabalho que existe.
      """

      assert html =~ "Alguém"
    end

    test "os quatro papéis do Scrum estão no seletor, sem cadastro", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      for nome <- ["Product Owner", "Scrum Master", "Developer", "Client"] do
        assert html =~ nome
      end

      assert EO.count_roles(ctx.tenant) == 0, """
      **Ler não escreve.** Os quatro aparecem porque são compostos da rede, e nenhuma linha
      foi gravada só por alguém abrir a tela.
      """
    end

    test "promover cria o vínculo e tira da lista", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      html =
        live
        |> form("#promover", %{
          "papel" => %{ctx.evidencia.id => "catalogo:sro.scrum_master_role"},
          "started_at" => %{ctx.evidencia.id => "2026-03-01"}
        })
        |> render_submit(%{"apenas" => ctx.evidencia.id})

      assert html =~ "1 membership(s) recorded"

      # A outra evidência continua esperando — confirmar uma não confirma as demais, e a
      # contagem no título acompanha.
      assert html =~ "1 participation(s) waiting for confirmation"

      assert EO.team_size(ctx.tenant, ctx.equipe.id) == 1
    end
  end

  describe "o nível de acesso" do
    test "NÃO aparece na seção de promoção — SC-005a", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A seção de promoção vai do título até o aviso que a segue. Recortar é necessário: a
      # tabela de MEMBROS mostra o nível de propósito, rotulado como acesso, e ali ele é
      # observação legítima.
      [_, resto] = String.split(html, "waiting for confirmation", parts: 2)
      [secao, _] = String.split(resto, "Por que o papel organizacional", parts: 2)

      refute secao =~ "MAINTAINER", """
      **A SC-005a.** `MAINTAINER` ao lado de um seletor de papel é uma dica, por mais que o
      texto negue — e a proibição da FR-012 viraria letra morta.

      A garantia é do contrato: `pending_evidence/2` não devolve o campo. Se ele apareceu
      aqui, alguém o buscou por outro caminho.
      """

      refute secao =~ "MEMBER"
    end

    test "continua aparecendo na tabela de membros, rotulado como acesso", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "access at the platform", """
      O nível **não some da plataforma** — é fato observado sobre a ferramenta, e apagá-lo
      seria perder dado verdadeiro. O que muda é o LUGAR: ele sai de onde a decisão de papel
      acontece.
      """

      assert html =~ "MAINTAINER"
    end
  end

  describe "a data de início" do
    test "vem preenchida com hoje, como ponto de partida", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ Date.to_iso8601(Date.utc_today())
      assert html =~ ~s(type="date")
    end

    test "esvaziar grava nulo, e não a data de hoje", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      live
      |> form("#promover", %{
        "papel" => %{ctx.evidencia.id => "catalogo:sro.developer_role"},
        "started_at" => %{ctx.evidencia.id => ""}
      })
      |> render_submit(%{"apenas" => ctx.evidencia.id})

      {:ok, evidencia} = EO.fetch_evidence(ctx.tenant, ctx.evidencia.id)
      {:ok, vinculo} = EO.fetch_membership(ctx.tenant, evidencia.promoted_membership_id)

      assert is_nil(vinculo.started_at), """
      **Branco é desconhecido.** A tela permite esvaziar, e esvaziar não vira hoje — quem
      promove pode não saber desde quando a pessoa está no papel, e inventar a data afirmaria
      que ela assumiu agora.
      """
    end
  end

  describe "confirmar todas" do
    test "confirma as linhas com papel, e PULA as sem — dizendo quantas", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      html =
        live
        |> form("#promover", %{
          "papel" => %{
            ctx.evidencia.id => "catalogo:sro.developer_role",
            # A segunda fica sem escolher: é o caso que o botão precisa tratar.
            ctx.outra_evidencia.id => ""
          },
          "started_at" => %{ctx.evidencia.id => "", ctx.outra_evidencia.id => ""}
        })
        |> render_submit(%{"apenas" => "todas"})

      assert html =~ "1 membership(s) recorded"

      assert html =~ "1 skipped", """
      **O pulo não pode ser silencioso.** Quem clicou em "confirmar todas" e viu só
      "1 confirmada" concluiria que havia uma linha — e havia duas.

      É o padrão que esta base mais paga: ausência de erro lida como resultado.
      """

      assert EO.team_size(ctx.tenant, ctx.equipe.id) == 1
      assert length(EO.pending_evidence(ctx.tenant, ctx.equipe.id)) == 1
    end

    test "confirma as duas quando as duas têm papel", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      html =
        live
        |> form("#promover", %{
          "papel" => %{
            ctx.evidencia.id => "catalogo:sro.developer_role",
            ctx.outra_evidencia.id => "catalogo:sro.scrum_master_role"
          },
          "started_at" => %{ctx.evidencia.id => "", ctx.outra_evidencia.id => ""}
        })
        |> render_submit(%{"apenas" => "todas"})

      assert html =~ "2 membership(s) recorded"
      refute html =~ "skipped"

      assert EO.team_size(ctx.tenant, ctx.equipe.id) == 2
      assert EO.pending_evidence(ctx.tenant, ctx.equipe.id) == []
    end

    test "nenhuma escolhida não confirma nada, e diz isso", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      html =
        live
        |> form("#promover", %{
          "papel" => %{ctx.evidencia.id => "", ctx.outra_evidencia.id => ""},
          "started_at" => %{ctx.evidencia.id => "", ctx.outra_evidencia.id => ""}
        })
        |> render_submit(%{"apenas" => "todas"})

      assert html =~ "Nothing confirmed"
      assert html =~ "2 rows"
      assert EO.team_size(ctx.tenant, ctx.equipe.id) == 0
    end

    test "o botão existe e diz o que faz", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Confirm all"

      assert html =~ "only the rows where a role was chosen", """
      O botão precisa dizer o que ele NÃO faz, antes de ser clicado. "Confirmar todas" lido
      literalmente promete confirmar todas — inclusive as sem papel, que ele pula.
      """
    end
  end
end
