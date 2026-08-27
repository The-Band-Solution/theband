defmodule TheBand.Quality.VerdictTest do
  @moduledoc """
  A tradução do estado da revisão para o conceito da rede — feature 044, T001 e T002.

  ## As asserções que carregam este arquivo

  1. **o mapa vem da BASE, e não do código.** É a asserção mais importante: um mapa
     reescrito em Elixir viraria segunda cópia, e duas cópias divergem no dia em que
     alguém mudar uma só;
  2. **`DISMISSED` e `PENDING` NÃO são veredito.** Contá-los faria "quantas objeções
     houve" incluir rascunho não submetido e posição retirada de circulação;
  3. **valor fora do mapa devolve ERRO.** `unmapped: reject` está declarado, e traduzir o
     desconhecido para o mais plausível é o erro que cai para o lado barato;
  4. **nenhum rótulo repete o enum do GitHub.** A página nomeia pelo conceito da rede.
  """
  use ExUnit.Case, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Quality.Verdict

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  describe "as três posições" do
    test "cada estado de posição devolve o conceito da rede" do
      assert Verdict.traduzir("APPROVED") == {:veredito, "qapo.endorsing_verdict"}
      assert Verdict.traduzir("CHANGES_REQUESTED") == {:veredito, "qapo.objecting_verdict"}
      assert Verdict.traduzir("COMMENTED") == {:veredito, "qapo.abstaining_verdict"}
    end

    test "os três conceitos existem na rede", _ do
      for {_, conceito} <-
            Enum.map(
              ~w(APPROVED CHANGES_REQUESTED COMMENTED),
              &Verdict.traduzir/1
            ) do
        assert KnowledgeBase.concept?(conceito), """
        `#{conceito}` não existe na base de conhecimento.

        O `value_map` aponta para um conceito, e apontar para conceito inexistente faria a
        tradução produzir um identificador que nenhuma tela sabe nomear — e o validador da
        base não o alcança, porque ele valida um arquivo por vez.
        """
      end
    end
  end

  describe "o que NÃO é veredito" do
    test "`DISMISSED` é ciclo de vida, e não posição" do
      assert Verdict.traduzir("DISMISSED") == {:ciclo_de_vida, :retirada}
    end

    test "`PENDING` é ciclo de vida, e não posição" do
      assert Verdict.traduzir("PENDING") == {:ciclo_de_vida, :nao_submetida}
    end

    test "os dois ficam FORA da lista de estados de veredito" do
      estados = Verdict.estados_de_veredito()

      refute "DISMISSED" in estados, """
      `DISMISSED` entrou na lista que a consulta usa para filtrar vereditos.

      São 52 no banco de desenvolvimento. Incluí-las faria "quantas objeções houve" contar
      posição que alguém tirou de circulação de propósito.
      """

      refute "PENDING" in estados
      assert Enum.sort(estados) == ["APPROVED", "CHANGES_REQUESTED", "COMMENTED"]
    end
  end

  describe "valor que o mapa não traduz" do
    test "devolve erro, e não o conceito mais plausível" do
      assert Verdict.traduzir("SOMETHING_NEW") == {:error, :nao_mapeado}, """
      Um estado desconhecido foi traduzido.

      `unmapped: reject` está declarado no mapeamento. Escolher o mais plausível é o erro
      que cai para o lado barato: o não reconhecido alguém corrige, o reconhecido errado
      vira medida e ninguém volta para conferir.
      """
    end

    test "nulo também devolve erro" do
      assert Verdict.traduzir(nil) == {:error, :nao_mapeado}
    end
  end

  describe "os rótulos da interface" do
    test "nomeiam pelo conceito, e nunca pelo enum do GitHub" do
      rotulos =
        Enum.map(
          ~w(qapo.endorsing_verdict qapo.objecting_verdict qapo.abstaining_verdict),
          &Verdict.rotulo/1
        )

      assert rotulos == ["endorsed", "objected", "abstained"]

      for r <- rotulos do
        refute r =~ "APPROVED"
        refute r =~ "CHANGES_REQUESTED"
        refute r =~ "COMMENTED"
      end
    end

    test "nenhum rótulo afirma ausência de problema" do
      rotulo = Verdict.rotulo("qapo.endorsing_verdict")

      refute rotulo =~ ~r/no issue|sem problema|clean|conform/i, """
      O rótulo do endosso afirma ausência de problema.

      A própria rede declara o contrário: `qapo.artifact_evaluation_identified_noncompliance`
      tem `many` no destino porque INCLUI zero e não o exige — aprovar é ausência de
      bloqueio, e não ausência de não conformidade.
      """
    end
  end
end
