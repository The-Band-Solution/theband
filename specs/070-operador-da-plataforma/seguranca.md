# Avaliação de segurança da spec 070: o operador da plataforma

**Data**: 2026-10-01 · **Papel**: Security (`AGENTS.md` §13), **antes do plano**, exigida pela
FR-011 e pelo §14.0 · **Quem escreveu o desenho**: não este papel · **Base lida**:
`origin/development` em `44fcc3d`, mais `specs/070-operador-da-plataforma/spec.md` e a issue #1009.

**Recorte.** Esta passagem cobre o desenho da spec 070 contra o código de sessão, acesso, API,
MCP e jobs de hoje. Não é varredura do repositório. Quase tudo veio de **leitura**. Três pontos
vieram de **medição**, e cada um diz como foi medido:

1. o comportamento do Ecto 3.14.1 com `nil` (§1.2);
2. as constraints reais de `user_sessions` e `tenants` no banco de desenvolvimento;
3. o efeito de `MATCH SIMPLE` sobre a FK composta, testado em tabelas temporárias com
   `ROLLBACK`. Nenhuma tabela real foi escrita.

A última seção lista o que ficou fora.

**Veredito curto.**

- **Hoje, a conta sem tenant falha fechada em todo caminho medido**, mas falha de três jeitos: por
  recusa, por `FunctionClauseError` e por `ArgumentError`. A US2, cenário 4, exige "a recusa de
  quem não é de lá". Para cumpri-la, a implementação vai acrescentar ramos para `nil` em cerca de
  dez pontos de entrada, e **cada ramo é um lugar onde `nil` pode virar "sem filtro"**.
- **A decisão "conta fora de qualquer organização" é de risco alto se for feita do jeito
  ingênuo**: tirar o `NOT NULL` de `users.tenant_id` e de `user_sessions.tenant_id`, e ensinar o
  plug e a hook de domínio a aceitar `nil`. **Ela é aceitável com cinco invariantes estruturais**
  (§3), e com elas o risco fica menor que o da alternativa de entidade separada, porque reaproveita
  a autenticação já endurecida em vez de escrever uma segunda.
- O plano não deve sair sem essas invariantes escritas.

---

## 1. O que uma conta sem tenant faz hoje, caminho por caminho

### 1.1 A tabela

| Caminho | Onde | O que acontece com `tenant_id = nil` | Resultado |
|---|---|---|---|
| Abrir sessão | `lib/the_band/tenants/sessions.ex:56-66`, `schemas/user_session.ex:57` (`validate_required` de `tenant_id`) | o changeset recusa, e `TheBandWeb.Sessao.abrir/2` casa `{:ok, _} =` (`lib/the_band_web/sessao.ex:60`) e dá `MatchError` | **500** no login, fechado mas ruidoso |
| Conferir sessão, se a linha existisse | `sessions.ex:190-198`, join `u.tenant_id == s.tenant_id` (linha 194) | `NULL = NULL` é desconhecido no SQL, a linha não volta, motivo `:inexistente` | recusa |
| Plug `CurrentScope` | `lib/the_band_web/plugs/current_scope.ex:56-57`, `:79-80` | `organizacao_ativa?(_)` devolve `false` para tenant `nil`, e a sessão cai como `:organizacao_suspensa` | recusa, mas **o log registra o motivo errado** |
| Hook `:current_scope` | `lib/the_band_web/live/hooks.ex:29`, `:138-139` | mesma cláusula: `organizacao_ativa(%User{})` cai no erro | recusa |
| `:require_operacao` e `:require_admin` | `hooks.ex:72-118` | ambas delegam primeiro a `:current_scope`, que já recusou | recusa |
| `require_user` | `current_scope.ex:97-106` | olha **só** `current_user`; nunca olha o tenant | depende inteiramente do plug acima |
| `Auth.authenticate/2` | `lib/the_band/tenants/auth.ex:94`, `:133-135` | `where: t.id == ^tenant_id` com `nil` levanta `ArgumentError` (medido, §1.2) | **500 em vez da mensagem única**: é oráculo de enumeração (O3) |
| Definir ou trocar a senha | `auth.ex:236`, `:255`; `session_controller.ex:58`, `:123` | `user.tenant` é `nil`, e `%Tenant{}` na cabeça da função dá `FunctionClauseError` | a conta não define a senha temporária: beco sem saída (O4) |
| Encerrar as sessões da conta | `auth.ex:333` chama `sessions.ex:159-169` | `s.tenant_id == ^nil` levanta | idem |
| `Access.scopes/2`, `pode_ver/3`, `pode_ver_equipe/3` | `lib/the_band/tenants/access.ex:70`, `:235`, `:399` | `%Tenant{}` na cabeça, com `current_tenant` nulo, dá `FunctionClauseError` | recusa por erro |
| `Access.operacional?/2` | `access.ex:603-606` | `User.admin?(user)` **sem** comparar `user.tenant_id` com o tenant recebido | **latente** (O5) |
| API (`ApiAuth`) | `lib/the_band_web/plugs/api_auth.ex:78-82` | o token tem `tenant_id NOT NULL` (migração `20260918140000`, linha 45); um dono sem tenant faz `nil == tenant.id` dar falso, e a resposta é 401 | recusa |
| Emitir token | `lib/the_band/tenants/api_tokens.ex:193` | não confere se o dono pertence ao tenant; só `api_auth.ex:81` segura | defesa no chamador (O15) |
| MCP | `lib/the_band_web/router.ex:130-133` | mesma pipeline da API | recusa |
| PubSub | `ingestion.ex:28`, `profiles.ex:48`, `mapping/notifications.ex:33`, `:40` | `subscribe` exige `%Tenant{}`, e `@topic <> ":" <> nil` levanta | recusa |
| Jobs Oban | `jobs/sync_github_eo.ex:52-54` e os demais | o `tenant_id` vem do job, e não da conta; o operador não enfileira nada | não se aplica, ver O7 |
| Assinaturas de domínio | 444 funções com `%Tenant{}` na cabeça; 9 públicas recebem `tenant_id` cru (`ingestion.ex:32`, `raw_data.ex:103`, `:135`, `tenants.ex:407`, `notifications.ex:37`, `profiles.ex:60`, `eo/queries.ex:714`, `sessions.ex:159`, `recompute_promotions.ex:69`) | `nil` falha na cabeça ou no Ecto | recusa |

### 1.2 O que o Ecto faz com `nil`

Medido com o Ecto 3.14.1 compilado do checkout principal. A linha de `mix.lock` é idêntica à do
worktree da 070.

| Forma | Comportamento |
|---|---|
| `where: u.tenant_id == ^nil` (macro `from`) | **levanta** `ArgumentError` |
| `where: [tenant_id: ^nil]` (forma de lista; `Repo.get_by` passa por aqui) | **levanta** |
| `dynamic([u], u.tenant_id == ^nil)` composto numa consulta | **levanta** |
| `fragment("? = ?", u.tenant_id, ^nil)` | **não levanta**. O SQL gera `= NULL` e devolve **vazio** |
| `u.tenant_id in ^[nil]` | **não levanta**. Devolve **vazio** |
| `Repo.get(Tenant, nil)` (`tenants.ex:73-78`) | levanta |

**Nenhuma forma medida transforma `nil` em "todas as linhas".** O Ecto ou recusa, ou a semântica
de `NULL` do SQL devolve vazio. O vazamento só aconteceria em código que **decide antes do Ecto**:

- um `defp filtrar(q, nil), do: q`, que já existe para filtros opcionais em `verification.ex:894-910`,
  `eo/queries.ex:1044-1085` e `changes.ex:765`. Nenhum deles hoje é de tenant;
- um `or is_nil(x.tenant_id)`;
- um `Enum.filter` em memória;
- um ramo novo de "administração global".

**É exatamente esse o código que a FR-011 convida a escrever.**

### 1.3 A FK composta não protege linha com `NULL`

Medido no Postgres local: a constraint é `user_sessions_user_id_fkey` com
`FOREIGN KEY (user_id, tenant_id) REFERENCES users(id, tenant_id)`, com `MATCH SIMPLE` implícito.
Numa réplica em tabela temporária, **uma linha com `user_id` que não existe e `tenant_id` nulo foi
aceita**.

Em `MATCH SIMPLE`, basta uma coluna da chave ser nula para o Postgres não conferir a FK. E essa FK
é a **única** sobre `user_id` (migração `20260929100000_sessoes_de_usuario.exs:41-43`). Tornar
`user_sessions.tenant_id` anulável apaga a integridade referencial da linha inteira, e não só do
tenant.

---

## 2. Achados

| # | Sev. | OWASP / ASVS | Onde | O que é | Bloqueia o plano |
|---|---|---|---|---|---|
| **O1** | **alta** (desenho, condicional) | A01, A04 · V1.4, V4.1.3 | `20260809120000_create_tenants_and_users.exs:27`; `user.ex:107`; `20260929100000_sessoes_de_usuario.exs:39-43` | a FR-011, feita do jeito ingênuo, afrouxa as duas invariantes de banco que transformam o próximo esquecimento de tenant em erro: `users.tenant_id NOT NULL` vale para **toda** conta, e a FK composta de sessão deixa de valer com `NULL` (§1.3). Depois disso, uma conta criada sem tenant por defeito fica indistinguível da conta do operador | **sim**, até o plano declarar I1 a I5 (§3) |
| **O2** | **alta** (desenho) | A01 · V4.1.5 (falhar fechado) | `current_scope.ex:79-80`; `hooks.ex:138-139`; `sessions.ex:194` | o fechamento de hoje é **acidental**. Três relaxamentos tentadores reabrem o domínio inteiro à conta sem tenant: `organizacao_ativa?(_) -> true` para o operador; um `if operador?` antes do `cond`; o join da sessão reduzido a `u.id == s.user_id`. Com qualquer um deles, `require_user` (`:97-106`) deixa passar toda rota de `:autenticado` | **sim**: o plano precisa proibir esses três pontos como caminho do operador, e o teste precisa travá-los |
| **O3** | média | A07 · V2.2.1, V3.2 | `auth.ex:94`, `:133-135` | a conta sem tenant faz `authenticate/2` levantar **antes** da recusa única. A resposta vira 500 em vez de "Credenciais inválidas", e isso diz a quem tenta que aquele e-mail é uma conta especial, além de quebrar o tempo constante | não; vira FR e tarefa |
| **O4** | média | A07 · V2.1, V3.3 | `auth.ex:236`, `:255`, `:333`; `session_controller.ex:58`, `:123`; `hooks.ex:142-144` | o fluxo de senha exige `%Tenant{}`. O operador não define a temporária nem troca a senha, e o `gate_de_senha` mora na hook de domínio, onde o operador não deve passar. A tentação será criar o operador **com senha definitiva por argumento de comando** | não, mas o plano precisa dizer como o operador recebe e troca a credencial |
| **O5** | média (latente) | A01 · V4.2.1 | `access.ex:603-606` | `operacional?/2` concede `{true, :admin}` só por `User.admin?`, sem `user.tenant_id == tenant_id`. É o único veredito da casa sem essa comparação: `pode_ver` (`:268`), `pode_ver_equipe` (`:401`), `pode_gerir_estrutura` (`:202`), `grant` (`:546`) e `revoke` (`:579`) comparam. Fica explorável no dia em que alguém passar um tenant alvo diferente do da conta, que é o desenho natural da área do operador. `bootstrap.ex:86` também lê `role == "admin"` globalmente | não; corrigir nesta feature |
| **O6** | **alta** | A01, A07 · V3.3.1, V4.1.3 | spec FR-001, FR-002; `hooks.ex:72-118` (o padrão de hoje confere só no `mount`) | revogar o papel não está escrito como "derruba a sessão do operador e vale no próximo ato". Pelo padrão da casa, a autorização é conferida no `mount`, e um LiveView montado continua emitindo eventos depois da revogação. O operador comprometido, que é o caso para o qual a revogação existe, continua suspendendo organizações até o socket fechar | **sim**: precisa virar FR |
| **O7** | média (**existe hoje**) | A01, A04 · V1.4 | `ingestion.ex:45`, `:506-575`; `jobs/schedule_due_syncs.ex:30`; `jobs/sync_github_eo.ex:52-54`; `jobs/reprocess_mappings.ex:21`; `jobs/recompute_promotions.ex:46`; `profiles/automation.ex:104-106`; `profiles/monthly_worker.ex:24`, `run_worker.ex:29`, `generate_worker.ex:77` | **nenhum worker lê `tenants.status`**: a busca por `"active"` em `lib/the_band/jobs`, `profiles` e `ingestion` volta vazia. Hoje a organização suspensa continua sendo coletada a cada 5 minutos e entra na rodada mensal de perfis, **que envia dado de pessoa ao provedor de LLM** com a chave dela. A FR-012 nomeia só "a coleta" | não; a FR-012 precisa listar todos os workers |
| **O8** | média | A01, A07 · V3.3.1 | `auth.ex:133` (lê o estado) e depois `session_controller.ex:29-33`, `sessions.ex:56` (grava a sessão) | há uma corrida entre entrar e suspender. A entrada lê `active`, a suspensão encerra tudo e confirma, e a sessão é gravada **depois**. Ela é recusada enquanto dura a suspensão e **volta a valer na reativação**, que é o defeito #1009 por outra porta | não; vira FR-005 estrutural |
| **O9** | baixa | A04 · V1.11 | o padrão de `tenants.ex` em `disable_user/4` (`ainda_ativa` é conferido **fora** da transação) | suspender duas vezes ao mesmo tempo abre dois episódios, e o SC-002 depende de haver um só episódio aberto | não |
| **O10** | média | A04 · V5.1.3 | `tenant.ex:22`, `:31`; banco: `tenants` só tem `tenants_pkey` | `tenants.status` é **string livre**, sem `validate_inclusion` e sem `check_constraint`. O "fato medido" da primeira linha da spec ("aceita `active` e `suspended`") está inexato: aceita qualquer valor. Como `Tenant.changeset/2` faz `cast` de `:status`, qualquer chamador muda o estado **sem episódio**, e isso fura o SC-002 | não; vira FR |
| **O11** | média | A08, A09 · V2.10, V7.1 | `lib/the_band/release.ex` (padrão de `semear_primeira_conta/0`); Dokploy | o "autor" da concessão feita por `rpc` é **declarado** por quem digita, e não autenticado. A credencial não pode ir em argumento: fica no histórico do shell, no terminal do Dokploy e no `ps`. O registro não apagável da FR-002 precisa de garantia além da ausência de função que apague | não; vira contrato |
| **O12** | média (decisão) | A01, A07 · V3.3.1 | `api_auth.ex:79`; spec, Edge Cases ("Tokens da API... já são recusados") | os tokens são recusados **enquanto dura** a suspensão e **voltam na reativação**, que é o #1009 dos tokens. Token pode ser "sem expiração" (`api_tokens.ex`, `expiracao/1`). O token que motivou a suspensão volta a responder 200 | **sim**: é decisão (P2) |
| **O13** | baixa | A01 · V4.3 | `router.ex:231` (`/organizations` já é a tela de organizações do EO); `current_scope.ex:97-106` | dois detalhes de rota. (1) Há colisão de nome: a rota do operador precisa de caminho próprio. (2) A FR-009 pede "not found", mas o visitante sem sessão recebe o redirecionamento de `require_user` para `/sign-in`, que confirma que a rota existe | não |
| **O14** | baixa | A09 · V7.1.1, V7.1.3 | `access_events.ex:146-150` (o ator vem do `Logger.metadata`); `current_scope.ex:68` | a área do operador tem plug e hook próprios. Se eles não gravarem `Logger.metadata(user_id: ...)`, a FR-010 sai **sem autor** no log. E o `tenant_id` do evento precisa ser a organização afetada, não o `nil` do operador | não |
| **O15** | baixa (existe hoje) | A04 · V4.1.3 | `api_tokens.ex:193` | `criar/4` não confere se o dono pertence ao tenant, e só `api_auth.ex:81` impede o uso. Com contas sem tenant passando a existir, é um caminho a mais para o mesmo esquecimento | não |
| **O16** | informativo | A07 · V2.8 | spec FR-008 | a conta do operador comprometida derruba a **disponibilidade** de todas as organizações (uma a uma; a FR-008 só proíbe o ato em lote) e enumera nomes e slugs. Desde que a FR-007 se mantenha, ela não alcança dado de domínio. A proteção é senha mais espera crescente (`auth.ex:162-165`, teto de 60 s, sem bloqueio), sem segundo fator | não; registrar como risco residual |

---

## 3. A decisão "conta fora de qualquer organização", comparada

| | **A ingênua**: `users` e `user_sessions` sem tenant, com ramos para `nil` no plug e na hook | **A endurecida**: `users` sem tenant **com** I1 a I5 | **B**: entidade separada (`platform_operators`, credencial e sessão próprias) | **C**: um tenant "de plataforma" que não guarda dado |
|---|---|---|---|---|
| `nil` de tenant no caminho de domínio | sim, para sempre, em todo `%User{}` | não: a conta sem tenant nunca chega ao plug nem à hook de domínio | não existe | não existe |
| FK de sessão | apagada para a linha (§1.3) | intacta: `user_sessions` continua `NOT NULL` | intacta | intacta |
| Autenticação | reaproveitada | **reaproveitada**: mensagem única, tempo constante, espera crescente, época e resumo do token | **segunda implementação**: o lugar clássico de defeito A07, na conta mais poderosa | reaproveitada |
| Tipo | o mesmo `%User{}` entra em funções de domínio | o mesmo `%User{}`, barrado pela invariante I3 com teste | `%Operator{}` não casa nenhuma função de domínio | `%User{}` com tenant real e vazio |
| O que piora | tudo acima | uma coluna discriminadora e uma tabela ou chave de sessão a mais | duplicação de auth e sessão, e uma segunda porta | o tenant especial precisa ser excluído do agendador, das listas e da suspensão; o operador vê telas de domínio vazias em vez da recusa (fere a US2, cenário 4) |
| Recomendação | **não** | **sim** | aceitável se o plano não conseguir entregar I1 a I5 | não |

### As invariantes da opção "A endurecida", cada uma com o teste que a prova

- **I1. Conta sem tenant só existe como conta de plataforma, e o banco garante.**
  - Desenho: um discriminador `users.kind` (`organization` ou `platform`), que é o padrão
    "Discriminador" da tabela de `AGENTS.md` §7.7, com
    `CHECK ((kind = 'platform') = (tenant_id IS NULL))` e
    `CHECK (kind = 'organization' OR role = 'member')`. O **poder** de operador continua no
    relator de concessão, e o discriminador diz só **de que tipo** é a conta.
  - Teste: um `insert` de `users` sem tenant e com `kind = 'organization'` reprova no banco.
  - Defeito a injetar: retirar o primeiro `CHECK`. O teste precisa passar a gravar.
- **I2. `user_sessions` não muda.** `tenant_id` continua `NOT NULL` e a FK composta continua
  intacta. A sessão do operador vive em tabela própria, com
  `FOREIGN KEY (user_id, kind) REFERENCES users(id, kind)` e `CHECK (kind = 'platform')`, o que
  exige `unique_index(users, [:id, :kind])`. Ela entra no giro operacional
  (`Release.encerrar_todas_as_sessoes`, `sessions.ex:176`) e na retenção de 90 dias
  (`ApagaSessoesAntigas`). Sem retenção, vira o registro permanente que a FR-015 da 064 proíbe.
  - Teste: inserir sessão de operador com `user_id` de conta `organization` reprova.
  - Defeito a injetar: tornar `user_sessions.tenant_id` anulável. O teste de §1.3 precisa
    aceitar a linha.
- **I3. A conta de plataforma é recusada pelo plug e pela hook de domínio por construção, e o
  log diz o motivo certo.** `current_scope.ex:79-80` e `hooks.ex:138-139` ganham uma cláusula
  explícita `%User{kind: "platform"} -> recusa :conta_de_plataforma`, em vez de depender de o
  tenant ser `nil`.
  - Teste: para **toda** rota de `TheBandWeb.Router.__routes__()` fora da área do operador
    (navegador, `/api/v1/*`, `/mcp`), a sessão do operador recebe a recusa de quem não é de lá.
  - Defeito a injetar: fazer `organizacao_ativa?/1` devolver `true` para a conta de plataforma.
    O teste precisa reprovar em `/people`, `/teams` e `/work`.
- **I4. A área do operador tem pipeline, `live_session`, plug e hook próprios**, e nenhum deles é
  `require_user`, `:current_scope` ou `CurrentScope` reaproveitado com ramo. A única porta é um
  `TheBand.Platform.operador?/1` que lê a concessão vigente.
  - Teste: um admin de organização recebe "not found" na rota do operador.
  - Defeito a injetar: trocar o plug da área por `require_admin`. O teste precisa reprovar.
- **I5. A conta de plataforma nunca é `admin`, e `operacional?/2` compara o tenant (O5).**
  - Teste: `operacional?(tenant_b, admin_de_a)` devolve `false`.
  - Defeito a injetar: retirar a comparação. O teste precisa devolver `{true, :admin}`.

---

## 4. Os cenários de ataque para o QA

Cada cenário diz o atacante, o dado hostil, a asserção e o defeito a injetar. O teste só vale se
for visto reprovar com o defeito.

1. **SC-003, o operador em domínio, nas três portas.** Atacante: a conta do operador, com sessão
   válida. Dado: dois tenants povoados, A e B, cada um com pessoas, equipes e issues.
   - Asserções: a resposta de `/people`, `/teams/:id_de_B`, `/api/v1/people` e `/mcp` é a mesma
     recusa de quem não é de lá.
   - Asserção que prova a ausência de vazamento: um handler de telemetria em
     `[:the_band, :repo, :query]` registra que **nenhuma consulta tocou tabela de domínio**
     (prefixos `eo_`, `spo_`, `cmpo_` e os demais) durante a requisição do operador.
   - Guarda de que mediu algo: o mesmo handler, numa requisição de um membro de A, registra mais
     de zero consultas de domínio.
   - Defeito a injetar: o da I3.
2. **O3, oráculo na entrada.** `authenticate(email_do_operador, "errada")` devolve
   `{:error, :invalid_credentials}`, e `refute` de qualquer exceção.
   - Defeito a injetar: retirar o ramo de plataforma antes de `organizacao_ativa?/1`. O teste
     precisa levantar `ArgumentError`.
3. **O6, revogação com socket aberto.** O operador monta a tela, a concessão é revogada, e o
   operador envia o evento `suspend` para o tenant A.
   - Asserções: A continua `active` e `refute` de episódio novo. A sessão do operador tem
     `ended_at`.
   - Defeito a injetar: conferir a concessão só no `mount`. A suspensão precisa acontecer.
4. **O8, a corrida.** Simulação determinística: com A suspensa, inserir diretamente uma sessão
   de A, que é a entrada que leu `active` antes. Reativar A e enviar o cookie.
   - Asserção: o cookie volta para `/sign-in`.
   - Defeito a injetar: retirar o encerramento na reativação. A resposta precisa dar `200`.
5. **#1009, o cenário da spec**, com dois tenants: suspender A não encerra nenhuma sessão de B.
   - Asserções: as sessões de A têm `ended_at`; as de B não têm, e as de B continuam sendo mais
     de zero.
   - Defeito a injetar: encerrar com `girar_todas/0`. B precisa cair.
6. **O7, os workers.** Um teste enumera os módulos com `use Oban.Worker`. Os que recebem tenant
   ficam numa lista explícita, e um worker novo fora da lista reprova o teste.
   - Para cada worker da lista, com o tenant suspenso, `perform/1` devolve
     `{:cancel, :organizacao_suspensa}` e **não** chama a borda HTTP. O Mox afirma isso.
   - Para o agendador, `enqueue_due_syncs/0` enfileira zero ferramentas de A e mais de zero de B.
   - Defeito a injetar: retirar a conferência de `SyncGitHubEO`. A borda HTTP precisa ser chamada.
7. **O10, o estado sem episódio.** `Tenant.changeset(t, %{status: "suspended"})` não muda o
   estado, e um `insert` direto com `status = 'Suspended'` reprova pela `check_constraint`.
8. **O12**, conforme a decisão P2. Na opção (a): um token de A emitido antes da suspensão e
   enviado depois da reativação recebe 401, e o token tem `revoked_at`.
9. **FR-002.** A concessão e a revogação ficam como linhas, e não existe função pública que
   apague uma delas.
   - Asserção: `refute function_exported?(TheBand.Platform, :delete_grant, _)`. Ela vale como
     guarda mínima; a garantia de verdade é ausência de caminho, revisada no PR.

---

## 5. Recomendações para o plano, por FR

- **FR-001 e FR-002 (O11).**
  - O comando de concessão segue o contrato da 052: e-mail e nome vêm do comando ou do ambiente,
    e **a senha inicial vem do ambiente** ou é uma temporária com `must_change_password`. Nunca
    vem de argumento.
  - O relator nunca carrega a senha. O `IO.puts` reporta só e-mail e ato.
  - O autor gravado é declarado e está marcado como declarado, por exemplo
    `granted_via: "release_command"`, com o texto que o executor informou. A spec deve dizer que a
    prova de quem executou é o acesso ao Dokploy, que fica fora da aplicação.
  - A revogação encerra as sessões do operador **na mesma transação**.
  - **Quem roda o comando já tem `THE_BAND_MASTER_KEY` e o banco.** O comando não acrescenta
    poder a ninguém, e isso deve estar escrito, para ninguém tratá-lo como controle.
- **FR-003, FR-004 e FR-006 (O9, O10).**
  - A suspensão é um `UPDATE tenants SET status = 'suspended' WHERE id = $1 AND status = 'active'`
    que confere uma linha afetada, dentro da transação que abre o episódio e encerra as sessões.
  - Um índice único parcial sobre os episódios abertos por tenant torna o SC-002 uma garantia de
    banco.
  - `:status` sai do `cast` genérico e ganha `check_constraint`.
- **FR-005 (O8).** Reativar **também** encerra toda sessão aberta da organização. O ato é
  idempotente e fecha a corrida sem precisar de lock.
- **FR-007 e FR-011.** Entram I1 a I5. A tela do operador lê de uma função única,
  `Platform.list_organizations/1`, que recebe o operador e devolve **só** nome, slug, estado e o
  último episódio. Não usa `Tenants.list_tenants/0` cru em tela.
- **FR-009 (O13).** Caminho próprio, por exemplo `/platform/organizations`. Decidir se o visitante
  sem sessão também recebe "not found", o que exigiria tirar a área de `require_user`.
- **FR-010 (O14).** A hook do operador grava `Logger.metadata(user_id: operador.id, papel: :operador)`.
  O evento leva o tenant **afetado**.
- **FR-012 (O7).** O texto passa a ser: *todo worker que age em nome de um tenant confere o estado
  do tenant em `perform/1` e cancela*. A lista de workers fica no plano, e o teste do cenário 6
  guarda essa lista.
- **Nova FR para a O6.** "A autorização de operador é conferida dentro da função que suspende e
  reativa, na transação, e não só no `mount`."

---

## 6. Perguntas para a pessoa mantenedora

**P1. Como a conta do operador é modelada?**

- (a) `users` sem tenant **endurecida**, com I1 a I5;
- (b) entidade separada, com credencial e sessão próprias;
- (c) tenant de plataforma.

**Recomendação: (a).** Mantém a decisão de 2026-10-01 e reaproveita a autenticação endurecida. O
preço é uma coluna discriminadora, uma tabela de sessão e os testes de §4. A opção "A ingênua" fica
**recomendada contra**.

**P2. A suspensão revoga os tokens de API da organização?**

- (a) sim, na mesma transação, com razão `organization_suspended`, e reativar não os devolve;
- (b) não, e eles voltam na reativação, registrado como risco residual aceito.

**Recomendação: (a)**, por paridade com a decisão P6 da #1009 para sessões. O token é credencial
de longa duração, e é o caso em que "voltar" mais custa.

**P3. O que a suspensão para?**

- (a) **todo** worker que age em nome do tenant: coleta, reprocessamento, promoções e perfis via
  LLM;
- (b) só a coleta, como diz a FR-012 hoje.

**Recomendação: (a).** A rodada mensal de perfis envia dado de pessoa da organização suspensa ao
provedor externo (O7), e é exposição a modelo depois de a organização ter sido desligada.

---

## 7. O que NÃO verifiquei

- **Cada LiveView de domínio, uma a uma.** Conferi o padrão das assinaturas (444 cabeças
  `%Tenant{}` e 9 funções públicas com `tenant_id` cru) e os pontos de entrada. Não li o `mount`
  de cada tela. O cenário 1 de §4 é o que cobre isso por medição, e ele ainda não existe.
- **As ferramentas da MCP individualmente.** Conferi a pipeline (`router.ex:130-133`) e
  `servidor.ex:41`, que lê `assigns.current_tenant`. Não li cada ferramenta.
- **A tela de tokens (`ApiTokenLive`).** Não conferi se o dono pode ser escolhido entre contas
  fora do tenant (O15).
- **O banco de produção.** As constraints foram lidas no banco de **desenvolvimento**
  (`the_band_dev`). Produção não foi tocada.
- **A estratégia de deploy do Dokploy e quem tem acesso a ele.** Isso determina quem pode rodar o
  comando de concessão (O11).
- **Por quanto tempo um socket de LiveView sobrevive à revogação.** A O6 se apoia no padrão do
  código, conferido só no `mount`, e não em medição.
- **Gates.** Não rodei `mix gates`, `mix sobelow`, `mix hex.audit` nem `mix deps.audit`. Esta
  passagem não mudou código; o único arquivo escrito é este. O veredito de gate pertence ao PR
  que implementar.
- **A interação com a #879 (064/T014).** Ela remove `users.session_token` e migra a mesma tabela
  `users` que a I1 altera. A ordem das migrações fica para o plano.
- **A medição do Ecto** usou o `_build` do checkout principal, cuja linha de `ecto` no `mix.lock`
  é idêntica à do worktree da 070 (comparada com `diff`). Não rodei a suíte.

## Decisões da pessoa mantenedora, 2026-10-01

| Pergunta | Decisão | Efeito nesta avaliação |
|---|---|---|
| 1. Como modelar a conta do operador | **(b) entidade separada**, contra a recomendação (a) | O1 e O2 deixam de se aplicar como estão escritos: `users` e `user_sessions` não mudam, e nenhum caminho de domínio passa a aceitar `nil`. Em troca, nasce uma **segunda autenticação**, que precisa de avaliação própria no plano: armazenamento da senha, limite de tentativas, sessão, cookie e o leitor da sessão separado de `TheBandWeb.Sessao`. I1 a I3 caem; I4 (área própria) e I5 (`operacional?/2` compara o tenant, #1034) continuam |
| 2. A suspensão revoga os tokens de API | **(a) sim** | FR-013 |
| 3. O que a suspensão para | **(a) todo worker do tenant** | FR-012, e a issue #1033, corrigida antes desta feature |

O6 virou FR-014, e O8 virou FR-015. O5, O7 e O15 existem hoje e viraram as issues #1034, #1033 e
#1035, que vêm antes da feature, pela regra "corrigir antes de implementar".
