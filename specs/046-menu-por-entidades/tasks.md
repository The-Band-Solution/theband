# Tasks: Menu por entidades

**Feature**: 046-menu-por-entidades | **Branch**: `046-menu-por-entidades`
**Input**: [spec.md](spec.md) · [plan.md](plan.md) · [research.md](research.md) · [contracts/](contracts/)

## Phase 1 — Setup

- [x] T001 Abrir branch e registrar baseline dos gates
  - **Pronta quando**: nada além do repositório; working tree limpa (`git status`)
  - **Descrição**: criar `feature/046-menu-por-entidades` a partir de `main`
    atualizada; rodar `mix gates` e guardar a saída como baseline — o veredito é o
    código de saída lido de dentro do log, nunca de comando composto (constituição XI)
  - **Feita quando**: a branch existe e o baseline registrou gates verdes antes de
    qualquer mudança
  - **Teste**: `echo $?` imediatamente após `mix gates` devolve 0, registrado no log
    da task

## Phase 2 — Foundational

- [x] T002 Helper de área ativa do menu
  - **Pronta quando**: T001 concluída
  - **Descrição**: função pura em `lib/the_band_web/components/layouts.ex` que mapeia
    o caminho da request para a área do menu (`/people` → `:people`, `/teams` →
    `:teams`, `/projects` e `/boards`... conferir: `/projects` → `:projects`;
    `/organizations` → `:organization`; `/work*`, `/roles`, `/syncs`, `/tools`,
    `/boards`, `/process` → `:settings`) — research R1, FR-006. Sem LiveView envolvida:
    caminho entra, átomo sai
  - **Feita quando**: todo caminho de rota existente resolve para exatamente uma área;
    caminho desconhecido resolve para `nil` sem levantar erro
  - **Teste**: `test/the_band_web/components/layouts_nav_test.exs` — tabela de
    caminhos cobrindo as 12 telas atuais + `/organizations` + caminho desconhecido

## Phase 3 — US1: A barra vira entidades + Settings (P1) 🎯 MVP

- [x] T003 [US1] Reorganizar a barra principal
  - **Pronta quando**: T002 concluída
  - **Descrição**: em `lib/the_band_web/components/layouts.ex`, a barra passa a
    conter só People, Teams, Projects (+ Organization quando T013 entregar a rota),
    Settings e o bloco da conta (tenant · e-mail, Sign out, theme_toggle) — FR-001.
    Remover os nove itens antigos da barra preservando o comentário-história do
    módulo (adaptado, não apagado: ele documenta por que Changes/Files/Checks
    precisam continuar acháveis — a resposta agora são as sub-abas). A marcação de
    área ativa usa o helper de T002 com `aria-current`
  - **Feita quando**: nenhuma tela renderiza os itens antigos na barra; a área ativa
    aparece marcada em toda tela; a barra rola dentro do contêiner em viewport
    estreito (classe `nav-rolavel` preservada — FR-008)
  - **Teste**: `layouts_nav_test.exs` — render do layout em rota de entidade e em
    rota movida: barra contém exatamente os itens esperados e `aria-current` na área
    certa; não contém "Changes" nem "Syncs"

- [x] T004 [US1] Menu Settings com três seções e gating
  - **Pronta quando**: T003 concluída
  - **Descrição**: dropdown Settings no header (`<details class="dropdown">` daisyUI,
    research R2) com seções Trabalho (Work), Vocabulário (Roles) e Operação (Syncs,
    Tools) — FR-002. Operação renderiza somente quando `User.admin?(@current_user)`
    (FR-003, research R5): condição num único ponto, para a spec 045 ampliar depois.
    Autorização de rota intocada
  - **Feita quando**: admin vê as três seções e alcança as cinco telas por clique;
    member vê Trabalho e Vocabulário e nenhum vestígio de Operação (nem o título);
    navegar fecha o dropdown
  - **Teste**: `layouts_nav_test.exs` — render com user admin contém
    "Operação"/"Syncs"/"Tools"; render com member não contém nenhum dos três; links
    apontam para as rotas de hoje

- [x] T005 [P] [US1] Rotas antigas respondem inalteradas
  - **Pronta quando**: T003 e T004 concluídas
  - **Descrição**: teste de fumaça percorrendo as rotas das nove telas movidas
    (`/roles`, `/work`, `/work/changes`, `/work/files`, `/work/verifications`,
    `/boards`, `/process`, `/syncs`, `/tools`) com sessão aberta — FR-004, SC-002.
    Nenhuma mudança em `router.ex` além da rota nova de US3
  - **Feita quando**: as nove rotas respondem com o mesmo status de antes da feature
    (incluindo o gating admin já existente de `/tools`)
  - **Teste**: `test/the_band_web/live/rotas_preservadas_test.exs` — cada rota
    montada com `live/2` ou `get/2`, asserção de status/redirect por papel

## Phase 4 — US2: Sub-abas de trabalho (P2)

- [x] T006 [US2] Componente de sub-abas
  - **Pronta quando**: T003 concluída (Work já fora da barra)
  - **Descrição**: function component `work_tabs/1` (em
    `lib/the_band_web/components/layouts.ex` ou `core_components.ex`, junto dos
    componentes de navegação) com assign `active` e as seis entradas fixas → rotas
    existentes: Issues `/work`, Changes `/work/changes`, Files `/work/files`, Checks
    `/work/verifications`, Boards `/boards`, Process `/process` — FR-005, research
    R6. Estilo de abas do design system (a ativa com marcação de borda/cor primária)
  - **Feita quando**: o componente renderiza as seis abas com a ativa marcada e
    `aria-current`; nenhuma rota inventada
  - **Teste**: teste de componente em `layouts_nav_test.exs` — render com cada valor
    de `active`, asserção do link marcado e dos seis hrefs exatos

- [x] T007 [US2] Sub-abas nas seis telas
  - **Pronta quando**: T006 concluída
  - **Descrição**: renderizar `<.work_tabs active={...}>` logo abaixo do header
    próprio em `work_item_live`, `change_live`, na LiveView de Files (conferir
    módulo real — plan aponta `repository_live`), `verification_live`, `board_live`
    e `process_live` — um valor de `active` por tela
  - **Feita quando**: as seis telas exibem as sub-abas com a própria tela marcada;
    navegar entre duas visões custa 1 clique (SC-004)
  - **Teste**: nos testes LiveView existentes de cada tela (ou
    `rotas_preservadas_test.exs`), asserção de que o HTML contém as sub-abas e a
    ativa certa por rota

## Phase 5 — US3: Tela Organization (P3)

- [x] T008 [US3] Leitura agregada da organização
  - **Pronta quando**: contrato `contracts/eo-organization-overview.md` escrito (está)
    e T001 concluída
  - **Descrição**: implementar `organization_overview/1` e
    `projects_without_organization/1` em
    `lib/the_band/ontology/seon/eo/queries.ex`, expostas por `defdelegate` na fachada
    `eo.ex` — exatamente o contrato: tenant como primeiro argumento, equipes
    vigentes, responsáveis pela definição da regra #369 (concessão declarada, nunca
    inferência por nome), projetos por `source_instance` ↔ login da organização
    (research R3/R4). Se a implementação desmentir o contrato, corrigir o contrato
    no mesmo commit com a razão
  - **Feita quando**: as duas funções devolvem as formas do contrato; organização sem
    equipe/responsável/projeto vem com listas vazias, não some; nenhum projeto entra
    em duas listas
  - **Teste**: `test/the_band/ontology/seon/eo/organization_overview_test.exs` — dois
    tenants povoados: o resultado de um não contém nada do outro (invariante
    multitenant é a violação testada); projeto com `source_instance` sem organização
    correspondente aparece só em `projects_without_organization/1`

- [x] T009 [US3] Tela Organization com estados vazios nomeados
  - **Pronta quando**: T008 concluída
  - **Descrição**: LiveView nova `lib/the_band_web/live/organization_live/index.ex` +
    rota `live "/organizations"` na live_session autenticada; uma seção por
    organização com equipes, responsáveis e projetos clicáveis para as páginas
    existentes; grupo "sem organização identificada" ao fim quando houver; estados
    vazios nomeados em cada nível — FR-007, SC-006. Adicionar o item Organization à
    barra (previsto em T003) com área ativa `:organization`
  - **Feita quando**: a tela lista o que o banco dev contém; cada ausência tem frase
    própria dizendo o que a alimentaria; tenant sem organização mostra o estado vazio
    da tela inteira; Organization marcada na barra
  - **Teste**: `test/the_band_web/live/organization_live_test.exs` — tenant povoado:
    organizações com equipes e projetos aparecem, HTML não contém dado do segundo
    tenant; tenant vazio: frase do estado vazio presente, zero seções de organização

- [x] T010 [US3] Número conferido contra a origem
  - **Pronta quando**: T009 concluída; banco dev povoado
  - **Descrição**: verificação da regra da casa (suíte verde não é evidência): com o
    servidor de dev de pé, comparar a contagem de organizações e de projetos por
    organização exibida em `/organizations` com consulta SQL direta; conferir se
    `source_instance` casa com os logins reais — o risco declarado em research R3.
    Registrar números e screenshot como evidência para o PR
  - **Feita quando**: contagens da tela == contagens do banco; o destino real dos
    projetos (casados vs. órfãos) está registrado com números
  - **Teste**: a própria verificação: saída do SQL + screenshot anexados à task/PR;
    divergência é bloqueio, não observação

## Phase 6 — Polish

- [x] T011 Gates verdes e evidência de viewport
  - **Pronta quando**: T003–T010 concluídas
  - **Descrição**: rodar `mix gates` (veredito = código de saída, nenhum comando
    depois); conferir SC-005 em viewport 1.280px (nenhuma rolagem lateral da página
    em People, Work com sub-abas, Organization e com o dropdown Settings aberto) com
    screenshot como evidência; atualizar `docs/` se o design system referenciar o
    menu antigo
  - **Feita quando**: 13 gates verdes registrados; screenshots de 1.280px sem
    rolagem lateral anexados
  - **Teste**: log do `mix gates` com código de saída 0 lido de dentro do log;
    screenshots no PR

## Dependencies

```text
T001 → T002 → T003 → T004 → T005
                 └──→ T006 → T007
T001 → T008 → T009 → T010          (T008 só depende de T001 + contrato)
T003 ─────────┘ (item Organization na barra entra com T009)
T005, T007, T010 → T011
```

- US1 (T003–T005) é o MVP — entregável e testável sozinha.
- US2 (T006–T007) depende só de T003; US3 (T008–T010) depende de T001/T003.
- US2 e US3 são paralelizáveis entre si depois de T003.

## Parallel Execution Examples

- Depois de T004: **T005 [P]** em paralelo com T006 (arquivos distintos).
- Depois de T003: US2 (T006) e US3 (T008) em paralelo — front de layout e query EO
  não se tocam.

## Implementation Strategy

MVP = Phase 1–3 (US1): a barra reorganizada com Settings entrega o valor pedido e é
demonstrável sozinha. US2 devolve a adjacência das telas de trabalho. US3 fecha o
espelho entidade↔menu com a única tela nova. Cada fase termina com os testes da
própria fase verdes antes da próxima começar.
