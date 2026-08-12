# Feature Specification: o detalhe da pessoa

**Feature**: `010-detalhe-da-pessoa` · **Criada em**: 2026-08-12
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#211](https://github.com/The-Band-Solution/theband/issues/211), product backlog

## Pedido

> "Ao clicar em uma pessoa quero saber em quais repositórios ela trabalhou, equipes, e quais issues
> ela trabalhou, e outros dados. Assim, crie uma página de detalhes de uma pessoa."
>
> — pessoa mantenedora, durante o sprint 007

---

## O que a plataforma sabe, medido em 2026-08-12

| | |
|---|---:|
| pessoas | **75** |
| equipes | 12 |
| **evidências** de vínculo pessoa-equipe | **88** |
| **vínculos** materializados | **0** |
| papéis cadastrados | **0** |
| designações de issue | 4 232 |
| issues com autor | 4 241 |
| issues **sem** autor | 288 |

E a distribuição por pessoa:

| | quantas das 75 |
|---|---:|
| com designação | 59 |
| com autoria | 44 |
| com evidência de equipe | **75** |
| sem nada | **0** |

### O zero que decide o desenho

**88 evidências, zero vínculos.** E isso **não** é defeito: o vínculo da ontologia exige **papel**, e
nenhum papel foi cadastrado — são as issues #99 e #100 do backlog.

A origem declara *"esta pessoa pertence a esta equipe, com este nível de acesso de plataforma"*. A
plataforma **não promove** isso a vínculo, porque nível de acesso não é papel.

**A tela precisa dizer as três coisas**: o que a origem declarou, que a plataforma não promoveu, e
por quê. Esconder o segundo faria a tela afirmar um vínculo que a plataforma recusou; esconder o
terceiro faria a recusa parecer defeito.

**É o produto funcionando.** A feature que existe para separar observado de derivado tem aqui o caso
mais claro de todos.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver o que a plataforma sabe de uma pessoa (Priority: P1)

Quem administra clica num nome em `/people` e chega a uma página que diz tudo o que foi coletado
sobre aquela pessoa: identidade, de onde veio, e desde quando é observada.

**Por que é P1**: o nome não é link hoje, e não existe para onde ir. É o pedido literal.

**Teste independente**: clicar em qualquer uma das 75 pessoas abre a página dela, com proveniência.

**Cenários de aceitação**

1. **Dado** a lista de pessoas, **quando** alguém clica num nome, **então** a página da pessoa abre.
2. **Dado** a página aberta, **quando** ela é lida, **então** diz de qual origem a pessoa veio, com
   qual identificador, e desde quando é observada.
3. **Dado** que a pessoa é de outro tenant, **quando** alguém tenta abri-la, **então** a resposta é
   **não encontrado**.
4. **Dado** o telefone, **quando** a página é aberta, **então** ela é legível em 360 px.

---

### User Story 2 - Ver as equipes, e o que a plataforma recusou promover (Priority: P1)

A página lista as equipes que a origem declara para a pessoa, com o **nível de acesso de
plataforma** — e diz que isso **não** é vínculo da ontologia, nem papel.

**Por que é P1**: são 88 evidências e zero vínculos. Uma tela que mostrasse "equipes" sem essa
distinção afirmaria o que a plataforma recusou afirmar.

**Teste independente**: a página de uma pessoa com evidência mostra a equipe, o nível de acesso, e a
frase que explica por que não há vínculo.

**Cenários de aceitação**

1. **Dado** uma pessoa com evidência de equipe, **quando** a página é lida, **então** a equipe
   aparece com o nível de acesso da origem e a marca de **derivado ou observado** correspondente.
2. **Dado** que nenhuma evidência foi promovida a vínculo, **quando** a página é lida, **então** ela
   diz **por que** — o vínculo exige papel, e nenhum papel foi cadastrado.
3. **Dado** que a pessoa saiu de uma equipe, **quando** a página é lida, **então** o vínculo aparece
   como **ausente**, com a data — nunca como atual, e nunca omitido.
4. **Dado** que a pessoa está em equipes de organizações diferentes, **quando** a página é lida,
   **então** cada equipe diz **de qual organização** é.
5. **Dado** que a pessoa não distingue cores, **quando** vê a página, **então** os estados continuam
   distinguíveis por forma e texto.

---

### User Story 3 - Ver o trabalho: issues e repositórios (Priority: P1)

A página mostra as issues em que a pessoa **foi designada** e as que ela **abriu**, **separadas**. E
os repositórios em que ela trabalhou — que é **derivado** dessas issues, não observado.

**Por que é P1**: é a outra metade do pedido, e é onde a confusão custa: 4 232 designações e 4 241
autorias não se somam.

**Teste independente**: a página de uma pessoa com as duas coisas mostra dois números distintos e
nunca a soma deles.

**Cenários de aceitação**

1. **Dado** uma pessoa com 12 designações e 7 autorias, **quando** a página é lida, **então** ela
   mostra **12** e **7**, e **nunca 19**.
2. **Dado** que quem abre uma issue não necessariamente trabalha nela, **quando** a página é lida,
   **então** os dois papéis têm rótulos distintos, e nenhum texto os chama de "issues" sem
   qualificar.
3. **Dado** um repositório em que a pessoa aparece, **quando** ele é listado, **então** a página diz
   que o vínculo é **derivado**, e de qual evidência — designação ou autoria.
4. **Dado** uma pessoa com muitas issues, **quando** a página é aberta, **então** a lista é paginada
   e o cabeçalho diz o total.
5. **Dado** uma pessoa **sem** designação e **sem** autoria, **quando** a página é lida, **então** as
   duas ausências são **nomeadas** — nunca exibidas como zero sem explicação.

---

### Edge Cases

1. **Pessoa sem nada coletado.** Hoje não existe — as 75 têm evidência de equipe —, mas a página tem
   de abrir e nomear as três ausências.
2. **As 288 issues sem autor.** A origem não devolveu autor: conta apagada, ou issue criada por
   integração. Elas não têm pessoa, então não aparecem em página nenhuma de pessoa.
3. **Pessoa que é `Bot`.** A lista distingue tipo de conta; a página de detalhe herda isso.
4. **Mesma pessoa em duas organizações** — é a issue #82, e a página não pode somar equipes de
   organizações diferentes numa lista sem dizer qual é qual.
5. **Nível de acesso `MAINTAINER`** sendo lido como papel Scrum. É a confusão mais fácil de cometer
   aqui.
6. **Pessoa com centenas de issues.** A página não pode consultar por linha.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O nome da pessoa em `/people` DEVE ser link para a página dela.
- **FR-002**: A página DEVE mostrar identidade e proveniência: origem, identificador na origem, e
  desde quando é observada.
- **FR-003**: A página DEVE listar as equipes que a origem declara, com o **nível de acesso de
  plataforma** de cada uma.
- **FR-004**: A página DEVE dizer que o nível de acesso de plataforma **NÃO é papel** da ontologia, e
  NÃO DEVE derivar papel a partir dele.
- **FR-005**: Quando a evidência de vínculo **não foi promovida**, a página DEVE dizer **por quê** —
  e não apresentar a evidência como se fosse vínculo.
- **FR-006**: Vínculo que deixou de ser observado DEVE aparecer como **ausente**, com a data, e NÃO
  DEVE ser omitido nem exibido como atual.
- **FR-007**: Cada equipe DEVE dizer **de qual organização** é.
- **FR-008**: A página DEVE mostrar, **separadas**, as issues em que a pessoa foi **designada** e as
  que ela **abriu**.
- **FR-009**: A página NÃO DEVE exibir a **soma** das duas — o número que junta designação com
  autoria não corresponde a nada.
- **FR-010**: Os repositórios em que a pessoa trabalhou DEVEM ser apresentados como **derivados**,
  com a evidência que os sustenta nomeada.
- **FR-011**: A lista de issues DEVE ser paginada, e o cabeçalho DEVE dizer o total.
- **FR-012**: Cada estado — observado, derivado, ausente — DEVE ser distinguível por **forma e
  texto**, e NÃO apenas por cor.
- **FR-013**: Ausência DEVE ser nomeada: pessoa sem designação, sem autoria ou sem equipe tem a
  ausência dita, nunca exibida como zero sem explicação.
- **FR-014**: A página DEVE abrir para **qualquer** pessoa da lista, inclusive uma sem nada coletado.
- **FR-015**: Pessoa de outro tenant DEVE responder **não encontrado**, nunca "sem permissão".
- **FR-016**: Desenhar a página NÃO DEVE consultar por linha: as contagens são agrupadas e as
  listas, paginadas.
- **FR-017**: A página DEVE ser legível em 360 px.

### Key Entities

- **Pessoa**: já existe, com proveniência. Ganha uma tela própria.
- **Evidência de vínculo com equipe**: já existe, com nível de acesso e período. Passa a ser
  **exibida**, com a distinção entre o que a origem declara e o que a plataforma promoveu.
- **Trabalho da pessoa**: **derivado** — designação e autoria de issues, e os repositórios delas.
  Nada é gravado.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Todas as **75** pessoas são alcançáveis por clique, e cada página abre.
- **SC-002**: Para uma pessoa com designações e autorias, a página mostra os **dois** números e
  **nunca a soma** deles.
- **SC-003**: A página de qualquer pessoa com evidência de equipe diz que **nenhuma** foi promovida a
  vínculo, e por quê — hoje são **88 evidências e 0 vínculos**.
- **SC-004**: Nenhum texto da página chama nível de acesso de plataforma de **papel**.
- **SC-005**: Vínculo que deixou de ser observado aparece com a data, e não como atual.
- **SC-006**: Cada equipe listada diz de qual organização é.
- **SC-007**: Os repositórios aparecem marcados como derivados, com a evidência nomeada.
- **SC-008**: Uma pessoa sem designação e sem autoria tem as duas ausências **nomeadas**.
- **SC-009**: Desenhar a página faz um número de consultas que **não cresce** com a quantidade de
  issues, equipes ou repositórios da pessoa.
- **SC-010**: Os estados permanecem distinguíveis com a cor removida.
- **SC-011**: A página é legível e navegável em 360 px.
- **SC-012**: Um tenant não alcança pessoa de outro, e a mensagem não confirma existência.

---

## Assumptions

- **"Trabalhou no repositório" é derivado, e a página diz isso.** A origem não declara vínculo
  pessoa-repositório; a plataforma o infere de designação e autoria. Apresentar como observado seria
  afirmar o que ninguém observou.
- **Designação e autoria são papéis diferentes sobre a issue**, e a página os mantém separados. Quem
  abre uma issue não necessariamente trabalha nela — a mesma distinção que a feature 006 protegeu ao
  proibir a soma de composição com atendimento.
- **Nível de acesso de plataforma não é papel.** `MAINTAINER` é permissão na ferramenta;
  `sro.scrum_master` é papel no processo. Derivar um do outro seria mapear por semelhança de nome, o
  que o projeto proíbe.
- **A ausência de vínculo promovido é informação, não lacuna.** A página a explica em vez de
  esconder: vínculo exige papel, e cadastrar papel é outra feature — #99 e #100.
- **Nada é gravado.** Todo o conteúdo da página é lido e derivado na hora, como a classificação
  épico/atômica.
- **As 288 issues sem autor não pertencem a pessoa nenhuma**, e por isso não aparecem aqui. Elas já
  são visíveis nas telas de trabalho, que contam issues por repositório.

## Dependencies

- A gramática da evidência em `docs/design-system.md`: forma, texto e rótulo acessível juntos. É o
  que sustenta FR-010 e FR-012.
- A tela de pessoas, que já existe com proveniência — é dela que o link parte.

## Out of Scope

| Fora | Por quê |
|---|---|
| cadastrar papel, ou alocar pessoa a papel | é a #99 e a #100, com ciclo próprio; esta feature **exibe** a ausência do papel, não a resolve |
| promover a evidência a vínculo | depende do papel existir |
| um lugar para as 288 issues sem autor | não têm pessoa; e a spec não inventa uma tela para elas |
| contribuição por commit, ou revisão de PR | não é coletado hoje |
| editar qualquer dado da pessoa | a plataforma observa a origem; editar aqui criaria uma segunda verdade |
| ordenar ou filtrar as issues da pessoa | não foi pedido; a paginação resolve a leitura |
