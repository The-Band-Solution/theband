# Specification Quality Checklist: as caixas de tempo, e as issues dentro delas

**Propósito**: validar a spec antes do `/speckit-plan`
**Criada em**: 2026-08-15
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor e necessidade
- [x] Escrita para quem decide, não só para quem implementa
- [x] Seções obrigatórias completas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos
- [x] Casos de borda identificados
- [x] Escopo delimitado
- [x] Dependências e suposições declaradas

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação
- [x] As user stories cobrem os fluxos principais
- [x] A feature atende os critérios de sucesso
- [x] Nenhum detalhe de implementação vazou para a spec

## Notas

**Toda medida desta spec foi feita contra a API real em 2026-08-15**, e três achados mudaram o
desenho antes de existir código:

1. **`Quarter` carrega trabalho.** No Produtos Internos ele tem 15 issues contra 3 do `Sprint`.
   Uma feature que coletasse só o campo chamado `Sprint` teria medido 3 e concluído que o quadro
   está parado.
2. **As caixas se sobrepõem.** `527 + 203 > 677` no DevOps: a mesma issue está em duas. Isso
   descartou `sprint_id` como coluna antes da primeira linha de migração.
3. **A duração real difere da configurada.** `Sprint 10` tem 3 dias num campo de 14. A FR-003
   existe por causa disso.

**Nenhum `[NEEDS CLARIFICATION]`, e a razão é que a decisão em aberto virou requisito**: qual
campo é o sprint não é uma pergunta para a spec responder — é a US4, e a plataforma recusa
decidir por conta própria (FR-011).
