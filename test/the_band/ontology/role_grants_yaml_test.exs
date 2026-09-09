defmodule TheBand.Ontology.RoleGrantsYamlTest do
  @moduledoc """
  As duas concessões por papel, declaradas na base — T002 da feature 060.

  ## Por que este teste existe

  Princípio IV: nada na tela sem declaração. A tela da estrutura da equipe decide quem pode
  agir a partir de uma concessão a um **papel organizacional**, e a concessão precisa ter
  nome na base antes de a tela existir.

  E há uma segunda razão, achada ao planejar: a concessão de **visibilidade** vive no código
  desde 2026-08-26 (`eo_role_visibility_grants`) e **nunca foi declarada**. O módulo declara
  as duas juntas — a lacuna se fecha em vez de dobrar.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  @modulo "eo.role_grants"
  @visibilidade "eo.role_visibility_grant"
  @gestao "eo.role_structure_management_grant"

  test "o módulo existe na base, com os dois conceitos irmãos" do
    modulos = KnowledgeBase.list(:module)

    assert Enum.any?(modulos, &(&1["id"] == @modulo)), """
    O módulo #{@modulo} não foi carregado. Sem ele, a concessão que decide quem gere a
    estrutura da equipe seria regra escondida no código — e a tela mostraria botão que
    nenhuma declaração sustenta.
    """

    conceitos =
      modulos
      |> Enum.find(&(&1["id"] == @modulo))
      |> Map.get("concepts", [])
      |> Enum.map(& &1["id"])
      |> Enum.sort()

    assert conceitos == Enum.sort([@visibilidade, @gestao]), """
    Os conceitos do módulo são #{inspect(conceitos)}. Esperados os dois irmãos: a concessão
    de visibilidade (que já existia no código, sem declaração) e a de gestão (nova).
    """
  end

  test "as duas concessões declaram o alcance como enum de team e organization" do
    conceitos = conceitos_do_modulo()

    for id <- [@visibilidade, @gestao] do
      escopo =
        conceitos
        |> Enum.find(&(&1["id"] == id))
        |> Map.get("attributes", [])
        |> Enum.find(&(&1["name"] == "scope"))

      assert escopo["type"] == "enum", "#{id}: o alcance é enum, e não booleano nem texto livre"

      assert Enum.sort(escopo["values"]) == ["organization", "team"], """
      #{id} declara os alcances #{inspect(escopo["values"])}. São dois, e a diferença
      importa: `team` alcança as equipes em que a pessoa tem o papel; `organization`,
      todas as da organização.
      """
    end
  end

  test "revogação é atributo opcional — revogar marca, nunca apaga" do
    for id <- [@visibilidade, @gestao] do
      atributos =
        conceitos_do_modulo() |> Enum.find(&(&1["id"] == id)) |> Map.get("attributes", [])

      revogado = Enum.find(atributos, &(&1["name"] == "revoked_at"))
      declarado = Enum.find(atributos, &(&1["name"] == "declared_at"))

      assert declarado["required"] == true, "#{id}: quando foi concedida é obrigatório"

      assert revogado && revogado["required"] == false, """
      #{id}: `revoked_at` precisa existir e ser opcional. Nulo é a concessão vigente;
      preenchido é a concessão que existiu e acabou. Sem a coluna, revogar seria apagar —
      e a casa não apaga.
      """
    end
  end

  test "cada concessão se liga ao PAPEL, e não à conta" do
    relacoes =
      KnowledgeBase.list(:module)
      |> Enum.find(&(&1["id"] == @modulo))
      |> Map.get("relations", [])

    for {origem, id} <- [
          {@visibilidade, "eo.visibility_grant_to_role"},
          {@gestao, "eo.structure_management_grant_to_role"}
        ] do
      relacao = Enum.find(relacoes, &(&1["id"] == id))

      assert relacao, "a relação #{id} não existe"
      assert relacao["source"] == origem

      assert relacao["target"] == "eo.organizational_role", """
      #{id} aponta para #{relacao["target"]}. A concessão é **do papel**: uma conta não a
      recebe, e a pessoa alcança pelo vínculo vigente com o papel. Apontar para a conta
      faria a permissão sobreviver à troca de papel da pessoa.
      """
    end
  end

  test "o módulo está listado na ontologia EO — senão ele não compõe" do
    eo = Enum.find(KnowledgeBase.list(:ontology), &(&1["id"] == "eo"))

    assert "role_grants" in eo["modules"], """
    O arquivo existe e a ontologia não o lista. O validador não exige o inverso, então esta
    é a única guarda: sem a linha em `eo/ontology.yaml`, o módulo fica órfão e ninguém nota.
    """
  end

  defp conceitos_do_modulo do
    KnowledgeBase.list(:module)
    |> Enum.find(&(&1["id"] == @modulo))
    |> Map.get("concepts", [])
  end
end
