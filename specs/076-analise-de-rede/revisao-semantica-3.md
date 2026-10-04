# Terceira revisão semântica — 076, análise de rede (T006)

**Papel**: Ontology & Semantic Integration (AGENTS.md §13), que pode bloquear. **Data**: 2026-10-04.
**Issue**: #1330 (T006), spec 076, #1309.

**Declaração de independência**: o autor desta revisão não escreveu o plano, o `research.md` nem as
emendas que revisa. Trabalhou no worktree da `feature/1309-fundacao`, sem commit.

**Objeto**: o commit `e319042` sobre [proposta-base/](proposta-base/):
`rules/network_analysis_parameters.yaml` (`size_limit`, `modularity_reading.values.random_weights`,
`small_world.values.generator` e `.sampling`, `betweenness_color_bands`, `layout.values.labelled_nodes`
e `.seeding`), `measurements/network_modularity_score.yaml` (Q_rand com peso) e o novo
`competency_questions/spo_network_analysis_competency_questions.yaml` (20 perguntas).

**Réguas**: AGENTS.md §6 e §8; [plan.md](plan.md) D7; [research.md](research.md) R5, R7, R8, R16, R19;
[revisao-semantica-2.md](revisao-semantica-2.md) A5, A8 e §4; `priv/knowledge_base/ontology/seon/spo/`
(dependências `[ufo, eo]`); `schemas/competency-question.schema.yaml`; a referência de formato
`qapo_review_network_competency_questions.yaml`; [data-model.md](data-model.md) §1.3.

---

## Veredito: **aprova com emendas**

Não bloqueia. As emendas da regra correspondem ao que o plano decidiu, cada valor com a razão
escrita. Nenhuma faixa vira adjetivo sobre pessoa. O Q_rand com os pesos reais sorteados é coerente
e a medida não ficou contraditória. As 20 perguntas cobrem as 20 medidas de
`network.structure.candidate_measurements`, uma por uma e na mesma ordem, só com ids de SPO e EO que
existem.

Um achado é **alto** (B1): as perguntas escrevem a aresta como `spo.participates_in`, que é
participação em atividade **executada**. Na designação, o responsável não participa de nada: ele está
designado para o item **planejado**. Isso apaga na base a distinção que `assignment.network.edge`
(`ufo_category`) declara com todas as letras: *"designação não é execução"*. Há mais dois achados
médios e um baixo. As quatro emendas abaixo são obrigatórias **antes** de a base ir para
`priv/knowledge_base/` (T007).

---

## 1. Achados

### B1 — Alto: a aresta de designação escrita como participação em atividade executada

A nota de proveniência das perguntas diz: *"duas pessoas (…) ligadas pela participação
(`spo.participates_in`) em atividades sobre um mesmo artefato (`spo.activity_creates_artifact`)"*.
Todas as 20 perguntas carregam `relations: [spo.participates_in, …]`.

- `spo.participates_in` liga `spo.project_stakeholder` a `spo.performed_project_activity`
  (`priv/knowledge_base/ontology/seon/spo/modules/processes_and_activities.yaml:250-260`). A definição
  é *"contribuiu com a execução da atividade"*.
- Na **revisão** isso vale para as duas pontas: quem submeteu e quem avaliou participaram de
  atividades executadas. É o que a QAPO já usa.
- Na **designação**, vale só para o autor. O responsável está designado sobre o item planejado
  (`sro.intended_scrum_development_task`). `assignment.network.edge` diz que ligar o responsável a
  `spo.is_in_charge_of` *"faria designação parecer execução"*, e `spo.participates_in` tem o mesmo
  defeito. A SPO **não tem** relação entre stakeholder e `spo.intended_project_activity`.

Nenhum validador acusa isso, porque os ids existem. Mesmo assim, a base passaria a afirmar que o
responsável executou. Viola AGENTS.md §6: *processo planejado ≠ executado*, e o mapeamento de tarefa
diz que *"assignee indica quem foi designado, não necessariamente quem executou"*.

### B2 — Médio: duas perguntas pedem lista onde a medida é contagem

- **cq04** pergunta *"**Quais** pessoas … não têm nenhuma aresta"* com `expected_query_type: count`,
  e a própria `rationale` diz *"A resposta é número, e não lista de nomes: quem está fora da rede
  não é apontado"*. A pergunta contradiz a decisão que a rationale defende.
- **cq02** pergunta *"**Quais** pares … e, para cada um, por qual motivo"*. A medida
  `assignment.network.excluded.count` conta por motivo e não lista pares.

### B3 — Médio: o teto de tamanho não cobre tudo o que os aleatórios sustentam, e as medidas não declaram o motivo

O `size_limit.values.absent_above` é `[sigma, q_rand, layout]`. Mas a mesma bateria de 100 G(n, m)
sustenta também `efficiency_rand` (`network_global_efficiency_ratio.yaml`, fórmula). O
`data-model.md` §1.3 torna o bloco `random` **inteiro** ausente acima do teto. A base e o modelo de
dados divergem, e acima do teto a eficiência dos aleatórios ficaria sem regra: ou ela roda, e o teto
não limita o custo, ou ela some sem motivo declarado.

Além disso, nenhuma das três medidas afetadas declara o motivo `network_too_large_for_platform`.
`network_small_world_sigma_score.yaml` lista quatro motivos de ausência e não lista esse, embora o
`data-model.md` o liste. A FR-050 pede ausência com o motivo **da base**.

### B4 — Baixo: o embaralhamento dos pesos não está determinado só pela semente

As emendas R7 e A8 existem porque *"a semente sozinha não reproduz o sorteio"*. O Fisher–Yates
permuta uma **lista**, e o resultado depende da ordem de entrada do multiconjunto e da ordem em que
os pesos embaralhados são atribuídos às m arestas sorteadas. A regra não declara nenhuma das duas.
Duas implementações corretas da regra dariam Q_rand diferentes com a mesma semente.

### O que está certo (conferido)

- **R5**: `size_limit` tem 300 / 3 000, a razão (54 pessoas e 155 arestas medidas, folga de mais de
  5×), o caráter provisório (T050, #1190) e *"ausência, nunca valor aproximado"*.
- **R7**: `exsss` com estado explícito, nós em ordem crescente de id, rejeição de laço e de par
  repetido, sequência contínua entre os grafos, e o layout semeado à parte (`seeding`). Bate com
  `research.md:136-149`.
- **R8**: o mesmo guloso CNM, com peso, e o mesmo multiconjunto embaralhado em cada aleatório. Com o
  mesmo `m_w`, a diferença entre Q e Q_rand é da estrutura, e não da distribuição dos pesos. A
  limitação nova nomeia o modelo nulo e o que fica fora dele (graus preservados). As
  `misinterpretations` continuam válidas. O caso de teste de `tasks.md:514` (todos os pesos 1 dão o
  Q_rand sem peso) é consequência direta. Não sobrou menção a Q_rand sem peso na proposta. O divisor
  *"grafos com ao menos uma aresta"* é sempre N quando m ≥ 1, o que é inofensivo.
- **R16**: as cinco faixas de cor são contíguas e sem buraco (`none` = 0, depois [0, 0,02),
  [0,02, 0,05), [0,05, 0,10) e ≥ 0,10), com rótulos numéricos e sem *alta*, *baixa* ou *ponte*. A
  regra recusa explicitamente os cortes 0,3 e 0,1 da referência e trata a intermediação ausente
  como cor neutra com razão. `labelled_nodes: 7` vem com a razão (legibilidade, protótipo 3.2.2) e
  com o aviso de que não afirma importância.
- **Perguntas**: o schema está cumprido. Só aparecem ids `spo.*` e `eo.*`, então nenhuma dependência
  vai para QAPO, CMPO, SRO ou OSDEF. Cada `rationale` nomeia a medida que cobre e corresponde à
  fórmula dela: grau por pessoas distintas, intermediação sem peso, proximidade de Wasserman e Faust,
  autovetor por componente, eficiência com 1/∞ = 0, σ como critério e não como rótulo. Nenhuma
  pergunta é sobre desempenho ou mérito, e a nota cita a FR-047. A aresta não é chamada de
  colaboração nem de delegação.

### Observações, não obrigatórias

- **O1**: `labelled_nodes` com alcance parcial. Os 7 nomes têm de sair só das pessoas alcançadas da
  visão, e nunca do grafo inteiro. É matéria do contrato e da segurança (R2). Sugiro uma frase em
  `layout.statement`: *"com alcance parcial, entre as pessoas alcançadas"*.
- **O2**: `size_limit` diz *"pessoas"*. Seria mais exato dizer *"pessoas da rede (nós, com ao menos
  uma aresta)"*, que é o `n` de R6.
- **O3**: a T006 pedia que as emendas fossem escritas pelo agente semântico, e não por quem escreveu
  o plano. Esta revisão independente supre a verificação, mas não a autoria.

---

## 2. Emendas obrigatórias antes da T007

**E1 (B1)**, em `competency_questions/spo_network_analysis_competency_questions.yaml`:

- na `provenance.note`, trocar a frase que começa por *"A pergunta é escrita no nível geral: duas
  pessoas"* e termina em *"(`spo.activity_creates_artifact`)."* por:
  > A pergunta é escrita no nível geral, e o nível geral alcança só parte da aresta de designação. Na
  > revisão, as duas pontas participam (`spo.participates_in`) de atividades executadas: a que criou
  > o artefato (`spo.activity_creates_artifact`) e a que o avaliou. Na designação, só o autor está
  > nesse caso. O responsável está DESIGNADO para o item planejado (`spo.intended_project_activity`),
  > e a SPO não tem relação entre stakeholder e atividade pretendida: `spo.participates_in` e
  > `spo.is_in_charge_of` ligam à atividade EXECUTADA, e usá-las faria designação parecer execução
  > (AGENTS.md §6; `assignment.network.edge`, `ufo_category`). Por isso `relations` nomeia só o que a
  > SPO sustenta. A aresta em si, de revisão ou de designação, é relação derivada das regras globais
  > e não tem id de relação na rede.
- **cq01, cq02 e cq03**: acrescentar `spo.intended_project_activity` a `concepts` e acrescentar à
  `rationale` *"Na designação, o responsável está designado para o item planejado
  (`spo.intended_project_activity`), e não participa da atividade: `spo.participates_in` cobre só o
  autor."*
- **cq04 a cq20**: retirar a linha `relations: [spo.participates_in]`. O campo é opcional no schema,
  e nessas perguntas ele afirmava que a aresta é participação.

**E2 (B2)**, no mesmo arquivo:

- **cq04**, `pt-BR`: *"Quantas pessoas da organização, que são stakeholders, não têm nenhuma aresta na
  janela?"*. Em `en`: *"How many people of the organisation, who are stakeholders, have no edge in
  the window?"*;
- **cq02**, `pt-BR`: *"Quantos pares candidatos a aresta não ligam duas pessoas distintas, por motivo,
  na ordem declarada da regra (conta de máquina, conta da organização, conta sem pessoa ligada, a
  mesma pessoa nas duas pontas)?"*. Em `en`: *"How many candidate pairs do not link two distinct
  people, per reason, in the rule's declared order (…)?"*.

**E3 (B3)**:

- em `rules/network_analysis_parameters.yaml`, `size_limit`: `absent_above: [sigma, q_rand,
  efficiency_rand, layout]`. No `name` e no `statement`, onde está *"σ, Q_rand nem layout"*, escrever
  *"σ, Q_rand, a eficiência dos aleatórios (efficiency_rand) nem layout"*;
- em `measurements/network_small_world_sigma_score.yaml`, acrescentar à lista de motivos de ausência:
  *"`network_too_large_for_platform` (acima de network.analysis.parameters.size_limit)"*;
- em `measurements/network_modularity_score.yaml` e `network_global_efficiency_ratio.yaml`, na
  fórmula: *"Acima de network.analysis.parameters.size_limit: Q_rand [efficiency_rand] AUSENTE com
  motivo `network_too_large_for_platform`; Q [efficiency] é calculada."*

**E4 (B4)**, em `rules/network_analysis_parameters.yaml`, `small_world`:

- em `values.sampling`, acrescentar `weights_input: undirected_pair_ascending` e `weights_assigned_to:
  sampled_pair_order`;
- no `note`, depois de *"embaralhados por Fisher–Yates logo depois dos pares de cada grafo"*:
  *"O multiconjunto entra no embaralhamento na ordem crescente do par {menor id, maior id} da
  projeção sem direção, e o i-ésimo peso embaralhado vai para o i-ésimo par sorteado."*

---

## 3. Medido

Executado a partir do worktree, código de saída lido sem pipe:
`scratchpad/076f-kbcopia.sh limpo`. O script monta a cópia de `priv/knowledge_base` com a proposta
sobreposta e as perguntas em `ontology/seon/spo/competency_questions/`.

| comando | saída | observação |
|---|---|---|
| `mix knowledge.validate <cópia>` | **0** | 174 artefatos: 8 arquivos de perguntas de competência, 37 medidas, 10 necessidades, 31 regras |
| `mix knowledge.graph <cópia>` | **0** | 33 módulos, dependências íntegras |

Os dois zeros provam a existência dos ids e a forma do schema. **Não** provam B1 a B4: nenhum
validador confere a categoria de uma relação citada numa pergunta, a dependência de ontologia dentro
de uma pergunta, nem a coerência entre `size_limit` e as medidas.

## 4. O que não verifiquei

- `mix knowledge.test`, que roda na T007 sobre a base já copiada;
- a forma das regras: `derivation_rule` não tem schema, e essa lacuna da 073 continua;
- nenhum número contra o banco, nem as fórmulas por execução.

## 5. Conferência das emendas (2026-10-04)

Conferido contra o commit `4dff5e8` (`git show 4dff5e8 -- specs/076-analise-de-rede/proposta-base`):

| emenda | conferido |
|---|---|
| E1 | a `provenance.note` traz o texto pedido; cq01 a cq03 citam `spo.intended_project_activity` e têm a frase na `rationale`; cq04 a cq20 não têm mais `relations: [spo.participates_in]` |
| E2 | cq02 e cq04 perguntam *"Quantos"* e *"Quantas"*, em `pt-BR` e em `en` |
| E3 | `size_limit.absent_above` é `[sigma, q_rand, efficiency_rand, layout]`, com o `name` e o `statement` ajustados; σ, modularidade e eficiência declaram `network_too_large_for_platform` |
| E4 | `sampling.weights_input: undirected_pair_ascending` e `weights_assigned_to: sampled_pair_order`, com a frase no `note` |

Medido de novo pelo revisor, com a mesma cópia (`076f-kbcopia.sh limpo`): `mix knowledge.validate`
**0** e `mix knowledge.graph` **0**.

**Veredito final: aprova.** A T007 pode levar a base a `priv/knowledge_base/`. As observações O1 a O3
continuam não obrigatórias.
