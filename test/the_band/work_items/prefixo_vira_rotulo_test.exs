defmodule TheBand.WorkItems.PrefixoViraRotuloTest do
  @moduledoc """
  O prefixo do título como segunda origem de rótulo — spec 065, T006.

  O teste que mais importa aqui é **negativo**: `[Portal ADM]` tem 68 issues no dado real,
  tem colchete, e **não** vira rótulo, porque não está na lista declarada. Sem essa
  asserção, uma implementação que aceita qualquer colchete passaria — e transformaria erro
  de digitação em caracterização.
  """

  use TheBand.DataCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems.Rotulos

  setup do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  describe "quais prefixos qualificam" do
    test "os declarados como NÃO-tipo viram rótulo" do
      # A lista vem de `not_type_patterns`, onde estes prefixos existem para serem
      # RECUSADOS como tipo — porque dizem quem faz ou em que área, não o que a issue é.
      # Essa recusa é exatamente a definição de caracterização.
      assert Rotulos.prefixo_reconhecido("[Devops] Fazer Deploy do Oráculo") == "Devops"
      assert Rotulos.prefixo_reconhecido("[Back-end] Permitir importação") == "Back-end"
      assert Rotulos.prefixo_reconhecido("[QA] Validar fluxo") == "QA"
    end

    test "prefixo NÃO declarado não vira rótulo — é o caso que prova a regra" do
      # 68 issues reais começam com este prefixo. Ele tem colchete, parece caracterização,
      # e mesmo assim fica de fora: aceitar qualquer colchete faria de um engano uma
      # afirmação sobre o trabalho do time.
      assert Rotulos.prefixo_reconhecido("[Portal ADM] - Adicionar healthcheck") == nil
      assert Rotulos.prefixo_reconhecido("[Qualquer Coisa] Alguma issue") == nil
    end

    test "prefixo de TIPO fica de fora" do
      # `[TASK]` tem 1188 issues e é roteado como TIPO pelo catálogo. Mostrá-lo também como
      # rótulo faria o mesmo texto significar duas coisas na mesma tela.
      assert Rotulos.prefixo_reconhecido("[TASK] OTTO-B2 — Harness de teste") == nil
      assert Rotulos.prefixo_reconhecido("[FEATURE] Nova tela") == nil
      assert Rotulos.prefixo_reconhecido("[BUG] Corrigir cálculo") == nil
    end

    test "título sem colchete, e título nulo" do
      assert Rotulos.prefixo_reconhecido("Implementar função de login") == nil
      assert Rotulos.prefixo_reconhecido(nil) == nil
    end

    test "a grafia sai como escrita, sem normalizar" do
      # `[Back-end]` vira `Back-end`, nunca `backend`. Normalizar seria a interpretação que
      # a FR-009 proíbe, aplicada ao nome do próprio rótulo.
      assert Rotulos.prefixo_reconhecido("[Back-end] x") == "Back-end"
      assert Rotulos.prefixo_reconhecido("[Front-end] y") == "Front-end"
    end
  end

  describe "as duas origens convivem" do
    test "o mesmo sentido vindo das duas vias aparece DUAS vezes" do
      # A issue real `[Back-end] Permitir importação de subrubricas` tem `backend` no campo
      # e `Back-end` no título. Juntá-los exigiria decidir que são a mesma coisa — e isso é
      # interpretação, não observação.
      rotulos = Rotulos.de(["backend"], "[Back-end] Permitir importação de subrubricas")

      assert rotulos == [
               %{texto: "backend", origem: :campo},
               %{texto: "Back-end", origem: :titulo}
             ]

      assert length(rotulos) == 2, "as duas origens foram unificadas — a FR-008 quebrou"
    end

    test "os do campo vêm primeiro, e a ordem é declarada" do
      rotulos = Rotulos.de(["um", "dois"], "[Devops] x")

      assert Enum.map(rotulos, & &1.origem) == [:campo, :campo, :titulo]
    end

    test "só o campo, só o título, e nenhum dos dois" do
      assert Rotulos.de(["só-campo"], "Sem colchete") == [%{texto: "só-campo", origem: :campo}]
      assert Rotulos.de(nil, "[QA] x") == [%{texto: "QA", origem: :titulo}]

      # Lista vazia, e não nulo: quem escreve a ausência em palavras é a tela.
      assert Rotulos.de(nil, "Nada aqui") == []
      assert Rotulos.de([], nil) == []
    end
  end

  describe "nada é interpretado (FR-009)" do
    test "rótulo escrito como chave:valor sai como texto" do
      rotulos = Rotulos.de(["prioridade:alta", "epic:base", "tipo:infra"], nil)

      # Nenhum deles vira campo de prioridade, elo de épico ou classificação. São três
      # cadeias de caracteres, e a plataforma não afirma nada sobre elas.
      assert Enum.map(rotulos, & &1.texto) == ["prioridade:alta", "epic:base", "tipo:infra"]
      assert Enum.all?(rotulos, &(&1.origem == :campo))
    end
  end
end
