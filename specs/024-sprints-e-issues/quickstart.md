# Quickstart — provar as caixas de tempo

**Feature** `024-sprints-e-issues` · **Data**: 2026-08-15

## Antes

```bash
set -a && . ./.env && set +a   # a chave mestra mora aqui
mix ecto.migrate
mix gates                      # sem `| tail` — o veredito é o código de saída
```

## O que provar, e em que ordem

### 1. O critério de identidade está na base

```bash
mix knowledge.validate
```

`sro.sprint` precisa ter `identity_criterion`. **Sem isso a migração não deve existir** — é o
princípio I, e a fase 0 achou que ele faltava.

### 2. Duas coletas produzem uma caixa

```
mix test test/the_band/ingestion/sprints_test.exs
```

A asserção é a **contagem de linhas**, e não o `outcome` devolvido — um `:unchanged` junto de uma
linha extra passaria numa asserção sobre o retorno.

### 3. A sobreposição não foi achatada

É a prova que mais importa. Sobre o payload capturado do DevOps:

```
527 vínculos no campo `Sprint`
203 vínculos no campo `Quarter`
677 itens no quadro
```

**A soma dos vínculos é maior que o número de itens.** Se o teste encontrar 677 ou menos, alguma
issue perdeu uma das duas caixas — e é exatamente o defeito que o modelo existe para impedir.

### 4. A duração é a da iteração

`Sprint 10` tem **3 dias** num campo configurado para 14. Se a tabela gravar 14, a série mente
sobre o período coberto.

### 5. Quadro sem iteração não é consultado

A borda simulada **reprova** se a consulta de itens for feita para quadro sem campo de iteração.
"Não trouxe caixas" não prova que não pediu — 15 dos 26 quadros medidos são assim.

### 6. Zero e "não se aplica" são distinguíveis

```elixir
count_issues_outside_any_sprint(tenant, quadro_sem_iteracao)
# {:error, :board_has_no_iteration_field}   ← e nunca {:ok, 0}
```

## Contra a origem real

```bash
mix run priv/scripts/coletar.exs   # com a chave mestra no ambiente
```

Conferir contra a medida de 2026-08-15:

| O quê | Esperado |
|---|---|
| quadros com campo de iteração | 11 de 26 |
| campos no total | 15 |
| iterações concluídas no DevOps | 32 |
| vínculos no DevOps | 527 `Sprint` + 203 `Quarter` |
| itens do DevOps fora de qualquer sprint | 150 |

**Divergência não é erro automático** — o quadro muda. Mas divergência grande sem sprint novo é
sinal de que a coleta perdeu algo.
