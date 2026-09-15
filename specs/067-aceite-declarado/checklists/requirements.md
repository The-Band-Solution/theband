# Specification Quality Checklist: O critério de aceite declarado pela organização

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details — a spec cita ids da ontologia (domínio) e nomes do dado
      observado (`state`, estágio); nenhum módulo, tabela nova ou tecnologia é prescrito
- [x] Focused on user value and business needs — a aceitação passa a existir onde a organização
      declarar; o retrabalho vira medida
- [x] Written for non-technical stakeholders — cada número tem origem e data; a decisão central
      está em prosa
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — zero; a pessoa mantenedora decidiu o caminho (c)
      em 2026-09-14
- [x] Requirements are testable and unambiguous — FR-009 enumera as quatro situações e a quinta
      à parte; FR-008 diz de onde a fase de sucesso NÃO pode vir
- [x] Success criteria are measurable — 10, 0, 119, 80, 100%, zero
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined — 19 cenários em 5 histórias
- [x] Edge cases are identified — 11, inclusive o robô, a reavaliação, a reabertura, a coleta
      parcial e o estágio renomeado
- [x] Scope is clearly bounded — Out of Scope com 6 exclusões, cada uma com destino
- [x] Dependencies and assumptions identified — 6 dependências, 9 premissas

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001..005 ↔ US1;
      FR-006..011 ↔ US2; FR-012..013 ↔ US3; FR-014..015 ↔ US4; FR-016..018 ↔ US5
- [x] User scenarios cover primary flows — declarar, ver, contar, retrabalho, sprint
- [x] Feature meets measurable outcomes defined in Success Criteria — SC-002/003 exercitam o
      quadro 43 com os números coletados
- [x] No implementation details leak into specification

## Notes

- Validado em 2026-09-14 numa iteração. Nenhum item reprovado; nenhuma decisão pendente.
- **Emenda do mesmo dia**: a US1 e a FR-001/003/006 passam ao gesto em dois passos — estágio de
  avaliação + sentido de cada saída (aceito · não aceito · sem veredito); saída não classificada
  fica *não declarada*. Revalidado: os cenários continuam Given/When/Then e testáveis.
- **Dependência de ordem**: o plano desta spec vem depois do da 066 (períodos de estágio) — a
  avaliação é datada pelos períodos.
- **Protótipo antes do código** para a declaração no quadro, o detalhe do item, o painel da
  pessoa, a tela da equipe e o sprint.
- **Sprint backlog antes de implementar** (L108).
