# Specification Quality Checklist: Pessoas e equipes separadas por organização observada

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-10
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### Iteração 1 — 2026-08-10

**Ajustes aplicados durante a redação**, a partir da descrição original, que
continha nomes de tabela e de coluna:

- `eo_people.organization_id`, `eo_teams.organization_id` e
  `eo_organization_membership_evidence` saíram do texto. O que permanece é a
  exigência de comportamento: o vínculo admite mais de uma organização por pessoa,
  e exatamente uma por equipe. **Como** isso é persistido é decisão de plano.
- "muitos-para-muitos" e "chave estrangeira" viraram enunciados de regra: FR-001
  admite mais de uma organização por pessoa; FR-005 exige exatamente uma por
  equipe. Um leitor não técnico consegue conferir os dois.
- O caminho `organization.id` do payload, e a razão de ele não existir, saíram da
  spec. É diagnóstico de causa, não requisito — vai para o `research.md`.

**Decisão de escopo registrada em Assumptions**: o vínculo com organização é
evidência, não alocação, pela mesma razão já aceita para o vínculo com equipe. A
alternativa — tratá-lo como emprego ou alocação — foi rejeitada por afirmar o que
a origem não afirma.

**Duas exigências que existem para impedir uma correção errada**:

- FR-015 e SC-004 fixam como as contagens se comportam com pessoas sobrepostas. Sem
  isso, alguém "conserta" a soma que não fecha e passa a contar a mesma pessoa
  duas vezes;
- FR-016 separa "não houve coleta" de "o filtro não devolveu nada". São causas
  diferentes, e um estado vazio genérico faz procurar defeito onde não há.

**Status**: todos os itens passam. A spec está pronta para `/speckit-plan`.

`/speckit-clarify` é opcional: não restam ambiguidades de escopo. As decisões em
aberto — forma de persistência do vínculo, como o retrofito de FR-019 recupera a
organização do que já foi coletado, e como a sobreposição de FR-017 é apresentada
na tela — são matéria de plano.
