# Sprint Backlog 001 — Fundação e coleta EO

**Iteration no GitHub**: Sprint 001 — Fundação e coleta EO · 2026-08-03 a 2026-08-09 · 7 dias
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)
**Feature**: [001-github-eo-ingestion](../../../specs/001-github-eo-ingestion/spec.md)
**Épico**: [#1](https://github.com/The-Band-Solution/theband/issues/1)
**Aberto em**: 2026-08-09

## Objetivo

Entregar a primeira fatia vertical do The Band: uma organização declara que usa o
GitHub, informa instância e credencial, dispara uma sincronização e **vê na tela**
as pessoas e equipes que a plataforma passou a conhecer — cada registro com
origem, identificador na ferramenta e data de coleta.

O bootstrap do projeto Phoenix faz parte desta fatia. Separá-lo produziria uma
entrega sem nada visível, o que o princípio VI da constituição proíbe.

## Lições consideradas

Do [registro acumulado](../licoes-aprendidas.md): **este é o primeiro sprint**, e
o arquivo de lições não existia ao abri-lo. As lições L01 a L07 foram escritas
durante e ao fim dele, e passam a valer como restrição para o sprint 002.

Duas restrições vieram de instruções permanentes anteriores ao sprint, e foram
aplicadas desde o planejamento:

- **fatia vertical** — toda entrega mostra tela e backend na mesma proposta de
  mudança; nunca infraestrutura sem consumidor visível;
- **cerimônia proporcional** — um checklist, não três, e requisitos só do que a
  feature entrega.

## User stories selecionadas

| # | User story | Tipo | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|---|
| US1 | Conectar uma ferramenta com credencial protegida | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#3](https://github.com/The-Band-Solution/theband/issues/3) | P0 | — | 5 cenários |
| US2 | Conhecer as pessoas e equipes de uma organização | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#4](https://github.com/The-Band-Solution/theband/issues/4) | P1 | — | 6 cenários |
| US3 | Rastrear de onde veio cada informação | Feature | [#1](https://github.com/The-Band-Solution/theband/issues/1) | [#5](https://github.com/The-Band-Solution/theband/issues/5) | P2 | — | 3 cenários |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a
*complexity* — dificuldade para o time. Campo em branco significa desconhecido,
não zero.

### Duas divergências de campo, registradas em vez de escondidas

**Escala de prioridade.** A spec usa P1/P2/P3; o projeto no GitHub oferece
P0/P1/P2. O mapeamento preserva a **ordem**, não o rótulo: US1→P0, US2→P1,
US3→P2. Ler "P0" aqui como "a mais importante das três", nunca como uma
criticidade que a spec não declarou.

**`Estimate` em branco, de propósito.** Nenhuma estimativa de complexidade foi
feita com o time. Preencher o campo com número inventado produziria métrica de
fluxo apoiada em ficção, e a ausência é o registro honesto de que a decisão não
foi tomada — ausência é nula, nunca zero.

## Tarefas

73 tarefas, issues [#6](https://github.com/The-Band-Solution/theband/issues/6) a
[#78](https://github.com/The-Band-Solution/theband/issues/78), derivadas de
[tasks.md](../../../specs/001-github-eo-ingestion/tasks.md). Numeração: `Tnnn` →
issue `#(nnn + 5)`.

| Fase | Tarefas | Issues | Atende |
|---|---|---|---|
| 1 — Setup | T001–T008 | #6–#13 | fundação (épico) |
| 2 — Foundational | T009–T031 | #14–#36 | fundação (épico) |
| 3 — US1 | T032–T040 | #37–#45 | US1 |
| 4 — US2 | T041–T060 | #46–#65 | US2 |
| 5 — US3 | T061–T068 | #66–#73 | US3 |
| 6 — Polish | T069–T073 | #74–#78 | fundação (épico) |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Materialização no GitHub

| Conceito SRO | GitHub | Estado |
|---|---|---|
| `sro.sprint` | iteration `2849580c` do ProjectV2, em `completedIterations` | 7 dias, 2026-08-03 a 2026-08-09 |
| `sro.epic` | issue [#1](https://github.com/The-Band-Solution/theband/issues/1), tipo `Feature`, 3 sub-issues user story | criado |
| `sro.atomic_user_story` | issues #3, #4, #5, tipo `Feature` | criadas e ligadas ao épico |
| `sro.intended_scrum_development_task` | issues #6–#78, tipo `Task` | criadas e ligadas às user stories |
| `sro.sprint_backlog` | 77 itens do projeto na iteration | atribuídos |

**Limitação registrada — tipos de issue.** A organização tem apenas `Task`, `Bug`
e `Feature`. `Epic` e `User Story` não existem, e criá-los altera a configuração
da organização, o que exige confirmação humana que não foi pedida. A regra
`github.issue_type_routing` aceita `Feature` como rota para
`sro.atomic_user_story`, e sua precedência é **estrutura sobre rótulo** — uma
issue tipo `Feature` cujas sub-issues são user stories é promovida a `sro.epic`.
Por isso o épico funciona sem o tipo dedicado, e a divergência fica registrada na
proveniência quando o próprio repositório for ingerido.

**Ocorrência corrigida.** A issue #2 é duplicata órfã da US1, criada por uma
execução do script de materialização que falhou no parsing da resposta **depois**
de a issue já existir. Fechada como `not planned`, com a razão registrada no
próprio fechamento. A US1 válida é a #3.

## Definition of Done deste sprint

Da constituição, princípio VII e seção Fluxo de desenvolvimento:

- [ ] critérios de aceitação avaliados um a um, com evidência
- [ ] issues atualizadas
- [ ] YAMLs validados
- [ ] testes passando
- [ ] Credo e Dialyzer aprovados
- [ ] migrações testadas
- [ ] mapeamento semântico revisado
- [ ] documentação atualizada
- [ ] **PR aprovado por outra pessoa ou outro agente**
- [ ] pipeline verde
- [ ] merge feito e issues encerradas

O resultado de cada item está em [sprint-review.md](sprint-review.md), separando
o que foi entregue do que não foi.
