# Sprint 017 — Quadros, campos e backlogs

**Período**: 2026-08-16 em diante
**Feature**: [004](../../../specs/004-issues-e-projetos/spec.md), fase F7 (convergência da F4)
**Plano**: [plan.md](../../../specs/004-issues-e-projetos/plan.md)

## Objetivo do sprint

A plataforma passa a enxergar os quadros inteiros — entidade, campos e valores por item —
e a derivar os dois backlogs; e a decisão de excluir um repositório ganha o caminho na
tela que faltava desde a 004.

## De onde este sprint veio

A F4 da feature 004 ficou especificada e não implementada; a feature 024 entregou as
iterações por caminho próprio (`sro_sprints`, 220 iterações, 2225 vínculos). A
convergência de 2026-08-16 mediu a spec contra o código e escreveu as onze tarefas que
faltam — **reconciliando, nunca refazendo**: a promoção iteração-iniciada→sprint, a
identidade `campo:iteração` e a idempotência da 024 ficam.

O que isto fecha e destrava: fecha [#181](https://github.com/The-Band-Solution/theband/issues/181)
e [#107](https://github.com/The-Band-Solution/theband/issues/107); destrava
[#180](https://github.com/The-Band-Solution/theband/issues/180) (mapear campo→atributo),
[#317](https://github.com/The-Band-Solution/theband/issues/317) (sugerir papel) e a
pergunta do Conecta Fapes sobre o que é *done*
([#367](https://github.com/The-Band-Solution/theband/issues/367)), que depende do campo
`Status` — hoje não coletado.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md):

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L11** | Sprint 002 | configurar iterations **recria as existentes** e custou reatribuir 96 itens. Este sprint **não cria iteration** — coleta é leitura; a limitação da iteration própria fica declarada abaixo |
| **L19** | Sprint 003 | a marca de ausência da T053 é **por quadro observado na execução**, nunca por tenant — marcar por tenant atingiria caixas que a execução não olhou |
| **L26** | Sprint 006 | organização sem quadros (T055) é **resposta**, nunca lista vazia silenciosa |
| **L57** | Sprint 015 | as tabelas novas nascem com consumidor no mesmo sprint (T057 é a tela) — tipo que ninguém produz e verificação que ninguém alcança são o mesmo defeito |
| **L59/L60** | Sprint 015/016 | gates sempre por `mix gates > log; ec=$?; exit $ec` — nunca pipe, nunca `echo EXIT=$?` em background |

## Sprint no GitHub

**Iteration**: **não criada, e é decisão** — a L11 registra que configurar iterations do
ProjectV2 recria as existentes. O projeto tem uma única iteration (`Sprint 002`), e criar
a do 017 arriscaria reatribuir tudo de novo. As issues entram no board com `Status: Ready`
e sem iteration; a [#176](https://github.com/The-Band-Solution/theband/issues/176) é a
decisão pendente sobre esse custo.
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)
**Tipos**: `Epic` e `User Story` não existem na organização; criá-los altera configuração
da org e espera confirmação da pessoa mantenedora. As tarefas são `Task`, filhas das user
stories por sub-issue — a hierarquia carrega o que o tipo não diz.

## User stories selecionadas

| # | User story | Tipo | Issue | Priority | Critérios |
|---|---|---|---|---|---|
| US2 (004) | Enxergar os quadros e o que cada item carrega | sem tipo próprio | [#107](https://github.com/The-Band-Solution/theband/issues/107) | P2 | FR-020…FR-032b, SC-008, SC-009\* |
| US3 (004) | Restringir quais repositórios são observados | sem tipo próprio | [#108](https://github.com/The-Band-Solution/theband/issues/108) | P3 | FR-005, FR-006 |

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T047 | A entidade de quadro, sem promover | US2 | [#373](https://github.com/The-Band-Solution/theband/issues/373) | feito |
| T048 | As definições dos campos configuráveis | US2 | [#374](https://github.com/The-Band-Solution/theband/issues/374) | feito |
| T049 | Os itens de cada quadro, ligados às issues | US2 | [#375](https://github.com/The-Band-Solution/theband/issues/375) | feito |
| T050 | O rascunho é registrado, não descartado | US2 | [#376](https://github.com/The-Band-Solution/theband/issues/376) | feito |
| T051 | O valor de cada campo em cada item | US2 | [#377](https://github.com/The-Band-Solution/theband/issues/377) | feito |
| T052 | Iteração futura vira processo pretendido | US2 | [#378](https://github.com/The-Band-Solution/theband/issues/378) | feito |
| T053 | O sprint removido é marcado, nunca apagado | US2 | [#379](https://github.com/The-Band-Solution/theband/issues/379) | feito |
| T054 | Os dois backlogs derivados, e a soma prova | US2 | [#380](https://github.com/The-Band-Solution/theband/issues/380) | feito |
| T055 | Organização sem quadros é resposta | US2 | [#381](https://github.com/The-Band-Solution/theband/issues/381) | feito |
| T056 | As consultas GraphQL alargadas | US2 | [#382](https://github.com/The-Band-Solution/theband/issues/382) | feito |
| T057 | A tela de quadros e backlogs | US2 | [#383](https://github.com/The-Band-Solution/theband/issues/383) | feito |
| T058 | O controle de excluir repositório na tela | US3 | [#384](https://github.com/The-Band-Solution/theband/issues/384) | feito |

Tarefa não recebe `Priority`: herda a da user story que atende. `Estimate` fica em branco
— desconhecido, nunca zero.

## Fora do escopo deste sprint

| O quê | Issue | Por quê |
|---|---|---|
| Mapear campo de quadro para atributo da ontologia (US3 da F6, T041–T044) | [#180](https://github.com/The-Band-Solution/theband/issues/180) | depende de os campos **existirem** — T048 e T051 são o pré-requisito. Entra no sprint seguinte |
| Sugerir papel a partir de evidência | [#317](https://github.com/The-Band-Solution/theband/issues/317) | funcionalidade nova, destravada mas não puxada |
| Competência como unidade do perfil | [#363](https://github.com/The-Band-Solution/theband/issues/363)/[#364](https://github.com/The-Band-Solution/theband/issues/364) | funcionalidade nova — decisão da pessoa mantenedora: *depois* |

## Riscos e dependências

| Risco | Por quê | O que fazer |
|---|---|---|
| **Volume dos itens** | o DevOps tem 677 itens em 7 páginas; agora vêm com valores de campo — a resposta cresce | paginação já existe; o custo real aparece na primeira coleta e vira medição |
| **Migrar `sro_sprints` para apontar ao quadro** | 220 iterações vivas; errar a ligação perde os 2225 vínculos | a migração liga por `board_number` + organização, e o gate de reprodutibilidade roda antes e depois |
| **Revisão independente** | os quatro PRs de 2026-08-16 entraram sem revisão humana | pedir à equipe `the-band` ao abrir, conferir `reviewRequests`, e **declarar** a lacuna se persistir |

## Definition of Done do sprint

- [ ] as 12 issues fechadas, ou repriorizadas com justificativa escrita
- [ ] `mix gates` com código de saída 0 — `> log; ec=$?; exit $ec`, nunca pipe
- [ ] SC-009b provado por teste: product + sprints = total de itens
- [ ] coleta real executada e medida (o quadro The Band tem 17 campos e 107 itens)
- [ ] PR com revisor pedido à equipe `the-band`, pedido **conferido**
- [ ] `sprint-review.md` escrito, separando entregue de não entregue
- [ ] `licoes-aprendidas.md` atualizado
- [ ] a lacuna da revisão independente **declarada**, se persistir
