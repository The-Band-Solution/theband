# Sprint 014 — o design system

**Período**: 2026-08-13 · **Features**: [016 migalha](../../../specs/016-migalha-de-pao/spec.md) · [017 tabela](../../../specs/017-tabela-que-busca-ordena-e-pagina/spec.md)
**Origem**: [#285](https://github.com/The-Band-Solution/theband/issues/285) e [#289](https://github.com/The-Band-Solution/theband/issues/289)

## Objetivo

As telas passam a dizer **onde a pessoa está** e a deixá-la **achar a linha** sem varrer a lista.

## A decisão de base veio de protótipo

A #289 começou com uma pergunta — *"existe algum framework tipo o NuxtUI para o Phoenix?"* — e
terminou com três protótipos funcionais da mesma tabela, com os mesmos 34 dados reais, usados lado a
lado. **Componente próprio**, decidido depois de usar.

| Recusado | Por quê |
|---|---|
| Petal | segundo vocabulário de classe ao lado do daisyUI |
| Backpex | vira dono da tela, e estas telas dizem o que a plataforma **recusa afirmar** |

## Lições aplicadas

| Lição | Como |
|---|---|
| **L21** | componente sem consumidor não é entrega: as duas features mexem em tela no mesmo sprint |
| **L28** | "a consulta ordena" e "a tela ordena" são afirmações diferentes — cada uma tem teste |
| **L30** | os números vêm da medida: 6,8 ms para contar, 14,2 ms para ordenar por derivada |
| **L42** | o contador de consultas exclui o Oban |
| **L49** | medir a cauda: a lista do repositório maior tem 2 514 linhas |
| **L52** | **uma feature por branch** — e ela cobrou de novo neste sprint |
| **L53** | teto de teste vem da medida dos dois lados |

## Escopo

| # | Feature | Estado |
|---|---|---|
| 016 | migalha de pão | **entregue** — PR #291, mergeado |
| 017 | tabela que busca, ordena e pagina | **entregue** — com dois cortes declarados |

## Os cortes declarados da 017

| O que | Por quê | Destino |
|---|---|---|
| estado na URL | exige `handle_params` e compor com o filtro que já usa `push_patch` | [#292](https://github.com/The-Band-Solution/theband/issues/292) |
| as tabelas menores | 12 linhas e 4 529 não pedem a mesma solução | quando alguém precisar procurar nelas |
| 360 px | asserção em markup não substitui olhar | `RETOMAR.md` |

## Definition of Done

- [x] `mix gates` verde por código de saída — **12 gates**
- [x] aceitação das duas, critério a critério
- [ ] `sprint-review.md`
- [ ] lições atualizadas
