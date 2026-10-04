# Contrato: o build do site

O site não tem API em tempo de leitura. O contrato é o do **build**: os hooks de
`scripts/mkdocs_hooks.py`, as chaves de configuração que eles leem, o que o template recebe, e o que o
build recusa.

## Hooks (MkDocs 1.6, chamados pelo próprio MkDocs)

| hook | recebe | faz | em erro |
|---|---|---|---|
| `on_config(config)` | a configuração | confere o sha256 do Mermaid contra `extra.mermaid.sha256` e calcula o `integrity` (sha384) do `<script>`; lê commit curto e data de `git log -1` | **reprova** (`PluginError`) se o arquivo faltar ou o hash diferir, com o esperado e o obtido; commit não obtível vira `None`, nunca valor inventado |
| `on_nav(nav, config, files)` | a navegação já traduzida | conta as páginas de cada seção de topo, recursivamente, com a chave = a primeira página da seção (nome PT); guarda título e URL de cada página | — |
| `on_env(env, config, files)` | o ambiente Jinja | entrega aos templates, inclusive à 404: `idioma`, `textos`, `home`, `funcionalidades` (de `mkdocs-dados/`), `build`, `secoes` e `paginas` | YAML inválido em `mkdocs-dados/` reprova o build |
| `on_page_markdown(markdown, page, config, files)` | o markdown | (a) reescreve para o GitHub os links que saem de `docs/` **ou** apontam para o que `exclude_docs` tira do site; (b) `README.md` / `README.en.md` usa `home.html`; (c) no build `en`, a página servida do PT ganha `page.meta["traducao_pendente"] = True` | — |
| `on_post_build(config)` | — | (a) troca `__TB_CSP_HASHES__` da `404.html` pelo sha256 de cada `<script>` inline; (b) no build `en`, escreve no log quantas páginas não têm EN e a lista em `en/traducao-pendente.txt`; com `extra.traducao.exigir: true`, **reprova** se houver alguma | reprova se a 404 perder o marcador da CSP, ou com a lista de pendentes |

**Corrigido em 2026-10-03, na implementação**: o contrato dizia `on_page_context`; ele não roda para a
404 (o MkDocs a renderiza como template do tema), e por isso os dados vão por `on_env`. Os dados saíram
de `overrides/dados/` para `mkdocs-dados/`, porque o Material copia para o site tudo o que não é template
em `custom_dir`.

## Chaves de configuração

| chave | tipo | para quê |
|---|---|---|
| `extra.mermaid.arquivo` | caminho relativo a `docs/` | o arquivo vendorizado |
| `extra.mermaid.sha256` | hex | o hash esperado |
| `extra.traducao.exigir` | bool, `false` até o último lote | reprovar página PT sem EN |
| `extra.links` | mapa | os destinos de saída: `landing`, `produto`, `plataforma`, `github`, `github_docs` |
| `extra.identidade.copiada_em` | data | quando os tokens foram copiados da landing |

## O que o contrato NÃO expõe, e por quê

- **A versão em produção.** Exigiria ler `/version` de `app.theband.dev` no navegador, o que é CORS,
  mudança de acesso (Q5, opção 2). A página diz "não informada".
- **A versão do `mix.exs`.** É a da árvore, não a do ar; versão errada na tela é pior que ausente.
- **Nada de `specs/`** como página do site (D1). O link para a spec vai ao GitHub.
- **Nenhuma URL de terceiro** em recurso carregado pela página. O `href` de navegação para o GitHub é
  link, não recurso.
