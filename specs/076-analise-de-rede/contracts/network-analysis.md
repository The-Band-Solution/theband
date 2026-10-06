# Contrato — `TheBand.NetworkAnalysis`

FR-001 a FR-055. Desenho em [data-model.md](../data-model.md); decisões em
[research.md](../research.md); achados em [seguranca.md](../seguranca.md) (R1–R15).

`lib/the_band/network_analysis.ex` contém **só `defdelegate`** (§7.1). Ninguém fora do módulo toca
`NetworkAnalysis.Schemas.Reading`, a tabela `network_analysis_readings`, nem `Repo` em nome dela.

**Depende de**: `TheBand.Tenants` (tenant, alcance, contas da organização), `TheBand.Ontology.SEON.EO`
(organização, tipos de conta, pessoas, nomes), `TheBand.Ontology.SEON.CMPO` (repositórios da
organização, coleta mais nova), `TheBand.WorkItems` (pares de designação), `TheBand.ReviewNetwork`
(arestas da revisão), `TheBand.Ontology.KnowledgeBase`. Sempre pela API pública
([fronteiras.md](fronteiras.md)).

## Os parâmetros entram pela fachada

Como na 073: cada função da fachada lê os parâmetros da base (`NetworkAnalysis.Parameters.fetch!/0`)
e chama a função de mesmo nome com aridade + 1, que os recebe como argumento. Os testes chamam a de
aridade maior com parâmetros montados; nenhum valor de k, janela, semente, teto ou corte está
escrito no código.

```elixir
@spec Parameters.fetch!() :: Parameters.t()
@spec Parameters.from_rules!(%{String.t() => map()}, %{String.t() => map()}) :: Parameters.t()
```

**Emenda de 2026-10-04 (T008)**: a leitura usa **quatro** regras, e não três. As janelas são as
de `review.network.parameters` (`network.analysis.parameters.networks.values.windows_from`).
`from_rules!/2` recebe por isso um mapa `id da regra => artefato` e as medidas de
`network.structure` (para as versões da proveniência), no lugar de `from_rules!/3`. A função
confere, sem usar para decidir, o que o código implementa: a ordem das exclusões de
`assignment.network.edge`, o gerador `exsss`, o modelo `gnm` e `random_weights:
shuffled_real_multiset`. Com valor diferente, levanta. A rede padrão é a primeira da lista
`networks.values.allowed`.

**Emenda de 2026-10-04 (O1 da revisão semântica do PR #1383)**, feita no mesmo commit da
implementação: uma **quinta** regra, `review.network.edge`, só pela versão. Ela entra em
`knowledge_versions`, e por isso na impressão digital: as arestas de revisão são as que a 073
gravou por essa regra, e sem a versão uma leitura da versão 1 e uma da 2 com as mesmas arestas
dariam a mesma impressão. Sem a regra, `from_rules!/2` levanta dizendo o id.

---

## `options/0`

```elixir
@spec options() :: %{
        networks: %{allowed: [String.t()], default: String.t()},   # ["review", "assignment"], "review"
        windows: %{allowed: [pos_integer()], default: pos_integer()}, # [30, 90, 180], 90
        views: %{allowed: [String.t()], default: String.t()},       # ["weighted", "communities"]
        eigenvector: %{max_iterations: pos_integer(), tolerance_per_node: float()} # 1000, 1.0e-6
      }
```

As listas fechadas para a tela desenhar os seletores. A tela nunca as escreve.

**Emenda (T053, 2026-10-06)**: `eigenvector` entra para a frase do estado sem valor dizer o número
de rodadas e a tolerância (PROMPT §3, 3.4.4). Antes a tela dizia só "after the rounds the base
allows", e ler `Parameters` da tela furaria a fronteira.

## `selection/1`

```elixir
@spec selection(%{optional(String.t()) => term()}) ::
        %{network: String.t(), window: pos_integer(), view: String.t()}
```

Normaliza os parâmetros do endereço (FR-002; R13 da segurança). Cada um é comparado como **texto
exato** com a lista (`"90"` sim; `"090"`, `"90; drop"`, `"36500"`, 10 000 caracteres, `nil` não);
fora da lista, o padrão, **sem dizer que era inválido**. Nunca `String.to_atom/1` nem
`String.to_existing_atom/1`; nenhum átomo criado (A12).

## `read/4`

```elixir
@spec read(Tenant.t(), User.t(), organization_id :: term(), selection()) ::
        {:ok, view()}
        | {:ausente, :not_computed | :stale | :review_reading_outdated}
        | {:error, :not_found}
```

**A única porta da análise para quem consulta** (FR-013). Ordem:

1. a organização por id **e** tenant (`EO.fetch_organization/2`, que faz o cast de UUID): outro
   tenant, inexistente e id malformado dão o mesmo `{:error, :not_found}`;
2. a leitura vigente de `(tenant, organização, rede, janela)`; sem ela, `{:ausente, :not_computed}`;
   com `computed_at` mais velho que a maior janela, `{:ausente, :stale}` (R18) — nunca a de outra
   rede ou janela no lugar (edge case *"Leitura de uma rede pronta e da outra não"*). Na rede
   `review`, a leitura feita de uma 073 que não sabe das contas declaradas vigentes é
   `{:ausente, :review_reading_outdated}` (ver a emenda E4 em `compute/3`);
3. `Tenants.pessoas_alcancadas(tenant, user)` e `Tenants.pessoas_alcancadas(tenant, user, origem:
   :concedida)`, **nesta chamada**; nunca recebidos de fora nem guardados (A22);
4. `View.build/5` (puro, [algoritmos.md](algoritmos.md) §View): o recorte da FR-015 com k da base;
5. com alcance parcial, o layout recalculado sobre o grafo da visão (FR-022);
6. os nomes das pessoas que sobraram (`EO.people_names/2`); pessoa sem nome sai da visão (073, R3
   item 3);
7. papel e percentil derivados **aqui**, pela regra vigente, só para quem a visão permite (R17,
   DS1);
8. a coleta mais nova que a leitura (073, Q3);
9. o número de contas declaradas da organização (R14), sem dizer quais.

Número de consultas fixo, independente do tamanho da rede; guardado por teste de teto.

**Emenda de 2026-10-04 (T017)**, feita no mesmo commit da implementação:

- **os nomes vêm antes do recorte**, numa consulta só para todos os ids da leitura (passo 6
  antes do 3). Sem isso, não há como saber quem saiu de EO depois do cálculo. Quem não tem nome
  sai dos dois alcances. Com alcance parcial, vira pessoa de fora. Com `:todas`, vira o agregado
  `community: :gone` (*"no longer in the platform"*), sob a mesma regra k. `View.build/5` recebe
  esse conjunto em `params.gone`;
- **a visão desta fatia** traz `reach`, `sees_others_positions?`, `people`, `graph` (nós, arestas
  e componentes), `organization_id`, `network`, `window_days`, `window_start`, `window_end`,
  `computed_at` e `newer_collection`. `counts`, `communities`, `hubs`, `distance`, `small_world`,
  `positions`, `provenance` e o layout da visão parcial entram com as tarefas que os calculam
  (T029, T031–T034, T035–T046). `declared_organization_accounts` entra com a T025, que cria as
  declarações. Até lá a chave **não existe**: um zero afirmaria que nenhuma conta foi declarada;
- `selection/1` e `options/0` têm a forma desta seção. A rede padrão é a primeira de
  `networks.values.allowed` (`review`), e as vistas (`weighted`, `communities`) são vocabulário da
  tela, sem valor da base.

**Emenda de 2026-10-04 (T029)**, feita no mesmo commit da implementação:

- a visão ganha `counts`, `declared_organization_accounts` e uma `provenance` parcial
  (`knowledge_versions`, `account_type_unknown`, `source_computed_at`; o resto entra com as
  tarefas que o calculam);
- `counts.items` é o número de issues abertas na janela (designação) ou de revisões contáveis
  (revisão), e é `{:ausente, :none_in_window}` quando zero: uma janela pode ter issues e nenhuma
  aresta, e por isso o motivo não é `:no_edge_in_window`;
- `counts.exclusions` é `{:ausente, :none_in_window}` quando a janela não tem par nem issue; com
  algum, a contagem de um motivo que não ocorreu é zero de verdade (073, #1308). Sem `pairs` nem
  `issues` no mapa: esses estão em `items`. Com alcance parcial, `{:recortado, :regra}`;
- `counts.people_without_edges` também é `{:recortado, :regra}` com alcance parcial: é contagem
  sobre a organização inteira;
- `declared_organization_accounts` é o número de pessoas **desta organização** com declaração
  vigente, calculado na leitura (`EO.organization_person_ids/2` ∩
  `Tenants.organization_account_ids/1`): duas consultas fixas, e o número não envelhece com a
  leitura;
- `provenance.account_type_unknown` só com alcance total.

**Emenda de 2026-10-04 (T031, T033)**, feita no mesmo commit da implementação:

- o nó de pessoa da visão ganha `out_weight`, `in_weight` (o cartão 3.2.5 diz quantas revisões ou
  issues, e não só quantas pessoas), `betweenness` (`{:ok, v}`, `{:ausente, :network_too_small}`
  ou, em leitura gravada antes da T030, `{:ausente, :not_computed}`), e, do `Reader`, `band` (o
  código da faixa de `betweenness_color_bands`, `nil` quando ausente) e `labelled?`;
- `labelled?` marca as `layout.labelled_nodes` pessoas de maior grau **da visão**, empate pelo id.
  A visão só tem alcançados por nome, e por isso os nomes escritos saem só deles (O1 da revisão
  semântica 3);
- `graph` ganha `layout` e `bands` (`[%{code, label}]`, a legenda). `layout` são as posições
  gravadas só quando a visão é a rede inteira (alcance total, nenhum agregado); com alcance
  parcial, ou com o agregado de quem saiu de EO, `Algorithms.Layout` sobre o grafo da visão, com a
  mesma semente (passo 5). Acima do teto, `{:ausente, :network_too_large_for_platform}`;
- o agregado do resto, quando nenhuma pessoa de fora tem comunidade (leituras antes da T035), tem
  `community: nil`, e não `:other`: *"outras comunidades"* afirmaria comunidades que não foram
  calculadas.

### `view()`

```elixir
%{
  organization_id: Ecto.UUID.t(),
  network: String.t(), window_days: pos_integer(),
  window_start: DateTime.t(), window_end: DateTime.t(),
  computed_at: DateTime.t(),
  newer_collection: :nenhuma | {:em, DateTime.t()},
  reach: :total | :parcial | :nenhum,          # :nenhum = DS5 (vazio ou só a própria pessoa)
  sees_others_positions?: boolean(),            # DS1: escopo concedido ou administração
  declared_organization_accounts: non_neg_integer(),

  # As contagens da rede (US2); com reach != :total, as exclusões são {:recortado, :regra}
  counts: %{
    items: {:ok, pos_integer()} | {:ausente, :no_edge_in_window},          # issues ou revisões
    edges: {:ok, pos_integer()} | {:ausente, :no_edge_in_window},
    exclusions: {:ok, %{atom() => non_neg_integer()}} | {:ausente, :no_edge_in_window} | {:recortado, :regra},
    people: {:ok, pos_integer()} | {:suprimido, :fewer_than_k_outside},
    people_without_edges: {:ok, non_neg_integer()} | {:ausente, :no_edge_in_window} | {:recortado, :regra}
  },

  # O grafo da visão (US3, US4); {:recortado, :no_reach} com DS5
  graph:
    {:ok, %{
      nodes: [node_view()],      # alcançados por nome + agregados; ordenados por id de visão
      edges: [%{from: node_id(), to: node_id(), weight: pos_integer()}],
      layout: {:ok, %{node_id() => {float(), float()}}} | {:ausente, :network_too_large_for_platform},
      components: {:ok, [pos_integer()]} | {:suprimido, :fewer_than_k_outside}
    }} | {:recortado, :no_reach} | {:ausente, :no_edge_in_window},

  communities: {:ok, %{modularity: measure(), q_rand: measure(), count: pos_integer(),
                       blocks: [community_block()]}} | {:recortado, :no_reach} | {:ausente, atom()},

  hubs: {:ok, %{degree: [hub()], betweenness: [hub()], closeness: [hub()],
                eigenvector: [%{component: pos_integer(), rows: [hub()]}]}}
        | {:recortado, :no_reach | :positions_not_granted} | {:ausente, atom()},

  distance: %{average: measure(), reachable_share: float() | nil, diameter: measure(),
              efficiency: measure(), random: random_measures()},
  small_world: %{clustering: measure(), excluded_degree_below_two: non_neg_integer() | nil,
                 random: random_measures(), sigma: measure(),
                 criterion: :meets | :does_not_meet | nil},

  positions: {:ok, [%{person_id: Ecto.UUID.t(), name: String.t(), community: pos_integer(),
                      degree: pos_integer(), role: role()}]}       # por NOME (FR-034)
             | {:recortado, :no_reach | :positions_not_granted},

  provenance: %{knowledge_versions: map(), seed: integer(), generator: String.t(),
                random_graphs: pos_integer(), layout_seed: integer(), source_computed_at: DateTime.t() | nil}
}

@type node_id :: Ecto.UUID.t() | String.t()     # "outside-1", "outside-2" para agregado: opaco, por renderização
@type node_view ::
        %{kind: :person, id: Ecto.UUID.t(), name: String.t(), degree: pos_integer(),
          out_people: non_neg_integer(), in_people: non_neg_integer(),
          betweenness: measure(), community: pos_integer(), links_outside_reach?: boolean()}
        | %{kind: :outside, id: String.t(), community: pos_integer() | :other | :gone | nil, size: pos_integer()}
@type measure :: {:ok, number()} | {:ausente, atom()} | {:suprimido, atom()}
@type hub :: %{person_id: Ecto.UUID.t(), name: String.t(), value: measure(), tied?: boolean(),
               detail: map()}     # closeness: %{distance_mean, reaches}; degree: %{out_people, in_people}
@type community_block :: %{index: pos_integer(), size: {:ok, pos_integer()} | {:suprimido, atom()},
                           internal_edges: {:ok, non_neg_integer()} | {:suprimido, atom()},
                           core: [%{person_id: Ecto.UUID.t(), name: String.t(), internal_degree: pos_integer(), tied?: boolean()}]  # tied?: emenda T053
                                 | {:recortado, :positions_not_granted},
                           members: [%{person_id: Ecto.UUID.t(), name: String.t()}],
                           outside: {:agregado, pos_integer()} | :sem_agregado}
@type role :: {:ok, %{code: String.t(), label: String.t(), sentence: String.t(),
                       degree_percentile: float(), betweenness_percentile: float(), cut: String.t()}}
              | {:ausente, :network_too_small} | {:recortado, :positions_not_granted}
```

## `profile/5`

```elixir
@spec profile(Tenant.t(), User.t(), organization_id :: term(), person_id :: term(), selection()) ::
        {:ok, profile()} | {:error, :not_found}
```

O perfil de uma pessoa na rede escolhida **e** na outra (protótipo 3.6.4). Abre **se, e só se**, a
pessoa está em `pessoas_alcancadas/2` desta chamada **ou** é a de quem consulta. `pode_ver/3` não é
chamado (FR-013, A10). Pessoa de outro tenant, inexistente, fora do alcance e id que não é UUID dão o
**mesmo** `{:error, :not_found}` (FR-014).

```elixir
%{
  person_id: Ecto.UUID.t(), name: String.t(),
  networks: %{
    String.t() => {:ok, %{
        out_people: non_neg_integer(), in_people: non_neg_integer(),       # rótulos de network.degree.count
        degree: measure(), betweenness: measure(), betweenness_percentile: measure(),
        degree_percentile: measure(), role: role(), community: pos_integer(),
        to: [%{person_id: Ecto.UUID.t(), name: String.t(), weight: pos_integer()}],   # por peso
        from: [%{person_id: Ecto.UUID.t(), name: String.t(), weight: pos_integer()}],
        to_outside_reach: {:agregado, pos_integer()} | :nenhum,   # "N issues with people outside your reach"
        from_outside_reach: {:agregado, pos_integer()} | :nenhum,
        to_total: pos_integer(), from_total: pos_integer(),       # DS3 (a): o total verdadeiro
        computed_at: DateTime.t(), window_start: DateTime.t(),    # emenda T053: a linha da
        window_end: DateTime.t(), window_days: pos_integer()      # leitura de cada rede (3.0.5)
      }}
      | {:ausente, :no_edges_in_window}       # só para pessoa alcançada (FR-014)
      | {:ausente, :not_computed | :stale}
  }
}
```

O papel e os percentis de **outra** pessoa seguem a DS1 (`{:recortado, :positions_not_granted}`); o
da própria pessoa aparece sempre (FR-047).

## `compute/3`

```elixir
@spec compute(Tenant.t(), organization :: map(), now :: DateTime.t()) ::
        {:ok, relator()} | {:error, {:reading_rejected, [atom()]}}
```

**Só o job chama.** Para cada rede e janela: monta as arestas (revisão: `ReviewNetwork.current_edges/2`;
designação: `WorkItems.assignment_pairs/3` + `AssignmentClassification`), calcula a impressão
digital, e, se diferente da vigente, calcula as medidas ([algoritmos.md](algoritmos.md)) e substitui
a leitura **da mesma rede e janela** numa transação. `Repo.insert/1`, nunca `insert!`; erro de
constraint vira `{:error, {:reading_rejected, campos}}` só com nomes de campo (A18). `now` vem de
quem chama. Depois do commit, avisa por PubSub só com ids (`Notices`, como a 073).

```elixir
@type relator :: %{
        readings: [%{network: String.t(), window_days: pos_integer(),
                     outcome: :computed | :unchanged | {:ausente, atom()},
                     edges: non_neg_integer(), people: non_neg_integer(),
                     excluded: %{String.t() => non_neg_integer()},
                     absent: [atom()],          # [:sigma, :q_rand, :efficiency_rand, :layout] por teto
                     duration_ms: non_neg_integer()}]
      }
```

O relator **não** carrega `person_id`, nome, login, papel nem medida por pessoa: o log sai dele (A19).

**Emenda de 2026-10-04 (T014)**, feita no mesmo commit da implementação:

- **as arestas entram por uma função de entrada.** `compute/3` lê os parâmetros e monta
  `NetworkAnalysis.Inputs.for_organization/4`; `compute/5` (interna, para os testes) recebe essa
  função, de forma `(rede, janela, início) -> {:ok, entrada} | {:ausente, motivo}`, e devolve
  `{:ok, relator, ids_gravados}`. Até a T028 ligar as duas fontes, as duas redes dão
  `{:ausente, :source_not_connected}`: nada é gravado, e o relator diz por quê. Lista vazia faria
  a leitura afirmar que não houve aresta;
- **o `outcome` ganha `{:ausente, motivo}`**, para a rede sem fonte. As exclusões são chaveadas
  pelos códigos da base, em texto;
- **a impressão digital** cobre as arestas canônicas, as exclusões, as pessoas sem aresta e as
  versões da base. `source_computed_at` não entra: com as mesmas arestas, a 073 recalculada não
  muda a leitura;
- **o log das consultas**: em `:debug`, `TheBand.Repo.LogDaConsulta` escrevia os parâmetros do
  INSERT da leitura, isto é, cada `person_id` da rede (A19, encontrado por este teste). As tabelas
  `network_analysis_readings` e `review_network_readings` passam a ter os parâmetros redigidos,
  como as que têm campo cifrado.

**Emenda de 2026-10-04 (T028)**, feita no mesmo commit da implementação:

- `Inputs.for_organization/4` faz todas as buscas **uma vez**, ao montar a função (as contas
  declaradas, as pessoas da organização, as leituras da 073, os pares de designação da maior janela
  e os tipos de EO), e a função só filtra por janela em memória: seis chamadas, as mesmas consultas;
- **revisão**: as arestas da leitura da 073 da mesma janela, `source_computed_at` = o instante
  dela, e as exclusões com os códigos da regra (`self_review`, `bot_or_app`,
  `organization_account` — nulo na leitura da versão 1 —, `unlinked_person`) e `pairs`. Sem
  leitura da 073 na janela, `{:ausente, :not_computed}`;
- **designação**: `AssignmentClassification.summarize/2` por janela; `provenance` leva
  `account_type_unknown`;
- `people_without_edges` desconta as contas declaradas da organização: elas não são pessoas nesta
  rede, e contá-las como *"pessoa sem aresta"* as poria de volta por outra porta. Nulo quando a
  janela não tem aresta;
- os tipos `exclusions` e `excluded` do relator aceitam `nil` (o motivo não avaliado).

**Emenda de 2026-10-04 (E4 da revisão semântica do PR #1383)**, feita no mesmo commit da
implementação. A conta declarada da organização sai das **duas** redes (A7), mas a de designação
usa as declarações de agora e a de revisão usa as arestas que a 073 gravou, e nada recalcula a 073
quando se declara ou revoga. Opção (b) da revisão:

- `Inputs.for_organization/4` devolve `{:ausente, :review_reading_outdated}` para a revisão
  quando a leitura da 073 foi gravada pela versão 1 (`organization_account` nulo) ou foi calculada
  **até** a última declaração ou revogação do tenant (`Tenants.organization_accounts_changed_at/1`).
  Instante igual conta como desatualizado: os dois são gravados em segundos. Nada é gravado, como
  no `:not_computed`;
- o mesmo predicado, `Inputs.review_reading_current?/3`, é aplicado por `read/4` à leitura da
  análise já gravada (pela contagem `organization_account` e por `source_computed_at`): a leitura
  feita antes da declaração não é mostrada, e a tela diz que a rede de revisão é recalculada na
  sincronização seguinte (`sync_github_eo` → `ComputeReviewNetwork` → `ComputeNetworkAnalysis`);
- a rede de designação não muda: ela não depende da 073.

**Emenda de 2026-10-05 (T035, T036)**, feita no mesmo commit da implementação:

- a leitura grava `nodes[].community` e `nodes[].internal_degree`, `communities` (`index`,
  `members`, `internal_edges`, `outside_edges`), `measures.modularity` (`value` e `communities`) e
  `measures.random` (`graphs` e `modularity` com `graphs_defined`). Sem aresta, `modularity` e
  `random` são `{"absent": "no_edge_in_window"}`; acima do teto, `random` é
  `network_too_large_for_platform`;
- **a impressão digital leva também a lista do que o código calcula** (`@calculo` em
  `Commands`). Sem ela, a leitura gravada antes de uma medida existir teria a mesma impressão da
  nova — as arestas e a base não mudaram — e nunca seria recalculada: ficaria para sempre sem a
  medida. A lista cresce com cada tarefa que acrescenta medida à leitura.

**Emenda de 2026-10-05 (T037)**, feita no mesmo commit da implementação: `communities` da
visão é `{:ok, %{count, modularity, q_rand, blocks, thresholds}} | {:recortado, :no_reach} |
{:ausente, :no_edge_in_window | :not_computed}`:

- `count` é `{:ok, n}`, ou `{:suprimido, :fewer_than_k_outside}` quando as comunidades sem
  ninguém alcançado somam entre 1 e k − 1 pessoas (regra 4: o número revelaria quantas);
- `modularity` é medida; `q_rand` é `{:ok, %{value, graphs_defined}}` ou ausente
  (`network_too_large_for_platform`, `no_edge_in_window`, `not_computed`);
- `thresholds` são as faixas citadas da base (`modularity_reading.values.cited_thresholds`, nova
  chave lida por `Parameters`, `modularity_thresholds`);
- cada bloco tem também `outside_edges` (as ligações para outras comunidades, 3.3.4), e
  `outside` pode ser `:nenhum` (nenhum de fora), `{:agregado, n}` (n ≥ k) ou `:sem_agregado`
  (entre 1 e k − 1). `core` é a lista, possivelmente vazia, ou `{:recortado,
  :positions_not_granted}` quando quem consulta não tem escopo concedido (DS1); com escopo, os
  candidatos são os alcançados cuja posição quem consulta pode ver (`View.ve_posicao_de?/2`);
- `View.build/5` recebe `core_size` nos parâmetros (`community_core_size` da base).

**Emenda de 2026-10-05 (T038–T040)**, feita no mesmo commit da implementação:

- a leitura grava, por nó, `closeness`, `distance_mean` (`value` e `reaches`) e `eigenvector`
  (`value` ou `absent: did_not_converge`); o nó da visão os carrega como `closeness`,
  `distance_mean` (`{:ok, %{mean, reaches}}`) e `eigenvector`;
- os motivos de ausência gravados viram átomo por uma lista fechada em `View` (`@motivos`), e
  nunca a partir do texto (A12);
- `hubs` da visão é `{:ok, %{degree, betweenness, closeness, eigenvector}}`; cada lista é
  `{:ok, [hub]}` ou `{:ausente, motivo}` (nenhuma pessoa com valor: o motivo de quem não tem), e
  `eigenvector` é `[%{component, rows}]`, com `rows` no mesmo formato. Os candidatos são os
  alcançados cuja posição quem consulta pode ver (DS1). `tied?` marca o valor repetido na lista,
  ou o último da lista empatado com quem ficou de fora dela. `View.build/5` recebe `hubs_size`.

**Emenda de 2026-10-05 (T041, T043)**, feita no mesmo commit da implementação: a leitura grava
`measures.average_distance` (com `reachable_share`), `diameter`, `global_efficiency`,
`path_lengths` (`[[passos, pares]]`), `clustering` (com `excluded_degree_below_two`),
`random.clustering`, `random.average_distance` (com `reachable_share`), `random.diameter`,
`random.global_efficiency`, `random.graphs_not_linked` (emenda da T053, 2026-10-06; ausente nas
leituras anteriores) e `sigma` (com `clustering_ratio` e `distance_ratio`), ou a ausência com
o motivo da base. Acima do teto, `random` e `sigma` ausentes com `network_too_large_for_platform`;
sem aresta, com `no_edge_in_window`.

**Emenda de 2026-10-05 (T042, T044)**, feita no mesmo commit da implementação: a visão traz
`distance` (`average`, `reachable_share`, `diameter`, `efficiency`, `lengths` — `{:ok, [{passos,
pares}]}` ou `{:suprimido, :fewer_than_k_outside}` —, e `random` com `graphs`, `not_linked` (T053;
`nil` em leitura anterior), `absent`, `average`,
`reachable_share`, `diameter`, `efficiency`) e `small_world` (`clustering`,
`excluded_degree_below_two`, `random_clustering`, `random_average`, `sigma` com as razões,
`graphs`, `not_linked` (T053), `criterion` — `:meets | :does_not_meet | nil` — e `threshold`, o limiar da base). A
`provenance` ganha `seed`, `generator` e `random_graphs`.

**Emenda de 2026-10-05 (T046, T047)**, feita no mesmo commit da implementação:

- o `Reader` deriva os papéis (`Position.roles/2`) sobre a leitura inteira, a cada `read/4` e
  `profile/5`; o nó de pessoa da visão ganha `role` (`{:ok, role}`, `{:ausente,
  :network_too_small_for_roles}` ou `{:recortado, :positions_not_granted}`), e a visão ganha
  `positions` (`{:ok, [%{person_id, name, community, degree, role}]}` por nome, `{:recortado,
  :no_reach}` ou `{:ausente, motivo}`) e `position_rule` (os limiares, o mínimo e os rótulos da
  base, para a tela dizer a regra sem escrever número);
- `profile/5`: `degree` é `{:ok, n}`; `betweenness_percentile` e `degree_percentile` estão dentro
  de `role` (o papel diz os dois percentis), e não à parte; `community` pode ser `nil` em leitura
  antiga. A pessoa é buscada por `EO.people_names/2` com o tenant, depois do cast do UUID.

## `discard_organization/2`

```elixir
@spec discard_organization(Tenant.t(), organization_id :: Ecto.UUID.t()) :: {:ok, non_neg_integer()}
```

Apaga as leituras da organização. Chamado por `Sources.end_observation/3`, dentro da transação (R18).

## `subscribe/1`

```elixir
@spec subscribe(Tenant.t()) :: :ok
```

Tópico do tenant; a mensagem é `{:network_analysis_ready, organization_id, [reading_id]}`, só ids.

---

## O que a API **não** expõe, e por quê

| não expõe | por quê |
|---|---|
| a leitura inteira, sem recorte | o recorte mora numa função de domínio (FR-013, R3 da 073); expor a leitura convida a tela a filtrar |
| `percentile/2`, `role/2` sobre pessoa avulsa | papel não é atributo da pessoa (R4); só existe dentro de `read/4` e `profile/5`, recortado |
| ranking de todas as pessoas por medida | só as listas de hubs, do tamanho da base; a lista geral é por nome (FR-034) |
| posição na rede inteira de um alcançado (*"2nd of 54"*) | R1 da segurança |
| a posição gravada com alcance parcial | entregaria onde estão as pessoas de fora (R2) |
| qualquer contagem de pessoas de fora abaixo de k | FR-015, regras 2 e 4 |
| `compute/3` para a tela, ou recálculo sob demanda | nenhuma ação de conta gera cálculo (073, R6); só o job |
| exportação (imagem, GEXF, CSV, JSON, HTML) | FR-053 |
| função para API pública, MCP ou material de perfil | FR-053, R12; exposição futura é spec própria, pela mesma função recortada |
| o login de qualquer conta | a consulta não o lê (R9); não tem como chegar à tela nem ao log |
| quais contas foram declaradas da organização | só o número, na área; a lista é da administração, em `Tenants` (R8) |
