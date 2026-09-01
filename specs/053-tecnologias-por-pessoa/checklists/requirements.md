# Specification Quality Checklist: As tecnologias com que cada pessoa trabalhou

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

## O que a validação mudou

**Primeira passagem.** Os requisitos citavam `commit_files`, `previous_path` e o
formato YAML do mapa — todos decisão de plano, não de spec. Trocados por "os
arquivos que os commits tocaram", "arquivo movido ou renomeado" e "mapa declarado
e versionado".

**Segunda.** SC-003 dizia "arquivos gerados são excluídos", que não se mede.
Virou "nenhum arquivo gerado aparece entre as cinco primeiras tecnologias de
qualquer pessoa do piloto, medido sobre as 88 pessoas observadas" — que se
verifica olhando.

**Terceira.** Faltava o critério que impede a feature de virar o oposto do que
pretende. Entrou o SC-008: *nenhuma tela atribui rótulo de especialidade a uma
pessoa*. Sem ele, o FR-015 seria intenção declarada e a violação — a etiqueta
"frontend" colada em alguém — não teria teste.

## A tensão central desta spec, registrada

Esta feature classifica **pessoas** a partir de um sinal **fraco**: a extensão do
arquivo. Isso é útil e é perigoso pela mesma razão — parece objetivo.

O que a contém, e precisa sobreviver ao plano e à implementação:

1. **O mapa é da organização, não do código.** Quem discorda corrige, e a
   correção vale sem recoletar (FR-002, FR-012, US2). Uma classificação que
   ninguém pode contestar é o desenho errado.
2. **A medida é sustentação, não volume.** Arquivos distintos e meses distintos,
   nunca linhas (FR-004). Linhas premiam quem commitou um lock file.
3. **A lacuna é visível.** Extensão sem mapa aparece nomeada (FR-007), e a
   proporção de não reconhecidos é medida (SC-004) — é o que faz o mapa melhorar.
4. **Proporção nunca vira rótulo** (FR-015, SC-008). "70% na interface" é um
   número com denominador à vista; "é frontend" é uma etiqueta que cola, fecha
   porta e sobrevive à pessoa ter mudado.
5. **O escopo termina em "com o quê" e "onde".** Nunca "quão bem", nunca
   comparação entre pessoas.

## Relação com a 026

A [026](../../026-perfil-de-competencias/spec.md) deriva competências de **texto
de issue interpretado por IA**, e a própria spec dela registra três medições que
limitam o que aquele texto autoriza afirmar — inclusive que 1298 de 2949
descrições foram escritas por outra pessoa, não por quem executou.

Esta spec deriva de **fato observado**: o commit tocou o arquivo, ou não tocou.
As duas se completam, e nenhuma substitui a outra. Onde discordarem, a
discordância é informação — o mesmo princípio da US3 sobre a linguagem principal
do repositório.
