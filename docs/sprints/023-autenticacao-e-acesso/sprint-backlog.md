# Sprint 023 — Autenticação e acesso

**Período**: 2026-08-28 a 2026-09-04
**Feature**: [045-autenticacao-e-acesso](../../specs/045-autenticacao-e-acesso/spec.md)
**Plano**: [plan.md](../../specs/045-autenticacao-e-acesso/plan.md)

## Objetivo do sprint

A plataforma ganha porta e gradação: entrar exige e-mail ou usuário do GitHub com
senha; a visão é a união dos escopos — person no piso, team/project derivados ou
concedidos, organization concedido — administrar deixa de ser ver; e Syncs/Tools/AI
só existem para quem administra ou responde por uma organização. O axioma:
**a pessoa tem acesso aos dados com os quais está relacionada.**

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L60 | Sprint 016/022 | forma completa em T001/T014: `mix gates > log 2>&1; echo "EXIT=$?" >> log` — veredito DENTRO do log |
| L71 | Sprint 022 | busca dirigida feita no plan ("Busca dirigida — testes do requisito antigo"): 4 invariantes revogados mapeados a destino antes do código |
| L03 | Sprint 001 | todo teste de segurança começa pela violação: username ambíguo, elo revogado, sessão morta, vazamento entre tenants, org A vendo ferramenta da org B |
| L38 | Sprint 009 | `Access.scopes/2` em passadas fixas por coleção; contrato proíbe consulta-por-linha |
| L61 | Sprint 021 | limitações viram ramo: conta sem senha recusa com orientação; derivado fecha com o fato |
| Contrato antes (memória/constituição VI) | — | `contracts/auth.md` e `contracts/access-scopes.md` escritos antes de T004/T005 |
| Baseline limpo (022) | Sprint 022 | T001 exige a run dos gates TERMINADA antes de qualquer edição |

## Sprint no GitHub

**Iteration**: Sprint 023 — Autenticação e acesso · 2026-08-29 · 7 dias (id `a61c4aa5`)
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Incidente registrado**: ao criar a iteration, a mutação
`updateProjectV2Field.iterationConfiguration` substituiu a lista ativa inteira e
apagou a iteration do Sprint 022 — os 15 itens dele ficaram sem Iteration. Reparo na
hora: as duas iterations recriadas (022 com a duração real de 1 dia) e os 15 itens
reatribuídos, conferidos por consulta. A lição vai para o fechamento deste sprint:
**a lista de iterations é substituída por inteiro; sempre reenviar as vigentes**.

**Limitações herdadas**: tipos `Epic`/`User Story` seguem inexistentes na organização
(criar exige aval); hierarquia por sub-issues não é usada — tarefa referencia a US no
corpo.

## User stories selecionadas

| # | User story | Tipo | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|---|
| US1 | Entrar com e-mail ou usuário do GitHub, e sair | (sem tipo — limitação) | — | [#545](https://github.com/The-Band-Solution/theband/issues/545) | P1 | 8 | 8 |
| US2 | Escopos de acesso acumulativos | (sem tipo) | — | [#546](https://github.com/The-Band-Solution/theband/issues/546) | P1 | 8 | 11 |
| US3 | Configurar o próprio perfil | (sem tipo) | — | [#547](https://github.com/The-Band-Solution/theband/issues/547) | P2 | 3 | 5 |

`Priority` é a *importance* da SRO; `Estimate` é a *complexity*. Em branco =
desconhecido, não zero.

## Tarefas

| # | Tarefa | Atende | Tipo | Issue | Estimate | Estado |
|---|---|---|---|---|---|---|
| T001 | Abrir branch e registrar baseline dos gates | US1 | Task | [#548](https://github.com/The-Band-Solution/theband/issues/548) | 1 | feito |
| T002 | Dependência bcrypt_elixir com justificativa | US1 | Task | [#549](https://github.com/The-Band-Solution/theband/issues/549) | 1 | feito |
| T003 | Migrações: credencial e concessões | US1 | Task | [#550](https://github.com/The-Band-Solution/theband/issues/550) | 3 | feito |
| T004 | Autenticação de domínio conforme contrato | US1 | Task | [#551](https://github.com/The-Band-Solution/theband/issues/551) | 5 | feito |
| T005 | Escopos de domínio conforme contrato | US2 | Task | [#552](https://github.com/The-Band-Solution/theband/issues/552) | 5 | feito |
| T006 | Tela de login do protótipo e sessão real | US1 | Task | [#553](https://github.com/The-Band-Solution/theband/issues/553) | 3 | feito |
| T007 | Sessão validada por token e expiração | US1 | Task | [#554](https://github.com/The-Band-Solution/theband/issues/554) | 3 | feito |
| T008 | Contas: criar e reiniciar senha (admin) | US1 | Task | [#555](https://github.com/The-Band-Solution/theband/issues/555) | 3 | feito |
| T009 | Tela de concessões com derivados declarados | US2 | Task | [#556](https://github.com/The-Band-Solution/theband/issues/556) | 3 | feito |
| T010 | O veredito único nas telas de pessoa | US2 | Task | [#557](https://github.com/The-Band-Solution/theband/issues/557) | 3 | feito |
| T011 | Operacionais restritas e filtradas (FR-023) | US2 | Task | [#558](https://github.com/The-Band-Solution/theband/issues/558) | 3 | feito |
| T012 | Tela de perfil | US3 | Task | [#559](https://github.com/The-Band-Solution/theband/issues/559) | 3 | feito |
| T013 | Verificação contra a origem e evidências | US3 | Task | [#560](https://github.com/The-Band-Solution/theband/issues/560) | 1 | feito |
| T014 | Gates verdes e fechamento | US3 | Task | [#561](https://github.com/The-Band-Solution/theband/issues/561) | 1 | feito |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Fora do escopo deste sprint

- **Recuperação de senha por e-mail** — não há envio de e-mail; caminho é o reset por
  quem administra (assumption da spec).
- **Auto-registro / convite por link** — cadastro segue ato administrativo.
- **Tipos de issue e hierarquia no GitHub** — aval pendente.
- **Multiplos papéis de gestão / transferência de "dono"** — organization por
  concessão cobre o caso de hoje (assumption).

## Riscos e dependências

- Rework do `Visibility` (FR-022) mexe em regra de acesso vigente — a regressão de
  FR-018 (líder declarado continua vendo) é a violação mais testada do sprint.
- Helper `log_in/2` alimenta ~centenas de testes: T007 muda o contrato dele; a suíte
  inteira é o teste de regressão.
- Migração seed depende de organizações observadas por tenant — tenants vazios geram
  0 concessões (correto: nada a preservar).

## Definition of Done do sprint

Além da DoD por tarefa:

- [x] quality gates verdes (forma completa da L60, EXIT no log) — 13/13, EXIT=0
- [x] base de conhecimento válida (parte dos gates)
- [x] issues encerradas ou repriorizadas com justificativa — #548–#561 fechadas;
      fatia de FR-008 repriorizada como [#568](https://github.com/The-Band-Solution/theband/issues/568)
- [x] `sprint-review.md` escrito
- [x] `licoes-aprendidas.md` atualizado (incidente da iteration incluído — L72)
