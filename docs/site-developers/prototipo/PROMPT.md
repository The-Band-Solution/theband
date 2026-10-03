# O prompt do protótipo do site de desenvolvedores

## 1. O pedido da pessoa mantenedora, textual e em ordem

2026-10-03:

> refazer o site de developers no mesmo design do site https://theband.dev/ — coloque isso no backlog

Decisões da pessoa mantenedora no item #1267, 2026-10-03, transmitidas pelo ciclo:

> **D1**: as specs entram no site como uma página por funcionalidade em `docs/funcionalidades/`,
> escrita para quem lê, com link para a spec no GitHub. `specs/` inteiro não é publicado, e os
> `seguranca*.md` ficam fora.
>
> **D3**: os tokens são copiados da landing (`gh-pages:index.html`) para o tema do MkDocs, com a
> data da cópia. Trazer a landing para o repositório não faz parte deste item.

E: o protótipo vai só como artifact privado, para a pessoa mantenedora aprovar; nada é publicado
em theband.dev.

## 2. O brief de design seguido

Como o ciclo o passou ao agente Design, em 2026-10-03:

- o site de desenvolvedores é MkDocs (`mkdocs.yml`, tema Material), publicado em
  `https://theband.dev/developers/` por `.github/workflows/docs.yml`;
- extrair de `https://theband.dev/` a identidade visual: tipografia, paleta, grade, cabeçalho,
  rodapé, tom e componentes; achar de onde ele sai;
- `docs/design-system.md` é normativo: sólido é observado, hachurado é derivado, tracejado é
  ausente, toda marca leva texto; a ausência é nomeada; mobile-first. Apontar onde o site principal
  diverge;
- o conteúdo é a navegação atual do `mkdocs.yml`, somadas as specs 064 e 070 a 074, que ainda não
  estão no site;
- desenhar, com dado real do repositório: (1) a home com cabeçalho e rodapé de theband.dev e o
  caminho de volta ao site principal; (2) uma página longa (ADR ou Funcionalidades); (3) uma página
  de Modelos com diagrama Mermaid; (4) a navegação lateral e a busca, na mesa e no telefone a
  360 px; (5) página não encontrada e seção sem conteúdo, com a ausência nomeada;
- critérios de aceitação da #1267, AC1 a AC12: em especial AC3 (navegação nos dois sentidos),
  AC6 (ausência nomeada, inclusive sem JavaScript e sem o script do Mermaid) e AC11 (nenhuma
  requisição a terceiro);
- deixar abertas, com recomendação: manter o MkDocs com tema próprio ou trocar de gerador; domínio
  ou subcaminho; idioma.

## 3. A estrutura aprovada, seção por seção

**É contra esta lista que o QA confere a entrega**, item a item, com a captura da tela real ao lado.
Divergência é defeito. "Real" abaixo quer dizer: gerado do repositório no build, não copiado do
protótipo.

### Em toda página (moldura)

- **M1.** Tokens copiados de `gh-pages:index.html` nos dois temas, declarados uma vez, com a data
  da cópia no comentário do CSS (#1267 D3); o tema segue o sistema e aceita `data-theme`.
- **M2.** Títulos em serifa, corpo em humanista, mono com `tabular-nums` para identificador, caminho,
  data e contagem; nenhuma webfont carregada, `font: false` (D2, AC11).
- **M3.** Barra do topo, nesta ordem: "The Band" (link para `https://theband.dev/`) · "documentação
  técnica" · busca · "O produto" (`/docs/`) · "GitHub" · "Entrar na plataforma"
  (`https://app.theband.dev/sign-in`). Abaixo de 46 rem: marca, botão de busca e botão de menu,
  cada um com alvo de 44 px (D3).
- **M4.** Faixa do build: marca **observado** com "construída de main @ `<commit>` · `<data>`";
  marca **ausente** com "versão em produção: não informada nesta página" (até Q5 decidir outra
  coisa); "English version pending" (até Q3).
- **M5.** Rodapé: "Continuum + SEON sobre UFO" com `abbr`; links theband.dev · O produto · A
  plataforma (`app.theband.dev/sign-in`) · GitHub (AC3); a base científica; a linha "Construída com
  MkDocs a partir de docs/ na main. Identidade copiada de theband.dev em `<data>`."
- **M6.** Nenhuma marca só por cor: cada uma tem forma (sólido, hachurado, tracejado) e texto. Azul
  sólido = declarado; verdete sólido = observado; latão hachurado = derivado; tracejado = ausente.
  Nenhum tracejado para outra coisa que não ausência (D5).
- **M7.** Larguras: uma coluna por padrão; navegação lateral a partir de 60 rem; sumário "nesta
  página" à direita a partir de 76 rem; texto até 44 rem. Nenhuma rolagem horizontal da página a
  360 px (D6).
- **M8.** Tabela com mais de três colunas empilha abaixo de 40 rem, com o nome da coluna em cada
  célula; as demais rolam dentro do próprio quadro.
- **M9.** Toda página de conteúdo termina com "Editar esta página no GitHub" e o caminho do arquivo,
  e com anterior / próxima.

### Tela 1 · início (`/developers/`)

- **1.1** Assinatura "The Band · documentação técnica"; título "Como o The Band é construído, *e
  por quê.*"; a chamada com o link para "o produto"; a base científica.
- **1.2** A pauta de theband.dev como divisor, com notas sólidas e hachuradas, `aria-hidden`.
- **1.3** "I. Por onde começar": as oito linhas, nesta ordem, cada uma com o link à direita (abaixo
  dela no telefone): Arquitetura · Modelo de dados · Deployment · Rede de ontologias · A API pública
  · Necessidades de informação e medidas · ADRs · Lições aprendidas.
- **1.4** "II. As seções": as treze seções do `nav`, em quatro grupos (entender; usar e integrar;
  operar; decidir e registrar), cada uma com a contagem **real** de páginas na navegação. Modelos,
  Ontologias e Medidas levam a marca de derivado; Decisões, a de declarado (D8).
- **1.5** "III. Funcionalidades novas, e as que ainda não têm página": uma linha por spec (064, 070,
  071, 072, 073, 074), com número, título da funcionalidade (link para a página quando existe),
  marca de declarado com spec, status e data, onde está (development, PR aberto), e a marca de
  ausente: "ainda não em produção", "página a escrever" ou "entra quando o PR for mergeado"
  (#1267 D1).

### Tela 2 · página longa (ADR 0008)

- **2.1** Migalha "Decisões › ADRs › 0008"; assinatura "ADR 0008"; título completo da ADR.
- **2.2** Recibo com status (marca de declarado "Aceita · 2026-09-06"), depende de, emenda, reverte.
- **2.3** Navegação lateral com a seção atual aberta e a página atual destacada; as outras seções
  fechadas com a contagem de páginas.
- **2.4** Sumário "nesta página" com os títulos de nível 2 e 3, o atual marcado.
- **2.5** Corpo com citação em borda latão e serifa itálica, código em mono sobre verdete-fundo,
  tabela de medida com números à direita.
- **2.6** Rodapé da página: editar no GitHub; anterior "0007 gestor de cotas", próxima "RFCs".

### Tela 3 · Modelos com Mermaid (Estados · Conta)

- **3.1** Recibo com marca de derivado, a fonte (`arquivo:linha`), a data da conferência e "o que
  não alcança", lidos do comentário `DERIVADO de …` do topo do arquivo.
- **3.2** O diagrama renderizado com as cores dos tokens nos dois temas: estados com borda verdete,
  transições em tinta secundária, notas em latão. O fonte Mermaid não muda.
- **3.3** Legenda da figura com a marca "derivado de `<arquivo:linhas>`".
- **3.4** "ver como tabela" e "ver o código Mermaid", fechados, abaixo da figura.

### Tela 4 · navegação e busca

- **4.1** Mesa: campo de busca no topo com atalho `/`; aberto, painel com "N páginas falam de
  "`<termo>`"", cada resultado com a seção, o título e o trecho com o termo destacado.
- **4.2** Resultado de página fora da navegação leva a marca ausente "fora da navegação".
- **4.3** Sem resultado: marca ausente "nenhuma página", a frase "Nenhuma página da documentação
  técnica fala de "`<termo>`"." e o alcance: quantas páginas a busca cobre, e que o produto não está
  nela, com o link (D10).
- **4.4** Telefone a 360 px, página: sumário vira "nesta página" recolhido; tabela empilhada.
- **4.5** Telefone, gaveta: seções com contagem, a atual aberta, alvos de 44 px; no fim "Entrar na
  plataforma", O produto, GitHub e a marca do build.
- **4.6** Telefone, busca: ocupa a tela, com botão de fechar; os mesmos resultados.

### Tela 5 · ausências

- **5.1** Página não encontrada sob `/developers/`, com a moldura do site: o caminho pedido em mono,
  "Esta página não está publicada.", a explicação (endereço mudou, ou ainda não chegou à `main`), a
  busca, e os links para o início, o índice da seção mais próxima, a pasta `docs/` no GitHub e o
  produto (forma conforme Q4).
- **5.2** Seção sem conteúdo (Funcionalidades): a frase "1 dos 7 grupos de telas em produção tem
  página.", a tabela com os sete grupos, as rotas e a página, ou a marca ausente "sem página ainda";
  e a frase que separa "não escrita" de "não existe" (D11).

- **5.3** Sem JavaScript: o campo de busca diz "A busca precisa de JavaScript", com a marca ausente
  "busca indisponível" e o caminho alternativo; a navegação funciona (D13).
- **5.4** Sem o script do Mermaid: a figura mostra a marca ausente "diagrama não desenhado", a frase
  e o código do diagrama; nunca área em branco (D13).

### Tela 6 · uma funcionalidade nova (072, `funcionalidades/administradores/`)

- **6.1** Migalha "Funcionalidades › Administradores"; a página na navegação, sob Funcionalidades.
- **6.2** Recibo: a tela (`/accounts`, coluna `Management`); a spec com marca de declarado e link
  para `specs/072-…` no GitHub; "em produção" com marca ausente "ainda não" enquanto não estiver; a
  régua (só o que a tela faz).
- **6.3** "O que você passa a conseguir fazer", com os rótulos da tela em inglês, em `code`.
- **6.4** "O que a tela recusa, e diz por quê": tabela situação × frase da tela.
- **6.5** "O que ela não faz".
- **6.6** Nenhum `seguranca*.md`, `tasks.md` ou `research.md` publicado ou linkado como página do
  site (#1267 D1).

### Fora da tela, mas parte da entrega

- **F1.** Nenhuma dependência nova sem a decisão da Q1.
- **F2.** `mkdocs build --strict` continua verde, e o guarda do `docs.yml` continua conferindo
  `CNAME` e `index.html` da raiz.
- **F3.** Nenhuma requisição a terceiro numa página com diagrama: nem Google Fonts, nem CDN do
  Mermaid (AC11, forma conforme Q9).

## 4. Como cada papel usa este arquivo

| papel | uso |
|---|---|
| **Product Owner** | registra o item no backlog (`docs/backlog/`) com o endereço do artifact e este prompt; leva Q1 a Q8 à pessoa mantenedora e devolve as respostas ao Design; aceita a entrega só conferida contra a seção 3 |
| **Design** | marca cada Q como *Decided <data>* com a resposta, e republica **no mesmo endereço**; toda mudança de tela passa por aqui |
| **Elixir/Phoenix Developer**, ou quem implementar o tema | implementa exatamente a seção 3; o que não for possível volta ao protótipo, não é improvisado no CSS |
| **QA** | confere M1 a M9, 1.1 a 6.6 e F1 a F3 na tela publicada, nos dois temas, na mesa e a 360 px, com captura ao lado |
| **Security** | avalia Q5 (opção 2), Q8 e Q9 antes de qualquer decisão por elas |
