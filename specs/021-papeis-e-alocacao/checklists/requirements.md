# Specification Quality Checklist: os papéis, e quem os desempenha

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota.** A spec nomeia `eo_team_memberships`, `organizational_role_id` e as três contagens do
banco. São **medida do estado atual**, na seção que existe para isso — e é o que explica por que
a feature é bloqueio e não melhoria: a coluna é `NOT NULL` e não há papel para preenchê-la.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

**A pergunta que tinha resposta, e por isso não virou pergunta**: uma pessoa pode ter dois papéis
na mesma equipe? **Pode.** Acumular Developer e Scrum Master é comum em Scrum, e recusar
produziria uma plataforma incapaz de descrever times reais. A unicidade ficou por pessoa, equipe,
papel e período vigente — virou a FR-006a.

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## O que a análise já achou, antes do plano

Nona feature seguida com defeito de desenho encontrado na fase de análise. Aqui são **dois**, e
os dois são de distinção achatada — a família que este repositório mais atrai:

**1. Declaração e observação no mesmo lugar.** O vínculo é humano; a evidência é da origem. Uma
tela que mostrasse "Developer" sem dizer que alguém digitou aquilo transformaria declaração em
observação, e é o oposto do que a plataforma inteira defende. Virou a **US3 inteira**, com
prioridade P1 — e não uma linha de interface.

**2. A coleta apagando o que a coleta não produziu.** Quando a origem deixa de mostrar a pessoa
na equipe, a evidência é marcada como não mais observada. Se o vínculo fosse junto, uma coleta
apagaria uma declaração humana. Virou **FR-014** e **SC-005**.

## Notes

- **`MAINTAINER` e `MEMBER` continuam não sendo papéis.** A feature não os promove
  automaticamente, e a SC-006 é a asserção disso: nenhuma tela apresenta nível de acesso como
  papel;
- a plataforma **sugere** os quatro papéis do Scrum e **não** os cadastra — quem reconhece o
  papel é a organização, e a SC-004 mede exatamente isso.
