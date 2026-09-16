# `Done` é alegação de conclusão, não aceite — e a devolução é o dado que falta contar

**Registrado em 2026-09-16**, a partir de uma observação da pessoa mantenedora: *"o
programador pode colocar em done e o PO voltar ele"*. Medido logo depois, contra a base
recolhida.

---

## O que a base diz

Um cartão que chega a `Done` pode sair de lá. Aconteceu **193 vezes**, em **185 issues**.

| | |
|---|---|
| devoluções de `Done` | 193 |
| feitas por **outra** pessoa que não a que pôs | 112 (58%) |
| feitas pela mesma | 81 (42%) |

Os pares mais frequentes mostram o fluxo com nitidez — a automação põe, a pessoa tira:

| pôs em Done | devolveu | vezes |
|---|---|---|
| `github-project-automation` | `LuizRojas` | 23 |
| `github-project-automation` | `joaopbarcellos` | 15 |
| `Eduardo2006g` | `github-project-automation` | 13 |
| `github-project-automation` | `marcelasfl` | 10 |
| `ArthurCremasco` | `joaomrpimentel` | 7 |

Para onde o cartão vai depois de sair de `Done`: Backlog 56, In Progress 18, Review 18,
In Validation 16, Homologation 12, Deploy 9, To Do 9.

**E onde ele parou:** das 185 issues que já saíram de `Done`, **116 voltaram e estão em
`Done`; 69 não estão** — pararam em Homologation (21), Backlog (15), Concluído (8),
Desaprovado (6), Deploy (5), Code Review (4) e outras.

## Por que isso importa para a medida

Se o gráfico por mês contar toda chegada a `Done`, ele conta **69 entregas que foram
recusadas** e hoje não estão entregues. E conta duas vezes a issue que foi, voltou e foi
de novo — 151 issues têm mais de uma chegada a `Done` num quadro só, separadas por 48,6
dias em média.

## A rede já dizia isso, e agora há número

`priv/knowledge_base/rules/github_project_item_status.yaml` declara explicitamente:

```yaml
  does_not_materialize:
    - concept: sro.accepted_deliverable  # sro.rule03
```

`sro.rule03` diz que o aceite deriva dos critérios de aceitação, **nunca** de marcação
manual. A regra estava certa por princípio; estes 193 casos são a evidência.

Chegar a `Done` é **alegação de conclusão** por quem moveu o cartão. Sair de `Done` é
**recusa** — e em 58% das vezes por outra pessoa, que é o desenho esperado: quem faz
alega, quem recebe decide.

## O que fazer

1. **guardar todas as chegadas, e não só a última.** Já acontece — cada evento é uma
   ocorrência com identidade própria desde o PR #924. Nada a fazer aqui, mas nada a
   desfazer também: consolidar numa data só perderia a história;
2. **não gravar "concluída" na issue.** A conclusão é leitura sobre a sequência, e o
   significado da sequência é declaração da organização (066). Gravar congelaria uma
   declaração dentro do dado;
3. **o critério de fim (066) precisa dizer o que conta quando o cartão volta** — a
   primeira chegada, a última, ou cada uma como entrega com a recusa ao lado. A regra da
   casa manda as duas afirmações lado a lado, nunca somadas: *N alegações de conclusão,
   M devoluções, e o estado de hoje*;
4. **a recusa é estado, e merece aparecer.** Hoje ela não aparece em tela nenhuma. Um
   cartão devolvido três vezes conta a mesma história que um aceito de primeira;
5. **depende de [o evento não dizer o quadro](o-evento-de-coluna-nao-diz-o-quadro.md)** —
   sem o quadro, uma devolução num quadro parece devolução no outro.

## O que isto NÃO é

Não é o critério de aceite ([spec 067](../../specs/067-aceite-declarado/spec.md)). Aceite
é ato declarado com avaliação; o que está aqui é a leitura do que a origem observou. Os
dois se encontram, e são coisas diferentes.
