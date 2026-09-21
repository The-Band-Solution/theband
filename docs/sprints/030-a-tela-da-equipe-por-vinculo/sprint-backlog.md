# Sprint 030 — A tela da equipe por vínculo, e a herança que ganhou tela

**Período**: 2026-09-07 a 2026-09-12 (cadência de uma semana) · **fechado em 2026-09-13**
**Feature**: [060 — a tela da equipe](../../../specs/060-tela-da-equipe/spec.md)
**Plano**: [plan.md](../../../specs/060-tela-da-equipe/plan.md) ·
**Pesquisa**: [research.md](../../../specs/060-tela-da-equipe/research.md) ·
**Protótipo**: [prototipo/](../../../specs/060-tela-da-equipe/prototipo/) — aprovado em 2026-09-07 e 2026-09-08
**Herança**: [045](../../../specs/045-autenticacao-e-acesso/spec.md) (D06 da v0.7.0) ·
[055](../../../specs/055-equipes-declaradas/spec.md) (FR-003 e o ato de subequipe)

> **Este backlog foi escrito depois do sprint, em 2026-09-13.** A skill `sprint-backlog` é
> obrigatória antes de implementar e não rodou: a 060 foi de spec a tela sem este documento,
> sem issues e sem iteration. O que está aqui é a **intenção reconstruída** a partir do
> `tasks.md` de 2026-09-07 e dos PRs — não a intenção registrada antes de executar. A
> distinção importa porque a análise de aderência entre plano e execução, que este documento
> existe para permitir, **não pode ser feita** para este sprint: quem escreve já sabe o que
> aconteceu. Ver a lacuna 1 ao fim, e a lição L108.

## Objetivo do sprint

**A página da equipe passa a mostrar quem está nela por vínculo — observado e declarado, lado a
lado —, e quem gere a estrutura passa a poder agir sobre cada linha**: dizer que a pessoa saiu,
que o vínculo nunca existiu, declarar ou trocar o papel, e criar papéis da organização a partir
do que a estrutura mostra. E, na segunda aba, o fluxo da equipe em três granulações.

## De onde este sprint veio

A spec 060 nasceu em 2026-09-06/07 do épico da tela da equipe: a página mostrava participação
sem dizer de onde vinha cada afirmação, e a saída de alguém não era declarável. O protótipo
(`team-dashboard-structure.html`) foi aprovado antes do código, e o prompt que o gerou está em
`prototipo/`. A ordem das tarefas é a das **fatias verticais**: a primeira tela é a T010, e antes
dela só o que a tela precisa para decidir quem vê botão — a concessão *gerir estrutura da
equipe* (T002–T007).

**A herança entrou por revisão, não por planejamento.** A revisão de 2026-09-10 (`RETOMAR.md`
daquele dia) achou três coisas fora da 060: a FR-003 da 055 era cláusula MUST desde 2026-09-06 e
**não tinha tela** — `declare_team_membership/5` existia com 11 testes e zero chamadas em
`lib/`; o ato de criar subequipe fazia **duas escritas sem transação**; e o D06 da v0.7.0 (a
conta desativada) estava recusado por três razões que o #853 se propôs a fechar. Os três
entraram no mesmo período, e por isso estão aqui.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md). **Registradas depois** — o que se pode
afirmar é o que a evidência dos PRs mostra, não o que foi lido ao abrir.

| Lição | Origem | Como aparece na evidência |
|---|---|---|
| **princípio IV** — contrato antes da primeira função pública | constituição | T001 escreveu os contratos antes de tudo (#817) |
| **vertical slice** — nunca infraestrutura sem consumidor na tela | constituição VIII | a T010 é a primeira tela, e T002–T007 existem só porque ela precisa do veredito |
| **L38 / L53** — o custo de uma tela se mede pela diferença, com teto dos dois lados | 009, 013 | T013 mediu o teto de consultas das duas abas |
| **L30** — conferir o número contra a origem | 003 | T006 substituiu `pode_declarar_estrutura/4` e **mediu**: zero contas perderam escrita |
| **L60** — o veredito é o código de saída | 019 | #853 `exit 0` (2 026 testes), #857 `exit 0` (2 028), #863 `exit 0` (2 112), #860 `exit 0` (2 085) |
| **reinjeção de defeito** como prova do teste | 029 | #853 reinjetou 4 e os 4 reprovaram; #857 desfez a transação e o teste nomeou a invariante; #863 reinjetou 4; #860 reinjetou 3 |
| **L95** — pedir revisor não é obter revisão | 027 | **aplicada pela metade**: #816–#821 pediram revisor (1 cada, `reviews` 0); **#853, #857, #860 e #863 não pediram** |
| **L102** — `git add -A` numa árvore compartilhada | **nasceu aqui**, 2026-09-09 | um PR que dizia mudar três arquivos mudou seis; refeito com caminhos explícitos |
| **L103 / L104** — o protótipo não é o produto; aviso descartado vira atestado | **nasceram aqui**, 2026-09-10 | o detector de design passou a ignorar `prototipo/` (#858) e a exigir as bibliotecas |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · **1 PR** no
projeto (#817, com `Iteration` nula); os outros seis, fora.

### Três limitações — declaradas, não contornadas

1. **A 060 não tem issue nenhuma.** Nem épico, nem user story, nem tarefa. `/speckit-tasks`
   rodou, `/speckit-taskstoissues` **não**. As 29 tarefas abaixo estão sem link **de
   propósito** — tarefa sem issue é pendência explícita, nunca link inventado. É a mesma lacuna
   da 052 no sprint 026, e o destino é o mesmo: **criação retroativa depois da confirmação da
   aceitação**, com cada issue dizendo que nasceu depois do trabalho;
2. **Sem iteration.** A iteration ativa no período (*Sprint 024 — Mensagens e o botão da chave*,
   2026-09-05 a 2026-09-12) não recebeu item nenhum desta feature;
3. **Sem tipo.** Consequência da 1 — não há o que tipar.

## User stories selecionadas

Da spec 060, as **seis** que o `tasks.md` chama de *PR 1*. US6, US7 e US8 ficaram para a *PR 2*
(ver *Fora do escopo*).

| # | User story | Priority | Issue | Tarefas | Critérios |
|---|---|---|---|---|---|
| US1 | Quem está na equipe, e de onde veio cada afirmação | P1 | — | T010–T013 | AS 1–5, FR-001 a FR-013, SC-004, SC-007 |
| US2 | Declarar o papel de quem a origem mostra, e alterá-lo | P1 | — | T018–T020 | FR-014 a FR-018 |
| US3 | A pessoa saiu, e o que ela fez continua contando | P1 | — | T014–T015 | FR-019 a FR-023, SC-001, SC-013 |
| US4 | O vínculo que nunca foi | P1 | — | T016–T017 | FR-024 a FR-028, SC-002 |
| US5 | Criar o papel da organização a partir da estrutura | P1 | — | T021–T022 | FR-029 a FR-034, SC-005 |
| US9 | O fluxo da equipe inteira: burn, Prometido × Entregue, Monte Carlo | P3 | — | T026–T029 | FR-064, FR-084, SC-009; os três gráficos nas três granulações |

`Priority` é a *importance* — valor para a organização, e vem da spec. `Estimate` (a
*complexity*) **não foi registrada**: sem issue não há campo; a coluna não existe nesta tabela
para não sugerir que houve estimativa.

## Tarefas

Todas executadas — os PRs estão na coluna *Estado*. A coluna *Issue* é `—` em todas, pela
limitação 1.

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T001 | Escrever os contratos antes da primeira função pública | fundação | — | feito · #817 |
| T002 | Declarar as duas concessões na base (`role_grants.yaml`) | fundação | — | feito · #817 |
| T003 | Emendar a regra da evidência para a v3 | fundação | — | feito · #817 |
| T004 | A tabela e o schema da concessão de gestão | fundação | — | feito · #819 |
| T005 | `EO.StructureGrants` — declarar, revogar, listar e alcançar | fundação | — | feito · #821 |
| T006 | `pode_gerir_estrutura/3` substitui `pode_declarar_estrutura/4` | fundação | — | feito · #821 |
| T007 | `/roles` concede e revoga *manages team structure* | fundação | — | feito · #821 |
| T008 | A saída declarada e a data da declaração no esquema | fundação | — | feito · #821 |
| T009 | As consultas do roster | US1 | — | feito · #821 |
| T010 | As duas abas de `/teams/:id`, com a aba na URL | US1 | — | feito · #821 |
| T011 | A seção *Members* por vínculo, a legenda, a discordância e *Where this team sits* | US1 | — | feito · #821 |
| T012 | Quem não gere lê tudo e não vê ação — e o evento é recusado com motivo | US1 | — | feito · #821 |
| T013 | O teto de consultas das duas abas, medido | US1 | — | feito · #821 |
| T014 | A saída grava quem e quando, alcança os dois papéis, e a coleta não recria | US3 | — | feito · #821 |
| T015 | "Left the team…" na linha, com data obrigatória e a origem do fim dita | US3 | — | feito · #821 |
| T016 | O equívoco alcança todos os vigentes do par | US4 | — | feito · #821 |
| T017 | "Mistake…" na linha, com razão obrigatória e o texto que separa de "saiu" | US4 | — | feito · #821 |
| T018 | `declare_role/6` e `change_role/5` | US2 | — | feito · #821 |
| T019 | "Declare role" / "Change role" na linha, e "＋ new role…" sem sair dela | US2 | — | feito · #821 |
| T020 | O lote "Declare all roles", por vínculo, na Estrutura | US2 | — | feito · #821 |
| T021 | `role_holder_counts/3` — quantas pessoas por papel | US5 | — | feito · #821 |
| T022 | A seção *Roles*: catálogo e criados, criar com código sugerido, renomear, ocultar | US5 | — | feito · #821 |
| T023 | A escrita de projeto vive na Estrutura, sob o mesmo veredito | fechamento | — | feito · #821 |
| T024 | Isolamento entre tenants nas consultas novas | fechamento | — | feito · #821 |
| T025 | Gates, quickstart e documentos | fechamento | — | feito · #821 |
| T026 | A granulação e a janela vivem no endereço, com padrão por granulação | US9 | — | feito · #821 |
| T027 | *Prometido × Entregue*, com a definição junto do título | US9 | — | feito · #821 |
| T028 | Os três gráficos na equipe composta, sobre o conjunto da equipe inteira | US9 | — | feito · #821 |
| T029 | O gráfico pequeno no cartão da subequipe | US9 | — | feito · #821 |

### Herança e o que entrou sem tarefa — entregáveis fora do `tasks.md` da 060

| # | Entregável | Feature | Origem | Estado |
|---|---|---|---|---|
| H4 | **A aba *Flow per person*** — o burn por pessoa e a previsão que diz sua confiança; três consultas para qualquer número de membros | 060 · US10–US12 da extensão `spec-graficos-por-membro.md` (FR-085 a FR-112) | o `tasks.md` as declarava **sem tarefa** ("depende da US9 e do protótipo desta aba, que ainda não existe"); o protótipo foi aprovado em 2026-09-08 e a tela entrou assim mesmo | feito · #860 (2026-09-12) — **não avaliado**; os requisitos estão sendo transcritos do protótipo no #913 |
| H1 | A conta desativada como o protótipo pediu — razão de lista fechada, episódio com as duas pontas, a recusa na tela | 045 · D06 da v0.7.0 | `docs/releases/v0.7.0.md`, D06 recusado | feito · #853 (2026-09-10) |
| H2 | Vincular pessoa a equipe — FR-003 ganha tela, com o veredito antes do botão | 055 · FR-003 | revisão de 2026-09-10 | feito · #863 (2026-09-12) |
| H3 | Declarar equipe dentro de outra é **um** ato, numa transação | 055 · `criar_subequipe` | revisão de 2026-09-10 | feito · #857 (2026-09-11) |

## Fora do escopo deste sprint

| O quê | Por quê |
|---|---|
| **US6** — as subequipes: quem compõe esta equipe, desde quando (P2) | *PR 2*; o cartão da subequipe foi movido para a US7 pela decisão 11 de 2026-09-07 (#820) |
| **US7** — o Dashboard reorganizado (P2) | *PR 2*; FR-041 (cartão e a porta) sem tarefa |
| **US8** — a visão geral do gestor (P2) | *PR 2* |
| **US10–US12** — os quatro gráficos por membro (FR-085 a FR-112) | o `tasks.md` as declarava sem tarefa; **entraram assim mesmo** pelo #860, fora do plano — ver H4 |
| **FR-007** | confirmado sem mudança (`pode_ver_equipe/3`) |

## Riscos e dependências

- **As seis perguntas abertas do `plan.md`** não bloqueavam começar e bloqueavam fechar T002,
  T014, T017 e T022. Quatro delas estavam na pauta em 2026-09-08: `started_at` de
  `eo_team_compositions` obrigatório × "data ou desconhecido" (FR-037); cinco transições sem
  teste; `eo_organizational_units` sem schema e sem leitor; a tabela por subequipe convive ou
  substitui os cartões (#820). **Nenhuma resposta está registrada** — as tarefas fecharam assim
  mesmo, e isto é dívida (ver a review);
- **Dois YAML e duas migrações** — `role_grants.yaml`, evidência v3, `saida_declarada_com_autor`,
  `concessao_de_gestao_da_estrutura`. Aditivas;
- **`Periodos.interseccao/1` pessimista** (dívida da 057/058) — a tela por vínculo consome a
  marca de período parcial, e uma equipe sem `started_at` a verá em toda linha.

## Definition of Done do sprint

- [x] quality gates verdes — `mix gates` `exit 0` em cada PR, e o CI verde em `development`
- [x] base de conhecimento válida — parte dos gates
- [ ] issues encerradas ou repriorizadas — **não há issues** (limitação 1)
- [x] `sprint-review.md` escrito — retroativo, 2026-09-13
- [x] `aceitacao.md` escrito — proposta do papel, confirmação pendente
- [x] `licoes-aprendidas.md` atualizado — L108
