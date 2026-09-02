<!--
  Este template existe por causa de três lições — L75, L83 e L92 — e a terceira
  aconteceu depois de as duas primeiras já estarem escritas.

  Lembrar da regra no momento de clicar o botão não funcionou. Por isso o tipo de
  merge é DECLARADO aqui, por quem abre o PR e conhece a branch.
-->

## Tipo de merge

<!-- Marque UM, e apague o outro junto com a linha de motivo que não usar. -->

- [ ] **Squash** — a branch morre no merge, ninguém ramifica dela
- [ ] **Merge commit** — alguém depende do histórico desta branch

**Motivo:** <!-- ex.: "branch empilhada sobre a #758" · "release para main" · "back-merge" · "os commits carregam decisão, um a um" -->

> **Merge commit é obrigatório** em branch empilhada, release para `main`,
> back-merge e hotfix. O squash cria um commit **novo, sem os pais originais** — o
> Git perde a informação de que aquele trabalho já foi integrado, e volta a
> oferecê-lo como se fosse inédito. Ver `AGENTS.md`, seção 12.

---

## O que muda

<!-- Uma ou duas frases: o que a pessoa passa a ver ou a poder fazer. -->

## Por quê

<!-- O problema que isto resolve. Se corrige defeito, diga o que acontecia antes. -->

## Evidência

```
mix gates
```

<!-- Cole o CÓDIGO DE SAÍDA, e não o texto do fim. `mix gates` é a definição
     única, e qualquer comando depois dele substitui o código que vale. -->

**Código de saída:**

## Issues

<!-- Um bloco por user story — título, número, prioridade — e uma linha por tarefa
     com issue, ID e O RESUMO DO QUE ENTREGOU. Lista de números sem resumo não
     passa (constituição 1.6.0, padrão do PR #543). -->

## Revisão

<!-- Se a revisão independente não puder ser obtida, DECLARE a lacuna aqui.
     Nunca marque como cumprida. CI verde não é revisão: os gates dizem que o
     código compila, passa e não regride, e não dizem que alguém leu o desenho.
     Princípio VII e L95. -->

## O que este PR não resolve

<!-- Limitação assumida, dívida gerada, item que foi para o backlog. Silenciar faz
     o PR parecer completo quando não é. -->
