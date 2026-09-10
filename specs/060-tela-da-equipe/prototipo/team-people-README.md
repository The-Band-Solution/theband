# O protótipo da aba *Flow per person*

[`team-people.html`](team-people.html) — abrir no navegador. Três telas numa página só, separadas
pelas faixas `screen 3` · `screen 4` · `screen 5`, continuando a numeração do protótipo aprovado
(`screen 1 · dashboard`, `screen 2 · structure`).

- **Endereço**: `https://claude.ai/code/artifact/a8c7e08c-e9df-4a28-94ea-0800087f9751`
- **Publicado**: 2026-09-08. **Endereço novo**, porque é **tela nova** — não republicação.
  **Republicado no mesmo endereço em 2026-09-10**, com a ramp tipográfica declarada e a borda
  colorida de um lado removida (`DESIGN.md`, *The One-Ramp Rule* e *The No-Accent-Edge Rule*).
  O conteúdo não mudou.
- **Status**: **APROVADO pela pessoa mantenedora em 2026-09-08**, registrado em **2026-09-10**
  junto das respostas às sete perguntas abertas — ver *As sete perguntas, respondidas*, abaixo.
- **Não altera** o protótipo aprovado em 2026-09-07,
  [`team-dashboard-structure.html`](team-dashboard-structure.html)
  (`.../0be1668f-3afa-4668-bfb2-c77fae11d941`), que continua valendo como está. Este herda dele
  os tokens, as marcas de vínculo, as marcas de conceito, o vão fixo de 3.5 rem e o vocabulário
  de seção.
- **A estrutura seção a seção**, que é a régua do QA, está em
  [`team-people-PROMPT.md`](team-people-PROMPT.md), seção 3.

## O pedido

> *"faça um protótipo com as métricas de cada membro da equipe na página da equipe"*
> — pessoa mantenedora, 2026-09-08

Antes dele, e no mesmo dia: *"Especifique colocar na tela da equipe para cada membro os gráficos:
Working in progress, prometido x realizado, throughput e monte carlo."*

## As três telas

| Faixa | Equipe | O que ela põe à prova |
|---|---|---|
| `screen 3` | **SQUAD PINK** · 5 pessoas · 297 abertos | o caso em que **nada se moveu**: cinco linhas iguais, a coluna de previsão inteira em recusa, e uma pessoa aberta com dois gráficos **vazios** — o teste de que ausência é escrita e gráfico vazio é desenhado |
| `screen 4` | **Equipe IA** · 7 pessoas · 83 abertos | o caso em que há movimento e as linhas **não** são iguais: uma acima do piso, duas abaixo por razões diferentes, uma que entrou dentro da janela, uma que saiu com data, uma **sem nenhum item observado**, e uma com item que a regra não classificou. E o segundo modo: **duas pessoas abertas**, quatro linhas de duas colunas |
| `screen 5` | **LEDS - ConectaFapes** · 31 pessoas | a densidade: seis colunas e 27 recusas em 31 linhas, com todos os blocos fechados. **Nada nesta faixa foi medido** |

## O que é real e o que é exemplo

**Real, medido na base de desenvolvimento em 2026-09-08:** itens **abertos** de quem está em
equipe — 760 TASK · 288 US · 71 BUG · 35 EPIC (1 154). SQUAD PINK: 5 pessoas, 180 · 78 · 21 · 18
(297), com 114, 77 e 54 abertos em três delas. Equipe IA: 7 pessoas, 67 TASK · 15 US · 1 BUG
(83), com 11, 3 e **0** abertos em três delas. Item aberto mais novo amostrado: 217 dias; mais
velho: 550.

**Exemplo, e marcado como tal na tela:** nomes, logins, papéis, contagens de repositório, o
rateio dos itens abertos restantes (52 em PINK, 69 em Equipe IA), **e todo número de aberto,
fechado, semanas com fechamento e previsão da página inteira**. A faixa de 31 linhas é exemplo
por inteiro.

## As decisões do desenho, e a razão de cada uma

Nenhuma decisão da pessoa mantenedora foi tomada sobre esta tela ainda. As de baixo são **do
desenho**, reversíveis por ela, e estão na própria tela (itens 7 a 17).

1. **A aba se sustenta, com o trabalho reenquadrado.** Ela **não** é triagem — *Problems now*, no
   Dashboard, já responde "o que precisa de olhar hoje" com limiares declarados e responde
   melhor. E **não** é profundidade — `/people/:id` é a casa disso. O que sobra é a única coisa
   que só a tela da equipe faz: **o fluxo de cada membro sobre uma janela só**. Se ela fosse
   enquadrada como triagem, duplicaria *Problems now*; como profundidade, duplicaria a tela da
   pessoa. Todo o resto do desenho decorre dessa frase.
2. **Seis colunas, e a quarta medida é estado, não valor.** *person · open now e a variação ·
   opened · closed · weeks with a close · forecast.* *Weeks with a close* é a regularidade da
   vazão, e ela **divide a unidade com o piso da previsão** — por isso as duas colunas ficam
   vizinhas: lê-se, na mesma linha, quantos períodos tiveram fechamento e quantos fechamentos
   faltam para o piso.
3. **A palavra "working in progress" não aparece na tabela.** O mesmo recurso que a casa já usa
   para "promised": a coluna se chama *open now*, e o nome pedido só aparece onde a definição
   está grudada nele. Nome que não carrega a definição não é usado.
4. **A frase anti-ranking é bloco acima dos números, e não colapsa** — em toda equipe e em todo
   tamanho. Além das palavras, quatro recursos: nenhuma coluna ordena e nenhuma se oferece para
   ordenar; nenhuma média ou taxa por pessoa em lugar nenhum; e **cada linha carrega o próprio
   denominador**, que é o que impede a coluna de virar escada.
5. **O controle de granulação aparece uma vez**, no cabeçalho da seção — **divergência
   deliberada** do Dashboard, onde ele mora no cabeçalho de cada gráfico (decisão de 8 Sep). Dois
   gráficos de duas pessoas não podem ficar em janelas diferentes (FR-079), e um controle
   repetido oito vezes afirma oito controles independentes. Cada gráfico continua nomeando a
   janela no título.
6. **Duas pessoas abertas, não três — e a segunda muda o layout.** Uma é duas por duas sob a
   própria linha. Duas **saem da tabela** e viram quatro linhas de duas colunas, para que os
   gráficos comparados fiquem lado a lado em vez de 1 400 px um do outro. Cada um mantém a
   própria escala e a linha diz que os eixos diferem.
7. **Três ausências, três tratamentos** — e uma quarta que a spec não previa: *nothing to
   forecast*, para quem não tem item aberto. O piso não é a razão ali, e usar as palavras do piso
   seria outra mentira.
8. **Gráfico vazio é desenhado, nunca em branco**: eixos, escala e a frase na área de plotagem.
   Retângulo em branco é indistinguível de gráfico que não renderizou, e esta tela tem equipes
   inteiras com gráfico vazio.
9. **A coluna de previsão tem fundo hachurado leve**, para que 27 recusas em 31 linhas se leiam
   como **uma região medida** e não como 27 buracos.
10. **A tela relata a observação, nunca a conclusão.** A faixa do SQUAD PINK diz "nada abriu nem
    fechou em oito semanas" e lista as leituras que produzem aquela tabela — quadro parado,
    dependência travada, cinco pessoas trabalhando em outro lugar — sem escolher uma.

## O que este desenho contesta na proposta do Product Owner

| # | Proposta | O que o desenho encontrou |
|---|---|---|
| 1 | **três pessoas abertas ao mesmo tempo** (FR-087, "proposto, não medido") | **duas.** Três gráficos lado a lado nesta coluna dão ~19 rem cada, abaixo do que uma série de oito pontos com rótulos de eixo carrega, e três escalas simultâneas não são comparação. E dois blocos abertos *no lugar*, com seis linhas entre eles, põem 1 400 px entre as duas coisas comparadas: por isso a segunda pessoa não é um segundo bloco, é um **modo** |
| 2 | quatro gráficos por pessoa | **throughput e *delivered* são os mesmos números.** O gráfico 3 desenha as barras do gráfico 2 outra vez, lidas como ritmo em vez de contra o que abriu. Os dois foram pedidos pelo nome; o desenho mantém os quatro e **escreve a redundância na tela** — derrubar um gráfico pedido nominalmente não é decisão do papel. Pergunta aberta 19 |
| 3 | *open now* como coluna da tabela | ela é a coluna que mais se parece com ranking **e é a mais enganosa**: na equipe real, o número grande é trabalho parado. Por isso a frase *"a high number here is work that has not moved"* está no bloco anti-ranking, e não em rodapé |
| 4 | a aba responde "quem precisa de olhar" | isso é *Problems now*, e com limiares declarados. Reenquadrada: a aba responde **distribuição e história**. Sem esse reenquadramento a aba duplica uma seção que já existe |

## As sete perguntas, respondidas em 2026-09-10

Todas as sete foram respondidas **pela recomendação do desenho**. E três delas mudaram de
terreno antes de serem respondidas, porque a camada de medida passou a existir e o que era
argumento virou número.

| # | pergunta | resposta | o que a medição acrescentou |
|---|---|---|---|
| **18** | quantas pessoas abrem ao mesmo tempo | **(b) duas**, com o layout emparelhado | **o argumento de custo caiu.** A aba inteira custa **5 consultas para 31 membros** — 3 da série por pessoa e 2 das tarefas abertas —, e abrir 1, 2 ou 3 pessoas custa **zero consulta extra**: os quatro gráficos e a mistura de conceitos saem de consultas que a tabela já faz. Sobrou só a legibilidade, e ela decidiu: três gráficos a ~19 rem cada não carregam uma série de oito pontos com rótulo de eixo |
| **19** | throughput redesenha as barras de *delivered* | **(a) quatro gráficos, e a tela diz que são os mesmos números** | — |
| **20** | as duas leituras precisam de nome na base | **(a) declarar as duas como leituras** das medidas já declaradas | escrito em `priv/knowledge_base/measurements/flow_per_person_readings.yaml`, id `flow.per_person.readings`. O validador **recusou** a primeira versão: eu inventei um campo `reads`, que o schema não declara — a relação passou para a fórmula e a proveniência, e mudar o schema é decisão maior do que esta pergunta pedia |
| **21** | o cabeçalho conta como *"ao lado"* da palavra `promised` | **(a) no topo**, e a palavra nunca aparece na tabela | — |
| **22** | cobertura sem denominador | **(a) o número, com *denominator unknown*** | **o numerador EXISTE.** `repositories_of_person/2` devolve de **0 a 6** repos por pessoa nas 31 da ConectaFapes, soma 51, e **4 pessoas com zero** — que é um fato útil e estava sendo inventado. O denominador continua não existindo, e é a lacuna real |
| **23** | a pessoa vê a própria linha sem alcançar a equipe | **não** — o veredito da equipe decide tudo | `pode_ver_equipe/3` **não** ganha um quinto caminho. O fluxo da própria pessoa continua em `/people/:id`, que ela alcança por ser ela |
| **24** | onde os quatro gráficos moram no longo prazo | **(a) agora, (b) depois** | e nunca (c): dois lugares com os mesmos quatro gráficos, mantidos em sincronia à mão, é deriva por construção |

## Q25 — a terceira pessoa: respondida em 2026-09-10

A pergunta nasceu da transcrição dos requisitos, e não da tela: **o teto é duas, e o
protótipo aprovado não desenhou o que acontece ao escolher a terceira.**

**Resposta da pessoa mantenedora: nem recusar, nem escolher por ela — a tela PERGUNTA qual
das duas abertas fechar.**

E a razão de cada alternativa ter caído:

| alternativa | por que não |
|---|---|
| **recusar** a terceira | transformaria o teto numa parede sem caminho. Quem quer comparar A com C teria de descobrir sozinho que precisa fechar B primeiro — e a recusa que não oferece o ato certo é exatamente o que esta casa recusa em toda parte |
| **fechar a mais antiga**, sozinha | decide por quem está comparando, e decide em silêncio. A pessoa escolheu a terceira **deliberadamente**; qual das duas primeiras deixa de interessar é informação que só ela tem |
| **perguntar qual fechar** | mantém o teto de duas **e** deixa a escolha com quem compara. Custa um estado a mais na tela e uma interação a mais — e é o preço de não decidir pela pessoa |

**O que isto acrescenta ao desenho**, e volta ao protótipo antes de voltar ao código:

- um **estado novo**: duas pessoas abertas, a terceira pedida, e a pergunta de qual fechar
  — com as duas abertas **nomeadas**, porque *"feche uma"* sem dizer quais são não é
  pergunta;
- o que acontece ao **desistir**: a terceira **não** abre, e as duas continuam como
  estavam. Desistir tem de ser um caminho de volta, e não um estado terceiro;
- e a razão do teto continua **escrita na tela**, como já estava: dois eixos diferentes
  comparam formas e não alturas, e três escalas seriam galeria e não comparação.

## As perguntas que ficam para a pessoa mantenedora

Estão na tela, itens 18 a 24, cada uma com opções e recomendação. Em resumo:

| # | Pergunta | Recomendação |
|---|---|---|
| 18 | quantas pessoas abertas ao mesmo tempo | **duas**, com o layout pareado — contra as três da FR-087 |
| 19 | throughput e *delivered* são os mesmos números — quatro gráficos ou três? | **quatro**, com a redundância escrita, na primeira versão |
| 20 | as duas derivações que a tabela introduz precisam de nome na base antes do código | **declarar as duas** como leituras das medidas existentes |
| 21 | a leitura da FR-063 ("ao lado") | **(a)**, e a tela nem usa a palavra na tabela |
| 22 | cobertura sem denominador (FR-111) | **mostrar a contagem dizendo que o denominador é desconhecido** |
| 23 | a pessoa vê a própria linha quando não alcança a equipe | herdada da spec; é decisão de acesso, não de tela |
| 24 | de quem são os quatro gráficos no longo prazo — desta aba ou de `/people/:id`? | **assim agora, migrar depois** — e nunca os dois ao mesmo tempo |

## Os nomes que a base de conhecimento precisa antes do código

Além dos três que a spec já lista — declarar o nível `person` em `flow.open_work.cumulative` e
em `flow.completion_forecast`, e declarar a substituição em `flow.wip.count` —, **este desenho
introduz duas derivações** que não existem declaradas (princípio IV):

1. **a variação da série entre a primeira e a última amostra da janela** — a coluna *and the
   change across the window*, leitura de `flow.open_work.cumulative` / da série de WIP;
2. **períodos com pelo menos um fechamento** — a coluna *weeks with a close*, leitura de
   `flow.throughput.rate`.

E uma terceira, qualitativa, que a FR-111 já marca como `[NEEDS CLARIFICATION]`:

3. **cobertura de repositórios por pessoa sem denominador** — a forma de dizer "N observados, e
   quantos existem não se sabe" precisa de declaração antes de virar texto de tela.

Se qualquer uma das três for recusada, a coluna correspondente sai da tabela — e a tabela passa
a mostrar um estoque sem direção e um total sem regularidade, o que contraria a FR-089.

## O que foi VERIFICADO em 2026-09-10, e deixou de ser invenção

A seção seguinte é de 2026-09-08 e **continua valendo no que não foi medido**. Quatro dos seus
itens caíram, medidos contra o banco de desenvolvimento com a camada
`TheBand.Teams.FlowPerPerson`:

| a seção dizia | medido em 2026-09-10 |
|---|---|
| *"No closing was measured"* | **falso.** Há **4 fechamentos** na janela de 56 dias da ConectaFapes, em **3 das 31** pessoas. `weeks with a close` é medível e não-zero para três delas |
| *"No repository-coverage number exists for any person"* | **falso** quanto ao numerador: **0 a 6** repos por pessoa, soma 51, **4 com zero**. O **denominador** é que não existe — e é a lacuna que a coluna nomeia |
| *"The query ceiling was not measured"* | **medido.** **5 consultas para 31 membros**, e abrir pessoas custa **zero extra**. O teto deixou de ser argumento |
| *"Nothing was measured for LEDS - ConectaFapes"* | **medido.** 31 membros, 26 itens abertos, 4 criadas e 4 fechadas na janela, **21 pessoas sem item nenhum**, e a mistura real de conceitos: **15 TASK · 9 US · 2 EPIC · 0 BUG** |

**O que continua não verificado**: a inferência dos zeros da SQUAD PINK, a divisão dos abertos
restantes entre pessoas, e o caso da equipe composta — que segue **descrito e não desenhado**.

## O que **não** foi verificado

Está escrito na própria tela, na seção *What was not verified*, e repetido aqui:

- **nenhum fechamento foi medido.** Todo número de *opened*, *closed*, *weeks with a close* e
  previsão das três faixas é inventado;
- **os zeros do SQUAD PINK são inferência, não leitura**: o item aberto mais novo tem 217 dias,
  logo nada aberto dentro da janela continua aberto — mas um item aberto **e** fechado dentro da
  janela não aparece nessa amostra, e ninguém contou esses;
- **o rateio dos abertos restantes** — 52 entre duas pessoas em PINK, 69 entre quatro na Equipe
  IA — é inventado para que as linhas somem o total real da subequipe;
- **não existe número de cobertura de repositórios** para nenhuma pessoa;
- **nada foi medido para LEDS - ConectaFapes**: a faixa de 31 linhas é teste de densidade com
  gente inventada, e o tamanho da equipe é a única coisa real nela;
- **o teto de consultas não foi medido** (SC-031): que duas pessoas abertas caibam no limite por
  render é argumento aqui, não medição;
- **o caso da equipe composta é descrito, não desenhado**: numa equipe composta a aba continua
  com uma linha por pessoa — a aba é por pessoa, não por vínculo —, com os chips de subequipe na
  célula da pessoa e ainda sem total algum.
