# Feature Specification: Rede de revisão

**Feature Branch**: `feature/1182-rede-de-revisao`

**Created**: 2026-10-03

**Status**: Draft

**Épico**: [#1182](https://github.com/The-Band-Solution/theband/issues/1182)

**Input**: User description: "073 — Rede de revisão (issue #1182, primeira fatia das redes complexas). Necessidade de informação: a revisão de código está concentrada em poucas pessoas? Quem revisa quem numa janela de tempo, por organização. Nós: pessoas. Aresta dirigida de quem revisou para quem abriu a solicitação de mudança, com peso. Pull Request não é merge. Auto-revisão fora e contada. Bots e logins sem pessoa ligada fora, com a contagem. Medidas declaradas na base, com limitações e interpretações incorretas. Pessoa sem revisão na janela tem medida ausente com motivo, nunca zero. Sem dependência nova. Tela mobile-first com protótipo aprovado antes do código. Fora: rótulo de papel da pessoa, comparação com equipes, coautoria, índice de mundo pequeno. Toca dado de pessoa: avaliação de segurança antes do código."

## Contexto

A análise do repositório `leds-conectafapes/leds-conectafapes-management-dashboard`, feita em 2026-10-03, propôs trazer ao The Band a leitura de **redes complexas** sobre o trabalho de desenvolvimento. Esta é a primeira de quatro fatias:

1. rede de revisão (esta);
2. comunidades observadas × equipes declaradas;
3. pontes e risco de dependência de pessoa;
4. coautoria de artefato.

A revisão vem primeiro por duas razões. O dado já é coletado. E a relação tem semântica limpa: uma avaliação de artefato (QAPO) **sobre** uma solicitação de mudança (CMPO), feita por uma pessoa (EO) sobre o trabalho de outra.

O repositório de referência tem três defeitos que esta feature **não** pode repetir:

- quando uma medida falha, ele inventa um valor (0,01);
- ele classifica por faixas numéricas sem razão escrita;
- ele calcula o índice de mundo pequeno só com os grafos aleatórios conexos e divide por dez.

E rotula pessoas como "hub" ou "ponte", que é julgamento sobre pessoa, e não medida.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Ver se a revisão está concentrada (Priority: P1)

Quem coordena o time abre a rede de revisão de uma organização observada numa janela de tempo. Vê quantas solicitações de mudança foram revisadas, por quantas pessoas, e **que fração** das revisões coube às uma, duas e três pessoas que mais revisaram, sem que a fração nomeie ninguém. Com isso decide se precisa redistribuir a revisão antes que uma ausência pare o fluxo.

Quem administra alcança todas as pessoas e lê a concentração da organização inteira. Quem tem alcance parcial lê a concentração entre as pessoas que alcança: a pergunta passa a ser *"a revisão está concentrada entre as pessoas que eu alcanço?"*.

**Why this priority**: é a pergunta da necessidade de informação, e responde sozinha a uma decisão: redistribuir ou não.

**Independent Test**: com revisões coletadas de uma organização, a tela mostra o total, a contagem de revisores e a concentração das três primeiras pessoas, e os números batem com uma contagem manual das mesmas revisões.

**Acceptance Scenarios**:

1. **Given** uma organização com 40 solicitações revisadas nos últimos 90 dias, 30 delas por Ana, **When** quem administra abre a rede de revisão, **Then** a tela diz que a pessoa que mais revisou fez 75% das revisões, **sem nomeá-la**, com a janela escrita.
   **And When** uma conta de alcance parcial, que não alcança Ana, abre a mesma tela, **Then** a concentração é calculada só sobre as revisões entre pessoas que ela alcança, e o nome de Ana não aparece em lugar nenhum da tela (R1, decidido em 2026-10-03).
2. **Given** a mesma organização, **When** a janela muda de 90 para 30 dias, **Then** todos os números são recalculados para a janela nova, e a janela aparece junto de cada número.
3. **Given** uma organização sem revisão nenhuma na janela, **When** a tela abre, **Then** ela diz que não houve revisão na janela, em palavras, e não mostra 0%.

---

### User Story 2 — Ver quem revisa quem (Priority: P2)

Quem coordena vê, para cada pessoa, quantas solicitações ela revisou e de quantas pessoas distintas, e quantas solicitações dela foram revisadas e por quantas pessoas distintas. Abrindo uma pessoa, vê os pares: de quem ela revisa, e quem a revisa.

**Why this priority**: a concentração da US1 diz **se** há problema; os pares dizem **onde** está. Depende da US1 para ter o recorte.

**Independent Test**: para uma pessoa com revisões nos dois sentidos, as quatro contagens e a lista de pares batem com as revisões coletadas da janela.

**Acceptance Scenarios**:

1. **Given** Bia, que revisou 12 solicitações de 4 pessoas e teve 5 solicitações revisadas por 2 pessoas, **When** a tela lista as pessoas, **Then** a linha de Bia mostra "reviewed 12, of 4 people" e "was reviewed on 5, by 2 people".
2. **Given** Caio, que abriu solicitações na janela e ninguém as revisou, **When** a linha dele aparece, **Then** o lado "was reviewed" diz em palavras que nenhuma solicitação dele foi revisada na janela, e não "0".
3. **Given** uma pessoa observada sem solicitação nem revisão na janela, **When** a lista é montada, **Then** ela não aparece na rede, e a contagem de pessoas sem atividade de revisão na janela é dita.

---

### User Story 3 — Ver a forma da rede (Priority: P3)

Quem coordena vê se a revisão forma um bloco só ou grupos que não se revisam entre si: o número de componentes, e quantas pessoas há em cada um.

**Why this priority**: é a primeira leitura estrutural. Grupos isolados indicam silos de revisão. Não é necessária para a decisão da US1.

**Independent Test**: com dois grupos de pessoas que só se revisam entre si, a tela diz "2 groups that do not review each other" e o tamanho de cada um.

**Acceptance Scenarios**:

1. **Given** a rede da janela com dois grupos sem aresta entre eles, **When** a tela abre, **Then** ela diz que há 2 grupos que não se revisam entre si, e quantas pessoas há em cada um.
2. **Given** uma rede conexa, **When** a tela abre, **Then** ela diz que todas as pessoas da rede estão ligadas por revisão, direta ou indiretamente.

---

### Edge Cases

- **Auto-revisão**: quem abriu a solicitação também a revisou. A revisão não vira aresta, e a quantidade de auto-revisões da janela é dita.
- **Revisor ou autor sem pessoa ligada** (login que não se resolveu numa pessoa observada): a revisão não entra na rede, e a quantidade é dita, separada da de bots.
- **Bot ou aplicativo** (a conta observada não é pessoa): fora da rede, com a contagem.
- **A mesma pessoa revisa a mesma solicitação várias vezes** (comentários em rodadas): conta **uma** aresta para aquela solicitação. O peso é o número de solicitações distintas.
- **Revisão pendente** (não enviada): não conta.
- **Revisão descartada depois** (dismissed): conta, porque a revisão aconteceu. A limitação é declarada.
- **Solicitação de outra organização**: nunca entra. Toda leitura é da organização de quem consulta.
- **Pessoa fora do alcance de quem consulta**: não aparece por nome, como par, nem na fração de concentração. A tela diz que há recorte pelo alcance e qual é a regra, **sem dizer quantas revisões ficaram de fora** (R2, decidido em 2026-10-03; precedente de `verification_live/people.ex`, 2026-09-09).
- **Grupos para quem tem alcance parcial**: são contados **só entre as pessoas alcançadas**, como a concentração; quem está fora do alcance não entra em grupo nem em tamanho de grupo (Q4, decidido em 2026-10-03 na aprovação do protótipo). O grupo mínimo da base (3) vale para quem alcança todos.
- **Duas organizações observadas no mesmo tenant**: cada uma tem a sua rede; nenhuma pessoa só da outra aparece (R4).
- **Cálculo ainda não feito, ou falhou**: a tela diz que a leitura não está disponível e por quê. Nunca mostra zero, nem a leitura de outra janela como se fosse esta.
- **Janela com menos revisões que a amostra mínima** (10 revisões, na unidade par revisor–solicitação): as contagens aparecem, e a concentração fica **ausente com motivo**, dizendo o mínimo. Não se mostra fração com aviso (decidido em 2026-10-03: *"75% de 4 revisões"* convida a leitura que o aviso tenta desfazer).
- **Menos revisores que k**: a fração daquele k fica ausente com motivo (*"only 2 people reviewed"*), e não 100%.
- **Conta apagada na origem** (autor ou revisor nulo, "ghost"): entra em **sem pessoa ligada**, e não em bot (decidido em 2026-10-03). "Não sei quem é" não é "é máquina". A coleta hoje a conta como bot (`github_change_requests.ex:321`); a divergência é tarefa desta feature.
- **Coleta terminou depois da leitura** e a leitura não foi renovada: a tela diz, em uma linha, que há coleta mais nova que a leitura (Q3, decidido em 2026-10-03).

## Requirements *(mandatory)*

### Functional Requirements

**A rede**

- **FR-001**: O sistema MUST montar, por **organização observada** (a organização do GitHub dentro do tenant, buscada por id e tenant juntos; decidido em 2026-10-03, R4) e por janela de tempo, uma rede em que cada nó é uma **pessoa observada com tipo de conta pessoa**, nunca um membro de equipe nem uma conta da plataforma. Toda leitura filtra cada tabela pelo tenant.
- **FR-002**: Cada aresta MUST ir de quem **revisou** para quem **abriu** a solicitação de mudança revisada. O peso é o número de solicitações distintas que aquela pessoa revisou daquela outra na janela. A aresta é sobre a revisão. **Nunca** sobre quem fez o merge: Pull Request não é merge.
- **FR-003**: Uma revisão MUST entrar na janela pelo instante em que foi enviada. Revisão pendente não entra.
- **FR-004**: O sistema MUST deixar fora da rede, contando cada caso separadamente e mostrando a contagem:
  - auto-revisões;
  - revisões em que revisor ou autor é bot ou aplicativo;
  - revisões em que revisor ou autor não está ligado a uma pessoa observada.

  As exclusões aparecem só como contagem, nunca com login, e a auto-revisão só no agregado, nunca por pessoa (R5, R9).
- **FR-005**: O mapeamento de "revisão de solicitação de mudança" para aresta da rede MUST estar declarado na base de conhecimento, com grau de equivalência, justificativa e limitações. **Não** se chama de "colaboração".

**As medidas**

- **FR-006**: A necessidade de informação "a revisão está concentrada em poucas pessoas?" MUST estar declarada na base, com a decisão que apoia e os conceitos de que depende.
- **FR-007**: As medidas MUST estar declaradas na base, cada uma com fórmula, unidade, níveis, limitações e interpretações incorretas:
  - revisões feitas por pessoa, e de quantas pessoas distintas;
  - revisões recebidas por pessoa, e de quantas pessoas distintas;
  - número de grupos que não se revisam entre si, **entre pessoas com ao menos uma aresta**, e o tamanho de cada um; para alcance parcial, **só entre as pessoas alcançadas** (Q4);
  - as contagens que a tela mostra ao lado da concentração: revisões, revisores, pessoas revisadas, pessoas sem atividade de revisão e exclusões por motivo (decidido em 2026-10-03 com o protótipo);
  - fração das revisões feitas pelas k pessoas que mais revisaram, para k = 1, 2 e 3, **sem identificar quem**.

  As interpretações incorretas mínimas, em cada medida: a medida não avalia a pessoa; revisar muito não é qualidade nem esforço; revisar pouco não é omissão; a revisão é visível só quando passa pela ferramenta observada (R5).
- **FR-008**: Os valores de k, o tamanho mínimo de amostra para falar em concentração e o tamanho mínimo de grupo abaixo do qual o tamanho não é mostrado a quem não alcança todos os integrantes MUST estar declarados na base com a razão escrita, e não no código (R2).
- **FR-009**: Medida sem valor MUST ser ausente com motivo, nunca zero. Os casos são:
  - a pessoa não revisou;
  - a pessoa não teve solicitação revisada;
  - a janela não teve revisão;
  - a janela teve menos revisões que a amostra mínima (só a concentração);
  - houve menos revisores que k (só a fração daquele k);
  - o cálculo não foi feito.

  Nenhuma medida pode ser substituída por um valor de reserva quando o cálculo falha.

**O cálculo**

- **FR-010**: O cálculo MUST rodar em segundo plano, por organização observada, e conferir antes de ler qualquer dado: o tenant existe e está ativo; a organização pertence ao tenant, buscada por id e tenant juntos; a janela está na lista fechada da base. Qualquer falha cancela o cálculo **sem gravar leitura** (R4).
- **FR-011**: Cada resultado MUST guardar a proveniência:
  - a janela;
  - o instante do cálculo;
  - quantas revisões entraram e quantas ficaram fora, por motivo;
  - a versão do mapeamento e das medidas usadas.
  A leitura guarda identificadores de pessoa, e nunca nome ou login. Existe **uma** leitura vigente por organização observada e janela; a nova substitui a anterior, e a anterior não é guardada: não se acumula histórico de quem revisa quem (R3, R7, decidido em 2026-10-03). O aviso de leitura pronta leva só a identificação da leitura, nunca o conteúdo.
- **FR-012**: Calcular de novo a mesma janela com os mesmos dados MUST dar o mesmo resultado.

**A tela**

- **FR-013**: A tela MUST mostrar a janela em uso e deixar escolher entre 30, 90 e 180 dias, validados no domínio; valor fora da lista é recusado. O padrão é 90. As três janelas são calculadas juntas, ao fim da coleta de revisões, e trocar de janela na tela **não** pede cálculo (R6, decidido em 2026-10-03).
- **FR-014**: Todo número da tela MUST ser marcado como **derivado**, com texto, e toda ausência MUST ser nomeada, dizendo de quem é: da origem ou da plataforma.
- **FR-015**: A leitura que chega à tela MUST ser recortada por **uma** função de domínio, com o alcance de quem consulta **recalculado a cada leitura**, pela mesma regra da tela de pessoas. Pessoa fora do alcance não aparece por nome, como par, nem na fração de concentração, que é calculada só sobre as revisões entre pessoas alcançadas (R1). A linha de pessoa alcançável mostra o total dela, e os pares fora do alcance não viram linha nem número. A tela diz que há recorte e qual é a regra, sem dizer quantas revisões ficaram de fora (R2). Os grupos, para alcance parcial, são só entre pessoas alcançadas (Q4), e as contagens de exclusão, **inclusive a de bot ou aplicativo**, não aparecem (Q5). A tela diz, acima da lista, que a linha traz o total da pessoa na janela e que os pares mostram só quem se alcança.
- **FR-016**: A tela MUST funcionar no telefone: empilhada por padrão, e a tabela com mais de três colunas empilha com o nome da coluna em cada célula.
- **FR-017**: A tela MUST seguir exatamente o protótipo aprovado pela pessoa mantenedora antes do código: [`prototipo/`](prototipo/), aprovado em 2026-10-03 com D1–D10 e as respostas Q1 (sem desenho da rede nesta fatia), Q3, Q4 e Q5.

**O que não se faz**

- **FR-018**: A feature MUST NOT atribuir rótulo de papel a pessoa ("hub", "ponte", "coordenador"), nem classificar pessoa por faixa numérica.
- **FR-018a**: A lista por pessoa MUST ser ordenada por nome. Nenhuma coluna de medida ordena a lista nem se oferece para ordenar, e a tela diz, ao lado da lista, que a medida não avalia pessoa (R5).
- **FR-018b**: A feature MUST NOT oferecer exportação da rede nem da lista por pessoa (R5).
- **FR-019**: A feature MUST NOT comparar a rede com as equipes declaradas, nem calcular coautoria nem índice de mundo pequeno.
- **FR-020**: A rede MUST NOT ser exposta pela API pública, pelo servidor MCP, nem entrar no material de geração de perfil nesta feature. Exposição futura exige spec própria e passa pela função de leitura recortada da FR-015 (R8).
- **FR-021**: O cálculo registra organização, janela, contagens e duração, e MUST NOT registrar par, nome ou login (R14).

### Key Entities

- **Leitura da rede de revisão**: o resultado de um cálculo para uma organização e uma janela. Contém:
  - as arestas com peso;
  - as contagens por pessoa;
  - os grupos;
  - a concentração;
  - as exclusões por motivo;
  - a proveniência.

  É substituída por uma nova leitura, nunca editada.
- **Aresta de revisão**: revisor → autor, com o número de solicitações distintas revisadas na janela. Deriva de avaliação de artefato (QAPO) sobre solicitação de mudança (CMPO), entre duas pessoas observadas (EO).
- **Exclusão**: uma revisão que não virou aresta, com o motivo:
  - auto-revisão;
  - bot ou aplicativo;
  - pessoa não ligada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para uma organização real, as contagens da tela — revisões, revisores, concentração das três primeiras, exclusões por motivo — batem com uma contagem manual das mesmas revisões na origem, para a mesma janela, sem diferença.
- **SC-002**: Nenhum número da tela aparece como zero quando o fato é ausência: verificado em uma organização sem revisão na janela e em uma pessoa sem solicitação revisada.
- **SC-003**: Quem coordena responde "a revisão está concentrada?" em menos de um minuto, a partir da tela, sem consultar outra fonte.
- **SC-004**: Uma pessoa de outro tenant, de outra organização observada, ou fora do alcance de quem consulta, nunca aparece por nome nem entra na fração de concentração, e a tela de alcance parcial não diz quantas revisões ficaram fora: verificado com dois tenants, duas organizações observadas e uma conta de alcance restrito.
- **SC-005**: Recalcular a mesma janela duas vezes dá o mesmo resultado, em 10 de 10 repetições.

## Assumptions

- **O que conta como revisão**: toda avaliação de artefato **enviada** sobre a solicitação — aprovação, pedido de mudança, comentário, e também a que foi descartada depois. A pendente fica fora.
- **Peso**: solicitações **distintas**, e não eventos de revisão. Rodadas de comentário inflariam quem comenta muito em poucas solicitações.
- **Janela padrão de 90 dias**, com 30 e 180 como alternativas. É escolha inicial, e não vem de outra medida: a base não declara janela para as medidas de fluxo, que se recortam por sprint. O protótipo a confirma ou troca.
- **k = 1, 2, 3, amostra mínima e grupo mínimo** declarados na base. A amostra mínima é de **10 revisões** (pares revisor–solicitação, a mesma unidade do denominador da concentração; decidido em 2026-10-03), com a razão escrita: abaixo disso, uma revisão a mais muda a fração em mais de dez pontos. O grupo mínimo é **3** (decidido em 2026-10-03).
- **O alcance** segue a regra já usada na tela de pessoas (feature 058). Quem administra vê todas as pessoas do próprio tenant (#1181).
- **A rede é recalculada** quando a coleta de revisões termina, nas três janelas. A tela mostra o instante da leitura.
- **Sem dependência nova**: o cálculo em escala de dezenas a centenas de pessoas cabe no que a plataforma já tem. A confirmação é do plano.

## Dependências

- Revisões e solicitações de mudança coletadas, com autor resolvido em pessoa observada (já existe).
- A classificação de conta como pessoa, bot ou aplicativo (já existe).
- A regra de alcance da tela de pessoas (feature 058), com a #1181 (`pessoas_alcancadas/2` compara o tenant) mergeada antes da tarefa que lê a rede com alcance (R11; PR #1183).
- **Avaliação do agente `security` antes do código**: feita em [seguranca.md](seguranca.md) (R1–R14), com as emendas incorporadas acima e as decisões da pessoa mantenedora de 2026-10-03 sobre R1, R2, R4, R6 e R7.
- **Protótipo aprovado pela pessoa mantenedora** antes do código da tela: aprovado em 2026-10-03 ([`prototipo/`](prototipo/)).
