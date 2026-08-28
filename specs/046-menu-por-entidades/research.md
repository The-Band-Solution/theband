# Research — Menu por entidades (046)

## R1 — Como marcar a área ativa na barra

**Decision**: derivar a área ativa do caminho da request (`@conn.request_path` /
socket view), mapeada por prefixo de rota → área (`/people` → People, `/work*` →
Settings, `/organizations` → Organization…), num helper puro no `layouts.ex`.

**Rationale**: o layout hoje não marca item ativo — a spec exige (FR-006). Mapa por
prefixo é declarativo, testável sem LiveView, e não exige que cada tela declare nada.

**Alternatives considered**: cada LiveView assinar a própria área via assign —
espalha responsabilidade por ~15 arquivos e quebra em silêncio quando uma tela nova
esquece; rejeitado.

## R2 — Menu Settings: dropdown ou página?

**Decision**: dropdown daisyUI (`<details class="dropdown">` ou popover) no header,
com as três seções e itens condicionais por papel. Sem página intermediária.

**Rationale**: o protótipo aprovado mostra dropdown; página intermediária custaria um
clique a mais em tudo. daisyUI dropdown já é dependência; fecha ao navegar
(comportamento nativo de `<details>` + navegação LiveView).

**Alternatives considered**: página /settings com cards — mais um hop; rejeitada.
Sidebar — mudança de layout muito maior que o problema; rejeitada.

## R3 — Projetos por organização: o vínculo que existe

**Decision (corrigida na implementação, 2026-08-28)**: a tela Organization liga
projeto a organização pela cadeia declarada
`observed_projects.connected_tool_id → connected_tools.organization_login →
eo_organizations.login`. Projeto cuja ferramenta não casa com organização observada
aparece num grupo "sem organização identificada" — ausência nomeada, nunca omitida.

**Rationale**: a primeira versão desta decisão casava por
`observed_projects.source_instance` ↔ login — e a implementação desmentiu **antes do
banco**: a coleta grava `source_instance = tool.instance_url`
(`lib/the_band/ingestion/github_projects.ex`), a URL da instância, nunca o login.
Teriam sido 100% órfãos. A cadeia pela ferramenta conectada é declarada no cadastro
(o GitHub exige `organization_login` na conexão) e já é o elo que o retrofito usa
(`fetch_organization_by_login/2`).

**Alternatives considered**: casar por `source_instance` — desmentido pelo código da
coleta; rejeitado. Adicionar `organization_id` ao projeto — migração + re-coleta,
escopo de outra feature; rejeitado aqui. Omitir projetos sem vínculo — ausência
silenciosa, proibida pela casa; rejeitado.

**Risco residual**: ferramenta antiga sem `organization_login` (outros tool_types não
o exigem) produz projetos órfãos legítimos — é o que o grupo nomeado existe para
mostrar. T010 ainda confere os números contra o banco povoado.

## R4 — "Responsáveis" da organização

**Decision**: responsáveis = pessoas com papel organizacional cuja concessão de
visibilidade (`eo_role_visibility_grants`) tem escopo organização — a mesma definição
que a regra "quem vê o painel de quem" (#369/FR-012) já usa para "responsável da
organização". A leitura entra na agregada `organization_overview/1`.

**Rationale**: reusa a definição declarada existente; inventar uma segunda noção de
"responsável" criaria dois vocabulários para a mesma palavra — o erro que o projeto
já documenta em `users.role` vs papel organizacional.

**Alternatives considered**: inferir por nome de papel ("Tech Leader") — proibido
explicitamente pela regra existente (não infere liderança por nome); rejeitado.

## R5 — Gating da seção Operação

**Decision**: `current_user.role == "admin"` — o mesmo predicado que hoje esconde
Tools. `User.admin?/1` já existe.

**Rationale**: FR-003 manda estender o gating vigente a Syncs dentro de Settings, sem
mudar autorização de rota. Quando a spec 045 entregar escopos, a condição vira
"admin? or organization_scope?" num único ponto (o helper do menu).

**Alternatives considered**: esperar a 045 — deixaria Syncs visível a todos dentro de
Settings, regressão contra o protótipo aprovado; rejeitado.

## R6 — Sub-abas: componente e rotas

**Decision**: function component `work_tabs/1` (assigns: `active`), com as seis
entradas fixas → rotas existentes (`/work`, `/work/changes`, `/work/files`,
`/work/verifications`, `/boards`, `/process`). Renderizado por cada uma das seis
LiveViews logo abaixo do header próprio.

**Rationale**: rotas não mudam (FR-004); as três primeiras já vivem sob `/work/*`.
Um componente único mantém as seis telas sincronizadas.

**Alternatives considered**: live_session com layout próprio contendo as abas — mexe
em roteamento sem necessidade; rejeitado. Mover /boards e /process para /work/* —
quebra URLs, proibido pela FR-004; rejeitado.
