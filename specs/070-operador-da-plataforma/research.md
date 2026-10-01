# Research — 070, o operador da plataforma

**Data**: 2026-10-01 · **Papel**: Software Architect · **Base lida**: worktree da 070 em `814ae5b`
(sobre `44fcc3d` de `development`), mais o commit `103d59e` da branch `fix/1033-suspensa-nao-trabalha`.

Tudo aqui veio de **leitura de código** ou de consulta ao GitHub, e cada afirmação diz onde. Nada
foi medido em banco nem em produção nesta passagem. Onde algo não foi verificado, está escrito.

---

## R0 — Os fatos de partida, conferidos

| fato | onde | conferido como |
|---|---|---|
| hash de senha da casa é **Bcrypt**, `bcrypt_elixir 3.3.2` sobre `comeonin 5.5.1` | `mix.lock:3`, `:9`; `mix.exs:148` | leitura |
| custo baixo só em teste (`log_rounds: 4`) | `config/test.exs:80-82` | leitura |
| política de senha: 12 a 128 caracteres | `lib/the_band/tenants/user.ex:200` | leitura |
| espera crescente: 3 livres, depois 2^(n-2) s até 60 s, por conta, no banco | `lib/the_band/tenants/auth.ex:36-37`, `:137-165` | leitura |
| tempo constante: `Bcrypt.no_user_verify/0` quando não há conta ou a recusa é de estado | `auth.ex:46-49`, `:94-96`, `:109-111` | leitura |
| sessão: 32 bytes, banco guarda `sha256`, busca por chave primária, `secure_compare` em memória, 7 dias por sessão, retenção de 90 dias | `lib/the_band/tenants/sessions.ex:10-14`, `:37-43`, `:190-205` | leitura |
| não há função que encerre as sessões **de uma organização**: só `encerrar/1`, `encerrar_da_conta/2` e `girar_todas/0` | `sessions.ex:118-184` | leitura |
| `user_sessions` tem índice em `tenant_id` | `priv/repo/migrations/20260929100000_sessoes_de_usuario.exs:54` | leitura |
| o cookie de sessão é um só (`Plug.Session`, assinado), `Secure` vem de `:cookie_de_sessao_seguro` | `lib/the_band_web/endpoint.ex:7-13`, `config/prod.exs:31` | leitura |
| o socket do LiveView recebe **só** a sessão do `Plug.Session`: `connect_info` aceita `:peer_data`, `:trace_context_headers`, `:x_headers`, `:user_agent`, `:sec_websocket_headers`, `:uri` ou `{:session, config}`, e não cookies arbitrários | `deps/phoenix/lib/phoenix/socket/transport.ex:278-286` (Phoenix 1.8.11, `mix.lock:47`), lido no checkout principal | leitura da dependência |
| sair (`DELETE /session`) faz `configure_session(drop: true)`, que apaga o cookie **inteiro** | `lib/the_band_web/controllers/session_controller.ex:43-49` | leitura |
| a hook de domínio confere a sessão **só no `mount`**; nenhum `attach_hook` em `handle_event`, e não existe `live_socket_id` em `lib/` | `lib/the_band_web/live/hooks.ex:22-60`; `grep live_socket_id` vazio | leitura, **não medido** |
| `Tenant.changeset/2` faz `cast` de `:status`, sem `validate_inclusion`; `create_tenant/1` passa `attrs` direto a ele | `lib/the_band/tenants/tenant.ex:22`, `:31`; `lib/the_band/tenants.ex:83-85` | leitura |
| nenhum chamador em `lib/` passa `status`: o bootstrap passa só nome e slug | `lib/the_band/tenants/bootstrap.ex:155` | `grep` |
| dois testes escrevem o estado direto: um pelo changeset, outro por `update_all` | `test/the_band/tenants/organizacao_suspensa_test.exs:44`; `test/the_band_web/api/organizacao_suspensa_test.exs:52`; e o teste novo da #1033 (`103d59e`, `organizacao_inativa_test.exs`) por `update_all` | `grep` |
| revogar token exige `revoked_by_user_id` (FK para `users`) e cláusula da lista fechada | `lib/the_band/tenants/schemas/api_access_token.ex:107-116`; `migrations/20260918140000_tokens_de_api.exs:72`; regra em `priv/knowledge_base/rules/api_access_thresholds.yaml:70-105` | leitura |
| revogação com a condição no `WHERE` (`is_nil(revoked_at)`) | `lib/the_band/tenants/api_tokens.ex:408-430` | leitura |
| `AccessEvents` pega o **ator** do `Logger.metadata`, e o formatador só imprime `:request_id`, `:tenant_id`, `:user_id` | `lib/the_band/tenants/access_events.ex:142-155`; `config/config.exs:79-80` | leitura |
| episódio de desativação: abre/fecha, razão de lista fechada na base, índice único parcial do aberto, `not_recorded` para o passado | `lib/the_band/tenants/account_disablement.ex`; `lib/the_band/tenants/account_lifecycle.ex`; `priv/knowledge_base/rules/access_account_lifecycle.yaml`; `migrations/20260910050000_episodio_de_desativacao.exs:71-105` | leitura |
| regras da base (`derivation_rule:`) **não têm schema em `schemas/`**; o validador confere id, duplicidade e `provenance.source_type` | `lib/the_band/ontology/yaml_validator.ex:476-481`; `ls priv/knowledge_base/schemas` | leitura |
| **nenhuma migração do repositório usa trigger nem `REVOKE`**; append-only é por ausência de função de apagar, `on_delete: :restrict` e índice parcial | `grep -i "create trigger\|revoke "` em `priv/repo/migrations` vazio; `20260810230000_create_tool_observation_events.exs:3-7` | `grep` |
| `/organizations` já é a tela de organizações do EO | `lib/the_band_web/router.ex:231` | leitura |
| não há rota sob `/platform` | `router.ex` inteiro | leitura |
| o repositório é **público** | `gh repo view --json visibility` → `PUBLIC` | consulta |
| `Tenants.ensure_active/1` existe **só na branch da #1033** (`tenants.ex:88-90` em `103d59e`); o PR #1038 está **aberto**, não mergeado | `gh pr view 1038` → `OPEN`, `mergedAt: null` | consulta |
| #1034 (O5) e #1035 (O15) estão abertas; #879 (064/T014, remove a coluna antiga) está aberta | `gh issue view` | consulta |

---

## R1 — Como o operador recebe a credencial (O4, O11)

**Decisão**: o comando de release **cria o operador sem senha** e imprime **um código de
definição de uso único, válido por 30 minutos**. O banco guarda só o `sha256` do código. O operador
abre `/platform/setup` no navegador e digita e-mail, código e a senha nova num formulário `POST`.
A senha **nunca existe fora do navegador do operador**, e o código nunca vai para URL.

```
/app/bin/the_band eval 'TheBand.Release.conceder_operador("ana@exemplo.org", "Ana", "Paulo, pelo Dokploy")'
operador concedido: ana@exemplo.org.
código de definição (vale 30 min, uma vez): 7k2m…  — abrir /platform/setup
```

**Razão**:

- **Nada secreto em argumento** (O11): o comando recebe e-mail, nome e o autor declarado. O
  histórico do shell, o `ps` e o terminal do Dokploy veem só isso.
- **O código é credencial curta, não senha**: 30 minutos, uma vez, e vira lixo assim que a senha é
  definida. A senha de verdade, que dura, ninguém além do operador viu.
- **Código no corpo de um `POST`, e não no caminho**: um link `/platform/setup/<token>` deixaria o
  token no log de acesso, no histórico do navegador e no `Referer`.
- **20 bytes aleatórios em base32 minúscula** (32 caracteres), na forma de
  `auth.ex:344-346`. **SHA-256 e não bcrypt**, pela mesma razão de `sessions.ex:10-14`: 160 bits
  não têm dicionário, e o bcrypt só acrescentaria latência.
- **Reiniciar a credencial é o mesmo caminho**: `Release.reiniciar_credencial_do_operador/2`
  emite código novo, invalida o anterior, apaga o `password_hash` e encerra as sessões do operador
  na mesma transação.

**Alternativas consideradas**:

| alternativa | por que não |
|---|---|
| senha por argumento do comando | é exatamente o que a O11 proíbe: histórico do shell, terminal do Dokploy, `ps` |
| senha por variável de ambiente, como a primeira conta da 052 (`release.ex:56-91`) | a variável fica **para sempre** na configuração do Dokploy, no `docker inspect` e no `/proc/1/environ`. Para a primeira conta isso é aceitável porque ela troca a senha no primeiro acesso; aqui seria a credencial da conta mais poderosa, legível por quem abre a tela de variáveis |
| temporária com `must_change_password`, como `Auth.gravar_temporaria/3` | a temporária é uma **senha**: quem a lê no terminal entra. O código de definição não entra em nada; só permite **definir** a senha, e usá-lo antes do operador é visível (o operador encontra o código consumido) |
| pedir a senha por `IO.gets` no `eval` | o `eval` no terminal web do Dokploy não é interativo garantidamente (**não verificado**), e a senha passaria pelo terminal de quem opera o servidor, que não é o operador |
| link mágico por e-mail | acrescenta dependência de entrega de e-mail e põe a segurança da conta mais poderosa na caixa de e-mail. Sem problema que o exija hoje (princípio VIII) |

**O que piora**: o código aparece **uma vez** na saída do terminal do Dokploy. Se o Dokploy guarda
essa saída, ela fica lá — **não verificado**. A mitigação é a validade de 30 minutos e o uso único;
quem rodou o comando já tem `THE_BAND_MASTER_KEY` e o banco, então o código não lhe dá poder novo
(seguranca.md §5). Fica declarado como risco residual.

---

## R2 — A segunda autenticação: armazenamento, tentativas e mensagem

**Decisão**: `TheBand.Platform.Credentials` reaproveita **as decisões** de `TheBand.Tenants.Auth`,
e não o módulo:

| decisão | origem | como entra aqui |
|---|---|---|
| Bcrypt, `hash_pwd_salt/1` e `verify_pass/2` | `user.ex:211`; `auth.ex:120` | igual |
| 12 a 128 caracteres | `user.ex:200` | igual |
| tempo constante com `Bcrypt.no_user_verify/0` | `auth.ex:46-49` | igual, inclusive para operador sem concessão vigente e sem senha definida |
| mensagem única | `session_controller.ex:24` | a mesma frase, `"Credenciais inválidas."` |
| espera crescente, 3 livres, teto de 60 s, no banco, sem bloqueio | `auth.ex:137-165` | as mesmas constantes, nas colunas `failed_attempts` e `last_failed_at` de `platform_operators` |
| o sucesso registra quantas falhas apagou | `auth.ex:176-195`; `access_events.ex:58-68` | igual, em evento de operador |
| época de senha contra a corrida de S2 | `sessions.ex:48-56`; `user.ex:221-233` | `platform_operators.password_epoch` |

**Por que duplicar e não extrair**: é a **segunda** ocorrência, e a regra é "duplicar uma vez é
barato" (`AGENTS.md` §7.7; constituição VIII). Extrair agora criaria uma abstração sobre `%User{}`
e `%Operator{}` com duas cabeças, e o que se queria era que **nenhuma função de domínio** casasse
`%Operator{}` (seguranca.md §3, coluna B). A duplicação é de cerca de trinta linhas, e cada cópia
leva comentário apontando para a outra.

**O que piora**: duas implementações da mesma política podem divergir. O teste de paridade de
`quickstart.md` §3 afirma as mesmas constantes nas duas.

**Emenda de 2026-10-01** (seguranca-autenticacao.md, A1 e A3): a cópia **não** reaproveita as
decisões de `auth.ex` como estão hoje, porque duas delas são defeito. A tentativa é serializada por
`FOR UPDATE` (A1, issue #1046, PR #1048) e a espera paga o custo do hash (A3, issue #1047). A cópia
nasce da versão corrigida, e o teste de paridade compara as duas depois das correções.

**Entra o segundo fator** (decisão de 2026-10-01, FR-016). Desenho em R13.

---

## R3 — Sessão do operador: tabela, cookie e LiveView

### R3.1 A tabela

**Decisão**: `platform_operator_sessions`, na forma de `user_sessions`: 32 bytes, `sha256` no
banco, busca pela chave primária, `secure_compare` em memória, `ended_at` desde o primeiro dia,
época na linha. Diferenças, cada uma com razão:

- **validade de 8 horas**, absoluta, e não 7 dias. É a conta mais poderosa da instalação, são uma
  ou duas pessoas, e entrar de novo custa um formulário. Constante nomeada, com o motivo escrito
  (antipadrão "número mágico");
- **a conferência exige concessão vigente**, na mesma consulta. Revogar o papel derruba a sessão
  mesmo que o `ended_at` falhe em ser gravado (defesa em profundidade da FR-014);
- **retenção de 90 dias**, apagada pelo mesmo job `TheBand.Jobs.ApagaSessoesAntigas`
  (`config/config.exs:120`), que ganha uma chamada. Um worker novo teria de entrar na
  classificação de `organizacao_inativa_test.exs` da #1033, e não há razão para dois jobs.

### R3.2 O cookie — a decisão que muda uma palavra da FR-011

**Fato** (R0): o socket do LiveView só recebe a sessão do `Plug.Session`. Um cookie com nome
próprio **não chega** ao `mount` conectado, e a hook não conseguiria conferi-lo. As duas formas
possíveis:

| | **(a) cookie próprio, telas por controller** | **(b) chaves próprias dentro do cookie da sessão, telas LiveView** |
|---|---|---|
| nome | `_the_band_operator`, `encrypt: true`, `http_only`, `secure` de `:cookie_de_sessao_seguro`, `same_site: "Strict"`, **`path: "/platform"`** | `"operator_session_id"` e `"operator_session_secret"` dentro de `_the_band_key` |
| o cookie chega às rotas de domínio? | **não**: o navegador só o envia sob `/platform` | **sim**, em toda requisição e em todo socket de domínio; o leitor de domínio só não o lê |
| sair de uma conta de organização derruba o operador? | não | **sim**: `configure_session(drop: true)` apaga o cookie inteiro (`session_controller.ex:46`) |
| O6, revogação com tela aberta | trivial: não há socket; toda ação é um `POST` que passa pelo plug | exige a conferência dentro da função (que existe de todo jeito, FR-014) e o fechamento do socket |
| `live_session` própria | não existe; a área tem **pipeline, plug e controller** próprios | existe |
| o que piora | recarga de página por ação; sem atualização ao vivo, irrelevante para uma lista de organizações e duas pessoas | o cookie do operador viaja junto do domínio; o acoplamento ao `drop` da saída |

**Decisão do plano: (a)**, porque isola mais e fecha a O6 sem mecanismo novo. **Emenda A8**: o
cookie não chega ao domínio **pela rede**; contra script da mesma origem, o isolamento é a CSP
(`script-src 'self'` sem `'unsafe-inline'`). Decisão da pessoa mantenedora em 2026-10-01: mesma
origem com CSP, e host próprio quando `theband.dev` entrar em produção. **Ela troca o "`live_session`" da FR-011 por controller**, e isso é decisão da
pessoa mantenedora: é a pergunta 1 do plano. Se a resposta for (b), mudam o roteador, o leitor e as
telas; o modelo de dados e os contratos de domínio **não mudam**.

**Cifrado e não só assinado**: o cookie é novo, e `encrypt: true` não custa nada. O de domínio é só
assinado (`sessao.ex:16-17`), e mudá-lo não é desta feature.

**`SameSite=Strict`**: link vindo de outro site chega sem o cookie, e o operador vê "not found" até
recarregar. É o preço, e é aceito: o operador entra digitando ou por favorito.

---

## R4 — Rotas e o "not found" para quem não é operador (FR-009, O13)

**Decisão**:

- prefixo **`/platform`**, que não colide com `/organizations` (`router.ex:231`);
- pipeline `:plataforma`, **sem** `TheBandWeb.Plugs.CurrentScope`: mesmas plugs de `:browser`
  (`router.ex:7-42`), a mesma CSP e `TheBandWeb.Plataforma.OperatorScope` no lugar do plug de
  domínio. A CSP sai para um atributo de módulo do roteador, usado pelas duas pipelines, para que
  não existam duas cópias que divirjam;
- `require_operator` **não redireciona**: sem sessão de operador válida, responde `404` com o mesmo
  corpo de uma rota inexistente (`TheBandWeb.ErrorHTML`, `"404.html"`, layout raiz, como
  `page_controller.ex:19-29`). O visitante anônimo recebe **a mesma** página que o caminho que não
  existe;
- **públicas**: só `GET /platform/sign-in`, `POST /platform/session`, `GET /platform/setup` e
  `POST /platform/setup`.

**A leitura da FR-009 que o plano faz, e que precisa estar escrita**: a página de entrada do
operador é pública por necessidade, e confirma que `/platform` existe. Isso não é segredo: o
repositório é **público** (R0). O que a FR-009 protege é a **lista de organizações e os atos**, e
esses respondem `404` a quem não é operador, inclusive ao admin de uma organização.

---

## R5 — O episódio de suspensão e as razões (FR-003, FR-006, O9)

**Decisão**: tabela `tenant_suspensions`, na forma de `account_disablements`
(`20260910050000_episodio_de_desativacao.exs:71-95`): abre com autor, instante, razão e nota; fecha
com autor, instante, razão e nota; fechar não toca a abertura. **Índice único parcial** sobre
`tenant_id WHERE reactivated_at IS NULL` faz do "um episódio aberto por organização" uma garantia de
banco (O9, SC-002).

Razões em `priv/knowledge_base/rules/platform_tenant_suspension.yaml`, com a **forma** de
`access_account_lifecycle.yaml`: `suspend_reasons.values.offered`, `recorded_only: [not_recorded]`,
`reactivate_reasons.values.offered` com `offered_only_against`, e `note_required`. O leitor é
`TheBand.Platform.SuspensionReasons`, na forma de `AccountLifecycle` (`account_lifecycle.ex:165-198`):
**base ausente devolve lista vazia, e o ato recusa**.

A lista inicial é **proposta** em `data-model.md` §5, e passa pela revisão semântica no PR do YAML.

**Alternativa recusada**: acrescentar as razões a `access.account_lifecycle`. São atos sobre
coisas diferentes (conta e organização), feitos por papéis diferentes; uma regra só faria uma
mudança em um vocabulário mudar o arquivo do outro (princípio X).

---

## R6 — `tenants.status` só muda pelo episódio (O10)

**Decisão**:

1. `check_constraint` `tenants_status_valido`: `status IN ('active', 'suspended')`;
2. `Tenant.changeset/2` **deixa de fazer `cast` de `:status`** e ganha
   `validate_inclusion(:status, ~w(active suspended))` para o valor que vem do `default`;
3. **não existe** função pública que escreva o estado. A escrita é um `update_all` condicional
   **dentro** de `Platform.Suspensions`, na transação do episódio:
   `UPDATE tenants SET status = 'suspended' WHERE id = $1 AND status = 'active'`, conferindo uma
   linha afetada.

**A migração do `CHECK` mede antes de afirmar**: o `up` conta as linhas com estado fora da lista e,
se houver alguma, **levanta** com a contagem. Mapear um valor desconhecido para `active` ou para
`suspended` seria escolher pela organização (antipadrão "fallback silencioso"). E para cada
organização já `suspended` sem episódio, insere um episódio `not_recorded`, sem autor, como a
`20260910050000` fez com as contas. Produção **não foi consultada**; a skill `release` mede isso
antes de publicar.

**O que quebra, e é esperado**: `test/the_band/tenants/organizacao_suspensa_test.exs:44` usa o
changeset para suspender. Ele e os que usam `update_all` passam a usar um ajudante de teste que
chama o comando de verdade, ou continuam com `update_all` onde o teste é justamente sobre um estado
escrito por fora (a #1033).

---

## R7 — A concessão não se apaga (FR-002, O11)

**Medido** (R0): nenhuma migração deste repositório usa trigger. A prática é ausência de função
que apague, `on_delete: :restrict` e índice parcial do vigente.

**Decisão**: `platform_operator_grants` segue a prática **e** ganha um trigger `BEFORE DELETE`
que levanta, mais um `BEFORE UPDATE` que só aceita preencher a revogação a partir de nula. O mesmo
par vai em `tenant_suspensions`.

Três respostas do princípio VIII:

- **problema**: a FR-002 diz "MUST NOT ser apagado", e a O11 pede garantia além da ausência de
  função. Sem trigger, um `Repo.delete_all` num teste, numa tarefa mix ou num console apaga sem
  aviso, e `on_delete: :restrict` só protege de quem apaga **o pai**;
- **existe agora?** sim: é requisito escrito, e as duas tabelas nascem nesta feature;
- **o que piora**: é o **primeiro trigger** da base. Ele é invisível a quem lê só Elixir, exige
  `execute/2` com par de `down`, e **não protege de quem tem o banco**: o dono da tabela faz
  `DROP TRIGGER`. Protege de código, e não de pessoa com acesso ao Postgres. Isso fica escrito no
  `@moduledoc` da migração para ninguém tratá-lo como controle contra atacante.

**`REVOKE DELETE` recusado**: a aplicação conecta como dona das tabelas (**não verificado** em
produção; é o padrão de `DATABASE_URL` único em `config/runtime.exs`), e o dono pode conceder de
volta. Seria um controle que parece e não é.

`TRUNCATE` não dispara trigger de linha. Nada neste repositório trunca essas tabelas, e o sandbox do
Ecto desfaz por `ROLLBACK`.

---

## R8 — A transação da suspensão (FR-004, FR-013, FR-014, FR-015, O6, O8)

**Decisão**: `Platform.Suspensions.suspender/3` é **um `Ecto.Multi`**, nesta ordem:

| passo | o que faz | falha → |
|---|---|---|
| `:autorizacao` | relê a sessão do operador pela chave primária (aberta, no prazo) e a concessão vigente com `lock: "FOR SHARE"` | `{:error, :nao_autorizado}` |
| `:razao` | valida razão e nota contra `SuspensionReasons` | `{:error, changeset}` |
| `:estado` | `update_all` condicional `active → suspended`, uma linha | `{:error, :ja_suspensa}` |
| `:episodio` | `insert` do episódio aberto; o índice parcial recusa o segundo | `{:error, :ja_suspensa}` |
| `:sessoes` | `Sessions.encerrar_da_organizacao/1`, devolvendo os ids encerrados | — |
| `:tokens` | `ApiTokens.revogar_por_suspensao/2`, cláusula `organizacao_suspensa` | — |

Depois do `commit`, e só depois: o evento de acesso e o fechamento dos sockets (R9).

**Por que `FOR SHARE` na concessão** (O6, FR-014): a revogação faz `UPDATE` na linha da concessão.
Com o `FOR SHARE` da suspensão, as duas se serializam. Se a revogação confirma primeiro, o `SELECT`
da suspensão reavalia a linha já revogada e não a encontra, e a suspensão recusa. Se a suspensão
confirma primeiro, ela aconteceu antes da revogação, o que é legítimo.

**`Repo.transaction(fn …)` ou `Ecto.Multi`**: a casa usa os dois (`tenants.ex:308-338` e
`auth.ex:281-291`; `Ecto.Multi` em `bootstrap.ex` e `eo/commands.ex`). O `Multi` é a escolha aqui
porque **cada passo tem nome**, e o teste do cenário 3 de seguranca.md §4 afirma **qual** passo
recusou.

**Reativar** (`reativar/3`): `:autorizacao`, `:razao`, `:estado` (`suspended → active`, uma linha),
`:episodio` (fecha o aberto, uma linha), `:sessoes` (encerra **de novo** toda sessão aberta da
organização: é o que fecha a corrida O8 sem lock). **Não devolve token**: revogação é definitiva
(`api_tokens.ex:379-381`).

**O autor da revogação do token**: `revoked_by_user_id` é FK para `users`, e o operador não está
lá. A revogação por suspensão grava `revoked_by_user_id = NULL` e uma coluna nova,
`revoked_by_suspension_id`, que aponta o episódio. A cláusula `organizacao_suspensa` entra na regra
como **só registrada**, e não aparece no select da tela de tokens. Detalhe em `data-model.md` §6.

---

## R9 — A sessão de domínio cai, e a tela aberta cai junto: o aviso do #1044

**Substituído em 2026-10-01** pela avaliação da segunda autenticação (A2). A proposta anterior,
gravar `live_socket_id` na sessão de domínio e enviar `disconnect`, foi **retirada**: é anterior ao
#1044 e conflita com ele.

**O que existe** (PR #1044, mergeado em `development`; `lib/the_band/tenants/sessions.ex:136-149`):
a hook de domínio inscreve o LiveView conectado em `"sessao:<id>"`, `"conta:<user_id>"` e
`"sessoes"`. Ao receber `:sessao_encerrada`, a hook reconfere a sessão no banco, e o banco decide.
`Sessions.avisar_encerramento/1` publica nos três tópicos, e quem encerra dentro de uma transação
avisa **depois do `commit`** (é o que `encerrar_da_conta/2` faz).

**Decisão**: `suspender/3` e `reativar/3`, depois do `commit`, chamam
`Sessions.avisar_encerramento({:sessao, id})` para cada id que `encerrar_da_organizacao/1`
devolveu. **Não** se cria tópico por organização: o aviso por id alcança exatamente as telas das
sessões encerradas, e não amplia o que cada socket escuta. A pergunta 3 do plano foi respondida
pelo #1044 e sai.

**Prova** (seguranca-autenticacao.md §5, cenários 5 e 6): uma aba de A conectada cai na suspensão e
na reativação; uma de B continua. Defeitos a injetar: retirar o aviso; avisar só em `suspender/3`.

---

## R10 — A guarda do SC-003, por telemetria

**Decisão**: um teste anexa um handler a `[:the_band, :repo, :query]` (o prefixo padrão do
`TheBand.Repo`), filtrado pelo processo do teste, e coleta `metadata.source` de cada consulta.

- **nas rotas `/platform/*`**, toda consulta tem `source` numa **lista permitida por rota**
  (emenda A9): os `GET` e os `POST` de entrada, definição e cadastro aceitam `platform_operators`,
  `platform_operator_grants`, `platform_operator_sessions`, `platform_operator_recovery_codes`,
  `tenant_suspensions` e `tenants`. **Só** os dois `POST` de ato (suspensão e reativação) aceitam
  também `user_sessions` e `api_access_tokens`. Lista permitida, e não proibida: uma tabela de
  domínio nova reprova sozinha. `source` nulo (SQL cru) também reprova (lição L56);
- **toda consulta reprova se o texto do SQL citar `"users"`**, com aspas, como o Ecto gera (A9):
  `source` mostra só a tabela do `from`, e `Sessao.conferir/1` consulta `user_sessions` com `join`
  em `users` (`sessions.ex:190-198`);
- **nas rotas de domínio com o cookie do operador forçado** (`put_req_cookie` ignora `Path`):
  `/people`, `/teams/:id_de_B`, `/api/v1/people`, `/mcp`. A resposta é a mesma de um anônimo, e
  **nenhuma** consulta toca `platform_*`. A segunda asserção prova que o leitor de domínio nunca lê
  a sessão do operador;
- **a guarda de que mediu algo**: a mesma coleta, numa requisição de um membro de A, registra mais
  de zero consultas fora da lista permitida.

**Defeitos a injetar**, um por vez, e cada um precisa reprovar:

- `OperatorScope` chama `TheBandWeb.Sessao.conferir/1` (A9: é o defeito que mais importa, e a lista
  permitida antiga não o pegava);
- `Platform.listar_organizacoes/1` passa a pré-carregar `users`.

Por que filtrar pelo processo: o handler é global, e um teste `async` em paralelo poluiria a
coleta. Em `Phoenix.ConnTest` a requisição roda no processo do teste.

---

## R11 — A ordem das migrações e a #879

A #879 (064/T014) remove `users.session_token` e está aberta. **Esta feature não altera `users`**,
porque o operador é entidade separada. As migrações da 070 tocam `tenants` (um `CHECK`),
`api_access_tokens` (uma coluna, um `CHECK`) e criam tabelas novas. Não há tabela em comum.

O risco que sobra é de ordem: se as duas entrarem na mesma release, os timestamps decidem a ordem,
e nenhuma depende da outra. A regra para a implementação é gerar as migrações da 070 **depois** de
rebasear sobre `development`, para que o timestamp seja posterior a qualquer migração já mergeada,
e a skill `release` mede as duas como risco de migração.

---

## R12 — Observabilidade do operador (FR-010, O14)

**Decisão**:

- o plug do operador grava `Logger.metadata(operator_id: operador.id)`, e `config/config.exs:80`
  ganha `:operator_id` na lista do formatador. Sem isso o metadado existe e **não sai** no log;
- **não** grava `user_id`. A seguranca.md sugeria `user_id` com `papel: :operador`; o plano
  recusa porque `user_id` significa `users.id` em toda linha de log, e um id de operador ali
  faria uma busca por pessoa devolver a entidade errada;
- não grava `tenant_id`: o operador não tem. O `tenant_id` vai **no evento**, e é o da organização
  afetada;
- `AccessEvents` ganha funções próprias de plataforma (contrato em
  `contracts/eventos-de-acesso.md`), todas em `:warning`, porque `config/test.exs` sobe o nível e
  um evento em `:info` não é observável por teste (`access_events.ex:157-171`).

---

## R13 — O segundo fator do operador (FR-016)

**Decisão da pessoa mantenedora, 2026-10-01**: TOTP **nesta feature**, contra a recomendação de
deixar para depois (seguranca-autenticacao.md, "Decisões"). Este é o **desenho**; a biblioteca não
está escolhida, e o desenho passa por avaliação de segurança própria antes do código.

| decisão | razão |
|---|---|
| TOTP (RFC 6238), SHA-1, 30 s, 6 dígitos, janela ±1 | é o que os aplicativos autenticadores aceitam sem configuração |
| segredo de 20 bytes, **cifrado em repouso** com `TheBand.Encrypted.Binary` (Cloak, `lib/the_band/vault.ex`) | é a forma das credenciais das ferramentas; o segredo TOTP, ao contrário da senha, precisa ser lido em claro para conferir, e por isso não pode ser só resumo |
| cadastro **na definição da senha**, em dois passos (`definir_senha/3`, depois `confirmar_segundo_fator/3`) | não existe conta habilitada sem segundo fator: `autenticar/3` recusa com `totp_confirmed_at` nulo |
| o código de cadastro entre os dois passos: 20 bytes, `sha256`, 10 min, uso único, no corpo do `POST` | o segundo passo precisa provar que veio do primeiro sem cookie novo e sem URL com segredo |
| a entrada é **um** formulário com e-mail, senha e segundo fator | sem estado "meio autenticado" entre os dois fatores, que seria uma sessão a mais para proteger |
| contra reuso: `totp_last_used_step`, gravado na transação com `FOR UPDATE` | o mesmo código, visto por cima do ombro, não serve duas vezes na janela de 90 s |
| 10 códigos de recuperação de 80 bits, só `sha256` no banco, consumo atômico | perda do celular não pode exigir o banco; uso único por `UPDATE … WHERE used_at IS NULL` |
| falha de segundo fator conta na mesma espera crescente da senha | são a mesma porta; contadores separados dobrariam as tentativas |
| reinício de credencial e nova concessão apagam o segredo e invalidam os códigos (A6) | revogar e conceder de novo não devolve o aplicativo de antes |
| sem QR code na primeira forma: segredo em base32 e a URI `otpauth://` em texto | QR é uma dependência de geração de imagem; entra só se a pesquisa recomendar |

**Pesquisa de dependência pendente** (AGENTS.md §3, tarefa do `tasks.md`):

| opção | a medir |
|---|---|
| **NimbleTOTP** (Dashbit) | versão, manutenção, licença, dependências transitivas, `mix hex.audit`, se a janela e a proteção contra reuso são do chamador |
| **RFC 6238 sobre `:crypto`** (`:crypto.mac(:hmac, :sha, …)`) | cerca de 30 linhas; os vetores de teste do RFC 6238, apêndice B, como teste; o custo de manter código criptográfico próprio |
| QR (EQRCode ou outra) | só se a tela sem QR for recusada no protótipo |

O resultado e a justificativa vão para o `plan.md`, "Dependência nova", antes do código.

**O que piora**: um segredo a mais em repouso, legível por quem tem a `THE_BAND_MASTER_KEY` e o
banco, que já tem tudo; dois passos de definição que podem ser abandonados no meio, exigindo o
comando de reinício; uma tela a mais no protótipo.
