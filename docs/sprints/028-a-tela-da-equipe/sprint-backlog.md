# Sprint 028 — A tela da equipe, e a equipe feita de equipes

**Período**: 2026-09-02 a 2026-09-09 (cadência de uma semana)
**Feature**: [057](../../../specs/057-tela-da-equipe-complexa/spec.md)
**Plano**: [plan.md](../../../specs/057-tela-da-equipe-complexa/plan.md)
**Protótipo aprovado**: [prototipo/](../../../specs/057-tela-da-equipe-complexa/prototipo)

## Objetivo do sprint

A tela da equipe passa a responder as quatro perguntas de gestão, a equipe
composta mostra suas subequipes **sem somar**, e — antes de qualquer indicador
novo — **os números param de contar quem já saiu e param de reescrever o
passado**.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md):

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L95** pedir revisor não é obter revisão | Sprint 027 | antes de cada merge, medir `gh pr view <n> --json reviews`. **Zero é impedimento**, não observação — foi o que faltou nos quatro PRs da 055 |
| **L96** issue que ninguém fecha faz o sprint parecer não entregue | Sprint 027 | `gh issue list --state open` com o prefixo `057/` entra na DoD do sprint, **antes** de escrever a review |
| **L97** feature que corrige o vínculo não corrige quem lê o vínculo | Sprint 027 | é a US1 deste sprint. O `plan.md` lista os consumidores do vínculo e diz de cada um se muda |
| **L91** o passo do ciclo sem gate é o que some | Sprint 025 | as 41 issues estão linkadas no `tasks.md`, uma por tarefa, e conferidas na origem |
| **L86** denominador móvel mente igual a inventado | Sprint 026 | SC-002 exige igualdade estrita entre a série antes e depois de registrar uma saída |
| **L11** reconfigurar iteration recria as existentes | Sprint 002 | **o campo de iteration não foi tocado** — ver a limitação abaixo |
| **L83/L92** squash diverge e apaga o back-merge | Sprint 026 | merge commit nos PRs, nunca squash |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
43 itens acrescentados

### Duas limitações declaradas, não contornadas

**1. Este sprint não tem iteration.** A última iteration configurada é *Sprint 026
— Herança e a produção*, com início em 2026-09-19 — datas que já não correspondem
a quando os sprints rodam. Acrescentar iterations exige `updateProjectV2Field`, e
a **L11 mediu o custo disso**: as iterations existentes foram recriadas e **97
itens ficaram órfãos**, com 87 reatribuídos à mão depois.

Não foi improvisado label nem milestone no lugar. O sprint 027 também rodou sem
iteration, e a lacuna se acumula — resolver isso é trabalho próprio, com o
snapshot dos `item id` antes.

**2. As user stories estão sem tipo.** A organização tem `Task`, `Bug` e
`Feature`; **`User Story` e `Epic` não existem**. Criar tipo altera a configuração
da organização, e a skill exige confirmação — não foi feita.

Tipar as seis como `Feature` faria a regra de roteamento em
`priv/knowledge_base/rules/github_issue_type_routing.yaml` classificá-las
erradamente. **Sem tipo é ausência; com o tipo errado é afirmação falsa.**

As 37 tarefas **estão** tipadas como `Task`, e as 28 que atendem user story estão
ligadas como sub-issue da sua.

## User stories selecionadas

| # | User story | Issue | Priority | Estimate | Tarefas | Critérios |
|---|---|---|---|---|---|---|
| US1 | A medida conta só enquanto a pessoa pertenceu | [#715](https://github.com/The-Band-Solution/theband/issues/715) | P0 | 5 | T005–T008 | SC-001, SC-002 |
| US2 | A equipe complexa mostra suas equipes, uma a uma | [#716](https://github.com/The-Band-Solution/theband/issues/716) | P0 | 5 | T009–T013, T037 | SC-003, SC-005 |
| US3 | O detalhe da subequipe: fazendo, feito, e o que vem | [#717](https://github.com/The-Band-Solution/theband/issues/717) | P1 | 3 | T014–T017 | — |
| US4 | O que cada pessoa está fazendo, e o que demonstrou | [#718](https://github.com/The-Band-Solution/theband/issues/718) | P1 | 5 | T018–T022, T035, T036 | SC-006, SC-007, SC-012 |
| US5 | Burn-up e burn-down, com o que resta entre as curvas | [#719](https://github.com/The-Band-Solution/theband/issues/719) | P1 | 3 | T023–T026 | SC-004 |
| US6 | Uma previsão que diz sua confiança | [#720](https://github.com/The-Band-Solution/theband/issues/720) | P2 | 5 | T027–T029 | SC-008, SC-009, SC-010 |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a
*complexity* — dificuldade para o time. **As tarefas não recebem `Priority`**:
herdam a da user story que atendem.

## Tarefas

Todas em [`tasks.md`](../../../specs/057-tela-da-equipe-complexa/tasks.md), com os
quatro campos e o link da issue. Faixa: [#721](https://github.com/The-Band-Solution/theband/issues/721)
a [#757](https://github.com/The-Band-Solution/theband/issues/757).

| Fase | Tarefas | Issues | Atende |
|---|---|---|---|
| Setup | T001 | #721 | — |
| Foundational | T002–T004, **T034** | #722–#724, #754 | bloqueia tudo |
| US1 | T005–T008 | #725–#728 | #715 |
| US2 | T009–T013, T037 | #729–#733, #757 | #716 |
| US3 | T014–T017 | #734–#737 | #717 |
| US4 | T018–T022, T035, T036 | #738–#742, #755, #756 | #718 |
| US5 | T023–T026 | #743–#746 | #719 |
| US6 | T027–T029 | #747–#749 | #720 |
| Polish | T030–T033 | #750–#753 | — |

**T034–T037 estão fora da ordem numérica de propósito**: nasceram do
`/speckit-analyze` depois das 33 primeiras issues, e renumerar as invalidaria.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado` —
todas em **a fazer**.

## Herdado do sprint 027

| Item | Issue | Por que veio | Onde entra |
|---|---|---|---|
| T014 da 055 — as duas afirmações quando coleta e declaração discordam | [#700](https://github.com/The-Band-Solution/theband/issues/700) | nunca implementada | **dentro da US3 desta feature**: a tela é reescrita ali, e fazê-la antes seria trabalho jogado fora |
| T015 da 055 — revisão CONFERIDA | [#701](https://github.com/The-Band-Solution/theband/issues/701) | os quatro PRs tiveram 2 revisores pedidos e **0 revisões** | **condição de entrada** de todo PR deste sprint |

## Fora do escopo deste sprint

| O que | Por quê |
|---|---|
| a mesma correção de linha de base na **página da pessoa** | teto de consultas e critério de revisão próprios — T032 registra no backlog em vez de esconder |
| seletor de período das séries | escolher o período é trabalho separado, e um seletor sem período fechado reabre a questão do denominador móvel |
| exportação, alerta ativo, comparação entre organizações | fora do que a feature responde |
| **qualquer soma consolidada** | por decisão, não por prazo — FR-008 |
| criar os tipos `User Story` e `Epic` | altera a configuração da organização; exige confirmação |
| acertar as iterations do Projects v2 | L11 mediu o custo: 97 itens órfãos |
| [servidor MCP](../../backlog/servidor-mcp.md) | registrado em 2026-09-02; bloqueado até autenticação e tenant serem decididos |

## Riscos e dependências

| Risco | Efeito | Mitigação |
|---|---|---|
| **revisão independente de novo não acontecer** | princípio VII violado outra vez, e a L95 vira reincidência | medir `reviews` antes de cada merge; zero é impedimento |
| a correção da US1 muda números já anotados por alguém | desconfiança na plataforma | o PR declara o antes e o depois, medidos em dado real |
| `show.ex` passar de ~1200 linhas | duas razões para mudar no mesmo arquivo | limite e critério de divisão já escritos no plano |
| teto de consultas estourar | tela lenta, gate vermelho | T031 transforma o teto em teste |
| a previsão ser lida como promessa | compromisso assumido sobre ruído | FR-033, o piso de R7, e o texto na tela |

## Definition of Done do sprint

Além da DoD por tarefa:

- [ ] `mix gates` com **código de saída 0** — o veredito é o código, e nenhum
      comando depois dele
- [ ] base de conhecimento válida, com as medidas novas declaradas (T004)
- [ ] **`gh pr view <n> --json reviews` > 0 em todo PR incorporado** — L95
- [ ] **`gh issue list --state open --search "057/ in:title"` conferida antes da
      review**, e toda divergência com o `tasks.md` resolvida — L96
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado

## Baseline dos gates

Medido em 2026-09-02, antes de qualquer linha desta feature:

```text
14 gates verdes.
CODIGO_DE_SAIDA=0
```

120 arquivos YAML · 14 ontologias · 238 conceitos · 175 relações · 5 medidas ·
32 módulos · derivação reproduzível em `eo`, `sro`, `cmpo` e `spo`.
