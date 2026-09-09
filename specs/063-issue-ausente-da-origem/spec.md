# Feature Specification: A issue que deixou de existir na origem

**Feature Branch**: `feat/063-issue-ausente-da-origem`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: *"uma issue deletada foi deletada pelo usuário. Logo, isso
deve ser rastreado. Colocamos isso como estado da issue."*

---

## Por que agora

A pessoa mantenedora apagou a issue `leds-conectafapes/conectafapes-project#333` na origem
— *"era da época da Malu, não tinha sentido nenhum, estava no project errado"* — e a
plataforma continua a mostrando **aberta**, com a mesma confiança com que mostra uma issue
que existe. É o caso 1 de
[`docs/backlog/investigar-estado-divergente-da-issue.md`](../../docs/backlog/investigar-estado-divergente-da-issue.md).

Uma issue que a origem não tem mais e que a tela chama de `open` entra em *Problems now*,
na linha de base do burn, em *Promised × Delivered*, na previsão e no que cada pessoa tem
aberto. **É medida errada que ninguém sabe que está errada** — e é o defeito exato que esta
plataforma existe para não cometer.

### O que foi medido contra a origem em 2026-09-09

Com a credencial da própria plataforma, e nenhum destes números precisa ser medido de novo.

| O que se perguntou | O que a origem respondeu |
|---|---|
| a issue `#333`, por número | `Could not resolve to an Issue with the number of 333.` — `NOT_FOUND` |
| o log de auditoria da organização | `Organization billing plan does not support access to auditLog information.` — `PLAN_NOT_SUPPORTED` |

Da issue apagada **não existe título, autor, data nem quem apagou**. O ato — `issue.destroy`,
com `actorLogin` e `createdAt` — existe **apenas** no `auditLog` da organização, que o GitHub
serve **somente no plano Enterprise**. A `leds-conectafapes` não o tem.

### Quatro causas, uma resposta só

A API devolve `NOT_FOUND` para todas as quatro, e nenhuma consulta as separa:

| Causa | O que aconteceu |
|---|---|
| apagada | alguém a removeu |
| transferida | ela existe, em outro repositório, com outro número |
| repositório privado | ela existe, e a plataforma deixou de poder vê-la |
| token sem acesso | ela existe, e a credencial deixou de alcançá-la |

**A plataforma não sabe que a issue foi apagada. Sabe que ela deixou de vir.** Toda esta
spec decorre dessa frase, e é por isso que `DELETED` não é o nome de nada aqui.

---

## O que a plataforma já tem, medido no código

Nada nesta seção é proposta: é o que está em `development` hoje.

| O que existe | Onde | O que faz |
|---|---|---|
| `collected_issues.no_longer_observed_at` | `work_items/schemas/collected_issue.ex:62` | a marca de *"a origem deixou de trazer isto"*, com data |
| `WorkItems.mark_issues_no_longer_observed/3` | `work_items/commands.ex:292` | grava a marca, **escopada ao repositório** percorrido — a L19 impedida no tipo |
| a chamada, uma vez por repositório | `ingestion/github_work_items.ex:329` | roda **depois** de uma paginação completa das issues daquele repositório |
| `observed_repositories.inaccessible_since` e `inaccessible_reason` | `cmpo/schemas/observed_repository.ex:25` | quando o repositório inteiro deixou de ser alcançado |
| `observed_repositories.issues_collected_at` | idem, `:31` | quando as issues daquele repositório foram percorridas **por inteiro** |
| a frase na tela da issue | `work_item_live/show.ex:102` | *"This issue did not show up in the last collection. Marked on ‹data›. The record stays: absence marks, it never deletes."* |
| o estado composto, **já em uso para quadros** | `board_live/index.ex:317` | `closed` · `no longer at the source` · `open` **só** quando nenhum dos dois |
| `is_nil(no_longer_observed_at)` como *vigente* | `work_items/queries.ex` | em **cinco** lugares: `count_collected_by_repository/2`, `count_assigned_to/2`, `count_authored_by/2` e `repositories_of_person/2` (duas vezes) |

### E o conserto que destravou tudo isto

[PR #847](https://github.com/The-Band-Solution/theband/pull/847), **ainda não mergeado**: o
corte que decide se um repositório vale ser lido comparava `pushedAt` — push de **código** —
e atividade de issue não é push. Repositórios de quadro eram pulados para sempre, e
`mark_issues_no_longer_observed/3` **nunca chegava a rodar neles**. Medido: `plataformas-project`
com push de 21 de julho e issue fechada no dia da medição, 712 issues congeladas.

**Sem o #847 esta feature não tem efeito nos repositórios onde o problema aparece.** É
dependência dura, e está na seção *Dependências*.

O resíduo do #847 — repositório onde uma issue é apagada e **nada mais acontece nunca** — já
tem item próprio em `docs/backlog/revisao-periodica-completa.md`, que chega junto com aquele
PR, e **não é escopo desta spec**.

---

## As cinco decisões desta spec

### D1 — O estado não entra em `collected_issues.state`, e a tela o compõe

**A decisão**: o estado derivado permanece onde já está — a marca temporal
`no_longer_observed_at` —, e **nenhuma coluna nova é criada para ele**. O que passa a
existir é uma **regra de composição** que toda tela aplica, e um nome.

**A razão**: `collected_issues.state` guarda `OPEN` ou `CLOSED` **como a origem os disse**.
Escrever ali um valor que a plataforma derivou faria uma coluna observada carregar dado
derivado — que esta casa não faz em lugar nenhum (princípio III) — e destruiria o original:
no dia em que a origem devolvesse a issue, não haveria de onde restaurar o `state`. A marca,
ao lado, **acrescenta** sem sobrescrever.

**O nome é `no longer at the source`**, e não é invenção: é a palavra que
`board_live/index.ex:318` já usa para quadros que sumiram da origem. Reusá-la é o oposto de
batizar conceito novo.

`DELETED` está **proibido como nome**, pela razão da seção anterior: a plataforma não observou
a deleção. `CLOSED` está proibido por razão mais grave — fechar é **ato de trabalho**, e uma
issue apagada contada como fechada vira **entrega**.

#### A composição, e ela é a regra

| `state` da origem | `no_longer_observed_at` | O que a tela afirma |
|---|---|---|
| `OPEN` | nulo | `open` |
| `CLOSED` | nulo | `closed` (com o motivo, quando houver) |
| `OPEN` | preenchido | **`no longer at the source`** — e **nunca** `open` |
| `CLOSED` | preenchido | `closed` **e** `no longer at the source`, nesta ordem |

**`open` é substituído; `closed` é acompanhado.** `open` afirma trabalho presente, e o que a
origem não tem mais não é trabalho presente. `closed` afirma um fato passado que aconteceu e
continua verdadeiro — a issue foi fechada, e depois sumiu.

#### O que hoje está errado, e é medível na tela

| Onde | O que a tela faz hoje |
|---|---|
| `work_item_live/show.ex:1070` | o cabeçalho diz `open` — `estado/1` lê **só** `state` — enquanto o aviso logo abaixo diz que a issue não veio na última coleta. **Duas afirmações opostas, uma acima da outra** |
| `repository_live/show.ex:347` e `:355` | a coluna `state` diz `open`; a ausência aparece como nota cinza sob o título. Quem lê uma tabela lê a coluna |
| `people_live/show.ex:1089` | a lista de issues da pessoa mostra `state` e **não mostra a ausência de forma alguma** — `list_issues/2` devolve o campo e o template o ignora |

### D2 — As duas causas que a plataforma PODE separar

Das quatro causas, duas classes são distinguíveis **hoje**, sem consulta nova à origem, e é
onde está o valor real.

**O que torna isto possível** é uma garantia do desenho da coleta, e ela precisa estar
escrita porque tudo aqui depende dela: **a marca só é gravada depois de uma paginação
completa das issues do repositório**. `paginar/6` percorre todas as páginas sem filtro de
data (`priv/connectors/github/queries/issues.graphql` não tem `since`), e as três saídas que
não são o sucesso completo **não marcam nada**:

| Saída da coleta | O que acontece com a marca |
|---|---|
| percorreu tudo | marca as que não vieram — `github_work_items.ex:329` |
| pulou pelo corte | **não marca** — `pular/3`, e nem grava `issues_collected_at` |
| erro de GraphQL, `401`/`403`, transporte | **não marca**; grava `inaccessible_since` e o motivo |
| recusa por cota | **não marca**; a etapa para e o resto é da retomada |

Então **uma marca é, por construção, prova de que o repositório foi lido.** É isso que separa
as classes:

| Situação, verificável por consulta | O que a plataforma pode afirmar |
|---|---|
| o repositório tem issues vigentes **e** esta está marcada | **esta issue deixou de existir no repositório** — apagada ou transferida, e a plataforma não sabe qual |
| **todas** as issues do repositório estão marcadas | **o repositório ficou sem issue nenhuma.** A plataforma NÃO afirma que cada uma foi apagada |
| o repositório tem `inaccessible_since` | **nada foi marcado.** A plataforma perdeu alcance, e perder alcance não é o dado sumir |

As duas primeiras se distinguem com o que já existe: `count_collected_by_repository/2`
devolve as vigentes por repositório, e `repositories_with_absent_issues/2` devolve quem tem
marcadas. A terceira já está dita na tela do repositório — `repository_live/show.ex:232`:
*"losing reach does not mark the issues as…"*.

**A quarta situação é a que falta**, e é o resíduo do #847: repositório **pulado pelo corte**.
Nada é marcado e a tela continua dizendo `open` sem dizer há quanto tempo ninguém olhou.
`issues_collected_at` responde isso e não é apresentado junto do estado.

### D3 — O ato existe, está fora de alcance, e o caminho até ele é declarado agora

O `auditLog` do GitHub tem `issue.destroy` com `actorLogin` e `createdAt`. É o **único** lugar
onde o ato existe, e ele responde a pergunta da pessoa mantenedora — *"foi deletada pelo
usuário, isso deve ser rastreado"* — de forma **observada**, não derivada.

Está fora de alcance por **plano da organização observada**, e essa distinção decide quem pode
resolver: não é lacuna da plataforma nem falha de coleta. É decisão comercial de um terceiro.

**O que a plataforma faz hoje**: diz que não alcança, e diz por quê. Ausência é dita.

**O que muda no dia em que o plano permitir** — e está escrito aqui para que não seja
redesenho:

| O que | Como |
|---|---|
| entra uma entidade de origem | `github.audit_log_entry` em `priv/knowledge_base/sources/github.yaml`, que hoje declara treze entidades e nenhuma delas é o log |
| entra um registro coletado | o ato, com `actorLogin`, `createdAt` e o `external_id` da issue; proveniência da coleta, como todo o resto |
| a tela ganha uma frase | *"deleted by ‹quem› on ‹data›"* **ao lado** de *"the platform noticed on ‹data›"* |
| das quatro causas, duas saem | `issue.destroy` → apagada; `issue.transfer` → transferida |

**O que NÃO muda, e é o teste de que o desenho está certo**: o nome do estado, a marca, a
regra de composição de D1 e os filtros de medida de D4. Se a chegada do log exigir mudar
qualquer um dos quatro, o desenho estava errado.

**As duas datas são fatos diferentes e as duas ficam.** Quando o ato aconteceu, e quando a
plataforma notou. Sobrescrever a segunda com a primeira apagaria a informação de quanto tempo
a plataforma afirmou algo errado — que é exatamente o que quem lê um número precisa saber.

#### Um segundo caminho, mais barato, que estreita sem depender do plano

`TRANSFERRED_EVENT` não está entre os onze `itemTypes` que a coleta pede em
`priv/connectors/github/queries/issues.graphql:66`. Ele aparece na *timeline da issue de
destino* e nomeia o repositório de origem. Coletá-lo permitiria à plataforma afirmar
**"transferida de ‹repositório›"** — e parar de chamar de indistinguível — para o subconjunto
em que **o destino também é observado**.

Fica como caminho declarado, não como escopo: o conjunto de campos precisa ser conferido
contra o schema da origem antes de virar requisito, e ele não cobre destino fora do escopo
observado.

### D4 — O efeito nas medidas, e ele é grande

**A issue ausente sai de cinco consultas e fica em muitas outras.** Cada linha abaixo foi
verificada no código de `development`.

| Módulo · função | Filtra a issue ausente? | O que a apagada faz |
|---|---|---|
| `work_items/queries.ex` · `count_collected_by_repository/2`, `count_assigned_to/2`, `count_authored_by/2`, `repositories_of_person/2` | **sim** | sai — são os cinco `is_nil` |
| `work_items/queries.ex` · `count_collected/2`, `list_issues/2` | não, **e está certo** | o catálogo mostra o que existiu; o que falta é a marca na coluna de estado (D1) |
| `work_items/person_work.ex` · `abertas/2` e quem a usa — `assigned_open_count/2`, `open_age_buckets/2`, `timeline_coverage/2`, `issues_assigned_to/2` | **sim** | sai |
| `work_items/person_work.ex` · `state_changes_by_period/3` | **não** | conta como *criada* no período em que foi aberta, e como *fechada* se tinha `closed_at` |
| `work_items/person_work.ex` · `closed_by_month/2`, `lead_time/2` | **não** | entra na série mensal e na mediana |
| `work_items/person_work.ex` · `prazo_do_trabalho_aberto/2` | filtra o **vínculo de sprint**, não a issue | o prazo da pessoa é puxado por trabalho que não existe |
| `work_items/team_work.ex` · **todo o módulo** — `open_at/4`, `open_at_by_team/3`, `open_tasks_by_person/4`, `por_evento/6`, `por_evento_e_equipe/6`, `fechadas_entre/4`, `primeira_atividade/3` | **não, em nenhuma** — zero ocorrências de `no_longer_observed_at` no arquivo | linha de base do burn, faíscas, *Promised × Delivered* e a lista do que cada pessoa tem aberto, todas infladas |
| `teams/problems_now.ex` · `issues_antigas/3` | **não** | a apagada conta no cartão *"aberta há mais de 30 dias"* |
| `ontology/continuum/sro/queries.ex` · `list_sprint_issues/2` | filtra o **vínculo**, não a issue | a apagada continua listada dentro da caixa de tempo |
| `ontology/seon/spo/projects.ex` · `issues/3` | **sim** | sai |
| `mapping/queries.ex` · `title_sample/2`, `issues_for_decision/2`, cobertura de promoção | **não** | entra na amostra e no denominador — **e as duas leituras são defensáveis; ver *Perguntas abertas* 2** |
| `forecast.ex` · `monte_carlo/2` | não se aplica | consome `serie` e `aberto` de `team_work.ex`; **herda o erro inteiro dos dois** |

#### Uma armadilha de nome que fez isto passar despercebido

`team_work.ex` tem `defp vigente_em/2`. Ela não filtra vigência de **issue**: filtra vigência
de **vínculo de pessoa a equipe**. Toda consulta do módulo a chama, e a leitura rápida conclui
que a vigência está tratada. Não está.

#### Duas medidas DECLARADAS têm insumo calculado sem o filtro

| Medida | Insumos afetados |
|---|---|
| `flow.open_work.cumulative` | `item_created_at`, `item_closed_at` e `open_at(window_start)` — todos de `team_work.ex` |
| `flow.completion.forecast` | `open_at_observation_instant`, `weekly_opened_count`, `weekly_closed_count` — os mesmos |

**Nenhuma medida nova nasce desta spec, e nenhuma necessidade de informação nova.** O que
falta às duas é uma linha em `scope.filters` — o mesmo lugar onde elas já declaram *"excluir
vínculo invalidado em qualquer período: ele nunca vigeu"*. Inventar `deleted_issue_ratio`
seria criar número que ninguém sabe interpretar para descrever um filtro que faltou.

**A contagem de issues ausentes que a tela mostra não é medida.** É número de tela, como
`memberships_pending_role` da 055 FR-018: informação sobre o quanto a plataforma sabe, não
sobre o trabalho do time.

### D5 — O que NÃO entra

| Fora | Por quê |
|---|---|
| reconstruir o conteúdo da issue apagada | **não existe.** `NOT_FOUND` não devolve título, autor nem data. O que a plataforma tem é o último estado que ela coletou, e ele é apresentado como tal |
| afirmar a causa quando as quatro são indistinguíveis | a plataforma diria o que não observou. As classes de D2 são o quanto se pode estreitar hoje |
| apagar a linha | ausência marca, nunca apaga. Não existe `delete_issue/2` e não passa a existir |
| tratar a ausência como fechamento | fecharia como **entrega** o que nunca foi entregue |
| a revisão periódica completa | é `docs/backlog/revisao-periodica-completa.md`: exige N, distribuição no tempo e orçamento de cota, e nenhuma se decide por analogia |
| o caso 2 — issue **fechada** na origem e aberta na tela | outro defeito, com outra causa. O mecanismo é o do PR #847 |
| alcançar o `auditLog` | depende do plano de um terceiro. O que é desta spec é **dizer** que não alcança, e por quê |

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quem lê a issue vê que a origem não a tem mais (Priority: P1)

Quem abre uma issue, ou a encontra numa lista, vê **no lugar do estado** que a origem deixou
de trazê-la — e não um `open` desmentido por uma nota cinza três linhas abaixo.

**Why this priority**: é o defeito relatado, e é o único que **toda** tela reproduz hoje.
Enquanto a tela afirmar `open`, nenhuma correção de medida convence quem leu.

**Independent Test**: marcar uma issue como ausente pelo caminho da coleta e percorrer as
três telas que a mostram — detalhe, lista do repositório, lista da pessoa —, conferindo que
nenhuma diz `open`.

**Acceptance Scenarios**:

1. **Given** uma issue com `state` `OPEN` e marca de ausência, **When** alguém abre o
   detalhe, **Then** o estado apresentado é **`no longer at the source`**, e a palavra
   `open` **não aparece** em lugar nenhum da página como estado dela.
2. **Given** uma issue com `state` `CLOSED` e marca de ausência, **When** alguém a vê,
   **Then** aparecem **as duas** afirmações — `closed` e `no longer at the source` —, nesta
   ordem, e o motivo do fechamento continua ao lado de `closed`.
3. **Given** a lista de issues de um repositório, **When** uma delas está marcada, **Then**
   a **coluna de estado** carrega a informação — não apenas uma nota sob o título.
4. **Given** a lista de issues de uma pessoa, **When** uma delas está marcada, **Then** a
   informação aparece; hoje não aparece de forma alguma.
5. **Given** uma issue marcada, **When** a página oferece ir até a origem, **Then** ou a ação
   não é oferecida, ou vem com a ressalva de que o endereço pode não resolver — porque na
   origem ele devolve `NOT_FOUND`.
6. **Given** uma issue vigente, **When** alguém a vê, **Then** **nada muda**: nenhuma marca
   nova, nenhuma coluna nova, nenhum aviso.
7. **Given** qualquer das telas acima, **When** a informação é apresentada, **Then** ela
   **não é carregada só por cor** — a mesma regra da 055 FR-002.

---

### User Story 2 - A issue ausente sai do que a plataforma chama de trabalho presente (Priority: P1)

Nenhum número que responde *"o que está aberto agora"* conta uma issue que a origem não tem
mais. A issue continua no catálogo, marcada; o que ela deixa de fazer é inflar contagem de
trabalho presente.

**Why this priority**: é o dano real. A tela errada engana quem olha aquela issue; o número
errado engana quem decide a partir de um painel, e não tem como desconfiar.

**Independent Test**: contar os cartões e as listas de trabalho presente de uma equipe,
marcar uma issue dela como ausente, recontar, e conferir que **exatamente** os números de
presente mudaram.

**Acceptance Scenarios**:

1. **Given** uma issue aberta e designada a alguém da equipe, há mais de 30 dias, **When**
   ela é marcada como ausente, **Then** o cartão (a) de *Problems now* diminui em um.
2. **Given** a mesma issue, **When** ela é marcada, **Then** ela **desaparece** da lista
   *o que cada pessoa tem aberto* daquela pessoa.
3. **Given** a mesma issue, **When** ela é marcada, **Then** `assigned_open_count/2` e as
   faixas de idade da pessoa diminuem em um — o que já acontece hoje, e o teste existe para
   que continue acontecendo.
4. **Given** a mesma issue, **When** ela é marcada, **Then** o prazo do trabalho aberto da
   pessoa é recalculado sem ela.
5. **Given** um sprint que a continha, **When** ela é marcada, **Then** ela **não** aparece
   mais na lista de issues vigentes daquela caixa de tempo.
6. **Given** qualquer dos números acima, **When** ele muda por causa disto, **Then** a tela
   **diz que mudou por ausência** — ver FR-013. Um número que cai sem explicação é lido como
   entrega.
7. **Given** a issue marcada, **When** alguém a procura no catálogo `/work/issues`, **Then**
   ela **continua lá**, marcada. Sair da medida não é sair do registro.

> **O período passado foi decidido em 2026-09-09**, e a FR-018 deixou de estar pendente: a
> série antiga **mantém** o que foi observado — o burn de agosto continua mostrando os 50 que
> mostrava — e **diz quantos dos seus itens estão hoje ausentes da origem**. Só o número do
> presente cai.
>
> Os sete cenários acima são todos sobre **trabalho presente**, e nunca dependeram dela.

---

### User Story 3 - A plataforma diz o que ela pode saber, e só isso (Priority: P2)

Quem investiga uma issue ausente descobre **qual das situações distinguíveis é a dela** — e
descobre também quando o repositório foi lido pela última vez por inteiro, que é o que torna a
afirmação interpretável.

**Why this priority**: P2 porque a US1 e a US2 já param o dano. Esta transforma "sumiu" em
"sumiu, e eis o que isso pode significar", que é a diferença entre um aviso e uma informação.

**Independent Test**: montar os quatro casos — repositório com vigentes e uma ausente;
repositório com todas ausentes; repositório inacessível; repositório pulado pelo corte — e
conferir que a tela diz coisas diferentes nos quatro.

**Acceptance Scenarios**:

1. **Given** um repositório com issues vigentes e uma marcada, **When** alguém abre a
   marcada, **Then** a tela diz que **o repositório foi percorrido** em ‹data› e **esta
   issue não veio** — e que apagada e transferida são indistinguíveis pela origem.
2. **Given** um repositório cujas issues estão **todas** marcadas, **When** alguém o abre,
   **Then** a tela diz que **o repositório ficou sem issue vigente**, e **não** afirma que
   cada uma foi apagada.
3. **Given** um repositório com `inaccessible_since`, **When** alguém abre uma issue dele,
   **Then** a tela diz que **a plataforma perdeu alcance** e que **nada foi marcado** — o
   estado exibido é o último conhecido, com a data em que foi conhecido.
4. **Given** um repositório **pulado pelo corte**, **When** alguém abre uma issue dele,
   **Then** a tela diz **quando ele foi percorrido por inteiro pela última vez**
   (`issues_collected_at`), ou diz que **não há registro de coleta** quando a data é nula —
   nunca as duas coisas como se fossem a mesma.
5. **Given** qualquer dos quatro casos, **When** a tela fala, **Then** ela **não usa a
   palavra apagada**, nem `deleted`, nem `DELETED`.

---

### User Story 4 - A ausência tem história, e a história não é apagada (Priority: P2)

Uma issue que sumiu, foi marcada, e voltou a aparecer **deixa registro dos dois momentos**.
Quem lê um painel antigo consegue saber que aquele número esteve errado, e por quanto tempo.

**Why this priority**: P2 porque é a diferença entre *"isso deve ser rastreado"* e *"isso é
sinalizado enquanto durar"*. Sem ela, a plataforma sabe da ausência apenas enquanto ela
persiste.

**O defeito, no código de hoje**: `record_collected_issue/2` (`work_items/commands.ex:44`)
grava `no_longer_observed_at: nil` a cada reobservação, com o comentário *"Quem quer saber
que a marca saiu lê a marca"* — mas a marca acabou de ser sobrescrita, e **nada resta**. É
o oposto do que a irmã declarada faz: a 055 FR-015 exige que vínculo observado que volta
nasça **novo**, com os dois períodos coexistindo.

**Independent Test**: marcar, reobservar, e perguntar ao banco se a plataforma sabe que
houve uma ausência entre as duas datas.

**Acceptance Scenarios**:

1. **Given** uma issue marcada em ‹d1›, **When** a origem volta a trazê-la em ‹d2›, **Then**
   o estado apresentado volta a ser o da origem **e** a plataforma registra que ela esteve
   ausente entre ‹d1› e ‹d2›.
2. **Given** uma issue que sumiu e voltou duas vezes, **When** alguém consulta a história,
   **Then** os **dois** intervalos existem, e nenhum sobrescreveu o outro.
3. **Given** uma issue com história de ausência mas vigente hoje, **When** alguém a vê numa
   lista, **Then** o estado é o da origem — a história **não** contamina o estado presente.
4. **Given** uma issue com história de ausência, **When** alguém abre o detalhe, **Then** a
   história está disponível ali, e não só no banco.

---

### User Story 5 - A plataforma diz que não alcança o ato, e diz de quem é a decisão (Priority: P3)

Quem pergunta *"quem apagou?"* recebe uma resposta honesta: **a plataforma não pode saber**,
o lugar onde o ato existe é o log de auditoria da organização, e ele está fora de alcance
pelo **plano** dela.

**Why this priority**: P3 porque não muda número nenhum. Vale porque a alternativa observada
hoje é a tela silenciar, e silêncio sobre ator é lido como *"não teve ator"*.

**Independent Test**: abrir uma issue marcada numa organização sem o plano e ler a frase.

**Acceptance Scenarios**:

1. **Given** uma issue marcada, **When** alguém abre o detalhe, **Then** a tela diz que
   **quem e quando** vivem no log de auditoria da organização, e que a plataforma **não o
   alcança**, com o motivo — o plano da organização observada.
2. **Given** a mesma tela, **When** ela apresenta a data da marca, **Then** ela **não** a
   apresenta como data da deleção: a marca diz quando a plataforma notou.
3. **Given** o motivo apresentado, **When** alguém o lê, **Then** fica claro que **não é
   lacuna da plataforma nem falha de coleta** — é decisão de um terceiro, e só ele a muda.

> Os cenários em que o log **está** ao alcance não são critérios de aceitação desta feature:
> não há como produzir evidência deles hoje (`PLAN_NOT_SUPPORTED`), e critério sem evidência
> possível não é critério. Eles estão em D3 como caminho declarado.

---

### Edge Cases

- **Repositório onde as issues foram desativadas na origem.** A consulta devolve sucesso com
  zero issues, e **todas** as vigentes seriam marcadas de uma vez. Cai na segunda classe de
  D2 — *"o repositório ficou sem issue vigente"* —, que é a afirmação certa, mas a causa é
  outra. A plataforma **não** deve tentar distinguir; deve dizer o que observou.
- **Issue transferida para repositório também observado.** A plataforma passa a ter duas
  linhas — a marcada na origem e a nova no destino — sem saber que são a mesma. É o caso que
  o `TRANSFERRED_EVENT` de D3 fecharia, e **hoje ele fica como duplicidade não detectada**.
- **Issue apagada que estava promovida a user story.** A promoção continua no banco,
  apontando para uma issue ausente. A classificação da issue-pai conta **só vínculos
  vigentes** (`github_work_items.ex:41`), mas a **promoção** não olha ausência — ver a
  pergunta aberta 2.
- **Issue apagada que era pai de outras.** Os vínculos de decomposição dela são marcados por
  `mark_decomposition_links_no_longer_observed/3`, escopado ao repositório do pai. As filhas
  ficam sem pai, e é a situação correta — o que falta é a tela da filha dizer isso.
- **Marca gravada por engano numa coleta parcial.** Não pode acontecer pelo desenho — as três
  saídas não-completas não marcam —, mas se acontecer, a US4 é o que permite descobrir.
- **A issue apagada tinha designados.** `problems_now.issues_antigas/3` não filtra designação
  ausente **nem** issue ausente. São dois defeitos na mesma consulta, e o segundo é desta
  spec; o primeiro é nomeado aqui e **não** é escopo.

---

## Requirements *(mandatory)*

### O estado e a sua apresentação

- **FR-001**: O estado derivado MUST viver na marca `collected_issues.no_longer_observed_at`,
  que já existe. Nenhuma coluna nova MUST ser criada para ele, e
  `collected_issues.state` MUST continuar guardando **apenas** o que a origem disse.
- **FR-002**: O nome apresentado MUST ser **`no longer at the source`** — o mesmo já usado
  para quadros em `board_live/index.ex`. As palavras `deleted`, `DELETED` e `apagada`
  MUST NOT ser usadas para este estado.
- **FR-003**: Toda tela que apresenta o estado de uma issue MUST compor origem e marca pela
  tabela de D1: `open` é **substituído** pelo estado derivado; `closed` é **acompanhado** por
  ele.
- **FR-004**: A informação MUST aparecer **onde o estado aparece** — coluna de estado nas
  listas, cabeçalho no detalhe —, e MUST NOT ser carregada apenas por nota secundária nem
  apenas por cor.
- **FR-005**: A ação de ir até a origem MUST ou ser suprimida, ou vir com a ressalva de que
  o endereço pode não resolver.
- **FR-006**: Issue vigente MUST NOT ganhar marca, aviso ou coluna nova.

### O que a plataforma pode afirmar

- **FR-007**: A plataforma MUST apresentar, para uma issue marcada, **qual das situações
  distinguíveis** é a dela, entre as três de D2, e MUST NOT afirmar a causa quando ela é
  indistinguível.
- **FR-008**: Quando o repositório tem issues vigentes e esta está marcada, a plataforma MUST
  afirmar que o repositório foi percorrido em ‹data› e que esta issue não veio, **e** MUST
  dizer que apagada e transferida não são distinguíveis pela origem.
- **FR-009**: Quando **todas** as issues do repositório estão marcadas, a plataforma MUST
  afirmar que o repositório ficou sem issue vigente, e MUST NOT afirmar que cada uma foi
  apagada.
- **FR-010**: Quando o repositório tem `inaccessible_since`, a plataforma MUST afirmar que
  perdeu alcance e que **nada foi marcado**, apresentando o último estado conhecido com a
  data em que foi conhecido.
- **FR-011**: Toda afirmação sobre ausência MUST vir acompanhada de **quando o repositório
  foi percorrido por inteiro** (`issues_collected_at`). Data nula MUST ser apresentada como
  *"não há registro de coleta"*, e nunca como *"não coletado"* — a mesma distinção que
  `work_item_live/index.ex:528` já sustenta.
- **FR-012**: A marca MUST NOT ser gravada por coleta que não percorreu o repositório por
  inteiro. Esta garantia já existe no código e MUST ganhar teste que a fixe, porque tudo em
  D2 depende dela.

### As medidas

- **FR-013**: Nenhum número que responde *"o que está aberto agora"* MUST contar issue
  marcada. Alcança, no mínimo: `teams/problems_now.ex · issues_antigas/3`;
  `work_items/team_work.ex · open_at/4`, `open_at_by_team/3`, `open_tasks_by_person/4`,
  `primeira_atividade/3`; `work_items/person_work.ex · prazo_do_trabalho_aberto/2`;
  `ontology/continuum/sro/queries.ex · list_sprint_issues/2`.
- **FR-014**: Quando um número muda por causa de ausência, a tela MUST dizer que mudou por
  ausência. Queda sem explicação é lida como entrega, e esta é a leitura errada mais cara
  desta feature.
- **FR-015**: A issue marcada MUST continuar aparecendo no catálogo `/work/issues` e na
  listagem do repositório, com o estado de FR-002. Sair da medida MUST NOT ser sair do
  registro.
- **FR-016**: `flow.open_work.cumulative` e `flow.completion.forecast` MUST declarar em
  `scope.filters` o tratamento dado à issue ausente, no mesmo lugar e na mesma forma em que
  já declaram *"excluir vínculo invalidado em qualquer período"*.
- **FR-017**: Nenhuma medida nova e nenhuma necessidade de informação nova MUST nascer desta
  feature. A contagem de issues ausentes exibida na tela é **número de tela**, como
  `memberships_pending_role` (055, FR-018), e MUST NOT ser apresentada como medida.
- **FR-018**: A issue marcada MUST NOT ser removida das séries de **período passado** —
  `state_changes_by_period`, `por_evento/6`, `fechadas_entre/4`, `closed_by_month/2`,
  `lead_time/2` e a linha de base `open_at/4` num instante passado mantêm o que foi
  observado naquele período.

  **E a série passada MUST dizer quantos dos seus itens estão hoje ausentes da origem.**
  Sem essa ressalva, manter o número vira silêncio sobre um valor que se sabe contaminado —
  e quem compara o passado com o presente não consegue reconciliar a diferença.

  **Decisão da pessoa mantenedora, 2026-09-09** (leitura B da pergunta aberta 1, agora
  fechada). A razão, com o caso concreto: em agosto o burn mostrava 50 itens abertos, e um
  deles era a issue apagada em setembro. O gráfico de agosto continua mostrando **50**,
  porque naquele dia ela **estava** no quadro e as pessoas a viam — a série registra o que
  era verdade então. Só o número de **hoje** cai para 49.

  Recalcular o passado faria gráficos já vistos mudarem sozinhos, e dois relatórios do mesmo
  mês discordarem sem nada explicando. É coerente com a **055 FR-005** — *"registrar a saída
  MUST NOT alterar nenhum número de período anterior"* — e com *"nada é apagado"*.

  **As duas perguntas são diferentes**: *"o que estava aberto naquele momento"* e *"o que
  está aberto agora"*. A ausência responde só a segunda.

### O ato, e o que dele se pode dizer

- **FR-019**: A plataforma MUST dizer, na issue marcada, que **quem e quando** vivem no log
  de auditoria da organização observada e que ela **não o alcança**, com o motivo.
- **FR-020**: O motivo MUST identificar que a limitação é do **plano da organização
  observada**, e não lacuna da plataforma nem falha de coleta.
- **FR-021**: A data da marca MUST NOT ser apresentada como data da deleção. Ela diz quando a
  plataforma notou.
- **FR-022**: O desenho MUST admitir o registro do ato **ao lado** da marca, sem sobrescrevê-la,
  para que a chegada do log seja acréscimo e não redesenho. As duas datas — do ato e da
  constatação — MUST poder coexistir.

- **FR-022a**: A plataforma MUST apresentar o **intervalo** em que a ausência aconteceu, e
  não uma data única. As duas pontas são observadas e nenhuma é inventada:

  | ponta | de onde vem | o que afirma |
  |---|---|---|
  | início | `last_observed_at` | a última coleta em que a issue **ainda estava lá** |
  | fim | `no_longer_observed_at` | a coleta em que **já não estava** |

  A frase é *"deixou de ser observada entre X e Y"*, e **MUST NOT** ser *"apagada em Y"* —
  pela mesma razão da FR-021. O que aconteceu no meio do intervalo a plataforma não viu.

  **Decisão da pessoa mantenedora, 2026-09-09.** Uma data única obrigaria a escolher entre
  duas mentiras: `last_observed_at` sugere que ainda estava lá quando já não estava, e
  `no_longer_observed_at` sugere que o ato foi naquele instante. O intervalo é o cerco, e é
  o que de facto se sabe.

- **FR-022b**: A **largura** do intervalo MUST ser legível, porque ela mede a qualidade da
  observação e não o comportamento de quem apagou.

  Com coleta diária são horas. Com o corte quebrado — o defeito que o PR #847 consertou, em
  que repositório de quadro era pulado por não receber push de código — eram **semanas ou
  meses**: a issue 703 ficou desatualizada de 04/09 até 09/09, e só porque alguém reparou.

  **Um intervalo largo é uma afirmação sobre a plataforma**, e não sobre a issue: diz por
  quanto tempo ela esteve cega naquele repositório. Apresentá-lo sem isso convidaria a ler
  demora de coleta como demora de quem trabalha.

- **FR-022c**: Quando o log de auditoria for alcançável (FR-019), o **instante do ato** entra
  ao lado e o intervalo **continua** — as duas coisas respondem perguntas diferentes:

  - o instante responde *"quando foi apagada"*;
  - o intervalo responde *"por quanto tempo a plataforma afirmou algo errado"*.

  Substituir o segundo pelo primeiro apagaria a única medida que a plataforma tem da própria
  cegueira, e é justamente a que ninguém pede e todos precisam depois.

### A história da ausência

- **FR-023**: Reobservar uma issue marcada MUST preservar o registro de que houve ausência,
  com início e fim. Hoje a marca é sobrescrita com nulo e nada resta.
- **FR-024**: Ausências sucessivas MUST produzir intervalos distintos que coexistem, como a
  055 FR-015 já exige do vínculo observado.
- **FR-025**: A história de ausência MUST NOT alterar o estado presente: issue vigente hoje
  aparece com o estado da origem.
- **FR-026**: Nenhuma linha MUST ser removida fisicamente, em nenhum caminho desta feature.

### A regra na base de conhecimento

- **FR-027**: A leitura da ausência MUST viver em `priv/knowledge_base/rules/`, como regra de
  derivação com `provider: platform`, e MUST NOT viver em constante de módulo — FR-069 da
  spec 060. A regra declara: que ausência não é fechamento; a composição de D1; e o critério
  que separa as situações de D2.
- **FR-028**: A coleta MUST reportar, por repositório e por execução, **quantas issues foram
  marcadas**. Hoje o número é descartado — `github_work_items.ex:328` casa `{:ok, _}` — e o
  relatório traz `vinculos_ausentes` sem o par de issues.

### Regras que valem em toda a feature

- **FR-029**: Toda consulta MUST ser escopada ao tenant.
- **FR-030**: Ausência MUST ser dita, nunca apresentada como zero. Zero afirma que se olhou e
  não havia; ausência afirma que não se sabe.
- **FR-031**: A plataforma MUST NOT inferir a causa a partir de padrão de título, de autor,
  de tempo desde a criação ou de qualquer heurística. Padrão largo erra para o lado barato.

### Key Entities

- **Issue coletada**: já existe. Ganha **estado apresentado** como composição de `state` e
  `no_longer_observed_at` — sem coluna nova para o estado.
- **Intervalo de ausência**: **novo**. Quando a ausência começou a ser constatada e quando
  deixou de ser. Sucessivos coexistem.
- **Registro do ato** *(caminho declarado, fora do escopo de entrega)*: quem apagou e quando,
  vindo do log de auditoria. Aponta para a issue, **ao lado** da marca.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **Zero** telas apresentam `open` para uma issue marcada — verificável
  percorrendo as três que a mostram hoje, com a issue marcada em cada uma.
- **SC-002**: **100%** das issues marcadas exibem o estado derivado **na posição do estado**,
  e a informação sobrevive à leitura sem cor.
- **SC-003**: Marcar **uma** issue de uma equipe faz **exatamente** os números de trabalho
  presente daquela equipe caírem em um — cartão (a) de *Problems now*, `open_at` no instante
  atual, a lista da pessoa e a lista do sprint — e **nenhum outro** número muda. Conferido
  contando antes e depois.
- **SC-004**: A contagem de issues marcadas hoje na `leds-conectafapes` é **medida**, por
  consulta ao banco de produção, e registrada. **O valor não é presumido**: é ele que decide
  se isto é conserto de coleta ou limpeza pontual, e é a pergunta 2 do caso 1 do item de
  investigação.
- **SC-005**: **Zero** linhas removidas fisicamente, conferível por consulta.
- **SC-006**: Uma issue que sumiu e voltou tem **um** intervalo de ausência registrado; que
  sumiu e voltou duas vezes tem **dois**.
- **SC-007**: **100%** das issues marcadas apresentam, junto do estado, a data em que o
  repositório foi percorrido por inteiro — ou a frase de ausência de registro quando ela é
  nula.
- **SC-008**: **Zero** ocorrências das palavras `deleted`/`apagada` como estado de issue, em
  tela ou em coluna de banco, conferível por busca no código.
- **SC-009**: Toda execução de coleta reporta o número de issues marcadas por repositório, e
  o relatório da execução o mostra ao lado de `vinculos_ausentes`.

---

## Fora de escopo

- reconstruir o conteúdo da issue apagada;
- afirmar a causa entre as quatro indistinguíveis;
- a revisão periódica completa — `docs/backlog/revisao-periodica-completa.md`;
- o caso 2 do item de investigação — a issue **fechada** na origem exibida como aberta;
- coletar o `auditLog` da organização;
- coletar `TRANSFERRED_EVENT` para detectar transferência;
- detectar que a issue nova no destino é a mesma que sumiu na origem;
- o filtro de **designação ausente** em `problems_now.issues_antigas/3` — defeito vizinho, na
  mesma consulta, com outra causa;
- desenhar a tela. A spec diz o que a tela precisa **afirmar**; o protótipo é do Design.

---

## Premissas

- **A coleta continua sendo a única fonte da marca.** Ninguém marca uma issue como ausente
  pela tela. Marca manual seria declaração vestida de observação.
- **A marca só existe depois de percorrer o repositório por inteiro.** É garantia do desenho
  atual, e a FR-012 a fixa em teste porque D2 inteira depende dela.
- **O PR #847 entra antes.** Sem ele, a marca não roda nos repositórios de quadro — que são
  onde os dois casos relatados aconteceram.
- **O último estado coletado continua sendo apresentado**, identificado como último estado
  conhecido, com a data. Não apresentá-lo deixaria a issue sem título na tela.
- **A tela é em inglês**, como o resto da interface hoje. A decisão sobre português
  (`docs/backlog/portugues-na-interface.md`) vale para esta tela como para as outras, e não é
  desta spec.
- **O plano da organização observada não muda por causa desta feature.** O caminho de D3 é
  declarado para não ser redesenho, não porque haja previsão de acontecer.

---

## Perguntas abertas — para a pessoa mantenedora

### 1. ~~A ausência é retroativa nas séries de período passado?~~ **DECIDIDA em 2026-09-09**

**Leitura B, com a ressalva na tela** — a recomendação deste papel, escolhida pela pessoa
mantenedora. Está na **FR-018**, que deixou de estar pendente.

O registro das duas leituras fica abaixo, porque a decisão se lê melhor com a alternativa
que ela recusou ao lado.

| Leitura | O que faz | Coerente com |
|---|---|---|
| **A — retroativa** | a issue sai de **toda** série, inclusive de períodos passados. Gráficos antigos mudam | *"a origem diz que aquilo não existe"* — e o caso real: *"não tinha sentido nenhum"* |
| **B — da marca para a frente** | *Promised × Delivered*, `closed_by_month` e `lead_time` **mantêm** o que foi observado no período; só o trabalho presente perde a issue | 055 FR-005 — *"registrar a saída MUST NOT alterar nenhum número de período anterior"* — e *"nada é apagado"* |

**Foi esta a escolhida: B, com uma ressalva na tela.** As duas perguntas são diferentes
— *"o que estava aberto naquele momento"* e *"o que está aberto agora"* —, e a segunda é a
única que a ausência responde. Mas a série passada MUST então dizer **quantos dos seus itens
estão hoje ausentes da origem**; sem isso, B vira silêncio sobre um número que se sabe
contaminado.

**Não bloqueia** a US1, a US3, a US4, a US5 nem os sete cenários da US2 — todos sobre presente.

### 2. A issue ausente entra no denominador da cobertura de promoção? **BLOQUEIA a FR relativa a `mapping/queries.ex`, e nada mais**

`title_sample/2`, `issues_for_decision/2` e a cobertura em `mapping/queries.ex` contam as
ausentes. Duas leituras, e as duas são defensáveis:

- **conta**: a pergunta é *"o que a regra decidiu sobre tudo o que já coletei"*, e a issue foi
  coletada. Tirá-la mudaria a cobertura sem nenhuma regra ter mudado;
- **não conta**: a cobertura é apresentada como estado atual, e um denominador com issues que
  a origem não tem mais faz a cobertura parecer pior do que é.

Nenhum requisito desta spec depende da resposta. Ela decide **uma linha** de código.

### 3. O intervalo de ausência é uma tabela, ou dois campos e um contador?

A forma completa — uma linha por intervalo — é a que a 055 FR-015 usa para vínculo. A forma
barata — primeira ausência, última ausência, quantas vezes — cabe na tabela existente e perde
os intervalos do meio.

**Não bloqueia**: a FR-023 e a FR-024 fixam o que precisa ser verdade; a forma é do plano.
Fica aqui porque a decisão tem custo e alguém vai querer opinar.

### 4. O repositório sem nenhuma issue vigente ganha marca própria?

A segunda classe de D2 é hoje derivada por consulta. Marcar o **repositório** tornaria a
afirmação um fato registrado em vez de recalculado.

**Não bloqueia**: FR-009 é satisfeita pela consulta.

### 5. A contagem de marcadas aparece onde?

Na tela do repositório, na de sincronizações, nas duas? FR-028 exige o número no relatório da
execução; onde ele é **exibido** é decisão de tela.

**Não bloqueia**: é pergunta para o Design, junto do protótipo.

---

## Dependências

| De que | Por quê | Estado |
|---|---|---|
| [PR #847](https://github.com/The-Band-Solution/theband/pull/847) | sem ele a marca não roda nos repositórios de quadro, e a feature não tem efeito onde o problema apareceu | **aberto** |
| protótipo aprovado pelo Design | há tela, e tela desta casa tem protótipo antes do código | **não iniciado** |
| decisão da pergunta aberta 1 | FR-018 | **pendente** |

---

## Impacto

### Base de conhecimento

- **nova**: uma regra de derivação em `priv/knowledge_base/rules/` com a leitura da ausência,
  a composição de D1 e o critério de D2 (FR-027);
- **alteradas**: `flow_open_work_cumulative.yaml` e `flow_completion_forecast.yaml` ganham a
  linha de `scope.filters` (FR-016);
- **nenhuma** necessidade de informação nova, **nenhuma** medida nova (FR-017);
- **caminho declarado, não alterado agora**: `sources/github.yaml` ganharia
  `audit_log_entry` no dia do plano (D3).

### Consultas

`teams/problems_now.ex` · `work_items/team_work.ex` (o módulo inteiro) ·
`work_items/person_work.ex` (parcial) · `ontology/continuum/sro/queries.ex` ·
possivelmente `mapping/queries.ex`, conforme a pergunta aberta 2.

### Telas

detalhe da issue · lista de issues do repositório · lista de issues da pessoa · painel da
equipe (*Problems now*, burn, *Promised × Delivered*, o que cada pessoa tem aberto) ·
relatório da sincronização.

### Coleta

`ingestion/github_work_items.ex` — deixar de descartar a contagem de marcadas (FR-028), e o
teste que fixa a garantia da FR-012.

---

## Referências

- [`docs/backlog/investigar-estado-divergente-da-issue.md`](../../docs/backlog/investigar-estado-divergente-da-issue.md) — os dois casos, com URL na origem e na plataforma
- `docs/backlog/revisao-periodica-completa.md` — o resíduo do corte, fora desta spec; **chega com o PR #847**, e por isso não há link
- [spec 055](../055-equipes-declaradas/spec.md) — FR-005, FR-015 e FR-016: o precedente de como esta casa trata o que a origem deixou de mostrar
- [spec 060](../060-tela-da-equipe/spec.md) — FR-069, o limiar que não vive em constante de módulo
- `priv/knowledge_base/rules/team_dashboard_thresholds.yaml` — a forma de uma regra de plataforma
