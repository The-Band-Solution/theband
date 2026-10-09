# Revisão semântica da proposta de base — 073/T003

**Papel**: Ontology & Semantic Integration (AGENTS.md §13). **Data**: 2026-10-03. **Issue**: #1191.
**Objeto**: [`proposta-base/`](proposta-base/): README, necessidade `review.concentration`, as nove
medidas `review.network.*`, o mapeamento da aresta `…as_review_edge`, a regra
`review.network.parameters` e as perguntas `qapo_review_network.cq01`–`cq04`. Quem revisa não
escreveu esses YAMLs.

**Réguas**: AGENTS.md §6, §8 e §11; os YAMLs reais de QAPO, CMPO, SPO e EO em
`priv/knowledge_base/ontology/`; os schemas em `priv/knowledge_base/schemas/`; `spec.md`,
`seguranca.md` (decisões de 2026-10-03), `research.md` (R2, R3, R11, R14), `data-model.md` e
`contracts/`.

---

## Veredito: **aprova com emendas**

As emendas já estão **aplicadas** em `proposta-base/` neste commit, e a proposta emendada foi
revalidada (seção 4). Nada bloqueia a T004, **desde que** a T004 faça as três coisas da seção 3,
que estão fora de `proposta-base/` e por isso não são deste papel.

O núcleo semântico estava certo, e é o que mais importa: a aresta é de **revisão**, de quem avaliou
para quem **submeteu** (não para quem integrou); o nó é `eo.person` com `account_type = 'person'`
pelo papel `spo.project_person_stakeholder`, nunca membro de equipe; a equivalência é `derived`; e
toda medida tem necessidade, pergunta, fórmula, unidade, níveis, limitações, interpretações
incorretas (as quatro mínimas da FR-007) e proveniência. As decisões de 2026-10-03 estão todas
carregadas (seção 5). Os achados são de **forma e de lugar**, e dois deles fariam a base afirmar
algo falso se entrassem como estavam.

---

## 1. Achados, por severidade

### A1 — Alto: a aresta declarada como `mapping:` duplicava, com outro grau, um mapeamento existente

`mappings/github/qapo/review_edge.yaml:1-6, 23-24, 58-62` (proposta original).

- O par (origem, alvo) `pull_request_review → qapo.artifact_evaluation` **já** é declarado por
  `priv/knowledge_base/mappings/github/qapo/review.yaml:1-8`, com `equivalence: partial`. A proposta
  declarava o **mesmo par** com `equivalence: derived`. A base passaria a dizer duas coisas sobre a
  mesma tradução, e quem lê `derived` entende que a avaliação de artefato é inferida — o que é
  falso: a avaliação é observada; é a **aresta** que é derivada. O validador não pega isto (ids
  diferentes, cada arquivo válido sozinho), e é por isso que o achado é alto.
- A identidade declarada não era a da coisa: `external_id_path: id` (o evento de review) com
  `natural_key: [pullRequest.id, author.id]` (a conta). A unidade da aresta é o par
  **(pessoa revisora, solicitação)**, como a própria implementação deduplica
  (`lib/the_band/review_network/graph.ex:46-51`).
- O cabeçalho da proposta (`review_edge.yaml:14-17`) já dizia que o cálculo lê `qapo_*` e `cmpo_*`
  integrados, e não o payload. Mapeamento é fonte externa → conceito (§8, §10); isto é derivação
  sobre instâncias da rede. `research.md` R11 (`:395-405`) já pedia `derivation_rule`, pela mesma
  razão.

**Emenda aplicada**: o mapeamento saiu; entrou `proposta-base/rules/review_network_edge.yaml`, regra
`review.network.edge` versão 1, com `semantics` (`equivalence: derived`, a justificativa do
mapeamento), `unit`, `inputs`, `relations`, as **dez** limitações (as nove do mapeamento e uma
nova, sobre a travessia QAPO/CMPO), e as sub-regras `counted_states` e `exclusions`, que saíram de
`review.network.parameters`. A FR-005 pede *"o mapeamento … declarado na base, com grau de
equivalência, justificativa e limitações"*: os três estão na regra, que é o que R11 decidiu.

### A2 — Alto: a categoria UFO da aresta não estava declarada

Em lugar nenhum da proposta. A pergunta "a aresta é relator?" ia aparecer no código (tabela com
`internal_id`? conceito novo?) sem resposta escrita.

**Emenda aplicada** (`review_network_edge.yaml`, `ufo_category`): **relação derivada, sem relator, e
não conceito da rede**. Os fundamentos são dois **eventos**, `qapo.artifact_evaluation` (`action`)
e `cmpo.change_request_submission` (`action`), ligados pelo artefato; nada persiste entre as duas
pessoas além deles, sem período nem contexto próprios — o contrário de `eo.team_membership`, que é
relator de verdade. Também não é relação material de UFO, que exigiria relator. Consequência
escrita: sem id de conceito, sem módulo, sem tabela de domínio com `internal_id`; vive só na
leitura derivada, que é o que `data-model.md` §1.1 já desenha.

### A3 — Médio: as perguntas de competência da QAPO citavam CMPO e EO, que a QAPO não declara

`ontology/seon/qapo/competency_questions/qapo_review_network_competency_questions.yaml:25-29, 41-44,
56-57, 70-71` (original): `cmpo.change_request`, `cmpo.change_request_submission`,
`cmpo.stakeholder_submitted_change_request`, `cmpo.submission_produced_change_request` e `eo.person`.

- A QAPO declara `dependencies: [ufo, spo]` (`priv/knowledge_base/ontology/seon/qapo/ontology.yaml:13`);
  CMPO e QAPO são irmãs (camada 2). O cabeçalho de `qapo.evaluation_participation`
  (`evaluation_participation.yaml:14-22`) e a primeira limitação de `review.yaml` registram a decisão
  de **não** fazer a QAPO depender da CMPO.
- Nem `mix knowledge.validate` nem `mix knowledge.graph` conferem a dependência de pergunta de
  competência (`yaml_validator.ex:250-266` só confere existência; `dependency_problems/1` olha só
  módulos). Medido: as seis ontologias que já têm perguntas citam **só** o que declaram. Esta seria a
  primeira dependência escondida, e entraria verde.

**Emenda aplicada**: as quatro perguntas passaram ao vocabulário QAPO + SPO. O lado do autor é
`spo.participates_in` + `spo.activity_creates_artifact`; a pessoa é `spo.project_person_stakeholder`
(que é `is_role_of: eo.person`). O texto de cada pergunta diz o que ela é no The Band (*"quem revisou a
solicitação de mudança submetida por outra pessoa"*), e a nota de proveniência nomeia o percurso
concreto pela CMPO, que mora na regra global `review.network.edge`. Os ids `cq01`–`cq04` não mudaram.

### A4 — Médio: o texto dos estados que contam afirmava uma recusa que não existe

`review_edge.yaml:69` (original): *"qualquer outro valor → a carga já recusa em review.yaml
(unmapped: reject)"*. Falso: a coleta grava o estado **cru**, qualquer que seja
(`lib/the_band/ingestion/github_change_requests.ex:347-349`); o `unmapped: reject` vale para a
tradução em veredito (`lib/the_band/quality/verdict.ex:27-31, 97-102`), e DISMISSED/PENDING nem
passam por ela (`verdict.ex:44`). Quem impede estado novo de virar aresta é a **lista de inclusão**
(`Quality.review_pairs/3` filtra por `states`, `quality.ex:477`).

**Emenda aplicada**: `counted_states.statement` diz isso, e a pergunta deixada em aberto pela nota da
proposta (`review_network_parameters.yaml:146-149`, *"a revisão semântica decide se ela mora aqui ou
no mapeamento"*) foi decidida: mora em `review.network.edge`, porque é significado da aresta, e o
`value_map` de `review.yaml` traduz posição, que a rede não usa.

### A5 — Médio: o invariante das exclusões não fechava com duas contas da mesma pessoa

`measurements/review_network_excluded_count.yaml:16-17` e `review_network_parameters.yaml:171-172`
(original): *"… = total de pares da janela"*, com par = (conta revisora, solicitação). Uma pessoa
com duas contas ligadas sobre a mesma solicitação são **dois** pares de conta e **uma** contribuição
ao peso — a implementação já deduplica (`graph.ex:46-51`, `:70-72`), e a base dizia outra coisa.

**Emenda aplicada**: `review.network.edge.unit` declara as duas unidades (pessoa para a aresta,
conta para a exclusão), e o invariante, nos dois arquivos, passou a ser sobre **pares contáveis da
janela, com os de aresta deduplicados por pessoa**. Acrescentada a limitação de que contas apagadas
sobre a mesma solicitação são indistinguíveis e contam **um** par (`quality.ex:480-487` agrupa por
login, e o login é nulo).

### A6 — Médio: `reviews_given` e `reviews.count` davam dois nomes de unidade ao mesmo número

`review_network_reviews_given.yaml:8` (`unit: change_requests`) contra
`review_network_reviews_count.yaml:8` (`unit: reviews`). A soma de `reviews_given` sobre as pessoas
**é** `reviews.count` (research.md R2, `:52-54`).

**Emenda aplicada**: `reviews_given` passou a `unit: reviews`, com comentário dizendo que o número é
também o de solicitações distintas que a pessoa revisou. `reviews_received` continua
`change_requests`, e está certo: ali não é soma de pesos. Com isto a **quinta pergunta do README**
(medidas em par num só arquivo) fica **decidida**: um arquivo por item da FR-007, unidade do primeiro
componente, o segundo escrito na expressão — separar permitiria mostrar *"12"* sem *"de 4 pessoas"*.

### A7 — Baixo: interpretação incorreta mal escrita em `reviews_given`

`review_network_reviews_given.yaml:57` (original): *"Somar as linhas e chamar de total da
organização"* — mas a soma das linhas **é** o total de revisões (para quem alcança todos). O erro
real é chamá-la de solicitações revisadas, e, com alcance parcial, somar linhas que trazem o total
verdadeiro de cada pessoa. **Emenda aplicada**, com as duas coisas.

### A8 — Baixo: duas lacunas de limitação

- `reviews_received`: a solicitação revisada só por conta **sem pessoa ligada** também aparece como
  não revisada (só bot estava escrito). **Emenda aplicada.**
- `people_without_activity`: quem só revisou solicitações de bot ou de conta não ligada revisou de
  fato e entra na contagem de "sem atividade". **Emenda aplicada.**

### A9 — Baixo: texto vencido

- `review_network_parameters.yaml:39-40` (original): *"O grupo mínimo … precisa de decisão da pessoa
  mantenedora"* — decidido em 2026-10-03 (3). **Corrigido**, junto com a descrição (*"cinco decisões
  numéricas e uma ordem de exclusão"* → quatro) e o nome da regra.
- `review_network_excluded_count.yaml:28` (original): *"a coleta hoje a conta como bot
  (`github_change_requests.ex:321`)"* — a T030 já alinhou a coleta (commit `908c29c`). **Corrigido.**

### A10 — Baixo: versão das medidas (FR-011)

`measurement.schema.yaml` não tem `version`; a FR-011 pede a versão das medidas na proveniência, e
`research.md` R11 (`:418-421`) decidiu o campo opcional. **Emenda aplicada**: as nove medidas
declaram `version: 1`. **Consequência deliberada**: contra o schema atual, a proposta reprova
(`EXIT=1`, seção 4) — é o que impede a T004 de levar as medidas sem a mudança de schema.

---

## 2. O que foi conferido e está certo

| conferência | resultado |
|---|---|
| todo conceito e relação citados existem com o id | sim: `eo.person` (`organizational_structure.yaml:72`), `spo.project_person_stakeholder` (`projects_and_stakeholders.yaml:73`), `qapo.artifact_evaluation` (`quality_assurance_process.yaml:34`), `qapo.evaluated_artifact` (`:41`), `cmpo.change_request` (`configuration_management_process.yaml:60`), `cmpo.change_request_submission` (`change_traceability.yaml:51`), as quatro relações (`evaluation_participation.yaml:56, 76`; `change_traceability.yaml:66, 81`), `cmpo.stakeholder_performed_checkin` (`:90`), `qapo.evaluation_verdict`, e as de SPO das perguntas emendadas (`spo.participates_in`, `processes_and_activities.yaml:250`; `spo.activity_creates_artifact`, `artifacts_and_resources.yaml:50`) |
| direção e cardinalidade | `stakeholder_performed_artifact_evaluation`: `spo.project_stakeholder` → avaliação, one/many — uma review, um autor, que é o que permite o par (pessoa, solicitação); `artifact_evaluation_evaluates`: many/one — várias rodadas sobre o mesmo artefato, que é o que o peso colapsa; `stakeholder_submitted_change_request` one/many e `submission_produced_change_request` one/one — um submissor por solicitação, logo um autor por aresta. O percurso revisor → avaliação → artefato ← submissão ← submissor é bem formado |
| `spo.project_person_stakeholder` especializa a origem das participações | sim: `parent: spo.project_stakeholder`, `is_role_of: eo.person` |
| a submissão é atividade de SPO | `cmpo.change_request_submission` é `parent: spo.performed_simple_activity`, que é `parent: spo.performed_project_activity` — por isso `spo.participates_in` e `spo.activity_creates_artifact` cabem nas perguntas |
| PR ≠ merge | a aresta usa submissão, e `cmpo.stakeholder_performed_checkin` só aparece para dizer que não é percorrida |
| pessoa ≠ membro de equipe | nó é pessoa pelo papel de SPO; equipe só na fatia 2, pelo relator |
| nunca por semelhança de nome | a justificativa da aresta é estrutural (participações + artefato), não lexical |
| §11, cada medida | as nove têm necessidade, pergunta (pela necessidade), fórmula com `inputs`, unidade, `levels`, `filters`, `period`, `limitations`, `misinterpretations` com as quatro mínimas da FR-007, e `provenance.source_type` |
| ausência nunca zero | toda medida nomeia o motivo de ausência; nenhuma usa 0, 0,01 ou `inf` |
| necessidade de informação | global, e por isso pode citar QAPO, CMPO, SPO e EO juntas; `decision_supported` diz o que **não** responde |

---

## 3. O que a T004 tem de fazer junto, fora de `proposta-base/`

Não é emenda deste papel (está em código, schema ou documento de plano), e é **condição** do aceite:

1. **Schema**: `version: { type: integer, minimum: 1 }` opcional em
   `priv/knowledge_base/schemas/measurement.schema.yaml`, no mesmo commit das medidas (R11). Sem ele
   a validação reprova, como deve.
2. **Código**: `lib/the_band/review_network/parameters.ex:56` lê `counted_states` de
   `review.network.parameters`. Passa a ler de `review.network.edge` (`rules.counted_states.values.states`),
   e `knowledge_versions` passa a gravar as **duas** regras e as medidas (FR-011). Sem a mudança,
   `Parameters.fetch!/0` levanta na carga — falha ruidosa, e não silenciosa.
3. **Documentos que divergem da proposta emendada** (corrigir no commit que a aceitar, como
   `data-model.md` §3 pede para si):
   - `data-model.md:33` — `knowledge_versions` com `review.network.thresholds`: o id é
     `review.network.parameters`;
   - `data-model.md:132-141` — *"Quatro"* medidas: são nove; grupos com unidade *"pessoas"*: é
     `groups` (o tamanho é que é em pessoas); concentração `ratio`: a base declara `percentage`,
     e o contrato transporta inteiros, o que é compatível;
   - `data-model.md:145-165` e `research.md:395-396` — chaves `minimum_sample`, `minimum_group_size`,
     `windows_days`, arquivo `review_network_thresholds.yaml`: valem as da proposta
     (`min_reviews`, `min_group_size_shown`, `window_days`, `review_network_parameters.yaml`);
   - `contracts/review-network.md:65-67` — `reviews`, `reviewers` e `authors` como
     `non_neg_integer()`: com o recorte sem aresta a base diz **ausente** (`no_review_in_window`),
     e a FR-009 e o SC-002 também. O contrato precisa de `{:ausente, :sem_revisao_na_janela}`
     nesses três, ou a tela precisa nomear a ausência do bloco inteiro. **Esta é a divergência mais
     importante desta lista**: zero no lugar de ausência é o que a plataforma existe para não fazer;
   - os nomes dos motivos divergem entre base, contrato e protótipo (`unlinked_person` /
     `unlinked` / `not_linked`; `did_not_review_in_window` / `:nao_revisou`). O significado é o
     mesmo e o código não lê esses nomes da base; registrar a correspondência basta.

---

## 4. Validação, com o código de saída

Cópia de `priv/knowledge_base/` para um diretório único do scratchpad
(`…/scratchpad/kb-t003-antes` e `…/kb-t003-depois`, nunca `theband-gate-*`), com os YAMLs da
proposta sobrepostos nos destinos do README §1. Saída redirecionada para arquivo; o código lido
direto do `mix`.

| quando | comando | EXIT | resultado |
|---|---|---|---|
| antes, proposta original | `mix knowledge.validate <cópia>` | 0 | 147 artefatos (23 mapeamentos, 25 regras, 17 medidas) |
| antes | `mix knowledge.graph <cópia>` | 0 | 33 módulos |
| depois, schema atual | `mix knowledge.validate <cópia>` | **1** | as nove medidas: *"campo version não está declarado no schema"* — esperado (A10) |
| depois, `version` opcional no schema da cópia | `mix knowledge.validate <cópia>` | 0 | 147 artefatos: 22 mapeamentos, 26 regras, 17 medidas, 9 necessidades, 7 arquivos de perguntas |
| depois | `mix knowledge.graph <cópia>` | 0 | 33 módulos, dependências íntegras |
| depois | `scripts/validate_knowledge_base.py --kb <cópia>` | 0 | 147 arquivos, 17 medidas |
| vista reprovando | perguntas com `spo.activity_creates_artifact_inexistente` | **1** | *"qapo_review_network.cq01 referencia spo.activity_creates_artifact_inexistente, que não existe"* (e cq02–cq04) |

`mix knowledge.test` **não existe** nesta instalação (`lib/mix/tasks/` tem só `knowledge.validate` e
`knowledge.graph`), embora AGENTS.md §4 o liste. `mix test` e `mix gates` não foram rodados, por
instrução.

---

## 5. As decisões de 2026-10-03, conferidas na base emendada

| decisão | onde está | confere |
|---|---|---|
| unidade = revisões (par revisor–solicitação) | `top_k_share` (denominador), `reviews.count`, `reviews_given` (`unit: reviews`), `review.network.edge.unit` | sim |
| mínimo de 10 revisões, abaixo é ausente | `review.network.parameters.min_reviews` (`10`, `below_minimum: absent`); `top_k_share` | sim |
| grupos só no recorte (Q4) | `unconnected_groups` (fórmula e filtro) | sim |
| conta apagada = sem pessoa ligada | `review.network.edge.exclusions` (item 2 e nota); `excluded.count` | sim |
| grupo mínimo = 3 | `review.network.parameters.min_group_size_shown` | sim, declarado e sem caso nesta fatia |
| estados APPROVED/CHANGES_REQUESTED/COMMENTED/DISMISSED; PENDING fora | `review.network.edge.counted_states` | sim, por lista de inclusão |
| concentração sobre o recorte, sem nomear (R1); sem contar o que ficou fora (R2) | `top_k_share` filtros | sim |
| exclusões só para quem alcança todos, bot inclusive (Q5) | `excluded.count` filtros | sim |

---

## 6. O que não verifiquei

- **As perguntas de competência contra dado**: não há executor (`mix knowledge.test` não existe);
  conferi só que cada id existe e que o percurso é bem formado.
- **Que `cmpo.submission_produced_change_request` especializa `spo.activity_creates_artifact`**: é a
  premissa que liga as perguntas emendadas ao percurso concreto, e a CMPO **não** a declara (só
  `cmpo.stakeholder_submitted_change_request` diz, em texto, que especializa `spo.participates_in`).
  Está escrita como limitação em `review.network.edge` e na nota das perguntas. Declará-la na CMPO é
  mudança de ontologia, fora desta feature; recomendo issue própria.
- **O volume e os números contra o banco**: nenhum (o mínimo de 10 tem razão aritmética escrita, não
  medida).
- **A forma das regras**: `derivation_rule` não tem schema (`research.md` R11, lacuna declarada); a
  de `review.network.edge` foi conferida pela das regras existentes e pela leitura do código que a
  vai consumir.
- **A pergunta aberta sobre `LEDS`** (conta de organização usada como `User`): continua aberta, como
  o README da proposta diz.
