# `vendor/` — ativo de terceiro servido do próprio domínio

O que está aqui **não é código desta casa**. É biblioteca de terceiro, copiada para o
repositório e servida de `https://<este-domínio>/vendor/...` em vez de um CDN.

## Por que copiado, e não carregado do CDN

A política de conteúdo desta aplicação é `script-src 'self'` (`lib/the_band_web/router.ex`).
Ela existe por um achado do Sobelow já tratado — issue #288 —, e o que aquele achado fechou
foi exatamente esta porta: script de terceiro com acesso ao DOM de uma aplicação multitenant
lê a sessão de quem está logado e enxerga o dado de todas as organizações que a pessoa
alcança. Afrouxar a política para aceitar um CDN reabriria o achado para poupar 1,8 MB.

O preço da escolha está escrito: o repositório carrega os bytes, e atualizar a biblioteca é
um passo manual — não há `npm update` que o faça.

## `swagger-ui/` — 5.17.14

A interface de `/api/docs`, que lê a descrição OpenAPI de `/api/openapi`.

| Arquivo | SHA-256 |
|---|---|
| `swagger-ui-bundle.js` | `c2e4a9ef08144839ff47c14202063ecfe4e59e70a4e7154a26bd50d880c88ba1` |
| `swagger-ui-standalone-preset.js` | `33b7a6f5afcac4902fdf93281be2d2e12db15f241d384606e6e6d17745b7f86f` |
| `swagger-ui.css` | `40170f0ee859d17f92131ba707329a88a070e4f66874d11365e9a77d232f6117` |

Origem: <https://github.com/swagger-api/swagger-ui>, release `v5.17.14`, diretório `dist/`.
Licença Apache-2.0.

### Como atualizar, e como conferir que deu certo

```bash
V=5.17.14   # troque pela versão nova
for f in swagger-ui.css swagger-ui-bundle.js swagger-ui-standalone-preset.js; do
  curl -sfL "https://cdn.jsdelivr.net/npm/swagger-ui-dist@$V/$f" \
    -o "priv/static/vendor/swagger-ui/$f"
done
printf '%s\n' "$V" > priv/static/vendor/swagger-ui/VERSION
shasum -a 256 priv/static/vendor/swagger-ui/*   # atualize a tabela acima
```

O CDN aparece **aqui, no passo manual de atualização** — nunca em tempo de execução. É a
diferença entre buscar o arquivo uma vez, conferi-lo e versioná-lo, e deixar um terceiro
entregar script ao navegador de quem usa a cada visita.

**Conferir no navegador, não no `curl`.** Um `HTTP 200` em `/api/docs` não diz que a página
funciona: quando a política bloqueia um script, o servidor responde 200 e a página fica em
branco — foi o que aconteceu na primeira tentativa. Abra `/api/docs`, veja as rotas
listadas, e confira que o console não acusa bloqueio de política.
