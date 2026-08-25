# Specification Quality Checklist: O critério de início, declarado pela organização

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-24
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota sobre nomes técnicos.** A spec cita `ProjectV2ItemStatusChangedEvent`,
`spo_project_boards.linked_at` e `collected_at`. Não são detalhe de implementação: são
**os nomes que a origem e o esquema já usam**, e a decisão de precedência é sobre eles
especificamente. Trocá-los por descrições genéricas tornaria a `FR-007` não-verificável —
"a data do vínculo" não diz qual das três datas disponíveis.

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

## O que foi decidido sem perguntar, e por quê

Três pontos ficaram sem `[NEEDS CLARIFICATION]` porque a decisão já veio da pessoa
mantenedora na conversa que originou a spec:

| ponto | decisão | de onde veio |
|---|---|---|
| por projeto ou por quadro | **ambos, com escala** | *"podemos fazer uma escala, sendo que o quadro vence o projeto"* |
| como desempatar | **`linked_at` mais recente** | *"tem que ser `linked_at`"* |
| conceito ontológico | **sim**, `ufo.social_object` | *"colocar um conceito ontológico nisso?"* |

Um ponto ficou **declarado como revisável** em vez de virar pergunta: issue em quadros de
**projetos diferentes**. Nenhum caso existe no dado de 2026-08-24, e travar a spec numa
pergunta sobre caso inexistente custaria mais que registrar o padrão e corrigir na revisão.

## O que a spec deliberadamente NÃO resolve

- **O critério de fim.** `flow.wip.count` precisa de início **e** fim, e esta feature entrega
  metade. Está na seção de Assumptions como limitação declarada — não como esquecimento.
- **Sugerir o critério.** Mostrar volume é informar; recomendar é escolher com passos extras,
  e a `FR-007` da feature 022 proíbe.

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
- **Depende da feature 041** ([PR #458](https://github.com/The-Band-Solution/theband/pull/458)),
  ainda não mergeada: a `FR-007` opera sobre `spo_project_boards.linked_at`, criada lá.
