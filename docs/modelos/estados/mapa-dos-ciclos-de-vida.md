<!-- DERIVADO de priv/repo/migrations/*.exs (93 migrações), reconstruídas em ordem para
     obter tabela → colunas, e confrontadas com as 65 declarações `schema "..." do` de
     lib/**/*.ex; mais a varredura das escritas de cada coluna de ciclo de vida em
     lib/**/*.ex (fora de `@doc`, `@moduledoc` e comentários) — em 2026-09-18.
     Conferido contra o código nesta data. Regenerar ao mudar a fonte.
     NÃO foi medido no banco: esta casa não tinha `psql` disponível na data, e por isso
     não há contagem de linhas aqui. O que há é estrutura, que sai da migração. -->

# Estados — o mapa dos ciclos de vida

**Antes de qualquer máquina de estados, o censo.** Esta página existe para que nenhum ciclo de
vida desapareça por não ter cabido num diagrama, e para que quem chega saiba **onde procurar**
o estado de um registro — porque nesta base ele quase nunca está onde se espera.

## A regra que explica tudo o que vem abaixo

> **O estado quase nunca é uma coluna.** Ele é um par de colunas de data, e a pergunta
> *"em que situação está?"* se responde perguntando *"qual dessas datas é nula?"*.

Das **66 tabelas de domínio**, exatamente **três** têm uma coluna chamada `status`:

| Tabela | Valores | Onde estão declarados |
|---|---|---|
| `syncs` | `running`, `completed`, `failed`, `interrupted` | `lib/the_band/ingestion/sync.ex:13` |
| `sync_checkpoints` | (situação da etapa da coleta) | `lib/the_band/ingestion/checkpoint.ex:19` |
| `tenants` | (situação do tenant) | `lib/the_band/tenants/tenant.ex:19` |

Todo o resto da plataforma codifica situação em **datas que podem ser nulas**, e o motivo é o
mesmo em todos os casos, escrito e reescrito nas migrações:

> *"Revogar MARCA, e nunca apaga: a pergunta 'desde quando este critério vale' só tem
> resposta se o encerramento preservar o começo."*
> — `priv/repo/migrations/20260825140000_create_activity_start_criteria.exs:66-67`

Uma coluna `status` sobrescrita perde o começo. Um par `declared_at` / `revoked_at` guarda os
dois instantes e o autor de cada um. O preço é que o estado deixa de ser legível de relance,
e é exatamente esse preço que esta pasta paga de volta.

## O censo: cada coluna de ciclo de vida, e em quantas tabelas

Contagem feita reconstruindo as 93 migrações em ordem. `n` é o número de tabelas de domínio
que têm a coluna.

| Coluna | n | Tabelas | Máquina documentada |
|---|--:|---|---|
| `no_longer_observed_at` | **23** | ver [observacao.md](observacao.md#as-23-tabelas) | [observacao.md](observacao.md) |
| `revoked_at` | **9** | ver [declaracao-revogavel.md](declaracao-revogavel.md#as-nove-tabelas) | [declaracao-revogavel.md](declaracao-revogavel.md) |
| `unlinked_at` | 4 | `spo_project_organizations`, `spo_project_teams`, `spo_project_repositories`, `spo_project_boards` | [projeto-declarado.md](projeto-declarado.md) |
| `ended_at` | 2 | `eo_team_memberships`, `eo_team_compositions` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `disabled_at` | 2 | `users`, `account_disablements` | [conta.md](conta.md) |
| `validated_at` | 2 | `tool_credentials`, `ai_provider_credentials` | [coleta.md](coleta.md#a-credencial) |
| `finished_at` | 2 | `syncs`, `profile_runs` | [coleta.md](coleta.md) |
| `invalidated_at` | 1 | `eo_team_memberships` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `end_declared_at` | 1 | `eo_team_memberships` | [vinculo-de-equipe.md](vinculo-de-equipe.md) |
| `excluded_at` | 1 | `observed_repositories` | [observacao.md](observacao.md#a-outra-ausência-a-que-é-decisão-nossa) |
| `enabled_at` | 1 | `account_disablements` | [conta.md](conta.md) |
| `person_revoked_at` | 1 | `users` | [conta.md](conta.md#máquina-2--o-elo-entre-a-conta-e-a-pessoa-observada) |
| `removed_at` | 1 | `spo_projects` | [projeto-declarado.md](projeto-declarado.md) |
| `hidden_at` | 1 | `eo_organizational_roles` | **nenhuma — ver abaixo** |
| `no_longer_in_configuration_at` | 1 | `project_iterations` | **nenhuma — ver abaixo** |
| `archived_at` | 1 | `cmpo_source_repositories` | **nenhuma — ver abaixo** |
| `inaccessible_since` | 1 | `observed_repositories` | [observacao.md](observacao.md#o-repositório-inalcançável) |
| `interrupted_by_user_id` | 1 | `syncs` | [coleta.md](coleta.md) |
| **`expires_at`** | **0** | — | **a coluna não existe; ver abaixo** |

## A coluna que não existe

A busca por **`expires_at`** foi pedida e não encontrou nada:

```text
$ grep -rn "expires_at" lib priv test
(nenhuma ocorrência)
```

**Nenhuma tabela, nenhum schema, nenhum teste.** Nada nesta plataforma expira por data
gravada. O que mais se aproxima são duas coisas diferentes, e nomeá-las evita a busca de novo:

1. **A sessão** expira por inatividade, não por coluna — `users.session_token` é girado, e
   quem desativa uma conta gira o token junto, exatamente para que "desativar" não signifique
   "desativar daqui a sete dias" (`lib/the_band/tenants.ex:246-249`).
2. **A cota do GitHub** tem janela de reposição, mas ela vem da origem a cada resposta e não é
   persistida como prazo.

Está escrito aqui porque **ausência encontrada é resultado**, e a próxima pessoa que procurar
`expires_at` merece encontrar esta linha em vez de repetir a busca.

## Os três ciclos de vida sem máquina desenhada

Não estão omitidos: estão **declarados como lacuna**, com a razão.

| Coluna | Tabela | Por que não há diagrama |
|---|---|---|
| `hidden_at` | `eo_organizational_roles` | É **um estado só e uma transição só** — o papel some das listas de escolha e continua valendo nos vínculos que já o citam. Um `stateDiagram` de duas caixas não ensina nada que a frase anterior não ensine. |
| `archived_at` | `cmpo_source_repositories` | **Não é estado nosso**: é o `archivedAt` que o GitHub devolve, copiado. A plataforma não o escreve por decisão própria, e por isso ele pertence ao dado observado, não ao ciclo de vida. |
| `no_longer_in_configuration_at` | `project_iterations` | É o `no_longer_observed_at` com outro nome, para a iteração que saiu da configuração do campo do quadro. A máquina é a mesma de [observacao.md](observacao.md); o nome diferente é que a origem aqui é a **configuração**, não a listagem. |

## Cobertura declarada

| | Quantas |
|---|---:|
| tabelas de domínio | **66** |
| tabelas com alguma coluna de ciclo de vida | **51** |
| tabelas com coluna `status` explícita | **3** |
| tabelas **sem** coluna de ciclo de vida | **15** |
| ciclos de vida com máquina desenhada nesta pasta | **7 documentos** |
| ciclos de vida encontrados e **declarados sem diagrama** | **3** (tabela acima) |

As **15 tabelas sem coluna de ciclo de vida** são, na maioria, as que registram **ocorrência** —
algo que aconteceu e não muda: `issue_promotions`, `profile_automation_events`, `raw_payloads`,
`tool_observation_events`, `refused_links`, `unmapped_pattern_decisions`,
`spo_performed_project_activities`. Esta última tem documento próprio
([atividade-executada.md](atividade-executada.md)) justamente porque *"nunca atualiza"* é uma
decisão de desenho que precisa estar escrita, não uma ausência.

Duas dessas 15 **têm** situação, e a têm fora da tabela — é onde quem chega mais se perde:

- **`connected_tools`** não tem coluna de estado. A situação sai do **último evento** de
  `tool_observation_events` (`ended` ou `resumed`), por
  `TheBand.Sources.observation_ended?/1`, e `situacao/1` a compõe com
  `needs_attention_since` para devolver `:ended | :needs_attention | :active`
  (`lib/the_band/sources.ex:259-265`). Houve uma coluna, e ela foi removida de propósito:
  *"A coluna era um terceiro lugar guardando o mesmo"* (`lib/the_band/sources.ex:246-247`).
  Está desenhada em [coleta.md](coleta.md#a-ferramenta-observada).
- **`sro_sprints`** guarda a situação num **booleano**, `completed`
  (`priv/repo/migrations/20260815120000_create_sro_sprints.exs:57`).

### Os quatro estados em booleano

A varredura de `add :<nome>, :boolean` nas 93 migrações devolve **8 nomes de coluna em 8
tabelas**. Quatro são atributo observado, e não situação — `is_default` e `is_protected`
(`cmpo_branches`), `is_primary` (`commit_authors`), `is_draft` (`project_items`); um é
instrução de fluxo (`users.must_change_password`). Os **quatro** restantes respondem
*em que situação está?*:

| Tabela | Coluna | Quem decide | Fonte |
|---|---|---|---|
| `sro_sprints` | `completed` | a origem | `20260815120000_create_sro_sprints.exs:57` |
| `observed_projects` | `closed` | a origem | `20260816200000_create_observed_projects.exs:29` |
| `tool_credentials` | `active` | **nós** | `20260809120400_create_sources_and_credentials.exs:52` |
| `issue_mapping_rules` | `active` | **nós** | `20260811200000_create_issue_mapping_rules.exs:48` |

Um booleano responde *terminou?* e não *quando, e por quem* — e é a forma que o resto desta
base abandonou em favor do par de datas. Os dois primeiros são **cópia da origem** (o GitHub
diz se o sprint acabou e se o quadro fechou), e aí o booleano é fiel ao que se observou.

Os dois `active` são **decisão nossa guardada em booleano**, e essa é a divergência de padrão
de verdade: desativar uma credencial ou uma regra de mapeamento não deixa data nem autor, e a
pergunta *"desde quando, e por quem"* fica sem resposta. Fica registrado para quem mantém
`Sources` e `Mapping` decidir; **não é achado de defeito** — é diferença entre esta parte e as
outras 9 tabelas de declaração, que gravam `revoked_at` e `revoked_by_user_id`.

## As sete máquinas

| Documento | O que responde |
|---|---|
| [`declaracao-revogavel.md`](declaracao-revogavel.md) | a família de **9 tabelas** em que a organização declara algo sobre o próprio processo, e pode revogar |
| [`atividade-executada.md`](atividade-executada.md) | por que a ocorrência **nunca é atualizada**, e o que são a promoção e a complementação |
| [`observacao.md`](observacao.md) | o que acontece quando a origem **para de mostrar** um registro, nas 23 tabelas que marcam ausência |
| [`conta.md`](conta.md) | quem entra, quem parou de entrar, e qual pessoa observada é aquela conta |
| [`coleta.md`](coleta.md) | a execução de coleta, a ferramenta observada e a credencial |
| [`projeto-declarado.md`](projeto-declarado.md) | o projeto declarado e seus quatro tipos de vínculo |
| [`vinculo-de-equipe.md`](vinculo-de-equipe.md) | o vínculo de pessoa a equipe — quatro campos, cinco situações *(anterior a esta leva)* |

## Como ler qualquer uma delas

Em toda máquina desta pasta vale a mesma convenção, porque ela vem do código:

- **um nome de estado é uma combinação de nulos**, e a combinação está escrita na tabela que
  abre cada documento;
- **toda transição leva o gatilho** — a função que escreve, com `arquivo:linha`;
- **toda transição leva o teste que a prova**, ou a declaração de que não há teste;
- **o que a casa recusa vira nota, nunca seta** — uma seta que o código não escreve é uma
  afirmação falsa com aparência de autoridade.
