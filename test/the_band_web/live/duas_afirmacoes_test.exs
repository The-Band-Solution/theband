defmodule TheBandWeb.DuasAfirmacoesTest do
  @moduledoc """
  Feature 055, T014 — as duas afirmações, quando coleta e declaração discordam (FR-012).

  ## O que este teste protege

  A FR-012 exige que a tela mostre **as duas afirmações** e proíbe escolher uma.
  Uma tela que escolhesse a mais recente passaria em qualquer asserção que
  procurasse "uma frase sobre a pessoa" — e é justamente esse o defeito.

  Por isso cada teste da discordância exige **as quatro** cordas: a origem
  nomeada da coleta, o que a coleta afirma, a origem nomeada da declaração, e o
  que a declaração afirma. **Retirar qualquer uma das duas afirmações reprova**,
  que é o que a tarefa pede.

  ## Por que as origens são procuradas em PALAVRA

  A tela distingue as duas fontes por cor de borda — `border-info` e
  `border-warning`. Se a asserção aceitasse a classe, uma tela em que a única
  diferença é o tom passaria, e quem lê não saberia qual fonte disse o quê. É a
  mesma razão da FR-002, e o mesmo cuidado do `EquipeDeclaradaTest`.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  # As duas origens, nomeadas. A tela pode mudar a redação das afirmações; o que
  # não pode é deixar de dizer QUEM afirmou.
  @origem_coleta "collected from the source"
  @origem_declaracao "declared by the organisation"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")

    {:ok, papel} =
      EO.create_role(tenant, org.id, %{code: "developer", name: "Desenvolvedor"}, admin.id)

    equipe = team_fixture(tenant, "T_a", %{organization: org})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("U_1", %{name: "Ana"}))

    {:ok, evidencia} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      papel: papel,
      equipe: equipe,
      pessoa: pessoa,
      evidencia: evidencia
    }
  end

  describe "a coleta mostra quem a declaração diz que saiu (FR-012)" do
    test "a tela mostra AS DUAS afirmações, cada uma com a sua origem", ctx do
      {:ok, vinculo} = aloca(ctx)
      {:ok, _} = EO.end_allocation(ctx.tenant, vinculo.id, ontem())

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A discordância é anunciada, e não escondida numa nota de rodapé.
      assert html =~ "Source and declaration disagree"

      # AS DUAS ORIGENS, em palavra.
      assert html =~ @origem_coleta
      assert html =~ @origem_declaracao

      # AS DUAS AFIRMAÇÕES. Uma tela que escolhesse a mais recente traria só a
      # segunda, e é esta dupla asserção que reprova esse caso.
      assert html =~ "The source still shows this person in this team"
      assert html =~ "Declared as having left this team"

      assert html =~ "Ana"
    end

    test "e não escolhe: a tela NÃO diz que a pessoa simplesmente saiu", ctx do
      {:ok, vinculo} = aloca(ctx)
      {:ok, _} = EO.end_allocation(ctx.tenant, vinculo.id, ontem())

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A afirmação da coleta é a que uma tela que "resolve" a discordância
      # descartaria — ela é mais antiga em espírito, e a declaração é a decisão
      # humana. Descartá-la esconderia que o GitHub não foi atualizado.
      assert html =~ "The source still shows this person in this team",
             "a tela escolheu a declaração e descartou a coleta — é o que a FR-012 proíbe"
    end
  end

  describe "a declaração diz vigente quem a coleta não mostra mais (FR-012)" do
    test "o sentido inverso também traz as duas", ctx do
      {:ok, _vinculo} = aloca(ctx)
      {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, daqui_um_minuto())

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Source and declaration disagree"
      assert html =~ @origem_coleta
      assert html =~ @origem_declaracao
      assert html =~ "The source no longer shows this person in this team"
      assert html =~ "Declared a current membership in this team"
    end
  end

  describe "o equívoco é caso próprio, e não 'saiu'" do
    test "declaração de que nunca esteve, com a coleta ainda mostrando", ctx do
      {:ok, _vinculo} = aloca(ctx)

      {:ok, _} =
        EO.record_team_membership_mistake(
          ctx.tenant,
          ctx.equipe.id,
          ctx.pessoa.id,
          "entrou na equipe errada",
          ctx.admin.id
        )

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ @origem_coleta
      assert html =~ @origem_declaracao
      assert html =~ "The source still shows this person in this team"

      # "nunca esteve" e "saiu em março" pedem conversas diferentes, e colapsá-las
      # perderia a diferença.
      assert html =~ "never belonged here"
      refute html =~ "Declared as having left this team"
    end
  end

  describe "o que NÃO é discordância" do
    test "as duas concordando não produzem seção nenhuma", ctx do
      {:ok, _vinculo} = aloca(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "Source and declaration disagree"
      refute html =~ @origem_declaracao
    end

    test "evidência SEM vínculo nenhum não é discordância — a declaração não falou", ctx do
      # Nenhum `aloca/1` aqui: existe evidência e não existe vínculo. Isso sai por
      # `pending_evidence/2` e a tela apresenta em separado (feature 057, FR-005).
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "Source and declaration disagree"
      assert html =~ "waiting for confirmation"
    end

    test "vínculo encerrado ao lado de outro vigente não é discordância", ctx do
      # Entrou como desenvolvedora, saiu, e voltou com outro papel. O vínculo
      # encerrado sozinho pareceria discordar da coleta; o vigente concorda.
      # Juntar linha a linha produziria discordância falsa — é o defeito que a
      # agregação por pessoa evita.
      {:ok, encerrado} = aloca(ctx)
      {:ok, _} = EO.end_allocation(ctx.tenant, encerrado.id, ontem())

      {:ok, outro_papel} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "sm", name: "Scrum Master"}, ctx.admin.id)

      {:ok, _vigente} =
        EO.allocate(ctx.tenant, %{
          person_id: ctx.pessoa.id,
          team_id: ctx.equipe.id,
          organizational_role_id: outro_papel.id
        })

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "Source and declaration disagree"
    end
  end

  defp aloca(ctx) do
    EO.allocate(ctx.tenant, %{
      person_id: ctx.pessoa.id,
      team_id: ctx.equipe.id,
      organizational_role_id: ctx.papel.id,
      evidence_id: ctx.evidencia.id,
      declared_by_user_id: ctx.admin.id
    })
  end

  defp ontem, do: DateTime.add(DateTime.utc_now(:second), -1, :day)
  defp daqui_um_minuto, do: DateTime.add(DateTime.utc_now(:second), 60, :second)
end
