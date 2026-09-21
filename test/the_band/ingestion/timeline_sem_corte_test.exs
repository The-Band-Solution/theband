defmodule TheBand.Ingestion.TimelineSemCorteTest do
  @moduledoc """
  A timeline não pode voltar a vir cortada em silêncio — feature 066, achado de 2026-09-15.

  ## O defeito que este teste guarda

  Dentro de `issues(first: 50)`, o GitHub devolve **10 itens** de timeline por issue e declara
  `totalCount` igual a 10, com `hasNextPage: false`. Por `issue(number:)` devolve os 19 reais.
  A guarda que existia olhava `hasNextPage` — e por isso **nunca disparou**.

  Custou 282 entregas sem data no quadro 43, 152 delas só em julho.

  ## O que se afirma aqui

  1. **a fase de issues pede 10 por página**, e não 50 — foi o valor medido em que a resposta
     vem íntegra;
  2. **a fase de repositórios continua em 50** — ela não traz timeline, e baixá-la custaria
     consultas sem ganho;
  3. **o limiar da segunda guarda existe** e é menor que a maior timeline íntegra da base, para
     errar para o lado de avisar.

  Nenhuma destas asserções chama a origem: são sobre a **decisão**, e é a decisão que
  regrediria.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ingestion.GithubWorkItems

  test "a fase de issues pede 10 por página, porque acima disso a origem corta a timeline" do
    tamanhos = GithubWorkItems.page_sizes()

    assert tamanhos["issues"] == 10,
           """
           A fase de issues voltou a pedir #{tamanhos["issues"]} por página.

           Medido em 2026-09-15 na issue #1828 do conectafapes-project, que tem 14 itens:
             page_size 50 → a origem declara totalCount 12
             page_size 25 → declara 13
             page_size 10 → declara 14

           O corte é proporcional aos nós pedidos, e a origem NÃO o sinaliza:
           `hasNextPage` vem `false`. Subir este número volta a perder eventos em silêncio.
           """
  end

  test "a fase de repositórios continua em 50 — ela não traz timeline" do
    assert GithubWorkItems.page_sizes()["repositories"] == 50
  end

  test "o limiar de suspeita é menor que a maior timeline íntegra já observada" do
    # 72 é a maior medida na base em 2026-09-15. Um limiar acima dela nunca avisaria.
    assert GithubWorkItems.limiar_de_suspeita() < 72
  end
end
