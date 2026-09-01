# Specification Quality Checklist: O domínio próprio, e a origem que passa a ser declarada

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-01
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

O que a validação conferiu, item por item, e o que decidiu o veredito:

1. **Nenhum nome de configuração aparece nos requisitos.** A busca por
   `check_origin`, `PHX_HOST` e `PHX_ORIGENS_EXTRAS` no `spec.md` não devolve
   nada — as duas únicas ocorrências de ferramenta no arquivo são a frase que a
   pessoa digitou (campo `Input`, que é registro do pedido) e a premissa que
   nomeia a escolha atual. Os requisitos falam do comportamento: *lista
   declarada* (FR-004), *ausência restringe* (FR-007), *muda sem release*
   (FR-006). Como o parâmetro se chama é decisão do `plan.md`.
2. **A ferramenta do intermediário está na premissa, não no critério.** Um
   critério que dissesse "com Cloudflare" venceria no dia da troca, e a aceitação
   passaria a depender de um fornecedor. Os critérios dizem *intermediário*.
3. **O SC-002 exige medida separada por endereço, de propósito.** "As telas vivas
   funcionam" seria satisfeito por uma medida só — e o defeito que esta feature
   evita é exatamente **um endereço funcionar e o outro não**. Critério que a
   medida errada satisfaz não é critério.

**Decisões tomadas sem perguntar**, documentadas nas premissas em vez de virarem
`[NEEDS CLARIFICATION]`:

- **`www` leva ao mesmo lugar** (FR-003) — o contrário é erro para quem digita, e
  não há leitura razoável em que `www` deva falhar;
- **o endereço antigo não é aposentado nesta feature** — ela garante a
  convivência; aposentar é decisão de quem opera, e o lugar onde ela se aplica
  (a lista declarada) fica pronto;
- **cache e CDN ficam fora** — são outro problema, e nada nesta feature depende
  deles.

**O que esta validação NÃO prova**: que a feature funciona. Checklist de spec
mede o documento, não o produto. As medidas do produto são os SC, e nenhum deles
foi executado — a plataforma ainda atende num endereço só.

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
