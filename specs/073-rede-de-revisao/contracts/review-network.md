# Contrato — `TheBand.ReviewNetwork`

FR-001 a FR-015, FR-020, FR-021. Desenho em [data-model.md](../data-model.md); decisões em
[research.md](../research.md); achados em [seguranca.md](../seguranca.md) (R1–R14).

`lib/the_band/review_network.ex` contém **só `defdelegate`**. Ninguém fora do módulo toca
`ReviewNetwork.Schemas.Reading`, nem a tabela `review_network_readings`, nem `Repo` em nome dela.

**Depende de**: `TheBand.Tenants` (alcance, tenant), `TheBand.Ontology.SEON.EO`,
`TheBand.Ontology.SEON.CMPO`, `TheBand.Quality`, `TheBand.Changes`,
`TheBand.Ontology.KnowledgeBase`, `TheBand.SemanticIntegration.Mapper` (só `account_type/1`).
Sempre pela API pública de cada um ([fronteiras.md](fronteiras.md)).

---

## `read/4`

```elixir
@spec read(Tenant.t(), User.t(), organization_id :: Ecto.UUID.t(), window :: String.t() | integer()) ::
        {:ok, view()}
        | {:ausente, :nao_calculada}
        | {:error, :not_found | :janela_invalida}
```

**A única porta da leitura para quem consulta** (FR-015; R3 da segurança). A tela nunca recebe a
leitura inteira para filtrar ela mesma.

Ordem, e cada passo é o que impede um cenário de ataque:

1. `window` é comparada com a lista fechada da regra de limiares. Aceita o inteiro ou o texto
   decimal exato (`"90"`); `"36500"`, `"-1"`, `"90; drop"`, `"abc"` e `nil` devolvem
   `{:error, :janela_invalida}`. **Nunca** `String.to_atom/1`, nunca `String.to_integer/1` sem a
   lista (A8);
2. a organização é buscada por id **e** tenant (`EO.fetch_organization/2`). Outra organização,
   inexistente ou de outro tenant, devolve `{:error, :not_found}`, o mesmo para os dois casos (A3,
   §11.1);
3. a leitura vigente de `(tenant, organização, janela)`. Sem linha: `{:ausente, :nao_calculada}`;
4. `Tenants.pessoas_alcancadas(tenant, user)`, **nesta chamada**, nunca recebida de fora nem
   guardada (R10, A13);
5. o recorte, puro, e os nomes pelas pessoas que sobraram (`EO.people_names/2`);
6. o fim da coleta de mudanças mais recente dos repositórios observados da organização
   (`CMPO.list_observed/2` com `organization_id:`, o maior `changes_collected_at`), comparado com
   `computed_at` (Q3, decidido em 2026-10-03). O registro já existe por repositório, fora do Oban,
   e nenhuma tabela nova é preciso: o plano registra a escolha em research.md R14.

Custo: **cinco consultas** (organização, leitura, pessoas da organização, nomes, repositórios) mais o que
`pessoas_alcancadas/2` custa (três, e uma a mais por organização em escopo,
`access.ex:302-307`). Nada cresce com o tamanho da rede. Guardado por teste de teto de consultas.

### `view()`

```elixir
%{
  organization_id: Ecto.UUID.t(),
  window_days: pos_integer(),
  window_start: DateTime.t(),
  window_end: DateTime.t(),
  computed_at: DateTime.t(),
  reach: :total | :parcial,

  # Q3: há coleta de mudanças da organização terminada depois desta leitura?
  newer_collection: :nenhuma | {:em, DateTime.t()},

  # Sobre o subgrafo das pessoas alcançadas (com :total, a rede inteira)
  reviews: non_neg_integer(),                 # pares revisor–solicitação
  reviewers: non_neg_integer(),               # pessoas com ao menos uma revisão feita no recorte
  authors: non_neg_integer(),                 # pessoas revisadas no recorte (D10)
  concentration:
    {:ok, [%{k: pos_integer(),
             value: {:ok, %{reviews: pos_integer(), of: pos_integer()}}
                    | {:ausente, :fewer_reviewers_than_k}}]}
    | {:ausente, :sem_revisao_na_janela}
    | {:ausente, {:abaixo_da_amostra_minima, minimo :: pos_integer()}},

  # Ordenada por nome, e por nada mais (FR-018a)
  people: [%{
    person_id: Ecto.UUID.t(),
    name: String.t(),
    given: {:ok, %{reviews: pos_integer(), people: pos_integer()}} | {:ausente, :nao_revisou},
    received: {:ok, %{change_requests: pos_integer(), people: pos_integer()}}
              | {:ausente, :sem_solicitacao_revisada},
    reviews_of: [%{person_id: Ecto.UUID.t(), name: String.t(), reviews: pos_integer()}],
    reviewed_by: [%{person_id: Ecto.UUID.t(), name: String.t(), reviews: pos_integer()}],
    pairs_outside_reach?: boolean()
  }],

  # Componentes fracos do MESMO recorte (Q4): com :parcial, só entre pessoas alcançadas
  groups: {:ok, [pos_integer()]} | {:ausente, :sem_revisao_na_janela},
  people_without_review_activity: non_neg_integer(),   # pessoas `person` alcançadas da organização

  # Só com reach: :total; com :parcial, {:recortado, :regra}
  exclusions:
    {:ok, %{self_reviews: non_neg_integer(), bot_or_app: non_neg_integer(), unlinked: non_neg_integer()}}
    | {:recortado, :regra},

  provenance: %{knowledge_versions: %{String.t() => pos_integer()}}
}
```

**Por que as frações vêm como contagem, e não como porcentagem**: `reviews` e `of` são inteiros,
e a tela faz a conta. Assim o SC-001 compara inteiros com a contagem manual, e o arredondamento é
decisão de apresentação, num lugar só.

**A linha da pessoa e a concentração têm populações diferentes, de propósito** (FR-015, achado do
protótipo): `given` e `received` são o total da pessoa na janela, sobre a rede inteira (R2, item 1),
e `reviews`, `reviewers`, `authors`, `concentration` e `groups` são do recorte. Bia aparece com
*"reviewed 12"* e a concentração pode dizer *10 of 14*. A tela escreve, acima da lista, *"Each row
shows the person's whole count in the window; the pairs show only people you reach"*, e o QA confere
que a frase está lá.

**Amostra mínima** (decidido em 2026-10-03): abaixo de `minimum_sample` **revisões** do recorte (a
mesma unidade do denominador), a concentração é `{:ausente, {:abaixo_da_amostra_minima, m}}`; as
contagens continuam. k maior que o número de revisores dá `{:ausente, :fewer_reviewers_than_k}`
naquele k, e nunca 100%.

**Por que `fractions` não traz quem**: é a decisão de 2026-10-03 sobre R1. Nenhum campo da
concentração carrega `person_id` ou nome, para nenhum leitor, administração inclusive.

### O que `read/4` NÃO expõe, e por quê

| não expõe | por quê |
|---|---|
| a leitura inteira, sem recorte | R3: filtro na tela é a segunda porta, e foi assim que o H2 nasceu |
| quantas revisões envolvem pessoas fora do alcance, em qualquer forma | decisão de 2026-10-03 sobre R2; precedente `verification_live/people.ex:147-154` |
| quantos pares de uma pessoa estão fora do alcance | só `pairs_outside_reach?`, sem número (R2, item 1) |
| grupo com pessoa fora do alcance, ou o tamanho dele | Q4: os grupos são do recorte, como a concentração; quem está fora não entra em grupo nenhum |
| login, de qualquer conta, inclusive das exclusões | R9: identidade fora de qualquer veredito |
| auto-revisão por pessoa | FR-004, R5: é acusação, e não medida |
| a pessoa que mais revisou, ou qualquer ordenação por medida | FR-018, FR-018a, R1, R5 |
| exclusões para alcance parcial, **inclusive bot ou aplicativo** | [research.md R12](../research.md#r12--o-que-a-tela-de-alcance-parcial-mostra-das-exclusões); Q5, decidido em 2026-10-03 |
| rótulo de papel, faixa numérica | FR-018 |
| qualquer formato de exportação | FR-018b |
| `Ecto.Query`, struct do schema | princípio X, letra I |

---

## `compute/3`

```elixir
@spec compute(Tenant.t(), organization :: map(), now :: DateTime.t()) ::
        {:ok, %{readings: [%{id: Ecto.UUID.t(), window_days: pos_integer(), reviews: non_neg_integer(),
                             excluded: %{self_reviews: n, bot_or_app: n, unlinked: n}}]}}
```

Chamada **só pelo job** ([job.md](job.md)), com tenant ativo e organização já conferida. Lê os pares
da maior janela uma vez, classifica, calcula as três janelas pela função pura e **substitui** as
três linhas da organização numa transação: apaga e insere. Ou as três ficam, ou nenhuma muda.

`now` vem de quem chama. A função não lê relógio, e é isso que torna a FR-012 testável.

Não devolve `{:error, _}` para caso de negócio: as conferências que poderiam falhar já foram feitas
pelo job, e o resto é bug (base inconsistente levanta na carga dos parâmetros; erro de banco
desfaz a transação e o Oban tenta de novo).

**Não expõe**: os pares, as arestas, ids de pessoa. O relator devolvido tem só contagens, e é o que o
job loga (FR-021).

---

## `windows/0`

```elixir
@spec windows() :: %{allowed: [pos_integer()], default: pos_integer()}
```

As janelas da regra de limiares. A tela as usa para desenhar a escolha, e nunca as escreve no
próprio código.

---

## `subscribe/1`

```elixir
@spec subscribe(Tenant.t()) :: :ok | {:error, term()}
```

Assina `"review_network:" <> tenant_id`. A mensagem é **só**:

```elixir
{:review_network_ready, organization_id :: Ecto.UUID.t(), reading_ids :: [Ecto.UUID.t()]}
```

Nenhuma aresta, contagem, `person_id` ou nome (A11). Quem recebe relê por `read/4`.

---

## Os parâmetros entram pela fachada, e só por ela

`compute/3`, `read/4` e `windows/0` são a fachada: cada uma lê `ReviewNetwork.Parameters` (a base)
e chama a função interna que recebe os parâmetros como **argumento**:

```elixir
Commands.compute(Tenant.t(), organization, now :: DateTime.t(), parameters()) :: {:ok, relator}
Reader.read(Tenant.t(), User.t(), organization_id, window, parameters()) :: mesmo retorno de read/4
```

**Por quê** (2026-10-03, `/speckit-analyze` sobre `tasks.md`): a base (k, janelas, amostra, grupo
mínimo, estados que contam) espera a revisão semântica de `proposta-base/`. Com os parâmetros como
argumento, o cálculo e o recorte são escritos e provados antes da base, sem nenhum valor escrito no
código para não esperar: o teste passa os parâmetros, e a fachada só existe quando a base existe
(T013, T017). Nenhuma das duas funções internas aparece na fachada, e ninguém fora do módulo as
chama.

```elixir
@type parameters :: %{
        windows: [pos_integer()], default_window: pos_integer(),
        ks: [pos_integer()], minimum_sample: pos_integer(),
        counted_states: [String.t()], knowledge_versions: %{String.t() => pos_integer()}
      }
```

Os nomes das chaves **da base** são os que a revisão semântica aceitar (T003); este mapa é a forma
em memória, e `Parameters` traduz uma na outra. O grupo mínimo (3, decidido em 2026-10-03) fica
declarado na base e **não** entra aqui: com a Q4, os grupos são do recorte, e não sobra caso em que
um tamanho de grupo fale de quem o leitor não alcança. Ele volta na fatia 2.

## `Graph` — módulo interno, puro

Não é API pública (não aparece na fachada), e é testado direto porque é onde a matemática mora.
Sem `Repo`, sem relógio, sem `Logger`.

```elixir
@spec build([par_classificado()], window_start :: DateTime.t()) :: grafo()
@spec totals_by_person(grafo()) :: %{person_id => %{given: ..., received_people: ...}}
@spec groups(edges) :: [[person_id]]                       # componentes fracos, ordenados
@spec concentration(edges, ks :: [pos_integer()]) :: [%{k, reviews, of}] | :sem_revisao
@spec induced(edges, MapSet.t()) :: edges                 # o subgrafo das pessoas alcançadas
```

## `Slice` — módulo interno, puro

Aplica o alcance a uma leitura e produz `view()` sem nomes. Separado de `Graph` porque muda quando a
**regra de acesso** muda, e não quando a matemática muda (princípio X).
