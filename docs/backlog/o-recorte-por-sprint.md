# O recorte por sprint: atrasou, não realizada, concluída

**Aberto em**: 2026-09-14 · **Pedido de quem usa** (Conecta Fapes): *"seria interessante
considerar apenas cards que possuem a sprint marcada, assim entendemos que o card faz parte de
uma sprint e podemos medir se ele atrasou, nunca foi realizado ou se teve problema"*.

## A parte do pedido que a plataforma NÃO deve atender, e por quê

**"Considerar apenas cards com sprint" apagaria a entrega.** Medido em 2026-09-14 nos 56 cards
de uma pessoa real no quadro 43:

| | com sprint | sem sprint |
|---|---|---|
| **Done** (27) | 4 | **23** |
| **Homologation** (24) | **24** | 0 |

Filtrar por sprint manteria o que está parado e descartaria o que foi entregue. E a **decisão de
2026-08-27 continua valendo** (reafirmada pela pessoa mantenedora em 2026-09-14): *a issue é da
pessoa pelo responsável*, com ou sem caixa de tempo.

## A parte que a plataforma deve atender

O que o pedido quer de verdade são **três estados por sprint**, que hoje não existem:

| estado | o que é |
|---|---|
| **concluída no sprint** | entrou na caixa e saiu pronta dentro dela |
| **atrasou** | o sprint acabou e o item continua aberto — e foi para o seguinte |
| **nunca realizada** | esteve na caixa e nunca saiu de backlog ou refinamento |

**O dado existe e é grande**: o *Sprint 41* do quadro 43 (31/08 a 14/09) fechou em 2026-09-14
com **100% de carry-over** — os 22 cards foram inteiros para o *Sprint 42*, zero ficou. É
exatamente "atrasou", e nenhuma tela da plataforma diz isso.

## O que já existe para reaproveitar

- `sro_sprint_issues` liga issue a sprint, com `no_longer_observed_at` (saiu da caixa);
- `PersonWork.prazo_do_trabalho_aberto/2` já conta *"N open issues sit in no time box"* — o
  avesso desta medida, e o único recorte de sprint que hoje chega à tela;
- a **fase declarada** e o **estágio como período** das specs [066](../../specs/066-pronto-declarado/spec.md)
  e [067](../../specs/067-aceite-declarado/spec.md) dizem *o que* aconteceu; este item diz
  *quando*, contra a caixa.

## Ordem

**Depois da 066** — "concluída no sprint" precisa da definição de pronto declarada, senão herda
o problema que a 066 existe para resolver: 294 itens *Done* que a plataforma conta como abertos.
