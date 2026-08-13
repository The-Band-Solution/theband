# Feature Specification: a tabela que busca, ordena e pagina

**Feature**: `017-tabela-que-busca-ordena-e-pagina` · **Criada em**: 2026-08-13
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#289](https://github.com/The-Band-Solution/theband/issues/289), pedido da pessoa mantenedora

## O pedido

> "Toda tabela tem search, ordenação por coluna, e paginação com índice 1, 2, … X."

## A decisão de base, já tomada

**Componente próprio.** A pessoa mantenedora decidiu em 2026-08-13, depois de usar três protótipos
funcionais lado a lado com os mesmos dados reais.

| Recusado | Por quê |
|---|---|
| Petal Components | traz o próprio CSS e vocabulário de classe, e o daisyUI já define `btn`, `badge`, `table` |
| Backpex | vira **dono da tela** — e estas telas dizem o que a plataforma observou **e o que ela recusa afirmar** |

---

## O que a medida achou

**Medido em 2026-08-13**, no banco de desenvolvimento:

| O que | Custo |
|---|---:|
| contar as 4 529 issues para a paginação numerada | **6,8 ms** |
| contar com filtro de busca aplicado | **4,9 ms** |
| ordenar por **conceito derivado**, 25 de 4 529 | **14,2 ms** |

**A paginação numerada é barata, e isso não era óbvio.** O receio era o custo de contar — a
plataforma acabou de sair de uma tela de 6,12 s por uma consulta que ninguém tinha medido. Contar
custa 7 ms.

**O caro é ordenar pelo que não existe no banco.** `conceito` vem da promoção vigente e `part of`
vem do axioma: ordenar por eles resolve a derivação para as **4 529** antes de cortar 25.

### As sete tabelas não são iguais

| Tela | Linhas |
|---|---:|
| `/work` | **4 529** |
| `/work/repositories/:id` | até **2 514** numa só |
| `/people` | 75 |
| `/teams` | 12 |
| `/syncs`, `/tools` | dezenas |

**Uma tabela de 12 linhas e uma de 4 529 não pedem a mesma solução** — e o componente precisa servir
às duas ou declarar o limiar.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Achar uma linha sem varrer a lista (Priority: P1)

Quem procura uma issue digita parte do título e a lista responde.

**Por que é P1**: é o primeiro pedido, e hoje achar `#1811` entre 4 529 exige paginar até ela.

**Cenários de aceitação**

1. **Dado** o texto digitado, **quando** a lista é exibida, **então** ela mostra as linhas que casam
   — **de todas as 4 529**, e não das 25 da página.
2. **Dado** que a busca não casa com nada, **quando** a lista é exibida, **então** ela **diz isso**,
   com o texto procurado — nunca uma tabela vazia sem explicação.
3. **Dado** uma busca ativa, **quando** a paginação é exibida, **então** o total é o das linhas que
   casam.
4. **Dado** que apaguei a busca, **quando** a lista volta, **então** volto para a primeira página.
5. **Dado** que a tela declara em quais colunas busca, **quando** alguém procura por algo que está
   noutra, **então** não encontra — e a tela **diz onde ela procura**.

---

### User Story 2 - Ordenar pela coluna que interessa (Priority: P1)

Clicar no cabeçalho ordena por aquela coluna, e clicar de novo inverte.

**Por que é P1**: é o segundo pedido, e é onde o domínio entra.

**Cenários de aceitação**

1. **Dado** o cabeçalho de uma coluna, **quando** clico, **então** a lista ordena por ela, e a
   direção fica visível **sem depender de cor**.
2. **Dado** que ordenei por uma coluna **derivada** — conceito ou `part of` —, **quando** a lista é
   exibida, **então** a ordem é a do valor exibido, e não a de um campo que não existe.
3. **Dado** que a coluna tem valores repetidos, **quando** a lista é exibida duas vezes, **então**
   a ordem é **a mesma** — o desempate é determinístico.
4. **Dado** que ordenei e paginei, **quando** vou para a página 3, **então** a ordem continua, e
   nenhuma linha aparece em duas páginas.
5. **Dado** uma coluna que **não** ordena, **quando** o cabeçalho é exibido, **então** ele não
   parece clicável.

---

### User Story 3 - Ir direto à página que quero (Priority: P1)

A paginação mostra os índices — 1, 2, 3 … X — e diz onde estou.

**Por que é P1**: é o terceiro pedido, e é o que a paginação de hoje não faz.

**Cenários de aceitação**

1. **Dado** 4 529 linhas com 25 por página, **quando** a paginação é exibida, **então** ela mostra
   os índices e o **total de páginas**.
2. **Dado** que estou na página 7, **quando** a paginação é exibida, **então** a 7 está marcada, e
   marcada por mais do que cor.
3. **Dado** que há mais páginas do que cabem, **quando** a paginação é exibida, **então** ela
   encurta com reticências e **preserva a primeira, a última e as vizinhas da atual**.
4. **Dado** a primeira página, **quando** a paginação é exibida, **então** "anterior" está
   desabilitado — e não some.
5. **Dado** 12 linhas e 25 por página, **quando** a tela é exibida, **então** **não há paginação** —
   uma única página não precisa de índice.

---

### Edge Cases

- **A última página com uma linha só**: continua sendo página, e o total não muda.
- **Buscar e mudar de página ao mesmo tempo**: a busca reseta para a primeira página, sempre.
- **Ordenar por coluna derivada em 2 514 linhas**: é o pior caso medido, e a spec exige medida antes
  e depois.
- **Telefone**: a tabela vira cartão, e **cabeçalho clicável não existe em cartão** — a ordenação
  precisa de outro gesto abaixo de 360 px.
- **Duas abas na mesma lista**: cada uma mantém a própria busca e página; o estado vive na URL.
- **Recarregar a página** com busca e ordem ativas: as duas sobrevivem, porque estão na URL.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A busca MUST alcançar **todas** as linhas da consulta, nunca só a página exibida.
- **FR-002**: Cada tela MUST declarar em quais colunas a busca procura, e a tela MUST dizer isso a
  quem lê.
- **FR-003**: Busca sem resultado MUST ser dita com o texto procurado.
- **FR-004**: A ordenação MUST funcionar também nas colunas **derivadas**, pelo valor exibido.
- **FR-005**: A ordenação MUST ter desempate determinístico — a mesma lista, duas vezes, é igual.
- **FR-006**: A direção da ordem MUST ser visível sem depender de cor.
- **FR-007**: Coluna não ordenável MUST NOT parecer clicável.
- **FR-008**: A paginação MUST mostrar índices numerados e o total de páginas.
- **FR-009**: Com uma única página, a paginação MUST NOT ser exibida.
- **FR-010**: Busca, ordem e página MUST viver na **URL** — recarregar preserva, e o endereço é
  compartilhável.
- **FR-011**: O componente MUST ser um só, e cada tela MUST apenas declarar colunas e escopo.
- **FR-012**: A medida de custo MUST ser registrada antes e depois, nas duas maiores tabelas.
- **FR-013**: Em 360 px, ordenar MUST continuar possível sem cabeçalho clicável.

### Key Entities

- **Coluna**: rótulo, valor, e **se ordena** — e se o valor é do banco ou derivado.
- **Escopo da busca**: quais colunas cada tela expõe à procura. É declaração, não adivinhação.
- **Página**: índice, tamanho e total — e o total custa uma contagem.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: As **sete** tabelas usam o mesmo componente.
- **SC-002**: Buscar `pipeline` em `/work` encontra as linhas que casam entre as **4 529**, e não
  entre as 25 exibidas.
- **SC-003**: A lista de trabalho continua abaixo de **200 ms** com busca e ordenação ativas — hoje
  são 120 ms sem elas.
- **SC-004**: Ordenar por conceito derivado em `/work` custa menos de **50 ms** — medido em 14,2 ms
  na consulta isolada.
- **SC-005**: A mesma lista, ordenada e desenhada duas vezes, produz a **mesma** ordem.
- **SC-006**: Recarregar a página com busca e ordem ativas devolve a mesma tela.
- **SC-007**: `/teams`, com 12 linhas, **não** exibe paginação.
- **SC-008**: Em 360 px, ordenar continua possível nas sete telas.

---

## Assumptions

- **A paginação numerada é viável**: contar custa **6,8 ms** hoje, e a busca com filtro **4,9 ms**.
  Em bases maiores isso muda, e a FR-012 existe para que se meça de novo.
- A busca é por texto contido, sem acento nem ordem de palavras. Busca semântica é outro trabalho —
  e é o item 037 do roadmap.
- **O estado na URL vale mais que a memória de sessão**: um endereço com busca e ordem é
  compartilhável, e é como se pede ajuda sobre uma lista.
- As colunas derivadas continuam derivadas. Materializá-las para facilitar a ordenação seria desfazer
  a decisão da feature 013 e violar a ADR 0004 D7.
