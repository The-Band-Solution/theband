# Contrato — `TheBand.Jobs.ComputeReviewNetwork`

FR-010, FR-011, FR-013, FR-021. Decisões em [research.md R8 e R9](../research.md#r8--o-gatilho-o-fim-da-coleta-de-revisões).

```elixir
use Oban.Worker,
  queue: :transformation,
  max_attempts: 3,
  unique: [fields: [:args, :worker], keys: [:tenant_id, :organization_id],
           states: :incomplete, period: :infinity]
```

**Corrigido na implementação (2026-10-03)**: o contrato pedia `states: [:available, :scheduled,
:retryable]`, deixando `:executing` de fora para que a coleta que termina durante um cálculo
enfileirasse o seguinte (research.md R9, D7). O Oban 2.23.1 avisa na compilação que a lista sem os
estados incompletos *"may break uniqueness"*, e o gate compila com `--warnings-as-errors`. Vale o
grupo `:incomplete`. O que piora: a coleta que termina durante um cálculo não o repete, e a leitura
alcança o dado na sincronização seguinte (intervalo mínimo de 15 minutos).

## `enqueue/2`

```elixir
@spec enqueue(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
def enqueue(tenant_id, organization_id)
```

Único produtor: `SyncGithubEo.coletar_mudancas/1`, ao fim da coleta de revisões. **Nenhuma tela,
rota ou evento enfileira** (decisão de 2026-10-03, R6). Um teste lê o código da camada web e reprova
se `ComputeReviewNetwork` aparecer nela.

## `perform/1`

Argumentos: `%{"tenant_id" => _, "organization_id" => _}`. Nenhum outro é lido; **a janela não é
argumento**.

| passo | falha | retorno | grava? |
|---|---|---|---|
| `Tenants.fetch/1` | não existe | `{:cancel, :tenant_not_found}` | não |
| `Tenants.ensure_active/1` | suspenso | `{:cancel, :tenant_inactive}` | não |
| `EO.fetch_organization/2` (id **e** tenant) | não existe, ou é de outro tenant | `{:cancel, :organization_not_found}` | não |
| `ReviewNetwork.compute/3` com `DateTime.utc_now(:second)` | exceção de banco | levanta; a transação desfaz; o Oban tenta de novo | não |
| `ReviewNetwork.compute/3` | leitura recusada pelo banco (076, T004) | `{:cancel, {:reading_rejected, campos}}`, só nomes de campo | não |
| sucesso | — | `:ok`, depois de `broadcast` e `Logger.info` | as três janelas, juntas |

Cancelar **nunca** grava leitura vazia (A10): leitura com *"nenhuma revisão"* porque a organização
não foi achada faria a tela afirmar que não houve revisão.

## O log (FR-021, R14)

Uma linha por janela, com `tenant_id`, `organization_id`, `window_days`, `reviews`, as três
contagens de exclusão e `duration_ms`. **Nunca** par, nome, login, nem `person_id`. Guardado por
`capture_log` em `:debug` com nomes de teste óbvios (A16).

## O aviso

`{:review_network_ready, organization_id, reading_ids}` em `"review_network:" <> tenant_id`,
depois do `commit` da transação. Só ids (A11). Quem emite é `ReviewNetwork.compute/3`, e não o job, para que o job
não toque módulo interno de `ReviewNetwork` (corrigido na implementação, 2026-10-03).

## O que o job NÃO faz

- não recebe nem valida janela vinda de fora: as janelas são as da base;
- não calcula organização de outro tenant, nem "todas as organizações do tenant";
- não roda na recoleta avulsa (`mix the_band.recollect_changes`); a próxima sincronização roda;
- não guarda estado de falha: o Oban guarda o job, e a tela mostra a leitura vigente com o instante
  dela ([research.md R14](../research.md#r14--ausências-o-que-a-leitura-devolve-quando-não-há-o-que-mostrar)).
