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
5. o recorte, puro, e os nomes pelas pessoas que sobraram (`EO.people_names/2`).

Custo: **quatro consultas** (organização, leitura, pessoas da organização, nomes) mais o que
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

  # Sobre o subgrafo das pessoas alcançadas (com :total, a rede inteira)
  reviews: non_neg_integer(),                 # pares revisor–solicitação
  reviewers: non_neg_integer(),
  concentration:
    {:ok, %{fractions: [%{k: pos_integer(), reviews: non_neg_integer(), of: pos_integer()}],
            sample: :suficiente | {:pequena, minimo :: pos_integer()}}}
    | {:ausente, :sem_revisao_na_janela},

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

  groups:
    {:ok, %{shown: [pos_integer()], small_without_size: non_neg_integer()}}
    | {:ausente, :sem_revisao_na_janela},
  people_without_review_activity: non_neg_integer(),

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

**Por que `fractions` não traz quem**: é a decisão de 2026-10-03 sobre R1. Nenhum campo da
concentração carrega `person_id` ou nome, para nenhum leitor, administração inclusive.

### O que `read/4` NÃO expõe, e por quê

| não expõe | por quê |
|---|---|
| a leitura inteira, sem recorte | R3: filtro na tela é a segunda porta, e foi assim que o H2 nasceu |
| quantas revisões envolvem pessoas fora do alcance, em qualquer forma | decisão de 2026-10-03 sobre R2; precedente `verification_live/people.ex:147-154` |
| quantos pares de uma pessoa estão fora do alcance | só `pairs_outside_reach?`, sem número (R2, item 1) |
| tamanho de grupo abaixo do mínimo para quem não alcança todos os integrantes | R2, item 3; vira `small_without_size` |
| login, de qualquer conta, inclusive das exclusões | R9: identidade fora de qualquer veredito |
| auto-revisão por pessoa | FR-004, R5: é acusação, e não medida |
| a pessoa que mais revisou, ou qualquer ordenação por medida | FR-018, FR-018a, R1, R5 |
| exclusões para alcance parcial | [research.md R12](../research.md#r12--o-que-a-tela-de-alcance-parcial-mostra-das-exclusões) |
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
