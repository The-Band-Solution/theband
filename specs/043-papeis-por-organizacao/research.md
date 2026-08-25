# Research: Papéis por organização

**Feature**: 043 · **Data**: 2026-08-24

Tudo medido no banco e no código, não estimado.

---

## R1 — A cadeia parada, e onde exatamente ela para

```
12  equipes
101 evidências de vínculo
  0 vínculos
  0 papéis organizacionais
```

`eo_team_memberships.organizational_role_id` é **`NOT NULL`** — conferido em
`information_schema`.

**Para no primeiro elo.** Não é a promoção que falta: é o papel, sem o qual a promoção é
impossível. Qualquer tentativa de promover hoje falharia na constraint.

**Consequência**: quatro das cinco medidas declaram `team` e nenhuma calcula. É a razão de
o nível Equipe dos painéis estar vazio, medido na proposta de dashboards de 2026-08-24.

---

## R2 — O nível de acesso já é recusado como papel, e antes desta feature

`EO.Constraints.platform_access_level_is_not_a_role/1` existe desde a feature 021:

```elixir
@platform_access_levels ~w(MAINTAINER MEMBER)
```

E o `@moduledoc` dá a justificativa que eu não teria escrito melhor:

> `MAINTAINER` e `MEMBER` dizem quem pode gerir membros e permissões do time; não dizem se a
> pessoa é programadora, testadora, designer ou gerente. Promovê-los a papel produziria um
> catálogo que não corresponde a função nenhuma, e faria **CQ12, CQ14 e CQ16 devolverem
> resposta falsa em vez de nenhuma**.

**Esta feature não cria a regra.** Ela impede que a tela a contorne, exibindo o valor onde a
decisão acontece.

### Os valores reais, e a correção de um erro meu

A primeira versão da spec citava `ADMIN`, `WRITE`, `READ`. **São permissões de repositório**,
não de vínculo de equipe. Medido:

| valor | evidências |
|---|---:|
| `MEMBER` | 63 |
| nulo | 33 |
| `MAINTAINER` | 5 |

O erro importava: a `SC-005a` manda procurar esses valores no HTML e exigir zero. Com o valor
errado, o teste **passaria por vacuidade** — daria zero porque `ADMIN` nunca esteve lá.

**E os três afirmam a mesma coisa**: que a pessoa é membro da equipe. As 33 com nível nulo
sustentam a promoção como as outras 68 — o que confirma que o nível é, ali, perigoso **e
inútil**.

---

## R3 — O catálogo tem forma pronta na casa

`Mapping.Catalog.list_proposals/2` compõe entradas de catálogo com as regras da organização,
e calcula um `state` por entrada. As entradas **não são linhas**: a linha nasce ao ativar.

E `MappingRule` distingue as duas origens por `catalog_key` nulável — presente significa que
veio do catálogo, nulo que alguém escreveu.

**Decisão**: reusar a forma. `catalog_concept_id` nulável em `eo_organizational_roles`, com o
identificador da SRO — `sro.scrum_master_role` — quando o papel vier do catálogo.

**O que NÃO se reusa**: o passo de ativação. Ver a decisão 4 do plano.

---

## R4 — Os quatro papéis estão na SRO, e a plataforma já os lê

`priv/knowledge_base/ontology/continuum/sro/modules/scrum_stakeholders.yaml`:

| conceito | |
|---|---|
| `sro.product_owner_role` | filho de `sro.scrum_role` |
| `sro.scrum_master_role` | idem |
| `sro.developer_role` | idem |
| `sro.client_role` | idem |

`EO.suggested_roles/0` já os deriva do YAML, filtrando por
`classification.parent == "sro.scrum_role"` — e o comentário do código diz *"os quatro que
herdam de `sro.scrum_role`, e não o próprio, que é o pai abstrato"*.

**O que muda**: deixam de ser sugestão de preenchimento e passam a estar **disponíveis** para
uso, sem cadastro.

**Consequência não trivial**: se a SRO ganhar um quinto filho de `sro.scrum_role`, ele
aparece em todas as organizações na leitura seguinte. Com composição isso é de graça; com
semeadura exigiria migração. É o argumento decisivo da decisão 1.

---

## R5 — O índice que bloqueia, e que eu só vi ao escrever o requisito de papel múltiplo

```sql
eo_organizational_roles_tenant_id_code_index
  UNIQUE (tenant_id, code)
```

Com o catálogo em todas as organizações, a **segunda** a materializar `scrum_master` bate na
constraint. **O cadastro por organização é impossível sem trocar isto.**

Apareceu ao conferir se o esquema suportava uma pessoa com vários papéis — suportava, porque
`eo_team_memberships_vigente_index` inclui `organizational_role_id` na chave. O papel múltiplo
já funcionava; o cadastro por organização não.

---

## R6 — Onde `platform_access_level` continua aparecendo

| tela | mostra? | por quê |
|---|---|---|
| `/teams/:id`, coluna *access at the platform* | **sim** | é fato sobre a ferramenta, e a tela é de observação |
| `/people/:id`, equipes da pessoa | **sim** | idem |
| **promoção de evidência** | **não** — `FR-011` | é onde a decisão de papel acontece |

A distinção é o lugar, não o dado. Remover a coluna perderia fato verdadeiro; exibi-la ao
lado de um seletor de papel a transforma em dica.
