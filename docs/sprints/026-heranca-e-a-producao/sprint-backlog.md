# Sprint 026 — Herança e a produção

**Período**: 2026-08-29 a 2026-09-05 — **fechado em 2026-09-01** ([review](sprint-review.md))
**Herança**: retrabalho das US [#573](https://github.com/The-Band-Solution/theband/issues/573)
e [#598](https://github.com/The-Band-Solution/theband/issues/598)
(aceitação do [sprint 025](../025-contas-e-o-elo-do-github/aceitacao.md))
**Feature**: [050-em-producao](../../specs/050-em-producao/spec.md) ·
[plan](../../specs/050-em-producao/plan.md) ·
[contrato do pipeline](../../specs/050-em-producao/contracts/pipeline-de-release.md)

## Objetivo do sprint

Primeiro a herança, na classe e não no exemplar: as frases de função-origem passam
pela borda (T014) e a busca diz organização e observação terminada (T009). Depois a
produção nasce no repositório: imagem, CD no push da `main` (Gitflow 1.7.0) e o
runbook do Dokploy — deixando o primeiro release a três marcos humanos de distância.

## Lições aplicadas

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L81 | Sprint 025 | o T014 fecha com a CAÇA AOS IRMÃOS pela forma `(erro\|ok\|error\|aviso): funcao(` — executada, zero restantes |
| L82 | Sprint 025 | o comentário que contradizia o contrato saiu, e o contrato ganhou a nota da violação com data e razão (T009) |
| L71 | Sprint 022 | os invariantes das frases (posição, unidade em passos) mudaram de veículo com o requisito — provados no catálogo |
| L60/L03/L38 | — | EXIT no log em todo gate e no CD; violações primeiro (docker run sem env, tag repetida); leituras em lote |
| L72 | Sprint 023 | a iteration 026 nasceu pela dança completa: 53 valores capturados, recriados, reatribuídos e conferidos (53/53, 0 falhas) |

## Sprint no GitHub

**Iteration**: Sprint 026 — Herança e a produção · id `46704707`
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) — 14
itens (2 tarefas de herança + 2 PRs + 3 US e 7 tarefas da 050).

## A herança — primeira da fila (entregue nesta abertura)

| # | Tarefa | Atende | Issue | PR | Estado |
|---|---|---|---|---|---|
| 047/T014 | As frases de função-origem passam pela borda | #573 | [#617](https://github.com/The-Band-Solution/theband/issues/617) | [#630](https://github.com/The-Band-Solution/theband/pull/630) | feito — mergeado em 2026-08-30 |
| 051/T009 | A busca diz a organização e a observação terminada | #598 | [#618](https://github.com/The-Band-Solution/theband/issues/618) | [#631](https://github.com/The-Band-Solution/theband/pull/631) | feito — mergeado em 2026-08-30 |
| 047/T015 | O verificador vê a classe função-origem (salto de um nó) | #573 | [#634](https://github.com/The-Band-Solution/theband/issues/634) | [#635](https://github.com/The-Band-Solution/theband/pull/635) | feito — PR aberto em 2026-08-31 |

## User stories da 050

| # | User story | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|
| US1 | A plataforma num endereço estável | [#620](https://github.com/The-Band-Solution/theband/issues/620) | P1 | 8 | 5 |
| US2 | Os dados sobrevivem | [#621](https://github.com/The-Band-Solution/theband/issues/621) | P2 | 5 | 3 |
| US3 | A produção recusa o regime de desenvolvimento | [#622](https://github.com/The-Band-Solution/theband/issues/622) | P2 | 3 | 3 |

## Tarefas da 050

| # | Tarefa | Atende | Issue | Estimate | Estado |
|---|---|---|---|---|---|
| T001 | Abrir baseline dos gates | US1 | [#623](https://github.com/The-Band-Solution/theband/issues/623) | 1 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T002 | A imagem, pela violação | US1 | [#624](https://github.com/The-Band-Solution/theband/issues/624) | 3 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T003 | O CI builda a imagem quando ela muda | US1 | [#625](https://github.com/The-Band-Solution/theband/issues/625) | 1 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T004 | O workflow de CD conforme o contrato | US1 | [#626](https://github.com/The-Band-Solution/theband/issues/626) | 3 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T005 | O runbook do Dokploy no Contabo | US1 | [#627](https://github.com/The-Band-Solution/theband/issues/627) | 3 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T006 | O ensaio de restauração, escrito para ser executado | US2 | [#628](https://github.com/The-Band-Solution/theband/issues/628) | 2 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |
| T007 | Gates verdes e PR no padrão | US2/US3 | [#629](https://github.com/The-Band-Solution/theband/issues/629) | 1 | feito — PR [#632](https://github.com/The-Band-Solution/theband/pull/632), mergeado em 2026-08-30 |

## Fora do escopo deste sprint

- **Os três marcos com pessoas** (plan §Marcos): criar o VPS na Contabo + instalar o
  Dokploy; os segredos (lista FECHADA do contrato) nos GitHub Secrets e no painel; o
  primeiro PR de release `development → main` (Product Owner, FR-016). O sprint
  deixa TUDO de repositório pronto; os marcos acontecem quando a pessoa mantenedora
  os fizer — e o primeiro release mede SC-001/002/004/005.
- **049** (depende do endereço público) e **#568** (sem spec).

## Riscos e dependências

- O passo do webhook só se prova de verdade no primeiro release — o contrato exige
  `--fail` e o ensaio documentado; até lá é dry-run/actionlint.
- bcrypt_elixir compila NIF: builder e runtime na MESMA base glibc (contrato) — o
  quickstart §2 pega divergência antes de qualquer VPS.
- Revisão pedida ao abrir nos quatro PRs do sprint; merges pela pessoa mantenedora.

## Definition of Done do sprint

- [x] quality gates verdes nas branches (L60, EXIT no log) — 14/14, `EXIT=0` em 2026-09-01
- [x] base de conhecimento válida — 120 YAML, 14 ontologias, 238 conceitos
- [ ] issues #617–#618, #620–#629 encerradas APÓS a aceitação — #617, #618 e #634
      encerradas; **#620–#629 seguem abertas**, à espera da confirmação do
      [registro de aceitação](aceitacao.md)
- [x] `sprint-review.md` escrito — [aqui](sprint-review.md)
- [x] `licoes-aprendidas.md` atualizado — L83 a L90
- [ ] PRs com revisão pedida ao abrir e no board — **NÃO cumprido**: seis dos nove
      PRs foram mergeados sem revisor pedido, e nenhum dos nove tem revisão
      registrada (L89)
