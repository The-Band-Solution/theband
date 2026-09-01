# Implementation Plan: A primeira conta nasce do ambiente

**Branch**: `052-primeira-conta-do-ambiente` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/052-primeira-conta-do-ambiente/spec.md`

## Summary

Uma função de domínio lê quatro valores do ambiente e, quando não existe nenhuma
pessoa com marca de administração, cria a organização e a primeira conta. Ela é
chamada pelo `rel/entrypoint.sh` logo depois de `Release.migrate()`, no mesmo
ponto onde o esquema já está aplicado e o endpoint ainda não subiu.

**Ela devolve um relator, e não imprime nada.** Quem imprime é o chamador do
release. Essa separação é o que torna a feature testável sem inspecionar log —
o defeito da L69, em que um erro dentro de `Logger.info` fica invisível ao teste
por configuração.

**Nenhuma migração é necessária**, e essa é a descoberta que mais encurtou o
plano. O FR-005 exige que duas subidas simultâneas não produzam dois
administradores, com a garantia vindo do armazenamento. Ela já existe:
`unique_index(:tenants, [:slug])` e `unique_index(:users, [:email])` estão no
esquema desde a primeira migração. Como as duas subidas simultâneas leem **as
mesmas variáveis**, elas tentam o mesmo slug e o mesmo e-mail — o banco deixa uma
passar e recusa a outra, que trata a recusa como "já existe" e segue.

## Technical Context

**Language/Version**: Elixir 1.20.2, OTP 29

**Primary Dependencies**: Ecto/Postgrex (já no projeto), Bcrypt via
`User.senha_changeset/3` (já existente). **Nenhuma dependência nova.**

**Storage**: PostgreSQL 16 — tabelas `tenants` e `users`, ambas já existentes,
**sem alteração de esquema**

**Testing**: ExUnit. Os casos de recusa e de idempotência são testes de domínio,
sem contêiner; o percurso do release entra no quickstart

**Target Platform**: o release em contêiner, no ponto do `entrypoint.sh`

**Project Type**: monólito modular multitenant (constituição V) — a feature vive
no contexto `TheBand.Tenants`, que já é dono de organização, conta e senha

**Performance Goals**: irrelevante — a função roda uma vez por boot e, no caso
comum, faz **uma** consulta de existência e para

**Constraints**: não pode derrubar o contêiner (FR-007); não pode imprimir a
senha (FR-006); precisa rodar depois do esquema e antes do endpoint (FR-003)

**Scale/Scope**: uma organização e uma conta, uma vez na vida de cada instalação

## Constitution Check

*GATE: passou antes da Phase 0, e reavaliado depois da Phase 1.*

| Princípio | Situação |
|---|---|
| **III — Proveniência e idempotência** | atendido pelo desenho: a função é idempotente por construção (FR-001/FR-002), e a idempotência é garantida pelo banco, não por consulta |
| **V — Monólito modular multitenant** | a criação passa pelo `Tenants`, que já é o dono. Nenhum módulo novo de domínio |
| **VI — Spec Kit antes do código** | spec e este plano antes de qualquer linha |
| **VIII — Desenho que o problema justifica** | ver a seção seguinte: um módulo novo, e a justificativa das três respostas |
| **X — Responsabilidade única** | a função decide e devolve; o release imprime. São dois atos, e o segundo não pertence ao domínio |
| **XI — Estado conferido antes, sinal nunca silenciado** | FR-009 exige que "já existe" seja **dito**. Silêncio faria "não criei" e "criei" parecerem iguais — o defeito do sucesso silencioso |

### Os padrões introduzidos, com as três respostas (princípio VIII)

**1. Um módulo novo, `TheBand.Tenants.Bootstrap`, em vez de uma função em `Tenants`.**

- *Qual problema concreto resolve*: `Tenants` tem 20 funções públicas e é o
  contexto que a interface inteira usa. A criação da primeira conta é o único
  caminho da plataforma que **lê o ambiente** e que **cria organização e conta
  no mesmo ato**. Misturada às demais, ela ficaria como uma função que qualquer
  tela pode chamar por engano, criando organização sem ninguém perceber.
- *Existe agora ou é previsão*: existe agora. O contexto já é grande, e a leitura
  de ambiente não aparece em nenhuma outra função dele.
- *O que fica pior*: mais um arquivo para quem procura "onde se cria conta". A
  mitigação é o `@moduledoc` do `Tenants` apontar para ele, e o inverso.

**2. Relator de retorno (`{:ok, :criada, ...}` / `{:ok, :ja_existe}` / `{:error, ...}`) em vez de imprimir direto.**

- *Qual problema concreto resolve*: L69 — defeito dentro de `Logger.info` é
  invisível a teste por configuração. Se a função imprimisse, os cenários da US3
  (variável ausente nomeada, regra recusada nomeada) só teriam prova por captura
  de log, que o projeto já viu falhar.
- *Existe agora ou é previsão*: existe agora, e está catalogado como lição.
- *O que fica pior*: o chamador precisa traduzir o relator em frase, e essa
  tradução é código que não existiria. É o mesmo custo que o projeto já paga em
  `humanizar/1`, e pela mesma razão.

**3. Nada mais.** Sem migração, sem *advisory lock*, sem tarefa `mix` nova, sem
tabela de controle de instalação, sem rota. Cada uma dessas foi considerada e
descartada no `research.md`, com o motivo.

## Project Structure

### Documentation (this feature)

```text
specs/052-primeira-conta-do-ambiente/
├── plan.md              # este arquivo
├── spec.md
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── primeira-conta.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks, ainda não
```

### Source Code (repository root)

```text
lib/the_band/tenants/
└── bootstrap.ex                    # NOVO — lê o ambiente, decide, devolve o relator

lib/the_band/
└── release.ex                      # ALTERADO — ganha semear_primeira_conta/0, que imprime

rel/
└── entrypoint.sh                   # ALTERADO — uma linha depois do migrate

test/the_band/tenants/
└── bootstrap_test.exs              # NOVO — a violação primeiro

docs/producao/
└── runbook.md                      # ALTERADO — §8, a primeira conta
```

**Structure Decision**: o monólito modular já existente. A feature acrescenta um
módulo ao contexto `Tenants` e uma chamada ao `Release` — não cria camada,
diretório nem aplicação.

## Complexity Tracking

> Sem violações da Constitution Check. Os dois padrões introduzidos estão
> justificados acima com as três respostas que o princípio VIII exige, e não são
> exceções a gate algum.
