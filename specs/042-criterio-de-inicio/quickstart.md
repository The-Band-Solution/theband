# Quickstart: provar que o critério de início funciona

**Feature**: 042 · **Data**: 2026-08-24

O que rodar e o que precisa aparecer. Não traz código de implementação.

## Antes

```bash
set -a && . ./.env && set +a
mix ecto.migrate
mix knowledge.validate      # reprova se spo.activity_start_criterion faltar — FR-001
mix phx.server
```

Um projeto com pelo menos um quadro associado e issues nele. No banco de desenvolvimento, **Conecta Fapes** serve depois de associados os quatro quadros.

---

## 1. Sem critério, nada é afirmado — `FR-004`

Entre em `/projects` e abra um projeto sem critério declarado.

**Esperado**: a seção do critério diz, **em frase**, que nenhum critério foi declarado — e **quantas** atividades estão sem instante de início por causa disso. Nenhum código como `criterio_ausente` aparece na tela (`SC-008`).

---

## 2. Declarar mostra o volume, e não recomenda — `FR-012`

Clique em declarar.

**Esperado**: a lista traz só tipos que a coleta tem, **com o volume de cada um** — `ProjectV2ItemStatusChangedEvent` 5.965, `AddedToProjectV2Event` 3.028, `AssignedEvent` 2.172. Nenhum vem marcado como sugerido.

---

## 3. A declaração vale na leitura seguinte — `FR-005`

Declare `ProjectV2ItemStatusChangedEvent` e abra a lista de atividades do projeto.

**Esperado**: as atividades passam a ter instante de início, **e cada uma diz de onde o critério veio** — "pelo projeto Conecta Fapes" (`FR-013`).

Troque para `AssignedEvent`. **Esperado**: os instantes mudam na mesma leitura, **sem nenhuma etapa de recálculo** — não há botão de recalcular, e não deve haver.

---

## 4. O quadro vence, e a tela avisa antes — `FR-006`, `FR-014`

Declare `AssignedEvent` num quadro do projeto. Depois volte a declarar no **projeto**.

**Esperado ao declarar no projeto**: antes de gravar, a tela nomeia **quais quadros vão ignorar** esta declaração, e por quê. Depois de gravar, as issues daquele quadro seguem o critério dele; as demais seguem o do projeto.

---

## 5. O desempate, e a frase quando ele não resolve — `FR-007`, `FR-008`, `FR-016`

Ponha uma issue em dois quadros, ambos com critério, associados ao projeto em instantes diferentes.

**Esperado**: vale o do quadro associado por último.

Agora force o empate — associe dois quadros no mesmo segundo, o que acontece naturalmente em associação em lote.

**Esperado**: o instante fica **ausente**, e a frase **nomeia os dois quadros e a data que empatou**. A plataforma não escolhe (`FR-008`).

---

## 6. As três ausências não se misturam — `FR-009`, `FR-015`

**Esperado**: em qualquer tela que as mostre, aparecem **separadas**, cada uma com frase própria e com o que fazer:

| ausência | a frase diz |
|---|---|
| sem critério | declare um critério para este projeto |
| critério ambíguo | desambigue: estes dois quadros empataram nesta data |
| evento não coletado | o critério pede este evento, e a coleta não o trouxe para esta issue |

Nenhuma soma com outra, e nenhuma aparece como zero.

---

## 7. Desfazer preserva — `FR-010`

Revogue o critério do projeto.

**Esperado**: as atividades voltam a não ter instante; o histórico da declaração **continua**, com quem declarou, quando, e quem revogou.

---

## O que a suíte cobre, e o que só o passo manual cobre

| verificação | teste | manual |
|---|---|---|
| a escala, os quatro ramos da resolução | `criterio_de_inicio_test.exs` | |
| isolamento entre tenants | idem, obrigatório pelo princípio V | |
| resolução em lote não cresce com o número de atividades | teste de custo de consulta | |
| a proveniência aparece junto do número | `criterio_na_tela_test.exs` | |
| nenhum código de motivo renderizado (`SC-008`) | idem, procurando `criterio_` no HTML | |
| **a frase ser compreensível por quem nunca leu a spec** (`SC-007`) | não | **sim** |

A última não tem substituto automatizado: um teste confirma que a frase está lá, não que ela ensina.
