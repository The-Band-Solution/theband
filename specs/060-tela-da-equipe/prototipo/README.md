# O protótipo aprovado

[`team-dashboard-structure.html`](team-dashboard-structure.html) — abrir no navegador. Duas
telas numa página só, separadas pela faixa `screen 1 · dashboard` / `screen 2 · structure`.

Desenhado e aprovado com a pessoa mantenedora em 2026-09-07, e é **a referência visual desta
feature**. Publicado durante o desenho em
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941`; a cópia aqui é a que
vale. Mesmo vocabulário visual do protótipo da 057 (`specs/057-tela-da-equipe-complexa/prototipo/`).

## As decisões tomadas sobre ele (2026-09-07)

1. **Duas abas** de `/teams/:id` — Dashboard e Structure —, com a aba na URL (`?tab=structure`).
2. **"Mistake" vale para vínculo declarado e observado.** Depois de marcado, a coleta **não
   recria** o vínculo mesmo que a origem continue listando a pessoa; a tela mostra as duas
   afirmações até a origem ser corrigida.
3. **Equipe composta pode ter membros diretos** — a linha "direct members" no dashboard e o
   chip "direct" na lista.
4. **Gráficos no dashboard da equipe composta** — burn-up/burn-down por semana · mês · ano,
   Prometido × Entregue, Monte Carlo — por pedido da pessoa mantenedora em 2026-09-07. Emenda a
   057 FR-011. A página do squad continua com os gráficos dela.
5. **Papéis são criados na tela de estrutura** (e continuam em `/roles`): mesmo comando, mesmo
   escopo — a organização.
6. **Projetos no dashboard**: só os vínculos declarados equipe → projeto. Trabalho fora de
   qualquer projeto declarado vira **alerta** (quem, onde, quanto) — nunca linha de projeto.
7. **Prometido × Entregue**: prometido = itens **abertos** no período; entregue = itens levados a
   **done** no período. Sem depender de iteração.

8. **Equipe composta mostra o resumo de cada subequipe** — um cartão por squad com as medidas
   e um gráfico pequeno; clicar no cartão ou no gráfico abre a página da subequipe (057, screen 2).

## Premissas que a spec carrega até serem contestadas

- Mês e ano só mudam a granulação do eixo do burn e do Prometido × Entregue; o Monte Carlo
  continua semanal.
- Nomes de pessoas no protótipo são fictícios (marcados `example`); contagens e medidas vêm da
  coleta real de 2026-09-06 da organização `leds-conectafapes`.
