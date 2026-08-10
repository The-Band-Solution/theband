# Quickstart — validação da feature 002

**Propósito**: provar, por execução, que a organização de cada pessoa e de cada
equipe está visível e filtrável — e que a equipe derivada nunca se passa por
observada.

O quadro atual é o ambiente de verificação: **3 organizações observadas, 72
pessoas, 10 equipes**, com o defeito medido em 0 de 72 e 0 de 10.

## Pré-requisitos

Os mesmos da feature 001. Nenhuma dependência nova.

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix phx.server
```

As três organizações já conectadas — `The-Band-Solution`, `ifesserra-lab` e
`leds-conectafapes` — bastam. Nenhuma nova precisa ser cadastrada.

## V1 — O modelo derivado passa a produzir a coluna

Antes de qualquer migração:

```bash
.venv/bin/python scripts/derive_information_model.py --ontology eo
```

| Verificar | Requisito |
|---|---|
| `eo_teams` agora traz `organization_id`, anotada como `association` | R3, contrato do modelo de informação |
| o `check_constraint` aparece, ligando a obrigatoriedade a `type` | FR-001 |
| `eo_people` **não** traz `organization_id` | F1 |
| a derivação das demais ontologias sai **idêntica** à de antes | regressão da regra nova |

A última é o teste de regressão da mudança no derivador: uma regra aditiva não
pode alterar o que já era gerado.

## V2 — O esquema volta a corresponder ao modelo

```bash
mix ecto.migrate
```

| Verificar | Requisito |
|---|---|
| `eo_people.organization_id` deixou de existir | F1 |
| `eo_teams.organization_id` existe, anulável, com o `check_constraint` | FR-001 |
| `eo_team_membership_evidence.platform_access_level` é anulável, com `check` exigindo-a para `github` | FR-006, R2 |

Conferir **antes** de migrar que as colunas removidas continuam nulas em 100% dos
registros. Estavam na análise; o plano manda reconferir.

## V3 — Retrofito sem consultar a origem (FR-023, SC-005)

Reprocessar o que já foi coletado, com o servidor no ar.

| Verificar | Requisito |
|---|---|
| as 10 equipes recebem organização | FR-023 |
| **nenhuma** chamada ao GitHub acontece — conferir no log de telemetria | SC-005 |
| o relatório diz quantas receberam e quantas ficaram sem, com o motivo | FR-024 |

O teste automático correspondente roda **sem expectativa no Mox da borda HTTP**:
qualquer chamada à origem o derruba sozinho.

## V4 — A equipe derivada aparece onde deve, e só onde deve

Disparar uma sincronização de cada organização.

| Organização | Esperado | Requisito |
|---|---|---|
| `ifesserra-lab` — 5 membros, 0 times | **1** equipe derivada, com os 5 | FR-004 |
| `leds-conectafapes` — 64 membros, 8 times | 1 equipe derivada, com os que estão fora dos 8 | FR-004 |
| `The-Band-Solution` — 6 membros, todos em times | **nenhuma** equipe derivada | FR-007 |

O terceiro caso é o que a maioria das implementações erra: criar a equipe sempre
produziria uma equipe vazia, sem referente.

## V5 — A derivada nunca se passa por observada (FR-005, FR-011, FR-017)

| Verificar | Requisito |
|---|---|
| na tela de equipes, a derivada tem selo visível | FR-017 |
| a contagem separa: "N equipes, M derivadas" | FR-011 |
| `select source_system from eo_teams` devolve `the_band` para ela | FR-005 |
| descontadas as derivadas, a contagem por organização bate com a origem | SC-010 |

A última é a verificação que importa: alguém comparando o número da plataforma
com o do GitHub tem de chegar ao mesmo, sem investigar.

## V6 — As contagens que não fecham, e estão certas (FR-019, SC-004)

| Verificar | Requisito |
|---|---|
| a soma das pessoas por organização é **maior ou igual** ao total | SC-004 |
| a diferença é exatamente o número de pessoas sobrepostas | SC-004 |
| a tela diz por que os números não somam | contrato de telas |

Sem a explicação na tela, o primeiro a somar conclui que há defeito — e o
"conserto" seria contar a mesma pessoa duas vezes.

## V7 — Filtrar por organização (FR-016, SC-002)

| Verificar | Requisito |
|---|---|
| filtrar por `leds-conectafapes` mostra só o quadro dela | FR-016 |
| a contagem do cabeçalho acompanha o filtro | FR-018 |
| combinar filtro e busca aplica os dois | US2, cenário 3 |
| filtro sem resultado diz "nada para este filtro", não "sem coleta" | FR-020 |

## V8 — Quem atravessa organizações (FR-021, SC-003)

| Verificar | Requisito |
|---|---|
| a pessoa presente em duas organizações é sinalizada, com quais | FR-021 |
| ela aparece **uma vez** na lista sem filtro | SC-003 |
| ela aparece **nas duas** listas filtradas | SC-003 |

## V9 — Nenhuma pessoa fica sem organização (SC-003a)

```sql
-- deve devolver zero
select count(*) from eo_people p
where not exists (
  select 1 from eo_team_membership_evidence e where e.person_id = p.id
);
```

É a verificação de que o caminho pela equipe ficou completo — a razão de a equipe
derivada existir.

## V10 — Isolamento entre organizações clientes (FR-022, SC-008)

Com dois tenants povoados, percorrer a interface autenticado em um. Nenhum
caminho mostra dado do outro, e o seletor de organização só lista as do próprio.

## Quality gates

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate
mix knowledge.graph
.venv/bin/python scripts/validate_knowledge_base.py
```

Todos verdes. `knowledge.validate` passa a reprovar mapeamento que declare
relação inexistente na ontologia (F6) — a validação que faltava, e sem a qual
este defeito não seria pego.

## O que esta feature NÃO prova

- **papéis organizacionais** — continuam fora; o vínculo segue sendo evidência;
- **reconciliação de identidade** — duas contas da mesma pessoa continuam dois
  registros;
- **medidas por organização** — o vínculo passa a existir; as medidas são feature
  própria;
- **hierarquia entre organizações observadas** — `parent_organization_id` existe
  no esquema e nada a preenche.
