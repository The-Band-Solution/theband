# Feature Specification: Os três papéis na solicitação de mudança, e a verificação do commit

**Feature Branch**: `044-pr-e-ci-da-pessoa`

**Created**: 2026-08-27

**Status**: Draft

**Input**: User description: "coloque na pagina pessoal de cada pessoa o quantidade e a listas PRs que ela criou, revisou e aprovou e a quantidade e a lista de CIs/CDs que o commit dela quebrou ou passou"

---

## O que foi medido antes de escrever *(mandatory)*

> **Esta spec foi reescrita três vezes no mesmo dia, e as duas primeiras estavam erradas
> pelo mesmo motivo: eu não procurei o que já existia.** A primeira declarou a revisão como
> lacuna sem dado. A segunda planejou coletar o que já era coletado. O registro fica aqui
> porque a lição vale mais que a spec: **procurar antes de construir**, e a base tem
> mecanismo para isso — ontologia, mapeamentos e fachadas de domínio.

Toda decisão sai de medição no banco de desenvolvimento em **2026-08-27**.

### Os três papéis pedidos já existem, e os três já são coletados

| papel pedido | conceito da rede | materializado | medida |
|---|---|---|---:|
| **criou** | `cmpo.stakeholder_submitted_change_request` | ✅ | 5.497 de 5.635 |
| **revisou / aprovou** | `qapo.stakeholder_performed_artifact_evaluation` | ✅ | **4.127** de 4.233 |
| **fechou** (integrou) | `cmpo.stakeholder_performed_checkin` | ✅ | 4.862 de 5.635 |

A tabela `collected_artifact_evaluations` existe e está cheia. A consulta
`change_requests.graphql` já pede `reviews` com `state`, `submittedAt` e
`author.__typename`. `TheBand.Quality.by_reviewer/2` já agrega por revisor.

**Não falta coleta, não falta recoleta, não falta tabela.** Falta a tela.

### Os estados que a coleta já trouxe

    APPROVED ............ 3.379
    COMMENTED ...........   508
    CHANGES_REQUESTED ...   294
    DISMISSED ...........    52
    PENDING .............     0

    autor User .......... 4.148
    autor Bot ...........    85

`PENDING` não aparece porque a API só devolve rascunho para quem o escreveu.

### O veredito passou a ser universal em 2026-08-27

Decisão da pessoa mantenedora: mapear o estado para a ontologia, e não deixar a plataforma
presa ao enum do GitHub. O módulo `qapo.evaluation_verdict` declara três posições, e o
mapa foi **aprovado**:

    APPROVED          → qapo.endorsing_verdict     endossa: apto a seguir
    CHANGES_REQUESTED → qapo.objecting_verdict     objeta: não conformidade a resolver
    COMMENTED         → qapo.abstaining_verdict    abstém: participou, sem posição

`DISMISSED` e `PENDING` ficam **fora do veredito** — são ciclo de vida. As três posições
saem da comparação entre GitHub, Gerrit e GitLab: **Gerrit prova que duas não bastam**,
porque `+1` endossa sem autoridade para liberar e `−1` objeta sem bloquear.

### A CI ligada ao commit da pessoa

`commit_authors.author_person_id` → `collected_commits.sha` →
`collected_verifications.head_sha`:

    execuções que casam com commit de pessoa .... 8.358 de 15.671 (53%)
    success 6.807 · failure 1.340 · skipped 156 · cancelled 53 · nulo 2

`vinicius-je`: abriu **793**, integrou **844**, commits com **985 success** e **79
failure**.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver os três papéis da pessoa na solicitação de mudança (Priority: P1)

Quem abre a página vê, **separados**, quantas solicitações a pessoa **abriu**, quantas
**revisou** e quantas **integrou** — cada um com a lista.

**Why this priority**: é o pedido inteiro, e os três papéis são o que a rede já separa.

**Independent Test**: abrir a página de `vinicius-je` e ver 793 abertas e 844 integradas.

**Acceptance Scenarios**:

1. **Given** uma pessoa nos três papéis, **When** a aba é exibida, **Then** os três
   números aparecem separados, cada um com lista, e **em nenhum lugar a soma dos três**.
2. **Given** uma pessoa que só revisa, **When** a aba é exibida, **Then** "abriu" é zero
   **nomeado** e "revisou" aparece cheio.
3. **Given** uma solicitação fechada sem integrar, **When** ela aparece na lista de
   abertas, **Then** o desfecho a distingue de uma integrada.

---

### User Story 2 - Ver o veredito de cada revisão (Priority: P1)

Quem vê "revisou 40" vê **como** revisou: quantas endossou, objetou, absteve.

**Why this priority**: "revisou 40" não distingue quem aprova tudo de quem questiona. É o
que o pedido chamou de "aprovou".

**Independent Test**: abrir a página de alguém com revisões e ver os três vereditos.

**Acceptance Scenarios**:

1. **Given** revisões de vereditos diferentes, **When** a aba é exibida, **Then** os três
   aparecem separados, nomeados pelo conceito da rede e **nunca** pelo enum do GitHub.
2. **Given** uma revisão **retirada** (`DISMISSED`), **When** os vereditos são contados,
   **Then** ela **não** entra — a posição não vale mais.
3. **Given** uma revisão de **robô** (`author_type = Bot`), **When** os vereditos são
   contados na página de uma pessoa, **Then** ela **não** entra: bot não tem pessoa, e
   somá-lo inventaria participação. Medido: 85 de 4.233.
4. **Given** que endossar não é ausência de não conformidade, **When** o endosso é
   exibido, **Then** a tela **não** o apresenta como "sem problemas encontrados".

---

### User Story 3 - Ver a verificação que o commit da pessoa quebrou ou passou (Priority: P1)

Quem abre a página vê quantas execuções de CI/CD dispararam sobre commits dessa pessoa,
por desfecho, com a lista.

**Why this priority**: responde "o trabalho dessa pessoa passa na verificação". Não depende
das outras duas.

**Independent Test**: abrir a página de `vinicius-je` e ver 985 passaram, 79 quebraram.

**Acceptance Scenarios**:

1. **Given** commits que dispararam CI, **When** a aba é exibida, **Then** as contagens por
   desfecho aparecem separadas e a lista mostra as mais recentes.
2. **Given** que 47% das execuções não casam com pessoa, **When** os números são exibidos,
   **Then** a parcela é dita **ao lado** deles, e nunca descontada nem somada.
3. **Given** um commit com mais de uma tentativa, **When** as execuções são contadas,
   **Then** a contagem **não** é apresentada como contagem de commits.
4. **Given** uma execução `skipped` ou `cancelled`, **When** ela é contada, **Then** ela
   **não** entra em "passou" nem em "quebrou".

---

### Edge Cases

- **Revisão de robô**: 85 de 4.233. `author_person_id` é nulo, e ela não aparece em pessoa
  alguma.
- **Revisão sem pessoa identificada**: 106 de 4.233 têm autor `User` sem pessoa promovida.
  Não aparecem, e a soma das páginas não fecha com o total.
- **Duas revisões da mesma pessoa na mesma solicitação**: são duas avaliações. "Revisou"
  conta **solicitações distintas**; o veredito conta **avaliações**.
- **Pessoa sem elo de conta** (#369): a aba não abre, e nada é carregado.
- **Commit com co-autoria**: aparece nas duas páginas, e a soma excede o total.
- **Estado que o mapa não traduz**: recusa a carga (`unmapped: reject`) até a #526.

---

## Requirements *(mandatory)*

### O que a página passa a mostrar

- **FR-001**: A aba MUST mostrar, **separados**, quantas solicitações a pessoa abriu,
  revisou e integrou — cada um com a lista das mais recentes.
- **FR-002**: A aba MUST mostrar os vereditos das revisões dela, separados por posição.
- **FR-003**: A aba MUST mostrar quantas execuções de CI/CD dispararam sobre commits da
  pessoa, por desfecho, com a lista.
- **FR-004**: `skipped` e `cancelled` MUST NOT contar como "passou" nem como "quebrou".
- **FR-005**: A contagem de execuções MUST NOT ser apresentada como contagem de commits.
- **FR-006**: Revisão de `Bot` MUST NOT entrar nas contagens de pessoa.

### A tradução do estado

- **FR-007**: A tela MUST nomear o veredito pelo conceito da rede, e MUST NOT exibir o
  enum do GitHub. Guardar e mostrar o cru prenderia a leitura ao vocabulário de um
  forjador.
- **FR-008**: `DISMISSED` e `PENDING` MUST ser tratados como ciclo de vida, e MUST NOT
  receber veredito.
- **FR-009**: O valor cru MUST continuar preservado no registro — a tradução acrescenta
  interpretação, e nunca substitui o que a origem disse.

### O que a página é obrigada a DECLARAR

- **FR-010**: A parcela de execuções sem autoria identificada MUST aparecer ao lado das
  contagens (47%), e MUST NOT ser descontada nem somada.
- **FR-011**: A tela MUST NOT apresentar endosso como "sem problemas encontrados". A rede
  declara que aprovar é ausência de bloqueio, e não de não conformidade.
- **FR-012**: Ausência em qualquer número MUST ser nomeada, e nunca um zero solto.

### O que a feature NÃO faz

- **FR-013**: A feature MUST NOT somar os três papéis.
- **FR-014**: A feature MUST NOT alterar a consulta de coleta nem recoletar. **Medido: o
  dado já está no banco** — 4.233 avaliações, 4.127 com pessoa. Recoletar não traria nada
  e repaginaria 5.635 solicitações em 160 repositórios à toa.

### O que a feature tem de respeitar

- **FR-015**: Nada MUST ser carregado quando a aba está fechada pela regra de visibilidade
  (#369, `FR-012h`).
- **FR-016**: O acréscimo de consultas por render MUST ser nomeado no teste-guarda de
  custo, ou derivado do que já foi carregado. A página está **exatamente** no teto de 23.

---

## Success Criteria *(mandatory)*

- **SC-001**: Quem abre a página vê os três papéis separados, e em nenhum lugar a soma.
- **SC-002**: Quem vê "revisou N" vê também como revisou.
- **SC-003**: Quem procura por que alguém tem muitas revisões e poucas objeções encontra os
  dois números lado a lado, sem abrir o GitHub.
- **SC-004**: Quem soma as páginas e compara com o total encontra a diferença explicada na
  própria tela.
- **SC-005**: A página continua dentro do teto de consultas declarado.
- **SC-006**: Nenhuma coleta é disparada por esta feature.

---

## Key Entities

- **`cmpo.change_request`** — a solicitação. Materializada, com autoria e integração.
- **`qapo.artifact_evaluation`** — a revisão. **Materializada em
  `collected_artifact_evaluations`**, com 4.233 registros.
- **`qapo.evaluation_verdict`** — a posição do avaliador. Três especializações declaradas
  em 2026-08-27, e a tradução vive no `value_map` do mapeamento.
- **`ciro.verification`** — a execução de CI. Materializada.
- **`cmpo.commit`** — a ponte entre pessoa e verificação, com co-autoria.

---

## Assumptions

1. **"Aprovou" é o veredito de endosso, e não um número à parte.** Contar aprovação
   separada de revisão faria a mesma avaliação aparecer duas vezes.

2. **"O commit dela" inclui co-autoria.** Ignorar `is_primary` apagaria participação real.
   A consequência — soma das páginas excede o total — é declarada.

3. **"Quebrou" é `conclusion = failure`.** `cancelled`, `skipped` e nulo não são falha.

4. **As listas mostram as mais recentes, e o corte é dito.**

5. **A tradução do estado acontece na LEITURA**, e não numa coluna nova. O `value_map` é
   dado da base de conhecimento, e materializá-lo criaria uma segunda cópia que diverge
   quando o mapa mudar — é a mesma postura da #514 e da #368.

---

## Dependencies

- **#369** — a regra de visibilidade da aba. Esta feature vive dentro dela.
- **#526** — a tela dos valores não mapeados; até ela, `unmapped: reject`.
- **O elo conta ↔ pessoa observada** — sem ele a aba não abre além de admin. Medido: 0 de
  2 contas com elo declarado.
- **`TheBand.Quality`** — a fachada que já agrega avaliações. `by_reviewer/2` existe; falta
  a leitura por pessoa.
