# Implementation Plan: Gerar só com chave — o botão diz antes do clique

**Branch**: `048-botao-sem-chave-desabilitado` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/048-botao-sem-chave-desabilitado/spec.md`

## Summary

Os botões de geração (página da pessoa e geração mensal) passam a dizer ANTES do
clique quando não há chave utilizável: `disabled` real + frase adaptada a quem lê
(quem opera recebe o caminho, quem não opera recebe quem resolve). A leitura de
estado reusa `AI.origem_da_chave/1` (1 por mount); a medição revelou que o caminho
da pessoa não tinha defesa de domínio — `Profiles.request/3` ganha a guarda
`{:error, :sem_chave}` que a spec supunha existente (research R3, spec corrigida).

## Technical Context

**Language/Version**: Elixir/Phoenix LiveView (monolito existente)

**Primary Dependencies**: nenhuma nova

**Storage**: nenhum novo — lê `ProviderCredential` existente (1 consulta por mount)

**Testing**: ExUnit + LiveViewTest; violação primeiro (L03)

**Target Platform / Project Type**: o monolito web

**Performance Goals**: zero consulta nova por linha; 1 leitura de credencial por
mount (edge case da spec)

**Constraints**: `Runs.credencial/1` (tenant-only, FR-011/044) INALTERADA;
`AI.opcoes/1` INALTERADA; desabilitar é comunicação — a defesa é do domínio (FR-003)

**Scale/Scope**: 2 telas, 4 botões (Generate again/profile; Turn on/Run now),
1 guarda de domínio

## Constitution Check

| Princípio | Como |
|---|---|
| VI — contrato antes | `contracts/estado-da-chave.md` com a mudança de `request/3` |
| VIII — estrutura justificada | nenhum módulo novo; PubSub de credencial REJEITADO (research R5: problema não existe) |
| X — uma coisa | a guarda vive em `request/3` (dono do enfileiramento); a frase vive na borda |
| Vertical slice | a guarda nasce com as duas telas consumindo o estado — nunca só backend |
| L03 | primeiro teste: evento forçado sem chave, recusado sem job |

### Registro das decisões de design (VIII)

| Decisão | Problema concreto (existe?) | O que piora |
|---|---|---|
| guarda em `request/3` | job condenado enfileirado sem chave; tela fica pendente para sempre (medido, R3 — sucesso silencioso) | quem chama passa a tratar `:sem_chave` |
| dois predicados de habilitação | os dois caminhos JÁ têm regras diferentes (mensal tenant-only por FR-011/044) | a tela carrega dois motivos — verdade do domínio, não complexidade nova |
| sem PubSub de credencial | nenhum: reavaliação por mount cobre o fluxo real | recarregar a página após configurar — aceito e declarado na spec (FR-002) |

## Busca dirigida — testes do requisito que muda (L71)

| Teste | O que afirma hoje | Destino |
|---|---|---|
| testes de `gerar_perfil` na página da pessoa | clique enfileira | ganham o setup de chave (ambiente ou tenant) — o clique só existe com chave |
| `profile_run_live` testes de run_now/enable | fluxo com credencial | inalterados (já criam credencial) — conferir, não presumir |
| flash "This organisation has no provider key" (run screen) | recusa do domínio na tela | INALTERADO — cenário 4: a recusa fica |

## Project Structure

### Documentation (this feature)

```text
specs/048-botao-sem-chave-desabilitado/
├── plan.md, research.md, quickstart.md, tasks.md
└── contracts/estado-da-chave.md
```

(Sem data-model.md: nenhuma entidade — leitura de credencial existente.)

### Source Code (repository root)

```text
lib/the_band/profiles.ex                      # request/3 ganha a guarda :sem_chave
lib/the_band_web/live/people_live/show.ex     # assign do estado + disabled + frase
lib/the_band_web/live/profile_run_live/index.ex  # idem, predicado tenant-only
test/the_band/profiles_test.exs               # violação: sem chave, sem job
test/the_band_web/live/botao_sem_chave_test.exs  # as duas telas, dois perfis de leitor
```

**Structure Decision**: monolito existente, zero arquivo novo além do teste.

## Complexity Tracking

Sem violações.
