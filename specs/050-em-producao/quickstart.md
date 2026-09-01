# Quickstart — validar a 050 de ponta a ponta

## 1. A imagem builda e recusa sem env (local, antes de qualquer VPS)

```bash
docker build -t theband:dev . > /tmp/build_050.log 2>&1; echo "EXIT=$?" >> /tmp/build_050.log
docker run --rm theband:dev > /tmp/run_sem_env.log 2>&1; echo "EXIT=$?" >> /tmp/run_sem_env.log
```

Esperado: build EXIT=0; run EXIT≠0 com "FALTA a variável de ambiente DATABASE_URL"
— a recusa NOMEIA (entrypoint adotado).

## 2. O contêiner sobe inteiro, com as variáveis vindas do `.env`

```bash
cp .env.example .env   # e preencher; a chave mestra JÁ existente nunca se regenera
docker compose --profile producao up --build
```

Esperado: "aplicando migrações pendentes… migrações aplicadas." ANTES do endpoint;
`curl -s localhost:4001/sign-in` → 200.

**A violação primeiro** — variável da lista fechada ausente:

```bash
THE_BAND_MASTER_KEY= docker compose --profile producao config --quiet; echo "EXIT=$?"
```

Esperado: EXIT=1 NOMEANDO a variável e dizendo como gerá-la.

O `.env` é ignorado pelo git e barrado no `.dockerignore` (`.env*`): chega em
runtime, nunca na imagem. O compose passa só as **cinco** da lista fechada do
contrato — `env_file:` despejaria o arquivo inteiro, e o `.env` de quem
desenvolve carrega segredo que a imagem não usa.

> **Por que o Postgres do ensaio tem `POSTGRES_DB`.** A primeira execução deste
> passo, em 2026-08-31, subia `postgres:16-alpine` cru e morria em
> `invalid_catalog_name`: o entrypoint da imagem **migra, não cria** o banco, e
> `band_prod` não existia. Em produção quem cria é o Dokploy (runbook §4). O
> serviço `postgres_prod` do compose nasce com o banco criado, e o passo passa a
> exercitar o que o VPS vai exercitar.

## 3. O workflow no seco (sem VPS)

Merge de teste em `main`? NÃO — main é produção (1.7.0). O `cd.yml` valida por:
`act`/dry-run OU o job condicional do CI que builda a imagem em PR. O passo do
webhook só se prova no primeiro release (contrato: ensaio documentado).

## 4. Runbook executado (com o VPS — marcos com pessoas)

§1 Dokploy instalado → §2 segredos → app criado apontando `ghcr.io/...` → banco →
backup agendado. **§Restauração ENSAIADA** (FR-008): backup → restore num banco
vazio → painéis conferidos — ANTES de dado real.

## 5. O primeiro release (Product Owner)

PR `development → main` com bump no mix.exs → merge → CD: imagem `vX.Y.Z` no ghcr,
tag git, webhook, produção no ar. Medir: SC-001 (entrar e ver painel <2min),
SC-002 (<15min/<2min), SC-005 (varredura das 27 rotas contra produção), SC-004
(varredura de segredos em imagem e logs).
