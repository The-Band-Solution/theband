# Feature 030 — Plano

**Spec**: [spec.md](spec.md) · **Mapeamento**: `priv/knowledge_base/mappings/github/cmo/issue_comment.yaml` (escrito e validado) · **Ontologia**: `priv/knowledge_base/ontology/continuum/cmo/` (escrita e validada)

## Decisões técnicas

### 1. Esquema: `collected_issue_comments`, no padrão da casa

Mesmo formato de `collected_issues` — nota como a origem entregou, com proveniência:

```
collected_issue_comments
  id, tenant_id, collected_issue_id (FK)
  body (text plano — bodyText), author_login, author_person_id (nullable)
  external_published_at, external_edited_at (nullable)
  source_system, source_instance, external_id (único por tenant)
  raw_payload (jsonb — preserve_raw_payload: true do mapeamento)
  collected_at, last_observed_at, no_longer_observed_at
```

Sem tabela para ato, discussão ou participação: **derivados na leitura** (FR-005), como
manda a regra da casa (contagens derivadas de entradas) e a relação
`cmo.participation_derived_from_acts`. A discussão É o conjunto dos comentários da issue.

### 2. Coleta: consulta própria, incremental por dois filtros

`priv/connectors/github/queries/issue_comments.graphql` — comentários paginados por issue
(`repository.issues.nodes.comments`), com `rateLimit` declarado e `totalCount` para
truncamento nunca silencioso. Incremental (FR-001): só issues com `comment_count > 0` **e**
`updatedAt` desde a última passada de comentários do repositório (campo novo
`comments_collected_at` em `observed_repositories`, ao lado de `issues_collected_at`).
Números da base real: 1.182 de 5.032 issues têm comentário; máximo 16 — uma página de 50
por issue cobre tudo que existe hoje, e `totalCount` acusa quando deixar de cobrir.

Ingestão em `lib/the_band/ingestion/github_issue_comments.ex`, no padrão de
`github_work_items.ex`: upsert por `external_id`, autor resolvido pela regra dos
designados (login sempre; `person_id` só se coletada), sumiço marca
`no_longer_observed_at` nos que a página não trouxe de volta para a mesma issue.

Fase nova na MESMA sincronização (`sync_github_eo.ex`), depois das issues — a FK precisa
da issue gravada; falhar aqui não derruba o que veio antes, como as demais fases.

### 3. Leitura: um módulo de consultas, número fixo delas

`lib/the_band/communication/discussions.ex` (contexto novo — princípio X: comunicação não
é work item):

- `for_issue(tenant, issue_id)` — a discussão de uma issue, ordenada; 1 consulta;
- `participation_of(tenant, person_id, período)` — as discussões da pessoa: issue,
  contagem, primeiro/último ato; 1 consulta agregada (GROUP BY issue);
- `last_act_for_issues(tenant, issue_ids)` — o último ato por issue, para o anti-padrão;
  1 consulta para N issues (nunca por linha — SC-004).

### 4. Anti-padrão: o sinal "parada" ganha resolução (FR-004)

`Antipatterns` passa a receber o último ato por issue (via `last_act_for_issues`) e o
rótulo da parada vira três: `silent` (sem discussão nunca) / `stale_discussion` (último
ato antes do limiar) / `active_discussion` (ato dentro do limiar). O limiar é o mesmo da
parada (90 dias), vindo da base de conhecimento — sem número novo inventado.

### 5. Telas (vertical slice — FR-003, FR-006)

- **Detalhe da issue**: seção "Discussion", com os dois vazios distintos (não coletada ×
  sem comentários — o campo `comments_collected_at` do repositório decide qual frase).
- **Página da pessoa**: seção "Discussions they took part in" — derivada, hachura +
  rótulo; issue linkada, contagem, primeiro/último; a frase diz que participação não é
  tarefa executada.
- **Tela de sync**: a fase nova aparece com o que cobriu (FR-008).

## Riscos e medidas

- **Custo de coleta**: medido na spec (1.967 comentários hoje); a consulta pagina 25
  issues × 50 comentários e declara custo — medir na primeira execução real e registrar.
- **Autor fantasma** (`author: null` — conta apagada no GitHub): login vira
  `"ghost"` literal do GitHub; registrado como limitação se aparecer na base real.
- **Ordem das fases**: comentários dependem de issues gravadas — a fase roda depois, e
  issue nova com comentário na mesma passada é coberta porque a fase lê da base, não da
  memória da fase anterior.

## Fases de implementação

| fase | entrega | prova |
|---|---|---|
| F1 | migração + schema Ecto | migração sobe e desce |
| F2 | consulta GraphQL + ingestão + fase de sync | coleta real no tenant, totais contra a API (SC-001) |
| F3 | `Discussions` (leitura, 3 funções) | testes + contador de consultas (SC-004) |
| F4 | detalhe da issue com a discussão | teste LiveView + ao vivo |
| F5 | anti-padrão com resolução tripla | teste + issue real rotulada (SC-002) |
| F6 | seção da pessoa | teste LiveView + no_assignment real conferida (SC-003) |
