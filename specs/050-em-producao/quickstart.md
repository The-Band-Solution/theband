# Quickstart — validar a 050 de ponta a ponta

## 1. A imagem builda e recusa sem env (local, antes de qualquer VPS)

```bash
docker build -t theband:dev . > /tmp/build_050.log 2>&1; echo "EXIT=$?" >> /tmp/build_050.log
docker run --rm theband:dev > /tmp/run_sem_env.log 2>&1; echo "EXIT=$?" >> /tmp/run_sem_env.log
```

Esperado: build EXIT=0; run EXIT≠0 com "FALTA a variável de ambiente DATABASE_URL"
— a recusa NOMEIA (entrypoint adotado).

## 2. O contêiner sobe inteiro contra um Postgres local

```bash
docker network create band 2>/dev/null; docker run -d --network band --name pg -e POSTGRES_PASSWORD=dev postgres:16-alpine
docker run --rm --network band -e DATABASE_URL=ecto://postgres:dev@pg/band_prod \
  -e SECRET_KEY_BASE=$(openssl rand -base64 48) -e THE_BAND_MASTER_KEY=<chave de teste> \
  -e PHX_HOST=localhost -e PHX_SERVER=true -p 4001:4000 theband:dev
```

Esperado: "aplicando migrações pendentes… migrações aplicadas." ANTES do endpoint;
`curl -s localhost:4001/sign-in` → 200. (Chave de teste gerada na hora com
`mix the_band.gen_key` — nunca a real.)

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
