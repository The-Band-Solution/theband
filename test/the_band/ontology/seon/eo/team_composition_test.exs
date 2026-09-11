defmodule TheBand.Ontology.SEON.EO.TeamCompositionTest do
  @moduledoc """
  Feature 055, US3 — equipe dentro de equipe.

  **O ciclo de comprimento 3 vem antes do de comprimento 2, e é de propósito.**
  O caso do vizinho direto — `A⊂B` e depois `B⊂A` — passa em implementação
  ingênua, que só olha se o par inverso existe. Só o caminho longo prova que a
  detecção percorre o grafo.

  Ciclo não é preciosismo: com ele, qualquer agregação pela hierarquia — a soma
  de competências que a #397 pede — **não termina**.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  defp cenario do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant)

    equipes =
      for nome <- ~w(A B C D) do
        {:ok, e} = EO.declare_structural_team(tenant, org.id, "Equipe #{nome}", autor.id)
        {nome, e}
      end
      |> Map.new()

    %{tenant: tenant, autor: autor, org: org, e: equipes}
  end

  describe "o ciclo é recusado (FR-009)" do
    test "comprimento 3: A⊂B, B⊂C, e C⊂A é recusado" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["B"].id, e["C"].id, a.id)

      assert {:error, motivo} = EO.compose_teams(t, e["C"].id, e["A"].id, a.id)

      # A recusa NOMEIA o caminho. "Fecharia ciclo" manda a pessoa procurar;
      # dizer por onde resolve.
      assert motivo =~ "Equipe A"
      assert motivo =~ "Equipe B"
    end

    test "comprimento 4, para o caso longo não passar por acaso" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["B"].id, e["C"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["C"].id, e["D"].id, a.id)

      assert {:error, _} = EO.compose_teams(t, e["D"].id, e["A"].id, a.id)
    end

    test "comprimento 2: A⊂B e B⊂A" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:error, _} = EO.compose_teams(t, e["B"].id, e["A"].id, a.id)
    end

    test "a equipe dentro de si mesma" do
      %{tenant: t, autor: a, e: e} = cenario()

      assert {:error, _} = EO.compose_teams(t, e["A"].id, e["A"].id, a.id)
    end
  end

  describe "declarar uma equipe DENTRO de outra é UM ato, numa transação" do
    test "a filha nasce composta na mãe, e herda a organização dela" do
      c = cenario()

      {:ok, filha} = EO.declare_subteam(c.tenant, c.e["A"], "  Squad Azul  ", c.autor.id)

      assert filha.name == "Squad Azul", "o nome é aparado — espaço na ponta não é nome"

      assert filha.organization_id == c.e["A"].organization_id, """
      A subequipe HERDA a organização da mãe, e não é conveniência: quem tem escopo nesta
      equipe declara DENTRO dela. Um seletor de organização aqui faria a autoridade subir.
      """

      assert Enum.any?(EO.list_teams(c.tenant, organization_id: c.org.id), &(&1.id == filha.id)),
             "a guarda do cenário: a filha existe de facto"

      partes = EO.team_parts(c.tenant, c.e["A"].id)
      assert Enum.any?(partes, &(&1.team_id == filha.id)), "e está composta na mãe"
    end

    test "a falha é RECUSA, e não queda — a tela precisa poder dizer o motivo" do
      c = cenario()
      mae_fantasma = %{c.e["A"] | id: Ecto.UUID.generate()}

      assert {:error, motivo} = EO.declare_subteam(c.tenant, mae_fantasma, "Squad X", c.autor.id),
             """
             Antes das `foreign_key_constraint/2` no `TeamComposition.changeset/2`, isto
             LEVANTAVA `Ecto.ConstraintError` — e exceção em `handle_event` de LiveView mata o
             processo: quem administra via a tela cair, e não o motivo. A transação já impedia
             a equipe órfã; o que faltava era a falha virar recusa.
             """

      assert is_binary(motivo), "e o motivo é frase, porque é ela que a tela mostra"
    end

    test "se a composição falha, a equipe NÃO fica criada e solta" do
      c = cenario()

      # A mãe que não existe no banco — o caso real é o formulário aberto sobre uma equipe
      # que saiu no meio. `organization_id` é válido, então o PRIMEIRO passo passa; o
      # segundo bate na chave estrangeira `whole_team_id`.
      mae_fantasma = %{c.e["A"] | id: Ecto.UUID.generate()}

      antes = length(EO.list_teams(c.tenant, organization_id: c.org.id))

      assert {:error, _motivo} =
               EO.declare_subteam(c.tenant, mae_fantasma, "Squad Órfã", c.autor.id)

      depois = EO.list_teams(c.tenant, organization_id: c.org.id)

      assert length(depois) == antes, """
      A INVARIANTE. Sem a transação, `declare_structural_team/4` já tinha gravado quando
      `compose_teams/4` falhou, e a equipe ficava CRIADA E SOLTA na organização — sem
      composição, e com a mensagem de erro falando do segundo passo sem dizer que o
      primeiro ficou feito. Quem lê conclui que nada aconteceu.
      """

      refute Enum.any?(depois, &(&1.name == "Squad Órfã")),
             "e a órfã não está lá nem com outro nome de busca"
    end
  end

  # ── OS CAMINHOS INFELIZES, e o que cada um tem de devolver ──
  #
  # Exercitados um a um contra o banco em 2026-09-10, e **três levantavam exceção** em vez de
  # recusar: nome de 300 caracteres (`Postgrex.Error` — a coluna é `varchar(255)` e não havia
  # validação de tamanho), autor inexistente e organização inexistente
  # (`Ecto.ConstraintError`, por falta de `foreign_key_constraint/2`).
  #
  # A lista não abre com a palavra que o Credo lê como marca de tarefa pendente: o
  # `Found a TODO tag` disparou duas vezes nesta sessão, por comentário que começava com ela.
  #
  # Exceção em `handle_event` de LiveView **mata o processo**: quem administra vê a tela cair,
  # e não o motivo. A tabela abaixo é o contrato — cada linha é uma recusa que a tela consegue
  # mostrar, e nenhuma é uma queda.
  describe "os caminhos infelizes recusam, e nenhum levanta" do
    setup do
      c = cenario()
      {:ok, _repetida} = EO.declare_subteam(c.tenant, c.e["A"], "Repetida", c.autor.id)
      c
    end

    for {rotulo, nome, trecho} <- [
          {"nome vazio", "", "can't be blank"},
          {"nome só de espaços", "     ", "can't be blank"},
          {"nome repetido entre declaradas", "Repetida", "já existe uma equipe declarada"},
          {"nome repetido com espaço nas pontas", "  Repetida  ",
           "já existe uma equipe declarada"},
          {"nome maior que a coluna", String.duplicate("x", 300), "at most 255"}
        ] do
      test "#{rotulo} recusa nomeando", c do
        assert {:error, motivo} =
                 EO.declare_subteam(c.tenant, c.e["A"], unquote(nome), c.autor.id)

        assert motivo =~ unquote(trecho), """
        A recusa tem de NOMEAR. `#{unquote(rotulo)}` devolveu #{inspect(motivo)}, e o esperado
        contém #{inspect(unquote(trecho))}.
        """
      end
    end

    test "o número do limite de tamanho aparece INTERPOLADO, e não como `%{count}`", c do
      {:error, motivo} =
        EO.declare_subteam(c.tenant, c.e["A"], String.duplicate("x", 300), c.autor.id)

      assert motivo =~ "255"

      refute motivo =~ "%{", """
      `traverse_errors` entrega `{mensagem, opções}`, e as opções carregam os valores que a
      mensagem referencia. Descartá-las com `{msg, _}` vazava `%{count}` PARA A TELA,
      literalmente, com as chaves. Medido em 2026-09-10.
      """
    end

    test "autor que não existe recusa, e não levanta", c do
      assert {:error, motivo} =
               EO.declare_subteam(c.tenant, c.e["A"], "Autor Fantasma", Ecto.UUID.generate())

      assert motivo =~ "does not exist"
    end

    test "organização que não existe recusa, e não levanta", c do
      mae = %{c.e["A"] | organization_id: Ecto.UUID.generate()}

      assert {:error, motivo} = EO.declare_subteam(c.tenant, mae, "Org Fantasma", c.autor.id)
      assert motivo =~ "does not exist"
    end

    test "mãe sem organização recusa nomeando o que falta", c do
      mae = %{c.e["A"] | organization_id: nil}

      assert {:error, motivo} = EO.declare_subteam(c.tenant, mae, "Sem Org", c.autor.id)

      assert motivo =~ "precisa da organização", """
      Aqui a recusa vem do `check_constraint` do banco, e a mensagem diz O QUE FALTA — não
      "constraint violated", que manda a pessoa procurar.
      """
    end

    test "NENHUM dos oito caminhos levanta", c do
      caminhos = [
        {"vazio", "", c.autor.id, c.e["A"]},
        {"espaços", "   ", c.autor.id, c.e["A"]},
        {"repetido", "Repetida", c.autor.id, c.e["A"]},
        {"longo", String.duplicate("x", 300), c.autor.id, c.e["A"]},
        {"autor fantasma", "A", Ecto.UUID.generate(), c.e["A"]},
        {"org fantasma", "B", c.autor.id, %{c.e["A"] | organization_id: Ecto.UUID.generate()}},
        {"sem org", "C", c.autor.id, %{c.e["A"] | organization_id: nil}},
        {"mãe fantasma", "D", c.autor.id, %{c.e["A"] | id: Ecto.UUID.generate()}}
      ]

      for {rotulo, nome, ator, mae} <- caminhos do
        resultado =
          try do
            EO.declare_subteam(c.tenant, mae, nome, ator)
          rescue
            e -> {:levantou, e.__struct__}
          end

        assert match?({:error, motivo} when is_binary(motivo), resultado), """
        `#{rotulo}` devolveu #{inspect(resultado)}. Toda recusa deste ato é `{:error, frase}`,
        porque a tela mostra a frase — e exceção em `handle_event` de LiveView derruba o
        processo em vez de dizer o motivo. Três destes oito levantavam em 2026-09-10.
        """
      end
    end
  end

  describe "compor e descompor (FR-008)" do
    test "a composição vale, com autor e início" do
      %{tenant: t, autor: a, e: e} = cenario()

      assert {:ok, c} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)

      assert c.part_team_id == e["A"].id
      assert c.whole_team_id == e["B"].id
      assert c.declared_by_user_id == a.id
      assert is_nil(c.ended_at)
    end

    test "a mesma composição duas vezes é recusada" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:error, motivo} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert motivo =~ "já"
    end

    test "descompor mantém a equipe, e o histórico" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:ok, c} = EO.decompose_teams(t, e["A"].id, e["B"].id, a.id)

      refute is_nil(c.ended_at)
      assert c.ended_by_user_id == a.id
      # A equipe continua existindo — a composição terminou, ela não.
      assert EO.count_teams(t) == 4
    end

    test "depois de descompor, compor de novo é permitido" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.decompose_teams(t, e["A"].id, e["B"].id, a.id)

      assert {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
    end

    test "uma equipe pode compor DUAS mães ao mesmo tempo" do
      # A cardinalidade é muitos-para-muitos de propósito: a estrutura real não é
      # árvore, e a mesma célula pode compor duas frentes.
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:ok, _} = EO.compose_teams(t, e["A"].id, e["C"].id, a.id)
    end
  end
end
