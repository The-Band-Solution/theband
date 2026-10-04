# Feature Specification: O site de desenvolvedores com a identidade de theband.dev, em português e inglês

**Feature Branch**: `feature/1267-site-de-desenvolvedores`

**Created**: 2026-10-03

**Status**: Draft

**Input**: issue #1267 (critérios AC1 a AC12, decisões D1 e D3 no comentário), o protótipo aprovado em
[`docs/site-developers/prototipo/`](../../docs/site-developers/prototipo/README.md) (régua M1–M9, 1.1–6.6
e F1–F3 do [`PROMPT.md`](../../docs/site-developers/prototipo/PROMPT.md)), e as decisões da pessoa
mantenedora de 2026-10-03, transcritas na seção *Decisões*.

## O que a pessoa vê ao final

Quem clica em *Documentação técnica* na landing de theband.dev chega a `theband.dev/developers/` e
continua no mesmo produto, visualmente: papel e tinta, verdete e latão, serifa nos títulos, nenhuma
fonte da web. O topo e o rodapé levam de volta à landing, à página do produto e à plataforma. Um
seletor troca o site entre português e inglês. As funcionalidades novas (064, 070 a 074) têm página.
Endereço que não existe responde com uma página que diz o que aconteceu e por onde seguir.

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| MkDocs 1.6.1 e Material 9.7.7, fixados com `==`; tema `indigo` e Roboto do Google Fonts | `requirements-docs.txt`, `mkdocs.yml` |
| o Material carrega o Mermaid de `https://unpkg.com/mermaid@11/dist/mermaid.min.js`, **só se** `mermaid` não estiver definido na página | `material/templates/assets/javascripts/bundle.*.min.js`, função `as()` |
| `mkdocs build --strict` **reprova hoje em `development`**: quatro links `../../specs/` em `docs/sprints/036-…` e `037-…` apontam para `docs/specs/`, um `../` a menos | build de 2026-10-03, código de saída 1 |
| 53 páginas de `docs/` fora do `nav`, entre elas as ADRs 0009 e 0010, as releases v0.10.1 a v0.12.0 e três modelos da 070 | o mesmo build, aviso de páginas omitidas |
| o workflow `docs.yml` só roda em push na `main`: nenhum PR constrói o site | `.github/workflows/docs.yml` |
| o guarda do deploy confere `CNAME`, `index.html` da raiz e `docs/index.html`; a raiz da `gh-pages` não tem `404.html` | `docs.yml`; `git ls-tree origin/gh-pages` |
| a landing é bilíngue (PT e EN, com botão), e os tokens dela estão em `gh-pages:index.html` | `git show origin/gh-pages:index.html`, linhas 18-54 |
| a `producao/prototipo-fila-parada/seguranca.md` e a seção `docs/seguranca/` são publicadas hoje | o build; o `nav` |
| issues de segurança abertas: nenhuma toca o site de documentação | `gh issue list --label security --state open`, 2026-10-03 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A mesma identidade, e o caminho de volta (Priority: P1)

Quem chega da landing reconhece o produto: tokens, tipografia, topo e rodapé de theband.dev, nos dois
temas, na mesa e a 360 px. De qualquer página volta à landing, à página do produto e à plataforma.

**Why this priority**: é o pedido da pessoa mantenedora; sem isso a troca de identidade no clique diz a
quem lê que saiu do The Band.

**Independent Test**: construir o site, abrir três páginas em 360 px e 1280 px nos dois temas; comparar
os tokens do CSS publicado com `gh-pages:index.html`; conferir os quatro links de saída com `curl`.

**Acceptance Scenarios**:

1. **Given** o site construído, **When** se compara o CSS do tema com a landing, **Then** os nove tokens
   têm os mesmos valores nos dois temas, declarados uma vez, com a data da cópia (M1, AC2).
2. **Given** qualquer página, **When** ela carrega, **Then** nenhuma requisição sai para outro domínio:
   sem Google Fonts, sem CDN do Mermaid (M2, F3, AC11).
3. **Given** uma página a 360 px, **When** ela é aberta, **Then** a página não rola na horizontal; a
   tabela larga rola dentro do próprio quadro ou empilha (M7, M8, AC4).
4. **Given** o topo e o rodapé, **When** se seguem os links, **Then** chegam a `theband.dev/`,
   `/docs/`, `app.theband.dev/sign-in` e ao GitHub (M3, M5, AC3).

---

### User Story 2 - O site em português e em inglês (Priority: P1)

Quem lê escolhe o idioma num seletor, e o site inteiro troca: moldura e conteúdo. O português é o
padrão. Enquanto uma página não tem tradução, a versão inglesa diz isso em vez de fingir que é inglês.

**Why this priority**: decisão da pessoa mantenedora em 2026-10-03; a landing é bilíngue, e um
seletor que troca só a moldura prometeria o que não entrega (Q3 do protótipo).

**Independent Test**: abrir uma página em PT, trocar para EN pelo seletor e chegar à mesma página em
EN; numa página sem tradução, ver o aviso nomeado em inglês; no build, ler a contagem de páginas sem
tradução.

**Acceptance Scenarios**:

1. **Given** uma página em PT com tradução, **When** se troca o idioma, **Then** abre a mesma página
   em EN, e o seletor marca o idioma atual.
2. **Given** uma página em PT sem tradução, **When** se abre a versão EN, **Then** a página mostra a
   marca de ausente "translation pending" com a frase que diz que o texto está em português.
3. **Given** o build, **When** ele termina, **Then** o log diz quantas páginas PT não têm EN, e com a
   opção de exigência ligada o build reprova enquanto houver alguma.

---

### User Story 3 - O conteúdo novo, e as ausências nomeadas (Priority: P1)

Quem procura as funcionalidades novas encontra uma página por funcionalidade (064, 070 a 074), escrita
para quem usa, com o link para a spec no GitHub. Endereço que não existe, busca sem JavaScript e
diagrama sem script dizem o que falta e de quem é a falta.

**Why this priority**: a segunda metade da necessidade da #1267; e o AC6 é regra da casa
(ausência é nomeada, nunca área em branco).

**Independent Test**: as seis páginas existem com a forma D14; a home lista as seis com a marca de
onde cada uma está; `/developers/qualquer-coisa/` mostra a 404 do site; com JavaScript desligado a
busca diz que precisa dele; sem o script do Mermaid a figura mostra o código.

**Acceptance Scenarios**:

1. **Given** a home, **When** ela renderiza, **Then** a seção III lista 064, 070, 071, 072, 073 e 074
   com spec, status, data, onde está e a marca de ausente que couber (1.5, AC10).
2. **Given** uma página de funcionalidade, **When** ela abre, **Then** tem recibo, "O que você passa a
   conseguir fazer", "O que a tela recusa, e diz por quê" e "O que ela não faz", e nenhum link para
   `seguranca*.md`, `tasks.md` ou `research.md` como página do site (6.1–6.6).
3. **Given** um endereço inexistente sob `/developers/`, **When** ele é pedido, **Then** a resposta é
   a 404 do site, com o caminho pedido, a explicação e os links de saída (5.1).
4. **Given** um endereço inexistente fora de `/developers/`, **When** ele é pedido, **Then** a
   resposta é a 404 neutra de theband.dev, com os links para os três sites.

---

### User Story 4 - O site não quebra em silêncio (Priority: P2)

Todo PR constrói o site em modo estrito e varre os links; página fora da navegação reprova, salvo a
lista declarada; o guarda do deploy continua de pé.

**Why this priority**: o build estrito já reprova em `development` sem ninguém saber, porque nenhum PR
o roda (fato medido acima).

**Independent Test**: um PR com um link quebrado injetado reprova no check; um `.md` novo fora do
`nav` reprova; o guarda do `docs.yml` aborta sem `CNAME`.

**Acceptance Scenarios**:

1. **Given** um PR que toca a documentação, **When** o CI roda, **Then** `mkdocs build --strict` e a
   varredura de links rodam e o veredito é o código de saída (AC7, AC8).
2. **Given** um `.md` novo fora do `nav` e fora de `not_in_nav`, **When** o build roda, **Then**
   reprova (Q7).
3. **Given** a publicação, **When** ela escreve o `404.html` da raiz, **Then** o guarda continua
   abortando se `CNAME`, `index.html` ou `docs/index.html` sumirem, e passa a abortar se o `404.html`
   não ficar (AC12).

### Edge Cases

- **Página nova em PT sem EN**: aparece na versão EN com a marca "translation pending", nunca como 404.
- **Página EN sem PT**: não existe; a regra é PT primeiro (traducao.md).
- **Hash do Mermaid que não confere**: o build reprova, com o hash esperado e o obtido.
- **O commit do build não é obtível** (árvore sem `.git`): a faixa diz "commit do build: não
  informado", nunca um valor inventado.
- **Spec só num PR aberto** (073, 074): não tem página até o merge (E5); a home diz onde está e
  "entra quando o PR for mergeado".
- **Busca sem resultado**: diz que nenhuma página fala do termo e qual é o alcance da busca (4.3).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O tema MUST usar os tokens copiados de `gh-pages:index.html`, nos dois temas, declarados
  uma vez, com a data da cópia no comentário (M1, AC2).
- **FR-002**: O site MUST NOT fazer requisição a outro domínio em tempo de leitura: `font: false`,
  Mermaid servido pelo site, com o hash conferido no build (M2, F3, AC11).
- **FR-003**: Topo, faixa do build e rodapé MUST seguir M3, M4 e M5, com os links de AC3. A faixa
  mostra o commit e a data do build como observado e "versão em produção: não informada" como
  ausente. O "English version pending" do protótipo sai, substituído pelo seletor de idioma.
- **FR-004**: O site MUST ser construído em PT (padrão) e EN, com um seletor de idioma que leva à mesma
  página no outro idioma. A página sem tradução MUST mostrar a ausência nomeada; o build MUST contar as
  páginas sem tradução e MUST poder reprovar por elas.
- **FR-005**: A home MUST seguir 1.1–1.5, com as contagens de páginas por seção tiradas do `nav` no
  build.
- **FR-006**: MUST existir uma página por funcionalidade 064, 070, 071, 072, 073 e 074 em
  `docs/funcionalidades/`, na forma D14, escrita a partir da spec e da tela, sem copiar a spec, com o
  link para a spec no GitHub (D1). **Emendado em 2026-10-03 pela avaliação de segurança (E5)**: as
  páginas da 073 e da 074 só entram depois do merge dos PRs #1228 e #1266; até lá, a home as lista com
  "entra quando o PR for mergeado". Nenhuma página diz defeito aberto nem mecanismo de proteção.
- **FR-012**: A seção `docs/seguranca/` e os arquivos de evidência MUST sair do site publicado (E1, E3);
  os links para eles vão ao GitHub.
- **FR-007**: MUST existir um `404.html` para a raiz da `gh-pages`, com a variante de `/developers/`;
  o guarda do `docs.yml` MUST passar a conferir a presença dele, sem deixar de conferir os três de hoje.
- **FR-008**: O build MUST reprovar página fora do `nav` (`validation.nav.omitted_files: warn` com
  `--strict`), com `not_in_nav` só para as pastas de protótipo e o que a avaliação de segurança mandar
  tirar da navegação.
- **FR-009**: Um job de CI MUST rodar `mkdocs build --strict` e a varredura de links do site construído
  em todo PR que toque o site, sem publicar nada.
- **FR-010**: Sem JavaScript, a navegação MUST funcionar e a busca MUST dizer que precisa dele; sem o
  script do Mermaid, a figura MUST mostrar o código do diagrama e o aviso (5.3, 5.4).
- **FR-011**: O que a avaliação de segurança ([seguranca.md](seguranca.md)) mandar retirar do site
  público MUST sair antes da publicação.

### Key Entities

Nenhuma entidade de domínio. O site é estático e não tem estado, escrita nem dado por tenant.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero requisições a outro domínio numa página com diagrama, nos dois idiomas
  (`grep` de `http` em `src=` e `href=` de recursos no HTML construído).
- **SC-002**: `mkdocs build --strict` sai com 0 e a varredura acha 0 links internos quebrados, nos dois
  idiomas.
- **SC-003**: 100% das páginas PT têm uma versão EN servida: traduzida, ou com a ausência nomeada.
- **SC-004**: Os nove tokens do CSS do tema são idênticos aos da landing, nos dois temas.
- **SC-005**: A 360 px, nenhuma das quatro páginas de AC4 rola na horizontal.

## Decisões da pessoa mantenedora, 2026-10-03

| decisão | o quê |
|---|---|
| protótipo | aprovado com D1–D14, como está |
| specs no site | uma página por funcionalidade em `docs/funcionalidades/`; `specs/` não é publicado |
| tokens | copiados da landing, com a data da cópia |
| idioma | o site inteiro em PT e EN, com seletor; sai o "English version pending" |
| terceiros | nenhum; `font: false`; Mermaid fixado e servido pelo site, com hash conferido |
| endereço | `theband.dev/developers/` (Q2, opção 1) |
| 404 | `404.html` na raiz da `gh-pages`, com variante para `/developers/`; o guarda se ajusta (Q4, opção 1) |
| versão | só o commit do build, e "versão em produção: não informada" (Q5, opção 1) |
| validação | `omitted_files: warn` com `--strict`, `not_in_nav` para os protótipos (Q7, opção 1) |
| segurança | o agente `security` avalia antes de publicar (Q8, Q9) |

## Escopo desta entrega: a base

Esta spec cobre o site inteiro, e a entrega é em duas partes:

1. **A base**, neste sprint: tema, Mermaid servido pelo site, estrutura de idiomas com o seletor, as seis
   páginas de funcionalidade em PT, a 404, o commit do build, a validação estrita e o job de CI.
2. **As traduções**, depois, por lotes, segundo [traducao.md](traducao.md).

O que da régua do protótipo não entra na base fica nomeado no `tasks.md`, com tarefa e issue.

## Assumptions

- O site continua publicado da `main` pelo `docs.yml`; este item não muda o gatilho.
- A landing e `/docs/` não mudam; as divergências V1, V4 e V5 do protótipo são itens separados.
- A interface do produto continua em inglês; nas páginas PT os rótulos da tela são citados em inglês.
