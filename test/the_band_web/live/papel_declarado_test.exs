defmodule TheBandWeb.PapelDeclaradoTest do
  @moduledoc """
  A tela distingue o que foi **observado** do que foi **declarado** (T008, T012, T013).

  ## Por que esta é a história que sustenta a feature

  O papel é declaração humana: nenhuma origem observada o fornece. A participação é observação:
  a origem mostrou a pessoa na equipe.

  Uma tela que mostrasse "Developer" sem dizer que **alguém digitou aquilo** transformaria
  declaração em observação — e é o oposto do que a plataforma inteira defende. Sem esta
  história, as duas anteriores entregariam um papel que a tela apresentaria como se tivesse
  vindo do GitHub.

  ## O caso decisivo é um `refute`

  `MAINTAINER` e `MEMBER` dizem quem administra o time na ferramenta de origem. Se aparecerem no
  bloco de papéis, a distinção morreu — e o teste que só afirma que o papel aparece passaria
  igual.
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

    %{
      conn: log_in(conn, user),
      tenant: tenant,
      user: user,
      pessoa: pessoa,
      equipe: equipe,
      organizacao: organizacao,
      evidencia: evidencia
    }
  end

  describe "a tela do catálogo" do
    test "os quatro do Scrum estão lá sem ninguém cadastrar", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/roles")

      for nome <- ["Product Owner", "Scrum Master", "Developer", "Client"] do
        assert html =~ nome, """
        **A FR-002.** Os quatro papéis que a SRO nomeia estão disponíveis em toda organização,
        sem cadastro prévio — é o que dispensa o passo que separava quem administra de poder
        promover uma evidência.
        """
      end

      assert html =~ "waiting for confirmation", """
      A tela diz **quantas evidências esperam**. Sem isso, quem lê não sabe que há trabalho
      parado — e a lista de papéis cheia pareceria "está tudo pronto".
      """
    end

    test "abrir a tela não grava nada", ctx do
      {:ok, _live, _html} = live(ctx.conn, ~p"/roles")

      assert EO.count_roles(ctx.tenant) == 0, """
      **Ler não escreve.** Os quatro do catálogo aparecem porque são **compostos da rede** a
      cada leitura, e não porque foram semeados.

      Semear criaria quatro linhas por organização que ninguém declarou — e se a SRO renomeasse
      um papel, as linhas divergiriam da rede em silêncio.
      """
    end

    test "cadastrar pela tela cria o papel da organização", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/roles")

      html =
        live
        |> form("form[phx-submit=create]", %{"code" => "tech_lead", "name" => "Tech Lead"})
        |> render_submit()

      assert html =~ "registered"
      assert EO.count_roles(ctx.tenant) == 1

      papeis = EO.list_organization_roles(ctx.tenant, ctx.organizacao.id)
      declarado = Enum.find(papeis, &(elem(&1.origem, 0) == :declarado))

      assert declarado.code == "tech_lead"

      assert declarado.origem == {:declarado, ctx.user.id}, """
      Papel declarado tem **autor**, e a tela mostra a origem. Sem ela, em seis meses ninguém
      sabe se `tech_lead` veio da rede ou alguém o digitou.
      """
    end
  end

  describe "a página da pessoa" do
    test "sem alocação, o papel aparece como pendente e não como acesso", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "access at the tool", """
      O nível da origem continua aparecendo, **rotulado como acesso**. Ele é informação; o que
      não pode é chamá-lo de papel.
      """

      refute html =~ "Roles declared for this person", """
      Sem alocação, o bloco de papéis declarados não existe. Um bloco vazio dizendo "nenhum
      papel" ao lado de uma participação observada confundiria as duas coisas.
      """
    end

    test "com alocação, a tela diz que foi declarado, e por quem", ctx do
      alocar(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Roles declared for this person"
      assert html =~ "Desenvolvedor"
      assert html =~ ctx.user.email, "quem declarou tem de aparecer — é a FR-011 na tela"

      assert html =~ "no source provides organisational role", """
      A frase é o que impede a leitura errada: sem ela, "Developer" ao lado de uma equipe
      observada parece ter vindo do GitHub.
      """
    end

    test "o nível de acesso não aparece como papel", ctx do
      alocar(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      bloco = bloco_de_papeis(html)

      refute bloco =~ "MAINTAINER", """
      **A SC-006, e é a asserção que uma feature de cadastro costuma não ter.**

      `MAINTAINER` diz quem administra o time na ferramenta de origem. Aparecer no bloco de
      papéis o transformaria em papel organizacional — e o teste que só afirma "o papel
      aparece" passaria igual.
      """
    end

    test "sem data de início, a tela diz que não foi informada", ctx do
      alocar(ctx)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "not stated", """
      Ausência de data é informação, e a tela a diz. Mostrar a data de hoje afirmaria que a
      alocação começou agora.
      """
    end

    test "a evidência que acabou não encerra o papel na tela", ctx do
      alocar(ctx)

      {:ok, _} =
        EO.mark_evidence_no_longer_observed(
          ctx.tenant,
          ctx.organizacao.id,
          DateTime.add(DateTime.utc_now(:second), 60, :second)
        )

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Desenvolvedor", """
      O papel **continua na tela** depois de a origem parar de mostrar a participação.

      Um teste que só afirmasse a frase sobre a evidência não pegaria o papel tendo sumido — e
      sumir seria a coleta apagando uma declaração humana.
      """

      assert html =~ "current", "e ele continua vigente: ninguém disse que a pessoa saiu"
    end
  end

  defp alocar(ctx) do
    {:ok, papel} =
      EO.create_role(
        ctx.tenant,
        ctx.organizacao.id,
        %{code: "developer", name: "Desenvolvedor"},
        ctx.user.id
      )

    {:ok, vinculo} =
      EO.allocate(ctx.tenant, %{
        person_id: ctx.pessoa.id,
        team_id: ctx.equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: ctx.user.id,
        evidence_id: ctx.evidencia.id
      })

    vinculo
  end

  # Só o bloco de papéis declarados — a asserção de ausência precisa ser sobre ele, e não
  # sobre a página inteira, onde `MAINTAINER` aparece legitimamente como acesso.
  defp bloco_de_papeis(html) do
    case Regex.run(~r{Roles declared for this person(.*?)</section>}s, html) do
      [_, bloco] -> bloco
      _ -> flunk("não achei o bloco de papéis declarados")
    end
  end
end
