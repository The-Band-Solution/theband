# Feature Specification: As tecnologias com que cada pessoa trabalhou

**Feature Branch**: `053-tecnologias-por-pessoa`

**Created**: 2026-09-01

**Status**: Draft — pronta para `/speckit-clarify` ou `/speckit-plan`

**Input**: User description: "saber as tecnologias que as pessoas trabalharam,
tomando como base os arquivos dos commits que elas mexeram — podemos pegar pela
extensão deles"

## Por que esta feature existe

Quem monta equipe precisa saber quem já trabalhou com o quê. Hoje a resposta mora
na memória de quem acompanhou, ou num currículo que ninguém confere.

A plataforma já observa o material: cada commit traz os arquivos que tocou, com
caminho, linhas acrescentadas e removidas, e proveniência. O que falta é ler.

**E há uma razão de desenho para esta feature existir ao lado da 026.** Aquela
deriva competências de **texto de issue, interpretado por IA**, e carrega o risco
declarado de virar julgamento sem lastro. Esta deriva de **arquivo tocado**, que
é fato observado: ou o commit mexeu no arquivo, ou não mexeu. Não substitui a
026 — dá a ela o lastro que texto não tem.

## O risco que esta spec existe para conter

Extensão de arquivo é um sinal **fraco**, e quatro coisas o transformam em número
que parece informação e não é:

| armadilha | o que ela produz se ninguém contiver |
|---|---|
| extensão tratada como tecnologia | `.js` vira "JavaScript" quando era React, Node ou jQuery; `.yaml` vira "YAML" quando era CI, Kubernetes ou base de conhecimento |
| arquivo gerado contado como trabalho | quem commitou um `package-lock.json` de 30 mil linhas lidera o ranking de JSON |
| linhas como medida | premia exatamente o caso acima, e pune quem apagou código |
| ausência de recência | quem mexeu em `.php` há três anos e nunca mais aparece como quem trabalha com PHP hoje |
| proporção virando rótulo | "70% dos arquivos na interface" lido como "é frontend" — e a etiqueta cola, fecha porta e sobrevive à pessoa ter mudado |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver com o que uma pessoa trabalhou (Priority: P1)

Quem coordena abre o painel de uma pessoa e vê as tecnologias com que ela
trabalhou, ordenadas pelo que sustenta e não pelo que apareceu uma vez. Cada uma
diz **de onde saiu**: quantos arquivos distintos, em quantos meses, e o mais
recente.

**Why this priority**: é a feature. Sem ela não há resposta para a pergunta que a
motivou.

**Independent Test**: abrir o painel de uma pessoa com commits coletados e
conferir que cada tecnologia listada corresponde a arquivos que os commits dela
de fato tocaram.

**Acceptance Scenarios**:

1. **Given** uma pessoa com commits em arquivos de duas tecnologias distintas,
   **When** seu painel é aberto, **Then** as duas aparecem, cada uma com o número
   de arquivos distintos, o número de meses distintos e a data mais recente.
2. **Given** uma tecnologia em que a pessoa tocou **um** arquivo **uma** vez,
   **When** o painel é aberto, **Then** ela aparece **abaixo** de outra com muitos
   arquivos em muitos meses — a ordem é por sustentação, não por presença.
3. **Given** uma pessoa sem commit coletado nenhum, **When** o painel é aberto,
   **Then** a tela diz que **não há material**, e não mostra lista vazia.

---

### User Story 2 - A organização corrige o mapa (Priority: P1)

Quem administra abre o mapa extensão→tecnologia, vê o que está declarado, e
corrige o que discorda. A correção vale na leitura seguinte, sem nova coleta.

**Why this priority**: mesma prioridade da US1 porque sem ela a US1 entrega uma
classificação que ninguém pode contestar — e classificação incontestável sobre
pessoas é exatamente o que esta spec quer evitar. O mapa é a peça que transforma
a leitura em algo que a organização possui.

**Independent Test**: mudar o mapa e conferir que a leitura muda, sem recoletar.

**Acceptance Scenarios**:

1. **Given** o mapa dizendo que `.ex` é Elixir, **When** alguém o corrige para
   outra coisa, **Then** a leitura seguinte reflete a correção.
2. **Given** uma extensão **sem** entrada no mapa, **When** o painel é aberto,
   **Then** ela aparece como **não reconhecida**, com quantos arquivos — e não
   some nem vira "outros".
3. **Given** uma regra que exclui arquivos gerados, **When** alguém a altera,
   **Then** a mudança fica registrada com autor e data, como toda declaração.

---

### User Story 3 - Onde as duas medidas divergem (Priority: P3)

Quem coordena compara o que os arquivos dizem com a **linguagem principal que o
repositório declara** — medida que a plataforma já coleta. Onde as duas divergem,
há algo real: alguém que só toca `.yaml` num repositório de código faz outra
coisa ali, e isso é informação, não erro.

**Why this priority**: P3 porque a US1 entrega valor sem ela. Mas é o que impede
a leitura de virar verdade única — duas medidas do mesmo fenômeno dizem mais que
qualquer uma sozinha.

**Independent Test**: com um repositório cuja linguagem principal é X e uma pessoa
que só tocou arquivos de Y nele, a divergência é mostrada.

**Acceptance Scenarios**:

1. **Given** uma pessoa cujos arquivos num repositório são de tecnologia
   diferente da linguagem principal dele, **When** a comparação é aberta,
   **Then** a divergência é dita, com os dois números.
2. **Given** repositório **sem** linguagem principal declarada na origem,
   **When** a comparação é aberta, **Then** isso é dito como ausência — e não
   contado como divergência.

---

### User Story 4 - Em que parte do sistema a pessoa trabalha (Priority: P2)

Quem monta equipe precisa saber mais que a lista de tecnologias: precisa saber se
a pessoa tem trabalhado **na interface, no servidor, na infraestrutura, nos dados
ou nos testes**. O mesmo mapa que traduz arquivo em tecnologia também diz a que
parte do sistema aquela tecnologia pertence, e a leitura mostra a **proporção** —
nunca um rótulo.

**Why this priority**: P2 porque a US1 já responde "com o que trabalhou", e esta
responde "onde". É a pergunta de quem monta equipe, e não de quem confere
currículo.

**Independent Test**: uma pessoa cujos arquivos são majoritariamente de interface
mostra proporção maior ali, com os números que sustentam a proporção visíveis.

**Acceptance Scenarios**:

1. **Given** uma pessoa com arquivos em duas partes do sistema, **When** o painel
   é aberto, **Then** as duas aparecem com a **proporção de arquivos distintos**
   de cada uma, e os números que a produzem.
2. **Given** uma pessoa com **90%** dos arquivos numa parte só, **When** o painel
   é aberto, **Then** a tela mostra a proporção — e **não** afirma que a pessoa
   "é" daquela parte.
3. **Given** uma tecnologia que pertence a **mais de uma** parte, **When** ela é
   contada, **Then** o arquivo conta para as partes que o mapa declara, e a tela
   diz que aquela tecnologia atravessa mais de uma.

---

### Edge Cases

- **Arquivo sem extensão.** `Dockerfile`, `Makefile`, `LICENSE`. O mapa precisa
  poder casar por **nome inteiro**, e não só por extensão — senão as tecnologias
  de infraestrutura somem justamente de quem trabalha com elas.
- **Arquivo movido ou renomeado.** O commit registra `previous_path`. Mover mil
  arquivos numa reorganização não é ter trabalhado em mil arquivos.
- **A mesma pessoa em contas diferentes.** A contagem é por **pessoa observada**,
  e não por autor de commit — o elo entre as duas coisas já existe na plataforma.
- **Extensão ambígua entre tecnologias.** `.h` é C ou C++; `.m` é Objective-C ou
  MATLAB. O mapa precisa poder dizer "ambígua", e a leitura precisa mostrar isso
  em vez de escolher uma.
- **Commit de mais de uma pessoa.** Coautoria existe. Atribuir o arquivo a todos
  os coautores é uma decisão, e precisa estar dita.
- **Repositório arquivado ou não mais observado.** Trabalho passado continua
  tendo acontecido; a leitura precisa dizer que a fonte não é mais observada, em
  vez de apagar o histórico.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST derivar, para cada pessoa observada, as
  tecnologias dos arquivos que os commits dela tocaram.
- **FR-002**: A tradução de arquivo para tecnologia MUST vir de um **mapa
  declarado e versionado**, nunca de regra embutida em código, e MUST casar por
  extensão **e** por nome inteiro de arquivo.
- **FR-003**: Arquivos **gerados e vendorizados** MUST ser excluídos por regra
  igualmente declarada. A regra MUST ser legível por quem administra.
- **FR-004**: A medida MUST ser **arquivos distintos tocados** e **meses
  distintos com atividade**. Linhas acrescentadas ou removidas MUST NOT ser
  medida de competência.
- **FR-005**: Cada tecnologia MUST vir com **a data mais recente** em que a
  pessoa tocou um arquivo dela.
- **FR-006**: A ordenação MUST favorecer sustentação — muitos meses — sobre
  volume num mês só.
- **FR-007**: Extensão **sem entrada no mapa** MUST aparecer como não
  reconhecida, com a contagem, e MUST NOT ser omitida nem agrupada em "outros".
- **FR-008**: Tudo o que esta feature produz MUST se declarar **derivado**, com a
  origem visível: de quantos arquivos, de quantos commits, em que período.
- **FR-009**: A contagem MUST ser por **pessoa observada**, reunindo as contas de
  autoria já vinculadas a ela.
- **FR-010**: Arquivo apenas **movido ou renomeado** MUST NOT contar como
  trabalho na tecnologia.
- **FR-011**: A leitura MUST respeitar o escopo de acesso de quem olha — as mesmas
  regras que já valem para o painel da pessoa.
- **FR-012**: Alteração no mapa ou nas regras de exclusão MUST valer na leitura
  seguinte, **sem** exigir nova coleta.
- **FR-013**: Extensão que o mapa declara **ambígua** MUST ser mostrada como
  ambígua, com as tecnologias possíveis — e MUST NOT ser resolvida por escolha
  automática.
- **FR-014**: O mapa MUST declarar, além da tecnologia, **a que parte do sistema**
  ela pertence — interface, servidor, infraestrutura, dados, teste —, e uma
  tecnologia MUST poder pertencer a mais de uma.
- **FR-015**: A leitura por parte do sistema MUST ser expressa como **proporção
  de arquivos distintos**, com os números que a produzem visíveis. A plataforma
  MUST NOT atribuir a uma pessoa um rótulo de especialidade.
- **FR-016**: Tecnologia que atravessa mais de uma parte MUST ser dita como tal,
  em vez de atribuída à parte mais provável.

### Key Entities

- **Mapa de tecnologias**: o que traduz extensão ou nome de arquivo em
  tecnologia. Declarado, versionado, corrigível por quem administra. Sabe dizer
  "ambígua" e sabe dizer "excluir".
- **Toque em arquivo**: o fato observado — este commit, desta pessoa, tocou este
  caminho, nesta data. Já existe na plataforma.
- **Parte do sistema**: interface, servidor, infraestrutura, dados, teste. Uma
  propriedade **da tecnologia**, declarada no mapa — nunca uma propriedade da
  pessoa.
- **Tecnologia derivada de uma pessoa**: a leitura. Nunca gravada como fato; é o
  resultado de aplicar o mapa vigente aos toques observados.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem coordena responde "esta pessoa já trabalhou com X?" em **menos
  de 30 segundos**, sem perguntar a ninguém.
- **SC-002**: **100%** das tecnologias mostradas podem ser rastreadas até os
  arquivos que as originaram — nenhuma aparece sem origem verificável.
- **SC-003**: Nenhum arquivo gerado ou vendorizado aparece entre as cinco
  primeiras tecnologias de qualquer pessoa do piloto. Medido sobre as 88 pessoas
  observadas.
- **SC-004**: A proporção de arquivos com extensão **não reconhecida** é
  **visível** e cai a cada correção do mapa — a lacuna é medida, não escondida.
- **SC-005**: Corrigir o mapa muda a leitura em **menos de 1 minuto**, sem nova
  coleta.
- **SC-006**: Duas pessoas que olham o mesmo painel veem os **mesmos números** —
  a leitura não depende de quem pergunta, só do escopo de acesso.
- **SC-007**: Quem monta equipe responde "quem já trabalhou na interface deste
  sistema?" em **menos de 1 minuto**, com os arquivos que sustentam a resposta a
  um clique.
- **SC-008**: **Nenhuma** tela atribui rótulo de especialidade a uma pessoa. Toda
  afirmação sobre parte do sistema é proporção, com o denominador à vista.

## Assumptions

- Os arquivos por commit já são coletados, com caminho e proveniência. Esta
  feature **lê** esse material; não acrescenta coleta.
- O elo entre autor de commit e pessoa observada já existe e é o que permite o
  FR-009.
- A linguagem principal do repositório já é coletada da origem, e é o que torna a
  US3 possível sem trabalho novo de coleta.
- O mapa inicial cobre as tecnologias presentes no piloto; extensões fora dele
  aparecem como não reconhecidas até alguém completar — que é o comportamento
  desejado, e não uma limitação.
- **Fica fora do escopo**: ler o conteúdo dos arquivos, inferir framework dentro
  de uma linguagem, medir qualidade do que foi escrito, e comparar pessoas entre
  si. Esta feature diz **com o que** e **onde** alguém trabalhou, nunca **quão
  bem** nem **o que a pessoa é**.
- A divisão em partes do sistema é **do mapa**, e portanto da organização. Um
  time que organize o trabalho de outro jeito muda o mapa; a leitura acompanha.
