# Specification Quality Checklist: Papéis por organização

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-24
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota.** A spec cita `eo_team_memberships.organizational_role_id`, `catalog_key` e os
identificadores `sro.*`. São **nomes do esquema e da rede**, e a decisão é sobre eles
especificamente — a `FR-001` fala de uma coluna que falta, e descrevê-la genericamente
tornaria o requisito não-verificável.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## As três decisões, e de onde vieram

| ponto | decisão | frase de origem |
|---|---|---|
| escopo do cadastro | **por organização** | *"o cadastro de papéis é por organização"* |
| quem associa | **uma pessoa, via sistema** | *"quem associa os papéis é uma pessoa via sistema"* |
| os quatro do Scrum | **pré-cadastrados, em todas** | *"esses papéis pré-cadastrados estão em todas as organizações"* |

Nenhuma virou `[NEEDS CLARIFICATION]` porque as três vieram ditas.

## A recusa que a spec protege

A `FR-012` e a `FR-013` existem para impedir o atalho óbvio: o GitHub entrega
`platform_access_level`, e seria fácil pré-selecionar *Scrum Master* para quem é `ADMIN`.

**`ADMIN` diz quem administra membros e permissões. Não diz quem facilita a cerimônia.**
Inferir papel organizacional a partir de acesso é exatamente o que a `FR-007` da feature 021
recusa observar — e o atalho seria invisível, porque produziria uma lista plausível.

A `SC-005` torna isso verificável: o campo de papel começa **vazio** em toda evidência.

## O que a spec deliberadamente NÃO resolve

- **Sugerir papel a partir de comportamento** — quem revisa mais, quem fecha mais tarefa.
  Tem os mesmos riscos da `FR-012` e merece spec própria.
- **Hierarquia de equipes** (#397). Depende desta: hierarquia sem membro não soma nada.

## Notes

- Não depende de PR aberto. `eo_team_membership_evidence` já existe com as 101 linhas, e
  `eo_team_memberships` já tem `declared_by_user_id` esperando.
