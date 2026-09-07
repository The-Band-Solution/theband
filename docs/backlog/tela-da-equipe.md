# A tela da equipe: dashboard do gestor e estrutura

**Spec:** [060](../../specs/060-tela-da-equipe/spec.md). **Protótipo aprovado em 2026-09-07:**
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941` — cópia que vale em
[`specs/060-tela-da-equipe/prototipo/`](../../specs/060-tela-da-equipe/prototipo/), com o
[prompt do design](../../specs/060-tela-da-equipe/prototipo/PROMPT.md) e o
[registro das decisões](../../specs/060-tela-da-equipe/prototipo/README.md).

**A implementação entrega exatamente a tela aprovada.** Seções, ordem, textos, marcas, ações
e recusas são as do protótipo; o que o protótipo marca `example` é dado de exemplo, e o que
está nas tabelas de contagem é dado real de 2026-09-06.

## O que é

Uma equipe passa a ter duas abas em `/teams/:id`:

- **Dashboard** — a visão geral do gestor: um cartão por squad (porta para o detalhe), os
  problemas de agora com limiar declarado, as medidas com a composição sobre a qual foram
  calculadas, o fluxo da equipe inteira (burn por semana · mês · ano, aberto × done, Monte
  Carlo), as pessoas — diretas e via squads — com o que cada uma faz agora e o que demonstrou,
  os projetos declarados e o alerta de trabalho fora de projeto.
- **Structure** — squads (compor, encerrar), papéis (criar, renomear, remover), membros
  (declarar papel, registrar saída com data, marcar equívoco com razão — inclusive em vínculo
  observado, sem recriação pela coleta), as duas afirmações quando coleta e declaração
  discordam, e a proveniência.

## Ordem de entrega (decisão da pessoa mantenedora: membros primeiro, depois subequipes)

| PR | user stories | o que entrega |
|---|---|---|
| 1 | US1–US5 | membros: lista por vínculo, declarar/alterar papel, saída com data e autor, equívoco em observado com guarda de recriação, criar papel na estrutura |
| 2 | US6 | subequipes: compor com data ou desconhecido, encerrar, ciclo com caminho, histórico, cartão como porta |
| 3 | US7 | dashboard: abas, composição em toda medida, problemas agora, pessoas, projetos declarados, alerta |
| 4 | US8 | fluxo da equipe inteira: burn semana/mês/ano, aberto × done, Monte Carlo |

Depende de: ADR 0008 (#814), #813.

## Perguntas em aberto (2026-09-07)

Listadas na conversa com a pessoa mantenedora e na spec: janela por granulação; saída sem data;
"declare all roles" em lote; limiares dos problemas; perfil no dashboard (quantas habilidades,
piso); qual é a equipe composta hoje (derivada × declarada); visibilidade por escopo; quem age na
estrutura; janela das medidas; definição de "trabalho fora de projeto".
