# Backlog

O que construir, em que ordem, e por quê. Cada documento traz a derivação do
escopo — não só a lista.

| Documento | Do que trata | Prioridade |
|---|---|---|
| [Entidades e CRUD](crud-entities.md) | como 220 conceitos viram ~94 entidades, e a ordem de construção | alta |
| [GitHub → SRO](github-to-sro.md) | ingestão do GitHub para a Scrum Reference Ontology, em fatias verticais | alta |
| [Papéis Scrum](papeis-scrum.md) | cadastro declarado e alocação de pessoas — o que o GitHub não expõe | alta |
| [Biblioteca de derivação](tooling-library.md) | extrair a transformação como biblioteca independente | **baixa** |

## Como isto se relaciona com o resto

O backlog diz **o que**. As decisões que o sustentam estão em
[ADRs](../adr/README.md), e o que ainda não foi decidido está em
[RFCs](../rfc/README.md).

Um item de backlog que dependa de questão aberta traz a referência explícita —
começar por ele antes da questão ser resolvida costuma significar refazer.

## Estado

| Área | Situação |
|---|---|
| Base de conhecimento | 12 ontologias, 220 conceitos, validada |
| Classificação OntoUML | 4 de 12 ontologias — EO, SPO, CMPO e SRO |
| Modelo de informação | derivável para as 4 classificadas, e reprodutível no CI |
| Especificação | 001, 002 e 003 completas |
| Aplicação Elixir | features 001, 002 e 003 entregues — 172 testes |
