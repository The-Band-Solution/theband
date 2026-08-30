# Research — 050 O The Band em produção

Medições de 2026-08-29 na `development`. As decisões de infraestrutura vieram da
pessoa mantenedora (2026-08-28/29) e estão nos FRs; aqui está o que o repositório
JÁ tem e o que falta, medido — nunca presumido.

## R1 — Metade da fundação de release já existe

**Medido**:

| Peça | Estado |
|---|---|
| `rel/entrypoint.sh` | **existe** — confere as quatro env obrigatórias pelo NOME (`DATABASE_URL`, `SECRET_KEY_BASE`, `THE_BAND_MASTER_KEY`, `PHX_HOST`), roda `TheBand.Release.migrate()` ANTES de servir (`set -e`: migração reprovada derruba o contêiner — nunca esquema pela metade), e dá `exec` no comando |
| `TheBand.Release.migrate/0` | existe (`lib/the_band/release.ex:31`) |
| `releases()` no `mix.exs` | existe (`the_band`, `include_executables_for: [:unix]`) |
| `assets.deploy` | alias existe |
| `config/runtime.exs` | `PHX_SERVER`, `DATABASE_URL` com mensagem de falta, recusa de boot sem `THE_BAND_MASTER_KEY` |
| **Dockerfile** | **NÃO existe** |
| **Workflow de CD** | **NÃO existe** — só `ci.yml` (que roda em todo push e PR: o Gitflow não abriu buraco) |

**Decisão**: o plano constrói só o que falta — Dockerfile, `cd.yml`, a fonte da
versão, e o runbook. O entrypoint e o migrate são adotados como estão.

## R2 — Dockerfile multi-stage, a receita padrão do Phoenix

**Decisão**: Dockerfile em dois estágios — builder (`hexpm/elixir` com a MESMA
versão de Elixir/OTP do CI, `mix deps.get --only prod`, `assets.deploy`,
`mix release`) e runtime (`debian-slim` da mesma base do builder, só a release +
`rel/entrypoint.sh`, usuário não-root, `ENTRYPOINT ["/app/entrypoint.sh"]`,
`CMD ["/app/bin/the_band", "start"]`).

**Rationale**: é o desenho do próprio gerador do Phoenix (`mix phx.gen.release
--docker`), sem invenção. bcrypt_elixir compila NIF no builder — a base do runtime
tem de ser a mesma família glibc do builder, e é por isso que os dois estágios
declaram a mesma imagem-base de SO.

## R3 — A fonte da versão é o `mix.exs`, e o PR de release a carrega

**Decisão**: a versão vive onde já vive — `project[:version]` no `mix.exs` (hoje
medido lá). O PR de release `development → main` (FR-016) inclui o bump da versão
como commit, e o CD **lê do mix.exs** para taggear imagem e criar a tag git
`vX.Y.Z` no merge. Uma fonte; o PO decide o número, o PR o registra, o CD o lê.

**Alternativas**: arquivo `VERSION` (segunda fonte para o mesmo fato — rejeitado);
tag manual antes do merge (inverte a ordem do Gitflow adotado: a tag NASCE do
merge — constituição 1.7.0).

## R4 — O CD dispara no push em `main`, e só nele

**Decisão**: `cd.yml` com `on: push: branches: [main]`. Passos: (1) reroda os
gates? NÃO — o PR de release já os rodou no CI e a main só recebe merge de PR; o
CD roda **teste de fumaça de build** (a imagem builda) e nada mais de suíte;
(2) extrai a versão do mix.exs; (3) builda e publica
`ghcr.io/the-band-solution/theband:vX.Y.Z` (e `:latest` como apontador) com
`GITHUB_TOKEN` (permissão `packages: write` — secret nativo, nada novo);
(4) cria a tag git `vX.Y.Z` no commit do merge se não existir;
(5) chama o webhook do Dokploy (`DOKPLOY_WEBHOOK_URL` em GitHub Secrets).

**Rationale**: na constituição 1.7.0, todo merge em main é deploy — o gatilho é
exatamente esse evento. Reproduzir a suíte no CD dobraria o tempo de entrega para
reprovar o que o CI acabou de aprovar.

## R5 — Dokploy: o app consome a imagem do ghcr, nunca builda

**Decisão**: o Dokploy roda a aplicação como **Docker image** apontando para
`ghcr.io/...:latest` (o webhook faz pull da mais nova ao ser chamado), com o
Postgres como serviço gerenciado do próprio Dokploy e as env obrigatórias no
painel. Auto-deploy-on-push do GitHub DESLIGADO no Dokploy (FR-015): quem manda é
o webhook, depois dos gates. Backup do banco agendado no Dokploy para storage
S3-compatível + snapshot da Contabo (FR-014, duas camadas), e o ENSAIO de
restauração (FR-008) é tarefa própria com evidência.

**Pacote privado**: ghcr de repositório privado exige credencial de registry no
Dokploy (um PAT read:packages) — registrada no painel, nunca no repositório. Se o
pacote for público, dispensa. Decisão operacional de quem cria o VPS; o runbook
cobre os dois.

## R6 — O que o repositório NÃO pode fazer sozinho (paradas legítimas)

1. Criar o VPS na Contabo e instalar o Dokploy — ato da pessoa mantenedora.
2. `DOKPLOY_WEBHOOK_URL` (e credencial do registry, se privado) nos GitHub
   Secrets — segredo nunca passa pelo chat nem pelo repositório.
3. O primeiro PR de release `development → main` — ato do Product Owner (FR-016).

O plano sequencia as tarefas para que TUDO de repositório fique pronto e testável
antes dessas três; elas entram como marcos nomeados no runbook.
