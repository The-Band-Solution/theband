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

**O pedido é o escopo, e a primeira versão desta spec esqueceu isso.** Ela inventou quatro estados
para a marca; a informação que eu queria carregar — repositório inacessível — **já está na coluna
`state`**, ao lado. FR-004 fixa isso: a marca não repete o que está do lado.

**Zero e desconhecido não são a mesma coisa**, e essa distinção sobreviveu ao corte porque não é
excesso: 61 dos 135 repositórios têm zero issues, e hoje não há como dizer quais nunca foram
consultados. FR-005 exige a diferença, e é a única coisa nesta feature que a plataforma ainda não
sabe.

**A navegação pedida já existe.** A spec diz isso em vez de reespecificar: o nome do repositório
já é link. O que a feature garante é que **os vazios continuem clicáveis** (FR-007) — a tela deles
explica *por que* estão vazios, e é isso que alguém procura ao clicar num vazio.

**O custo de consulta entrou como requisito.** A tela já faz 135 consultas de contagem, uma por
repositório. FR-010 e FR-011 impedem que a marca dobre isso: um número, dois consumidores — e a
pesquisa mostrou que agrupar leva de 135 para **1**.

**O escopo foi fechado explicitamente.** FR-013 tira a tela de sincronização: lá o repositório é
fase de execução, e a pergunta é "a coleta está funcionando", não "onde há trabalho". Escopo
implícito é o que faz feature crescer sem ninguém decidir.

## Notes

Nenhum item incompleto.

**A spec foi cortada depois da primeira validação.** A versão inicial tinha 22 FR e quatro
estados na marca; a pessoa mantenedora recusou — *"como assim apagar os estados? só pedi para
colocar um símbolo"* — e estava certa. Ficaram 13 FR e dois estados, mais o "não se sabe" que o
FR-005 exige.

A regra que ficou disso: **quando a spec cresce além do pedido, a pergunta é se a informação nova
já existe em outro lugar da tela.** Aqui existia — a coluna `state` já diz `unreachable`,
`excluded` e `archived`.

O plano está escrito, e é pequeno de propósito: um padrão introduzido, cinco recusados.

A numeração do diretório é `007`, e a branch em andamento também se chama
`007-interface-em-ingles` — são coisas diferentes. O plano resolveu em R5: a branch desta feature
é **`008-marca-de-issues`**, porque reusar o número faria duas branches indistinguíveis, e
renumerar o diretório faria a spec mentir sobre a ordem em que foi escrita.
