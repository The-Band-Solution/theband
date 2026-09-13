# Specification Quality Checklist: O rótulo como campo do item de trabalho

**Purpose**: Validate specification completeness and quality before proceeding to planning

**Created**: 2026-09-13

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

### Duas correções feitas na validação

**1. Nomes de arquivo e função saíram dos requisitos.** A primeira redação citava
`list_issues`, `queries.ex:543` e `not_type_patterns` dentro das FR. Passaram a descrições em
linguagem de quem usa — *"a listagem"*, *"o detalhe"*, *"a declaração que já recusa esses
prefixos como tipo"*. Os nomes ficaram só na seção de medição, onde são **evidência**, e no
plano, onde são endereço.

O critério da FR-013 é o caso mais claro: dizia *"junção lateral agregada, nunca N+1"* —
mecanismo com nome de requisito. Passou a **"o número de consultas não cresce com o número de
itens"**, que é a propriedade, e que continua verificável.

**2. A FR-012 ganhou o que faltava para ser testável.** Dizia *"a ordem é estável"*, sem dizer
estável em relação a quê. Passou a **"a mesma a cada leitura dos mesmos dados"** — sem essa
cláusula, uma implementação que reordena quando o dado muda passaria, e não é isso que se quer
dizer.

### O que não é detalhe de implementação, apesar de parecer

Os números da seção de medição — 1 733, 1 519, 369, 316 — são **evidência**, não configuração.
Eles sustentam duas afirmações que a spec faz e que não seriam críveis sem eles: que a
caracterização já existe no dado, e que a convenção do prefixo continua crescendo (340 em
agosto, 369 hoje). Tirá-los deixaria a decisão de ler o título parecendo palpite.

### A prioridade que contraria a numeração

A US3 é **P1**, igual à US1, e não P3 como a ordem sugeriria. É deliberado: ela é a regra que
a US1 pode quebrar. Um campo de rótulo ao lado do conceito é exatamente a situação em que
alguém, meses depois, "melhora" a classificação lendo o rótulo — e a US3 existe para que isso
falhe num teste em vez de virar medida errada.

### O que esta validação NÃO substitui

O protótipo foi **aprovado pela pessoa mantenedora** em 2026-09-13, e a FR-015 exige que a
tela entregue seja aquela. Mas ninguém além de quem escreveu leu **esta spec**. A aprovação é
da tela; a conferência do texto ainda não aconteceu.
