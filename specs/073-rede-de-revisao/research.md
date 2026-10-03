# Pesquisa da 073 — rede de revisão

**Plano**: [plan.md](plan.md) · **Spec**: [spec.md](spec.md) · **Segurança**: [seguranca.md](seguranca.md)
**Data**: 2026-10-03 · **Base**: `development` em `ec07df5` (branch `feature/1182-rede-de-revisao`)

Cada item tem **decisão**, **razão** e **alternativas**. As afirmações sobre o código citam
arquivo e linha. As medidas de volume foram feitas no banco de **desenvolvimento** em 2026-10-03,
só com contagens (nenhum nome, nenhum login saiu da consulta). Não são medidas de produção, e o
plano diz onde isso importa (R10).

---

## R1 — Onde o módulo mora, e o nome

**Decisão**: subsistema próprio, `TheBand.ReviewNetwork`, em `lib/the_band/review_network.ex`
(fachada só com `defdelegate`) e `lib/the_band/review_network/`. O nome é o da coisa derivada:
a rede formada pela participação `qapo.stakeholder_performed_artifact_evaluation` sobre
`cmpo.change_request`, entre pessoas de `eo.person`. **Não** se chama `Collaboration`: a FR-005
recusa a palavra, e revisar não é colaborar.

**Razão**:

- a rede atravessa três ontologias (QAPO, CMPO, EO) e não é conceito de nenhuma delas. Não há
  `kind` a materializar (princípio IX): é **leitura derivada**, como `TheBand.Verification` e
  `TheBand.Forecast`, que já moram no topo de `lib/the_band/`;
- `TheBand.Quality` (`lib/the_band/quality.ex:1-17`) é a leitura de `qapo.artifact_evaluation`.
  Pôr a rede ali daria a ele uma segunda razão para mudar (princípio X): a rede tem tabela, job,
  regra de alcance e parâmetros próprios, e muda quando a regra de recorte muda, o que nada tem a
  ver com o tempo até a primeira revisão;
- a fronteira continua verificável em revisão: a rede **lê** pelas APIs públicas de `Quality`,
  `Changes`, `EO` e `CMPO` (R4), e grava **só** na tabela dela.

**Alternativas**:

- `TheBand.Quality.ReviewNetwork`: recusada pela razão de X acima;
- `lib/the_band/analytics/review_network/`, que o `AGENTS.md` §5 prevê para a camada de acesso:
  recusada **agora**. Seria a primeira e única moradora da pasta, e as três leituras irmãs
  (`Quality`, `Verification`, `Forecast`) estão no topo. Movê-las seria refatoração sem relação
  com esta feature (§17). Fica como observação para quando houver a segunda rede (fatia 2 do
  épico).

---

## R2 — A unidade: o que é "uma revisão" nesta rede

**Decisão**: a unidade de contagem é o **par (revisor, solicitação de mudança) distinto**, entre
duas pessoas observadas com `account_type = 'person'`, com ao menos uma avaliação enviada desse
revisor naquela solicitação dentro da janela.

- **peso da aresta** revisor → autor = número de solicitações distintas do autor que o revisor
  revisou na janela (FR-002);
- **revisões feitas por uma pessoa** = soma dos pesos das arestas que saem dela = solicitações
  distintas que ela revisou;
- **total de revisões** de um recorte = soma dos pesos das arestas do recorte;
- **concentração para k** = (soma das revisões feitas pelas k pessoas que mais revisaram) ÷
  (total de revisões), sobre o **mesmo** recorte. As frações são crescentes em k e nunca passam
  de 1.

**Razão**: é a única unidade que se soma sem dupla contagem e com a qual a concentração é uma
razão de concentração de verdade (as k parcelas são partes do mesmo todo). A suposição da spec
sobre o peso (*"solicitações distintas, e não eventos de revisão"*) já a escolhe para a aresta;
a concentração e o total usam a mesma, para que **um** número não tenha duas definições na tela
(L67).

O cenário 1 da US1 (*"40 solicitações revisadas, 30 delas por Ana → 75%"*) é exatamente isto
quando cada solicitação tem um revisor. Quando uma solicitação tem dois revisores, ela conta duas
revisões, uma de cada um. **Isto precisa estar escrito na tela e na base**, e está em
[data-model.md](data-model.md#medidas) e na limitação da medida.

**Alternativa considerada, e por que não**: denominador = solicitações revisadas distintas, e a
fração = parte das solicitações em que alguma das k pessoas revisou. Responde *"quanto do fluxo
para se as k saírem"*, que é outra pergunta, legítima. Recusada aqui porque:

1. as frações deixam de ser parcelas de um todo (k = 1 e as outras podem somar mais de 100%);
2. no recorte por alcance (FR-015), contar solicitações distintas exige guardar **qual pessoa
   revisou qual solicitação**, o que a leitura materializada não guarda (R7 da segurança, mínimo
   de dado pessoal). Com pares, os pesos das arestas bastam.

**Confirmação pendente**: a pessoa mantenedora confirma a unidade **no protótipo** (o rótulo do
número precisa dizê-la). Não bloqueia o plano: a troca muda a fórmula da medida 4 e a função pura
de concentração, e não a tabela.

**Consequência que o plano aceita**: o total por pessoa e as frações não falam de
"solicitações revisadas" da organização. A tela não mostra esse número (uma segunda contagem com
outra população seria a L67).

---

## R3 — Quais avaliações contam, e a ordem das exclusões

**Decisão**:

1. **Estados que contam**: `APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`, por **lista
   explícita** lida da regra da base, com `external_submitted_at` não nulo. Estado novo da origem
   **não** entra por omissão: a lista é de inclusão, e não *"tudo menos PENDING"*. É a mesma
   postura do `unmapped: reject` de `priv/knowledge_base/mappings/github/qapo/review.yaml`
   (*"o não reconhecido alguém corrige, o reconhecido errado vira medida"*);
2. avaliação e solicitação com `no_longer_observed_at` nulo, como em todo `Quality`
   (`lib/the_band/quality.ex:41`, `:78-79`);
3. **cada par (conta revisora, solicitação) cai em exatamente um destino**, nesta ordem:
   1. **bot ou aplicativo**, se qualquer dos dois lados for. Pessoa ligada: `eo_people.account_type
      ∈ {bot, app}`. Conta não ligada: `Mapper.account_type/1`
      (`lib/the_band/semantic_integration/mapper.ex:93-101`) aplicado ao `__typename` e ao login,
      **chamado e nunca reimplementado** (precedente `lib/the_band/ingestion/github_work_items.ex:510`);
   2. **pessoa não ligada**, se qualquer lado não tem `person_id`. A conta apagada na origem
      (`author` nulo, `author_type` nulo) cai **aqui**, e não em bot: `Mapper.account_type(%{})`
      devolve `"person"` (`mapper.ex:101`), e "não sei quem é" não é "é máquina" (R9 da
      segurança, terceiro item);
   3. **auto-revisão**, se revisor e autor são a mesma pessoa;
   4. senão, **aresta**.

**Invariante que vira teste**: total de pares da janela = soma dos pesos + bot + não ligada +
auto-revisão. É o que torna o SC-001 conferível por contagem manual, e a falha de qualquer
classificação aparece como diferença, e não some.

**Razão do nó exigir `account_type = 'person'`** (R9 da segurança): `Quality` decide humano por
`author_type == "User"` (`quality.ex:25`), e EO classifica por `__typename` **e** sufixo `[bot]`
do login (`mapper.ex:92-101`). Uma conta `User` com login `algo[bot]` passa no primeiro e é bot no
segundo. **Medido no banco de desenvolvimento**: das 4 954 avaliações, 4 803 são `User` com pessoa
`person`, 97 são `Bot` sem pessoa, 54 são `User` sem pessoa ligada, e **zero** são `User` ligadas
a pessoa `bot`. O caso não existe hoje no dado; a guarda existe porque a regra é de EO, e não de
`author_type` (cenário A14).

**O lado do autor da solicitação** não tem `__typename` gravado (`collected_change_requests` só
tem `author_login` e `author_person_id`,
`priv/repo/migrations/20260818020000_create_collected_changes.exs:37-38`). Para autor não ligado,
a classificação usa só o login. É limitação declarada na regra, e não lacuna escondida.

**PENDING**: no dado de desenvolvimento **não há** avaliação com `external_submitted_at` nulo (a
API do GitHub não devolve rascunho de outra pessoa). O filtro fica como defesa, e a regra diz que
o rascunho não conta (FR-003).

---

## R4 — "A organização", e as consultas sem furar fronteira

**Decisão** (decisão da pessoa mantenedora em 2026-10-03, R4): organização é a
`eo_organizations` observada, buscada por **id e tenant juntos**. A solicitação pertence à
organização pelo repositório: `collected_change_requests.observed_repository_id →
observed_repositories.source_repository_id → cmpo_source_repositories.organization_id`
(`priv/repo/migrations/20260811150100_create_cmpo_source_repositories.exs:54`).

A pessoa entra na rede de A pela **atividade nos repositórios de A**, e não pela equipe. Quem é
de B e revisou em A aparece em A, porque revisou ali. O cenário A3 usa pessoas que só agem em B, e
é isso que ele prova.

**As leituras, cada uma pela fronteira do dono** (contrato em
[contracts/fronteiras.md](contracts/fronteiras.md)):

| passo | quem responde | por quê ali |
|---|---|---|
| a organização existe neste tenant? | `EO.fetch_organization/2` (**nova**, sem `!`) | `EO.fetch_organization!/2` (`lib/the_band/ontology/seon/eo/queries.ex:768-773`) levanta; o job precisa de `{:error, :not_found}` para cancelar sem gravar (FR-010) |
| quais repositórios observados são dela | `CMPO.list_observed/2` com a opção **nova** `organization_id:` | a consulta já seleciona `r.organization_id` (`lib/the_band/ontology/seon/cmpo/queries.ex:39`); filtrar no banco, e não em `Enum` (§7.2) |
| os pares revisor–solicitação da janela | `Quality.review_pairs/3` (**nova**) | `Quality` é dona de `collected_artifact_evaluations` e já junta `collected_change_requests` (`quality.ex:74-80`) |
| quem abriu solicitação na janela | `Changes.change_request_authors/3` (**nova**) | `Changes` é dona de `collected_change_requests`; é o que põe Caio (US2, cenário 2) na lista |
| que tipo de conta é cada pessoa | `EO.account_types/2` (**nova**) | `eo_people` é de EO; juntar a tabela em `Quality` seria a segunda junção de tabela de EO fora de EO (a primeira é `quality.ex:169`) |
| o nome de cada pessoa, na leitura | `EO.people_names/2` (existe, `eo/queries.ex:101-108`) | filtra por tenant: um id de outro tenant nunca vira nome (R3 da segurança, item 3) |
| quem da organização não teve atividade | `EO.organization_person_ids/2` (**nova**) | a contagem da US2, cenário 3, sobre as pessoas `person` da organização |

**Tenant em cada tabela** (R12 da segurança): `Quality.review_pairs/3` filtra `a.tenant_id`
**e** `c.tenant_id`, e junta `a.collected_change_request_id == c.id and a.tenant_id ==
c.tenant_id`. A FK de avaliação para solicitação é simples
(`priv/repo/migrations/20260819040000_create_artifact_evaluations.exs:44-46`), e é a cláusula da
consulta, e não o banco, que impede a avaliação de T2 apontando para solicitação de T1 (A2).

**Alternativa recusada**: uma consulta só, em `ReviewNetwork`, juntando as cinco tabelas por nome,
como `TheBand.Verification.by_organization/1` faz (`lib/the_band/verification.ex:758-775`).
É mais curta e tem precedente, e é a forma que o princípio X, letra D, chama de violação
(*"depender da fronteira pública de outro, nunca das tabelas dele"*). O custo da fronteira aqui
é medido: **cinco consultas** por cálculo, todas com índice, sobre centenas de linhas.

---

## R5 — Os algoritmos, em Elixir puro, e por que sem dependência

**Decisão**: `TheBand.ReviewNetwork.Graph`, módulo **puro** (sem `Repo`, sem relógio), que
recebe a lista de pares classificados e devolve arestas, contagens por pessoa, grupos e
concentração.

| cálculo | como | custo |
|---|---|---|
| arestas com peso | `Enum.frequencies_by/2` sobre `{revisor, autor}` dos pares que viraram aresta | O(P) |
| revisões feitas e de quantas pessoas | soma dos pesos e número de arestas que saem de cada nó | O(E) |
| revisões recebidas e por quantas pessoas | solicitações distintas do autor com ao menos um par aresta, e número de arestas que chegam | O(P) |
| grupos (componentes **fracamente** conexos) | lista de adjacência **não dirigida** em mapa, e busca em largura com `MapSet` de visitados. Só nós com ao menos uma aresta (FR-007, item 3) | O(V + E) |
| concentração top-k | pesos de saída por revisor, ordenados decrescentes, prefixos de soma para k = 1..3 | O(V log V) |

Busca em largura, e não união-busca: com imutabilidade, a união-busca precisa de um mapa de pais
com compressão de caminho reescrito a cada passo, e não ganha nada na escala medida. Componente
fraco é a mesma noção do repositório de referência (`dashboard_team_graph.py:281`,
`nx.weakly_connected_components`).

**Determinismo (FR-012, SC-005)**: toda saída é ordenada (arestas por `{revisor, autor}`, grupos
por tamanho decrescente e depois pelo menor id, frações por k), e a janela entra como **par de
instantes recebido**, nunca como `DateTime.utc_now/0` dentro da função. Dez repetições do mesmo
cálculo comparam igual por `==`.

**Escala medida** (desenvolvimento, 2026-10-03, 180 dias até a última revisão coletada): **2 561**
eventos de revisão, **40** revisores, **233** arestas. A consulta inteira levou **11,8 ms**.

**Princípio VIII, as três perguntas para NÃO trazer `libgraph`** (ou qualquer biblioteca de
grafo):

1. *Que problema a biblioteca resolveria?* Componentes fracos e grau de saída. Os dois somam
   umas quarenta linhas sobre `Map` e `MapSet`;
2. *Existe agora?* Não: o tamanho medido é 40 nós e 233 arestas. Centralidade de intermediação,
   comunidades e caminhos (fatias 2 e 3 do épico) **não** estão nesta feature (FR-019);
3. *O que piora sem ela?* Código de grafo nosso para testar e manter. Com ela: dependência nova
   (manutenção, auditoria em `hex.audit`/`deps.audit`, ADR não exigida mas justificativa sim), para
   duas funções. **A spec já exclui dependência nova**, e esta pesquisa confirma que ela não é
   necessária. Quando a fatia 3 pedir intermediação, a pergunta volta, com medida.

---

## R6 — O alcance: `pessoas_alcancadas/2`, e não `pode_ver/3`

**Decisão**: a função de leitura chama `TheBand.Tenants.pessoas_alcancadas/2`
(`lib/the_band/tenants/access.ex:325-361`, delegada em `lib/the_band/tenants.ex:38`) **a cada
leitura**, dentro de `ReviewNetwork.read/4`.

**Razão**:

- a pergunta é sobre um **conjunto** (quais pessoas da rede eu alcanço), e `pessoas_alcancadas/2`
  responde em três consultas (`access.ex:302-307`). `pode_ver/3` responde por alvo e consulta as
  equipes do alvo (`access.ex:235-264`, `:404+`); por pessoa da rede seria a L38;
- é a regra que as telas de pessoa nomeada já usam: `verification_live/people.ex:90`,
  `change_live/commits.ex:76`, `api/v1/person_controller.ex:198`. A FR-015 pede *"a mesma regra da
  tela de pessoas"*;
- ela é **mais estreita** que `pode_ver/3`: não inclui a liderança declarada (`EO.Visibility`),
  como `person_controller.ex:195-197` registra. O erro é para o lado fechado.

**Recalculada a cada leitura** (R10 da segurança): nenhum `assign` guarda o conjunto; trocar de
janela e receber o aviso de leitura pronta passam pela função de domínio de novo. Custo: três
consultas por leitura.

**Dependência #1181**: o conserto (`user.tenant_id == tenant.id` antes de `:todas`) foi mergeado
em `development` como **`2535f6d`** (PR #1183, 2026-10-03 12:50 UTC), **depois** de esta branch
nascer. Ele **não está** na branch (`git merge-base --is-ancestor 2535f6d HEAD` falha). A tarefa
que lê a rede com alcance começa com `development` integrada na branch, e o cenário A18 prova.

**Achado lateral, fora do escopo**: o aviso de recorte de `verification_live/people.ex:157-161`
diz que a lista inclui *"whoever you lead by declared role"*, e a função que ela chama **não**
inclui a liderança declarada. A tela afirma mais alcance do que aplica. A tela da 073 **não**
copia a frase; o aviso dela descreve o que `pessoas_alcancadas/2` faz. O achado vai como issue
própria.

---

## R7 — A leitura materializada: uma por organização e janela

**Decisão**: tabela `review_network_readings`, uma linha **vigente** por `(tenant, organização,
janela)`, garantida por índice único. O job grava as três janelas numa **transação**: apaga as
linhas da organização e insere as três novas. Nenhuma leitura antiga sobrevive (R7 da segurança,
decisão de 2026-10-03). Desenho em [data-model.md](data-model.md).

**O que a linha guarda, e o que não guarda**:

- guarda as **arestas com peso** (ids de pessoa), a **lista de pessoas** com o que não se deriva
  das arestas (solicitações distintas revisadas de cada autor), as **exclusões** por motivo, a
  janela, o instante e as versões da base;
- **não** guarda nome, login (R3, R7 da segurança), nem quem revisou qual solicitação;
- **não** guarda grupos nem concentração. Os dois são **função pura das arestas** e dependem do
  alcance de quem lê (R1 da segurança). Guardá-los daria uma segunda verdade para o leitor com
  alcance total, e um segundo caminho de cálculo (o guardado, para quem administra; o recalculado,
  para quem não administra), que divergiria na primeira correção. A entidade-chave da spec diz que
  a leitura *"contém"* grupos e concentração; aqui ela os contém **por derivação**, na mesma função
  para todo leitor.

**Substituição por apagar e inserir, e não por `upsert`**: a spec diz que a leitura *"é
substituída, nunca editada"* (entidade-chave). Linha nova tem id novo, e o aviso de leitura
pronta leva esse id.

**Alternativa medida e recusada pela spec**: calcular na hora da leitura, sem tabela. A consulta
leva 12 ms no dado medido, e funcionaria. A spec (FR-010, FR-011, FR-013, decisão de R6/R7)
escolheu o cálculo em segundo plano, com proveniência gravada e nenhuma ação de conta comum
gerando trabalho. O plano segue a spec, e registra que o motivo é de segurança e proveniência, e
não de custo.

---

## R8 — O gatilho: o fim da coleta de revisões

**Onde a coleta de revisões termina**: as avaliações são gravadas dentro da etapa `:mudancas` do
`TheBand.Jobs.SyncGithubEo`, em `GithubChangeRequests.collect/1`
(`lib/the_band/ingestion/github_change_requests.ex:306-324`, chamada por
`lib/the_band/jobs/sync_github_eo.ex:362-371`). A etapa é concluída e registrada em
`executar_etapa/3` (`sync_github_eo.ex:275-279`).

**Decisão**: enfileirar o cálculo em `coletar_mudancas/1` (`sync_github_eo.ex:362`), logo depois
de `GithubChangeRequests.collect/1` devolver `{:ok, _}`. Para isso, o `ctx` passado a
`coletar_trabalho/1` (`sync_github_eo.ex:173`) ganha `organization_id`, que `collect/1` já devolve
(`sync_github_eo.ex:160-161`) e hoje não segue adiante.

**Razão**: o fim da **sincronização** pode estar horas depois do fim da coleta de revisões. As
etapas de arquivos (`:arquivos`, fatia de 500 por passada, `sync_github_eo.ex:373-381`) e de
verificações andam no balde REST e hibernam pela janela de cota (`sync_github_eo.ex:179-183`).
Esperar o `completed` atrasaria a rede por uma etapa que não muda nada nela.

**Alternativas**:

- *no fim do sync* (`sync_github_eo.ex:185-195`): recusada pelo atraso acima;
- *Oban Cron diário*: desacopla a coleta da rede, e recalcula organização sem coleta nova. Pior:
  atraso de até um dia, e trabalho sem dado novo;
- *assinante do PubSub do sync*: evento em processo se perde se o nó reinicia, e o cálculo
  deixaria de ser trabalho persistido.

**O que piora**: o job de coleta passa a conhecer `TheBand.ReviewNetwork` (uma linha, e um
`alias`). É acoplamento de coleta para leitura, e fica **escrito** ao lado da linha.

A recoleta avulsa (`mix the_band.recollect_changes`) **não** dispara; a próxima sincronização
dispara. Fica declarado no contrato do job.

---

## R9 — O job: fila, unicidade, conferências e cancelamento

**Decisão**: `TheBand.Jobs.ComputeReviewNetwork`, fila **`:transformation`**, `max_attempts: 3`.

- **fila existente**: `config/config.exs:114` já configura `transformation: 5`. Fila declarada e
  não configurada fica `available` para sempre (`lib/the_band/jobs/recompute_promotions.ex:5-9`).
  É transformação do que já foi coletado, a mesma razão do `RecomputePromotions`;
- **sem fila própria**: a R6 da segurança pedia fila própria **se** a tela pudesse pedir
  recálculo. A decisão de 2026-10-03 tirou esse caminho: o único produtor é a sincronização, que
  anda no ritmo do agendador (intervalo mínimo de 15 minutos, `config/config.exs:131-134`);
- **unicidade**: `unique: [fields: [:args, :worker], keys: [:tenant_id, :organization_id],
  states: [:available, :scheduled, :retryable], period: :infinity]` (Oban 2.23.1, `mix.lock`).
  **`:executing` fica de fora de propósito**: se uma coleta termina enquanto o cálculo anterior
  roda, o novo entra, e a leitura não perde o dado que acabou de chegar. Período infinito, e não
  os 30 s de `recompute_promotions.ex:38`, que a R6 apontou;
- **argumentos**: `tenant_id` e `organization_id`. **A janela não é argumento**: o job calcula as
  três janelas da base de uma vez (FR-013). Nenhum valor de janela vem de fora;
- **conferências antes de ler qualquer dado (FR-010)**, nesta ordem, cada falha um `{:cancel,
  motivo}` **sem gravar leitura**:
  1. `Tenants.fetch/1` → `{:cancel, :tenant_not_found}`;
  2. `Tenants.ensure_active/1` (`lib/the_band/tenants.ex:94-95`) → `{:cancel, :tenant_inactive}`;
  3. `EO.fetch_organization(tenant, organization_id)` → `{:cancel, :organization_not_found}`. A
     organização de **outro** tenant cai aqui, porque a busca é por id **e** tenant;
  4. as janelas e parâmetros da base são lidos e validados (inteiros positivos, k crescente). Base
     inconsistente **não** é cancelamento: é falha de carga, e levanta (princípio IV);
- **o resultado é relator** (L69, R14 da segurança): `ReviewNetwork.compute/3` devolve
  `{:ok, %{leituras: [%{id, janela_em_dias, revisoes, excluidas: %{...}}]}}`, testável sem log;
- **log**: organização, janela, contagens por motivo, duração. **Nunca** par, nome, login, nem
  id de pessoa (FR-021);
- **aviso**: `{:review_network_ready, organization_id, [reading_id]}` no tópico
  `"review_network:" <> tenant_id`. **Só ids de leitura** (R3 da segurança, item 2). O padrão de
  `recompute_promotions.ex:57`, que transmite o resultado, **não** é copiado.

---

## R10 — Índice e volume

**Decisão**: índice novo `collected_artifact_evaluations (tenant_id, external_submitted_at)`.

**As três perguntas**:

1. *Problema*: a consulta recorta por tenant e por data de envio. Sem o índice, ela percorre
   todas as avaliações do tenant pelo prefixo do índice único `(tenant_id, external_id)`
   (`20260819040000_create_artifact_evaluations.exs:75`);
2. *Existe agora?* **Em parte, e cresce**: medido em desenvolvimento, **49%** das avaliações já
   estão fora da janela de 180 dias (2 413 de 4 954), e a tabela só cresce (avaliação é marcada,
   nunca apagada, `:68-70`). O cálculo roda a cada coleta. Hoje a varredura custa **1,4 ms**; o
   problema é a tendência, e não o número de hoje;
3. *O que piora*: um índice a mais mantido a cada gravação de avaliação (centenas por coleta), e
   uma migração sobre tabela em uso. Pequena (5 mil linhas), sem `concurrently`.

**Medida de produção pendente**: a R6 da segurança pede medir o cálculo de 180 dias **na maior
organização de produção** antes de declarar que cabe. Esta pesquisa mediu desenvolvimento
(**11,8 ms** para a consulta inteira, 40 nós, 233 arestas). O dado de desenvolvimento é cópia de
uma organização real, mas **não** é produção, e a tarefa de medição em produção fica no
`tasks.md`, com o número escrito antes do merge da US1.

---

## R11 — A base de conhecimento: forma de cada artefato

**O conteúdo dos YAMLs não está aqui.** Ele é escrito em paralelo em
[`proposta-base/`](proposta-base/) (necessidade de informação, medidas, mapeamento, regra com k,
amostra e grupo mínimo, perguntas de competência), e **aquele diretório é a fonte**. Este item
decide só a **forma** que o código lê e as restrições que o plano impõe a ela. Onde a proposta
divergir desta forma (por exemplo, a aresta declarada como `mapping:` e não como regra), a
divergência é resolvida na revisão semântica, antes do código, e o vencedor fica registrado aqui.

**Decisão de forma**:

| o quê | forma | arquivo |
|---|---|---|
| necessidade de informação | `information_need:` (schema `information-need.schema.yaml`) | `information_needs/review_concentration.yaml` |
| as quatro medidas (FR-007) | `measurement:` (schema `measurement.schema.yaml`) | `measurements/review_network_*.yaml` |
| o que vira aresta (FR-005) | `derivation_rule:` com `semantics`, `limitations` e `version` | `rules/review_network_edge.yaml` |
| k, amostra mínima, grupo mínimo, janelas (FR-008, FR-013) | `derivation_rule:` | `rules/review_network_thresholds.yaml` |

**Por que a aresta é regra, e não `mapping:`**: o schema de mapeamento
(`priv/knowledge_base/schemas/mapping.schema.yaml`) descreve **fonte externa → conceito
ontológico**, e exige `identity.external_id_path`. A aresta não tem identidade externa, e o alvo
não é conceito de ontologia: é estrutura derivada de duas participações já mapeadas
(`qapo.stakeholder_performed_artifact_evaluation` e `cmpo.stakeholder_submitted_change_request`).
Preencher `identity` para passar no schema seria mentir para o validador. A regra carrega o que a
FR-005 pede (equivalência `derived`, justificativa, limitações), no vocabulário do mapeamento, e a
proveniência que `yaml_validator.ex:476-482` exige.

**Lacuna declarada**: `derivation_rule` **não tem schema** (`schema_check.ex:29-36` só valida
ontologia, módulo, mapeamento, necessidade, medida e pergunta de competência). A forma das duas
regras é garantida por **teste** (`mix knowledge.test` e ExUnit) que lê as chaves obrigatórias, e
pelo módulo `ReviewNetwork.Parameters`, que levanta na carga se faltar alguma (precedente:
`quality.ex:305-310`).

**Por que duas regras**: mudam por razões diferentes (princípio X). A da aresta muda quando o
**significado** muda (um estado novo passa a contar), e invalida leituras antigas. A dos limiares
muda quando a **apresentação** muda (amostra mínima de 10 para 15). Precedente:
`rules/team_dashboard_thresholds.yaml` separado de `rules/change_request_ceremony.yaml`.

**Versão das medidas (FR-011)**: `measurement.schema.yaml` **não tem** `version`. Decisão:
acrescentar `version` **opcional** (inteiro ≥ 1) ao schema. As quatro medidas novas declaram
`version: 1`; as existentes não mudam. A leitura grava as versões das duas regras e das quatro
medidas.

- *Problema*: a FR-011 pede a versão das medidas na proveniência, e não há onde lê-la;
- *Existe agora?* Sim, é requisito desta feature;
- *O que piora*: nenhum gate confere que a versão sobe quando a fórmula muda. É disciplina de
  revisão, e o revisor semântico é quem a cobra.

Alternativa recusada: resumo (`sha256`) do conteúdo carregado. Automático, mas opaco: quem lê a
proveniência não sabe se `3f9a…` é anterior ou posterior a `b21c…`.

**Revisão semântica obrigatória** antes do código (§8): a regra da aresta, a unidade (R2) e a
mudança de schema.

---

## R12 — O que a tela de alcance parcial mostra das exclusões

**Decisão, derivada das decisões de 2026-10-03 sobre R1 e R2**: as contagens de exclusão (bot,
não ligada, auto-revisão) aparecem **só para quem alcança todas as pessoas** (`:todas`). Para
alcance parcial, a tela diz a regra das exclusões em palavras, sem número.

**Razão**: as três contagens são sobre a organização inteira. A de **não ligada** conta revisões
de contas que, por definição, ninguém alcança (sem `person_id`). A de **auto-revisão** contaria
pessoas fora do alcance, e calculá-la só sobre as alcançadas exigiria guardar auto-revisão por
pessoa, que a FR-004 proíbe mostrar e a R5 chama de acusação. A de **bot** conta atividade nas
solicitações de pessoas fora do alcance. As três são, portanto, *"contagem de revisões que envolvem
quem você não alcança"*, que a decisão sobre R2 recusa.

**Confirmação**: no protótipo. Se a pessoa mantenedora quiser a contagem de bot visível a todos,
ela é a única das três que não fala de pessoa, e a mudança é local à função de recorte.

---

## R13 — `Quality.by_reviewer/2` sai nesta feature

**Decisão**: remover `Quality.by_reviewer/2` (`quality.ex:429-455`) e os testes dela
(`test/the_band/quality_test.exs:130`, `:151`, `:170`, `:213`).

**Razão** (R12 da segurança): é um ranking de revisores por login, ordenado por contagem
decrescente, **sem alcance**, e **sem nenhum chamador** em `lib/`. É o atalho óbvio para quem
implementar a US2, e o contrato desta feature proíbe exatamente o que ele faz (FR-018a, FR-015).
Está na superfície que a feature toca, então não é refatoração sem relação (§17). O isolamento
entre tenants que o teste de `:213` provava passa a ser provado pelos cenários A1 e A2, sobre a
consulta nova.

**Em commit próprio**, para que a revisão veja a remoção separada da feature.

---

## R14 — Ausências: o que a leitura devolve quando não há o que mostrar

| situação | o que a função devolve | o que a tela diz (inglês, decidido no protótipo) |
|---|---|---|
| nenhuma leitura gravada para a organização e a janela | `{:ausente, :nao_calculada}` | a leitura ainda não foi calculada, e quando será (ao fim da próxima coleta) |
| leitura existe, total de revisões do recorte é zero | concentração `{:ausente, :sem_revisao_na_janela}` | não houve revisão na janela, em palavras, nunca 0% (US1, cenário 3) |
| total abaixo da amostra mínima | concentração com `amostra: {:pequena, minimo}` | os números aparecem, com o aviso (edge case) |
| pessoa que não revisou | `feitas: {:ausente, :nao_revisou}` | em palavras, nunca 0 |
| pessoa sem solicitação revisada | `recebidas: {:ausente, :sem_solicitacao_revisada}` | em palavras (US2, cenário 2) |
| organização de outro tenant, ou inexistente | `{:error, :not_found}` | *not found*, nunca *permission denied* (§11.1) |
| janela fora da lista | `{:error, :janela_invalida}` | volta à janela padrão |

**Falha do cálculo**: não se grava estado de falha. Se o cálculo falha depois de um sucesso, a tela
mostra a leitura vigente **com o instante dela**, que é o que ela é. Se nunca houve sucesso, é
`:nao_calculada`. A tela nunca mostra a leitura de outra janela no lugar desta (edge case),
porque a busca é por janela.

**Alternativa recusada**: ler `oban_jobs` para dizer *"o último cálculo falhou"*. Acopla a leitura
de domínio à tabela de uma dependência, e o Pruner apaga o job em 7 dias
(`config/config.exs:116`): a frase dependeria da idade da falha.

---

## R15 — A tela, e o protótipo antes dela

**Decisão de rota (proposta, o protótipo confirma)**: `live "/organizations/:id/review-network"`,
na `live_session :autenticado` (`lib/the_band_web/router.ex:298`, `on_mount :current_scope`).

- **qualquer conta autenticada do tenant** abre; o recorte é a função de domínio (FR-015), e não
  um `require_*`. Fechar a página para quem não administra faria o colega perder a leitura da
  própria equipe, que é o argumento de `verification_live/people.ex:83-85`;
- área do menu: `:organization`, pelo prefixo `"/organizations"` já declarado em
  `lib/the_band_web/components/layouts.ex:187`. Nenhuma linha nova em `@nav_areas`;
- a janela vem em `?window=30|90|180`, validada **no domínio** (`ReviewNetwork.read/4`), nunca
  convertida em átomo (A8);
- organização de outro tenant: *"not found"* com o mesmo texto da inexistente (§11.1).

**O protótipo do Design precede o código da tela** (FR-017, memória *Tela exatamente a aprovada*):
o agente `design` publica o protótipo navegável com dado real agregado, guarda-o em
[`prototipo/`](prototipo/) com o prompt e as decisões (escrito em paralelo a este plano, por
outro agente), e a pessoa mantenedora aprova. **O código da tela espera essa aprovação.**
As tarefas da tela ficam **bloqueadas** por essa aprovação no `tasks.md`.

**Sem desenho de grafo nesta fatia** (R13 da segurança): sem biblioteca JS. Se o protótipo pedir
desenho, é SVG gerado no servidor em HEEx, sem `raw/1`, e a decisão volta ao plano.
