# RFCs

Propostas técnicas abertas a comentário. Um RFC existe para **discutir antes de
decidir**, quando a escolha é cara de reverter, tem alternativas defensáveis, ou
depende de conhecimento que ainda não temos.

## Índice

| # | Título | Status |
|---|---|---|
| [0001](0001-derivacao-do-modelo-de-informacao.md) | Derivação do modelo de informação a partir da rede de ontologias | Aberto a comentários |

## RFC ou ADR?

| | RFC | ADR |
|---|---|---|
| Momento | antes de decidir | ao decidir |
| Conteúdo | alternativas, medições, o que falta saber | a decisão e por quê |
| Estado | pode ficar aberto por tempo indeterminado | aceita ou substituída |
| Quem lê | quem vai opinar | quem vai implementar ou revisitar |

Um RFC resolvido vira ADR, quando a decisão é arquitetural, ou vira trabalho na
base de conhecimento, quando é matéria de modelagem. O RFC permanece como
registro de como se chegou lá.

## Formato

Arquivo `NNNN-titulo-em-kebab-case.md`, com cabeçalho contendo status, data e
relação com ADRs existentes. O corpo é livre, mas questões em aberto devem ter
identificador estável (`Q1`, `Q2`, …) — números não são reciclados, e questão
resolvida permanece na lista com o destino registrado.
