# Data model — PR 1: o que muda no esquema, na base de conhecimento, e o que não muda

**Feature**: 060 · **Data**: 2026-09-07 · Complementa `specs/055-equipes-declaradas/data-model.md`
(o relator, o equívoco, a composição) e `specs/045-autenticacao-e-acesso/data-model.md` (escopos).

## 1. `eo_team_memberships` — a saída declarada e a data da declaração (FR-010, FR-015, FR-021, FR-022)

### Colunas novas

| Coluna | Tipo | Nulo | Significado | Quem escreve |
|---|---|---|---|---|
| `declared_at` | `utc_datetime` | sim | **quando** a declaração (papel + autor) foi feita — o "em D" de "declarado por X em D" | `allocate/2` quando `declared_by_user_id` entra; `declare_team_membership/5`; `change_role/5` |
| `ended_by_user_id` | `binary_id` FK `users` (restrict) | sim | **quem** declarou a saída. Nulo com `ended_at` preenchido = fim **constatado pela coleta** | `record_team_departure/5`, `end_allocation/4` |
| `end_declared_at` | `utc_datetime` | sim | **quando** a saída foi declarada — distinto de `ended_at`, que é a data em que a pessoa saiu | os mesmos dois comandos |

**Por que três colunas e não duas**: `ended_at` é a data **da saída** (informada por quem
declara, podendo ser retroativa); `end_declared_at` é o instante **do registro**. Colapsá-las
faria "saiu em março, declarado em setembro" virar "saiu em setembro" — e a medida do período
anterior mudaria, que é justamente o que SC-001 proíbe.

### CHECK constraints

| Nome | Regra | Por quê |
|---|---|---|
| `eo_saida_declarada_completa` | `(ended_by_user_id IS NULL AND end_declared_at IS NULL) OR (ended_by_user_id IS NOT NULL AND end_declared_at IS NOT NULL AND ended_at IS NOT NULL)` | autor e instante andam juntos, e só existem sobre uma saída que existe. Modelo: `eo_equivoco_do_vinculo_completo` (migração `20260901230000:104-112`) |
| `eo_declaracao_tem_autor` | `(declared_by_user_id IS NULL AND declared_at IS NULL) OR (declared_by_user_id IS NOT NULL AND declared_at IS NOT NULL)` | "declarado por X" sem "em D" é meia proveniência |

O CHECK é do **banco**, não só do changeset: o changeset protege a tela; o CHECK protege a
migração, o `update_all` e o script avulso.

### Backfill

```sql
UPDATE eo_team_memberships
   SET declared_at = inserted_at
 WHERE declared_by_user_id IS NOT NULL AND declared_at IS NULL;
```

Nada é inventado para `ended_by_user_id`: os fins que existem hoje **não têm autor**, e é
verdade que não têm — foram constatados pela coleta (`encerrar_vinculos_observados/3`) ou
declarados por um comando que não guardava quem. A tela diz "author not recorded" (FR-022).

### O que a vigência continua sendo

`vigente = ended_at IS NULL AND invalidated_at IS NULL`. As colunas novas **não** entram na
definição de vigência nem nos índices parciais existentes
(`eo_team_memberships_vigente_index`, `eo_team_memberships_observado_vigente_index`) — são
proveniência, não estado.

## 2. `eo_role_structure_management_grants` — a concessão de gestão (FR-080 a FR-082)

Espelho de `eo_role_visibility_grants` (migração `20260827060000`), com o verbo trocado.

| Coluna | Tipo | Nulo | Significado |
|---|---|---|---|
| `id` | `binary_id` PK | não | |
| `tenant_id` | `binary_id` | não | multitenant (princípio V) |
| `organizational_role_id` | `binary_id` FK `eo_organizational_roles` | não | a concessão é **do papel**, nunca da conta |
| `scope` | `string` | não | `team` \| `organization` |
| `declared_by_user_id` | `binary_id` FK `users` | não | quem concedeu |
| `declared_at` | `utc_datetime` | não | quando |
| `revoked_by_user_id` | `binary_id` FK `users` | sim | quem revogou |
| `revoked_at` | `utc_datetime` | sim | quando — **revogar é marcar, nunca apagar** |

**Índice parcial** `eo_concessao_de_gestao_vigente_index` em
`(tenant_id, organizational_role_id, scope) WHERE revoked_at IS NULL`: uma concessão vigente por
papel e alcance. A segunda é recusada pelo **banco**, e o changeset a traduz com
`unique_constraint`.

### O veredito e os seus motivos

`Tenants.pode_gerir_estrutura(tenant, user, team_id)` devolve relator, nunca booleano:

| Retorno | Quando |
|---|---|
| `{:ok, :admin}` | conta administradora do mesmo tenant |
| `{:ok, :gestor_da_equipe}` | vínculo vigente com papel cuja concessão vigente tem `scope: "team"` **nesta** equipe |
| `{:ok, :gestor_da_organizacao}` | idem com `scope: "organization"` na organização desta equipe |
| `{:nao, :conta_sem_pessoa_declarada}` | a conta não tem elo com pessoa (`users.person_id` nulo) |
| `{:nao, :vinculo_encerrado}` | existe vínculo **encerrado ou invalidado** com papel que alcançaria, e nenhum vigente |
| `{:nao, :sem_concessao}` | nenhum papel vigente da pessoa tem concessão que alcance esta equipe |

A tela traduz cada motivo numa frase (FR-006, SC-011). Esconder o botão não é autorização: o
evento re-pergunta.

## 3. Base de conhecimento

### 3.1 Módulo novo `ontology/seon/eo/modules/role_grants.yaml`

Declara **as duas** concessões — a de visibilidade, que existe no código desde a #369 e nunca foi
declarada, e a de gestão, nova. Declarar as duas juntas fecha a lacuna em vez de dobrá-la. A
categoria UFO é proposta deste plano (pergunta aberta 4).

```yaml
module:
  id: eo.role_grants
  ontology: eo
  name: Role Grants
  version: 1.0.0
  description:
    pt-BR: >
      O que um papel organizacional PERMITE na plataforma — ver o painel de trabalho de quem, e
      gerir a estrutura de qual equipe. Não é conceito da EO de referência: é a declaração
      adjacente, no mesmo lugar ontológico de spo.activity_start_criterion. A concessão é POR
      PAPEL e nunca inferida do nome dele; tem autor, data e revogação por marca.
  provenance:
    source_type: project_decision
    reference: "Issue #369 (visibilidade, 2026-08-26); spec 045 FR-022; spec 060 FR-080–082 (gestão, decisão da pessoa mantenedora em 2026-09-07)"
    year: 2026
    note: >
      A concessão de visibilidade existia no código (eo_role_visibility_grants) sem estar
      declarada na base — lacuna herdada. Declarar as duas juntas fecha a lacuna.

concepts:
  - id: eo.role_visibility_grant
    name: Role Visibility Grant
    label: { pt-BR: "Concessão de visibilidade por papel", en: "Role Visibility Grant" }
    definition:
      pt-BR: >
        Declaração de que quem desempenha um papel organizacional, com vínculo vigente, alcança o
        painel de trabalho das pessoas da sua equipe (alcance team) ou da sua organização
        (alcance organization). Persistida em eo_role_visibility_grants.
    classification: { ufo_category: normative_description, ontouml_stereotype: kind }
    attributes:
      - { name: scope, type: enum, values: [team, organization], required: true }
      - { name: declared_at, type: datetime, required: true }
      - { name: revoked_at, type: datetime, required: false }

  - id: eo.role_structure_management_grant
    name: Role Structure Management Grant
    label: { pt-BR: "Concessão de gestão da estrutura por papel", en: "Role Structure Management Grant" }
    definition:
      pt-BR: >
        Declaração de que quem desempenha um papel organizacional, com vínculo vigente, pode
        declarar a estrutura de uma equipe — papel de cada pessoa, saída, equívoco, composição,
        papéis da organização, ligação a projeto — nas equipes em que tem o papel (team) ou em
        todas as da organização (organization). Administrar a plataforma continua sendo outra
        coisa: a administradora age sem concessão; ninguém mais age sem ela.
        Persistida em eo_role_structure_management_grants.
    classification: { ufo_category: normative_description, ontouml_stereotype: kind }
    attributes:
      - { name: scope, type: enum, values: [team, organization], required: true }
      - { name: declared_at, type: datetime, required: true }
      - { name: revoked_at, type: datetime, required: false }

relations:
  - id: eo.visibility_grant_to_role
    name: granted to
    source: eo.role_visibility_grant
    target: eo.organizational_role
    type: association
    cardinality: { source: many, target: one }
  - id: eo.structure_management_grant_to_role
    name: granted to
    source: eo.role_structure_management_grant
    target: eo.organizational_role
    type: association
    cardinality: { source: many, target: one }
```

E em `eo/ontology.yaml`: `modules: [organizational_structure, role_grants]`.

**Por que `normative_description`/`kind` e não `relator`**: um relator reifica a relação entre dois
indivíduos; aqui o segundo lado é um **nível** (`team`|`organization`), não um indivíduo. A
concessão é uma norma declarada sobre o que o papel pode, com identidade própria (autor, data,
revogação). A revisão semântica decide.

### 3.2 Regra emendada `rules/github_team_membership_evidence.yaml` → `version: 3`

Acrescenta, em `materializes[eo.team_membership].note` e em `observed_link.promotion.note`:

> Depois de uma **saída declarada** (`ended_by_user_id`) ou de um **equívoco**
> (`invalidated_at`) sobre o vínculo observado, a coleta **não recria** o vínculo enquanto a
> observação da origem for **contínua** (a evidência sem `no_longer_observed_at`). Uma observação
> **nova** depois de ausência constatada é retorno, e nasce vínculo observado novo; os períodos
> coexistem. Decisão da pessoa mantenedora em 2026-09-07 (spec 060 FR-026, FR-027).

## 4. Estruturas derivadas (não persistidas)

### 4.1 A linha do roster (`EO.list_team_roster/3`)

```text
%{
  person_id, name, login,
  situacao: :vigente | :saiu | :equivoco,        # por pessoa, agregado (FR-012)
  vinculos: [
    %{
      membership_id, team_id, team_name, direta?: boolean,   # direta? = team_id da tela
      role: %{id, code, name} | nil,                          # nil = "not declared"
      origem: :observado | :declarado,                        # declared_by_user_id nulo/preenchido
      declared_by: email | nil, declared_at,
      started_at,                                             # nil = "unknown"
      fim: nil | {:declarado, por, em, quando} | {:coleta, quando} | {:sem_autor, quando},
      equivoco: nil | %{razao, por, em}
    }
  ]
}
```

Regras de leitura: pessoa aparece **uma** vez (FR-009); `situacao` = `:vigente` se algum vínculo é
vigente; `:equivoco` se **todos** são invalidados (mesma regra de `membership_disagreements/2`);
`:saiu` nos demais casos. Chips de subequipe = `team_name` dos vínculos vigentes em partes;
`direct` quando `direta?`.

### 4.2 Totais do cabeçalho (`EO.team_roster_totals/2`)

`%{vigentes: n, sairam: n, equivocos: n}` — por **pessoa**, com a mesma definição de 4.1. Os três
números **batem com a consulta** porque saem da mesma agregação (FR-012).

### 4.3 Contagens por papel (`EO.role_holder_counts/3`)

`%{role_id => %{nesta_equipe: n, na_organizacao: n}}` — pessoas **distintas** com vínculo vigente;
papel do catálogo sem linha (`id: nil`) tem `0/0` por construção.

## 5. O que NÃO muda

| Tabela / conceito | Por quê |
|---|---|
| `eo_team_membership_evidence` | continua sendo o que a origem mostrou; só deixa de alimentar a lista |
| `eo_team_compositions` | `started_at` obrigatório e igual a agora — muda na PR 2 (FR-037) |
| `eo_organizational_roles` | o comando é o mesmo (`create_role/4`); muda o lugar de onde é chamado |
| `eo_role_visibility_grants` | ganha **declaração na base**; a tabela e o código não mudam |
| `access_scope_grants` | escopos de **conta** continuam decidindo **visão**; deixam de decidir **escrita** na estrutura (D6) |
| `eo.team_membership` (YAML) | atributos novos são proveniência da declaração, não semântica do relator |
| `spo_project_teams` | `linked_at`/`unlinked_at` como estão; a escrita muda de aba |
