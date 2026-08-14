# Retomar — feature 022, a timeline das issues

**Parado em**: 2026-08-14 · **Branch**: `049-timeline-atividade`

## Estado em uma linha

**F1 feita e testada** (T001–T004). Faltam F2, F3 e F4 — nove tarefas. A PR #321 (só
documento) foi mergeada em `154e1ff`, e o conteúdo foi conferido na main — não pelo
assunto do commit, que num squash diz pouco.

---

## O primeiro passo ao voltar

```bash
set -a && . ./.env && set +a      # a chave mestra mora aqui; mix run sobe a app e precisa dela
mix test test/the_band/ontology/seon/spo/    # 10 testes, o chão da F1
```

Depois é T005, na ordem abaixo.

---

## O que está feito

| Tarefa | O que entregou |
|---|---|
| T001 | migração `spo_performed_project_activities` — ida e volta provada |
| T002 | `internal_id/1` pelo critério da ontologia, com marcador explícito de ausência |
| T003 | `record_activity/2` — `:created` ou `:unchanged`, **nunca** `:updated` |
| T004 | `list_activities/3` crescente e `count_activity_types/1` |

**10 testes passam.** Credo limpo, formatado.

Arquivos: `lib/the_band/ontology/seon/spo.ex` (fachada), `spo/commands.ex`,
`spo/queries.ex`, `spo/schemas/performed_project_activity.ex`,
`test/the_band/ontology/seon/spo/atividade_test.exs`.

### Uma decisão que vale reler antes de mexer

O hash de identidade dos outros módulos usa `to_string/1`, e `to_string(nil)` é `""`.
Aqui isso seria defeito: `source_external_id` é texto da origem, e a que **não deu**
identidade ao evento colidiria com a que deu uma **vazia**. O marcador de ausência é
`"\x00"`, explícito, e há teste afirmando que os dois não colidem.

---

## O que falta, na ordem

### F2 — coletar (T005, T006, T007, T008)

Ponto de entrada: `lib/the_band/ingestion/github_work_items.ex`, e a consulta em
`priv/connectors/github/queries/issues.graphql`.

- **T005**: `timelineItems(first:, itemTypes: [...])` na consulta da issue. **Já medido
  em 2026-08-14**: vem junto, aceita `itemTypes:`, e o máximo numa issue foi 18 — a
  página de 100 cobre com folga. `IssueComment` **fica de fora** (é a #318);
- **T006**: cada nó vira `record_activity/2` com `subject_type: "issue"`. A asserção do
  teste é a **soma** — classificados mais sem conceito igual ao total recebido (SC-003).
  *"Os eventos apareceram"* passaria igual com o descarte;
- **T007**: a timeline entra na janela da 020. `percorrer?/2` já existe em
  `github_work_items.ex:199`. **O teste tem de reprovar se `timelineItems` for pedido**
  para repositório parado — "não trouxe eventos" não prova que não pediu;
- **T008**: o login do autor resolve por `ctx.pessoas` (o mesmo mapa de `gravar_issue/3`,
  linha 503). Login não resolvido grava `performer_login` com `performer_id` nulo, e
  **não cria pessoa**.

### F3 — a tela (T009, T010, T011)

`work_item_live/show.ex`. A T010 é a que recusa: `{:error, :no_start_signal}`, e
`refute html =~ "lead time"` no bloco de cycle time.

### F4 — as máximas (T012, T013)

Detecção lendo as regras da base, **nunca de lista fixa no código**. A T013 sinaliza os
dois antipadrões estruturais, e **o caso que importa é o negativo**: quadro com
`In Progress` não sinaliza.

---

## As três causas de `no_start_signal`, que não se resolvem no mesmo lugar

Está no contrato, seção 5, e é o que a implementação da T010 tem de respeitar:

| Situação | O que falta | Onde se resolve |
|---|---|---|
| há movimentação, nenhuma regra diz qual marca o início | a declaração | feature própria |
| o quadro não tem estado de "em andamento" | o estado | **no quadro**, `ap05` |
| não há movimentação coletada | a coleta | aqui |

Confundi-las é a L57. Nenhuma se resolve mostrando um número.

---

## Decisões suas que ainda estão abertas

1. **Qual movimentação marca "peguei"** neste quadro. A medida tornou concreto: os
   estados são `Backlog`, `Ready`, `In review`, `Done` — e se a resposta for "nenhuma",
   o `ap05` é a resposta da plataforma, e a correção é no quadro;
2. **acrescentar o estado de andamento no quadro** — independente do código, e quanto
   antes existir, mais movimentação real a primeira coleta encontra. Vale só para
   frente: issue que já percorreu o fluxo antigo não ganha movimentação retroativa;
3. migração do Oban v12 → v14 (dívida separada, registrada em `config/test.exs`).

---

## O que ficou medido pela metade

Sondei quatro repositórios e **dois voltaram `NOT_FOUND`** — pareei repositório com a
organização errada. A comparação entre quadros se apoia em **dois**, não quatro. O
achado sobrevive (um tem estado de andamento, o outro não), mas não sustenta dizer quão
comum é. Refazer a sondagem com os pares certos é trabalho de meia hora, e a PR #321 já
declara a lacuna.
