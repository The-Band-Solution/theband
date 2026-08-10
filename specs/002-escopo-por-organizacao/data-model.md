# Modelo de dados — Fase 1

**Feature**: 002 · **Data**: 2026-08-10
**Depende de**: [plan.md](plan.md) · [research.md](research.md) · [ontology-analysis.md](ontology-analysis.md) · [ADR 0004](../../docs/adr/0004-modelo-de-informacao-one-table-per-kind.md)

**Nenhuma tabela nova.** A feature corrige o esquema existente e o traz de volta
para o que a derivação produz.

## O que muda no modelo derivado

Depois de declarar a relação `eo.organizational_team_belongs_to_organization` e
de acrescentar a regra de associação ao derivador, a saída de
`derive_information_model.py --ontology eo` passa a incluir:

```text
┌─ eo_teams   (eo.team, kind)
│    type                enum   NOT NULL  {organizational_team, project_team}
│    organization_id     uuid   NULL      → FK (association)
└─    check: organization_id IS NOT NULL OR type <> 'organizational_team'
```

A FK é **anulável** porque a relação parte do subkind `organizational_team`, e
`project_team` liga-se a projeto, não a organização. A obrigatoriedade é do
subkind, e vive no `check_constraint` — ver [research.md](research.md), R3.

## O que sai do esquema

| Coluna | Por quê |
|---|---|
| `eo_people.organization_id` | **semanticamente errada**: a pessoa pertence a várias organizações, e a coluna alternaria de valor a cada coleta. Além disso nunca existiu no modelo derivado |
| `eo_teams.organization_id` (a atual) | escrita à mão na feature 001, contra a ADR 0004 D4. É recriada pela derivação, agora com lastro na ontologia e com o `check_constraint` |

Ambas estão **nulas em 100% dos registros** — conferido: 0 de 72 pessoas e 0 de
10 equipes. Remover é seguro, e o plano reconfere antes de migrar.

## O que muda em `eo_team_membership_evidence`

| Coluna | Antes | Depois |
|---|---|---|
| `platform_access_level` | `NOT NULL` | **anulável** |
| — | — | `check`: obrigatório quando `source_system = 'github'` |

O vínculo derivado não tem nível de acesso porque a origem não conhece o vínculo.
Ausência é nula, nunca zero; gravar `MEMBER` para manter a coluna obrigatória
afirmaria o que a origem não afirma.

O `unique_index` da Application Reference não muda — ele já inclui
`source_system`, então o vínculo observado e o derivado da mesma pessoa na mesma
equipe seriam linhas distintas. Não ocorre por construção: uma pessoa só entra na
equipe derivada se estiver fora de todas as observadas.

## A equipe derivada

Não é tipo novo nem tabela nova: é uma linha de `eo_teams` cuja proveniência
aponta para a derivação.

| Coluna | Equipe observada | Equipe derivada |
|---|---|---|
| `type` | `organizational_team` | `organizational_team` |
| `name` | nome do time no GitHub | **nome da organização** |
| `slug` | slug do time | slug da organização |
| `organization_id` | FK da organização | FK da organização |
| `source_system` | `github` | **`the_band`** |
| `source_instance` | `https://github.com` | `https://github.com` |
| `external_id` | id do time | **`derived:default_team:<external_id da organização>`** |
| `collected_at` | instante da coleta | instante da coleta que a derivou |

**É `source_system` que distingue observada de derivada.** Nenhuma coluna nova
foi criada para isso — a que responde já existe, por exigência do princípio III.

```text
observadas   where source_system = 'github'
derivadas    where source_system <> 'github'
```

## Relações resultantes

```text
eo_organizations
      ▲
      │ organization_id  (FK, anulável, obrigatória para organizational_team)
      │
   eo_teams ──────────────┐
      ▲                   │ observadas (source_system = github)
      │ team_id           │ derivadas  (source_system = the_band)
      │
eo_team_membership_evidence
      │ person_id
      ▼
   eo_people
```

**Não existe aresta entre `eo_people` e `eo_organizations`.** A organização de
uma pessoa é lida percorrendo as equipes dela — e a equipe derivada garante que
toda pessoa tenha ao menos uma.

## Regras de validação, por requisito

| Requisito | Onde é imposto |
|---|---|
| FR-001 | `check_constraint` gerado: `organization_id` obrigatória quando `type = 'organizational_team'` |
| FR-002 | o `unique_index` da Application Reference já distingue equipes por `external_id`; slugs iguais em organizações diferentes são ids diferentes |
| FR-003 | consulta que parte de `eo_team_membership_evidence` e chega a `eo_teams.organization_id` |
| FR-004, FR-007 | avaliado ao fim da coleta; sem membro de fora, nenhuma equipe é criada |
| FR-005 | `source_system = 'the_band'` e `external_id` com prefixo `derived:` |
| FR-006 | `platform_access_level` nula, com `check_constraint` exigindo-a só para `github` |
| FR-008 | `observed_at`, `last_observed_at`, `no_longer_observed_at` — já existem |
| FR-009, FR-010 | inalterado: a identidade continua sendo a Application Reference |
| FR-011, FR-017 | contagens e telas filtram por `source_system` |
| FR-019 | contagem total usa `distinct` sobre a pessoa; por organização, conta em cada uma |
| FR-023 | retrofito percorre `raw_payloads → syncs → connected_tools.organization_login` |

## Transições de estado

**Equipe derivada**: criada quando há membro fora das equipes observadas →
marcada `no_longer_observed_at` quando deixa de ter integrantes → **nunca
apagada**. Uma equipe que existiu e esvaziou é informação.

**Vínculo derivado de pessoa a equipe**: a pessoa que entra numa equipe observada
sai da derivada na coleta seguinte, e o vínculo anterior fica marcado como não
mais observado.
