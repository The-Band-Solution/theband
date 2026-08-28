# Implementation Plan: Autenticação e papel de acesso

**Branch**: `045-autenticacao-e-acesso` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/045-autenticacao-e-acesso/spec.md`

## Summary

Fechar a porta e graduar o acesso: login por e-mail ou usuário do GitHub com senha
(irreversível em repouso), logout e expiração de sessão; escopos de acesso
**acumulativos** — person como piso do elo vigente, team/project derivados das relações
ou concedidos, organization só concedido — com administrador como marca de gestão
noutro eixo; tela de perfil; gestão de contas e concessões em Settings; e as telas
operacionais (Syncs, Tools, AI) restritas a administrador ou organization (FR-023).
Protótipo aprovado no canvas "Autenticação e Acesso"; o axioma que rege tudo: **a
pessoa tem acesso aos dados com os quais está relacionada.**

## Technical Context

**Language/Version**: Elixir ~> 1.17, Phoenix LiveView (projeto existente)

**Primary Dependencies**: existentes + **`bcrypt_elixir` (nova — ver justificativa em
research R1)** para hash de senha

**Storage**: PostgreSQL 16 via Ecto — migrações em `users` (credencial, sessão,
tentativas) e tabela nova `access_scope_grants` (concessões, com proveniência)

**Testing**: ExUnit + Phoenix.LiveViewTest; `mix gates` (13 gates); testes de violação
obrigatórios (acesso indevido, vazamento entre tenants, sessão morta)

**Target Platform**: web (monólito Phoenix multitenant)

**Project Type**: web — domínio (`tenants/`, `ontology/seon/eo/visibility`) + web
(login, perfil, gestão, gating de menu e rotas)

**Performance Goals**: verificação de escopo por request sem consulta-por-linha (L38);
hash de senha ~100ms por tentativa (custo do bcrypt é feature, não bug)

**Constraints**: FR-002 mensagem única de recusa; FR-003 senha irreversível e fora de
log; FR-017 tenant em toda consulta; FR-018 regra de liderança declarada (#369)
preservada — escopos SOMAM; migração sem rebaixamento silencioso (admins ganham
organization de cada organização observada)

**Scale/Scope**: 3 user stories; ~5 telas (sign-in refeita, perfil nova, contas +
concessões novas em Settings, gating nas operacionais); 2 migrações; 1 módulo de
domínio novo (escopos) + rework do Visibility

## Constitution Check

*GATE: aprovado antes da Phase 0; reavaliado após Phase 1 — sem violação.*

| Princípio | Avaliação |
|---|---|
| I. Domínio pelas ontologias | ✅ Escopo de acesso é vocabulário da PLATAFORMA (tenants/), não da ontologia; deriva de relações da EO por leitura, sem duplicar conceito. A distinção papel de acesso ≠ papel organizacional atravessa spec, código e telas. |
| II. Fonte externa não é domínio | ✅ Nenhuma coleta tocada. Login por usuário do GitHub lê o elo declarado + `eo_people.login` já coletado. |
| III. Proveniência e idempotência | ✅ Concessão carrega quem/quando; revogação grava `revoked_at` — marca, nunca apaga. Derivado não se grava: é leitura do fato. |
| IV. Semântica em YAML | ✅ Não se aplica — nenhum mapeamento novo. |
| V. Monólito modular multitenant | ✅ `access_scope_grants` com `tenant_id` + índices; toda API recebe tenant. |
| VI. Spec Kit antes do código | ✅ spec + checklist aprovados; contratos em `contracts/` antes das funções públicas. |
| VII. Quality gates | ✅ gates antes do PR; teste de violação para cada invariante de segurança. |
| VIII. Desenho que o problema justifica | ✅ ver "Decisões de desenho" abaixo. |
| IX. Ontologias modulares | ✅ nada muda na rede. |
| X. Responsabilidade única | ✅ telas: entrar / perfil / contas / concessões — uma coisa cada; módulo `Tenants.Access` decide escopo, `Vault`-like separação para senha (no changeset, nunca na tela). |
| XI. Estado conferido, sinal não silenciado | ✅ migração testada com rollback; recusa de login nunca silenciosa em log de auditoria (sem vazar segredo). |

### Decisões de desenho (princípio VIII)

1. **Dependência nova `bcrypt_elixir`**
   - *Problema*: FR-003 exige senha irreversível; não existe hash de senha no projeto.
   - *Existe agora?* Sim — é o objeto da feature.
   - *O que piora*: NIF nativo no build; aceito — é o padrão do ecossistema
     (phx.gen.auth) e o custo computacional por tentativa é desejado (research R1).

2. **Tabela `access_scope_grants` (concessões) separada de `users`**
   - *Problema*: escopos ACUMULAM (N por conta) com alvo e proveniência — não cabem em
     coluna; e derivado não se grava (acompanha o fato), então a tabela guarda SÓ o
     concedido.
   - *Existe agora?* Sim — FR-006/007/008.
   - *O que piora*: mais uma tabela e um join na resolução de escopos; contido numa
     única função de leitura (contrato `access-scopes.md`).

3. **Módulo `Tenants.Access` como ponto único do veredito de visão**
   - *Problema*: a união piso+derivado+concedido+liderança(#369) precisa de UM dono;
     espalhada por telas, a primeira divergência vira furo de acesso silencioso.
   - *Existe agora?* Sim — FR-010/011/018/022.
   - *O que piora*: `EO.Visibility.pode_ver/3` passa a ser chamada por dentro de
     `Access.pode_ver/3` (uma indireção); em troca, o motivo nomeado (FR-011) tem um
     vocabulário só.

4. **Token de sessão versionado na conta (`session_token`)**
   - *Problema*: FR-004/015 — logout e troca de senha derrubam as OUTRAS sessões; o
     cookie do Phoenix sozinho não permite invalidar à distância.
   - *Existe agora?* Sim.
   - *O que piora*: uma consulta de validação por request autenticada (já existe a de
     `fetch_user` na hook — o token entra na mesma leitura, custo zero adicional).

## Project Structure

### Documentation (this feature)

```text
specs/045-autenticacao-e-acesso/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── auth.md              # autenticação: login por identificador, senha, sessão
│   └── access-scopes.md     # escopos: resolução da união, concessão, revogação
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
lib/the_band/tenants/
├── user.ex                   # + credencial (hash), session_token, tentativas, admin?/1 mantido
├── access.ex                 # NOVO: veredito único — união de escopos + motivo nomeado
├── access/scope_grant.ex     # NOVO: schema da concessão (nível, alvo, proveniência)
└── auth.ex                   # NOVO: autenticação — identificador→conta, verificação, throttle

lib/the_band/tenants.ex       # fachada: defdelegates novos

lib/the_band_web/
├── controllers/session_controller.ex   # create por identificador+senha; delete
├── live/session_live/new.ex            # tela de login (marketing + form do protótipo)
├── live/profile_live/index.ex          # NOVO: /profile — perfil próprio
├── live/accounts_live/index.ex         # NOVO: /accounts — contas (admin): criar, reset senha
├── live/access_scopes_live/index.ex    # NOVO: /access-scopes — concessões (admin)
├── live/hooks.ex                       # current_scope valida token de sessão + expiração
└── components/layouts.ex               # Settings: Access scopes/Accounts; Operação: admin OU organization
router.ex                               # rotas novas; /syncs sai da sessão aberta p/ gating FR-023

priv/repo/migrations/
├── xxxx_users_credentials.exs          # hash, session_token, tentativas, timestamps de senha
└── xxxx_access_scope_grants.exs        # concessões

test/the_band/tenants/{auth_test,access_test}.exs
test/the_band_web/live/{login_test,profile_test,accounts_test,access_scopes_test,gating_operacional_test}.exs
```

**Structure Decision**: acesso é assunto da plataforma → mora em `tenants/`; a regra
de liderança declarada permanece na EO (`Visibility`) e é consumida, não movida.

### Busca dirigida — testes do requisito antigo (lição L71)

Invariantes que esta feature revoga, e os testes que os documentam (grep executado no
plan, como L71 manda):

| Invariante antigo | Onde está testado/escrito | Destino |
|---|---|---|
| Sign-in lista contas e entra por escolha | `session_live/new.ex` (lacuna declarada); testes que usam `log_in/2` direto na sessão | tela refeita; `log_in/2` de teste CONTINUA (atalho de teste, não de produção) — documentar no helper |
| Admin da plataforma vê tudo (decisão 2026-08-27) | `EO.Visibility` (ramo admin) e `visibilidade_test` | FR-022: ramo sai; testes mudam para "admin sem concessão não vê" |
| `member` = só consulta | `users.role` moduledoc | semântica atualizada: member = sem marca de gestão |
| Operação visível só p/ admin (046) | `layouts_nav_test` ("member não vê vestígio") | condição vira admin OU organization — teste ganha o caso organization |

## Complexity Tracking

Sem violações — tabela vazia.
