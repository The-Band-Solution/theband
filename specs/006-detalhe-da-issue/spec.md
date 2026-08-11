# Feature Specification: Detalhe da issue, e a decomposição navegável

**Feature Branch**: `feature/006-detalhe-da-issue`

**Created**: 2026-08-11

**Status**: Draft

**Input**: "ao clicar na issue quero ver todos os dados dela: descrição, developer, status,
tudo que o GitHub fornece, tudo salvo no banco. E ao clicar no repositório quero ver todas
as issues dele. Complementando: se for um EPIC devo ver as US e suas Tasks; e se for uma US
tenho que ver as Tasks."

## O que existe hoje, e o que falta

A feature 004 coletou 4455 issues e 135 repositórios, e a tela `/trabalho` mostra uma lista
com número, título, tipo e o conceito promovido. **Ela não mostra a issue.**

Falta o corpo, quem abriu, quem está designado, os rótulos, o marco, o estado de
fechamento, as datas — e falta o que dá sentido ao resto: **a decomposição**.

### A decomposição existe no dado, e são duas relações diferentes

```
#1     Coleta de pessoas e equipes…        →  3 user stories,  36 tarefas
#2237  [EPIC][M21] Gestão de Formulários   → 22 user stories,   0 tarefas
#79    Pessoas e equipes por organização   →  3 user stories,   5 tarefas
#1896  [EPIC] Gestão de Planejamento       →  7 user stories,   0 tarefas
```

**Um épico compõe-se de user stories.** Uma user story **é atendida por** tarefas. As duas
chegam pela mesma API — sub-issues —, e chamá-las de "filhas" na tela apagaria a distinção
que sustenta todo o resto:

| Relação | Conceito | Significa |
|---|---|---|
| `sro.epic_composed_of_user_story` | composição | a parte **é parte** do todo; o escopo do épico é a soma das partes |
| `sro.intended_task_planned_to_meet_user_story` | atendimento | a tarefa **serve** a história; o esforço dela não compõe escopo |

Somar as duas conta o esforço duas vezes — no épico e nas partes. É o que
`sro.rule07` proíbe.

### E o dado real já viola a regra

```
41  tarefas cujo pai é ÉPICO      sro.rule07: tarefa nunca atende épico diretamente
 3  tarefas SEM pai               sro.rule07: toda tarefa atende uma user story atômica
```

Isso não é erro da plataforma: é o que ela existe para mostrar. A issue `#1` tem 36 tarefas
penduradas nela sendo épico — e alguém precisa ver isso para decidir se decompõe melhor ou
se aquelas tarefas pertencem a outra história.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver tudo o que a plataforma sabe de uma issue (Priority: P1)

A pessoa clica numa issue da lista e vê **todos os dados dela**: o corpo, quem abriu, quem
está designado, os rótulos, o marco, o estado com o motivo de fechamento, as datas, e o
projeto em que ela aparece.

Vê também o que **a plataforma decidiu**: o conceito para o qual foi promovida, a regra e a
versão que decidiram, a divergência se houver, e a lacuna se não foi promovida.

**Why this priority**: é o pedido, e é o que fecha a tela de trabalho. Uma lista que não
abre é um índice de coisas que não se pode consultar.

**Independent Test**: abrir a issue `#1` e conferir que o corpo, o autor, o estado
`fechada como concluída`, as datas e o conceito promovido aparecem — e que o número de
sub-issues bate com o que a API diz.

**Acceptance Scenarios**:

1. **Dado** uma issue coletada, **quando** o usuário a abre, **então** vê corpo, autor,
   designados, rótulos, marco, estado, motivo de fechamento e as três datas — criação,
   atualização e fechamento.
2. **Dado** uma issue sem corpo, sem designado ou sem rótulo, **quando** ela é aberta,
   **então** cada ausência aparece como **ausência**, e nenhuma é preenchida com valor
   inventado.
3. **Dado** uma issue promovida, **quando** ela é aberta, **então** consta o conceito, a
   **regra** e a **versão** que decidiram, e se a evidência foi o tipo declarado.
4. **Dado** uma issue não promovida, **quando** ela é aberta, **então** consta o motivo e o
   **nome do tipo** encontrado, quando houver.
5. **Dado** uma issue promovida contra o rótulo declarado, **quando** ela é aberta,
   **então** a divergência aparece com o conceito declarado, o derivado e o motivo.
6. **Dado** o histórico de promoções, **quando** o usuário o consulta, **então** vê as
   decisões anteriores em ordem, e qual é a vigente.
7. **Dado** a issue na origem, **quando** o usuário quer conferir, **então** existe link
   para ela no GitHub — a plataforma não substitui a origem, ela a harmoniza.

---

### User Story 2 - Navegar a decomposição, com as duas relações separadas (Priority: P1)

Abrindo um **épico**, a pessoa vê as user stories que o compõem — e, dentro de cada uma, as
tarefas que a atendem. Abrindo uma **user story**, vê as tarefas que a atendem e o épico de
que ela faz parte. Abrindo uma **tarefa**, vê a história que ela atende.

As duas relações aparecem **separadas e nomeadas**, nunca numa lista única de "filhas".

**Why this priority**: é o complemento pedido, e é onde a ontologia deixa de ser
vocabulário e passa a mudar o que se vê. Uma lista única de filhas somaria composição com
atendimento, e a soma conta esforço duas vezes.

**Independent Test**: abrir `#1` e conferir que as 3 user stories aparecem como
**composição** e as 36 tarefas como **atendimento**, em seções distintas — e que a `#3`,
com nove sub-issues do tipo `Task`, aparece como user story atômica com nove tarefas
atendendo, não como épico.

**Acceptance Scenarios**:

1. **Dado** um épico, **quando** ele é aberto, **então** as user stories que o compõem
   aparecem em seção própria, com o conceito de cada uma.
2. **Dado** um épico, **quando** ele é aberto, **então** as tarefas que aparecem sob ele são
   mostradas em seção **distinta**, rotulada como atendimento, e **não** somadas às user
   stories.
3. **Dado** um épico, **quando** ele é aberto, **então** as tarefas **das** user stories
   dele aparecem aninhadas na história correspondente, e não soltas no épico.
4. **Dado** uma user story atômica, **quando** ela é aberta, **então** vê as tarefas que a
   atendem e, quando houver, **o épico de que ela é parte**.
5. **Dado** uma tarefa, **quando** ela é aberta, **então** vê a user story que ela atende, e
   pode navegar até ela.
6. **Dado** um épico com 22 user stories, **quando** ele é aberto, **então** a lista é
   navegável sem carregar as tarefas de todas de uma vez.
7. **Dado** uma issue sem decomposição, **quando** ela é aberta, **então** a ausência é
   declarada — distinta de "não foi coletada".

---

### User Story 3 - Ver o que viola a regra, na própria issue (Priority: P2)

Abrindo um épico com tarefas penduradas diretamente nele, a pessoa vê que aquilo **viola
`sro.rule07`** — tarefa nunca atende épico — com a explicação e a contagem. O mesmo para
tarefa sem pai.

**Why this priority**: o dado real tem 41 tarefas nessa situação e 3 sem pai. Mostrar isso
na issue é o que transforma "a plataforma classificou" em "o time pode decidir". Sem esta
história, a violação existe no banco e ninguém a encontra.

**Independent Test**: abrir `#1` e conferir que as 36 tarefas aparecem com o aviso de
`sro.rule07`, nomeando o axioma — e que a issue **continua** coletada e promovida, porque a
violação é do vínculo, não dela.

**Acceptance Scenarios**:

1. **Dado** um épico com tarefas ligadas diretamente, **quando** ele é aberto, **então** o
   aviso nomeia `sro.rule07` e explica por que ligar tarefa a épico conta esforço duas
   vezes.
2. **Dado** uma tarefa sem user story, **quando** ela é aberta, **então** o aviso diz que
   toda tarefa atende uma história atômica, e que esta não tem.
3. **Dado** a violação, **quando** ela é exibida, **então** a issue continua promovida e
   consultável: o que é inválido é o **vínculo**, não a issue.
4. **Dado** um vínculo recusado na coleta, **quando** a issue envolvida é aberta, **então**
   a recusa aparece com o motivo — e, no caso de ciclo, com o caminho.

---

### User Story 4 - Ver todas as issues de um repositório (Priority: P1)

A pessoa clica num repositório na tela de trabalho e vê **as issues dele** — com o conceito
de cada uma, o estado, e a contagem por conceito no cabeçalho.

**Why this priority**: é o outro pedido, e é o recorte que a lista de 4455 issues não
oferece. Um repositório de 19 issues é examinável; a lista inteira não.

**Independent Test**: abrir o repositório `theband` e conferir que as 127 issues dele
aparecem, que a contagem por conceito soma 127, e que nenhuma issue de outro repositório
aparece.

**Acceptance Scenarios**:

1. **Dado** um repositório observado, **quando** o usuário o abre, **então** vê as issues
   dele com número, título, tipo na origem, conceito promovido e estado.
2. **Dado** o repositório aberto, **quando** o cabeçalho é lido, **então** a contagem por
   conceito **soma o total** de issues dele.
3. **Dado** um repositório sem issues, **quando** ele é aberto, **então** a tela diz
   **coletado e vazio**, distinto de não coletado.
4. **Dado** um repositório excluído da observação, **quando** ele é aberto, **então** as
   issues dele continuam consultáveis, e a tela diz que a plataforma parou de olhar.
5. **Dado** um repositório com 127 issues, **quando** ele é aberto, **então** a lista é
   paginada, e a ordem é estável entre páginas.
6. **Dado** o repositório, **quando** ele é aberto, **então** vê o que o git fornece — nome
   qualificado, endereço, linguagem predominante, ramo padrão, última escrita.

---

### Edge Cases

1. **Corpo com markdown, imagem e menção** — o que a tela renderiza e o que ela escapa.
2. **Corpo muito longo**, de milhares de linhas.
3. **Autor que não é pessoa** — bot, `github-actions`, conta de automação.
4. **Autor removido da organização**, ou conta apagada: a issue existe, o autor não.
5. **Designado que a plataforma não conhece** como pessoa coletada.
6. **Épico dentro de épico** — a composição é recursiva, e a profundidade pode passar de 2.
7. **Ciclo na decomposição** — recusado na coleta, e a issue precisa mostrar a recusa.
8. **Sub-issue em repositório fora do escopo observado**: a relação existe, a issue não.
9. **Issue fechada como `NOT_PLANNED`** — o motivo do fechamento muda o significado.
10. **Issue movida entre repositórios**: o número muda, a identidade não.
11. **Milestone e projeto** — dois agrupamentos diferentes, e nenhum é o sprint.
12. **Rótulo com a mesma cor de outro**, e rótulo com nome que parece tipo — `bug`, `epic`.

## Requirements *(mandatory)*

### Functional Requirements

#### O que é coletado, e salvo

- **FR-001**: A plataforma DEVE coletar e persistir, de cada issue: corpo, autor,
  designados, rótulos, marco, estado, motivo de fechamento, e as datas de criação,
  atualização e fechamento.
- **FR-002**: A plataforma DEVE persistir a contagem de comentários e de reações, e NÃO
  DEVE persistir o conteúdo deles — comentário é outra entidade, com outra semântica.
- **FR-003**: O corpo DEVE ser persistido **como a origem o devolveu**, sem normalização —
  ele é evidência, e reescrevê-lo destrói o que sustenta a promoção por padrão de texto.
- **FR-004**: Autor e designados DEVEM ser ligados às pessoas já coletadas quando existirem;
  quando não existirem, o identificador da origem DEVE ser preservado, e a ausência do
  vínculo DEVE ser declarada.
- **FR-005**: Rótulo DEVE ser persistido com nome e cor, e NÃO DEVE ser promovido a
  conceito: rótulo é texto livre, e mapeá-lo por semelhança de nome é o antipadrão que o
  princípio I proíbe.
- **FR-006**: Marco e projeto DEVEM ser persistidos como referências da origem, e NENHUM
  DEVE ser tratado como sprint.
- **FR-007**: Toda coleta DEVE preservar o payload bruto, como a feature 004 já faz.

#### O detalhe

- **FR-008**: A tela de detalhe DEVE apresentar todos os campos coletados da issue.
- **FR-009**: Campo ausente na origem DEVE aparecer como **ausente**, e NÃO DEVE ser
  preenchido com valor inventado nem escondido.
- **FR-010**: A tela DEVE apresentar o conceito promovido, a **regra** e a **versão** que
  decidiram, e a fonte da evidência.
- **FR-011**: A tela DEVE apresentar a divergência entre tipo declarado e conceito derivado,
  quando houver.
- **FR-012**: A tela DEVE apresentar o **histórico** de promoções em ordem, indicando a
  vigente.
- **FR-013**: A tela DEVE oferecer link para a issue na origem.
- **FR-014**: O corpo DEVE ser renderizado de forma segura: markdown da origem NÃO DEVE
  poder injetar conteúdo executável.

#### A decomposição

- **FR-015**: A tela DEVE apresentar **composição** e **atendimento** como relações
  distintas, nomeadas, em seções separadas.
- **FR-016**: A tela NÃO DEVE apresentar uma contagem única de "filhas" que some as duas.
- **FR-017**: Num épico, as user stories que o compõem DEVEM aparecer com o conceito de cada
  uma, e as tarefas **de cada história** DEVEM aparecer aninhadas nela.
- **FR-018**: Numa user story, as tarefas que a atendem DEVEM aparecer, e o épico de que ela
  é parte DEVE aparecer quando houver.
- **FR-019**: Numa tarefa, a user story que ela atende DEVE aparecer e ser navegável.
- **FR-020**: A composição DEVE ser navegável em profundidade maior que dois — épico dentro
  de épico existe, e `sro.rule04` só proíbe ciclo.
- **FR-021**: Ausência de decomposição DEVE ser declarada, distinta de ausência de coleta.

#### O que viola a regra

- **FR-022**: Tarefa cujo pai é épico DEVE aparecer com aviso nomeando `sro.rule07`, e a
  explicação DEVE dizer que ligar tarefa a épico conta o esforço duas vezes.
- **FR-023**: Tarefa sem user story DEVE aparecer com aviso nomeando o mesmo axioma.
- **FR-024**: A issue envolvida numa violação DEVE continuar promovida e consultável: o
  inválido é o **vínculo**, não a issue.
- **FR-025**: Vínculo recusado na coleta DEVE aparecer no detalhe das issues envolvidas, com
  o motivo — e, no caso de ciclo, com o caminho.

#### As issues de um repositório

- **FR-026**: A tela do repositório DEVE listar as issues dele, com número, título, tipo na
  origem, conceito promovido e estado.
- **FR-027**: O cabeçalho DEVE trazer a contagem por conceito, e ela DEVE **somar o total**
  de issues do repositório.
- **FR-028**: A lista DEVE ser paginada, com ordem **estável** entre páginas.
- **FR-029**: Repositório coletado e vazio DEVE ser distinguível de não coletado.
- **FR-030**: Repositório excluído da observação DEVE ter as issues consultáveis, e a tela
  DEVE dizer que a plataforma parou de olhar.
- **FR-031**: A tela DEVE apresentar o que o git fornece do repositório: nome qualificado,
  endereço, linguagem predominante, ramo padrão e última escrita observada.

#### Isolamento e consumo

- **FR-032**: Nenhuma tela DEVE exibir dado de outro tenant, e a consulta a recurso de outro
  tenant DEVE responder "não encontrado".
- **FR-033**: Abrir o detalhe NÃO DEVE consultar a origem: tudo o que a tela mostra vem do
  que já foi coletado.
- **FR-034**: A coleta dos campos novos DEVE respeitar o limite de consumo da origem, e o
  acréscimo de campos NÃO DEVE exigir recoleta de quem já foi coletado — o retrofito ocorre
  na coleta seguinte.

### Key Entities

- **Issue coletada**, estendida: corpo, autor, designados, rótulos, marco, estado, motivo de
  fechamento, datas, contagem de comentários e reações.
- **Designação**: a ligação entre issue e pessoa designada. É relação, e não coluna — uma
  issue tem zero ou muitos designados.
- **Rótulo observado**: nome e cor, por repositório. Preservado e **não** promovido.
- **Vínculo de decomposição**, já existente: ganha o significado derivado — composição
  quando a parte é user story, atendimento quando é tarefa.
- **Violação de axioma**: derivada, não gravada. Sai do conceito do pai e do conceito da
  parte.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Todo campo que a origem fornece para uma issue está persistido ou declarado
  como fora de escopo — nenhum é perdido em silêncio.
- **SC-002**: Nenhum campo ausente na origem aparece preenchido na tela.
- **SC-003**: Composição e atendimento nunca aparecem somados na mesma contagem.
- **SC-004**: Num épico com 3 user stories e 36 tarefas, a tela mostra **3** na composição e
  **36** no atendimento — nunca 39 em lugar nenhum.
- **SC-005**: Uma user story com nove tarefas atendendo aparece como user story atômica, e
  não como épico.
- **SC-006**: As 41 tarefas cujo pai é épico aparecem com o aviso de `sro.rule07`, e as 41
  continuam promovidas.
- **SC-007**: As 3 tarefas sem pai aparecem com o mesmo aviso.
- **SC-008**: A contagem por conceito no cabeçalho do repositório soma o total de issues
  dele, sob qualquer filtro.
- **SC-009**: A ordem da lista paginada é a mesma em duas execuções, e nenhuma issue aparece
  em duas páginas.
- **SC-010**: Abrir o detalhe de uma issue não gera nenhuma requisição à origem.
- **SC-011**: Nenhum corpo de issue renderizado permite injeção de conteúdo executável.
- **SC-012**: Um usuário de um tenant não alcança issue, repositório nem vínculo de outro
  tenant por nenhum caminho.
- **SC-013**: Duas coletas seguidas sem mudança na origem produzem os mesmos campos, sem
  duplicar designado nem rótulo.

## Assumptions

- **Comentários e timeline ficam fora.** A issue `#1` tem 48 itens de timeline, e coletá-los
  multiplicaria o consumo da origem por issue. Comentário é entidade própria, com autor e
  data, e merece decisão própria.
- **Rótulo não é promovido a conceito, e a decisão é firme.** Um rótulo `bug` não faz a issue
  um defeito: quem decide é o tipo declarado ou a regra da organização. Promover rótulo por
  nome é o antipadrão que a feature 005 existe para evitar.
- **Autor é ligado a `eo.person` quando a pessoa já foi coletada.** Quando não, o login é
  preservado e o vínculo fica declaradamente ausente — criar a pessoa a partir da issue
  produziria pessoa sem a proveniência que a coleta de EO dá.
- **A violação de `sro.rule07` é derivada em consulta**, não gravada. Gravá-la a faria
  divergir no instante em que a classificação de pai ou parte mudasse.
- **O retrofito dos campos novos ocorre na coleta seguinte.** Issues já coletadas ficam sem
  corpo até serem reobservadas, e a tela declara isso em vez de mostrar vazio.

## Dependencies

- Feature 004 — issues, repositórios, promoções e vínculos coletados. Sem ela não há o que
  detalhar.
- Feature 005 — regras de mapeamento: quanto mais issues promovidas, mais a decomposição faz
  sentido. Não é bloqueante: a decomposição de quem já está promovido funciona hoje.

## Out of Scope

| Fora | Por quê |
|---|---|
| Comentários e timeline | multiplicaria o consumo por issue; entidade própria |
| Editar issue na plataforma | a plataforma observa; escrever na origem é outra decisão |
| Promover rótulo a conceito | rótulo é texto livre; é o antipadrão do princípio I |
| Pull requests ligados à issue | é CMPO, com mapeamento próprio |
| Histórico de mudança de estado | exigiria timeline; responde outra pergunta |
| Anexos e imagens do corpo | a plataforma não armazena binário da origem |
