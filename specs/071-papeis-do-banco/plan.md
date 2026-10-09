# Implementation Plan: Os papéis do banco — o que migra e o que serve

**Branch**: `feature/1131-papeis-do-banco` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

**Input**: `specs/071-papeis-do-banco/spec.md`, emendada pela avaliação de segurança
([seguranca.md](seguranca.md), S1 a S11) e pelas decisões da pessoa mantenedora de 2026-10-02.

## Summary

O processo que serve passa a conectar com um papel sem posse e sem superusuário, só com DML (a lista
fechada de FR-002). A migração roda com o papel dono, por uma credencial separada, que só o
entrypoint lê e que sai do ambiente antes do servidor.
- Um passo idempotente a cada deploy concede os privilégios e os padrões (R2).
- Uma conferência por `rpc` mede, no banco, se a separação está em vigor (R3).
- O deploy sem a credencial nova segue três estados (R4).
- O dono dedicado `the_band_owner` é passo do roteiro (R8).

## Technical Context

**Language/Version**: Elixir 1.20.2, OTP 29 (os de `development`).

**Primary Dependencies**: as de hoje. **Nenhuma dependência nova.**

**Storage**: PostgreSQL 16 em produção e 17 no CI (S8). Nenhuma tabela, coluna ou migração nova.

**Testing**: ExUnit. O papel não-dono nasce na transação do sandbox (`CREATE ROLE` é transacional,
medido), e as tentativas rodam em `SAVEPOINT`.

**Target Platform**: o contêiner da release no Dokploy (`rel/entrypoint.sh`, `Dockerfile`).

**Project Type**: monólito Phoenix. É infraestrutura de acesso, sem tela.

**Performance Goals**: a conferência por `rpc` em menos de 2 s; o passo de conceder em menos de 2 s
por deploy.

**Constraints**:
- nenhuma credencial em log, erro, commit ou roteiro (FR-012);
- só `42501` conta como recusa;
- a conferência nunca grava.

**Scale/Scope**: 1 módulo novo (`TheBand.Papeis`), três funções em `TheBand.Release`, o entrypoint,
1 teste e a §14 do runbook.

## Constitution Check

| princípio | como esta feature o cumpre |
|---|---|
| I, II, IV, IX | não toca ontologia, fonte externa nem base de conhecimento. `Papeis` declara "depende de nenhuma ontologia" |
| III | não muda ingestão nem proveniência; as guardas que protegem a proveniência passam a valer contra quem serve |
| V | o multitenant não muda; o papel que serve vê todo tenant, e isso é o risco residual declarado |
| VI | spec, plano, avaliação de segurança antes do código, tarefas e sprint backlog, nesta ordem |
| VII | `mix gates`, e as guardas nascem provadas (A1–A10, cada uma com o defeito a injetar) |
| VIII | uma estrutura nova, justificada abaixo |
| X | `Papeis` faz uma coisa: os privilégios do papel que serve, concedidos e conferidos. O entrypoint só orquestra |
| XI | a conferência lê antes de afirmar, e o veredito é o relator medido; o entrypoint não suprime erro (`set -e` mantido, e nenhum `2>/dev/null`) |

**Segurança (§14.0)**: avaliada por quem não escreveu o desenho, antes do plano. Os achados de
severidade média (S1–S7) entram como requisito; S5 entra como risco residual decidido, com a #1140.

### As decisões de desenho (princípio VIII)

| estrutura | problema concreto | existe agora? | o que fica pior |
|---|---|---|---|
| módulo `TheBand.Papeis` | a concessão (deploy), a conferência (`rpc`) e as pendentes (deploy sem credencial) leem e escrevem o mesmo catálogo de privilégios; em `Release` ficariam misturadas a seis outros comandos | sim, os três chamadores existem nesta feature | um arquivo a mais; o SQL de privilégio fica num lugar só, o que é a vantagem |
| o relator `{veredito, motivos}` | a frase "em vigor" tirada da presença da variável mentia (S2, S4); três consumidores precisam do mesmo veredito (log do deploy, `warning` a cada subida, `rpc`) | sim | o código traduz átomos em frase, como `Bootstrap` já faz |
| o passo de conceder **a cada deploy**, e não numa migração | a restauração e as tabelas fora do caminho ficam sem privilégio; a migração com nome de papel derruba o deploy (S7, R2) | sim | `GRANT`s leves a cada subida |
| `Task` sem link para o `warning` a cada subida | FR-008: o log do deploy some | sim | uma consulta de catálogo no boot; falha vira `:inconclusivo` e não derruba |

## Project Structure

### Documentation (this feature)

```text
specs/071-papeis-do-banco/
├── spec.md  seguranca.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/papeis.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/the_band/papeis.ex                 # novo: conceder/2, conferir/1, pendentes/1
lib/the_band/release.ex                # migrate/0 com a concessão; migrar_sem_credencial/0; conferir_papeis/0
lib/the_band/application.ex            # o Task do warning a cada subida
rel/entrypoint.sh                      # a credencial só na linha da migração, o unset, os três estados
docs/producao/runbook.md               # §14: os papéis, o dono dedicado, a troca, a conferência, o ensaio
test/the_band/papeis_test.exs          # A1–A8, A10
test/the_band/release_papeis_test.exs  # os três estados, a URL redigida (A7), A6
```

## Complexity Tracking

| desvio | por que é necessário | alternativa mais simples recusada porque |
|---|---|---|
| `TEMP` continua com `PUBLIC` (S10) | o PostgreSQL concede por padrão, e tirar exigiria conferir que nada da aplicação usa tabela temporária | a defesa é o `search_path` fixo nas funções de trigger, conferido pela conferência (`:funcao_sem_search_path`) |
| a credencial que migra no ambiente do contêiner (S5) | decisão de 2026-10-02: aceitar e declarar | migrar fora do contêiner ou o `setpriv` vão pela #1140, com avaliação própria |

## Riscos

| risco | mitigação |
|---|---|
| o primeiro deploy depois da troca sem a variável nova, e com migração pendente | **não sobe**, por decisão; o roteiro manda criar as duas variáveis **antes** do merge e conferir com o `rpc` |
| o Dokploy não manter o contêiner antigo quando o novo não sobe | não verificado; o roteiro faz a troca fora de deploy com migração |
| o backup do Dokploy com `--no-acl` | não verificado; o passo de conceder reaplica a cada deploy, e o ensaio confere (SC-005) |
| CI em 17, produção em 16 | a lista vai por nome; o teste afirma a ausência de `MAINTAIN` onde ele existe |
