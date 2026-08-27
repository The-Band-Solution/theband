<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# SMPO — Software Management Planning Ontology

> Conceitualização do planejamento macro do projeto: os horizontes que a organização declara para organizar o trabalho — o trimestre à frente —, e a alocação de itens de trabalho a eles. Existe para responder em que horizonte um trabalho foi planejado, pergunta que a execução não responde: o sprint diz quando o trabalho aconteceu, e o horizonte diz para quando ele havia sido pensado.

| | |
|---|---|
| **Id** | `smpo` |
| **Versão** | 0.1.0 |
| **Camada** | Domínio |
| **Rede** | Continuum |
| **Namespace** | `the_band.ontology.continuum.smpo` |
| **Depende de** | [ufo](ufo.md), [eo](eo.md), [spo](spo.md), [sro](sro.md) |
| **Origem** | Issue #514 — a lacuna medida em 2026-08-26, e a decisão da pessoa mantenedora no mesmo dia |

> **Nota.** Extensão do continuum, não parte da tese: a tese cobre execução (SPO/SRO) e integração/entrega contínuas (CIRO/CDRO). O planejamento macro — o horizonte declarado ANTES da execução — é lacuna documentada na #514.
A LACUNA FOI PROCURADA NA LITERATURA ANTES DE SER PREENCHIDA (2026-08-26), como a CMO fez na #318:
- **SPMO — Software Project Management Ontology** (SEON, Ruy et al.) é a camada
  certa: declara cobrir "escopo, tempo e duração, e estimativa de custo de processos
  pretendidos, além do rastreamento entre planejado e executado". Os 17 conceitos
  dela são de estimativa e rastreamento — `Estimated Process`, `Duration Estimated
  Activity`, `Project Plan`, `Work Package`, `Tracked Process` — e **nenhum
  representa período de planejamento ou caixa de tempo**. A lacuna existe também na
  referência.
- **A SEON publicada não contém a SRO.** O Scrum Reference Ontology é trabalho do
  mesmo grupo, fora da rede — e é por isso que ele vive no continuum desta base.
- **SAFe** é o único corpo que nomeia a caixa: o *Program Increment*, "caixa de tempo
  fixa de 8 a 12 semanas", frequentemente alinhada ao trimestre fiscal. Bate com o
  medido — 61 a 92 dias, média 84, que são 12 semanas.

  O nome NÃO foi adotado: importar "Program Increment" importaria o método, e esta
  organização não pratica SAFe. O que foi adotado da literatura é a distinção que ela
  faz — "PI Planning é um evento com formato prescrito; *quarterly planning* é uma
  cadência que as organizações definem para si mesmas". "Definem para si mesmas" é o
  que fundamenta `social_object`.

`smpo.planning_horizon` é, portanto, decisão deste projeto e não termo da literatura. Ele existe como pai para que o trimestre não seja a única forma possível de horizonte macro — e o segundo caso ainda não foi observado nesta base, onde os únicos campos de iteração são `Quarter` (média 84 dias), `Sprint` e `Iteration` (média 13).
Ao contrário do resto do continuum, os verbos aqui não são todos no passado: um horizonte de planejamento é declarado para o futuro, e descrevê-lo no passado apagaria justamente o que o distingue da execução.


## Módulos

- **[Project Planning](#project-planning)** — O horizonte que a organização declara para planejar trabalho, o trimestre como espécie dele, e a alocação de um item de trabalho a um horizonte. A alocação é RELATOR e nunca booleano: "está no Q3?" perde quem alocou e quando, e é justamente isso que permite ver replanejamento.

---

## Project Planning

<a id="project-planning"></a>

O horizonte que a organização declara para planejar trabalho, o trimestre como espécie dele, e a alocação de um item de trabalho a um horizonte. A alocação é RELATOR e nunca booleano: "está no Q3?" perde quem alocou e quando, e é justamente isso que permite ver replanejamento.

*Fonte: Issue #514; a lacuna medida em 2026-08-26*

### Conceitos

#### `smpo.planning_horizon` — Planning Horizon

*Horizonte de Planejamento*

Período que a organização DECLARA para organizar trabalho à frente. É objeto social: existe porque alguém convencionou que aquele intervalo tem nome e serve para planejar — o mesmo intervalo não é horizonte em outra organização, e nenhuma das duas está errada.
NÃO é processo executado. `sro.sprint` é `complex_action`: o trabalho acontece DENTRO dele, e ele termina tendo produzido um entregável. Um horizonte não é executado nem produz coisa alguma — ele diz para quando o trabalho havia sido pensado, e continua existindo mesmo que nada tenha sido feito.

<sub>categoria UFO: `social_object`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `title` | string | sim |
| `starts_on` | date | não |
| `ends_on` | date | não |

Exemplos: *Quarter 3 de 2026*; *H1 2027*

#### `smpo.planning_quarter` — Planning Quarter

*Trimestre de Planejamento*

Horizonte de planejamento de aproximadamente três meses. É o horizonte MACRO desta organização: medido em 2026-08-26, os 27 trimestres coletados vão de 61 a 92 dias, com média de 84 — contra 13 dias de média dos 171 sprints.
A duração não é o critério de identidade, e sim consequência: o que faz um trimestre ser trimestre é a organização tê-lo declarado como horizonte macro, e não o número de dias. Um trimestre encurtado continua sendo o trimestre.

<sub>categoria UFO: `social_object` · especializa `smpo.planning_horizon`</sub>

Exemplos: *Quarter 1*; *Q3/2026*

#### `smpo.planning_allocation` — Planning Allocation

*Alocação de Planejamento*

Vínculo entre um item de trabalho e o horizonte para o qual ele foi planejado, com quem alocou e quando.
É RELATOR, e não booleano: "esta issue está no Q3?" responde sim ou não e perde as perguntas que importam — quando entrou, quem pôs, se saiu de outro horizonte. É essa perda que apaga o replanejamento, que é o fato mais informativo do planejamento macro.
Alocar a um horizonte é independente de executar num sprint: medido em 2026-08-26, **639 issues** estão ao mesmo tempo num trimestre e num sprint. As duas caixas não competem — respondem perguntas diferentes sobre a mesma issue.

<sub>categoria UFO: `relator`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `allocated_at` | datetime | não |
| `removed_at` | datetime | não |

Exemplos: *a issue #412 alocada ao Quarter 3 em 2026-06-30 por quem planeja*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `allocates` | `smpo.planning_allocation` | `spo.artifact` | many → one | materialization |
| `allocates to` | `smpo.planning_allocation` | `smpo.planning_horizon` | many → one | materialization |
| `overlaps` | `sro.sprint` | `smpo.planning_horizon` | many → many | association |

- **`smpo.allocation_mediates_item`** — O relator conecta um item de trabalho — a issue promovida, artefato do processo — ao horizonte. O alvo é `spo.artifact` e não `sro.user_story` porque nem todo item alocado a um trimestre foi promovido a user story: medido na #514, o trimestre recebe issue de qualquer tipo.
- **`smpo.sprint_overlaps_horizon`** — Sobreposição temporal OBSERVADA entre a execução e o horizonte — nunca contenção mereológica, e a diferença foi medida.
Dos 135 sprints que coincidem no tempo com um trimestre do mesmo quadro em 2026-08-26, **104 ficam dentro e 31 atravessam a fronteira** — 23%. Declarar `part_whole` tornaria esses 31 impossíveis de representar, e a plataforma teria de escolher um trimestre para eles, que é escolher pela organização.
A cardinalidade `many`/`many` diz o resto: um sprint pode não coincidir com horizonte algum, e um horizonte pode existir sem sprint nenhum dentro dele.


---

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Em que horizonte de planejamento um item de trabalho foi posto, e quando? | `smpo.planning_allocation`, `smpo.planning_horizon` |
| `CQ02` | Quais itens saíram de um horizonte e entraram em outro — o replanejamento que a pergunta "está no Q3?" apaga? | `smpo.planning_allocation` |
| `CQ03` | Quais sprints coincidiram com um trimestre, e quais atravessaram a fronteira dele? | `smpo.planning_quarter`, `sro.sprint` |
| `CQ04` | Quantos itens foram planejados para um horizonte e nunca entraram em sprint algum? | `smpo.planning_allocation`, `smpo.planning_horizon`, `sro.sprint` |



---

[← Rede de ontologias](README.md)

