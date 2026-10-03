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

Quem coordena o time abre a rede de revisão da organização numa janela de tempo. Vê quantas solicitações de mudança foram revisadas, por quantas pessoas, e **que fração** das revisões coube às uma, duas e três pessoas que mais revisaram. Com isso decide se precisa redistribuir a revisão antes que uma ausência pare o fluxo.

**Why this priority**: é a pergunta da necessidade de informação, e responde sozinha a uma decisão: redistribuir ou não.

**Independent Test**: com revisões coletadas de uma organização, a tela mostra o total, a contagem de revisores e a concentração das três primeiras pessoas, e os números batem com uma contagem manual das mesmas revisões.

**Acceptance Scenarios**:

1. **Given** uma organização com 40 solicitações revisadas nos últimos 90 dias, 30 delas por Ana, **When** quem coordena abre a rede de revisão, **Then** a tela diz que a pessoa que mais revisou fez 75% das revisões e nomeia Ana, com a janela escrita.
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
- **Pessoa fora do alcance de quem consulta**: aparece só como contagem ("N reviews involve people outside your reach"), sem nome e sem par.
- **Cálculo ainda não feito, ou falhou**: a tela diz que a leitura não está disponível e por quê. Nunca mostra zero, nem a leitura de outra janela como se fosse esta.
- **Janela com uma só revisão**: os números aparecem, e a tela avisa que a amostra é pequena demais para falar em concentração.

## Requirements *(mandatory)*

### Functional Requirements

**A rede**

- **FR-001**: O sistema MUST montar, por organização e por janela de tempo, uma rede em que cada nó é uma **pessoa observada**, nunca um membro de equipe nem uma conta da plataforma.
- **FR-002**: Cada aresta MUST ir de quem **revisou** para quem **abriu** a solicitação de mudança revisada. O peso é o número de solicitações distintas que aquela pessoa revisou daquela outra na janela. A aresta é sobre a revisão. **Nunca** sobre quem fez o merge: Pull Request não é merge.
- **FR-003**: Uma revisão MUST entrar na janela pelo instante em que foi enviada. Revisão pendente não entra.
- **FR-004**: O sistema MUST deixar fora da rede, contando cada caso separadamente e mostrando a contagem:
  - auto-revisões;
  - revisões em que revisor ou autor é bot ou aplicativo;
  - revisões em que revisor ou autor não está ligado a uma pessoa observada.
- **FR-005**: O mapeamento de "revisão de solicitação de mudança" para aresta da rede MUST estar declarado na base de conhecimento, com grau de equivalência, justificativa e limitações. **Não** se chama de "colaboração".

**As medidas**

- **FR-006**: A necessidade de informação "a revisão está concentrada em poucas pessoas?" MUST estar declarada na base, com a decisão que apoia e os conceitos de que depende.
- **FR-007**: As medidas MUST estar declaradas na base, cada uma com fórmula, unidade, níveis, limitações e interpretações incorretas:
  - revisões feitas por pessoa, e de quantas pessoas distintas;
  - revisões recebidas por pessoa, e de quantas pessoas distintas;
  - número de grupos que não se revisam entre si, e o tamanho de cada um;
  - fração das revisões feitas pelas k pessoas que mais revisaram, para k = 1, 2 e 3.
- **FR-008**: Os valores de k e o tamanho mínimo de amostra para falar em concentração MUST estar declarados na base com a razão escrita, e não no código.
- **FR-009**: Medida sem valor MUST ser ausente com motivo, nunca zero. Os casos são:
  - a pessoa não revisou;
  - a pessoa não teve solicitação revisada;
  - a janela não teve revisão;
  - o cálculo não foi feito.

  Nenhuma medida pode ser substituída por um valor de reserva quando o cálculo falha.

**O cálculo**

- **FR-010**: O cálculo MUST rodar em segundo plano, por organização, e conferir a organização antes de ler qualquer dado.
- **FR-011**: Cada resultado MUST guardar a proveniência:
  - a janela;
  - o instante do cálculo;
  - quantas revisões entraram e quantas ficaram fora, por motivo;
  - a versão do mapeamento e das medidas usadas.
- **FR-012**: Calcular de novo a mesma janela com os mesmos dados MUST dar o mesmo resultado.

**A tela**

- **FR-013**: A tela MUST mostrar a janela em uso e deixar escolher entre 30, 90 e 180 dias. O padrão é 90.
- **FR-014**: Todo número da tela MUST ser marcado como **derivado**, com texto, e toda ausência MUST ser nomeada, dizendo de quem é: da origem ou da plataforma.
- **FR-015**: A tela MUST respeitar o alcance de quem consulta, com a mesma regra da tela de pessoas. Pessoas fora do alcance não aparecem por nome nem como par; as revisões que as envolvem aparecem só como contagem.
- **FR-016**: A tela MUST funcionar no telefone: empilhada por padrão, e a tabela com mais de três colunas empilha com o nome da coluna em cada célula.
- **FR-017**: A tela MUST seguir exatamente o protótipo aprovado pela pessoa mantenedora antes do código.

**O que não se faz**

- **FR-018**: A feature MUST NOT atribuir rótulo de papel a pessoa ("hub", "ponte", "coordenador"), nem classificar pessoa por faixa numérica.
- **FR-019**: A feature MUST NOT comparar a rede com as equipes declaradas, nem calcular coautoria nem índice de mundo pequeno.

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
- **SC-004**: Uma pessoa de outra organização, ou fora do alcance de quem consulta, nunca aparece por nome: verificado com duas organizações e com uma conta de alcance restrito.
- **SC-005**: Recalcular a mesma janela duas vezes dá o mesmo resultado, em 10 de 10 repetições.

## Assumptions

- **O que conta como revisão**: toda avaliação de artefato **enviada** sobre a solicitação — aprovação, pedido de mudança, comentário, e também a que foi descartada depois. A pendente fica fora.
- **Peso**: solicitações **distintas**, e não eventos de revisão. Rodadas de comentário inflariam quem comenta muito em poucas solicitações.
- **Janela padrão de 90 dias**, com 30 e 180 como alternativas. É escolha inicial, e não vem de outra medida: a base não declara janela para as medidas de fluxo, que se recortam por sprint. O protótipo a confirma ou troca.
- **k = 1, 2, 3 e amostra mínima** declarados na base. A amostra mínima começa em 10 solicitações revisadas, com a razão escrita: abaixo disso, uma revisão a mais muda a fração em mais de dez pontos.
- **O alcance** segue a regra já usada na tela de pessoas (feature 058). Quem administra vê todas as pessoas da organização.
- **A rede é recalculada** quando a coleta de revisões termina e quando alguém pede outra janela. A tela mostra o instante da leitura.
- **Sem dependência nova**: o cálculo em escala de dezenas a centenas de pessoas cabe no que a plataforma já tem. A confirmação é do plano.

## Dependências

- Revisões e solicitações de mudança coletadas, com autor resolvido em pessoa observada (já existe).
- A classificação de conta como pessoa, bot ou aplicativo (já existe).
- A regra de alcance da tela de pessoas (feature 058).
- **Avaliação do agente `security` antes do código**: a feature mostra quem revisa quem, que é dado sobre pessoa (AGENTS.md §14.0).
- **Protótipo aprovado pela pessoa mantenedora** antes do código da tela.
