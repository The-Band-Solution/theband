# Feature Specification: a timeline da issue, e a primeira atividade executada

**Feature**: `022-timeline-das-issues` · **Criada em**: 2026-08-14
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#179](https://github.com/The-Band-Solution/theband/issues/179), levantada ao fechar o
sprint 005. Os comentários saíram para a [#318](https://github.com/The-Band-Solution/theband/issues/318).

## O pedido

> "Coletar a timeline das issues."

---

## O que a medida achou

**Medido em 2026-08-14**, depois da coleta das três organizações:

| O que a plataforma tem | O que ela não tem |
|---|---|
| `external_created_at` — quando a issue nasceu | quando alguém **começou** |
| `external_closed_at` — quando fechou | quem fez o quê, e quando |
| `comment_count` — quantos comentários | quem comentou |
| 4286 designações vigentes | desde quando cada uma vale |

```
5032 issues · 3390 fechadas · 1642 abertas · lead time mediano 1,2 dia
```

**Só há dois instantes por issue, e nada entre eles.**

### O que isso impede, e não é pouco

| O que não dá para responder | Por quê |
|---|---|
| **cycle time** | falta o instante em que o trabalho começou |
| **WIP verdadeiro** | "aberta e designada" não é "em progresso": as 1642 abertas incluem quem foi designado meses atrás e nunca começou |
| **CFD** | precisa dos estados intermediários |
| quem facilita sem executar | é o sinal da [#317](https://github.com/The-Band-Solution/theband/issues/317), e ele está na timeline |

### O conceito que esta feature ataca

`spo.performed_project_activity`:

> *"Atividade efetivamente executada... É o **kind das ocorrências de atividade em toda a rede**:
> commits, execuções de teste, cerimônias, implantações e inspeções são todos especializações
> deste conceito, e compartilham o mesmo princípio de identidade."*

Um item de timeline **é** uma atividade executada: alguém designou, alguém fechou, alguém
reabriu — cada um com autor e instante.

E o critério de identidade do conceito pede exatamente o que a timeline fornece:

```
tenant_id · organization_id · project_id · activity_type · performer_id · occurred_at · source_external_id
```

Com duas notas que a própria ontologia escreveu, e que esta feature usa:

- **`performer_id` é anulável** — atividade automatizada não tem executor humano, e a timeline
  do GitHub tem eventos de bot;
- **`source_external_id` preserva a identidade da origem**, o que impede que duas coletas do
  mesmo evento gerem ocorrências distintas.

### E o achado que muda o peso da feature

**Nada materializa `spo.performed_project_activity` hoje.** Procurado no banco em 2026-08-14:
não existe tabela de atividade.

Esta feature seria a **primeira**, e a forma que ela der será herdada por commits, execuções de
teste, cerimônias e implantações — porque o conceito é o *kind* de todas elas, e a ontologia diz
que elas *"compartilham o mesmo princípio de identidade"*.

Isso é oportunidade e é risco: modelar a tabela em torno da timeline do GitHub obrigaria a
retrabalhar quando o primeiro commit chegar.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O que aconteceu com esta issue, e quando (Priority: P1)

Quem abre uma issue vê a sequência do que aconteceu: quem designou, quem reabriu, quem fechou —
com autor e instante.

**Por que é P1**: é o que a coleta passa a saber, e o que torna as outras histórias possíveis.
Sem o registro, não há o que derivar.

**Independent Test**: coletar uma issue com três eventos e conferir que a página dela mostra os
três, em ordem, com autor e data.

**Cenários de aceitação**

1. **Dado** uma issue designada e depois fechada, **quando** alguém a consulta, **então** os
   dois eventos aparecem em ordem, com quem os fez.
2. **Dado** um evento cujo autor é um bot, **quando** ele aparece, **então** a tela diz que não
   houve executor humano — e não omite o evento.
3. **Dado** duas coletas seguidas, **quando** a segunda roda, **então** nenhum evento é
   duplicado.
4. **Dado** um evento que a plataforma não sabe classificar, **quando** ele chega, **então** ele
   é registrado como tipo desconhecido, **nomeando o tipo da origem** — nunca descartado em
   silêncio.

---

### User Story 2 - A plataforma diz o que ela não sabe derivar (Priority: P1)

Quem procura cycle time descobre que ele **depende de uma decisão que ninguém tomou** — e a tela
diz qual é.

**Por que é P1, e por que ela existe**: a timeline traz `assigned`, `labeled`, `closed`,
`reopened`. **Nenhum deles significa "começou"** — e qual deles marca o início é decisão de cada
organização. Uma plataforma que escolhesse sozinha produziria um cycle time plausível e errado,
e ninguém perceberia.

**Independent Test**: com a timeline coletada e nenhuma regra declarada, a tela mostra os
eventos e diz que o cycle time não pode ser calculado, nomeando o que falta.

**Cenários de aceitação**

1. **Dado** eventos coletados e nenhuma regra de início declarada, **quando** alguém procura
   cycle time, **então** a plataforma diz que **não sabe** qual evento marca o começo.
2. **Dado** o mesmo estado, **quando** a tela lista os tipos de evento observados, **então** ela
   mostra quais existem e com que frequência — que é o que permite alguém decidir.
3. **Dado** que a plataforma não sabe, **quando** alguém pede a medida, **então** ela **não**
   devolve o lead time no lugar: são medidas diferentes, e trocá-las silenciosamente é pior que
   não responder.

---

### User Story 3 - A coleta da timeline não encarece a coleta inteira (Priority: P2)

A timeline é coletada sem multiplicar o consumo da origem por issue.

**Por que é P2**: é a razão pela qual a issue foi adiada em 2026-08-11, e o custo mudou desde
então — a feature 020 fez a coleta pular 106 de 121 repositórios.

**Independent Test**: uma segunda coleta sem atividade na origem não pede timeline de issue
alguma.

**Cenários de aceitação**

1. **Dado** um repositório sem push desde a última revisão, **quando** a coleta roda, **então**
   ela não pede a timeline das issues dele.
2. **Dado** uma issue cuja `updatedAt` não mudou, **quando** a coleta roda, **então** a timeline
   dela não é pedida de novo.
3. **Dado** o orçamento da origem, **quando** a coleta o esgota, **então** ela pausa e retoma —
   como já faz, e sem perder o que trouxe.

---

### Edge Cases

- **Evento sem autor.** Bot, automação, ou ação do próprio GitHub. O conceito prevê
  `performer_id` anulável, e a ausência tem representação canônica no hash.
- **Evento de tipo novo.** O GitHub acrescenta tipos de timeline; a plataforma não pode
  descartar o que não conhece.
- **A mesma issue coletada duas vezes.** `source_external_id` no critério de identidade impede
  a duplicata — e o teste precisa afirmar isso.
- **Issue com muitos eventos.** A issue original citava 48 itens numa issue; medir a
  distribuição real é tarefa do plano.
- **Evento anterior à primeira coleta.** A timeline traz o histórico inteiro, inclusive de antes
  de a plataforma existir. É dado legítimo, e a data é da origem.
- **Issue transferida entre repositórios.** A timeline registra, e o vínculo com repositório
  muda.

---

## Requirements *(mandatory)*

### Registrar a ocorrência

- **FR-001**: Cada item de timeline coletado MUST ser registrado como atividade executada, com
  tipo, instante e — quando houver — executor.
- **FR-002**: A identidade MUST seguir o critério declarado em `spo.performed_project_activity`,
  incluindo `source_external_id`.
- **FR-003**: Coletar duas vezes MUST NOT duplicar ocorrência.
- **FR-004**: Evento sem executor humano MUST ser registrado com executor ausente, e MUST NOT
  ser descartado.
- **FR-005**: Evento de tipo que a plataforma não classifica MUST ser registrado **nomeando o
  tipo da origem**, e MUST NOT ser descartado em silêncio.
- **FR-006**: A ocorrência MUST guardar a proveniência — origem, instância e identificador
  externo.

### O que a plataforma recusa derivar

- **FR-007**: A plataforma MUST NOT escolher sozinha qual evento marca o início de um trabalho.
- **FR-008**: Quando não há regra de início declarada, a plataforma MUST dizer que não sabe
  calcular cycle time, e MUST nomear o que falta.
- **FR-009**: A plataforma MUST NOT apresentar lead time onde cycle time foi pedido.
- **FR-010**: A tela MUST mostrar os tipos de evento observados e sua frequência — é o que
  permite a decisão da FR-007.

### O custo

- **FR-011**: A timeline MUST NOT ser pedida para repositório que a coleta pulou.
- **FR-012**: A timeline MUST NOT ser pedida de novo para issue cuja atualização não mudou.
- **FR-013**: A coleta MUST continuar respeitando o orçamento da origem, pausando e retomando.

### A tela

- **FR-014**: A página da issue MUST mostrar os eventos em ordem, com autor e instante.
- **FR-015**: Evento sem autor MUST ser exibido dizendo que não houve executor humano.

---

## Success Criteria *(mandatory)*

- **SC-001**: Uma issue com designação e fechamento mostra **dois** eventos em ordem, com autor
  e data.
- **SC-002**: Duas coletas seguidas produzem o **mesmo** número de ocorrências.
- **SC-003**: Nenhum evento recebido é descartado: a soma dos classificados e dos desconhecidos
  é igual ao total que a origem devolveu.
- **SC-004**: Com a timeline coletada e nenhuma regra de início declarada, a plataforma **não**
  exibe cycle time — e diz qual decisão falta.
- **SC-005**: Uma segunda coleta sem atividade na origem faz **zero** pedidos de timeline.
- **SC-006**: A tela lista os tipos de evento observados com a contagem de cada um.

---

## Assumptions

- **A timeline é coletável junto da issue**, na mesma consulta. Confirmar é do plano; se exigir
  consulta separada por issue, o custo muda e a FR-012 vira essencial.
- **Nem todo tipo de evento tem conceito na rede.** `labeled`, `mentioned`, `cross-referenced`
  não têm — e a FR-005 é a decisão de registrá-los como desconhecidos em vez de descartar.
- **O tipo de evento é dado da origem**, e não classificação da plataforma. Traduzi-lo para um
  vocabulário próprio esconderia o que a origem disse.
- A distribuição real de eventos por issue **não foi medida** — a plataforma não coleta timeline
  hoje. A issue original citava 48 numa issue; medir é tarefa do plano.

## Fora do escopo

- **Os comentários** — [#318](https://github.com/The-Band-Solution/theband/issues/318), e a
  direção registrada é o conceito de **colaboração**, não `spo.information_item`.
- **Declarar qual evento marca o início.** A FR-007 recusa escolher; **declarar** é feature
  própria, e ela se parece com as regras de mapeamento que já existem.
- **Calcular cycle time, WIP ou CFD.** Esta feature entrega o dado; as medidas vêm depois da
  declaração acima.
- **Commits, execuções de teste e implantações.** São irmãs desta no mesmo conceito, e cada uma
  tem origem própria.
