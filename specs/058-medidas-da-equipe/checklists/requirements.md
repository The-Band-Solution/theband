# Specification Quality Checklist: As medidas que faltam na tela da equipe

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

## Notas da validação

**Uma user story cuja entrega pode ser a recusa.** A US3 é diferente das outras
duas e a spec diz isso explicitamente: se a pesquisa não achar caminho honesto de
uma verificação até uma equipe, **a entrega é a recusa declarada com o elo que
falta nomeado** — e isso conta como entrega.

Escrever a US3 como "implementar a taxa" seria prometer o que não se sabe
possível, e a alternativa comum — deixá-la fora do escopo até saber — adiaria a
pesquisa indefinidamente. `FR-013` e `SC-007` cobrem os dois desfechos.

**Um nome de função no texto, e por quê fica.**
`TheBand.Quality.time_to_first_review/2` aparece na seção de abertura. É detalhe
de implementação, e normalmente sairia. Fica porque a razão de esta feature
existir é que **aquela função específica já calcula e não chega à tela** — sem
nomeá-la, a seção diria "a medida não aparece", que é vago e não explica o custo
baixo do item.

**Três achados corrigidos na primeira iteração:**

1. **A US2 não dizia o que fazer com borda desconhecida.** A primeira redação
   falava em interseção de três períodos e silenciava sobre o nulo. Corrigido com
   `FR-009` e `SC-005` — tratar desconhecido como aberto é o mesmo fallback
   silencioso que a feature 057 corrigiu no vínculo, e repeti-lo aqui seria
   reincidência com a lição já escrita.

2. **A US1 não dizia o que acontece com solicitação sem revisão.** Zero seria a
   resposta natural e errada: espera em curso não é tempo zero. `FR-004` e
   `SC-003`.

3. **Faltava a regra de "não somar" nesta feature.** A 057 a estabeleceu para a
   equipe composta, e as medidas por pessoa desta feature trazem o mesmo risco.
   `FR-020`.

**Nenhum marcador de clarificação foi emitido.** A única incerteza real — o
caminho verificação → equipe — **não é pergunta para a pessoa mantenedora**: é
pergunta para o código, e o `research.md` do plano é o lugar dela.
