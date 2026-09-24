# Inventário do que está aberto em segurança, antes do MCP

**Data**: 2026-09-24 · **Árvore medida**: `origin/development` em `efa8c1f`, lida direto do
checkout `062-reconciliar-plano`, que difere dela **só** em `specs/062-servidor-mcp/` e
`RETOMAR.md` (`git diff --stat origin/development HEAD`). **Nada da 062 foi revisado aqui**:
o desenho dela está com outro agente de Security, em paralelo.

**A pergunta**: a pessoa mantenedora pediu *"garantir que tudo está seguro antes de fazer o
MCP"*. Este documento **não** responde "está seguro". Responde, item a item, o que os
documentos declararam, o que o código faz hoje, e o que fica entre os dois — e, para cada
aberto, se o servidor MCP o **herdaria ou ampliaria** ao reusar `:api_autenticada`,
`ApiAuth`, `ApiRateLimit`, `ApiReadLog`, `ApiAccessLog`, `AccessEvents`,
`Tenants.Access.pode_ver_equipe/3`, a base de conhecimento e os tokens da 061.

**Três achados novos**, medidos com teste temporário (rodado e removido; remoção conferida
com `test ! -f` e `git status --short` vazio). Os três ficam **sob** superfícies que o MCP vai
reusar, e por isso vêm primeiro.

---

## 0. As ferramentas, e o código de saída

Redirecionadas para arquivo e lidas depois, nunca por `| tail`.

| Comando | Código de saída | O que saiu |
|---|---:|---|
| `mix sobelow --exit low --skip` | **0** | `... SCAN COMPLETE ...`, nenhum achado |
| `mix hex.audit` | **0** | `No retired or security advisory packages found` — e **sem** o aviso de exceção obsoleta que o H11 citava |
| `mix deps.audit` | **0** | `No vulnerabilities found.` |
| `mix test` do arquivo temporário (3 medições) | **0** | `3 passed` — as saídas das medições estão na §1 |
| `mix gates` | **não rodado** | fora do pedido (o servidor dev está de pé). **Nenhum veredito de gate está sendo afirmado por este documento** |

### Que as ferramentas mediram, e não que nada apareceu

- **Sobelow**: injetado `send_file(conn, 200, arquivo)` sobre parâmetro num controller de
  mentira. Saída **1**, `Traversal.SendFile: Directory Traversal in send_file - High
  Confidence`, apontando o arquivo. Removido (`test ! -f` → `REMOVIDO`), nova varredura:
  saída **0**, zero ocorrências de `Traversal`. A ferramenta lê o que se supõe que ela lê.
- **`mix deps.audit`**: a base de avisos é o clone em
  `~/.local/share/elixir-security-advisories-mirego` — último commit **2026-09-23**, **119**
  arquivos `.yml`. Não é base vazia nem velha.
- **`mix hex.audit`**: **não provado** nesta passagem com caso positivo. É consulta à base
  do Hex; não há como plantar um aviso nela. O que se pode dizer é que o aviso de exceção
  obsoleta que ele imprimia em 2026-09-09 **desapareceu junto com a exceção** (H11) — o
  comando lê o `mix.exs`.
- **As anotações `@sobelow_skip`**: 7 em `lib/`, todas `Traversal.FileModule`, **todas com o
  motivo escrito** na linha acima da função (`github_work_items.ex:942`,
  `github_issue_comments.ex:289`, `github_branches.ex:259`, `github_projects.ex:395`,
  `github_change_requests.ex:539`, `profiles/prompt.ex:55`, `jobs/sync_github_eo.ex:722`).
- **Injeção e XSS**: `grep -rn 'fragment("' lib/ | grep '#{'` → **0**;
  `grep -rn "raw(" lib/the_band_web` fora de comentário → **0**.

---

## 1. Os três achados novos — e por que vêm antes do inventário

### N5 — `ApiAuth` não lê `tenants.status`: organização suspensa continua lendo por token

**Severidade: Alta** · OWASP A01/A07 · ASVS V4.1, V3.3 · **MEDIDO com teste**

**Onde.** `lib/the_band_web/plugs/api_auth.ex:70-81` — `com_tenant/2` confere que o tenant
existe (`Tenants.fetch/1`, `tenants.ex:72-77`, que é `Repo.get` sem filtro), que a conta dona
existe, que é do mesmo tenant, e que `User.ativa?(dono)`. **Não confere `tenant.status`.** As
três portas de sessão conferem: `auth.ex:93` e `:132-133`, `current_scope.ex:43-44` e `:58`,
`hooks.ex:29` e `:149`. É o H3-A fechado nas três portas de sessão e **aberto na quarta**, a
que a 061 acrescentou.

**A medida.** Tenant com token do admin → `GET /api/v1/people` **200**; tenant marcado
`"suspended"` com `assert suspenso.status == "suspended"` como guarda do cenário; mesmo token,
`build_conn()` novo → **`M1_STATUS_DEPOIS_DA_SUSPENSAO=200`**.

**Caminho concreto.** Quem opera suspende uma organização — o gesto que, desde o #837, derruba
sessão e recusa entrada. Toda pessoa daquela organização que tenha emitido um token continua
lendo pessoas, equipes, medidas, projetos e sincronizações pela API, até o token vencer (ou
nunca, desde a decisão de 2026-09-23 de oferecer *sem expiração* —
`docs/backlog/decisoes-da-tela-de-tokens.md`).

**Consequência para o negócio.** *"Suspendemos a organização"* deixa de ser verdade no
instante em que ela tem uma integração. É exatamente a forma do H3: a coluna volta a
**parecer** um controle.

**O que fecha.** Uma cláusula em `com_tenant/2`: `true <- tenant.status == "active"`, caindo
no `recusar(conn, :conta_dona_indisponivel)` que já existe (ou num motivo próprio de log, sem
mudar o corpo — SC-003). **Cenário para o QA**: o M1 acima, invertido — `assert` 200 antes,
`assert` 401 depois, `assert` corpo byte-idêntico ao de token inexistente, e o par com dois
tenants povoados em que o **ativo** continua 200 (senão "o suspenso não lê" passaria com a
rota quebrada nos dois).

### N6 — recusa de equipe não é registrada em lugar nenhum

**Severidade: Média** · OWASP A09 · ASVS V7.2 · **MEDIDO com teste**

**Onde.** `lib/the_band_web/controllers/api/v1/team_controller.ex:305-321` —
`com_equipe/3` recebe `{:nao, _}` de `Tenants.pode_ver_equipe/3` e responde `404` pelo
`else _ ->`, sem chamada a `AccessEvents` nem a `Logger`. `lib/the_band_web/live/teams_live/show.ex:4405`
idem na tela. `AccessEvents` (`lib/the_band/tenants/access_events.ex`) **não tem** função
para recusa de equipe — só `painel_recusado/4`, que é de pessoa. E `ApiReadLog`
(`api_read_log.ex:36`) grava **só** `status in 200..299`, com o `@moduledoc` afirmando que
*"a recusa já é registrada por `ApiAuth` e por `AccessEvents.painel_recusado/4`"* — o que é
verdade para pessoa e falso para equipe.

**A medida.** Conta `member` sem escopo, `assert {:nao, _} = pode_ver_equipe(...)` como
guarda, token dela, `GET /api/v1/teams/:id` → 404 dentro de `capture_log(level: :debug)`:
**`M3_LINHAS_API_ACCESS_LOG=0`**, **`M3_LOG_INTEIRO=""`**. **Controle positivo** na mesma
técnica: token inválido na mesma rota dentro de `capture_log` →
**`M3_CONTROLE_POSITIVO_CAPTURA=true`** (a linha `credencial recusada` apareceu). O vazio é
do código, não da captura.

**Ressalva de método.** `config/test.exs:24` fixa `level: :warning`. A ausência medida vale
para `:warning` ou acima; um `Logger.info` não apareceria no teste nem se existisse. Por
leitura, não existe: não há chamada nenhuma no ramo de recusa.

**Consequência.** A FR-024 da 045 aceitou o risco de agregação **apoiada no registro de
acesso** (`specs/045-autenticacao-e-acesso/spec.md:348-355`). Para pessoa, o apoio existe;
para equipe — cujo `/measures` traz quebra por pessoa nomeada — **não existe**. Um laço sobre
`/api/v1/teams` percorrendo ids recusados não deixa rastro nenhum.

**O que fecha.** `AccessEvents.equipe_recusada/4` (ou `painel_recusado` generalizado com a
natureza do alvo) chamada no ramo `{:nao, motivo}` de **`pode_ver_equipe/3` nos dois
chamadores** — ou, melhor, dentro de um ponto único que os dois usem, para que o terceiro
chamador (o MCP) não precise lembrar. O `@moduledoc` do `ApiReadLog` corrigido. **Cenário**:
o M3 invertido, com `assert log =~ equipe.id` e `refute` de que o log carregue o token.

### H2-R — o perfil derivado e as competências por pessoa ficam fora do veredito, na tela e na API

**Severidade: Alta** (herdada do H2, que a deu a esta mesma seção) · OWASP A01 · ASVS V4.1.3
· **MEDIDO com teste na tela; LIDO na API**

**Onde.**

- `lib/the_band_web/live/people_live/show.ex:318` carrega `perfil_atual/2` **sem** olhar
  `alcance`; a seção `id="profile"` em `:1229` **não** tem `:if={@ve_o_trabalho?}` (as de
  `:565` e `:689` têm);
- `lib/the_band_web/controllers/api/v1/person_controller.ex:343` e `:369` — `profile:`
  devolvido **sempre**; só `work:` (`:385`) segue `ve?`;
- `person_controller.ex:185` e `:281-283` — a **listagem** `/api/v1/people` traz, para cada
  pessoa da página, `competencies` com `completed_tasks` — **contagem por pessoa**, que é o
  exemplo literal de *agregado* na tabela da FR-024 (`spec.md:337`).

**A medida.** Pessoa com perfil gravado (marcas `MARCA-FORCAS-M2`, `MARCA-HABILIDADE-M2`),
conta `member` sem elo, guarda `assert {:nao, :sem_elo_declarado} = pode_ver(...)`,
`refute html =~ "Reading at a glance"` (a defesa que existe funciona) — e
**`M2_PERFIL_FORCAS_VISIVEL=true`**, **`M2_PERFIL_HABILIDADE_VISIVEL=true`**,
**`M2_SECAO_PROFILE_VISIVEL=true`**.

**Por que isto não é decisão já tomada.** A FR-024 classificou três naturezas (agregado,
atribuição, diretório) e o inventário do H2 (`2026-09-09-inventario-do-h2.md`) as distribuiu
por **rota**. O perfil não é rota — é seção — e não aparece em nenhuma das três listas. O
contrato da API (`specs/061-api-publica/contracts/api-v1-people.md:314-321`) nomeia o que fica
fora do veredito — `discussion_participation` e `changes` — e **não nomeia o perfil**; ele
ficou fora por paridade com a tela, que é exatamente o mecanismo do H2: *"um regime herdado por
omissão"*. O teste de paridade (`h2_paridade_das_rotas_test.exs:47-50`) enumera duas rotas de
ranking; seção não entra nele.

**Consequência.** Qualquer conta do tenant — e qualquer token dela — lê de qualquer pessoa o
texto que um modelo escreveu sobre forças, evolução e *"atenção"*, e a listagem entrega as
competências contadas de todas as pessoas, página a página. É a leitura mais atributiva do
produto, e a 062 existe para entregá-la **a outro modelo**, em escala.

**O que fecha — começa por decisão.** A pessoa mantenedora classifica o perfil (e as
competências derivadas dele) numa das três naturezas da FR-024, e a classificação vira texto
na FR. Se *agregado*: gatear a seção, o `profile:` do detalhe e as `competencies` da
listagem, e acrescentar **seção** ao teste de paridade. Se *não agregado*: escrever por quê, no
mesmo lugar em que `changes` está justificado. **Cenário**: o M2 invertido, mais o `assert` de
que quem alcança vê o perfil (senão o `refute` celebraria perfil ausente).

---

## 2. O inventário, item a item

**Legenda do veredito**: **fechado** = há linha de código (ou de configuração) que fecha, e
ela foi lida hoje · **parcial** = parte fechada, parte aberta, as duas nomeadas · **aberto** =
o código de hoje ainda tem o defeito · **doc. desatualizado** = o documento diz uma coisa e o
código outra.

### 2.1 Os achados de 2026-09-09 (H1–H16)

| # | Declarado | Medido hoje (arquivo:linha, comando) | Veredito |
|---|---|---|---|
| **H1** `/set-password` sem a senha atual | fechado e aceito (#835) | `session_controller.ex:104` — `true <- user.must_change_password` na cadeia do `with`; testes `login_test.exs:109` (regime normal recusado, com guarda `refute ctx.member.must_change_password`) e `:146` (o par: temporária funciona) | **fechado** |
| **H2** veredito em 2 de 26 LiveViews | decidido e fechado, aceito (#838, #845) | agregados por rota: `verification_live/people.ex` (linhas 68-83 sem comentário) e `process_live/index.ex` filtram por `Tenants.pessoas_alcancadas/2`; `change_live/commits.ex:50`; teste de paridade `h2_paridade_das_rotas_test.exs`. **Mas** a seção `#profile` e o `profile`/`competencies` da API seguem fora — ver **H2-R** | **parcial** — rotas fechadas; seção e API abertas |
| **H3-A** `tenants.status` não lido | fechado e aceito (#837) | lido em `auth.ex:93,132-133`, `current_scope.ex:43-44,58`, `hooks.ex:29,149`; teste `organizacao_suspensa_test.exs`. **Não** lido em `api_auth.ex:70-81` — **N5, medido** | **parcial** — sessão fechada, token aberto |
| **H3-B** conta desativada | fechado, **não aceito** (#844) | `auth.ex:108-110` (`:conta_desativada`), `current_scope.ex:46-47`, `hooks.ex:32,146-147`, e `api_auth.ex:74` (`User.ativa?(dono)`) — a conta desativada **não** autentica por token. Migrações `20260909180000`, `20260910050000` | **fechado no código** — aceitação: ver N3 |
| **H4** nenhum evento de acesso | fechado, **não aceito** (#849) | existem e têm chamador: `entrada_aceita` (`auth.ex:184`, com o contador de falhas **antes** de zerar — a campanha não apaga mais a evidência), `entrada_recusada` (`auth.ex:65`), `espera_acionada` (`auth.ex:151`), `painel_recusado` (`people_live/show.ex:294`, `person_controller.ex:327`), `sessao_derrubada` (`hooks.ex:69`, `current_scope.ex:82`), `ato_administrativo` (`tenants.ex:324,382` — desativar/reativar). `Logger.metadata(user_id, tenant_id)` em `current_scope.ex:69` e `hooks.ex:41`; `config/config.exs:80` publica os três. **Sem evento**: concessão e revogação de escopo (`access.ex:532,568`), elo declarado e revogado (`tenants.ex:180,237`), definição/troca/reinício de senha (`auth.ex:238,256,300`), criação e revogação de token de API (`api_tokens.ex:389`), **recusa de equipe (N6)**. `grep -rln correlation_id lib/` → **vazio** | **parcial** — 6 de 8 eventos de §H4 registrados; faltam concessão de escopo, elo e troca de senha; `correlation_id` não existe |
| **H5** sessão encerrada serve no LiveView conectado | não feito | `grep` por `send_after`, `send_interval`, `:timer.`, `attach_hook(... :handle_info ...)` em `lib/the_band_web/` → só `hooks.ex:51` (`:nav_area`, `:handle_params`) | **aberto** |
| **H6** `pode_ver_equipe` por `users.role` contra o cabeçalho | D-e decidida: **concede** | `access.ex:20-40` reescrito ("Administrar VÊ, desde 2026-09-09"); ramo em `access.ex:202-203` e `:259` com `user.tenant_id == tenant.id` | **fechado** (por decisão, com o texto alinhado — ver N1) |
| **H7** Dokploy implanta `latest` | não feito | `cd.yml:73-84` documenta a escolha **alternativa**: as duas tags continuam, e o passo `a produção confirma a versão` (`cd.yml:128-156`) **falha** o CD se `/version` não devolver a versão publicada. O Dokploy continua puxando o que a aplicação dele declara | **parcial** — o CD agora **prova** qual versão subiu; não há registro persistente do *digest* implantado, e duas releases próximas ainda correm pelo mesmo apontador (a segunda faria a primeira falhar, e não passar em silêncio) |
| **H8** ações por tag mutável; `ci.yml` sem `permissions` | não feito | `grep -n "uses:" .github/workflows/*.yml` → **todas** fixadas por SHA com a versão em comentário (`cd.yml:31,67`, `ci.yml:57-202`, `docs.yml:43,45`); `ci.yml:18-19` `permissions: contents: read`; `pr-tipo-de-merge.yml:22-24` declarado; `pull_request_target` → ausente | **fechado** — **o README do backlog está desatualizado** ("não feitos") |
| **H9** `ssl: true` do Repo comentado | pergunta para quem opera (D-f) | `config/runtime.exs:86` — `# ssl: true,` continua comentado. Nenhum registro de resposta à D-f em `docs/` (`grep -rn "D-f"` → só a pergunta no README). `2026-09-12-destino-de-backup-em-segundo-host.md:207-211` a declara **aberta** e acrescenta a segunda superfície (dump para outro host) | **aberto** — severidade ainda a determinar |
| **H10** cookie assinado, não cifrado | não feito | `endpoint.ex:7-11` — `store: :cookie`, `signing_salt`, `same_site: "Lax"`, **sem `encryption_salt`** | **aberto** |
| **H11** exceção obsoleta no `mix.exs` | — | `grep -n ignore_advisories mix.exs` → **vazio**; `mix hex.audit` saiu 0 **sem** a linha de exceção obsoleta | **fechado** |
| **H12** `deps` commitada como link simbólico | fechado (#836) | `git cat-file -t origin/development:deps` e `origin/main:deps` → `path 'deps' exists on disk, but not in ...` (ausente nos dois); gate `sem link simbólico rastreado` em `gates.ex:102,253` | **fechado** |
| **H13** `PHX_HOST` cai em `example.com` | não feito | `config/runtime.exs:105` — `System.get_env("PHX_HOST") \|\| "example.com"`, ao lado de `SECRET_KEY_BASE`, que levanta (`:98-103`) | **aberto** |
| **H14** expiração só na hook; comentário diz "inatividade" | não feito | `hooks.ex:18-19` ainda diz *"Sete dias de inatividade"*; `hooks.ex:154-156` mede desde `logged_in_at`, escrito só em `auth.ex:193`; `current_scope.ex` **não** confere validade. **Piorou na forma prevista**: há agora **duas** rotas de controller sob `:require_user` — `/profile/password` (`router.ex:231`) e **`/api/docs`** (`router.ex:157-164`, Swagger UI) —, e a segunda nasceu herdando a lacuna. Dano baixo: a UI não traz dado. E `hooks.ex:152` aceita `logged_in_at: nil` como válido sem prazo | **aberto** — o achado previu a próxima rota, e ela veio |
| **H15** `fetch_organization_by_login/2` com tenant UUID cru | não feito | `eo/queries.ex:714-720`, exposto por `eo.ex:159`; o filtro por tenant continua correto | **aberto** (desenho, sem exploração) |
| **H16** `base_url` garantido pelo chamador | não feito | `ai/provider_credential.ex:63,71` — `cast` e `validate_required`, sem allowlist; `ai.ex:26` a constante; `grep "169.254\|meta-data" test/the_band/ai_test.exs` → **vazio**: o cenário de ataque continua sem teste | **aberto** |

### 2.2 Os itens da fila de 2026-09-09 (N1–N4)

| # | Declarado | Medido hoje | Veredito |
|---|---|---|---|
| **N1** os três registros do H6 | aberto | `access.ex:20-40` diz o que o código faz; `specs/023-painel-da-pessoa/spec.md:273-281` tem a nota de revogação e restauração da FR-012j; `specs/045-autenticacao-e-acesso/spec.md:103` e `:410` tachados com a emenda. A frase *"being an administrator … does not open panels"* só sobrevive em **comentário** (`commits.ex:37`, `access.ex:245`), como citação histórica, não na tela | **fechado** — o README não foi atualizado |
| **N2** as duas chamadas que faltavam ao H4 | aberto | `painel_recusado/4` tem **3** chamadores (tela, API, e a menção em `api_read_log.ex:15` é prosa); `espera_acionada/3` tem 1 (`auth.ex:151`). **Mas** a chamada ficou nos **chamadores** de `pode_ver/3`, e não em `Access` como o N2 pedia — e o terceiro veredito, `pode_ver_equipe/3`, **não registra recusa em lugar nenhum** (N6) | **parcial** — o que o N2 nomeou foi feito; a forma escolhida deixa o próximo chamador sem registro, e o próximo é o MCP |
| **N3** o que faltava à conta desativada | aberto | razão ao desativar e ao reativar (`tenants.ex:295,363`, `enable_user/4` com ator e razão); vocabulário em `priv/knowledge_base/rules/access_account_lifecycle.yaml`; episódio próprio (`20260910050000_episodio_de_desativacao.exs`); texto do *revoke* em dois lugares (`accounts_live/index.ex:867` e `:1492`, *"Does not remove access"*); os dois testes nomeados em `test/the_band/tenants/conta_desativada_test.exs` | **fechado no código**; a **reclassificação do D06** (não aceito na v0.7.0) **não tem registro** em nenhum `docs/releases/*.md` — é ato do Product Owner, pendente |
| **N4** `/deps/` não ignora link | aberto | `.gitignore:19` — `/deps`; `git check-ignore -v deps` → `.gitignore:19:/deps  deps`, **saída 0** | **fechado** — o README não foi atualizado |

### 2.3 A spec 064 — segredo em repouso

`specs/064-segredo-em-repouso/tasks.md`: **19 tarefas, 0 marcadas**. Conferido no código se
alguma foi feita sem marcar — **nenhuma foi**, com uma exceção anterior à própria lista.

| História | Declarado | Medido hoje | Veredito |
|---|---|---|---|
| **US1** nenhum segredo em claro chega a backup (T001–T005) | aberta | `ls lib/mix/tasks/` → nenhuma tarefa de varredura; nenhum módulo de padrões de segredo em `lib/`. A varredura de 2026-09-12 foi **ato manual**, provada com caso positivo, e não é repetível por comando | **aberto** |
| **US2** `session_token` legível no banco (T009–T014) | aberta | `tenants/user.ex:64` — `field :session_token, :string, redact: true`; nenhuma migração de tabela de sessões nem de época de senha (`ls priv/repo/migrations \| grep -i "sess\|epoca\|epoch"` → vazio) | **aberto** |
| **US3** segredo nunca chega a log/erro (T006–T008) | aberta, com o caminho do GitHub já feito | `TheBand.Segredo` (`lib/the_band/segredo.ex`) usado no caminho do GitHub: `sources.ex:132,424,478,495`, `integrations/github/http/req.ex:46` (`Segredo.expor/1` só no cabeçalho). **Caminho do modelo continua nu**: `integrations/llm/http/req.ex:24` — `chave = opts[:key] \|\| System.get_env("API_KEY")`, binário passado a `chamar/5`. **E o token da 061** chega nu a `Tenants.authenticate_api_token(valor)` (`api_auth.ex:41-49`) — é o mesmo mecanismo de quadro de pilha, não medido aqui. T007/T008 (datas de encerramento do Oban): nenhuma linha em `lib/` | **parcial** — GitHub fechado; modelo e token de API abertos |
| **FR-016–019** idade da credencial (T017–T019) | aberta | nenhum campo de data de troca em `integrations/`, `ai/`, `sources.ex` | **aberto** |

### 2.4 As credenciais expostas — ato de operação, não de código

| Item | Declarado | Medido | Veredito |
|---|---|---|---|
| **token do GitHub em claro em `oban_jobs.errors`** (2026-09-04 a 09-12) | rotação **adiada para 2026-10-12** por decisão da pessoa mantenedora, com risco declarado (`docs/backlog/rotacionar-o-token-que-vazou.md:50-51`) | a linha foi redigida em 09-12; a rotação é no GitHub e **não é verificável daqui** | **aberto, aceito com prazo** — 18 dias para o prazo |
| **token de produção da API que passou por proxy que intercepta TLS** | *"por revogar"* (`docs/releases/v0.9.1.md:417`), *"trate como vazado"* (`RETOMAR.md:116-117`) | **não medido**: verificar exigiria ler a base de produção, e este papel não usa produção para confirmar achado | ~~aberto~~ **fechado em 2026-09-24**: revogado pela pessoa mantenedora, declarado e não medido (SC-003 torna revogado indistinguível de inexistente). Fica: conferir no painel de uso se leu algo depois das medições |

---

## 3. Em relação à 062 — o que bloqueia e o que é independente

**Critério**: *bloqueia* quando o MCP, ao reusar a peça, **herdaria** o defeito sem que nada
acuse, ou o **ampliaria** — mais consumidores, consumidor automático, mais volume. A
classificação é recomendação; a prioridade é do Product Owner.

| Item | Classificação | Por quê, em uma frase |
|---|---|---|
| **N5** — token de organização suspensa autentica | **bloqueia** | o MCP autentica por `ApiAuth`; sem a cláusula, suspender a organização não desliga o agente dela — e o agente é justamente a integração que ninguém lembra de desligar |
| **N6** — recusa de equipe sem registro | **bloqueia** | o MCP vai chamar `pode_ver_equipe/3`, e um agente que itera sobre ids recusados é o padrão de agregação que a FR-024 só aceitou **porque** haveria registro |
| **N2** — o registro de recusa mora no chamador | **bloqueia** (é o mesmo defeito do N6, visto pela forma) | cada chamador novo de `pode_ver/3` precisa lembrar de chamar `painel_recusado/4`, e o MCP é o terceiro; enquanto a recusa não for registrada num ponto único, o registro depende da memória de quem escreve a 062 |
| **H2-R** — perfil e competências fora do veredito | **bloqueia** (pela decisão, não pelo código) | a 062 existe para servir a outro modelo exatamente o texto derivado que hoje nenhuma natureza da FR-024 classifica; publicar antes da decisão congela por omissão o regime que o H2 já mostrou ser o defeito |
| **token de produção pelo proxy TLS** | **bloqueia** (ato de operação) | tokens da 061 são os tokens do MCP; uma credencial tratada como vazada ganharia a superfície nova no dia em que ela subir, e revogá-la custa um clique |
| **US3 da 064** — segredo nu em argumento | **independente, com uma condição** | o caminho de hoje não muda com o MCP; mas se o desenho da 062 guardar o valor do token em processo de longa duração (sessão de transporte), o valor entra em estado de processo e relatório de falha — a condição é o desenho não introduzir esse caminho, e ela é do agente que revisa a 062 |
| **H4 restante** — escopo, elo, senha, token sem evento; sem `correlation_id` | **independente** | o MCP lê; esses eventos são de administração e de sessão — faltam para investigar, mas o MCP não os torna mais faltantes |
| **H5** — LiveView conectado | **independente** | o MCP autentica por token a cada chamada, não por socket de LiveView |
| **H10, H13, H14** — cookie, `PHX_HOST`, expiração de sessão | **independente** | são da sessão de navegador; o MCP não usa cookie (H13 só o alcançaria se a 062 derivar origem ou URL de `PHX_HOST`) |
| **H7** — identidade da imagem | **independente** | afeta a auditoria de qualquer release igualmente |
| **H9** — TLS até a base | **independente** | o MCP não abre conexão nova com a base; o volume a mais atravessa o mesmo canal |
| **H15** — tenant como UUID cru | **independente** | a regra que a 062 precisa seguir é a que a API já segue — tenant da **linha do token** (`api_auth.ex:68-71`), nunca de parâmetro |
| **H16** — `base_url` do modelo | **independente** | o MCP não grava credencial de modelo |
| **US1, US2, FR-016–019 da 064** | **independente** | backup, `session_token` e idade de credencial de terceiro não passam pelo MCP; o token da 061 já é guardado como SHA-256 e conferido com `secure_compare` (`api_tokens.ex:204,272,336-337`) |
| **token do GitHub por rotacionar** | **independente** | é credencial de coleta, não de leitura; o MCP não a toca |
| **N3 / D06** — reclassificação | **independente** | é registro de aceitação; o controle está no código, inclusive no caminho por token |

**Em resumo**: cinco itens bloqueiam, e **três deles fecham com poucas linhas** — uma
cláusula em `com_tenant/2` (N5), um evento e um ponto único de registro de recusa (N6/N2), e
um clique para revogar o token exposto. O quarto (H2-R) é uma decisão de produto antes de
qualquer código.

---

## 4. O que está desatualizado nos documentos

Registrado para quem ler a fila de `docs/backlog/README.md:73-93` como estado atual — ela
**não é**:

- **H8** consta *"não feitos"* — está **fechado** (SHA em todas as ações, `permissions` no
  `ci.yml`);
- **H7** consta *"não feitos"* — está **parcial** (verificação de versão no CD);
- **N1** e **N4** constam como itens novos abertos — estão **fechados** no código;
- **N2** consta como *"duas funções escritas e nunca chamadas"* — as duas têm chamador hoje;
- o `@moduledoc` de `lib/the_band_web/plugs/api_read_log.ex:15` afirma que *"a recusa já é
  registrada por `ApiAuth` e por `AccessEvents.painel_recusado/4`"* — verdade para pessoa,
  **falso para equipe** (N6);
- o comentário de `hooks.ex:18` continua dizendo *"inatividade"* (H14).

---

## 5. O que NÃO verifiquei

Esta seção é resultado. Sem ela, o documento seria lido como *"o resto está seguro"*.

1. **`mix gates`** — não rodado, por pedido. **Nenhum veredito de gate é afirmado aqui.**
2. **O desenho da 062** — deliberadamente fora; está com outro agente. A §3 classifica o que o
   MCP **herdaria das peças existentes**, não o que ele acrescentaria.
3. **Produção** — nada foi lido de lá: nem se o token do proxy foi revogado, nem se o do GitHub
   foi rotacionado, nem quantos tenants estão `suspended` (o que muda a urgência do N5), nem a
   topologia do banco (H9), nem se a porta HTTP da aplicação é alcançável fora do proxy (o
   `rewrite_on: [:x_forwarded_proto]` confia em quem chega).
4. **O H2-R na API** — **lido**, não medido. A medida foi na tela; que `profile:` e
   `competencies` saem para token sem alcance vem de `person_controller.ex:185,343,369`.
5. **O mecanismo de quadro de pilha para o token da 061** (US3) — **não reproduzido**. Afirmo
   que o valor passa nu por `api_auth.ex:41-49`; não afirmo que ele chega a um log.
6. **`ApiRateLimit` sob o MCP** — o limitador conta **requisições por token**
   (`api_rate_limit.ex`, ETS por nó). Se o transporte do MCP carregar várias chamadas numa
   requisição, o limite mede outra coisa. É pergunta de desenho da 062, e deixo nomeada para
   quem a revisa.
7. **As 20+ rotas de `:autenticado` uma a uma, quanto a seção** — o H2-R foi achado lendo
   `people_live/show.ex`; as outras telas não foram relidas procurando **seção** com agregado
   fora do veredito. O inventário do H2 foi feito por **rota**, e o H2-R mostra que isso é
   piso.
8. **H5 com teste** — o veredito "aberto" vem do `grep` por revalidação, não de uma medida com
   `view` conectado.
9. **`mix hex.audit` com caso positivo** — não há como plantar aviso na base do Hex.
10. **Os documentos de 2026-09-12 e 2026-09-13 sobre backup** (`destino-de-backup-em-segundo-host`,
    `dump-varrido-e-restaurado`, `o-caminho-completo-do-backup`) e o
    `2026-09-09-api-com-token.md` — lidos só onde citam H9, H4 ou a 064; os achados próprios
    deles **não** foram inventariados um a um.
11. **Exportação, telemetria e serialização à mão** de struct com segredo — continua aberto
    desde o item 7 da §7 de 2026-09-09.
12. **Se H1, H2, H3 ou o N5 já foram explorados** — o H4 parcial agora permitiria responder
    para entrada e painel de pessoa **daqui em diante**; para equipe, escopo e o período antes
    do #849, não há como.

---

## Referências

`docs/seguranca/2026-09-09-o-que-consertar-agora.md` (H1–H16) ·
`docs/seguranca/2026-09-09-inventario-do-h2.md` · `docs/backlog/README.md:66-101` (a tabela
da v0.7.0 e N1–N4) · `docs/backlog/conta-desativada.md` · `docs/backlog/rotacionar-o-token-que-vazou.md`
· `docs/backlog/plano-de-correcoes-da-api.md` · `docs/releases/v0.9.1.md:405-425` ·
`specs/045-autenticacao-e-acesso/spec.md` (FR-022, FR-024) · `specs/061-api-publica/contracts/api-v1-people.md`
· `specs/064-segredo-em-repouso/` · constituição, princípios V, VII, VIII, XI · `AGENTS.md` §14,
§15, §17 · OWASP Top 10 (2021) A01, A02, A05, A06, A07, A08, A09, A10 · OWASP ASVS V2, V3,
V4, V7, V9, V10, V14.
