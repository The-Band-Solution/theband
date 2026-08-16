# Specification Quality Checklist: Geração mensal dos perfis de competência

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-16
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

**O marcador aberto foi resolvido em 2026-08-16.** `FR-018` — quem decide que o texto existe
— não tinha padrão razoável: as quatro opções implicavam produtos diferentes, e escolher por
conta própria seria decidir em silêncio o que a 026 registrou como decisão com autor e data.
A pessoa mantenedora decidiu pela organização inteira, ligada por quem administra, e o
resíduo da escolha está escrito na spec, na seção da `FR-018`.

**Três clarificações da mesma sessão**, registradas em `## Clarifications`:

- a automação **nasce desligada** — nenhum texto passa a existir por efeito de deploy
  (`FR-018a`, `SC-010`);
- "a cada 3 meses" é o **M**, e não a cadência: a rodada continua mensal, e os dois ramos
  da `FR-006` alcançam gente diferente;
- **acumulativo vale para os dois lados** — o material de cada geração é o histórico inteiro
  da pessoa, e o perfil anterior continua gravado (`FR-022`, `FR-023`, `SC-009`).

**Duas verificações que passaram por pouco, e o que as salvou:**

- *"Sem implementação"* — a spec nomeia cron, base de conhecimento versionada e credencial
  cifrada. Cada um está aqui como **fato já decidido do produto**, e não como escolha
  técnica desta feature: o agendamento próprio é a fronteira entre coletar e interpretar
  (`FR-002`), a base versionada é onde os pisos da 026 já moram, e a cifragem é requisito de
  segurança. A escolha de biblioteca, tabela e formato fica para o `plan.md`;
- *"Critérios mensuráveis"* — `SC-002` fixa 6 de 34 com N=10, número da medição de
  2026-08-16. Ele vale como critério **desta base**, e `FR-021` obriga a recontagem antes de
  os limiares serem fixados. Se a recontagem mudar o número, `SC-002` muda junto — e isso é
  correção de spec, não descumprimento dela.

Itens marcados como incompletos exigem atualização da spec antes de `/speckit-plan`.
