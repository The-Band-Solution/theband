# Specification Quality Checklist: A marca de trabalho no repositório

**Purpose**: Validar completude e qualidade da especificação antes do planejamento
**Created**: 2026-08-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor para quem usa
- [x] Escrita para quem decide, não para quem implementa
- [x] Todas as seções obrigatórias completas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos para as quatro user stories
- [x] Casos de borda identificados — oito
- [x] Escopo delimitado, com o que fica fora e por quê
- [x] Dependências e premissas declaradas

## Feature Readiness

- [x] Cada requisito funcional tem critério de aceitação
- [x] Os cenários cobrem o fluxo principal
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## O que a validação achou, e entrou na spec

**O pedido literal apagaria três estados.** "Símbolo nos repositórios que possuem issues" é
binário; a plataforma distingue quatro. O achado que decidiu: **38 repositórios inacessíveis têm
897 issues** — um símbolo binário os colocaria do lado errado dos dois, porque eles têm trabalho
**e** não estão sendo olhados. FR-001 e FR-007 nasceram disso.

**Zero e desconhecido não são a mesma coisa**, e a spec teve de dizer qual. FR-004 e FR-005
separam "coletado e vazio" de "nunca coletado" — a mesma distinção que o corpo da issue já
carrega, e que já custou um defeito nesta base.

**A navegação pedida já existe.** A spec diz isso em vez de reespecificar: o nome do repositório
já é link. O que a feature garante é que **os vazios continuem clicáveis** (FR-009), porque a
tela deles explica *por que* estão vazios — e é isso que alguém procura ao clicar num vazio.

**O custo de consulta entrou como requisito.** A tela já faz uma consulta de contagem por
repositório — 135 delas. FR-013 e FR-014 impedem que a marca dobre isso: um número, dois
consumidores.

**Ordenação virou filtro.** Ordenar por contagem por padrão faria quem sabe que o repositório
está na letra M perdê-lo. FR-019 fixa a ordem, e a US4 oferece o filtro — que **diz quantos
omitiu** (FR-018), porque esconder sem dizer quanto foi escondido faz alguém concluir que a
lista é tudo.

**O escopo foi fechado explicitamente.** FR-022 tira a tela de sincronização: lá o repositório é
fase de execução, e a pergunta é "a coleta está funcionando", não "onde há trabalho". Escopo
implícito é o que faz feature crescer sem ninguém decidir.

## Notes

Nenhum item incompleto. A spec está pronta para `/speckit-plan`.

A numeração do diretório é `007`, e a **branch** em andamento também se chama
`007-interface-em-ingles` — são coisas diferentes: a branch carrega a interface em inglês e o
design system, que esta spec **usa** como dependência. O plano precisa nomear a branch desta
feature de forma a não colidir.
