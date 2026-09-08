# A tela da equipe: dashboard do gestor e estrutura

**Spec:** [060](../../specs/060-tela-da-equipe/spec.md). **Protótipo aprovado em 2026-09-07:**
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941` — cópia que vale em
[`specs/060-tela-da-equipe/prototipo/`](../../specs/060-tela-da-equipe/prototipo/), com o
[prompt do design](../../specs/060-tela-da-equipe/prototipo/PROMPT.md) e o
[registro das decisões](../../specs/060-tela-da-equipe/prototipo/README.md).

**A implementação entrega exatamente a tela aprovada.** Seções, ordem, textos, marcas, ações
e recusas são as do protótipo; o que o protótipo marca `example` é dado de exemplo, e o que
está nas tabelas de contagem é dado real de 2026-09-06.

## O que a implementação de 2026-09-08 entregou

| User story | Estado | O que dá para fazer na tela |
|---|---|---|
| **US1** — quem está na equipe | **entregue** | duas abas na mesma rota, uma linha por pessoa com os vínculos dentro, as quatro marcas com legenda em texto, e quem não gere lê tudo sem ver ação |
| **US2** — declarar e alterar papel | **entregue** | *Declare role* / *Change role* na linha, `＋ new role…` criando sem sair dela, e o lote *Declare all roles* |
| **US3** — a pessoa saiu | **entregue** | *Left the team…* com data obrigatória e vazia, e a mensagem dizendo quantos vínculos foram alcançados |
| **US4** — o vínculo que nunca foi | **entregue** | *Mistake…* com razão obrigatória, e o texto que separa equívoco de saída |
| **US5** — os papéis da organização | **entregue** | a seção *Roles*, com as duas contagens, código sugerido, renomear e ocultar |
| **US9** — o fluxo em três granulações | **entregue** | burn com valores e datas no eixo, *Promised × Delivered*, Monte Carlo como histograma, e o seletor semana/mês/ano no cabeçalho de cada gráfico |
| **US6, US7, US8** | **sem tarefa** | especificadas; o perfil de cada membro, o cartão da subequipe como porta, e as tarefas e problemas por pessoa |

**Fora da entrega, e por quê:**

- **T029, o gráfico pequeno no cartão da subequipe** (FR-084): depende do **cartão**, que é a
  US7. Construir o gráfico antes do cartão seria infraestrutura sem consumidor visível;
- **os quatro gráficos por membro** — WIP, prometido × realizado, throughput e Monte Carlo —
  pedidos em 2026-09-08 e especificados em
  [`spec-graficos-por-membro.md`](../../specs/060-tela-da-equipe/spec-graficos-por-membro.md)
  como US10 a US12. **Sem protótipo aprovado**, e a casa não implementa tela sem ele.

**Três defeitos anteriores à feature, achados ao construí-la:**

1. `count_team_members_at/3` e `team_members_at/3` contavam **vínculos** onde prometiam
   pessoas — quem tem dois papéis contava duas vezes, e a tela listava a pessoa duas vezes;
2. o evento `promover` **não conferia permissão nenhuma**: qualquer conta autenticada que
   alcançasse a tela declarava papel para quem quisesse;
3. a coleta **desfazia a saída declarada** sobre vínculo observado, porque a guarda não
   reconhecia o autor da saída. Registrado como emenda na ADR 0008.

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
