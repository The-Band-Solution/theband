defmodule TheBand.Ingestion.VersaoDaConsultaTest do
  @moduledoc """
  A consulta que mudou não é a mesma consulta — issue #452.

  ## O defeito, medido

  A feature 041 acrescentou `statusCheckRollup` à consulta de solicitações. Duas semanas
  depois havia **763 solicitações em 10 repositórios** sem o campo — **100% em cada um dos
  dez**. Repositório inteiro sem o campo é repositório não tocado desde que o campo existe.

  Nenhum erro. A tela dizia *"não dá para saber"* sobre dado que a origem responde
  perfeitamente, e ninguém ligou a lacuna à mudança que a criou.

  ## O caso que mais importa

  `a impressão digital de cada consulta é a declarada` — ele reprova quando alguém muda um
  `.graphql` sem decidir o que fazer com o já coletado. É a **prevenção**, e é o único
  caso deste arquivo que vale para consultas cujas fases ainda não têm remédio automático.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ingestion.QueryVersion

  describe "a prevenção — vale para TODA consulta" do
    test "a impressão digital de cada consulta é a declarada" do
      for nome <- QueryVersion.arquivos() do
        declarada = Map.get(QueryVersion.impressoes(), nome)
        atual = QueryVersion.impressao_de(nome)

        assert declarada == atual, """
        **`#{nome}.graphql` mudou, e ninguém decidiu o que fazer com o já coletado.**

            declarada: #{inspect(declarada)}
            atual:     #{atual}

        Duas saídas, e escolher é o ponto desta issue:

        1. **a mudança acrescenta campo** — incremente a versão da fase em `@versoes` E
           atualize a impressão. A coleta reabre o corte uma vez por repositório, e o
           histórico é repaginado com a consulta nova;

        2. **a mudança não acrescenta campo** — reformatar, renomear alias, comentar — só
           atualize a impressão. Reabrir a coleta por isso repaginaria o histórico sem
           motivo.

        Escolher a 2 quando era a 1 recria o defeito da #452: 763 registros sem o campo, em
        silêncio.
        """
      end
    end

    test "toda consulta no disco tem impressão declarada, e vice-versa" do
      no_disco = MapSet.new(QueryVersion.arquivos())
      declaradas = MapSet.new(Map.keys(QueryVersion.impressoes()))

      assert MapSet.difference(no_disco, declaradas) |> MapSet.to_list() == [], """
      **Consulta nova sem impressão declarada nasce fora da vigilância** — e a próxima
      mudança nela volta a ser silenciosa, que é exatamente o defeito.
      """

      assert MapSet.difference(declaradas, no_disco) |> MapSet.to_list() == [], """
      Impressão declarada para arquivo que não existe mais. Sobra que ninguém remove vira
      ruído, e ruído faz o teste parar de ser lido.
      """
    end
  end

  describe "o remédio — a versão reabre o corte uma vez" do
    test "versão gravada IGUAL à atual: o corte vale" do
      atual = QueryVersion.atual("changes")
      assert QueryVersion.corte_vale?(%{"changes" => atual}, "changes")
    end

    test "versão gravada MENOR: o corte é ignorado" do
      atual = QueryVersion.atual("changes")

      refute QueryVersion.corte_vale?(%{"changes" => atual - 1}, "changes"), """
      **É este ramo que conserta a #452.** O repositório percorrido com a consulta antiga
      precisa repaginar o histórico uma vez; sem isso, o registro anterior ao corte fica
      sem o campo novo para sempre.
      """
    end

    test "mapa vazio: o corte é ignorado" do
      refute QueryVersion.corte_vale?(%{}, "changes"), """
      Repositório coletado antes de a versão existir. **Não saber com que versão foi
      percorrido é o mesmo risco que saber que foi com uma antiga** — e presumir a atual
      inventaria o passado ao contrário, deixando de fora justamente quem o defeito atingiu.
      """

      refute QueryVersion.corte_vale?(nil, "changes")
    end

    test "outra fase não é afetada pela versão desta" do
      atual = QueryVersion.atual("comments")

      assert QueryVersion.corte_vale?(
               %{"changes" => 1, "comments" => atual},
               "comments"
             ),
             """
             As fases são independentes. Acrescentar campo na consulta de solicitações não
             pode repaginar os comentários — seria repaginar o histórico inteiro a cada
             mudança de qualquer consulta, e o corte deixaria de servir para o que existe.
             """
    end

    test "marcar grava a versão atual sem apagar as outras" do
      versoes = QueryVersion.marcar(%{"comments" => 1}, "changes")

      assert versoes["changes"] == QueryVersion.atual("changes")
      assert versoes["comments"] == 1, "a fase que não foi percorrida não perde a versão"
    end

    test "fase sem remédio automático falha alto, e não devolve um padrão" do
      assert_raise KeyError, fn -> QueryVersion.atual("verifications") end

      refute "verifications" in QueryVersion.fases(), """
      **`verifications` sai de REST, e não de arquivo `.graphql`.** Não há o que vigiar por
      impressão digital ali, e devolver uma versão padrão faria a fase parecer coberta.

      Falhar alto é o que mantém a limitação visível — está escrita no `@moduledoc`, junto
      com `issues`, `branches` e a coluna morta `reviews_collected_at`.
      """
    end
  end
end
