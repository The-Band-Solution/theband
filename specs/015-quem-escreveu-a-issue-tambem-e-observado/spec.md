# Feature Specification: quem escreveu a issue também é observado

**Feature**: `015-quem-escreveu-a-issue-tambem-e-observado` · **Criada em**: 2026-08-13
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#283](https://github.com/The-Band-Solution/theband/issues/283), decisão da pessoa mantenedora

## O pedido, e as três decisões que ele já traz fechadas

> "Nesse caso crie pessoas… cadastre as pessoas em `eo_people`."
> "Às vezes as pessoas saem da organização e ficam as issues."
> "Podemos falar que elas participaram da organização pelas issues."

| Decisão | Escolha | Tomada por |
|---|---|---|
| criar ou não | **criar** | pessoa mantenedora |
| onde | **`eo_people`**, com os outros | pessoa mantenedora |
| identidade | **pedir o `id` à origem**, nunca deduzir do login | pessoa mantenedora, depois de a medida mostrar que o payload só tem login |
| pertencimento | participação **derivada do trabalho**, nunca membro | pessoa mantenedora |

---

## O que a medida achou

**Medido em 2026-08-13**, no banco de desenvolvimento:

| | |
|---|---:|
| pessoas coletadas | **75** |
| dessas, marcadas como ausentes | **4** — saíram **durante** a observação |
| aparições sem pessoa | **288** |
| logins distintos por trás delas | **15** — 14 autores e 1 designado |
| desses 15, quantos já estiveram em `eo_people` | **zero** |

E o trabalho deles é antigo:

| login | issues | de | até |
|---|---:|---|---|
| `sofialctv` | 64 | 2025-02-03 | 2026-01-22 |
| `sofiasilv4` | 45 | 2026-02-05 | 2026-04-09 |
| `jessicaduque` | 44 | 2025-04-10 | 2025-07-15 |
| `lucasbruno-devdog` | 40 | 2025-07-31 | 2026-05-19 |

**A plataforma começou a olhar depois que essas pessoas saíram.** Quem saiu durante a observação está
registrado, com a marca de ausência — são as 4. Quem saiu antes nunca entrou, e sobrou o trabalho sem
autor.

### Por que pedir à organização não resolve

A consulta que traz membros **nunca** devolverá `jessicaduque`: ela não é mais membro. O que a traz é
o próprio nó do autor, porque a conta existe no GitHub independente de organização.

### E por que deduzir do login seria pior que não fazer

O payload guardado tem exatamente isto:

```json
{ "login": "LuizRojas" }
```

Sem `id`, sem nome, sem tipo de conta. Criar a pessoa daí chavearia identidade por uma string que o
GitHub permite **renomear** — e o login liberado pode ser tomado por outra conta. É a **L25** aplicada
a pessoa.

### O mapeamento já cobre este caso, e isso não é semântica nova

`github.user.to.eo.person` já existe, com identidade em `id` e chave natural `login`. A justificativa
dele diz, por extenso:

> *"Uma conta de usuário do GitHub identifica um agente que atuou no repositório."*

**É o mesmo mapeamento chegando por outro caminho** — pela issue em vez da lista de membros.

---

## A participação, e por que ela não é pertencimento

O mapeamento declara a limitação, e ela continua valendo:

> *"Não existe vínculo direto entre pessoa e organização… o caminho respondível é pessoa → equipe →
> organização, e quem não está em equipe alguma não aparece em organização alguma."*

`jessicaduque` nunca esteve numa equipe. Pela derivação de hoje, ela apareceria com **zero
organizações** — falso de outra maneira, porque ela trabalhou lá.

**A segunda cadeia é observada de ponta a ponta**, e é a que esta feature usa:

```
pessoa → issue que ela escreveu → repositório → organização
```

Nenhum elo é inferido: a issue diz quem a escreveu, o repositório diz de quem é a issue, e a
organização diz de quem é o repositório. Medido: cada um dos 15 aparece em **uma** organização, por
1 a 5 repositórios.

**As duas perguntas continuam separadas, e é isso que a feature protege:**

| Pergunta | Hoje | Depois |
|---|---:|---:|
| quem é **membro** da organização? | 75, por evidência de equipe | **os mesmos 75** |
| quem **trabalhou** nos repositórios dela? | 75, e 288 issues sem autor | **90**, com as 15 marcadas como observadas pelo trabalho |
| de onde veio a afirmação? | — | a issue que ela escreveu, com data |

Juntar as duas faria "quem é da organização?" responder 90, sendo que 15 ninguém admitiu.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A coleta observa quem escreveu (Priority: P1)

A coleta de issues passa a trazer a identidade do autor e dos designados, e a pessoa é registrada com
a mesma proveniência das outras.

**Por que é P1**: sem isso, nada mais acontece.

**Teste independente**: coletar um repositório cuja issue tem autor fora da organização, e conferir
que a pessoa existe com identificador da origem.

**Cenários de aceitação**

1. **Dado** uma issue cujo autor não é membro, **quando** o repositório é coletado, **então** a
   pessoa passa a existir com `external_id` vindo da origem.
2. **Dado** a mesma coleta repetida, **quando** ela termina, **então** nenhuma pessoa é duplicada —
   a identidade é o `id`, não o login.
3. **Dado** um autor que **é** membro, **quando** a coleta roda, **então** nada muda para ele: a
   pessoa já existe e continua a mesma.
4. **Dado** um login que a origem já não resolve — conta apagada —, **quando** a coleta roda,
   **então** o login continua sem pessoa, e a tela continua declarando isso.
5. **Dado** que a coleta falhou, **quando** ela termina, **então** nenhuma pessoa é criada pela
   metade.

---

### User Story 2 - Bot não é pessoa (Priority: P1)

Conta que não é de usuário — bot, app, conta de serviço — **não** vira pessoa.

**Por que é P1**: o mapeamento já declara isso como limitação, e criar bots como pessoas
contaminaria toda medida que conta gente.

**Teste independente**: uma issue escrita por bot não aumenta a contagem de pessoas.

**Cenários de aceitação**

1. **Dado** uma issue escrita por um bot, **quando** a coleta roda, **então** nenhuma pessoa é
   criada por ela.
2. **Dado** a mesma issue, **quando** o detalhe é exibido, **então** o autor aparece com o nome do
   bot e **sem** ligação — e a tela diz que não é pessoa.
3. **Dado** a contagem de pessoas do tenant, **quando** comparada antes e depois, **então** ela
   cresce **apenas** pelos autores que são contas de usuário.

---

### User Story 3 - Trabalhou não é pertence (Priority: P1)

A pessoa observada pelo trabalho aparece nas telas com a organização em que trabalhou — e a
plataforma diz que isso é derivado do trabalho, nunca que ela é membro.

**Por que é P1**: é a decisão semântica da feature, e é onde ela pode virar defeito.

**Teste independente**: a contagem de membros por evidência de equipe não muda; a de quem trabalhou,
sim.

**Cenários de aceitação**

1. **Dado** uma pessoa observada só pelo trabalho, **quando** a página dela é exibida, **então** a
   organização aparece **com a evidência** — as issues, e desde quando.
2. **Dado** a mesma pessoa, **quando** a tela mostra a origem do vínculo, **então** ela **não** diz
   que a pessoa é membro nem que tem papel.
3. **Dado** a lista de membros de qualquer equipe, **quando** comparada com hoje, **então** ela é
   **idêntica** — ninguém entra em equipe por ter escrito issue.
4. **Dado** a pergunta "quantas pessoas a organização tem", **quando** respondida, **então** o
   número continua sendo o de evidência de equipe.

---

### Edge Cases

- **A pessoa volta para a organização**: ela já existe; a evidência de equipe se acrescenta à de
  trabalho, e nenhuma pessoa duplicada nasce.
- **O login foi renomeado desde a coleta antiga**: a identidade é o `id`; o login novo atualiza o
  registro em vez de criar outro.
- **Issue sem autor** — apagado na origem: continua sem pessoa, e a ausência continua nomeada.
- **As issues já coletadas** não têm o `id` do autor guardado: elas só ganham vínculo na **próxima**
  coleta, e isso precisa estar dito em vez de descoberto.
- **A mesma pessoa em duas organizações**: aparece nas duas, com a evidência de cada uma.
- **Designado que não é autor**: vale a mesma regra — o nó do designado também traz identidade.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A coleta MUST pedir à origem o **identificador** do autor e dos designados, além do
  login.
- **FR-002**: A pessoa MUST ser registrada em `eo_people`, pelo mapeamento
  `github.user.to.eo.person` que já existe.
- **FR-003**: A identidade MUST ser o identificador da origem — **nunca** o login.
- **FR-004**: Conta que não é de usuário MUST NOT virar pessoa.
- **FR-005**: A pessoa observada pelo trabalho MUST ter proveniência dizendo **de onde** veio: a
  issue, e quando.
- **FR-006**: A contagem de **membros** — por evidência de equipe — MUST NOT mudar.
- **FR-007**: Nenhuma evidência de participação em equipe MUST ser criada por causa de trabalho.
- **FR-008**: A organização de uma pessoa observada pelo trabalho MUST ser derivada da cadeia
  pessoa → issue → repositório → organização, e a tela MUST dizer que é derivada.
- **FR-009**: A coleta MUST ser idempotente: repetir não duplica pessoa nem reescreve proveniência.
- **FR-010**: Login que a origem não resolve MUST continuar sem pessoa, com a razão exibida.
- **FR-011**: Nenhuma pessoa MUST ser apagada — as 4 marcadas como ausentes continuam como estão.
- **FR-012**: A pessoa criada durante a execução MUST ser resolvível **na mesma execução** — pelas
  issues do repositório em que apareceu **e** pelas dos repositórios coletados depois.
- **FR-013**: A designação MUST gravar `person_id` para quem passou a existir, pela mesma regra do
  autor.

### Key Entities

- **Pessoa**: kind próprio, sem organização na tabela. Cadastrá-la **não** afirma pertencimento.
- **Evidência de participação em equipe**: o que sustenta "é membro". Não é tocada por esta feature.
- **Autoria e designação**: o que sustenta "trabalhou". É a evidência nova.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de uma coleta, as **288** aparições sem pessoa caem para as que a origem não
  resolve — contas apagadas e bots.
- **SC-002**: A contagem de pessoas sai de **75** e cresce **apenas** pelos autores que são contas de
  usuário.
- **SC-003**: A contagem de **membros por evidência de equipe** continua **75** — nenhuma pessoa
  entra em equipe por ter escrito issue.
- **SC-004**: Cada pessoa criada tem `external_id` da origem, e nenhuma tem identidade por login.
- **SC-005**: Duas coletas seguidas sem mudança na origem criam **zero** pessoas na segunda.
- **SC-005b**: Numa execução com dois repositórios, a pessoa que aparece no primeiro é resolvida
  também no segundo — **zero** issues com `author_login` preenchido e `author_person_id` nulo para
  autor que a execução observou.
- **SC-006**: A página de uma pessoa observada só pelo trabalho mostra a organização **e** a
  evidência — 64 issues em 5 repositórios, no caso de `sofialctv`.
- **SC-007**: Nenhuma pessoa some: a contagem depois é **maior ou igual** a 75.

---

## Assumptions

- **A prova exige coleta com a origem respondendo**, e portanto a chave mestra — que é da pessoa
  mantenedora. Os testes montam o caso com a borda HTTP simulada; o número real só muda na coleta.
- **As issues já coletadas não ganham autor retroativamente sem nova coleta**: o payload guardado não
  tem o `id`. Reprocessar o payload antigo **não** resolve, e isso é limitação declarada.
- Os **15** logins são a medida de 2026-08-13. Quantos deles a origem ainda resolve — contas apagadas
  não resolvem — só se sabe na coleta.
- A feature [014](../014-clicar-leva-a-pagina/spec.md) **não depende** desta: ela liga o que tem
  destino, e o que muda depois desta é a população, não a regra.
