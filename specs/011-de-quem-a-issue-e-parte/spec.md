# Feature Specification: de quem cada issue é parte

**Feature**: `011-de-quem-a-issue-e-parte` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#246](https://github.com/The-Band-Solution/theband/issues/246), product backlog

## Pedido

> "Coloque para cada issue o seu US ou EPIC, se existir."
>
> — pessoa mantenedora, 2026-08-12, sobre a tabela de issues em `/work/repositories/:id`

---

## O que a medida achou, e ela muda o pedido

**Medido em 2026-08-12**, usando a promoção **vigente** de cada issue:

| | |
|---|---:|
| issues vigentes | 4 529 |
| **com pai** | **1 666** |
| sem pai | 2 863 |

E as duplas de conceito — pai e filha —, que é o que decide o desenho:

| pai | filha | quantas | a relação é |
|---|---|---:|---|
| user story | tarefa | **1 136** | atendimento |
| **épico** | **tarefa** | **293** | **violação da `sro.rule07`** |
| épico | user story | 178 | composição |
| épico | defeito | 21 | composição |
| épico | épico | 14 | composição |
| user story | defeito | 7 | — |
| defeito | tarefa | 7 | atendimento |
| user story | user story | 5 | composição |
| defeito | defeito | 5 | — |

**Três coisas saltam, e nenhuma estava no pedido:**

1. **"US ou EPIC" não cobre os casos.** Há **12 issues com pai que é defeito**, e defeito não é
   nenhum dos dois. A coluna diz o **conceito do pai**, não uma de duas palavras.
2. **293 issues têm pai que a plataforma considera errado.** Tarefa direto sob épico **viola
   `sro.rule07`** — a plataforma já sabe disso e já avisa na mesma tela, num painel separado. A
   coluna não pode mostrar esse pai como se fosse relação em ordem.
3. **Ser parte não é uma relação, são duas.** A tarefa **atende** a user story; a user story
   **compõe** o épico. A feature 006 separou as duas e proibiu somá-las, e uma coluna chamada "pai"
   junta o que ela separou.

### E dois números que decidem casos de borda

| | |
|---|---:|
| issues com **mais de um** pai | **36** |
| vínculos cujo pai está em **outro repositório** | **57** |

**A função que já existe erra os 36.** `fetch_parent/2` — usada no detalhe da issue — tem `limit: 1`
**sem ordem**: para as 36 ela devolve um pai arbitrário, e o resultado pode mudar entre execuções. É
a família da L20, e a lista vai herdar o defeito se reusar a função como está.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver de quem a issue é parte, sem abrir a issue (Priority: P1)

Quem varre a lista de um repositório quer saber, em cada linha, de quem aquela issue é parte — sem
abrir uma por uma.

**Por que é P1**: é o pedido literal, e hoje a informação só existe dentro do detalhe de cada issue.

**Teste independente**: numa lista de 29 issues, as que têm pai o mostram na própria linha.

**Cenários de aceitação**

1. **Dado** uma issue com pai, **quando** a lista é exibida, **então** a linha mostra o pai com o
   **número e o título** dele.
2. **Dado** uma issue **sem** pai, **quando** a lista é exibida, **então** a linha diz que ela não é
   parte de nada — nunca uma célula vazia.
3. **Dado** o pai, **quando** alguém clica nele, **então** o detalhe dele abre.
4. **Dado** o telefone, **quando** a lista vira cartões, **então** a informação continua legível.

---

### User Story 2 - Saber qual relação é, e quando ela está errada (Priority: P1)

A linha diz **o conceito do pai** e **qual das duas relações** é — atendimento ou composição. E
quando a dupla viola a regra do processo, a linha diz isso.

**Por que é P1**: 293 das 1 666 têm pai que viola a `sro.rule07`. Mostrar esse pai como relação
normal apagaria um sinal que a plataforma já produz.

**Teste independente**: uma tarefa sob user story e uma tarefa sob épico aparecem com **textos
diferentes** na mesma lista.

**Cenários de aceitação**

1. **Dado** uma tarefa cujo pai é user story, **quando** a linha é exibida, **então** ela diz que a
   tarefa **atende** aquela user story.
2. **Dado** uma user story cujo pai é épico, **quando** a linha é exibida, **então** ela diz que a
   user story **compõe** aquele épico.
3. **Dado** uma tarefa cujo pai é **épico**, **quando** a linha é exibida, **então** ela diz que a
   relação **viola a regra** — e o texto é diferente dos dois anteriores.
4. **Dado** que o pai não foi promovido a conceito nenhum, **quando** a linha é exibida, **então**
   ela diz que o pai existe e **não tem conceito** — sem inventar um.
5. **Dado** que a pessoa não distingue cores, **quando** vê a lista, **então** os casos continuam
   distinguíveis por texto.

---

### User Story 3 - Não ser enganado quando há mais de um pai (Priority: P2)

Trinta e seis issues têm **mais de um** pai. A linha não escolhe um em silêncio.

**Por que é P2**: são 36 de 1 666 — pouco, e é exatamente onde uma escolha silenciosa passa
despercebida. E a função que já existe faz essa escolha hoje, sem ordem definida.

**Teste independente**: uma issue com dois pais mostra que há dois, e a mesma lista desenhada duas
vezes mostra a **mesma** coisa.

**Cenários de aceitação**

1. **Dado** uma issue com dois pais, **quando** a linha é exibida, **então** ela diz que há mais de
   um — nunca mostra um como se fosse o único.
2. **Dado** a mesma lista desenhada duas vezes, **quando** as duas são comparadas, **então** a ordem
   e a escolha são **as mesmas**.
3. **Dado** um pai em **outro** repositório, **quando** a linha é exibida, **então** ela diz de qual
   repositório ele é — o número da issue repete entre repositórios.

---

### Edge Cases

1. **Pai em outro repositório** — 57 vínculos. O número sozinho é ambíguo: `#12` existe em vários.
2. **Pai que deixou de ser observado.** O vínculo tem `no_longer_observed_at`; a linha não pode
   mostrar como atual.
3. **Pai sem conceito** — hoje **zero**, porque toda issue está promovida. Vai existir de novo na
   primeira coleta que traga tipo novo.
4. **Um repositório com 2 514 issues.** A coluna não pode consultar por linha.
5. **Cadeia de três níveis** — épico, user story, tarefa. A linha mostra **o pai**, não o avô.
6. **Épico dentro de épico** — 14 casos. A relação é composição, e o texto precisa funcionar.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A lista de issues do repositório DEVE mostrar, para cada issue com pai, **o número e o
  título** do pai.
- **FR-002**: Issue **sem** pai DEVE ter isso dito em texto — nunca célula vazia.
- **FR-003**: A linha DEVE dizer o **conceito do pai**, e NÃO DEVE reduzi-lo a "user story ou épico":
  há 12 issues com pai que é defeito.
- **FR-004**: A linha DEVE dizer **qual relação** é — **atendimento** ou **composição** —, e as duas
  NÃO DEVEM ser chamadas pelo mesmo nome.
- **FR-005**: Quando a dupla de conceitos **viola a `sro.rule07`**, a linha DEVE dizer isso, com
  texto diferente do de uma relação em ordem.
- **FR-006**: A decisão de qual relação é DEVE usar **o mesmo axioma** que a plataforma já usa —
  nenhuma segunda implementação.
- **FR-007**: Pai sem conceito DEVE ser dito como **sem conceito**, e NÃO DEVE receber um conceito
  inventado.
- **FR-008**: Issue com **mais de um** pai DEVE ter isso dito, e NÃO DEVE aparecer com um pai como se
  fosse o único.
- **FR-009**: A escolha e a ordem DEVEM ser **determinísticas**: a mesma lista desenhada duas vezes
  mostra a mesma coisa.
- **FR-010**: Pai em **outro repositório** DEVE ser identificado com o repositório dele.
- **FR-011**: Vínculo que deixou de ser observado NÃO DEVE aparecer como atual.
- **FR-012**: O pai DEVE ser navegável — clicar abre o detalhe dele.
- **FR-013**: Desenhar a lista NÃO DEVE consultar por linha, nem aumentar o número de consultas que a
  tela faz hoje mais do que **uma**.
- **FR-014**: Cada caso DEVE ser distinguível por **texto**, e não apenas por cor.
- **FR-015**: A informação DEVE ser legível quando a tabela vira cartão no telefone.
- **FR-016**: Nenhuma tela DEVE exibir issue de outro tenant, e a consulta a issue de outro tenant
  DEVE responder **não encontrado**.

### Key Entities

- **Vínculo de decomposição**: já existe, com pai, filha e período. Passa a ser **exibido na lista**,
  com o conceito do pai ao lado.
- **A relação**: **derivada** da dupla de conceitos — atendimento, composição, ou violação. Nada é
  gravado.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: As **1 666** issues com pai mostram o pai na própria linha, sem abrir a issue.
- **SC-002**: As **2 863** sem pai dizem isso em texto, e nenhuma célula fica vazia.
- **SC-003**: Uma tarefa sob user story e uma tarefa sob épico têm textos **diferentes** na mesma
  lista — são 1 136 e 293 no dado real.
- **SC-004**: Nenhuma linha chama de "user story ou épico" um pai que é **defeito** — são 12.
- **SC-005**: As **36** issues com mais de um pai dizem que há mais de um.
- **SC-006**: A mesma lista desenhada duas vezes produz **exatamente** o mesmo resultado.
- **SC-007**: Os **57** vínculos com pai em outro repositório mostram de qual repositório ele é.
- **SC-008**: Desenhar a lista acrescenta **no máximo uma** consulta ao que a tela já faz.
- **SC-009**: Os casos continuam distinguíveis com a cor removida.
- **SC-010**: A informação é legível em 360 px.
- **SC-011**: Um tenant não alcança issue de outro, e a mensagem não confirma existência.

---

## Assumptions

- **A relação é derivada da dupla de conceitos, e o axioma é o que já existe.** `Axioms.rule07/2` já
  decide se tarefa sob épico é violação, e é a mesma função que a tela do repositório usa hoje. Uma
  segunda implementação faria a lista avisar sobre o que o detalhe declara correto.
- **A coluna mostra o pai, não a linhagem.** Cadeia de três níveis existe; mostrar o avô seria outra
  pergunta, e a tela do detalhe já mostra a decomposição completa.
- **Mais de um pai é dito, não resolvido.** A plataforma não escolhe qual vale: são 36 casos, e a
  escolha é do processo do time, não da tela.
- **Nada é gravado.** A relação é lida e derivada na hora, como a classificação épico/atômica.

## Dependencies

- `Axioms.rule07/2` e a promoção **vigente** — a decisão precisa do conceito atual, e usar o
  histórico infla: medir com todas as promoções deu 2 238 para 1 666 issues.
- A gramática da evidência do design system: texto sempre, cor nunca sozinha.

## Out of Scope

| Fora | Por quê |
|---|---|
| mostrar a linhagem completa | é outra pergunta; o detalhe da issue já mostra a decomposição |
| **corrigir** as 293 violações | a plataforma observa e avisa; corrigir é decisão do time na origem |
| escolher qual pai vale, entre os 36 | a plataforma não decide isso pelo time |
| a mesma coluna em `/work` | a lista lá é do tenant inteiro, e a pergunta ali é outra |
| filtrar a lista por pai | não foi pedido |
