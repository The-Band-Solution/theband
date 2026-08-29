# Contrato — Estado da chave e a guarda de `Profiles.request/3`

Escrito antes do código (constituição VI). Erro de contrato se corrige no mesmo
commit, com razão.

## Leitura de estado (existente, reusada — nada novo)

```elixir
TheBand.AI.origem_da_chave(tenant)
#=> {:tenant, %ProviderCredential{}} | {:ambiente, last4} | :nenhuma

TheBand.AI.fetch(tenant)
#=> {:ok, %ProviderCredential{}} | {:error, :not_found}
```

- Página da pessoa: botão de geração habilita quando `origem_da_chave != :nenhuma`.
- Geração mensal: botões habilitam quando `fetch == {:ok, _}` — ambiente NÃO conta
  (FR-011 da 044, `Runs.credencial/1` inalterada).
- UMA leitura por mount de tela; nenhuma leitura por linha.

## `Profiles.request/3` — mudança de contrato

### Antes

```elixir
@spec request(Tenant.t(), binary(), binary() | nil) :: {:ok, Oban.Job.t()} | {:error, term()}
# enfileira SEM conferir chave; sem chave, o worker falha depois (sucesso silencioso)
```

### Depois

```elixir
@spec request(Tenant.t(), binary(), binary() | nil) ::
        {:ok, Oban.Job.t()} | {:error, :sem_chave} | {:error, term()}
```

- Recusa `{:error, :sem_chave}` quando `AI.origem_da_chave(tenant) == :nenhuma`,
  ANTES de enfileirar — nenhum job nasce condenado.
- `{:ambiente, _}` continua aceito neste caminho: é como o desenvolvimento roda
  (`AI.opcoes/1` decide a chave, num lugar só — contrato dela inalterado).
- A borda traduz `:sem_chave` em frase (via catálogo da 047 quando ela existir;
  literal preservado até lá se a 048 chegar antes — os dois PRs são independentes).

## A frase da lacuna (FR-001/FR-004)

- Quem opera (`@operacao_menu` verdadeiro): a frase nomeia o caminho — a chave se
  configura em **AI provider** (área operacional, PR #567).
- Quem não opera: a frase diz que QUEM OPERA configura — sem link para onde a
  pessoa não alcança.
- Botão desabilitado usa `disabled` real (atributo), nunca só classe — leitor de
  tela e teste enxergam o mesmo fato.

## Testes que provam o contrato

| Invariante | Teste |
|---|---|
| Violação primeiro (L03): evento forçado sem chave é recusado pelo domínio | `profiles_test.exs` — `request/3` com tenant sem chave e sem ambiente devolve `{:error, :sem_chave}`, e NENHUM job é enfileirado |
| Ambiente ainda vale para a pessoa | `request/3` com `API_KEY` do ambiente enfileira |
| Mensal continua tenant-only | teste existente de `Runs` inalterado |
| Botão diz antes do clique | teste de tela: sem chave → `disabled` + frase; com chave → habilitado, frase ausente |
| Frase adaptada | dois usuários (opera / não opera), duas frases |
