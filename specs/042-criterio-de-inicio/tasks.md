# Tasks: O critério de início, declarado pela organização

**Feature**: 042 · **Branch**: `042-criterio-de-inicio` · **Data**: 2026-08-24
**Spec**: [spec.md](./spec.md) · **Plano**: [plan.md](./plan.md) · **Fecha**: [#370](https://github.com/The-Band-Solution/theband/issues/370)

## Bloqueio — liberado em 2026-08-24

A `FR-007` opera sobre `spo_project_boards.linked_at`, criada na feature 041. O [PR #458](https://github.com/The-Band-Solution/theband/pull/458) foi **mergeado** em 2026-08-24 (`c497b91`), e a tabela está na `main`. Nenhum bloqueio pendente.

---

## Fase 1 — Base de conhecimento

O conceito entra na rede **antes** do código. Não é ordem cerimonial: os gates reprovam se o YAML faltar, e o esquema referencia um conceito que precisa existir.

- [x] T001 Declarar o critério na rede — [#459](https://github.com/The-Band-Solution/theband/issues/459)
  - **Pronta quando**: nada além do repositório — `SPO` já declara `dependencies: [ufo, eo]`, conferido em research.md R1
  - **Descrição**: criar `priv/knowledge_base/ontology/seon/spo/modules/activity_start_criterion.yaml` com `spo.activity_start_criterion` classificado como `ufo_category: social_object`, `ontouml_stereotype: kind`. A definição MUST registrar que qual evento marca o início é **convenção social** e não fato observado — FR-001, research.md R2. Acrescentar o módulo à lista `modules:` de `ontology.yaml`
  - **Feita quando**: `mix knowledge.validate` aceita a base; o conceito aparece em `docs/ontology/concept-index.md` depois de regenerar; a contagem de conceitos da rede sobe em um
  - **Teste**: `mix knowledge.validate` sai com código 0, e `grep spo.activity_start_criterion docs/ontology/spo.md` encontra a definição

- [x] T002 Declarar as relações do critério — [#460](https://github.com/The-Band-Solution/theband/issues/460)
  - **Pronta quando**: T001 concluída
  - **Descrição**: no mesmo módulo, `spo.criterion_recognises` (critério → `ufo.event`, muitos-para-um) e as relações de alvo. **A relação com o quadro NÃO existe na rede** — `observed_projects` é tabela de coleta, não conceito de domínio —, e isso MUST ficar escrito como limitação declarada no YAML, e não contornado com um conceito inventado. FR-002, data-model.md
  - **Feita quando**: as relações aparecem no grafo; a limitação sobre o quadro está escrita no YAML, com a razão
  - **Teste**: `mix knowledge.graph` gera sem erro de referência pendente, e a limitação é legível em `docs/ontology/spo.md`

- [x] T003 Regenerar a documentação derivada — [#461](https://github.com/The-Band-Solution/theband/issues/461)
  - **Pronta quando**: T001 e T002 concluídas
  - **Descrição**: `.venv/bin/python scripts/generate_docs.py`. Commitar o que ele produz. **Regenerar não é opcional** — a lição L68 e a issue #450 mostram o custo: a página afirmou 12 ontologias por nove features enquanto a base tinha 13
  - **Feita quando**: `git status` fica limpo depois de rodar o gerador uma segunda vez
  - **Teste**: rodar o gerador duas vezes seguidas e conferir que a segunda não produz diff

---

## Fase 2 — Esquema (bloqueia todas as histórias)

- [x] T004 Criar a tabela do critério — [#462](https://github.com/The-Band-Solution/theband/issues/462)
  - **Pronta quando**: T002 concluída (o PR #458 já foi mergeado)
  - **Descrição**: migração `spo_activity_start_criteria` conforme data-model.md — `tenant_id` obrigatório, `project_id` e `observed_project_id` ambos nulos, `event_type` cru, autor e data de declaração e de revogação. `event_type` **sem enum**: a origem nomeia os eventos, e congelar a lista faria a plataforma recusar um evento novo do GitHub como se fosse erro
  - **Feita quando**: `mix ecto.migrate` e `mix ecto.rollback` completam nos dois sentidos; o `@moduledoc` da migração diz por que o alvo é polimórfico e o que isso custa
  - **Teste**: `mix ecto.migrate && mix ecto.rollback && mix ecto.migrate` — a ida e a volta, não só a ida

- [x] T005 Impedir alvo duplo e critério vigente duplicado — [#463](https://github.com/The-Band-Solution/theband/issues/463)
  - **Pronta quando**: T004 concluída
  - **Descrição**: `CHECK (num_nonnulls(project_id, observed_project_id) = 1)` e dois índices únicos **parciais sobre os vigentes** (`WHERE revoked_at IS NULL`). O parcial é o que permite redeclarar depois de revogar — um índice total impediria, e é o mesmo desenho de `spo_project_repositories`
  - **Feita quando**: inserir linha com os dois alvos é recusado pelo banco; inserir segundo critério vigente para o mesmo alvo é recusado; inserir depois de revogar o anterior é aceito
  - **Teste**: `test/the_band/ontology/seon/spo/criterio_de_inicio_test.exs` — três casos de violação, cada um esperando `Ecto.ConstraintError` ou changeset inválido, e um caso de redeclaração aceita

---

## Fase 3 — História 1 (P1): declarar o critério do projeto

**Objetivo**: quem administra declara, e as atividades do projeto ganham instante de início.

**Teste independente**: declarar num projeto sem quadros e conferir que as atividades dele ganham início — e que as de outro projeto continuam sem.

- [x] T006 [US1] Schema do critério — [#464](https://github.com/The-Band-Solution/theband/issues/464)
  - **Pronta quando**: T005 concluída; `contracts/criterio.md` escrito
  - **Descrição**: `lib/the_band/ontology/seon/spo/schemas/activity_start_criterion.ex`, com changeset validando o alvo exclusivo e o `unique_constraint` nomeando os dois índices parciais. O `@moduledoc` explica por que o conceito é `social_object` — quem lê o schema não vai ler a spec
  - **Feita quando**: changeset com dois alvos é inválido; changeset sem alvo nenhum é inválido; changeset com um alvo é válido
  - **Teste**: casos de changeset no arquivo de teste da feature, os três estados do alvo

- [x] T007 [US1] Declarar e revogar — [#465](https://github.com/The-Band-Solution/theband/issues/465)
  - **Pronta quando**: T006 concluída
  - **Descrição**: `lib/the_band/ontology/seon/spo/start_criterion.ex` com `declare_start_criterion/4` e `revoke_start_criterion/3`, conforme `contracts/criterio.md`. O alvo é **tupla marcada** — `{:project, id}` ou `{:board, id}` —, e redeclarar **revoga a anterior e cria a nova na mesma transação**, nunca `update`: a FR-010 manda preservar quem declarou antes. Tipo desconhecido devolve `{:error, :unknown_event_type}`, e não levanta — princípio VIII, erro previsto é retorno
  - **Feita quando**: declarar duas vezes deixa duas linhas, uma revogada; revogar preenche autor e data e não apaga; tipo inexistente devolve erro sem levantar
  - **Teste**: caso que declara, redeclara e conta as linhas — `Repo.aggregate(..., :count) == 2` com uma revogada. E caso que afirma `{:error, :unknown_event_type}` sem `rescue`

- [x] T008 [US1] Delegar na fachada SPO — [#466](https://github.com/The-Band-Solution/theband/issues/466)
  - **Pronta quando**: T007 concluída
  - **Descrição**: `defdelegate` em `lib/the_band/ontology/seon/spo.ex` — a fachada contém apenas delegação, ADR 0003. Foi exatamente isto que faltou na feature 041 e produziu `UndefinedFunctionError` com a função existindo
  - **Feita quando**: as funções respondem por `SPO.` e não só por `SPO.StartCriterion.`
  - **Teste**: os testes da feature chamam por `SPO.`, nunca pelo módulo interno

- [x] T009 [US1] Resolver o início em lote — [#467](https://github.com/The-Band-Solution/theband/issues/467)
  - **Pronta quando**: T007 concluída; `contracts/criterio.md` define o retorno
  - **Descrição**: `resolve_start/2` — recebe **lista** de issues, devolve mapa. Nunca uma issue por chamada: com 19.200 atividades a versão unitária é N+1, e a decisão 2 do plano só se sustenta em lote. O retorno carrega a **origem** junto do instante (`{:board, id, title}` ou `{:project, id, name}`), porque a FR-013 exige que a tela diga de onde o critério veio, e devolver só o `DateTime` tornaria isso impossível sem segunda consulta. Vale a **primeira** ocorrência do evento — FR-011
  - **Feita quando**: uma issue resolvida devolve instante **e** origem; o número de consultas não cresce com o número de issues; a segunda ocorrência do evento na mesma issue é ignorada
  - **Teste**: caso com 1 e com 50 issues afirmando o **mesmo número de consultas**, usando o mesmo padrão do teste de custo que `verification` já tem

- [x] T010 [US1] Nomear as três ausências — [#468](https://github.com/The-Band-Solution/theband/issues/468)
  - **Pronta quando**: T009 concluída
  - **Descrição**: `resolve_start/2` devolve `{:missing, :sem_criterio}`, `{:missing, {:criterio_ambiguo, quadros}}` e `{:missing, {:evento_nao_coletado, tipo}}` — **valores distintos, nunca `nil`**. `nil` colapsaria as três, e a FR-009 proíbe agregá-las. O ambíguo carrega os quadros com título e `linked_at`, porque a FR-016 manda nomeá-los
  - **Feita quando**: as três ausências são distinguíveis no retorno; o ambíguo traz os quadros em empate; nenhum caminho devolve `nil` para ausência
  - **Teste**: três casos, um por ausência, afirmando o valor exato — e um caso afirmando que **nenhuma** delas é `nil`

- [x] T011 [US1] Listar os tipos de evento com volume — [#469](https://github.com/The-Band-Solution/theband/issues/469)
  - **Pronta quando**: T007 concluída
  - **Descrição**: `collected_event_types/1` devolve os tipos que a coleta tem, com contagem, ordenados por volume — FR-012. **Não recomenda**: devolver "sugerido" faria a plataforma escolher com passos extras, e a FR-007 da feature 022 proíbe
  - **Feita quando**: a lista traz só tipos presentes em `spo_performed_project_activities` do tenant; cada um com sua contagem; nenhum campo de sugestão
  - **Teste**: caso afirmando que um tipo ausente do tenant **não** aparece, e que a ordenação é por volume decrescente

- [x] T012 [US1] Declarar o critério na tela do projeto — [#470](https://github.com/The-Band-Solution/theband/issues/470)
  - **Pronta quando**: T008 e T011 concluídas
  - **Descrição**: seção em `lib/the_band_web/live/projects_live/index.ex`, junto do alvo — princípio X. Mostra o critério vigente, a lista de tipos **com volume**, e o botão de revogar
  - **Feita quando**: declarar grava com autor; a lista mostra os volumes; revogar volta ao estado sem critério
  - **Teste**: `test/the_band_web/live/criterio_na_tela_test.exs` — o HTML contém o volume de pelo menos um tipo, e depois de declarar contém o tipo declarado

- [x] T013 [US1] Contar as atividades sem instante — [#471](https://github.com/The-Band-Solution/theband/issues/471)
  - **Pronta quando**: T010 e T012 concluídas
  - **Descrição**: a tela do projeto informa **quantas** atividades estão sem instante de início e **por qual** das três ausências — FR-004, FR-009. Nunca um total agregado
  - **Feita quando**: a contagem aparece separada por ausência; declarar um critério reduz a de `sem_criterio` na leitura seguinte
  - **Teste**: caso que abre a tela, afirma a contagem, declara, reabre e afirma a contagem menor — **sem nenhuma etapa de recálculo entre as duas**

---

## Fase 4 — História 2 (P1): o quadro vence o projeto

**Objetivo**: um projeto com quadros de processos diferentes mede cada um pelo seu.

**Teste independente**: critérios diferentes no projeto e num quadro dele; as issues daquele quadro seguem o do quadro, as demais o do projeto.

- [x] T014 [US2] Aplicar a escala de precedência — [#472](https://github.com/The-Band-Solution/theband/issues/472)
  - **Pronta quando**: T009 concluída
  - **Descrição**: em `resolve_start/2`, a ordem **quadro que declarou → projeto que declarou → nulo** — FR-006. Quadro **sem** critério não vence: ele só entra na escala quando declarou
  - **Feita quando**: issue em quadro com critério segue o do quadro; issue em quadro sem critério segue o do projeto; issue fora de quadro segue o do projeto
  - **Teste**: três casos, um por ramo, com critérios propositalmente **diferentes** entre projeto e quadro para que a troca seja detectável

- [x] T015 [US2] Declarar o critério na tela do quadro — [#473](https://github.com/The-Band-Solution/theband/issues/473)
  - **Pronta quando**: T012 e T014 concluídas
  - **Descrição**: a mesma seção, agora por quadro, na lista de quadros que a feature 041 criou. O alvo muda; a interação não
  - **Feita quando**: declarar num quadro não altera o critério do projeto; os dois aparecem simultaneamente na tela, distinguíveis
  - **Teste**: caso que declara nos dois e afirma que a tela mostra ambos, com o do quadro marcado como prevalecente

- [x] T016 [US2] Avisar quais quadros vão ignorar a declaração — [#474](https://github.com/The-Band-Solution/theband/issues/474)
  - **Pronta quando**: T015 concluída
  - **Descrição**: `boards_overriding/2` e o aviso na tela — ao declarar no projeto, a tela nomeia **quais quadros vão ignorar** esta declaração, **antes de gravar** — FR-014. Depois de gravar seria informação inútil
  - **Feita quando**: o aviso aparece antes da gravação e nomeia os quadros; não aparece quando nenhum quadro tem critério próprio
  - **Teste**: caso que declara num quadro, abre a declaração do projeto, e afirma que **o título daquele quadro** está no HTML antes de qualquer gravação

---

## Fase 5 — História 3 (P2): desempatar entre quadros

**Objetivo**: as 414 issues em mais de um quadro (13% do dado) recebem instante.

**Teste independente**: issue em dois quadros com critérios diferentes segue o do vínculo mais recente.

- [x] T017 [US3] Desempatar pela data do vínculo — [#475](https://github.com/The-Band-Solution/theband/issues/475)
  - **Pronta quando**: T014 concluída
  - **Descrição**: quando a issue está em mais de um quadro com critério, vence o de `spo_project_boards.linked_at` **maior** — FR-007. `collected_at` **não serve**, e a razão está medida em research.md R3: empata em 0,0 s em 100% dos 414 casos, e significa "quando nós olhamos"
  - **Feita quando**: o critério do vínculo mais recente prevalece; trocar a ordem de associação troca o resultado
  - **Teste**: caso com dois quadros de `linked_at` distintos, afirmando o vencedor — e depois revertendo a ordem e afirmando que o vencedor mudou

- [x] T018 [US3] Nomear o empate em vez de escolher — [#476](https://github.com/The-Band-Solution/theband/issues/476)
  - **Pronta quando**: T017 concluída
  - **Descrição**: `linked_at` iguais devolvem `{:missing, {:criterio_ambiguo, quadros}}` — FR-008. A plataforma **MUST NOT** desempatar por conta própria: escolher o primeiro faria exatamente o que a FR-007 da feature 022 proíbe, num lugar onde ninguém procuraria
  - **Feita quando**: dois vínculos com a mesma data devolvem ambíguo; o retorno traz os dois quadros com título e data
  - **Teste**: caso com `linked_at` idênticos afirmando `criterio_ambiguo` e **os dois títulos** no retorno — nunca um instante

- [x] T019 [US3] Listar as pendências de desambiguação — [#477](https://github.com/The-Band-Solution/theband/issues/477)
  - **Pronta quando**: T018 e T013 concluídas
  - **Descrição**: a tela lista as issues em estado ambíguo, com os quadros em empate e a data — para quem administra resolver. É trabalho, não erro
  - **Feita quando**: a lista aparece só quando há ambíguas; cada linha nomeia os quadros e a data; a lista some quando o empate é desfeito
  - **Teste**: caso que cria o empate, afirma a linha na tela, desassocia um quadro e afirma que a linha sumiu

---

## Fase 6 — As regras na tela

Pedido da pessoa mantenedora: *"coloque essas regras nas telas para o usuário entender"*. Uma escala que decide um número e vive só na spec produz o efeito que esta casa combate.

- [x] T020 A proveniência acompanha o número — [#478](https://github.com/The-Band-Solution/theband/issues/478)
  - **Pronta quando**: T014 concluída
  - **Descrição**: toda tela que mostre instante de início diz **de onde o critério veio** — do quadro (e qual) ou do projeto (e qual) — FR-013. Não é página de ajuda: fica junto do número
  - **Feita quando**: o instante nunca aparece sozinho; a origem é clicável para o alvo que a declarou
  - **Teste**: caso afirmando que o HTML contém o título do quadro ou o nome do projeto na mesma linha do instante

- [x] T021 As ausências viram frase — [#479](https://github.com/The-Band-Solution/theband/issues/479)
  - **Pronta quando**: T013 e T019 concluídas
  - **Descrição**: as três ausências escritas em frase, **nunca em código** — FR-015. E cada frase diz **o que fazer**: declarar, desambiguar, ou coletar
  - **Feita quando**: nenhum código de motivo é renderizado; cada frase termina com uma ação
  - **Teste**: **a violação, não o caminho feliz** — `refute html =~ "criterio_ambiguo"` e `refute html =~ "sem_criterio"` nas três telas. É a `SC-008`

- [x] T022 Explicar o desempate no ponto da decisão — [#480](https://github.com/The-Band-Solution/theband/issues/480)
  - **Pronta quando**: T016 e T021 concluídas
  - **Descrição**: uma frase, onde o desempate é aplicado, dizendo **por que** é a data do vínculo e o custo de errar — FR-017. Regra de precedência que ninguém entende é obedecida sem ser conferida
  - **Feita quando**: a explicação está junto da lista de pendências e da declaração de quadro; não está numa página separada
  - **Teste**: caso afirmando que a explicação aparece na tela de pendências, e revisão humana de que ela é compreensível — `SC-007`, que teste automatizado não substitui

---

## Fase 7 — Fechamento

- [x] T023 Quality gates verdes — [#481](https://github.com/The-Band-Solution/theband/issues/481)
  - **Pronta quando**: todas as tarefas de implementação concluídas
  - **Descrição**: `mix gates` — os treze, e **nunca** com `| tail` nem `| grep`: o veredito é o código de saída, e o pipe devolve o do `tail`. Lição L23
  - **Feita quando**: o comando sai com código 0
  - **Teste**: `mix gates > /tmp/g.log 2>&1; ec=$?; tail -30 /tmp/g.log; exit $ec`

- [x] T024 Percorrer o quickstart a mão — [#482](https://github.com/The-Band-Solution/theband/issues/482)
  - **Pronta quando**: T023 concluída
  - **Descrição**: os sete passos de [quickstart.md](./quickstart.md), incluindo o que nenhuma suíte cobre — a `SC-007`, se a frase ensina quem nunca leu a spec
  - **Feita quando**: os sete passos produziram o esperado, e o que divergiu virou defeito registrado ou correção de spec
  - **Teste**: o registro do percurso, passo a passo, com o que apareceu na tela — no formato de `specs/027-geracao-mensal-de-perfis/percurso-t026.md`

---

## Dependências

```
Fase 1 (rede)  ─→ Fase 2 (esquema) ─→ US1 ─→ US2 ─→ US3 ─→ Fase 6 ─→ Fase 7
                        ↑
                  PR #458 mergeado
```

**US2 depende de US1**, e não é independente: a escala precisa de algo para ordenar. **US3 depende de US2** pela mesma razão. A independência que o template pede não existe aqui, e forçá-la produziria tarefas que não entregam nada sozinhas.

## Paralelismo

| podem ir juntas | por quê |
|---|---|
| T001 e T004 | YAML e migração são arquivos diferentes, e o PR #458 já está mergeado |
| T011 e T009 | listar tipos não depende de resolver |
| T020, T021 e T022 | telas diferentes, depois de a resolução existir |

O resto é sequencial por dependência real, não por conveniência.

## Escopo mínimo

**US1 sozinha entrega valor**: um projeto declara, e as atividades dele ganham instante. As três medidas paradas destravam para projetos sem quadro ou de quadro único — **2.801 das 3.215 issues (87%)**.

US2 e US3 cobrem os 13% restantes, e US3 é a que resolve as 414.

## Total

**24 tarefas** · US1: 8 · US2: 3 · US3: 3 · rede: 3 · esquema: 2 · telas: 3 · fechamento: 2
