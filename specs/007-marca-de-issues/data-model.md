# Modelo de dados — Feature 007

**Uma coluna.** Nenhuma tabela nova, nenhuma removida, nenhum índice novo.

---

## `observed_repositories.issues_collected_at`

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `issues_collected_at` | `utc_datetime` | **sim** | `nil` = nunca passou por coleta de issues |

### O que ela registra, e o que não registra

**Registra um evento**: a fase de issues rodou para este repositório, e terminou. É a mesma
natureza de `collected_at` e `last_observed_at`, que já existem — fato de coleta, não situação
derivada.

**Não registra** quantas issues foram encontradas. A contagem vem da consulta, sempre. Guardá-la
aqui seria situação materializada — ADR 0004 D7 — e envelheceria no instante em que uma issue
fosse coletada, sem nada dizendo que envelheceu.

### `nil` é a única coisa que a plataforma hoje não sabe

Sem esta coluna, "repositório com zero issues" tem dois significados indistinguíveis:

| significado | quantos hoje |
|---|---:|
| a coleta rodou e não achou nada | ? |
| a coleta nunca rodou para ele | ? |

**61 repositórios estão nesse limbo.** A tela mostraria `0` para os dois grupos — ausência
desenhada como quantidade, que é o que o design system proíbe.

Conferi que não é derivável do que existe:

| candidato | por que não serve |
|---|---|
| `sync_checkpoints` | a chave é `github.issue`, uma por execução — não por repositório |
| `raw_payloads` | prova que **houve** issue; não prova coleta que achou zero |
| `collected_issues` | a ausência de linha é justamente a ambiguidade |
| `observed_repositories.inserted_at` | diz quando passou a ser observado, não quando foi consultado |

### Onde é escrita

No **mesmo ponto** que grava o checkpoint da fase de issues, em
`TheBand.Ingestion.GithubWorkItems`. Dois pontos diferentes é como a data fica gravada para uns
repositórios e não para outros — e aí a marca mente sobre coleta, que é pior que não saber.

Repositório **excluído** ou **inacessível** não é consultado, e portanto **não** recebe a data.
Isso é correto: a plataforma não olhou.

---

## O que esta feature **não** cria

| Não criado | Por quê |
|---|---|
| coluna com a contagem de issues | situação materializada; a consulta agrupada resolve |
| coluna dizendo "tem trabalho" | é derivado de exibição, calculado na leitura |
| tabela de visita por pessoa | o indicador de "novas desde a última visita" está fora do escopo |
| índice novo | a consulta agrupada filtra por `observed_repository_id`, que já é indexado |

---

## A consulta que sustenta a marca

`WorkItems.count_collected_by_repository/2` — uma consulta, agrupada, devolvendo mapa.

Hoje a tela faz **135 consultas** (uma por repositório) e a marca precisaria do mesmo número. A
agrupada faz **1**, e a coluna e a marca leem o mesmo mapa — que é o que FR-010 exige.

A contagem é de issues **vigentes**: `no_longer_observed_at` nulo.

E daí sai o **quarto texto**, que não é um quarto estado da marca:

| contagem vigente | houve issue alguma vez | texto |
|---|---|---|
| > 0 | — | `N issues` |
| 0 | **sim**, todas ausentes | `no current work` |
| 0 | não, e a coleta rodou | `collected, no issues` |
| 0 | não, e a coleta nunca rodou | `not collected yet` |

`no current work` afirma que **houve** trabalho e ele não está presente. Dizer "no issues" ali
apagaria o fato de que existiram — e é a mesma distinção que `no_longer_observed_at` carrega em
`collected_issues`, `issue_assignees` e `issue_labels`.
