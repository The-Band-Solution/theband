# Specification Quality Checklist: coletar só o que mudou

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota sobre o primeiro item.** A spec nomeia `last_pushed_at`, `issues_collected_at`,
`records_created` e `issues.graphql`. São **medidas do estado atual**, na seção que existe para
isso, e não decisão de implementação: o requisito diz *"anterior à última revisão completa"*, e
não *"comparar as duas colunas"*. A convenção deste repositório é a spec trazer a medida com o
nome do que foi medido — foi assim na 012 e na 018.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

**Três suposições estão declaradas e nenhuma virou pergunta**, porque as três têm resposta
verificável no plano — e a verificação é barata. A que mais importa é se comentário altera
`updatedAt`: se não alterar, a história 3 perde alteração real, e a spec diz que o plano
resolve.

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## O que a análise de desenho já achou, antes do plano

A fase de análise achou defeito de desenho em **sete** features seguidas neste repositório, e
esta continua a série. O defeito aqui é de **consequência em outra parte do sistema**:

> A marca de ausência das features 009 e 012 depende de percorrer a lista inteira. Uma coleta
> que olha só o que mudou não vê o que sumiu — e os 52 vínculos marcados ontem deixariam de ser
> recalculados sem que nada avisasse.

Isso virou a **FR-012**, que obriga o plano a declarar a estratégia e a provar o recálculo. Sem
ela, a feature entregaria velocidade trocando por uma afirmação falsa sobre o que a plataforma
observa — que é exatamente o que a 012 existe para impedir.

## Notes

- a spec **não escolhe** entre coleta completa periódica e outra estratégia para a FR-012: as
  duas têm custo diferente e a decisão é do plano, com a medida na mão;
- a contagem (`records_created`/`updated`) aparece como **história 1 e P1**, e não como conserto
  à parte, porque sem ela o sucesso da feature não é verificável — a mesma tela mostraria
  "baixou 5%" e "perdeu 95%".
