# Modelo de dados — o vínculo que sumiu na origem

**Feature** `012-vinculo-que-sumiu-na-origem`

**Nenhuma tabela nova, nenhuma coluna nova, nenhuma migração.** A coluna existe desde
`20260811150500_create_decomposition_links.exs`; o que falta é escrevê-la.

---

## `decomposition_links` — o que já existe

| Coluna | O que afirma |
|---|---|
| `parent_issue_id` | a issue que **declara** ter partes |
| `child_issue_id` | a parte |
| `observed_at` | quando a plataforma viu este vínculo **pela primeira vez** |
| `last_observed_at` | quando o viu **pela última** |
| `no_longer_observed_at` | quando **deixou** de vê-lo — nulo enquanto vigente |

**O repositório não está aqui, e é de propósito**: ele está na issue-pai
(`collected_issues.observed_repository_id`). Duplicá-lo criaria um segundo lugar onde ele pode ficar
errado.

---

## Os três estados, e as quatro transições

```text
        (a origem declara pela 1ª vez)
                    │
                    ▼
            ┌───────────────┐   a execução não reviu    ┌───────────────┐
            │   VIGENTE     │ ────────────────────────► │   AUSENTE     │
            │ no_longer=nil │                           │ no_longer=data│
            └───────────────┘ ◄──────────────────────── └───────────────┘
                    │            a origem declara de novo
                    │  a execução reviu
                    └──► VIGENTE, com last_observed_at novo
```

| # | Transição | Quem faz | Regra |
|---|---|---|---|
| T1 | inexistente → vigente | `record_decomposition_link/2` | grava `observed_at` e `last_observed_at` |
| T2 | vigente → vigente | `record_decomposition_link/2` | só `last_observed_at` muda; `observed_at` **preservado** |
| T3 | **vigente → ausente** | **esta feature** | `last_observed_at < started_at` da execução |
| T4 | ausente → vigente | `record_decomposition_link/2` | zera a marca; `observed_at` **preservado** |

**T3 é a que falta**, e é a feature inteira. As outras três já funcionam.

**Não existe transição ausente → ausente.** Vínculo já marcado não é remarcado: o que se registra é
quando deixou de ser visto, não quando se olhou de novo.

**Não existe apagar.** Nenhuma transição sai do grafo.

---

## O corte, escrito por extenso

Um vínculo é marcado quando **as três** valem:

1. o **pai** está no repositório que a execução acabou de ler com sucesso;
2. `last_observed_at` é **anterior** ao `started_at` daquela execução;
3. `no_longer_observed_at` ainda é nulo.

E a data escrita é o instante em que se notou — **não** o `started_at`. São dois instantes, e a
[pesquisa D2](research.md#d2--dois-instantes-e-eles-não-são-o-mesmo) diz por quê.

---

## O que a marca significa para quem lê

| Pergunta | Resposta |
|---|---|
| "esta issue é parte de quem?" | só os vínculos **vigentes** contam |
| "esta issue tem mais de um pai?" | conta vigentes; um vigente + um ausente é **um** |
| "esta decomposição já existiu?" | sim, e a linha ausente é a prova, com as datas |
| "a origem ainda declara?" | não — foi por isso que a marca entrou |

---

## Estado medido em 2026-08-12

| | |
|---|---:|
| vínculos | 1 666 |
| vigentes | 1 666 |
| ausentes | **0** |
| **deveriam estar ausentes** | **52** |

Os 52 estão distribuídos em `eo_lib` (29), `theband` (15) e `ResearchDomain` (8), e nos 52 **pai e
filha continuam vigentes** — não há issue ausente para explicá-los.
