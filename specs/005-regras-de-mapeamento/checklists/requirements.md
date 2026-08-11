# Specification Quality Checklist: Regras de mapeamento de tipo por organização

**Purpose**: Validar completude e qualidade antes do planejamento
**Created**: 2026-08-11
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhes de implementação
- [x] Focada em valor de usuário
- [x] Escrita para quem não implementa
- [x] Seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum [NEEDS CLARIFICATION] restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios independentes de tecnologia
- [x] Cenários de aceitação definidos
- [x] Edge cases identificados
- [x] Escopo delimitado
- [x] Dependências e suposições identificadas

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação
- [x] Cenários cobrem os fluxos principais
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## Notas da validação

**A spec nasceu de um número, não de uma intuição**: 77% das issues não promovidas, e
2911 de 3403 com prefixo no título. O que a mediu foi a tela da feature 004 — a lacuna
visível é o que tornou esta feature especificável.

**O achado que mudou o desenho, e vale registrar por quê.** A primeira leitura do pedido
levaria a uma tela que lista prefixos por frequência e oferece "criar regra" em cada
linha. Medindo, os cinco prefixos mais frequentes incluem `[Devops]` (340),
`[Back-end]` (256), `[Front-end]` (237) e `[Dados]` (186) — que são **área**, não tipo:

```
prefixo que é TIPO   1409
prefixo que é ÁREA   1274
```

Quase metade. Uma tela que empurrasse o mapeamento de todos produziria 1274 issues com
conceito errado — e conceito errado é pior que conceito ausente, porque a medida passa a
existir e a mentir. Daí a US3, e daí FR-031 exigir a distinção como **sugestão a
conferir** em vez de classificação automática.

**Três requisitos existem porque regex é código que o usuário escreve.** FR-016, FR-017 e
FR-018 recusam o que não compila, o que casa vazio e o que não termina. O segundo é o menos
óbvio e o mais perigoso: `.*` grava sem erro e reclassifica tudo.

**FR-012 e FR-013 são o princípio III aplicado a inferência.** Promover por padrão de
título é inferência sobre texto livre, e não pode aparecer igual a promover por tipo
declarado. A plataforma já distingue observado de derivado em todo lugar; esta feature não
abre exceção.

**FR-036 fecha uma porta antes de ela existir.** `tool_concept_mappings`, da feature 004,
foi especificada e não implementada. Deixar as duas coexistirem daria dois lugares para a
mesma decisão — e a divergência entre elas seria silenciosa. Mapeamento por igualdade de
nome é o caso particular de `igual a` desta feature.
