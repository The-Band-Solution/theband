# Segunda revisão semântica — 076, análise de rede

**Papel**: Ontology & Semantic Integration (AGENTS.md §13), que pode bloquear. **Data**: 2026-10-04.
**Issue**: #1309. **Origem**: decisão D6 (a) da pessoa mantenedora, 2026-10-04.

**Declaração de independência**: o autor desta revisão não escreveu a spec, a proposta da base,
a primeira revisão ([revisao-semantica.md](revisao-semantica.md)), a avaliação de segurança nem
o protótipo. Recebeu a branch na ponta `4120f5c` e trabalhou na `feature/1309-revisao-semantica-2`.

**Objeto**: [revisao-semantica.md](revisao-semantica.md); [proposta-base/](proposta-base/) — a
necessidade `network.structure`, as 20 medidas, as regras `assignment.network.edge`,
`network.analysis.parameters` e `network.position_role` e a emenda a `review.network.parameters`;
as seções de [spec.md](spec.md) que tocam semântica; e o protótipo aprovado
([prototipo/](prototipo/)) só no que ele diz sobre a semântica.

**Réguas**: AGENTS.md §6, §8 e §11; `priv/knowledge_base/ontology/` (EO, SPO, SRO, QAPO, CMPO,
OSDEF); `priv/knowledge_base/schemas/`; a base da 073 já em `priv/knowledge_base/`; a coleta
(`lib/the_band/work_items/`, `lib/the_band/ingestion/github_work_items.ex`,
`priv/connectors/github/queries/issues.graphql`); a referência
`scratchpad/ref-dashboard/dashboard_team_graph.py`; e a literatura citada na própria proposta.

**Decisões já tomadas** (2026-10-04, tabela no fim da spec): D1 (a), D2 (a), D3 (a), D4 (a),
D5 (a), D6 (a), DS1 (b), DS2 = 3, DS3 (a), DS4 (a), DS5 (b). Esta revisão as toma como dadas.

---

## Veredito: **aprova com emendas**

Não bloqueia o plano. O núcleo se sustenta: a aresta está declarada como **regra derivada**, com
`equivalence: partial`, justificativa e limitações; as fórmulas de Brandes, de Wasserman e Faust,
de Latora e Marchiori, de Newman e de Humphries e Gurney estão certas; ausência nunca vira zero;
nenhum id inexiste e nenhuma dependência vai do geral para o específico.

Um achado é **alto** (A1): a spec e a proposta diziam *"assigns to"* e *"receives from"*, e o
protótipo diz *"delegation"* em toda a tela. As duas formas atribuem ao autor da issue o ato de
designar, que é exatamente o que a D1 e a S1 da primeira revisão dizem que a aresta **não** observa.
Corrigido na spec e na proposta; o protótipo ficou registrado como divergente, e o código segue a
spec.

Quatro achados médios ficam como **condição do plano**, não da spec: A3 (o tipo da conta não ligada
não está gravado, e bot vira "sem pessoa ligada"), A5 (Q_rand sem peso), A6 (o nulo do σ tem nós
isolados que a rede real não tem) e A7 (se a marca de conta da organização vale também para a rede
de revisão da 073, que a D3 não decidiu).

---

## 1. Achados

### A1 — Alto: o vocabulário da tela atribuía ao autor o ato de designar — **emenda aplicada**

A D1 escolheu a aresta autor → responsável **com o nome "designação"**, e a primeira revisão (S1)
mostra por quê: quem abriu a issue não é necessariamente quem designou
(`AssignedEvent.actor`, `priv/connectors/github/queries/issues.graphql:86`). Mesmo assim, o texto
que vai para a tela dizia o contrário:

| onde | dizia | por que é errado |
|---|---|---|
| `spec.md:147` (US5, cenário 2) | *"assigns to"* / *"receives from"* | "Ana assigns to Bia" afirma que Ana designou |
| `spec.md:208`, `:216` (US9) e FR-048 | *"para quantas pessoas designa … e de quantas recebe"*; *"assigns to 2 people"*, *"receives from 3 people"* | idem; e "receber de" sugere entrega de trabalho |
| `proposta-base/measurements/network_degree_count.yaml:16-18` | `assignment: "assigns to"`, `"receives from"` | é o rótulo que a tela usa |
| `proposta-base/measurements/assignment_network_edge_weight_count.yaml:18` | *"de quem ela recebe"* | idem |
| `prototipo/network-analysis.html` (25 ocorrências) e `prototipo/README.md` | *"delegation"*, *"assigned … issues to"* | delegar é ato de quem delega; a primeira revisão recusou o nome |

"Designação" sem agente era a solução, e a tela tinha voltado a pôr um agente nela. É o caso que
o AGENTS.md §6 chama de distinção que corrompe medida: a pergunta "quem distribui trabalho?" seria
respondida com o dado de "quem abre issues", e ninguém perceberia.

**Emenda aplicada**: os rótulos passam a ser *"opened issues assigned to"* (saída) e *"assigned on
issues opened by"* (entrada), em `network_degree_count.yaml:16-18`, `:33` (limitação nova),
`assignment_network_edge_weight_count.yaml:18`, e na spec: US5 cenário 2 (`spec.md:148`), US9
(`:208`, `:217`) e FR-048. O protótipo está aprovado e não foi alterado; o README dele registra que
a tela usa *assignment*, e não *delegation* (`prototipo/README.md`, *Aprovação*).

**Não alterado**: `seguranca.md:168` e `:251` citam *"assigns to"* como exemplo de texto da tela. O
argumento de segurança não muda com o rótulo; a citação fica para o dono do documento atualizar.

**A distinção designação ≠ execução ≠ colaboração** está preservada no resto: a aresta não usa
`spo.is_in_charge_of` (`seon/spo/modules/processes_and_activities.yaml:240`, alvo
`spo.performed_project_activity`) nem `sro.developer_in_charge_of_development_task`
(`continuum/sro/modules/scrum_stakeholder_participation.yaml:55`, alvo
`sro.performed_scrum_development_task`); as duas são de execução, e a recusa está certa e escrita
(`assignment_network_edge.yaml`, `ufo_category`). Nenhum texto da spec ou da proposta chama a
aresta de colaboração; `grep -i colabora` só encontra negações e a citação da referência.

### A2 — Médio: a categoria UFO da aresta dizia que a issue é sempre objeto social — **emenda aplicada**

`assignment_network_edge.yaml` dizia que os fundamentos da aresta são fatos *"sobre o MESMO objeto
social (a issue, que na SRO é `sro.user_story`, `sro.intended_scrum_development_task`, `sro.epic`,
ou `osdef.defect`…)"*. Conferido na base:

| conceito | `ufo_category` | onde |
|---|---|---|
| `sro.user_story` | `social_object` | `continuum/sro/modules/product_and_sprint_backlog.yaml:26` |
| `sro.epic` | `social_object` | `…/product_and_sprint_backlog.yaml:48` |
| `sro.intended_scrum_development_task` | `intention` | `…/product_and_sprint_backlog.yaml:101` |
| `osdef.defect` | `disposition` | `seon/osdef/modules/defects_and_failures.yaml:24` |

Dois dos quatro não são objeto social. E, no defeito, a issue **não é** o defeito: é o relato dele —
a mesma distinção que o AGENTS.md §6 faz entre documento de requisito e requisito.

**Emenda aplicada** (`assignment_network_edge.yaml:61-85`): o fundamento é o **registro** da
ferramenta (a issue coletada), e a aresta não herda a categoria do conceito ao qual o registro foi
promovido. O resto da classificação está certo e foi mantido: **relação derivada, sem relator**. Se
houver compromisso social na designação, ele liga quem designou (ou a organização) ao responsável,
e o autor da issue não participa dele. Por isso não há id de conceito, módulo nem tabela com
`internal_id`.

### A3 — Médio: o tipo da conta não ligada não está gravado, e bot vira "sem pessoa ligada" — **limitação aplicada; tarefa do plano**

A regra classifica conta não ligada por `Mapper.account_type/1`
(`assignment_network_edge.yaml`, `exclusions`, item 1). Essa função decide por `__typename` e, sem
ele, pelo sufixo `[bot]` do login (`lib/the_band/semantic_integration/mapper.ex:94-101`). Mas:

- a consulta traz `author { __typename login … on User { id name } }` e
  `assignees … { __typename id login name }` (`issues.graphql:44-45`);
- `collected_issues` guarda `author_login` e `author_person_id`, e **não** o tipo
  (`lib/the_band/work_items/schemas/collected_issue.ex:37-38`); `issue_assignees` guarda `login` e
  `person_id`, e **não** o tipo (`…/schemas/issue_assignee.ex:25-28`);
- a coleta não cria pessoa para conta `Bot` (`github_work_items.ex:532-570`), e o autor `Bot` nem
  tem `id` na consulta, que só pede `id` `on User`.

Então, para conta de máquina não ligada, a regra só tem o login. Se o login vier sem o sufixo
`[bot]`, a conta cai em `unlinked_person` em vez de `bot_or_app`. **Quantas contas vêm sem o sufixo
não foi medido.** Na GraphQL o login de `Bot` costuma vir sem o sufixo, e uma conta de agente
designável (`Copilot`) é `Bot`. As duas hipóteses são verificáveis nos payloads brutos que a coleta
já guarda.

Nenhuma aresta errada nasce disso: as duas exclusões tiram a conta da rede. Mas a contagem por
motivo, que é a FR-007 e o SC-001, sai errada, e no sentido que a 073 recusou: "não saber quem é"
no lugar de "saber que é máquina". A rede de revisão já resolveu o mesmo problema gravando
`author_type` (`priv/knowledge_base/rules/review_network_edge.yaml:87`, `:132-135`).

**Aplicado**: limitação nova em `assignment_network_edge.yaml:215-225`. **Para o plano**: persistir
o tipo da conta do autor e de cada responsável (a consulta já o traz; é migração e mapeamento), ou
declarar a subcontagem e medir quantas contas ela atinge. Não bloqueia a spec.

### A4 — Médio: o protótipo aprovado diverge da base em método — **registrado; vale a base**

O protótipo foi gerado antes da proposta da base, e as premissas dele (`prototipo/README.md`,
*Premissas*, *Medidas novas*) divergem dela em cinco pontos:

| protótipo | base proposta | o que vale |
|---|---|---|
| comunidades por **Louvain** (`README.md:38`, `:131`) | Clauset-Newman-Moore guloso, com peso e desempate declarado (`network_analysis_parameters.yaml`, `communities`) | a base: Louvain é aleatorizado, e "igual à referência" é o guloso |
| σ contra **50** aleatórios; **"not tested"** em rede partida (`README.md:143`; `network-analysis.html:405`) | 100 aleatórios G(n, m); σ calculado em rede desconexa pela regra de pares que se alcançam, e ausente só pelos motivos da medida | a base (FR-041, FR-042) |
| autovetor **sem deslocamento**, ausente para todos se não assentar (`README.md:142`) | iteração sobre A + I, **por componente**, ausente só no componente que não converge | a base (FR-036) |
| papel como *"on many paths between communities"* (`README.md:88`) | *"in shortest paths between other people that pass through them"* (`network_position_role.yaml`, `labels`) | a base: a intermediação conta caminhos entre **todos** os pares, e não entre comunidades; "between communities" afirma mais do que a medida mede |
| ids `network_analysis.*` (`README.md:126-136`) | ids `network.*` e `assignment.network.*` | a base |

A Q1 aprovada (*"papel como frase sobre as ligações"*) é cumprida pelas frases da base; a frase do
protótipo é que precisa mudar. Nada disso reabre a aprovação, que foi da forma da tela. O README do
protótipo registra que o código segue a spec e a base.

### A5 — Médio: Q_rand — a redação dizia "a mesma partição", e a comparação é sem peso contra com peso — **redação aplicada; o peso fica para o plano**

1. `network_analysis_parameters.yaml` (`modularity_reading`) e `network_modularity_score.yaml`
   diziam *"a modularidade média da mesma partição gulosa aplicada aos grafos aleatórios"*. Lido ao pé
   da letra, é a partição da rede real imposta aos aleatórios, que mede outra coisa (quase sempre
   Q ≈ 0). A intenção é o **mesmo algoritmo** em cada aleatório (Guimerà, Sales-Pardo e Amaral, 2004).
   **Emenda aplicada**: `network_analysis_parameters.yaml:158-161` e `network_modularity_score.yaml:16-18`.
2. Q é calculada com peso e Q_rand sem peso. A proposta declara isso como limitação
   (`network_modularity_score.yaml:32`, *"comparação de ordem de grandeza"*), e a declaração é honesta.
   Mas pesos concentrados aumentam Q, e a rede de designação concentra peso. A comparação, que é a
   razão de Q_rand existir (S10 da primeira revisão), fica enviesada a favor de "há estrutura".
   **Recomendação para o plano**: sortear nos aleatórios o **multiconjunto dos pesos reais**, com o
   mesmo gerador e a mesma semente. Q_rand passa a ter peso, e a limitação cai. Não apliquei porque
   muda o método, e não só o texto.

### A6 — Médio: o nulo do σ tem nós isolados que a rede real não tem — **limitação e registro aplicados**

A rede real não tem pessoa sem aresta (FR-008: pessoa sem aresta não é nó). Um G(n, m) com a mesma
densidade, numa rede esparsa como a de designação, tem nós isolados e componentes pequenos. A
proposta faz o certo ao aplicar aos dois lados a mesma regra de pares que se alcançam (corrige
`dashboard_team_graph.py:198`, que descartava o aleatório desconexo). Mas a mesma regra não torna
iguais as duas estruturas:

- **L_rand** sobre um aleatório fragmentado é média de distâncias **dentro** de componentes
  pequenos, e tende a ser menor;
- **C_rand** exclui os mesmos nós de grau < 2, mas os aleatórios têm mais deles.

As duas coisas puxam σ para baixo de um jeito que depende de quão fragmentado o aleatório saiu.

**Aplicado** (`network_small_world_sigma_score.yaml:20-22`, `:40-41`): o σ grava a fração média de
pares que se alcançam nos aleatórios, ao lado da `reachable_share` da rede real, e a limitação diz
quando L / L_rand compara coisas diferentes. **Para o plano**: se as frações divergirem muito nos
dados reais (#1190), avaliar G(n, m) condicionado a grau mínimo 1, ou ausência com motivo. Não
apliquei porque é escolha de modelo nulo.

Na mesma medida (`:42`): Humphries e Gurney (2008) definem σ com **dois** coeficientes, a
transitividade (C^Δ) e a média local (C^ws). A base usa a média local, que é a do networkx e a da
referência. A escolha está certa, mas não estava dita, e o número muda com a outra. **Aplicado.**

### A7 — Médio: a D3 não decidiu se a marca de conta da organização vale para a rede de revisão — **decisão pendente**

`review.network.edge` tem três motivos de exclusão (`priv/knowledge_base/rules/review_network_edge.yaml:156`,
`order: [bot_or_app, unlinked_person, self_review]`), e `assignment.network.edge` tem quatro. Na
mesma área, com a mesma organização, a conta marcada como da organização seria **nó** na rede de
revisão e **excluída** na de designação. Com isso, o grau, a intermediação, as comunidades e o papel
das pessoas ligadas a ela deixariam de ser comparáveis entre as duas redes do seletor. A spec manda
ler as duas lado a lado (Q2 do protótipo, alternadas).

A D3 aprovou *"a administração marca, com as guardas da R8"*. A pergunta da própria tabela, *"e se
vale para a rede de revisão da 073"*, ficou sem resposta (`spec.md`, tabela de decisões, D3).
**Recomendação**: vale para as duas. Isso exige `review.network.edge` versão 2, com o motivo
`organization_account` entre `bot_or_app` e `unlinked_person`, e a nota de que as leituras da
versão 1 não o tinham. É decisão da pessoa mantenedora, e precisa vir antes da tarefa que implementa
a marca.

### A8 — Baixo: a semente sozinha não reproduz o sorteio — **emenda aplicada**

`small_world` e `layout` fixam *"semente 42"* e dizem *"como `networkx.spring_layout(seed=42)`"*. A
FR-052 e o SC-003 pedem o mesmo resultado a cada cálculo, e a semente sozinha não garante isso: o
algoritmo do gerador (`:rand` do Erlang tem vários) e o procedimento de sorteio das m arestas também
fazem parte. E "semente 42" em Elixir não reproduz os números do numpy, então a comparação do SC-002
com ferramenta de referência só pode ser de método e de valor dentro da tolerância, e não de
sorteio.

**Aplicado**: `network_analysis_parameters.yaml:337-343` (`small_world`) e `:397-399` (`layout`).

### A9 — Baixo: a razão do mínimo de 10 pessoas para o papel estava errada — **emenda aplicada**

`network_position_role.yaml` dizia que *"10 é o primeiro n em que o quinto superior tem duas
pessoas"*. Com o posto médio da própria regra e o corte estrito > 80, sem empate, as pessoas acima
do corte são as de posto k com (k + ½)/n > 0,8:

| n | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| pessoas acima de 80 | 1 | 1 | 1 | **2** | 2 | 2 |

A afirmação vale para n = 8, e não para 10. A primeira revisão (S7) repete o erro. O valor 10 se
sustenta por outra razão: folga para empate e coincidência com o mínimo do σ, para que papel e σ
apareçam e sumam juntos. **Aplicado** em `network_position_role.yaml:73-77`.

O resto da regra está certo. O percentil por posto médio, 100 × (#{M < M(u)} + #{M = M(u)}/2)/n,
coincide entre a regra e a medida `network_position_percentile_percentage.yaml:15`: a regra conta
"outras pessoas iguais + ½", a medida conta "iguais, incluindo u, / 2", e as duas dão o mesmo valor.
O exemplo de 40% empatados em zero dá percentil 20, como escrito. Os rótulos de `labels` são
posicionais e só afirmam o que os dois percentis afirmam, e as `misinterpretations` cobrem
importância, atributo da pessoa, "não colabora" e a comparação entre organizações.

### A10 — Médio: a necessidade prometia uma decisão que nenhuma medida sustenta — **emenda aplicada**

`network_structure.yaml:21` listava como decisão apoiada *"onde a ausência de uma pessoa separaria a
rede (quem está em muitos caminhos)"*. Isso é pergunta de **ponto de articulação**. Nenhuma das 20
medidas o calcula, e intermediação alta não implica corte: há pessoa de intermediação alta cuja
saída não separa nada, porque há caminhos alternativos. A frase também contradiz a própria
`network_betweenness_ratio.yaml:35` (*"Ler intermediação alta como indispensabilidade comprovada"*
é interpretação incorreta). Além disso, "a ausência de uma pessoa" é um juízo sobre a pessoa.

**Aplicado** (`network_structure.yaml:20-23`): a decisão passa a ser "por onde passam os caminhos
observados entre os grupos", com a negação explícita.

### A11 — Baixo: a borda "rede com uma aresta só" contradizia a base — **emenda aplicada**

`spec.md:227` dizia *"intermediação definida (zero para as duas, que é valor…)"* e *"comunidades
ausentes"*. A base diz o contrário nos dois casos. Com n < 3, a intermediação é **ausente** com
`network_too_small`, porque a normalização (n − 1)(n − 2)/2 vale zero (`network_analysis_parameters.yaml`,
`betweenness`). E a comunidade só é ausente sem aresta (`network_communities_count.yaml:18`).
Alinhada à base: intermediação ausente, uma comunidade com as duas pessoas, e σ e papel ausentes.

### A12 — Baixo: "um aleatório com clustering zero" na US7 — **emenda aplicada**

`spec.md:184` dizia que σ é ausente quando *"um aleatório"* tem clustering zero. A base diz quando a
**média** C_rand é zero ou indefinida (`network_small_world_sigma_score.yaml:23`), e a FR-042 diz o
mesmo. Lida como estava, a frase faria um único sorteio sem triângulo derrubar o σ. Alinhada.

### A13 — Baixo: um defeito da referência não estava na tabela — **emenda aplicada**

`dashboard_team_graph.py:59-68` junta `assignee` **e** `assignees`, e o responsável principal está
nos dois. O peso da referência conta esse responsável **duas vezes** por issue, e por isso não é
"número de issues". A FR-005 da 076 já corrige isso (issues **distintas**), mas a tabela *O que não se
repete* não dizia, e quem comparar o SC-001 com o relatório de referência encontraria diferença sem
explicação. Também faltava, na linha das comunidades, que a referência particiona **sem** peso
(`:241`) e calcula Q **com** peso (`nx.community.modularity`, padrão `weight='weight'`, `:254`).
**Aplicado** em `spec.md:56` e na linha das comunidades.

### A14 — Baixo: "a origem não dá a data da designação" — **emenda aplicada**

`assignment_network_issues_count.yaml:28` e a regra (`window`) diziam que a origem não dá a data. A
origem dá a data no `AssignedEvent.createdAt`, e a plataforma a coleta. O que não a tem é a lista
`assignees` e a tabela `issue_assignees`. A distinção importa porque é a opção (b) da D1. Corrigido
nos dois lugares.

### A15 — Baixo: o validador não confere os ids de conceito das necessidades nem as referências das regras — **lacuna declarada**

Injetei `sro.epico_inexistente` em `required_concepts` de `network.structure` e
`network.estrutura_inexistente` em `answers_information_need` de `network.diameter.count`. O
`mix knowledge.validate` saiu com `EXIT=1`, mas acusou **só** a segunda. Os ids de conceito e
relação das necessidades, e as referências entre regras (`windows_from:
review.network.parameters.window_days`, `network.position_role.min_people`), não são conferidos
por máquina. Conferi os 17 ids à mão (seção 2). Fica como lacuna da base, fora desta feature: abrir
issue.

### A16 — Baixo: id incompleto no README da proposta — **emenda aplicada**

`proposta-base/README.md:44` citava `reviews_received`; o id é `review.network.reviews_received.count`.

---

## 2. O que foi conferido e está certo

| conferência | resultado |
|---|---|
| ids de conceito e relação citados | os 17 existem: `eo.person` (`seon/eo/modules/organizational_structure.yaml:72`), `spo.project_person_stakeholder` (`seon/spo/modules/projects_and_stakeholders.yaml:73`), `qapo.artifact_evaluation` (`seon/qapo/modules/quality_assurance_process.yaml:34`), `qapo.stakeholder_performed_artifact_evaluation` (`…/evaluation_participation.yaml:56`), `qapo.artifact_evaluation_evaluates` (`:76`), `cmpo.change_request` (`seon/cmpo/modules/configuration_management_process.yaml:60`), `cmpo.change_request_submission` (`…/change_traceability.yaml:51`), `cmpo.stakeholder_submitted_change_request` (`:66`), `cmpo.submission_produced_change_request` (`:81`), `sro.user_story`, `sro.epic`, `sro.intended_scrum_development_task` (`continuum/sro/modules/product_and_sprint_backlog.yaml:26`, `:48`, `:101`), `osdef.defect` (`seon/osdef/modules/defects_and_failures.yaml:24`), `spo.is_in_charge_of` (`…/processes_and_activities.yaml:240`), `spo.participates_in` (`:250`), `sro.developer_in_charge_of_development_task` (`continuum/sro/modules/scrum_stakeholder_participation.yaml:55`), `sro.developer` (`…/scrum_stakeholders.yaml:86`) |
| direção das relações recusadas | `spo.is_in_charge_of`: `spo.project_stakeholder` → `spo.performed_project_activity`; `sro.developer_in_charge_of_development_task`: `sro.developer` → `sro.performed_scrum_development_task`. As duas são de execução, e a recusa da S2 está certa |
| dependência entre ontologias | a proposta não cria conceito, relação nem módulo; as regras e medidas são globais. A sugestão da S2, de a SRO declarar a designação sobre `sro.intended_scrum_development_task`, iria de SRO para SPO e EO, o que é permitido. `mix knowledge.graph`: `EXIT=0` |
| a 073 coerente | `review.network.parameters` só perde a segunda entrada de `refuses`, sem mudar nenhum valor (diff contra `priv/knowledge_base/rules/review_network_parameters.yaml`); `windows_from` aponta para `window_days` com `allowed: [30, 90, 180]`; `outside_reach.min_group = 3` = `min_group_size_shown: 3`; a direção revisor → autor (`review_network_edge.yaml:39`) bate com "reviews" / "is reviewed by" em `network.degree.count` |
| a coleta sustenta a aresta | `collected_issues.author_person_id`, `external_created_at` e `no_longer_observed_at` (`collected_issue.ex:38`, `:57`, `:62`); `issue_assignees.person_id` e `no_longer_observed_at` (`issue_assignee.ex:25-28`); `person_work.ex:110-119` confirma que não há data de designação; `assignees(first: 10)` (`issues.graphql:45`) não trunca, porque o GitHub limita a 10 responsáveis por issue |
| Brandes / Freeman | soma sobre pares **não ordenados** {s, t}, dividida por (n − 1)(n − 2)/2: é a normalização do networkx para grafo sem direção. Zero é valor; ausente com n < 3 |
| proximidade (Wasserman e Faust) | ((r − 1)/(n − 1)) × ((r − 1)/D) é `closeness_centrality(wf_improved=True)`; a referência já a usava sobre o grafo sem direção (`:94`), e o defeito era só o 1/c como distância (`:318`), corrigido em `network.person_distance.mean` |
| autovetor | iteração sobre A + I normalizada em L2, a partir de 1, com tolerância n_c × 1e-6: é o `networkx.eigenvector_centrality`. Converge em grafo bipartido porque A + I é primitiva (autovalores λ + 1 e 1 − λ). Componente de 2 dá 1/√2, como escrito |
| distâncias e eficiência | média sobre pares que se alcançam, com a fração ao lado; diâmetro entre quem se alcança; eficiência de Latora e Marchiori com 1/∞ = 0 por definição. Caminho de 4: 5/3, 3 e 13/18 |
| modularidade de Newman | Q = (1/2m) Σ_uv [A_uv − k_u k_v / 2m] δ(c_u, c_v), na forma com peso, certa |
| σ de Humphries e Gurney | (C/C_rand)/(L/L_rand) com G(n, m); os cinco defeitos da referência (`:192-204`, `:222`) corrigidos um a um; ausência no lugar de 0; leitura "meets the σ > 1 criterion" com Telesford et al. (2011) |
| clustering | média local de Watts e Strogatz sobre grau ≥ 2, com a contagem dos excluídos (D5); a mesma regra nos aleatórios |
| ausência nunca zero | toda medida nomeia o motivo; o único zero de definição (eficiência) está escrito como definição |
| §11, cada medida | as 20 têm necessidade, fórmula com `inputs`, unidade, `levels`, `filters`, `period`, `limitations`, `misinterpretations` e proveniência |
| juízo sobre pessoa | papel, hubs, grau, intermediação, autovetor, percentil e grau interno têm a interpretação incorreta "a medida não avalia a pessoa" ou equivalente; os rótulos de papel são posicionais (D2) e a frase de não avaliação é requisito (FR-047) |

---

## 3. Validação, com o código de saída

Cópia de `priv/knowledge_base/` em diretório único do scratchpad, com os 24 YAMLs de
`proposta-base/` sobrepostos. Saída redirecionada para arquivo, `$?` lido direto do `mix`, sem pipe.

| comando | EXIT | resultado |
|---|---|---|
| `mix knowledge.validate priv/knowledge_base` (base, sem a proposta) | 0 | 148 artefatos |
| `mix knowledge.validate <cópia>` (proposta como recebida, `kb-076-rev2-…`) | 0 | 172 artefatos: 37 medidas, 10 necessidades, 30 regras |
| `mix knowledge.graph <cópia>` | 0 | 33 módulos, dependências íntegras |
| a mesma cópia com `sro.epico_inexistente` e `network.estrutura_inexistente` injetados | **1** | acusa só a segunda (A15); arquivos restaurados e conferidos com `cmp` |
| `mix knowledge.validate <cópia nova>` (com as emendas, `kb-076-rev2b-1791112530-70116`) | 0 | 172 artefatos: 37 medidas, 10 necessidades, 30 regras |
| `mix knowledge.graph <cópia nova>` | 0 | 33 módulos, dependências íntegras |

`mix test` não foi rodado (fora do escopo).

## 4. O que não verifiquei

- **A forma das três regras**: `derivation_rule` não tem schema em `schemas/`, e o validador as aceita
  sem conferir campos (lacuna da 073, mantida).
- **Nenhum número contra o banco**: nem o volume (#1190), nem quantas contas de máquina vêm sem
  `[bot]` (A3), nem quão fragmentados saem os G(n, m) com a densidade real (A6).
- **As fórmulas por execução**: conferi contra a definição e contra o networkx, mas não calculei as
  cinco redes do SC-002.
- **As perguntas de competência**: continuam por escrever. Depois da D1, já podem ir para o plano.
