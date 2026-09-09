defmodule TheBandWeb.PapeisNaEstruturaTest do
  @moduledoc """
  A seção *Roles* dentro da Estrutura — feature 060, T021 e T022: FR-029 a FR-033, SC-005.

  ## As asserções que carregam este arquivo

  1. **é o mesmo papel, e não uma cópia** (FR-030, SC-005): criar aqui e abrir `/roles` acha
     o papel. Duas portas para o mesmo conceito com escopos diferentes produziriam dois
     catálogos que divergem em silêncio;
  2. **o código é sugerido do nome e editável** (FR-031). Sugerir sem permitir editar imporia
     a nossa transliteração; pedir sem sugerir faria digitar duas vezes a mesma coisa;
  3. **papel do catálogo não tem ação de renomear nem de ocultar** (FR-033): o nome vem da
     rede de conceitos, e mudá-lo aqui faria a plataforma discordar da ontologia que publica;
  4. **a recusa de ocultar diz QUANTOS vínculos impedem** (FR-033). "Não é possível" manda
     procurar o problema; "3 pessoas desempenham" diz onde ele está;
  5. **as contagens são de PESSOAS distintas**, aqui e na organização (FR-029).
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})
    vizinha = team_fixture(tenant, "T_outra", %{organization: org, name: "QA"})

    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, admin.id)

    %{
      conn: log_in(build_conn(), admin),
      tenant: tenant,
      admin: admin,
      org: org,
      equipe: equipe,
      vizinha: vizinha,
      dev: dev
    }
  end

  defp estrutura(ctx), do: live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        source_attrs("U_#{login}", %{login: login, name: String.capitalize(login)})
      )

    p
  end

  defp declarar(ctx, pessoa, papel, equipe) do
    {:ok, v} =
      EO.declare_role(ctx.tenant, equipe.id, pessoa.id, {:existente, papel.id}, ctx.admin.id)

    v
  end

  describe "a lista dos papéis da organização (FR-029)" do
    test "traz catálogo e criados, com origem e código", ctx do
      {:ok, _live, html} = estrutura(ctx)

      assert html =~ "Roles"
      assert html =~ "from the catalogue"
      assert html =~ "created here"

      # O criado, com o código dele.
      assert html =~ "Desenvolvedora"
      assert html =~ "created by the organisation"

      # E os quatro do catálogo, que existem sem cadastro.
      assert html =~ "Scrum Master"
      assert html =~ "catalogue · sro."
    end

    test "conta PESSOAS distintas aqui e na organização (FR-029)", ctx do
      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")

      # Ana nesta equipe; Bia na equipe vizinha, mesma organização.
      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, bia, ctx.dev, ctx.vizinha)

      contagens = EO.role_holder_counts(ctx.tenant, ctx.org.id, ctx.equipe.id)

      assert contagens[ctx.dev.id] == %{nesta_equipe: 1, na_organizacao: 2}, """
      A coluna da equipe conta só quem o desempenha AQUI; a da organização, todos. Um número
      só para as duas responderia a pergunta errada em uma delas.
      """
    end

    test "a mesma pessoa com o papel em duas equipes conta UMA vez na organização", ctx do
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, ana, ctx.dev, ctx.vizinha)

      contagens = EO.role_holder_counts(ctx.tenant, ctx.org.id, ctx.equipe.id)

      assert contagens[ctx.dev.id] == %{nesta_equipe: 1, na_organizacao: 1}, """
      A pergunta é quantas PESSOAS desempenham o papel. Contar vínculos daria 2 para uma
      pessoa só — o mesmo defeito que `count_team_members_at/3` tinha.
      """
    end

    test "papel sem ninguém aparece com zero, e não fica fora da tabela", ctx do
      {:ok, _live, html} = estrutura(ctx)

      assert html =~ "Desenvolvedora"

      contagens = EO.role_holder_counts(ctx.tenant, ctx.org.id, ctx.equipe.id)

      refute Map.has_key?(contagens, ctx.dev.id), """
      Papel sem ninguém NÃO entra no mapa, e a tela lê `0/0` por omissão. Uma entrada com zero
      no mapa seria uma linha inventada para dizer o que a ausência já diz.
      """
    end
  end

  describe "criar papel a partir da Estrutura (FR-030, FR-031)" do
    test "o código é sugerido do nome", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois = render_change(live, "sugerir_codigo", %{"name" => "Tech Lead", "code" => ""})

      assert depois =~ ~s|value="tech_lead"|, "o código não foi sugerido a partir do nome"
    end

    test "o código editado NÃO é sobrescrito pela sugestão", ctx do
      {:ok, live, _html} = estrutura(ctx)

      render_change(live, "sugerir_codigo", %{"name" => "Tech Lead", "code" => ""})
      depois = render_change(live, "sugerir_codigo", %{"name" => "Tech Lead", "code" => "tl"})

      assert depois =~ ~s|value="tl"|, """
      A partir do momento em que a pessoa escreve o código, a sugestão pararia de ajudar e
      passaria a apagar o que ela digitou a cada letra do nome.
      """
    end

    test "criar aqui aparece em /roles — é o MESMO papel (SC-005)", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "criar_papel", %{"name" => "Tech Lead", "code" => "tech_lead"})

      assert depois =~ "created"

      # E em `/roles`, que é a outra porta para o mesmo escopo.
      {:ok, _roles, html} = live(ctx.conn, ~p"/roles")

      assert html =~ "Tech Lead", """
      Criar na Estrutura e não achar em `/roles` significaria duas portas para o mesmo
      conceito com escopos diferentes — dois catálogos que divergem em silêncio.
      """
    end

    test "código repetido na MESMA organização é recusado com a razão", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois = render_submit(live, "criar_papel", %{"name" => "Outra Dev", "code" => "dev"})

      assert depois =~ "already has a role with that code"
      assert depois =~ "another organisation is fine"
    end

    test "o mesmo código em OUTRA organização não é conflito (FR-031)", ctx do
      outra = organization_fixture(ctx.tenant, "outra")

      assert {:ok, _} =
               EO.create_role(
                 ctx.tenant,
                 outra.id,
                 %{code: "dev", name: "Dev"},
                 ctx.admin.id
               )
    end
  end

  describe "renomear e ocultar (FR-032, FR-033)" do
    test "renomear mantém os vínculos apontando para o mesmo papel", ctx do
      ana = pessoa(ctx, "ana")
      vinculo = declarar(ctx, ana, ctx.dev, ctx.equipe)

      {:ok, live, _html} = estrutura(ctx)

      depois =
        render_submit(live, "renomear_papel", %{
          "role_id" => ctx.dev.id,
          "name" => "Engenheira"
        })

      assert depois =~ "renamed to Engenheira"

      {:ok, ainda} = EO.fetch_membership(ctx.tenant, vinculo.id)

      assert ainda.organizational_role_id == ctx.dev.id, """
      Renomear é atualizar a linha, e não criar um papel novo migrando os vínculos. Se o
      `organizational_role_id` mudasse, toda medida por papel de um período anterior mudaria.
      """
    end

    test "ocultar papel COM vínculo vigente é recusado, dizendo quantos", ctx do
      declarar(ctx, pessoa(ctx, "ana"), ctx.dev, ctx.equipe)
      declarar(ctx, pessoa(ctx, "bia"), ctx.dev, ctx.equipe)

      {:ok, live, _html} = estrutura(ctx)

      depois = render_click(live, "ocultar_papel", %{"role_id" => ctx.dev.id})

      assert depois =~ "2 people still hold this role", """
      A recusa tem de dizer QUANTOS vínculos impedem (FR-033). "Não é possível ocultar" manda
      quem administra procurar o problema; o número diz onde ele está.
      """
    end

    test "ocultar papel sem ninguém funciona, e é MARCA — não apaga", ctx do
      {:ok, live, _html} = estrutura(ctx)

      depois = render_click(live, "ocultar_papel", %{"role_id" => ctx.dev.id})

      assert depois =~ "hidden"

      # A linha continua, marcada. Quem desempenhou aquele papel continua tendo desempenhado.
      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)
      oculto = Enum.find(papeis, &(&1.id == ctx.dev.id))

      refute is_nil(oculto), "ocultar apagou a linha"
      refute is_nil(oculto.hidden_at)
    end

    test "papel do CATÁLOGO não oferece renomear nem ocultar", ctx do
      {:ok, _live, html} = estrutura(ctx)

      # Só o papel criado tem os botões; os do catálogo não têm `id` até serem materializados,
      # e mesmo materializados a origem os exclui da ação.
      botoes = length(String.split(html, ~s|phx-click="abrir_renomear"|)) - 1

      assert botoes == 1, """
      Achei #{botoes} botões de renomear, e só o papel criado pela organização deveria ter um.
      O nome do papel do catálogo vem da rede de conceitos, e mudá-lo aqui faria a plataforma
      discordar da ontologia que ela mesma publica (FR-033).
      """
    end
  end

  describe "quem não gere lê os papéis e não age" do
    setup ctx do
      {:ok, outra} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "leitor-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{leitor: log_in(build_conn(), outra)}
    end

    test "vê a tabela e nenhum botão nem formulário", ctx do
      {:ok, _live, html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      assert html =~ "Roles"
      assert html =~ "Desenvolvedora"
      refute html =~ "abrir_renomear"
      refute html =~ "ocultar_papel"
      refute html =~ "criar_papel"
    end

    test "o evento de criar é recusado", ctx do
      {:ok, live, _html} = live(ctx.leitor, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      antes = length(EO.list_organization_roles(ctx.tenant, ctx.org.id))

      depois = render_submit(live, "criar_papel", %{"name" => "Pela porta", "code" => "porta"})

      assert depois =~ "not linked to a person"
      assert length(EO.list_organization_roles(ctx.tenant, ctx.org.id)) == antes
    end
  end
end
