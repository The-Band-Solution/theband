# Data Model: os três papéis e a verificação

**Feature**: 044 · **Date**: 2026-08-27

## Nenhuma entidade nova. Nenhuma migração.

Todas as tabelas existem e estão povoadas. Este documento descreve **como elas se ligam**
para responder as perguntas da spec, e onde cada ligação pode falhar.

---

## As entidades, e o que cada uma já tem

### `collected_change_requests` — a solicitação de mudança

Materializa `cmpo.change_request`. **5.635 linhas.**

| coluna | papel nesta feature | preenchida |
|---|---|---:|
| `author_person_id` | quem **abriu** — `cmpo.stakeholder_submitted_change_request` | 5.497 |
| `merged_by_person_id` | quem **integrou** — `cmpo.stakeholder_performed_checkin` | 4.862 |
| `state` | o desfecho: `MERGED` 4.878 · `CLOSED` 668 · `OPEN` 89 | 5.635 |
| `external_merged_at` | distingue fechada **sem** integrar de integrada | — |

**Onde falha**: 138 solicitações sem autor identificado. Elas não aparecem em pessoa
alguma, e a soma das páginas não fecha com o total. É fato, e a spec manda declará-lo.

### `collected_artifact_evaluations` — a revisão

Materializa `qapo.artifact_evaluation`. **4.233 linhas.**

| coluna | papel nesta feature | preenchida |
|---|---|---:|
| `author_person_id` | quem **revisou** — `qapo.stakeholder_performed_artifact_evaluation` | 4.127 |
| `state` | o valor **cru** da origem, traduzido na leitura | 4.233 |
| `author_type` | separa `Bot` (85) de `User` (4.148) | 4.233 |
| `external_submitted_at` | nulo em rascunho — avaliação que não aconteceu | — |
| `collected_change_request_id` | a solicitação avaliada | 4.233 |

**Onde falha**: 106 avaliações de `User` sem pessoa promovida, mais 85 de `Bot` que não
têm pessoa por definição.

### `collected_verifications` — a execução de verificação

Materializa `ciro.verification`. **15.671 linhas.**

| coluna | papel nesta feature |
|---|---|
| `head_sha` | a ponte para o commit |
| `conclusion` | `success` · `failure` · `skipped` · `cancelled` · nulo |
| `attempt` | a tentativa — duas tentativas do mesmo commit são duas execuções |

### `collected_commits` + `commit_authors` — a ponte

| coluna | papel |
|---|---|
| `collected_commits.sha` | casa com `head_sha` |
| `commit_authors.author_person_id` | de quem é o commit — **20.585** autorias |
| `commit_authors.is_primary` | distingue autor de co-autor; **os dois contam** |

---

## As duas ligações, e o que cada uma perde

### Ligação 1 — pessoa → solicitação → avaliação

```
eo_people
   │  author_person_id
   ├──────────────────────► collected_change_requests   (abriu)
   │  merged_by_person_id
   ├──────────────────────► collected_change_requests   (integrou)
   │  author_person_id
   └──────────────────────► collected_artifact_evaluations
                                   │ collected_change_request_id
                                   └──► collected_change_requests   (revisou)
```

**Perde**: a solicitação sem autor identificado (138) e a avaliação sem pessoa (191, entre
bot e não promovido).

### Ligação 2 — pessoa → commit → verificação

```
eo_people
   │  author_person_id
   └──► commit_authors ──► collected_commits ──► collected_verifications
                              sha  =  head_sha
```

**Perde 47%** — 7.313 de 15.671 execuções não casam. Três causas, e nenhuma é defeito:

1. execução disparada por evento **sem commit** — `schedule`, `workflow_dispatch`;
2. commit cujo autor nunca foi promovido a pessoa;
3. commit de bot.

A parcela vai **ao lado** do número, e nunca descontada dele.

---

## O veredito, que é derivado e não armazenado

```
collected_artifact_evaluations.state    (cru, da origem)
              │
              │  value_map do mapeamento github.pull_request_review.to.qapo...
              ▼
    APPROVED          → qapo.endorsing_verdict
    CHANGES_REQUESTED → qapo.objecting_verdict
    COMMENTED         → qapo.abstaining_verdict

    DISMISSED → ciclo de vida: retirada       (NÃO é veredito)
    PENDING   → ciclo de vida: não submetida  (NÃO é veredito)
```

**Regra de leitura**: quem conta veredito conta **só as três posições**. As 52
`DISMISSED` ficam fora, e a tela pode dizê-lo — a avaliação aconteceu e foi tirada de
circulação.

**Valor não mapeado** recusa a carga (`unmapped: reject`) até a issue #526 existir.

---

## O que a contagem conta, e é preciso não confundir

| pergunta | unidade | por quê |
|---|---|---|
| "revisou quantas?" | **solicitações distintas** | duas revisões na mesma solicitação são um trabalho sobre uma mudança |
| "endossou quantas?" | **avaliações** | são posições tomadas, e a mesma pessoa pode mudar de posição |
| "quantas passaram?" | **execuções** | e nunca commits — nova tentativa é execução nova |

Medido em `vinicius-je`: **revisou 627** solicitações com **721 avaliações** (634 + 57 +
30). A diferença é quem revisou a mesma solicitação mais de uma vez.
