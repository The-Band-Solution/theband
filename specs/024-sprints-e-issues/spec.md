# Feature Specification: as caixas de tempo, e as issues dentro delas

**Feature**: `024-sprints-e-issues` · **Criada em**: 2026-08-15
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: decisão da pessoa mantenedora — *"após baixar as sprints, associe as issues nelas"*.

## O pedido

> "Sprints são iterations do GitHub. Milestones são marcos de projeto.
> Após baixar as sprints, associe as issues nelas."

---

## O que a sondagem achou, e o que ela mudou

**Medido em 2026-08-15**, contra a API real das três organizações. Duas consultas: uma pelos
campos de iteração, outra pela associação das issues.

### As caixas de tempo existem, e têm história

```
26 quadros · 11 com campo de iteração · 15 campos no total
```

| Quadro | Campo | Duração | Iterações concluídas |
|---|---|---:|---:|
| DevOps | `Sprint` | 14d | **32** |
| Edite | `Sprint` | 14d | 16 |
| Conecta Fapes | `Sprint` | 14d | 8, e 10 em curso |
| The Band | `Iteration` | 7d | 1 |

Sprint 40 no DevOps, Sprint 38 na Conecta Fapes. **Não é configuração abandonada** — são anos de
iterações fechadas, com data de início e duração.

### O nome do campo não diz o que ele é

`Sprint` e `Iteration` nomeiam a mesma coisa: The Band chama de `Iteration` o que a Conecta Fapes
chama de `Sprint`. E `Quarter`, também campo de iteração, **não é sprint** — é caixa de tempo de
outra granularidade.

Escolher pelo nome erra em quem chamou de `Iteration`. Escolher pela duração inventa um limiar —
e o dado desautoriza qualquer limiar: há `Sprint 10` com **3 dias** e `Quarter 1` com **61**,
ambos em campos configurados para 14 e 90.

### `Quarter` carrega trabalho de verdade — e às vezes mais que `Sprint`

| Quadro | Itens | `Sprint` | `Quarter` |
|---|---:|---:|---:|
| DevOps | 677 | **527** | 203 |
| Edite | 20 | 15 | **16** |
| Produtos Internos | 169 | 3 | **15** |

**No Produtos Internos a relação inverte.** Quem organiza o trabalho ali é o trimestre; o campo
`Sprint` tem 3 itens e está praticamente morto.

Uma feature que coletasse só o campo chamado `Sprint` mediria 3 itens naquele quadro e concluiria
que nada acontece — quando 15 estão organizados por trimestre.

### As caixas de tempo se sobrepõem

No DevOps, `527 + 203 = 730`, **maior que os 677 itens do quadro**. A mesma issue está num sprint
**e** num trimestre.

Faz sentido — um sprint mora dentro de um trimestre —, e obriga o modelo: **uma issue pertence a
mais de uma caixa de tempo, de granularidades diferentes**. Uma coluna `sprint_id` na issue
estaria errada no primeiro dia.

### E a medida entrega uma lacuna de graça

**150 dos 677 itens do DevOps não estão em sprint algum.** Trabalho num quadro que usa sprint,
fora de qualquer sprint. É informação sobre o processo, e a plataforma tem de saber dizê-la.

---

## O conceito que esta feature ataca

`sro.sprint`, já declarado na base:

> *"Processo executado específico que ocorre após a Definição do Product Backlog e visa
> desenvolver o produto"* — com `start_date` e `end_date`.

É **caixa de tempo**, e é subtipo de `spo.specific_performed_project_process`.

**Milestone não é sprint**, e a medida confirma: dos 89 valores distintos de `milestone_title`
gravados em 1580 issues, nenhum é período. São `[Dados] Importador e Validador`, `[QA] Backlog de
Bugs` — módulos e frentes, agrupamento por assunto. `[QA] Backlog de Bugs` não termina numa data.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber quais caixas de tempo existem (Priority: P1)

Quem abre o quadro vê as iterações que a origem declara: nome, início, duração, e quantas já
fecharam.

**Por que é P1**: sem elas não há onde associar issue nenhuma, e é a base de tudo que vem depois.

**Independent Test**: coletar uma organização e conferir que os 15 campos de iteração medidos
aparecem, com as durações reais.

**Cenários de aceitação**

1. **Dado** um quadro com campo de iteração, **quando** a coleta roda, **então** cada iteração é
   registrada com nome, data de início e duração **como a origem os declara**.
2. **Dado** um quadro com **dois** campos de iteração, **quando** a coleta roda, **então** os dois
   são registrados — `Quarter` não é descartado por não ser sprint.
3. **Dado** uma iteração cuja duração real difere da configurada — `Sprint 10` com 3 dias num
   campo de 14 —, **quando** ela é registrada, **então** vale a duração **dela**, e não a do campo.
4. **Dado** duas coletas seguidas, **quando** a segunda roda, **então** nenhuma iteração é
   duplicada.
5. **Dado** um quadro sem campo de iteração, **quando** a coleta roda, **então** nada é registrado
   e isso **não** é erro — 15 dos 26 quadros medidos são assim.

---

### User Story 2 - Saber quais issues estão em cada caixa (Priority: P1)

Quem abre uma iteração vê as issues associadas a ela; quem abre uma issue vê em que caixas ela
está.

**Por que é P1**: é o pedido literal, e é o que torna a caixa de tempo útil em vez de decorativa.

**Independent Test**: coletar o quadro DevOps e conferir que 527 itens aparecem no campo `Sprint`
e 203 no `Quarter`.

**Cenários de aceitação**

1. **Dado** uma issue associada a um sprint, **quando** a coleta roda, **então** o vínculo é
   registrado.
2. **Dado** uma issue associada a **um sprint e um trimestre**, **quando** a coleta roda, **então**
   os **dois** vínculos existem — a sobreposição é o caso medido, não a exceção.
3. **Dado** uma issue que saiu de uma iteração, **quando** a coleta seguinte roda, **então** o
   vínculo é **marcado como não mais observado**, e nunca apagado.
4. **Dado** um item do quadro que não é issue — um rascunho do próprio Projects —, **quando** ele
   aparece, **então** ele **não** vira issue inventada.

---

### User Story 3 - Saber o que ficou fora de qualquer caixa (Priority: P2)

Quem abre o quadro vê quantas issues dele não estão em iteração nenhuma.

**Por que é P2**: 150 dos 677 itens do DevOps estão nessa situação, e o número só existe se a
plataforma souber dizê-lo. É a diferença entre "o quadro usa sprint" e "o quadro usa sprint para
tudo".

**Cenários de aceitação**

1. **Dado** um quadro que usa iteração, **quando** alguém o consulta, **então** a contagem de
   issues fora de qualquer caixa aparece.
2. **Dado** um quadro **sem** campo de iteração, **quando** alguém o consulta, **então** a tela diz
   que o quadro não usa caixas de tempo — e **não** que 100% está fora delas. São coisas
   diferentes.

---

### User Story 4 - Declarar qual campo é o sprint (Priority: P2)

Quem conhece o quadro declara qual dos campos de iteração materializa `sro.sprint`.

**Por que é P2, e por que existe**: a plataforma **não pode** decidir sozinha. `Iteration` é
sprint, `Quarter` não é, e os dois são campos de iteração. Escolher pelo nome ou pela duração
produziria uma classificação plausível e errada — no Produtos Internos, a declaração legítima pode
apontar para `Quarter`, e aí o sprint daquele time dura 90 dias, que é a verdade do quadro dele.

**Cenários de aceitação**

1. **Dado** um quadro com dois campos de iteração e nenhuma declaração, **quando** alguém pede o
   sprint, **então** a plataforma diz que **não sabe qual dos dois é**, e lista os candidatos.
2. **Dado** uma declaração, **quando** ela é gravada, **então** ela tem autor e data — decisão tem
   autor.
3. **Dado** um campo de iteração **não** declarado como sprint, **quando** a coleta roda, **então**
   ele continua registrado como caixa de tempo.
4. **Dado** que a declaração muda, **quando** ela é regravada, **então** **nada é recoletado** — a
   caixa de tempo é dado, e a classificação é leitura.

---

### Edge Cases

- **Quadro com dois campos de iteração.** Medido em 4 quadros. Os dois são coletados.
- **Iteração com duração diferente da configurada.** `Sprint 10` de 3 dias, `Quarter 1` de 61.
- **Issue em mais de um quadro.** Ela pode estar em iterações de quadros diferentes ao mesmo tempo.
- **Iteração sem issue alguma.** Existe e é registrada — sprint vazio é informação.
- **Item do quadro que é rascunho**, e não issue. Não vira issue.
- **Iteração em curso.** A Conecta Fapes tem 10; elas não têm fim conhecido ainda, e a data de
  término é derivada do início mais a duração.

---

## Requirements *(mandatory)*

### Coletar a caixa de tempo

- **FR-001**: Cada iteração declarada por um quadro MUST ser registrada com nome, data de início e
  duração, **como a origem os nomeia**.
- **FR-002**: Um quadro com mais de um campo de iteração MUST ter **todos** registrados.
- **FR-003**: A duração registrada MUST ser a **da iteração**, e não a configurada no campo.
- **FR-004**: Coletar duas vezes MUST NOT duplicar iteração.
- **FR-005**: Quadro sem campo de iteração MUST NOT produzir erro nem registro.

### Associar as issues

- **FR-006**: A associação entre issue e caixa de tempo MUST ser muitos-para-muitos.
- **FR-007**: Issue que saiu de uma iteração MUST ter o vínculo **marcado**, e MUST NOT ter o
  registro apagado.
- **FR-008**: Item de quadro que não é issue MUST NOT gerar issue.

### O que ficou fora

- **FR-009**: A plataforma MUST saber dizer quantas issues de um quadro não estão em caixa de
  tempo alguma.
- **FR-010**: "O quadro não usa caixas de tempo" e "todas as issues estão fora delas" MUST ser
  distinguíveis.

### A declaração

- **FR-011**: A plataforma MUST NOT escolher sozinha qual campo de iteração é o sprint.
- **FR-012**: Sem declaração, a plataforma MUST dizer que não sabe e MUST listar os candidatos.
- **FR-013**: A declaração MUST ter autor e data.
- **FR-014**: Mudar a declaração MUST NOT exigir recoleta.

### O custo

- **FR-015**: A coleta de iterações MUST respeitar o orçamento da origem, pausando e retomando.

---

## Success Criteria *(mandatory)*

- **SC-001**: Sobre o quadro DevOps, a plataforma registra as 32 iterações concluídas do campo
  `Sprint` e as do campo `Quarter`.
- **SC-002**: Sobre o mesmo quadro, **527** issues aparecem associadas ao `Sprint` e **203** ao
  `Quarter`.
- **SC-003**: A soma das associações é **maior** que o número de itens do quadro — porque a mesma
  issue está em duas caixas, e achatar isso perderia uma das duas.
- **SC-004**: A plataforma responde que **150** itens do DevOps não estão em sprint algum.
- **SC-005**: Sobre o Produtos Internos, `Quarter` aparece com 15 issues e `Sprint` com 3 — e
  nenhum dos dois é descartado.
- **SC-006**: Duas coletas seguidas produzem o mesmo número de iterações e de vínculos.
- **SC-007**: Num quadro com dois campos e sem declaração, a plataforma **não** afirma qual é o
  sprint, e lista os dois.

---

## Assumptions

- **A iteração é do quadro, e não do repositório.** Um quadro cruza repositórios, e a caixa de
  tempo pertence a ele.
- **A data de término é derivada** de início mais duração: a origem não a fornece, e calculá-la é
  aritmética, não inferência.
- **A associação vem do valor do campo no item do quadro**, e é por isso que ela exige a API do
  Projects v2 — a timeline da issue não a traz.
- **`Quarter` é caixa de tempo legítima**, e não lixo a filtrar. Ele carrega 203 issues no DevOps.

## Fora do escopo

- **Velocity, burndown e burnup de sprint.** Dependem desta base, e cada um tem decisão própria —
  velocity precisa de unidade de tamanho, que a plataforma não coleta.
- **Cerimônias.** `sro.ceremony`, `sro.planning_meeting` e as irmãs são conceitos vizinhos e
  origem diferente; nenhuma vem do Projects v2.
- **Milestone.** É marco de projeto, não caixa de tempo. Já está coletado em `milestone_title`, e
  promovê-lo a conceito é outra feature.
- **Sprint backlog como conceito.** `sro.sprint_backlog` é o conjunto planejado; esta feature
  observa o que **está** na caixa, que é coisa diferente do que foi planejado para ela.
