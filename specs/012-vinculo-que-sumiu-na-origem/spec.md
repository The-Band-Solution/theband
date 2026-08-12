# Feature Specification: o vínculo que sumiu na origem

**Feature**: `012-vinculo-que-sumiu-na-origem` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#263](https://github.com/The-Band-Solution/theband/issues/263), achada **durante** a
feature 011 — medindo para escrever a spec, não rodando teste

## O defeito

> `decomposition_links.no_longer_observed_at` existe **desde a migração de 2026-08-11**, e **nada no
> código o preenche**.

`record_decomposition_link/2` faz upsert e **ressuscita** o vínculo que voltou a aparecer — zera a
marca. Nenhuma função marca o vínculo que **deixou** de aparecer.

O princípio da casa é que **ausência é marcada, nunca apagada**. Aqui ela não é nem marcada nem
apagada: é **ignorada**, e o vínculo antigo se apresenta como atual. É pior que apagar, porque
apagar pelo menos não afirma.

---

## O que a medida achou

**Medido em 2026-08-12**, no banco de desenvolvimento:

| | |
|---|---:|
| vínculos de decomposição | **1 666** |
| **marcados como ausentes** | **0** |
| vínculos que a última coleta **não** reviu | **52** |
| repositórios afetados | **3** |

Os 52 por repositório, e cada linha diz uma coisa diferente:

| repositório | vínculos não revistos | o que mais a medida diz |
|---|---:|---|
| `eo_lib` | **29** | **nenhuma** issue do repositório declara sub-issue hoje |
| `theband` | **15** | **157** vínculos do mesmo repositório foram revistos na mesma coleta |
| `ResearchDomain` | **8** | **nenhuma** issue do repositório declara sub-issue hoje |

**Os 15 do `theband` são a prova mais dura de que a coleta rodou**: 157 vínculos do mesmo
repositório receberam carimbo novo às 12h32 de 2026-08-12, e esses 15 ficaram em 2026-08-11 15h04.
Não foi coleta que faltou — foi decomposição que a origem parou de declarar.

E os 29 do `eo_lib` são a prova mais dura de que a plataforma afirma o que a origem nega: as issues
do repositório foram recoletadas, **todas com zero sub-issues**, e a plataforma segue afirmando 29
decomposições.

### O que a medida **descartou**

| hipótese | medida | veredito |
|---|---:|---|
| são vínculos de issue que sumiu | **0** dos 52 têm pai marcado ausente | descartada |
| são vínculos de parte que sumiu | **0** dos 52 têm filha marcada ausente | descartada |
| é repositório inacessível, não coletado | **0** vínculos com pai em repositório inacessível | descartada |

**Nos 52, pai e filha estão vigentes.** Não há issue ausente para explicar o vínculo: o que sumiu foi
a relação, e só ela.

### Dois números que decidem o desenho

| | |
|---|---:|
| vínculos cujo pai e filha estão em **repositórios diferentes** | **57** |
| recusas registradas em `refused_links`, todas `out_of_scope` | **4** |

**Quem declara o vínculo é o pai, e o escopo da marca é o repositório do pai.** A origem devolve as
partes **dentro** da issue-pai; a coleta lê essa lista uma vez por repositório. Um vínculo cujo pai
está em `A` e a filha em `B` é declarado por `A` — e uma coleta de `B` **não** tem como saber se ele
acabou. Marcar por tenant repetiria a **L19** no nível do vínculo: numa organização de 121
repositórios, uma coleta de um marcaria os vínculos dos outros 120.

---

## A tela já está pronta, e é isso que torna esta feature uma fatia vertical

A feature 011 entregou a coluna `part of` sabendo exibir o vínculo ausente:

- o rótulo existe: *"absent: this link existed and is not present now"*;
- a contagem de "mais de um pai" **já exclui** o ausente — um pai vigente mais um vínculo que acabou
  é **um** pai;
- `list_parents/2` já carrega `no_longer_observed_at` no resultado.

**A tela sabe exibir, e o dado nunca chega nesse estado.** Esta feature liga os dois: nenhuma
infraestrutura sem consumidor visível, e o consumidor já existe.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A coleta para de afirmar a decomposição que a origem largou (Priority: P1)

Quem coleta um repositório espera que a plataforma passe a dizer o que a origem diz **agora**. Se uma
sub-issue foi removida do pai, o vínculo deixa de ser vigente — e continua registrado, com a data em
que deixou de ser visto.

**Por que é P1**: é o defeito. Sem isso, os outros cenários não têm dado para exibir.

**Teste independente**: coletar um repositório cujo pai perdeu uma parte, e conferir que aquele
vínculo — **e nenhum outro** — ficou marcado.

**Cenários de aceitação**

1. **Dado** um vínculo registrado e um pai que não declara mais aquela parte, **quando** o
   repositório do pai é coletado, **então** o vínculo passa a **ausente**, com a data em que deixou
   de ser visto.
2. **Dado** um vínculo que a coleta **reviu**, **quando** a mesma execução termina, **então** ele
   continua vigente — nunca é marcado junto.
3. **Dado** um vínculo marcado como ausente, **quando** a origem volta a declarar a mesma
   decomposição, **então** ele volta a vigente, e a data de primeira observação **não** muda.
4. **Dado** que nada mudou na origem, **quando** o mesmo repositório é coletado duas vezes,
   **então** a segunda coleta não marca nada — nem cria vínculo, nem apaga marca.
5. **Dado** um vínculo que deixou de ser visto, **quando** ele é marcado, **então** a linha continua
   existindo — **nada é apagado**.

---

### User Story 2 - A tela deixa de afirmar o que a origem não declara (Priority: P1)

Quem varre a lista de issues de um repositório vê a coluna `part of` dizendo que aquele vínculo
acabou, em vez de vê-lo apresentado como relação atual.

**Por que é P1**: é o valor visível. Os 52 vínculos de hoje são 52 afirmações erradas em tela, e é
por isso que a marca no banco não é o entregável — a tela é.

**Teste independente**: uma issue cujo único vínculo está ausente aparece na lista dizendo que a
decomposição acabou, e **não** aparece como issue com pai.

**Cenários de aceitação**

1. **Dado** uma issue cujo vínculo com o pai está ausente, **quando** a lista é exibida, **então** a
   linha diz que aquele vínculo **existiu e não está presente agora**.
2. **Dado** uma issue com um pai vigente e um vínculo ausente, **quando** a lista é exibida,
   **então** ela **não** diz "mais de um pai".
3. **Dado** o detalhe do pai, **quando** ele lista as partes, **então** a parte cujo vínculo está
   ausente **não** conta como parte vigente.
4. **Dado** que a pessoa não distingue cores, **quando** vê a lista, **então** vigente e ausente
   continuam distinguíveis por **texto**.

---

### User Story 3 - Coleta que não olhou não marca (Priority: P1)

Um repositório que a coleta não conseguiu ler, ou que o tenant excluiu, **não** produz ausência de
vínculo nenhum.

**Por que é P1**: é a família da **L19** e da feature 009 — a marca de ausência aplicada fora do que
foi olhado apaga observação verdadeira, e faz isso **sem erro nenhum**. Já custou 38 repositórios e
899 issues uma vez.

**Teste independente**: uma coleta em que um repositório falha e outro responde marca vínculo **só**
no que respondeu.

**Cenários de aceitação**

1. **Dado** um repositório cuja leitura falhou de forma transitória, **quando** a coleta termina,
   **então** **nenhum** vínculo daquele repositório é marcado como ausente.
2. **Dado** um repositório marcado como inacessível, **quando** a coleta roda, **então** ele não é
   coletado e **nenhum** vínculo dele é marcado.
3. **Dado** um repositório excluído pelo tenant, **quando** a coleta roda, **então** vale o mesmo.
4. **Dado** um vínculo cujo pai está no repositório `A` e a filha no `B`, **quando** **só** `B` é
   coletado, **então** o vínculo **não** é marcado — quem o declara é `A`.
5. **Dado** dois tenants, **quando** um deles coleta, **então** nenhum vínculo do outro é tocado.

---

### Edge Cases

- **A parte fora do escopo observado** já é registrada como recusa (`out_of_scope`, **4** hoje) e
  **não** vira vínculo. Recusa não é vínculo, e esta feature **não** a marca nem a expira.
- **O pai perdeu todas as partes.** Todos os vínculos daquele pai ficam ausentes, e a issue continua
  vigente — ela não sumiu, a decomposição dela sumiu.
- **O ciclo recusado** (`reason: "cycle"`) continua fora: nunca foi vínculo.
- **A coleta que falha no meio da paginação** do repositório: se a leitura não completou, o
  repositório não conta como olhado, e nada dele é marcado.
- **O relógio, e são dois instantes diferentes.** O **corte** é o início da execução: sem isso, um
  vínculo gravado durante a própria execução cai do lado errado. A **data da marca** é quando a
  ausência foi notada — igual a issue, designado e rótulo, e trocar isso daria dois significados à
  mesma coluna em tabelas vizinhas.
- **Vínculo já marcado que continua ausente** numa coleta seguinte: a data **não** é reescrita. O que
  se registra é quando deixou de ser visto, não quando se olhou de novo.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A coleta MUST marcar como ausente todo vínculo de decomposição cujo **pai** está no
  repositório coletado e que a execução **não** reviu.
- **FR-002**: O **corte** entre "revisto nesta execução" e "não revisto" MUST ser o instante em que a
  execução **começou** — nunca "agora". A **data gravada na marca** MUST seguir a convenção que a
  plataforma já usa em issue, designado e rótulo: o instante em que a ausência foi notada.
- **FR-003**: O escopo da marca MUST ser o **repositório do pai** — nunca o tenant, nunca a
  organização.
- **FR-004**: A marca MUST ser aplicada **uma vez por repositório coletado**, e só depois de a
  leitura daquele repositório ter completado com sucesso.
- **FR-005**: Repositório **não coletado** — inacessível, excluído pelo tenant, ou cuja leitura
  falhou — MUST NOT ter vínculo algum marcado.
- **FR-006**: O vínculo que **reaparece** na origem MUST voltar a vigente, preservando a data de
  primeira observação.
- **FR-007**: O vínculo marcado MUST permanecer registrado — **nada é apagado**.
- **FR-008**: Marcar MUST ser idempotente: uma segunda coleta sem mudança na origem não altera
  nenhuma data.
- **FR-009**: Vínculo **já** marcado como ausente MUST NOT ter a data reescrita por coleta
  posterior.
- **FR-010**: A operação MUST ser escopada por tenant, e não pode alcançar vínculo de outro.
- **FR-011**: A lista de issues do repositório MUST exibir o vínculo ausente **como ausente**, com
  texto — não só cor.
- **FR-012**: Contagens de decomposição — "mais de um pai", partes de um pai, e as listas de
  atendimento e composição — MUST contar **só** os vínculos vigentes.
- **FR-013**: A coleta MUST registrar, **por repositório**, quantos vínculos marcou — no resultado da
  fase e no log da execução. E MUST NOT criar número novo na tela de sincronizações: o consumidor
  visível é a lista de issues, e um segundo número ao lado dos outros convida a somar o que não se
  soma.
- **FR-014**: Recusas (`refused_links`) MUST permanecer fora desta marcação.

### Key Entities

- **Vínculo de decomposição**: a afirmação de que uma issue é parte de outra. Tem quando foi
  observado pela primeira vez, quando foi visto pela última vez, e — a partir desta feature — quando
  **deixou** de ser visto.
- **Execução de coleta**: tem um instante de início, e é ele que define o corte entre "revisto nesta
  execução" e "não revisto".
- **Repositório observado**: o escopo da marca. Só o repositório que a execução **leu com sucesso**
  produz ausência.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de uma coleta com a origem respondendo, os **52** vínculos que a origem não
  declara mais aparecem marcados como ausentes — e a contagem sai de **0**, onde está desde
  2026-08-11.
- **SC-002**: Na mesma coleta, os vínculos que a origem **ainda** declara continuam vigentes: no
  `theband`, os 157 revistos permanecem, e só os 15 são marcados.
- **SC-003**: Nenhum vínculo de repositório que a execução não leu é marcado — a contagem de marcados
  em repositório não coletado é **zero**, em qualquer execução.
- **SC-004**: A lista de issues de `eo_lib` deixa de apresentar as 29 decomposições como atuais, e
  passa a dizer, em texto, que elas acabaram.
- **SC-005**: Duas coletas seguidas sem mudança na origem produzem **as mesmas** datas em todos os
  1 666 vínculos.
- **SC-006**: O log da execução nomeia o repositório e quantos vínculos ele marcou, e esse número
  bate com a contagem feita direto no banco.
- **SC-007**: O painel de violações da `sro.rule07` cai de **293** para **281** — as **12** violações
  que dependiam de vínculo que a origem não declara mais deixam de ser afirmadas, e as 12 tarefas
  passam a contar na outra forma da violação, a que é sobre tarefa **sem** pai.

### A consequência que a marca tem fora da feature, e ela é esperada

**Número derivado muda quando o vínculo sai da vigência**, porque a plataforma inteira já conta só o
vigente. Conferido nas seis consultas de vínculo: todas filtram o ausente. O que muda, medido:

| O que | Hoje | Depois |
|---|---:|---:|
| violações da `sro.rule07` por tarefa sob épico | 293 | **281** |
| pais afetados pela marca | — | **4** |
| pai que **deixaria** de ser épico | — | **nenhum hoje** — o único épico afetado mantém 3 das 6 partes user story |

**O terceiro caso é mecanismo novo, não número novo**: um pai cujas partes user story ficam todas
ausentes deixa de ser classificado como épico. Está correto — épico é derivado das partes, e parte
que a origem não declara mais não sustenta a derivação. Hoje ninguém cai nesse caso, e é por isso que
ele está declarado em vez de descoberto depois.

---

## Assumptions

- **A feature 011 precisa estar incorporada** para o critério visível ser verificável: a coluna
  `part of` e o rótulo de vínculo ausente vivem no [PR #264](https://github.com/The-Band-Solution/theband/pull/264),
  aberto e aguardando revisão. A parte de coleta não depende dele; a de tela depende.
- Os **52** vínculos são a medida de 2026-08-12. O número muda a cada coleta — o critério é
  "os que a origem não declara mais", e 52 é o valor conferido no dia.
- A origem continua declarando decomposição **de cima para baixo**: as partes vêm dentro do pai. Se
  isso mudar, o escopo da marca muda junto.
- O corte por instante de início da execução assume que o carimbo de "visto pela última vez" de um
  vínculo revisto é **sempre** posterior ao início da execução que o reviu.
- A prova no dado real exige a chave mestra e a origem respondendo, que a pessoa mantenedora executa
  — a asserção em teste não substitui a conferência.
