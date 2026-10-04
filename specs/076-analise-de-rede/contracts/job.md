# Contrato — `TheBand.Jobs.ComputeNetworkAnalysis`

FR-017, FR-018, FR-054; R7, R10, R15 da segurança.

```elixir
use Oban.Worker,
  queue: :network_analysis,          # configurada: network_analysis: 1 (R4)
  max_attempts: 3,
  unique: [fields: [:args, :worker], keys: [:tenant_id, :organization_id],
           states: :incomplete, period: :infinity]

@impl Oban.Worker
def timeout(_job), do: :timer.seconds(120)   # provisório, R5; confirmado por T050

@spec enqueue(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
```

**Argumentos**: `tenant_id`, `organization_id`. Qualquer outro (`network`, `window`) é **ignorado**:
as redes e as janelas são as da base. **Único produtor**: `ComputeReviewNetwork`, depois do commit da
leitura da 073 (R3). Nenhuma tela enfileira.

## `perform/1`, na ordem

1. o tenant existe (`Tenants.fetch/1`), senão `{:cancel, :tenant_not_found}`;
2. está ativo (`Tenants.ensure_active/1`), senão `{:cancel, :tenant_inactive}`;
3. a organização é deste tenant (`EO.fetch_organization/2`), senão `{:cancel, :organization_not_found}`;
4. `NetworkAnalysis.compute(tenant, organizacao, DateTime.utc_now(:second))`;
5. `{:error, {:reading_rejected, campos}}` → `{:cancel, {:reading_rejected, campos}}`, sem tentar de
   novo (o erro é de dado, e o termo gravado em `oban_jobs.errors` só tem nomes de campo — A18);
6. registra, a partir do **relator**, uma linha por rede e janela: organização, rede, janela,
   `outcome`, arestas, pessoas, exclusões por motivo, ausências por teto, duração. **Nunca** par,
   nome, login, papel, comunidade nem medida por pessoa (FR-054, A19).

Nenhum cancelamento grava leitura (A14). O cálculo de σ, Q_rand e layout acima do teto não roda
(A16). Impressão digital igual à vigente: `outcome: :unchanged`, leitura não regravada (A15).

## Testável sem log

`perform/1` devolve `:ok` ou `{:cancel, motivo}`; o relator é o retorno de
`NetworkAnalysis.compute/3`, e os testes afirmam sobre ele (L69). O log é derivado do relator.
