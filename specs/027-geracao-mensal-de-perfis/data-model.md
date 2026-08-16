# Data Model: geração mensal dos perfis

**Feature**: 027 · **Data**: 2026-08-16

Três tabelas novas. Nenhuma delas é ontológica: descrevem **a plataforma trabalhando**, e não a organização observada. É a mesma fronteira que separa `syncs` de `eo.person`.

---

## `profile_automation_events`

O ato de ligar ou desligar a geração automática de uma organização. Somente-acréscimo: o estado atual é o evento mais recente.

| campo | tipo | nulo? | o que é |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid → `tenants` | não | |
| `event` | string | não | `enabled` ou `disabled` |
| `actor_user_id` | uuid → `users` | não | **quem** — `FR-019`. Não é anulável: um evento sem autor é o estado sem dono que a `FR-018a` existe para impedir |
| `occurred_at` | utc_datetime | não | **quando** |
| `inserted_at` / `updated_at` | utc_datetime | não | |

**Índices**: `[:tenant_id, :occurred_at]`.

**Regras**
- `event` restrito aos dois valores, no changeset **e** em `check_constraint` — changeset sozinho não é integridade;
- ausência de evento significa **desligada**. É o que faz a `FR-018c` valer sem migração de dados: organização que já existe não tem evento, logo não está ligada;
- nada é apagado. Desligar é um evento novo, não a remoção do anterior.

---

## `profile_runs`

Uma execução da geração num tenant.

| campo | tipo | nulo? | o que é |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid → `tenants` | não | |
| `trigger` | string | não | `cron` ou `manual` — `FR-004`, e é o que a `FR-015` grava sem mudar como o texto aparece |
| `requested_by_user_id` | uuid → `users` | **sim** | preenchido só quando `trigger = manual`. Nulo aqui é ausência real, e não desconhecida |
| `started_at` | utc_datetime | não | |
| `finished_at` | utc_datetime | **sim** | nulo = **em execução**. É o que a `FR-003` consulta para recusar a segunda |
| `outcome` | string | **sim** | `completed` ou `ended_early`; nulo enquanto executa |
| `ended_reason` | string | **sim** | preenchido só em `ended_early` — `FR-016` |
| `credential_last_four` | string | não | os quatro últimos da chave usada. É o que torna a `SC-006` verificável pelo registro, e não por inspeção de código |
| `inserted_at` / `updated_at` | utc_datetime | não | |

**Índices**: `[:tenant_id, :started_at]`; índice parcial em `[:tenant_id]` onde `finished_at IS NULL`, que é a consulta da `FR-003`.

**Transições**

```text
aberta (finished_at nulo)
  ├─→ completed     todas as pessoas selecionadas têm entrada
  └─→ ended_early   falha de credencial; ended_reason nomeia
```

Não há estado `cancelada`: nenhuma linha do código a produziria, e um estado que não acontece é um estado que quem lê precisa considerar à toa.

---

## `profile_run_entries`

Uma linha **por pessoa considerada** na rodada. É o checkpoint da `R2` e a origem de todas as contagens da `FR-014`.

| campo | tipo | nulo? | o que é |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid → `tenants` | não | |
| `profile_run_id` | uuid → `profile_runs` | não | |
| `person_id` | uuid → `eo_persons` | não | |
| `outcome` | string | não | `generated`, `skipped` ou `failed` |
| `reason` | string | **sim** | obrigatório quando `skipped`: `no_material`, `no_new_work`, `observation_ended`. Nulo quando `generated` |
| `failure_reason` | string | **sim** | obrigatório quando `failed`; texto já redigido pela borda — a chave nunca entra aqui |
| `person_profile_id` | uuid → `eo_person_profiles` | **sim** | o perfil que esta entrada produziu, quando produziu |
| `input_tokens` | integer | **sim** | consumo desta geração — `FR-020`. Nulo quando não houve chamada |
| `inserted_at` / `updated_at` | utc_datetime | não | |

**Índices**: `unique_index [:profile_run_id, :person_id]` — é o guarda de idempotência da `R2`, e é constraint de banco, não só validação; `[:tenant_id, :profile_run_id]`.

**Regras**
- os **três** motivos de pulo da `FR-014` são a lista fechada, com `check_constraint`. Não existe `other`: um motivo genérico é o "não elegível" que a `FR-014` proíbe;
- `failed` é **desfecho**, e não motivo de pulo. Pular é a plataforma decidindo não escrever; falhar é ela ter tentado e não conseguido. A tela conta os dois separados;
- `input_tokens` nulo é ausência nomeada, nunca zero. Zero significaria "chamou e não consumiu", que não acontece.

---

## O que **não** muda

- **`eo_person_profiles`** continua como está. A rodada grava perfil pelo mesmo caminho da geração pedida a mão, e um perfil não sabe se veio de rodada — `FR-015`. Quem sabe é a entrada de rodada, que aponta para ele;
- **`ai_provider_credentials`** já está entregue nesta branch;
- **nenhuma ontologia é tocada.** A decisão R1 da feature 026 — nenhum conceito de competência entra na rede — continua valendo, e esta feature não a reabre.

## As contagens da `FR-014`, e por que são derivadas

```text
consideradas   = count(entries)
geradas        = count(entries where outcome = generated)
puladas/motivo = count(entries where outcome = skipped) group by reason
falhas         = count(entries where outcome = failed)
tokens         = sum(entries.input_tokens)
```

Nenhuma delas é coluna em `profile_runs`. Guardá-las seria mais rápido e criaria o defeito que este repositório já teve duas vezes: dois lugares guardando o mesmo fato, e eles discordando depois de uma retentativa. Com 34 entradas por rodada, a agregação não se mede.
