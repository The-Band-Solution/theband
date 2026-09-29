# Avaliação de segurança da US2 — o token de sessão deixa de ser legível no banco

**Data**: 2026-09-28 · **Papel**: Security (`AGENTS.md` §13), antes do código, exigida pelo §14.0
· **Quem escreveu o desenho**: não este papel · **Base lida**: `origin/development` em `8d55481`

**Recorte declarado.** Passagem sobre **o desenho** da Fase 4 (T009–T014) — `research.md` R2, R3
e R5, `data-model.md` — contra o código de sessão de hoje. Não é varredura do repositório.
Nada foi executado: todo achado abaixo vem de **leitura**, e o que se apoia em execução se
apoia no teste que já existe (`test/the_band_web/cookie_de_sessao_evidencia_test.exs`,
afirmação 3). A seção final diz o que ficou fora.

**Veredito sobre o núcleo do desenho**: a separação *token por sessão, resumido* + *época de
senha* é a correção certa para a FR-004, e SHA-256 é o resumo certo (ver §1). Os achados não
contestam o núcleo; contestam **o que o desenho deixa de dizer** sobre os caminhos que hoje
dependem do giro de `users.session_token` — e há cinco deles, não quatro.

---

## 1. As perguntas do pedido, respondidas

**SHA-256 sem sal nem HMAC basta?** Sim. O valor é `:crypto.strong_rand_bytes(32)`
(`lib/the_band/tenants/user.ex:250`): 256 bits, sem dicionário. Sal existe contra tabela
pré-computada de entrada de baixa entropia; aqui não há. HMAC com chave do servidor só
acrescentaria algo contra quem **escreve** no banco — e quem escreve troca o `password_hash`,
o que já basta para assumir a conta. Contra quem **lê** (o objetivo da FR-004), a pré-imagem de
SHA-256 sobre 256 bits é inviável com ou sem chave. E o HMAC teria custo: acoplaria a
invalidação de todas as sessões ao giro da chave. A base já decidiu exatamente isto para o
token da API — `docs/adr/0010-hash-do-token-de-api.md:54`, `lib/the_band/tenants/api_tokens.ex:272`
—, e a sessão deve seguir o mesmo precedente. ASVS V2.9 / V3.2.2 atendidos.

**Oráculo de temporização na busca por `token_hash`?** Não há um que importe. A busca pelo
índice único compara no Postgres, fora de tempo constante, mas o que o tempo vazaria são bytes
**do resumo** — que é justamente o que quem lê o dump já tem e não serve. E sem o
`SECRET_KEY_BASE` não se itera valor nenhum, porque o cookie é assinado. O ponto real é outro
(achado S8): `secure_compare/2` **depois** de achar a linha por igualdade de resumo é teatro,
e diverge da ADR 0010.

**Sessão múltipla muda a semântica?** Para quem usa, quase não: hoje todos os aparelhos
compartilham um token por conta, sair só apaga o cookie local, e trocar a senha derruba os
demais — o novo desenho preserva os três. Muda por dentro, e muda **para melhor** num ponto que
o desenho não nomeia: hoje **sair não encerra nada no servidor** (S5). O que é semântica nova e
pede decisão é o que se faz com as linhas: crescimento, retenção e o carimbo de atividade (S10).

---

## 2. Achados

| # | severidade | OWASP / ASVS | onde | o que é | bloqueia |
|---|---|---|---|---|---|
| **S1** | **alta** | A01 · V3.3.1 | `user.ex:136`, `tenants.ex:319`, `data-model.md` "Transições" | desativar hoje **gira o token**; no desenho, "as sessões caem pelo caminho que já existe" — e o caminho é o giro que some. Reativar a conta **ressuscita** toda sessão aberta antes da desativação, inclusive a que motivou desligar alguém | T011, T013 |
| **S2** | média | A07 · V3.3.1, V3.3.3 | `data-model.md` "A sessão do Phoenix" | a época vai **no cookie**. Quem tem o `SECRET_KEY_BASE` e roubou um cookie antes da troca de senha reassina com a época nova — um inteiro, adivinhável — e a troca **não o derruba**. Hoje derruba (o token gira). E o data-model se contradiz: "todas escrevem `ended_at`", mas a troca de senha só incrementa a época | T009, T011, T013 |
| **S3** | **alta** (condicional) | A01, A04 · V3.3.1 | `session_controller.ex:86` | `set_password` é **segunda porta** que confere `user.session_token == get_session(...)`. Se a T013 migrar só plug, hook e `create` — que é o que a descrição dela lista —, e contas novas ficarem com a coluna nula, `nil == nil` passa: cookie de sessão encerrada + reinício por quem administra = definir a senha alheia. É o **H1** de 2026-09-09 de volta | T013 |
| **S4** | média (existe hoje) | A07 · V3.2.1 | `current_scope.ex:54`, `hooks.ex:139-141`, `hooks.ex:152` | conta com `session_token` nulo aceita cookie que traga **só** `user_id`: `nil != nil` é falso, a guarda `nil == nil` casa, e `logged_in_at: nil` passa a validade. Com o `SECRET_KEY_BASE`, assume-se conta sem token — contradiz a R1 ("quem tem só uma metade não assume nenhuma"). O desenho fecha **se** a conferência recusar ausência por construção | T011 |
| **S5** | média (existe hoje) | A07 · V3.3.1 | `session_controller.ex:40-44`, `login_test.exs:201` | sair faz só `configure_session(drop: true)`: o token não muda, e o cookie copiado antes de sair **continua valendo** (é o mesmo conteúdo que a afirmação 3 já prova aceito). O teste de logout não reenvia o cookie antigo. A T013 diz "as quatro formas **continuam** funcionando" — sair nunca funcionou no servidor | T013 |
| **S6** | média | A07 · V3.3.2 | `hooks.ex:18-19`, `:152-158`; plug sem validade | a validade de 7 dias existe **só na hook**, conta de `users.logged_in_at` (por **conta**: um login legítimo em outro aparelho **estende** a sessão roubada) e **não** vale no plug — `POST /profile/password` e `/api/docs` aceitam sessão vencida. O desenho não a menciona, e `last_seen_at` é "se vier a existir". Mudar a sessão de tabela sem levá-la junto é regressão silenciosa | T011, T012, T013 |
| **S7** | média | A02, A08 · V3.3.1 | `rel/entrypoint.sh:27`; T012–T014 | entre T012 e T014 o bruto continua em `users.session_token` **e** passou a ser o token vivo das linhas migradas: todo backup da janela carrega sessões utilizáveis com o `SECRET_KEY_BASE`. E se o código antigo servir durante a migração (estratégia do Dokploy **não verificada**), uma troca de senha ou desativação feita por ele gira só a coluna velha, e a linha migrada **continua valendo** no código novo. O mesmo vale para rollback da T013 se ela deixar de girar a coluna | T012, T013 |
| **S8** | baixa | V3.2 / ADR 0010 | T011 `conferir/2` | busca por igualdade de resumo seguida de `secure_compare` compara o valor consigo mesmo. Sem risco, mas é a alegação de controle que não controla nada, e o oposto do que a ADR 0010 fez | T011 (decisão de forma) |
| **S9** | baixa | A01 · V4.1 | `data-model.md` `user_sessions` | a tabela não tem `tenant_id`, e `api_access_tokens` — o precedente da casa — tem. A busca por resumo é global (como `fetch_user/1` por id, hoje) e não cruza tenant por colisão, mas sem a coluna não há como encerrar as sessões **de uma organização**, nem FK composta que impeça linha com `user_id` de outro tenant | T009 |
| **S10** | baixa | V3.3, LGPD | `data-model.md` `last_seen_at`, "não se apaga" | uma escrita por requisição e por montagem de LiveView; e `last_seen_at` é **trilha de atividade de pessoa**, que viaja em todo backup e nunca sai, porque a sessão encerrada não se apaga | T009 (decisão) |
| **S11** | média | A09 · V7.1.1, FR-006 | T011 `abrir/1 → {sessão, bruto}`; T012 | o bruto sai de `abrir/1` como **binário nu** — a classe exata do H17 (`FunctionClauseError` imprime argumentos). A FR-006 desta spec exige a garantia **pelo tipo**. E uma T012 escrita como laço em Elixir com parâmetros levaria o valor ao log do migrador | T011, T012 |
| **S12** | baixa | A09 · FR-009 | `varredura.ex:88`, `:176-181`; `padroes.ex:65`; T014 | o controle positivo do padrão de sessão é plantado numa **tabela temporária** chamada `users.session_token`. Depois da T014 o controle continua achando, e a varredura diz "limpo" sobre uma coluna que não existe: o teste da T014 ("a varredura não acha mais o padrão") passa por vacuidade | T014 |
| **S13** | baixa | V3.3.3 | T010, `user.ex:196-209` | a época incrementada no changeset a partir da struct lida é *read-modify-write*: reinício por quem administra e troca própria concorrentes gravam o mesmo `n+1`, e a sessão aberta entre os dois sobrevive ao segundo | T010 (não bloqueia) |
| **S14** | baixa | V3.3.1 | sem `live_socket_id` em `lib/` | LiveView **já conectado** não reexecuta `on_mount` por evento: sair, trocar senha ou desativar não derruba o socket aberto até a próxima montagem. Existe hoje; o desenho é o momento barato de fechar, porque passa a haver um id por sessão | não bloqueia |
| **S15** | baixa (fora do escopo) | V3.4.1 | `endpoint.ex:7-12` | cookie de sessão sem `secure: true`. O `force_ssl` redireciona, mas a primeira requisição em HTTP leva o cookie antes do redirecionamento | issue própria |

---

## 3. O que fecha cada um, e o teste que prova

O cenário é deste papel; a forma do teste é do QA. Cada um diz **o defeito a injetar** —
guarda que não se vê reprovar não é guarda (§14.0).

| # | correção proposta | cenário de ataque → asserção | defeito a injetar |
|---|---|---|---|
| S1 | `Tenants.disable_user` encerra (`ended_at`) todas as sessões da conta **na mesma transação** do episódio | abre sessão A; desativa; reativa; reenvia o cookie A → `/sign-in`. `refute` do 200 | tirar o encerramento da transação → o teste precisa dar 200 |
| S2 | a época **vai na linha** (`password_epoch` em `user_sessions`), lida da **mesma** leitura que verificou o bcrypt; a conferência exige `linha.epoch == users.password_epoch`; e a troca também escreve `ended_at` nas demais | com `SECRET_KEY_BASE` real e o bruto de antes da troca, forjar cookie com a época nova → `/sign-in`. E a corrida: senha verificada com a época `n`, troca comita, linha gravada depois → recusada | comparar a época do cookie em vez da linha |
| S3 | `set_password` usa **a mesma** conferência (de preferência `conn.assigns.current_user` do plug), e não uma comparação própria | reinício por quem administra da conta X; cookie antigo de X (sessão encerrada) em `POST /set-password` → `/sign-in`, e `password_hash` de X **inalterado** no banco | voltar a linha 86 para comparação de campo |
| S4 | `conferir/2` casa só `bruto` binário de 43 bytes; ausência é recusa por cabeça de função | conta criada por `create_user/2` sem senha; cookie `%{"user_id" => id}` assinado com a chave real → hoje 200 (**o QA confirma antes**), depois `/sign-in` | cláusula que trata `nil` como "sem token para conferir" |
| S5 | `delete/2` chama `Sessions.encerrar/1` antes do `drop` | entra; guarda o cookie; sai; reenvia o cookie guardado → `/sign-in`. Hoje é aceito | remover a chamada de `encerrar` |
| S6 | validade **por sessão**, absoluta, contada de `inserted_at`, dentro de `Sessions.conferir` — ponto único que plug e hook chamam; na T012, `inserted_at = users.logged_in_at`, e não `now()` | sessão com `inserted_at` de 8 dias: `GET /people` **e** `POST /profile/password` → `/sign-in`. Login legítimo em outro aparelho **não** estende a sessão velha | contar de `last_seen_at`, ou pôr a conferência só na hook |
| S7 | T012 e T013 **no mesmo deploy**, com o contêiner antigo parado antes da migração; enquanto a coluna existir, linha migrada (marcada) só vale se `sha256(users.session_token)` ainda casa com ela; até a T014, senha e desativação **continuam** girando a coluna; T014 na release seguinte | com a linha migrada, girar `users.session_token` pelo caminho antigo e reenviar o cookie → `/sign-in` | tirar a condição da linha migrada |
| S8 | escolher: id da sessão no cookie, busca por PK, `secure_compare` do resumo em memória (coerente com a ADR 0010 e amarra o `user_id`); **ou** busca por resumo e apagar a alegação de tempo constante | — | — |
| S9 | `tenant_id` não nulo + FK composta `(user_id, tenant_id)` | linha com `user_id` do tenant A e `tenant_id` de B → `Ecto.ConstraintError` | remover a FK composta |
| S10 | carimbo com granularidade (no máximo uma escrita a cada 15 min) ou nenhum, se não houver expiração ociosa; retenção das encerradas decidida | 20 requisições em 1 min → **uma** escrita | — |
| S11 | `abrir/1` devolve `Segredo.t()` até `put_session`; `token_hash` com `redact: true`; T012 em SQL puro — `INSERT … SELECT sha256(convert_to(session_token,'UTF8'))` — sem interpolação nem parâmetro | `FunctionClauseError` forçado no caminho que recebe o bruto → `refute Exception.format(...) =~ bruto`; e a reinjeção com binário nu **vaza** | devolver binário nu |
| S12 | na T014, aposentar ou reapontar o padrão; o teste da T014 vira: abrir sessão real, `pg_dump`, busca **literal** do bruto → 0 — com o mesmo teste antes da T014 achando-o em `users.session_token` | — | — |
| S13 | incremento atômico (`inc:`) ou, bastante, encerrar as sessões no mesmo `UPDATE` | — | — |
| S14 | `put_session(:live_socket_id, "user_sessions:#{id}")` e `Endpoint.broadcast(..., "disconnect", %{})` ao encerrar | LiveView conectado; sair em outra aba → o socket cai | — |

**Dois ajustes nos testes que a tarefa já cita**, para não nascerem verdes por vacuidade:

- `cookie_de_sessao_evidencia_test.exs:126` usa o resumo em **hexadecimal**, e o desenho grava
  `bytea`. Depois da T013 qualquer lixo é recusado, e o teste passaria sem medir. A afirmação 3
  precisa ler **o que está na linha** de `user_sessions` — o que o dump dá — e ter o **par
  positivo**: o bruto devolvido por `abrir/1`, com a mesma chave, **é** aceito;
- a T010 confere a época só em "troca de senha e login". São **cinco** chamadores de
  `senha_changeset/3`: `auth.ex:245` (primeira definição), `:260` (troca própria), `:317`
  (cadastro e reinício), `bootstrap.ex:121`. O reinício por quem administra é a ferramenta de
  expulsar conta comprometida — é ele que o teste precisa cobrir primeiro.

---

## 4. Bloqueantes, por tarefa

| tarefa | não começa sem |
|---|---|
| **T009** | decidir onde mora a época (S2 → na linha) e `tenant_id` (S9, P4) |
| **T010** | teste cobrindo os cinco chamadores |
| **T011** | S1 (API encerra por conta), S2, S4, S6, S11; forma da S8 escolhida |
| **T012** | P1 decidida; S6 (`inserted_at` herdado), S7, S11 (SQL puro) |
| **T013** | S1, S3, S5, S6, S7 — e `test/support/conn_case.ex:51-56` passa a abrir sessão por `Sessions`, não por campo |
| **T014** | S12 |

---

## 5. Decisões da pessoa mantenedora

**P1 — As sessões vivas: migrar ou pedir nova entrada?** Os valores de hoje estão em toda cópia
tirada até a T014 (S7).
(a) migrar sem queda, como no desenho, e contar com a validade de 7 dias (S6) para matá-las;
(b) **não migrar**: todos entram de novo, anunciado — a FR-002 permite o segundo ramo;
(c) migrar e encerrar as migradas no deploy da T014.
**Recomendo (b).** Custa duas entradas (plan.md: 3 usuários, 2 com sessão); elimina de vez todo
bruto que já esteve em backup, e **apaga a T012 e a janela inteira da S7**. (a) só é seguro com
a S6 feita no plug e na hook.

**P2 — Expiração.** (a) absoluta de 7 dias **por sessão** — o de hoje, corrigido para não ser
por conta; (b) (a) + ociosa por `last_seen_at`; (c) nenhuma.
**Recomendo (a).** (b) só se houver pedido; sem ela, `last_seen_at` não tem trabalho.

**P3 — Retenção das sessões encerradas.** (a) para sempre, como o data-model diz; (b) apagar
depois de N dias (proponho 90); (c) apagar ao encerrar.
**Recomendo (b).** O evento de acesso já fica no log (`AccessEvents`); a linha guardada para
sempre é trilha de atividade de pessoa em todo backup.

**P4 — `tenant_id` em `user_sessions`.** (a) sim, com FK composta; (b) não.
**Recomendo (a)** — custo de uma coluna, e segue `api_access_tokens`.

**P5 — Giro depois de restaurar.** A R5 mostra que a sessão encerrada entre o backup e o desastre
**volta a valer** — e as encerradas por motivo de segurança são exatamente essas.
(a) passo **obrigatório** do procedimento; (b) recomendado.
**Recomendo (a).**

**P6 — Organização suspensa.** Hoje a suspensão bloqueia enquanto dura e **não** encerra: reativar
a organização devolve as sessões. (a) manter; (b) encerrar na suspensão. Fora do escopo da US2,
e registrado para não ser descoberto depois. **Recomendo (b)**, em issue própria.

---

### Decididas em 2026-09-28, pela pessoa mantenedora

Todas pela recomendação. O efeito de cada uma no desenho está em
[data-model.md](data-model.md), e nas tarefas em [tasks.md](tasks.md), Fase 4.

| | decisão | efeito |
|---|---|---|
| P1 | **(b)** não migrar; todos entram de novo, anunciado | a T012 deixa de migrar e passa a **girar** `users.session_token` de todos no deploy da T013; a janela da S7 some |
| P2 | **(a)** validade absoluta de 7 dias, por sessão | conta de `user_sessions.inserted_at`, no ponto único de conferência; `last_seen_at` sai do desenho |
| P3 | **(b)** apagar 90 dias depois de deixar de valer | tarefa nova, **T020** |
| P4 | **(a)** `tenant_id` com FK composta | na T009 |
| P5 | **(a)** giro obrigatório depois de restaurar | na T015 e na T016 |
| P6 | **(b)** encerrar na suspensão, em issue própria | fora da US2; S15 também vira issue própria |

**A forma da S8**, escolhida por quem implementa, sem pedir decisão porque o precedente existe:
id da sessão no cookie, busca por chave primária, `secure_compare` do resumo em memória —
a mesma forma da ADR 0010.

---

## 6. O que esta avaliação NÃO verificou

- **nenhum teste foi executado.** S4 e S5 são inferidos do código e da afirmação 3 já existente;
  o QA os confirma reprovando **antes** da correção;
- **a estratégia de deploy do Dokploy** — se o contêiner antigo serve enquanto o novo migra. A S7
  depende disso, e a recomendação é não depender;
- **se há backup de produção já tirado**, onde, e por quanto tempo fica — portanto quantas cópias
  carregam os tokens de sessão de produção;
- **quantas contas têm `session_token` nulo** em produção (S4) — nem em desenvolvimento, medi;
- o fluxo de convite / primeiro acesso por e-mail além de `set_password`, e o MCP e a API
  (`/api/v1`, `/mcp`), que usam token próprio (`ApiTokens`) e não a sessão — não relidos aqui;
- `Plug.Debugger` mostra a sessão na página de erro **em desenvolvimento**; não conferi que está
  desligado no release além de `code_reloading?`;
- `mix gates` **não foi rodado**: esta passagem não altera código, só acrescenta este documento.
