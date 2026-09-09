# O protótipo aprovado

[`team-dashboard-structure.html`](team-dashboard-structure.html) — abrir no navegador. Duas
telas numa página só, separadas pela faixa `screen 1 · dashboard` / `screen 2 · structure`.

Desenhado e aprovado com a pessoa mantenedora em 2026-09-07, e é **a referência visual desta
feature**. Publicado durante o desenho em
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941`; a cópia aqui é a que
vale. Mesmo vocabulário visual do protótipo da 057 (`specs/057-tela-da-equipe-complexa/prototipo/`).

**Republicado no mesmo endereço em 2026-09-08** — pedido textual: *"faça um novo protótipo com as
marcas de conceitos e me mostre"*. Endereço novo seria protótipo novo, e protótipo novo pediria
aprovação nova; por isso a republicação é sempre aqui. As decisões desta rodada estão na seção
"As decisões da republicação" abaixo, e a estrutura seção a seção — que é a régua do QA — na
seção 3 do `PROMPT.md`.

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

9. **O dashboard é a visão geral do gestor**: além das medidas, mostra **Problems now**
   (issues abertas há mais de 30 dias, revisões esperando há mais de 7, pipeline falhando na
   main, tarefas paradas além do limiar, pessoas sem tarefa, membros sem papel, trabalho fora de
   projeto, anomalias de estrutura — cada um com o limiar declarado na base) e **People** — todos
   os membros, diretos e via squads, com papel, **as tarefas abertas agora** (todas, com idade e
   marca de parada; nunca uma "atual" eleita) e o **perfil demonstrado** (ou "sem perfil ainda",
   abaixo do piso).

## As dez respostas da pessoa mantenedora (2026-09-07, segunda rodada)

| # | questão | decisão |
|---|---|---|
| 1 | janela dos gráficos por granulação | padrão fixo (8 semanas · 12 meses · todos os anos) **e** a pessoa pode escolher o período |
| 2 | saída sem data | **exigir a data** |
| 3 | "Declare all roles" em lote | **manter** |
| 4 | limiares dos problemas | **30 d** issues, **7 d** revisões — ganham YAML; tarefa parada usa os **90 d** já declarados |
| 5 | perfil no dashboard | **4 habilidades, piso 15**, e **link para o perfil detalhado** da pessoa |
| 6 | qual é a equipe composta | a organização **declara** "Conecta Fapes" e compõe os squads; a derivada continua ao lado |
| 7 | quem vê nomes, tarefas e perfil | quem tem escopo sobre a equipe **e os membros da equipe**; os demais veem agregados |
| 8 | quem age na estrutura | administrador **e** um papel de **gestor da equipe** (concessão "gerir estrutura da equipe") |
| 9 | janela das medidas | **56 dias por padrão**, e a pessoa pode escolher o período |
| 10 | trabalho fora de projeto declarado | issues e PRs em repositórios fora de qualquer quadro de projeto declarado + quadros sem projeto |

## As decisões da republicação (2026-09-08)

A marca do conceito **não estava no protótipo aprovado**: entrou na implementação depois da
aprovação de 7 de setembro. Pela regra da casa — *a tela implementada é exatamente a tela
aprovada* — ela precisava voltar ao protótipo antes de continuar no código. As decisões de cor
estão em [`marca-do-conceito.md`](marca-do-conceito.md); as de estrutura, aqui.

| # | decisão | razão em uma linha |
|---|---|---|
| 16 | **A marca do conceito abre cada item de trabalho**, no lugar do `node_id` da origem. Seis cláusulas: `EPIC`, `US`, `TASK`, `BUG`, o identificador sem tradução, e `—` | duas ignorâncias diferentes são duas afirmações diferentes, e o `node_id` não diz nada a quem lê |
| 16b | **Matiz pertence à origem e ao estado**; a família do conceito se distingue por **forma** — sem quadrado, escada do escopo em peso e preenchimento — e toma emprestada uma única matiz, o **clay do defeito** | não há matiz livre nesta paleta, e o clay significa gravidade nesta casa |
| 17 | **Vão fixo de 3.5 rem**, marca alinhada à direita | quinze itens de uma pessoa começavam em quinze bordas esquerdas diferentes |
| 18 | **`stale` sai do clay e vai para o âmbar** — e esta é a única das três divergências resolvida **a favor da implementação** | a coluna de flags desta mesma tela já marca o mesmo fato em âmbar; âmbar é "derivado e aviso", que é o que a passagem de um limiar é; e com quase todo item parado, o clay pintaria a lista inteira e deixaria de significar gravidade. O **texto** continua `stopped · over 90 d`: o limiar é parte da medida |
| 19 | **O burn abre na linha de base do que já estava aberto**, e a identidade `open(t) = open(t₀) + opened − closed` fica escrita sob o gráfico | sem a base, uma equipe com 834 itens velhos e poucas aberturas novas mostra distância zero — e a implementação já calcula essa base (`aberto_inicial`) |
| 20 | **Itens além do limiar: uma linha por subequipe e nenhum total** | item de quem está em duas subequipes seria contado duas vezes (057, FR-008) |
| 21 | **Nomes**: "Committed × delivered" → **Promised × Delivered** (a palavra da pessoa mantenedora, e "committed" afirmava um compromisso que a plataforma não tem); "Monte Carlo forecast" → **Delivery forecast** (o método não é a resposta). O seletor de granulação vai para o cabeçalho de cada gráfico, e a janela fica sempre no título | |
| 22 | **As duas hipóteses da previsão são *frozen scope* e *live scope***, como `flow.completion.forecast` declara — e não "últimas 8 semanas / últimas 4 semanas", que o protótipo aprovado nomeava | nada na tela sem declaração na base (constituição, princípio IV) |

### As três divergências levantadas em 2026-09-08, e o veredito

| divergência | veredito |
|---|---|
| `declared` em verdete na implementação, `info` azul no aprovado | **o protótipo fica como está** — verdete significa "a origem mostrou", e uma matiz não pode significar as duas coisas. Defeito da implementação |
| as quatro marcas de vínculo sem o quadrado de 0.6 rem | **o protótipo fica como está** — o quadrado é o canal da família, e é ele que faz a separação entre as duas famílias ser por forma. Defeito da implementação, e a correção de raiz |
| `stale` em âmbar na implementação, clay tracejado no aprovado | **o protótipo muda** (decisão 19). É a única em que a implementação estava certa, e a razão só ficou visível com o dado real e com o `BUG` tomando o clay |

As duas primeiras — mais duas que apareceram na conferência: o texto do badge (`stale` em vez de
`stopped · over 90 d`) e a faísca do cartão em `primary`/`warning` em vez da cor da subequipe —
estão na tabela **"Where the screen of 8 Sep drifted from this prototype"**, no fim do protótipo.
São defeitos para o QA levantar, e não mudanças a adotar.

### As perguntas que ficaram abertas, para a pessoa mantenedora

| # | pergunta | opções | recomendação |
|---|---|---|---|
| 23 | **O badge em toda linha.** Todo item aberto do SQUAD PINK está além dos 90 dias, e um badge que tudo tem deixa de ser sinal | (a) um badge por linha, como aprovado; (b) dizer uma vez por pessoa ("all 114 open beyond 90 d") e marcar as **exceções** | **(b)** — marcar o raro, não o comum. O protótipo mostra (a), para que as duas possam ser comparadas |
| 24 | **O que a previsão prevê.** O ritmo vem quase todo de itens abertos dentro da janela, enquanto 834 mais velhos não se moveram | (a) uma previsão, com a ressalva escrita; (b) duas populações — trabalho novo e estoque parado — cada uma com a sua; (c) prever só o estoque | **(b)**, porque as duas têm ritmo diferente e dono diferente |
| 25 | **Os dois clays**, quando um defeito também está parado | resolvido por ora movendo `stale` para âmbar; se a pessoa mantenedora preferir `stale` em clay, o `BUG` devolve a matiz e se distingue só por peso | **manter como republicado** |

### As medidas novas que pedem YAML antes do código

| nome proposto | o que é |
|---|---|
| `flow.wip.by_concept` | contagem de itens abertos **por conceito**, por pessoa e por subequipe — a "mistura" dos cartões e das linhas de pessoa |
| `flow.stalled_work.count` | itens abertos além do limiar declarado, por subequipe e por pessoa, **sem total** |
| `flow.open_work.age` | idade do item aberto mais velho e do mais novo (550 d / 217 d na tela) |
| `flow.open_work.baseline` | o aberto no início da janela (`aberto_inicial`), do qual o burn parte — **confirmar antes se `flow.open_work.cumulative` já o cobre** |
| `flow.completion.forecast.unfinished_share` | a proporção de rodadas que não concluíram dentro do horizonte — a YAML já a exige no resultado; falta o nome com que a tela a mostra |
| `flow.concept.promotion_coverage` | quantos itens a promoção classificou **sem tipo declarado na origem** (778 de 1 154) |

Nenhuma delas é medida nova de fenômeno: são recortes e composições de medidas já declaradas. Pelo
princípio IV, mesmo assim precisam de nome na base antes de a tela mostrá-las.

## Premissas que a spec carrega até serem contestadas

- Mês e ano só mudam a granulação do eixo do burn e do Prometido × Entregue; o Monte Carlo
  continua semanal.
- "Gestor da equipe" é uma concessão a um papel organizacional (como as concessões de
  visibilidade de `/access-scopes`), e não um segundo tipo de conta.
- Nomes de pessoas no protótipo são fictícios (marcados `example`); contagens e medidas vêm da
  coleta real de 2026-09-06 da organização `leds-conectafapes`.
- **Desde 2026-09-08**: as contagens de itens por conceito vêm da base de desenvolvimento medida
  naquele dia — 760 TASK, 288 US, 71 BUG, 35 EPIC entre quem está em equipe; 180/78/21/18 numa
  subequipe real, mostrada como SQUAD PINK. O rateio entre as cinco pessoas, os títulos, os
  números de item e os logins continuam `example`. As curvas de fluxo continuam `example`, agora
  na ordem de grandeza real do estoque.
