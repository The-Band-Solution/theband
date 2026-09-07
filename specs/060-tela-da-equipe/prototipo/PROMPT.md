# O prompt do design aprovado

Registro fiel do que produziu o protótipo `team-dashboard-structure.html`, publicado em
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941` e aprovado pela pessoa
mantenedora em 2026-09-07. **A implementação reproduz exatamente esta tela** — seções, ordem,
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

## 3. A estrutura aprovada, seção por seção

**Aba Dashboard** — cabeçalho com marcas e composição; *Squads at a glance* (um cartão por squad
+ membros diretos, cada cartão é a porta para a página do squad); *Problems now* (issues abertas
> 30 d, revisões esperando > 7 d, pipeline falhando na branch padrão, tarefas paradas além do
limiar, pessoas sem tarefa, membros sem papel, trabalho fora de projeto, anomalias de estrutura —
verde = conferido e nada achado); *Time to first review* (código · em curso · cerimônia, e a
tabela por squad); *Pipeline success rate*; *Flow* (seletor semana · mês · ano; burn-up/down com
região hachurada; aberto × done por período; Monte Carlo semanal com P50/P85 e duas hipóteses);
*People — direct and through the squads* (por squad: papel, todas as tarefas abertas com idade e
parada, perfil demonstrado, flags); *Projects this team is working on* (só vínculos declarados) +
alerta *working outside any declared project*; *Who worked on the project, and when*; *Structure
warnings*.

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
