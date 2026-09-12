# Modelos

<!-- DERIVADO da estrutura de agentes em 2026-09-07. Índice mantido à mão; cada
     documento abaixo é derivado do código e traz a própria proveniência. -->

Os modelos que a implementação não carrega sozinha: o que existe, por quais situações passa, o
que o banco guarda, e o que depende do quê no backlog.

**A regra**: modelo é **derivado**, nunca lembrado. Todo documento aqui sai de uma fonte do
repositório — schema, migração, YAML da base, spec, issue — e abre dizendo de onde saiu, com
`arquivo:linha` e a data da conferência. Quem escreve é o papel
[Documentation — Modelos](../../.claude/agents/documentacao-modelos.md).

| Pasta | O que responde | Forma |
|---|---|---|
| `classes/` | quais entidades existem, o que carregam, como se ligam | `classDiagram` (Mermaid), uma por subsistema |
| `estados/` | por quais situações um registro passa, e o que provoca cada transição | `stateDiagram-v2`, com gatilho, guarda e o teste que prova |
| `banco/` | quais tabelas, colunas, chaves e **índices parciais** (que carregam invariante) | `erDiagram`, derivado das migrações |
| `dsm/` | o que precisa vir antes do quê, entre épicos, user stories e features | matriz em Markdown, com blocos e ciclos nomeados |

## O que existe hoje

**15 documentos, 23 diagramas Mermaid**, conferidos contra o código em
2026-09-12. A coluna *diagramas* é a contagem de blocos ```` ```mermaid ```` no arquivo — zero
significa que o documento é tabela ou matriz, e não que falta desenho.

| Documento | Diagramas | Derivado de |
|---|---|---|
| [`classes/eo-estrutura-organizacional.md`](classes/eo-estrutura-organizacional.md) | 1 | lib/the_band/ontology/seon/eo/schemas/*.ex (organization.ex:20-39, person.ex:28-59, team.ex:29-55, organizational_role.ex:44-63, team_membership.ex:52 |
| [`classes/ingestao-e-observacao.md`](classes/ingestao-e-observacao.md) | 1 | lib/the_band/sources/connected_tool.ex:23-38, tool_credential.ex:26-42, observation_event.ex:32-44; lib/the_band/ingestion/sync.ex:15-42, checkpoint.e |
| [`classes/perfis-e-modelo.md`](classes/perfis-e-modelo.md) | 1 | lib/the_band/ai/provider_credential.ex:1-34, lib/the_band/profiles/run.ex:1-38, run_entry.ex:1-39, automation_event.ex:19-25; lib/the_band/ontology/se |
| [`classes/projetos-e-processo.md`](classes/projetos-e-processo.md) | 2 | lib/the_band/ontology/seon/spo/schemas/project.ex:29-45, project_organization.ex:17-25, project_team.ex:17-25, project_repository.ex:21-29, project_bo |
| [`classes/tenants-e-acesso.md`](classes/tenants-e-acesso.md) | 1 | lib/the_band/tenants/tenant.ex:14-25, user.ex:31-91, access/scope_grant.ex:15-32 e :18, account_disablement.ex:40-55, access.ex:60-104 e :532-533, acc |
| [`classes/trabalho-e-mudanca.md`](classes/trabalho-e-mudanca.md) | 2 | lib/the_band/work_items/schemas/collected_issue.ex:21-69, issue_promotion.ex:29-60, decomposition_link.ex:17-24, refused_link.ex:23-31, issue_assignee |
| [`estados/vinculo-de-equipe.md`](estados/vinculo-de-equipe.md) | 2 | lib/the_band/ontology/seon/eo/schemas/team_membership.ex:52-135; lib/the_band/ontology/seon/eo/commands.ex:69-193, 588-769, 793-826, 1281-1345, 1386-1 |
| [`banco/eo-e-acesso.md`](banco/eo-e-acesso.md) | 1 | — |
| [`banco/ingestao-e-observacao.md`](banco/ingestao-e-observacao.md) | 1 | — |
| [`banco/mapa-das-tabelas.md`](banco/mapa-das-tabelas.md) | 0 | priv/repo/migrations/*.exs (88 migrações aplicadas) confrontadas com `information_schema.tables` e `information_schema.columns` do banco de desenvolvi |
| [`banco/perfis-e-modelo.md`](banco/perfis-e-modelo.md) | 1 | — |
| [`banco/projetos-e-processo.md`](banco/projetos-e-processo.md) | 2 | — |
| [`banco/trabalho-e-mudanca.md`](banco/trabalho-e-mudanca.md) | 2 | — |
| [`dsm/060-tela-da-equipe.md`](dsm/060-tela-da-equipe.md) | 0 | specs/060-tela-da-equipe/spec.md (US1 a US9, FR-001 a FR-083, SC-001 a SC-021), specs/060-tela-da-equipe/tasks.md (T001 a T025, "Dependências e ordem" |
| [`arquitetura/visao-geral.md`](arquitetura/visao-geral.md) | 6 | lib/the_band/application.ex:11-44, lib/the_band_web/router.ex:7-152, lib/the_band/ontology/knowledge_base.ex:126-141, config/config.exs:88-120, lib/th |

> **O índice é mantido à mão, e por isso mente primeiro.** Em 2026-09-12 ele ainda dizia
> *"`banco/` ainda está vazia"* enquanto a pasta tinha seis documentos e sete ERDs. A regra
> que sobra disto: quem acrescenta documento **atualiza esta tabela no mesmo commit** — índice
> que contradiz o diretório é pior que índice nenhum, porque quem o lê não vai conferir.

## Como ler uma DSM

Linhas e colunas são os mesmos itens, na mesma ordem. A célula `(i, j)` marcada significa
**i depende de j**, e a marca diz a natureza: `D` dado · `T` tela · `R` regra · `E` esquema.
Depois de reordenar, o que fica **abaixo** da diagonal é ordem possível; o que sobra **acima**
é ciclo, e ciclo é achado — o documento o nomeia e propõe o corte. Blocos na diagonal são as
fatias que viajam juntas numa PR; a recomendação de fatiamento é oferecida ao Product Owner,
que decide.
