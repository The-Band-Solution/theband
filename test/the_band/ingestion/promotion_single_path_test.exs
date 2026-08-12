defmodule TheBand.Ingestion.PromotionSinglePathTest do
  @moduledoc """
  A coleta **não** promove por conta própria: ela chama o recálculo.

  ## Por que este teste existe

  A coleta tinha o seu próprio laço de promoção, montado antes de a etapa estrutural
  existir. O recálculo tinha outro, com as três etapas. Dois caminhos para a mesma decisão, e
  quem rodava por último ganhava.

  Medido no dado real: a coleta das 10h14 regravou **3451 issues como não promovidas** sobre
  o que a etapa estrutural havia decidido às 02h08. A tela passou a mostrar 77% sem conceito,
  a coleta concluiu com sucesso, e nada no log dizia por quê.

  É a terceira vez que este projeto paga por dois caminhos para uma decisão —
  `classification/2`, prévia contra recálculo, e agora coleta contra recálculo.

  O teste é **estrutural de propósito**: um teste de comportamento passaria enquanto os dois
  caminhos concordassem, e o defeito nasce justamente quando um deles muda.
  """
  use ExUnit.Case, async: true

  @coleta "lib/the_band/ingestion/github_work_items.ex"

  test "a coleta não grava promoção diretamente" do
    fonte = File.read!(@coleta)

    refute fonte =~ "record_promotion", """
    A coleta voltou a gravar promoção por conta própria.

    Ela precisa chamar `Mapping.recompute/2`, que aplica as três etapas — tipo declarado,
    título e estrutura —, grava só o que mudou, e é o mesmo caminho que a tela de regras usa.

    Um laço próprio aqui reintroduz o defeito que custou 3451 issues: a coleta sobrescreve
    com "não promovida" o que a etapa estrutural decidiu, porque ela não conhece essa etapa.
    """
  end

  test "a coleta chama o recálculo" do
    fonte = File.read!(@coleta)

    assert fonte =~ "Mapping.recompute", """
    A coleta deixou de chamar o recálculo. Sem ele, as issues coletadas ficam sem conceito
    até alguém abrir a tela de regras e disparar o recálculo à mão.
    """
  end

  test "a coleta não monta decisão por conta própria" do
    fonte = File.read!(@coleta)

    # O parêntese é o que distingue **chamada** de menção: o moduledoc daquele arquivo
    # cita `WorkItems.decide/2` para contar por que o laço saiu, e casar a palavra solta
    # reprovaria a explicação junto com o defeito.
    refute fonte =~ "WorkItems.decide(", """
    A coleta voltou a montar a decisão. `Mapping.Decision` é o único lugar que sabe a ordem
    das três etapas, e duplicar a montagem aqui faz a coleta decidir diferente da tela.
    """
  end
end
