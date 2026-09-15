# A complexidade dos cards, e o que ela responde sobre quem trabalha

**Aberto em**: 2026-09-14 · **Pedido de quem usa** (Conecta Fapes), com o destino escrito no
próprio pedido: *"seria interessante padronizar/marcar a complexidade nos cards e puxar isso
para o the band de modo a identificar se o bolsista atua em demandas complexas ou somente em
fáceis (colocar isso como nova feature e colocar no backlog)"*.

## O dado já existe, e está pela metade

O quadro 43 tem o campo **`Story Points`** — seleção única com os valores `1 · 2 · 3 · 5 · 8 ·
13` —, preenchido em **229 dos 1 194** itens (2026-09-14). Os valores são **coletados crus**
desde a feature 004 e nunca interpretados.

## Por que não basta ligar

**`Story Points` é seleção única; `complexity` é numérico.** O mapeamento por tenant existente
exige `field_type: NUMBER` e mapeia um campo `Estimate`; aqui os nomes das opções **são**
números, e converter "o nome da opção parece um número" é interpretação — precisa de regra
declarada, não de palpite no código.

E a distinção que a casa já escreveu não pode ser perdida: **importância** é valor para a
organização (quem decide é o Product Owner); **complexidade** é dificuldade para o time. O campo
`Priority` do quadro **não** vira importância.

## O que a medida deve dizer, e o que não pode dizer

O pedido é *"atua em demandas complexas ou só em fáceis"*. A resposta honesta é uma
**distribuição**, nunca uma média:

- **os pontos das entregas da pessoa, por valor** — quantas de 1, de 3, de 8 — no período;
- **"não estimado" sempre escrito**: hoje seriam **965 de 1 194**. Uma média sobre 19% do dado
  responderia com confiança o que ninguém mediu;
- **nunca somar pontos entre pessoas nem entre equipes** como se fosse produtividade: pontos são
  estimativa de dificuldade, não de esforço entregue.

## Ordem

Depois da [066](../../specs/066-pronto-declarado/spec.md): "entregou" precisa da definição de
pronto declarada. Antes disso, a distribuição contaria como entregue só o que fechou na origem —
e no quadro 43 são 165 de 459 *Done*.
