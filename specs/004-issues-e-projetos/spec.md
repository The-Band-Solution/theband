# Feature Specification: Issues e projetos das organizações observadas

**Feature Branch**: `feature/004-issues-e-projetos`

**Created**: 2026-08-10

**Status**: Draft

**Input**: "especifique buscar as issues de cada repositorio e projetos"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber quais issues existem, e o que elas são (Priority: P1)

A pessoa que administra o tenant já conectou uma organização e vê pessoas e
equipes. Agora ela quer ver o **trabalho**: as issues dos repositórios daquela
organização, cada uma classificada pelo que a estrutura mostra — épico, user
story, tarefa pretendida ou defeito — e, junto delas, **o que não foi
classificado e por quê**.

**Why this priority**: é o pedido, e é o que desbloqueia tudo que a SRO promete.
Sem issues não há user story, sem user story não há backlog, e sem backlog
nenhuma das 37 questões de competência da SRO sobre escopo tem resposta.

**Independent Test**: coletar uma organização com repositórios reais e conferir
que cada issue aparece com o conceito para o qual foi promovida, que as não
promovidas aparecem contadas com o motivo, e que a contagem das duas somadas
bate com o total de issues do GitHub.

**Acceptance Scenarios**:

1. **Dado** uma organização observada com repositórios, **quando** a coleta de
   issues ocorre, **então** cada repositório visível pela credencial é registrado
   como repositório de código observado, com a organização de origem.
2. **Dado** uma issue de tipo `Bug`, **quando** ela é coletada, **então** é
   promovida a defeito, e a proveniência registra a regra e a versão dela que
   decidiu.
3. **Dado** uma issue de tipo `Feature` **sem** sub-issues, **quando** ela é
   coletada, **então** é promovida a user story atômica.
4. **Dado** uma issue de tipo `Feature` **com** sub-issues que também são user
   stories, **quando** ela é coletada, **então** é promovida a épico — a
   estrutura vence o rótulo.
5. **Dado** uma issue de tipo `Epic` **sem** sub-issues, **quando** ela é
   coletada, **então** é promovida a user story atômica **e a divergência entre o
   tipo declarado e o conceito derivado fica registrada**, porque não existe
   épico sem partes.
6. **Dado** uma issue de tipo `User Story` cujas sub-issues são todas do tipo
   `Task`, **quando** ela é coletada, **então** permanece user story atômica: as
   tarefas a **atendem**, não a compõem.
7. **Dado** uma issue sem tipo, ou com tipo que nenhuma rota reconhece, **quando**
   ela é coletada, **então** o payload é preservado, **nada é promovido**, e ela
   é contada como lacuna com o nome do tipo encontrado.
8. **Dado** uma coleta concluída, **quando** o usuário abre a tela de issues,
   **então** vê o total coletado, o total promovido por conceito, o total não
   promovido por motivo, e as divergências entre tipo declarado e derivado.

---

### User Story 2 - Enxergar os projetos e o que cada item carrega (Priority: P2)

A mesma pessoa quer ver os projetos (Projects v2) da organização, quais itens
estão em cada um, e que valores os campos configuráveis do projeto carregam —
prioridade, estimativa, iteração — sabendo **quais desses campos a plataforma
consegue interpretar e quais ela apenas guarda**.

**Why this priority**: o projeto é o que dá ordem e recorte temporal ao trabalho.
Sem ele as issues são uma lista sem prioridade e sem sprint. Depende de US1
existir: um item de projeto aponta para uma issue.

**Independent Test**: coletar um projeto real, conferir que seus itens apontam
para as issues já coletadas, que os campos configurados aparecem com o valor de
cada item, e que um campo sem mapeamento declarado aparece como guardado e não
interpretado.

**Acceptance Scenarios**:

1. **Dado** uma organização observada com quadros, **quando** a coleta ocorre,
   **então** cada quadro aparece com nome, número e organização de origem, **como
   artefato de fonte** — e não como projeto, porque quadro é planejamento e
   visualização, não empreendimento.
2. **Dado** um projeto com itens, **quando** a coleta ocorre, **então** cada item
   que referencia uma issue já coletada aponta para ela, e nenhum item duplica a
   issue.
3. **Dado** um campo configurável **com** mapeamento declarado para um atributo
   da ontologia, **quando** o item tem valor nele, **então** o atributo é
   preenchido com a proveniência do campo de origem.
4. **Dado** um campo configurável **sem** mapeamento declarado, **quando** o item
   tem valor nele, **então** o valor é guardado e exibido como **não
   interpretado** — nunca convertido por adivinhação.
5. **Dado** um projeto **sem** campo de importância numérica, **quando** o
   usuário consulta a ordem do backlog, **então** a ausência é declarada na tela,
   e nenhuma ordem é inventada a partir de outro campo.
6. **Dado** uma iteração que **já começou**, **quando** a coleta ocorre, **então**
   ela é promovida a sprint, com proveniência de derivação.
7. **Dado** uma iteração cuja data de início ainda **não chegou**, **quando** a
   coleta ocorre, **então** ela é promovida a **processo pretendido** e **não** a
   sprint — é um planejamento que não foi feito, e intenção não é ocorrência.
8. **Dado** um item de projeto **sem** iteração atribuída, **quando** o usuário
   consulta o produto, **então** ele aparece como product backlog, que é
   exatamente o que "sem iteração" significa.
9. **Dado** itens atribuídos a uma iteração já iniciada, **quando** o usuário
   consulta aquele sprint, **então** eles aparecem como o sprint backlog dele — e
   nenhum item aparece nos dois conjuntos.

---

### User Story 3 - Ver e ajustar como os tipos da organização são mapeados (Priority: P2)

A pessoa que administra o tenant abre uma tela que mostra **os tipos de issue que a
organização de fato usa**, para qual conceito cada um é roteado, e o que a estrutura
decide em vez do rótulo. A mesma tela mostra os campos do quadro e quais deles a
plataforma interpreta.

Quando um tipo não é reconhecido, a tela é onde ela declara o que ele significa.

**Why this priority**: a regra de roteamento tem `status: proposed` e `confidence:
medium` — ela **vai** errar, e errar em silêncio é o que a US1 evita mostrando a
lacuna. Esta tela é o outro lado: sem ela, corrigir a regra exige editar YAML no
repositório, e quem administra o tenant não faz isso. A lacuna ficaria visível e
inendereçável.

**Independent Test**: abrir a tela numa organização que usa `Feature`, `Task` e
`Bug`, conferir que os três aparecem com o conceito de destino, que `Epic` e
`User Story` aparecem como **não usados por esta organização** em vez de ausentes, e
que declarar um tipo desconhecido faz a coleta seguinte deixar de contá-lo como
lacuna.

**Acceptance Scenarios**:

1. **Dado** uma organização observada, **quando** o usuário abre a tela de
   mapeamento, **então** vê os tipos de issue **que a organização usa**, com a
   contagem de issues de cada um e o conceito para o qual é roteado.
2. **Dado** um tipo da regra global que a organização não usa — `Epic`,
   `User Story` —, **quando** o usuário abre a tela, **então** ele aparece marcado
   como **não usado aqui**, e não como erro nem como ausência.
3. **Dado** o tipo `Feature`, **quando** o usuário vê a linha dele, **então** a tela
   mostra que ele roteia para **dois** conceitos e que **a estrutura decide qual** —
   com partes que são user stories é épico, sem partes ou com partes que são tarefas
   é atômica.
4. **Dado** um tipo desconhecido contado como lacuna, **quando** o usuário declara
   para qual conceito ele vai, **então** a declaração é gravada com autor e data, e a
   coleta seguinte o promove — deixando de contá-lo como lacuna.
5. **Dado** uma declaração do usuário que contraria um axioma — por exemplo mapear
   um tipo para `sro.epic` sem exigir partes —, **quando** ele tenta salvar,
   **então** a plataforma recusa nomeando o axioma, e não grava.
6. **Dado** os campos do quadro, **quando** o usuário abre a tela, **então** vê
   quais estão mapeados para atributo da ontologia e quais não, com o motivo de cada
   não mapeado.
7. **Dado** que o usuário quer mapear `Priority` para `importance`, **quando** ele
   tenta, **então** a plataforma **recusa** e explica: importance é decimal com
   escala declarada, `Priority` é seleção única cujos valores o tenant inventou.
8. **Dado** uma declaração gravada pela tela, **quando** alguém a consulta,
   **então** a proveniência diz que veio de decisão do tenant, com quem e quando —
   nunca de observação.

---

### User Story 4 - Restringir quais repositórios são observados (Priority: P3)

A pessoa que administra o tenant vê que a organização tem repositórios que não
interessam — arquivados, forks, experimentos — e quer excluí-los da coleta sem
desconectar a organização.

**Why this priority**: é otimização de volume e de ruído, não de correção. Sem
ela a coleta funciona e traz demais; com ela a coleta traz o que interessa. O
padrão de coletar tudo precisa existir primeiro, para haver o que restringir.

**Independent Test**: excluir um repositório da observação, rodar a coleta, e
conferir que as issues dele não são coletadas nem marcadas como ausentes — a
plataforma parou de olhar, e isso não é o mesmo que ter sumido.

**Acceptance Scenarios**:

1. **Dado** uma organização com repositórios observados, **quando** o usuário
   exclui um deles, **então** a coleta seguinte não o consulta.
2. **Dado** um repositório excluído da observação, **quando** a coleta ocorre,
   **então** as issues dele **não** são marcadas como não mais observadas — a
   causa é decisão do tenant, e é registrada como tal.
3. **Dado** um repositório arquivado no GitHub, **quando** a coleta ocorre,
   **então** ele continua observado e as issues dele continuam consultáveis, com
   a marca de arquivado — arquivar não é apagar.
4. **Dado** um repositório que se tornou privado ou inacessível pela credencial,
   **quando** a coleta ocorre, **então** a coleta **não** marca as issues dele
   como ausentes, e a ferramenta passa a exigir atenção nomeando o repositório
   inacessível.

---

### Edge Cases

1. **Ciclo de sub-issues** — A ganha B como parte, e B ganha A. O grafo de
   decomposição precisa ser acíclico (`sro.rule04`), e um ciclo faz a
   classificação épico/atômica não convergir.
2. **Issue movida entre repositórios.** O GitHub preserva o número na origem e
   cria outro no destino. A identidade é o identificador global, não o número.
3. **Issue de repositório fora da organização observada aparece como sub-issue.**
   A parte está fora do escopo, mas a relação existe.
4. **Duas organizações observadas com projetos que compartilham a mesma issue.**
   Projects v2 aceita itens de qualquer repositório que a pessoa alcance.
5. **Projeto de usuário, não de organização.** Existe e pode conter issues da
   organização observada.
6. **Item de projeto que é rascunho**, sem issue por trás.
7. **Campo configurável renomeado entre duas coletas.** O identificador do campo
   permanece, o nome muda.
8. **Iteração excluída da configuração do projeto** depois de ter tido itens.
9. **Repositório sem nenhuma issue.** Distinguir "coletado e vazio" de "não
   coletado" é o que impede alguém de concluir que o time não trabalha.
10. **Volume**: organização com dezenas de repositórios e milhares de issues,
    contra um limite de consumo por janela de tempo.
11. **Tipo de issue criado pela organização com nome próprio** — `Spike`,
    `Chore`, `Débito` — que nenhuma rota global reconhece.
12. **A mesma issue promovida a conceitos diferentes em duas coletas**, porque
    ganhou ou perdeu sub-issues no intervalo.

## Requirements *(mandatory)*

### Functional Requirements

#### Descoberta e escopo

- **FR-001**: A plataforma DEVE descobrir os repositórios de cada organização
  observada a partir da própria organização, sem exigir que o usuário conecte
  cada repositório.
- **FR-002**: Cada repositório descoberto DEVE ser registrado com a organização
  de origem, e a proveniência DEVE permitir dizer por qual ferramenta conectada
  ele foi observado.
- **FR-003**: A plataforma DEVE registrar, para cada repositório, se ele está
  arquivado na origem, e MANTER consultáveis as issues de repositório arquivado.
- **FR-004**: A plataforma DEVE permitir excluir um repositório da observação sem
  desconectar a organização.
- **FR-005**: A exclusão de um repositório da observação NÃO DEVE marcar as
  issues dele como não mais observadas; a causa DEVE ser registrada como decisão
  do tenant, distinta de ausência na origem.
- **FR-006**: Quando um repositório antes acessível se tornar inacessível pela
  credencial, a coleta NÃO DEVE marcar as issues dele como ausentes, e DEVE
  registrar o repositório inacessível como motivo de atenção da ferramenta.

#### Coleta de issues

- **FR-007**: A plataforma DEVE coletar as issues de cada repositório observado,
  preservando o payload bruto de cada uma para reprocessamento.
- **FR-008**: Cada issue DEVE ser identificada pela Application Reference —
  sistema de origem, instância e identificador externo global — e NUNCA pelo
  número dentro do repositório.
- **FR-009**: Duas coletas idênticas NÃO DEVEM produzir registros duplicados nem
  alterar a contagem de nada.
- **FR-010**: A marca de "não mais observado" para issues DEVE ser escopada pelo
  **repositório** coletado, nunca pelo tenant nem apenas pela organização.
- **FR-011**: A coleta DEVE registrar, por repositório, quantas issues foram
  encontradas, quantas promovidas e quantas não promovidas.

#### Promoção e classificação

- **FR-012**: A promoção de uma issue a um conceito da rede DEVE seguir a regra
  de roteamento versionada na base de conhecimento, e a proveniência DEVE
  registrar qual regra e qual versão dela decidiu.
- **FR-013**: Quando o tipo declarado e a estrutura divergirem, a **estrutura
  DEVE vencer**, e a divergência DEVE ser registrada com o conceito declarado, o
  conceito derivado e o motivo.
- **FR-014**: Uma issue cujo tipo é nulo, ou cujo nome de tipo nenhuma rota
  reconhece, NÃO DEVE ser promovida a nenhum conceito; o payload DEVE ser
  preservado e a issue DEVE ser contada como lacuna, com o nome do tipo
  encontrado.
- **FR-015**: A classificação entre épico e user story atômica DEVE ser
  **derivada da existência de partes**, e NUNCA gravada como valor escolhido por
  quem coleta.
- **FR-016**: Sub-issues do tipo tarefa NÃO DEVEM tornar épica a issue que as
  contém: tarefa **atende** user story, não a compõe.
- **FR-017**: Um vínculo de composição que fecharia um ciclo na decomposição DEVE
  ser recusado, e a recusa DEVE nomear o caminho que fecha o ciclo. As issues
  envolvidas permanecem coletadas.
- **FR-018**: Um vínculo de composição cuja parte está em repositório fora do
  escopo observado DEVE ser registrado como referência externa, sem promover a
  parte.
- **FR-019**: A mesma issue promovida a conceitos diferentes em coletas distintas
  DEVE registrar a mudança, e a classificação vigente DEVE ser a da última
  coleta.

#### Projetos

- **FR-020**: A plataforma DEVE coletar os quadros (Projects v2) das organizações
  observadas, com nome, número e organização de origem, como **artefato de fonte**.
  O quadro é **planejamento** — uma forma de organizar as issues e seus estados, e
  uma forma de visualização —, e NÃO DEVE ser promovido a nenhum conceito.
- **FR-020a**: O que o quadro CONTÉM é que promove: iterações iniciadas viram
  sprints, iterações futuras viram processos pretendidos, e a atribuição de iteração
  separa os dois backlogs. Nenhuma consulta DEVE tratar o quadro como
  empreendimento.
- **FR-021**: A plataforma DEVE coletar os itens de cada projeto e ligá-los às
  issues já coletadas, sem duplicar a issue.
- **FR-022**: Um item de projeto que não referencia issue — rascunho — DEVE ser
  registrado como item sem trabalho associado, e NÃO DEVE ser promovido a nenhum
  conceito de escopo.
- **FR-023**: A plataforma DEVE coletar a **definição** dos campos configuráveis
  de cada projeto e o **valor** de cada campo em cada item.
- **FR-024**: O mapeamento entre campo configurável e atributo da ontologia DEVE
  ser declarado na base de conhecimento, por tenant, e NUNCA inferido do nome do
  campo.
- **FR-025**: Um campo sem mapeamento declarado DEVE ter o valor guardado e
  exibido como **não interpretado**.
- **FR-026**: Quando o projeto não tiver campo mapeado para um atributo da
  ontologia, esse atributo DEVE permanecer vazio e a ausência DEVE ser exibida
  como limitação — nenhum outro campo DEVE ser usado como substituto.
- **FR-027**: A identidade de um campo configurável DEVE ser o identificador do
  campo, e não o nome, de modo que renomear não crie um campo novo.
- **FR-028**: A coleta de projeto DEVE trazer projeto, campos, itens e valores de
  campo dos itens, e NÃO DEVE trazer o histórico de alterações dos itens.

#### Iterações e sprint

- **FR-029**: Uma iteração cuja data de início já passou DEVE ser promovida a
  sprint, com proveniência de derivação declarando que a origem é configuração de
  projeto.
- **FR-030**: Uma iteração cuja data de início ainda não chegou NÃO DEVE ser
  promovida a sprint; DEVE ser promovida a **processo pretendido**, porque é um
  planejamento que não foi feito.
- **FR-030a**: Quando a coleta seguinte encontrar a iteração já iniciada, ela DEVE
  passar de pretendida a sprint — mesma identidade externa, registro novo. A
  transição ocorre na **coleta**, nunca no instante do início: a plataforma afirma
  o que observou.
- **FR-031**: Uma iteração removida da configuração do projeto depois de ter tido
  itens DEVE permanecer consultável, marcada como não mais presente na origem.
- **FR-032**: O conjunto dos itens de um projeto **sem** iteração atribuída DEVE
  ser consultável como product backlog. A ausência de iteração é o que o define —
  não um campo separado.
- **FR-032a**: O conjunto dos itens atribuídos a uma iteração **já iniciada** DEVE
  ser consultável como o sprint backlog daquele sprint.
- **FR-032b**: A composição dos dois conjuntos DEVE ser **derivada da atribuição de
  iteração**, e NUNCA gravada como pertencimento escolhido por quem coleta — pelo
  mesmo motivo que a classificação épico/atômica é derivada das partes.

#### Mapeamento declarado pelo tenant

- **FR-041**: A plataforma DEVE apresentar, por organização observada, os tipos de
  issue **que ela de fato usa**, com a contagem de cada um e o conceito de destino.
- **FR-042**: Um tipo previsto pela regra global e **não usado** pela organização
  DEVE aparecer como *não usado aqui*, distinto de erro e de ausência de
  configuração.
- **FR-043**: Para tipo que roteia para mais de um conceito, a tela DEVE dizer que
  **a estrutura decide**, e qual estrutura decide o quê.
- **FR-044**: A pessoa autorizada DEVE poder declarar o conceito de destino de um
  tipo desconhecido, e a declaração DEVE ser gravada com autor, data e proveniência
  de decisão do tenant.
- **FR-045**: A plataforma DEVE recusar declaração que contrarie um axioma da rede,
  nomeando o axioma — e NÃO DEVE gravá-la.
- **FR-046**: A plataforma DEVE recusar mapear campo de seleção única para atributo
  numérico da ontologia, explicando a diferença de escala.
- **FR-047**: A tela DEVE apresentar os campos do quadro separados em interpretados
  e não interpretados, com o motivo de cada não interpretado.
- **FR-048**: Uma declaração feita pela tela DEVE ter o mesmo efeito que a declarada
  em YAML versionado, e DEVE ser distinguível dela pela proveniência.

#### Tela

- **FR-033**: A plataforma DEVE apresentar, por organização observada, os
  repositórios, o total de issues coletadas e o total promovido por conceito.
- **FR-034**: A tela DEVE apresentar **o que não foi promovido**, agrupado por
  motivo, com o nome do tipo encontrado quando o motivo for tipo desconhecido.
- **FR-035**: A tela DEVE apresentar as divergências entre tipo declarado e
  conceito derivado, porque elas são o sinal de épico abandonado sem decomposição
  ou de user story que virou épico sem retipagem.
- **FR-036**: A tela DEVE distinguir repositório coletado e sem issues de
  repositório não coletado.
- **FR-037**: Nenhuma tela DEVE exibir dado de outro tenant, e a consulta a um
  recurso de outro tenant DEVE responder "não encontrado".

#### Consumo da origem

- **FR-038**: A coleta DEVE respeitar o limite de consumo da origem, pausando
  antes de estourá-lo, e DEVE poder ser retomada do ponto onde parou.
- **FR-039**: A coleta interrompida por limite de consumo DEVE preservar o
  progresso parcial, e a retomada NÃO DEVE recoletar o que já foi coletado.
- **FR-040**: Quando a organização não usa projetos, a coleta de projetos DEVE
  terminar declarando isso, e NÃO DEVE parecer uma coleta vazia por falha.

### Key Entities

- **Repositório observado**: repositório de código de uma organização observada.
  Guarda a organização de origem, se está arquivado, e se o tenant decidiu
  excluí-lo da observação. Corresponde a `cmpo.source_repository`.
- **Issue coletada**: o registro bruto e preservado de uma issue, com a
  Application Reference, o tipo declarado na origem, o vínculo com o repositório
  e o momento da última observação.
- **Promoção**: a ligação entre uma issue coletada e o conceito da rede para o
  qual ela foi promovida — épico, user story atômica, tarefa pretendida ou
  defeito — com a regra e a versão que decidiram, e a divergência quando houver.
- **Vínculo de decomposição**: a relação entre uma issue e suas partes, que
  decide épico contra atômica. Guarda também os vínculos recusados, com o motivo.
- **Projeto observado**: projeto de uma organização observada, com nome, número e
  origem.
- **Definição de campo**: um campo configurável de um projeto, identificado pelo
  identificador e não pelo nome, com o tipo e as opções quando houver.
- **Valor de campo do item**: o valor que um item carrega em um campo, com a
  indicação de ter sido interpretado por mapeamento declarado ou apenas guardado.
- **Iteração observada**: uma iteração da configuração do projeto, com início e
  duração, e a indicação de já ter começado — o que decide a promoção a sprint.
- **Lacuna de promoção**: contagem por motivo do que foi coletado e não
  promovido, com o nome do tipo encontrado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para cada repositório observado, a soma de issues promovidas e não
  promovidas é igual ao total de issues coletadas — nenhuma issue desaparece
  entre a coleta e a classificação.
- **SC-002**: Duas coletas seguidas sem mudança na origem produzem contagens
  idênticas de issues, promoções, projetos, itens e valores de campo.
- **SC-003**: Nenhuma issue de repositório que não foi coletado nesta execução é
  marcada como não mais observada.
- **SC-004**: 100% das issues promovidas têm registrada a regra e a versão que
  decidiram a promoção.
- **SC-005**: Nenhuma issue com tipo desconhecido ou ausente aparece promovida a
  qualquer conceito, e todas aparecem contadas na lacuna, com o nome do tipo.
- **SC-006**: Nenhum épico registrado está sem partes, e nenhuma folha da
  decomposição é épico.
- **SC-007**: Nenhum ciclo existe na decomposição, e cada vínculo recusado por
  ciclo aparece com o caminho que o fechava.
- **SC-008**: Nenhum valor de campo configurável sem mapeamento declarado aparece
  convertido em atributo da ontologia.
- **SC-009**: Nenhuma iteração com início no futuro aparece como sprint.
- **SC-009a**: Nenhum quadro observado aparece promovido a projeto, de software ou
  Scrum, por nenhum caminho.
- **SC-009c**: Toda iteração coletada tem exatamente um registro vigente — sprint
  se já começou, processo pretendido se não. Nenhuma tem os dois, nenhuma tem
  nenhum.
- **SC-009b**: A soma dos itens no product backlog e nos sprint backlogs de um
  projeto é igual ao total de itens dele — nenhum item fica em dois conjuntos nem
  fora dos dois.
- **SC-010**: A tela distingue, sem ambiguidade, repositório coletado e vazio de
  repositório não coletado.
- **SC-011**: Uma coleta interrompida pelo limite de consumo, ao ser retomada,
  não recoleta nenhuma página já coletada.
- **SC-012**: Um usuário de um tenant não alcança repositório, issue, projeto nem
  item de outro tenant por nenhum caminho.
- **SC-013**: Nenhum tipo de issue aparece na tela de mapeamento sem existir na
  organização ou sem estar marcado como não usado por ela.
- **SC-014**: Nenhuma declaração que contrarie axioma da rede é gravada, e a recusa
  nomeia o axioma.
- **SC-015**: Nenhum campo de seleção única aparece mapeado para atributo numérico
  da ontologia.

## Assumptions

- **Todos os repositórios visíveis pela credencial entram na observação por
  padrão.** A alternativa — escolher repositórios antes da primeira coleta —
  exigiria uma tela de seleção sobre dados que ainda não existem. Restringir é a
  US3, e só faz sentido depois de haver o que restringir.
- **A regra de roteamento por tipo de issue continua sendo a que já está
  versionada na base de conhecimento**, com `status: proposed` e confiança média.
  Esta feature a aplica e mede; corrigi-la é consequência do que a medição
  mostrar, e não pré-requisito.
- **Tipos de issue são configuráveis por organização.** A lista global reconhece
  os nomes usuais; cada tenant sobrescreve com os seus. Um tipo próprio não
  reconhecido não é erro da coleta — é lacuna declarada, e a US1 a torna visível.
- **Sub-issues são a única fonte de decomposição considerada.** Listas de tarefas
  em markdown não são lidas: seriam heurística sobre texto livre, e produziriam
  hierarquia plausível e errada.
- **O histórico de alterações dos itens de projeto fica de fora**, por custo de
  consumo. Ele responderia quando um item mudou de coluna ou de iteração, que é
  outra pergunta e merece decisão própria.
- **Projeto de usuário fica fora do escopo desta feature.** A plataforma observa
  organizações; um projeto pessoal que contém issues da organização observada
  aparece como referência não coletada.
- **A promoção usa a estrutura vigente na coleta.** Uma issue que ganha
  sub-issues entre duas coletas muda de classificação, e a mudança é registrada —
  não é retrofito do passado.

## Dependencies

- Feature 001 — ferramentas conectadas, credencial cifrada, coleta com
  checkpoint, payload bruto preservado e controle do limite de consumo.
- Feature 002 — escopo por organização: repositório e issue herdam a organização
  de origem.
- Feature 003 — ciclo de observação: uma ferramenta com observação encerrada não
  entra na coleta de issues nem de projetos.
- Base de conhecimento — regra de roteamento por tipo de issue, axiomas da SRO, e
  o modelo de informação derivado da SRO, que passou a existir no sprint 003.

## Out of Scope

| Fora | Por quê |
|---|---|
| Pull requests e commits | são a CMPO, e têm mapeamento próprio no backlog |
| Histórico de alterações de item de projeto | custo de consumo alto, e responde outra pergunta |
| Cerimônias, papéis e critérios de aceitação | o GitHub não os expõe; vêm de cadastro declarado ([#98](https://github.com/The-Band-Solution/theband/issues/98)) |
| Tarefa executada e entregável | exigem ligar issue a commit e a PR, que é a CMPO |
| Escrever de volta no GitHub | a plataforma observa; escrever é outra decisão |
| Projetos de usuário | a plataforma observa organizações |
| Promover quadro a projeto de software ou Scrum | quadro é planejamento e visualização; empreendimento vem de cadastro declarado |
| `sro.planning_meeting` a partir do quadro | o quadro é o resultado de planejar, não a cerimônia. Derivá-la afirmaria uma reunião que ninguém registrou |
