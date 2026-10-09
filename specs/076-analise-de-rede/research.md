# Research: análise de rede (076)

**Data**: 2026-10-04 · **Plano**: [plan.md](plan.md) · **Spec**: [spec.md](spec.md)

Cada seção: **Decisão**, **Razão**, **Alternativas**. Onde a decisão vem de outro documento, ele é
citado e não repetido. Os números de volume foram medidos no banco de desenvolvimento, só com
agregados (nenhum nome, login nem id saiu da consulta).

---

## R1 — O módulo: `TheBand.NetworkAnalysis`, ao lado de `ReviewNetwork`

**Decisão**: subsistema novo, `TheBand.NetworkAnalysis`, no topo de `lib/the_band/`, com fachada só
de `defdelegate`. `TheBand.ReviewNetwork` (073) continua dono da página da rede de revisão, que vira
a primeira página da área (US1, Q4 do protótipo: *"a página da 073 fica como está"*).

**Razão**: a análise tem tabela, job, fila, regras de alcance e parâmetros próprios, e cobre **duas**
redes. Dentro de `ReviewNetwork`, o módulo passaria a mudar pela página da 073 **e** pela análise —
duas razões (princípio X). O nome do subsistema é o da área do menu.

**Alternativas**: (a) estender `ReviewNetwork` e renomeá-lo — mexe no que está no ar sem pedido
(Q4); (b) um módulo por rede — duplicaria todo o cálculo, que é o mesmo sobre arestas diferentes.

## R2 — De onde vêm as arestas de cada rede

**Decisão**:

- **revisão**: da leitura vigente da 073, por uma função nova da fachada,
  `ReviewNetwork.current_edges/2`, que devolve, por janela, as arestas (ids e peso), as exclusões e
  o instante do cálculo. Só ids; nenhum nome nem login;
- **designação**: consulta nova, `WorkItems.assignment_pairs/3`, e classificação nova,
  `NetworkAnalysis.AssignmentClassification`, pela ordem da regra `assignment.network.edge`.

**Razão**: a rede de revisão da análise tem de ser **a mesma** da página da 073 (US1, cenário 2:
*"os mesmos números"*). Ler da leitura vigente garante isso por construção, inclusive o instante;
recalcular a classificação em outro lugar produziria duas redes de revisão com instantes diferentes
na mesma área. E não duplica a classificação da 073 (princípio VIII).

**Alternativas**: extrair de `ReviewNetwork.Commands` uma função que monte as arestas sem gravar, e
chamá-la dos dois jobs — duas classificações por sincronização, e a página e a análise discordando
por segundos.

## R3 — O gatilho: a 073 encadeia a 076

**Decisão**: `ComputeReviewNetwork`, depois do commit da leitura da 073, enfileira
`ComputeNetworkAnalysis` para a mesma organização. É o **único** produtor. Nenhuma tela enfileira.

**Razão**: na sincronização, a etapa `:mudancas` depende de `:trabalho`
(`lib/the_band/jobs/sync_github_eo.ex:326-343`): quando a 073 termina, as issues já foram coletadas.
Encadear depois da 073 dá à análise as duas redes frescas, e a de revisão já gravada (R2).

**O que piora**: o job da 073 passa a conhecer a análise (acoplamento escrito ao lado da linha). Se
a etapa de mudanças falhar e a de issues não, a designação só é recalculada na sincronização
seguinte. Escrito como limitação.

**Alternativas**: enfileirar também ao fim de `:trabalho` — com a unicidade em `:incomplete`, o
segundo enfileiramento se perde enquanto o primeiro roda, e a análise sai com a revisão velha.

## R4 — Fila, unicidade, tempo máximo e impressão digital (FR-017; R7 da segurança)

**Decisão**:

- fila `:network_analysis`, **configurada** com concorrência 1 em `config/config.exs` (fila declarada
  e não configurada fica `available` para sempre, `recompute_promotions.ex:7-9`);
- unicidade `keys: [:tenant_id, :organization_id]`, `states: :incomplete`, `period: :infinity`, como
  a 073 (o Oban 2.23 recusa a lista sem os estados incompletos);
- as duas redes e as três janelas no mesmo job;
- `timeout/1` de **120 s** (provisório, confirmado por T050 e pela #1190);
- **impressão digital** por rede e janela: SHA-256 (`:crypto.hash/2`, OTP) da lista canônica das
  arestas — `source|target|weight`, ordenada — mais as versões da base. Igual à vigente: a leitura
  não é regravada; só `checked_at` avança, e o relator diz `:unchanged`.

**Razão**: o termo que domina o custo é Q_rand (100 execuções do guloso por rede e janela); na maior
parte das sincronizações nada mudou. `checked_at` separado de `computed_at` mantém o aviso de
*"coleta mais nova que a leitura"* (073, Q3) verdadeiro.

**Alternativas**: recalcular sempre (6 × 101 guloso a cada 15 min por organização); guardar a
impressão fora da leitura (uma tabela a mais para um campo).

## R5 — O teto de tamanho (FR-017)

**Decisão**: chave nova `size_limit` em `network.analysis.parameters`, com `max_people` e
`max_undirected_edges`. Valor **provisório 300 / 3 000**, com a razão: o maior volume medido é 54
pessoas e 155 arestas (R20), e o teto deixa folga de mais de cinco vezes. T050 mede o pipeline
inteiro sobre G(n, m) do tamanho do teto e confirma que as 6 combinações cabem em 120 s; a #1190
traz o número de produção. Acima do teto: σ, Q_rand e layout **ausentes** com
`network_too_large_for_platform`, e não rodam.

**Alternativas**: sem teto (laço sem fim é negação de serviço, R14 da segurança); teto em constante
de módulo (a regra de `review.network.parameters` recusa).

**Medida (T050, 2026-10-05)**: `Commands.compute/5` sobre um G(300, 3 000) sorteado com semente 76,
as duas redes e as três janelas com as mesmas arestas (o pior caso: nenhuma combinação fica abaixo
do teto), parâmetros da base. Máquina: Apple M4, 10 núcleos, 16 GB, Elixir 1.20.2 / OTP 29,
`MIX_ENV=test`, em `test/the_band/network_analysis/teto_test.exs` (tag `:slow`).

| | as 6 combinações |
|---|---|
| medida dos 100 aleatórios em sequência | **105,6 s** |
| medida dos 100 aleatórios em paralelo | **32,9 s** |

Por partes, num G(300, 3 000): o guloso 77 ms e a busca em largura de todos os pares 70 ms por
aleatório — cerca de 16 s para os 100 de uma combinação, que é quase todo o custo; intermediação
358 ms, layout 443 ms, autovetor 9 ms e clustering 3 ms sobre a rede real. Em sequência, o job
ficava a 15 s do `timeout/1` de 120 s **nesta** máquina, e passaria dele numa mais lenta.

**Decisão**: a medida de cada aleatório roda em paralelo (`Task.async_stream/3`, na ordem em que
foram gerados); o sorteio continua sequencial, e o resultado é o mesmo, número por número (a
reprodutibilidade da T049 continua passando). O teto (300 / 3 000) e o `timeout/1` (120 s) **não
mudam**: com 2 núcleos, a estimativa é de cerca de 55 s. **Fica aberto** confirmar com o número de
núcleos de produção e com a medida da #1190 / T003 (a pessoa mantenedora).

**A guarda, provada (2026-10-06)**: o teste tem teto de 90 s. Medido de novo, com a máquina sob
carga: **50,2 s** em paralelo. Com o defeito — a medida em sequência —, **108,2 s**, e o teste
reprova pelo assert. 300 aleatórios em paralelo ficaram em 89,8 s: o teto não distingue um
aumento de 3× nos aleatórios, e não é para isso que ele existe; ele guarda o tempo do job.

## R6 — Os algoritmos, em Elixir puro

Todos em `lib/the_band/network_analysis/algorithms/`, puros: sem `Repo`, sem relógio, sem `Logger`,
sem `:digraph` (tabelas ETS ligadas ao processo, R14). Entrada ordenada por id de pessoa; toda soma
de ponto flutuante percorre a lista na mesma ordem, para que o mesmo dado dê o mesmo número (FR-052).
`n` = pessoas com aresta; `m` = arestas da projeção sem direção.

| algoritmo | referência | o que computa | complexidade |
|---|---|---|---|
| **projeção sem direção** | `network.analysis.parameters.undirected_projection` | {u, v} com peso w(u→v) + w(v→u) | O(m) |
| **componentes fracos** | busca em largura (a da 073, `ReviewNetwork.Graph.groups/1`) | componentes, critério fraco (FR-019) | O(n + m) |
| **busca em largura de todos os pares** | — | distâncias em passos; base de proximidade, distância média, diâmetro, eficiência | O(n·(n + m)) |
| **proximidade** | Wasserman e Faust (1994), `closeness_centrality(wf_improved=True)` | ((r−1)/(n−1))·((r−1)/D(u)); e à parte D(u)/(r−1) e r−1 (FR-035) | dentro da anterior |
| **distância média, diâmetro, eficiência** | Latora e Marchiori (2001) para a eficiência | média sobre pares que se alcançam com a fração \|A\|/\|P\|; máximo em A; Σ 1/d sobre P / \|P\| | dentro da anterior |
| **intermediação** | Freeman (1977), algoritmo de **Brandes (2001)**, sem peso, sem direção | dependências acumuladas por fonte; soma dividida por 2 (pares não ordenados) e por (n−1)(n−2)/2; n < 3 ausente | O(n·m) |
| **autovetor** | iteração de potência sobre **A + I** (como `networkx.eigenvector_centrality`) | por componente com ≥ 2 pessoas, partindo de x = 1, normalizado em L2, converge quando Σ\|Δx\| < n_c × 1e-6, até 1 000 iterações; sem convergência, o componente fica ausente (`did_not_converge`) | O(iterações·(n_c + m_c)) |
| **clustering local** | Watts e Strogatz (1998), média local (C^ws de Humphries e Gurney) | fração dos pares de vizinhos ligados; grau < 2 fora da média e contado (D5) | O(Σ d(u)²) |
| **comunidades** | guloso de **Clauset, Newman e Moore (2004)**, com peso, resolução 1 | começa com uma comunidade por pessoa; junta o par **adjacente** de maior ΔQ = 2(e_ij − a_i·a_j); empate pelo par de menor índice (i, j) lexicográfico, índice inicial = posição na ordem do id; para quando o maior ΔQ ≤ 0; numera por tamanho decrescente, empate pelo menor índice | O(n·m) com varredura simples dos pares adjacentes por passo; mapa de mapas para e_ij |
| **modularidade** | Newman (2004), forma com peso | Q = Σ_c (e_cc − a_c²) | O(m) |
| **grafos aleatórios** | G(n, m) de Erdős–Rényi | ver R7 | O(m) por grafo, esperado |
| **Q_rand** | Guimerà, Sales-Pardo e Amaral (2004) | o **mesmo** guloso em cada aleatório, com os **pesos reais sorteados** (R8) | 100 × O(n·m) |
| **σ** | Humphries e Gurney (2008) | (C/C_rand)/(L/L_rand), C e L dos aleatórios pelas mesmas regras; média sobre os grafos em que a medida está definida, com o número que entrou | 100 × O(n·(n + m)) |
| **percentil e papel** | posto médio (`network.position_role.percentile_method`) | 100 × (#{M < M(u)} + #{M = M(u)}/2)/n; cortes da regra; **na leitura**, nunca gravado (R4 da segurança) | O(n log n) |
| **layout** | Fruchterman e Reingold (1991), como `networkx.spring_layout` | ver R9 | 50 × O(n²) |

**Tolerância do SC-002**, declarada aqui: **1e-9** para o que é exato em aritmética de ponto
flutuante (grau, distâncias, proximidade, eficiência, intermediação, clustering, modularidade de
uma partição dada); **1e-6 relativo** para o autovetor. Os valores de referência das cinco redes
(estrela, caminho, dois grupos com ponte, bipartida, desconexa) são escritos à mão no teste, com o
cálculo ao lado, e conferidos uma vez contra o networkx fora do repositório; o teste não chama
Python (nenhuma dependência nova).

**Razão para Elixir puro**: R14 da segurança e a spec (*Assumptions*): redes de dezenas a poucas
centenas de pessoas; nenhuma biblioteca Hex de grafo cobre CNM com desempate declarado e σ com
gerador declarado. **O que piora**: cerca de seiscentas linhas de algoritmo nosso para testar; o
risco é de correção, e o SC-002 é a guarda.

**Alternativas**: `libgraph` (sem intermediação de Brandes nem comunidades; dependência nova para
BFS); NIF ou porta para networkx (Python, ADR, §2).

## R7 — O gerador pseudoaleatório e o sorteio, declarados (A8 da revisão 2)

**Decisão**:

- algoritmo `:exsss` do `:rand` (Xorshift116**, o padrão do OTP), com **estado explícito**:
  `:rand.seed_s(:exsss, 42)` e `:rand.uniform_s/2`. Nunca o estado no dicionário do processo
  (R14 da segurança: qualquer outra chamada a `:rand` no mesmo processo mudaria a sequência);
- os nós dos aleatórios são os índices 1..n na ordem crescente do id de pessoa;
- **sorteio de G(n, m)**: sorteia u e v uniformes em 1..n; rejeita u = v e par já sorteado
  (normalizado como {min, max}); repete até m pares. Os 100 grafos consomem a **mesma** sequência, em
  ordem: o grafo i começa onde o i−1 parou;
- os pesos do Q_rand (R8) consomem a sequência depois dos pares de cada grafo, pelo embaralhamento
  de Fisher–Yates;
- o layout (R9) usa **outra** semeadura, `:rand.seed_s(:exsss, 42)` de novo, para que a ordem de
  cálculo de σ e de layout não mude as posições;
- `exsss`, a semente, o procedimento de rejeição e o de Fisher–Yates entram na regra
  (`small_world.values.generator`, `.sampling`) e na proveniência da leitura. Trocar qualquer um é
  versão nova da regra.

Conferido nesta máquina (OTP 29): `rand:seed_s(exsss, 42)` aceita inteiro.

**Razão**: FR-052 e SC-003. A semente sozinha não reproduz o sorteio.

## R8 — Q_rand com peso (A5 da revisão 2)

**Decisão**: cada grafo aleatório recebe, nas suas m arestas, o **multiconjunto dos pesos reais** da
projeção sem direção, embaralhado pelo gerador declarado. Q_rand é a média da modularidade da
partição que o **mesmo** guloso, com peso, encontra em cada aleatório. A limitação *"comparação de
ordem de grandeza"* de `network_modularity_score.yaml` cai, e a regra ganha
`modularity_reading.values.random_weights: shuffled_real_multiset`.

**Razão**: pesos concentrados aumentam Q; comparar Q com peso contra Q_rand sem peso enviesaria a
favor de "há estrutura", justamente na rede de designação, que concentra peso. Muda o método, e por
isso passa pela revisão do agente semântico (T006), não só por este plano.

**Alternativas**: manter Q_rand sem peso com a limitação (a revisão 2 o desaconselha); configuração
nula com graus preservados (outra escolha de modelo nulo, não pedida).

## R9 — O layout no servidor (FR-022)

**Decisão**: Fruchterman–Reingold como `networkx.spring_layout`: posições iniciais uniformes em
[0, 1)² sorteadas em ordem crescente de id; k = 1/√n; temperatura inicial 0,1 com resfriamento
linear até zero em 50 iterações; força de atração multiplicada pelo peso da projeção sem direção;
deslocamento limitado pela temperatura. Ao fim, reescala para a caixa [40, 960] × [40, 960] do
`viewBox` e arredonda a uma casa. As duas vistas usam as mesmas posições.

- **alcance total**: as posições gravadas na leitura;
- **alcance parcial**: recalculadas **na leitura** sobre o grafo da visão (alcançados e agregados),
  com a mesma semente e a mesma ordem (R2 da segurança; FR-022). Dezenas de nós: 50 × 2 500 pares,
  medido em T034;
- acima do teto (R5), ausente: a página mostra só a lista (a mesma do telefone).

**Razão**: o mesmo dado dá o mesmo desenho; o navegador não calcula posição; com alcance parcial, as
coordenadas da rede inteira entregariam onde estão as pessoas de fora.

**Medida (T034, 2026-10-04)**: `Algorithms.Layout.fruchterman_reingold/3` com os parâmetros da base
(semente 42, 50 iterações), grafo G(n, 3n) sorteado com semente 76, mediana de 5 corridas, em
`test/the_band/network_analysis/layout_custo_test.exs`. Máquina: Apple M4, 10 núcleos, 16 GB,
Elixir 1.20.2 / OTP 29, `MIX_ENV=test`.

| nós da visão | mediana |
|---|---|
| 50 | **13 ms** |
| 300 (o teto de pessoas, R5) | **463 ms** |

O custo é O(iterações · n²), e 300 nós **passa dos 200 ms** que a tarefa pôs como limite. A
decisão de **guardar o layout por `(leitura, alcance)`** em vez de recalcular a cada leitura fica
aberta para a pessoa mantenedora na [#1384](https://github.com/The-Band-Solution/theband/issues/1384). O que pesa nela: a visão parcial
típica tem dezenas de nós (os alcançados mais um agregado por comunidade), e 50 nós custam 13 ms;
os 463 ms só aparecem numa visão perto do teto, que exigiria alcançar quase 300 pessoas sem
alcançar todas. Guardar por alcance é guardar um desenho por conjunto de pessoas alcançadas — mais
uma tabela, com invalidação a cada mudança de alcance (A22), para um caso que o volume medido
(R20) ainda não mostrou.

## R10 — A visão recortada (FR-011 a FR-016; R1–R6 da segurança)

**Decisão**: `NetworkAnalysis.View` (puro) recebe a leitura, o alcance, o alcance **concedido**
(DS1), a pessoa de quem consulta e os parâmetros, e devolve a visão **sem nomes**; o `Reader` põe os
nomes. As regras, todas da FR-015 com k = 3 (DS2):

1. **nós**: alcançados por id; de fora, um agregado por comunidade com ≥ k; os de comunidades com
   < k num agregado *"other communities"* se juntarem ≥ k; senão nenhum nó, e a marca
   *"has links outside your reach"* em cada alcançado ligado a alguém de fora;
2. **id do agregado**: `outside-<n>`, com n a posição do agregado na lista da visão — opaco, sem
   relação com `person_id` nem hash (A6);
3. **arestas**: alcançado–alcançado como na leitura; alcançado–agregado e agregado–agregado com a
   soma por sentido; nada dentro de um agregado;
4. **supressão complementar**: tamanho de comunidade, arestas internas e número de pessoas da rede
   ou do componente aparecem com alcance parcial só se as pessoas de fora que eles contam forem ≥ k;
   senão `{:suprimido, :fewer_than_k_outside}`;
5. **hubs**: só alcançados, ordenados pela medida da rede inteira, sem posição na rede inteira;
6. **comunidades**: os três mais centrais entre os alcançados; comunidade sem alcançado sem bloco;
7. **papel**: só de alcançado; nenhuma contagem de papel de fora;
8. **DS1 (b)**: hubs, papel e *"os três mais centrais"* de **outra** pessoa só para quem tem escopo
   **concedido** que a alcança, ou administra; a própria pessoa vê o próprio papel sempre. Os três
   mais centrais entram na DS1 porque são ordenação por medida (uma lista de hubs por comunidade);
   **a confirmar** com a pessoa mantenedora (plano, *Decisões a confirmar*);
9. **DS5 (b)**: alcance vazio, ou só a própria pessoa: a visão traz as medidas da rede e o próprio
   perfil; grafo, comunidades, hubs e papéis de outros vêm `{:recortado, :no_reach}`;
10. **grau normalizado** não aparece com alcance parcial (FR-033).

A mesma visão alimenta o grafo ponderado, o de comunidades e a lista do telefone (R2, item 8).

**Razão**: o recorte mora em **uma** função de domínio (FR-013). `View` muda quando a regra de
acesso muda; os algoritmos, quando a matemática muda (princípio X, como `Slice` na 073).

## R11 — O alcance: uma função, com uma opção (FR-013; R5 da segurança; DS1, DS4)

**Decisão**:

- a área inteira usa `Tenants.pessoas_alcancadas/2`, chamada **dentro** de `NetworkAnalysis.read/4` e
  `profile/5`, a cada chamada; `pode_ver/3` não é chamado em nenhum ponto da área;
- a DS1 pede quem alcança **por concessão**. Em vez de uma segunda função, a mesma ganha uma opção:
  `Tenants.pessoas_alcancadas(tenant, user, origem: :concedida)`, que considera só escopos com
  `origin: :granted` (e `:todas` para a administração). É o que a DS1 recomendou (*"uma variante
  ... no módulo de acesso, e não na tela"*);
- DS4 (a): a #1185 é resolvida **corrigindo a frase** do aviso de recorte da verificação
  (`lib/the_band_web/live/verification_live/people.ex:157-161`) para a regra de
  `pessoas_alcancadas/2`. Tarefa da Fase 2, `security`, antes da que aplica o alcance.

**Alternativas**: função nova `pessoas_alcancadas_por_concessao/2` — duas portas com nomes
parecidos são como a R5 nasceu.

## R12 — A rede de designação: a consulta e a classificação (FR-005 a FR-009; R9 da segurança)

**Decisão**: `WorkItems.assignment_pairs(tenant, repository_ids, since: instante)` devolve, por par
(issue, responsável vigente) de issue aberta desde o instante: `collected_issue_id`, `opened_at`,
`author_person_id`, `author_account_type`, `assignee_person_id`, `assignee_account_type`. Seis
filtros de tenant (issue, responsável, autor, responsável como pessoa, repositório observado,
repositório de origem), `a.no_longer_observed_at IS NULL`, `i.no_longer_observed_at IS NULL`.
**Nenhum login** é lido. Os repositórios vêm de `CMPO.list_observed(tenant, organization_id: …)`
sem os excluídos, como na 073 (`commands.ex:80-88`).

`AssignmentClassification.classify/3` recebe os pares, os tipos de EO (`EO.account_types/2`) e as
contas declaradas da organização (R14), e devolve, por par, exatamente um destino, na ordem da
regra: `bot_or_app` → `organization_account` → `unlinked_person` → `self_assignment` →
`{:aresta, autor, responsável}`. A conta não ligada usa o tipo **gravado** (R13). O peso é o número
de issues **distintas** do par; o invariante da regra (soma dos pesos + exclusões = pares) é
conferido em teste. Issue sem responsável vigente conta em `issues_without_assignee`.

**Por que não reaproveitar `ReviewNetwork.Classification`**: os lados de entrada são diferentes (a
revisão tem `__typename` do revisor e só o login do autor; a designação passa a ter o tipo gravado
dos dois lados), e a ordem tem um degrau a mais. É a **segunda** ocorrência; a terceira abstrai
(princípio VIII).

## R13 — O tipo da conta gravado na coleta de issues (A3 da revisão 2)

**Medido** (desenvolvimento, 2026-10-04): nos payloads brutos de `github.issue`
(`raw_payloads`), **12** têm `author.__typename = "Bot"`; em `collected_issues`, **3** issues têm
autor não ligado com login **sem** o sufixo `[bot]`, e nenhuma com o sufixo. A hipótese da revisão 2
se confirma: pela regra de hoje, essas contas cairiam em `unlinked_person`, e não em `bot_or_app`.

**Decisão**:

1. migração aditiva: `collected_issues.author_account_type` e `issue_assignees.account_type`, texto
   anulável com `check` em `('person', 'bot', 'app')`;
2. a coleta grava o tipo por `Mapper.account_type/1` sobre o nó (`author` e cada nó de `assignees`
   trazem `__typename`, `issues.graphql:44-45`). **Chamado, nunca reimplementado**;
3. migração de dados, separada, que preenche as linhas existentes a partir do payload bruto mais
   recente de cada issue (`raw_payloads`, `raw_entity_type = 'github.issue'`, mesmo
   `tenant_id` e `external_id`). `down` explícito que anula as duas colunas;
4. tipo **nulo** (payload ausente) → `unlinked_person`, e a leitura conta quantas linhas
   classificou sem tipo (`provenance.account_type_unknown`), para a limitação ser medida e não
   presumida.

**Razão**: é a FR-007 e o SC-001; a 073 resolveu o mesmo problema gravando `author_type`.

## R14 — A conta da organização (D3 (a), R8 da segurança, A7)

**Decisão**:

- relator `organization_account_declarations` em `TheBand.Tenants.Access` (mesmo desenho de
  `ScopeGrant`): `tenant_id`, `person_id` (FK composta com `eo_people(id, tenant_id)`),
  `declared_by_user_id`, `declared_at`, `reason` (obrigatório), `revoked_by_user_id`, `revoked_at`.
  Índice único parcial de uma declaração vigente por pessoa. **Nunca** em `eo_people.account_type`,
  que a coleta reescreve;
- `Tenants.declare_organization_account/4`, `revoke_organization_account/3`,
  `organization_account_ids/1`, `list_organization_accounts/2`. Só administração **deste** tenant
  (`PapelDeAdministrador.exigir_ator/2`, relido no banco); recusa pessoa com elo vigente com conta
  da plataforma (`Tenants.person_of_user`) e a pessoa da própria conta de quem declara;
- eventos em `Tenants.AccessEvents` ao declarar e revogar (tenant, conta que agiu, pessoa, resultado);
- tela: na página da pessoa (`PeopleLive.Show`), para a administração, o controle de declarar e
  revogar com motivo; na lista de pessoas, para a administração, as contas declaradas e quem
  declarou; na área, para todos, *"accounts declared by administrators as organisation accounts are
  not people in this network"* com o número de contas declaradas **na organização**;
- **A7, opção padrão (a confirmar)**: a marca vale para as **duas** redes. Exige
  `review.network.edge` versão 2, com `organization_account` entre `bot_or_app` e
  `unlinked_person`; `ReviewNetwork.Classification` ganha o degrau; `review_network_readings` ganha
  `excluded_organization_account`, **anulável**: nulo nas leituras da versão 1, que não o avaliaram
  (ausência nunca é zero). A página da 073 mostra o motivo novo junto dos três. Se a pessoa
  mantenedora decidir que não vale, T027 sai do backlog e a área diz, na rede de revisão,
  que a marca não se aplica.

**Razão**: com a marca só na designação, a mesma conta é nó numa rede e excluída na outra, e as
medidas das pessoas ligadas a ela deixam de ser comparáveis no seletor (A7).

## R15 — As páginas, as rotas e o menu (FR-001 a FR-003; protótipo aprovado)

**Decisão**: item **Network analysis** na barra principal (`lib/the_band_web/components/layouts.ex`),
depois de *Organization*, com `{"/network-analysis", :network_analysis}` em `@nav_areas`. Rotas, todas
`live`, no `live_session :autenticado` (qualquer conta do tenant; o recorte é a função de domínio):

| rota | página do protótipo |
|---|---|
| `/network-analysis` | a área: escolhe a organização (com uma só, vai direto a ela) |
| `/network-analysis/:organization_id` | Review network — a página da 073 (`ReviewNetworkLive.Show`, montada também aqui) |
| `/network-analysis/:organization_id/graph` | Graph (ponderado, com a alternância de vista da FR-026) |
| `/network-analysis/:organization_id/communities` | Communities |
| `/network-analysis/:organization_id/hubs` | Hubs |
| `/network-analysis/:organization_id/distance` | Distance and small world |
| `/network-analysis/:organization_id/positions` | Positions and profiles (a lista por nome) |
| `/network-analysis/:organization_id/people/:person_id` | o perfil (US9) |

Parâmetros `?network=review|assignment&window=30|90|180&view=weighted|communities`, comparados como
texto exato contra as listas da base; fora da lista, o padrão (FR-002). O endereço antigo
`/organizations/:id/review-network` continua como rota `live` da mesma LiveView, ação `:legacy`, que
valida o id por `EO.fetch_organization/2` e faz `push_navigate` para `~p"/network-analysis/#{id}"` com
a janela da lista; nada do parâmetro original é colado (A13).

**Divergência registrada**: o protótipo desenha as rotas sob `/organizations/:id/network/...`. A
spec pede a área marcada como ativa no menu (FR-001), e o mapa de áreas é por prefixo; sob
`/organizations`, a área ativa seria *Organization*. A rota não é elemento aprovado da tela.

## R16 — O SVG, o zoom e o destaque (FR-020 a FR-026; R6, R13 da segurança)

**Decisão**:

- componente de função `TheBandWeb.NetworkAnalysisLive.GraphComponents.graph/1`, que renderiza
  `<svg viewBox="0 0 1000 1000">` **inline** no HEEx: `<line>` com `marker-end` para a seta,
  `<circle>`, `<text>` e `<title>` com o nome **escapado** pelo HEEx. Nenhum `raw/1`, nenhum
  `<foreignObject>`, nenhum `data-*` com JSON;
- todo atributo numérico (`cx`, `cy`, `r`, `stroke-width`, coordenadas) formatado no servidor
  (`:erlang.float_to_binary(x, decimals: 1)`); cor por **classe** da paleta fixa, nunca `style` com
  dado; `href` só por `~p` para o perfil de pessoa alcançada;
- cor da intermediação em cinco faixas (`none`, `<2%`, `2–5%`, `5–10%`, `≥10%`, protótipo 3.2.1),
  declaradas na base (`network.analysis.parameters.betweenness_color_bands`, com a razão: faixa de
  **cor**, numérica, sem adjetivo) — sem isso, a FR-031/FR-038 (nenhuma faixa sem razão na base)
  reprovaria o protótipo;
- **zoom e arrasto**: hook co-localizado `.NetworkGraph` (`phoenix-colocated` já está em
  `assets/js/app.js:25`) que só aplica `transform` no `<g>` de viewport e responde a roda, botões
  + / − / *fit* e arrasto. Não recebe dado, não faz `pushEvent`;
- **destaque**: `Phoenix.LiveView.JS` (`add_class`/`remove_class`) em `phx-mouseenter`, `phx-focus`
  e toque, sobre classes já renderizadas: cada aresta leva as classes `e-<id do nó>` das duas pontas.
  Nenhuma ida ao servidor; não há `handle_event` de destaque (A8 fica sem superfície). O texto
  *"N links out, M in"* do nó é renderizado no `<title>` e na lista;
- **vista ponderada × comunidades** (FR-026): as duas colorações estão no markup como classes; o
  botão alterna uma classe no `<svg>` por `JS.toggle_class`. Sem recalcular;
- **telefone**: o SVG é `hidden sm:block`; a lista empilhada (`<.data_table stacked>` com
  `data-label`) é `sm:hidden` e carrega toda informação do grafo (FR-025, SC-007);
- nomes escritos só para os sete mais ligados (protótipo 3.2.2); os demais no `<title>`, no foco e
  na lista. O número sete entra em `network.analysis.parameters.layout.labelled_nodes`.

## R17 — O cálculo grava; a leitura deriva (FR-018)

**Decisão**: gravados por rede e janela: arestas, exclusões, pessoas sem aresta, por pessoa (graus,
intermediação, proximidade, distância média e alcance, autovetor ou motivo, componente, comunidade,
grau interno, posição), comunidades, medidas da rede (com as dos aleatórios), impressão digital,
proveniência. **Não** gravados: percentil e papel (derivam-se na leitura pela regra vigente),
nomes, logins, a visão recortada. A substituição apaga só `(tenant, organização, rede, janela)`
da mesma rede (A21) e usa `Repo.insert/1`, nunca `insert!`; erro devolve
`{:error, {:reading_rejected, [campos]}}` só com nomes de campo (R10 da segurança, A18).

## R18 — Retenção (R11 da segurança)

**Decisão**: `Sources.end_observation/3`, dentro da transação, chama
`NetworkAnalysis.discard_organization/2` e `ReviewNetwork.discard_organization/2`, que apagam as
leituras da organização. A leitura não mostra leitura com `computed_at` mais velho que a maior
janela (180 dias): `{:ausente, :stale}` com o motivo na tela. Pessoa apagada de EO: com `:todas`,
entra no agregado *"no longer in the platform"* sob k; com alcance parcial, é de fora.

**Por que a 073 também**: é o mesmo defeito, na mesma superfície (§14.0, item 2), e o conserto é a
mesma linha.

## R19 — A base de conhecimento (princípio IV)

**Decisão**: os 24 arquivos de `proposta-base/` vão para `priv/knowledge_base/` pelo quadro do
`proposta-base/README.md`, **depois** das emendas deste plano revisadas pelo agente semântico:

- `network.analysis.parameters`: `size_limit` (R5), `modularity_reading.random_weights` (R8),
  `small_world.generator` e `.sampling` (R7), `betweenness_color_bands` e `layout.labelled_nodes`
  (R16), `hubs_list_size.tie_break` mantido no id (o protótipo dizia *"empates por nome"*; vale a
  base, A4 da revisão 2);
- `network_modularity_score.yaml`: limitação de Q_rand sem peso retirada (R8);
- **perguntas de competência** da necessidade `network.structure` (a revisão 2, §4, diz que já podem
  ir para o plano): uma por medida que a tela mostra, testadas por `mix knowledge.test`;
- com A7 confirmado: `review.network.edge` versão 2.

`derivation_rule` não tem schema (lacuna da 073); a forma é garantida por `NetworkAnalysis.Parameters`,
que **levanta** quando falta chave, e por teste que injeta a falta.

## R20 — Volume medido

Desenvolvimento, 2026-10-04, maior organização observada, issues abertas nos últimos 180 dias:
**2 906 issues**, **2 585** designações vigentes, **155** arestas dirigidas autor → responsável entre
pessoas ligadas, **54** pessoas; consulta de **46,8 ms** sem índice novo. Rede de revisão (073,
2026-10-03): 40 pessoas, 233 arestas.

**Produção, 2026-10-09 (T003)**: o log do job `análise de rede` da v0.12.0, na organização
`leds-conectafapes`, a única observada. Só agregados; medido pela pessoa mantenedora, a partir do log
do container.

| rede | janela | pessoas | arestas | duração do cálculo |
|---|---|---|---|---|
| designação | 30 d | 48 | 87 | 99 ms |
| designação | 90 d | 48 | 137 | 126 ms |
| designação | 180 d | 54 | 171 | 233 ms |
| revisão | 30 d | 42 | 126 | 105 ms |
| revisão | 90 d | 46 | 205 | 133 ms |
| revisão | 180 d | 49 | 258 | 143 ms |

A janela de 180 dias tem 3 036 issues, e `unlinked_person: 0` na designação. O teto (300 pessoas / 3
000 arestas) está longe, e a R5 e a T050 **não** reabrem. **Não medidos**: os núcleos da máquina e
o tempo isolado de `WorkItems.assignment_pairs/3` (a duração acima já inclui a consulta).

## R21 — Divergências do protótipo aprovado, e o que vale

| protótipo | vale | por quê |
|---|---|---|
| *delegation* | *assignment* | D1, A1 da revisão 2 |
| Louvain | guloso CNM com peso e desempate | A4 da revisão 2 |
| 50 aleatórios; σ *"not tested"* em rede partida | 100; σ calculado pelos pares que se alcançam | FR-041, FR-042 |
| autovetor sem deslocamento, ausente para todos | A + I, por componente | FR-036 |
| empate por nome nos hubs | empate pelo id, marcado *"tied"* | base, `hubs_list_size` |
| *"a person outside your reach"* nos hubs (3.7.4) | só alcançados | R1 da segurança, Q3 da aprovação |
| conta sem alcance vê o grafo agregado | só medidas e o próprio perfil | DS5 (b) |
| comunidades por **letra** (A, B, …) | letra, como aprovado (3.3.2): é o identificador em texto que a FR-021 pede; a spec usa *"Community 1"* como exemplo | a confirmar com a pessoa mantenedora (baixo) |
| rotas `/organizations/:id/network/...` | `/network-analysis/...` | R15 |

**Encontradas na conferência da T053 (2026-10-06), e aprovadas pela pessoa mantenedora no mesmo
dia (T054): "não faça igual ao protótipo".** As dez valem como estão no código, e são divergências
aprovadas como as de cima.

| protótipo | vale hoje | por quê | estado |
|---|---|---|---|
| posição em frase sobre as ligações (*"Linked to many people, and on many paths…"*) | rótulo e frase da regra `network.position_role` (*"Central position. Among the top fifth…"*) | FR-044, D2 | aprovada em 2026-10-06 |
| listas do perfil por nome | por peso, empate pelo nome | FR-048 | aprovada em 2026-10-06 |
| perfil com proximidade e autovetor | sem eles | FR-048 | aprovada em 2026-10-06 |
| autovetor de 0 a 100, relativo ao maior | 0 a 1, comparável só dentro do grupo; abaixo de 0,005, *"under 0.01"* | R1 da segurança: com alcance parcial, o 100 poderia ser de alguém de fora; `contracts/tela.md` | aprovada em 2026-10-06 |
| a Tela 1 sempre | com uma organização só, `/network-analysis` vai direto a ela | `contracts/tela.md` | aprovada em 2026-10-06 |
| aviso de alcance explicando o que é o alcance | o texto da spec, sem a explicação | US1, cen. 5 | aprovada em 2026-10-06 |
| agregado *"N outside your reach · B"* | *"People outside your reach — community B (4)"* | US3, cen. 5; `contracts/tela.md` | aprovada em 2026-10-06 |
| linha da leitura com *derived* na página da 073 | a da 073, como aprovada | Q4 (a) da aprovação | aprovada em 2026-10-06 |
| seletores em preto; menu lateral; perfil em 2×2 | primária verdete; abas no topo; uma coluna por rede | design system; o menu da área | aprovada em 2026-10-06 |
| cor da intermediação em barra segmentada | cinco círculos com o rótulo de cada faixa | a mesma regra, outra forma | aprovada em 2026-10-06 |
| grafo na proporção do quadro | as posições do servidor enquadradas eixo a eixo em 1000 × 625, e os sete nomes postos sem colisão | defeito D2 da T053: o viewBox quadrado espremia o núcleo; a posição não é medida (`Algorithms.Layout`) | feito na T053 |

## R22 — Nenhuma dependência nova (R14 da segurança)

`mix.exs`, `mix.lock` e `assets/package.json` não mudam. SHA-256 por `:crypto` (OTP). O hook é
co-localizado e servido de `'self'`; a CSP não muda. `mix hex.audit` e `mix deps.audit` ficam como
estão.

## R23 — O cálculo que falhou (edge case *"Cálculo falhou"*)

**Decisão**: a falha não se grava, como na 073 (`specs/073-rede-de-revisao/plan.md`, *O que este
plano NÃO resolve*). A substituição é atômica: se o job cancela, estoura o `timeout/1` ou levanta,
a leitura vigente continua a anterior, **com o instante dela** na linha da leitura, e nunca como se
fosse de agora. A tela diz que a leitura não está disponível, e por quê, nos três casos em que não
há leitura a mostrar: `not_computed` (nunca calculada), `stale` (mais velha que a maior janela) e a
rede de revisão sem leitura da 073. A linha *"there is a newer collection"* (073, Q3) avisa quando a
coleta terminou depois do último cálculo bem-sucedido, que é o sinal visível de um cálculo que
falhou depois dela.

**Alternativas**: gravar o estado de falha por organização (tabela ou coluna a mais, e um segundo
caminho de escrita que pode discordar do primeiro); se a pessoa mantenedora pedir, é FR nova.
