defmodule TheBand.Ontology.SEON.EO.PapeisTest do
  @moduledoc """
  O catálogo de papéis que a organização reconhece (T004 a T007).

  ## O que a medida achou, e por que esta feature existe

  Em 2026-08-14: **101 evidências de vínculo, zero vínculos, zero papéis**. Os três números
  são o mesmo fato — `eo_team_memberships.organizational_role_id` é `NOT NULL`.

  ## As duas asserções que importam aqui não são as óbvias

  A primeira é que o **código não muda** ao renomear: é por ele que os vínculos referenciam o
  papel. A segunda é que pedir as sugestões **não grava nada** — a plataforma sugere, e quem
  reconhece o papel é a organização.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    # Papel passou a ser DA ORGANIZAÇÃO — issue #317. O tenant sozinho já não basta.
    %{tenant: tenant, org: organization_fixture(tenant), user: user_fixture(tenant)}
  end

  describe "cadastrar" do
    test "o papel aparece na lista", ctx do
      assert {:ok, papel} =
               EO.create_role(
                 ctx.tenant,
                 ctx.org.id,
                 %{code: "developer", name: "Desenvolvedor"},
                 ctx.user.id
               )

      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)

      assert encontrado = Enum.find(papeis, &(&1.id == papel.id))
      assert encontrado.code == "developer"

      assert encontrado.origem == {:declarado, ctx.user.id}, """
      A origem fica visível, e não inferida do nome — FR-003. Sem ela, em seis meses ninguém
      sabe se o papel veio da rede ou alguém o digitou.
      """

      # **A lista não tem só o declarado.** Os quatro do Scrum vêm sempre, compostos da rede —
      # é a FR-002, e é o que dispensa cadastro prévio antes de promover.
      assert length(papeis) == 5, """
      Esperado: os quatro do catálogo mais o declarado. Vieram #{length(papeis)}.
      """
    end

    test "o mesmo código duas vezes é recusado", ctx do
      {:ok, _} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "developer", name: "Desenvolvedor"},
          ctx.user.id
        )

      # **A recusa é `{:error, :code_taken}`, e não um changeset.** Erro previsto de negócio é
      # retorno nomeado — princípio VIII. Quem chama precisa distinguir "código repetido" de
      # "formulário inválido", e um changeset obrigaria a inspecionar erros para saber qual é.
      assert {:error, :code_taken} =
               EO.create_role(
                 ctx.tenant,
                 ctx.org.id,
                 %{code: "developer", name: "Outro nome"},
                 ctx.user.id
               )
    end

    test "o mesmo código em outra ORGANIZAÇÃO é aceito", ctx do
      # **No mesmo tenant.** Era o índice `UNIQUE (tenant_id, code)` que impedia, e ele foi o
      # bloqueio real da issue #317: sem trocá-lo, a segunda organização a receber qualquer
      # papel do catálogo bateria na constraint.
      vizinha = organization_fixture(ctx.tenant, "vizinha")

      {:ok, _} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "developer", name: "Desenvolvedor"},
          ctx.user.id
        )

      assert {:ok, _} =
               EO.create_role(
                 ctx.tenant,
                 vizinha.id,
                 %{code: "developer", name: "Developer"},
                 ctx.user.id
               )

      declarados = fn org_id ->
        ctx.tenant
        |> EO.list_organization_roles(org_id)
        |> Enum.filter(&(elem(&1.origem, 0) == :declarado))
      end

      assert length(declarados.(ctx.org.id)) == 1, """
      **Esta é a asserção do escopo**, e não a da duplicata. Papel é reconhecimento de uma
      organização; duas organizações reconhecerem "developer" não é conflito, e cada uma vê
      só o seu.
      """

      assert length(declarados.(vizinha.id)) == 1, "e a vizinha vê o dela, e só o dela"
    end
  end

  describe "renomear" do
    test "muda o nome e preserva o código", ctx do
      {:ok, papel} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.user.id)

      assert {:ok, renomeado} =
               EO.rename_role(ctx.tenant, papel.id, "Pessoa Desenvolvedora", ctx.user.id)

      assert renomeado.name == "Pessoa Desenvolvedora"

      assert renomeado.code == "dev", """
      **A asserção é sobre o que não mudou.** É pelo código que os vínculos referenciam o
      papel; trocá-lo ao renomear seria trocar a identidade em vez do rótulo.
      """
    end

    test "nome em branco é recusado, e o anterior permanece", ctx do
      {:ok, papel} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.user.id)

      assert {:error, :blank_name} = EO.rename_role(ctx.tenant, papel.id, "   ", ctx.user.id)

      assert {:ok, intacto} = EO.fetch_role(ctx.tenant, papel.id)
      assert intacto.name == "Dev"
    end

    test "papel de outro tenant é não encontrado", ctx do
      {:ok, papel} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.user.id)

      vizinho = tenant_fixture()

      assert {:error, :not_found} = EO.rename_role(vizinho, papel.id, "invadido")
    end
  end

  describe "remover" do
    test "papel sem vínculo é removido", ctx do
      {:ok, papel} =
        EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.user.id)

      assert {:ok, _} = EO.delete_role(ctx.tenant, papel.id)

      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)
      refute Enum.any?(papeis, &(&1.id == papel.id))

      # A lista **não** fica vazia: os quatro do catálogo continuam disponíveis. Eles não são
      # linhas, então apagar linha nenhuma os alcança.
      assert length(papeis) == 4
    end

    test "papel com vínculo é recusado, e a recusa diz quantos", ctx do
      %{papel: papel} = cenario_com_alocacao(ctx)

      assert {:error, {:in_use, 1}} = EO.delete_role(ctx.tenant, papel.id)

      assert Enum.any?(EO.list_organization_roles(ctx.tenant, ctx.org.id), &(&1.id == papel.id)),
             """
             A recusa não pode ter meio-efeito: o papel continua existindo depois dela.
             """
    end
  end

  describe "as sugestões da ontologia" do
    test "quatro voltam, e nenhuma é gravada", ctx do
      sugestoes = EO.suggested_roles()

      assert length(sugestoes) == 4, """
      A SRO nomeia quatro papéis que herdam de `sro.scrum_role`: Product Owner, Scrum Master,
      Developer e Client. O próprio `sro.scrum_role` é o pai abstrato e não entra.
      """

      assert Enum.all?(sugestoes, &(&1.code != nil and &1.name != nil))

      assert EO.count_roles(ctx.tenant) == 0, """
      **Esta é a asserção que importa — a SC-004.** A plataforma sugere e não cadastra.

      `eo.organizational_role` é papel social **reconhecido pela organização**; cadastrar
      automaticamente faria a plataforma reconhecer no lugar dela, e produziria quatro papéis
      que talvez nenhuma equipe use.
      """
    end
  end

  defp cenario_com_alocacao(ctx) do
    {:ok, papel} =
      EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.user.id)

    organizacao = organization_fixture(ctx.tenant, "acme")
    equipe = team_fixture(ctx.tenant, "T_a", %{organization: organizacao})

    {:ok, pessoa} =
      EO.upsert_person_from_source(ctx.tenant, source_attrs("U_1", %{name: "Alguém"}))

    {:ok, vinculo} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id
      })

    %{papel: papel, pessoa: pessoa, equipe: equipe, vinculo: vinculo}
  end
end
