# Sprint 024 — Registro de aceitação

**Avaliado em**: 2026-08-29, na `main` (PRs #593 e #594 mergeados), pelo papel de
product-owner com evidência executada — 13 evidências (E1–E13), incluindo sonda
independente fora da árvore. **Confirmado pela pessoa mantenedora em 2026-08-29**,
nas duas decisões reservadas ao papel: leitura ESTRITA do AS1 da US1, e revisão
pós-merge pedida (comentários nos #593/#594 mencionando quem revisa).

## Veredito por user story

| US | Issue | Veredito | Critério decisivo |
|---|---|---|---|
| 047/US1 — erros no catálogo | #573 | **NÃO ACEITA** | Contraexemplo executável: recusas em literal via assign renderizado (`access_scopes_live/index.ex:87,90,105` → `:144`), fora do catálogo E fora de `pendencias.md`. O SC-001 vale na letra (a regra só vigia `put_flash`) e é falso na substância — e a qualificação da spec dependia da enumeração, que faltou |
| 047/US2 — sistema no catálogo | #574 | **NÃO ACEITA** | "Escopo %{nivel} concedido." / "Escopo revogado." em literal (`:83`, `:102` → `:145`); o método de `pendencias.md` (grep de notices) é cego à classe assign+div — a tela não aparece na lista. FR-007 permanece não exercitado (zero comentários de decisão migrados) |
| 047/US3 — idioma | #575 | **ACEITA** com ressalvas | Troca por UMA config provada com frase vinda só do `.po`; lacunas `en: 0`, `pt: 132` nomeadas. Ressalvas: o corpo da US ainda diz "português padrão" (a correção R2 não alcançou o parágrafo); o relatório enumera lacunas DO catálogo — o que nunca entrou nele é invisível também ali |
| 048/US1 — botão da chave | #587 | **ACEITA** com ressalvas | 5 cenários + SC-001..003 com evidência, incluindo a sonda do leitor comum (E9) e a fila Oban vazia na violação. Ressalvas: "Start run" da spec corresponde a "Turn on"/"run now" na tela (o segundo sem asserção própria, coberto por identidade de condição); `rodada_test` mudou de veículo com razão registrada; o teste do leitor comum tem corpo em `if` — mitigado pela sonda, frágil a mudança de fixture |

**Composição do entregável do sprint**: #575 e #587
(`sro.sprint_deliverable_composed_of_accepted_deliverable`). As tarefas 047/T001–T011
classificam como `sro.non_successfully_performed_scrum_development_task` no que toca
US1/US2; as da 048, executadas com sucesso.

## O retrabalho, nomeado e finito

Migrar ou enumerar a classe **"assign de mensagem renderizado"**:
`access_scopes_live` (5 frases), `projects_live/index.ex:349,353,356` (3),
`sync_live/mapping_rules.ex:49` (`humanizar/1`) — e ampliar a fronteira do
verificador para essa classe POR AST (nunca regex larga), com `pendencias.md`
corrigido. Entra **em primeiro lugar** no backlog do sprint 025 (herança antes de
escopo novo), como tarefas novas ligadas às mesmas US — nunca reabertura das
executadas. O esforço já gasto conta em `rework.not_accepted_deliverable_ratio`.

## Violações de processo registradas

1. **Revisão nunca pedida, duas vezes** (E10: zero eventos `review_requested`,
   zero revisões, merge pelo autor nos dois PRs). Decisão da pessoa mantenedora:
   **revisão pós-merge** — pedida em 2026-08-29 por comentário nos #593/#594 a
   Adylla027/EduardoNFraiz; o resíduo fecha quando a revisão existir registrada.
2. **PRs fora do Projects v2** (`projectItems: []`) — o board não viu o sprint;
   medidas de fluxo subcontaram.
3. **Issues fechadas antes deste registro** (14:51–14:52) — ordem invertida;
   mantidas fechadas para não apagar histórico, o retrabalho entra como tarefas
   novas.

## As correções de spec — todas legítimas

As cinco correções do sprint (idioma padrão, 55→137, default_locale runtime, chave
por tenant, defesa nascendo na 048) são correções de premissa contra dado medido,
registradas com data e razão — nenhuma enfraquece critério; a da defesa o
fortalece. Única sobra: o parágrafo da US3, já listado no retrabalho.
