# Contrato — marcar o vínculo que a origem não declara mais

**Feature** `012-vinculo-que-sumiu-na-origem` · **Fronteira**: `TheBand.WorkItems`

Escrito **antes** da primeira função pública, como o princípio VI exige.

---

## `TheBand.WorkItems.mark_decomposition_links_no_longer_observed/3`

Marca como ausentes os vínculos de decomposição **cujo pai está no repositório informado** e que a
execução não reviu.

```elixir
@spec mark_decomposition_links_no_longer_observed(
        Tenant.t(),
        Ecto.UUID.t(),
        DateTime.t()
      ) :: {:ok, non_neg_integer()}
```

| Argumento | O que é |
|---|---|
| `tenant` | o tenant, e o `UPDATE` é escopado por ele |
| `observed_repository_id` | o repositório **do pai**, obrigatório |
| `desde` | o `started_at` da execução — o **corte**, não a data da marca |

Devolve `{:ok, quantos}` — quantos vínculos esta chamada marcou. Zero é fato: a execução reviu todos.

### Não existe versão de aridade 2

**A L19 impedida no tipo**, igual à irmã `mark_issues_no_longer_observed/3`. Sem
`observed_repository_id` a chamada marcaria os vínculos de repositórios que a execução nunca olhou —
numa organização de 121, coletar um atingiria os outros 120.

### Garantias

| # | Garantia | Por que |
|---|---|---|
| G1 | escopo por `tenant_id` **e** por repositório do pai | princípio V; FR-003 |
| G2 | marca só `last_observed_at < desde` | FR-001; o corte é o início da execução |
| G3 | **não** reescreve marca existente — `is_nil(no_longer_observed_at)` no `WHERE` | FR-009 |
| G4 | idempotente: segunda chamada sem mudança devolve `{:ok, 0}` | FR-008 |
| G5 | **nada é apagado** — só `no_longer_observed_at` é escrito | FR-007; princípio III |
| G6 | um `UPDATE`, independente de quantos vínculos | 1 666 hoje; laço seria uma ida por vínculo |
| G7 | a data gravada é o instante em que se notou, como em issue, designado e rótulo | FR-002 |

### O que a função **não** faz, e por quê

| Não faz | Por quê |
|---|---|
| **não** decide se a coleta foi bem-sucedida | quem sabe é a fase; chamar no ramo errado é o defeito que a feature 009 pagou |
| **não** toca `refused_links` | recusa nunca foi vínculo afirmado |
| **não** apaga nada | ausência é marcada, nunca removida |
| **não** ressuscita | quem devolve vigência é `record_decomposition_link/2`, que já zera a marca |
| **não** olha o repositório da **filha** | quem declara a decomposição é o pai; 57 vínculos cruzam repositório |
| **não** devolve `Ecto.Query` | princípio X, letra I: quem chama não conhece o schema |

### Erros

**Não há erro previsto de negócio.** A função devolve `{:ok, n}` sempre — inclusive `{:ok, 0}` para
repositório sem vínculo nenhum. Argumento que não é UUID levanta, e isso é bug de quem chama, não
caso previsto: princípio VIII, erro previsto é retorno, exceção é para bug.

---

## O que muda em `TheBand.Ingestion.GithubWorkItems`

**Nenhuma função pública nova.** A chamada entra em `coletar_issues/2`, no ramo `{:ok, …}`, ao lado
da marcação de issues:

| Onde | O que acontece |
|---|---|
| ramo `{:ok, nodes, total}`, depois de `vincular/2` | marca, e o número entra no resultado da fase |
| ramo `{:error, reason}` | **nada é marcado** — nem transitório, nem permanente |
| repositório excluído ou inacessível | não chega a `coletar_issues/2`: `list_collectable/2` já filtrou |

O resultado por repositório ganha um campo:

```elixir
%{repositorio: nome, coletadas: n, alcancado: true, vinculos_ausentes: m}
```

E o log nomeia repositório e número quando `m > 0` — **silêncio quando é zero**, pela mesma razão que
a tela de sincronizações esconde "0 unreachable": uma linha que aparece sempre treina quem lê a
ignorá-la.

---

## O que a tela consome, e já existe

Nenhuma função nova de consulta. `list_parents/2` (feature 011) já carrega `no_longer_observed_at`, e
a lista de issues já tem o rótulo *"absent: this link existed and is not present now"*.

**Esta feature não muda a tela: ela faz o dado chegar no estado que a tela já sabe exibir.**
