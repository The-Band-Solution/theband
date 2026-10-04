# Research: o site de desenvolvedores

Medido em 2026-10-03, num venv com `mkdocs==1.6.1`, `mkdocs-material==9.7.7` e o candidato.

## R1. O plugin de idiomas

| candidato | licença | última versão | manutenção | dependências | serve? |
|---|---|---|---|---|---|
| **`mkdocs-static-i18n` 1.3.1** (ultrabug) | MIT | 2026-02-20 | 1.2.3 (2024-05), 1.3.0 (2025-01), 1.3.1 (2026-02); repositório ativo no GitHub | só `mkdocs>=1.5.2` | **sim**: `docs_structure: suffix`, idioma padrão, `fallback_to_default`, `nav_translations`, reconfigura o seletor e a busca do Material |
| `mkdocs-i18n` 0.4.6 | **AGPL-3.0** | 2023-04 | parado há três anos | `mkdocs-material` | não: licença e abandono |
| `mkdocs-multilang` 0.1.3 | MIT | 2019-08 | abandonado | `mkdocs>=1.0.4` | não |
| **sem plugin**: dois `mkdocs.yml` + `extra.alternate` do Material | — | — | — | nenhuma | possível, com custo: dois `nav` a manter em par, o seletor leva à raiz do outro idioma e não à mesma página, e a página sem tradução vira 404 em vez de ausência nomeada |

**O spike** (`scratchpad/spike-i18n`, fora do repositório): `mkdocs build --strict` com o plugin sai **0**
no Material 9.7.7. O extra `material` do plugin declara `mkdocs-material<9.7.2`, mas o extra não é
instalado e o build não reclama; o risco é de compatibilidade futura, e o CI o pega no build estrito.

O que o spike mostrou e o desenho usa:

| fato | uso |
|---|---|
| a página EN sem tradução é a PT servida em `/en/…`, com `page.file.locale == "pt"` no build `en` | o hook reconhece a página sem tradução e injeta a marca "translation pending" |
| o plugin escreve só em `site/` e `site/en/` | a publicação continua sendo `cp -r site developers` |
| o plugin acrescenta `en` ao `lang` da busca | a busca EN tem o próprio índice |

## R2. O Mermaid sem CDN

O bundle do Material 9.7.7 carrega `https://unpkg.com/mermaid@11/dist/mermaid.min.js` **só se**
`typeof mermaid == "undefined"`. Com o Mermaid carregado no `<head>` pelo próprio site, o CDN nunca é
pedido.

| escolha | por quê |
|---|---|
| **mermaid 11.17.2** (2026-08-25), e não 12.1.0 (2026-10-02) | o Material 9.7.7 foi feito para a 11; a 12 saiu ontem |
| **vendorizado** em `docs/assets/javascripts/vendor/` | o build fica reprodutível e offline; a troca de versão vira diff revisável |
| integridade do tarball | conferida contra o `dist.integrity` do registro npm: `sha512-V6K3C8EB…BBg==`, igual |
| sha256 do arquivo | `581ed7d74bd9048d0e3a91363927d72ef22942d7722546b27f7cc29e35390eb8`, conferido pelo hook em todo build |
| URLs embutidas | só w3.org, documentação e licenças; nenhuma busca em tempo de leitura |

## R3. A 404 na raiz

O MkDocs gera `site/404.html` com URLs absolutas a partir de `site_url`, porque a 404 é servida em
qualquer caminho. Copiado para a raiz da `gh-pages`, ele funciona fora de `/developers/`. Um arquivo só
faz as duas variantes: o texto neutro é o que aparece sem JavaScript; com JavaScript, o caminho pedido
decide a variante (`/developers/` ou o resto de theband.dev).

## R4. A varredura de links

Nenhuma dependência: um script Python de biblioteca padrão (`html.parser`) lê o `site/` construído,
resolve cada `href` e `src` interno contra o disco e reprova o que não existe. `linkchecker` 10.6.0
faria o mesmo com três dependências a mais; não se justifica para links de arquivo local.

## R5. O build estrito já reprova em `development`

Quatro links `../../specs/` em `docs/sprints/036-papeis-do-banco/` e `037-papel-de-administrador/`
apontam para `docs/specs/`. Ninguém viu porque nenhum PR roda o build. O conserto é um `../` a mais,
e entra como a primeira tarefa, em commit próprio.
