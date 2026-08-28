# Implementation Plan: Menu por entidades

**Branch**: `046-menu-por-entidades` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/046-menu-por-entidades/spec.md`

## Summary

Reorganizar a navegação: barra principal com as entidades (People, Teams, Projects,
Organization) + Settings + conta; as nove telas restantes migram para um menu Settings
em três seções (Trabalho, Vocabulário, Operação — a última só para admin); as seis
telas de trabalho ganham sub-abas comuns; e nasce a tela Organization, leitura pura da
EO. Nenhuma rota muda, nenhuma migração, nenhum conceito ontológico novo.

## Technical Context

**Language/Version**: Elixir ~> 1.17, Phoenix LiveView (projeto existente)

**Primary Dependencies**: Phoenix LiveView, Tailwind + daisyUI (design system em
`assets/css/app.css`, normativo por `docs/design-system.md`)

**Storage**: PostgreSQL 16 via Ecto — **sem migração nesta feature** (leitura apenas)

**Testing**: ExUnit + Phoenix.LiveViewTest; gates via `mix gates` (13 gates)

**Target Platform**: web (monólito Phoenix multitenant)

**Project Type**: web app — mudança em `lib/the_band_web` (layout, um LiveView novo) e
uma função de leitura nova em `lib/the_band` (EO)

**Performance Goals**: nenhum novo — telas de leitura nos padrões existentes

**Constraints**: URLs existentes imutáveis (FR-004); rolagem lateral da página proibida
(FR-008, regra já vigente no layout); gating de menu Operação usa `current_user.role == "admin"`
(modelo vigente — a spec 045 amplia depois)

**Scale/Scope**: 1 layout alterado, 1 componente de sub-abas, 1 LiveView novo
(Organization), ~6 LiveViews tocados para exibir sub-abas, 1 função pública nova na EO

## Constitution Check

*GATE: aprovado antes da Phase 0; reavaliado após Phase 1.*

| Princípio | Avaliação |
|---|---|
| I. Domínio pelas ontologias | ✅ Tela Organization lê EO (organizações, equipes) e Projects — nenhum conceito novo, nenhuma duplicação. |
| II. Fonte externa não é domínio | ✅ Nenhuma coleta tocada. Vínculo projeto→organização usa o que o domínio já registra (ver research R3 e a limitação declarada). |
| III. Proveniência e idempotência | ✅ Leitura pura; nada gravado. |
| IV. Semântica em YAML | ✅ Não se aplica — nenhum mapeamento novo. |
| V. Monólito modular multitenant | ✅ Toda consulta nova recebe `tenant` como primeiro argumento (padrão EO). |
| VI. Spec Kit antes do código | ✅ spec.md + checklist aprovados; contrato da função nova em `contracts/` antes da implementação. |
| VII. Quality gates | ✅ `mix gates` antes do PR; testes LiveView para menu, sub-abas e tela nova. |
| VIII. Desenho que o problema justifica | ✅ Ver "Decisões de desenho" abaixo — cada estrutura nova com problema, existência e custo. |
| IX. Ontologias modulares | ✅ Nada muda na rede. |
| X. Responsabilidade única | ✅ Tela Organization faz uma coisa: mostrar a organização. Sub-abas são navegação, não lógica. |
| XI. Estado conferido, sinal não silenciado | ✅ Nenhum comando destrutivo no fluxo; gates lidos do código de saída. |

### Decisões de desenho (princípio VIII)

1. **Componente `nav_settings` (menu suspenso) no layout**
   - *Problema concreto*: doze itens numa barra que já estourou 1.280px (medido
     2026-08-19); telas que "não se acham" — Changes/Files/Checks ficaram meses
     alcançáveis só por URL.
   - *Existe agora?* Sim — medido e documentado no próprio layout.
   - *O que piora*: telas movidas ficam a 2 cliques em vez de 1; mitigado pelas
     sub-abas (US2) para o grupo de uso frequente.

2. **Componente de sub-abas das telas de trabalho (function component único)**
   - *Problema concreto*: com Work fora da barra, alternar entre as seis visões
     custaria Settings → item a cada troca. Seis telas repetirem markup de navegação à
     mão divergiria na primeira mudança.
   - *Existe agora?* Nasce com a US1 desta feature — é consequência direta, não
     previsão.
   - *O que piora*: um componente a mais no layouts/core; custo pequeno e local.

3. **Função nova `EO.organization_overview/1` (leitura agregada)**
   - *Problema concreto*: a tela Organization precisa de organizações + equipes +
     responsáveis numa passada; compor N consultas na LiveView furaria a fronteira do
     módulo (AGENTS §7.1) e espalharia a regra de "responsável".
   - *Existe agora?* Sim — a tela é desta feature.
   - *O que piora*: mais um item na fachada EO; aceito, é o padrão do módulo
     (defdelegate, ADR 0003).

**Nenhuma violação. Complexity Tracking vazio.**

## Project Structure

### Documentation (this feature)

```text
specs/046-menu-por-entidades/
├── plan.md              # este arquivo
├── research.md          # Phase 0
├── data-model.md        # Phase 1 (sem entidade nova — declara isso)
├── quickstart.md        # Phase 1
├── contracts/
│   └── eo-organization-overview.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/the_band_web/
├── components/
│   ├── layouts.ex            # barra principal reorganizada + menu Settings
│   └── core_components.ex    # (ou layouts.ex) sub-abas de trabalho: work_tabs/1
├── live/
│   ├── organization_live/
│   │   └── index.ex          # tela Organization (nova, leitura)
│   ├── work_item_live/       # recebe <.work_tabs active={:issues}>
│   ├── change_live/          # :changes
│   ├── repository_live/      # :files (conferir módulo real na implementação)
│   ├── verification_live/    # :checks
│   ├── board_live/           # :boards
│   └── process_live/         # :process
└── router.ex                 # rota nova /organizations (única rota nova)

lib/the_band/ontology/seon/eo.ex        # defdelegate organization_overview/1
lib/the_band/ontology/seon/eo/queries.ex # implementação da leitura agregada

test/the_band_web/live/organization_live_test.exs
test/the_band_web/components/layouts_nav_test.exs   # menu por papel + marcação ativa
test/the_band/ontology/seon/eo/organization_overview_test.exs
```

**Structure Decision**: monólito existente; mudança concentrada em `the_band_web`
(layout + 1 LiveView) e uma consulta agregada na EO atrás da fachada.

## Complexity Tracking

Sem violações — tabela vazia.
