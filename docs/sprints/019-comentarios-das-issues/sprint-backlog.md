# Sprint 019 — Os comentários das issues, e a participação nas discussões

**Período**: 2026-08-17 a 2026-08-31
**Feature**: [030](../../specs/030-comentarios-das-issues/spec.md)
**Plano**: [plan.md](../../specs/030-comentarios-das-issues/plan.md)

## Objetivo do sprint

A conversa das issues vira dado da plataforma: coletada como nota (cmo.comment),
lida como discussão e participação (derivadas), e visível em três lugares — o detalhe
da issue, o anti-padrão da parada (que ganha resolução tripla) e a página da pessoa.

## A decisão que abriu o sprint

**A CMO existe.** A rede não tinha conceito para comentário (#318); a pessoa mantenedora
decidiu estender o continuum (2026-08-17) em vez de achatar comentário em
`spo.information_item`. Ontologia, módulo, competency questions e o mapeamento
`github.issue_comment.to.cmo.comment` já estão escritos e validados pela base — o
sprint começa com a Phase 0 feita.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md):

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L25 | Sprint ~010 | identidade do comentário por external_id, natural_key com repositório e issue — número sozinho não identifica |
| L26 | Sprint ~010 | casamento estreito nos envelopes da ingestão; lista vazia com totalCount > 0 é erro, nunca sucesso |
| L29 | Sprint ~012 | falha transitória na fase de comentários não marca estado permanente — a próxima coleta tenta de novo |
| L30/L35 | Sprint ~012 | SC-001 é conferência contra a API por amostra, não suíte verde |
| L47 | Sprint 017 | a fase de comentários lê issues da BASE, não da memória da fase anterior — issue nova com comentário entra na mesma passada |
| L48 | Sprint 017 | closing keywords em inglês nos commits; conferência pós-merge |

E a oitava do sucesso silencioso (rodada muda, 2026-08-17, ainda sem número de lição):
`totalCount` na consulta e cobertura registrada na fase existem exatamente para
truncamento nunca ser silêncio.

## Sprint no GitHub

**Limitação registrada**: sem iteration criada para este sprint no Projects v2 — as
issues estão criadas e tipáveis, e a atribuição à iteration fica como pendência para a
pessoa mantenedora (criar iterations é mudança de configuração da organização).

## User stories selecionadas

| # | User story | Issue | Critérios |
|---|---|---|---|
| US1 | ver a discussão da issue na plataforma | [#411](https://github.com/The-Band-Solution/theband/issues/411) | FR-001/002/003/007/008, SC-001 |
| US2 | parada em silêncio ≠ parada com discussão | [#412](https://github.com/The-Band-Solution/theband/issues/412) | FR-004, SC-002 |
| US3 | participação como evidência na pessoa | [#413](https://github.com/The-Band-Solution/theband/issues/413) | FR-005/006, SC-003/004 |

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T000 | CMO + mapeamento, validados | decisão | — (feita na abertura) | feito |
| T001 | migração | US1 | [#417](https://github.com/The-Band-Solution/theband/issues/417) | feito |
| T002 | schema Ecto + upsert | US1 | [#418](https://github.com/The-Band-Solution/theband/issues/418) | feito |
| T003 | consulta GraphQL | US1 | [#424](https://github.com/The-Band-Solution/theband/issues/424) | feito |
| T004 | ingestão incremental | US1 | [#419](https://github.com/The-Band-Solution/theband/issues/419) | feito |
| T005 | fase de sync | US1 | [#420](https://github.com/The-Band-Solution/theband/issues/420) | feito |
| T006 | coleta real, totais contra a API | US1 | [#414](https://github.com/The-Band-Solution/theband/issues/414) | feito |
| T007 | Discussions (leitura) | todas | [#421](https://github.com/The-Band-Solution/theband/issues/421) | feito |
| T008 | discussão no detalhe da issue | US1 | [#415](https://github.com/The-Band-Solution/theband/issues/415) | feito |
| T009 | anti-padrão com resolução tripla | US2 | [#416](https://github.com/The-Band-Solution/theband/issues/416) | feito |
| T010 | participação na página da pessoa | US3 | [#422](https://github.com/The-Band-Solution/theband/issues/422) | feito |
| T011 | verificação ao vivo | US2/US3 | [#423](https://github.com/The-Band-Solution/theband/issues/423) | feito |

## Os critérios de sucesso, com a evidência

| # | critério | evidência |
|---|---|---|
| SC-001 | coleta termina e bate com a origem | **2.013 comentários**, 5.116 issues visitadas, 160 repositórios, 0 truncado, 0 inalcançável, 259s. A issue 645 conferida contra a API viva: 3 comentários lá, 3 aqui, mesmos autores e instantes. A diferença com `comment_count` (2.008) é o campo ser do momento da coleta das issues — o coletado bate com a origem de **agora**. |
| SC-002 | issue parada real rotulada | AndréCoelho: duas paradas de 419d como `silent` ("nobody has commented on it — decide whether it dies or comes back") e uma de 104d como `stale discussion` ("1 comment(s), none since 2026-05-18 — discussed, then left"). Antes, três linhas idênticas. |
| SC-003 | no_assignment com participação | **7 das 24** pessoas sem designação alguma trabalham na conversa: `lucasbruno-devdog` com **72 atos em 50 discussões**, `dnribeiro` com 17 em 13, mais `0xdeadbad`, `oliverids`, `sofiasilv4`, `ogianpaneto`, `JoelHanerth`. Eram invisíveis na plataforma. |
| SC-004 | número fixo de consultas | `last_act_for_issues/2`: 1 consulta para 8 issues. `for_issue/2`: 1 consulta com 1 ou com 20 comentários. O detalhe da issue passou de 39 para **40** consultas por render — uma fixa, e o teto do teste-guarda foi atualizado com a razão escrita. |

## Fora do escopo deste sprint

Review threads de PR, reações, menções como relação, e o uso da participação no
material do perfil (decisão separada da pessoa mantenedora) — todos declarados na spec
e no mapeamento.

## Definition of Done do sprint

- [ ] quality gates verdes (`mix gates`)
- [ ] base de conhecimento válida (a CMO já passa)
- [ ] SC-001 a SC-004 verificados no tenant real, com evidência
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
