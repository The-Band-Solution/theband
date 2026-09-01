# Implementation Plan: O The Band em produção

**Branch**: `050-plano` (artefatos) | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/050-em-producao/spec.md`

## Summary

A produção nasce sobre o que o repositório JÁ tem (entrypoint com env conferidas e
migração antes de servir, `Release.migrate`, `releases()` — research R1) somando o
que falta: **Dockerfile multi-stage**, **`cd.yml`** (push na `main` → versão do
mix.exs → imagem no ghcr → tag git → webhook do Dokploy), a **fonte única da
versão** no PR de release, e o **runbook** do Dokploy no VPS Contabo (Postgres
gerenciado, backups em duas camadas, ensaio de restauração). Três atos ficam com
pessoas e são marcos nomeados: criar o VPS + Dokploy, os segredos, e o primeiro PR
de release (Product Owner, FR-016).

## Technical Context

**Language/Version**: Elixir/OTP do CI (a MESMA no builder — R2); mix release

**Primary Dependencies**: nenhuma de código; infra: Docker, GitHub Actions, ghcr,
Dokploy (Contabo VPS ~8GB)

**Storage**: Postgres gerenciado pelo Dokploy; backups Dokploy→S3-compatível +
snapshot Contabo (FR-014); restauração ENSAIADA (FR-008)

**Testing**: build da imagem no CI quando Dockerfile/rel mudarem; `docker run` sem
env recusa nomeando; varredura SC-005 (27 rotas da 045) contra produção no
primeiro release

**Target Platform**: VPS Contabo com Dokploy (decisões 2026-08-28/29)

**Performance Goals**: SC-002 (release <15min de procedimento, <2min de
indisponibilidade percebida) — medidos no primeiro release real

**Constraints**: nenhum segredo em repositório/imagem/log (FR-005/FR-009, SC-004);
auto-deploy-on-push do Dokploy DESLIGADO (FR-015); merge em main = deploy
(constituição 1.7.0); `rel/entrypoint.sh` e `Runs`/domínio INTOCADOS

**Scale/Scope**: 1 Dockerfile, 1 workflow, 1 runbook, 1 ajuste de CI (build da
imagem em PRs que tocam Docker), 0 mudanças de domínio

## Constitution Check

*Sem violações.*

| Princípio | Como |
|---|---|
| VI — contrato antes | `contracts/pipeline-de-release.md` antes de qualquer YAML/Dockerfile |
| VIII — estrutura justificada | ver registro abaixo; nada de Terraform/K8s/staging — problema que não existe nesta escala |
| Gitflow 1.7.0 | o CD é a consequência mecânica do "merge em main é deploy" |
| L60 | os passos do workflow ecoam veredito em log; o webhook usa `--fail` |
| L38/L03 | violações primeiro nos testes de infra: `docker run` sem env; tag repetida FALHA nomeando |
| Segurança (memória da casa) | segredos só em Secrets/painel; a lista é FECHADA no contrato |

### Registro das decisões de design (VIII)

| Decisão | Problema concreto (existe?) | O que piora |
|---|---|---|
| CD sem rerodar a suíte | o PR de release já passou no CI; dobrar custaria ~8min por deploy para reprovar o já aprovado | uma regressão só-de-merge escaparia — mitigada: main só recebe merge de PR verde |
| versão no mix.exs (fonte única) | duas fontes divergem (R3) | bump vira commit obrigatório no PR de release — é o desenho, não o custo |
| Dokploy consome imagem (não builda) | build no VPS gastaria o servidor de produção e duplicaria a receita | o VPS depende do ghcr acessível — aceito, é o mesmo GitHub do repositório |
| sem ambiente de staging | escala atual (dezenas de pessoas, 1 tenant); development+CI cobrem | o primeiro erro só aparece em produção — mitigado por rollback via imagem anterior no Dokploy |

## Busca dirigida — o que já existe e não muda (L71)

| Artefato | Destino |
|---|---|
| `rel/entrypoint.sh` | ADOTADO como está — as quatro env, migrate antes, `set -e` |
| `lib/the_band/release.ex` | intocado |
| `ci.yml` | ganha UM job condicional (build da imagem quando Dockerfile/rel/ mudarem); os treze+1 gates intocados |
| seeds (recusam :prod) | intocados — US3 da spec já implementada pela 045, conferida no primeiro release |

## Project Structure

### Documentation (this feature)

```text
specs/050-em-producao/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── checklists/requirements.md
└── contracts/pipeline-de-release.md
docs/producao/
└── runbook.md            # nasce nas tarefas: Dokploy, segredos, backup, restauração, rollback
```

### Source Code (repository root)

```text
Dockerfile                      # NOVO — multi-stage (R2)
.dockerignore                   # NOVO
.github/workflows/cd.yml        # NOVO — push em main (contrato)
.github/workflows/ci.yml        # + job build-da-imagem condicional
rel/entrypoint.sh               # existente, adotado
```

**Structure Decision**: zero diretório de código novo; infra na raiz e em
`.github/`, runbook em `docs/producao/`.

## Marcos com pessoas (paradas legítimas — R6)

1. VPS Contabo + Dokploy instalado (pessoa mantenedora, runbook §1).
2. `DOKPLOY_WEBHOOK_URL` nos GitHub Secrets + env no painel (pessoa mantenedora,
   runbook §2 — segredo nunca no chat).
3. Primeiro PR de release `development → main` (Product Owner, FR-016) — o
   primeiro deploy real, com SC-001/002/005 medidos e o ensaio de restauração
   (FR-008) antes de dado real.

## Complexity Tracking

Sem violações.
