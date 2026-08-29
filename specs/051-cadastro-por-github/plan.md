# Implementation Plan: Contas — cadastrar pessoas e associar o GitHub

**Branch**: `051-cadastro-por-github` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/051-cadastro-por-github/spec.md`

## Summary

`/accounts` vira a área única do onboarding: cadastrar a pessoa (nome + e-mail, com a
temporária emitida NO ato — transação nova `cadastrar_conta/3`) e associar a conta do
GitHub ali mesmo (busca entre pessoas coletadas, `declare_person/4` existente, recusa
de conflito nomeando a conta dona via leitura estreita `user_of_person/2`). Nenhuma
entidade nova, nenhuma migração: o índice único parcial do elo vigente já garante a
corrida, e a feature é recomposição de tela sobre domínio que existe.

## Technical Context

**Language/Version**: Elixir/Phoenix LiveView (monolito existente)

**Primary Dependencies**: nenhuma nova

**Storage**: nenhum novo — users + elo existentes; índice único parcial já imposto

**Testing**: ExUnit + LiveViewTest; violações primeiro (L03): conflito e duplicado

**Performance Goals**: lista com elo em UMA consulta (join), busca só por evento,
leitura do conflito só no caminho do erro — zero consulta por linha (L38)

**Constraints**: fluxo da temporária da 045 intacto (mostrada uma vez, troca
forçada); invariante de login intacto; `create_user/2` e `declare_person/4` com
contratos vigentes inalterados; frases novas no catálogo da 047 (gate reprova
literal)

**Scale/Scope**: 1 tela recomposta (`accounts_live`, 161 linhas hoje), 2 funções de
domínio novas (1 transação, 1 leitura estreita), ~6 mensagens novas no catálogo

## Constitution Check

*Sem violações.*

| Princípio | Como |
|---|---|
| VI — contrato antes | `contracts/contas-e-elo.md` com as duas funções novas e a tela |
| VIII — estrutura justificada | ver registro abaixo; entidade "pessoa declarada" REJEITADA na spec |
| X — tela faz uma coisa | a coisa de /accounts é contas; o elo é atributo de conta — a leitura do elo continua na página da pessoa |
| Vertical slice | as funções novas nascem com a tela consumindo — nunca domínio ocioso |
| L03 | violações primeiro: pessoa já vinculada, e-mail duplicado |
| L38 | join único para a lista; busca por evento; conflito lido só no erro |

### Registro das decisões de design (VIII)

| Decisão | Problema concreto (existe?) | O que piora |
|---|---|---|
| `cadastrar_conta/3` transacional | cadastro em dois cliques deixa conta sem senha se o segundo falta (existe: create é insert puro) | mais uma função pública ao lado de `create_user/2` — os dois documentados no contrato |
| `user_of_person/2` leitura estreita | `:taken` sem nome obriga quem administra a caçar a conta dona (existe: cenário 3) | uma função de leitura a mais; roda só no erro |
| erro de `declare_person` NÃO muda | — | evita mexer em contrato vigente usado pela página da pessoa |

## Busca dirigida — testes do requisito que muda (L71)

| Teste | O que afirma hoje | Destino |
|---|---|---|
| `accounts_test.exs` (da 045) | criar por e-mail e reset com temporária | INALTERADOS — `create_user/2` e `reset_password/3` não mudam; a tela ganha o ato novo ao lado |
| testes do elo na página da pessoa | declarar/revogar lá | INALTERADOS — a página continua lendo e administrando; a 051 acrescenta o segundo lugar de administração, não move o primeiro* |
| `login_test.exs` | recusa única | INALTERADO |

*A spec diz "muda ONDE se administra, não onde se lê" — e o plano mantém a
administração TAMBÉM na página da pessoa (remover seria regressão de fluxo sem
pedido; o custo de manter é zero, é o mesmo domínio).

## Project Structure

### Documentation (this feature)

```text
specs/051-cadastro-por-github/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── checklists/requirements.md
└── contracts/contas-e-elo.md
```

(Sem data-model.md: nenhuma entidade nova — contrato registra as duas funções.)

### Source Code (repository root)

```text
lib/the_band/tenants.ex                    # + cadastrar_conta/3, user_of_person/2
lib/the_band_web/live/accounts_live/index.ex   # lista com elo, cadastro com temporária, associar/revogar
priv/gettext/                              # ~6 chaves novas (errors/sistema)
test/the_band/tenants_cadastro_test.exs    # NOVO — transação e violações
test/the_band_web/live/accounts_elo_test.exs   # NOVO — tela: associar, conflito nomeado, revogar, N+1
```

**Structure Decision**: monolito existente; zero diretório novo.

## Complexity Tracking

Sem violações.
