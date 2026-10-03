# Avaliação de segurança — 071, os papéis do banco (antes do plano)

Agente `security`, 2026-10-02, sobre o commit `89c0323` da branch `feature/1131-papeis-do-banco`.
Não escrevi o desenho. Avaliação **antes do plano** (AGENTS §14.0). Escopo: `spec.md` inteira e o
código que ela cita: `rel/entrypoint.sh`, `Dockerfile`, `config/runtime.exs`, `config/config.exs`
(Oban), `config/test.exs`, `lib/the_band/release.ex`, as migrações com `execute`/extensão, o runbook
§2, §4, §5, §6, §10.2 e §12, o CI (`.github/workflows/ci.yml`) e a conferência G1–G5 da 070.

Não rodei `mix test` nem `mix gates`, por instrução. Não editei `lib/`, `test/` nem `priv/`.

## Como foi medido

Tudo o que está marcado **medido** saiu do `the_band_postgres` local (**PostgreSQL 16.14**, o mesmo
major da produção), na base `the_band_dev`, **dentro de uma única transação terminada em
`ROLLBACK`**: dois papéis `NOLOGIN` criados na transação (`m071`, o que migra, e `s071`, o que serve),
um esquema próprio do `m071`, uma tabela com `bigserial`, uma `CHECK`, um trigger `BEFORE DELETE` e
um `BEFORE TRUNCATE` na forma do `nao_apaga`/`nao_trunca` da 070, e os privilégios padrão de FR-005.
Erros com `ON_ERROR_ROLLBACK` e `VERBOSITY sqlstate`, para ler o código e não a frase. Depois do
`ROLLBACK`, conferido: 0 papéis `m071`/`s071` e 0 esquemas `s071sch` sobraram. O roteiro está em
`scratchpad/m071.sql` da sessão, e o QA pode reaproveitá-lo como forma.

Duas medições fora do banco: o ambiente de processo em contêiner (no `the_band_postgres`, usando
`PG_MAJOR` como marcador, por não ser segredo; só contagens foram impressas, nunca valores) e a
mensagem de `Ecto.InvalidURLError` (com a Ecto do `_build/dev` e senha falsa óbvia).

### O que a medição respondeu

| Pergunta do pedido | Resposta | Como |
|---|---|---|
| papel não-dono, com `SELECT/INSERT/UPDATE/DELETE` e `USAGE, SELECT` na sequência, faz as escritas da aplicação | **sim**: `INSERT … RETURNING id` (usa a sequência), `UPDATE`, `SELECT`; o `DELETE` cai no trigger (`P0001`), e não em privilégio | medido |
| `ALTER TABLE … DISABLE TRIGGER x` / `DISABLE TRIGGER ALL` (inclui os triggers internos das FKs) | **recusado**, `42501` | medido |
| `DROP TRIGGER`, `DROP CONSTRAINT`, `TRUNCATE`, `DROP TABLE … CASCADE`, `ALTER … OWNER`, `DROP FUNCTION … CASCADE`, `CREATE OR REPLACE FUNCTION` sobre a função do trigger, `REINDEX` | **recusados**, `42501` | medido |
| `SET session_replication_role = replica` exige superusuário? | **sim, para quem serve**: `42501`, e o `SHOW` continua `origin`. **E também para o dono não-superusuário**: o `m071` recebeu `42501` | medido |
| `TRIGGER` com função em `pg_temp` | sem o privilégio `TRIGGER`: `42501`. **Com** `GRANT TRIGGER`, também `42501` (a função temporária não serve a trigger de tabela permanente) | medido |
| `CREATE` no esquema `public` no PG16 | `PUBLIC` tem só `USAGE`: ACL `{pg_database_owner=UC/pg_database_owner,=U/pg_database_owner}`. O dono do `public` é **quem é dono da base** | medido na `the_band_dev`; **produção não verificada** |
| `TEMP` na base | `PUBLIC` tem (ACL nula = padrão): `CREATE TEMP TABLE` e `CREATE FUNCTION pg_temp.f()` **passam** para quem serve | medido |
| `LISTEN`, `UNLISTEN`, `pg_notify` sem privilégio de tabela | **passam** | medido |
| `gen_random_uuid()` | é **do núcleo** (`pg_catalog`) desde o 13, e `pg_catalog` vem primeiro; o `pgcrypto` da migração `20260809120000` também tem uma, que fica sombreada. Executável por `PUBLIC` | medido |
| sequências da aplicação | **uma só**: `oban_jobs_id_seq`. Todas as tabelas de domínio usam `uuid` | medido na `the_band_dev` |
| `setval` com `USAGE, SELECT` | **recusado**, `42501` — o que é desejável | medido |
| funções `SECURITY DEFINER` em `public` | **nenhuma** (as 38 do `pgcrypto`, todas `prosecdef = f`, dono `postgres`); nenhum trigger fora dos internos | medido na `the_band_dev` |
| tabela criada por **outro** papel que não o dos privilégios padrão | **sem** privilégio para quem serve: `SELECT` dá `42501` | medido |
| `CREATE TABLE IF NOT EXISTS` sobre tabela **que já existe**, por quem não tem `CREATE` no esquema | **`42501`**: o PostgreSQL confere o privilégio no esquema antes de olhar se a tabela existe | medido |
| `LOCK TABLE schema_migrations IN SHARE UPDATE EXCLUSIVE MODE` (o `migration_lock` padrão da Ecto) | **passa** com `UPDATE/DELETE` | medido |
| **papel que serve como dono do esquema** | `DISABLE TRIGGER` continua recusado, **mas `DROP FUNCTION … CASCADE` passa e leva os triggers junto** | medido |
| **papel que serve membro do papel que migra** (`GRANT m071 TO s071`) | `DISABLE TRIGGER` **passa** | medido |
| `GRANT SET ON PARAMETER session_replication_role` ao que serve | `replica` **passa**, e o `SHOW` diz `replica` | medido |
| membro de `pg_write_all_data` | `TRUNCATE` continua `42501` | medido |
| controle positivo, `m071` (dono, não superusuário) | `DISABLE TRIGGER`, `DROP TRIGGER`, `DROP CONSTRAINT`, `TRUNCATE` passam; `replica` **não** | medido |
| `unset X; exec cmd` tira `X` de `/proc/<pid>/environ` do processo que fica | **sim**: 0 ocorrências depois do `exec` | medido |
| processo aberto por `docker exec` (o `HEALTHCHECK`, o terminal) recebe o ambiente **configurado** do contêiner | **sim**: 1 ocorrência, mesmo com o PID que serve sem a variável | medido |
| processo do mesmo usuário lê o `/proc/<pid>/environ` de outro processo do contêiner | **sim** | medido |
| `Ecto.InvalidURLError` com senha que tem `/` ou `#` | **a mensagem contém a senha** | medido com senha falsa; contagem, não valor |

## Respostas diretas às seis perguntas

### 1. O desenho fecha o G1?

**Fecha o caminho por SQL**, se FR-001/FR-002 forem escritos como condições sobre o papel inteiro, e
não só sobre posse de tabela. Do jeito que estão, **não fecham, e a conferência de FR-009 pode dizer
"em vigor" com o G1 aberto** (achados S1 e S2). O que precisa estar em FR-001/FR-002/FR-003 está na
seção de emendas. Os pontos pedidos:

- **`TRIGGER`, `TRUNCATE`, `REFERENCES`**: fora. `TRIGGER` e `TRUNCATE` foram medidos como
  necessários de negar; `REFERENCES` não dá caminho medido (FK de tabela temporária para permanente
  é proibida no PostgreSQL), mas não é usado e sai por mínimo privilégio;
- **ser dono**: de nada. Tabela, sequência, função, tipo, **esquema e base**. A posse do esquema
  basta para `DROP FUNCTION … CASCADE` (medido), e a posse da base dá a posse do `public` pelo
  `pg_database_owner`;
- **superusuário**: não, nem `CREATEROLE`, `CREATEDB`, `REPLICATION`, `BYPASSRLS`;
- **pertencer a papel**: a nenhum papel que seja dono de objeto da base, direta ou indiretamente, nem
  aos predefinidos `pg_execute_server_program`, `pg_read_server_files`, `pg_write_server_files`,
  `pg_signal_backend`. Herança de papel anula toda a separação (medido);
- **`CREATE` no `public`**: o PG16 já o tira de `PUBLIC` em base **criada** no 15 ou depois (medido
  na local). Base restaurada de dump de versão antiga, ou com `GRANT` explícito, pode ter. Isto é
  condição a **conferir**, não a supor. Sem `CREATE` em `public`, quem serve também não planta função
  homônima para sequestrar o `search_path` de quem migra — que seria escalada para o papel que migra;
- **`SECURITY DEFINER`**: não existe nenhuma hoje (medido). A regra a escrever: função
  `SECURITY DEFINER` só com `SET search_path = pg_catalog, public`, `REVOKE EXECUTE … FROM PUBLIC`,
  e dono que **não** é superusuário. Função de trigger fica `SECURITY INVOKER`, como a da 070;
- **`session_replication_role`**: exige superusuário **ou** `GRANT SET ON PARAMETER` (PG15+). Medido
  nos dois sentidos. Logo, FR-003 se sustenta só se a conferência olhar `pg_parameter_acl`;
- **`ALTER DEFAULT PRIVILEGES`**: tem de ser `FOR ROLE <o papel que de fato executa as migrações>`.
  Sem `FOR ROLE`, vale para quem executou o comando, e tabela criada por outro papel nasce sem
  privilégio para quem serve (medido). Listar os privilégios por nome, **nunca `ALL`**: no PG17, que
  é o do CI (S8), `ALL` inclui `MAINTAIN`.

### 2. FR-006: funciona com `exec` e com o release?

**Para o processo que serve, sim** (medido): `unset` antes de `exec "$@"` faz o `execve` levar o
ambiente sem a variável, e o `/proc/1/environ` passa a ser o do novo programa. O
`bin/the_band start` e o `erlexec` também trocam de imagem por `exec`, e herdam o ambiente já sem
ela. O `eval` da migração é um filho do shell que termina antes do `exec`.

**Para o contêiner, não** (S5): todo processo aberto por `docker exec` recebe o ambiente
**configurado** do contêiner, e não o do PID 1 (medido). Isso inclui o `HEALTHCHECK` do `Dockerfile`,
que roda `bin/the_band rpc` **a cada 60 segundos, como `band`**, o mesmo usuário do BEAM, e todo
terminal aberto pelo Dokploy. Um processo do mesmo usuário lê o `/proc/<pid>/environ` do outro
(medido). Então quem executa código dentro do BEAM lê a credencial que migra no próximo
healthcheck. O `bin/the_band eval` e o `rpc` pelo terminal do Dokploy têm a credencial no ambiente
do cliente; o `rpc` executa **no nó que serve**, sem ela; o `eval` sobe VM nova e só a usaria se o
`runtime.exs` a lesse (FR-007).

### 3. FR-008: riscos e o sinal mensurável

A decisão "migrar com a credencial que serve e avisar" só se cumpre no **estado de hoje** (a
credencial que serve ainda é dona). No estado em que a pessoa mantenedora já trocou o `DATABASE_URL`
para o papel novo e a credencial que migra falta, **a migração reprova e o contêiner não sobe**
(S4): o `Ecto.Migrator` executa `CREATE TABLE IF NOT EXISTS schema_migrations` em toda execução, e
isso é `42501` para quem não tem `CREATE` no esquema, **mesmo com a tabela existindo** (medido). O
`set -e` derruba o contêiner. FR-008 diz "MUST subir" e não consegue. O segundo risco é o aviso virar
paisagem: uma linha no log de deploy que aparece em todo deploy, por meses.

**Sinal mensurável**: o veredito **não pode** vir da presença da variável. A credencial que migra
pode estar presente e ser idêntica à que serve, ou o papel que serve pode ser membro do dono. O
veredito vem de **consultar o banco com a credencial que serve**, e é um relator, não uma frase de
log (L69): `{:em_vigor, papel}` ou `{:nao_em_vigor, papel, [motivo]}`, com motivos fechados e
nomeados (`:mesma_credencial`, `:superusuario`, `:dono_de_objeto`, `:membro_de_dono`,
`:create_em_public`, `:privilegio_a_mais`, `:replica_permitida`, `:schema_migrations_gravavel`,
`:credencial_que_migra_ausente`). A linha de log e a saída da conferência são a tradução desse
relator. A aplicação o calcula **também ao subir**, não só no entrypoint, e o loga em `warning`.

### 4. Backup, Oban, `schema_migrations`, sequências, extensões

- **`pg_dump` e os `GRANT`s**: o `pg_dump` inclui `GRANT`/`REVOKE` e `ALTER DEFAULT PRIVILEGES` por
  padrão, **salvo** com `--no-acl`/`-x` ou `--no-owner`/`-O`. **Papéis não entram no `pg_dump`**: são
  objetos do cluster. Não verifiquei com que opções o backup do Dokploy roda. O ensaio do §6 cria um
  banco **novo no Dokploy**, isto é, outro cluster, onde o papel que serve não existe: os `GRANT`s
  falham, e a instância de ensaio, apontada para a credencial administrativa, sobe e "passa" sem ter
  testado nada (S7);
- **Oban**: as tabelas são `oban_jobs` (com a única sequência) e `oban_peers` (`UNLOGGED`). Nenhuma
  função nem trigger do Oban na base (medido; a migração do Oban nesta versão não cria o trigger de
  notificação). O notificador usa `pg_notify`/`LISTEN`, sem privilégio de tabela (medido). O
  `Pruner` apaga com `DELETE`, que é concedido. O `oban_peers` usa `INSERT … ON CONFLICT DO UPDATE`,
  que exige `INSERT`, `UPDATE` e `SELECT`, concedidos. **O `Oban.Plugins.Reindexer`, se um dia
  entrar, reprova**: `REINDEX` exige dono (medido). Não li o código do Oban 2.23.1;
- **`schema_migrations`**: com os privilégios padrão de FR-005, ela **ganha `INSERT` para quem
  serve**, e isso é caminho de ataque (S3). Quem serve não precisa dela em produção (o
  `CheckRepoStatus` do Phoenix é só de dev). Revogar tudo;
- **sequências**: `USAGE, SELECT`. Sem `UPDATE`, o `setval` é recusado (medido), e nada da
  aplicação o usa (busca textual em `lib/`);
- **extensões**: `gen_random_uuid()` é núcleo no 16; o `pgcrypto` é extensão confiável (*trusted*)
  desde o 13, e um dono não-superusuário com `CREATE` na base consegue criá-la. Extensão não
  confiável exigiria superusuário — relevante se o papel que migra deixar de ser o `postgres`.

### 5. O teste de FR-011 no CI

O CI conecta como `postgres`, superusuário, e o teste roda no sandbox. `CREATE ROLE` é transacional
(medido: rolado de volta, sobram 0), então **o papel não-dono nasce e morre dentro da transação do
teste**, sem sobrar no cluster e sem afrouxar nada. Forma e defeitos a injetar estão em
"Cenários para o QA". Dois cuidados: o controle positivo de `replica` é de **superusuário**, não do
dono (S2); e o controle positivo sobre tabelas reais toma `ACCESS EXCLUSIVE` até o fim da transação,
então esse caso é `async: false`. A recusa de quem serve é conferida **antes** do lock
(o `42501` voltou imediato), mas isso não medi sob concorrência.

### 6. Risco residual para a nota da release

Na seção própria, no fim.

## Achados

Severidade pela tabela do papel. Nenhum achado é de exposição ativa: o G1 é conhecido e está
declarado. A prioridade é do Product Owner.

### S1 — Média. FR-001/FR-002 descrevem posse de tabela, e o G1 continua aberto por quatro portas que eles não nomeiam

**O que é (A01/A04)**: FR-001 exige "não é dono de nenhuma tabela e não é superusuário". Medido:
um papel que satisfaz as duas condições e **é membro** do dono desliga trigger; um que **é dono do
esquema** (ou da base, pelo `pg_database_owner`) apaga a função do trigger com `CASCADE`; um com
`GRANT SET ON PARAMETER session_replication_role` pula todos os triggers da sessão.

**Onde**: `specs/071-papeis-do-banco/spec.md`, FR-001, FR-002, FR-003.

**Caminho**: a pessoa mantenedora segue o roteiro, e na hora de "fazer funcionar" executa
`GRANT the_band_owner TO the_band_app`, ou cria a base com `OWNER the_band_app`. Uma injeção de SQL
pelo processo que serve executa `DROP FUNCTION tenant_estado_tem_episodio() CASCADE` ou
`DISABLE TRIGGER`. Tudo isso com FR-001 cumprido ao pé da letra.

**Consequência para o negócio**: a feature é dada como entregue, e a concessão do operador e o
episódio de suspensão continuam apagáveis por quem invadir a aplicação.

**O que fecha**: as emendas a FR-001/FR-002/FR-003 abaixo, e o cenário A2 do QA.

**Se não entrar agora**: o plano nasce de uma definição incompleta, e o teste de FR-011 só cobre as
quatro tentativas, que **não pegam** o caso do dono do esquema (`DISABLE TRIGGER` e `DROP TRIGGER`
continuam recusados a ele; só `DROP FUNCTION` passa).

### S2 — Média. A conferência e a prova de que a medição mede podem mentir

**O que é**: dois defeitos de medida (o "sucesso silencioso" da casa).

1. FR-009 confere "não é dono nem superusuário" e as quatro tentativas. Pelo S1, um papel dono do
   esquema passa nas quatro e nas duas condições, e a conferência diria **"em vigor"**.
2. US1-5 e SC-002 dizem que, com o papel que migra, as quatro tentativas **passam**. Medido: com
   dono **não superusuário**, `SET session_replication_role` é `42501`. O critério só é verdadeiro
   se o papel que migra for superusuário. Escrito assim, ele empurra o desenho para manter o
   `postgres` como papel que migra, ou faz o teste ser ajustado até passar.

**Onde**: `spec.md`, FR-009, US1 cenário 5, SC-002.

**O que fecha**: controle positivo **por tentativa** (dono para as três de estrutura, superusuário
ou papel com `SET ON PARAMETER` para a de sessão), e a conferência com catálogo **e** tentativa (FR-009
emendado).

### S3 — Média. Quem serve pode gravar em `schema_migrations` e fazer a próxima guarda nunca ser instalada

**O que é (A08, integridade)**: FR-005 manda dar a toda tabela criada por migração os privilégios de
FR-002, e `schema_migrations` é criada pela migração. Quem serve ganha `INSERT` nela.

**Caminho**: SQL arbitrário pelo papel que serve insere a versão de uma migração que ainda vai ser
implantada — por exemplo a da 070 que cria `tenant_estado_tem_episodio`, cuja versão fica visível no
PR antes do deploy. No deploy, a Ecto considera a migração aplicada, não a executa, e não diz nada. A
guarda nunca existe em produção, em silêncio. É o G1 de novo, por outra porta, e **mais barato**
depois da feature do que antes, porque ataca a próxima guarda e não a atual.

**Onde**: `spec.md`, FR-002, FR-005 e o caso de borda `schema_migrations`, que já diz "não escreve
nela" mas não vira requisito.

**O que fecha**: `REVOKE ALL ON schema_migrations FROM <quem serve>`, **depois** de toda concessão
em massa, a cada execução; a conferência de FR-009 reprova se quem serve tiver qualquer privilégio
nela. Cenário A4.

### S4 — Média. FR-008 não consegue subir no estado em que mais vai acontecer

**O que é (disponibilidade; A04)**: medido que `CREATE TABLE IF NOT EXISTS` sobre tabela existente é
`42501` sem `CREATE` no esquema, e o `Ecto.Migrator` faz isso em toda execução. Logo, com o
`DATABASE_URL` já apontando para o papel novo e a credencial que migra ausente, `migrate/0` levanta,
o `set -e` derruba o contêiner, e a produção não sobe — o oposto do que a pessoa mantenedora decidiu.

**Caminho**: a troca no painel é manual e em dois campos. Esquecer um, ou um redeploy depois de
alguém apagar a variável "porque não é mais usada", basta.

**Onde**: `spec.md`, FR-008 e US2 cenário 4; `rel/entrypoint.sh:27`; `lib/the_band/release.ex:34-40`.

**O que fecha**: FR-008 separado em três estados, com decisão explícita para o terceiro (emenda
abaixo). Não verifiquei se o Dokploy mantém o contêiner antigo servindo quando o novo não sobe; se
mantiver, o efeito é deploy travado, e não indisponibilidade.

**Se não entrar agora**: o plano implementa o "migra com o que serve" literal, que funciona nos
testes (onde quem migra é o `postgres`) e falha só em produção, no primeiro deploy depois da troca.

### S5 — Média. A credencial que migra continua ao alcance de quem executa código no contêiner

**O que é (A02; ASVS V2 gestão de segredos)**: FR-006 tira a credencial do PID 1, e isso funciona
(medido). Mas o `HEALTHCHECK` do `Dockerfile` roda por `docker exec`, como `band`, a cada 60
segundos, com o ambiente configurado do contêiner — **com a credencial**. Medido que esse processo a
recebe e que outro processo do mesmo usuário a lê em `/proc/<pid>/environ`.

**Caminho**: execução de código dentro do BEAM (dependência comprometida, `eval` indevido,
`binary_to_term` inseguro) varre `/proc/*/environ` por alguns minutos e colhe a credencial do papel
que migra, que é dono — e, pela premissa da spec, hoje o `postgres`, superusuário, com
`COPY … TO PROGRAM` (execução de comando no contêiner do banco). É exatamente o atacante "eval ou
falha que execute SQL arbitrário" do Input da spec.

**Consequência para o negócio**: a feature declara a credencial fora do alcance da aplicação, e ela
está a um healthcheck de distância. O teste de US2 cenário 3, se olhar só o PID 1, dá verde falso.

**Onde**: `Dockerfile` (`HEALTHCHECK … CMD /app/bin/the_band rpc …`); `spec.md`, FR-006 e US2-3.

**O que fecha** — decisão de desenho para o plano, com o que cada uma piora:

| opção | fecha? | o que piora |
|---|---|---|
| a. credencial que migra em **arquivo** legível só por `root`, entrypoint começa como `root`, migra, e troca para `band` (`setpriv --reuid band --regid band --init-groups`) antes do `exec`; healthcheck também por `setpriv` | sim, contra quem é `band` | o contêiner volta a **começar** como `root`, o que a casa trata como regressão; precisa de medição e decisão da pessoa mantenedora |
| b. migração fora do contêiner que serve (serviço de execução única, ou passo de pré-deploy do Dokploy, se existir) | sim | mais uma peça no deploy; não verifiquei se o Dokploy oferece |
| c. `env -u` no `HEALTHCHECK` | não: o processo `env` tem a variável até o próprio `execve` (janela curta, mas real), e o terminal do Dokploy continua com ela | quase nada, e quase nada fecha |
| d. aceitar | — | vai para a nota como risco residual, nomeado: FR-006 protege o ambiente do processo que serve, e não o contêiner |

Recomendo **a** ou **b**; a escolha é do plano e da pessoa mantenedora. Com **d**, o texto de FR-006
e de US2-3 precisa dizer o limite, para ninguém ler como "a aplicação não alcança a credencial".

### S6 — Média. URL malformada imprime a senha no log de deploy

**O que é (A09; ASVS V7)**: `Ecto.InvalidURLError` monta a mensagem com a URL inteira
(`deps/ecto/lib/ecto/exceptions.ex:162`), sem redigir. Medido com senha falsa: com `/` ou `#` na
senha, a mensagem contém a senha. A `migrate/0` casa `{:ok, _, _} = …` e a exceção sobe para o
stderr do `eval`, que é o log de deploy do Dokploy.

**Caminho**: o roteiro de FR-010 manda gerar duas senhas; `openssl rand -base64` produz `/` e `+`.
Uma delas, colada sem codificar na URL, vai para o log no primeiro deploy. **Já vale hoje para o
`DATABASE_URL`**; a feature dobra as chances e cria a ocasião (gerar credencial nova à mão).

**Onde**: `lib/the_band/release.ex:38`, `:60`, `:110`, `:201`; `config/runtime.exs:76-87`;
`spec.md`, FR-010, FR-012.

**O que fecha**: o roteiro gera senha só com `[0-9a-f]` (`openssl rand -hex 32`), o que dispensa
codificar; e o `Release` traduz `Ecto.InvalidURLError` numa frase que nomeia a variável e **não** a
URL. Cenário A7. Como é anterior à feature, pode ser issue própria; o roteiro novo não pode esperar.

### S7 — Média. O ensaio de restauração passa sem testar o papel que serve

**O que é (A05; ASVS V14)**: o §6 restaura num banco **novo do Dokploy** (outro cluster) e aponta a
instância de ensaio para a URL desse banco, que é a administrativa. Papéis não estão no `pg_dump`.
Os `GRANT … TO the_band_app` falham na restauração (o `psql < dump` segue adiante sem parar), a
aplicação de ensaio sobe como superusuário, os três números batem, e o ensaio "passa". SC-005 é
declarado cumprido sem ter sido medido. Se o backup do Dokploy usar `--no-acl`/`--no-owner` (não
verifiquei), a restauração de verdade também perde a concessão, e a produção restaurada responde
`42501` em toda tela — barulhento, mas é indisponibilidade no pior momento.

**Onde**: `docs/producao/runbook.md` §4, §6; `spec.md`, FR-005, FR-010, SC-005.

**O que fecha**: a concessão **reaplicada em todo deploy**, idempotente, pelo passo que migra
(emenda a FR-005), o que torna a restauração auto-corretiva no deploy seguinte; e o ensaio do §6
criando os dois papéis no cluster de ensaio **antes** de restaurar, servindo pela credencial do papel
que serve, e rodando a conferência de FR-009 como último passo.

### S8 — Baixa. O CI mede em PostgreSQL 17, a produção roda 16

`.github/workflows/ci.yml:44` e `:137` usam `postgres:17-alpine`; a produção é 16 (runbook §4) e o dev
local é 16.14. O modelo de privilégios mudou entre eles: o 17 tem `MAINTAIN` e `pg_maintain`, e
`GRANT ALL` concede `MAINTAIN` no 17 e não no 16. Um teste de privilégio verde no 17 é medida de outro
servidor. **O que fecha**: FR-002 lista privilégios por nome (já é o caso), e o teste de FR-011 roda
contra o major da produção, ou declara a diferença. Não medi nada no 17.

### S9 — Baixa. SC-003 não cobre o Oban nem a subida em produção

`config/test.exs:38-74` desliga filas, plugins e peer. A suíte inteira passando com o papel que serve
prova as consultas da aplicação, e **não** o `Cron`, o `Pruner`, o peer, o notificador, nem o
`saude_da_fila` do healthcheck — todos citados em US1-4. **O que fecha**: um ensaio de fumaça com o
Oban ligado contra o papel que serve (local ou o §6), com critério medido: um job do `Cron`
completado, uma linha em `oban_peers`, e o `Pruner` executado sem `42501` no log.

### S10 — Baixa. `TEMP` para `PUBLIC` mantém a superfície do G2 da 070

Quem serve cria tabela e função em `pg_temp` (medido). O G2 da 070 já fechou o sombreamento da função
adiada com `SET search_path = pg_catalog, public`. O que falta é a regra valer para **toda** função
de trigger, presente e futura. **O que fecha**: a conferência de FR-009 reprova função de trigger em
`public` sem `search_path` fixo (`proconfig`). `REVOKE TEMP ON DATABASE … FROM PUBLIC` fecharia de
vez, mas exige medir que nada da aplicação usa temporária; não medi.

### S11 — Informativo. O papel de hoje é, muito provavelmente, superusuário, e isso é maior que o G1

A imagem oficial do PostgreSQL cria o `POSTGRES_USER` como superusuário de bootstrap, e o Dokploy
usa essa imagem. Se o `DATABASE_URL` de produção for esse usuário (não verificado: é segredo, não o
li), uma injeção de SQL hoje alcança `COPY … TO PROGRAM` e `pg_read_server_files`: comando e arquivo
no contêiner do banco, e não só "desligar guardas". A feature fecha isso para o processo que serve,
o que vale a pena dizer na nota. E reforça S5: enquanto o papel que migra for o `postgres`, a
credencial que migra no contêiner é uma credencial de superusuário. A recomendação é tornar o
**dono dedicado não-superusuário** o estado-alvo do roteiro, e não opcional. Não medi o caminho de
transferência (`REASSIGN OWNED BY postgres` costuma ser recusado para o superusuário de bootstrap;
o caminho é `ALTER … OWNER TO` por objeto, executado por superusuário).

## Emendas propostas à spec, FR por FR

- **FR-001** — reescrever como condição sobre o papel, não sobre tabela:
  > O processo que serve MUST conectar com um papel que: não é superusuário nem tem `CREATEROLE`,
  > `CREATEDB`, `REPLICATION` ou `BYPASSRLS`; **não é dono de nenhum objeto da base** (tabela,
  > sequência, função, tipo, esquema, nem a própria base); **não é membro, direto ou herdado,** de
  > nenhum papel dono de objeto da base, nem de `pg_execute_server_program`,
  > `pg_read_server_files`, `pg_write_server_files` e `pg_signal_backend`; e é **diferente** do papel
  > que migra.
- **FR-002** — privilégios por nome, com as exceções:
  > `SELECT, INSERT, UPDATE, DELETE` em toda tabela da aplicação, **exceto `schema_migrations`, em que
  > não tem privilégio nenhum**; `USAGE, SELECT` nas sequências (sem `UPDATE`); `USAGE` no esquema
  > `public`; `CONNECT` na base. MUST NOT ter `TRUNCATE`, `REFERENCES`, `TRIGGER`, `CREATE` no esquema
  > ou na base, `SET` em `session_replication_role` (`pg_parameter_acl`), nem `ALL`. No PG17,
  > tampouco `MAINTAIN`.
- **FR-003** — acrescentar às quatro tentativas: `DROP FUNCTION <função de trigger> CASCADE`,
  `DROP TABLE`, `CREATE TABLE` em `public`, e `INSERT` em `schema_migrations`. A recusa é
  **`42501`** (`insufficient_privilege`); outra classe de erro **não** conta como recusa.
- **FR-004** — nomear a variável e dizer que **só o entrypoint a lê**; `config/runtime.exs` e `lib/`
  não conhecem o nome dela. O entrypoint a entrega ao `eval` da migração como `DATABASE_URL` do
  comando (`DATABASE_URL="$X" /app/bin/the_band eval …`), sem exportá-la. Nunca `set -x`.
- **FR-005** — trocar "privilégios padrão e concessão inicial" por:
  > A cada deploy, depois de migrar e com a credencial que migra, um passo **idempotente** MUST:
  > conceder FR-002 em todas as tabelas e sequências existentes; definir
  > `ALTER DEFAULT PRIVILEGES FOR ROLE <papel que migra> IN SCHEMA public` para tabelas e sequências;
  > e em seguida revogar tudo em `schema_migrations`. O nome do papel que serve vem do usuário do
  > `DATABASE_URL`, e nunca é escrito em migração.
  É o que torna a restauração e a transição auto-corretivas (S7), e tira o nome do papel das
  migrações (onde, se o papel não existisse, o `GRANT` derrubaria o deploy).
- **FR-006** — manter, e acrescentar o limite ou a correção de S5: ou "a credencial que migra MUST
  NOT estar no ambiente configurado do contêiner que serve" (opções a/b), ou o limite escrito: "FR-006
  protege o ambiente do processo que serve; processos abertos por `docker exec`, incluindo o
  `HEALTHCHECK`, recebem a credencial" (opção d, com risco residual na nota).
- **FR-007** — acrescentar: o `rollback/2` recebe a credencial que migra **só** pela atribuição no
  próprio comando, conforme o roteiro; e "nenhum comando de release lê a variável que migra" vira
  verificação (cenário A6).
- **FR-008** — separar os estados, e o veredito vem da medição, não da variável:

  | estado | o que acontece |
  |---|---|
  | credencial que migra ausente, e a que serve **consegue** migrar (é dona, o estado de hoje) | migra com ela e sobe, como decidido; relator `:nao_em_vigor` com `:credencial_que_migra_ausente` |
  | credencial que migra ausente, a que serve **não** consegue migrar, e **não há migração pendente** | **decidir**: subir sem migrar (exige conferir as pendentes lendo `schema_migrations` sem a `Ecto.Migrator`, que faz DDL), com relator `:nao_em_vigor`; ou não subir |
  | credencial que migra ausente, a que serve não consegue migrar, e **há migração pendente** | não sobe, com uma linha que nomeia a variável que falta. Subir sobre esquema pela metade é o que o próprio `set -e` existe para impedir |

  O terceiro estado contradiz "MUST subir" e é decisão da pessoa mantenedora — eu recomendo não
  subir. Em todos, a linha "separação NÃO em vigor" sai do relator, e a aplicação a repete em
  `warning` **a cada subida**.
- **FR-009** — a conferência roda **por `rpc`**, dentro do nó que serve, para medir o papel que de
  fato serve (por `eval` ela mediria o que o `runtime.exs` daquela VM ler). Ela:
  - lê o catálogo (sem lock): `rolsuper` e os outros atributos de FR-001; posse em `pg_class`,
    `pg_proc`, `pg_namespace`, `pg_type` e `pg_database`; `pg_has_role(…, 'MEMBER')` para cada dono
    e cada predefinido; `has_schema_privilege(…, 'public', 'CREATE')`;
    `has_database_privilege(…, 'CREATE')`; `pg_parameter_acl`; os privilégios em
    `information_schema.role_table_grants` comparados à lista **fechada** de FR-002; nada em
    `schema_migrations`; função de trigger em `public` sem `search_path` fixo (S10);
  - tenta as recusas de FR-003 numa transação que sempre termina em `ROLLBACK`, com
    `SET LOCAL lock_timeout = '200ms'`, e só aceita `42501` como recusa. Sucesso, `lock_not_available`
    ou qualquer outro código é **"NÃO em vigor"** ou **"inconclusivo"**, nunca "em vigor";
  - devolve o relator de FR-008, e a frase é tradução dele.
- **FR-010** — acrescentar ao roteiro: senha só `[0-9a-f]` (`openssl rand -hex 32`); conferir o
  `rolsuper` e a posse da base **antes** da troca, e não supor; nunca `GRANT <dono> TO <quem serve>`
  nem base com `OWNER` de quem serve, com o motivo; o ensaio do §6 cria os papéis no cluster de
  ensaio, serve pela credencial do papel que serve e termina com a conferência; a opção do dono
  dedicado não-superusuário como estado-alvo (S11).
- **FR-011** — acrescentar: o papel do teste recebe os privilégios **pelo mesmo artefato** que a
  produção usa (a lista de comandos de FR-005), e não por `GRANT` escrito no teste; e a asserção é
  sobre o código `42501` e sobre o trigger continuar ativo (`pg_trigger.tgenabled = 'O'`), nunca só
  sobre `Postgrex.Error` (a lição do G3 da 070).
- **FR-012** — acrescentar: erro de URL de banco é traduzido sem a URL (S6).
- **US1 cenário 5 / SC-002** — controle positivo por tentativa: as de estrutura com o dono; a de
  `session_replication_role` com superusuário, ou com um papel com `SET ON PARAMETER`, criado no
  teste.
- **US2 cenário 3** — "procurar a credencial" inclui o processo do `HEALTHCHECK` e um `docker exec`
  qualquer, ou a spec declara o limite (S5).
- **SC-003** — acrescentar o ensaio de fumaça do Oban (S9).
- **SC-005** — o ensaio serve pelo papel que serve, e a conferência diz "em vigor" no ambiente
  restaurado (S7).
- **Edge case `schema_migrations`** — vira requisito em FR-002 (S3).
- **Assumptions** — "o `pg_dump` preserva os `GRANT`s" é verdade só sem `--no-acl`/`--no-owner` e
  num cluster onde os papéis existem; trocar a afirmação pela verificação.

## Cenários de ataque para o QA

Formato: quem, com o quê, esperando o quê, e a asserção que importa. Todo teste roda dentro da
transação do sandbox, como o `postgres` do CI; o papel não-dono nasce ali com nome único
(`"serve_t_#{System.unique_integer([:positive])}"`) e morre no `ROLLBACK`. Cada tentativa em
`SAVEPOINT` próprio, porque erro aborta a transação. Antes das tentativas, **asserir que mediu**:
`SELECT current_user` é o papel criado, e `rolsuper` dele é `false`.

| # | Atacante e dado | Esperado | Asserção | Defeito a injetar (tem de reprovar) |
|---|---|---|---|---|
| A1 | SQL arbitrário como quem serve: `DISABLE TRIGGER`, `DROP TRIGGER`, `DROP CONSTRAINT`, `TRUNCATE`, `SET session_replication_role = replica` sobre as tabelas reais com guarda (`platform_operator_grants`, `tenant_suspensions`, `tenants`) | recusa | código `42501` em cada uma; depois, `tgenabled = 'O'` em cada trigger, a constraint existe, `SHOW session_replication_role` = `origin`, e a contagem de linhas não mudou | acrescentar `TRUNCATE` (e depois `TRIGGER`) à lista de concessão |
| A2 | o mesmo, com o papel **membro do dono** | o teste reprova | — | `GRANT <dono> TO <quem serve>` no artefato de concessão |
| A3 | `DROP FUNCTION tenant_estado_tem_episodio() CASCADE` e `CREATE TABLE public.x()` | recusa `42501`; o trigger adiado ainda existe | `pg_trigger` tem `tenants_estado_tem_episodio` | `ALTER SCHEMA public OWNER TO <quem serve>` (o caso que as quatro tentativas não pegam) |
| A4 | `INSERT INTO schema_migrations VALUES (<versão futura>, now())` | recusa `42501` | `count` de `schema_migrations` inalterado | tirar o `REVOKE` de `schema_migrations` do artefato |
| A5 | `GRANT SET ON PARAMETER session_replication_role TO <quem serve>` | a conferência de FR-009 diz `:nao_em_vigor` com `:replica_permitida` | o relator, e não a frase | — (é o próprio defeito) |
| A6 | o `eval` de qualquer comando de release com a variável que migra presente e o `DATABASE_URL` de quem serve | o `Repo` conecta como quem serve | `SELECT current_user` dentro do comando | `runtime.exs` lendo a variável que migra quando presente |
| A7 | `DATABASE_URL` com senha falsa contendo `/` (`"serve:SENHA/DE-TESTE@…"`) no `migrate/0` | erro que nomeia a variável | `refute` que a saída contém `"SENHA/DE-TESTE"` | deixar a exceção da Ecto subir crua |
| A8 | conferência de FR-009 com o papel que serve **igual** ao que migra (as duas URLs com o mesmo usuário) | `:nao_em_vigor`, `:mesma_credencial` | o relator | veredito tirado da presença da variável |
| A9 | o contêiner de pé com a variável que migra configurada (valor falso óbvio) | ausente no PID 1 **e** no processo do `HEALTHCHECK` (ou o limite escrito, se a opção for d) | contagem do **nome** em `/proc/1/environ` e em `/proc/<pid do docker exec>/environ`; nunca o valor | tirar o `unset` do entrypoint |
| A10 | controle positivo, `async: false`: as tentativas de estrutura como o dono, e `replica` como superusuário | passam | código de sucesso, dentro de `SAVEPOINT` desfeito | — (é a prova de que A1 mede privilégio, e não nome de trigger errado) |

A1, A3 e A4 também valem como asserção da conferência de FR-009: rodada com o papel do teste, ela
diz `:em_vigor`; com cada defeito injetado, diz `:nao_em_vigor` com o motivo certo.

## Risco residual para a nota da release

Enquanto a 071 não estiver em produção **com a conferência dizendo "em vigor"**:

- **o G1 está aberto**: a aplicação migra e serve com o mesmo papel, e quem executar SQL por ela
  desliga ou apaga as guardas do banco. Se esse papel for superusuário (não verificado; provável,
  S11), alcança também comando e arquivo no contêiner do banco.

Depois da 071 em vigor, o que continua aberto, e precisa estar escrito:

- **acesso a dado**: quem executa SQL ou código pelo processo que serve lê e escreve todo dado de
  todo tenant, insere job do Oban com argumentos quaisquer (a defesa é a validação de `tenant_id` do
  job, princípio V) e pode `NOTIFY` nos canais do Oban. A feature fecha o **desligar as guardas**;
- **quem tem o Dokploy tem a credencial que migra**: painel, `docker inspect`, terminal;
- **S5, se a opção for d**: quem executa código no contêiner como `band` colhe a credencial que migra
  no processo do `HEALTHCHECK`;
- **FR-008**: a produção pode seguir indefinidamente em "separação NÃO em vigor"; o que impede isso
  é a issue #1131 continuar aberta até a conferência dizer "em vigor" em produção (SC-004), e não o
  merge da feature;
- **a garantia vale para o que é criado pelo papel que migra**: tabela criada à mão por outro papel
  nasce sem privilégio para quem serve (medido) — é falha barulhenta, não silenciosa.

## O que NÃO verifiquei

- **O papel do `DATABASE_URL` de produção**: superusuário, dono, nome. É segredo e não o li. Também
  não li o ACL do `public` nem o dono da base de produção; os fatos de ACL são da base local.
- **As opções do backup do Dokploy** (`--no-acl`, `--no-owner`, formato) e se o ensaio do §6 já foi
  feito com elas.
- **O Dokploy**: se o terminal é `docker exec` com o ambiente configurado (presumi; medi o mecanismo
  no Docker local, não no VPS), se há passo de pré-deploy ou serviço de execução única, e se o
  contêiner antigo segue servindo quando o novo não sobe (S4).
- **O kernel do VPS**: medi a leitura de `/proc/<pid>/environ` entre processos do mesmo usuário no
  Docker Desktop local. Uma configuração que restrinja isso (`hidepid`, LSM) mudaria S5; não sei se
  existe lá.
- **O código do Oban 2.23.1**: não li. As afirmações sobre `Pruner`, peer e notificador vêm da
  configuração, das tabelas na base de dev e de `pg_notify`/`LISTEN` medidos. Algum caminho do Oban
  que exija mais que `SELECT/INSERT/UPDATE/DELETE` só aparece no ensaio de S9.
- **A `Ecto.Migrator` por dentro**: o `42501` de S4 foi medido no PostgreSQL com o comando
  equivalente; não li o código da `ecto_sql` 3.14.0 para confirmar que ela emite exatamente
  `CREATE TABLE IF NOT EXISTS` antes de qualquer outra coisa em toda execução.
- **PostgreSQL 17** (o do CI): nada medido nele.
- **Os testes que executam SQL de migração pela `Repo`**
  (`test/mix/tasks/confere_encerramentos_test.exs:78`,
  `test/the_band_web/sessao_pela_tabela_test.exs:236`): não li se é só DML. Se tiver DDL, reprovam
  sob o papel que serve em SC-003, e precisarão de uma conexão de dono.
- **As guardas da 070 reais**: as migrações com `nao_apaga`, `so_revoga`, `so_fecha`, `nao_trunca` e
  `tenant_estado_tem_episodio` não existem nesta branch. Medi com análogos no esquema temporário da
  transação, como a conferência da 070 fez.
- **Os comandos de release da 070** (T032, runbook §13): não estão nesta branch.
- **`REASSIGN OWNED BY postgres`** e o caminho de transferência de posse para um dono dedicado.
- **`REVOKE TEMP … FROM PUBLIC`**: não medi se algo da aplicação ou do Oban cria temporária.
- **Se o repositório é público** (o que torna S3 mais barato: a versão da próxima migração de guarda
  fica legível no PR).
- **O restante do produto**: esta é avaliação do desenho da 071, não varredura. Não rodei Sobelow,
  `hex.audit`, `deps.audit` nem `mix gates`.
