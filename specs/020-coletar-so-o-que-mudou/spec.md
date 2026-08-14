# Feature Specification: coletar só o que mudou

**Feature**: `020-coletar-so-o-que-mudou` · **Criada em**: 2026-08-14
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: pedido da pessoa mantenedora em 2026-08-14

## O pedido

> "Não quero baixar todos os elementos todo momento. Como podemos verificar quais serão novos
> elementos e quais elementos serão atualizados?"

---

## O que a medida achou

**Medido na coleta real de 2026-08-14 03:33**, nas três organizações observadas.

| Organização | Duração | Issues baixadas | Mudaram desde a coleta anterior |
|---|---:|---:|---:|
| leds-conectafapes | **5min 08s** | 4295 | **34** |
| ifesserra-lab | 30s | 414 | — |
| The-Band-Solution | 23s | 322 | — |
| **total** | **6min 01s** | **5031** | 502 novas · 182 alteradas |

**4295 baixadas, 34 mudadas.** Menos de 1%.

E há um corte mais grosso disponível antes desse:

```
106 dos 121 repositórios da leds-conectafapes não receberam push nenhum
desde a coleta anterior — e foram percorridos inteiros mesmo assim.
```

### O defeito que a medida encontrou no caminho

**`records_created` e `records_updated` são zero em todas as 38 execuções** que existem no
banco. A tela de sincronização mostra:

```
records collected   4553
created                0
updated                0
skipped                0
```

Ela está exibindo fielmente o que foi gravado. `github_work_items.ex:121` e `:408` chamam
`Ingestion.tally(:unchanged)` **fixo** — para toda issue e todo repositório, independentemente
de ter sido criada ou atualizada. E `:unchanged` só incrementa `records_collected`.

A informação existia no instante em que foi descartada: hoje entraram 502 issues novas e 182
mudaram na origem. `records_created` deveria dizer 502.

**Isto não é acessório da feature — é pré-requisito dela.** Uma coleta que baixa menos precisa
provar que não deixou de trazer o que mudou, e a prova é a contagem. Sem ela, "baixamos 5% do
que baixávamos" e "perdemos 95% do que deveríamos trazer" produzem a mesma tela.

### O que já existe e não é usado

| O quê | Onde | Diz |
|---|---|---|
| `observed_repositories.issues_collected_at` | preenchido a cada coleta | quando as issues daquele repositório foram revistas |
| `cmpo_source_repositories.last_pushed_at` | vem da consulta de repositórios | última atividade na origem — **preenchido nos 160** |
| `collected_issues.external_updated_at` | vem de cada issue | quando a issue mudou na origem |
| `Ingestion.tally/2` | já distingue `:created`, `:updated`, `:unchanged` | e os chamadores passam `:unchanged` fixo |

A consulta `issues.graphql` ordena por `CREATED_AT ASC` e **não filtra por atualização**.

### A ironia útil

A fase de **promoção** já faz o que se quer da coleta: `gravar_se_mudou/4` só grava quando a
decisão mudou — hoje gravou 532 de 5031. A plataforma já sabe não **escrever** o que não mudou.
O que ela não sabe é não **baixar**.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A execução diz o que ela fez (Priority: P1)

Quem abre `/syncs` depois de uma coleta vê quantos registros entraram, quantos mudaram e
quantos continuaram iguais.

**Por que é P1**: é o pré-requisito da história 2, e é o que hoje mente. Sem ele, coletar menos
não tem como ser provado — nem desmentido.

**Independent Test**: rodar uma coleta contra origem simulada com uma issue nova, uma alterada e
uma inalterada, e conferir que a tela diz 1, 1 e 1.

**Cenários de aceitação**

1. **Dado** um registro que não existia, **quando** a coleta o grava, **então** `created`
   aumenta em um.
2. **Dado** um registro que existia e cujo conteúdo mudou, **quando** a coleta o grava,
   **então** `updated` aumenta em um, e `created` não.
3. **Dado** um registro idêntico ao que já estava gravado, **quando** a coleta passa por ele,
   **então** nenhum dos dois aumenta — e `records collected` aumenta.
4. **Dado** que a coleta foi interrompida no meio, **quando** alguém lê os números, **então**
   eles refletem o que aconteceu até ali, e não zero.

---

### User Story 2 - O repositório sem atividade não é percorrido (Priority: P1)

A coleta pula inteiro o repositório cuja origem não registrou push desde a última vez que as
issues dele foram revistas.

**Por que é P1**: é o corte mais grosso e o mais barato — 106 de 121 repositórios, com dado que
já está no banco e já vem da origem. Não depende de mudar a consulta de issues.

**Independent Test**: duas coletas seguidas sem atividade na origem entre elas; a segunda não
faz consulta de issues para repositório algum, e a tela diz que nenhum foi revisto.

**Cenários de aceitação**

1. **Dado** um repositório cujo `last_pushed_at` é anterior ao `issues_collected_at`,
   **quando** a coleta roda, **então** ela **não** consulta as issues dele.
2. **Dado** o mesmo repositório, **quando** a coleta termina, **então** a tela diz que ele foi
   pulado, e **por quê** — nunca em silêncio.
3. **Dado** um repositório com push depois da última revisão, **quando** a coleta roda,
   **então** ele é percorrido normalmente.
4. **Dado** um repositório nunca coletado, **quando** a coleta roda, **então** ele é percorrido
   — ausência de data não é ausência de mudança.
5. **Dado** um repositório pulado, **quando** alguém pergunta pelas issues dele, **então** elas
   continuam vigentes: pular não é marcar ausência.

---

### User Story 3 - A issue inalterada não é baixada (Priority: P2)

Dentro do repositório que **teve** atividade, a coleta traz apenas as issues alteradas desde a
última revisão.

**Por que é P2**: depende da 2 estar feita para valer a pena, e é a que exige mudar a consulta
da origem. Sozinha, ela ainda percorreria os 106 repositórios parados.

**Independent Test**: repositório com 50 issues, uma delas alterada; a coleta traz uma.

**Cenários de aceitação**

1. **Dado** um repositório com atividade, **quando** a coleta roda, **então** ela pede à origem
   apenas as issues alteradas desde `issues_collected_at`.
2. **Dado** que a coleta anterior falhou no meio, **quando** a seguinte roda, **então** ela
   parte da última revisão **completa**, e não da interrompida.
3. **Dado** uma issue que sumiu da origem, **quando** a coleta incremental roda, **então** a
   marca de ausência **continua funcionando** — ver os riscos abaixo.

---

## O risco que esta feature cria, e ele tem nome

**A marca de ausência depende de ver a lista inteira.** A feature 012 marca o vínculo que a
origem deixou de declarar, e a 009 cura a marca de repositório inacessível. As duas raciocinam
por **comparação com o que foi visto**: "não apareceu" só significa alguma coisa em relação ao
que foi olhado.

Uma coleta que olha só o que mudou **não vê** o que sumiu. Se nada for feito, os 52 vínculos
marcados de ontem passariam a nunca mais ser recalculados, e a marca de ausência viraria
afirmação sobre um conjunto que ninguém percorreu — a L19 de cabeça para baixo.

**Duas saídas, e a spec não escolhe — o plano escolhe:**

| Saída | Custo | Consequência |
|---|---|---|
| coleta completa periódica, incremental no resto | uma execução cara de vez em quando | a marca de ausência atrasa até a próxima completa |
| a origem informa remoção | depende de a origem informar | GitHub não informa issue apagada; informa fechada |

**FR-012 abaixo transforma isso em requisito**, e não em observação.

---

### Edge Cases

- **Primeira coleta de um repositório**: sem `issues_collected_at`, tudo é novo. É o caso da
  L47, e ele já subconta a decomposição por outro motivo.
- **Relógio da origem e relógio da plataforma**: uma issue alterada no mesmo segundo da coleta
  pode cair fora da janela. A janela precisa de sobreposição declarada.
- **Coleta interrompida no meio de um repositório**: gravar `issues_collected_at` ali diria que
  ele foi revisto, e a próxima coleta o pularia. É acoplamento temporal — efeito registrado
  antes do trabalho que ele descreve.
- **Push que não mexe em issue**: um commit muda `last_pushed_at` sem alterar issue alguma. O
  repositório é percorrido à toa, e isso é **aceitável** — o custo do falso positivo é uma
  consulta, e o do falso negativo é dado que não chega.
- **Issue alterada por comentário**: `updatedAt` muda? Se não, o corte perde alteração real.
- **Reprocessamento**: ele trabalha sobre o payload preservado, e não deve mudar de
  comportamento por causa da coleta incremental.

---

## Requirements *(mandatory)*

### Contagem — o pré-requisito

- **FR-001**: Cada registro gravado MUST ser contado como **criado**, **atualizado** ou
  **inalterado**, conforme o que aconteceu com ele.
- **FR-002**: A tela de sincronização MUST exibir os três números, e eles MUST corresponder ao
  que a execução fez.
- **FR-003**: Execução interrompida MUST preservar as contagens do que já foi feito.
- **FR-004**: A contagem MUST valer para issues e repositórios, não só para pessoas e equipes.

### Pular o que não teve atividade

- **FR-005**: A coleta MUST NOT consultar issues de repositório cujo `last_pushed_at` seja
  anterior à última revisão completa das issues dele.
- **FR-006**: Repositório nunca revisto MUST ser percorrido.
- **FR-007**: A plataforma MUST registrar quantos repositórios foram pulados e por quê, e a
  tela MUST dizer isso — pular em silêncio é indistinguível de não achar nada.
- **FR-008**: Pular um repositório MUST NOT marcar coisa alguma como não mais observada.

### Trazer só o alterado

- **FR-009**: Dentro do repositório com atividade, a coleta MUST pedir à origem apenas as
  issues alteradas desde a última revisão completa.
- **FR-010**: A marca de revisão MUST ser gravada **depois** de o repositório ter sido
  percorrido por inteiro, nunca antes.
- **FR-011**: A janela de tempo MUST ter sobreposição declarada, para que alteração
  simultânea à coleta não caia fora.

### O que não pode quebrar

- **FR-012**: A marca de ausência das features 009 e 012 MUST continuar correta. A spec **não**
  decide como; o plano MUST declarar a estratégia e MUST provar que os 52 vínculos marcados
  hoje continuariam sendo recalculados.
- **FR-013**: O reprocessamento MUST NOT mudar de comportamento.
- **FR-014**: A coleta completa MUST continuar possível sob demanda, e a tela MUST oferecê-la.

---

## Success Criteria *(mandatory)*

- **SC-001**: Numa segunda coleta sem atividade na origem, **nenhuma** consulta de issues é
  feita, e a execução termina em menos de **um décimo** do tempo da primeira.
- **SC-002**: A tela diz, para cada execução, quantos registros entraram, mudaram, ficaram
  iguais e foram pulados — e a soma dos quatro é o total percorrido.
- **SC-003**: Uma issue alterada na origem entre duas coletas **chega** na segunda.
- **SC-004**: Uma issue que sumiu da origem continua sendo marcada como ausente, na cadência
  que o plano declarar.
- **SC-005**: Sobre o dado real de hoje — 121 repositórios da `leds-conectafapes`, 106 sem push
  —, a coleta consulta no máximo **15** deles.
- **SC-006**: `records_created` de uma coleta que traz 502 issues novas diz **502**.

---

## Assumptions

- **A origem informa `updatedAt` por issue**, e o GraphQL do GitHub aceita filtrar por ele.
  Confirmar no plano é obrigatório: a consulta atual ordena por `CREATED_AT` e não filtra.
- **`last_pushed_at` é confiável como sinal de atividade.** Ele está preenchido nos 160
  repositórios observados. Push que não mexe em issue produz falso positivo, e o custo dele é
  uma consulta — aceitável.
- **Comentário em issue altera `updatedAt`.** Se não alterar, a história 3 perde alteração real,
  e o plano precisa dizer o que fazer.
- A feature **não** muda o que é gravado nem o modelo — muda o que é **pedido** à origem, e o
  que é **contado**.

## Fora do escopo

- **Coletar comentários e timeline** — é a issue #179, e tem spec própria.
- **Webhooks.** A origem avisar em vez de a plataforma perguntar resolveria outro problema, com
  outro custo: exposição de endpoint, autenticação de entrega e reentrega. Não é esta feature.
- **Mudar a cadência das coletas.** Quem dispara continua sendo quem opera.
