# Contrato — acréscimos à API pública de EO

**Feature**: 002 · Complementa [o contrato da feature 001](../../001-github-eo-ingestion/contracts/ontology-eo.md), que continua valendo.

Escrito antes da implementação, conforme o princípio VI.

## Escritas

```elixir
@spec upsert_derived_team(Tenant.t(), organization :: Organization.t(), attrs :: map()) ::
        {:ok, Team.t()} | {:error, Ecto.Changeset.t()}

@spec record_derived_team_membership(Tenant.t(), attrs :: map()) ::
        {:ok, TeamMembershipEvidence.t()} | {:error, Ecto.Changeset.t()}
```

`upsert_derived_team/3` recebe a **organização já persistida**, e não o seu
identificador externo, porque a equipe derivada só existe em função dela: sem
organização não há o que derivar, e passar o struct torna isso um erro de
compilação em vez de um `nil` descoberto no banco.

A proveniência é montada pela própria função — quem chama **não** decide
`source_system` nem `external_id`. Deixar isso aberto permitiria gravar uma
equipe derivada como se fosse observada, que é o único jeito de esta feature
mentir.

## Leituras

```elixir
@spec list_organizations(Tenant.t(), opts :: keyword()) :: [Organization.t()]

@spec list_people(Tenant.t(), opts :: keyword()) :: [Person.t()]
@spec count_people(Tenant.t(), opts :: keyword()) :: non_neg_integer()

@spec list_teams(Tenant.t(), opts :: keyword()) :: [Team.t()]
@spec count_teams(Tenant.t(), opts :: keyword()) :: non_neg_integer()

@spec list_person_organizations(Tenant.t(), person_id :: Ecto.UUID.t()) :: [Organization.t()]
@spec list_people_in_several_organizations(Tenant.t(), opts :: keyword()) ::
        [%{person: Person.t(), organizations: [Organization.t()]}]
```

`opts` novas, válidas em `list_*` **e** em `count_*`, como as existentes:

| `opts` | Efeito |
|---|---|
| `:organization_id` | restringe à organização observada; para pessoas, atravessa as equipes |
| `:origin` | `:observed` \| `:derived` \| `:all` (padrão). Lê `source_system` |

`:limit` e `:offset` continuam sendo a única assimetria admitida entre listagem e
contagem — paginação recorta a exibição, não o conjunto.

**`list_people/2` com `:organization_id` continua devolvendo cada pessoa uma
vez**, ainda que ela esteja em duas equipes daquela organização. A distinção é
por pessoa, não por vínculo.

## Constraints — invariantes novas

| Invariante | O que rejeita |
|---|---|
| Equipe derivada declara-se derivada | `source_system = 'github'` em equipe cujo `external_id` tem prefixo `derived:` |
| Equipe derivada exige organização | equipe derivada sem `organization_id` |
| Vínculo derivado não tem nível de acesso | `platform_access_level` preenchido em vínculo com `source_system <> 'github'` |
| Vínculo observado exige nível de acesso | `platform_access_level` nulo em vínculo com `source_system = 'github'` |
| Equipe organizacional exige organização | `type = 'organizational_team'` sem `organization_id` |

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| `link_person_to_organization/3` | não existe vínculo direto. A organização vem das equipes, e expor a função convidaria a criar o segundo caminho que a spec rejeitou |
| `delete_derived_team/2` | equipe derivada que esvazia é marcada como não mais observada, nunca apagada. Ela existiu, e isso é informação |
| `create_team/2` com proveniência livre | permitiria gravar equipe derivada como observada; é o único jeito de esta feature produzir dado falso |
| `list_teams/2` sem distinguir origem por padrão | **exceção deliberada**: o padrão é `:all`, porque a pergunta mais comum é "quais equipes existem". Quem compara com o GitHub usa `:observed`, e a interface diz qual está vendo |
