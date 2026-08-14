# Contrato — coleta incremental

**Feature** `020-coletar-so-o-que-mudou` · **Data**: 2026-08-14

O contrato vem antes da implementação. Se a implementação mostrar que ele está errado, o
conserto entra **no mesmo commit** — nunca depois.

---

## 1. A marca de vínculo ausente passa a receber o que foi olhado

```elixir
# hoje — escopo é o repositório
@spec mark_decomposition_links_no_longer_observed(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
        {:ok, non_neg_integer()}

# passa a ser — escopo é a lista de pais efetivamente percorridos
@spec mark_decomposition_links_no_longer_observed(Tenant.t(), [Ecto.UUID.t()], DateTime.t()) ::
        {:ok, non_neg_integer()}
```

**Lista vazia devolve `{:ok, 0}`** e não marca coisa alguma. É o caso do repositório pulado, e
tratá-lo como "nenhum pai apareceu, então marque tudo" seria o defeito que este contrato existe
para impedir.

**Por que a assinatura muda, e não um parâmetro opcional.** Um `opts[:parent_ids]` deixaria o
comportamento antigo como padrão — e o comportamento antigo, na coleta incremental, marca 4261
vínculos falsos. O padrão perigoso não pode ser o que se obtém por esquecimento.

---

## 2. A contagem por escrita

```elixir
# hoje, em github_work_items.ex:121 e :408
ctx.sync |> Ingestion.reload() |> Ingestion.tally(:unchanged)

# passa a ser
ctx.sync |> Ingestion.reload() |> Ingestion.tally(resultado.outcome)
```

`outcome` é `:created`, `:updated` ou `:unchanged`, e **já é devolvido pelo upsert** — é o que a
fase de EO usa em `sync_github_eo.ex:406`.

`Ingestion.tally/2` **não muda**: ele já distingue os três casos, e já soma `records_collected`
em todos.

---

## 3. Pular repositório sem atividade

```elixir
@spec percorrer?(CMPO.SourceRepository.t(), ObservedRepository.t()) ::
        :sim | {:nao, :sem_push_desde_a_revisao}
```

| Estado | Resposta |
|---|---|
| `issues_collected_at` nulo | `:sim` — nunca revisto é sempre percorrido |
| `last_pushed_at` nulo | `:sim` — ausência de data não é ausência de mudança |
| `last_pushed_at >= issues_collected_at` | `:sim` |
| `last_pushed_at < issues_collected_at` | `{:nao, :sem_push_desde_a_revisao}` |

**O motivo é valor de retorno, não log.** A tela precisa dizer por que pulou, e um átomo é o que
atravessa a fronteira sem virar frase montada no meio do caminho.

**Falso positivo é aceito e falso negativo não.** Um commit que não mexe em issue faz o
repositório ser percorrido à toa — custa uma consulta. O contrário custaria dado que não chega.

---

## 4. A consulta de issues ganha a janela

```graphql
query($owner: String!, $name: String!, $page_size: Int = 50,
      $after: String, $since: DateTime) {
  repository(owner: $owner, name: $name) {
    issues(first: $page_size, after: $after,
           filterBy: {since: $since},
           orderBy: {field: UPDATED_AT, direction: ASC}) {
```

**`$since` nulo traz tudo** — é o modo completo, e é o que a rede de segurança usa.

**A ordenação muda de `CREATED_AT` para `UPDATED_AT`.** Com filtro por atualização, ordenar por
criação faz a paginação atravessar páginas cuja maioria está fora da janela.

> **Bloqueado pela fase 0.** Este contrato afirma que `filterBy: {since:}` existe e que ele
> filtra por atualização. Está documentado no schema e **não foi medido aqui**. Uma consulta
> resolve, e nada é construído em cima antes dela.

---

## 5. A janela tem sobreposição, e ela é declarada

```elixir
@sobreposicao_da_janela 60  # segundos
```

A coleta pede desde `issues_collected_at - 60s`, e não desde `issues_collected_at`.

**Por quê.** O carimbo de atualização é da origem e a marca de revisão é da plataforma: os dois
relógios não são o mesmo. Uma issue alterada no instante da revisão anterior cairia fora da
janela por diferença de milissegundos, e não voltaria nunca — o próximo `since` seria ainda mais
recente.

**Sessenta segundos é um número escolhido, e o plano o declara em vez de escondê-lo.** Ele custa
reler as issues alteradas no minuto anterior, o que é barato; e cobre desvio de relógio, latência
de gravação e o intervalo entre pedir e receber a página.

---

## 6. O que a tela passa a dizer

| Campo | Origem |
|---|---|
| modo da execução | `syncs.mode` |
| repositórios pulados | contagem por motivo, no resultado da fase |
| criados · atualizados · inalterados | `records_created`, `records_updated`, e a diferença |

**A soma tem de fechar**: criados mais atualizados mais inalterados mais pulados é o total
percorrido. Um número que não fecha é pior que número nenhum — ele parece informação.
