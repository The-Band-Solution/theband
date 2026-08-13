# Busca, ordenação e página no endereço

**Issue**: [#292](https://github.com/The-Band-Solution/theband/issues/292) · **Corte declarado
da feature 017** — FR-010 e SC-006, escritos na spec e não entregues.

## O problema, medido

Antes desta feature, `/work?q=agulha` abria a lista **sem** a busca: o estado morava no socket.
Duas consequências, e as duas foram reproduzidas em teste antes da correção:

1. recarregar a página perde busca, ordenação e página, e volta ao começo;
2. o endereço não é compartilhável — quem pede ajuda sobre uma lista precisa **descrever** o que
   digitou, em vez de mandar o link.

## User Scenarios & Testing

### User Story 1 — O link leva ao que eu estou vendo (P1)

Quem manda o endereço manda também o estado da lista.

**Cenários de aceitação**

1. **Dado** `/work?q=agulha`, **quando** a tela abre, **então** o resultado da busca já está lá.
2. **Dado** `/work?ordem=number&dir=desc`, **quando** abre, **então** a coluna aparece ordenada
   decrescente.
3. **Dado** `/work?pagina=2`, **quando** abre, **então** a segunda página é a vigente.
4. **Dado** que alguém buscou, **quando** o resultado aparece, **então** o **endereço mudou** —
   não só o socket.

### User Story 2 — Parâmetro que não dá para ler é dito (P1)

**Por que é P1**: ordenar em silêncio por outra coisa é pior do que recusar. Quem mandou o link
acredita que a outra pessoa vê o que ele pediu.

**Cenários de aceitação**

1. **Dado** `?ordem=inexistente`, **então** a tela diz que aquela coluna não é ordenável ali, e
   lista as que são.
2. **Dado** `?dir=deitado` com coluna válida, **então** ordena crescente **e avisa** — a coluna
   pedida é respeitada.
3. **Dado** `?pagina=abc`, **então** mostra a primeira página e diz por quê.
4. **Dado** qualquer parâmetro inválido, **então** a tela **não cai**.

### User Story 3 — Os estados convivem (P2)

O filtro de repositório já usava o endereço. Busca e ordenação passam a dividir o mesmo lugar.

**Cenários de aceitação**

1. **Dado** um repositório filtrado, **quando** alguém busca, **então** os dois parâmetros
   coexistem no endereço.
2. **Dado** que a busca foi apagada, **então** o parâmetro **some** do endereço — `?q=&pagina=1`
   sugere escolha que ninguém fez.

## Requirements

- **FR-001**: `?q=`, `?ordem=`, `?dir=` e `?pagina=` no endereço, nas duas listas.
- **FR-002**: parâmetro inválido MUST ser dito, e MUST NOT derrubar a tela.
- **FR-003**: o átomo da coluna MUST sair da lista declarada pela tela, nunca do texto recebido.
- **FR-004**: o filtro de repositório MUST continuar funcionando junto.
- **FR-005**: parâmetro no valor padrão MUST ser omitido do endereço.

## Success Criteria

- **SC-001**: abrir o endereço de novo devolve a mesma tela, sem passar por clique algum.
- **SC-002**: nenhuma combinação de parâmetro inválido produz erro 500.

## Fora do escopo

- Guardar o estado por pessoa entre sessões. O endereço é o lugar certo porque é o que se manda;
  preferência salva resolveria outro problema.
