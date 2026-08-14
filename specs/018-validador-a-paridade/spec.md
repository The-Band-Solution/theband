# Feature Specification: o validador Elixir à paridade

**Feature**: `018-validador-a-paridade` · **Criada em**: 2026-08-13
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#177](https://github.com/The-Band-Solution/theband/issues/177), dívida desde o sprint 002

## O pedido

> "O validador Python faz 12 verificações sobre a base de conhecimento; o Elixir faz 4."

## O risco concreto, e ele já tem nome

**A L23**: aviso de verificação pulada é reprovação, não observação. O validador Python **precisa do
`.venv`** — e quando ele falta, a verificação de forma dos YAML não acontece. `mix gates` provisiona
o venv por isso, e o dia em que a provisão falhar, **o gate passa medindo menos**.

Com paridade, a verificação sobrevive à ausência do Python.

---

## O que a medida achou

**Contado em 2026-08-13**, lendo os dois validadores:

| Verificação | Python | Elixir |
|---|:---:|:---:|
| ids em `ontologia.conceito`, minúsculas | ✓ | **parcial** — só duplicidade |
| `parent` e `is_role_of` existem, e a direção | ✓ | ✗ |
| origem e destino de relação existem | ✓ | ✗ |
| papel alcança o tipo rígido que o fundamenta | ✓ | ✗ |
| módulo listado tem arquivo | ✓ | ✗ |
| nenhum ciclo entre ontologias | ✓ | **fora do validador** — vive em `knowledge.graph` |
| pergunta de competência referencia o que existe | ✓ | ✗ |
| medida responde necessidade declarada | ✓ | ✗ |
| mapeamento declara equivalência, justificativa, limitações | ✓ | ✗ |
| vínculo prometido por mapeamento tem lastro | ✓ | ✗ |
| artefato contra o JSON Schema do tipo | ✓ | ✗ |
| proveniência declarada | ✓ | ✓ |
| **segredo em YAML** | ✗ | **✓** |

**A última linha inverte o pedido**: o Elixir tem uma verificação que o Python **não** tem. Paridade
não é "copiar o Python" — é as duas fazerem as treze.

### O que a base tem hoje

```
96 arquivos YAML · 12 ontologias · 220 conceitos · 144 relações · 5 medidas
```

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A verificação sobrevive sem Python (Priority: P1)

Quem roda os gates sem `.venv` recebe o mesmo veredito sobre a base.

**Por que é P1**: é o risco que originou a dívida, e ele já custou uma vez — dez execuções verdes
localmente e reprovação no CI por seis mapeamentos com erro de forma.

**Cenários de aceitação**

1. **Dado** um YAML com erro que só o Python pegava, **quando** `mix knowledge.validate` roda,
   **então** ele reprova.
2. **Dado** a base íntegra, **quando** os dois validadores rodam, **então** os dois aprovam.
3. **Dado** um problema qualquer, **quando** os dois rodam, **então** **os dois** o encontram.

---

### User Story 2 - O problema é dito de forma acionável (Priority: P1)

Quem recebe a reprovação sabe qual arquivo, qual campo e o que fazer.

**Por que é P1**: validador que diz "inválido" obriga quem lê a caçar.

**Cenários de aceitação**

1. **Dado** um problema, **quando** ele é relatado, **então** a mensagem nomeia o **arquivo**.
2. **Dado** uma referência quebrada, **quando** relatada, **então** a mensagem diz **o que** não
   existe.
3. **Dado** vários problemas, **quando** relatados, **então** todos aparecem — não só o primeiro.

---

### User Story 3 - As duas verificações não divergem (Priority: P1)

Um teste compara as duas saídas sobre a mesma base.

**Por que é P1**: duas implementações da mesma regra divergem no dia em que uma muda — é o que
aconteceu com `promocoes_vigentes` e custou a feature 013.

**Cenários de aceitação**

1. **Dado** a base do repositório, **quando** os dois rodam, **então** o conjunto de problemas é o
   mesmo.
2. **Dado** um problema introduzido de propósito, **quando** os dois rodam, **então** os dois o
   acham.

---

### Edge Cases

- **YAML com sintaxe inválida**: os dois reprovam antes de qualquer verificação semântica.
- **Ontologia referenciada e ainda não materializada**: é exigência declarada, não erro — a
  constituição IX exige que a derivação **não** falhe por isso.
- **Base vazia**: aprova, e diz que não achou artefato — nunca aprova em silêncio.
- **Schema JSON ausente para um tipo**: é problema do validador, e precisa ser dito.

---

## Requirements *(mandatory)*

- **FR-001**: O validador Elixir MUST fazer as **treze** verificações.
- **FR-002**: Cada problema MUST nomear o arquivo.
- **FR-003**: Todos os problemas MUST ser relatados, nunca só o primeiro.
- **FR-004**: `mix knowledge.validate` MUST reprovar por código de saída.
- **FR-005**: O validador MUST NOT depender de Python para verificação alguma.
- **FR-006**: A verificação de **segredo em YAML** MUST existir também no Python.
- **FR-007**: Um teste MUST comparar as saídas dos dois sobre a mesma base.
- **FR-008**: Ontologia referenciada e não materializada MUST ser exigência, não erro.
- **FR-009**: Base sem artefato MUST dizer isso.

---

## Success Criteria *(mandatory)*

- **SC-001**: As **treze** verificações existem nos dois.
- **SC-002**: Sobre a base do repositório, os dois aprovam — **96 artefatos**.
- **SC-003**: Um problema introduzido de propósito é achado pelos dois, para cada uma das treze.
- **SC-004**: `mix knowledge.validate` sem `.venv` reprova o mesmo que reprovaria com ele.
- **SC-005**: Nenhuma verificação existente é perdida.

---

## Assumptions

- **A verificação contra JSON Schema exige biblioteca** no Elixir. Escolher uma é decisão do plano,
  com a justificativa que o `AGENTS.md` exige para dependência nova.
- A contagem de "12" da issue vem do Python. **São 13** com a de segredo, que só o Elixir tem — a
  medida corrigiu o pedido.
- O validador Python **continua existindo**: paridade é para a verificação sobreviver à ausência
  dele, não para removê-lo.
