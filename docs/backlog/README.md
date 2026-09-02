# Backlog

O que construir, em que ordem, e por quê. Cada documento traz a derivação do
escopo — não só a lista.

| Documento | Do que trata | Prioridade |
|---|---|---|
| [Entidades e CRUD](crud-entities.md) | como 220 conceitos viram ~94 entidades, e a ordem de construção | alta |
| [GitHub → SRO](github-to-sro.md) | ingestão do GitHub para a Scrum Reference Ontology, em fatias verticais | alta |
| [Papéis Scrum](papeis-scrum.md) | cadastro declarado e alocação de pessoas — o que o GitHub não expõe | alta |
| [Biblioteca de derivação](tooling-library.md) | extrair a transformação como biblioteca independente | **baixa** |
| [Setup inicial e a empresa com endereço próprio](setup-inicial-e-multiempresa.md) | o wizard que cria a empresa, conecta organizações do GitHub e dá a ela `<empresa>.theband.dev` | **alta** |
| [O projeto pertence a uma organização](projeto-pertence-a-organizacao.md) | o elo que falta entre projeto e organização, decidido em 2026-09-01, e a premissa da ontologia que ele vence | **alta** |
| [Português na interface](portugues-na-interface.md) | 23 ocorrências de português numa interface que serve em inglês — e o verificador que não as vê | média |
| [Decisões pendentes](decisoes-pendentes.md) | o que não pode ser implementado sem uma resposta humana — o quadro do Conecta Fapes, o conector do ArgoCD, a skill de humanização | **bloqueadas** |

## Dívidas e defeitos com issue aberta

Levantados ao fechar o sprint 005. Nenhum tem iteration: entram quando forem priorizados.

| Issue | Tipo | O que é | Por que ainda não foi feito |
|---|---|---|---|
| [#175](https://github.com/The-Band-Solution/theband/issues/175) | defeito | job `discarded` deixa o `sync` em `running` e bloqueia toda coleta da ferramenta | só há saída por SQL; a 005 aumenta a exposição ao acrescentar recálculo assíncrono |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | processo | sprints 003, 004 e 005 sem iteração no Projects v2 | configurar iterations recria as existentes — L11, 96 itens reatribuídos |
| [#177](https://github.com/The-Band-Solution/theband/issues/177) | dívida | validador Elixir faz 4 verificações; o Python faz 12 | declarada desde o sprint 002 |
| [#178](https://github.com/The-Band-Solution/theband/issues/178) | dívida | `connected_tools.status` materializa situação, contra a ADR 0004 D7 | declarada e **não ampliada** desde a feature 002 |
| [#179](https://github.com/The-Band-Solution/theband/issues/179) | escopo | comentários e timeline das issues | multiplicaria o consumo da origem por issue |
| [#180](https://github.com/The-Band-Solution/theband/issues/180) | escopo | campo de quadro → atributo da ontologia | depende de coletar quadros como entidade |
| [#181](https://github.com/The-Band-Solution/theband/issues/181) | escopo | quadros, campos e iterações do Projects v2 | fase F4 da feature 004, fora do MVP entregue |

Herança anterior, ainda sem iteration: [#81](https://github.com/The-Band-Solution/theband/issues/81), [#82](https://github.com/The-Band-Solution/theband/issues/82) (feature 002),
[#98](https://github.com/The-Band-Solution/theband/issues/98) a [#100](https://github.com/The-Band-Solution/theband/issues/100) (papéis Scrum), [#104](https://github.com/The-Band-Solution/theband/issues/104) (ajustar ferramenta
conectada), [#107](https://github.com/The-Band-Solution/theband/issues/107) e [#108](https://github.com/The-Band-Solution/theband/issues/108) (quadros e escopo de repositórios).

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
| Especificação | 001 a 006 completas — ciclo Spec Kit inteiro em cada uma |
| Aplicação Elixir | features 001 a 004 entregues; 006 aguardando revisão — **250 testes** |
| Dado real coletado | 4471 issues, 135 repositórios, duas organizações, 22 877 promoções |
| Promoção a conceito | **1020 de 4471** — os outros 77% são o que a feature 005 resolve |
