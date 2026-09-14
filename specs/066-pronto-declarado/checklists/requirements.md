# Specification Quality Checklist: A definição de pronto declarada pela organização

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — a spec cita `state`/`closed_at`
      e `Status`/opção como **nomes do dado observado**, não como desenho; nenhum módulo, tabela
      ou tecnologia é prescrito
- [x] Focused on user value and business needs — a pessoa do feedback via 23 de 27 entregáveis
      como abertos; a organização decide o que é pronto
- [x] Written for non-technical stakeholders — cada número tem a origem escrita; a decisão
      central está em prosa
- [x] All mandatory sections completed — User Scenarios, Requirements, Success Criteria,
      Assumptions; Dependencies e Out of Scope acrescentadas

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — zero; as quatro decisões da pessoa mantenedora
      de 2026-09-14 fecharam o que estaria em aberto
- [x] Requirements are testable and unambiguous — cada FR tem sujeito, MUST e resultado
      observável; FR-008 enumera os três textos de ausência
- [x] Success criteria are measurable — tempos, contagens (294, 41, zero de diferença), 100%
- [x] Success criteria are technology-agnostic — SC-008 fala em "número de consultas", que é
      medida do custo já usada pela casa, sem nomear tecnologia
- [x] All acceptance scenarios are defined — 19 cenários em 5 histórias, Given/When/Then
- [x] Edge cases are identified — 9, inclusive renomear/remover opção, dois quadros, rascunho,
      duplicada/não planejada, sem instante, reativação
- [x] Scope is clearly bounded — Out of Scope com 8 exclusões nomeadas, cada uma com destino
- [x] Dependencies and assumptions identified — 5 dependências, 7 premissas

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001..006 ↔ US1;
      FR-007..012 ↔ US2; FR-013..014 ↔ US3; FR-015..019 ↔ US4; FR-020 ↔ US5
- [x] User scenarios cover primary flows — declarar, ver, o desacordo, as medidas, o em andamento
- [x] Feature meets measurable outcomes defined in Success Criteria — SC-002/003 exercitam o
      caso real (`#2107`, 294/41)
- [x] No implementation details leak into specification

## Notes

- Validado em 2026-09-14 numa iteração. Nenhum item reprovado.
- **Emenda de 2026-09-14, feita**: a análise da SRO/SPO trouxe os conceitos, e a FR-001 passou a
  citá-los pelo id (`sro.intended_scrum_development_task`, `spo.performed_project_activity` com e
  sem `end_date`, `sro.performed_scrum_development_task`); aceitação **excluída** dos destinos pela
  `sro.rule03`; a regra ganha o id `github.project_item_status`, que `issue_task.yaml` já citava
  sem existir (FR-021); a recusa *"esta coluna não diz fase"* vira destino registrado (FR-022).
- **Segunda emenda, 2026-09-14**: o estágio do quadro preservado ao lado da fase (FR-023), a
  idade no estágio (FR-024), a entidade *Estágio do quadro* e o edge case dos homônimos. E a
  decisão do *Desaprovado* foi tomada pela pessoa mantenedora — caminho (c), critério de aceite
  declarado, spec 067. Nenhuma decisão pendente resta nesta spec.
- **Protótipo antes do código** (FR-015 da casa): as telas tocadas (declaração no quadro,
  detalhe, listagem, painel da pessoa, tela da equipe, quadro) passam pelo papel de Design
  depois desta spec e antes do plano de implementação.
