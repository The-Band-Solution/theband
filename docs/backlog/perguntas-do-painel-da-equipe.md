# As perguntas do painel da equipe — proposta para aprovação

**Estado**: proposta. **Nada aqui vira tela antes do aceite de quem mantém.**

Escrito em 2026-09-04, a pedido da pessoa mantenedora, para destravar o épico
[#504](https://github.com/The-Band-Solution/theband/issues/504), que declara desde
2026-08-25: *"as perguntas que o painel responde são decisão de quem mantém"*.

## Antes: duas correções de fato

O épico e a spec 058 afirmam que a **feature 042 (critério de início) está
"especificada, 24 issues, sem código"**. Medido em 2026-09-04:

| O que se afirmava | O que a origem diz |
|---|---|
| 042 sem código | `lib/the_band/ontology/seon/spo/schemas/activity_start_criterion.ex`, 103 linhas |
| 24 issues abertas | **zero** abertas — #459 a #482 todas fechadas |
| tarefas por fazer | `specs/042-criterio-de-inicio/tasks.md`: **24 de 24 marcadas** |

**A dependência que bloqueava o painel foi entregue, e o épico não foi revisado.**
É a segunda vez que isso acontece com o mesmo épico: o sprint 029 nasceu
exatamente de descobrir que três dependências dele haviam mudado de estado sem
ninguém conferir. A lição L99 — *conferir issue por issue acha o que planejar não
acha* — vale para o próprio épico, e o intervalo de conferência precisa ser menor
que o intervalo em que as coisas mudam.

Segunda correção: `flow.throughput.rate` e `flow.wip.count` **já declaram o nível
`team`** na base de conhecimento. O que falta não é a medida — é a pergunta que
ela responde, e a tela.

## O que a proposta é, e o que ela não é

Cada pergunta abaixo é uma **necessidade de informação** candidata: pergunta,
quem pergunta, e a **decisão que ela apoia**. O campo da decisão é obrigatório na
base de conhecimento, e por bom motivo — pergunta sem decisão produz painel que
se olha e não se usa.

A proposta de dashboards de 2026-08-24 mediu o custo de errar isto: das 20
combinações medida × nível, **4 se calculavam**. Por isso cada pergunta abaixo diz
com que medida ela seria respondida e se essa medida **se calcula hoje**.

---

## Grupo 1 — o ritmo da equipe (o que o épico pediu)

### P1. Esta equipe está entregando mais, menos, ou o mesmo que costumava?

- **Quem pergunta**: quem gerencia a equipe
- **Decisão apoiada**: replanejar o escopo do próximo ciclo — pedir menos, ou
  investigar o que mudou
- **Medida**: `flow.throughput.rate`, nível `team`, série semanal
- **Calcula hoje?** **Sim** — o critério de início existe desde a feature 042
- **A limitação que a tela precisa dizer**: tarefa sem data de fim registrada é
  **lacuna**, e não zero. Uma equipe que fecha tarefas sem registrar a data
  apareceria parada

### P2. Quanto trabalho esta equipe tem em andamento ao mesmo tempo?

- **Quem pergunta**: quem gerencia a equipe
- **Decisão apoiada**: parar de puxar trabalho novo antes de terminar o aberto
- **Medida**: `flow.wip.count`, nível `team`
- **Calcula hoje?** **Sim**
- **A limitação**: item atribuído a duas pessoas da mesma equipe é **um item só** —
  a contagem por equipe usa `DISTINCT`, e por isso **não** é a soma das contagens
  por pessoa

### P3. O trabalho está concentrado em alguém?

- **Quem pergunta**: quem gerencia a equipe
- **Decisão apoiada**: redistribuir antes de a pessoa virar gargalo — ou descobrir
  que a concentração é a estrutura do trabalho, e não um acidente
- **Medida**: `flow.wip.count`, nível `person`, dentro da equipe
- **Calcula hoje?** **Sim**
- **A limitação**: os níveis `person` e `team` **não somam**, e a tela precisa
  dizer isso onde os dois aparecem — é o mesmo texto que a feature 058 já usa para
  a espera por revisão

---

## Grupo 2 — o que a feature 058 já respondeu

Ficam aqui para o painel ser lido como um conjunto, e não como seções soltas.

| # | Pergunta | Medida | Estado |
|---|---|---|---|
| P4 | Quanto o trabalho desta equipe espera pela primeira revisão humana? | `review.time_to_first_review.duration` | **na tela** |
| P5 | Quem trabalhou neste projeto, e quando? | interseção de três períodos | **na tela** |
| P6 | O pipeline dos repositórios desta equipe está estável? | `ci.pipeline_success_rate.ratio` | **na tela** |

---

## Grupo 3 — perguntas que NÃO proponho, e por quê

Estão aqui porque a ausência delas é decisão, e decisão silenciosa vira lacuna
que alguém preenche adiante sem saber que houve escolha.

| Pergunta | Por que fica de fora |
|---|---|
| *Esta equipe é mais produtiva que aquela?* | comparar equipes por throughput compara o trabalho delas, não a competência — e o denominador (o que é uma tarefa) varia por equipe. A medida existiria; a conclusão que ela sugere seria falsa |
| *Quanto retrabalho esta equipe gera?* | `rework.not_accepted_deliverable_ratio` **não se calcula**: a aceitação nunca é registrada. Pôr a seção com "sem dado" ensina a ignorá-la |
| *Quantas atividades cada pessoa realizou?* | `spo_performed_project_activities` permite contar hoje, e **isso não é throughput**: conta evento ocorrido, não tarefa concluída. O épico proíbe explicitamente emprestar o nome |
| *Quando esta equipe termina o backlog?* | já existe como previsão na tela, com a confiança declarada. Repetir em outro formato convidaria a lê-la como promessa |

---

## O que fazer com esta proposta

1. **Você corta, acrescenta ou aprova** — a lista não é fechada;
2. o que sobreviver vira `information_need` na base de conhecimento, **com a
   decisão apoiada**, antes de qualquer número aparecer na tela (princípio IV);
3. só então a tela; e cada seção nasce com a limitação junto do número.

Enquanto isso não acontece, o épico #504 continua **bloqueado por decisão**, e não
por implementação — o que mudou hoje é que a dependência técnica não é mais o
motivo.
