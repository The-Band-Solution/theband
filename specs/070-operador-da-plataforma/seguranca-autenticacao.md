# Avaliação de segurança da segunda autenticação: o operador da plataforma (070)

**Data**: 2026-10-01 · **Papel**: Security (`AGENTS.md` §13), o gate de `plan.md` ("Gate de
segurança, antes de qualquer código") · **Quem escreveu o desenho**: não este papel ·
**Base lida**: worktree da 070 em `a917719`, o diff do PR #1044 (aberto, não mergeado), e o código
de `lib/` e `config/` desse mesmo commit. As dependências (`deps/plug`, `deps/phoenix`) foram lidas
no checkout principal, com a mesma linha de `mix.lock`.

**Recorte.** É uma avaliação de **desenho**, feita por **leitura**. Nada foi medido: não rodei
teste, gate, banco nem produção. Cada achado diz em que arquivo e linha se apoia, e os que dependem
de comportamento em execução estão marcados como "por leitura". A decisão (b) da pessoa mantenedora,
a entidade separada, é premissa desta avaliação. Ela não é rediscutida aqui.

---

## Veredito

**O desenho pode seguir para `tasks.md`, com as emendas da §4.** Nenhum achado pede para desfazer a
decisão (b). As tarefas continuam **bloqueadas** até a emenda entrar no contrato correspondente:

| tarefa bloqueada | por quê | o que a destrava |
|---|---|---|
| `Platform.Credentials` | A1, A3, A5 | contrato de credenciais emendado: tentativa serializada, custo do hash também na espera, consumo atômico do código |
| `Platform.Grants` e os três comandos de `Release` | A6 | contrato de concessão emendado: conceder de novo apaga a senha antiga |
| `Platform.Suspensions` | A2 | PR #1044 mergeado, e R9 substituído pelo aviso do #1044 depois do `commit` |
| o teste do SC-003 (R10) | A9 | lista permitida por rota, e asserção sobre `users` no SQL |

O resto entra como tarefa comum, com o teste dela.

**O que está certo, e como conferi** (tudo por leitura):

- **Nenhum segredo em argumento.** O comando recebe e-mail, nome e o autor declarado
  (`contracts/concessao-do-operador.md`), na forma de `release.ex:106-118`. A senha só existe no
  navegador do operador (research R1).
- **O código de definição** tem 160 bits, guarda só `sha256`, vale 30 minutos e chega pelo corpo
  de um `POST`, e não pela URL. Por esse lado, força bruta no `POST /platform/setup` não é viável,
  e o código não vai para o log de acesso nem para o `Referer`.
- **O cookie** é separado (`_the_band_operator`), cifrado, `http_only`, `Secure` por
  `config/prod.exs:31`, `SameSite=Strict` e `Path=/platform`. O `encrypt: true` do Plug deriva a
  chave de `secret_key_base` e do nome do cookie (`deps/plug/lib/plug/conn.ex:1599`, `:1686-1687`).
  A validade de 8 h é conferida **no servidor** por `inserted_at`, e não só pelo `max_age`.
- **Controller em vez de LiveView, a pergunta 1 do plano.** Concordo com (a). O socket só recebe o
  `Plug.Session` (`endpoint.ex:20-22`, `@session_options` em `:7-14`). E a saída de domínio apaga
  o cookie inteiro (`session_controller.ex:46`). Com a opção (b), o cookie do operador viajaria
  junto do domínio.
- **Fixação de sessão** não acontece pelo desenho. O id e o segredo nascem no servidor, e um id
  escolhido pelo cliente não tem linha com o resumo certo (`sessions.ex:201-205`, que a cópia
  segue).
- **Na transação da suspensão, `FOR SHARE` na concessão serializa com a revogação** (research R8).
  Em `READ COMMITTED`, o `SELECT … FOR SHARE` que espera reavalia a linha nova, e com
  `revoked_at IS NULL` no `WHERE` ela não volta. A suspensão recusa, como o contrato diz.
- **MCP sem conexão longa.** `GET` e `DELETE` recebem `405`, e não há stream
  (`lib/the_band_web/mcp/porta.ex:11-14`). Revogar os tokens na suspensão corta a próxima chamada,
  e não fica conexão aberta para trás.
- **Os triggers estão justificados com honestidade** (research R7): protegem de código, e não de
  quem tem o banco. O texto já diz isso.

---

## 1. Achados

| id | sev. | OWASP · ASVS | onde | o quê | bloqueia o código |
|---|---|---|---|---|---|
| **A1** | **alta** | A07 · V2.2.1, V11.1.4 | `auth.ex:71`, `:137-160`, `:167-174`; research R2 (`:100`, "as mesmas constantes") | a espera crescente que o plano copia **lê e grava fora de lock**. N tentativas paralelas leem o mesmo `failed_attempts`, todas passam por `fora_da_janela/1`, e todas testam a senha. Também não há limite por IP (A4) nem segundo fator (O16). Na conta mais poderosa, é o único freio | **sim**: `Credentials` |
| **A2** | **alta** | A01, A07 · V3.3.1, V3.3.4 | research R9; `contracts/suspensao.md` ("se a pergunta 3 for aceita"); PR #1044 (`Sessions.topicos/1`, `avisar_encerramento/1`) | a suspensão encerra `ended_at`, mas o LiveView aberto da organização só cai se alguém avisar depois do `commit`. O #1044 criou o aviso, com tópicos por sessão, por conta e geral, e **nenhum por organização**. O plano propõe outro mecanismo (`live_socket_id`), anterior ao #1044 e em conflito com ele. Sem o aviso, a sessão comprometida, que motivou a suspensão, continua agindo na aba aberta | **sim**: `Suspensions` |
| **A3** | média | A07 · V2.2.1, V3.2 | `auth.ex:71` (o `with` retorna antes de qualquer `Bcrypt`); `contracts/credenciais-do-operador.md:16` | **oráculo de existência pela espera.** Quem está em espera recebe a recusa sem custo de hash, e quem não existe nunca entra em espera. Quatro tentativas erradas num e-mail, e a quinta responde instantânea só se a conta existir. O contrato lista os casos em que o hash roda e deixa a espera de fora. **O defeito existe hoje** nas contas de organização | **sim** (emenda de contrato) |
| **A4** | média | A07, A04 · V2.2.1, V11.1.4 | `contracts/credenciais-do-operador.md` (a espera é por conta); `grep remote_ip\|x-forwarded-for` em `lib/` e `config/` vazio; `config/prod.exs:14-15` (só `rewrite_on: [:x_forwarded_proto]`) | (a) **nenhum limite por IP**, e a aplicação nem conhece o IP do cliente: atrás do proxy do Dokploy, `remote_ip` é o do proxy. (b) **Negação de serviço do operador**: quem sabe o e-mail faz uma tentativa por janela e mantém a conta em espera. O `POST /platform/setup` conta no mesmo contador. Num `suspected_compromise`, quem ataca impede o operador de entrar para suspender | não; vira tarefa, com a pergunta 2 |
| **A5** | média | A07 · V2.3.1, V11.1.6 | `contracts/credenciais-do-operador.md:29-34` | **o código não é de uso único sob concorrência.** O contrato confere `sha256` em memória e depois grava. Dois `POST` com o mesmo código passam os dois, e vale a senha de quem confirmar por último. Quem leu o código no terminal do Dokploy (R1, "não verificado") corre junto do operador. As duas definições dão certo, e "o operador encontra o código consumido" (R1, tabela) deixa de valer como detecção | **sim**: `Credentials` |
| **A6** | média | A07 · V2.5.4, V3.3.1 | `contracts/concessao-do-operador.md:16-19` | **conceder de novo ressuscita a senha antiga.** `conceder/3` "cria o operador se não existir" e emite um código, mas não diz que apaga `password_hash`, sobe a época e encerra as sessões. O operador revogado, talvez por comprometimento, volta a entrar com a senha de antes no dia em que alguém conceder de novo. É o #1009 do operador | **sim**: `Grants` |
| **A7** | média | A09 · V7.1.3, V7.2.1 | `contracts/eventos-de-acesso.md:9-19` | **definir a senha não deixa rastro.** Há evento para a entrada, a espera, a concessão e o reinício, e **nenhum** para a definição aceita ou recusada (código errado, vencido, e-mail inexistente). É o caminho de tomada da conta, e o único que não se investiga | não; vira tarefa |
| **A8** | média | A04 · V1.4.1, V14.4 | research R3.2 (`:149`, "o cookie nem chega ao domínio"); `router.ex:31` | **`Path=/platform` não é fronteira contra script da mesma origem.** Um XSS em qualquer tela de domínio, onde todo texto vem do GitHub, roda na mesma origem. `fetch('/platform/organizations/x')` leva o cookie do operador: `SameSite` não barra mesma origem, e `http_only` não impede o uso. O script lê o CSRF do HTML e envia a suspensão. O isolamento depende de não haver XSS, o que hoje se apoia em `script-src 'self'` e no escape do HEEx. O research afirma um isolamento que é só de rede | não; risco declarado, pergunta 3 |
| **A9** | média | A01 · V1.4 (teste) | research R10 (`:325-328`) | **a guarda do SC-003 não pega o defeito que mais importa.** A lista permitida vale para **todas** as rotas `/platform/*` e inclui `user_sessions`. `Sessao.conferir/1` consulta `user_sessions` com `join` em `users` (`sessions.ex:190-198`), e o `source` da telemetria é a tabela do `from`. Se `OperatorScope` passar a ler a sessão de domínio, a guarda continua verde | **sim**: a tarefa do teste |
| **A10** | baixa | A09 · V7.1.1 | `deps/phoenix/mix.exs:72` (o filtro padrão é `["password", "token"]`, por substring); `deps/phoenix/lib/phoenix/router.ex:1436` (os parâmetros saem em `:debug`); nenhum `filter_parameters` em `config/` | se o campo do formulário se chamar `code` ou `codigo`, o código de definição sai em claro na linha `Parameters:` do log. Hoje isso só acontece em `:debug`, e `config/prod.exs:34` fixa `:info`. Mas configuração não é controle | não |
| **A11** | baixa | A07 · V3.3.2 | `data-model.md` §3; research R3.1 | o limite de 8 h é só absoluto, sem inatividade. O ASVS L2 pede reautenticação periódica **e** após inatividade (30 min). Para uma ou duas pessoas, uma coluna `last_seen_at` resolve | não |
| **A12** | baixa | A01 · V4.3 | `contracts/rotas-da-plataforma.md` ("corpo idêntico"); `router.ex:118-119` (o padrão da #943); `components/layouts/root.html.heex:6` | (a) um caminho inexistente sob `/platform` não casa rota, não passa pela pipeline `:plataforma` e sai sem CSP nem cookie de CSRF. O `404` de `require_operator` sai **com** os dois, e os cabeçalhos distinguem. (b) "Corpo idêntico" não se cumpre byte a byte, porque o `csrf-token` mascarado muda a cada resposta | não |
| **A13** | baixa | A04 · V1.11 | research R7; `data-model.md` §2 e §4 | (a) `TRUNCATE` passa por trigger de linha. Um `BEFORE TRUNCATE` por comando custa uma linha. (b) O `BEFORE UPDATE` precisa comparar **cada** coluna fora da revogação com `IS DISTINCT FROM`, que é seguro com nulo, e liberar `updated_at` em `tenant_suspensions`. (c) `platform_operators.email` é mutável sem registro, e a concessão não guarda o e-mail da época: o histórico perde **quem** recebeu o papel | não |
| **A14** | baixa | A07 · V2.5 | `contracts/credenciais-do-operador.md:26-34`; `contracts/concessao-do-operador.md:27-31` | `definir_senha/3` não exige concessão vigente, e `revogar/3` não apaga o código pendente. Hoje é inofensivo, porque `autenticar/2` exige a concessão, mas a defesa fica num só lugar | não |
| **A15** | baixa | A01 · V1.11 | research R8 | `reiniciar_credencial/2` encerra as sessões sem tocar a linha da concessão. Por isso o `FOR SHARE` da suspensão não serializa com ele, e uma suspensão em voo completa com a sessão que acabou de ser reiniciada. A janela é de milissegundos. O `FOR SHARE` também na linha da sessão fecha a brecha | não |
| **A16** | informativo | A07 · V2 (L2 ↔ AAL2, multifator) | O16; plan, pergunta 2 | sem segundo fator. Com A1 e A4 corrigidos, o risco que sobra é a senha do operador **reutilizada** ou capturada. O ASVS associa o nível L2 ao AAL2, que é multifator, e por isso a lacuna vai como **risco residual aceito**, com quem decidiu | não, se aceito na release |
| **A17** | informativo | A02 · V2.10 | research R1 ("não verificado") | o código aparece uma vez no terminal do Dokploy. Se quem opera o servidor **não** é a pessoa operadora, o código precisa ser transmitido a ela, e o caminho natural é o chat, que a regra da casa proíbe. O runbook precisa dizer que a pessoa operadora roda o comando ela mesma, ou recebe o código por voz | não |

**Dois defeitos existem hoje** e não são da 070: A1 e A3 em `TheBand.Tenants.Auth`, nas contas de
organização. A regra "corrigir antes de implementar" (CLAUDE.md) pede uma issue para cada um, com
label `security`. A 070 não pode **copiar** o defeito: é o momento mais barato de não tê-lo duas
vezes.

---

## 2. O detalhe dos achados que bloqueiam

### A1: a espera crescente não segura tentativas paralelas

- **O caminho do ataque.** O atacante sabe o e-mail do operador. O repositório é público, e
  e-mails de quem mantém aparecem nos commits. Ele dispara rajadas de, por exemplo, 30 `POST
  /platform/session` simultâneos a cada janela. `fora_da_janela/1` lê o `failed_attempts` da
  mesma linha em todas elas, todas testam a senha, e `registrar_falha/1` grava `n + 1` calculado
  em memória (`auth.ex:170`). As gravações se sobrescrevem. O teto prático deixa de ser "uma por
  60 s" e passa a ser a CPU do Bcrypt no VPS.
- **O que ele obtém.** A conta que suspende qualquer organização e enumera todas.
- **Por leitura, não medido.** Concorrência em teste exige `Task` com o sandbox em modo
  compartilhado. Esse é o teste abaixo, e ele ainda não existe.
- **A correção.** A tentativa lê a linha do operador com `SELECT … FOR UPDATE` dentro de uma
  transação que inclui a verificação e o registro. Com uma ou duas pessoas operadoras, serializar
  as tentativas de uma conta é o desenho mais simples, e não custa nada a quem é legítimo. A
  alternativa é o incremento atômico `UPDATE … SET failed_attempts = failed_attempts + 1 …
  RETURNING`, decidido **antes** do hash.
- **O que fica pior.** Uma transação segura o lock durante o Bcrypt, cerca de 250 ms com custo
  12, na linha de uma pessoa só.

### A2: a suspensão precisa avisar as telas abertas, e o mecanismo agora é o do #1044

- **O que existe.** O #1044 faz a hook inscrever o LiveView conectado em `"sessao:<id>"`,
  `"conta:<user_id>"` e `"sessoes"`. Ao receber `:sessao_encerrada`, a hook reconfere a sessão no
  banco, e o banco decide. Quem encerra **dentro de uma transação** avisa **depois do `commit`**:
  é o que o próprio #1044 escreve em `encerrar_da_conta/2`.
- **O que falta.** `encerrar_da_organizacao/1` roda dentro do `Multi` e não pode avisar. Ninguém
  avisa depois.
- **A emenda.**
  - Depois do `commit` de `suspender/3` e de `reativar/3`, publicar
    `Sessions.avisar_encerramento({:sessao, id})` para cada id que `encerrar_da_organizacao/1` já
    devolve. O contrato já diz que os ids servem a isso.
  - **Não** criar tópico por organização. O aviso por id alcança exatamente as telas das sessões
    encerradas, e não amplia o que cada socket escuta.
  - Retirar a proposta de `live_socket_id` de R9 e a pergunta 3 do plano. A pergunta foi
    respondida pelo #1044.
  - O #1044 entra como **pré-requisito** na tabela do plano, ao lado do #1038.
- **Sem a emenda.** A sessão que motivou a suspensão continua emitindo eventos de domínio pela
  aba aberta (rodar coleta, conceder escopo, gerar token) até o socket reconectar. A suspensão
  pararia o login e a navegação, e não pararia quem ataca.

### A5: o código é de uso único só sem concorrência

O consumo precisa ser uma operação atômica, numa destas duas formas:

- `SELECT … FOR UPDATE` da linha do operador, `secure_compare`, gravação e `NULL` no código,
  tudo na mesma transação;
- ou `UPDATE … SET setup_code_hash = NULL, … WHERE id = $1 AND setup_code_hash = $2 AND
  setup_code_expires_at > now()`, conferindo **uma** linha afetada.

Comparar o resumo no SQL não abre canal de tempo útil: quem ataca controla a pré-imagem, e não o
resumo.

### A6: conceder de novo

`conceder/3` sobre um operador que já existe, sem concessão vigente, faz o mesmo que
`reiniciar_credencial/2`, na mesma transação:

- `password_hash = NULL`;
- `password_epoch + 1`;
- encerra as sessões do operador;
- emite o código novo.

Revogar e conceder de novo **nunca** devolve credencial antiga.

### A9: a guarda do SC-003

- **A lista permitida passa a valer por rota.** Os `GET` de `/platform/*` aceitam
  `platform_operators`, `platform_operator_grants`, `platform_operator_sessions`,
  `tenant_suspensions` e `tenants`. Só os dois `POST` de ato aceitam também `user_sessions` e
  `api_access_tokens`.
- **Toda consulta reprova se o SQL citar `"users"`**, com aspas, como o Ecto gera, porque o
  `source` mostra só a tabela do `from`.
- **O defeito a injetar** passa a ser: `OperatorScope` chama `TheBandWeb.Sessao.conferir/1`. O
  teste precisa reprovar.

---

## 3. Item a item, contra o que foi pedido

| item | veredito | achados |
|---|---|---|
| código de definição: entropia, validade e resumo | correto | — |
| código: uso único sob concorrência | falha | A5 |
| código: para onde vai a saída | risco declarado, e incompleto quanto à transmissão | A17, A10 |
| `POST /platform/setup`: enumeração e força bruta | a força bruta é inviável (160 bits); enumeração só pela espera compartilhada | A3, A4 |
| senha: armazenamento | Bcrypt e 12 a 128 caracteres, igual à casa. O Bcrypt trunca em 72 bytes, e o limite de 128 caracteres não avisa. Sem conferência contra senha vazada (V2.1.7). Informativo | — |
| tentativas, mensagem única e tempo constante | a mensagem é única; o tempo vaza na espera; a espera se contorna por concorrência | A1, A3 |
| bloqueio | não há, e é certo. A espera por conta faz o papel de bloqueio para quem sabe o e-mail | A4 |
| sessão: tabela, resumo, 8 h, concessão por requisição | correto | A11 |
| FR-014, encerrar na revogação | correto na revogação; quase certo no reinício | A15, A6 |
| cookie: nome, `Path`, `SameSite`, `Secure`, cifrado | correto | A8 |
| CSRF | `protect_from_forgery` guarda o token no cookie **de domínio** (`_the_band_key`, `Path=/`). A única coisa compartilhada é o `_csrf_token`. Sair do domínio (`drop: true`) invalida o formulário aberto do operador, que dá 403 no envio. Afeta disponibilidade, não segurança | — |
| um cookie vaza para o outro lado? | `_the_band_operator` não chega ao domínio pela rede, mas chega por script da mesma origem. `_the_band_key` **chega** a `/platform` e não pode ser lido lá | A8, A9 |
| sair de um apaga o outro? | sair do operador não toca o domínio. Sair do domínio não encerra o operador, e invalida o CSRF dele | — |
| área por controller e `404` | correto no desenho; a forma do `404` distingue rota de não rota | A12 |
| página pública e limite por IP | a página pública é aceitável (o repositório é público, R0). **Não há** limite por IP, e não há IP real | A4 |
| transação, autorização relida | correta, com `FOR SHARE` | A15 |
| triggers | justificados; faltam três detalhes | A13 |
| PR #1044 | a suspensão **precisa** avisar, e o plano não prevê isso no mecanismo do #1044 | A2 |
| segundo fator (O16) | residual, e aceitável só com A1 e A4 fechados | A16 |

---

## 4. Emendas ao plano e aos contratos

1. **`contracts/credenciais-do-operador.md`**:
   - a tentativa serializada por `FOR UPDATE` na linha do operador (A1);
   - `Bcrypt.no_user_verify/0` também na espera, porque a espera **não** pula o custo (A3);
   - o consumo atômico do código (A5);
   - `definir_senha/3` exige concessão vigente (A14);
   - o nome do campo do formulário contém `token`, por exemplo `setup_token`, ou `config/config.exs`
     ganha `filter_parameters` com `"code"` e `"secret"` (A10).
2. **`contracts/concessao-do-operador.md`**:
   - conceder de novo apaga a senha, sobe a época e encerra as sessões (A6);
   - revogar apaga o código pendente (A14);
   - a concessão guarda o e-mail do momento (A13c).
3. **`contracts/eventos-de-acesso.md`**: `operador_senha_definida/1` e
   `operador_definicao_recusada/2`, com motivo `:codigo_errado`, `:codigo_vencido`, `:sem_codigo`
   ou `:identificador_nao_resolveu` (A7).
4. **research R9 e `contracts/suspensao.md`**: o aviso por id do #1044 depois do `commit`, em
   `suspender/3` e em `reativar/3`. A pergunta 3 do plano sai. O #1044 entra como pré-requisito
   (A2).
5. **research R10**: a lista por rota e a asserção sobre `users` (A9).
6. **`contracts/rotas-da-plataforma.md`**: um `match :*, "/platform/*caminho"` por último dentro
   do escopo da pipeline `:plataforma`, como `router.ex:118-119`. A asserção passa a ser status,
   cabeçalhos e corpo **sem o `csrf-token`** (A12).
7. **`data-model.md`**:
   - `last_seen_at` em `platform_operator_sessions`, com 30 min de inatividade (A11);
   - `BEFORE TRUNCATE` nas duas tabelas protegidas (A13a);
   - o `BEFORE UPDATE` com `IS DISTINCT FROM` por coluna (A13b).
8. **research R3.2**: trocar "o cookie nem chega ao domínio" por "o cookie não chega ao domínio
   pela rede; contra script da mesma origem, o isolamento é a CSP" (A8).
9. **`plan.md`, Riscos**: A8, A16 e A17 como riscos residuais, e as duas issues de A1 e A3 nas
   contas de organização.

---

## 5. Cenários de ataque para o QA

Cada cenário só vale se for **visto reprovar** com o defeito injetado. Fixture sem segredo real:
senha e código são strings óbvias de teste.

1. **A1, rajada paralela.**
   - Atacante: quem sabe o e-mail do operador.
   - Montagem: um operador com 3 falhas registradas e `last_failed_at` agora; 10 `Task` chamam
     `autenticar/2` com senha errada ao mesmo tempo.
   - Asserção: no máximo **uma** chega a registrar falha, porque `failed_attempts` sobe 1 e não
     10. As outras nove devolvem `{:throttled, _}`.
   - Guarda de que mediu: com a senha certa numa das dez e sem espera, ela autentica.
   - Defeito a injetar: retirar o `FOR UPDATE`. O teste precisa ver `failed_attempts` maior que 1
     a mais.
2. **A3, o relógio da espera.**
   - Montagem: um operador em espera, e um e-mail inexistente.
   - Asserção: as duas recusas chamam `Bcrypt.no_user_verify/0` ou `verify_pass/2`. Instrumentar
     por `:telemetry` ou por contagem, e não por cronômetro, que é instável em CI.
   - Defeito a injetar: retirar o hash da espera.
3. **A5, o mesmo código duas vezes.**
   - Montagem: duas `Task` chamam `definir_senha/3` com o mesmo código e senhas diferentes.
   - Asserção: exatamente uma devolve `{:ok, _}`, a outra devolve `{:error, :invalid_credentials}`,
     e `setup_code_hash` fica nulo.
   - Defeito a injetar: conferir em memória sem lock. As duas passam.
4. **A6, conceder de novo.**
   - Montagem: conceder, definir a senha, revogar, conceder de novo.
   - Asserção: `autenticar(email, senha_antiga)` devolve `{:error, :invalid_credentials}`, e
     `refute` de qualquer sessão de antes válida.
   - Defeito a injetar: não apagar `password_hash` em `conceder/3`.
5. **A2, a aba aberta da organização suspensa.**
   - Montagem: uma pessoa de A com `live/2` conectado em `/work`; suspender A pelo `POST` do
     operador.
   - Asserção: a próxima mensagem do LiveView é o redirecionamento para `/sign-in`, e um
     `render_click` depois disso não executa.
   - Guarda com dois tenants: um LiveView de B conectado continua respondendo.
   - Defeito a injetar: retirar o aviso depois do `commit`. A aba de A continua respondendo.
6. **A2, a reativação.** Mesma montagem, com uma sessão de A inserida durante a suspensão (a
   corrida O8) e uma aba conectada a ela. Reativar A derruba a aba.
   - Defeito a injetar: avisar só em `suspender/3`.
7. **A9, a área do operador não lê a sessão de domínio.**
   - Montagem: `GET /platform/organizations` com o cookie de um **admin de A** válido e **sem**
     cookie de operador.
   - Asserção: `404`, e nenhuma consulta cita `user_sessions` ou `"users"`.
   - Defeito a injetar: `OperatorScope` chama `Sessao.conferir/1`.
8. **A8, a mesma origem.** É teste de **configuração**, e não de exploração.
   - Asserção: toda resposta de `/platform/*` tem a CSP com `script-src 'self'` sem
     `'unsafe-inline'` e `frame-ancestors 'none'`, e `Cache-Control: no-store`.
   - Defeito a injetar: a pipeline `:plataforma` sem `put_secure_browser_headers`.
9. **A10, o código fora do log.**
   - Asserção: `Phoenix.Logger.filter_values(%{"setup_token" => "x"})` devolve `"[FILTERED]"`,
     ou o mesmo para o nome que o formulário usar.
   - Defeito a injetar: renomear o campo para `code`.
10. **A12, o `404`.**
    - Asserção: `GET /platform/organizations` anônimo e `GET /platform/nao-existe` têm o mesmo
      status, o mesmo conjunto de cabeçalhos de segurança e o mesmo corpo depois de retirar o
      `csrf-token`.
    - Defeito a injetar: retirar o curinga do escopo. Os cabeçalhos passam a diferir.
11. **A13, o registro.**
    - Asserções: `TRUNCATE platform_operator_grants` levanta; um `UPDATE` que preenche
      `revoked_at` **e** muda `granted_by_declared` levanta.
    - Defeito a injetar: o trigger de `UPDATE` comparando só `revoked_at`.
12. **A7, a definição registrada.**
    - Asserções: um código errado produz `operador_definicao_recusada` com `:codigo_errado`, em
      `:warning`, e o código não aparece em nenhuma linha capturada (`refute =~`).
    - Defeito a injetar: retirar a chamada.

Os cenários 1 a 9 de `seguranca.md` §4 continuam valendo onde a decisão (b) não os desfez. Os
cenários 3, 4, 5, 7, 8 e 9 valem; os cenários 1 e 2 mudam de forma, porque o operador já não é
`%User{}`, e o cenário 7 aqui o substitui na parte do leitor de sessão.

---

## 6. Perguntas para a pessoa mantenedora

**P1. O operador entra sem segundo fator nesta feature (A16, O16)?**

- (a) sim, como risco residual aceito na nota da release, **com A1, A3, A4 e A11 fechados** e a
  spec do TOTP aberta logo depois;
- (b) não: a 070 espera a spec do segundo fator.

**Recomendação: (a).** Com a espera serializada, o limite por IP e a inatividade de 30 min, o que
sobra é a senha reutilizada ou capturada. Para uma ou duas pessoas, isso cabe num risco declarado
por prazo curto. Sem A1 fechado, (a) **não** é recomendável.

**P2. Como a aplicação conhece o IP de quem chama (A4)?**

- (a) `Plug.RewriteOn` com `:x_forwarded_for`, confiando **só** no proxy do Dokploy. Antes,
  medir que o Traefik **sobrescreve** o cabeçalho, e não acrescenta. Com isso: limite por IP em
  `/platform/session` e `/platform/setup`, e a espera por conta passa a ser por conta e IP, o que
  fecha a negação de serviço;
- (b) uma lista de IPs permitidos para `/platform` no Traefik, fora da aplicação;
- (c) nada, e a A4 vira risco residual.

**Recomendação: (a), medida antes.** (b) é um bom complemento se a pessoa operadora tiver
endereço estável, mas fica fora do repositório e fora dos testes. Confiar em `X-Forwarded-For`
sem medir o proxy deixaria quem ataca escolher o próprio IP, e isso seria pior que (c).

**P3. A área do operador fica na mesma origem das organizações (A8)?**

- (a) sim, agora, com o risco declarado. A defesa é a CSP de `router.ex:28-39`, que a pipeline
  `:plataforma` reaproveita;
- (b) um host próprio (por exemplo, `platform.<domínio>`), com cookie só desse host, quando
  `theband.dev` entrar em produção.

**Recomendação: (a) agora, e (b) registrada como próxima etapa.** Hoje a produção está num
endereço `sslip.io`, e um host próprio exigiria DNS e certificado novos, fora do escopo da 070.
Enquanto a área estiver na mesma origem, afrouxar `script-src` vira, por consequência, achado alto
**também** para o operador.

---

## 7. O que NÃO verifiquei

- **Nada em execução.** Não rodei `mix test`, `mix gates`, `mix sobelow`, `mix hex.audit` nem
  `mix deps.audit`: o banco de teste estava em uso, e a instrução era não rodar. A1, A2 e A5 são
  **por leitura**. A1 depende de concorrência real, e os cenários 1, 3 e 5 são a medição.
- **O terminal do Dokploy**: se guarda a saída do `eval`, quem tem acesso a ela, e se o `eval`
  pode ser agendado com a saída persistida (A17).
- **O proxy do Dokploy (Traefik)**: se sobrescreve ou acrescenta `X-Forwarded-For` (P2).
- **O #1044 inteiro.** Li o diff de `lib/`, e não o teste dele nem a sua revisão. Ele está aberto,
  e a forma pode mudar antes do merge. A emenda A2 segue a forma de hoje.
- **XSS nas telas de domínio.** A8 é condicional. Não varri as telas atrás de `raw/1`; a última
  medição disso não é desta passagem.
- **O custo do Bcrypt em produção.** Assumi o padrão de 12 rodadas. Só `config/test.exs` fixa o
  valor, e não li a configuração de runtime do release.
- **A `ApiTokenLive` e a escrita do autor "revoked when the organisation was suspended"**: não
  conferi se a tela trata `revoked_by_user_id` nulo sem `FunctionClauseError`.
- **O que `seguranca.md` já listava como não verificado** continua não verificado: as telas
  LiveView uma a uma, as ferramentas da MCP e o banco de produção.

## Decisões da pessoa mantenedora, 2026-10-01

| Pergunta | Decisão | Efeito |
|---|---|---|
| 1. Segundo fator (O16) | **TOTP nesta feature**, contra a recomendação de deixar para depois | O plano ganha o segundo fator do operador: segredo TOTP cifrado em repouso (Cloak, como as credenciais), cadastro na definição da senha, conferência a cada entrada, códigos de recuperação de uso único guardados só como hash, e janela de ±1 passo com proteção contra reuso do mesmo código. A biblioteca, se houver (por exemplo NimbleTOTP, ou RFC 6238 sobre `:crypto`), precisa da pesquisa de dependência do AGENTS §3 e de uma avaliação de segurança própria antes do código |
| 2. IP do cliente | **Medir o Traefik, depois `Plug.RewriteOn`** | Pré-requisito com medição: confirmar em produção que o Traefik do Dokploy **sobrescreve** `x-forwarded-for`, e não acrescenta. A medição precisa de acesso ao servidor e é da pessoa mantenedora. Sem ela, o limite por IP não entra, e fica só a espera por conta (#1046) |
| 3. Origem | **Mesma origem + CSP** | A8 fica declarado como risco residual. A CSP entra como defesa, e o host próprio vem quando `theband.dev` entrar em produção |

Defeitos que existem hoje e vêm antes da feature: A1 virou a #1046 e A3 virou a #1047.

---

## Conferência das emendas (T008, 2026-10-01)

**Papel**: Security, que **não** escreveu as emendas. **Base lida**: o worktree da 070 em
`61d6098`; `origin/development` em `0891244` (com o #1044 mergeado às 22:37Z); os diffs abertos do
PR #1048 (#1046) e do PR #1049 (#1047), por `gh pr diff`. **Por leitura**: não rodei teste, gate
nem banco.

### Veredito por achado

| id | veredito | onde está, e o que conferi |
|---|---|---|
| **A1** | **coberto, depois de corrigido aqui** | `credenciais-do-operador.md`, "Tentativa serializada": `FOR UPDATE` antes da espera e do hash, para senha, código de definição, código de cadastro e segundo fator; o segundo fator conta no mesmo contador. Conferido contra o #1048: escolheu `FOR UPDATE` (`verificar_com_trava/2`, `conta_travada/1`), e não o incremento com `RETURNING`, então a cópia segue `FOR UPDATE`. **Faltava**: dizer que a recusa **confirma** a transação. Com `Repo.rollback/1` na recusa, o `failed_attempts + 1` seria desfeito e a espera voltaria a não contar. Acrescentado ao contrato |
| **A2** | coberto | `suspensao.md` (aviso por id depois do `commit`, em `suspender/3` e `reativar/3`, sem tópico por organização); `sessoes-e-tokens-da-organizacao.md` (`encerrar_da_organizacao/1` devolve os ids e não avisa); research R9 (sem `live_socket_id`). Conferido em `development`: `avisar_encerramento({:sessao, id})` publica `:sessao_encerrada` em `"sessao:"<>id` (`sessions.ex:147`), a hook inscreve o socket nesse tópico (`hooks.ex:136-140`) e reconfere no banco, inclusive `organizacao_ativa/1` (`hooks.ex:151-161`, `:174-175`). Na suspensão a tela cai por dois motivos, `ended_at` e `status` |
| **A3** | **coberto, depois de corrigido aqui** | `credenciais-do-operador.md`: `no_user_verify/0` antes de `{:throttled, _}`, e todos os casos pagam o hash. Conferido contra o #1049: `Bcrypt.no_user_verify()` no ramo da espera de `fora_da_janela/1`. **Faltava**: o oráculo pela **mensagem**. Só conta que existe entra em espera, e o contrato devolvia `{:throttled, s}` sem dizer como a tela o mostra. Acrescentado: a espera sai com a mesma frase, status e destino de `:invalid_credentials`, sem os segundos, como `session_controller.ex:10-11` e `:36-37` de `development`. Também em `rotas-da-plataforma.md`, "Respostas" |
| A4 | coberto como pendência declarada | `rotas-da-plataforma.md` (sem limite por IP até a medição do Traefik); plan, Riscos; tasks T004 e T043. A negação de serviço pela espera continua aberta, e é para estar |
| **A5** | coberto | `credenciais-do-operador.md`: consumo atômico do código de definição e do de cadastro, dentro do `FOR UPDATE`; `segundo-fator-do-operador.md`: código de recuperação por `UPDATE … WHERE used_at IS NULL … RETURNING`, conferindo uma linha. O TOTP errado não consome o código de cadastro, e conta falha. Aceitável: são 160 bits, e a espera vale |
| **A6** | coberto | `concessao-do-operador.md`: conceder de novo apaga `password_hash`, sobe a época, apaga o segredo TOTP e o passo, marca os códigos de recuperação como usados, anula o código de cadastro e encerra as sessões. `data-model.md` §1a sustenta o `used_at` |
| A7 | coberto | `eventos-de-acesso.md`: `operador_senha_definida/1` e `operador_definicao_recusada/2` com os quatro motivos pedidos e `:sem_concessao`; e o par do cadastro do segundo fator. O que não vai para o log inclui código, segredo e TOTP |
| A8 | coberto | `rotas-da-plataforma.md` (CSP na pipeline, `no_store`); research R3.2 com a frase emendada; plan, Riscos, como residual da decisão 3 |
| **A9** | coberto | research R10: lista permitida por rota, só os dois `POST` de ato com `user_sessions` e `api_access_tokens`; reprova se o SQL citar `"users"`; `source` nulo reprova; defeito a injetar `OperatorScope` chamando `Sessao.conferir/1`. Conferido que o defeito seria pego: o `por_id/1` de `development` faz `join: u in User` no `from(s in UserSession)` (`sessions.ex:222-232`). **A linha citada em R10 está velha** (`:190-198`) |
| A10 | coberto | `credenciais-do-operador.md`: `password`, `setup_token`, `enrollment_token` e `second_factor_token`, mais `filter_parameters` com `"code"`, `"secret"` e `"totp"`; tasks T016 e T039 |
| A11 | coberto | `data-model.md` §3 (`last_seen_at`, 30 min); `sessao-do-operador.md` (`:inativa`, gravação no máximo por minuto) |
| A12 | coberto | `rotas-da-plataforma.md`: curinga por último no escopo da pipeline; a asserção sem o `csrf-token` |
| A13 | coberto no `data-model.md`, com **research R7 desatualizado** | (a) `nao_trunca` nas duas tabelas; (b) `IS DISTINCT FROM` por coluna, liberando `updated_at` em `tenant_suspensions`; (c) `email_at_grant`. O último parágrafo de R7 ainda diz que `TRUNCATE` não dispara trigger de linha "e nada trunca", como se fosse a razão de não ter o trigger. Contradiz o `data-model.md`, e quem ler só R7 conclui o contrário |
| A14 | coberto | `credenciais-do-operador.md`: `definir_senha/3` e `confirmar_segundo_fator/3` exigem concessão vigente; `concessao-do-operador.md`: `revogar/3` anula o código de definição e o de cadastro |
| A15 | coberto | `suspensao.md`: `FOR SHARE` na linha da sessão e na concessão; `concessao-do-operador.md`: `reiniciar_credencial/2` faz `FOR UPDATE` nas sessões antes de encerrar. A tabela de research R8 ainda descreve só a concessão com `FOR SHARE`. É ambíguo, e não errado |
| A16 | superado pela decisão 1 | o TOTP entrou (FR-016, `segundo-fator-do-operador.md`, research R13). O que sobra é o aparelho do segundo fator, nos Riscos do plano. A avaliação **própria** do TOTP continua pendente, e é ela que fecha este item |
| A17 | coberto | plan, Riscos (o runbook: a pessoa operadora roda o comando, ou recebe por voz, nunca por chat); tasks T059 e T062 |

**Dos seis bloqueantes**, A2, A5, A6 e A9 estavam cobertos como estavam. A1 e A3 estavam cobertos
no mecanismo e abertos numa borda. Os dois contratos foram corrigidos nesta passagem.

### O que mudou nos contratos

- `contracts/credenciais-do-operador.md`, nas regras gerais:
  - a nota de que o #1048 escolheu `FOR UPDATE`;
  - a regra de que a recusa confirma o registro da falha, e o único `ROLLBACK` é o do changeset
    (A1);
  - a regra de que `{:throttled, _}` chega à tela igual a `:invalid_credentials` (A3).
- `contracts/rotas-da-plataforma.md`, "Respostas": a linha da espera nos três `POST` públicos (A3).

### O que fica, e não é deste papel corrigir

- **`plan.md`**, sem edição minha, porque outro agente o edita:
  - a tabela "superfície de risco" (`:30-31`) ainda manda a O16 para "pergunta 2" e o LiveView
    aberto para "pergunta 3". As duas já foram decididas;
  - a linha da #1047 nos pré-requisitos (`:65`) diz "PR não aberto". O PR é o **#1049**, aberto;
  - a pergunta 1 aparece como "aberta", e o commit `61d6098` registra a FR-011 emendada (T005).
    `rotas-da-plataforma.md` repete "a decisão ainda é da pessoa mantenedora".
- **research R7**: o parágrafo do `TRUNCATE` precisa dizer que o trigger existe (A13a).
- **research R8**: a linha `:autorizacao` precisa dizer "a sessão **e** a concessão com
  `FOR SHARE`" (A15).
- **research R10**: trocar `sessions.ex:190-198` por `:222-232`, e
  `sessoes-e-tokens-da-organizacao.md` cita `encerrar_da_conta/2` em `:158-169`, que hoje está em
  `:188-198`. São referências deslocadas pelo #1044, e não mudam o desenho.
- **O aviso do #1044 só alcança o nó que publica** (`sessions.ex:212-213`, comentário de
  `girar_todas/0`). A suspensão roda no `POST` do nó que serve, então a tela cai. Se um dia houver
  um ato de plataforma por `eval`, ou mais de um nó sem cluster, a A2 volta. Hoje não há nenhum
  dos dois.
- **Os bloqueios de código continuam**: a avaliação própria do TOTP, os PRs #1048 e #1049 ainda
  abertos, e o protótipo. Se a revisão mudar a forma de algum dos dois PRs, esta conferência precisa
  ser refeita para A1 ou A3.

### O que NÃO conferi

- Os testes dos PRs #1048 e #1049: li só o diff de `lib/`. Também não conferi se o
  `Repo.transaction` do #1048 roda o `no_user_verify` do #1049 **dentro** do lock. Pela leitura
  dos dois, roda: a espera segura a linha por cerca de 250 ms. Isso mede custo, e não segurança.
- O `quickstart.md` e o `tasks.md` além das linhas que citam os achados.
- `spec.md`: se a FR-016 e a FR-011 emendada dizem o mesmo que os contratos.
- Nada em execução. Os cenários 1, 3 e 5 da §5 continuam sendo a medição de A1, A5 e A2.

## Conferência das emendas D1 (2026-10-01)

Feita pelo agente `security`, que não escreveu as emendas, sobre o commit `9ec8d1d` (achado D1 do
`/speckit-analyze`): `contracts/sessoes-e-tokens-da-organizacao.md` (as três funções novas de
`TheBand.Tenants`), `contracts/suspensao.md`, research R8 e R10, e as tarefas T038a, T040, T041,
T046a, T049, T050 e T053. Foi leitura de documento e de `lib/` em `9ec8d1d`. Nada rodou.

**Veredito: nenhum ponto bloqueante falhou, e o contrato não mudou.** Ficam dois achados médios
e duas recomendações baixas, para o Product Owner decidir prazo.

### Veredito por ponto

| ponto | veredito | como foi verificado |
|---|---|---|
| (1) `trocar_estado_no_multi/5` abre um caminho para trocar o estado sem episódio, sem autorização ou fora do `Multi` | **não abre um caminho novo**; a guarda por `xref` basta para *esta* função, e não basta para o invariante (D1-a) | o contrato só deixa a função existir como passo de um `Multi` de quem a chama, sem variante que grave sozinha; os pares são só dois e qualquer outro dá `FunctionClauseError`; a condição de estado fica no `WHERE`. Em R8, `:autorizacao` (com `FOR SHARE` na sessão e na concessão) é o **primeiro** passo, e `:estado` vem depois dele na mesma transação; `:episodio` vem depois de `:estado`, e a falha dele desfaz a troca. Na reativação, zero linhas no `:episodio` dão `:sem_episodio_aberto` e também desfazem a troca. T049 exige que nenhuma recusa mude o estado, inclusive `:nao_autorizado` |
| (2) as leituras públicas vazam além das quatro colunas, ou alcançam domínio | **não vazam**; uma recomendação (D1-b) | `tenant.ex:19-26`: a tabela tem só `id`, `name`, `slug`, `status` e os dois timestamps, nenhum campo cifrado nem de pessoa. O contrato devolve mapa, sem `join` nem contagem, e não lê `tenant_suspensions`. T038a afirma que as chaves são *exatamente* as quatro, e o defeito a injetar (`Repo.all(Tenant)` sem `select`) reprova as duas asserções. R10 reprova nos `GET` um `SELECT` de `tenants` que cite `inserted_at`/`updated_at`, o que pega a struct inteira; a coluna nova que alguém puser no `select` é pega pela asserção de chaves de T038a. A guarda de `"users"` no SQL continua valendo em toda rota `/platform` |
| (3a) A2, o aviso às telas abertas depois do `commit` | **não afetado** | a troca de estado não avisa e não encerra sessão; os ids continuam vindo do passo `:sessoes`, e o aviso continua depois do `commit` (suspensao.md, R9). A hook reconfere `organizacao_ativa/1` (`hooks.ex:138`), que lê `tenant.status`, e o `status` muda na mesma transação de `ended_at`: depois do `commit`, a tela cai pelos dois motivos, como antes. Os três defeitos de T053 continuam os certos |
| (3b) A15, o `FOR SHARE` na sessão e na concessão | **não afetado** | `:autorizacao` não mudou nem de forma nem de posição. O `UPDATE` em `tenants` pega um lock de linha que não conflita com o `FOR SHARE` das tabelas `platform_*`. Duas suspensões paralelas: a segunda espera o lock da linha de `tenants`, o `WHERE status = 'active'` é reavaliado na linha já confirmada, dá zero linhas e vira `:ja_suspensa` |
| (3c) T3 (seguranca-totp.md, a rotação da chave não alcança `totp_secret`) | **não afetado** | `tenants` não tem coluna cifrada (`tenant.ex:19-26`), e D1 não toca o Cloak nem `mix the_band.rotate_key` |
| (3d) os defeitos a injetar de T038a, T046a, T049 e T050 | **certos**, com uma lacuna em T046a (D1-c) | T046a: tirar `status == ^de` faz a segunda troca gravar e reprova; chamar a função de um módulo de rascunho reprova o `xref`. T049 e T050: um caso por retorno, e o passo que recusou afirmado pelo nome no `Multi`, que é o que prova `:estado_mudou → :ja_suspensa/:nao_suspensa` |

### Os achados

**D1-a — média (A04 · V1.11, V4.1.3). O `xref` guarda a função, e não guarda o invariante.**
O que precisa valer é *"`tenants.status` só muda com episódio"* (O10, SC-002). O `xref` prova que
só `Platform.Suspensions` chama `trocar_estado_no_multi/5`. Ele **não** pega outra escrita do mesmo
estado: `Ecto.Changeset.change(tenant, status: "suspended")` e `force_change/3` passam por fora
do `cast`, e um `Repo.update_all(Tenant, set: [status: …])` em qualquer módulo também. O `xref`
também não vê `apply/3` nem `eval` de release. Hoje não existe nenhuma dessas escritas: os dois
escritores de `tenants` em `lib/` são `create_tenant/1` (`tenants.ex:84-85`) e `bootstrap.ex:155`,
e os dois só criam a linha. Por isso o achado é de desenho, e não de exploração.
- **Caminho**: quem tem acesso a commit (ou ao `eval` de release) suspende ou reativa uma
  organização sem episódio. A tela do operador mostra `suspended` sem histórico, e
  `:sem_episodio_aberto` passa a ser alcançável, o que o contrato hoje chama de "só possível por
  escrita externa".
- **A capacidade que só a `Platform` produz não resolve.** Em Elixir, uma struct não é opaca:
  `%TheBand.Platform.Autorizacao{}` pode ser escrita literalmente em qualquer módulo, então ela
  protege tanto quanto o `xref`. E ainda faria `Tenants` depender de um tipo da `Platform`, que é
  a direção que o princípio X, letra D proíbe.
- **O que fecha**: um invariante no banco. Um trigger de constraint `DEFERRABLE INITIALLY
  DEFERRED` em `tenants` e em `tenant_suspensions` que recusa o `commit` quando
  `status = 'suspended'` e não há episódio aberto, ou quando `status = 'active'` e há. Ele vale
  para todo caminho, inclusive `eval`. É adiado porque, em R8, `:estado` vem antes de `:episodio`.
  **Cenário para o QA**: dentro de uma transação, `Repo.update_all` direto em `tenants.status`
  sem episódio; o `commit` precisa ser recusado. Defeito a injetar: tirar o trigger, e o `commit`
  passa.
- **Se não entrar agora**: o O10 continua coberto pelo `CHECK`, pelo `cast` sem `:status` e pelo
  `xref`. Essas três defesas dependem de quem escreve código lembrar. A decisão é do Product
  Owner; a data-model.md teria de ganhar o trigger, com a tarefa e o teste correspondentes.

**D1-b — média (A01 · V4.1.3). As leituras de resumo são leituras de todas as organizações, e
nenhuma guarda impede um chamador de domínio de usá-las.** `resumos_para_a_plataforma/0` não
recebe tenant, por desenho: é o escopo da plataforma. Se um LiveView de domínio a chamar, uma
pessoa da organização A passa a ver nome, slug e estado de B. `list_tenants/0` já tem a mesma
forma e é chamada por `profiles/automation.ex:105` e por uma tarefa mix, então o risco não é novo.
Mas a função nova existe **para** a área do operador, e o contrato não a amarra ao chamador como
amarra a escrita.
- **O que fecha**: o mesmo teste de `xref` de T046a, estendido às duas leituras em T038a, com
  `TheBand.Platform.Suspensions` como único chamador em `lib/`. Defeito a injetar: chamar a leitura
  de um módulo de domínio de rascunho, e o teste reprova.
- Não é bloqueante: nenhum chamador de domínio existe, e o dado (nome e slug de organização
  cliente) é o de menor sensibilidade entre os de outro tenant.

**D1-c — baixa. Em T046a, o "fora do `Multi`" não tem um defeito a injetar com nome.** O risco
que o contrato descreve é a troca se confirmar sem o resto da transação. A forma concreta disso é
a função executar o `update_all` **na hora em que monta o `Multi`**, e não dentro de um
`Multi.run`. A frase de T046a *"com um passo seguinte que falha, o estado volta"* pega esse
defeito, mas o defeito não está listado, e uma guarda só vale quando foi vista reprovando
(§14.0). **O que fecha**: em T046a, um terceiro defeito a injetar: o `update_all` executado na
construção do `Multi`, e o caso do `ROLLBACK` tem de reprovar.

**D1-d — informativo. O `%Tenant{}` chega à `Platform`.** A tabela "O que a API NÃO expõe"
exclui `%Tenant{}` da *área do operador*. Mas `Platform.Suspensions` recebe a struct de
`Tenants.fetch/1` (`tenants.ex:72-78`, um `Repo.get` sem `preload`) e do resultado do passo
`:estado`. Isso é aceitável **se** a struct não sair de `Suspensions`: `suspender/3` e
`reativar/3` devolvem `Suspension.t()`, e a guarda de `"users"` de R10 vale também para os `POST`
de ato. Vale que T049 afirme isso. Não é contradição do contrato, e não muda nada.

### O que mudou nos contratos

Nada. Nenhum ponto bloqueante falhou. D1-a, D1-b e D1-c são recomendações para o `tasks.md` e,
no caso de D1-a, para a `data-model.md`. Ficam abertos até serem corrigidos ou explicitamente
aceitos pelo Product Owner.

### O que NÃO conferi

- **Nada rodou**: nem `mix xref callers`, nem os testes. Não conferi que `mix xref callers` existe
  e tem essa forma na versão de Elixir do projeto. T032 usa o mesmo mecanismo, e a conferência é
  de quem o implementar.
- Afirmo o comportamento do `UPDATE` concorrente (a reavaliação do `WHERE` em `READ COMMITTED`)
  pelo que o PostgreSQL documenta. Não o medi. O cenário 3 de `seguranca.md` §4 é a medição.
- `spec.md`, `plan.md` e `quickstart.md` além do que cita D1. Também não conferi as outras
  correções do mesmo commit (O1, S1, S4 e os achados médios e baixos).
- Busquei em `lib/` as escritas em `tenants` pelos padrões `Tenant.changeset`,
  `update_all(Tenant` e `change(tenant`. Não fiz uma leitura arquivo a arquivo: uma escrita por
  SQL cru com outro texto não seria encontrada.
