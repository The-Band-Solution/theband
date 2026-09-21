# A aba *Flow per person* na tela da equipe

**Spec**: [060](../../specs/060-tela-da-equipe/spec.md) — US10 a US12, **FR-085 a FR-131**,
SC-022 a SC-038, escritos em 2026-09-10 a partir do protótipo.

**Protótipo, atestado como aprovado em 2026-09-08**:
`https://claude.ai/code/artifact/a8c7e08c-e9df-4a28-94ea-0800087f9751` — cópia que vale em
[`specs/060-tela-da-equipe/prototipo/team-people.html`](../../specs/060-tela-da-equipe/prototipo/team-people.html),
com o [prompt do desenho e a régua do QA](../../specs/060-tela-da-equipe/prototipo/team-people-PROMPT.md)
(seção 3, **26 itens**) e o [registro das decisões](../../specs/060-tela-da-equipe/prototipo/team-people-README.md).

**A implementação entrega exatamente a tela aprovada.** Seções, ordem, textos, marcas, ações e
recusas são as do protótipo. A aceitação confere a **seção 3 do prompt**, item a item, com a
captura da tela real ao lado e a conferência do QA como evidência.

## O estado do registro, e por que ele importa antes de qualquer tarefa

| O que | Estado em 2026-09-10 | Evidência |
|---|---|---|
| protótipo publicado | **sim**, endereço próprio, 2026-09-08 | `team-people-PROMPT.md` linha 4 |
| régua do QA escrita | **sim**, 26 itens | `team-people-PROMPT.md` §3 |
| requisitos escritos no lugar normativo | **sim, desde 2026-09-10** — FR-085 a FR-131 na `spec.md` | `grep -c "^- \*\*FR-" spec.md` → 131 definições, sem buraco e sem repetição |
| aprovação **registrada** | **não** | `team-people-PROMPT.md`: *"Status: aguardando aprovação"*; `team-people-README.md`: *"Status: aguardando aprovação da pessoa mantenedora"*; `grep -rn "a8c7e08c" --include="*.md" .` devolve só esses dois arquivos |
| aprovação **atestada** | **sim** — a afirmação de que a pessoa mantenedora aprovou em 2026-09-08 chegou na tarefa de 2026-09-10, de quem coordena | a própria tarefa |

**Aprovação atestada não é aprovação registrada, e a diferença é a mesma que este projeto cobra
de revisão de código.** Vazio prova ausência de registro, não ausência do fato. O que falta é um
ato só: o Design marcar *Approved 2026-09-08* nos dois arquivos e republicar no mesmo endereço, e
a pessoa mantenedora confirmar. Até lá, toda tarefa desta aba seria construída contra uma régua
cuja aprovação só existe de memória — e é a régua que decide aceitação de 26 itens.

## O que a aba é, e o que ela não é

`/teams/:id?tab=people` — terceira aba, **sem rota nova**, rótulo ***Flow per person***. Uma linha
por membro, na **mesma janela** dos gráficos do Dashboard, com seis colunas e **nenhum gráfico na
linha**. Os quatro gráficos de **uma** pessoa abrem sob a própria linha; **duas** pessoas abertas
tiram as duas das linhas e viram quatro linhas de duas colunas. O teto é duas.

Ela responde **distribuição e história**. Ela **não** é triagem — *Problems now*, no Dashboard, já
responde "o que precisa de olhar hoje" com limiares declarados e responde melhor — e **não** é
profundidade, que é `/people/:id`. Esse recorte é a decisão 7 do desenho, e todo o resto decorre
dela: sem ele, a aba duplica uma seção que já existe.

**O que ela nunca faz**, porque é decisão e não dificuldade: ordenar pessoas por medida (nem
oferecer a ordenação), apresentar média ou taxa por pessoa em lugar algum, desenhar limite de WIP,
somar as linhas para produzir número de equipe, ou repetir a lista de tarefas abertas.

## Os requisitos, por bloco

| Bloco | Requisitos | O que fixa |
|---|---|---|
| onde a aba vive | FR-085 a FR-088, FR-113, FR-114 | `people` no mesmo parâmetro da FR-001, sem rota nova; rótulo exato; tabela por padrão; a aba não repete a lista do Dashboard |
| um controle de granulação | FR-104, FR-115 | **um só**, no cabeçalho da seção — divergência deliberada do Dashboard, porque dois gráficos de duas pessoas nunca podem ficar em janelas diferentes |
| os dois blocos antes dos números | FR-116 a FR-118 | acima da tabela, sem colapsar, em toda equipe e tamanho; nenhuma média nem taxa por pessoa; nenhuma coluna ordena nem se oferece para ordenar |
| *working in progress* | FR-089 a FR-092 | a **série**, nunca um valor solto; **não é** `flow.wip.count` — o critério de fim não existe (#506) —, e o que se computa é a substituição declarada; **nenhum limite de WIP**; as más leituras copiadas |
| vazão e *promised × delivered* | FR-093 a FR-097 | item com dois responsáveis conta **uma vez para cada**, logo **nenhuma coluna soma ao fluxo da equipe**; *fechado* é ato da ferramenta; a contagem ignora o tamanho do item |
| a previsão | FR-098 a FR-103, FR-123 | a contagem *N of M* acima da tabela, **inclusive com N = 0 e N = M**; a coluna é **de estado, não de valor**, hachurada, com quatro estados e os quatro números da recusa; a história da equipe **não** é emprestada |
| as seis colunas | FR-119 a FR-123 | a célula da pessoa com papel, início, saída com autor e cobertura; a variação da série em palavras; o item não classificado junto da contagem; o denominador reduzido de *weeks with a close* |
| um bloco, e o de duas pessoas | FR-124 a FR-130 | teto **duas**, com a razão na tela; quatro gráficos numerados 1→4; **gráfico vazio é desenhado**; cada escala rotulada, e a frase de que os eixos diferem |
| as ausências | FR-131 | **três** ausências com forma, palavras e lugar próprios, mais a quarta — *nothing to forecast* |
| quem vê | FR-107, FR-108 | só quem alcança a equipe pelos quatro caminhos de `pode_ver_equipe/3`; recusa com motivo nomeado, nunca aba vazia |

## Decomposição

Três user stories atômicas, todas **P3** — `importance` **40** pela convenção declarada (P1=100,
P2=70, P3=40). `complexity` **desconhecida**: o Project não tem `Estimate` para nenhuma delas, e
desconhecido não é zero.

| User story | O que entrega | Depende de | Ordem |
|---|---|---|---|
| **US10** — o fluxo de cada membro, comparável na mesma janela | a tabela: seis colunas, um controle de granulação, os dois blocos, a ordem declarada | US9 (**entregue** em 2026-09-08) | **1ª** |
| **US12** — a ausência dita, pessoa por pessoa | as células que recusam: os quatro números, as quatro ausências, a contagem *N of M* | US10 | **2ª** |
| **US11** — os quatro gráficos de uma pessoa, sob demanda | o bloco de uma pessoa, o modo de duas, o gráfico vazio desenhado | US10, US12 | **3ª** |

**US12 vem antes da US11, e a razão está na spec**: sem a ausência dita, a primeira versão dos
gráficos mostra branco para a maioria das pessoas de uma equipe real, e branco é a afirmação que
a plataforma recusa. Numa equipe de 31 pessoas a coluna de previsão é quase toda recusa.

**Cada uma é fatia vertical.** US10 sozinha já é tela com número na tela — não é infraestrutura
sem consumidor. **As três não caberão numa semana junto de outra coisa**: a cadência é de uma
semana (decisão de 2026-08-10), e o corte, se preciso, é por user story e nunca por camada.

## As nove decisões pendentes, e o que cada uma trava

Sete são do cartão de decisões da própria tela (itens 18 a 24); Q25 e Q26 nasceram da
transcrição de 2026-09-10. As leituras, as recomendações e o que cada resposta emenda estão na
seção *Decisões do protótipo da aba Flow per person* da
[spec](../../specs/060-tela-da-equipe/spec.md).

| # | Pergunta, em uma linha | Trava |
|---|---|---|
| **Q20** | as duas leituras novas — a variação da série e os períodos com fechamento — precisam de nome na base | **o código** de FR-120 e FR-122: duas das seis colunas. Princípio IV |
| **Q21** | o cabeçalho da seção conta como "ao lado" da palavra *promised* (FR-063)? | **a aceitação**: a leitura (b) recusa o entregável que a (a) aceita |
| **Q25** | o que acontece ao escolher a **terceira** pessoa? | **a aceitação** do cenário 3 da US11 — o estado não foi desenhado |
| Q18 | duas pessoas abertas, ou três, ou uma | nada hoje; a resposta diferente emenda FR-124, SC-022, SC-031, SC-035 |
| Q19 | *throughput* e *delivered* são os mesmos números: quatro gráficos ou três? | nada hoje; emenda FR-127, FR-130 |
| Q22 | cobertura sem denominador | nada hoje; fecha a `[NEEDS CLARIFICATION]` da FR-111 |
| Q23 | a pessoa vê a própria linha quando não alcança a equipe? | nada hoje; se sim, é quinto caminho no veredito de acesso — do Arquiteto |
| Q24 | de quem são os quatro gráficos no longo prazo | nada hoje; decide o destino de FR-124 a FR-130 |
| Q26 | o que da seção 3 é aparato do protótipo e o que é tela | a **régua do QA**: 25 itens ou 26 |

**Q21 é o caso em que este papel não escolhe.** Um critério que admite duas leituras aceita e
recusa o mesmo entregável, e escolher a leitura que faz o sprint fechar é inverter a ordem entre
critério e classificação. As duas leituras estão escritas; a decisão é da pessoa mantenedora.

## Antes do código, e não é deste papel

Cinco declarações faltam na base de conhecimento, e o princípio IV as põe **antes** da tela:

| O quê | De quem |
|---|---|
| declarar o nível `person` em `flow.open_work.cumulative` e em `flow.completion_forecast` | Ontologia |
| declarar as duas leituras de FR-120 e FR-122 (Q20) | Ontologia |
| declarar onde vive a substituição do WIP que a FR-090 obriga a dizer | Ontologia |
| **candidato a ADR**: o que a plataforma chama de WIP enquanto o critério de fim não existe (#506) | Arquiteto |
| a consulta nova da série de trabalho aberto por pessoa, e a janela em `state_changes_by_period/3` | Desenvolvedor |

**Nenhuma medida nova.** As quatro necessidades de informação já existem — `flow.work_in_progress`,
`flow.throughput`, `flow.open_work_balance` e a que `flow.completion_forecast` responde. Esta aba
não cria número.

## Veredito: está aceitável para decompor?

**Ainda não — e falta um ato, não um sprint.**

| Portão | Estado | O que fecha |
|---|---|---|
| protótipo aprovado, com o registro da aprovação | **aberto** | Design marca *Approved 2026-09-08* nos dois arquivos e republica no mesmo endereço; a pessoa mantenedora confirma |
| requisito escrito no lugar normativo | **fechado em 2026-09-10** | FR-085 a FR-131 na `spec.md` |
| régua do QA sem ambiguidade | **aberto** | Q26 — 25 itens de tela, ou 26 |
| declaração na base antes da tela | **aberto** para duas colunas | Q20, e o YAML da Ontologia |
| critério que não aceita e recusa o mesmo entregável | **aberto** | Q21 e Q25 |

Decompor agora produziria tarefas contra uma régua cuja aprovação não tem registro, duas colunas
cujo código o princípio IV não autoriza, e dois cenários que nenhuma evidência pode aceitar ou
recusar. **Fechados o registro da aprovação, Q26 e Q20, US10 e US12 estão prontas para tarefa**;
a US11 espera Q25, que é um estado de tela e volta ao Design.

O que **não** falta, e vale dizer porque é o caso mais comum de bloqueio nesta casa: dependência
de trabalho alheio. A US9 está entregue, `Forecast.monte_carlo/2` serve por pessoa sem alteração,
e `state_changes_by_period/3` só precisa receber a janela.

## O que o protótipo declara não ter medido

Está na própria tela, na seção *What was not verified*, e é o que a aceitação **não** pode tratar
como número:

- **nenhum fechamento foi medido** — todo *opened*, *closed*, *weeks with a close* e previsão das
  três faixas é exemplo;
- os zeros do SQUAD PINK são **inferência**: o item aberto mais novo tem 217 dias, mas um item
  aberto **e** fechado dentro da janela não aparece naquela amostra, e ninguém o contou;
- o rateio dos abertos restantes (52 em PINK, 69 na Equipe IA) é inventado para as linhas somarem
  o total real da subequipe;
- não existe número de cobertura de repositórios para nenhuma pessoa;
- **nada** foi medido para LEDS - ConectaFapes: a faixa de 31 linhas é teste de densidade, e o
  tamanho da equipe é a única coisa real nela;
- o teto de consultas (SC-031) **não foi medido** — é argumento, não medição;
- o caso da equipe composta é **descrito, não desenhado**.

**Real, medido na base de desenvolvimento em 2026-09-08**: itens abertos de quem está em equipe —
760 TASK · 288 US · 71 BUG · 35 EPIC (1 154); SQUAD PINK, 5 pessoas, 180 · 78 · 21 · 18 (297),
com 114, 77 e 54 abertos em três pessoas; Equipe IA, 7 pessoas, 67 TASK · 15 US · 1 BUG (83), com
11, 3 e **0** abertos em três pessoas; item aberto mais novo 217 dias, mais velho 550.
