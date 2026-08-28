# Research — Autenticação e papel de acesso (045)

## R1 — Hash de senha: bcrypt_elixir

**Decision**: `bcrypt_elixir` (Comeonin), custo padrão 12.

**Rationale**: FR-003 exige irreversível. É a escolha do `phx.gen.auth` — manutenção
ativa, auditada, sem dependência de serviço externo. O custo (~100ms/verificação) é
desejado: é o que torna força-bruta cara, e conversa com a espera crescente de FR-016.

**Alternatives considered**: `argon2_elixir` — mais forte em teoria, build mais pesado
e sem ganho prático no perfil desta plataforma (interna, com throttle); rejeitado.
Pbkdf2 puro-Elixir — mais fraco por padrão; rejeitado.

## R2 — Sessão: cookie assinado + token versionado na conta

**Decision**: manter a sessão de cookie do Phoenix (`user_id`) e acrescentar
`session_token` (aleatório, 32 bytes) gravado na conta e carregado na sessão. A hook
`current_scope` valida `user_id` + token + expiração (`logged_in_at` + 7 dias, FR-016
das Assumptions). Trocar senha/logout global gira o token — as outras sessões caem na
próxima ação (FR-015). Logout local: `configure_session(drop: true)` como hoje.

**Rationale**: o cookie sozinho não invalida à distância; token na conta invalida
todas de uma vez, na MESMA consulta que a hook já faz (`fetch_user`). Tabela de
sessões daria logout seletivo — problema que ninguém tem (princípio VIII).

**Alternatives considered**: Phoenix.Token com TTL — expira, mas não revoga na troca
de senha sem lista de revogação; rejeitado. Tabela `sessions` — estrutura sem
problema atual; rejeitado.

## R3 — Identificador de login: e-mail sempre; usuário do GitHub pelo elo vigente

**Decision**: `Auth.authenticate(identificador, senha)` resolve em duas etapas:
(1) e-mail exato em `users` (case-insensitive, único global); (2) senão,
`eo_people.login` == identificador → contas com elo vigente para essa pessoa
(`users.person_id`, `person_revoked_at IS NULL`). Zero ou mais de uma conta → recusa
com a MESMA mensagem (FR-002/019). A verificação de senha roda SEMPRE (hash dummy
quando não há conta) para não vazar existência por tempo de resposta.

**Rationale**: FR-019 — o elo é declarado e revogável; nenhuma coluna nova. Ambiguidade
(mesma pessoa em dois tenants) não identifica: e-mail resolve.

**Alternatives considered**: coluna `github_login` em users — segunda fonte da mesma
verdade, diverge da coleta; rejeitado (a spec já o proíbe).

## R4 — Espera crescente (FR-016): contador na conta

**Decision**: `failed_attempts` + `last_failed_at` em `users`. Recusa quando
`now < last_failed_at + min(2^(attempts-3), 60)s` (3 tentativas livres; depois 2, 4,
8… até teto de 60s), com a mensagem única. Sucesso zera. Identificador inexistente não
grava nada (não há conta) — o hash dummy de R3 já iguala o tempo.

**Rationale**: por conta e por banco: sobrevive a deploy, vale em cluster, testável.
Sem bloqueio permanente (a spec proíbe). ETS morreria no restart (lição da casa sobre
estado em processo).

**Alternatives considered**: plug de rate-limit por IP — NAT pune inocentes e não
protege contra alvo único distribuído; rejeitado como mecanismo único.

## R5 — Escopos: concessão em tabela própria; derivado é leitura

**Decision**: tabela `access_scope_grants` (tenant, user, level ∈ team|project|
organization, target_id, granted_by, granted_at, revoked_by, revoked_at). Derivados
NÃO se gravam: `Access.scopes(tenant, user)` compõe piso (elo vigente) + derivados
(vínculos/alocações vigentes da pessoa, via EO/Projects) + concessões vigentes, e
devolve a lista com a ORIGEM de cada um (`:floor`, `:derived_team`, `:derived_project`,
`:granted`). A tela pinta hachura pelo campo origem — derivado se declara.

**Rationale**: FR-020/021 — derivado nasce e morre com o fato; gravá-lo criaria
segunda verdade que dessincroniza. Concessão precisa de proveniência e revogação com
marca (III).

**Alternatives considered**: materializar derivados com job — sincronização eterna;
rejeitado. Colunas em users — não acumula N escopos; rejeitado.

## R6 — Alvo do derivado project: a cadeia declarada pessoa→equipe→projeto

**Decision**: escopo project derivado nasce da cadeia **declarada**:
`eo_team_memberships` vigente (pessoa→equipe) × `spo_project_teams` vigente
(equipe→projeto declarado, com `linked_by/linked_at/unlinked_at`). Alvo = o projeto
declarado da SPO (`spo_projects`), não o quadro observado.

**Medido no banco dev antes de decidir** (regra da casa): não existe tabela de
alocação direta pessoa→projeto; existem 5 projetos declarados e **3 vínculos
projeto↔equipe vigentes** em `spo_project_teams` — a cadeia já carrega proveniência e
revogação (`unlinked_at`), exatamente o padrão que FR-020 pede ("fecha com o fato").

**Rationale**: a spec diz "alocada ao projeto" — a alocação declarada que existe é a
da equipe ao projeto, e a pessoa chega por vínculo vigente. Inferir de issue atribuída
("trabalhou lá") daria escopo por atividade passada — inferência que a casa proíbe
(mesma família de "não infere liderança por nome"); rejeitado.

**Alternatives considered**: derivação vazia até existir alocação pessoa→projeto —
desnecessária: a cadeia declarada existe e tem 3 casos reais; rejeitado. Inferir de
`observed_projects`/issues — inferência; rejeitado.

## R7 — FR-022/018: rework do veredito de visão

**Decision**: `Access.pode_ver(tenant, user, person_id)` devolve `{:ok, motivo}` /
`{:nao, motivo}` (mesmo formato do Visibility): 1º piso (é a própria pessoa via elo);
2º derivados/concessões (team da pessoa-alvo ∩ escopos team; projeto idem;
organization da pessoa-alvo ∈ escopos organization); 3º delega a
`EO.Visibility.pode_ver/3` para a liderança declarada (#369, FR-018). O ramo "admin
vê tudo" SAI do Visibility (FR-022) — a migração dá aos admins concessão organization
de cada organização observada do tenant, então ninguém perde visão na virada.

**Rationale**: soma, nunca subtrai (FR-018); motivo específico por ramo (FR-011);
decisão 2026-08-27 revista com o vocabulário que faltava — registrado na spec.

## R8 — FR-023 nas telas operacionais: gating por rota + filtragem por organização

**Decision**: novo mount hook `require_operacao` (admin OU concessão organization
vigente) para /syncs, /tools, /ai, /profiles; /accounts e /access-scopes ficam em
`require_admin`. Para organization (não admin), as telas operacionais filtram pelo
conjunto de organizações concedidas: Syncs/Tools já são por ferramenta conectada, e
ferramenta carrega `organization_login` — o filtro é `organization_login ∈ logins das
organizações concedidas`. Menu (046) muda a condição num ponto só, como o plan da 046
previu.

**Rationale**: FR-023 pede "vê e opera o que pertence à organização-alvo"; a corrente
tool→organization_login já existe (usada na 046).

## R9 — Migração de dados: sem rebaixamento silencioso

**Decision**: migração 2 (grants) semeia, para cada `users.role == "admin"`, uma
concessão organization por organização observada do tenant, `granted_by` = a própria
conta, `granted_at` = data da migração, e um comentário na migração dizendo por quê.
Contas sem senha: `password_hash` NULL — o login recusa com a mensagem única e a tela
orienta procurar quem administra (FR-014); NENHUMA senha é semeada.

**Rationale**: assumption da spec ("virada não rebaixa ninguém em silêncio");
credenciais nunca no repositório (memória da casa).

## R10 — Login de teste continua por atalho de sessão

**Decision**: o helper `log_in/2` dos testes (init_test_session com user_id) continua
— com o token de sessão do usuário incluído. Não passa pelo formulário: os testes de
autenticação exercitam o formulário; o resto dos testes não paga bcrypt por setup.

**Rationale**: custo de hash em ~1.400 testes seria minutos de suíte por nada;
o caminho de produção tem testes próprios (violação primeiro).
