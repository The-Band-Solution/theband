defmodule TheBandWeb.DeclararPapelNaLinhaTest do
  @moduledoc """
  Declarar e alterar o papel a partir da linha — feature 060, T019: FR-015 a FR-018 e FR-034.

  ## As asserções que carregam este arquivo

  1. **o botão diz o que faz**: "Declare role" onde não há papel, "Change role" onde há. São
     comandos diferentes — um completa o vínculo observado, o outro encerra um papel e abre
     outro —, e um rótulo só para os dois esconderia que a segunda ação **encerra** algo;
  2. **"since" vem vazia**, e o rótulo diz que vazio é desconhecido, nunca hoje (FR-016). A
     seção de promoção pré-preenchia com hoje, e é o que a FR-016 proíbe;
  3. **"＋ new role…" cria e declara sem sair da linha** (FR-034);
  4. **as recusas do domínio chegam com frase de tela**, e não como átomo inspecionado.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})

    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, admin.id)
    {:ok, sm} = EO.create_role(tenant, org.id, %{code: "sm", name: "Scrum Master"}, admin.id)

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    %{
      conn: log_in(build_conn(), admin),
      tenant: tenant,
      admin: admin,
      org: org,
      equipe: equipe,
      ana: ana,
      dev: dev,
      sm: sm
    }
  end

  defp estrutura(ctx), do: live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")

  defp observar(ctx) do
    {:ok, _} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: ctx.ana.id,
        team_id: ctx.equipe.id,
        person_external_id: ctx.ana.external_id,
        team_external_id: ctx.equipe.external_id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: ~U[2026-02-01 00:00:00Z]
      })
  end

  defp declarar(ctx, papel) do
    {:ok, v} =
      EO.declare_role(ctx.tenant, ctx.equipe.id, ctx.ana.id, {:existente, papel.id}, ctx.admin.id)

    v
  end

  defp abrir(live, ctx) do
    live
    |> element(~s|button[phx-click="abrir_papel"][phx-value-person_id="#{ctx.ana.id}"]|)
    |> render_click()
  end

  describe "o botão diz qual das duas ações é" do
    test "vínculo observado sem papel oferece 'Declare role'", ctx do
      observar(ctx)
      {:ok, _live, html} = estrutura(ctx)

      assert html =~ "Declare role"
      refute html =~ "Change role"
    end

    test "vínculo com papel declarado: o botão da linha ACRESCENTA, e trocar é por papel", ctx do
      declarar(ctx, ctx.dev)
      {:ok, live, html} = estrutura(ctx)

      # ANTES este teste afirmava `html =~ "Change role"` no botão da LINHA, e a ação encerrava
      # o primeiro papel por ordem de criação. Decisão da pessoa mantenedora em 2026-09-08: um
      # botão *Change* por papel, e o da linha passa a somar.
      #
      # A razão é a ambiguidade que o rótulo antigo escondia: com *Developer* e *Scrum Master*,
      # quem clicava em "Change role" não escolhia qual estava trocando.
      assert html =~ "Add role"
      refute html =~ "Change role"
      refute html =~ "Declare role"

      # E o *Change* daquele papel existe, com o id do vínculo.
      assert has_element?(live, ~s|button[phx-click="abrir_papel"][phx-value-membership_id]|)
    end
  end

  describe "o formulário (FR-015, FR-016, FR-034)" do
    test "abre com 'choose…', os papéis da organização e '＋ new role…'", ctx do
      observar(ctx)
      {:ok, live, _html} = estrutura(ctx)

      aberto = abrir(live, ctx)

      assert aberto =~ "declare role ·"
      assert aberto =~ "choose…"
      assert aberto =~ "Desenvolvedora"
      assert aberto =~ "Scrum Master"
      assert aberto =~ "new role…"
    end

    test "a data 'since' vem VAZIA, e o texto diz o que vazio significa", ctx do
      observar(ctx)
      {:ok, live, _html} = estrutura(ctx)

      aberto = abrir(live, ctx)

      assert aberto =~ ~s|type="date" name="desde"|

      refute aberto =~ ~r/name="desde"[^>]*value="\d/, """
      A data de início não pode vir preenchida (FR-016). Vazio é DESCONHECIDO, e preencher com
      hoje afirmaria que a pessoa assumiu o papel agora — quando o que se sabe é que ninguém
      disse quando.
      """

      assert aberto =~ "empty date = unknown, never today"
    end

    test "declarar completa o vínculo observado — mesmo id", ctx do
      observar(ctx)
      [observado] = EO.list_team_roster(ctx.tenant, ctx.equipe.id) |> Enum.flat_map(& &1.vinculos)

      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "papel" => "existente:#{ctx.dev.id}",
          "desde" => ""
        })

      assert depois =~ "Role recorded"

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [vinculo] = pessoa.vinculos
      assert vinculo.membership_id == observado.membership_id, "declarar criou um segundo vínculo"
      assert vinculo.role.id == ctx.dev.id
      assert is_nil(vinculo.started_at), "data vazia gravou uma data"
    end

    test "declarar sem escolher papel é recusado com a razão", ctx do
      observar(ctx)
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "papel" => "",
          "desde" => ""
        })

      assert depois =~ "does not guess"

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [vinculo] = pessoa.vinculos
      assert is_nil(vinculo.role), "a recusa declarou o papel mesmo assim"
    end

    test "'＋ new role…' cria o papel e declara, sem sair da linha (FR-034)", ctx do
      observar(ctx)
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "papel" => "novo",
          "nome_do_papel" => "Tech Lead",
          "desde" => ""
        })

      assert depois =~ "Role recorded"

      # O papel existe na organização DA EQUIPE, com o código derivado do nome.
      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)
      criado = Enum.find(papeis, &(&1.name == "Tech Lead"))

      refute is_nil(criado), "o papel novo não foi criado"
      assert criado.code == "tech_lead", "o código sai do nome, para não pedir duas vezes"

      # E está declarado na pessoa, na mesma submissão.
      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [vinculo] = pessoa.vinculos
      assert vinculo.role.name == "Tech Lead"
    end

    test "'＋ new role…' sem nome é recusado, e nenhum papel é criado", ctx do
      observar(ctx)
      antes = length(EO.list_organization_roles(ctx.tenant, ctx.org.id))
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "papel" => "novo",
          "nome_do_papel" => "   ",
          "desde" => ""
        })

      assert depois =~ "needs a name"
      assert length(EO.list_organization_roles(ctx.tenant, ctx.org.id)) == antes
    end
  end

  describe "um botão Change por PAPEL (decisão de 2026-09-08)" do
    test "com dois papéis, há dois botões Change — e o da linha ACRESCENTA", ctx do
      um = declarar(ctx, ctx.dev)
      dois = declarar(ctx, ctx.sm)

      {:ok, live, html} = estrutura(ctx)

      # Um botão por papel, cada um carregando o SEU membership_id.
      assert has_element?(live, ~s|button[phx-value-membership_id="#{um.id}"]|)
      assert has_element?(live, ~s|button[phx-value-membership_id="#{dois.id}"]|)

      # E o botão da linha, sem membership_id, passa a dizer que soma.
      assert html =~ "Add role", """
      Com papel já declarado, o botão da linha ACRESCENTA um segundo — e chamá-lo de
      "Declare role" esconderia que o primeiro continua. Antes desta decisão ele dizia
      "Change role" e encerrava o primeiro papel por ordem de criação: quem tinha dois clicava
      sem saber qual estava trocando, e a tela não perguntava.
      """

      refute html =~ "Change role"
    end

    test "sem papel algum, o botão da linha diz Declare role", ctx do
      observar(ctx)
      {:ok, _live, html} = estrutura(ctx)

      assert html =~ "Declare role"
      refute html =~ "Add role"
    end

    test "o formulário NOMEIA o papel que está sendo trocado", ctx do
      um = declarar(ctx, ctx.dev)
      _dois = declarar(ctx, ctx.sm)

      {:ok, live, _html} = estrutura(ctx)

      aberto =
        live
        |> element(~s|button[phx-value-membership_id="#{um.id}"]|)
        |> render_click()

      assert aberto =~ "replacing Desenvolvedora", """
      Com dois papéis vigentes, "change role · Ana" não diz qual — e é justamente a
      ambiguidade que o botão por papel veio remover. Deixá-la no título a reintroduziria
      depois do clique.
      """

      refute aberto =~ "replacing Scrum Master"
      assert aberto =~ "role this person holds here is untouched"
    end

    test "trocar UM papel deixa o outro intacto", ctx do
      um = declarar(ctx, ctx.dev)
      dois = declarar(ctx, ctx.sm)

      {:ok, papel_novo} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "tl", name: "Tech Lead"}, ctx.admin.id)

      {:ok, live, _html} = estrutura(ctx)

      render_submit(live, "registrar_papel", %{
        "person_id" => ctx.ana.id,
        "membership_id" => um.id,
        "papel" => "existente:#{papel_novo.id}",
        "desde" => "2026-03-01"
      })

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      vigentes =
        pessoa.vinculos
        |> Enum.filter(&(&1.vigente? and &1.role))
        |> Enum.map(& &1.role.name)
        |> Enum.sort()

      assert vigentes == ["Scrum Master", "Tech Lead"], """
      Trocar um papel encerra AQUELE e abre o novo; os outros continuam — é o que FR-018
      permite. Achei #{inspect(vigentes)}.
      """

      # E o encerrado é exatamente o que foi clicado.
      encerrado = Enum.find(pessoa.vinculos, &(&1.membership_id == um.id))
      assert encerrado.fim, "o papel clicado não foi encerrado"

      intacto = Enum.find(pessoa.vinculos, &(&1.membership_id == dois.id))
      assert is_nil(intacto.fim), "o outro papel foi encerrado sem ninguém pedir"
    end

    test "papel de SUBEQUIPE não oferece Change nesta tela", ctx do
      parte = team_fixture(ctx.tenant, "T_dados", %{organization: ctx.org, name: "DADOS"})
      {:ok, _} = EO.compose_teams(ctx.tenant, parte.id, ctx.equipe.id, ctx.admin.id)

      {:ok, na_parte} =
        EO.declare_role(ctx.tenant, parte.id, ctx.ana.id, {:existente, ctx.dev.id}, ctx.admin.id)

      {:ok, live, html} = estrutura(ctx)

      # A pessoa aparece, com o chip da subequipe.
      assert html =~ "DADOS"

      refute has_element?(live, ~s|button[phx-value-membership_id="#{na_parte.id}"]|), """
      Trocar o papel de alguém numa subequipe é trabalho na tela DAQUELA subequipe, onde o
      veredito é o dela. Oferecer o botão aqui faria a autoridade atravessar de lado — quem
      gere esta equipe passaria a mexer na estrutura de outra.
      """
    end
  end

  describe "alterar o papel a partir da linha (FR-017)" do
    test "encerra o antigo e abre o novo na mesma data", ctx do
      vinculo = declarar(ctx, ctx.dev)
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "membership_id" => vinculo.id,
          "papel" => "existente:#{ctx.sm.id}",
          "desde" => "2026-03-01"
        })

      assert depois =~ "Role recorded"

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert length(pessoa.vinculos) == 2, "a troca tem de deixar o histórico como linha"

      antigo = Enum.find(pessoa.vinculos, &(&1.membership_id == vinculo.id))
      novo = Enum.find(pessoa.vinculos, &(&1.membership_id != vinculo.id))

      assert antigo.fim, "o papel antigo continuou vigente"
      assert novo.role.id == ctx.sm.id
      assert novo.started_at == ~U[2026-03-01 00:00:00Z]
    end

    test "trocar para o mesmo papel é recusado com frase de tela, e nada muda", ctx do
      vinculo = declarar(ctx, ctx.dev)
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "membership_id" => vinculo.id,
          "papel" => "existente:#{ctx.dev.id}",
          "desde" => ""
        })

      assert depois =~ "already holds that role", """
      A recusa tem de chegar como frase, e não como `:already_allocated` inspecionado — quem
      lê a tela não sabe o que é um átomo.
      """

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [so_um] = pessoa.vinculos
      assert is_nil(so_um.fim), "o encerramento não foi desfeito"
    end
  end

  describe "quem não gere não vê o botão, e o evento é recusado" do
    setup ctx do
      {:ok, outra} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "leitor-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      declarar(ctx, ctx.dev)
      %{leitor: log_in(build_conn(), outra)}
    end

    test "lê a linha e não vê ação de papel", ctx do
      {:ok, _live, html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      assert html =~ "Ana"
      refute html =~ "abrir_papel"
    end

    test "o evento direto é recusado, e o papel não muda", ctx do
      {:ok, live, _html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      depois =
        render_submit(live, "registrar_papel", %{
          "person_id" => ctx.ana.id,
          "papel" => "existente:#{ctx.sm.id}",
          "desde" => ""
        })

      assert depois =~ "not linked to a person"

      [pessoa] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [so_um] = pessoa.vinculos
      assert so_um.role.id == ctx.dev.id
    end
  end
end
