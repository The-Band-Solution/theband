# Implementation Plan: Mensagens internacionalizadas

**Branch**: `047-mensagens-internacionalizadas` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/047-mensagens-internacionalizadas/spec.md`

## Summary

Toda mensagem que a plataforma diz às pessoas — recusa, confirmação, aviso — sai do
código e entra no catálogo gettext que o projeto já carrega ocioso, referenciada
pelo próprio texto (msgid = frase atual, research R2), em dois domínios (`errors`,
`sistema`). Um verificador AST (`mix mensagens.verificar`) entra nos gates e
reprova literal novo nos ralos de mensagem; `mix mensagens.lacunas` enumera o que
falta traduzir por idioma. A migração preserva cada byte do que as telas mostram —
nenhum teste de texto quebra, e a recusa única da 045 continua byte-idêntica por
construção.

## Technical Context

**Language/Version**: Elixir 1.20 / Phoenix LiveView (monolito existente)

**Primary Dependencies**: gettext (~> já em `mix.exs`, backend `TheBandWeb.Gettext`
existente e ocioso) — nenhuma dependência nova

**Storage**: nenhum — catálogo em `priv/gettext/*.po` (data-model.md)

**Testing**: ExUnit; testes de mix task com fixtures; testes de tela existentes
como sentinelas (texto inalterado)

**Target Platform**: o próprio monolito web

**Project Type**: web (estrutura existente `lib/the_band` + `lib/the_band_web`)

**Performance Goals**: nenhum novo — gettext resolve em compile/ETS; zero consulta

**Constraints**: migração NÃO muda um byte do texto exibido (R2); domínio
(`lib/the_band/**`) não chama gettext — devolve motivo, a borda traduz (contrato);
recusa única da 045 byte-idêntica com teste inalterado (FR-004)

**Scale/Scope**: 55 chamadas `put_flash` em 12 arquivos (medido); motivos de
recusa da borda; ~36 notices/estados vazios ficam ENUMERADOS em pendências por
tela (R7), fora do sprint

## Constitution Check

*GATE: verificado antes da Phase 0 e reavaliado após o design. Sem violações.*

| Princípio | Como o plano o atende |
|---|---|
| VI — contrato antes de função pública | `contracts/catalogo-de-mensagens.md` escrito antes de qualquer task/tela |
| VIII — estrutura só com problema real | ver "Registro das decisões de design" |
| X — módulo faz uma coisa | duas tasks separadas (`verificar` reprova; `lacunas` relata) — vereditos diferentes, módulos diferentes |
| Vertical slice | o catálogo nasce com consumidor: as 55 chamadas migradas e o gate reprovando plantio — nunca infraestrutura ociosa |
| L60 (gates) | veredito do gate dentro do log (quickstart §2/§5) |
| L03 (violação primeiro) | teste do verificador começa pelo literal plantado |

### Registro das decisões de design (princípio VIII)

| Decisão | Problema concreto (existe hoje?) | O que piora |
|---|---|---|
| mix task própria em vez de check do Credo | não há `.credo.exs`; registrá-lo exigiria materializar a config default e arriscar o veredito do gate credo (existe hoje) | mais um módulo de task; duas ferramentas de análise em vez de uma |
| msgid = frase atual, default "en" | assumption "pt padrão" quebraria dezenas de testes e deixaria a UI bilíngue por sprints (medido, R2) | o catálogo carrega msgids em duas línguas (045 é pt) — feiúra registrada, invariante preservada |
| domínio não chama gettext | já é o padrão da casa (`recusa/1`); gettext no domínio acoplaria mensagem a regra | a borda carrega funções de tradução de motivo — é onde elas já vivem |
| pendências como documento, não allowlist | allowlist consumida por gate vira lista permanente (a spec proíbe) | o gate não vê o legado HEEx — dívida visível em vez de imposta |

## Busca dirigida — testes do requisito que muda (L71)

A migração preserva texto por construção (R2), então **nenhum invariante é
revogado**. Sentinelas que provam isso, mapeadas antes do código:

| Teste | O que afirma | Destino |
|---|---|---|
| `login_test.exs` | recusa única byte-idêntica (Enum.uniq) | INALTERADO — passa por cima da migração (FR-004/SC-004) |
| `gating_operacional_test.exs` | `flash["error"] =~ "organization"` | inalterado — texto preservado |
| 5 arquivos com `flash["..."]` | textos de flash | inalterados — texto preservado |
| `menus_do_rastro_test` e telas | textos de tela | fora do escopo v1 (HEEx nas pendências) |

Se algum quebrar, a causa é migração que mudou texto — proibido pelo contrato, e o
conserto é restaurar o byte, nunca ajustar o teste.

## Project Structure

### Documentation (this feature)

```text
specs/047-mensagens-internacionalizadas/
├── plan.md              # este arquivo
├── research.md          # R1–R7
├── data-model.md        # estrutura do catálogo
├── quickstart.md        # validação de ponta a ponta
├── pendencias.md        # telas com texto HEEx fora do v1 (nasce na implementação, medido)
├── contracts/
│   └── catalogo-de-mensagens.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── mix/tasks/
│   ├── mensagens.verificar.ex     # NOVO — gate: AST dos ralos de mensagem
│   └── mensagens.lacunas.ex       # NOVO — relatório de lacunas por idioma
├── the_band_web/
│   ├── gettext.ex                 # existente — ganha config de locales
│   ├── controllers/session_controller.ex   # @mensagem_unica → defp com dgettext
│   ├── plugs/current_scope.ex     # flashes migrados
│   └── live/**/*.ex               # 12 arquivos com put_flash migrados
├── mix/tasks/gates.ex             # + gate "mensagens no catálogo"
config/config.exs                  # default_locale/allowed_locales
priv/gettext/                      # errors/sistema .pot + en/ + pt/

test/
├── mix/tasks/
│   ├── mensagens_verificar_test.exs
│   └── mensagens_lacunas_test.exs
└── the_band_web/…                 # sentinelas existentes, inalteradas
```

**Structure Decision**: monolito existente; a feature acrescenta duas mix tasks e o
catálogo — nenhum diretório novo além de `priv/gettext/pt/`.

## Complexity Tracking

Sem violações a justificar.
