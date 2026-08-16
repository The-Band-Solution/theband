# Tasks — Perfil de competências e evolução

**Feature**: 026 · **Branch**: `056-perfil-de-competencias`

Cada tarefa tem título curto, `Pronta quando`, `Descrição`, `Feita quando` e `Teste`.
Comando e caminho moram na descrição, nunca no título.

---

## Fase 1 — Base de conhecimento

- [ ] **T001 Declarar a necessidade de informação**
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `priv/knowledge_base/information_needs/people_demonstrated_domains.yaml`,
    no formato dos cinco arquivos existentes. A pergunta é *"em que domínios técnicos há
    evidência de atuação desta pessoa, e como isso mudou?"*; `decision_supported` é indicar
    tarefa e apoiar evolução. `provenance.source_type: project_decision`. Inclui um campo
    dizendo **o que ela não responde** — qualidade, confiabilidade, senioridade. `AGENTS.md`
    §17 proíbe tela sem necessidade declarada
  - **Feita quando**: `mix kb.validate` aceita o arquivo; `docs/metrics/README.md` regenerado
    lista a necessidade nova
  - **Teste**: `mix kb.validate` sai zero; e um teste que carrega a base e afirma que
    `people.demonstrated_domains` existe com `decision_supported` não vazio

- [ ] **T002 Mover os limiares para YAML**
  - **Pronta quando**: T001 concluída
  - **Descrição**: `priv/knowledge_base/rules/profile_thresholds.yaml` com o piso de evidência
    (15 tarefas com corpo), o mínimo por período (5), o critério de destaque (6 tarefas, 2
    períodos, presença no recente), o limiar da linha de base (1,3×) e a idade que torna uma
    tarefa aberta acionável (90 dias). Princípio IV: número que decide o que a tela **afirma**
    não nasce em constante de módulo. Cada valor leva a data e a medição que o originou
  - **Feita quando**: nenhum desses números aparece literal em `lib/`; a base carrega o arquivo
  - **Teste**: `grep -rE "\b(15|90|1\.3)\b" lib/the_band/profiles/` não acha nenhum deles em
    posição de limiar; teste de carga afirma os cinco valores

---

## Fase 2 — O material (sem rede)

- [ ] **T003 Calcular a linha de base do tenant**
  - **Pronta quando**: T002 concluída
  - **Descrição**: `lib/the_band/profiles/baseline.ex` — **uma** consulta agrupada por mês
    sobre `collected_issues`, devolvendo criadas, concluídas, corpo mediano e proporção de
    título tipado. Calculada uma vez por geração, nunca dentro do laço dos períodos — R5
  - **Feita quando**: devolve os 20 meses observados numa consulta só; mês sem issue não vira
    linha com zero, e sim ausência
  - **Teste**: `test/the_band/profiles/baseline_test.exs` — conta as consultas com
    `Ecto.Adapters.SQL.query_count` e afirma **1**; e afirma que mês sem dado não aparece

- [ ] **T004 [US1] Montar o material por pessoa**
  - **Pronta quando**: T003 concluída; contrato em `contracts/perfil-derivado.md` escrito
  - **Descrição**: `lib/the_band/profiles/material.ex` com `build_material/2` conforme o
    contrato. Divide as concluídas em **três períodos por volume** — não por duração, porque
    períodos iguais comparariam 4 tarefas com 90. Traz também as abertas com idade, autoria
    própria por período, e as tarefas compartilhadas. Ordenar datas com `Enum.sort(Date)`: o
    sort padrão sobre `%Date{}` compara campo a campo em ordem alfabética de chave e ordena
    **pelo dia**
  - **Feita quando**: os três erros do contrato são devolvidos distintos; o intervalo de meses
    de cada período está correto
  - **Teste**: `material_test.exs` — um caso por erro; e um caso com datas cruzando ano que
    falharia com `Enum.sort/1` e passa com `Enum.sort(Date)`

- [ ] **T005 [US1] Calcular o veredito da linha de base**
  - **Pronta quando**: T004 concluída
  - **Descrição**: em `material.ex`, comparar a razão de crescimento do corpo da pessoa com a
    do projeto nos mesmos meses, e devolver a **frase pronta**. R6: o modelo errou essa
    divisão na validação — chamou 415 → 814 de "perto de estável". Conta que decide requisito
    não se delega a quem só lê texto
  - **Feita quando**: as três saídas existem — acima, abaixo, acompanhou — e o limiar vem do
    YAML da T002
  - **Teste**: `material_test.exs` — os dados reais do `AndreCoelhoS` (469→833 contra 415→814)
    produzem "ACOMPANHOU"; um caso 3× contra 1,1× produz "ACIMA"

---

## Fase 3 — A borda e o job

- [ ] **T006 Abrir a borda HTTP do provedor**
  - **Pronta quando**: contrato escrito
  - **Descrição**: `lib/the_band/integrations/llm/http.ex` como behaviour e `.../http/req.ex`
    como implementação, espelhando `GitHub.HTTP`. `{:error, {:empty_response, _}}` é ramo
    próprio: 200 com texto vazio não é sucesso. A chave vem de `API_KEY` e **toda** mensagem
    de erro passa por filtro que a substitui — provedores devolvem a chave dentro do texto de
    alguns erros
  - **Feita quando**: `impl/0` devolve o Mox em teste; nenhum caminho imprime a chave
  - **Teste**: `llm_http_test.exs` com Mox — um caso por ramo de erro; e um caso que injeta a
    chave na mensagem do provedor e afirma que ela **não** aparece na saída

- [ ] **T007 [US1] Limpar o resumo**
  - **Pronta quando**: T006 concluída
  - **Descrição**: `lib/the_band/profiles/sanitizer.ex` com `clean_summary/1`. Corta no
    primeiro subtítulo **depois do título** — o título é ele próprio um cabeçalho, e cortar na
    primeira ocorrência deixa o resumo vazio e a limpeza sem efeito, sem erro. Remove grupos
    entre parênteses, enumerações soltas, o conectivo órfão e o parêntese vazio. Devolve
    quantas saíram
  - **Feita quando**: o resumo sai sem `#`, sem frase terminando em conjunção, e a contagem
    bate
  - **Teste**: `sanitizer_test.exs` usando **o texto real** da validação de 2026-08-15 — o
    parágrafo com 17 citações, o `( no resumo do período 3)` e o `, como.` que a primeira
    versão da limpeza deixou

- [ ] **T008 [US1] Compor o prompt a partir do YAML**
  - **Pronta quando**: T002 e T004 concluídas
  - **Descrição**: `lib/the_band/profiles/prompt.ex` — lê o texto do prompt de
    `priv/knowledge_base/` e injeta o material. As regras que o prompt carrega (sem gênero,
    só `#<número>` de tarefa presente, resumo sem citação) são as `FR-005`, `FR-008` e
    `FR-010`, e mudá-las é mudar requisito
  - **Feita quando**: o prompt montado contém o veredito da T005 e o recorte da T004
  - **Teste**: `prompt_test.exs` — afirma que o material aparece, que o veredito aparece, e
    que o prompt não é lido de string embutida no módulo

- [ ] **T009 [US1] Gerar em trabalho de fundo**
  - **Pronta quando**: T006, T007, T008 concluídas
  - **Descrição**: `lib/the_band/profiles/generate_worker.ex`, fila `perfis`. Monta, chama,
    limpa, grava. R4: a chamada levou de 25 a 60 s na validação, e segurar o LiveView
    prenderia a aba. Resposta vazia é falha e **não** vira perfil — `FR-022`
  - **Feita quando**: falha do provedor deixa o perfil anterior intacto; sucesso grava com
    proveniência completa
  - **Teste**: `generate_worker_test.exs` com Mox — um caso de sucesso, um de 429, um de 200
    vazio; o último afirma que **nada** foi gravado

---

## Fase 4 — Persistência

- [ ] **T010 Criar a tabela somente-acréscimo**
  - **Pronta quando**: `data-model.md` escrito
  - **Descrição**: migração de `eo_person_profiles` conforme o data model, com o recorte de
    entrada em colunas e `check` de corpo não vazio. Referencia `person_id`, e **não** o login
  - **Feita quando**: `mix ecto.migrate` e rollback funcionam; o `check` rejeita corpo vazio
  - **Teste**: ida e volta da migração; e um `insert` com corpo vazio que a constraint recusa

- [ ] **T011 Comando e consulta do perfil**
  - **Pronta quando**: T010 concluída
  - **Descrição**: `lib/the_band/ontology/seon/eo/schemas/person_profile.ex` e
    `.../eo/profiles.ex` conforme o contrato, expostos por `defdelegate` na fachada `eo.ex`.
    Toda consulta filtra por `tenant_id`
  - **Feita quando**: `current_profile/2` devolve o mais recente; `list_profiles/2` devolve
    todos em ordem; gravar duas vezes não apaga a primeira
  - **Teste**: `profiles_test.exs` — duas gerações e as duas continuam legíveis; e um caso de
    isolamento entre tenants

---

## Fase 5 — A tela

- [ ] **T012 [US1] [US2] A aba, com os três estados**
  - **Pronta quando**: T009 e T011 concluídas
  - **Descrição**: aba em `lib/the_band_web/live/people_live/show.ex`. Três estados com três
    frases diferentes: **nunca gerado**, **pedido e ainda não pronto**, **falhou**. O bloco do
    perfil usa `<.evidence>` e sai hachurado com rótulo em texto — cor sozinha reprova em WCAG
    1.4.1 e desfaz o produto. Modelo, data e recorte aparecem **antes** do texto
  - **Feita quando**: os três estados são distinguíveis por texto; números observados aparecem
    sólidos e distintos do texto derivado
  - **Teste**: `perfil_test.exs` — um caso por estado, cada um afirmando a frase própria; e um
    caso que afirma que o rótulo "derived" aparece **em texto**, não só em classe CSS

- [ ] **T013 [US2] Recusar abaixo do piso**
  - **Pronta quando**: T012 concluída
  - **Descrição**: com material abaixo do piso, a aba não oferece geração e diz os números. A
    frase atribui a falta ao **registro** — `FR-019`. Os três erros da `build_material/2`
    produzem três mensagens diferentes
  - **Feita quando**: `costabeber` (41 com corpo) não tem botão de gerar; a mensagem traz 41 e
    o piso
  - **Teste**: `perfil_test.exs` — um caso por erro; e um que afirma que a mensagem **não**
    contém formulação que sugira pouca produção da pessoa

- [ ] **T014 [US3] Declarar o egresso no pedido**
  - **Pronta quando**: T012 concluída
  - **Descrição**: no momento em que a geração é pedida, a tela diz que título e descrição das
    tarefas vão para um provedor externo — `FR-020`. Não é rodapé: é a frase que acompanha o
    botão
  - **Feita quando**: a frase aparece antes da confirmação, e nomeia o que sai
  - **Teste**: `perfil_test.exs` — afirma a frase no fluxo do pedido, e afirma que ela some
    depois que o perfil existe

- [ ] **T015 [US4] Dizer quantas tarefas entraram desde a geração**
  - **Pronta quando**: T012 concluída
  - **Descrição**: comparar o recorte gravado com o que existe hoje e exibir a diferença —
    `FR-016`. Sem isso, um perfil de dezembro parece atual em junho
  - **Feita quando**: com tarefa nova depois da geração, a aba diz quantas
  - **Teste**: `perfil_test.exs` — gera, cria três tarefas, e afirma "3" na tela

---

## Fase 6 — Fechamento

- [ ] **T016 Rodar os gates e medir na origem**
  - **Pronta quando**: T001 a T015 concluídas
  - **Descrição**: `mix gates` — **nunca** com `| tail` ou `| grep`, porque o veredito é o
    código de saída. Depois, gerar um perfil real e conferir contra o banco: as contagens da
    tela batem com a consulta direta
  - **Feita quando**: gates verdes; e o recorte exibido confere com `select count(*)`
  - **Teste**: saída do `mix gates` com código zero, e a comparação registrada no PR

- [ ] **T017 Abrir o PR com revisor**
  - **Pronta quando**: T016 concluída
  - **Descrição**: PR ligado ao projeto, com revisor pedido, corpo descrevendo o que foi
    medido. A revisão independente é exigida pelo princípio VII e **não pode ser satisfeita
    por quem implementou** — declarar a lacuna, nunca marcá-la como cumprida
  - **Feita quando**: PR aberto com revisor; corpo traz a evidência
  - **Teste**: `gh pr view` mostra revisor pedido e vínculo com o projeto

---

## Dependências

```text
T001 → T002 → T003 → T004 → T005 ─┐
                                   ├→ T009 → T011 → T012 → T013, T014, T015 → T016 → T017
T006 → T007 → T008 ────────────────┘         T010 ┘
```

T013, T014 e T015 são paralelizáveis entre si.

## MVP

**T001 a T013.** Entrega a aba que lê o perfil e a que recusa quando não há material — as duas
histórias P1. T014 e T015 completam, e a fatia já é vertical sem elas.
