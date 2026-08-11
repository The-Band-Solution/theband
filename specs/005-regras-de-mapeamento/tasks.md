# Tarefas — Feature 005: regras de mapeamento de tipo por organização

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/mapping-rules.md](contracts/mapping-rules.md) · **Quickstart**:
[quickstart.md](quickstart.md)

25 tarefas em cinco fases. A ordem é dependência, não preferência: F1 → F2 → F3 → F4 → F5.

**MVP declarado**: F1, F2 e F3. Com elas, uma pessoa cria regra pela API, a decisão passa a
valer e as issues são recalculadas. F4 e F5 entregam o catálogo e a tela — e sem F5 ninguém sem
acesso ao console consegue usar a feature, o que está declarado como custo.

---

## Fase F1 — A regra: tabela, validação e comando

- [ ] T001 Criar a tabela de regras
  - **Pronta quando**: nada além do repositório; `data-model.md` está escrito
  - **Descrição**: migração criando `issue_mapping_rules` com as 15 colunas de
    [data-model.md](data-model.md). Três índices: único em
    `(organization_id, where, how, pattern)`, único em `(organization_id, position)`, e
    `(tenant_id, organization_id, active)`. `created_by_id` é **not null** — é o que impede
    regra sem autor. **Nenhuma coluna é removida**
  - **Feita quando**: duas regras com a mesma posição na mesma organização são recusadas pelo
    banco; regra sem `created_by_id` é recusada
  - **Teste**: round trip — `mix ecto.migrate`, rollback, migrate — e um teste que espera
    violação de índice nas duas tentativas acima

- [ ] T002 Criar a tabela de decisão "não é tipo"
  - **Pronta quando**: T001 feita
  - **Descrição**: migração criando `unmapped_pattern_decisions` com `decided_by_id` not null e
    `reverted_at` anulável, e único em `(organization_id, pattern)`. A decisão é reversível
    porque alguém pode marcar como "não é tipo" o que é
  - **Feita quando**: o mesmo padrão não pode ser declarado duas vezes na mesma organização
  - **Teste**: round trip, e o teste de reversão em T014

- [ ] T003 Acrescentar proveniência à promoção
  - **Pronta quando**: T001 feita
  - **Descrição**: migração acrescentando `evidence_source`, `confidence` e `mapping_rule_id` a
    `issue_promotions`. Todas anuláveis: as 1020 promoções existentes **não** são retrofitadas,
    porque preencher retroativamente afirmaria algo que ninguém verificou
  - **Feita quando**: as promoções antigas continuam com as três colunas nulas, e a consulta as
    distingue das novas
  - **Teste**: round trip, e SQL conferindo que nenhuma linha existente foi alterada

- [ ] T004 Validar o padrão antes de qualquer escrita
  - **Pronta quando**: o contrato declara `validate/3` e as três recusas
  - **Descrição**: `TheBand.Mapping.PatternValidator.validate/3`, função **pura**, sem banco.
    Recusa: não compila — com a **posição**, que é o que permite corrigir —, casa string vazia,
    e excede o limite de tempo. Usa `Regex.compile/2` e **nunca** `compile!/2`: erro previsto é
    retorno, não exceção. O limite é medido em `Task.await/2` sobre **títulos reais** da
    organização, porque uma expressão rápida em `"abc"` pode ser lenta no título de 200
    caracteres que o time escreve
  - **Feita quando**: `"[US"`, `".*"` e `"(a+)+$"` são recusadas com motivos distintos
  - **Teste**: `test/the_band/mapping/pattern_validator_test.exs` — o teste é a **violação**,
    não o caminho felizes: cada uma das três recusas é um caso

- [ ] T005 Criar regra com autor obrigatório
  - **Pronta quando**: T001 e T004 feitas
  - **Descrição**: `Mapping.create_rule/4` valida com T004 **antes** de gravar. `actor` é
    parâmetro da assinatura, e **não existe versão sem ele** — a obrigatoriedade no tipo é o que
    impede a regra com autor "sistema". Devolve
    `{:error, {:invalid_pattern, motivo}}` com o motivo estruturado
  - **Feita quando**: nenhum caminho da API pública grava regra sem autor
  - **Teste**: V1 do quickstart, e um teste que tenta gravar padrão inválido e confere que
    **nada** foi gravado

- [ ] T006 Alterar regra criando versão
  - **Pronta quando**: T005 feita
  - **Descrição**: `Mapping.update_rule/4` incrementa `version` e revalida o padrão. Regra vinda
    do catálogo passa a ter versão da organização, e o catálogo em YAML **não** é alterado —
    FR-042
  - **Feita quando**: alterar duas vezes deixa `version = 3`, e o YAML do catálogo está
    inalterado
  - **Teste**: um teste que altera e confere versão, mais `git diff --exit-code` no arquivo do
    catálogo

- [ ] T007 Desativar sem apagar
  - **Pronta quando**: T005 feita
  - **Descrição**: `Mapping.deactivate_rule/3` grava `active: false`, `deactivated_at` e
    `deactivated_by_id`. **Não apaga**: as promoções que a regra produziu apontam para ela, e
    apagá-la tornaria a proveniência ilegível. Não existe `delete_rule/2`
  - **Feita quando**: a regra desativada para de valer na decisão e continua consultável pela
    promoção que produziu
  - **Teste**: desativar, recalcular, e conferir que a promoção antiga ainda resolve o
    `mapping_rule_id`

- [ ] T008 Listar as regras na ordem de aplicação
  - **Pronta quando**: T005 feita
  - **Descrição**: `Mapping.list_rules/3` devolve as regras por `position`, com autor, data,
    versão e quantas issues cada uma promoveu — FR-033. Ordem determinística **e visível**: sem
    ela, acrescentar regra mudaria a classificação sem ninguém ver
  - **Feita quando**: a ordem devolvida é a mesma em duas execuções, e bate com `position`
  - **Teste**: duas leituras com a mesma ordem, e regra de outro tenant ausente da lista

---

## Fase F2 — A decisão: segunda etapa em `Routing`

- [ ] T009 Ler a regra da organização na decisão por tipo
  - **Pronta quando**: F1 feita
  - **Descrição**: `Routing.decide/2` passa a consultar `issue_mapping_rules` da organização
    **antes** da regra do tenant e da global. A precedência é
    organização → tenant → global, e ela existe porque a organização é quem conhece a própria
    convenção
  - **Feita quando**: `Chore` mapeado por regra da organização promove, e continua não promovendo
    em organização que não o mapeou
  - **Teste**: `routing_test.exs` com as duas organizações, conferindo que a decisão de uma não
    vaza para a outra

- [ ] T010 Acrescentar a etapa de título, e só depois
  - **Pronta quando**: T009 feita
  - **Descrição**: segunda etapa em `Routing.decide/2`, avaliada **somente** quando a etapa 1
    não decidiu. FR-008 exige que tipo declarado vença regra de título, e a única forma de
    garantir isso é **não chegar** à etapa 2 — avaliar as duas e escolher depois deixaria a
    precedência dependente da ordem de comparação
  - **Feita quando**: issue com tipo `Task` e título `[FEATURE] x` é promovida a **tarefa**, e a
    regra de título não é sequer avaliada
  - **Teste**: V4 do quickstart. O teste é a **violação**: se a etapa 2 for alcançada, ele falha

- [ ] T011 Aplicar as quatro formas de comparação
  - **Pronta quando**: T010 feita
  - **Descrição**: `equals`, `starts_with`, `contains` e `regex`, com `case_sensitive`
    respeitado. `contains "US"` casa `"STATUS"` e `starts_with "US"` não — a diferença é o
    motivo de a forma ser **declarada** e não inferida
  - **Feita quando**: as quatro formas casam o esperado, e a insensibilidade a maiúsculas funciona
    nas quatro
  - **Teste**: V3 do quickstart, com o caso `"STATUS"` explícito

- [ ] T012 Registrar fonte da evidência e confiança
  - **Pronta quando**: T010 e T003 feitas
  - **Descrição**: a decisão devolve `evidence_source` e `confidence` — etapa 1 grava
    `declared_type`/`high`, etapa 2 grava `title`/`medium`. Nível, **nunca número**: um número
    seria inventado, e viraria meta — alguém o otimizaria escrevendo regras mais amplas
  - **Feita quando**: 100% das promoções por regra têm as duas colunas preenchidas — SC-004
  - **Teste**: V9 do quickstart, por SQL agrupando por fonte e confiança

- [ ] T013 Ligar a promoção à regra que decidiu
  - **Pronta quando**: T012 feita
  - **Descrição**: `mapping_rule_id` na promoção, para a tela responder "qual regra decidiu esta
    issue" — FR-010. A coluna existe **além** de `evidence_source` porque a promoção sobrevive à
    regra: derivar a fonte da regra na leitura daria resposta diferente depois de ela mudar
  - **Feita quando**: a tela do detalhe da issue mostra a regra por nome, e a promoção continua
    legível depois de a regra ser desativada
  - **Teste**: desativar a regra e conferir que a promoção ainda a resolve

- [ ] T014 Declarar e reverter "não é tipo"
  - **Pronta quando**: T002 feita
  - **Descrição**: `Mapping.declare_not_a_type/5` e `revert_not_a_type/3`. O padrão sai da
    pendência e passa a **ausência declarada**, com quem e quando. Existe porque `[Devops]` com
    340 issues ficaria para sempre na lista, e a insistência empurra alguém a mapear área como
    tipo
  - **Feita quando**: `[Devops]` sai da lista de pendências sem nenhuma issue ser promovida; e
    reverter o devolve
  - **Teste**: V12 do quickstart, conferindo que a contagem de promovidas **não muda**

---

## Fase F3 — Prévia e recálculo

- [ ] T015 Calcular a prévia sem consultar a origem
  - **Pronta quando**: F2 feita
  - **Descrição**: `Mapping.preview/3` sobre as issues **já coletadas**. Devolve `matched`,
    `would_change` e uma amostra de títulos. `matched` sem `would_change` esconderia o caso
    perigoso: casar 1031 e mudar 1031 é muito diferente de casar 1031 e mudar 3
  - **Feita quando**: os dois números são distintos quando devem ser, e nenhuma requisição sai
    para a origem
  - **Teste**: V6 e V7 do quickstart

- [ ] T016 Provar que prévia e efeito coincidem
  - **Pronta quando**: T015 e T017 feitas
  - **Descrição**: teste que compara `would_change` da prévia com o número de promoções que o
    recálculo grava. A prévia usa a **mesma função de decisão** que o recálculo — duas
    implementações fariam a prévia mentir, e alguém aprovaria uma regra vendo 3 e
    reclassificaria 900
  - **Feita quando**: a diferença é **zero** — SC-007
  - **Teste**: V5 do quickstart

- [ ] T017 Recalcular na fila que já existe
  - **Pronta quando**: F2 feita
  - **Descrição**: worker Oban na fila **`transformation`** — declarar fila nova sem configurá-la
    faz o job ficar `available` para sempre, e o sintoma foi uma coleta que "completou" sem
    coletar nada. Assíncrono **sempre**, sem limite condicional: dois caminhos e o raro é o que
    quebra
  - **Feita quando**: gravar regra enfileira o job, e o job conclui recalculando as issues da
    organização
  - **Teste**: um teste que enfileira e executa com `Oban.Testing`, conferindo o estado
    `completed` — e **não** `available`

- [ ] T018 Gravar promoção nova, preservando a anterior
  - **Pronta quando**: T017 feita
  - **Descrição**: o recálculo grava linha nova em `issue_promotions`; a vigente é a última por
    `inserted_at` em microssegundo. Append-only já é como a feature 004 grava — FR-026
  - **Feita quando**: uma issue recalculada tem duas promoções, e a segunda é a vigente
  - **Teste**: conferir as duas linhas e qual `promotion_history/2` marca como vigente

- [ ] T019 Tornar o recálculo idempotente
  - **Pronta quando**: T018 feita
  - **Descrição**: comparar a decisão nova com a **vigente** e só gravar quando diferem —
    FR-027. Sem isso, cada execução dobraria o histórico e a tela mostraria dezenas de decisões
    idênticas
  - **Feita quando**: executar duas vezes sobre o mesmo estado não produz linha nova
  - **Teste**: V8 do quickstart

- [ ] T020 Preservar a promoção na reobservação
  - **Pronta quando**: T018 feita
  - **Descrição**: a coleta seguinte **não** apaga a promoção por regra — FR-028. A coleta grava
    o que a origem disse; quem decide conceito é a regra, e uma coleta que redecidisse
    silenciosamente perderia o que a pessoa configurou
  - **Feita quando**: sincronizar depois de criar regra mantém as issues promovidas por ela
  - **Teste**: um teste que grava regra, recalcula, simula reobservação e confere que a promoção
    vigente é a mesma

---

## Fase F4 — O catálogo composto por organização

- [ ] T021 Ler o catálogo e compor com as regras da organização
  - **Pronta quando**: F1 feita; o catálogo existe em
    `priv/knowledge_base/rules/github_issue_pattern_catalog.yaml` e valida nos dois gates
  - **Descrição**: `Mapping.list_proposals/2` compõe **em leitura**: para cada entrada do
    catálogo, procura a regra da organização pela chave `(where, how, pattern)` normalizado —
    **nunca** o índice da lista, porque reordenar o catálogo não pode desligar decisões já
    tomadas. Estado de cada entrada: `:proposed`, `:activated` ou `:edited`. **Nada é copiado
    para o banco na conexão** — FR-043
  - **Feita quando**: organização recém-conectada tem **zero** linhas em
    `issue_mapping_rules`, e as propostas aparecem
  - **Teste**: V10 e V11 do quickstart — o segundo reordena o YAML e confere que as ativações
    permanecem

- [ ] T022 Contar quantas issues cada proposta casaria
  - **Pronta quando**: T021 e T015 feitas
  - **Descrição**: `would_match` por entrada, calculado sobre as issues da organização.
    `would_match == 0` aparece como **não aplicável a esta organização**, não como erro —
    FR-045: um catálogo com 18 entradas mostraria 18 avisos de erro numa organização que usa
    três convenções
  - **Feita quando**: `[TASK]` mostra 1031 na organização que o usa e 0 na que não usa, e a
    segunda diz "não aplicável"
  - **Teste**: as duas organizações do dado real, com os números medidos

- [ ] T023 Ativar proposta e ativar todas, com autoria
  - **Pronta quando**: T021 feita
  - **Descrição**: `activate_catalog_rule/4` e `activate_all_proposals/3`. As regras criadas
    registram **a pessoa** como autora — nunca "sistema", que é o que FR-041 proíbe. Uma ação,
    uma autoria
  - **Feita quando**: depois de ativar todas, nenhuma regra tem autor nulo nem autor de sistema
  - **Teste**: ativar todas e conferir `created_by_id` em cada linha criada

---

## Fase F5 — A tela

- [ ] T024 Componente de regras na tela de sincronização
  - **Pronta quando**: F3 e F4 feitas
  - **Descrição**: componente alcançado **pela organização**, com cabeçalho próprio, na tela de
    sincronização. Mostra: a lacuna agrupada com `declared_types` e `title_patterns`
    **separados**; as propostas do catálogo com `would_match`; as regras vigentes na ordem de
    aplicação; quanto do total ainda não tem conceito; e a ação de declarar que um padrão não é
    tipo.

    **A separação entre "provavelmente é tipo" e "provavelmente não é" é obrigatória** —
    FR-031: sugerir regra para `[Devops]` daria ao produto 340 user stories que são rótulos de
    equipe.

    A prévia aparece **antes** de gravar, com `matched` e `would_change`.

    Sobre o princípio X: o componente tem uma responsabilidade só, e a hospedagem fica
    visivelmente separada do relatório de execução — misturar as regras ao cartão da execução
    repetiria o erro do resumo de trabalho que apareceu dentro do cartão de cada sync
  - **Feita quando**: a tela mostra as duas listas separadas, e não há caminho que sugira criar
    regra para um padrão marcado como não sendo tipo
  - **Teste**: teste de LiveView que **recusa** a sugestão de regra para `[Devops]` na lista de
    prováveis tipos, e confere que `[TASK]` está nela

- [ ] T025 Alcançar as regras pela organização
  - **Pronta quando**: T024 feita
  - **Descrição**: o acesso ao componente parte da **organização cuja coleta produziu a
    lacuna** — FR-052. Uma lista global obrigaria escolher a organização duas vezes: uma para
    ver a coleta, outra para ver as regras. E a hospedagem é a tela de sincronização, não página
    própria em `/mapeamento` — FR-050, decisão da pessoa mantenedora em 2026-08-11, com a
    alternativa recusada registrada em R7.

    **A separação exigida por FR-051 é verificável**: o componente tem cabeçalho próprio, e o
    relatório de execução da coleta e as regras não compartilham cartão. Misturá-los repetiria o
    erro do resumo de trabalho que apareceu dentro do cartão de cada sync — o número parecia da
    execução e era do tenant
  - **Feita quando**: existe caminho de um clique da organização sincronizada até as regras dela,
    e não existe rota `/mapeamento`
  - **Teste**: teste de LiveView que parte de `/sincronizacoes`, alcança as regras da organização
    e **recusa** a existência de rota própria; e que confere que o cabeçalho do componente é
    distinto do cartão da execução

---

## Dependências

```text
T001 → T002, T003
T001 + T004 → T005 → T006, T007, T008
F1 → T009 → T010 → T011, T012 → T013
T002 → T014
F2 → T015, T017 → T018 → T019, T020
T015 + T017 → T016
F1 → T021 → T022, T023
F3 + F4 → T024 → T025
```

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T002 e T003 | migrações independentes, depois de T001 |
| T006, T007 e T008 | comandos e leitura sobre a mesma tabela |
| T011 e T012 | formas de comparação e proveniência não se tocam |
| T022 e T023 | contagem e ativação são independentes |

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 a FR-007 (a regra) | T001, T005, T006, T007, T011 |
| FR-008 a FR-011 (precedência e ordem) | T008, T009, T010 |
| FR-012 a FR-015 (proveniência) | T003, T012, T013 |
| FR-016 a FR-020 (limites e recusas) | T004, T005 |
| FR-021 a FR-024 (prévia) | T015, T016 |
| FR-025 a FR-028 (recálculo) | T017, T018, T019, T020 |
| FR-029 a FR-035 (tela e isolamento) | T014, T024 |
| FR-050 a FR-052 (colocação da tela) | T024, T025 |
| FR-036, FR-037 (herança da 004) | T009 substitui; T037 fica no product backlog |
| FR-038 a FR-045 (catálogo) | T021, T022, T023 |

**48 de 48 requisitos com tarefa** — a numeração da spec vai até FR-052 com quatro números não
usados (046 a 049), e as três da colocação da tela estavam sem tarefa até a análise apontar. SC-001 a SC-017 verificados por V1 a V12 do
[quickstart](quickstart.md).

## Fora do escopo deste conjunto

| Item | Destino |
|---|---|
| mapeamento campo de quadro → atributo | product backlog, FR-037 |
| `tool_concept_mappings` (T043–T046 da 004) | **substituídas**, não concluídas — FR-036 |
| inferir regra automaticamente | recusado: inferência sobre texto livre é decisão de pessoa |
