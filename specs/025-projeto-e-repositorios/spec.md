# Feature Specification: o projeto, seus subprojetos e os repositórios dele

**Feature**: `025-projeto-e-repositorios` · **Criada em**: 2026-08-15
**Estado**: rascunho — **bloqueada por dependência de ontologia**, ver abaixo
**Papel que escreveu**: Product Owner
**Origem**: decisão da pessoa mantenedora — *"um projeto pode ter subprojetos e vários
repositórios; as issues dos repositórios são issues dos projetos; essa associação é manual"*.

## O pedido

> "Vamos implementar o conceito de projeto e repositório. Um projeto pode ter subprojetos e
> vários repositórios. No nosso caso, as issues dos repositórios são issues dos projetos.
> Essa associação é manual: quem usa cadastra o projeto e associa os repositórios."

---

## ⚠ Bloqueio: duas relações não existem na rede

**Estudado em 2026-08-15.** O que já existe:

| Conceito | Estado |
|---|---|
| `spo.project` | **existe** — kind, social_object, com `name`, `started_at`, `ended_at` |
| `spo.software_project` | **existe** — subkind de `spo.project` |
| `sro.scrum_project` | **existe** — kind, parent `spo.software_project` |
| `cmpo.source_repository` | **existe e já materializado** — 160 repositórios coletados |

O que **não** existe, e a feature inteira depende:

| O que falta declarar | Forma |
|---|---|
| **`spo.simple_project`** | `phase` de `spo.project` — projeto que não é decomposto em outros |
| **`spo.complex_project`** | `phase` de `spo.project` — projeto composto de outros |
| **projeto complexo composto de projeto** | parte-todo, alvo `spo.project`, **recursiva** |
| **regra: hierarquia de projeto é acíclica** | espelho de `sro.rule04` |
| **projeto agrupa repositório** | associação muitos-para-muitos, declarada por pessoa |

### Simples e complexo são **fases**, e a distinção não é minha

Decisão da pessoa mantenedora em 2026-08-15: *"um projeto complexo é composto por projetos
simples"*. A rede já resolveu exatamente esta forma para user story, e o espelho é literal:

| SRO | Aqui |
|---|---|
| `sro.atomic_user_story` — *"user story que não é decomposta em outras"*, `phase` | `spo.simple_project` |
| `sro.epic` — *"user story composta de outras"*, `phase` | `spo.complex_project` |
| `sro.epic_composed_of_user_story` — alvo é **user story**, logo recursiva | projeto composto de **projeto** |
| `sro.rule04.epic_hierarchy_is_acyclic` | a mesma regra, para projeto |

**`phase`, e não subkind, é o ponto.** A definição de `sro.epic` diz: *"ser épico não é rótulo
atribuído, e sim consequência de ter partes — uma user story sem partes não é épico, ainda que a
ferramenta a chame assim"*.

Vale igual: **ninguém cadastra um projeto complexo.** Cadastra-se um projeto, e ele **vira**
complexo ao ganhar a primeira parte — e volta a simples se perdê-la.

**A composição é recursiva**, e não de dois níveis: um projeto complexo pode conter outro
complexo, em qualquer profundidade, exatamente como épico compõe épico. É o que permite
`Conecta Fapes → Backend → Pagamentos`, e é o que torna o axioma acíclico **obrigatório** — sem
ele a travessia até as issues não termina.

**Isto não é detalhe de implementação.** Pelo princípio I da constituição, o domínio nasce das
ontologias — uma tabela `projects` com `parent_id` inventado seria conceito entrando pela porta
de trás, com aparência de dado modelado.

**E não é trabalho deste papel.** Definir conceito, relação e cardinalidade é de *Ontology &
Semantic Integration*. Esta spec descreve o valor e os critérios; a declaração é pré-requisito
e precisa acontecer antes da primeira migração.

---

## O que a medida achou

**Medido em 2026-08-15**, no banco com dado real:

| Organização | Repositórios | Issues |
|---|---:|---:|
| leds-conectafapes | 121 | 4295 |
| ifesserra-lab | 25 | 414 |
| The-Band-Solution | 14 | 326 |

**160 repositórios, 5035 issues, 3 organizações.** Um projeto agrupa um punhado deles, e é isso
que torna a feature necessária: hoje a única forma de perguntar "o que aconteceu no projeto X" é
saber de cor quais repositórios pertencem a ele.

### A issue já sabe de qual repositório é

`collected_issues.observed_repository_id` existe e está preenchido. Isso decide um ponto de
desenho, e a spec o fixa como critério:

**"As issues dos repositórios são issues do projeto" é uma travessia, não uma associação nova.**
Projeto → repositórios → issues. Guardar `project_id` na issue duplicaria o fato, e as duas
fontes discordariam no dia em que alguém movesse um repositório de projeto.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cadastrar um projeto (Priority: P1) · `importance: 100`

Quem administra cadastra um projeto com nome, e opcionalmente quando ele começou e terminou.

**Por que é P1**: nada mais existe sem ela. É a raiz da decomposição.

**Independent Test**: cadastrar um projeto e vê-lo na listagem, com o nome que foi digitado.

**Critérios de aceitação** — `sro.functional_acceptance_criterion`

1. **Dado** um nome, **quando** alguém cadastra, **então** o projeto existe e aparece na lista.
2. **Dado** um projeto sem data de início, **quando** ele é exibido, **então** a tela diz **"não
   informado"** — e não uma data inventada nem um traço solto.
3. **Dado** um nome já usado no mesmo tenant, **quando** alguém tenta cadastrar, **então** a
   plataforma recusa e diz qual projeto já tem aquele nome.
4. **Dado** um projeto cadastrado, **quando** ele é exibido, **então** a proveniência diz
   **declaração**, e nunca observação — projeto não vem da origem, vem de quem cadastrou.
5. **Dado** o formulário de cadastro, **quando** ele é exibido, **então** ele **não** pergunta se
   o projeto é simples ou complexo: a fase é consequência de ter partes, e antes das partes a
   pergunta não tem resposta.
6. **Dado** um projeto recém-cadastrado, **quando** ele é exibido, **então** ele consta como
   **simples** — porque não tem partes, e não porque alguém escolheu.

---

### User Story 2 - Associar repositórios ao projeto (Priority: P1) · `importance: 100`

Quem administra escolhe, entre os repositórios observados, quais pertencem ao projeto.

**Por que é P1, e empata com a US1**: é o pedido literal, e é o que dá utilidade ao cadastro. Um
projeto sem repositório não responde nada.

**Independent Test**: associar 3 dos 160 repositórios a um projeto e conferir que o projeto passa
a listar as issues dos três, e só delas.

**Critérios de aceitação**

1. **Dado** um projeto e repositórios observados, **quando** alguém associa, **então** o vínculo
   existe **com autor e data** — decisão tem autor.
2. **Dado** um repositório já associado a **outro** projeto, **quando** alguém o associa a este,
   **então** os dois vínculos coexistem: um repositório pode servir a mais de um projeto.
3. **Dado** um vínculo, **quando** alguém o desfaz, **então** ele é **marcado como encerrado**, e
   nunca apagado — com autor e data, como a alocação de papel.
4. **Dado** um repositório que saiu da observação, **quando** o projeto é exibido, **então** o
   vínculo aparece dizendo isso, em vez de sumir.

---

### User Story 3 - Ver as issues do projeto (Priority: P1) · `importance: 100`

Quem abre um projeto vê as issues de todos os repositórios associados a ele.

**Por que é P1**: é a pergunta que motivou o pedido. As duas anteriores existem para permitir
esta.

**Independent Test**: um projeto com 3 repositórios mostra a soma das issues dos três, e a
contagem bate com a listagem.

**Critérios de aceitação**

1. **Dado** um projeto com repositórios associados, **quando** alguém o abre, **então** as issues
   deles aparecem, com o repositório de cada uma visível.
2. **Dado** um projeto sem repositório associado, **quando** alguém o abre, **então** a tela diz
   **"nenhum repositório associado"** — e não uma lista vazia de issues, que sugeriria projeto
   sem trabalho.
3. **Dado** um vínculo encerrado, **quando** o projeto é aberto, **então** as issues daquele
   repositório **não** contam no total atual.
4. **Dado** qualquer contagem exibida, **quando** há filtro ou busca, **então** ela bate com a
   listagem.

---

### User Story 4 - Compor um projeto de outros (Priority: P2) · `importance: 70`

Quem administra declara que um projeto é parte de outro, e o pai passa a ser complexo.

**Por que é P2**: entrega valor sozinha, mas as três anteriores já respondem a pergunta central.
Hierarquia sem projeto e sem repositório não tem o que agrupar.

**Independent Test**: compor um projeto de dois outros e conferir que o pai mostra as issues dos
repositórios dos dois, e que ele passou a constar como complexo.

**Critérios de aceitação**

1. **Dado** dois projetos, **quando** um é declarado parte do outro, **então** o vínculo existe
   com autor e data.
2. **Dado** um projeto que ganhou a primeira parte, **quando** ele é exibido, **então** ele consta
   como **complexo** — sem ninguém ter mudado um tipo. É consequência, não rótulo.
3. **Dado** um projeto complexo que perdeu a última parte, **quando** ele é exibido, **então** ele
   volta a constar como **simples**. Fase muda com o fato; tipo não mudaria.
4. **Dado** um projeto complexo, **quando** ele é declarado parte de um terceiro, **então** a
   composição é aceita — ela é **recursiva**, como épico compõe épico, e a profundidade é livre.
5. **Dado** um projeto pai, **quando** alguém o abre, **então** as issues dos repositórios dos
   subprojetos aparecem **separadas** das dos repositórios diretos — são origens diferentes, e
   somá-las sem distinguir esconderia de onde o número veio.
6. **Dado** uma tentativa de tornar um projeto parte de si mesmo, **direta ou indiretamente**,
   **quando** ela é feita, **então** a plataforma **recusa** e diz qual é o caminho do ciclo.
7. **Dado** um projeto marcado como parte de dois pais diferentes, **quando** isso acontece,
   **então** é aceito — a hierarquia é grafo acíclico, e não árvore. A contagem de issues do
   ancestral diz **de qual caminho** cada issue veio, para a mesma issue sob dois pais não parecer
   duas.

---

### Edge Cases

- **Projeto sem repositório e sem subprojeto.** Cadastro recém-feito. A tela diz isso, e não
  mostra painel de zeros.
- **Repositório em dois projetos.** Permitido pela US2, e a issue dele conta nos dois — como a
  designação conta para cada pessoa, sem dividir.
- **Hierarquia profunda.** Projeto → subprojeto → subprojeto. A travessia é recursiva, e o
  axioma acíclico é o que garante que ela termina.
- **Projeto encerrado com repositórios ativos.** `ended_at` preenchido não encerra os vínculos:
  são fatos diferentes, e apagar um ao mexer no outro perderia história.
- **Repositório excluído da observação pelo tenant.** É decisão do tenant e não do projeto; o
  vínculo continua, e a tela distingue isso de "não coletado".

---

## Requirements *(mandatory)*

### O projeto

- **FR-001**: A plataforma MUST permitir cadastrar projeto com nome, e opcionalmente início e fim.
- **FR-002**: O nome MUST ser único dentro do tenant.
- **FR-003**: Data ausente MUST ser exibida como "não informado", e MUST NOT virar data padrão.
- **FR-004**: O projeto MUST carregar proveniência de **declaração**, com autor e data.

### Os repositórios

- **FR-005**: A associação entre projeto e repositório MUST ser muitos-para-muitos.
- **FR-006**: Cada vínculo MUST ter autor e data.
- **FR-007**: Desfazer um vínculo MUST marcá-lo como encerrado, e MUST NOT apagá-lo.
- **FR-008**: A associação MUST ser manual, e a plataforma MUST NOT inferir projeto a partir de
  nome de repositório, organização ou qualquer padrão de texto.

### As issues

- **FR-009**: As issues do projeto MUST ser derivadas da travessia projeto → repositórios →
  issues.
- **FR-010**: A issue MUST NOT guardar referência a projeto — duas fontes para o mesmo fato
  discordariam quando um repositório mudasse de projeto.
- **FR-011**: Issue de repositório com vínculo encerrado MUST NOT contar no total atual.

### A hierarquia

- **FR-012**: Um projeto MUST poder ser declarado parte de outro, com autor e data.
- **FR-013**: A plataforma MUST recusar ciclo na hierarquia, e MUST nomear o caminho do ciclo.
- **FR-014**: As issues vindas de subprojetos MUST ser distinguíveis das vindas de repositórios
  diretos.
- **FR-015**: A fase — simples ou complexo — MUST ser **derivada** de ter partes, e a plataforma
  MUST NOT oferecer escolha de tipo no cadastro.
- **FR-016**: A composição MUST ser recursiva: um projeto complexo MUST poder conter outro
  complexo, sem profundidade fixa.

### O que a plataforma recusa

- **FR-017**: A plataforma MUST NOT criar projeto a partir de observação — nem de Projects v2,
  nem de organização, nem de repositório. Projeto é declaração.

---

## Success Criteria *(mandatory)*

- **SC-001**: Um projeto com 3 dos 160 repositórios associados mostra as issues dos três, e
  nenhuma dos outros 157.
- **SC-002**: A contagem exibida bate com a listagem sob qualquer filtro.
- **SC-003**: Desfazer um vínculo e refazê-lo preserva os dois registros, com as duas datas.
- **SC-004**: Uma tentativa de ciclo — A parte de B, B parte de A — é recusada, e a mensagem
  nomeia `A → B → A`. Um ciclo indireto de três níveis é recusado igual.
- **SC-004a**: Um projeto recém-cadastrado consta como **simples**; ao ganhar uma parte passa a
  **complexo**; ao perder a última volta a **simples** — sem ninguém alterar um campo de tipo.
- **SC-004b**: `A → B → C`, com C tendo repositórios, faz as issues de C aparecerem em A — a
  travessia é recursiva.
- **SC-005**: Um projeto sem repositório diz "nenhum repositório associado", e a tela **não**
  exibe uma lista vazia de issues.
- **SC-006**: O mesmo repositório em dois projetos aparece nos dois, e a soma dos dois projetos é
  maior que o número de repositórios distintos.
- **SC-007**: Nenhum caminho da plataforma cria projeto sem alguém ter cadastrado.

---

## Assumptions

- **O projeto é `spo.software_project`**, e não `sro.scrum_project`: adotar Scrum é afirmação
  sobre o processo, e a plataforma não observa isso. Promover a `scrum_project` seria declarar
  algo que ninguém disse.
- **O escopo é o tenant.** Projeto não atravessa tenants, como nada mais atravessa.
- **A tela vive em `/projects`.** Rota nova porque a pergunta é nova; nenhuma tela existente
  responde "o que este projeto agrupa".
- **Repositório observado é o alvo do vínculo**, e não `cmpo.source_repository` cru: é o
  observado que carrega a decisão do tenant de olhar para ele.

## Fora do escopo

- **Declarar o conceito e as duas relações na base de conhecimento.** É pré-requisito, e é de
  *Ontology & Semantic Integration* — ver o bloqueio no topo.
- **Métricas por projeto.** Vazão, lead time e antipadrões agregados por projeto vêm depois, e
  cada um herda as limitações já medidas na feature 023.
- **Ligação com o Projects v2 do GitHub.** O quadro é outra coisa: ele organiza trabalho, e o
  projeto aqui agrupa repositórios. Um quadro pode cruzar projetos, e um projeto pode não ter
  quadro.
- **Stakeholders do projeto.** `spo.project_person_stakeholder` e
  `spo.project_team_stakeholder` existem na ontologia e são feature própria.
- **Release.** Não é conceito da base — a lacuna já está registrada no papel de PO.

---

## Nota do Product Owner

**Nenhum `[NEEDS CLARIFICATION]` em aberto.** A pergunta sobre profundidade foi decidida em
2026-08-15: composição **recursiva**, espelhando `sro.epic_composed_of_user_story`.

**A consequência aceita**: um subprojeto pode ter mais de um pai, e aí a mesma issue aparece em
dois ancestrais. A US4 critério 7 exige que a tela diga **de qual caminho** cada issue veio —
sem isso, a mesma issue sob dois pais pareceria duas, que é o defeito que a feature 023 já
enfrentou com designação compartilhada.

**Decomposição**: as quatro user stories são atômicas — nenhuma tem partes, e cada uma tem
critérios avaliáveis sobre um entregável. US1 a US3 formam a fatia vertical mínima: cadastro,
associação e a tela que responde a pergunta. **US4 é entregável separado**, e não deve ser
misturada na mesma tarefa que as três primeiras.
