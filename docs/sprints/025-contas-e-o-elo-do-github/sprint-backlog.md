# Sprint 025 — Contas e o elo do GitHub

**Período**: 2026-08-29 a 2026-09-05
**Herança**: retrabalho das US1/US2 da 047 (recusadas na
[aceitação do sprint 024](../024-mensagens-e-o-botao-da-chave/aceitacao.md))
**Feature nova**: [051-cadastro-por-github](../../specs/051-cadastro-por-github/spec.md)
**Plano**: [051/plan.md](../../specs/051-cadastro-por-github/plan.md)

## Objetivo do sprint

Primeiro a herança: a classe "assign de mensagem renderizado" entra no catálogo e no
verificador, fechando de verdade as US1/US2 da 047. Depois a 051: `/accounts` vira a
área única do onboarding — cadastrar a pessoa (nome, e-mail, temporária no ato) e
associar a conta do GitHub ali, pela identidade estável.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md):

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L80 | Sprint 024 | o retrabalho amplia o verificador POR AST e refaz as pendências com amostragem independente — nunca o grep validando a si mesmo |
| L76 | Sprint 024 | a classe assign se conta por AST antes de dimensionar (T012) |
| L77 | Sprint 024 | o verificador ampliado ganha teste de ponta que não passa por ele |
| L60/L03/L38/L71 | — | as de sempre: EXIT no log; violação primeiro; leitura por join, nunca por linha; testes do requisito que muda mapeados no plano da 051 |
| L72 refinada | Sprint 025 (abertura) | a iteration 025 foi criada reenviando as ativas; os 15 valores da 022 se perderam de forma irrecuperável — registro de pertença é o backlog no repositório |
| L79 | Sprint 024 | agente de aceitação com ordem explícita de não trocar branch |

## Sprint no GitHub

**Iteration**: Sprint 025 — Contas e o elo do GitHub · id `23bb051e`
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) —
12 itens (10 da 051 + 2 do retrabalho), Estimate/Priority preenchidos.

**Limitação registrada (L72 refinada)**: os itens do Sprint 022 perderam o valor de
iteration quando a lista ativa foi recriada — a API recusa reatribuir a iteration
completada. A pertença deles está no sprint-backlog da 022.

## A herança — primeira da fila

| # | Tarefa | Atende | Issue | Estimate | Estado |
|---|---|---|---|---|---|
| 047/T012 | A classe assign entra no catálogo e no verificador | 047/US1+US2 (#573, #574) | [#609](https://github.com/The-Band-Solution/theband/issues/609) | 3 | a fazer |
| 047/T013 | Pendências com amostragem independente, e o texto da US3 | 047/US2+US3 | [#610](https://github.com/The-Band-Solution/theband/issues/610) | 2 | a fazer |

## User stories da 051

| # | User story | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|
| US1 | Cadastrar a pessoa: nome e e-mail | [#597](https://github.com/The-Band-Solution/theband/issues/597) | P1 | 3 | 3 |
| US2 | Associar a conta do GitHub, na mesma área | [#598](https://github.com/The-Band-Solution/theband/issues/598) | P1 | 5 | 5 |

## Tarefas da 051

| # | Tarefa | Atende | Issue | Estimate | Estado |
|---|---|---|---|---|---|
| T001 | Abrir baseline dos gates | US1 | [#599](https://github.com/The-Band-Solution/theband/issues/599) | 1 | a fazer |
| T002 | O cadastro transacional com temporária, pela violação | US1 | [#600](https://github.com/The-Band-Solution/theband/issues/600) | 2 | a fazer |
| T003 | A leitura estreita do conflito | US2 | [#601](https://github.com/The-Band-Solution/theband/issues/601) | 1 | a fazer |
| T004 | O cadastro na tela, com a temporária de uma vez | US1 | [#602](https://github.com/The-Band-Solution/theband/issues/602) | 2 | a fazer |
| T005 | A lista diz quem tem GitHub, numa consulta | US2 | [#603](https://github.com/The-Band-Solution/theband/issues/603) | 2 | a fazer |
| T006 | Associar com busca, e o conflito nomeado | US2 | [#604](https://github.com/The-Band-Solution/theband/issues/604) | 3 | a fazer |
| T007 | Revogar na área, e o login acompanha | US2 | [#605](https://github.com/The-Band-Solution/theband/issues/605) | 2 | a fazer |
| T008 | Gates verdes e PR no padrão | US2 | [#606](https://github.com/The-Band-Solution/theband/issues/606) | 1 | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

## Fora do escopo deste sprint

- **050 (produção)** — adiada por decisão; **049** depende dela; **#568** sem spec.
- Queima das demais telas de `pendencias.md` (a refeita do T013) — sprints futuros.
- Tradução pt completa — lacunas visíveis pelo relatório.

## Riscos e dependências

- O retrabalho amplia o verificador: o gate pode nascer vermelho de novo se a
  varredura da classe assign achar mais que as ~9 mapeadas — o número certo sai do
  AST (L76), e o dimensionamento aceita crescer.
- Ordem declarada: retrabalho (PR próprio) ANTES da 051 — os dois tocam telas
  distintas, mas o verificador ampliado precisa valer para o código novo da 051.
- Revisão ANTES do merge desta vez — a violação do 024 não se repete: os PRs deste
  sprint pedem revisão ao abrir.

## Definition of Done do sprint

- [ ] quality gates verdes nas branches (forma L60, EXIT no log)
- [ ] base de conhecimento válida
- [ ] issues #597–#606, #609–#610 encerradas APÓS a aceitação (ordem certa desta vez)
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] PRs com revisão pedida ao abrir, e dentro do board do projeto
