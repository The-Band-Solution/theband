# Data Model: Papéis por organização

**Feature**: 043 · **Data**: 2026-08-24

Nenhuma tabela nova. Duas colunas e um índice.

---

## `eo_organizational_roles` — o que muda

| coluna | estado | o que é |
|---|---|---|
| `tenant_id` | existe | |
| **`organization_id`** | **nova, `NOT NULL`** | a organização dona do papel — `FR-001` |
| **`catalog_concept_id`** | **nova, nulável** | `sro.scrum_master_role` quando vem do catálogo; nulo quando declarado — `FR-003` |
| `code`, `name` | existem | |
| **`declared_by_user_id`** | **nova, nulável** | quem declarou — `FR-005`. Nulo quando `catalog_concept_id` está preenchido |
| **`hidden_at`** | **nova, nulável** | papel do catálogo ocultado desta organização — `FR-004` |

### O índice, que é o bloqueio

```sql
-- antes: UNIQUE (tenant_id, code)
--   a SEGUNDA organização a materializar `scrum_master` bate na constraint

DROP INDEX eo_organizational_roles_tenant_id_code_index;
CREATE UNIQUE INDEX ON eo_organizational_roles (tenant_id, organization_id, code);
```

Perde-se a unicidade por tenant. **É deliberado**: a `FR-006` diz que dois papéis de mesmo
código em organizações diferentes são papéis diferentes.

### A regra de origem

```sql
-- do catálogo: tem conceito, não tem autor
-- declarado:   tem autor, não tem conceito
CHECK (num_nonnulls(catalog_concept_id, declared_by_user_id) = 1)
```

Sem isto, um papel poderia afirmar as duas origens — e a `FR-003` exige que a origem seja
visível e única.

---

## O catálogo, que não é tabela

Os quatro papéis da SRO **não são linhas** até serem usados. `EO.RoleCatalog.list/2` compõe:

```
para cada conceito filho de sro.scrum_role:
  procura linha desta organização com catalog_concept_id = o conceito
    achou      → devolve a linha, com id
    não achou  → devolve a entrada do catálogo, SEM id, marcada disponível
```

E a materialização acontece **na primeira promoção que usar o papel**:

```
promover(evidência, papel_do_catálogo):
  1. materializa a linha, com on_conflict: :nothing sobre o índice único
  2. relê para pegar o id — inclusive quando outro processo a criou
  3. cria o vínculo apontando para ela
```

O `on_conflict` cobre a corrida de duas promoções simultâneas com o mesmo papel. Transação
serializável seria cara para um caso que acontece raramente e cujo desfecho correto é
*"use a linha que já existe"*.

---

## `eo_team_memberships` — o que **não** muda

```sql
eo_team_memberships_vigente_index
  UNIQUE (tenant_id, person_id, team_id, organizational_role_id, ...)
```

**O papel já está na chave.** Uma pessoa com Product Owner e Developer na mesma equipe são
duas linhas, e o mesmo papel repetido já é recusado — `FR-006a` e `FR-006b` **já funcionam**.

O que esta feature acrescenta é a `FR-006c`, que é de **leitura**:

> Toda contagem de pessoas por equipe conta **pessoas distintas**, nunca vínculos.

Uma pessoa com dois papéis é **uma** pessoa na equipe. Somar vínculos faria a equipe parecer
maior — erro que passa despercebido porque o número fica plausível.

### A constraint que falta

```
o papel do vínculo tem de ser da MESMA organização da equipe — FR-008
```

Não é expressável em `CHECK` (envolve duas tabelas), então é validação de changeset, com
teste próprio. `eo_teams` já tem `organization_id`; `eo_organizational_roles` passa a ter.

---

## `eo_team_membership_evidence` — o que não muda

Nada. As 101 linhas ficam como estão, `platform_access_level` incluído.

O que muda é **onde ele aparece**: sai da tela de promoção (`FR-011`), continua em
`/teams/:id` e `/people/:id`, onde é fato sobre a ferramenta e não decisão sobre papel.

`promoted_membership_id` já existe e passa a ser preenchido — hoje é nulo em 100%.

---

## O que esta feature NÃO acrescenta

- **Nenhuma tabela.** Nem de catálogo, nem de estado de ativação.
- **Nenhuma coluna em `eo_team_memberships`.** O que ela precisa já tem.
- **Nenhum conceito na rede.** Os quatro papéis já estão na SRO; nenhuma relação nova é
  declarada, e por isso EO **não** ganha dependência de SRO — princípio IX.
