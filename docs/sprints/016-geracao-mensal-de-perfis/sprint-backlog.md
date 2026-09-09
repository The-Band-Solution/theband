# Sprint 016 — a geração mensal dos perfis

**Período**: a partir de 2026-08-16 · fim não declarado — ver *Limitações* abaixo
**Feature**: [027 geração mensal de perfis](../../../specs/027-geracao-mensal-de-perfis/spec.md)
**Plano**: [plan.md](../../../specs/027-geracao-mensal-de-perfis/plan.md) · **Tarefas**: [tasks.md](../../../specs/027-geracao-mensal-de-perfis/tasks.md)
**Branch**: `027-geracao-mensal-de-perfis`

## Objetivo do sprint

O perfil de competências deixa de depender de alguém lembrar de clicar: a plataforma o escreve sozinha, uma vez por mês, para quem teve trabalho novo — e mostra numa tela o que a rodada fez e quanto custou.

## Fase 0 — o que sobrou do sprint anterior, com destino

A regra da **L12** é que nenhum escopo novo é selecionado enquanto o item anterior não tiver destino. O destino não precisa ser "concluído": pode ser devolvido, descartado com motivo, ou bloqueado com bloqueador nomeado.

| Item | Estado real | Destino |
|---|---|---|
| **Feature 026** — perfil de competências, PR [#330](https://github.com/The-Band-Solution/theband/pull/330) | **incorporado** em 2026-08-16 às 13:06 UTC, commit `16c7388` | concluído |
| Revisão independente do #330 | **não aconteceu**: `reviews` vazio no momento do merge, com pedido pendente a `Adylla027` e `EduardoNFraiz` | **lacuna registrada**, não marcada como cumprida — princípio VII |
| `sprint-review.md` do sprint 014 | **não existe** | pendência declarada abaixo |
| Sprints 015 e as features 018 a 026 | sem diretório em `docs/sprints/` | pendência declarada abaixo |

### A pendência de processo, dita por inteiro

A conferência que a **L44** manda fazer ao abrir um sprint encontrou o seguinte: `docs/sprints/` vai até **014**, e o registro de lições cita **Sprint 015**. As features 018 a 026 foram entregues **sem** `sprint-backlog.md` e sem `sprint-review.md`, embora as lições tenham continuado a ser escritas — o arquivo acumulado chegou a L59.

Ou seja: o mecanismo que produz aprendizado continuou funcionando, e o que produz **rastro do que foi planejado contra o que foi entregue** parou. É exatamente a metade que a L44 descreve como a que some sem nada falhar.

Este sprint não corrige o passado — reconstruir nove reviews de memória produziria documento pior que a ausência. O que ele faz é **voltar a produzir**, e registrar a lacuna para que ninguém a leia como "não houve sprint".

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L12** | Sprint 001 | a Fase 0 acima: a 026 recebeu destino antes de qualquer escopo novo ser selecionado, e a revisão que não aconteceu está declarada, não maquiada |
| **L44** | Sprint 009 | a conferência mecânica foi feita ao abrir, e achou a lacuna de nove sprints sem documento |
| **L58** | Sprint 015 | o #330 foi incorporado por *squash* durante esta sessão; a branch da 027 foi **rebaseada** sobre a `main` para o PR desta feature não mostrar a 026 de novo. Conferido com `git log origin/main..HEAD`: dois commits, os meus |
| **L11** | Sprint 001 | **por isso o sprint não vira iteration no GitHub**: reconfigurar o campo recria as iterations existentes, e Sprint 001 e 002 perderiam identidade |
| **L26** | Sprint 006 | a `FR-016` separa falha de credencial de falha transitória, e `200` com lista vazia de modelos é **erro** em `verify/2`, nunca sucesso |
| **L28** | Sprint 007 | os tokens de entrada são **gravados** por pessoa, e não só calculados para exibir — `FR-020`, T014 |
| **L30** e **L35** | Sprints 008 e 009 | o custo da rodada é medido contra o provedor de verdade, não estimado — T024, e é o único item que nenhum teste substitui |
| **L59** | Sprint 015 | o verde do CI é conferido no commit, e não no PR: o gate de Credo que o `57c509f` quebrou não apareceu no #330 porque os checks verdes eram do commit anterior |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · `PVT_kwDODHSRm84BAAnT`

**Limitações declaradas, e não contornadas:**

- **o campo `Iteration` parou no Sprint 002**, iniciado em 2026-08-10 com sete dias. Não há iteration para os sprints 003 a 016. Criar a deste sprint exige `updateProjectV2Field` sobre a configuração do campo, e a **L11** registra que essa mutação recria as iterations existentes — Sprint 001 e 002 perderiam identidade, e com ela a série que o produto pretende ingerir. **Decisão de 2026-08-16: não mexer, e registrar aqui**;
- **os tipos `Epic` e `User Story` não existem na organização.** Só `Task`, `Bug` e `Feature`. Criá-los altera a configuração da organização inteira. As 28 issues foram criadas sem tipo próprio, com o rótulo `enhancement`, e a ligação com a feature vive **no corpo de cada issue** — o caminho `specs/027-geracao-mensal-de-perfis/tasks.md`, que é o que permite reencontrá-las;
- consequência: a hierarquia `Epic → User Story → Task` que a regra de roteamento espera **não existe** para este sprint. Quem for ingerir o repositório vai ler estas 28 issues como tarefas soltas.

## User stories selecionadas

| # | User story | Prioridade | Tarefas | Critérios de aceitação |
|---|---|---|---|---|
| **US1** | O perfil está lá quando eu abro | P1 | 11 | 4 cenários |
| **US2** | Ver o que a rodada fez, e o que ela custou | P1 | 5 | 4 cenários |

As duas são P1 e **entram juntas**: a US1 sozinha é infraestrutura sem consumidor visível, o que o princípio VI proíbe. `Priority` e `Estimate` não foram gravadas no projeto — ver *Limitações*. Campo em branco significa desconhecido, nunca zero.

## Tarefas

### Setup

| # | Tarefa | Issue | Estado |
|---|---|---|---|
| T003 | Fila própria para as rodadas | [#331](https://github.com/The-Band-Solution/theband/issues/331) | a fazer |
| T004 | Limiares de regeneração na base de conhecimento | [#332](https://github.com/The-Band-Solution/theband/issues/332) | a fazer |
| T005 | Validação recusa limiar ausente ou inválido | [#333](https://github.com/The-Band-Solution/theband/issues/333) | a fazer |

### Fundação

| # | Tarefa | Issue | Estado |
|---|---|---|---|
| T006 | Migração dos eventos de automação | [#334](https://github.com/The-Band-Solution/theband/issues/334) | a fazer |
| T007 | Migração das rodadas | [#335](https://github.com/The-Band-Solution/theband/issues/335) | a fazer |
| T008 | Migração das entradas de rodada | [#336](https://github.com/The-Band-Solution/theband/issues/336) | a fazer |
| T009 | Schemas das três tabelas | [#337](https://github.com/The-Band-Solution/theband/issues/337) | a fazer |

### US1 — o perfil está lá quando eu abro

| # | Tarefa | Issue | Estado |
|---|---|---|---|
| T010 | Ler os limiares sem padrão embutido | [#338](https://github.com/The-Band-Solution/theband/issues/338) | a fazer |
| T011 | Decidir quem entra na rodada, e por qual motivo não | [#339](https://github.com/The-Band-Solution/theband/issues/339) | a fazer |
| T012 | Ligar e desligar com autor | [#340](https://github.com/The-Band-Solution/theband/issues/340) | a fazer |
| T013 | Abrir, registrar e encerrar a rodada | [#341](https://github.com/The-Band-Solution/theband/issues/341) | a fazer |
| T014 | A geração devolve o consumo | [#342](https://github.com/The-Band-Solution/theband/issues/342) | a fazer |
| T014a | O material continua sendo o histórico inteiro | [#343](https://github.com/The-Band-Solution/theband/issues/343) | a fazer |
| T015 | A rodada executa sequencialmente, com checkpoint | [#344](https://github.com/The-Band-Solution/theband/issues/344) | a fazer |
| T016 | Falha de credencial encerra a rodada | [#345](https://github.com/The-Band-Solution/theband/issues/345) | a fazer |
| T016a | Quem falhou volta na rodada seguinte | [#346](https://github.com/The-Band-Solution/theband/issues/346) | a fazer |
| T017 | O cron mensal enfileira uma rodada por organização | [#347](https://github.com/The-Band-Solution/theband/issues/347) | a fazer |
| T017a | Subir a versão não gera nada | [#348](https://github.com/The-Band-Solution/theband/issues/348) | a fazer |

### US2 — ver o que a rodada fez

| # | Tarefa | Issue | Estado |
|---|---|---|---|
| T018 | Tela da geração automática | [#349](https://github.com/The-Band-Solution/theband/issues/349) | a fazer |
| T019 | Os nove números de cada rodada | [#350](https://github.com/The-Band-Solution/theband/issues/350) | a fazer |
| T020 | Ligar dispara a primeira rodada | [#351](https://github.com/The-Band-Solution/theband/issues/351) | a fazer |
| T020a | Pedir uma rodada a mão | [#352](https://github.com/The-Band-Solution/theband/issues/352) | a fazer |
| T021 | Uma organização não vê a rodada da outra | [#353](https://github.com/The-Band-Solution/theband/issues/353) | a fazer |

**Já entregue nesta branch**, e por isso fora da contagem: a credencial por organização — `lib/the_band/ai.ex`, a tela `/ai` e `verify/2` na borda —, commit `46b433d`, com 31 testes.

## Fora do escopo deste sprint

| # | Tarefa | Issue | Por que fica de fora |
|---|---|---|---|
| T022 | O limiar novo vale na rodada seguinte | [#354](https://github.com/The-Band-Solution/theband/issues/354) | US3, P2. Depende da US1 existir, e o valor aparece quando alguém quiser ajustar — não na primeira rodada |
| T023 | Registro operacional sem chave e sem material | [#355](https://github.com/The-Band-Solution/theband/issues/355) | polimento |
| T024 | **Medir o custo real de uma rodada** | [#356](https://github.com/The-Band-Solution/theband/issues/356) | exige chave real e de 15 a 35 minutos de rodada contra o provedor. **Fica de fora do sprint, e não do caminho**: a `FR-021` obriga essa medição antes de N e M serem fixados — ver *Riscos* |
| T025 | Quality gates verdes | [#357](https://github.com/The-Band-Solution/theband/issues/357) | roda ao fechar |
| T026 | Percorrer o quickstart a mão | [#358](https://github.com/The-Band-Solution/theband/issues/358) | roda ao fechar |

Silenciar isto faria o sprint parecer a feature inteira. Não é: são 23 das 28 issues.

## Riscos e dependências

| Risco | Por quê | O que fazer |
|---|---|---|
| **N e M ficam fixados sem a medição** | a T024 está fora do sprint, e a `FR-021` a exige antes de os limiares valerem | os valores entram no YAML como **iniciais**, e o `SC-002` diz que muda junto com a recontagem. Se a medição não acontecer, o sprint fecha com a dívida registrada, nunca com o número declarado por estimativa |
| **Job Oban de 35 minutos** | é fora do comum neste repositório | fila própria (T003) e checkpoint (T015). Reinício de nó no meio devolve o job à fila, e o checkpoint é o que impede isso de custar dinheiro |
| **Revisão independente** | o #330 foi incorporado sem ela; nada garante que o PR desta feature terá | pedir à equipe `the-band` **ao abrir** o PR, e conferir com `gh pr view --json reviewRequests` — a L14 registra que o `gh` sai com código zero mesmo quando o pedido é recusado |
| **Provedor externo** | 34 gerações seguidas podem esbarrar em limite de taxa | a `FR-016` já separa isso de falha de credencial; se acontecer, vira medição para a T024 |

## Definition of Done do sprint

- [ ] as 23 issues fechadas, ou repriorizadas com justificativa escrita
- [ ] `mix gates` com código de saída 0 — nunca com `| tail` nem `| grep`
- [ ] `mix knowledge.validate` passando com a regra `regeneration` nova
- [ ] PR aberto com revisor pedido à equipe `the-band`, e o pedido **conferido**
- [ ] `sprint-review.md` escrito, separando entregue de não entregue
- [ ] `licoes-aprendidas.md` atualizado
- [ ] a lacuna da revisão independente **declarada**, se persistir — nunca marcada como cumprida
