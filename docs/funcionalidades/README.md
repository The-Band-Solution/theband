# Funcionalidades

O que o produto faz, escrito para **quem usa**.

O resto do site descreve como The Band é construído — a [arquitetura](../architecture/overview.md),
a [rede de ontologias](../ontology/README.md), as [decisões](../adr/README.md) e as
[medidas](../metrics/README.md). Nenhuma dessas páginas responde à pergunta de quem abre a
plataforma: *o que esta tela me diz, e o que ela não me diz*.

Esta seção responde a essa.

## As páginas

| Página | A tela | Features |
|---|---|---|
| [A tela da equipe](tela-da-equipe.md) | `/teams/:id` — quem está na equipe, e como ela está | [055](../../specs/055-equipes-declaradas/spec.md), [057](../../specs/057-tela-da-equipe-complexa/spec.md), [058](../../specs/058-medidas-da-equipe/spec.md), [060](../../specs/060-tela-da-equipe/spec.md) |

## As três regras que valem para toda página desta seção

Elas não são estilo. São a razão de a seção existir, e o que a distingue de um
material de divulgação.

1. **Só entra o que está na tela.** A régua é a implementação, não a especificação.
   Requisito escrito e não construído é **lacuna nomeada** ao fim da página, nunca
   descrição no presente. Uma página que descreve a tela que se pretendia entregar
   ensina quem lê a desconfiar de todas as outras.

2. **A interface está em inglês; o texto está em português.** Ao citar um rótulo da
   tela, ele é citado **em inglês** — é o que a pessoa vai procurar com os olhos — e
   explicado em português. Traduzir o rótulo no texto faria a pessoa procurar por uma
   palavra que a tela não tem. Que a interface esteja em inglês é lacuna registrada em
   [`portugues-na-interface`](../backlog/portugues-na-interface.md).

3. **Nenhum número inventado.** Todo exemplo numérico vem de um documento deste
   repositório, e a página diz de onde. Onde não há medida, a página descreve **sem
   número** em vez de arredondar uma plausível.
