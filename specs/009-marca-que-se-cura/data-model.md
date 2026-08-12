# Modelo de dados — Feature 009

**Uma coluna nova, e duas semânticas corrigidas.** Nenhuma tabela nova, nenhuma removida, nenhum
estado novo.

---

## `syncs.repositories_unreachable`

| Coluna | Tipo | Nulo | Padrão | Nota |
|---|---|---|---|---|
| `repositories_unreachable` | `integer` | não | **0** | quantos repositórios a execução não alcançou |

### Por que o padrão zero é correto aqui, e não é exceção à regra

A regra do projeto é *ausência é nula, nunca zero*. Aqui **zero é um fato**, não uma ausência: uma
coleta que alcançou todos os repositórios não alcançou **zero** deles.

O que seria ausência é a coluna não existir — e é o estado de hoje, em que a plataforma não sabe
quantos deixou de alcançar. Trinta e nove caíram, e a execução concluiu com sucesso e 100%.

**O risco declarado**: se alguém esquecer de incrementar, o zero **afirma** que tudo foi alcançado.
É a L32 esperando acontecer, e a mitigação é um teste em que **tudo** falha e o número tem de ser
igual à contagem de repositórios.

### Por que não em `skip_reasons`, que era o caminho mais curto

O mecanismo de "pulado" incrementa `records_collected` junto:

```elixir
{:skipped, reason} ->
  %{records_collected: sync.records_collected + 1, records_skipped: ..., skip_reasons: ...}
```

Trinta e nove repositórios não alcançados entrariam como **39 registros coletados**. Misturar
unidade num contador é como um número certo começa a mentir — e este projeto já pagou por isso,
quando a contagem por execução somava o tenant inteiro.

---

## `observed_repositories.inaccessible_since` — a semântica corrigida

| Antes | Depois |
|---|---|
| sobrescrita a **cada** falha | gravada **na primeira**, preservada nas seguintes |

**O que ela passa a significar**: *desde quando* a plataforma não alcança este repositório. Antes
significava *quando alguém tentou por último* — e com isso um repositório inacessível há dez dias
parecia novo em cada coleta.

`inaccessible_reason` continua sendo sobrescrita, e é o certo: ela carrega **a última** falha, e é o
que decide se alguém age.

As duas juntas respondem o que uma sozinha não responde: **desde quando**, e **por que agora**.

---

## O que a feature **não** cria

| Não criado | Por quê |
|---|---|
| `last_attempt_at` | o registro de sincronização já data a última tentativa |
| estado "inacessível há muito tempo" | a data distingue; um estado a mais obriga toda leitura a conhecê-lo |
| histórico de incidentes por repositório | exige evento append-only e necessidade de informação própria — declarado na spec |
| coluna com o tipo do erro | o motivo em texto já carrega, e um enum de erro de terceiro envelhece com a origem |

---

## O que muda em `list_collectable/2`

| Antes | Depois |
|---|---|
| rejeita `excluded_at` **e** `inaccessible_since` | rejeita **só** `excluded_at` |

**A exclusão é decisão de alguém; a inacessibilidade é inferência da plataforma.** Tratar as duas
como uma fez a inferência ganhar a mesma força que a decisão — e foi assim que um `:nxdomain` de um
instante tirou 39 repositórios de circulação por dois dias.

O nome da função não muda porque ele já estava certo: *o que a coleta deve consultar*. Era a
implementação que discordava dele.
