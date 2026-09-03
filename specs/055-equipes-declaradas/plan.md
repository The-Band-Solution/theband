# Implementation Plan: A organização declara suas equipes

**Branch**: `feat/055-equipes-declaradas` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/055-equipes-declaradas/spec.md`

## Summary

**O domínio está mais pronto do que o pedido sugeria, e menos do que parece.**
`eo_teams` tem `declared_by_user_id`; `eo_team_memberships` tem `started_at`,
`ended_at`, papel e autor; a evidência observada é tabela separada desde
2026-08-09; e `EO.Commands.create_declared_team/3` já existe.

O que falta é de três tipos, e só o primeiro é código de domínio novo:

1. **a composição entre equipes** — não existe campo nem tabela;
2. **os comandos que faltam** — declarar vínculo, registrar saída, registrar
   equívoco, compor e descompor;
3. **as telas** — hoje `teams_live` só busca, ordena e pagina.

## Technical Context

**Language/Version**: Elixir 1.17, Erlang/OTP 27
**Primary Dependencies**: Phoenix 1.8 (LiveView), Ecto, PostgreSQL
**Storage**: PostgreSQL — **uma migração nova** (composição) e **três colunas**
no vínculo existente
**Testing**: ExUnit; os invariantes são de histórico, e a prova é a violação
**Target Platform**: monólito modular multitenant
**Project Type**: web
**Performance Goals**: nenhuma nova. A organização de referência tem **12
equipes**; a detecção de ciclo é sobre esse conjunto
**Constraints**: nenhuma linha removida fisicamente (FR-006); nenhum número de
período anterior muda ao registrar saída (FR-005)
**Scale/Scope**: 12 equipes e 88 pessoas hoje; a estrutura aceita N

## Constitution Check

| Princípio | Situação |
|---|---|
| **I. Domínio pelas ontologias** | a composição entre equipes precisa de conceito na EO — **não pode nascer só como tabela**. Ver decisão 1 |
| **II. Fonte externa não é domínio** | preservado: a camada declarada é acrescida, e a coleta continua mandando no que ela vê (FR-012) |
| **III. Proveniência e idempotência** | é o coração da feature. `declared_by_user_id` em tudo; nada é removido |
| **V. Monólito modular multitenant** | toda consulta escopada (FR-010) |
| **VI. Spec Kit antes do código** | cumprido |
| **VII. Gates e revisão independente** | 14 gates; revisão pedida **e conferida** (L89) |
| **VIII. Desenho que o problema justifica** | cinco decisões abaixo, duas delas de NÃO fazer |
| **X. Responsabilidade única** | a tela de equipe faz equipe; vínculo e composição são seções dela, não telas novas |
| **XI. Estado conferido, sinal nunca silenciado** | as recusas — ciclo, duplicata, sem permissão — são relator, nunca silêncio |

### As decisões de desenho (princípio VIII)

> **Corrigido durante a execução (T002), com a razão — L82.** O plano dizia
> **módulo novo** `team_composition.yaml`. Ao abrir o módulo existente, achei
> `eo.organization_part_of_organization` — `part_whole` com
> `temporal: historical_relation`, e `eo.team` na mesma vizinhança. A composição
> de equipes é **a mesma forma, entre outros dois nós**: módulo novo para uma
> relação seria estrutura sem problema que a justifique (princípio VIII). Ela
> entrou como `eo.team_part_of_team` no `organizational_structure.yaml`, e
> **aparece em `docs/ontology/eo.md`** — que era o que a #527 exigia provar.

**1. Tabela própria para a composição, e conceito na EO — não `parent_team_id`.**

- *Problema*: declarar que uma equipe faz parte de outra, **com autor e data**, e
  poder desfazer sem apagar.
- *Existe agora*: sim — é o pedido, e a hierarquia é metade dele.
- *Alternativa descartada*: uma coluna `parent_team_id` em `eo_teams`. Ela não
  carrega quem declarou nem quando, o que a torna a versão booleana do relator —
  o antipadrão nomeado em `AGENTS.md` §7.7. E amarra a uma composição por equipe.
- *O que piora*: uma tabela a mais, e a consulta de hierarquia deixa de ser um
  `JOIN` e vira caminhada.

**2. O equívoco é registrado no vínculo, com três campos — não um `DELETE`.**

- *Problema*: o FR-006 exige desfazer um vínculo que **nunca vigeu**, sem apagar,
  e distinguindo-o de quem saiu.
- *Existe agora*: sim. Sem isso, "remover" viraria `DELETE`, e o histórico
  desapareceria — que é o que o SC-003 proíbe.
- *Alternativa descartada*: `ended_at = started_at`. Diria "durou zero" e perderia
  **a razão** — e a razão é o que distingue engano de saída no mesmo dia.
- *O que piora*: mais três colunas, e **toda consulta de vínculo vigente passa a
  ter duas condições** em vez de uma. É o custo real, e ele reaparece em cada
  consulta nova.

**3. A detecção de ciclo caminha em memória, sem consulta recursiva.**

- *Problema*: o FR-009 proíbe ciclo por caminho de qualquer comprimento.
- *Existe agora*: sim, mas em escala pequena — **12 equipes**.
- *Alternativa descartada*: `WITH RECURSIVE`. Correta e mais cara de ler, para um
  conjunto que cabe na memória com folga.
- *O que piora*: **a solução tem prazo de validade**. Fica declarado como
  limitação: acima de alguns milhares de equipes, a caminhada passa a pesar, e a
  troca por consulta recursiva é a correção. Limitação escrita não vira surpresa.

**4. NÃO generalizar `create_declared_team/3` agora.**

- *O que ela é hoje*: cria `type: "project_team"`, **sem organização**, e o
  moduledoc explica por quê — o que justifica aquele tipo é o vínculo com
  projeto. Serve à feature 028.
- *Por que não mexer*: a equipe desta feature é da **estrutura da empresa**, tem
  organização, e outro tipo. Generalizar a função existente misturaria dois casos
  cujas invariantes diferem, e quebraria a 028 para servir a 055.
- *O que se faz*: uma função irmã, ao lado, com o tipo e a organização que esta
  feature exige. **Duplicar duas vezes é barato; abstrair cedo e errado é caro** —
  na terceira ocorrência se saberá o que varia.

**5. NÃO construir o rollup de competências.**

- *O que resolveria*: a soma das competências pela hierarquia, que a issue #397
  pede.
- *Existe agora*: não como problema desta entrega. Ele **depende** da composição,
  que é o que esta feature cria.
- *O que ficaria pior*: as duas juntas num diff só, e a aceitação sem saber qual
  delas quebrou.

## Project Structure

### Documentation (this feature)

```text
specs/055-equipes-declaradas/
├── spec.md
├── plan.md              # este arquivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1 — a tabela nova e as três colunas
├── quickstart.md        # Fase 1 — como validar, incluindo o SC-003
├── contracts/
│   └── equipes-declaradas.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
priv/knowledge_base/ontology/seon/eo/modules/
└── organizational_structure.yaml  # +1 relação: eo.team_part_of_team (ver a correção abaixo)

priv/repo/migrations/
└── <ts>_composicao_de_equipes_e_o_equivoco.exs   # NOVO

lib/the_band/ontology/seon/eo/
├── schemas/team_composition.ex    # NOVO
├── schemas/team_membership.ex     # +3 campos do equívoco
├── commands.ex                    # declarar equipe da estrutura, vínculo, saída, equívoco, compor
└── queries.ex                     # hierarquia, e o vigente com as duas condições

lib/the_band_web/live/teams_live/
├── index.ex                       # criar equipe
└── show.ex                        # vincular, registrar saída, desfazer engano, compor

test/the_band/ontology/seon/eo/
├── team_composition_test.exs      # NOVO — ciclo, e o caminho longo
└── team_membership_test.exs       # saída, equívoco, duplicata vigente
```

**Structure Decision**: tudo dentro de `ontology/seon/eo/`, onde as equipes já
vivem. Nenhum contexto novo: a tela chama `EO.Commands` e `EO.Queries`, que é
como ela já chama hoje.

## Complexity Tracking

Nenhuma violação a justificar. As cinco decisões estão registradas acima, e
**duas são de NÃO fazer** — o que o princípio VIII pede que apareça.
