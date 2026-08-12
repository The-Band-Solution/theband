# Feature Specification: a página da pessoa que não varre tudo

**Feature**: `013-pagina-da-pessoa-mais-rapida` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: pedido da pessoa mantenedora — *"estudo de como otimizar a tela de pessoas para melhorar
a performance"*

## O pedido, e o que a medida fez com ele

> "Faça um estudo de como otimizar a tela de pessoas para melhorar a performance."

**Medido na aplicação em execução, em 2026-08-12**, com o banco de desenvolvimento real — 4 529
issues, 75 pessoas, 44 289 promoções:

| Tela | Tempo | Consultas |
|---|---:|---:|
| `/people` — a lista | **25 ms** | 9 |
| `/people/:id` — o detalhe | **85 ms** | 13 |
| `/work` — a lista de trabalho | **322 ms** | 15 |

**A tela de pessoas não é a mais lenta, e a causa dela é a mesma da que é.** A lista de pessoas
responde em 25 ms; o detalhe em 85 ms; e `/work`, que ninguém mencionou, em **322 ms** — treze vezes
a lista de pessoas.

**Otimizar só a tela pedida deixaria a causa de pé.** Esta spec trata a causa, e a tela da pessoa é
onde ela foi encontrada e é onde a melhoria será verificada.

---

## O que a medida achou

### A consulta que domina, e o que ela faz

A consulta mais cara do detalhe da pessoa leva **60 ms dos 85**. O plano de execução diz por quê:

```text
Seq Scan on issue_promotions   (44 289 linhas)          8,8 ms
  → Sort (3 822 kB em memória)                         33,1 ms
    → Unique  (4 512 linhas)
      → Merge Left Join com 350 issues da pessoa
        → Limit 25
Execution Time: 41,5 ms
```

**Quatro mil e quinhentas linhas são calculadas para decorar vinte e cinco.** A subconsulta que
decide "qual é a promoção vigente de cada issue" é feita **para o tenant inteiro**, sem relação com
a pessoa que está na tela, e depois cruzada com as issues dela.

| | |
|---|---:|
| promoções na tabela | **44 289** |
| promoções **por issue** | **9,8** em média, **13** no máximo |
| issues do tenant | 4 529 |
| issues que a tela mostra por vez | **25** |

**As 9,8 promoções por issue crescem a cada coleta.** A tabela é histórico: cada execução acrescenta
a decisão daquele momento. A varredura de hoje custa 33 ms; ela cresce com o histórico, não com o
que a tela mostra.

### O segundo achado, e ele é de índice

O mesmo plano mostra:

```text
Seq Scan on issue_assignees
  Filter: (no_longer_observed_at IS NULL) AND (person_id = ...)
  Rows Removed by Filter: 3 882
```

**Achar as issues de uma pessoa varre as 4 232 designações.** Existe índice por
`(collected_issue_id, no_longer_observed_at)` — que serve à pergunta "quem é designado desta issue"
—, e **nenhum** por `person_id`, que é a pergunta que a página da pessoa faz.

### O alcance, que é maior que a tela pedida

A mesma subconsulta de promoção vigente é usada em **16 lugares** dentro das consultas de trabalho, e
**24** no código todo. Foi por isso que `/work` mede 322 ms com quatro consultas acima de 40 ms cada,
entre elas a contagem de divergências.

**Toda tela que diz o conceito de uma issue paga a varredura inteira.**

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A página da pessoa abre sem varrer o tenant (Priority: P1)

Quem abre o detalhe de uma pessoa vê os repositórios, as issues designadas e as autorais no tempo de
uma tela que consulta o que ela mostra — e não no tempo de uma que percorre o histórico inteiro de
promoções.

**Por que é P1**: é o pedido, e é onde a causa foi medida.

**Teste independente**: abrir a página de uma pessoa com 350 issues designadas e medir o tempo e o
número de linhas lidas; comparar com a medida de hoje.

**Cenários de aceitação**

1. **Dado** uma pessoa com 350 issues designadas, **quando** a página é aberta, **então** ela
   responde em **menos da metade** do tempo de hoje.
2. **Dado** a mesma página, **quando** o histórico de promoções dobrar, **então** o tempo **não**
   dobra — o custo deixa de crescer com o histórico.
3. **Dado** a página aberta, **quando** o conteúdo é comparado com o de hoje, **então** é **o mesmo**:
   mesmas issues, mesmos conceitos, mesma ordem, mesmos números.
4. **Dado** duas aberturas seguidas, **quando** os tempos são comparados, **então** a diferença entre
   elas é pequena — a melhoria é constante, não sorte de cache.

---

### User Story 2 - Achar as issues de uma pessoa sem ler as designações de todas (Priority: P1)

A pergunta "quais issues são desta pessoa" é respondida indo direto às designações dela.

**Por que é P1**: hoje ela lê 4 232 linhas para devolver 350, e é a segunda metade do custo da
página.

**Teste independente**: o plano de execução da consulta deixa de conter varredura sequencial em
designações.

**Cenários de aceitação**

1. **Dado** a consulta das issues designadas a uma pessoa, **quando** o plano é examinado, **então**
   ele usa acesso por índice, não varredura.
2. **Dado** uma pessoa **sem** issue nenhuma, **quando** a página é aberta, **então** ela responde
   igualmente rápido — e diz que não há, sem inventar zero onde não se sabe.
3. **Dado** o mesmo conteúdo, **quando** comparado com hoje, **então** nada muda no que a tela diz.

---

### User Story 3 - A mesma correção vale para as outras telas (Priority: P2)

A lista de trabalho, o detalhe da issue e a lista do repositório usam a mesma decisão de promoção
vigente, e melhoram junto.

**Por que é P2**: é consequência, não pedido. Mas deixá-la de fora significaria corrigir num lugar o
que existe em dezesseis.

**Teste independente**: `/work` medida antes e depois, sem nenhuma mudança na tela em si.

**Cenários de aceitação**

1. **Dado** a lista de trabalho, **quando** medida depois da mudança, **então** ela responde em
   menos tempo que hoje.
2. **Dado** qualquer tela que exiba conceito de issue, **quando** comparada com hoje, **então** o
   conceito exibido é **idêntico** — a promoção vigente continua sendo a mais recente.
3. **Dado** uma issue com **13** promoções no histórico, **quando** a tela a exibe, **então** o
   conceito é o da **última**, e o histórico continua inteiro no banco.

---

### Edge Cases

- **Issue sem promoção nenhuma**: continua aparecendo, sem conceito — a ausência é dita, nunca
  preenchida com um valor inventado.
- **Duas promoções no mesmo instante**: o desempate precisa ser determinístico, ou a mesma tela
  desenhada duas vezes mostra conceitos diferentes.
- **A coleta rodando enquanto a tela é lida**: a tela mostra o que estava vigente quando leu; nunca
  uma mistura de antes e depois na mesma linha.
- **Pessoa sem designação e sem autoria**: a página abre e diz isso, sem erro e sem zero disfarçado.
- **Tenant recém-criado, com histórico vazio**: nenhuma tela pode depender de haver promoção.
- **Multitenant**: a decisão de vigência de um tenant nunca pode alcançar linhas de outro.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A página da pessoa MUST responder consultando o que ela exibe — o custo NÃO PODE
  crescer com o histórico de promoções do tenant.
- **FR-002**: A consulta que lista as issues designadas a uma pessoa MUST usar acesso por índice,
  sem varredura sequencial das designações.
- **FR-003**: O conceito exibido MUST continuar sendo o da promoção **mais recente** de cada issue.
- **FR-004**: O desempate entre promoções da mesma issue MUST ser determinístico — a mesma tela
  desenhada duas vezes mostra o mesmo conceito.
- **FR-005**: Nenhuma linha de `issue_promotions` MUST ser apagada — o histórico é proveniência.
- **FR-006**: Issue sem promoção MUST continuar aparecendo, e a ausência de conceito MUST ser dita,
  nunca preenchida.
- **FR-007**: Toda consulta envolvida MUST permanecer escopada por tenant.
- **FR-008**: O conteúdo de todas as telas afetadas MUST ser **idêntico** ao de hoje — issues,
  conceitos, contagens, ordem.
- **FR-009**: A medida MUST ser registrada antes e depois, na mesma máquina e com o mesmo dado, e a
  comparação MUST ser por **diferença** e por **constância**.
- **FR-010**: A melhoria MUST ser verificável por teste automatizado que falhe se o custo voltar a
  crescer com o histórico.

### Key Entities

- **Promoção de issue**: a decisão da plataforma sobre o conceito de uma issue, num instante. É
  **histórico** — 9,8 por issue hoje, e cresce a cada coleta.
- **Promoção vigente**: a mais recente de cada issue. É **derivada**, e é a derivação que custa.
- **Designação**: o vínculo entre pessoa e issue, com marca de ausência. É por ela que a página da
  pessoa encontra o trabalho.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: O detalhe da pessoa responde em **menos de 40 ms** — hoje são **85 ms**, medidos cinco
  vezes com variação menor que 10%.
- **SC-002**: A consulta dominante da página deixa de ler **44 289** linhas de promoção; passa a ler,
  no máximo, o número de issues que a página exibe — **25**.
- **SC-003**: O plano de execução das issues de uma pessoa **não contém** varredura sequencial de
  designações, e para de descartar **3 882** linhas por filtro.
- **SC-004**: A lista de trabalho `/work` responde em **menos de 200 ms** — hoje são **322 ms**.
- **SC-005**: Cada tela afetada exibe **exatamente** o mesmo conteúdo de hoje, conferido lado a lado.
- **SC-006**: Com o histórico de promoções **dobrado**, o tempo da página da pessoa varia menos de
  10% — hoje ele cresceria junto.
- **SC-007**: Nenhuma linha de `issue_promotions` some: a contagem depois é **maior ou igual** a
  44 289.

---

## Assumptions

- **A medida vale para este banco de desenvolvimento**, com 4 529 issues e 44 289 promoções. Em
  bancos maiores a diferença aumenta, e é isso que a SC-006 mede.
- Os tempos foram medidos pelo **render HTTP inicial**. O LiveView conectado repete o `mount`, então
  o custo real por visita é aproximadamente o dobro — a **L38** já registrou isso, e a comparação
  antes/depois usa a mesma forma de medir dos dois lados.
- A página da pessoa não muda de aparência nem de conteúdo. **Esta feature não é de interface**: se
  algo na tela mudar, é defeito.
- O histórico de promoções continua crescendo. Reduzi-lo, arquivá-lo ou apagá-lo **não** é escopo, e
  a FR-005 proíbe.
- O ambiente de medição é a máquina de desenvolvimento com o Postgres em contêiner local. Números
  absolutos mudam com a máquina; a **razão** entre antes e depois, não.
