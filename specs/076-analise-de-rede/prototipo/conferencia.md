# Conferência da tela entregue contra o protótipo aprovado — 076/T053

**Quem conferiu**: o agente QA (texto, estados e regras) e o agente Design (codificação visual), em
par, em 2026-10-06. Cada um conferiu a sua parte de forma independente, e os achados foram somados
aqui. **Quem consertou**: a sessão de implementação, na mesma branch, com a guarda de cada conserto
vista reprovando antes de ser aceita.

**Como**: a tela real, servida pela branch `feature/1309-acabamento` com o dado real de
`leds-conectafapes` no banco de desenvolvimento (leituras calculadas em 2026-10-06 21:55 UTC: rede
de revisão com 37, 44 e 47 pessoas e rede de designação com 47, 48 e 54 pessoas, nas janelas de 30,
90 e 180 dias). Capturas a 1280 px e a 360 px feitas pelo Playwright, e interações exercidas no
navegador: zoom, arrasto, roda e foco pelo teclado. A régua é `PROMPT.md` §3, e as divergências já
aprovadas são as de `research.md` R21.

**O que não tem captura**: a Tela 7 (alcance parcial), porque a conta usada administra a
organização, e os estados que o dado real não produz (3.4.4, 3.5.5). Esses itens estão marcados
*"conforme por teste"*, com o teste citado, e nunca como *conforme*.

As capturas finais, já depois dos consertos, estão em [`conferencia/`](conferencia/).

Legenda: **conforme** · **R21** (divergência aprovada) · **R21 aprovada em 2026-10-06** (segue a spec;
a pessoa mantenedora decidiu manter) · **defeito → consertado** · **conforme por teste** · **aberto**.

## Em toda página

| item | veredito | evidência |
|---|---|---|
| 3.0.1 menu e as seis páginas na ordem | conforme | abas "Review network, Graph, Communities, Hubs, Distance and small world, Positions and profiles" |
| 3.0.2 duas arestas, sem *collaboration* | R21 (*delegation* → *assignment*) | busca por `collaborat` e `delegat` nas 18 capturas: nenhuma ocorrência |
| 3.0.3 a aresta acompanha a navegação | **defeito → consertado** | a passagem pela Review network perdia `network`. Agora a página da 073 aceita a rede, conferida contra a lista da base, e a devolve às abas. Guarda: `review_network_live/area_test.exs`, que com o defeito reprova |
| 3.0.4 janela 30/90/180 lê outra leitura | conforme | "Switching the window reads another stored reading. It computes nothing." |
| 3.0.5 linha da leitura com *derived* e *observed* | conforme nas cinco páginas de análise; **defeito → consertado** no perfil; R21 aprovada em 2026-10-06 na 073 | o perfil não tinha linha nenhuma. Agora tem uma por rede (`Shared.linha_da_leitura/1`), como em [desk-profile](conferencia/desk-profile.png) |
| 3.0.6 até duas casas; nenhum zero no lugar de ausência | **defeito → consertado** | o autovetor positivo saía *"0.00"*. Agora sai *"under 0.01"* (`Shared.autovetor_texto/1`). Guarda: `graph_component_test.exs`. Os *"0"* de exclusão são contagens, e por isso fatos |

## Tela 1 — a área

| item | veredito | evidência |
|---|---|---|
| 3.1.1–3.1.4 | conforme por teste | `index_test.exs:41-54` |
| a Tela 1 aparece | R21 aprovada em 2026-10-06 | com uma organização só, `/network-analysis` leva direto a ela (`contracts/tela.md`) |

## Tela 2 — o grafo ponderado

| item | veredito | evidência |
|---|---|---|
| 3.2.1 tamanho, cor, espessura e seta | conforme na regra; **defeito → consertado** na legenda | a legenda não tinha a escala do tamanho e escrevia *"(derived)"* sem a marca. Agora tem três círculos (o menor, o mediano e o maior grau) e `Shared.marca`. O item *"not calculated"* só aparece se algum nó estiver sem faixa. Guarda: `graph_component_test.exs` |
| 3.2.1 cor em barra segmentada | R21 aprovada em 2026-10-06 | cinco círculos rotulados: a mesma regra, outra forma |
| 3.2.2 só sete nomes | conforme; **defeito → consertado** na sobreposição | os sete nomes se sobrepunham. Agora são postos sem colisão, de forma determinística (`rotulos/2`). Guarda: `graph_component_test.exs`, que com a colocação desligada reprova |
| 3.2.3 zoom, arrasto e destaque | **defeito → consertado** (arrasto e roda) | o ponteiro era dividido pela caixa do elemento, e o `viewBox` se ajusta pela altura. Agora usa `getScreenCTM().inverse()`. Medido no navegador: arrasto de (−200, −100) moveu o nó (−200,0, −100,0), e a roda manteve o ponto sob o cursor (606,3 contra os 606,3 esperados) |
| 3.2.4 mesma leitura, mesma figura | conforme | `cx` e `cy` dos 44 nós iguais depois de recarregar |
| desenho contra o protótipo | **defeito → consertado** | o `viewBox` quadrado num quadro largo espremia o núcleo. As posições do servidor passam a ser enquadradas eixo a eixo em 1000 × 625, a proporção do protótipo (`fit_to_frame/1`). A posição não é medida, e a mesma leitura dá a mesma figura. Veja [desk-graph](conferencia/desk-graph.png). **Aberto**: o núcleo continua denso, porque é a forma do dado real com o layout de Fruchterman e Reingold. Mudar o layout é mudança na base, e não foi feita |
| 3.2.5 o cartão | **defeito → consertado** (três) | (a) *"was reviewed on 55 change requests"* somava revisões e as chamava de solicitações, enquanto a 073 contava 49 distintas. Agora diz *"55 times on their change requests"*. A designação aberta, que conta uma vez por responsável, diz *"issues assigned N times"*. (b) O autovetor: ver 3.0.6, e a escala em R21 aprovada em 2026-10-06. (c) *"1 links out"* passa a *"1 link out"* |
| 3.2.6 contados e não desenhados | conforme | "bot or app 18 / organisation account 0 / not linked to a person 67 / self-reviews 21" |
| 3.2.7 sem ligação, escrito | conforme; **defeito → consertado** na marca | a frase vinha sem a marca tracejada. Agora vem com `<.absent reason="not drawn">`. Guarda: `graph_counts_test.exs` |
| 3.2.8 conectividade | conforme; **defeito → consertado** no resumo | *"1173 reviews"* incluía as excluídas e contradizia a soma desenhada (1067). Agora diz *"in this window, including those counted below and not drawn"* |

## Tela 3 — comunidades

| item | veredito | evidência |
|---|---|---|
| 3.3.1 três blocos | conforme | "Communities 5", "Modularity 0.55" contra Q_rand 0.54, "Not the declared teams / a reading" |
| 3.3.2 cor, contorno tracejado e letra | **defeito grave → consertado** | `fill-opacity-10` não é utilitário do Tailwind: nenhuma regra era gerada, e o contorno saía opaco cobrindo os nós. Agora usa `[fill-opacity:0.1]`. Guarda: `design_tokens_test.exs`, que mede no CSS compilado e reprova com a classe antiga. Veja [desk-communities](conferencia/desk-communities.png) |
| 3.3.2 A é a maior | conforme | A 15, B 13, C 8, D 5, E 3 |
| 3.3.3 o método | R21 (Louvain → CNM) | "greedy modularity method of Clauset, Newman and Moore" |
| 3.3.4 cartões | conforme; **defeito → consertado** no empate | o empate em "Most linked inside" não era marcado. Agora leva *"tied"*, como nos hubs. Guarda: `communities_test.exs` |

## Tela 4 — hubs

| item | veredito | evidência |
|---|---|---|
| 3.4.1, 3.4.3 | conforme | quatro blocos com *derived*, e a frase literal |
| 3.4.2 | R21 (empate pelo id, *"tied"*); **defeito → consertado** | o autovetor saía *"0.00"*: ver 3.0.6 |
| 3.4.4 estado sem valor | **defeito → consertado**, conforme por teste | faltavam o número de rodadas e a razão. Agora a frase diz *"After 1000 rounds… changing by more than 0.000001 per person…"*, lido da base por `NetworkAnalysis.options/0` (emenda no contrato). Guarda nova: `hubs_test.exs` |

## Tela 5 — distância e mundo pequeno

| item | veredito | evidência |
|---|---|---|
| 3.5.1, 3.5.2 | conforme | "2.6 steps", "6 steps", "47%"; barras hachuradas, 946 pares |
| 3.5.3 | R21 (50 → 100) | tabela com as duas razões |
| 3.5.4 σ e os aleatórios | **defeito → consertado** | não dizia quantos aleatórios ficaram partidos nem como a distância foi medida neles. A bateria passa a contar (`not_linked`), a leitura grava `random.graphs_not_linked`, e a frase diz *"k of 100 came out not fully linked; in those, the distance is the average over the pairs that reach each other"*. Leitura anterior: *"not recorded in this reading"*. Guarda: `distance_test.exs` |
| 3.5.5 rede partida | conforme por teste | `distance_test.exs:66-80` |

## Tela 6 — posições e perfil

| item | veredito | evidência |
|---|---|---|
| 3.6.1 tabela por nome | conforme; R21 aprovada em 2026-10-06 na frase | a frase vem da regra da base (FR-044) |
| 3.6.2, 3.6.3 | conforme | a regra a um clique, e a frase de não avaliação |
| 3.6.4 perfil | conforme nas seções; R21 aprovada em 2026-10-06 (listas por peso, sem proximidade nem autovetor: FR-048); **defeito → consertado** em duas coisas | (a) a lista vazia levava *"· 0 issues"* ao lado da ausência; agora fica só a ausência. (b) As unidades: cada linha é o peso do par (solicitações ou issues distintas), e o total diz *"reviewed N times"* ou *"N assignments"* onde a soma conta uma vez por par |

## Tela 7 — alcance parcial

| item | veredito | evidência |
|---|---|---|
| 3.7.1 | conforme por teste; R21 aprovada em 2026-10-06 no texto | `index_test.exs:140`: o texto é o da spec (US1, cen. 5) |
| 3.7.2 | conforme por teste; R21 aprovada em 2026-10-06 no rótulo | `graph_recorte_test.exs:169-184`: *"People outside your reach — community B (4)"* (US3, cen. 5) |
| 3.7.3 | conforme por teste | `graph_recorte_test.exs:177-179` |
| 3.7.4 | R21 (só alcançados) | `hubs_test.exs`, `communities_test.exs` |

## Tela 8 — telefone

| item | veredito | evidência |
|---|---|---|
| 3.8.1 nenhum grafo, com a frase | conforme | [phone-graph](conferencia/phone-graph.png) |
| 3.8.2 cartões e linhas por nome | **defeito → consertado** (dois) | (a) em `/positions`, o critério saía do cartão e a página ficava com 370 px. Agora é um bloco só, e a largura é de 360 px. Guarda: `positions_test.exs`. (b) Em `/communities`, os cartões vinham depois de 44 cartões de pessoa. Agora vêm primeiro (`max-sm:order-first`). Medido: os cartões em y = 1249 e a lista em y = 2495 |
| 3.8.3 perfil empilhado | conforme | [phone-profile](conferencia/phone-profile.png) |
| sem rolagem horizontal | conforme | `scrollWidth` = 360 nas oito páginas |

## Fim da página

| item | veredito | evidência |
|---|---|---|
| 3.9.1 *Decisions and open questions* | **aberto** (Design e Product Owner) | a tela, corretamente, não leva a seção. O protótipo continua *"version 1 · awaiting the maintainer's approval"*, com Q1–Q4 em *Open*. O `PROMPT.md` §4 pede ao Design que marque *Decided* e republique, e que traga as linhas de R21. Fica para depois da decisão das propostas da R21 (T054) |

## Observações, sem veredito

- *"organisation account 0"* aparece quando nenhuma conta da organização foi declarada. O número é
  uma contagem verdadeira, mas pode ser lido como *"não há tráfego de conta da organização"*. Fica
  para a pessoa mantenedora decidir se a frase muda para *"none declared"*.
- No tema escuro, as faixas *<2%* e *2–5%* ficam muito próximas (`dark-graph.png` do Design).
- Fora da 076, no telefone, o item *Network analysis* do menu principal fica fora da tela, num
  menu com rolagem horizontal sem indicação.
- *"generator exsss"* é um identificador interno, e aparece na tela como proveniência.
