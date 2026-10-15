# Avaliação de segurança antes do código: `TheBand.Release.separar_papeis/0` (#1131, opção B)

Agente `security`. Leitura feita em `origin/development` (fetch de 2026-10-10), sem trocar a branch
do diretório principal. Nenhum código de produção escrito, nenhum gate rodado: esta é uma avaliação
de desenho, e não de implementação.

Arquivos lidos: `lib/the_band/release.ex`, `lib/the_band/papeis.ex`, `rel/entrypoint.sh`,
`rel/env.sh.eex`, `docs/producao/runbook.md` §14,
`docs/producao/scripts/separar-papeis-quando-o-dono-e-postgres.sql`,
`specs/071-papeis-do-banco/spec.md` (FR-001 a FR-012), `seguranca-1140.md` (títulos dos achados),
`test/the_band/release_papeis_test.exs` (começo), issue #1131 com os comentários.

## Veredito

**Recomendo ficar com A, emendada** (o roteiro SQL do PR #1430, com as senhas definidas por
`\password` do `psql` em vez de coladas no texto). B não é recusada: é aceitável **se e somente se**
as condições C1 a C9 abaixo forem bloqueantes do PR. As razões:

| critério | A (roteiro, `psql` no contêiner do Postgres) | B (`separar_papeis/0` no release) |
|---|---|---|
| ensaio | **ensaiado** em 2026-10-09 (81 tabelas, 43 funções; conferência "em vigor"; `DISABLE TRIGGER` recusado) | reimplementação do roteiro em Elixir: o ensaio não vale para ela e precisa ser refeito |
| tempo até fechar o defeito em produção | hoje: é ato da pessoa mantenedora | spec/FR, contrato, testes, PR, revisão independente, release e só então o ato |
| credencial de superusuário no contêiner que serve | **não entra**: o `psql` do contêiner do Postgres conecta pelo socket local | entra no contêiner da aplicação (mitigável, ver P2) |
| código privilegiado permanente no release | nenhum | uma função que cria papéis e transfere posse, chamável por qualquer `eval` daqui para frente |
| senha das duas contas | `\password` faz SCRAM no cliente: nada no histórico, nada no log do servidor | gerada e impressa (ver P1); exige SCRAM no Elixir para ter a mesma garantia |
| erro humano (senha não hex, base errada, esquecer a concessão) | possível; mitigado pelas quatro conferências | eliminável por código e testável em CI, que é a vantagem real de B |
| repetível em instalação nova | cópia manual do roteiro | sim, e é o único argumento de B que não é conveniência |

Ponderando pelo `CLAUDE.md` (exposição ativa > defeito conhecido > feature): hoje quem serve é
superusuário, e isso é **defeito de segurança conhecido em produção**. O caminho que o fecha mais
cedo, com o artefato já ensaiado e sem nova superfície no release, é A. B só se justifica pelo que
vem depois: instalação nova, ou por uma dificuldade operacional concreta de rodar `psql` no
Dokploy, que não está registrada em lugar nenhum que eu tenha lido. Se esse impedimento existe, ele
é o motivo legítimo de B, e deveria ficar escrito na spec.

### A emendada, em três linhas

1. no roteiro, `CREATE ROLE ... LOGIN ...` **sem** `PASSWORD`;
2. dentro da mesma sessão do `psql`, depois do `COMMIT`: `\password the_band_owner` e
   `\password the_band_app`. O `psql` pede a senha sem eco, calcula o verificador SCRAM no cliente e
   manda só o hash. A senha não vai para `~/.psql_history`, nem para o log do servidor, nem para a
   tela;
3. a senha vem de `openssl rand -hex 32`, gerada no computador da pessoa, colada no prompt e no
   painel do Dokploy. Nunca no chat.

## Superfície

| o que B introduz | onde |
|---|---|
| uma função pública no release que executa `CREATE ROLE`, `ALTER ... OWNER`, `ALTER SCHEMA/DATABASE OWNER` | `lib/the_band/release.ex` |
| uma variável nova, `DATABASE_ADMIN_URL`, com credencial de **superusuário** | ambiente do processo `eval`; corre o risco de parar no painel |
| duas senhas novas, geradas ou recebidas | stdout do terminal do Dokploy |
| uma conexão de superusuário a partir do contêiner da aplicação | rede interna do Dokploy |
| um exemplo de `ACCESS EXCLUSIVE` em toda tabela, numa transação | o banco de produção, com a aplicação servindo |

E uma mudança de contrato: o FR-007 da 071 diz que "nenhum comando de release lê a variável que
migra". `DATABASE_ADMIN_URL` não é a variável que migra, mas é **mais forte** que ela. Ela precisa de
FR próprio na `spec.md`. Não é detalhe de implementação.

## Cenários de ataque

| # | atacante, o que já tem | o que obtém sem defesa | defesa exigida |
|---|---|---|---|
| X1 | execução de código como `band` (RCE pela aplicação) **depois** da troca | chama `separar_papeis/0` por `rpc` ou dentro do nó; se a função cai no `TheBand.Repo` quando falta a URL de admin, roda com `the_band_app` e falha com `42501`, o que é inofensivo. Mas se `DATABASE_ADMIN_URL` estiver no ambiente do servidor (posta no painel "para facilitar"), o nó de `band` a herda: `como_band` e o `exec` final só tiram `DATABASE_MIGRATION_URL` | C1, C2, C3 |
| X2 | o mesmo RCE como `band`, **antes** da troca | nada novo: `DATABASE_URL` já é superusuário. B não piora o estado de hoje, e é por isso que o estado de hoje é o defeito | — |
| X3 | quem lê a tela ou o histórico do terminal do Dokploy | a senha do dono, que dá migração e, com ela, desligar as guardas | P1: imprimir só uma vez, e nada de senha em argumento |
| X4 | quem lê o log do PostgreSQL | a senha em claro, se ela for como literal em `CREATE/ALTER ROLE ... PASSWORD '...'` e o comando falhar (`log_min_error_statement = error`, o padrão) ou se `log_statement` estiver ligado | C5: verificador SCRAM calculado no Elixir; o servidor nunca vê a senha em claro |
| X5 | operador distraído, sem má-fé | roda com a URL de admin apontando para a base `postgres`: transfere a posse na base errada, imprime "em vigor" no lugar errado | C6: recusar se a base da URL de admin não é a base de `DATABASE_URL` |
| X6 | operador roda de novo, com o painel já trocado | senhas regeneradas derrubam a aplicação, que tem as antigas no painel; ou passa a imprimir senha nova sem que ninguém precise | C7: rodar de novo **nunca** altera senha |
| X7 | quem tem o painel e lê `docker inspect` | a senha do `postgres`, que esteve em `DATABASE_URL` até hoje e continua a mesma depois da separação | R1 (vale para A e B): girar a senha do `postgres` depois |

## As perguntas, uma a uma

### P1 — As senhas dos dois papéis

**Decisão recomendada para B: geradas pela função, impressas uma vez, e nunca recebidas.**

- `:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)`: 64 hexadecimais. Isso cumpre o S6
  (só `0-9a-f`, que não quebra a URL) por construção, em vez de depender de quem digita;
- o servidor recebe **só o verificador SCRAM-SHA-256** (`SCRAM-SHA-256$4096:<sal>$<StoredKey>:<ServerKey>`,
  com `:crypto.pbkdf2_hmac/5` e `:crypto.mac/4`, disponíveis no OTP 29 da imagem). A senha em claro
  nunca sai da VM `eval`;
- a impressão é **uma vez**, as duas URLs completas prontas para colar (o conteúdo do File Mount e
  o novo `DATABASE_URL`), com host, porta e base derivados de `DATABASE_URL`, e a frase "não serão
  mostradas de novo". É o mesmo padrão de `imprimir_codigo/1` do operador (spec 070).

Por que não as alternativas:

| alternativa | defeito |
|---|---|
| senha em argumento do `eval` | vai para `argv`: `ps` mostra a qualquer usuário do contêiner, inclusive `band`; e vai para o histórico do shell |
| senha em variável na mesma linha (`SENHA_APP=... the_band eval`) | fora do `ps` (o `environ` é 0400 do dono), mas no histórico do shell; e quem digitou a gerou fora da função, com o risco de não ser hex |
| senha lida de arquivo | alguém precisa escrever o arquivo: a senha passa pelo terminal do mesmo jeito, e sobra um arquivo para apagar |

O que a impressão **não** resolve, e precisa ficar declarado: a saída do terminal web do Dokploy
fica no `scrollback` do navegador, e **eu não sei se o Dokploy guarda a sessão do terminal**. A
saída de `docker exec` não vai para o `docker logs` do contêiner (só o PID 1 vai), mas isso também
precisa ser medido, e não suposto.

Se a sessão cair entre a impressão e a colagem, a senha se perde. Isso **não** autoriza regenerar
sozinha ao rodar de novo (C7). O caminho é explícito: um `\password` manual, ou uma segunda função
`redefinir_senha_do_papel/1` com o mesmo contrato, e só se aparecer a necessidade. Hoje não aparece.

### P2 — A credencial de superusuário no histórico, `ps` e `docker exec`

- **Antes da troca no painel**, `DATABASE_URL` do contêiner **já é** o `postgres` superusuário. O
  comando recomendado não digita segredo nenhum:
  `DATABASE_ADMIN_URL="$DATABASE_URL" /app/bin/the_band eval 'TheBand.Release.separar_papeis()'`.
  O histórico guarda o texto `$DATABASE_URL`, e não o valor. O `ps` não mostra variáveis de ambiente
  de processos de outro usuário, e o `environ` é só de root;
- por isso a ordem é obrigatória: **separar → conferir → trocar o painel → reimplantar**. Depois da
  troca, a URL de admin teria de ser digitada, e aí o histórico a guarda;
- "ler de arquivo e apagar" não melhora: o arquivo é escrito pelo terminal do mesmo jeito, e em
  `/run` (que não é tmpfs nesta imagem, como medido no B5 da #1162) o apagado não é destruído;
- a alternativa A não tem esse problema: o `psql` roda no contêiner do Postgres, pelo socket local,
  e a credencial de superusuário não atravessa para o contêiner da aplicação.

### P3 — Rodar duas vezes

Idempotente, e com efeito zero sobre credenciais:

- papel existe → não é criado, **e a senha não é tocada**. A frase diz `papéis já existiam; senhas
  NÃO alteradas`;
- papel existe com atributo perigoso (`SUPERUSER`, `CREATEROLE`, `CREATEDB`, `REPLICATION`,
  `BYPASSRLS`) ou `the_band_app` membro de `the_band_owner` → **recusa e não corrige**. Quem criou
  isso à mão precisa saber; corrigir em silêncio esconde de onde veio;
- posse já é de `the_band_owner` → os laços não encontram nada (o roteiro já filtra
  `<> 'the_band_owner'`, menos o laço de tabelas, que precisa do filtro também);
- a concessão (C8) é idempotente por desenho em `Papeis.conceder/2`.

### P4 — Rodar com o painel já trocado

Aí `DATABASE_URL` é `the_band_app`, e `DATABASE_ADMIN_URL="$DATABASE_URL"` conectaria como quem
serve. A função **precisa recusar** antes de qualquer escrita: `rolsuper` falso em `current_user`
→ `{:error, :nao_e_superusuario}`, com frase que nomeia a variável e nunca o valor. Se a URL for
digitada à mão (superusuário de verdade), cai no P3: nada de senha, posse já transferida, concessão
reaplicada, conferência impressa.

### P5 — A função no release, chamada por `rpc` como `band`

O `rpc` roda **dentro do nó que serve**, com o ambiente dele. Três defesas, todas exigidas:

1. **sem URL de admin, recusa; nunca cai no `TheBand.Repo`** (C1). A função abre conexão própria
   (`Postgrex` direto, ou um repo dinâmico com `put_dynamic_repo`) só a partir de
   `DATABASE_ADMIN_URL`;
2. **recusa dentro de nó vivo** (C2): `Node.alive?()` verdadeiro ou `RELEASE_COMMAND != "eval"`
   devolve `{:error, :so_por_eval}`. O `eval` não abre distribuição (medido na #1162);
3. **`DATABASE_ADMIN_URL` nunca alcança `band`** (C3): `rel/entrypoint.sh` recusa subir se ela estiver
   no ambiente do contêiner (ela não tem nada a fazer no painel), e `como_band`, o `exec` final e
   `rel/env.sh.eex` passam a fazer `env -u DATABASE_ADMIN_URL` junto com `DATABASE_MIGRATION_URL`.

Antes da troca, X2 vale: como `band` já é superusuário, a função não acrescenta capacidade. Depois
da troca, sem as três defesas, ela vira uma porta para quem conseguir pôr a URL de admin no ambiente.

### P6 — Logs

- nenhuma URL, senha ou verificador em `IO.puts`, `Logger`, `inspect` ou mensagem de erro, com
  **uma** exceção nomeada: as duas URLs da impressão única, no stdout do `eval`;
- todo o corpo dentro de `com_url_redigida/1`, que já traduz `Ecto.InvalidURLError` sem a URL. Vale
  também para `Postgrex.Error`: a mensagem de um `CREATE ROLE` recusado pode trazer o texto do
  comando. Por isso o comando não pode carregar segredo em claro (C5), e o `rescue` traduz para
  `{:error, {:postgres, sqlstate}}`;
- `ERL_CRASH_DUMP_SECONDS=0` na linha do runbook, como na migração (A4 da #1140): o crash dump traz
  o ambiente e as variáveis do processo, isto é, a URL de admin e as senhas geradas;
- a frase final traz contagens (tabelas, funções, sequências, tipos transferidos), nomes de papel e
  a conferência. Nunca um valor.

## O contrato mínimo (para `specs/071-papeis-do-banco/contracts/papeis.md`)

```elixir
@spec separar_papeis() :: :ok | {:error, motivo_da_recusa()}
# imprime a frase do relator; o retorno é o que os testes asserem (L69: o relator, e não o log)

@type motivo_da_recusa ::
        :sem_url_de_admin            # DATABASE_ADMIN_URL ausente
        | :so_por_eval               # chamada em nó vivo (rpc, remote, iex)
        | :nao_e_superusuario        # a URL não é de superusuário
        | :base_diferente            # a base da URL de admin não é a de DATABASE_URL
        | {:papel_perigoso, String.t()}   # já existe com atributo de FR-001, ou o app é membro do dono
        | {:conferencia, [Papeis.motivo()]}  # as conferências não deram zero: ROLLBACK
        | {:postgres, atom()}        # SQLSTATE, nunca a mensagem
```

O que ela faz, numa transação, nesta ordem:

1. confere as recusas acima, **antes** de qualquer escrita;
2. `SET LOCAL lock_timeout` curto: `ALTER ... OWNER` pede `ACCESS EXCLUSIVE` em cada tabela com a
   aplicação servindo, e esperar indefinidamente é a aplicação parada. Com timeout, a transação
   desfaz tudo e diz `{:postgres, :lock_not_available}`;
3. cria os papéis que faltam, com os atributos negativos explícitos e o verificador SCRAM;
4. transfere a posse objeto a objeto, com os mesmos filtros do roteiro (extensões fora);
5. esquema e base para `the_band_owner`, com `format('%I', ...)` e nada interpolado em Elixir, como
   `Papeis` já faz;
6. **concede a `the_band_app`** com `SET LOCAL ROLE the_band_owner` e `Papeis.conceder/2`, para que
   os privilégios padrão sejam `FOR ROLE the_band_owner`, e não do `postgres` (C8). O roteiro A não
   concede: depende de o deploy seguinte rodar com o File Mount. Se a pessoa trocar `DATABASE_URL` e
   esquecer o arquivo, `migrar_sem_credencial` como `the_band_app` sem privilégio quebra no `SELECT`
   em `schema_migrations`, e a aplicação não sobe;
7. as quatro conferências do roteiro, que precisam dar zero; e `Papeis.conferir/2` sob
   `SET LOCAL ROLE the_band_app`. Qualquer motivo → `ROLLBACK`;
8. `COMMIT`, e só então a impressão única das URLs.

**A conferência do passo 7 é pré-verificação, e não a evidência que fecha a #1131.** `SET ROLE` não
passa por `pg_hba`, `LOGIN` nem senha. O que fecha continua sendo o `rpc` do runbook §14.4, depois
do deploy (SC-004).

O que ela **não** expõe e **não** faz:

- não recebe senha por argumento nem por variável;
- não devolve senha no retorno (o retorno é o que um `rpc` mostraria);
- não lê `DATABASE_MIGRATION_URL` nem o File Mount;
- não altera senha de papel existente;
- não toca o papel `postgres`, nem outras bases, nem `GRANT the_band_owner TO the_band_app`;
- não roda no entrypoint nem em lugar automático nenhum, como `rollback/2`.

## Condições bloqueantes, se B seguir

| # | condição | severidade se faltar |
|---|---|---|
| C1 | sem `DATABASE_ADMIN_URL`, recusa; nunca usa `TheBand.Repo` | média: depois da troca, falharia com `42501`; o perigo é o fallback esconder o erro de chamada |
| C2 | recusa em nó vivo (`rpc`) | média |
| C3 | `DATABASE_ADMIN_URL` recusada no entrypoint e removida em `como_band`, no `exec` e em `env.sh.eex` | **alta**: superusuário no ambiente do processo que serve desfaz a separação inteira |
| C4 | senhas geradas por `:crypto.strong_rand_bytes`, hex, impressas uma vez, depois do `COMMIT` | média |
| C5 | o servidor recebe só o verificador SCRAM | média: senha do dono no log do PostgreSQL |
| C6 | a base da URL de admin é a base de `DATABASE_URL` | média |
| C7 | rodar de novo não altera senha, e recusa papel perigoso preexistente | média: X6 derruba a produção |
| C8 | concede a `the_band_app` como `the_band_owner` na mesma transação | média: um esquecimento derruba a produção |
| C9 | FR nova na `spec.md` para `DATABASE_ADMIN_URL`, e o FR-007 revisto | processo (princípio VI): sem FR, não há tarefa nem teste |

## Os testes que o QA deve escrever, com o defeito a injetar

Banco de teste com dois papéis criados no setup (`@moduletag :precisa_criar_papel`, como em
`release_papeis_test.exs`). A posse inicial é de um papel que faz as vezes do `postgres`. Cada
teste é visto reprovando com o defeito injetado antes de ser aceito.

| # | cenário | asserção | defeito a injetar |
|---|---|---|---|
| T1 | sem `DATABASE_ADMIN_URL` | `{:error, :sem_url_de_admin}`; **refute** que algum papel foi criado (`pg_roles`) | fallback para `TheBand.Repo` |
| T2 | chamada com `Node.alive?` simulado | `{:error, :so_por_eval}`, nada escrito | retirar a guarda |
| T3 | URL de papel sem `rolsuper` | `{:error, :nao_e_superusuario}`; **refute** mudança de posse | conferir só depois de escrever |
| T4 | base diferente | `{:error, :base_diferente}` | comparar só o host |
| T5 | primeira execução | zero tabelas, funções, sequências e tipos de outro dono em `public`; `the_band_app` **não** é membro de `the_band_owner`; sob `SET ROLE the_band_app`, `DISABLE TRIGGER` dá `42501` e `tgenabled = 'O'`. Antes de asserir zero, **assert** que havia objetos do dono antigo (que a medida mediu) | tirar o laço de funções (os triggers ficam com o dono antigo) |
| T6 | segunda execução | `rolpassword` dos dois papéis **igual** antes e depois; retorno `:ok` | regenerar senha sempre |
| T7 | papel preexistente com `CREATEROLE`, ou `the_band_app` membro do dono | `{:error, {:papel_perigoso, _}}`, e **refute** que o atributo foi corrigido em silêncio | `ALTER ROLE` corretivo |
| T8 | lock ocupado por outra conexão numa tabela | `{:error, {:postgres, :lock_not_available}}`; **refute** qualquer posse transferida (tudo ou nada) | tirar a transação, ou o `lock_timeout` |
| T9 | segredo fora da saída | capturando stdout e log: **refute** a URL de admin e sua senha em todo caminho de erro; as senhas geradas aparecem **exatamente uma vez**, e nunca no retorno | `inspect(erro)` num ramo de recusa |
| T10 | SCRAM | `rolpassword` começa com `SCRAM-SHA-256$`; um login com a senha impressa funciona (`Postgrex.start_link` com a URL impressa) | mandar `PASSWORD` em claro (o login funciona e a guarda não pega: o teste precisa da asserção sobre o formato **e** do sinal de que o comando não continha o literal, por `pg_stat_statements` ou por inspeção do SQL montado) |
| T11 | a concessão | sob `SET ROLE the_band_app`, `SELECT` em `schema_migrations` passa e `INSERT` dá `42501`; tabela criada depois por `the_band_owner` dá `SELECT` a quem serve | conceder como `postgres` (os privilégios padrão ficam do papel errado) |
| T12 | entrypoint (teste de shell, como os da #1140, no Docker local) | com `DATABASE_ADMIN_URL` no ambiente do contêiner, **não sobe**; `rpc` como root não a vê em `System.get_env` | retirar o `env -u` |

## Riscos que valem para A e B

- **R1 — média. A senha do `postgres` não muda com a separação.** Ela esteve em `DATABASE_URL`
  (ambiente do processo de `band`, `docker inspect`, painel) desde o primeiro deploy. Quem teve
  execução como `band` antes, ou leu o ambiente, continua com superusuário depois. Recomendação:
  girar a senha do `postgres` **pelo serviço de banco do Dokploy** (para que o backup agendado
  receba a nova) e conferir que um backup roda depois (runbook §4). Girar com `ALTER ROLE` direto
  quebraria o backup em silêncio, e eu **não verifiquei** como o Dokploy guarda essa credencial;
- **R2 — baixa. Janela de bloqueio.** As duas opções pegam `ACCESS EXCLUSIVE` em ~81 tabelas
  numa transação. Com a aplicação e o Oban servindo, pode esperar ou entrar em deadlock. Janela de
  pouco uso e `lock_timeout`, como o runbook já pede;
- **R3 — informativo.** Entre o `COMMIT` e a troca no painel, a aplicação serve como `postgres`, e
  a separação existe no banco mas não está em vigor. A conferência do `rpc` diz "NÃO em vigor
  (superusuario)" até o deploy, e isso é o esperado, não falha.

## O que não entra

- a função **não** substitui o `rpc` do §14.4 como evidência de fechamento;
- girar a senha do `postgres` (R1) é ato separado, da pessoa mantenedora;
- tirar a migração do contêiner que serve (o risco residual do S5) segue fora;
- `redefinir_senha_do_papel/1` não entra sem necessidade concreta.

## O que eu não verifiquei

- se o terminal web do Dokploy guarda a sessão ou o scrollback em algum lugar do servidor;
- se a saída de `docker exec` deixa de ir para `docker logs` nesta instalação (o comportamento
  padrão do Docker, não medido aqui);
- `log_statement`, `log_min_error_statement` e `password_encryption` do PostgreSQL de produção, e o
  método do `pg_hba` (se for `md5`, o verificador SCRAM ainda autentica; se for `password`, não
  medi);
- como o Dokploy guarda e usa a senha do `postgres` no backup agendado (R1);
- se o histórico do shell do terminal do Dokploy persiste (`ash`/`sh` da imagem bookworm, `HISTFILE`
  de root);
- o meio de `papeis.ex` (linhas 200 a 260, privilégios e funções de trigger) foi lido só em parte;
- o `seguranca.md` e a `evidencia-1140.md` da 071 foram lidos só pelos títulos, e não por inteiro;
- se existe impedimento operacional para rodar o `psql` no Dokploy, que é o que justificaria B;
- nenhum gate foi rodado: esta avaliação não mudou código.
