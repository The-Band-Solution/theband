# Feature Specification: A organização declara suas equipes

**Feature Branch**: `feat/055-equipes-declaradas`

**Created**: 2026-09-01

**Status**: Draft

**Emendada**: 2026-09-06 — ver a seção *Emenda de 2026-09-06*, logo após
"Por que agora". Os trechos alterados estão marcados *(emendado em 2026-09-06)*,
com o texto anterior preservado.

**Input**: User description: "vamos focar em criar equipes .. uma equipe pode ter outra equipe .. e uma equipe pode adicionar ou remover uma pessoa ou informar que ela saiu da equipe."

## Por que agora

Hoje **equipe só nasce da coleta**. A plataforma vê o que o GitHub mostra — 12
equipes e 88 pessoas no banco de desenvolvimento — e não há como dizer que existe
uma equipe que o GitHub não conhece, nem que duas delas formam uma terceira, nem
que alguém saiu.

Organizações reais não cabem no que a forja de código expõe: há times que
atravessam repositórios, células dentro de departamentos, e pessoas que entram e
saem sem que nada mude no GitHub. **A plataforma mede o que essas pessoas
produzem e não sabe dizer de quem elas são.**

## Emenda de 2026-09-06 — a participação observada é vínculo

**Decisão da pessoa mantenedora em 2026-09-06**, entre três saídas apresentadas
pelo Product Owner. Escolheu a segunda e a terceira: a participação observada no
GitHub vira vínculo automaticamente na coleta, e toda medida por equipe diz sobre
quem foi calculada — a segunda parte é a emenda correspondente na
[spec 058](../058-medidas-da-equipe/spec.md), FR-026.

### O motivo, medido

A regra em vigor até esta data — `github.team_membership_evidence`, versão 1 —
dizia que a participação num time do GitHub é **evidência**, e que evidência só
vira vínculo quando alguém confirma escolhendo um papel (feature 043, FR-007). A
coleta cumpriu a regra. O resultado, medido pela pessoa mantenedora em
2026-09-06 contra a organização `leds-conectafapes`:

| O que | Quanto |
|---|---:|
| equipes do GitHub coletadas | 8 |
| evidências de vínculo coletadas | 59, em 49 pessoas — bate com a origem |
| vínculos vigentes nessas 8 equipes | **0** — ninguém confirmou papel nenhum |
| solicitações de mudança nos últimos 56 dias | 1 077 |
| das quais abertas por autor que só tem evidência pendente | **838 (78%)** |

As 838 estão fora de toda medida por equipe da feature 058 — não porque a
plataforma não saiba de quem são, mas porque a regra exigia um ato humano que não
aconteceu. A coleta traz o fato; a regra o deixava sem efeito. As 8 equipes
disparam `structure.ap02.team_with_no_members` tendo, na origem, 49 pessoas.

**O que a regra acertava e continua valendo**: o GitHub não expõe papel
organizacional, `MAINTAINER` e `MEMBER` são nível de acesso, e nenhum papel MUST
ser inferido deles (043, FR-011 e FR-012). **O que a regra errava**: tratar a
ausência do papel como ausência do vínculo. São duas lacunas diferentes, e a
segunda não existe — a pessoa está no time.

### O que muda

| Antes (v1 da regra) | Depois (esta emenda) |
|---|---|
| participação observada é evidência; não é membro | participação observada é **vínculo observado**; é membro vigente |
| confirmar = criar vínculo a partir da evidência, com papel | confirmar = **declarar o papel** no vínculo observado que já existe |
| ausência na origem marca a evidência como não mais observada | ausência na origem **encerra** o vínculo observado (`ended_at`) |
| `memberships_pending_role` conta evidências não promovidas | conta **vínculos vigentes sem papel declarado** |
| vínculo tem sempre papel e autor | vínculo observado tem papel **não declarado** e autor de declaração **ausente**; a origem dele é a proveniência da coleta |

**O que não muda**: FR-012. Quando coleta e declaração discordam, a tela mostra as
duas afirmações. A coleta não toca em vínculo que carregue declaração — papel
declarado, saída registrada ou equívoco —, e é exatamente por isso que a
discordância continua possível e continua visível.

Os requisitos estão em FR-013 a FR-018; os critérios em SC-007 a SC-009. O texto
que a regra da base de conhecimento precisa passar a dizer, e a razão ontológica
que o sustenta, estão em
[`docs/backlog/vinculo-observado-sem-papel.md`](../../docs/backlog/vinculo-observado-sem-papel.md).

### O que esta emenda contradiz, e onde

| Onde | O que diz | O que passa a valer |
|---|---|---|
| 043, FR-007 | "A plataforma MUST NOT promover sozinha" | a plataforma materializa a **participação**; o **papel** continua sendo ato humano. A frase vale para o papel e deixa de valer para o vínculo |
| 043, FR-009 e FR-014 | a evidência promovida aponta para o vínculo; a tela diz "quantas evidências esperam confirmação" | toda evidência aponta para um vínculo por construção; a tela diz quantos **vínculos** estão **sem papel declarado** |
| 043, FR-018 | medida que dependa de `started_at` exclui os vínculos sem data e diz quantos | já contradito pela 057 (FR-006a: nulo é membro, nunca excluído); com a emenda, quase todo vínculo nasce sem data, e a leitura da 057 é a que vale |
| 057, FR-005 e US1 cenário 5 | pessoa observada sem vínculo é "evidência não promovida" e não entra nas contagens | a classe fica **vazia por construção**: toda participação observada tem vínculo. FR-006 e FR-006a da 057 (`started_at` nulo é membro) passam a ser o caminho da quase totalidade dos membros |
| `github.team_membership_evidence` v1 | `does_not_materialize: eo.team_membership` | precisa da versão 2 — texto proposto na nota acima |
| esta spec, premissa "A coleta continua mandando no que ela vê" | a feature não altera o observado, só acrescenta o declarado ao lado | a coleta passa a **materializar vínculo**; o que ela não faz é tocar em declaração |

Nenhum desses arquivos é alterado por esta emenda. Cada um é corrigido por quem o
mantém, e a emenda existe para que a correção tenha de onde partir.

### Decisões que esta emenda deixa em aberto

1. **Evidências cuja observação já terminou** (`no_longer_observed_at` preenchido)
   na migração: viram vínculo observado **já encerrado** — preserva o que houve,
   como FR-005 exige do declarado — ou ficam como estão? A emenda propõe a
   primeira leitura e não a decide.
2. **Equívoco em vínculo observado.** FR-006 desfaz vínculo "que nunca vigeu". A
   origem afirma que a pessoa está no time; declarar equívoco contradiz a origem.
   Duas leituras: a organização pode contradizer a origem, e FR-012 mostra as duas;
   ou vínculo observado admite saída (FR-004), nunca equívoco.
3. **A equipe derivada** (`github.default_team`) persiste o mesmo tipo de
   evidência para quem não está em time nenhum. A decisão de hoje fala em "times
   do GitHub"; se a equipe derivada acompanha, precisa ser dito.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A organização cria a equipe que o GitHub não conhece (Priority: P1)

Quem administra abre a lista de equipes, cria uma com nome próprio, e ela passa a
existir ao lado das que vieram da coleta — **distinguível delas na tela**, porque
uma foi observada e a outra foi declarada, e confundir as duas é o defeito que
esta plataforma existe para não cometer.

**Why this priority**: sem criar, não há o que compor nem a que vincular. É a
base das outras duas histórias.

**Independent Test**: criar uma equipe pela tela e encontrá-la na lista, marcada
como declarada, sem tocar em nada do GitHub.

**Acceptance Scenarios**:

1. **Given** a lista de equipes, **When** quem administra cria uma equipe com
   nome, **Then** ela aparece na lista **marcada como declarada**, com quem a
   declarou e quando.
2. **Given** uma equipe que veio da coleta, **When** alguém olha a lista,
   **Then** ela aparece **marcada como observada** — e a distinção **não** é
   carregada só por cor.
3. **Given** uma equipe declarada, **When** quem administra tenta criar outra com
   o mesmo nome no mesmo escopo, **Then** é recusado com a razão — nomes
   repetidos tornam impossível saber de qual equipe um painel fala.
4. **Given** alguém que não administra, **When** tenta criar, **Then** é
   recusado.

---

### User Story 2 - A pessoa entra, sai, e o que ela fez continua lá (Priority: P1)

Quem administra vincula pessoas à equipe, com o papel que cada uma desempenha. E
quando alguém sai, isso é **registrado como saída** — a pessoa **esteve** ali, e
o que ela entregou naquele período continua contando para a equipe.

*(Emendado em 2026-09-06)*: as pessoas que a origem mostra no time **já estão
vinculadas** quando a tela abre — com papel não declarado. O que quem administra
faz por elas é **declarar o papel**, não criar o vínculo (FR-013, FR-014). Vincular
do zero continua existindo para quem a origem não mostra.

**Why this priority**: mesma prioridade da US1 porque **a US1 sozinha entrega uma
casca**. Equipe sem pessoas não responde nenhuma pergunta.

**Independent Test**: vincular três pessoas, registrar a saída de uma, e conferir
que um painel de período anterior à saída mostra **o mesmo número** antes e
depois.

**Acceptance Scenarios**:

1. **Given** uma equipe, **When** quem administra vincula uma pessoa com um
   papel, **Then** o vínculo passa a valer a partir da data informada, com quem
   o declarou.
2. **Given** uma pessoa vinculada, **When** quem administra registra que ela
   **saiu**, **Then** o vínculo ganha data de fim — e **nenhum número de período
   anterior muda**.
3. **Given** um vínculo criado **por engano** — a pessoa nunca esteve nessa
   equipe —, **When** quem administra o desfaz, **Then** ele deixa de valer para
   qualquer período, e **o registro do equívoco permanece**, com autor e razão.
4. **Given** uma pessoa que saiu, **When** ela é vinculada de novo à mesma
   equipe, **Then** nasce um vínculo novo — os dois períodos coexistem, e o
   histórico mostra os dois.
5. **Given** uma pessoa já vinculada e vigente, **When** alguém tenta vinculá-la
   de novo à mesma equipe, **Then** é recusado com a razão.

---

### User Story 3 - Equipe dentro de equipe (Priority: P2)

Quem administra diz que uma equipe faz parte de outra, e a estrutura da
organização passa a existir na plataforma — departamento com células dentro,
frente com times dentro.

**Why this priority**: P2 porque as duas primeiras já entregam valor. A
composição é o que torna possível perguntar da organização inteira em vez de time
a time — e é ela que o rollup de competências vai usar depois.

**Independent Test**: pôr duas equipes dentro de uma terceira e ver a estrutura
na tela; tentar fechar um ciclo e ser recusado.

**Acceptance Scenarios**:

1. **Given** duas equipes, **When** quem administra declara que a primeira faz
   parte da segunda, **Then** a estrutura aparece nas duas telas — a de cima
   mostra o que contém, a de baixo mostra de quem faz parte.
2. **Given** a equipe A dentro da B, **When** alguém tenta pôr a B dentro da A,
   **Then** é recusado: **a composição não pode fechar ciclo**, direto ou por
   qualquer caminho.
3. **Given** uma equipe que contém outras, **When** ela deixa de conter uma
   delas, **Then** a que saiu continua existindo, com o seu histórico intacto.
4. **Given** uma equipe observada, **When** quem administra a põe dentro de uma
   declarada, **Then** funciona — a composição é declaração, e vale para os dois
   tipos.

---

### Edge Cases

- **Ciclo por caminho longo.** A dentro de B, B dentro de C, e alguém tenta pôr C
  dentro de A. A recusa precisa alcançar o caminho inteiro, não só o vizinho.
- **Equipe declarada com o nome de uma observada.** Não é erro — a organização
  pode ter um time interno homônimo. A tela precisa deixar claro qual é qual.
- **Saída sem data.** Quem registra a saída pode não saber o dia exato. O que
  acontece: recusa, ou aceita com a data de hoje e diz que foi presumida?
- **Pessoa que a coleta mostra na equipe e a declaração diz que saiu.** As duas
  afirmações são verdadeiras em fontes diferentes: o GitHub ainda a lista, a
  organização diz que saiu. **A tela mostra as duas, não escolhe.** *(Permanece
  após a emenda de 2026-09-06 — FR-012 e FR-016.)*
- **Equipe com pessoas dentro, sendo removida.** Remover apagaria vínculos que
  contam para períodos passados.
- **Profundidade.** Uma equipe dentro de outra, dentro de outra — até onde?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Quem administra MUST poder criar uma equipe declarada, com nome, e
  o registro MUST guardar **quem declarou e quando**.
- **FR-002**: A tela MUST distinguir equipe **observada** de **declarada**, e a
  distinção MUST NOT ser carregada apenas por cor.
- **FR-003**: Quem administra MUST poder vincular uma pessoa a uma equipe, com
  papel e data de início, e o vínculo MUST guardar quem o declarou. *(Emendado em
  2026-09-06: vale para o vínculo **declarado**. O vínculo observado nasce sem papel
  e sem autor de declaração — FR-013.)*
- **FR-004**: Quem administra MUST poder registrar que uma pessoa **saiu**,
  informando a data. O vínculo MUST continuar existindo com fim registrado.
- **FR-005**: Registrar a saída MUST NOT alterar nenhum número de período
  anterior à data de saída. **Esta é a diferença entre sair e ser apagado**, e é
  o requisito que decide o desenho.
- **FR-006**: Quem administra MUST poder desfazer um vínculo criado **por
  engano** — aquele que nunca vigeu. O registro do equívoco MUST permanecer, com
  autor e razão. **Nenhuma linha é removida fisicamente.**
- **FR-007**: A plataforma MUST recusar vincular à mesma equipe uma pessoa que já
  tem vínculo vigente ali, dizendo a razão. *(Emendado em 2026-09-06: quando o
  vínculo vigente é **observado e sem papel**, vincular a pessoa com um papel é
  **declarar o papel nele** — FR-014 —, e não uma segunda vinculação a recusar.)*
- **FR-008**: Quem administra MUST poder declarar que uma equipe faz parte de
  outra, e desfazer essa composição.
- **FR-009**: A plataforma MUST recusar composição que feche **ciclo**, por
  caminho de qualquer comprimento.
- **FR-010**: Toda consulta MUST ser escopada ao tenant. Equipe de uma
  organização MUST NOT aparecer para outra.
- **FR-011**: Nenhuma das ações MUST estar disponível para quem não administra.
- **FR-012**: Quando a coleta e a declaração discordarem sobre uma pessoa estar
  na equipe, a tela MUST mostrar **as duas afirmações**, e MUST NOT escolher uma.

#### Emenda de 2026-09-06 — o vínculo observado

- **FR-013**: A coleta MUST materializar cada participação observada de uma pessoa
  num time da origem como **vínculo observado**: um `eo.team_membership` vigente
  com papel **não declarado** (`organizational_role_id` nulo), sem autor de
  declaração (`declared_by_user_id` nulo), com início **desconhecido**
  (`started_at` nulo) e com a proveniência da coleta — `source_system`,
  `source_instance`, `external_id`, `collected_at`. O vínculo observado MUST
  contar como membro vigente em toda medida por equipe, **sem confirmação**.
- **FR-013a**: Para cada par pessoa–equipe MUST existir **no máximo um** vínculo
  observado vigente, e a coleta repetida MUST NOT duplicá-lo (princípio III). *O
  índice de vigência de hoje não garante isto: com papel nulo, a chave
  `(tenant, pessoa, equipe, papel)` trata cada nulo como distinto.*
- **FR-013b**: Papel não declarado é **ausência**, e MUST ser apresentado como
  "papel não declarado" — nunca como papel padrão, nunca preenchido a partir do
  nível de acesso da origem (043, FR-011 e FR-012), nunca omitido da tela.
- **FR-013c**: `started_at` do vínculo observado MUST permanecer nulo. A data em
  que a coleta viu a pessoa MUST NOT ser usada como início (043, FR-019). Para o
  recorte por data valem FR-006 e FR-006a da 057: nulo é membro, contado a partir
  da primeira observação, com a tela dizendo que o início é desconhecido.
- **FR-014**: A ação de **confirmar** (043, US3 — hoje `EO.promote_evidence/4`)
  MUST passar a **declarar o papel no vínculo observado** vigente da pessoa naquela
  equipe — gravando o papel, quem declarou e quando —, e MUST NOT criar um segundo
  vínculo enquanto o observado estiver vigente e sem papel. A data de início MAY
  ser declarada no mesmo ato (043, FR-016 a FR-018); em branco, continua
  desconhecida. Um **segundo papel** para a mesma pessoa na mesma equipe (043,
  FR-006a) nasce como vínculo declarado adicional, como hoje.
- **FR-015**: Quando a coleta deixa de encontrar a pessoa no time, o vínculo
  observado MUST ser **encerrado** com `ended_at` igual ao instante da coleta que
  constatou a ausência, e a tela MUST dizer que o fim foi **constatado pela
  coleta**, não declarado. O vínculo MUST NOT ser apagado — FR-005 e FR-006 valem
  para ele. Se a origem voltar a mostrar a pessoa, nasce um vínculo observado
  **novo**, e os dois períodos coexistem (US2, cenário 4).
- **FR-015a**: A data de fim constatada pela coleta é **limitada pela cadência da
  coleta**: diz quando a plataforma deixou de ver, não quando a pessoa saiu. A
  tela MUST declarar essa limitação junto da data.
- **FR-016**: A coleta MUST NOT criar, encerrar nem alterar vínculo que carregue
  **qualquer declaração** — papel declarado (FR-014), saída registrada (FR-004)
  ou equívoco (FR-006). Discordância entre o que a coleta mostra e o que está
  declarado permanece regida por **FR-012**: as duas afirmações, nenhuma
  escolhida.
- **FR-017**: As evidências de vínculo já coletadas e ainda observadas MUST ser
  promovidas a vínculo observado por **migração de dados**, uma por par
  pessoa–equipe, sem papel e sem início inventados, e cada evidência MUST passar
  a apontar para o vínculo que a materializou (021, FR-009). Para a
  `leds-conectafapes` em 2026-09-06 são **59 evidências, 49 pessoas, 8 equipes**.
  *Evidência cuja observação já terminou: decisão em aberto — ver a emenda.*
- **FR-018**: `memberships_pending_role` MUST passar a contar **vínculos vigentes
  sem papel declarado**, e MUST NOT contar evidência. O número continua sendo
  informação, não erro: mede quanto da estrutura a organização ainda não
  declarou, e MUST aparecer na tela da equipe ao lado do total de membros.

### Key Entities

- **Equipe**: já existe. Ganha origem — observada ou declarada — e a composição.
- **Vínculo de pessoa a equipe**: já existe, com pessoa, equipe, papel, início,
  fim e autor. Ganha o registro de equívoco. *(Emendado em 2026-09-06: ganha
  também a forma **observada** — papel não declarado, autor de declaração ausente,
  proveniência da coleta, fim constatado pela ausência. FR-013 a FR-016.)*
- **Composição entre equipes**: **nova**. Qual equipe faz parte de qual, desde
  quando, declarada por quem.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem administra cria uma equipe e vincula três pessoas em **menos
  de 3 minutos**, sem console e sem sair da tela de equipes.
- **SC-002**: **100%** das equipes na lista dizem se foram observadas ou
  declaradas, e a informação sobrevive à leitura sem cor.
- **SC-003**: Um painel que mede um período **anterior** a uma saída mostra
  **exatamente o mesmo número** antes e depois de a saída ser registrada.
- **SC-004**: **100%** das tentativas de fechar ciclo na composição são
  recusadas, incluindo ciclos de comprimento 3 ou mais.
- **SC-005**: **Zero** linhas removidas fisicamente: toda operação de desfazer
  deixa registro com autor e razão, conferível por consulta.
- **SC-006**: Uma pessoa que saiu e voltou aparece com **dois períodos**
  distintos, e a soma do tempo dela na equipe não conta o intervalo em que
  esteve fora.

#### Emenda de 2026-09-06

- **SC-007**: Após uma coleta, **100%** das participações observadas em times do
  GitHub têm vínculo vigente na plataforma, e **zero** delas requerem confirmação
  para contar como membro — verificável comparando, por time, a lista de membros
  da origem com os vínculos observados vigentes.
- **SC-008**: Após a migração, as **8** equipes da `leds-conectafapes` têm ao
  menos um vínculo vigente e `structure.ap02.team_with_no_members` deixa de
  disparar para todas; as **838** solicitações dos últimos 56 dias cujos autores
  só tinham evidência deixam de estar fora de toda medida por falta de vínculo.
  **O valor pós-migração é medido, não presumido**: a aceitação inclui a consulta
  que o confirma.
- **SC-009**: **100%** dos vínculos observados têm papel nulo e início nulo
  enquanto ninguém declarar — zero preenchidos pela coleta. **Zero** vínculos com
  declaração criados, encerrados ou alterados por qualquer coleta posterior.

## Assumptions

- **Quem administra é quem declara.** O papel de administração já existe na
  plataforma (045/052), e esta feature não cria papel novo. Delegar a declaração
  a outros papéis é decisão futura.
- **A saída exige data.** Quando quem registra não souber o dia exato, a data de
  hoje é usada **e marcada como presumida** — ausência não vira zero, e presunção
  não vira fato.
- **Sem limite de profundidade** na composição, com o ciclo proibido. Limite
  arbitrário resolveria um problema que não existe.
- **O rollup de competências fica FORA.** A issue #397 pede a soma das
  competências pela hierarquia; ela depende desta feature e é outra entrega.
  Construir as duas juntas esconderia qual delas quebrou.
- **A coleta continua mandando no que ela vê.** Esta feature não altera equipe
  observada nem apaga o que o GitHub mostrou; ela acrescenta a camada declarada
  ao lado. *(Emendado em 2026-09-06: a coleta passa a **materializar** o que vê
  como vínculo observado — FR-013 — e a encerrá-lo quando deixa de ver — FR-015.
  O que ela continua não fazendo é tocar em declaração — FR-016.)*
- **Fora de escopo**: importar equipes de planilha, convidar pessoa que ainda não
  foi coletada, e notificar alguém sobre a entrada ou saída.
