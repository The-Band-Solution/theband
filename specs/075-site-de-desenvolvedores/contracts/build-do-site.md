# Contrato: o build do site

O site não tem API em tempo de leitura. O contrato é o do **build**: os hooks de
`scripts/mkdocs_hooks.py`, as chaves de configuração que eles leem, o que o template recebe, e o que o
build recusa.

## Hooks (MkDocs 1.6, chamados pelo próprio MkDocs)

| hook | recebe | faz | em erro |
|---|---|---|---|
| `on_config(config)` | a configuração | confere o sha256 do Mermaid contra `extra.mermaid.sha256`; grava `extra.build = {"commit": str \| None, "data": str \| None}` a partir de `git log -1` | **reprova** (`PluginError`) se o arquivo faltar ou o hash diferir, com o esperado e o obtido; commit não obtível vira `None`, nunca valor inventado |
| `on_nav(nav, config, files)` | a navegação já traduzida | conta as páginas de cada seção de topo, recursivamente | — |
| `on_page_markdown(markdown, page, config, files)` | o markdown | (a) reescreve links que saem de `docs/` para o GitHub (já existia); (b) a página `README.md` / `README.en.md` usa `home.html`; (c) no build `en`, página servida do PT ganha `page.meta["traducao_pendente"] = True` | — |
| `on_page_context(context, page, config, nav)` | o contexto do template | entrega `secoes` (título → contagem), `funcionalidades` (lidas de `overrides/dados/funcionalidades.yml`) e `build` | — |
| `on_post_build(config)` | — | escreve no log quantas páginas PT não têm EN; com `extra.traducao.exigir: true`, **reprova** se houver alguma | reprova com a lista |

## Chaves de configuração

| chave | tipo | para quê |
|---|---|---|
| `extra.mermaid.arquivo` | caminho relativo a `docs/` | o arquivo vendorizado |
| `extra.mermaid.sha256` | hex | o hash esperado |
| `extra.traducao.exigir` | bool, `false` até o último lote | reprovar página PT sem EN |
| `extra.links` | mapa | os quatro destinos de saída: `landing`, `produto`, `plataforma`, `github` |

## O que o contrato NÃO expõe, e por quê

- **A versão em produção.** Exigiria ler `/version` de `app.theband.dev` no navegador, o que é CORS,
  mudança de acesso (Q5, opção 2). A página diz "não informada".
- **A versão do `mix.exs`.** É a da árvore, não a do ar; versão errada na tela é pior que ausente.
- **Nada de `specs/`** como página do site (D1). O link para a spec vai ao GitHub.
- **Nenhuma URL de terceiro** em recurso carregado pela página. O `href` de navegação para o GitHub é
  link, não recurso.
