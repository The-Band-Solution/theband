# Feature 032 — Plano

**Spec**: [spec.md](spec.md) · **Mapeamentos**: `github.pull_request.to.cmpo.change_request`,
`github.commit.to.cmpo.commit_artifact_copy` · **Relações**: `cmpo.change_traceability`,
`sro.scope_traceability`

## O banco

Duas tabelas novas e duas de vínculo. Nomes seguem a camada de plataforma
(`collected_*`), como issues e comentários — o conceito ontológico fica no mapeamento, e
a tabela guarda a nota como a origem entregou.

```
collected_change_requests                    -- cmpo.change_request
  id, tenant_id, observed_repository_id (FK)
  number, title, body, state                 -- OPEN | CLOSED | MERGED
  source_branch, target_branch               -- cmpo.source_branch / target_branch
  changed_files
  author_login, author_person_id             -- quem submeteu (FR-002)
  merged_by_login, merged_by_person_id       -- quem integrou (FR-002)
  external_created_at, external_merged_at, external_closed_at
  source_system, source_instance, external_id (único por tenant)
  raw_payload
  collected_at, last_observed_at, no_longer_observed_at

collected_commits                            -- cmpo.commit_artifact_copy
  id, tenant_id, observed_repository_id (FK)
  sha (natural key com repositório), message_headline, message_body
  additions, deletions, changed_files
  external_committed_at
  source_system, source_instance, external_id (= sha do node GraphQL)
  raw_payload
  collected_at, last_observed_at, no_longer_observed_at

commit_authors                               -- cmpo.stakeholder_performed_commit
  id, tenant_id, collected_commit_id (FK)
  author_login, author_person_id, author_name, author_email
  is_primary                                 -- o autor do Git × co-autores do trailer
  collected_at, last_observed_at, no_longer_observed_at

change_request_issues                        -- sro.change_request_attends_*
  id, tenant_id, collected_change_request_id (FK), collected_issue_id (FK)
  source                                     -- "closing_reference" (só isso, por ora)
  collected_at, last_observed_at, no_longer_observed_at
```

E `collected_commits.change_request_id` (nullable, FK) — `cmpo.commit_accomplished_change_request`,
com `zero_or_one` no destino porque commit fora de solicitação é representável.

**Por que `commit_authors` é tabela e não coluna**: a relação declarada tem cardinalidade
`many` na origem, e no dado real **todo** commit tem dois autores. Coluna faria o modelo
mentir; e `is_primary` preserva a distinção entre quem o Git registra como autor e quem
entrou pelo trailer `Co-Authored-By` — são fatos diferentes sobre a mesma mudança.

**`author_email` não vai para tela**: é dado pessoal. Fica no banco porque é a única
identificação de quem não tem conta no GitHub, e a limitação está no mapeamento.

Checkpoint por repositório: `changes_collected_at` em `observed_repositories`, ao lado de
`issues_collected_at` e `comments_collected_at`.

## A coleta

**Uma consulta, dois níveis.** `priv/connectors/github/queries/change_requests.graphql`
traz PRs paginados por repositório, e **os commits de cada PR aninhados** — porque é assim
que o volume fica administrável e o rastro se mantém:

```
repository.pullRequests(first: 25, orderBy: {field: UPDATED_AT, direction: DESC})
  number title bodyText state createdAt mergedAt closedAt changedFiles
  headRefName baseRefName
  author { login ... on User { id } }
  mergedBy { login ... on User { id } }
  closingIssuesReferences(first: 10) { totalCount nodes { id number } }
  commits(first: 50) { totalCount nodes { commit {
    oid messageHeadline messageBody committedDate additions deletions
    authors(first: 5) { nodes { name email user { login id } } }
  } } }
```

**O incremental é por `updatedAt` e para cedo**: a ordenação é decrescente, então a
paginação encerra no primeiro PR mais antigo que o checkpoint — não percorre o histórico
inteiro a cada passada. É diferente da coleta de comentários (que filtra por `since` na
origem) porque `pullRequests` não aceita filtro de data; parar cedo é o equivalente.

`totalCount` em `closingIssuesReferences` e em `commits` contra o que chegou: truncamento
nunca silencioso, e com página incompleta o sumiço não é marcado.

Ingestão em `lib/the_band/ingestion/github_change_requests.ex`, fase nova depois das
issues (a FK de `change_request_issues` precisa da issue gravada — L47: lê da base, não da
memória da fase anterior).

## A leitura

`lib/the_band/changes/` — contexto novo (princípio X: mudança não é work item):

- `Changes.for_issue(tenant, issue_id)` — as solicitações que atendem uma issue, com quem
  abriu e quem integrou; 1 consulta;
- `Changes.get(tenant, id)` + `Changes.commits_of(tenant, change_id)` — o detalhe da
  solicitação com seus commits e autores; 2 consultas;
- `Changes.by_person(tenant, person_id)` — três listas nunca somadas: abertas, integradas,
  commits executados; 1 consulta agregada por lista, e a de commits inclui co-autoria via
  `commit_authors`.

## As telas

1. **Detalhe da issue** (`/work/issues/:id`) — seção "Change requests": número, título,
   estado, quem abriu, quem integrou. Os **dois vazios distintos** (FR-006), decididos por
   `changes_collected_at` do repositório.
2. **Detalhe da solicitação** (`/work/changes/:id`, rota nova) — os commits que a
   realizaram, cada um com **todos** os autores e a marca de co-autoria; as issues que ela
   atende; as branches.
3. **Página da pessoa** (`/people/:id`) — seção "Changes": três leituras separadas
   (abriu / integrou / executou), nunca somadas, com a de commits mostrando quando a pessoa
   é co-autora e não autora principal.

## Fases

| fase | entrega | prova |
|---|---|---|
| F1 | migração + 4 schemas | migração sobe e desce |
| F2 | consulta GraphQL + ingestão + fase de sync | coleta real, totais contra a API (SC-001) |
| F3 | `Changes` (leitura) | testes + contador de consultas (SC-003) |
| F4 | seção na issue | teste LiveView + ao vivo |
| F5 | tela da solicitação | teste + rastreio completo ao vivo (SC-002) |
| F6 | seção na pessoa, com co-autoria | teste + SC-004 no dado real |

## Riscos

- **Volume**: 121 repositórios, milhares de PRs. A primeira coleta é longa; medir e
  registrar, como foi feito com os comentários (2.013 em 259s).
- **Rate limit**: a consulta aninhada custa mais que a de comentários. `rateLimit`
  declarado, e a medida da primeira execução vai para o backlog.
- **PR sem `closingIssuesReferences`**: comum, e não é erro — é PR que não fecha issue.
  A tela precisa dizer isso sem parecer falha.
