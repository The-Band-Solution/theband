# Fase 0 — Pesquisa: o que já existe, lido no código

Cada achado abaixo foi verificado na fonte. O que não foi verificado está dito
como não verificado.

## R1 — O modelo já tem dois terços da feature

| peça | onde | estado |
|---|---|---|
| equipe com autor da declaração | `eo/schemas/team.ex` — `declared_by_user_id` | **existe** |
| vínculo com período e papel | `eo/schemas/team_membership.ex` — `person_id`, `team_id`, `organizational_role_id`, `started_at`, `ended_at`, `declared_by_user_id` | **existe** |
| evidência observada, separada | `eo/schemas/team_membership_evidence.ex` | **existe** desde 2026-08-09 |
| criar equipe declarada | `EO.Commands.create_declared_team/3` | **existe** — ver R2 |
| composição entre equipes | — | **não existe**, nem campo nem tabela |
| comandos de vínculo declarado | — | há `record_derived_team_membership/2`, que é **derivado**, não declarado |
| telas | `teams_live/index.ex`, `show.ex` | só `buscar`, `ordenar`, `pagina` |

**Consequência para o plano**: a `started_at`/`ended_at` que a US2 precisa **já
está lá**. O que falta no vínculo é só o registro do equívoco.

## R2 — `create_declared_team/3` existe, e não serve a esta feature

Lida no código: ela cria `type: "project_team"`, **com `slug: nil` e sem
organização**, e o próprio moduledoc explica por quê — *"o que justifica o tipo é
o vínculo com projeto, e a EO permite organização nula exatamente para ele"*.
Serve à feature 028.

A equipe desta feature é da **estrutura da empresa**: tem organização, e outro
tipo. **Decisão**: função irmã, não generalização — ver a decisão 4 do plano.

**Alternativa considerada**: acrescentar parâmetros opcionais à existente.
Descartada porque as invariantes diferem (organização nula é *exigida* lá, e
*proibida* aqui), e uma função com invariante condicional ao parâmetro é a que
ninguém consegue ler depois.

## R3 — A escala que justifica caminhar em memória

Medido no banco de desenvolvimento: **12 equipes** e **88 pessoas**. O ensaio de
restauração de 2026-08-31 confirmou os mesmos números pela imagem.

Com 12 nós, a detecção de ciclo por caminhada carrega o grafo inteiro em uma
consulta e resolve em memória. `WITH RECURSIVE` seria correto e mais caro de ler.

**A limitação fica declarada**: acima de alguns milhares de equipes a caminhada
passa a pesar, e a troca por consulta recursiva é a correção. **Não é dívida
escondida — é escolha com prazo, escrita.**

## R4 — O índice parcial único é o padrão da casa para vigência

O FR-007 (não vincular duas vezes vigente) é o mesmo problema que a feature 045
resolveu no elo pessoa↔conta: **índice parcial único** sobre as colunas do
vínculo, `WHERE` a linha está vigente.

Com o equívoco, a condição do índice ganha o segundo termo — vigente é *sem fim*
**e** *sem invalidação*. É o custo real da decisão 2, e ele aparece aqui.

**Por que índice e não consulta prévia**: a consulta prévia perde a corrida entre
duas abas. A 052 provou isso — a garantia contra dois administradores veio dos
índices únicos, não de um `SELECT` antes do `INSERT`.

## R5 — O que a coleta faz com a equipe declarada, e por que ela não some

`create_declared_team/3` grava proveniência `the_band/declared`, e o moduledoc
registra a consequência: *"a coleta nunca a marca como ausente, porque ela não
veio da origem"*.

**Verificado**: o corte de ausência (`no_longer_observed_at`) roda sobre o que a
origem devolveu. Equipe declarada não está lá, logo não entra na comparação.

Isso **não foi testado** para a composição — que é tabela nova e não passa pela
coleta. Fica como caso a cobrir: coletar não pode desfazer composição declarada.
