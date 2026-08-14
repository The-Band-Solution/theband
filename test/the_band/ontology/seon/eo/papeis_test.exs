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
    %{tenant: tenant_fixture()}
  end

  describe "cadastrar" do
    test "o papel aparece na lista", ctx do
      assert {:ok, papel} =
               EO.create_role(ctx.tenant, %{code: "developer", name: "Desenvolvedor"})

      assert [encontrado] = EO.list_roles(ctx.tenant)
      assert encontrado.id == papel.id
      assert encontrado.code == "developer"
    end

    test "o mesmo código duas vezes é recusado", ctx do
      {:ok, _} = EO.create_role(ctx.tenant, %{code: "developer", name: "Desenvolvedor"})

      assert {:error, changeset} =
               EO.create_role(ctx.tenant, %{code: "developer", name: "Outro nome"})

      assert errors_on(changeset)[:code], "a recusa precisa nomear o campo em conflito"
    end

    test "o mesmo código em outro tenant é aceito", ctx do
      vizinho = tenant_fixture()

      {:ok, _} = EO.create_role(ctx.tenant, %{code: "developer", name: "Desenvolvedor"})

      assert {:ok, _} = EO.create_role(vizinho, %{code: "developer", name: "Developer"})

      assert length(EO.list_roles(ctx.tenant)) == 1, """
      **Esta é a asserção do escopo**, e não a da duplicata. Papel é reconhecimento de uma
      organização; duas organizações reconhecerem "developer" não é conflito, e cada uma vê
      só o seu.
      """

      assert length(EO.list_roles(vizinho)) == 1
    end
  end

  describe "renomear" do
    test "muda o nome e preserva o código", ctx do
      {:ok, papel} = EO.create_role(ctx.tenant, %{code: "dev", name: "Dev"})

      assert {:ok, renomeado} = EO.rename_role(ctx.tenant, papel.id, "Pessoa Desenvolvedora")

      assert renomeado.name == "Pessoa Desenvolvedora"

      assert renomeado.code == "dev", """
      **A asserção é sobre o que não mudou.** É pelo código que os vínculos referenciam o
      papel; trocá-lo ao renomear seria trocar a identidade em vez do rótulo.
      """
    end

    test "nome em branco é recusado, e o anterior permanece", ctx do
      {:ok, papel} = EO.create_role(ctx.tenant, %{code: "dev", name: "Dev"})

      assert {:error, :blank_name} = EO.rename_role(ctx.tenant, papel.id, "   ")

      assert {:ok, intacto} = EO.fetch_role(ctx.tenant, papel.id)
      assert intacto.name == "Dev"
    end

    test "papel de outro tenant é não encontrado", ctx do
      {:ok, papel} = EO.create_role(ctx.tenant, %{code: "dev", name: "Dev"})
      vizinho = tenant_fixture()

      assert {:error, :not_found} = EO.rename_role(vizinho, papel.id, "invadido")
    end
  end

  describe "remover" do
    test "papel sem vínculo é removido", ctx do
      {:ok, papel} = EO.create_role(ctx.tenant, %{code: "dev", name: "Dev"})

      assert {:ok, _} = EO.delete_role(ctx.tenant, papel.id)
      assert EO.list_roles(ctx.tenant) == []
    end

    test "papel com vínculo é recusado, e a recusa diz quantos", ctx do
      %{papel: papel} = cenario_com_alocacao(ctx)

      assert {:error, {:in_use, 1}} = EO.delete_role(ctx.tenant, papel.id)

      assert [_] = EO.list_roles(ctx.tenant), """
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
    {:ok, papel} = EO.create_role(ctx.tenant, %{code: "dev", name: "Dev"})
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
