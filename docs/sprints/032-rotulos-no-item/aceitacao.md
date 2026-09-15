# Sprint 032 — Registro de aceitação

**Feature**: [065 — o rótulo como campo do item de trabalho](../../../specs/065-rotulos-no-item/spec.md)
**Avaliado em**: 2026-09-13, na `development` em `0ccf02b` (PRs #907 e #908 mergeados), com
evidência executada nesta avaliação — testes nomeados, sondas de tela sobre cenário real, e
consultas só-leitura ao banco de desenvolvimento.
**Papel**: Product Owner — avaliação **proposta pelo agente** no papel `sro.product_owner_role`,
publicada como comentário em cada issue de user story em 2026-09-13
([#904](https://github.com/The-Band-Solution/theband/issues/904#issuecomment-5656207868),
[#905](https://github.com/The-Band-Solution/theband/issues/905#issuecomment-5656210973),
[#906](https://github.com/The-Band-Solution/theband/issues/906#issuecomment-5656213669)).
**Confirmação pela pessoa alocada ao papel: PENDENTE.** Nenhuma issue foi fechada.
**Tipo de PO**: `sro.product_owner_client` — quem demanda é quem mantém.
**Regra**: `sro.rule03` — a fase decorre dos critérios, com evidência executada; critério sem
evidência não vira aceito.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 3 |
| Aceitos | 1 (US3 — pendente de confirmação e da revisão do #907) |
| Não aceitos | 2 (US1, US2) |
| Critérios avaliados | 37 — 26 conformes · 7 não conformes · 2 ambíguos · 2 não medidos |
| Tarefas executadas com sucesso | 6 (T001, T002, T003, T004, T006, T008) + 4 sem user story (T009, T010, T013, T014) |
| Tarefas executadas sem sucesso | 4 (T005, T007 pelo D1; T011, T012 pelo D2) |

**As duas recusas têm naturezas diferentes.** A US1 recusa por **defeito medido** — o detalhe
não cumpre o que a listagem cumpre — e por dois critérios sem evidência. A US2 recusa por algo
**anterior ao código**: a spec e o mecanismo chamam coisas diferentes de "rótulo", e o exemplo
da US não é divergência para a plataforma. Reescrever a tela sem decidir isso seria retrabalho
anunciado.

### Evidência executada, comum aos três

| comando | saída | código |
|---|---|---:|
| `mix test test/the_band/work_items/rotulos_na_listagem_test.exs` | 7 passed | 0 |
| `mix test test/the_band/work_items/prefixo_vira_rotulo_test.exs` | 9 passed | 0 |
| `mix test test/the_band/work_items/divergencia_com_rotulo_test.exs` (prometido pela T011) | **arquivo não existe** | — |
| sonda do papel — `/work` e o detalhe renderizados sobre `cenario_real/1`, HTML impresso | 6/9 — as 3 falhas são da US2 e de um marcador da sonda | 2 |
| sonda do papel, parte 2 — `WorkItems.decide/2` com e sem prefixo; promoção divergente fabricada | 3 passed | 0 |
| `mix run --no-start` só-leitura (Repo + KnowledgeBase, sem Oban) + `psql` via `docker exec` no `the_band_dev` | contagens abaixo | 0 |
| `mix gates` — **não rerodado**; CI run [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) sobre `0ccf02b` | success | — |

As sondas são instrumento do papel e não ficam no repositório.

---

## D1 — Os rótulos na lista, com a origem de cada um

**Produzido por**: 065/T001–T003, T005–T007 · [#890](https://github.com/The-Band-Solution/theband/issues/890),
[#891](https://github.com/The-Band-Solution/theband/issues/891), [#892](https://github.com/The-Band-Solution/theband/issues/892),
[#894](https://github.com/The-Band-Solution/theband/issues/894), [#895](https://github.com/The-Band-Solution/theband/issues/895),
[#896](https://github.com/The-Band-Solution/theband/issues/896) · PR [#907](https://github.com/The-Band-Solution/theband/pull/907)
**Materializa**: 065/US1 — ver, na lista, como o time chamou cada item · [#904](https://github.com/The-Band-Solution/theband/issues/904) · P1

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — rótulo do campo na linha, com a marca de **observado** | funcional | sim | HTML da linha `#2`: `bg-success text-success-content`, `title="observed — set on the label field at the source"` envolvendo `backend` |
| AC2 — prefixo reconhecido vira rótulo **derivado**, distinguível **sem cor** | funcional | sim | mesma linha: `Back-end` com `outline` + `repeating-linear-gradient(135deg…)` (forma) e `title="derived — read from the bracketed prefix in the title"` (texto) |
| AC3 — item sem rótulo diz **ausência** escrita | funcional | sim | linha `#3`: `<span class="text-xs italic opacity-60">no label</span>`; nunca célula vazia |
| AC4 / FR-013 / SC-005 — consultas não crescem com as linhas | não funcional | sim | teste T003: 1 consulta para 10 e para 100 (`assert cem == 1`); banco real: **1 consulta** para 10, 100 e 1 000 itens |
| **Teste independente** — "os mesmos rótulos aparecem ao abrir cada item" | funcional | **não** | issue `[Devops] …` com rótulo `backend`: `/work` mostra `backend` (observado) **e** `Devops` (derivado); `/work/issues/:id` mostra só `backend`, como `badge-ghost`, **sem origem e sem o derivado** |
| FR-001 — rótulos na **listagem e no detalhe** | funcional | listagem sim · **detalhe não** | mesma evidência: o detalhe expõe só os do campo |
| FR-002 — o rótulo declara **de onde veio** | funcional | listagem sim · **detalhe não** | `Rotulos.de/2` devolve `origem: :campo \| :titulo` (teste); na tela, `title` por origem; o campo `labels` do detalhe não declara nada |
| FR-003 — distinção sem cor | não funcional | sim, na listagem | forma (sólido × hachura+contorno) **e** texto (`title`), medidos no HTML |
| FR-004 — só prefixos da lista declarada | funcional | sim | teste: `[Portal ADM]` (68 issues reais) e `[Qualquer Coisa]` → `nil` |
| FR-005 — a lista vive junto da recusa, sem repetição | não funcional | sim | `Mapping.prefixos_recusados_como_tipo/0` devolve os 8 de `not_type_patterns` da base carregada; `grep` em `lib/` e `priv/knowledge_base/`: nenhum literal fora do catálogo. **Sem o teste prometido** de acrescentar prefixo e vê-lo aparecer |
| FR-006 — prefixo de tipo não vira rótulo | funcional | sim | teste: `[TASK]`, `[FEATURE]`, `[BUG]` → `nil` |
| FR-010 / SC-007 — ausência escrita | funcional | sim | `no label` na linha; **2 811 das 5 033** issues reais caem nesse caso |
| FR-012 / SC-006 — mesma ordem a cada leitura | não funcional | sim | teste (duas leituras idênticas; `ORDER BY` dentro do `array_agg`); banco real: duas leituras de 5 033 linhas idênticas |
| SC-001 — rótulos de **todos** os itens visíveis sem abrir nenhum | funcional | sim | 50 linhas na página, 50 com rótulo ou ausência escrita |
| SC-002 — "as 1 519 issues com prefixo passam a ter rótulo consultável" | funcional | **mecanismo sim; número não reproduz** | pela função entregue sobre os títulos reais: **1 489** derivam (`Devops` 369 · `Back-end` 316 · `Front-end` 303 · `Dados` 267 · `QA` 113 · `Backend` 83 · `Front` 35 · `Infra` 3). Com `ILIKE` seriam 1 536: **47** variantes de caixa não derivam. 1 519 não é nenhum dos dois |
| SC-003 — origem acertada em 100%, inclusive em **tons de cinza** | não funcional | **não medido** | exige a tela renderizada; a T013 leu **código**, por quem implementou — não é evidência independente |
| FR-015 — tela **exatamente** a do protótipo aprovado | não funcional | **não medido** | sem captura da tela real, sem `PROMPT.md`; a T013 declara que não olhou a tela renderizada |
| decisões da mantenedora: coluna por **último**; **3 + `+N`** que abre a issue; cor do GitHub **não** usada | funcional | sim | `labels` é a 8ª e última `<td>`; com 5 rótulos a linha mostra `a b c` e `+2` como `<a href="/work/issues/…">`; classe fixa, sem `style` de cor |

**Fase derivada**: **`sro.not_accepted_deliverable`**. Falha no teste independente da própria
US e em FR-001/FR-002 no detalhe; SC-003 e FR-015 sem evidência. A listagem, sozinha, está
conforme em todo critério medido — a recusa é pelo que a US promete e o detalhe não cumpre, e
pelo que ninguém olhou.
**Fase das tarefas**: T005 e T007 → `sro.non_successfully_performed_scrum_development_task`;
T001, T002, T003, T006 → `sro.successfully_performed_scrum_development_task`. Nenhuma issue de
tarefa é reaberta.

**O que falta, exatamente**:

1. o campo `labels` do detalhe (`show.ex`, hoje `badge-ghost` sobre `@issue.labels`) passa a
   usar a mesma gramática da listagem — as duas origens, com marca. **Protótipo primeiro**:
   nenhum dos três aprovados cobre esse campo;
2. conferência do QA da tela real contra o protótipo, com captura, inclusive em tons de cinza
   (SC-003, FR-015), por quem não implementou;
3. decisão da pessoa mantenedora sobre as **47 variantes de caixa** e correção do número da
   SC-002. Recomendação do papel: manter a comparação sensível a caixa — é a do catálogo, e
   normalizar seria a FR-009 aplicada ao nome — e escrever **1 489**;
4. os testes de tela de T005/T007 e o `prefixos_test.exs` de T001, como guarda de regressão.

---

## D2 — A alegação ao lado do veredito

**Produzido por**: 065/T011, T012 · [#900](https://github.com/The-Band-Solution/theband/issues/900),
[#901](https://github.com/The-Band-Solution/theband/issues/901) — **fechadas sem código** no #907,
com a justificativa de que a divergência "já aparece por linha na tabela principal"
**Materializa**: 065/US2 — ver a alegação ao lado do veredito · [#905](https://github.com/The-Band-Solution/theband/issues/905) · P2

**O que o dado real diz antes da tela.** A issue-exemplo da US — `[TASK] Desativar/corrigir o
GitHub Issues Bot…` (`#2`) — tem `issue_type: Bug`, rótulos `["bug", "oráculo", "task"]`,
`declared_concept: osdef.defect`, `derived_concept: osdef.defect`, **`divergence_kind: nil`**.
Para a plataforma ela **não é uma divergência**: divergência aqui é *tipo declarado ×
estrutura*, não *rótulo × conceito*. Nas 512 divergências vigentes do tenant, o tipo é sempre
`user_story_without_parts`; `label_vs_structure` existe em `ConceptLabel` e **nunca é
produzido**. Onde rótulo e conceito discordam de fato — `bug` × tarefa (47), `feature` × tarefa
(69), `enhancement` × tarefa (46) — `divergence_kind` é nulo em todos. E `list_divergences/2`
**não recebeu rótulos**.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 (a) — rótulo e conceito **lado a lado** | funcional | sim | linha `#200` (Bug→defeito, rótulo `task`): `promoted to` = `defect`, `labels` = `task`, na mesma `<tr>` |
| AC1 (b) — **a linha diz que divergem** | funcional | **não** | nenhuma palavra de divergência na linha; no dado real o Bot tem `divergence_kind: nil` |
| AC2 — item sem rótulo entre as divergências diz **"não há o que comparar"** | funcional | **ambíguo** | linha divergente sem rótulo mostra `user story with no parts or tasks` e `no label`. Célula não vazia: sim. Frase "nothing to compare": **não**. Decisão do papel; **348 das 512** divergências reais estão neste caso |
| AC3 — fica claro **qual lado a plataforma seguiu** | funcional | **não, na linha** | só o cartão agregado, **por tipo**, diz `concept kept — signal` / `concept decided by the axiom` |
| FR-014 — mostrar **os dois** e dizer **qual seguiu** | funcional | parcial | os dois: sim; "qual seguiu": só no cartão por tipo |
| SC-008 — alegação e veredito na mesma linha, e qual foi seguido **sem abrir mais nada** | funcional | **não** | mesma evidência de AC1(b)/AC3 |
| Teste independente — item em que rótulo e conceito discordam, tela mostra os dois **e que discordam** | funcional | **não** | mostra os dois; não dá para ver que discordam além de ler e comparar |

**Fase derivada**: **`sro.not_accepted_deliverable`** — falha em AC1(b), AC3, SC-008 e no
teste independente; AC2 aguarda decisão.
**Fase das tarefas**: T011 e T012 → `sro.non_successfully_performed_scrum_development_task`.
O critério da spec não mudou, e o entregável não o atende. **Não reabrir**: nascem tarefas
novas depois das decisões.

**A causa, que precisa de decisão antes de nova tarefa.** A spec escreveu "rótulo" (o *label*
do GitHub) sobre um mecanismo cuja palavra "label" significa *tipo declarado*. O exemplo
escolhido é justamente um caso em que a plataforma **não vê divergência**. Sem decidir isto, a
AC1(b) é inalcançável como escrita:

1. **rótulo × conceito é divergência que a plataforma computa e enuncia?** Se sim, é regra nova
   de derivação — e qual rótulo "nomeia conceito" é interpretação do conteúdo, que a FR-009
   proíbe. Se não, a US2 precisa ser reescrita para *tipo declarado × estrutura*, que é o que
   existe;
2. **a linha diz qual lado foi seguido?** Hoje só o cartão agregado diz — e para
   `user_story_without_parts` o lado seguido é o **declarado** ("concept kept"), o contrário do
   que a AC3 pressupõe;
3. **AC2**: `no label` basta, ou a linha divergente sem rótulo diz "nothing to compare"?

Tela nova em qualquer das respostas → protótipo → código.

---

## D3 — O rótulo nunca vira conceito

**Produzido por**: 065/T004, T008 · [#893](https://github.com/The-Band-Solution/theband/issues/893),
[#897](https://github.com/The-Band-Solution/theband/issues/897) · PR [#907](https://github.com/The-Band-Solution/theband/pull/907)
**Materializa**: 065/US3 — o rótulo nunca vira conceito · [#906](https://github.com/The-Band-Solution/theband/issues/906) · P1

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — item tarefa ganha rótulo `bug`, classificação continua **tarefa** | funcional | sim | teste T004 (`assert depois == antes`, `refute depois == "osdef.defect"`), saída 0 |
| AC2 — prefixo de área **não participa** da decisão de tipo | funcional | sim | `decide/2`: `Task` + `[Devops] x` = `Task` + `x`; sem tipo + `[Devops] x` = sem tipo + `x` → `skip type_absent`; `Feature`+`[QA] x`+partes `Task` = sem prefixo. Três pares idênticos |
| AC3 — `chave:valor` aparece **como escrito**, nenhum campo preenchido | funcional | sim | teste FR-009 (`prioridade:alta`, `epic:base`, `tipo:infra` literais); tela: `>prioridade:alta<` e `>epic:base<` na linha `#201`; nenhum campo do item derivado de rótulo. Dado real: 48 `prioridade:alta`, 37 `prioridade:media`, 21 `epic:qualidade`, todos texto |
| FR-007 — rótulo nunca altera a classificação | funcional | sim | T004; SC-004; dado real: `bug` × tarefa (47), `feature` × tarefa (69), `epic` × atômica (5) coexistem com `divergence_kind` nulo |
| FR-008 — origens distintas **não unificadas nem normalizadas** | funcional | sim | `Rotulos.de(["backend"], "[Back-end] …")` → 2 elementos; tela: linha `#2` com dois rótulos e dois `title`; dado real `#2212` tem `["backend"]` no campo e `[Back-end]` no título; 238 issues com as duas origens |
| FR-009 — conteúdo do rótulo não interpretado | funcional | sim | idem AC3 |
| SC-004 — qualquer rótulo, **100%** sem mudança | não funcional | sim | sonda: `#1`, `#3`, `#98`, `#200`, `#201` — antes = depois após `bug task feature epic prioridade:alta epic:base` em cada um: 5/5 |
| Teste independente — pôr `bug` num item tarefa, classificação não muda | funcional | sim | T004 |

**Fase derivada**: **`sro.accepted_deliverable`** — 8 de 8 conformes.
**Fase das tarefas**: T004, T008 → `sro.successfully_performed_scrum_development_task`.
**A aceitação não está consumada**: exige (a) a confirmação pela pessoa alocada ao papel, e
(b) revisão pós-merge registrada no #907 por `Adylla027` ou `EduardoNFraiz`, **ou** o atestado
datado da pessoa mantenedora com a exceção registrada — o papel não aceita entregável cujo PR
nasceu sem revisor pedido e fora do projeto. Feitos os dois: `gh issue close 906 --reason completed`.

---

## Critérios alterados durante o sprint

**O escopo da fase 4 (T009, T010) foi reescrito no #908**, depois do #907: as tarefas nasceram
descrevendo a listagem, onde não havia defeito, e passaram a descrever o detalhe. É alteração de
**tarefa**, não de critério da spec — FR-016 e FR-017 não mudaram. A US2 **não** teve o critério
alterado quando T011/T012 foram fechadas sem código; por isso a fase delas é a que é.

## Critérios sem evidência

| Critério | User story | O que falta |
|---|---|---|
| SC-003 — origem acertada em 100%, em tons de cinza | 065/US1 | olhar a tela renderizada, por quem não implementou |
| FR-015 — tela exatamente a do protótipo | 065/US1 | captura ao lado do protótipo; `PROMPT.md` |
| AC2 — "não há o que comparar" | 065/US2 | decisão do papel sobre o que basta |

## Critérios sem user story

FR-011, FR-015, FR-016, FR-017, FR-018, SC-009 e SC-010 não estão presos a nenhuma US — T009 e
T010 não têm `[US]`. Medidos de passagem e conformes no que dava: `#2393` compõe `#205` e `#512`
de dois outros repositórios, com `repositorio` em cada parte; 1 953 vínculos vigentes, 5 cruzam
repositório; régua `border-l-[3px]` para composição e `→` para atendimento. A marca
`other repository` **não foi exercitada em tela**.

## Lacunas de processo

1. **PRs #907 e #908 sem revisor pedido e fora do Projects v2** — zero eventos
   `review_requested`, `reviews` vazio, `projectItems` vazio. É *revisão não pedida*: a pessoa
   mantenedora é `author` de registro e não escreveu o código, logo é revisora legítima; o
   atestado não foi escrito;
2. **o protótipo aprovado não está registrado** como o papel exige — sem
   `specs/065-rotulos-no-item/prototipo/PROMPT.md`, sem item em `docs/backlog/`;
3. **a T013 foi feita por quem implementou**, lendo código — a conferência independente da tela
   não aconteceu;
4. **cinco arquivos de teste prometidos no `tasks.md` não existem** (T001, T005, T007, T011, T012);
5. **este registro foi escrito depois** — o sprint rodou sem `sprint-backlog.md`, e a avaliação
   nasceu como comentário nas issues porque não havia pasta de sprint onde morar.

## O que acontece com as issues, depois da confirmação

**Proposto**, e nada executado até a confirmação:

| Issue | Ação | Razão |
|---|---|---|
| #906 (US3) | **encerrar** | entregável aceito — depois da confirmação **e** da revisão do #907 (ou do atestado com exceção) |
| #904 (US1) | **segue aberta**, com destino | próximo sprint backlog, em primeiro lugar, com as quatro tarefas novas do D1 |
| #905 (US2) | **segue aberta**, com destino | product backlog, até as três decisões do D2 |
| #890–#903 (T001–T014) | **ficam encerradas** | executadas; a fase de T005, T007, T011 e T012 é `non_successfully_performed`, e isto está escrito aqui — encerrar a issue não apaga a fase |

## Destino das user stories

| User story | Issue | Destino |
|---|---|---|
| 065/US1 | [#904](https://github.com/The-Band-Solution/theband/issues/904) | **próximo sprint**, primeira — o detalhe via protótipo, a conferência do QA, a decisão das 47 variantes com o SC-002 corrigido, os testes devidos |
| 065/US2 | [#905](https://github.com/The-Band-Solution/theband/issues/905) | **product backlog** — três decisões antes de qualquer tarefa |
| 065/US3 | [#906](https://github.com/The-Band-Solution/theband/issues/906) | **aceita**, encerrar após confirmação e revisão |
