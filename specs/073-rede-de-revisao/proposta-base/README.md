# Proposta de base de conhecimento para as redes complexas

**Status**: proposta, 2026-10-03. Ainda **não** está em `priv/knowledge_base/`. Fica aqui para
que nada entre no gate antes da aprovação da pessoa mantenedora.

**Origem**: o pedido foi *"olhe os dados que ele gera e me faça uma proposta de knowledge base"*.
"Ele" é o repositório de referência `leds-conectafapes/leds-conectafapes-management-dashboard`.
Foram lidos:

- o código `dashboard_team_graph.py` e `dashboard_organization.py`;
- a saída em `report/`: `collaboration_report.md`, `teams.md`, `developer_stats.md` e
  `organization_stats.md`.

**Escopo**:

- a 073 (rede de revisão) tem YAML completo;
- as fatias 2 a 4 têm só o esboço, na seção 4.

> Este documento não reproduz nomes nem logins de pessoas do relatório de referência. Quando um
> exemplo precisa de conta, usa contas que não são pessoas: `dependabot[bot]`,
> `github-actions[bot]` e a conta de organização `LEDS`.

---

## 1. O que vai para onde quando aprovado

| Arquivo desta proposta | Destino em `priv/knowledge_base/` | Tipo |
|---|---|---|
| `information_needs/review_concentration.yaml` | `information_needs/review_concentration.yaml` | necessidade `review.concentration` |
| `measurements/review_network_reviews_given.yaml` | `measurements/` | medida `review.network.reviews_given.count` |
| `measurements/review_network_reviews_received.yaml` | `measurements/` | medida `review.network.reviews_received.count` |
| `measurements/review_network_unconnected_groups.yaml` | `measurements/` | medida `review.network.unconnected_groups.count` |
| `measurements/review_network_concentration_top_k_share.yaml` | `measurements/` | medida `review.network.concentration.top_k_share` |
| `measurements/review_network_reviews_count.yaml` | `measurements/` | medida `review.network.reviews.count` (pedida pelo protótipo) |
| `measurements/review_network_reviewers_count.yaml` | `measurements/` | medida `review.network.reviewers.count` (pedida pelo protótipo) |
| `measurements/review_network_authors_reviewed_count.yaml` | `measurements/` | medida `review.network.authors_reviewed.count` (pedida pelo protótipo, D10) |
| `measurements/review_network_people_without_activity_count.yaml` | `measurements/` | medida `review.network.people_without_activity.count` (pedida pelo protótipo) |
| `measurements/review_network_excluded_count.yaml` | `measurements/` | medida `review.network.excluded.count`, por motivo (pedida pelo protótipo) |
| `rules/review_network_edge.yaml` | `rules/review_network_edge.yaml` | regra `review.network.edge`: a aresta, os estados que contam e as exclusões (era o mapeamento `…as_review_edge`; ver a seção 6) |
| `rules/review_network_parameters.yaml` | `rules/review_network_parameters.yaml` | regra `review.network.parameters`: janelas, k, amostra mínima, grupo mínimo |
| `ontology/seon/qapo/competency_questions/qapo_review_network_competency_questions.yaml` | o mesmo caminho | perguntas `qapo_review_network.cq01`–`cq04` |

O id `review.concentration` segue o padrão de `review.time_to_first_review`. As medidas seguem o
padrão `<área>.<assunto>.<forma>`, como `review.time_to_first_review.duration`.

---

## 2. Cada métrica da referência: adotar, adaptar ou recusar

**Antes da tabela: a rede da referência não é de colaboração.** A aresta vai de quem abriu a
issue para quem foi designado para ela (`dashboard_team_graph.py:53-80`). Isso é **delegação**,
e o relatório inteiro a chama de colaboração. Toda métrica abaixo herda esse erro. Por isso
nenhuma é adotada **sobre aquela aresta**. A 073 troca a aresta por revisão, que tem semântica
declarada na rede de ontologias: QAPO sobre CMPO, entre pessoas de EO.

| Métrica da referência | Decisão | Vira | Razão |
|---|---|---|---|
| **Grau** (`degree_centrality`, `:87`) | **ADAPTAR** | `review.network.reviews_given.count` e `review.network.reviews_received.count` | **O que se aproveita**: a contagem de pares distintos é útil. **O defeito**: a referência soma entrada e saída e divide por n − 1, e escreve *"colabora diretamente com N"* (`:300`). Um par recíproco conta duas vezes, e o número muda com o tamanho da rede. **Na adaptação**: contagem crua, separada por direção, sempre em par (solicitações e pessoas distintas). Não há normalização, percentil nem ranking. |
| **Intermediação** (`betweenness`, `:90`) | **RECUSAR** na 073 | candidata adaptada na fatia 3, sem nomear | Na referência, ela serve para chamar uma pessoa de *"ponte"* (`:308`, `:501`) com cortes 0,1 e 0,3 sem razão escrita. Também ignora o peso. A pergunta legítima por trás dela, *"a ausência de quem separa a rede?"*, é a da fatia 3, e lá também se responde sem rótulo. |
| **Proximidade** (`closeness`, `:94`) | **RECUSAR** | — | **A semântica não vale**: *"dissemina informação rapidamente"* não se aplica a revisão, porque revisar não transmite informação a terceiros. **O cálculo está errado**: a referência converte 1/c em *"alcança outros em N passos"* (`:318`). Em grafo desconexo o networkx aplica a correção de Wasserman–Faust, e 1/c deixa de ser distância média. Não há decisão que o número apoie. |
| **Autovetor** (`:98-117`) | **RECUSAR** | — | **É julgamento**: lê "influência", que é juízo sobre pessoa. **Usa fallback**: quando o cálculo falha, usa a centralidade de grau (`:113`), em outra escala, e para nó isolado inventa **0,01** (`:117`). **Não compara**: a normalização por componente torna valores de componentes diferentes incomparáveis, e a tabela os ordena juntos. |
| **Distância média** (`:139-149`) | **RECUSAR** | — | Revisão não é caminho de comunicação. Em grafo desconexo a referência faz a média **simples** das médias por componente (`:149`, `:218`), sem pesar pelo tamanho, e devolve `inf` quando não há componente. |
| **Diâmetro** (`:152-162`) | **RECUSAR** | — | Mesma razão. É o máximo entre componentes (`:162`), o que contradiz a frase *"no máximo N passos para uma informação ir de um desenvolvedor para qualquer outro"*: entre componentes, não há caminho. |
| **Eficiência global** (`:165`) | **RECUSAR** | — | Não apoia decisão nenhuma. As faixas 0,4 e 0,7 (`:354`) não têm razão escrita. |
| **Coeficiente de clustering** (`:184`) | **RECUSAR** na 073 | talvez contexto na fatia 2 | Sem decisão que o apoie. Na referência, só existe para alimentar o σ. A spec 073 o deixa fora (FR-019). |
| **σ de mundo pequeno** (`:177-231`) | **RECUSAR** | — | Ver a seção 3. Há quatro defeitos de cálculo. Mesmo calculado certo, o σ não responde a pergunta de nenhum stakeholder da plataforma. A spec exclui (FR-019). |
| **Modularidade** (`:238-254`) | **ADAPTAR**, só na fatia 2 | candidata *"modularidade da partição declarada"* | **Os defeitos**: a referência maximiza modularidade **sem peso** (`:241`). Usa `to_undirected()`, que guarda o peso de um só sentido do par recíproco (`:80`, `:238`). E classifica com faixas 0,3 e 0,7 sem razão (`:404`). **O que se aproveita**: a modularidade da partição **declarada** (equipes) sobre a rede de revisão responde *"as equipes explicam quem revisa quem?"*. Essa é a pergunta da fatia 2. |
| **Comunidades** (`:233-256`) | **ADAPTAR**, só na fatia 2 | *"grupos observados"*, nunca *"equipes"* | A detecção é útil para comparar com as equipes declaradas. A referência apresenta cada comunidade com *"membros mais centrais"* (`:422-436`), e isso é **RECUSADO**: é ranking dentro do grupo. Comunidade observada não é equipe (seção 5). |
| **Componentes** (`:277-282`) | **ADAPTAR** | `review.network.unconnected_groups.count` | A referência testa conectividade **forte** e reporta componentes **fracos** na mesma frase. Por isso o relatório publicado diz *"o grafo é desconexo, contendo 1 componentes"*. Aqui vale só o critério fraco, declarado. Pessoa sem aresta não é grupo. Grupo pequeno não tem tamanho mostrado a quem não alcança todos (regra `min_group_size_shown`). |
| **"Papel na rede"** (`:495-510`) | **RECUSAR** | recusa registrada em `review.network.parameters.refuses` | São rótulos como *"Coordenador central"*, *"Hub"*, *"Ponte entre equipes"* e *"Colaborador especializado com foco limitado"*. Saem de percentis com cortes 80, 50 e 30 sem razão escrita. É julgamento sobre pessoa (FR-018). Além disso, o percentil de uma pessoa muda quando outra entra na rede. |
| **Rankings top-5** por centralidade (`:120-123`) | **RECUSAR** | `review.network.concentration.top_k_share` | A pergunta *"está concentrada?"* se responde com a fração das k primeiras **sem dizer quem**. Nomear o primeiro colocado é o ranking que `flow_per_person_readings.yaml` já recusa. |
| **Listas "Atribui / Recebe issues"** por pessoa (`:512-529`) | **ADAPTAR** | os pares da US2, sob o alcance | Viram pares de **revisão**, ordenados por nome e não por peso (a referência ordena por peso, `:517`). Par fora do alcance não vira linha (R2). |
| **Nó = qualquer login** | **RECUSAR** | `review.network.edge` (`exclusions`) | O relatório lista `dependabot[bot]`, `github-actions[bot]` e a conta de organização `LEDS` como desenvolvedores (`developer_stats.md`), e `LEDS` aparece como membro central de uma comunidade. Aqui só é nó quem é `eo.person` com `account_type = 'person'`. |
| **Laço removido em silêncio** (`assignee != author`, `:71`) | **ADAPTAR** | `self_review`, contado | Auto-revisão não vira aresta, **e é contada** no agregado. Na referência ela some sem registro. |
| **Erro de linha engolido** (`except Exception`, `:76`) | **RECUSAR** | `fallback: skip` com contagem | Linha que falha some sem contagem, e o total deixa de fechar com a origem. |
| **Velocidade e Monte Carlo** (`dashboard_organization.py:191-281`) | **RECUSAR** | já existe: `flow.completion.forecast` | Ver a seção 3. Duplicaria uma medida declarada, e a da referência tem defeitos que a da plataforma já evita: semente, piso de amostra, percentil nulo quando não converge. |
| **Throughput e entregue × prometido por equipe** (`teams.md`, `organization_stats.md`) | **RECUSAR** aqui | já existem: `flow.throughput.rate`, `flow.open_work.cumulative` | Fora das redes, e já declarados. O "prometido" da referência é aberto mais fechado **por coorte de criação** (`dashboard_organization.py:93`), e não compromisso. |

### O que a 073 acrescenta e a referência não tem

- **Ausência com motivo**: quatro motivos (FR-009), em vez de 0, 0,01 ou `inf`.
- **Exclusões contadas**: três motivos, em ordem, que fecham com o total.
- **Alcance**: a concentração é recortada pelas pessoas que quem consulta alcança (R1).
- **Interpretações incorretas** escritas em cada medida, incluindo a recusa de ordenar.

---

## 3. Os defeitos de cálculo da referência, com o lugar

Estão escritos para que nenhum seja copiado por quem portar a ideia.

### σ de mundo pequeno (`dashboard_team_graph.py:177-229`)

1. **Divide por 10 mesmo quando menos de 10 grafos entraram.** Só os grafos aleatórios
   **conexos** são somados (`:198`), mas a divisão é sempre por `num_random_graphs = 10`
   (`:192`, `:202-204`).
   - **O que sai errado**: as colunas *"Rede Aleatória"* do relatório saem subestimadas pela
     fração de grafos conexos.
   - **Por que o σ sobrevive**: o fator aparece no numerador e no denominador e se cancela. É
     coincidência, não desenho.
   - **Quando o σ também quebra**: com zero grafos conexos ele vira **0** (`:222`), e o relatório
     afirma *"NÃO é mundo pequeno"*. É um fallback que vira conclusão.
2. **Amostra condicionada à conexidade.** Descartar os grafos desconexos enviesa os valores de
   C_rand e L_rand. A comparação deixa de ser com o grafo aleatório equivalente.
3. **Os dois lados não são comparáveis.** O L real é a média simples das médias por componente
   (`:209-218`). O L aleatório vem só de grafos conexos.
4. **Sem semente e com 10 amostras.** Rodar de novo dá outro σ. Nada no relatório diz isso.

### Eventos sem valor

- **Autovetor**: usa 0,01 para nó isolado (`:117`) e a centralidade de grau como reserva
  (`:113`), em outra escala.
- **Distância média e diâmetro**: viram `inf` (`:149`, `:162`).
- **Velocidades**: viram 0 quando não há simulação (`dashboard_organization.py:208-210` e
  `:249-258`).

### Faixas sem razão escrita

`:308`, `:354`, `:404` e `:497-507`. Cada uma transforma número em adjetivo: *"eficiência
moderada"*, *"comunidades moderadamente definidas"*, *"papel crítico"*.

### Conectividade

`:277-282` testa conectividade forte e reporta componentes fracos. O resultado publicado é *"o
grafo é desconexo, contendo 1 componentes"*.

### Monte Carlo (`dashboard_organization.py`)

1. **A unidade do período não fecha.**
   - **O que diz**: o período é declarado quinzenal (`:81-82`, `to_period("2W")`), e a data
     prevista soma **14 dias** por período (`:171`, `:239`).
   - **O que a tabela mostra**: `organization_stats.md` lista períodos **semanais** (26/08,
     02/09, 09/09).
   - **A consequência**: se os períodos são semanais, as datas previstas ficam esticadas para
     perto do dobro.
2. **Fator aleatório sem razão.** A velocidade é multiplicada por `random.uniform(0.8, 1.2)`
   (`:229`).
3. **O rótulo inverte o sentido.** *"Velocidade P10 (Otimista)"* é a **menor** velocidade.
   Otimista é a **data** P10, e não a velocidade P10.
4. **"Entregue" é coorte, não entrega.** Conta issues **criadas** no período que estão
   fechadas, e não o que foi fechado no período (`:93`).

---

## 4. As quatro fatias e o que cada uma acrescenta à base

| Fatia | Pergunta | Acrescenta à base | Depende de |
|---|---|---|---|
| **1 — 073 rede de revisão** | *A revisão está concentrada em poucas pessoas? Há grupos que não se revisam?* | 1 necessidade, 9 medidas, 2 regras (aresta e parâmetros), 4 perguntas de competência (esta pasta) | QAPO, CMPO, SPO, EO; dado já coletado |
| **2 — comunidades observadas × equipes declaradas** | *As equipes declaradas correspondem a quem revisa quem?* | 1 necessidade, 2–3 medidas, regra do algoritmo e da semente | fatia 1 (a aresta); `eo.team_membership` temporal |
| **3 — pontes e risco de dependência de pessoa** | *Se uma pessoa ficar indisponível, quanto da revisão para?* | 1 necessidade, 2–3 medidas, regra de exibição para quem tem alcance parcial | fatia 1; decisão sobre nomear |
| **4 — coautoria de artefato** | *Onde o código é alterado por uma pessoa só?* | 1 necessidade, 2–3 medidas, 1 mapeamento pessoa–artefato | CMPO (`cmpo.artifact_copy`, `cmpo.stakeholder_performed_commit`); SysSwO para agrupar além do arquivo |

As fatias 2 a 4 abaixo são **esboço**. Nenhuma tem fórmula fechada onde a decisão ainda não
existe. Nenhuma tem YAML, porque `information-need.schema.yaml` e `measurement.schema.yaml` não
têm campo `status`. Um YAML marcado `draft` reprovaria no schema, e escrevê-lo sem o campo faria
o rascunho parecer pronto.

### Fatia 2 — comunidades observadas × equipes declaradas

**Necessidade candidata**: `review.team_alignment`.

- **Pergunta**: *"Numa janela, a revisão acontece dentro das equipes declaradas, entre elas, ou
  em grupos que não correspondem a equipe nenhuma?"*
- **Decisão apoiada**: rever a composição declarada das equipes, ou abrir caminho de revisão
  entre equipes que dependem uma da outra e não se revisam.
- **Conceitos**: `eo.team`, `eo.team_membership` (o relator, com período), `eo.team_member`,
  `eo.person`, e a aresta da fatia 1.

**Medidas candidatas**:

- **Fração do peso de revisão dentro da equipe declarada.** A fórmula é quase fechada, mas falta
  decidir duas coisas:
  - em que data o vínculo vale: a da revisão, a da abertura (como faz
    `review.time_to_first_review.duration`) ou a da consulta;
  - o que fazer com a pessoa que está em duas equipes ao mesmo tempo. A EO permite isso; a
    partição, não.
- **Modularidade da partição declarada.** Fica aberto como tratar quem está em mais de uma
  equipe e quem não está em nenhuma.
- **Grupos observados e sua sobreposição com as equipes** (tabela de contingência, sem índice
  único). Ficam abertos:
  - o algoritmo, determinístico e sem dependência nova, ou com ADR;
  - a semente;
  - o tamanho mínimo de grupo, que reusa `min_group_size_shown`.

**O que NÃO responde**:

- se a equipe está "errada": grupo observado é o que a ferramenta viu numa janela, e equipe é
  decisão organizacional;
- se a equipe funciona bem;
- quem "deveria" estar em qual equipe.

Comunidade observada **não é** equipe, e nunca recebe nome de equipe.

### Fatia 3 — pontes e risco de dependência de pessoa

**Necessidade candidata**: `review.dependency_risk`.

- **Pergunta**: *"Se uma ou duas pessoas ficarem indisponíveis, que parte das solicitações fica
  sem quem as revise, e a rede se parte?"*
- **Decisão apoiada**: formar mais revisores para os repositórios ou caminhos que dependem de
  poucas pessoas, antes de uma ausência.
- **Conceitos**: os da fatia 1, mais o repositório (`cmpo.source_repository`) como nível.

**Medidas candidatas**:

- **Cobertura dependente**: fração das solicitações revisadas que tiveram **um único** revisor
  humano. A fórmula é fechável. Fica aberto se o nível é repositório ou organização.
- **Menor número de revisores que cobre metade das solicitações revisadas**, por repositório. É o
  "fator ônibus" de revisão. Ficam abertos o corte (50%?) e a razão escrita dele.
- **Pessoas cuja ausência separa a rede** (vértices de corte), **contadas, não nomeadas**. Nomear
  ou não para quem administra é **decisão da pessoa mantenedora, com avaliação do agente
  `security`**. É a primeira medida que, nomeada, diria *"esta pessoa é indispensável"*.
- A intermediação da referência **não** entra: rotula *"ponte"* e não responde a decisão melhor
  que as três acima.

**O que NÃO responde**:

- quem é mais valioso;
- se a dependência é ruim. Um revisor designado único pode ser decisão consciente.

Também não substitui `review.time_to_first_review`: dependência é risco, espera é sintoma.

### Fatia 4 — coautoria de artefato

**Necessidade candidata**: `code.co_authorship`.

- **Pergunta**: *"Que partes do código foram alteradas por uma pessoa só na janela, e quais
  pessoas alteram as mesmas partes?"*
- **Decisão apoiada**: onde espalhar conhecimento de código: par, revisão cruzada, rotação.
- **Conceitos**: `cmpo.commit_artifact_copy`, `cmpo.stakeholder_performed_commit`,
  `cmpo.artifact_copy` (o arquivo tocado, já mapeado por `mappings/github/cmpo/commit_file.yaml`),
  e, para agrupar além do arquivo, `sys_swo.code` / `sys_swo.software_item`.

**Medidas candidatas**:

- **Autores distintos por artefato.** Ficam abertos:
  - a granularidade: arquivo, diretório ou `sys_swo.code`;
  - renomeação;
  - arquivo gerado;
  - commit de merge;
  - o trailer `Co-authored-by`;
  - bots.
- **Artefatos com um só autor na janela.**
- **A projeção pessoa–pessoa da coautoria.** Só se uma decisão a pedir. A projeção bipartida
  fabrica arestas entre quem nunca interagiu.

**O que NÃO responde**:

- quem **conhece** o código: tocar um arquivo não é conhecê-lo, e conhecer não exige tocar;
- autoria no sentido de propriedade;
- qualidade.

Coautoria **não é** colaboração: dois commits no mesmo arquivo podem estar a meses um do outro.

---

## 5. Riscos semânticos

| Não confunda | Por quê, aqui | Onde a proposta se protege |
|---|---|---|
| **Revisão ≠ colaboração ≠ delegação** | A referência chama delegação (autor da issue → designado) de colaboração. Revisão é um terceiro ato, sobre um artefato. Nenhum dos três é "trabalhar junto". | `equivalence: derived` e justificativa na regra `review.network.edge`; limitação *"NÃO é colaboração, NÃO é delegação, NÃO é integração"*; FR-005 |
| **Pull Request ≠ merge** | A aresta é sobre quem revisou a **solicitação**, e não sobre quem integrou. Solicitação revisada não é solicitação integrada. | `review.network.edge` (justificativa); `reviews_received` (limitação); `cq01` |
| **Pessoa ≠ membro de equipe** | O nó é `eo.person`, pelo papel `spo.project_person_stakeholder`. Equipe só entra na fatia 2, pelo relator `eo.team_membership` e com data. | necessidade (`required_concepts`); FR-001 |
| **Comunidade observada ≠ equipe** | Um grupo de quem se revisa numa janela não é uma equipe, e nunca recebe nome de equipe. | `unconnected_groups` (limitação); fatia 2 |
| **Ausência ≠ zero** | Pessoa que não revisou, solicitação não revisada, janela vazia, cálculo não feito, amostra abaixo do mínimo: cada caso tem motivo nomeado. Nunca 0, 0,01 ou `inf`. | fórmula de cada medida; regra `min_reviews`; recusa do 0,01 |
| **Bot ou conta de organização ≠ pessoa** | `dependabot[bot]`, `github-actions[bot]` e `LEDS` são nós na referência. Aqui o nó exige `account_type = 'person'`, e não só `__typename = User` (R9). | `review.network.edge` (`exclusions`, `relations.reviewer.note`) |
| **Medida ≠ avaliação de pessoa** | Revisar muito não é qualidade, revisar pouco não é omissão, e o número não ordena a lista. | `misinterpretations` das quatro medidas; FR-018/018a |
| **Fração das revisões ≠ fração das solicitações** | Com vários revisores por solicitação, as duas divergem. A 073 mede revisões; a outra é a pergunta de dependência da fatia 3. | `top_k_share` (limitação) |

**Pergunta aberta sobre `LEDS`.** A exclusão de conta de organização depende de a coleta a
classificar como não-pessoa. Se `LEDS` chega como `__typename = Organization`, já cai em
`bot_or_app`, porque `author_type` é diferente de `User`. Se chega como `User`, por ser uma conta
pessoal usada pela organização, ela é nó, e a plataforma não tem como saber. Isto **não** foi
conferido contra o banco. É coisa para o plano medir.

---

## 6. Decisões da pessoa mantenedora — 2026-10-03

As quatro primeiras foram **decididas** em 2026-10-03, junto da aprovação do protótipo, e os YAMLs
desta pasta já as carregam. O texto original de cada pergunta fica abaixo da tabela, como registro.

| # | decisão | onde está |
|---|---|---|
| 1 | Abaixo da amostra mínima, a concentração é **ausente com motivo** (`sample_below_minimum`), e as contagens aparecem. A spec foi corrigida | `review.network.parameters.min_reviews` (`below_minimum: absent`); `top_k_share` |
| 2 | O denominador **e a unidade da amostra** são **revisões** (par revisor–solicitação), e não solicitações. A chave passou de `min_reviewed_change_requests` para `min_reviews` | `top_k_share`; regra `min_reviews` |
| 3 | Conta apagada ("ghost") entra em **sem pessoa ligada**, e não em bot. Diverge de `github_change_requests.ex:321`, e a 073 tem tarefa para alinhar a coleta (T030) | `review.network.edge` (`exclusions`); `review.network.excluded.count` |
| 4 | **Grupo mínimo = 3**. Com a Q4 do protótipo (grupos só entre pessoas alcançadas), a regra não tem caso nesta fatia, e fica declarada para a fatia 2 | regra `min_group_size_shown`; `unconnected_groups` |

**Do protótipo, que muda a base**: Q4 (grupos contados só entre pessoas alcançadas) reescreveu
`review.network.unconnected_groups.count`; Q5 (exclusões, bot inclusive, só para quem alcança todas)
está em `review.network.excluded.count`; e as cinco medidas novas da seção 1 são os números da tela
que ainda não tinham declaração. A quinta decisão abaixo (medidas em par) segue aberta para a revisão
semântica.

**Revisão semântica (073/T003, 2026-10-03)** — parecer em
[`../revisao-semantica.md`](../revisao-semantica.md). Mudou esta pasta assim:

- a quinta pergunta foi **decidida**: as medidas em par ficam num só arquivo, com a unidade do
  primeiro componente e o segundo escrito na expressão; `reviews_given` passou a `unit: reviews`,
  a mesma de `review.network.reviews.count`;
- a aresta saiu de `mappings/` e virou a regra `review.network.edge`, com os estados que contam e
  a ordem das exclusões (que saíram de `review.network.parameters`) e a categoria UFO declarada;
- as perguntas de competência passaram a citar só QAPO e SPO, que é o que a QAPO declara;
- as nove medidas ganharam `version: 1`, o que exige o campo opcional `version` em
  `measurement.schema.yaml` no mesmo commit que as levar para a base (research.md R11).

### O texto original das perguntas

1. **Concentração abaixo da amostra mínima**: ausente (proposta) ou mostrada com aviso (texto
   atual do edge case da spec)? Estava em `review.network.parameters.min_reviewed_change_requests`.
2. **Grupo mínimo = 3**: é proposta desta base, sobre a sugestão de R2. Esconde só grupos de 2,
   para quem não alcança os dois.
3. **Denominador da concentração = revisões**, e não solicitações. Coincide com o exemplo da
   spec. Diverge quando há vários revisores por solicitação.
4. **Conta apagada → "sem pessoa ligada"**, e não "bot". Diverge da coleta atual
   (`github_change_requests.ex:321`, R9).
5. **Medidas em par num só arquivo** (solicitações e pessoas distintas). O schema tem um só
   `unit`. A alternativa é separar em seis medidas, ao custo de permitir mostrar *"12"* sem *"de
   4 pessoas"*.

---

## 7. Como foi validado

O validador da base aceita um diretório como argumento (`mix knowledge.validate <raiz>`) e não
precisa de banco: roda `compile` e `app.config`, sem iniciar o `Repo`.

1. Copiei `priv/knowledge_base/` para um diretório temporário fora do repositório e sobrepus os
   oito YAMLs desta proposta nos caminhos de destino da seção 1.
2. **Com a proposta**: `mix knowledge.validate <cópia>` → `EXIT=0`, *"base de conhecimento válida
   — 142 artefatos"*.
3. **Sem a proposta**: a base do repositório dá 134 artefatos. São 8 a mais, cada um contado no
   tipo certo:

   | tipo | sem a proposta | com a proposta |
   |---|---|---|
   | `information_need` | 8 | 9 |
   | `measurement` | 8 | 12 |
   | `mapping` | 22 | 23 |
   | `derivation_rule` | 24 | 25 |
   | `competency_questions` | 6 | 7 |

4. **A validação foi vista reprovando.** Numa medida da cópia, troquei a necessidade por uma
   inexistente e acrescentei um campo fora do schema. Resultado: `EXIT=1`, com os dois problemas
   apontados no arquivo da proposta:
   - *"responde a review.concentracao_inexistente, que não existe"*;
   - *"campo campo_inventado não está declarado no schema"*.

   Restaurada a medida, voltou a `EXIT=0`.
5. **O validador Python** (`scripts/validate_knowledge_base.py --kb <cópia>`) conta 142 arquivos e
   12 medidas, e acusa um só problema: a falta de `jsonschema` no ambiente, que impede a
   verificação de forma dele. A de forma foi feita pelo validador Elixir (`SchemaCheck`).

**Revalidado em 2026-10-03, depois das decisões da seção 6 e das cinco medidas novas**: a mesma
cópia, com os treze YAMLs desta pasta, dá `mix knowledge.validate <cópia>` → `EXIT=0`, *"base de
conhecimento válida — 147 artefatos"* (17 medidas, 9 necessidades, 25 regras). Vista reprovando:
`review.network.reviews.count` apontando para `review.concentracao_inexistente` → `EXIT=1`, com o
arquivo e a frase *"responde a review.concentracao_inexistente, que não existe"*.

**Revalidado na revisão semântica (073/T003, 2026-10-03)**, com as emendas aplicadas, numa
cópia nova da base com os doze YAMLs desta pasta (o mapeamento saiu, a regra da aresta entrou):

| verificação | código de saída | o que diz |
|---|---|---|
| `mix knowledge.validate <cópia>`, schema de medida **sem** `version` | `EXIT=1` | as nove medidas: *"campo version não está declarado no schema"* — é o esperado, e é o que impede levar as medidas sem a mudança de schema |
| o mesmo, com `version` opcional no schema da cópia (research.md R11) | `EXIT=0` | 147 artefatos: 22 mapeamentos, 26 regras, 17 medidas, 9 necessidades, 7 arquivos de perguntas |
| `mix knowledge.graph <cópia>` | `EXIT=0` | 33 módulos, dependências íntegras |
| `scripts/validate_knowledge_base.py --kb <cópia>` | `EXIT=0` | 147 arquivos, 17 medidas |
| vista reprovando: `spo.activity_creates_artifact` trocada por id inexistente nas perguntas | `EXIT=1` | *"qapo_review_network.cq01 referencia spo.activity_creates_artifact_inexistente, que não existe"* |

**O que não foi verificado:**

- **a regra**: `derivation_rule` não tem schema em `schemas/`, então foi conferida só pela forma
  das regras existentes (`team_dashboard_thresholds.yaml`, `access_account_lifecycle.yaml`);
- **os testes**: `mix test` não foi rodado, por instrução;
- **as perguntas de competência**: não foram executadas contra dado;
- **o volume**: nenhum número foi medido contra o banco.
