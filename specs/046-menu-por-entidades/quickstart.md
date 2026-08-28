# Quickstart — validar o menu por entidades (046)

## Pré-requisitos

```bash
docker compose up -d postgres        # já de pé no dev
set -a && source .env && set +a      # THE_BAND_MASTER_KEY e afins
mix ecto.setup                       # se o banco estiver vazio: seeds com 2 tenants
mix phx.server                       # http://localhost:4000
```

## Cenários de validação

### US1 — barra e Settings

1. Entrar como conta **admin** → barra mostra People · Teams · Projects ·
   Organization · Settings · conta. Nenhum dos nove itens antigos na barra.
2. Abrir Settings → seções Trabalho (Work), Vocabulário (Roles), Operação (Syncs,
   Tools). Clicar cada item → tela certa, URL de hoje.
3. Entrar como conta **member** → Settings sem a seção Operação (nem título).
4. Acessar direto `/work/changes`, `/roles`, `/syncs` → telas respondem como antes
   (autorização inalterada).
5. Em cada tela: conferir a marcação de área ativa na barra (entidade ou Settings).
6. Estreitar a janela (<900px) → barra rola dentro de si; página sem rolagem lateral.

### US2 — sub-abas de trabalho

1. Abrir `/work` → sub-abas Issues · Changes · Files · Checks · Boards · Process,
   Issues marcada.
2. Clicar Changes → `/work/changes`, Changes marcada. Repetir para as seis.
3. Abrir `/process` por URL direta → sub-abas presentes, Process marcada.

### US3 — tela Organization

1. Abrir Organization pela barra → organizações do tenant, cada uma com equipes,
   responsáveis e projetos; itens clicáveis levam às páginas existentes.
2. Projetos sem organização identificada aparecem no grupo nomeado próprio.
3. No tenant secundário do seed (sem organização, se for o caso) → estado vazio
   nomeado.
4. Conferir número contra a origem (regra da casa): total de organizações na tela ==
   `SELECT count(*) FROM eo_organizations WHERE tenant_id = ...` no banco dev.

## Testes e gates

```bash
mix test test/the_band_web/live/organization_live_test.exs
mix test test/the_band_web/components/
mix test test/the_band/ontology/seon/eo/organization_overview_test.exs
mix gates    # veredito = código de saída; nenhum comando depois dele
```

Contratos: [contracts/eo-organization-overview.md](contracts/eo-organization-overview.md).
Modelo: [data-model.md](data-model.md) — sem entidade nova.
