# Specification Quality Checklist: A organização declara suas equipes

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

**Os nomes de tabela ficaram fora dos requisitos, de propósito.** O pedido citava
`eo_teams` e `team_membership`, e eles não aparecem em nenhum FR — só em *Key
Entities*, onde o texto diz o que a entidade **é**, não onde ela mora. A spec
precisa continuar válida se o esquema mudar de nome.

**O SC-003 é o critério que decide a feature.** *"Um painel que mede um período
anterior a uma saída mostra exatamente o mesmo número antes e depois"* — é o que
separa **sair** de **ser apagado**, e é a única forma de provar que o histórico
sobreviveu. Sem ele, "registrar a saída" seria satisfeito por um `DELETE`.

**O FR-006 resolve uma tensão do pedido.** O pedido pede *remover* e *informar
que saiu* como coisas diferentes, e a leitura fácil seria remover = apagar a
linha. Isso contraria a proveniência que atravessa o produto. A spec separa as
duas pela **pergunta que cada uma responde**:

- **sair** — a pessoa esteve e não está mais. O período vale, e continua contando;
- **engano** — a pessoa nunca esteve. O vínculo deixa de valer para qualquer
  período, **e o registro do equívoco permanece**.

Nenhuma das duas remove linha. A diferença está no que passa a ser verdade, não
no que some do banco.

**O FR-012 é o mais fácil de "simplificar" errado.** Quando a coleta diz que a
pessoa está na equipe e a declaração diz que saiu, a tentação é escolher uma —
normalmente a declarada, por ser mais recente. A spec proíbe: **as duas
afirmações são verdadeiras em fontes diferentes**, e escolher esconde que o
GitHub não foi atualizado, que é informação sobre a organização.

**Decisões tomadas sem perguntar**, documentadas nas premissas:

- **saída sem data usa hoje, marcada como presumida** — recusar travaria o caso
  comum (ninguém lembra o dia), e aceitar em silêncio transformaria presunção em
  fato;
- **sem limite de profundidade**, com ciclo proibido — limite arbitrário
  resolveria problema que não existe (princípio VIII);
- **o rollup de competências fica fora** — a #397 pede, mas ele depende desta
  feature. Juntar as duas esconderia qual quebrou.

**O que esta validação NÃO prova**: que a feature funciona. Checklist de spec
mede o documento. Os SC são as medidas do produto, e nenhum foi executado.

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
