# Cards arquivados, itens que somem do quadro, e duplicatas

**Aberto em**: 2026-09-14 · **Pedido de quem usa** (Conecta Fapes): *"algumas issues relativas
[a uma pessoa] são do ano passado, precisei recriar alguns cards devido ao processo de
refatoração… pediram para arquivar apenas, isso impactou na métrica dele de certa forma"*.

## A preocupação, medida — e ela não se confirma como impacto de métrica

**Arquivar card não afeta medida nenhuma da plataforma**: a plataforma conta por **issue +
responsável**, não por card de quadro. E a API devolveu **zero** itens arquivados nos oito
quadros da organização em 2026-09-14.

Das 113 issues da pessoa, **57 estão fora do quadro 43** — e **55 delas estão fechadas**. Elas
contam como entrega de 2025, que é o correto. **Zero duplicatas por título** entre as 113.

**O que se confirma é outra coisa**: no repositório inteiro há **52 grupos de título repetido**,
**128 issues**, das quais **41 em grupos com duas ou mais abertas**. Essas contam duas vezes na
carga de quem as tem.

## O que fazer, e o que não fazer

**Duplicata é `stateReason = DUPLICATE`** — decisão da pessoa mantenedora em 2026-09-14 —, e
**nunca título igual**. Títulos como *"Round 1 - aprovado"* (11 vezes) são trabalho repetido de
verdade, não duplicata; casar por título inventaria.

| o que | por quê |
|---|---|
| coletar `isArchived` dos itens de quadro | hoje não é pedido nem guardado; o dia em que a API devolver arquivados junto, eles entram como itens normais |
| marcar item que **sumiu** do quadro | `project_items.no_longer_observed_at` **existe e nunca é preenchida** — não há equivalente ao que a coleta já faz com iterações e vínculos |
| issue com `stateReason = DUPLICATE` fora da carga da pessoa | por regra declarada, com o original nomeado quando a origem o disser |
| issue fechada como `NOT_PLANNED` | **à parte**, dita — nem entrega nem pendência |

## Tamanho

Pequeno, e independente das specs 066/067. O `stateReason` **já é coletado** e já aparece no
detalhe (*"closed · not planned"*); falta usá-lo nas contagens.
