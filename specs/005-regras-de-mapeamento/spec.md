# Feature Specification: Regras de mapeamento de tipo por organização

**Feature Branch**: `feature/005-regras-de-mapeamento`

**Created**: 2026-08-11

**Status**: Draft

**Input**: "coloque regras de mapeamento de issues por organização. Permita eu cadastrar as
regras de mapeamento para os tipos usando Regex. Por exemplo, posso falar que US é quando
xxxxxx, sendo uma expressão regex ou string simples. E tenha uma tela que identifique os
tipos não mapeados e permita criar os regex."

## O problema, medido

A coleta da feature 004 trouxe **4455 issues** de duas organizações. A tela de trabalho
mostra:

```
1015 promovidas
3440 NÃO promovidas
       3403  sem tipo na origem
         37  tipo desconhecido — Chore (17), Refactor (16), Hotfix (4)
```

**77% das issues não são promovidas a conceito nenhum.** Não é falha da coleta: é a
plataforma se recusando a chutar, e é o comportamento correto. O que falta é o caminho
para quem administra dizer o que aquelas issues são.

### As issues sem tipo declaram o tipo no título

Das 3403 sem tipo, **2911 começam com prefixo entre colchetes**:

```
[TASK] 1024   [Devops] 340   [Back-end] 256   [Front-end] 237   [Dados] 186
[FEATURE] 111 [QA] 97        [US] 60          [Backend] 57      [FIX] 57
[BUG] 51      [Front] 35
```

### E nem todo prefixo é tipo — é a distinção que decide esta feature

```
prefixo que é TIPO   1409   [TASK] [FEATURE] [US] [BUG] [FIX] [EPIC] [E2E] [STORY]
prefixo que é ÁREA   1274   [Devops] [Back-end] [Front-end] [Dados] [QA] [Infra]
```

`[TASK]` diz **o que** a issue é. `[Devops]` diz **quem** faz, ou em que área — e não diz
nada sobre o conceito.

Uma tela que listasse os prefixos por frequência e oferecesse "criar regra" para todos
empurraria a pessoa a mapear área como tipo. O backlog do produto passaria a ter 340 user
stories que são rótulos de equipe, e a medida de escopo mentiria sem avisar.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Começar com um catálogo pronto, e editá-lo (Priority: P1)

A pessoa que administra o tenant abre a tela de regras e **não encontra uma lista vazia**:
encontra um catálogo de regras já escritas para os padrões usuais — `[TASK]`, `[FEATURE]`,
`[US]`, `[BUG]`, `[FIX]`, `Chore`, `Refactor`, `Hotfix` — cada uma com o conceito de
destino proposto e a contagem de issues que casaria **naquela organização**.

Ela revisa, ajusta o que discorda, ativa em bloco o que concorda, e ignora o resto.

**Why this priority**: sem catálogo, a primeira sessão de quem administra é escrever oito
regras à mão para padrões que qualquer projeto usa. O catálogo transforma isso em revisar e
confirmar — e revisar é onde o julgamento humano de fato agrega.

**As regras do catálogo chegam PROPOSTAS, nunca ativas.** Ativá-las por padrão promoveria
1409 issues sem ninguém decidir, e a plataforma passaria a afirmar conceitos que ninguém
declarou. O catálogo economiza a **escrita**, não a **decisão**.

**Independent Test**: abrir a tela numa organização recém-conectada, conferir que o
catálogo aparece com a contagem real de cada padrão, que **nenhuma** issue está promovida
por regra ainda, e que ativar `[TASK]` promove exatamente as 1024.

**Acceptance Scenarios**:

1. **Dado** uma organização observada, **quando** o usuário abre a tela de regras,
   **então** vê o catálogo com o padrão, o conceito proposto e **quantas issues daquela
   organização** cada um casaria.
2. **Dado** o catálogo apresentado, **quando** o usuário não faz nada, **então**
   **nenhuma** issue é promovida por regra — proposta não é decisão.
3. **Dado** uma regra do catálogo, **quando** o usuário a ativa, **então** ela passa a
   valer para aquela organização, com **ele** como autor da decisão — nunca "sistema".
4. **Dado** uma regra do catálogo, **quando** o usuário a edita, **então** a alteração
   vale **só para a organização dele**, e o catálogo permanece como estava para as
   outras.
5. **Dado** uma regra editada pelo usuário, **quando** o catálogo mudar numa versão nova
   da plataforma, **então** a edição dele **não** é sobrescrita, e a tela mostra que a
   regra divergiu do catálogo.
6. **Dado** o catálogo, **quando** o usuário quer aceitar tudo, **então** existe **uma
   ação** que ativa as regras propostas de uma vez — com a prévia do total antes de
   confirmar.
7. **Dado** um padrão do catálogo que casa zero issues naquela organização, **quando** a
   tela é aberta, **então** ele aparece como **sem ocorrências aqui** em vez de sumir:
   pode casar o que a próxima coleta trouxer.

---

### User Story 2 - Mapear um tipo que a plataforma não reconhece (Priority: P1)

A pessoa que administra o tenant vê que 17 issues têm o tipo `Chore`, que nenhuma regra
reconhece. Ela declara que `Chore` é tarefa pretendida, vê **quantas issues isso afeta
antes de gravar**, e a classificação passa a valer sem nova coleta da origem.

**Why this priority**: é o caso mais simples e o mais seguro — o tipo foi **declarado na
origem**, e mapeá-lo não infere nada. Sem isso, corrigir a regra exige editar YAML no
repositório, o que quem administra o tenant não faz.

**Independent Test**: mapear `Chore` para tarefa pretendida, conferir que a prévia mostra
17 issues, gravar, e ver a contagem de tarefas pretendidas subir em 17 sem que nenhuma
coleta ocorra.

**Acceptance Scenarios**:

1. **Dado** um tipo não reconhecido com issues, **quando** o usuário abre a tela de
   regras, **então** ele aparece com o nome, a contagem e a organização — e nenhum
   conceito sugerido.
2. **Dado** que o usuário escolhe o conceito de destino, **quando** ele pede a prévia,
   **então** vê **quantas** issues a regra casaria e **uma amostra delas**, antes de
   gravar.
3. **Dado** a prévia conferida, **quando** o usuário grava, **então** a regra passa a
   valer para aquela organização, com autor e data.
4. **Dado** a regra gravada, **quando** a promoção é recalculada, **então** as issues
   afetadas ganham promoção nova, a anterior permanece consultável, e **nenhuma coleta à
   origem ocorre**.
5. **Dado** uma regra que o usuário quer desfazer, **quando** ele a desativa, **então** a
   promoção volta ao que a regra anterior dizia, e o histórico registra as duas decisões.

---

### User Story 3 - Resgatar issues sem tipo por padrão de título (Priority: P1)

A mesma pessoa vê que 1024 issues começam com `[TASK]` e não têm tipo na origem. Ela cria
uma regra dizendo que **título começando com `[TASK]`** é tarefa pretendida — por texto
simples ou por expressão regular — e as 1024 passam a ser promovidas.

**Why this priority**: é onde está o volume. Sem esta história, 3403 issues permanecem sem
conceito, e nenhuma medida de escopo do produto tem base.

**Independent Test**: criar a regra para `[TASK]`, conferir que a prévia mostra 1024 e que
`[Devops]` **não** é casada, gravar, e ver a contagem subir em 1024.

**Acceptance Scenarios**:

1. **Dado** uma organização com issues sem tipo, **quando** o usuário abre a tela,
   **então** vê os **padrões candidatos** agrupados, com a contagem de cada um.
2. **Dado** um padrão candidato, **quando** o usuário cria a regra, **então** pode
   escolher entre **igual a**, **começa com**, **contém** e **expressão regular** — e a
   escolha é explícita, nunca presumida.
3. **Dado** uma regra de título, **quando** ela promove uma issue, **então** a promoção
   registra que a evidência é **o título e não o tipo declarado**, e com que confiança.
4. **Dado** uma issue que tem tipo declarado **e** casa uma regra de título, **quando** a
   promoção ocorre, **então** o **tipo declarado vence** — regra de título só se aplica a
   quem não tem tipo.
5. **Dado** a regra `começa com [TASK]`, **quando** a prévia é calculada, **então**
   `[Devops] ...` **não** aparece entre as casadas.
6. **Dado** a regra `contém US`, **quando** o usuário pede a prévia, **então** ele vê que
   ela casa também títulos com `STATUS` e `DISCUSSÃO` — e pode corrigir antes de gravar.

---

### User Story 4 - Não mapear o que não é tipo (Priority: P2)

A pessoa vê que `[Devops]`, `[Back-end]` e `[QA]` aparecem entre os padrões mais
frequentes, e a tela **diz que eles provavelmente não são tipos** — são área ou equipe. Ela
os marca como "não é tipo", e eles deixam de aparecer como pendência.

**Why this priority**: é o que impede a feature de causar o dano que ela deveria evitar.
Sem esta história, a tela pressiona por mapear tudo, e 1274 issues viram conceito errado —
o que é pior que continuarem sem conceito.

**Independent Test**: marcar `[Devops]` como não é tipo, conferir que ele sai da lista de
pendências, que nenhuma issue foi promovida por causa disso, e que a decisão fica
registrada com autor.

**Acceptance Scenarios**:

1. **Dado** um padrão candidato que designa área ou equipe, **quando** o usuário o marca
   como **não é tipo**, **então** ele sai das pendências e **nenhuma promoção ocorre**.
2. **Dado** um padrão marcado como não é tipo, **quando** a coleta seguinte traz issues com
   ele, **então** elas continuam contadas como sem tipo, e **não** reaparecem como
   pendência nova.
3. **Dado** a decisão de não mapear, **quando** alguém a consulta, **então** consta quem
   decidiu e quando — a ausência de mapeamento passa a ser **declarada** em vez de
   pendente.

---

### Edge Cases

1. **Expressão regular que não compila.** O usuário digita `[TASK` sem fechar.
2. **Expressão que casa vazio** — `.*` ou `^` — e casaria **todas** as issues.
3. **Expressão catastroficamente lenta**, com aninhamento de quantificadores.
4. **Duas regras casam a mesma issue** — `começa com [TASK]` e `contém TASK`.
5. **Regra que casa zero issues** hoje, e passa a casar depois de uma coleta.
6. **Regra apontando para conceito que a estrutura contradiz** — mapear para épico uma
   issue sem partes.
7. **A mesma regra em duas organizações**, com resultados diferentes.
8. **Regra criada, promoção recalculada, e a coleta seguinte reobserva a issue** — a
   promoção por regra não pode ser perdida pela reobservação.
9. **Prefixo maiúsculo e minúsculo** — `[TASK]` e `[Task]` são o mesmo tipo para quem
   escreveu, e strings diferentes.
10. **Issue cujo título muda na origem** e deixa de casar a regra.
11. **Volume**: uma regra que reclassifica 3403 issues de uma vez.
12. **Regra criada por quem não é admin.**

## Requirements *(mandatory)*

### Functional Requirements

#### O catálogo

- **FR-038**: A plataforma DEVE trazer um **catálogo de regras pré-escritas** para os
  padrões usuais, declarado na base de conhecimento em YAML versionado — nunca embutido em
  código.
- **FR-039**: As regras do catálogo DEVEM chegar **propostas**, e NÃO DEVEM promover nada
  antes de alguém ativá-las. O catálogo economiza a escrita, não a decisão.
- **FR-040**: A tela DEVE mostrar, para cada regra do catálogo, **quantas issues daquela
  organização** ela casaria — o catálogo é o mesmo para todas, e o efeito é de cada uma.
- **FR-041**: Ativar uma regra do catálogo DEVE registrar **a pessoa** como autora da
  decisão, e nunca "sistema": o catálogo propôs, alguém decidiu.
- **FR-042**: Editar uma regra do catálogo DEVE criar uma versão **da organização**, sem
  alterar o catálogo nem afetar outras organizações.
- **FR-043**: Uma atualização do catálogo NÃO DEVE sobrescrever regra que a organização
  editou, e a tela DEVE mostrar que a regra **divergiu** do catálogo.
- **FR-044**: A plataforma DEVE oferecer **uma ação** para ativar todas as propostas de
  uma vez, com a prévia do total antes de confirmar.
- **FR-045**: Regra do catálogo que casa zero issues naquela organização DEVE aparecer
  como **sem ocorrências aqui**, e NÃO DEVE ser escondida.

#### A regra

- **FR-001**: A regra DEVE ser escopada **por organização observada**, e duas
  organizações DEVEM poder mapear o mesmo texto para conceitos diferentes.
- **FR-002**: A regra DEVE declarar **onde** procura: no **tipo declarado** ou no
  **título**. Nunca nos dois ao mesmo tempo, porque a força da evidência é diferente.
- **FR-003**: A regra DEVE declarar **como** compara, entre: `igual a`, `começa com`,
  `contém` e `expressão regular`. A escolha DEVE ser explícita — a plataforma NÃO DEVE
  presumir a forma a partir do texto digitado.
- **FR-004**: A regra DEVE declarar o **conceito de destino**, e ele DEVE ser um conceito
  existente na rede ontológica.
- **FR-005**: A regra DEVE registrar **quem** a criou e **quando**. Mapeamento é decisão,
  e decisão tem autor.
- **FR-006**: A regra DEVE poder ser desativada sem ser apagada, e a desativação DEVE
  recalcular a promoção das issues afetadas.
- **FR-007**: A comparação DEVE poder ser declarada **sensível ou insensível a
  maiúsculas**, com insensível como padrão — `[TASK]` e `[Task]` são a mesma intenção.

#### Precedência, e ela é visível

- **FR-008**: O **tipo declarado na origem** DEVE ter precedência sobre qualquer regra de
  título. Regra de título só se aplica a issue **sem** tipo.
- **FR-009**: Entre regras que casam a mesma issue, a ordem DEVE ser **determinística e
  visível**: a regra com **ordem menor** vence, e a ordem é atributo da regra.
- **FR-010**: A tela DEVE mostrar, para cada issue promovida por regra, **qual regra**
  decidiu.
- **FR-011**: Acrescentar uma regra NÃO DEVE alterar silenciosamente a classificação de
  issues que outra regra já decidia; quando isso for ocorrer, a prévia DEVE dizer
  **quantas** issues mudam de conceito.

#### Proveniência, e é o que o princípio III exige

- **FR-012**: A promoção por **tipo declarado** e a promoção por **inferência de título**
  DEVEM ser distinguíveis em consulta e na tela. As duas NÃO DEVEM aparecer como a mesma
  coisa.
- **FR-013**: A promoção por inferência de título DEVE registrar **confiança menor** que a
  promoção por tipo declarado, e a confiança DEVE ser consultável.
- **FR-014**: Toda promoção por regra DEVE registrar o **identificador e a versão da
  regra** que decidiu, de modo que a pergunta "por que esta issue foi classificada assim"
  tenha resposta depois de a regra mudar.
- **FR-015**: Uma medida derivada que some issues promovidas por tipo declarado e por
  inferência DEVE declarar essa composição. Somar sem declarar produz número que ninguém
  sabe interpretar.

#### O que a plataforma recusa

- **FR-016**: Expressão regular que não compila DEVE ser recusada na hora, com a posição
  do erro — e NÃO DEVE ser gravada.
- **FR-017**: Expressão que casa **string vazia** DEVE ser recusada: ela casaria todas as
  issues, e o efeito só apareceria depois de gravada.
- **FR-018**: A avaliação de cada expressão DEVE ter **limite de tempo**, e a expressão
  que o exceder DEVE ser recusada nomeando o limite.
- **FR-019**: Regra apontando para conceito que **um axioma da rede contradiz** DEVE ser
  recusada nomeando o axioma — mapear para épico não torna épico o que não tem partes.
- **FR-020**: Só pessoa com papel de administração DEVE poder criar, alterar ou desativar
  regra.

#### A prévia

- **FR-021**: Antes de gravar, a plataforma DEVE mostrar **quantas** issues a regra casa e
  **uma amostra** delas.
- **FR-022**: A prévia DEVE mostrar quantas issues **mudariam de conceito** — distinto de
  quantas passariam a ter conceito.
- **FR-023**: A prévia DEVE ser calculada sobre as issues **já coletadas**, sem consultar a
  origem.
- **FR-024**: A prévia de uma regra que casa **zero** issues DEVE dizer isso
  explicitamente, e a regra DEVE poder ser gravada de todo modo — ela pode casar o que a
  próxima coleta trouxer.

#### Recálculo sem recoleta

- **FR-025**: Gravar, alterar ou desativar regra DEVE recalcular a promoção das issues
  afetadas **sem consultar a origem**.
- **FR-026**: O recálculo DEVE gravar promoção **nova**, preservando a anterior — a
  vigente é a última, e o histórico responde o que valia antes.
- **FR-027**: O recálculo DEVE ser **idempotente**: executá-lo duas vezes sobre o mesmo
  estado NÃO DEVE produzir promoção nova na segunda vez.
- **FR-028**: A reobservação de uma issue numa coleta seguinte NÃO DEVE apagar a promoção
  que uma regra decidiu.

#### Onde a tela vive

- **FR-050**: A tela de regras DEVE viver **na tela de sincronização**, e não como página
  própria. Decisão da pessoa mantenedora em 2026-08-11.
- **FR-051**: A colocação DEVE respeitar o princípio X — a tela de sincronização responde
  "a coleta está funcionando", e as regras respondem "o que a plataforma entende". São
  perguntas diferentes, logo o mapeamento entra como **componente ou aba própria**, com
  cabeçalho próprio, e NÃO misturado ao relatório de execução.
- **FR-052**: O acesso DEVE partir da **organização** cuja coleta produziu a lacuna: a
  regra é por organização, e chegar nela por uma lista global obrigaria escolher a
  organização duas vezes.

#### A tela

- **FR-029**: A tela DEVE listar, por organização, os **tipos declarados não
  reconhecidos**, com nome e contagem.
- **FR-030**: A tela DEVE listar os **padrões candidatos de título** das issues sem tipo,
  agrupados, com a contagem de cada um.
- **FR-031**: A tela DEVE **distinguir padrão que provavelmente é tipo de padrão que
  provavelmente é área ou equipe**, e a distinção DEVE ser apresentada como sugestão a
  conferir — nunca como classificação automática.
- **FR-032**: A tela DEVE permitir marcar um padrão como **não é tipo**, e o marcado DEVE
  sair das pendências sem gerar promoção.
- **FR-033**: A tela DEVE mostrar as regras vigentes, na ordem em que são aplicadas, com
  quantas issues cada uma promove hoje.
- **FR-034**: A tela DEVE mostrar quanto do total ainda **não** tem conceito, para que o
  progresso seja legível sem virar meta.
- **FR-035**: Nenhuma tela DEVE exibir dado de outro tenant, e a consulta a recurso de
  outro tenant DEVE responder "não encontrado".

#### Herança da feature 004

- **FR-036**: Esta feature **substitui** `tool_concept_mappings`, especificada na feature
  004 como fases T043 a T046 e **não implementada**. As duas NÃO DEVEM coexistir: um
  mapeamento por igualdade de nome é o caso particular de `igual a` desta feature.
- **FR-037**: O mapeamento **campo de quadro → atributo da ontologia**, também previsto na
  004, permanece fora desta feature: campo configurável não é tipo de issue, e a
  correspondência por texto não se aplica a ele.

### Key Entities

- **Regra de mapeamento**: pertence a uma organização observada. Guarda onde procura (tipo
  ou título), como compara, o texto ou a expressão, o conceito de destino, a ordem, se está
  ativa, a sensibilidade a maiúsculas, o autor e a data.
- **Padrão não mapeado**: agrupamento derivado das issues sem conceito — o texto candidato,
  a contagem, e se já foi marcado como "não é tipo".
- **Decisão de não mapear**: registro de que um padrão **não** designa tipo, com autor e
  data. Transforma pendência em ausência declarada.
- **Promoção por regra**: a promoção existente da feature 004, acrescida da regra que
  decidiu, da fonte da evidência — tipo declarado ou título — e da confiança.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de mapear os tipos declarados não reconhecidos, nenhuma issue com
  tipo declarado permanece sem conceito.
- **SC-002**: Uma regra de título com `começa com [TASK]` promove exatamente as issues cujo
  título começa com esse texto — e nenhuma que apenas o contenha.
- **SC-003**: Nenhuma issue com tipo declarado é classificada por regra de título.
- **SC-004**: 100% das promoções por regra registram a regra, a versão, a fonte da
  evidência e a confiança.
- **SC-005**: A promoção por inferência de título é distinguível da promoção por tipo
  declarado em toda consulta e em toda tela onde as duas apareçam.
- **SC-006**: Nenhuma expressão regular inválida, que case vazio, ou que exceda o limite de
  tempo é gravada.
- **SC-007**: A prévia mostra a mesma contagem que o recálculo produz — a diferença entre
  as duas é zero.
- **SC-008**: Gravar uma regra não gera nenhuma requisição à origem.
- **SC-009**: Executar o recálculo duas vezes sobre o mesmo estado produz a mesma
  quantidade de promoções vigentes.
- **SC-010**: Nenhum padrão marcado como "não é tipo" reaparece como pendência depois de
  uma coleta nova.
- **SC-011**: A ordem de aplicação das regras é a mesma em duas execuções sobre o mesmo
  conjunto.
- **SC-012**: Nenhuma promoção por regra é perdida quando a issue é reobservada.
- **SC-013**: Um usuário sem papel de administração não cria, altera nem desativa regra por
  nenhum caminho.
- **SC-014**: Um usuário de um tenant não alcança regra, padrão nem promoção de outro
  tenant por nenhum caminho.
- **SC-015**: Numa organização recém-conectada, o catálogo aparece com contagem por padrão
  e **zero** issues promovidas por regra.
- **SC-016**: Nenhuma regra do catálogo promove issue sem ter sido ativada por uma pessoa,
  e toda ativação tem autor.
- **SC-017**: Uma regra editada pela organização permanece como ela a deixou depois de o
  catálogo mudar, e a divergência é visível.

## Assumptions

- **O prefixo entre colchetes é o padrão candidato mais frequente**, mas não o único: a
  tela também agrupa a primeira palavra seguida de separador, porque 52 issues começam com
  "Criar" e 13 com "Testar". Nenhum dos dois é sugerido como tipo automaticamente.
- **O catálogo inicial cobre os padrões medidos no dado real** — `[TASK]`, `[FEATURE]`,
  `[US]`, `[BUG]`, `[FIX]`, `[EPIC]`, `[E2E]` — mais os tipos declarados que apareceram
  como desconhecidos: `Chore`, `Refactor`, `Hotfix`. Ele cresce por commit revisável na
  base de conhecimento, não por formulário.
- **A sugestão de "provavelmente é área" parte de uma lista conhecida** — Devops, Back-end,
  Front-end, Dados, QA, Infra — declarada na base de conhecimento e revisável, não
  embutida em código. Ela é sugestão a conferir, e a pessoa decide.
- **A confiança da inferência por título é menor que a do tipo declarado**, e não é
  numérica: são níveis declarados, como o resto da base de conhecimento já usa.
- **O recálculo é síncrono para volumes pequenos e assíncrono para grandes.** O limite é
  decisão do plano; a spec exige apenas que a pessoa saiba quando terminou.
- **Regex é avaliada no servidor sobre texto já coletado.** Nenhuma regra é aplicada
  durante a coleta: promover na coleta faria uma regra nova exigir recoleta.

## Dependencies

- Feature 004 — issues coletadas, promoção append-only com regra e versão, e a tela de
  trabalho que expõe a lacuna. Sem ela não há o que mapear.
- Base de conhecimento — a regra de roteamento global e a do tenant continuam sendo o
  padrão do qual a configuração parte.

## Out of Scope

| Fora | Por quê |
|---|---|
| Mapear campo de quadro para atributo | campo configurável não é tipo de issue; a correspondência por texto não se aplica |
| Sugerir conceito automaticamente por semelhança de nome | é o antipadrão que o princípio I proíbe: `[Front-end]` não é conceito, e `[TASK]` só é tarefa porque alguém declarou |
| Aprender a regra a partir de correções | exigiria histórico de correção e um modelo; e um mapeamento inferido de inferência não tem como ser auditado |
| Aplicar regra durante a coleta | faria regra nova exigir recoleta, e o payload preservado existe para não exigir |
| Regra sobre corpo da issue, comentários ou labels | outra fonte de evidência, com outra força; label em particular é texto livre e merece decisão própria |
