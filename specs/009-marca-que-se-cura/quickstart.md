# Quickstart — Feature 009: a marca de inacessível se cura

Oito verificações. Os números vêm do banco de desenvolvimento, medidos em 2026-08-12: **39
repositórios marcados como inacessíveis, 899 issues dentro**, duas coletas concluídas depois da
última marca e **zero** limpezas.

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix ecto.migrate
mix phx.server            # localhost:4000/work
```

---

## V1 — O estado antes, para poder comparar

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where inaccessible_since is not null) as inacessiveis,
       count(*) filter (where excluded_at is not null) as excluidos,
       min(inaccessible_since)::date as marcados_desde
  from observed_repositories;"
```

**Esperado hoje**: `39 | 0 | 2026-08-11`.

**Guarde este número.** É o denominador de V2.

---

## V2 — Uma coleta limpa as marcas

Disparar a sincronização pela tela e, ao terminar:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where inaccessible_since is not null) from observed_repositories;"
```

**Esperado**: **zero** para os repositórios que a origem alcança — é o SC-001.

**O que NÃO pode acontecer**: o número continuar 39, que é o estado de hoje depois de **duas**
coletas concluídas.

---

## V3 — As issues perdidas voltam

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select sr.name, count(i.id)
  from observed_repositories orp
  join cmpo_source_repositories sr on sr.id = orp.source_repository_id
  left join collected_issues i on i.observed_repository_id = orp.id
 where sr.name in ('leds-conectafapes-prestacao-de-contas','plataformas-project','produtos-internos-project')
 group by sr.name order by 2 desc;"
```

**Esperado**: `plataformas-project` 647, `produtos-internos-project` 232, e
`leds-conectafapes-prestacao-de-contas` **11** — hoje ela tem 9, e a origem tem 11. É o SC-002.

---

## V4 — Falha interna da origem NÃO marca

```bash
mix test test/the_band/integrations/github/transient_test.exs -o "interna"
```

**Esperado**: o payload **real** que produziu a 39ª marca — `"Something went wrong while executing
your query on 2026-08-12T12:32:30Z. Please include 6D2F:110188:1CD8DB0:1D79ED0:6A7C67D3 when
reporting this issue"` — é classificado como **transitório**.

**Falha típica**: casar só a tupla e devolver falso no caso geral, que é o comportamento de hoje.

---

## V5 — "Não encontrado" continua marcando

```bash
mix test test/the_band/integrations/github/transient_test.exs -o "permanente"
```

**Esperado**: `NOT_FOUND` e `FORBIDDEN` são permanentes; e uma lista com **naturezas mistas** vale
como permanente.

**Por que esta verificação existe**: marcar de menos deixaria repositório apagado sendo consultado a
cada coleta, para sempre.

---

## V6 — A data de início não se move

```bash
mix test test/the_band/ontology/seon/cmpo/inaccessible_test.exs -o "desde quando"
```

**Esperado**: duas falhas consecutivas deixam `inaccessible_since` **inalterada**, e
`inaccessible_reason` com a **última** falha. É o SC-007.

**Falha típica**: sobrescrever a data, que é o comportamento de hoje — e faz um repositório
inacessível há dez dias parecer novo em cada coleta.

---

## V7 — O excluído nunca é tentado

```bash
mix test test/the_band/ingestion/unreachable_recovery_test.exs -o "excluído"
```

**Esperado**: **nenhuma** requisição é feita pelo repositório excluído pelo tenant, mesmo que ele
também esteja marcado como inacessível. A exclusão é decisão de alguém, e a plataforma não a desfaz.

---

## V8 — A coleta diz quantos não alcançou

Com a origem falhando para todos — desligue a rede, ou aponte a instância para um endereço inválido:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select status, repositories_unreachable from syncs order by started_at desc limit 1;"
```

**Esperado**: a coleta **conclui**, e `repositories_unreachable` é igual à contagem de repositórios
observados — hoje 121 na `leds-conectafapes`. É o SC-005.

**O que NÃO pode**: `completed` com `repositories_unreachable = 0` numa coleta em que nada foi
alcançado. Zero ali **afirma** que tudo foi alcançado, e é o defeito da L32 nesta feature.

---

## Os dez gates

```bash
mix gates
```

**Esperado**: `10 gates verdes`, e **código de saída zero**. Conferir pelo texto não basta — foi a
L23.
