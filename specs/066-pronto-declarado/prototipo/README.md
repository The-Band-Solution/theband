# O protótipo das três declarações do quadro

[`board-declarations.html`](board-declarations.html) — abrir no navegador. Duas telas numa
página só, separadas pelas faixas `screen 1 · the board` e `screen 2 · where the statements
land`, mais a seção `decisions and open questions`. Tudo visível ao carregar: os dois
formulários de declaração aparecem **abertos** como exemplo.

Desenhado em **2026-09-14**, a partir do pedido do Product Owner do mesmo dia, para as specs
**066** (a definição de pronto declarada) e **067** (o critério de aceite declarado), ao lado da
**042** (critério de início) que já está na tela. Publicado em
`https://claude.ai/artifact/Gi7gtFR9uJfynPbuEuAU9g`; **a cópia aqui é a que vale** — o endereço
publicado pode mudar, a spec não pode depender dele. Mesmo vocabulário visual do protótipo
aprovado da 060 (`specs/060-tela-da-equipe/prototipo/`) e do `DESIGN.md`.

A estrutura seção a seção — **que é a régua do QA** — está na seção 3 do
[`PROMPT.md`](PROMPT.md).

**Aprovação: aguardando a pessoa mantenedora.**

## O dado que a tela mostra, e de onde veio

Tudo o que é número vem de `dado-real-quadro-43.md` (medido em 2026-09-14 na origem e no banco
de desenvolvimento; eventos de mudança de estágio coletados até 2026-09-09). O que **não** foi
medido está escrito na tela como *not measured for this prototype* — nunca preenchido com um
plausível. As **declarações** (quais regras estão ativas, quem as fez, quando) são `example`:
nenhuma foi feita ainda, e o autor é um nome fictício (*Ana Vieira*), não uma pessoa real.

**Onde o dado e a spec divergem, a tela segue o dado:**

| a spec diz | o dado diz | a tela mostra |
|---|---|---|
| 067, US1: saídas de Homologation "→ Done 10, → In Validation 2, → To Do 1, → Dependencies 1, → Desaprovado 0" | há também **→ Homologation In Progress 2** | as seis saídas, inclusive essa, com a contagem |
| 066, tabela de fatos: "1 077 itens com valor de Status já no banco — Done 377 abertas · 68 fechadas" (coleta de 09/09) | na origem em 14/09: Done **459** — **294** abertas · 165 fechadas | os números de 14/09, com a data escrita |
| 067, SC-003: "119 do Backlog e 80 do robô não aparecem como aceitos" | os 119 e os 80 são **movimentações**, não itens; o robô se sobrepõe às outras origens | a composição dos moves listada; o número de **itens** sem avaliação declarada **recusado** ("not measured"), porque 459 − 10 somaria populações diferentes |

## As decisões de desenho, e a razão de cada uma (2026-09-14)

| # | decisão | a razão |
|---|---|---|
| **D1** | **Os dois cartões novos entram logo depois de *Start criterion*, na ordem 042 → 066 → 067, cada um com cabeçalho próprio e uma pergunta.** Nada mais na tela se move | princípio X: um componente responde uma pergunta. A voz dos cabeçalhos é a que a tela já tem — *What each iteration field means*, *Where the deadline comes from* — então *What each column means* e *Where evaluation happens* soam como a mesma tela, não como um painel colado |
| **D2** | **Proposta é âmbar hachurado; ativa é `info` cheio; sem decisão é tracejado; revogada é cinza cheio.** Nenhuma matiz nova, nenhuma forma nova | a proposta é **derivada** do vocabulário reconhecido, e a marca da casa para derivado é âmbar hachurado — a natureza da proposta já tem nome no sistema. A linha de In Progress mostra uma proposta em repouso; a de Done mostra a regra ativa **e** a proposta de que ela veio, para que a distinção esteja na mesma tabela |
| **D3** | **Os cinco destinos são rádios com o id da ontologia e uma linha do que cada um afirma**, e a lista traz a caixa tracejada *Not offered here: accepted / not accepted* citando `sro.rule03` e apontando para o cartão C. A linha **Desaprovado** carrega o mesmo ponteiro | 066 FR-001 manda dizer, com a regra, **onde a pessoa procuraria "aceito"**. Ela procuraria em dois lugares: na lista de destinos e na linha Desaprovado. Explicar no ponto da decisão, como a 042 fez com o desempate |
| **D4** | **Revogar aparece como marca no registro**: a linha Homologation guarda a regra anterior (*completed*, declarada 09:02, revogada 09:10, com a razão) abaixo da ativa | "revogar marca, nunca apaga" é regra da casa e precisa de forma na tela, não só no banco. O QA confere que revogar produz esta linha, nunca uma célula vazia |
| **D5** | **O cartão de avaliação é dois passos num cartão só** — chips para o estágio, tabela para as saídas — e não dois cartões | as saídas não têm sentido sem o estágio: separar em dois cartões seria duas perguntas para uma decisão. Toda saída observada aparece com a contagem; os estágios sem saída registrada viram **uma** linha recolhida, para que a primeira ocorrência tenha onde cair (067, edge case "saída nova") |
| **D6** | **Zero é escrito como contagem** — "0 · collected · up to 9 Sep" — e a linha Desaprovado diz **por que** é zero (o único Desaprovado veio de In Progress). A **cobertura** é uma caixa fixa sob a tabela | 067 FR-013 e SC-002: zero como contagem, não como ausência de critério; cobertura em 100% das telas com número da 067 |
| **D7** | **A terceira contagem, *no declared evaluation*, recusa número de itens neste protótipo** e lista os moves | o dado medido é de **movimentações** (197 + 119 + 58 + …), não de itens, e o robô se sobrepõe. Inventar 449 (= 459 − 10) somaria populações distintas — a regra "duas medidas: comparar sobreposição" desta casa. A implementação conta itens; o protótipo mostra a forma e recusa o número |
| **D8** | **No detalhe do item, três cartões de afirmação lado a lado com as marcas**, mais a tabela de períodos de estágio (uma linha por passagem, com a fonte); no painel da pessoa, os mesmos três, depois a cobertura, depois os dois números de desacordo | 066 FR-007/FR-010/FR-024 e 067 FR-011: as afirmações são distinguíveis sem cor e nunca sintetizadas. Onde uma medida não foi feita hoje, o cartão **diz** "not measured" em vez de carregar número de exemplo contra uma pessoa real |
| **D9** | **Autores e instantes das declarações são uma administradora fictícia marcada `example`** | nenhuma declaração foi feita; atribuir uma a uma pessoa real seria afirmar o que ninguém registrou |
| **D10** | **Cartões que não mudam aparecem como stubs quietos** — "unchanged — as on the screen of 14 Sep 2026" | mantém a **ordem** conferível sem redesenhar o que o QA compara com a tela de hoje; redesenhar o que não muda convidaria a mudá-lo |

## As perguntas que ficaram abertas, para a pessoa mantenedora

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** | O cartão da 042 deve ser renomeado de *Start criterion* para uma pergunta na mesma voz — *When work starts* —, para que as três declarações leiam como três respostas? | (a) manter *Start criterion*; (b) renomear no mesmo PR, texto do resto intocado | **(b)** — só o cabeçalho muda, e é a razão pela qual o princípio X dá cabeçalho a cada componente |
| **Q2** | Uma proposta pode ser dispensada sem declarar destino — um *Ignore* que a esconde — ou o único jeito de removê-la é declarar *this column says no phase*? | (a) sem ignore: a recusa registrada é o caminho (066 FR-022); (b) um ignore por conta, não registrado | **(a)** — um ignore não registrado é decisão que ninguém acha depois |
| **Q3** | Onde a organização escolhe qual definição alimenta as medidas de fluxo (066 FR-016)? É escolha da organização, não do quadro | (a) uma linha neste cartão com link para a tela da organização; (b) só na tela da organização | **(a)** — quem acabou de declarar *Done → completed* vai procurar aqui por que o burn não mudou |
| **Q4** | A cláusula "só transições feitas por pessoa": padrão desmarcado (robô conta, ator visível — 067 FR-005) ou marcado? | (a) desmarcado, como a FR-005 diz; (b) marcado | **(a)** — a plataforma não decide que a automação "não avalia"; o ator aparece sempre |
| **Q5** | Os números de desacordo (294 · 41) se repetem no topo da seção do quadro, acima dos cartões, ou só dentro do cartão da 066? | (a) só no cartão; (b) também na linha do cabeçalho do quadro | **(a)** — não têm sentido sem a regra que os produz, e a regra vive no cartão |

## Os nomes que a base precisa antes do código

Princípio IV — nada na tela sem declaração na base de conhecimento:

- `github.project_item_status` — a regra que a 066 FR-021 nomeia: destinos admitidos, o
  vocabulário que gera propostas, e o que **não** materializa (`sro.accepted_deliverable`,
  `sro.sprint_deliverable`), com a razão;
- o **vocabulário reconhecido de pronto** (*Done*, *Concluído*, *Closed*…), versionado, com
  proveniência — propõe, nunca decide;
- o **critério de avaliação de aceite** — objeto social da SRO no molde de
  `spo.activity_start_criterion` (067 FR-016), com a cláusula *só pessoas* e os três sentidos de
  saída; nome e id definitivos são do trabalho de ontologia no plano;
- nomes de medida para: *concluída pelo quadro e aberta na origem*; *fechada na origem e não
  concluída pelo quadro*; *aceitos pelo critério*; *não aceitos*; *sem avaliação declarada*;
  *fora da avaliação*; *cobertura dos eventos de mudança de estágio*; *idade no estágio atual* e
  *passagens pelo estágio* (066 FR-025).

## Premissas que a spec carrega até serem contestadas

- **A tela vive no quadro**, ao lado do critério de início — três declarações, três cartões, uma
  pergunta cada. A escolha de definição para as medidas (066 FR-016) é da organização e fica
  fora desta tela (Q3 decide se há um link).
- **A proposta é derivada, e leva a marca de derivado.** Se a casa decidir que proposta merece
  marca própria, é uma matiz nova — e a decisão de 2026-09-08 não achou nenhuma livre.
- **Os nomes de estágio nunca são traduzidos** na tela (*Refinamento*, *Pronto para
  desenvolvimento*, *Desaprovado* ficam em português dentro da interface em inglês), porque são a
  palavra da organização (066 FR-023).
- **Quem não administra vê as tabelas sem a coluna de ação** (066 FR-005, 067 FR-004); o
  protótipo mostra a visão de quem administra e escreve a outra em nota.
- **O painel da pessoa e o detalhe do item existem hoje** e ganham os cartões de afirmação;
  este protótipo desenha só o que muda neles, não a tela inteira.
