# Feature Specification: clicar leva à página

**Feature**: `014-clicar-leva-a-pagina` · **Criada em**: 2026-08-13
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#281](https://github.com/The-Band-Solution/theband/issues/281), pedido da pessoa mantenedora

## O pedido

> "Em qualquer página, ao clicar em um elemento devo ser levado à tela dele. Por exemplo, ao clicar
> em um repositório devo ir para a página do repositório; se clicar no nome de uma pessoa, devo ir
> para a página dela."

---

## O que a medida achou, e ela encolhe o pedido

**Medido na aplicação em execução, em 2026-08-13**, contando quais nomes aparecem em cada tela e
quantos deles estão dentro de uma ligação:

| Tela | Nomes que já levam à página | Texto morto |
|---|---:|---:|
| lista de trabalho | **135** repositórios | 0 |
| lista de pessoas | todos | 0 |
| detalhe da pessoa | 8 repositórios | 0 |
| lista do repositório | pais e repositórios | 0 |
| **detalhe da equipe** | 0 | **os membros** |
| **detalhe da issue** | o repositório (botão) | **autor e designados** |

**A plataforma já liga quase tudo.** O que falta está em **dois lugares**, e é sempre a mesma coisa:
o **nome de uma pessoa** exibido como texto onde ela tem página.

### Quantas ligações nascem

| Onde | Quantos |
|---|---:|
| designados de issue **com** pessoa coletada | **4 229** |
| autores de issue **com** pessoa coletada | **4 241** |
| membros de equipe | os que a equipe tiver, sobre **88** evidências |

### E quantos nomes **não** podem virar ligação

| Caso | Casos | Logins distintos | Por quê |
|---|---:|---:|---|
| autor com login e **sem** pessoa coletada | 286 | **14** | a pessoa não foi observada; a tela já diz *"person not collected"* |
| designado sem pessoa coletada | 2 | **1** | idem |
| organização, na lista de pessoas e nas sincronizações | — | — | **não existe página de organização** |

**Quinze pessoas, 288 aparições — e é o coração da feature, não a exceção.**

A plataforma coleta pessoas de **duas** fontes: a coleta de EO traz os **75** membros da organização
e das equipes, com proveniência; a coleta de issues traz o `author_login`, que é **texto escrito pelo
GitHub**, não pessoa. Quando os dois se encontram, há destino. Quando não — alguém que saiu da
organização, nunca entrou, ou contribuiu de fora —, sobra o login.

E a plataforma **não cria a pessoa a partir da issue**, o que já está escrito no código:

> *"A login with no linked person is a declaration, not a failure: the person was not collected, and
> creating them from the issue would produce a record with no provenance."*

Criar `sofialctv` — 64 issues, nenhuma pessoa coletada — produziria um registro cuja única evidência
é "apareceu como autora": sem quando foi observada, sem tipo de conta, sem organização.

**A saída fácil é a errada duas vezes.** Ligar todos os nomes por uniformidade produz cliques que não
levam a lugar nenhum; "resolver" criando as pessoas faz a plataforma afirmar **90** pessoas onde
observou **75**.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Do trabalho para quem o fez (Priority: P1)

Quem lê o detalhe de uma issue clica no nome do autor ou de um designado e chega na página daquela
pessoa.

**Por que é P1**: são **8 470** nomes hoje sem saída, e é o caminho que o pedido cita.

**Teste independente**: abrir uma issue com autor e designados coletados e chegar às páginas deles.

**Cenários de aceitação**

1. **Dado** uma issue cujo autor foi coletado, **quando** clico no nome dele, **então** a página
   dessa pessoa abre.
2. **Dado** uma issue com designados coletados, **quando** clico em um deles, **então** a página
   dele abre.
3. **Dado** um autor **sem** pessoa coletada, **quando** a issue é exibida, **então** o login
   aparece **sem** ligação, e a tela continua dizendo que a pessoa não foi coletada.
4. **Dado** que navego por teclado, **quando** chego ao nome, **então** ele recebe foco visível e
   abre com `Enter`.
5. **Dado** que não distingo cores, **quando** vejo a linha, **então** consigo dizer o que é
   ligação sem depender de cor.

---

### User Story 2 - Da equipe para quem participa dela (Priority: P1)

Quem lê o detalhe de uma equipe clica no nome de um membro e chega na página dele.

**Por que é P1**: é o mesmo movimento da US1, na outra tela onde ele falta.

**Teste independente**: abrir uma equipe com membros e chegar à página de um deles.

**Cenários de aceitação**

1. **Dado** uma equipe com membros, **quando** clico no nome de um, **então** a página dele abre.
2. **Dado** um membro cuja participação **não é mais observada**, **quando** a linha é exibida,
   **então** ela continua clicável e continua marcada como não observada — a pessoa existe, a
   participação é que acabou.
3. **Dado** o login exibido abaixo do nome, **quando** clico em qualquer um dos dois, **então**
   chego ao mesmo lugar.

---

### User Story 3 - Nome sem destino não vira ligação (Priority: P1)

Nome que não tem página **continua texto** — e a tela diz por quê.

**Por que é P1**: é o requisito que impede a feature de virar um defeito. Ligação que não leva a
lugar nenhum é pior que texto: ela promete.

**Teste independente**: uma issue com autor não coletado e uma organização exibida na lista de
pessoas não produzem nenhuma ligação.

**Cenários de aceitação**

1. **Dado** um login sem pessoa coletada, **quando** a tela é exibida, **então** não há ligação, e
   a razão continua escrita.
2. **Dado** o nome de uma organização, **quando** a tela é exibida, **então** ele não é ligação —
   **não existe página de organização**, e inventar uma rota seria afirmar tela que não existe.
3. **Dado** qualquer nome exibido, **quando** ele é ligação, **então** o destino existe e responde
   — nenhuma ligação aponta para rota inexistente.

---

### Edge Cases

- **A pessoa de outro tenant**: a ligação nunca aparece, porque o nome nunca aparece.
- **A mesma pessoa duas vezes na mesma tela** — autora e designada da mesma issue: as duas levam ao
  mesmo lugar, e a tela não muda de comportamento por isso.
- **Clique na linha inteira**: a ligação é no **nome**, nunca na linha — clicar na linha sequestra a
  seleção de texto de quem quer copiar um título.
- **Nome vazio**: pessoa sem `name` exibe o `login`, e é ele que vira a ligação.
- **A página de destino apagada entre o render e o clique**: responde `não encontrado`, e não erro.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O nome de uma pessoa MUST levar à página dela sempre que a pessoa estiver coletada.
- **FR-002**: Login **sem** pessoa coletada MUST NOT virar ligação, e a razão já exibida MUST
  permanecer.
- **FR-003**: Nome de entidade **sem página** — organização, hoje — MUST NOT virar ligação.
- **FR-004**: A ligação MUST envolver o **nome**, nunca a linha inteira.
- **FR-005**: Toda ligação MUST ser alcançável e acionável por teclado, com foco visível.
- **FR-006**: O que é ligação MUST ser distinguível **sem depender de cor**.
- **FR-007**: Nenhuma ligação MUST apontar para rota inexistente.
- **FR-008**: A navegação MUST permanecer **dentro** da plataforma — o nome não abre a origem. O
  botão que leva ao GitHub já existe e continua separado.
- **FR-009**: O conteúdo exibido MUST permanecer o mesmo: ligar um nome não muda o que a tela diz.
- **FR-010**: Nenhuma consulta nova MUST ser acrescentada por linha — o identificador da pessoa já
  viaja nos dados que a tela carrega.

### Key Entities

- **Pessoa**: tem página, e é o destino de quase toda ligação desta feature.
- **Login sem pessoa**: a origem nomeou alguém que a plataforma não coletou. Tem nome e **não** tem
  destino — e é o caso que a feature precisa preservar.
- **Organização**: aparece em duas telas e **não tem página**.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: No detalhe de uma issue, **todo** autor e designado com pessoa coletada leva à página
  dela — hoje são **8 470** nomes sem saída.
- **SC-002**: No detalhe de uma equipe, todo membro leva à página dele.
- **SC-003**: As **288** aparições sem pessoa coletada — **15** logins distintos — continuam **sem**
  ligação, e a frase que explica continua na tela.
- **SC-003b**: A contagem de pessoas em `eo_people` **não muda**: continuam **75**. Nenhuma pessoa é
  criada para dar destino a um nome.
- **SC-004**: Nenhum nome de organização vira ligação.
- **SC-005**: Uma varredura das telas afetadas encontra **zero** ligações apontando para rota que
  não responde.
- **SC-006**: O número de consultas por render **não muda** em nenhuma das telas afetadas.
- **SC-007**: O conteúdo textual de cada tela afetada permanece **idêntico** ao de hoje — muda o que
  é clicável, não o que está escrito.

---

## Assumptions

- **A medida é de 2026-08-13**, e os números vêm do banco de desenvolvimento: 4 229 designações e
  4 241 autorias com pessoa coletada; 288 aparições sem, concentradas em **15** logins.
- **A lista de trabalho, a lista de pessoas, o detalhe da pessoa e a lista do repositório já ligam
  o que precisam** — a feature não os toca, e o teste confere que continuam ligando.
- **Organização não ganha página nesta feature.** Criar a rota é decisão de produto, e transformaria
  o pedido em outro trabalho.
- O identificador da pessoa já está nos dados que as telas carregam — `author_person_id`,
  `assignees[].person_id` e `member.person.id`. **Nenhuma consulta nova é necessária**, e a FR-010
  existe para que isso seja verificado em vez de suposto.
