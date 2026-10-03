# O protótipo do site de desenvolvedores no design de theband.dev

Item de backlog: **#1267**. [`site-developers.html`](site-developers.html): abrir no navegador. Seis telas, separadas pelas
faixas `screen N · nome`, e a seção final *Decisões e perguntas abertas*. Tudo visível ao carregar,
sem nenhum controle.

Desenhado em **2026-10-03** pelo agente Design, a partir do pedido da pessoa mantenedora no mesmo
dia. Publicado em **<https://claude.ai/artifact/9p9PZQ3ovAGXkpRH6sKDbW>** (versão 3, no mesmo
endereço da versão 1, com as decisões D1 e D3 da #1267). O artifact é privado, para a aprovação;
nada foi publicado em theband.dev. **A cópia aqui
é a que vale**: o endereço pode mudar, e o item do backlog não pode depender dele. Republicação é
sempre no mesmo endereço.

**Estado: versão 3, para aprovação.** As decisões D1 e D3 da #1267 são da pessoa mantenedora
(2026-10-03) e resolvem Q1 e Q6. D1 a D11 abaixo são do desenho, contestáveis. Q2, Q3 (= D2 da
#1267), Q4, Q5, Q7, Q8 e Q9 estão abertas; o Product Owner as leva.

A estrutura seção a seção, que é **a régua do QA**, está na seção 3 do [`PROMPT.md`](PROMPT.md).

## O dado que o protótipo mostra

**Todo real, e nada de exemplo.** O texto das páginas vem do repositório em `origin/development`,
2026-10-03:

| tela | de onde vem o texto |
|---|---|
| 1 · início | `docs/README.md` (por onde começar, base científica); contagens de páginas por seção, do `nav` do `mkdocs.yml`; as specs, do cabeçalho de `specs/064`, `070`, `071`, `072` em development, `073` em `origin/feature/1182-rede-de-revisao` e `074` em `origin/feature/802-tracing-signoz` |
| 2 · ADR 0008 | `docs/adr/0008-vinculo-observado.md`, cortado onde a faixa "trecho" diz |
| 3 · modelos | `docs/modelos/estados/conta.md`, com o diagrama Mermaid como está no arquivo, mais curto nas notas |
| 4 · busca | os 8 arquivos de `docs/` que contêm "vínculo observado" (`grep -ric`); "sinfonia" em nenhum |
| 5 · ausências | o endereço `modelos/estados/organizacao-suspensa/`, que responde 404 hoje; os 7 grupos de telas de `theband.dev/docs/`, seção II; o diagrama da tela 3, para o estado sem script |
| 6 · funcionalidade 072 | `specs/072-papel-de-administrador/spec.md` (US1 a US3) e os rótulos da tela em `lib/` de development, conferidos com `grep` |

O commit do build (`ce77a10`, 2026-09-30) é o último da `main` que tocou `docs/` ou `mkdocs.yml`.

Medido em 2026-10-03, e citado no protótipo:

| fato | como |
|---|---|
| `app.theband.dev/version` responde `0.11.0`, sem `Access-Control-Allow-Origin` | `curl -D - -H 'Origin: https://theband.dev'` |
| `mix.exs` em development diz `0.12.0` | `grep version: mix.exs` |
| `/developers/modelos/estados/organizacao-suspensa/` devolve a 404 genérica do GitHub Pages | `curl` e `<title>` |
| a `gh-pages` não tem `404.html` na raiz | `git ls-tree origin/gh-pages` |
| 227 páginas em `docs/`, 176 no `nav`, 51 fora | comparação do `mkdocs.yml` com os `.md` de `docs/` |
| `/docs/` marca v0.10.0 como "no ar" | o HTML de `theband.dev/docs/` |
| o site de developers carrega Roboto de `fonts.googleapis.com` e o Mermaid de `unpkg.com/mermaid@11` | o HTML de uma página de modelo e o `bundle.*.min.js` do Material |

## O que adota de theband.dev

Lido em 2026-10-03 de `https://theband.dev/` (landing, na raiz da `gh-pages`) e de
`https://theband.dev/docs/` (a página do produto, mantida à mão na `gh-pages`). Nenhum dos dois tem
fonte em `development`: vivem só na `gh-pages`.

| elemento | em theband.dev | no site de developers |
|---|---|---|
| paleta | `--papel #f1f4f2`, `--tinta #17211c`, `--tinta-2 #4c5c55`, `--verdete #2c6b60`, `--verdete-forte`, `--verdete-fundo`, `--latao #96731f`, `--pauta`, `--cartao`, e os escuros | os mesmos valores, mapeados nas variáveis `--md-*` do Material |
| tipografia | títulos em serifa (Iowan Old Style, Palatino), corpo em humanista (Seravek, Gill Sans), mono com `tabular-nums`; nenhuma webfont | igual |
| barra do topo | landing: botões flutuantes; `/docs/`: barra com borda, "The Band · o produto", Entrar | a barra de `/docs/`, com a busca no meio |
| rodapé | Continuum + SEON sobre UFO, base científica, links | igual, mais como a página é construída |
| pauta e numeração | pauta de cinco linhas com notas; seções "I., II., III." | na home |
| recibo | `dl` mono, rótulos em versalete | metadados de toda página |
| "ver como tabela" | todo gráfico tem a tabela num `details` | todo diagrama Mermaid |
| citação | borda latão, serifa itálica | citações de código com `arquivo:linha` |

O único token que não vem de theband.dev é `info` (`#23566f` / `#7fb4d6`, de `assets/css/app.css`),
para a marca de declarado.

## Onde theband.dev diverge do design system

`docs/design-system.md` é normativo. Onde o site principal diverge dele:

| # | divergência | o que este site faz |
|---|---|---|
| V1 | o chip "declarado por alguém" da landing é **tracejado**, e o design system reserva o tracejado para a **ausência** | declarado é sólido azul; tracejado só para ausente (D5). A correção da landing é um item separado para o Product Owner |
| V2 | verdete `#2c6b60`/`#5fa294` no site; `#1f6f68`/`#5cbcb2` no design system | segue theband.dev, porque o pedido é o design dele |
| V3 | design system: títulos em grotesca, corpo em serifa; theband.dev faz o inverso | segue theband.dev (D2) |
| V4 | o atributo de tema é `data-theme` na landing e `data-tema="claro\|escuro"` em `/docs/` | a ponte usa `data-theme` |
| V5 | `/docs/` marca v0.10.0 como "no ar", e a produção serve 0.11.0 | fora do escopo; registrado para o Product Owner |

## Decisões da pessoa mantenedora (#1267), 2026-10-03

- **#1267 D1.** As specs entram no site como **uma página por funcionalidade** em
  `docs/funcionalidades/`, escrita para quem usa, com link para a spec no GitHub. `specs/` não é
  publicado, e os `seguranca*.md` ficam fora. É a tela 6 e a seção III da home. Resolve a Q6.
- **#1267 D3.** Os tokens são **copiados da landing** (`gh-pages:index.html`) para o tema do
  MkDocs, **com a data da cópia**; fontes do sistema. Trazer a landing para o repositório não faz
  parte deste item. Resolve a Q1: MkDocs + Material como hoje.

## Decisões do desenho

Todas de 2026-10-03, e contestáveis.

- **D1. A paleta de theband.dev, nos dois temas.** Os nove tokens da landing mais `info`. Um
  `extra_css` aponta as variáveis do Material (`--md-default-bg-color`, `--md-typeset-color`,
  `--md-primary-fg-color`, `--md-accent-fg-color`, `--md-mermaid-*`) para eles.
- **D2. A tipografia de theband.dev.** Serifa nos títulos, humanista no corpo, mono para
  identificadores, caminhos, datas e contagens. Nenhuma webfont. A inversão em relação ao design
  system (V3) fica registrada: os sites públicos são uma família, o produto é outra.
- **D3. A barra do topo de `/docs/`, com busca.** "The Band" leva a theband.dev; "documentação
  técnica" diz onde se está; O produto, GitHub e Entrar à direita. No telefone, marca, busca e
  menu com alvos de 44 px; Entrar, O produto e GitHub no fim da gaveta.
- **D4. A proveniência da página, com a gramática da evidência.** O recibo no topo de toda página:
  ADR e spec **declaradas** (sólido azul, status e data); modelos, ontologias, mapeamentos e medidas
  **derivados** (hachurado latão, fonte e data da conferência); commit do build **observado**
  (sólido verdete); o que falta **ausente** (tracejado, com o motivo). Sempre com texto.
- **D5. Tracejado só para ausência.** O site não copia o chip tracejado de "declarado" da landing.
- **D6. Mobile-first, três larguras.** Uma coluna por padrão; navegação lateral a partir de 60 rem;
  sumário à direita a partir de 76 rem. Texto até 44 rem. Tabela com mais de três colunas empilha
  com `data-label` abaixo de 40 rem; as demais rolam dentro do próprio quadro.
- **D7. Mermaid herda o tema, e toda figura tem tabela.** Nenhum fonte de diagrama muda. Legenda
  com a marca de derivado, "ver como tabela" e "ver o código Mermaid". O comentário `DERIVADO de …`
  do topo do arquivo vira o recibo.
- **D8. A home agrupa as treze seções por intenção** (entender; usar e integrar; operar; decidir e
  registrar), sem mudar o `nav`. Cada seção diz quantas páginas tem na navegação.
- **D9. O build diz de onde veio.** Commit e data da `main`, no topo e no fim da gaveta. Não é a
  versão em produção (Q5).
- **D10. A busca diz o que cobre.** Sem resultado, nomeia a ausência e o alcance. Resultado fora da
  navegação leva a marca.
- **D11. Seção sem conteúdo lista o que falta**, com "sem página ainda" e a frase que separa "não
  escrita" de "não existe".
- **D12. Navegação nos dois sentidos (AC3).** O topo leva a `theband.dev/`, a `/docs/` e a
  `app.theband.dev/sign-in`; o rodapé repete os três e o GitHub.
- **D13. Os estados sem script (AC6).** Sem JavaScript, o campo de busca diz "A busca precisa de
  JavaScript" e a navegação funciona; sem o script do Mermaid, a figura mostra o código do diagrama
  com o aviso "diagrama não desenhado", e a tabela continua em "ver como tabela".
- **D14. A página de funcionalidade** tem sempre: recibo (a tela, a spec com link, se está em
  produção, a régua), "O que você passa a conseguir fazer", "O que a tela recusa, e diz por quê",
  "O que ela não faz". Rótulos da tela em inglês, texto em português.

## Perguntas abertas, com recomendação

### Q1. Manter o MkDocs com tema próprio, ou trocar de gerador? *Decided 2026-10-03, pela #1267 D3*

MkDocs 1.6.1 + Material 9.7.7, como hoje, com `extra_css` (os tokens, com a data da cópia),
`theme.font: false` (sai o Roboto) e `theme.custom_dir` com três parciais: topo, rodapé e 404.
Nenhuma dependência nova, nenhuma ADR. Era a recomendação.

### Q2. Subcaminho `/developers/` ou subdomínio?

1. **Manter `theband.dev/developers/`.** Mesma origem; os links publicados continuam valendo; nada
   muda no DNS nem no certificado.
2. **`developers.theband.dev`.** Outro registro de DNS, outro destino, redirecionamento dos links.
3. **Unificar `/docs/` e `/developers/`** num site só com duas portas.

**Recomendação: 1.** O pedido é de design, não de endereço.

### Q3. Idioma do cabeçalho e do rodapé (é a D2 da #1267)

A landing abre em português com botão PT/EN e as duas versões escritas; `/docs/` é só português
com "English version pending"; a documentação técnica é português. O AGENTS.md (§11.1) manda
documentação em português e interface do produto em inglês.

1. **Português no conteúdo e na moldura**, com "English version pending" como em `/docs/`. Rótulos
   da tela do produto citados em inglês, como já faz `funcionalidades/`.
2. **Moldura bilíngue** e conteúdo em português.
3. **Traduzir** as 227 páginas.

**Recomendação: 1.** Um botão de idioma que troca só a moldura promete o que não entrega.

### Q4. Página não encontrada

O GitHub Pages só serve o `404.html` da raiz, e a raiz da `gh-pages` não tem um.

1. **Um `404.html` na raiz** com a moldura de theband.dev e uma variante para `/developers/` (busca
   e links da tela 5). Exige mudar o guarda do `docs.yml`, que protege a raiz.
2. **Uma 404 neutra** na raiz, com links para os três sites.
3. **Manter a genérica.**

**Recomendação: 1**, com a 2 como o que aparece sem JavaScript. O guarda continua conferindo
`CNAME` e `index.html`.

### Q5. A versão em produção aparece no site?

1. **Agora: só o commit do build**, e "versão em produção: não informada nesta página".
2. **Ler `/version` no navegador.** Exige CORS na rota: mudança de acesso, avaliação do agente
   security antes.
3. **Gravar no build a versão do `mix.exs`.** Recusada: é a versão da árvore, não a que está no ar.

**Recomendação: 1 agora, e 2 como item próprio** se a pessoa mantenedora quiser a versão aqui.

### Q6. Como as specs chegam ao site *Decided 2026-10-03, pela #1267 D1*

Uma página por funcionalidade em `docs/funcionalidades/`, escrita à mão para quem usa. A
recomendação do protótipo (gerar uma lista do cabeçalho de `specs/*/spec.md`) fica recusada. A
071 é infraestrutura sem tela: se tiver página, fica em Operação.

### Q7. As 51 páginas fora da navegação

Entre elas as ADRs 0009 e 0010, as releases v0.10.1 a v0.12.0, três modelos da 070 e o runbook de
saúde da fila. São publicadas e achadas pela busca, e não aparecem no menu. Esta pasta será mais
uma: o build publica `docs/site-developers/prototipo/`.

1. **`validation: nav: omitted_files: warn`** no `mkdocs.yml`, que o `--strict` transforma em falha,
   com `not_in_nav` para o que é de propósito, como as pastas de protótipo.
2. **Colocar as 51 na navegação à mão**, sem guarda.
3. **Aceitar como está.**

**Recomendação: 1**, num item próprio, antes do tema novo.

### Q8. A seção Segurança num site público

O site publica `docs/seguranca/`, com inventários de achados por data. A home nova dá à seção um
lugar visível.

1. **Avaliação do agente security** sobre o que da seção é público, antes de publicar o tema novo.
2. **Manter como está.**

**Recomendação: 1.** Na dúvida, trata-se como segurança (CLAUDE.md), e a avaliação é de quem não
desenhou o site.

### Q9. De onde vem o script do Mermaid (AC11)

Hoje o Material carrega `https://unpkg.com/mermaid@11/dist/mermaid.min.js`. A landing não faz
requisição a terceiro.

1. **Servir o Mermaid do próprio site**: o arquivo da versão 11, fixado, em `docs/assets/`, por
   `extra_javascript`, com o hash conferido no build. É código de terceiro no repositório: passa
   pelo agente security.
2. **Desenhar os diagramas no build**, em SVG. Exige Node e `mermaid-cli` no CI: tecnologia nova.
3. **Manter o CDN.** Recusa o AC11.

**Recomendação: 1**, com o estado sem script da D13.

## Medidas novas para a base de conhecimento

Nenhuma. As contagens de páginas são do próprio site, lidas do `mkdocs.yml` no build.

## Premissas que valem até serem contestadas

- O site continua sendo construído da `main` e publicado em `gh-pages/developers/` pelo `docs.yml`.
- `/docs/` e a landing não mudam por causa deste item; as divergências V1, V4 e V5 são itens
  separados.
- O conteúdo de `docs/` não muda; só a moldura, o tema e as três parciais.
