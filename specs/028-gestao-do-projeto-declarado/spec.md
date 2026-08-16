# Feature 028 — Gestão do projeto declarado

**Criada**: 2026-08-16 · **Origem**: pedidos da pessoa mantenedora na tela `/projects`
(issues #385, #386, #387) · **Estende**: feature 025

## O propósito

O projeto declarado ganhou cadastro na 025 e ficou sem ciclo de vida: não se edita, não
se remove, não diz quais organizações o alimentam nem quem trabalha nele. Esta feature
fecha o ciclo — **sem tocar no que é observado**: quadro, repositório e issue continuam
imutáveis pela tela.

## User stories

- **US1 (P1, #385)** — Como administradora, edito nome e período de um projeto declarado,
  e removo um projeto que declarei por engano, para o cadastro refletir a organização real.
- **US2 (P2, #387)** — Como administradora, associo organizações observadas ao projeto,
  para que o seletor de repositórios ofereça só o que essas organizações alcançam.
- **US3 (P2, #386)** — Como administradora, associo equipes ao projeto — e crio uma equipe
  declarada quando ela não existe na origem — para responder *quem trabalha neste projeto*.

## Functional requirements

- **FR-001**: Editar projeto MUST alcançar nome, início e fim. O autor da última edição
  MUST ser gravado (`updated_by_user_id`).
- **FR-002**: Remover projeto MUST ser **marca**, nunca apagamento — `removed_at` e
  `removed_by_user_id`. Projeto removido sai das listagens e permanece consultável no banco.
- **FR-003**: Remover projeto que tem partes MUST ser recusado com a frase dizendo o
  motivo. As partes são movidas ou removidas primeiro — remover em cascata apagaria
  declarações que ninguém pediu para apagar.
- **FR-004**: A associação projeto↔organização MUST ser N:N, com autor e vigência
  (`linked_by/at`, `unlinked_by/at`) — o mesmo desenho de projeto↔repositório.
- **FR-005**: Com uma ou mais organizações associadas vigentes, o seletor de repositórios
  MUST oferecer apenas repositórios dessas organizações. Sem associação, oferece todos —
  compatível com hoje, e a ausência do filtro MUST ser dita na tela do seletor.
- **FR-006**: A associação projeto↔equipe MUST ter o mesmo desenho da FR-004.
- **FR-007**: Criar equipe declarada MUST produzir `eo_teams` com `type: "project_team"`,
  proveniência `source_system: "the_band"` / `source_instance: "declared"`, autor gravado,
  e **sem organização** — o que a justifica é o vínculo com o projeto, exatamente como o
  schema da EO já documenta.
- **FR-008**: A tela MUST distinguir equipe declarada de equipe observada — o produto
  existe para separar o que observou do que alguém declarou.
- **FR-009**: Membros de equipe declarada estão **fora desta feature**: pertencer exige
  papel organizacional (#99/#100), e criar membership sem papel violaria a regra da EO. A
  equipe nasce vazia e a tela diz isso.

## Success criteria

- **SC-001**: editar e remover aparecem só para admin; a remoção com partes é recusada com frase.
- **SC-002**: projeto com organização associada mostra no seletor só os repositórios dela;
  sem associação, todos — e o seletor diz qual dos dois está acontecendo.
- **SC-003**: equipe criada pela tela aparece em `/teams` como declarada, distinta das
  observadas, e nenhuma consulta de coleta a marca como ausente (ela não veio da origem).
- **SC-004**: nenhuma mudança em tabela observada — o diff não toca coleta.

## O que esta feature NÃO faz

| Fora | Por quê |
|---|---|
| membros em equipe declarada | exige papel organizacional — #99/#100 |
| editar/remover equipe declarada | ciclo de vida de equipe é feature própria |
| promover project_team a conceito além do que a EO já diz | a promoção é o vínculo, não um ato extra |
| restringir o filtro da FR-005 quando não há associação | quebraria os 4 projetos existentes sem aviso |
