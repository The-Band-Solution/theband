# Sprint 011 — o vínculo que sumiu na origem

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [012 — o vínculo que sumiu na origem](../../../specs/012-vinculo-que-sumiu-na-origem/spec.md)
**Plano**: [plan.md](../../../specs/012-vinculo-que-sumiu-na-origem/plan.md)
**Origem**: [#263](https://github.com/The-Band-Solution/theband/issues/263), achada **durante** o sprint 010
**Análise**: rodada antes do código, **quatro correções** — três de desenho

## Objetivo do sprint

Ao fim deste sprint, a plataforma para de afirmar decomposição que a origem não declara mais.

São **1 666** vínculos, **0** marcados como ausentes, e **52** que a última coleta não reviu. A coluna
`no_longer_observed_at` existe desde 2026-08-11 e **nada no código a escreve**.

## A conferência da L44, feita antes de tudo

**Abrir sprint novo confere o anterior.** O sprint 010 tem os três documentos:

```text
docs/sprints/010-de-quem-a-issue-e-parte/sprint-backlog.md   ✓
docs/sprints/010-de-quem-a-issue-e-parte/sprint-review.md    ✓
specs/011-de-quem-a-issue-e-parte/aceitacao.md               ✓  12 de 13 critérios
```

**E a conferência achou uma coisa que a L44 não previa**: os três documentos, as lições **L38 a L44**
e o `RETOMAR.md` vivem no PR [#264](https://github.com/The-Band-Solution/theband/pull/264), que está
**aberto**. Uma branch tirada da `main` abriria este sprint sem conseguir ler as lições que ele
precisa citar — que é exatamente o defeito que a L44 descreve, por outro caminho.

**Resolvido empilhando**: `016-vinculo-que-sumiu-na-origem` saiu de `015-de-quem-a-issue-e-parte`, e
não da `main`. Vai para a review deste sprint como lição.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 44 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L08** | Sprint 002 | contrato antes da primeira função pública — `contracts/decomposition-absence.md` |
| **L18** | Sprint 003 | a aceitação avalia os SC um a um com evidência, nunca a suíte verde |
| **L19** | Sprint 003 | a marca é **por repositório**, e não existe aridade sem ele — a L19 impedida no tipo |
| **L21** | Sprint 004 | T001 é função sem consumidor; T005 a chama no mesmo sprint |
| **L22**, **L23** | Sprint 004 | `mix gates`, veredito por código de saída |
| **L27** | Sprint 005 | ciclo completo antes do código — **sétima** feature seguida |
| **L28** | Sprint 005 | "a função marca" e "a tela mostra" são afirmações diferentes: T008 vai ao HTML |
| **L29** | Sprint 005 | **falha transitória não marca nada** — é a US3 inteira, e é a lição que custou 38 repositórios |
| **L30** | Sprint 005 | os números vêm do banco: 1 666, 0, 52, 57, 12 — todos medidos, nenhum lembrado |
| **L32** | Sprint 006 | a tela não afirma o que não observou — é o defeito sendo corrigido, na direção do dado |
| **L35** | Sprint 007 | conferir contra a origem acha defeito fora da feature: os 12 da `sro.rule07` |
| **L43** | Sprint 010 | quando o axioma responde outra pergunta, corrige-se a precondição — aqui, o **corte**, não a data |
| **L44** | Sprint 010 | a conferência mecânica dos três documentos, feita acima |

**A L29 não é citação decorativa neste sprint**: ela **é** a US3. A feature toda consiste em marcar
ausência, e marcar ausência do que não foi olhado é exatamente o que tirou 38 repositórios e 899
issues de circulação, em silêncio.

**A L30 já cobrou o seu preço aqui, e antes do código.** O plano mediu que gravar o `started_at` na
marca contradiz as três implementações irmãs — e o FR-002 foi corrigido antes de existir função.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) · 13 itens, `Status =
Backlog`, `Priority = P1` no épico e nas três user stories, `Estimate` em todas.

**Iteração**: **não atribuída**, e a razão é a mesma desde o sprint 004 — o campo existe e só tem
`Sprint 002` configurada. Reconfigurar iterations do ProjectV2 **recria as existentes** (L11), e já
custou reatribuir 96 itens. Fica declarado como limitação, não como esquecimento.

**Tipos**: épico e user stories como `Feature`, tarefas como `Task` — a organização não tem `Epic`
nem `User Story`, e a regra de roteamento decide épico pela presença de sub-issues.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|
| US1 | A coleta para de afirmar a decomposição que a origem largou | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#266](https://github.com/The-Band-Solution/theband/issues/266) | P1 | 8 | 5 |
| US2 | A tela deixa de afirmar o que a origem não declara | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#267](https://github.com/The-Band-Solution/theband/issues/267) | P1 | 5 | 4 |
| US3 | Coleta que não olhou não marca | [#265](https://github.com/The-Band-Solution/theband/issues/265) | [#268](https://github.com/The-Band-Solution/theband/issues/268) | P1 | 5 | 5 |

**As três são P1, e não é inflação.** US1 é o defeito; US2 é o que se vê; US3 é o que impede a
correção de virar um defeito pior que o original.

## Tarefas

Detalhadas em [012/tasks.md](../../../specs/012-vinculo-que-sumiu-na-origem/tasks.md). Cada tarefa é
filha da **user story que ela atende** — nunca do épico.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Marcar o vínculo não revisto | US1 | [#269](https://github.com/The-Band-Solution/theband/issues/269) | 5 | F1 | a fazer |
| T002 | Preservar a vigência de quem voltou | US1 | [#270](https://github.com/The-Band-Solution/theband/issues/270) | 2 | F1 | a fazer |
| T003 | Fixar a idempotência da marca | US1 | [#271](https://github.com/The-Band-Solution/theband/issues/271) | 2 | F1 | a fazer |
| T004 | Barrar o alcance a outro tenant | US3 | [#272](https://github.com/The-Band-Solution/theband/issues/272) | 2 | F1 | a fazer |
| T005 | Marcar ao fim da coleta do repositório | US1 | [#273](https://github.com/The-Band-Solution/theband/issues/273) | 3 | F2 | a fazer |
| T006 | Não marcar o que não foi olhado | US3 | [#274](https://github.com/The-Band-Solution/theband/issues/274) | 5 | F2 | a fazer |
| T007 | Dizer no log o que deixou de ser declarado | US1 | [#275](https://github.com/The-Band-Solution/theband/issues/275) | 2 | F2 | a fazer |
| T008 | Provar que a lista diz que o vínculo acabou | US2 | [#276](https://github.com/The-Band-Solution/theband/issues/276) | 5 | F3 | a fazer |
| T009 | Conferir no dado real | US1·US2·US3 | [#277](https://github.com/The-Band-Solution/theband/issues/277) | 3 | F4 | a fazer |

**Total: 29 de complexity, nove tarefas.** Um ponto abaixo do sprint 010, e sem migração: a coluna já
existe.

**Quatro das nove asserem ausência de efeito** — T002, T003, T004 e T006. É onde o defeito desta
família aparece, e ele nunca levanta erro.

## O que a análise mudou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | **a marca muda número em outra tela**: 12 dos 52 vínculos sustentam violações da `sro.rule07`, e o painel cai de **293 para 281** | SC-007 na spec, e a quarta conferência em T009 |
| **A2** | **a ordem contra `promover/2` passa a ser carga**: `classification/2` conta só vigentes, e promover antes de marcar classificaria épico por parte que a origem largou | declarada em T005 e no `@moduledoc` da coleta |
| **A3** | **FR-014 sem tarefa**, e ele era testável | asserção em T006: `refused_links` intacta depois da coleta |
| **A4** | **T008 bloqueada**, não pendente: exige código que está em PR não incorporado | resolvido empilhando a branch sobre a da feature 011 |

**E o plano tinha achado dois antes disso, os dois por ler o código**: o FR-002 pedia gravar o
`started_at` na marca, contra a convenção das três irmãs; e o FR-013 pedia número novo na tela de
sincronizações, que é o caso concreto do princípio X.

**Sétima feature seguida em que a fase de análise acha defeito de desenho** que nenhum teste de
unidade pegaria.

## Escopo confirmado

**Feature 012 completa — F1 a F4, T001 a T009.**

T001 sozinha é função sem consumidor, e a **L21** diz que isso não é funcionalidade entregue. O corte
possível seria T001 + T005 — o MVP —, e o que ele não entrega é a prova de que a coleta que falhou
não marca nada, que é a US3.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| `order_by` em `fetch_parent/2` | é a [#261](https://github.com/The-Band-Solution/theband/issues/261), e é outra tela |
| filha promovida a defeito no detalhe do pai | é a [#262](https://github.com/The-Band-Solution/theband/issues/262), e é outra tela |
| marcar recusa (`refused_links`) como ausente | recusa nunca foi vínculo afirmado — FR-014 manda **não** tocar |
| generalizar as quatro marcações de ausência | os cortes não são iguais: um é por data, dois são por lista |
| campo novo em `syncs` para contar o que a coleta marcou | número ao lado de números que respondem outra pergunta |
| corrigir as decomposições na origem | a plataforma observa; corrigir é decisão do time |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **marcar o que não foi olhado** — a L19 e a L29 juntas | escopo por repositório na assinatura; T006 assere zero em três cenários de falha |
| marcar os **57** vínculos entre repositórios ao coletar a filha | o escopo é o repositório do **pai**; T006 monta o caso |
| **cortar por "agora"** e marcar o que a própria execução gravou | o corte é `ctx.started_at`; T001 monta o caso do vínculo gravado durante a execução |
| marcar antes de `vincular/2` | T005 fixa a ordem, e o `@moduledoc` passa a declará-la |
| **promover antes de marcar** e classificar épico por parte largada | a marca é dentro de `coletar_issues/2`, e `promover/2` roda depois de todos os repositórios |
| reescrever a data de quem já estava marcado | `is_nil(...)` no `WHERE`; T003 compara o mapa de datas antes e depois |
| **T008 sem o código da feature 011** | a branch foi empilhada sobre a 015; se o #264 for alterado na review, esta branch rebasa |
| a prova no dado real ficar pendente | está declarada como pendente em T009, e exige a chave mestra — nunca contada como cumprida |

## Definition of Done do sprint

- [ ] `mix gates` verde por **código de saída** — nunca com `| tail`
- [ ] base de conhecimento válida
- [ ] as nove issues encerradas ou repriorizadas com justificativa
- [ ] PR aberto com revisão pedida à equipe `the-band` e item no projeto
- [ ] `aceitacao.md` avaliando os 14 FR e os 7 SC um a um
- [ ] `sprint-review.md` escrito **neste sprint**, não no seguinte — L44
- [ ] `licoes-aprendidas.md` atualizado
