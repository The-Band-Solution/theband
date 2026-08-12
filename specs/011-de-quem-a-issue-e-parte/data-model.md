# Modelo de dados — Feature 011

**Nenhuma coluna nova, nenhuma migração.** A feature só lê, e a relação é derivada.

## O que já existe, e é o que ela usa

### `decomposition_links`

| coluna | para que serve aqui |
|---|---|
| `tenant_id` | escopo, em toda consulta |
| `parent_issue_id` | o pai |
| `child_issue_id` | a filha — a chave do agrupamento |
| `observed_at`, `last_observed_at` | o período em que o vínculo foi visto |
| `no_longer_observed_at` | **ausência marcada** — vínculo que deixou de aparecer |

Vínculos vigentes: **1 666**. Com `no_longer_observed_at` preenchido: **zero** hoje.

### `collected_issues`

`number`, `title`, `observed_repository_id` do pai — e `observed_repository_id` é o que expõe a
segunda fronteira: o **nome** do repositório é de CMPO.

### `issue_promotions`

O conceito do pai vem da promoção **vigente** — `distinct on (collected_issue_id)` ordenado por
`inserted_at desc`, que é o `promocoes_vigentes/1` que já existe.

**Usar o histórico infla**: medido com todas as promoções, o mesmo grafo deu **2 238** vínculos onde a
promoção vigente dá 1 666.

## O que a consulta devolve

```text
%{child_issue_id => [
    %{id, number, title, observed_repository_id, derived_concept, no_longer_observed_at}
  ]}
```

Ordem dentro da lista: `number` ascendente, `id` ascendente como desempate. **O desempate não é
enfeite**: `number` repete entre repositórios, e 57 vínculos têm pai em outro repositório.

## Estados da relação — derivados, nunca gravados

| estado | quando | quantos hoje |
|---|---|---:|
| atendimento | filha promovida a tarefa, e a `sro.rule07` não é violada | 1 143 |
| violação | filha é tarefa e o pai é **épico** | 293 |
| composição | filha promovida a épico ou user story | 197 |
| a ontologia não nomeia | filha promovida a **defeito** | 33 |
| pai sem conceito | o pai existe e não foi promovido | 0 |
| sem pai | não há vínculo vigente | 2 899 issues |

**"Pai sem conceito" e "sem pai" não são o mesmo estado**, e os dois viram `nil` se alguém não tomar
cuidado — em `rule07/2` o `nil` do pai significa "não tem pai". Confundi-los faria a tela dizer *task
without parent* sobre uma issue que tem pai.
