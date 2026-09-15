# Feature Specification: A recoleta da timeline truncada

**Feature Branch**: `068-recoleta-da-timeline`

**Created**: 2026-09-15

**Status**: Draft

**Input**: pedido da pessoa mantenedora em 2026-09-15, ao ver que 282 entregas do Conecta Fapes
não tinham data de conclusão: *"temos que coletar esses dados… precisa aparecer no gráfico do
mês"*.

**O conserto já foi feito; isto é o que ficou para trás.** O commit `3b63587` fez a fase de
issues pedir 10 por página e acrescentou a guarda que faltava — vale para as **próximas**
coletas. O dado que já está no banco continua truncado, e o corte não deixou marca.

---

## O defeito, reproduzido

Dentro de `issues(first: 50)`, a origem devolve parte da timeline de cada issue e **declara
`totalCount` igual ao que cortou**, com `hasNextPage: false`. Não há sinal: a guarda que existia
olhava `hasNextPage`, e por isso **nunca disparou**.

Medido na issue `#1828` do `conectafapes-project`, que tem **14** itens:

| quanto se pede por página | a origem declara |
|---|---|
| 50 | **12** |
| 25 | **13** |
| **10** | **14** — completo |

O corte é **proporcional aos nós pedidos**, não um teto fixo.

## O que custou, medido

No quadro 43 do Conecta Fapes, 377 cartões marcados como concluídos com a issue aberta na
origem:

| situação | quantas |
|---|---|
| **têm o evento de conclusão na origem e não no banco** | **282 (75%)** |
| fecharam depois da última coleta | 25 (6%) |
| chegaram a Done sem gerar evento nenhum | 69 (18%) |
| não existem mais na origem | 1 |

As 282 se distribuem por **abril 10 · maio 81 · junho 35 · julho 152 · agosto 4**. Julho sozinho
tem 152 conclusões que nenhum gráfico por mês mostra.

**O alcance é toda a base, porque a coleta é a mesma**: 4 711 issues com evento coletado, de
5 033 issues em 33 repositórios. **475** delas têm entre 10 e 13 eventos — a faixa onde a
distribuição quebra, e a assinatura provável do corte.

> **475 é indício, não diagnóstico.** Uma issue pode ter 11 eventos de verdade. O número exato
> só se sabe perguntando à origem por todas — que é o que esta feature faz.

## Por que não dá para ser incremental

O corte **não deixou marca**: o registro truncado é indistinguível do completo. Não há coluna
que diga "esta issue veio pela metade", e o `totalCount` gravado é o número cortado. Sem
perguntar por todas, não há como saber quais precisam.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recoletar a timeline de um repositório, com prova (Priority: P1)

Quem administra escolhe um repositório e manda recoletar a timeline. A plataforma percorre
**todas** as issues dele, traz a timeline completa, insere o que falta, e ao fim diz: quantas
issues percorreu, quantas ganharam eventos, quantas continuam iguais, e quantos pontos de cota
custou.

**Why this priority**: sem a recoleta, o conserto do `page_size` só serve para o futuro, e as
282 entregas continuam sem data. É a fatia que devolve o dado.

**Independent Test**: recoletar o `conectafapes-project` e conferir que a issue `#1828` passa a
ter o evento `2026-06-11 → Done`, que hoje não existe no banco.

**Acceptance Scenarios**:

1. **Given** um repositório observado, **When** a recoleta termina, **Then** o relatório diz
   issues percorridas, issues com eventos novos, eventos inseridos, e custo em pontos — **todos
   medidos, nenhum estimado**.
2. **Given** uma issue cuja timeline já estava completa, **When** a recoleta passa por ela,
   **Then** nenhum evento é inserido e nenhum é alterado.
3. **Given** a mesma recoleta executada duas vezes seguidas, **When** a segunda termina,
   **Then** ela insere **zero** eventos — e o relatório diz isso, em vez de ficar em silêncio.
4. **Given** a cota da origem esgotada no meio, **When** a recoleta para, **Then** ela diz onde
   parou, quanto percorreu, e pode ser retomada **de onde parou** — nunca do começo.
5. **Given** a recoleta terminada, **When** leio o relatório, **Then** ele diz **quantas issues
   continuam suspeitas** — resposta no teto da página —, porque um número que não chega a zero é
   informação.

---

### User Story 2 - Provar que a recoleta trouxe tudo (Priority: P1)

A recoleta não se declara completa por ter terminado. Para uma **amostra** das issues
percorridas, a plataforma faz uma segunda leitura por outro caminho e compara a contagem. Se
divergir, a recoleta é declarada **incompleta**, com as issues divergentes nomeadas.

**Why this priority**: é o defeito de novo, do outro lado. A origem já mentiu uma vez sobre
quanto entregou, e uma recoleta que confia nela repete o erro — desta vez com a confiança de
quem acabou de consertar.

**Independent Test**: recoletar com a conferência ligada e ver, no relatório, a amostra
conferida e a divergência (zero ou não).

**Acceptance Scenarios**:

1. **Given** a recoleta em curso, **When** ela confere a amostra, **Then** compara o número de
   itens obtidos com uma segunda leitura por outro caminho, e registra os dois números.
2. **Given** qualquer divergência na amostra, **When** a recoleta termina, **Then** o veredito é
   **incompleta**, as issues divergentes são nomeadas, e o relatório diz o que fazer.
3. **Given** amostra sem divergência, **When** a recoleta termina, **Then** o relatório diz
   **quantas** issues foram conferidas de quantas — nunca só "conferido".

---

### User Story 3 - Ver o que mudou, e o que continua faltando (Priority: P2)

Depois da recoleta, quem acompanha vê **o efeito**: quantos eventos novos por repositório e por
mês de ocorrência, e quantas das 282 entregas do quadro 43 passaram a ter data. E vê o que
**continua** sem data: as 69 que chegaram a Done sem gerar evento.

**Why this priority**: é o que responde *"melhorou?"* com número, e o que impede a leitura de que
a recoleta resolveu tudo.

**Independent Test**: comparar a distribuição de conclusões por mês antes e depois, no mesmo
quadro.

**Acceptance Scenarios**:

1. **Given** a recoleta terminada, **When** abro o relatório, **Then** vejo eventos novos por
   repositório e por mês de ocorrência.
2. **Given** o quadro 43, **When** comparo antes e depois, **Then** vejo quantas entregas
   ganharam data — e quantas **continuam sem**, com a razão (a origem não registrou evento).
3. **Given** um repositório sem nada a recuperar, **When** a recoleta passa por ele, **Then** o
   relatório o lista com zero eventos novos — **presença com zero**, nunca ausência da linha.

---

### Edge Cases

- **Issue apagada na origem** entre a coleta e a recoleta: a issue não é encontrada; fica
  registrada como **não recuperável**, e a recoleta segue. Medido: 1 das 377 já está assim.
- **A pessoa do evento não está resolvida** no momento da recoleta: a identidade da atividade
  inclui quem a executou, então gravar sem resolver criaria um **segundo** registro do mesmo
  evento. A recoleta resolve as pessoas **antes**, como a coleta normal faz. Aconteceu ao
  reproduzir o defeito à mão, e custou 11 duplicatas que tiveram de ser apagadas.
- **Dois eventos do mesmo tipo, mesmo ator e mesmo segundo, em issues diferentes**: colapsam
  numa identidade só, porque a issue não faz parte dela. Medido: **40 em 2 606** (1%), nenhum
  com status *Done*. A recoleta **não piora** isso e **não o conserta** — apenas o declara no
  relatório, porque é limite conhecido.
- **A origem volta a truncar** com o novo tamanho de página: a conferência da US2 pega, e a
  recoleta é declarada incompleta em vez de dar por feita.
- **Cota esgotada a meio de um repositório**: para no fim da issue corrente, nunca no meio; o
  ponto de retomada é a issue seguinte.
- **Duas recoletas simultâneas do mesmo repositório**: a segunda é recusada com a razão — não
  corrompe, mas gastaria cota duas vezes pelo mesmo dado.
- **Issue sem timeline nenhuma**: percorrida, zero eventos, contada como percorrida. Não ter
  evento é fato sobre a issue, não falha da recoleta.

## Requirements *(mandatory)*

### Functional Requirements

**A recoleta**

- **FR-001**: Quem administra MUST poder disparar a recoleta de timeline **por repositório
  observado**, e a recoleta MUST percorrer **todas** as issues dele — nunca um subconjunto
  inferido, porque o corte não deixou marca.
- **FR-002**: A recoleta MUST ser **idempotente**: executada duas vezes seguidas, a segunda
  insere zero eventos, e o relatório MUST dizer isso.
- **FR-003**: A recoleta MUST NOT apagar nem alterar evento já gravado. Só insere o que falta.
- **FR-004**: A recoleta MUST resolver as pessoas dos eventos **antes** de gravar, porque quem
  executou faz parte da identidade da atividade — gravar sem resolver duplicaria o mesmo evento.
- **FR-005**: A recoleta MUST parar com segurança quando a cota da origem se esgotar, dizendo
  **onde parou**, e MUST poder ser retomada **daquele ponto** — nunca do começo.
- **FR-006**: Duas recoletas simultâneas do mesmo repositório MUST ser recusadas, com a razão.

**A prova**

- **FR-007**: A recoleta MUST conferir uma **amostra** das issues percorridas por uma segunda
  leitura, por caminho diferente do usado na recoleta, e MUST registrar os dois números.
- **FR-008**: Qualquer divergência na amostra MUST tornar o veredito **incompleta**, com as
  issues divergentes nomeadas; a recoleta MUST NOT declarar-se completa por ter terminado.
- **FR-009**: O relatório MUST dizer **quantas** issues foram conferidas de quantas — a
  cobertura da própria conferência, nunca só a palavra "conferido".
- **FR-010**: O relatório MUST dizer quantas issues terminaram **no teto da página** — a
  assinatura do corte —, mesmo que zero.

**O que mudou**

- **FR-011**: O relatório MUST trazer, por repositório: issues percorridas, issues com eventos
  novos, eventos inseridos, e custo em pontos de cota — todos medidos.
- **FR-012**: O relatório MUST trazer os eventos novos **por mês de ocorrência**, para que o
  efeito nas medidas seja visível antes e depois.
- **FR-013**: Repositório sem nada a recuperar MUST aparecer no relatório **com zero**, e nunca
  ser omitido — presença com zero é informação; ausência da linha é ambígua.
- **FR-014**: O relatório MUST declarar os limites conhecidos que a recoleta **não** resolve: os
  eventos que a origem nunca registrou, e a colisão de identidade entre eventos do mesmo tipo,
  ator e segundo em issues diferentes.

**A medida do estrago**

- **FR-015**: Antes de recoletar, a plataforma MUST poder **medir e mostrar** quantas issues
  estão na faixa suspeita, por repositório — e MUST dizer que o número é **indício, não
  diagnóstico**.

### Key Entities

- **Execução de recoleta**: repositório, quando começou, quando terminou, onde parou se parou,
  issues percorridas, issues com eventos novos, eventos inseridos, custo em pontos, veredito
  (completa · incompleta · interrompida) e a razão.
- **Conferência por amostra**: issues sorteadas, o número de itens obtido pelos dois caminhos, e
  a divergência de cada uma.
- **Efeito**: eventos novos por repositório e por mês de ocorrência.
- **Limite declarado**: cada coisa que a recoleta não alcança, com a razão e o número quando
  houver.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois da recoleta do `conectafapes-project`, a issue `#1828` tem o evento
  `2026-06-11 → Done`, que hoje não existe no banco.
- **SC-002**: Das **282** entregas do quadro 43 com evento de conclusão na origem, **pelo menos
  95%** passam a ter data no banco; as que não passarem são nomeadas com a razão.
- **SC-003**: A distribuição de conclusões por mês do quadro 43 passa de **zero** para os valores
  medidos na origem em abril, maio, junho, julho e agosto de 2026.
- **SC-004**: A segunda execução da recoleta, logo após a primeira, insere **zero** eventos.
- **SC-005**: **Nenhum** evento é apagado ou alterado — a contagem de eventos anteriores à
  recoleta é idêntica antes e depois.
- **SC-006**: **100%** dos relatórios trazem a cobertura da conferência e a lista de limites não
  resolvidos.
- **SC-007**: A recoleta interrompida por cota retoma e termina sem repetir o que já percorreu —
  medido pelo custo total das duas partes contra o de uma execução única.
- **SC-008**: O custo medido da recoleta do `conectafapes-project` fica dentro da cota de uma
  hora — a medição de 2026-09-15 aponta **176 pontos** contra 5 000 disponíveis.

## Assumptions

- **O conserto do `page_size` já está em vigor** (`3b63587`), e a recoleta o usa. Recoletar com
  o defeito de pé traria o mesmo corte.
- **A segunda leitura da conferência usa caminho diferente** do da recoleta — se usasse o mesmo,
  provaria apenas que a origem é consistente consigo mesma, não que entregou tudo.
- **A amostra da conferência é pequena e sorteada**, não a totalidade: conferir tudo dobraria o
  custo e a cota é o recurso escasso. O tamanho da amostra é decisão do plano, e o relatório diz
  qual foi.
- **Recoletar é seguro por construção**: a identidade da atividade já existe e já é conferida
  antes de inserir. O risco não é duplicar por reexecução — é duplicar por **resolver a pessoa
  de outro jeito**, e a FR-004 fecha isso.
- **475 é a faixa suspeita, não o número de issues truncadas.** A distribuição de eventos por
  issue cai suavemente até 9 e quebra entre 10 e 13; a quebra é o indício. O número real sai da
  recoleta.
- **Os 69 cartões sem evento nenhum não são recuperáveis** por esta feature: a origem não
  registrou a mudança. Eles continuam contados e não datados, como a 066 já prevê.
- **A recoleta não muda nenhuma medida sozinha.** Ela devolve o dado; datar a conclusão depende
  da declaração da 066 e da 067.

## Dependencies

- **O conserto da coleta** (`3b63587`): o tamanho de página por fase e a guarda do teto.
- **022 — timeline das issues**: os eventos, a identidade da atividade e a gravação idempotente.
- **004 — issues e projetos**: as issues e os repositórios observados.
- **066 e 067**: as consumidoras do dado recuperado — sem elas, a data existe e ninguém a usa.
- **A cota da origem**: o recurso escasso, e o motivo de a recoleta precisar parar e retomar.

## Out of Scope

- **O conserto do `page_size`** — já feito.
- **A definição de pronto** (066) e **o critério de aceite** (067).
- **Mudar a identidade da atividade** para incluir a issue: é emenda à ontologia mais migração de
  dezessete mil registros, e item próprio. Esta feature **declara** a colisão, não a conserta.
- **Recoletar issues, comentários, mudanças ou verificações** — só a timeline.
- **Recuperar o que a origem nunca registrou**: os 69 cartões sem evento. Nenhuma recoleta os
  alcança.
