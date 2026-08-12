# Specification Quality Checklist: o vínculo que sumiu na origem

**Propósito**: validar a completude da spec antes do planejamento
**Criada em**: 2026-08-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação nos **requisitos** — ver a nota abaixo sobre o diagnóstico
- [x] Focada no valor: a plataforma para de afirmar decomposição que a origem não declara
- [x] Legível por quem não programa
- [x] Todas as seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis — 52, 157, 15, 29, 1 666, zero
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos nas três user stories
- [x] Casos de borda identificados — seis, incluindo o relógio e o vínculo entre repositórios
- [x] Escopo delimitado: recusas e ciclos ficam **fora**, e está escrito
- [x] Dependências e premissas identificadas — a dependência do PR #264 está nomeada

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação correspondente
- [x] As user stories cobrem os fluxos principais: marcar, exibir, e não marcar o que não foi olhado
- [x] A feature atende aos critérios mensuráveis
- [x] Fatia vertical: coleta **e** tela, com o consumidor visível já existente (feature 011)

## Notas

**Sobre nomes de função e coluna na spec.** Aparecem em duas seções — *O defeito* e *O que a medida
achou* —, e ali eles **são** a evidência: o defeito é que uma coluna existente nunca é escrita, e
isso não se demonstra sem nomeá-la. As três user stories, os catorze FRs e os seis SCs estão escritos
em termos de comportamento observável. É o mesmo tratamento das specs 009, 010 e 011.

**Duas verificações que a spec deixa explícitas em vez de esconder:**

| O que | Por quê |
|---|---|
| os **52** são a medida de 2026-08-12 | o número muda a cada coleta; o critério é "os que a origem não declara mais" |
| SC-004 depende do PR #264 | a tela que exibe o vínculo ausente ainda não está na `main` |

**A conferência no dado real exige a chave mestra**, que é da pessoa mantenedora. A asserção em teste
é declarada como asserção, nunca como conferência.
