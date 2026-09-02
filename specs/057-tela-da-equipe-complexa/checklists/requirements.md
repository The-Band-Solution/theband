# Specification Quality Checklist: A tela da equipe, e a equipe feita de equipes

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-02
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

## Notas da validação

**Iteração 1 — três achados, todos corrigidos no spec.**

1. **Nomes de módulo e função vazaram** do texto de entrada para a seção de
   abertura (`Profiles.team_skills`, `evolution/2`, `started_at`). Os dois
   primeiros foram removidos e substituídos pelo comportamento observável — "o
   conjunto de membros vem da evidência que o GitHub mostra hoje". Os nomes de
   atributo `started_at` e `ended_at` **foram mantidos** em FR-002 e FR-006:
   são atributos declarados na ontologia (`eo.team_membership`), publicados em
   `priv/knowledge_base/`, e não detalhe de implementação — trocá-los por
   paráfrase tornaria o requisito ambíguo sobre qual borda do período é
   inclusiva.

2. **Três critérios de sucesso eram binários disfarçados de medida.** SC-003,
   SC-006 e SC-007 diziam "não apresenta soma" sem dizer como conferir. Cada um
   ganhou o método de verificação — varredura da tela renderizada, contagem de
   linhas, contagem de marcas.

3. **A previsão não tinha piso.** A primeira redação deixava o comportamento com
   histórico curto em aberto, o que produziria faixa larga apresentada como
   informação. Resolvido com FR-034, SC-010 e o piso declarado em Assumptions —
   escolha registrada como suposição, não como pergunta ao usuário, porque há um
   padrão defensável e a decisão não muda o escopo.

**Decisão sobre marcadores de clarificação**: nenhum foi emitido. As três
ambiguidades reais — período das séries, limiar de parada e piso da previsão —
têm padrão defensável e estão registradas em Assumptions, conforme a orientação
de preferir suposição documentada a pergunta.

**Uma decisão de escopo que merece leitura do Product Owner**: a feature
**recusa** qualquer total consolidado (FR-008), e isso está em Assumptions como
decisão e não como prazo. Se a expectativa de quem gerencia for ver um número
único da equipe composta, esta spec o nega deliberadamente — e a razão está em
FR-009.
