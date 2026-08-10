# Contrato — API pública do módulo ontológico EO

**Feature**: 001 · **Fase**: 1 · **Base**: [ADR 0003](../../../docs/adr/0003-organizacao-por-ontologias.md) e R9 da [research.md](../research.md)

`TheBand.Ontology.SEON.EO` é o **único** ponto de entrada. Nenhum outro módulo
alcança os schemas, e nenhum outro módulo chama `Repo` sobre as tabelas `eo_*`.
O módulo raiz contém apenas `defdelegate`; a implementação vive em `commands/`,
`queries/` e `constraints/`.

Quem viola isso é pego em revisão porque a violação é textual: `Repo` ou
`EO.Schemas.` fora de `lib/the_band/ontology/seon/eo/`.

## Escritas

Toda escrita recebe o tenant como primeiro argumento — nunca do dicionário de
processo (constituição, princípio V).

```elixir
@spec upsert_organization_from_source(Tenant.t(), attrs :: map()) ::
        {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}

@spec upsert_person_from_source(Tenant.t(), attrs :: map()) ::
        {:ok, Person.t()} | {:error, Ecto.Changeset.t()}

@spec upsert_team_from_source(Tenant.t(), attrs :: map()) ::
        {:ok, Team.t()} | {:error, Ecto.Changeset.t()}

@spec record_team_membership_evidence(Tenant.t(), attrs :: map()) ::
        {:ok, TeamMembershipEvidence.t()} | {:error, Ecto.Changeset.t()}

@spec mark_evidence_no_longer_observed(Tenant.t(), collection_started_at :: DateTime.t()) ::
        {:ok, count :: non_neg_integer()}
```

**Correção de contrato — `mark_evidence_no_longer_observed/2`.** A primeira versão
deste documento recebia uma lista de identificadores. Está errada, e a
implementação está certa: a plataforma **não recebe evento de remoção**, ela
percebe a ausência por comparação entre coletas. Quem chama não tem como saber
quais vínculos sumiram — quem sabe é a consulta, marcando tudo que não foi
reobservado desde o início desta coleta. Passar a lista exigiria que o conector
descobrisse a ausência antes, que é justamente o que a função existe para fazer.

**`upsert_*_from_source` e não `create_*`.** Entidade ingerida não é criada por
alguém: é observada. A função recebe a proveniência junto dos atributos, resolve
a Application Reference e decide entre inserir e atualizar. Não existe
`create_person/2` público — não há caso de uso de criar pessoa à mão nesta
feature, e expor a função convidaria a criá-la sem proveniência.

**`attrs` obrigatórios em toda escrita de origem externa**:

```elixir
%{
  source_system: "github",
  source_instance: "https://github.com",
  external_id: "MDQ6VXNlcjE=",
  collected_at: ~U[2026-08-09 12:00:00Z],
  # ... atributos do conceito
}
```

Faltando qualquer um dos quatro, a função devolve `{:error, changeset}` com erro
em `:provenance`. Registro sem Application Reference é inválido, não incompleto
(constituição, princípio III).

**Idempotência**: a segunda chamada com a mesma quádrupla e os mesmos atributos
devolve `{:ok, struct}` sem escrever — `record_version` não muda. É o que SC-003
verifica.

**O struct devolvido carrega `:outcome`** — campo virtual com `:created`,
`:updated` ou `:unchanged`. É parte da interface, não detalhe interno: dele sai o
relatório de FR-028, e sem ele quem chama precisaria de uma segunda consulta só
para saber se escreveu. Virtual porque descreve **a chamada**, não o registro —
recarregar a linha do banco devolve `nil` ali, e isso está correto.

## Leituras

```elixir
@spec list_people(Tenant.t(), opts :: keyword()) :: [Person.t()]
@spec count_people(Tenant.t(), opts :: keyword()) :: non_neg_integer()

@spec list_teams(Tenant.t(), opts :: keyword()) :: [Team.t()]
@spec count_teams(Tenant.t(), opts :: keyword()) :: non_neg_integer()

@spec list_team_members(Tenant.t(), team_id :: Ecto.UUID.t(), opts :: keyword()) ::
        [%{person: Person.t(), platform_access_level: atom(), observed_at: DateTime.t()}]

@spec count_evidence_pending_role(Tenant.t(), opts :: keyword()) :: non_neg_integer()
```

**`list_*` e `count_*` aceitam exatamente as mesmas `opts` de filtro.** Não é
preferência de estilo: uma contagem que ignora o filtro que a listagem aplica
exibe "41 pessoas" acima de uma lista de 10, e o defeito é invisível até existir
uma tela.

| `opts` | Efeito | Vale em |
|---|---|---|
| `:account_type` | átomo ou lista — `"person"`, `["bot", "app"]` | `list_*` e `count_*` |
| `:search` | nome ou login, sem distinguir maiúsculas | `list_*` e `count_*` |
| `:only_observed` | `true` exclui o que já foi marcado como não mais observado | `list_*` e `count_*` |
| `:limit`, `:offset` | paginação | **só `list_*`** |
| `:team_id` | restringe a uma equipe | `count_evidence_pending_role/2` |

**Correção de contrato — `:order_by` não existe.** A primeira versão deste
documento o listava. A ordenação é fixa e não parametrizável: pessoas e equipes
saem por nome. Deixá-la aberta permitiria ordenar por coluna que a contagem
ignora, o que reintroduziria pela porta dos fundos a divergência que a regra
acima existe para impedir.

`:limit` e `:offset` são a única assimetria admitida, e ela é deliberada:
paginação recorta a **exibição**, não o conjunto. Uma contagem que respeitasse o
`:limit` devolveria sempre o tamanho da página, o que não responde nada.

**Todas recebem o tenant.** Uma função de leitura sem tenant não existe na API —
query sem filtro de tenant é bug de segurança, não de correção.

## Constraints — invariantes que o módulo impõe

Vivem em `constraints/` e são chamadas pelos changesets. Cada uma tem teste
próprio nomeado pela regra que protege.

| Invariante | Origem | O que rejeita |
|---|---|---|
| Papel de plataforma não é papel organizacional | regra `github.team_membership_evidence` | qualquer caminho que transforme `MAINTAINER`/`MEMBER` em `eo_organizational_roles` |
| Membership exige papel | `eo.team_membership` é relator de três termos | `eo_team_memberships` com `organizational_role_id` nulo |
| Equipe do GitHub é organizacional | mapeamento `github.team.to.eo.organizational_team` | `eo_teams.type = 'project_team'` sem vínculo efetivo com projeto ou repositório, ou declaração do tenant |
| Conta de automação não é pessoa | mapeamento `github.user.to.eo.person`, limitação 1 | contagem de pessoas que inclua `account_type` em `{bot, app}` |
| Identidade não se unifica por heurística | mapeamento `github.user.to.eo.person`, limitação 2 | qualquer merge de contas por nome ou e-mail semelhante |

## O que a API NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| `create_person/2`, `create_team/2` | não há caso de uso de cadastro manual nesta feature; expor convidaria a criar registro sem proveniência |
| `delete_person/2`, `delete_team/2` | ausência na origem marca `no_longer_observed_at`; a plataforma existe para preservar rastreabilidade histórica |
| `create_team_membership/2` | exige papel organizacional, que nenhuma fonte desta feature fornece |
| qualquer função que devolva `Ecto.Query` | devolver query vaza o schema interno e permite compor fora da fronteira, contornando o filtro de tenant |
| `Repo` reexportado | mesma razão |

## Contrato de erro

`{:error, %Ecto.Changeset{}}` para violação de dados. `{:error, reason}` legível
para erro de negócio — nunca `raise` genérico. O conector traduz esses retornos
em contagem de ignorados com motivo (FR-028), e não os engole.
