# Implementation Plan: Coleta de pessoas e equipes do GitHub para a Enterprise Ontology

**Branch**: `001-github-eo-ingestion` | **Date**: 2026-08-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-github-eo-ingestion/spec.md`

**Fase 0**: já resolvida em [research.md](research.md) (R1 a R9). Este plano a
reutiliza e registra as duas divergências encontradas ao confrontá-la com a base
de conhecimento e com a constituição ratificada depois dela.

## Summary

A feature entrega a primeira fatia vertical do The Band: uma organização cliente
declara que usa o GitHub, informa instância e credencial, dispara uma
sincronização e vê na tela as pessoas e equipes que a plataforma passou a
conhecer — cada registro exibindo de onde veio, qual o identificador na origem e
quando foi coletado.

A abordagem técnica é a que a [research.md](research.md) fixou: Phoenix com
LiveView sobre PostgreSQL, coleta pelo GraphQL do GitHub via Req, orquestrada por
Oban com checkpoint de cursor persistido, credencial cifrada em repouso por
Cloak, e a base de conhecimento YAML carregada no boot para ETS, servindo os
mapeamentos que transformam payload bruto em conceitos de EO.

**O bootstrap do projeto Phoenix faz parte desta fatia.** O repositório hoje tem
apenas documentação, a base de conhecimento YAML e as ferramentas Python que
operam sobre ela. Não existem `mix.exs`, `lib/`, `config/`, `compose.yaml` nem
`.github/`. Separar o bootstrap em feature própria produziria uma entrega sem
nada visível, o que o princípio VI da constituição proíbe.

## Technical Context

**Language/Version**: Elixir 1.20.2 sobre Erlang/OTP 29 (R1 — verificados no ambiente)

**Primary Dependencies**: Phoenix `~> 1.8` · Ecto SQL `~> 3.14` · Oban `~> 2.23` ·
Req `~> 0.7.2` (fixado em `~> 0.7.2` e não `>= 0.7`, por estar em `0.x` — R1) ·
`yaml_elixir ~> 2.12` (R2) · `cloak_ecto ~> 1.3` (R3) · ExUnit + Mox · Credo · Dialyzer

**Storage**: PostgreSQL 16 via Docker Compose. Uma base, tabelas compartilhadas,
`tenant_id` em toda tabela de domínio (constituição, princípio V)

**Testing**: ExUnit. `test/contract/` com Mox apenas na borda HTTP;
`test/integration/` com tag `:integration` para Postgres, Oban, paginação, rate
limit, idempotência e isolamento entre tenants

**Target Platform**: servidor Linux; Phoenix Release em produção, Docker Compose em desenvolvimento

**Project Type**: aplicação web — monólito modular multitenant, backend e LiveView no mesmo projeto

**Performance Goals**: nenhuma meta de latência é requisito da spec. O que é
medido é comportamental: SC-006 (no máximo uma reconsulta por página após
interrupção) e SC-009 (concluir sem intervenção manual mesmo atingindo o rate limit)

**Constraints**: rate limit do GraphQL do GitHub é por complexidade de consulta,
não por número de requisições — a pausa é preventiva, lida de
`rateLimit { cost remaining resetAt }` na própria resposta (R6). A base de
conhecimento é lida uma vez por boot; alterar YAML em produção exige reinício (R4)

**Scale/Scope**: organizações de até algumas centenas de pessoas (SC-009 fixa o
caso verificável em 100 pessoas e 20 equipes). Uma ontologia (EO), quatro
mapeamentos, uma regra de derivação, uma tela

## Constitution Check

*GATE: avaliado antes da Fase 0 e reavaliado após a Fase 1.*

Contra a [constituição v1.0.0](../../.specify/memory/constitution.md), princípio a princípio.

| # | Princípio | Veredito | Como esta feature o satisfaz — ou o que fica em aberto |
|---|---|---|---|
| I | Domínio organizado pelas ontologias | **PASS** | O domínio ganha `TheBand.Ontology.SEON.EO`, com API pública por `defdelegate` e schemas privados (R9, ADR 0003). Não existe módulo de domínio chamado GitHub: o conector vive em `lib/the_band/integrations/github/` e `priv/connectors/github/`. As tabelas são as seis derivadas da EO por `one table per kind`, e `eo.team_member` permanece absorvido em `eo.person`, sem virar coluna |
| II | Fonte externa não é domínio | **PASS** | O caminho é `Req → payload bruto em raw_data → proveniência → mapeamento YAML → comando público de EO → Ecto`. O conector nunca chama `Repo` sobre schema de EO. O payload original é preservado íntegro, o que é o que torna FR-017 possível — reprocessar mapeamento corrigido sem consultar o GitHub |
| III | Proveniência e idempotência | **PASS** | Toda tabela de domínio recebe `tenant_id`, `internal_id`, `record_version`, timestamps; toda tabela alimentada por fonte externa recebe `source_system`, `source_instance`, `external_id`, `collected_at` e `unique_index` sobre a quádrupla com o tenant. O upsert é por Application Reference, não por nome. Ausência na origem marca `last_observed_at`, nunca apaga |
| IV | Semântica declarada em YAML versionado | **PASS com dívida declarada** | A transformação lê os mapeamentos de `priv/knowledge_base/mappings/github/eo/` e a regra `github.team_membership_evidence`; não há regra de conversão embutida no código. **Dívida**: dos gates de conhecimento que a constituição nomeia, esta feature entrega `mix knowledge.validate` e `mix knowledge.graph` (ambos caem do carregador de boot); `mix knowledge.test`, `mix knowledge.docs` e `mix knowledge.information_model` continuam sendo os scripts Python de `scripts/`, chamados pelo CI. Registrado em Complexity Tracking |
| V | Monólito modular multitenant | **PASS** | Um projeto Phoenix, uma base PostgreSQL, `tenant_id` em toda query e em todo job Oban, validado antes de executar. Nenhum broker externo: Oban cobre paginação, retry e reprocessamento. Nenhuma tecnologia da lista de ADR obrigatória é introduzida |
| VI | Spec Kit e sprint backlog antes do código | **PASS** | spec, checklist e research concluídos; este plano fecha a etapa de planejamento e é seguido por `/speckit-tasks`, `/speckit-taskstoissues`, `/speckit-analyze` e `sprint-backlog` antes de qualquer código. A fatia é vertical de ponta a ponta: termina na tela de pessoas e equipes, não na infraestrutura |
| VII | Quality gates e revisão independente | **PASS com lacuna declarada** | A feature cria `.github/workflows/ci.yml` rodando os oito gates. **Lacuna**: a constituição exige revisão independente, e quem implementa não pode aprovar o próprio PR. Enquanto não houver segunda pessoa ou agente revisor designado, a condição **não pode ser marcada como cumprida** — é declarada como pendente no PR, nunca assinada por quem implementou |

**Resultado do gate**: aprovado. Duas ressalvas registradas em Complexity
Tracking; nenhuma delas é violação de princípio, e ambas têm caminho de saída
escrito.

### Divergências encontradas ao confrontar research.md com a base de conhecimento

Duas, ambas resolvidas aqui, porque a base de conhecimento é a fonte da semântica
(princípio IV) e o plano não pode contradizê-la em silêncio.

**D-1 — nome da tabela de evidência.** A [research.md](research.md) R7 propõe
`eo_observed_team_links`. A regra
[`github_team_membership_evidence.yaml`](../../priv/knowledge_base/rules/github_team_membership_evidence.yaml)
declara `persisted_as: team_membership_evidence`. Prevalece a regra: a tabela é
**`eo_team_membership_evidence`**, com o prefixo da ontologia dona conforme
AGENTS.md §9. A decisão de R7 — tabela própria, distinta de `eo_team_memberships`
— permanece integralmente válida; muda só o nome.

**D-2 — colunas da evidência.** A regra nomeia `person_external_id`,
`team_external_id`, `platform_access_level` e `observed_at`. R7 acrescenta
`last_observed_at` e `promoted_membership_id`, que a regra não contradiz e que
FR-021 e o edge case de remoção entre coletas exigem. As duas se somam; a tabela
carrega chaves internas **e** os identificadores externos, porque a evidência
precisa ser rastreável à origem mesmo antes de resolver a chave interna.

## Project Structure

### Documentation (this feature)

```text
specs/001-github-eo-ingestion/
├── spec.md              # concluído
├── checklists/
│   └── requirements.md  # concluído, todos os itens passam
├── research.md          # Fase 0 — concluída (R1 a R9)
├── plan.md              # este arquivo
├── data-model.md        # Fase 1
├── contracts/           # Fase 1
│   ├── ontology-eo.md          API pública do módulo ontológico
│   ├── github-connector.md     definição declarativa do conector e query GraphQL
│   └── liveview-screens.md     contrato das telas
├── quickstart.md        # Fase 1
└── tasks.md             # /speckit-tasks — não criado aqui
```

### Source Code (repository root)

Somente o que esta feature justifica. Diretório vazio não é criado
antecipadamente (AGENTS.md §5).

```text
the-band/
├── mix.exs  compose.yaml  .formatter.exs  .credo.exs  .env.example
├── .github/workflows/ci.yml
├── config/{config,dev,test,prod,runtime}.exs
├── lib/
│   ├── the_band.ex
│   ├── the_band/
│   │   ├── application.ex          supervisor; falha o boot sem chave mestra (FR-005a)
│   │   ├── repo.ex
│   │   ├── vault.ex                Cloak.Vault + Ecto.Type do campo cifrado
│   │   ├── tenants/                organização cliente; fronteira de isolamento
│   │   ├── accounts/               usuário, sessão, perfil administrador
│   │   ├── sources/                ferramenta conectada + credencial (FR-002 a FR-009)
│   │   ├── raw_data/               payload bruto preservado (FR-011)
│   │   ├── provenance/             Application Reference e resolução de identidade
│   │   ├── integrations/github/    Req, GraphQL, paginação, rate limit, checkpoint
│   │   ├── ingestion/              orquestração da sincronização e relatório final
│   │   ├── semantic_integration/   aplica os mapeamentos YAML ao payload bruto
│   │   ├── ontology/
│   │   │   ├── knowledge_base.ex   carrega no boot para ETS (R4)
│   │   │   ├── yaml_loader.ex  yaml_validator.ex  dependency_graph.ex
│   │   │   └── seon/eo/
│   │   │       ├── eo.ex           API pública; só defdelegate (R9)
│   │   │       ├── schemas/  commands/  queries/  constraints/
│   │   ├── jobs/                   workers Oban da sincronização
│   │   └── the_band_web/
│   │       ├── router.ex  endpoint.ex  plugs/  components/
│   │       └── live/{source_live,sync_live,people_live,teams_live}/
├── priv/
│   ├── repo/migrations/
│   ├── knowledge_base/             já existe; esta feature não o reescreve
│   └── connectors/github/{queries,definitions}/
├── scripts/                        Python; permanece até as Mix tasks o substituírem
└── test/
    ├── support/  the_band/  the_band_web/  contract/  integration/  fixtures/
```

**Structure Decision**: aplicação web em projeto único (`mix phx.new the_band`),
sem separação frontend/backend — LiveView é tela e backend na mesma entrega, que
é exatamente o que o princípio VI pede. As camadas da tese aparecem como
fronteiras internas: `integrations/` e `ingestion/` para a camada de integração
de aplicações, Oban e `semantic_integration/` no lugar do broker,
`ontology/seon/eo/` como o serviço baseado em ontologia, e `the_band_web/live/`
como a camada de acesso ao dado.

## Complexity Tracking

| Violação | Por que é necessária | Alternativa mais simples, e por que foi rejeitada |
|---|---|---|
| Bootstrap do Phoenix dentro da feature 001, em vez de feature de fundação própria | O repositório não tem projeto Elixir. Sem `mix.exs`, `config/`, `Repo` e supervisor, nenhum requisito da spec é implementável | Uma feature 000 só de fundação foi considerada e rejeitada: entregaria zero tela, violando o princípio VI. O roadmap original do AGENTS.md §19, que punha a primeira tela na feature 035, é justamente o que a regra da fatia vertical corrige |
| `mix knowledge.test`, `mix knowledge.docs` e `mix knowledge.information_model` continuam em Python nesta feature | Portar as três para Elixir é trabalho comparável ao da feature inteira, e nenhuma delas é necessária para a coleta funcionar. `scripts/README.md` já declara cada script como transitório, com a Mix task que o substituirá nomeada | Portar tudo agora foi rejeitado por inchar a fatia sem entregar nada visível. Deixar o gate de fora foi rejeitado por contrariar o princípio IV: o CI roda os scripts Python, então o gate existe — muda o executor, não a exigência. As Mix tasks entram como feature própria, ligada ao item de extração da biblioteca |
| `eo_team_membership_evidence` como tabela fora do modelo derivado da ontologia | O GitHub fornece pessoa e equipe, e não o papel que `eo.team_membership` exige. Gravar membership com papel nulo violaria o relator e espalharia o tratamento de nulo por toda consulta de papel | Reutilizar `eo_team_memberships` com papel nulo foi rejeitado por corromper o modelo. Descartar o vínculo foi rejeitado porque é o dado mais valioso da coleta. A tabela é a materialização de `observed_link` que a própria regra da base de conhecimento manda persistir, com o nome que ela declara |
| Uma tela lê o dado de duas ontologias? Não — só EO | — | Registrado para deixar explícito que a fatia **não** amplia escopo: CMPO, SRO e as demais não entram, e `granted_repositories` do mapeamento de time é ignorado nesta feature por apontar para `cmpo.source_repository`, que não existe ainda |

## Constitution Check — reavaliação após a Fase 1

O desenho não introduziu violação nova. O que ele acrescentou foi a materialização
de três princípios em artefato verificável:

| # | O que a Fase 1 acrescentou |
|---|---|
| I | `eo_teams.type` absorve os dois subkinds e `eo.team_member` não vira coluna — a derivação foi conferida contra a saída real de `derive_information_model.py --ontology eo`, que produz 6 tabelas a partir de 10 conceitos. As tabelas de papel e de alocação são criadas vazias em vez de omitidas, para que a próxima fonte não exija migração |
| II | O contrato do conector proíbe textualmente `Repo` sobre `eo_*` e fixa `raw_payloads` guardando `mapping_id` e `mapping_version`, o que torna FR-017 e SC-007 verificáveis por execução (V7 do quickstart) |
| III | O índice de idempotência e as quatro colunas de proveniência viraram `NOT NULL` no banco, não só validação de changeset. Constraint no changeset sozinho não é integridade |
| IV | As cinco constraints de módulo derivam uma a uma de limitação declarada na base de conhecimento, com a origem nomeada. Nenhuma é invenção do plano |
| V | Toda função da API pública de EO recebe o tenant; nenhuma devolve `Ecto.Query`, o que fecha o caminho de compor fora da fronteira e contornar o filtro |
| VI | O quickstart valida por tela, não por teste unitário — V5, V6 e V8 só são verificáveis com a interface funcionando, o que é a prova de que a fatia é vertical |
| VII | Os oito gates estão no quickstart e no CI. A revisão independente segue **declarada como pendente**, não assinada |

Uma decisão de contrato merece registro por ter nascido de defeito real observado
antes: `list_*` e `count_*` aceitam exatamente as mesmas `opts`. Uma contagem que
ignora o filtro da listagem exibe um total que não corresponde ao que está na
tela, e o defeito permanece invisível enquanto não houver consumidor.

## Fases

- **Fase 0 — pesquisa**: concluída em [research.md](research.md), R1 a R9, mais as
  duas divergências D-1 e D-2 resolvidas neste plano.
- **Fase 1 — desenho e contratos**: concluída — [data-model.md](data-model.md),
  [contracts/](contracts/) e [quickstart.md](quickstart.md).
- **Fase 2 — tarefas**: `/speckit-tasks`, fora do escopo deste comando.
