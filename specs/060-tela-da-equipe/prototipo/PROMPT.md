# O prompt do design aprovado

Registro fiel do que produziu o protótipo `team-dashboard-structure.html`, publicado em
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941` e aprovado pela pessoa
mantenedora em 2026-09-07, **republicado no mesmo endereço em 2026-09-08** com as marcas de
conceito (seção 1.b abaixo). **A implementação reproduz exatamente esta tela** — seções, ordem,
textos, marcas, ações e recusas. Mudança no protótipo é mudança de spec, e passa por aqui.

## 1. Os pedidos da pessoa mantenedora, textuais e em ordem

1. "Vamos projetar a tela de equipes. Uma equipe tem um dashboard com as métricas, uma tela de
   estrutura contendo a lista de subequipes, seus membros e permitindo deletar um membro (quando
   cadastrou errado), informar que um membro não faz mais parte (informando a data de saída), o
   papel de cada membro e as subequipes que faz parte dela. Me mostre o protótipo antes de
   começar a prototipar."
2. "Na tela de estruturação da equipe, permita criar os roles."
3. "Adicione também na tela principal da equipe gráfico de burn up e burn down por semana, mês e
   ano, Prometido vs Entregado e Monte Carlo."
4. "E também adicione em quais projetos estão trabalhando."
5. "Prometido: vem de Aberto. E realizado de Done."
6. "Projetos no dashboard: só os vínculos declarados equipe → projeto. Quadros que as pessoas
   tocaram sem vínculo declarado não aparecem como projeto da equipe. Neste caso falamos que
   estão fazendo algo sem quadro, aí colocamos um alerta."
7. "Se a equipe é composta, pode mostrar o resumo dos dados de todas as subequipes, e ao clicar
   nela ou no gráfico vemos os detalhes delas."
8. "No dashboard faltou colocar o perfil de cada membro direto e indireto na equipe complexa, as
   tarefas que estão executando agora, e problemas, como issues abertas. O dashboard precisa dar
   uma visão geral da equipe para o gestor."

Decisões dadas às perguntas do desenho: abas com a aba na URL; "mistake" também em vínculo
observado, e a coleta não recria; equipe composta pode ter membros diretos.

### 1.b Os pedidos de 2026-09-08, que produziram a republicação

9. "coloque uma cor no símbolo da Task .. tá sem cor"
10. "a diferença e um possível prazo de conclusão baseado na velocidade de entrega"
11. "faça um novo protótipo com as marcas de conceitos e me mostre"

O pedido 9 foi respondido em `marca-do-conceito.md` (a decisão de cor, com as seis classes e os
conflitos nomeados) e trouxe consigo o que este arquivo registra: **a marca do conceito não
estava no protótipo aprovado** — entrou na implementação depois da aprovação, e pela regra da
casa pedia protótipo republicado. O pedido 11 é essa republicação.

## 2. O brief de design que o agente seguiu

- **Design system existente, não inventado**: os tokens do protótipo aprovado da 057
  (`specs/057-tela-da-equipe-complexa/prototipo/team-of-teams.html`) e do
  `assets/css/app.css` — papel `#f7f8f7`, tinta `#101614`, **verdete** `#1f6f68` (claro) /
  `#5cbcb2` (escuro) como primária, `info` azul para o declarado, `amber` para o derivado e para
  aviso, `clay` para equívoco e gravidade. Corpo em serif, títulos em grotesk, números e rótulos
  em mono com `tabular-nums`. Cores de subequipe `s1`/`s2`/`s3`. Dois temas por tokens.
- **Marcas** herdadas da 057: `declared` (azul, cheio), `observed` (verdete, cheio), `derived`
  (âmbar, hachurado), `absent` (tracejado); novas nesta tela: `left` (cinza cheio), `mistake`
  (clay hachurado).
- **Regras da casa que a tela obedece**: uma linha por subequipe e **nenhum total** (057 FR-008/
  FR-009); ausência escrita, nunca zero (057 FR-012, FR-021); nenhuma tarefa eleita como
  "atual" (057 FR-018); marca de parada no limiar declarado (057 FR-020); perfil abaixo do piso
  diz "sem perfil ainda" (057 FR-023/FR-024); as duas afirmações lado a lado quando coleta e
  declaração discordam (055 FR-012); recusa como estado de primeira classe ("sem projeto
  declarado — sem taxa"); toda medida com a composição sobre a qual foi calculada — "X observados
  sem papel declarado, Y declarados" (ADR 0008, 058 FR-026); nada é apagado — saída tem data e
  autor, equívoco tem razão e autor.
- **Dados**: contagens e medidas reais da coleta de 2026-09-06 da organização
  `leds-conectafapes` (8 times, 3/7/19/4/7/6/8/5 membros; 140 solicitações, mediana 0,6 h de
  código e 0,1 h de cerimônia, 38 dias de espera em curso, 85,3% sobre 1 657 no pipeline, 46
  issues abertas há mais de 30 dias). Nomes de pessoas fictícios, marcados `example`.
- **Texto da interface em inglês**, como todo o produto; copy que diz o que a ação faz e o que
  não faz ("ended, not deleted"; "absence, not zero").

### 2.b O brief da republicação de 2026-09-08

- **A marca do conceito é outra família**, e se separa das marcas de vínculo pela **forma**, não
  pela matiz: sem quadrado, sem cor — a escada do escopo em peso e preenchimento, e uma única
  matiz emprestada, o clay do defeito, porque clay é gravidade nesta casa. Razão completa em
  `marca-do-conceito.md`.
- **Vão fixo de 3.5 rem** para a marca, alinhada à direita: quinze itens de uma pessoa começavam
  em quinze bordas esquerdas diferentes.
- **Dado real da base de desenvolvimento, medido em 2026-09-08**: itens abertos de quem está em
  equipe — 760 TASK, 288 US, 71 BUG, 35 EPIC (1 154); numa equipe real, mostrada como SQUAD PINK
  — 180 TASK, 78 US, 21 BUG, 18 EPIC (297), com duas pessoas de 114 e 77 abertas; o item aberto
  mais novo amostrado tem 217 dias e há itens de 550. O tipo declarado na origem é **nulo em 778
  dos 1 154**, e a promoção classifica todos. **A seção de pessoas mostra a proporção real** —
  31 itens visíveis em 20 TASK, 8 US, 2 BUG, 1 EPIC —, que é o que revela se o peso escolhido
  funciona. Nomes, logins, títulos e o rateio entre as pessoas continuam `example`.
- **O que a implementação ganhou depois da aprovação e o protótipo passa a registrar**: os
  cartões de subequipe com faísca (e a razão de a tabela abaixo não ter gráfico); o seletor
  semana · mês · ano no cabeçalho de **cada** gráfico, com a janela sempre escrita no título;
  *Promised × Delivered* com a definição junto do título; *Delivery forecast* como histograma,
  duas hipóteses no mesmo eixo X, percentis sobre a forma e a coluna hachurada das rodadas que
  nunca zeraram; a linha de base do burn (`aberto_inicial`) e a identidade que ela sustenta.

## 3. A estrutura aprovada, seção por seção

**Aba Dashboard** — cabeçalho com marcas e composição; *Squads at a glance* (um cartão por squad
+ membros diretos, cada cartão é a porta para a página do squad); *Problems now* (issues abertas
> 30 d, revisões esperando > 7 d, pipeline falhando na branch padrão, tarefas paradas além do
limiar, pessoas sem tarefa, membros sem papel, trabalho fora de projeto, anomalias de estrutura —
verde = conferido e nada achado); *Time to first review* (código · em curso · cerimônia, e a
tabela por squad); *Pipeline success rate*; *Flow* (seletor semana · mês · ano **no cabeçalho de
cada gráfico**, com a janela no título; burn-up/down com região hachurada **e a linha de base do
que já estava aberto**; *Promised × Delivered* por período, com a definição junto do título;
*Delivery forecast* semanal — histograma, duas hipóteses no mesmo eixo, percentis sobre a forma e
a coluna hachurada do "never");
*People — direct and through the squads* (por squad: papel, **a mistura de conceitos da pessoa**,
todas as tarefas abertas — cada uma abrindo com **a marca do conceito num vão fixo de 3.5 rem**,
com idade e parada, ordenadas pela idade, da mais velha para a mais nova —, perfil demonstrado,
flags; e, antes dos grupos, **a legenda das seis marcas** com a nota da promoção); *Projects this
team is working on* (só vínculos declarados) + alerta *working outside any declared project*;
*Who worked on the project, and when*; *Structure warnings*.

Detalhando o que mudou em 2026-09-08, e é contra isto que o QA confere:

* **Squads at a glance** — cada cartão ganha a **mistura de conceitos** (`TASK n · US n · BUG n ·
  EPIC n`) abaixo dos três números; o cartão de membros diretos diz "no open item — nothing to
  break down"; a nota explica que a faísca responde à forma e nunca ao valor, e que é por isso
  que a tabela abaixo não tem gráfico.
* **Problems now** — o cartão das paradas passa a ser *work items open beyond the stop threshold*
  e **recusa o total**: uma linha por subequipe ("one row per squad — no total"), com o limiar,
  a idade do mais velho e do mais novo, e a população nomeada. O cartão das issues > 30 d também
  nomeia a sua população, e a nota da seção diz que as duas populações são diferentes e que a
  sobreposição não foi medida.
* **People** — legenda das seis marcas + três notas (matiz pertence à origem e ao estado; a marca
  vem da promoção `github.issue_type_routing`, com 778 de 1 154 sem tipo declarado; o vão de
  3.5 rem e o único caso que pode crescer). Grupo do **SQUAD PINK** com cinco pessoas e os
  números reais da subequipe. Bia Lemos aparece em GREEN e em PINK **com a mesma lista**, e a
  linha diz por quê.
* **Flow** — o seletor de granulação sai do cabeçalho da seção e vai para o **cabeçalho de cada
  gráfico**, ao lado do título que nomeia a janela; a previsão **não tem seletor** e diz que é
  semanal. O **burn** abre na linha de base do que já estava aberto, escreve a identidade
  `open(t) = 834 + opened − closed` e traz a frase da diferença e do ritmo. **Promised ×
  Delivered** (era "Committed × delivered") com a definição junto do título. **Delivery forecast**
  (era "Monte Carlo forecast"): dois histogramas empilhados no mesmo eixo X — *if nothing new
  opened* e *if work keeps arriving as it has*, que é o par declarado em
  `flow.completion.forecast` —, percentis sobre a forma, coluna hachurada do "never" separada por
  um vão, percentil nulo quando as rodadas não concluíram, e um segundo bloco `example` com o
  mesmo cartão quando um ritmo **chega** a zero, para que a forma e as marcas fiquem registradas.
* **Decisions and open questions** — decisões 16 a 22 (8 Sep), três perguntas abertas (23 a 25) e
  a tabela **"Where the screen of 8 Sep drifted from this prototype"**, que é a lista de defeitos
  que o QA levanta contra a implementação.

**Aba Structure** — legenda das marcas; *Squads* (compostas, encerrada em histórico, "Add
squad" com data, "End composition"); *Roles* (catálogo SRO + criados; "New role" com nome e
código; renomear; remover só sem vínculo); *Members* (papel ou "not declared", tipo de vínculo,
desde quando, chips dos squads; ações *Declare role · Left the team… · Mistake…*; saídas e
equívocos riscados com quem/quando; os três formulários inline); *Source and declaration
disagree*; *Where this team sits*.

## 4. Como usar este arquivo

- O **Design** (`.claude/agents/design.md`) parte daqui para qualquer mudança na tela e
  republica no mesmo endereço.
- O **Product Owner** (`.claude/agents/product-owner.md`) cita o endereço e este prompt no item
  do backlog e na spec, e só aceita a entrega da tela conferida contra o protótipo.
- O **QA** confere a tela entregue contra a seção 3, item a item.
