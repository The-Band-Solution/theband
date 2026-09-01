# Contrato — O pipeline de release (CD)

Escrito antes do código (constituição VI). Erro de contrato se corrige no mesmo
commit, com a razão. Governança: constituição 1.7.0 (Gitflow — todo merge em
`main` é deploy) e FR-015/FR-016 da spec.

## A fonte da versão

`project[:version]` no `mix.exs` — única fonte. O PR de release
`development → main` carrega o commit de bump (`chore: release vX.Y.Z`), decidido
pelo Product Owner sobre entregáveis ACEITOS (FR-016). O CD LÊ, nunca inventa.

## O gatilho e os passos do `cd.yml`

```
on: push: branches: [main]
```

| # | Passo | Regra |
|---|---|---|
| 1 | Extrair a versão | do `mix.exs`; se a tag `vX.Y.Z` JÁ existe com outro commit, o workflow FALHA nomeando o conflito — versão repetida não republica |
| 2 | Build da imagem | Dockerfile multi-stage (contrato abaixo); sem suíte de testes aqui — o PR de release já passou pelo CI; falha de build é falha do deploy, dita |
| 3 | Publicar | `ghcr.io/the-band-solution/theband:vX.Y.Z` e `:latest`; login com `GITHUB_TOKEN` (`permissions: packages: write`) |
| 4 | Tag git | cria `vX.Y.Z` anotada no commit do merge, apontando o registro de release |
| 5 | Delivery | `POST` no webhook do Dokploy (`secrets.DOKPLOY_WEBHOOK_URL`); resposta não-2xx FALHA o workflow — deploy que não confirmou não é deploy |

O workflow inteiro é idempotente por versão: rodar de novo sobre a mesma tag/imagem
já publicada não republica nem re-entrega — reporta e sai verde.

## O Dockerfile

- Dois estágios, MESMA base de SO (glibc) nos dois — bcrypt_elixir compila NIF no
  builder; runtime de outra família quebraria em runtime, não no build.
- Builder: deps `--only prod`, `assets.deploy`, `mix release`.
- Runtime: só a release + `rel/entrypoint.sh` (adotado como está: env conferidas
  pelo nome, `Release.migrate()` ANTES de servir, `set -e`); usuário não-root;
  `EXPOSE 4000`.
- Nenhum segredo em ARG/ENV do Dockerfile — tudo chega em runtime pelo painel.

## O Dokploy (runbook, não código)

- Aplicação como **Docker image** (`ghcr.io/...`), pull disparado pelo webhook;
  auto-deploy-on-push DESLIGADO (FR-015).
- Postgres gerenciado pelo Dokploy; `DATABASE_URL` e as demais env obrigatórias no
  painel. Backup agendado (FR-007) + snapshot Contabo (FR-014); ensaio de
  restauração com evidência (FR-008) antes do primeiro release com dado real.
- Registry privado → credencial `read:packages` cadastrada no painel.

## Segredos — a lista fechada

| Onde | O quê |
|---|---|
| GitHub Secrets | `DOKPLOY_WEBHOOK_URL` (e nada mais novo: `GITHUB_TOKEN` é nativo) |
| Painel do Dokploy | `DATABASE_URL`, `SECRET_KEY_BASE`, `THE_BAND_MASTER_KEY`, `PHX_HOST` (+ credencial do registry se privado) |
| Repositório / chat | **nada, nunca** |

## Testes que provam o contrato

| Invariante | Prova |
|---|---|
| A imagem builda e o entrypoint recusa sem env | `docker build` no CI de PR que toca Dockerfile/rel/; `docker run` sem env sai não-zero com o NOME da variável |
| A versão lida = mix.exs | passo do workflow com asserção explícita |
| Idempotência por versão | job re-executado sobre tag existente sai verde sem republicar (teste manual documentado no runbook do primeiro release) |
| Webhook não-2xx falha | o passo usa `--fail`; ensaio no primeiro release |
| SC-005 (rotas recusam sem sessão) | a varredura da 045 reexecutada contra o endereço de produção no primeiro release |
