# Feature Specification: Os papéis do banco — o que migra e o que serve

**Feature Branch**: `feature/1131-papeis-do-banco`

**Created**: 2026-10-02

**Status**: Draft

**Input**: issue #1131. É o achado **G1** da conferência de segurança do trigger da spec 070
(`specs/070-operador-da-plataforma/seguranca-autenticacao.md`, "Conferência do trigger e do U1",
2026-10-02). A pessoa mantenedora decidiu em 2026-10-02: issue agora, implementação depois da 070.
O risco fica declarado na nota da release até lá.

A aplicação **migra e serve com o mesmo papel** do banco. Esse papel é dono das tabelas, ou
superusuário. Por isso o código que rode dentro da aplicação pode desligar toda guarda que vive no
banco: os triggers somente-acréscimo, o trigger adiado da 070, as `CHECK` e as FKs. Basta uma
injeção de SQL, um `eval` ou uma falha que execute SQL arbitrário.

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| a migração roda no entrypoint, antes do servidor, com o `DATABASE_URL` de quem serve | `rel/entrypoint.sh:27` (`TheBand.Release.migrate()`) |
| o repositório lê **uma** URL só, `DATABASE_URL` | `config/runtime.exs:76-87` |
| `semear_primeira_conta/0` roda por `eval` no entrypoint, depois da migração | `rel/entrypoint.sh`, `lib/the_band/release.ex:56` |
| `girar_sessoes/0`, `rotacionar_chave/0` e `saude_da_fila/0` rodam por `rpc`, dentro do nó que serve, com o papel dele | `lib/the_band/release.ex:140`, `:179`; runbook §10.2 e §12 |
| os comandos do operador da plataforma (070) rodam por `eval`, numa VM nova com o ambiente do contêiner | `lib/the_band/release.ex` (070/T032), runbook §13 |
| o Oban usa as tabelas `oban_*`, e o notificador do PostgreSQL usa `LISTEN/NOTIFY` | `config/config.exs:88-106` |
| o banco de produção foi criado pelo Dokploy (§4 do runbook), que usa o usuário `postgres` por padrão. **Não foi verificado** se o `DATABASE_URL` de produção usa esse usuário (superusuário) ou outro | `docs/producao/runbook.md` §4 |
| o backup é o agendado do Dokploy, e o ensaio de restauração usa `pg_dump -U postgres` | runbook §4 e §6 |
| as guardas que vivem no banco: `nao_apaga`, `so_revoga`, `so_fecha` e `nao_trunca` (070); o trigger adiado `tenant_estado_tem_episodio` (070/T044a); e todas as `CHECK` e FKs | `priv/repo/migrations/` |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A aplicação que serve não consegue desligar as guardas do banco (Priority: P1)

Quem opera a plataforma precisa que o registro somente-acréscimo continue somente-acréscimo
**mesmo quando algo dentro da aplicação foi comprometido**. Se uma injeção de SQL alcançar o banco
pelo processo que serve, ela não pode apagar a concessão do operador, reescrever um episódio de
suspensão, nem deixar uma organização suspensa sem episódio.

**Why this priority**: é o defeito de segurança. Sem esta história, as guardas da 064, da 070 e de
toda `CHECK` protegem só de engano, e não de ataque.

**Independent Test**: conectado com o papel que serve, tentar desligar um trigger, apagar uma
constraint, truncar uma tabela e pular os triggers da sessão. As quatro tentativas são recusadas
por falta de privilégio. As escritas normais da aplicação passam.

**Acceptance Scenarios**:

1. **Given** o processo que serve, **When** ele tenta `ALTER TABLE … DISABLE TRIGGER`, **Then** o
   banco recusa por falta de privilégio, e o trigger continua ativo.
2. **Given** o processo que serve, **When** ele tenta `DROP TRIGGER`, `DROP CONSTRAINT` ou
   `TRUNCATE`, **Then** o banco recusa, e nada muda.
3. **Given** o processo que serve, **When** ele tenta `SET session_replication_role = replica`,
   **Then** o banco recusa, e os triggers continuam disparando na sessão.
4. **Given** o processo que serve, **When** ele lê, insere, altera e apaga linhas como a aplicação
   faz hoje (telas, API, MCP, coleta, Oban), **Then** tudo passa como antes.
5. **Given** a mesma bateria, **When** cada tentativa roda com o papel que tem o privilégio dela,
   **Then** ela passa: as de estrutura, com o dono; a de `session_replication_role`, com um papel que
   tem `SET` nesse parâmetro. É o controle positivo, **por tentativa**: um dono que não é
   superusuário também recebe a recusa no `session_replication_role` (medido, `seguranca.md` S2).

---

### User Story 2 - A migração continua acontecendo sozinha no deploy (Priority: P1)

Quem publica uma versão precisa que as migrações continuem rodando no entrypoint, como hoje, sem
passo manual. Agora elas rodam com o papel que é dono do esquema, e esse papel não fica ao alcance
do processo que serve.

**Why this priority**: sem isto, separar os papéis quebraria o deploy, e o conserto de segurança
viraria uma indisponibilidade.

**Independent Test**: num ambiente com os dois papéis, um deploy com uma migração nova aplica a
migração, a aplicação sobe e serve, e a credencial do papel que migra não está no ambiente do
processo que serve.

**Acceptance Scenarios**:

1. **Given** os dois papéis e as duas credenciais configuradas, **When** o contêiner sobe, **Then**
   a migração roda com o papel que migra, e a aplicação serve com o papel que serve.
2. **Given** uma tabela nova criada por uma migração, **When** a aplicação a usa, **Then** o papel
   que serve tem nela os mesmos privilégios das outras, sem passo manual.
3. **Given** o processo que serve já de pé, **When** se procura a credencial do papel que migra no
   ambiente **dele**, **Then** ela não está lá. **O limite, decidido em 2026-10-02**: processos
   abertos por `docker exec`, inclusive o `HEALTHCHECK`, recebem o ambiente configurado do contêiner,
   e código dentro do processo que serve pode lê-los em `/proc` (medido, S5). Isso fica como risco
   residual, e não como garantia.
4. **Given** a credencial do papel que migra ausente no deploy, **When** o contêiner sobe, **Then**
   o resultado segue os três estados de FR-008, e em nenhum deles a aplicação serve sobre esquema
   pela metade.

---

### User Story 3 - Quem opera sabe criar os papéis, e o backup continua restaurável (Priority: P2)

A pessoa mantenedora precisa de um roteiro para criar os dois papéis em produção, trocar as
credenciais no painel e conferir que a separação está em vigor. O backup e a restauração precisam
continuar funcionando com os papéis novos.

**Why this priority**: a correção só vale em produção depois desse passo humano. O backup é o que
não pode quebrar em silêncio.

**Independent Test**: seguir o roteiro num ambiente local criado do zero, restaurar um backup feito
antes da troca, e conferir que a aplicação serve e que as quatro tentativas da US1 continuam
recusadas.

**Acceptance Scenarios**:

1. **Given** o roteiro, **When** quem não escreveu a feature o segue, **Then** os dois papéis
   existem, as credenciais estão no painel, e a conferência da US1 passa contra o ambiente.
2. **Given** um backup feito antes da troca, **When** ele é restaurado depois dela, **Then** a
   aplicação serve com o papel que serve, e os privilégios dele estão corretos.
3. **Given** o roteiro, **When** ele é lido, **Then** nenhuma credencial aparece nele. Os valores
   são gerados por quem opera, e não passam por chat, commit nem log.

### Edge Cases

- **O papel que serve hoje pode ser superusuário.** Superusuário ignora privilégios. A troca precisa
  de um papel **novo**, sem superusuário, e o roteiro manda conferir isso, e não supor.
- **`schema_migrations`**: o papel que serve não migra, mas a aplicação pode ler a tabela (o
  Phoenix confere migrações pendentes só em dev). O papel que serve não escreve nela.
- **Os comandos de release.** Os que rodam por `rpc` herdam o papel que serve, e isso basta: só
  leem e escrevem linhas. Os que rodam por `eval` sobem uma VM nova, com o ambiente do contêiner, e
  precisam usar o papel que serve, e não o que migra.
- **`rollback/2` de release** (`release.ex:199`) desfaz migração e precisa do papel que migra.
- **O Oban.** As tabelas `oban_*` vêm das migrações, e precisam dos mesmos privilégios das outras.
  `LISTEN/NOTIFY` não exige privilégio de tabela no PostgreSQL.
- **As sequências.** Tabela com chave inteira precisa de `USAGE` na sequência para inserir.
- **O teste da guarda em CI** precisa de um papel não-dono na base de teste. Criá-lo exige um papel
  com privilégio de criar papéis, que o CI tem (`postgres`). Isso não vale em produção.
- **Uma tabela criada fora de migração**, à mão, por quem tem o banco, não recebe os privilégios
  padrão se o criador não for o papel que migra. O roteiro diz isso.

## Requirements *(mandatory)*

### Functional Requirements

> **Emendado em 2026-10-02** pela avaliação do agente `security` (`seguranca.md`, S1 a S10) e pelas
> decisões da pessoa mantenedora sobre S4, S5 e S11.

- **FR-001**: O processo que serve MUST conectar com um papel que:
  - não é superusuário, nem tem `CREATEROLE`, `CREATEDB`, `REPLICATION` ou `BYPASSRLS`;
  - **não é dono de nenhum objeto da base**: tabela, sequência, função, tipo, esquema, nem a
    própria base;
  - **não é membro**, direto ou herdado, de nenhum papel dono de objeto da base, nem de
    `pg_execute_server_program`, `pg_read_server_files`, `pg_write_server_files` ou
    `pg_signal_backend`;
  - é **diferente** do papel que migra (S1).
- **FR-002**: O papel que serve MUST ter **exatamente** estes privilégios, por nome e nunca `ALL`:
  - `SELECT, INSERT, UPDATE, DELETE` em toda tabela da aplicação, inclusive as do Oban,
    **exceto `schema_migrations`**, em que não tem privilégio nenhum (S3);
  - `USAGE, SELECT` nas sequências, sem `UPDATE`;
  - `USAGE` no esquema `public` e `CONNECT` na base.

  Ele MUST NOT ter `TRUNCATE`, `REFERENCES`, `TRIGGER`, `CREATE` no esquema ou na base, nem `SET`
  em `session_replication_role`. No PostgreSQL 17, também não `MAINTAIN` (S8).
- **FR-003**: Estas tentativas MUST ser recusadas ao papel que serve com o código **`42501`**
  (`insufficient_privilege`):
  - desligar um trigger (`DISABLE TRIGGER`);
  - apagar um trigger, uma constraint, uma função de trigger (`DROP FUNCTION … CASCADE`) ou uma
    tabela;
  - truncar;
  - criar tabela em `public`;
  - mudar `session_replication_role`;
  - inserir em `schema_migrations`.

  Outra classe de erro **não** conta como recusa.
- **FR-004**: A migração MUST rodar no entrypoint com o papel que migra, por uma credencial
  **separada**, numa variável que **só o entrypoint lê**. `config/runtime.exs` e `lib/` não
  conhecem o nome dela. O entrypoint a entrega só ao comando da migração e nunca a exporta, nem com
  `set -x`.
- **FR-005**: A cada deploy, depois de migrar e com a credencial que migra, um passo **idempotente**
  MUST:
  - conceder FR-002 em todas as tabelas e sequências existentes;
  - definir os privilégios padrão `FOR ROLE <papel que migra>` para tabelas e sequências novas;
  - revogar tudo em `schema_migrations`.

  O nome do papel que serve vem do usuário da credencial que serve, e nunca é escrito em migração.
  É o que torna a transição e a restauração auto-corretivas (S7).
- **FR-006**: O entrypoint MUST tirar a credencial do papel que migra do ambiente **antes** de
  iniciar o servidor. FR-006 protege o ambiente **do processo que serve**, e não o contêiner.
  **Decidido em 2026-10-02 (S5, opção "aceitar e declarar")**: o `HEALTHCHECK` e qualquer
  `docker exec` recebem o ambiente configurado do contêiner, com a credencial. Isso é risco
  residual, nomeado na nota da release, com issue para levar a migração para fora do contêiner que
  serve.
- **FR-007**: Os comandos de release MUST usar o papel que serve, salvo `rollback/2`, que recebe a
  credencial que migra **só** pela atribuição no próprio comando, como diz o roteiro. Nenhum
  comando de release lê a variável que migra, e isso é verificado (cenário A6 de `seguranca.md`).
- **FR-008**: O veredito de "separação em vigor" MUST vir de uma **medição no banco**, e não da
  presença da variável. Com a credencial que migra ausente:

  | estado | o que acontece |
  |---|---|
  | a credencial que serve **consegue** migrar (é dona, o estado de hoje) | migra com ela e sobe, como decidido em 2026-10-02; o relator diz "separação NÃO em vigor: credencial que migra ausente" |
  | a que serve **não** consegue migrar, e **não há migração pendente** | sobe sem migrar; o relator diz "separação em vigor no banco, credencial que migra ausente" (decidido em 2026-10-02). As pendentes se conferem lendo `schema_migrations` sem a `Ecto.Migrator`, que faz DDL |
  | a que serve não consegue migrar, e **há migração pendente** | **não sobe**, com uma linha que nomeia a variável que falta (decidido em 2026-10-02) |

  Em todos, a linha do relator sai no log do deploy, e a aplicação a repete em `warning` a cada
  subida (S4).
- **FR-009**: Uma conferência MUST rodar por `rpc`, dentro do nó que serve, para medir o papel que
  de fato serve. Ela:
  - lê o catálogo, sem lock: os atributos e as pertenças de FR-001, as posses, os privilégios
    comparados à lista **fechada** de FR-002, `schema_migrations` sem privilégio, e as funções de
    trigger em `public` sem `search_path` fixo (S10);
  - tenta as recusas de FR-003 numa transação que sempre termina em `ROLLBACK`, com
    `lock_timeout` curto, e só aceita `42501` como recusa. Sucesso, `lock_not_available` ou outro
    código dão "NÃO em vigor" ou "inconclusivo", e nunca "em vigor";
  - devolve o relator de FR-008. A frase é tradução dele, e a conferência não altera nada.
- **FR-010**: O roteiro de operação MUST cobrir:
  - **o estado-alvo, decidido em 2026-10-02 (S11)**: um papel que migra **dedicado e não
    superusuário**, `the_band_owner`, que recebe a posse uma vez (`REASSIGN OWNED`, como
    `postgres`), ficando o `postgres` só para administração e backup;
  - a criação do papel que serve;
  - conferir `rolsuper` e a posse da base **antes** da troca, e não supor;
  - nunca `GRANT <dono> TO <quem serve>`, nem base com `OWNER` de quem serve, com o motivo;
  - senha só hexadecimal (`openssl rand -hex 32`, S6);
  - a troca das duas credenciais no painel;
  - o ensaio do runbook §6 criando os papéis no cluster de ensaio, servindo pela credencial que
    serve e terminando com a conferência de FR-009 (S7).

  Nenhum valor de credencial aparece no roteiro.
- **FR-011**: Um teste MUST provar FR-003 conectado com um papel equivalente ao que serve.
  - O papel recebe os privilégios **pelo mesmo artefato** que a produção usa (o passo de FR-005), e
    não por `GRANT` escrito no teste.
  - A asserção é sobre o código `42501` e sobre o trigger continuar ativo (`tgenabled = 'O'`).
  - O teste MUST ser visto reprovando com o controle positivo de US1-5.
- **FR-012**: As credenciais dos dois papéis MUST NOT passar por chat, commit, log ou mensagem de
  erro. Um erro de URL de banco é traduzido sem a URL, porque `Ecto.InvalidURLError` a imprime
  (medido, S6). A conferência e os logs nomeiam o papel, e nunca a senha.

### Key Entities

- **Papel que migra**: `the_band_owner`, dono do esquema e não superusuário (S11); criado por quem
  opera; usado só pelo passo de migração, pelo passo de concessão de FR-005 e pelo `rollback`.
- **Papel que serve**: sem posse e sem superusuário; usado por toda requisição, job e comando de
  release que não migra.
- **Privilégios padrão**: a regra do banco que dá ao papel que serve os privilégios de FR-002 em
  cada tabela e sequência nova criada pelo papel que migra.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com o papel que serve, 4 de 4 tentativas de desligar guardas (trigger, constraint,
  truncamento, réplica de sessão) são recusadas, e 0 guardas ficam desligadas depois delas.
- **SC-002**: No ambiente de teste, cada tentativa de FR-003 passa com o papel que tem o privilégio
  dela (o controle positivo de US1-5). É a prova de que a medição mede.
- **SC-003**: A suíte inteira da aplicação passa com o processo conectado pelo papel que serve. Um
  ensaio de fumaça com o Oban ligado também passa: enfileira, executa e apaga job (S9). Ou seja,
  nenhuma funcionalidade dependia de ser dono.
- **SC-004**: Depois do deploy que introduz os papéis, a conferência de FR-009 contra a produção
  diz "em vigor". Antes de a pessoa mantenedora criar os papéis, ela diz "não em vigor", e diz por
  quê.
- **SC-005**: Um backup feito antes da troca é restaurado num cluster de ensaio com os papéis, e a
  aplicação serve pela credencial que serve. A conferência de FR-009 diz "em vigor" no ambiente
  restaurado, porque o passo de FR-005 reaplica as concessões (S7).

## Assumptions

- **O estado-alvo é o dono dedicado** (`the_band_owner`, não superusuário), decidido em 2026-10-02
  (S11). O roteiro transfere a posse uma vez. Até o roteiro ser seguido, o papel que migra é o dono
  atual, e a conferência diz isso.
- **Os papéis não entram no `pg_dump`**, e os `GRANT`s só voltam num cluster em que os papéis
  existem, sem `--no-acl`. A restauração não é suposta correta: ela é conferida, e o passo de FR-005
  a corrige no deploy seguinte (S7).
- `LISTEN/NOTIFY`, usado pelo Oban, não exige privilégio de tabela (medido). A única sequência é
  `oban_jobs_id_seq`. `gen_random_uuid` é do núcleo do PostgreSQL 16.
- O CI usa PostgreSQL 17 e a produção usa 16. A lista de privilégios vai por nome, e o teste confere
  os dois modelos (S8).
- **O que esta feature não fecha** (risco residual, para a nota da release):
  - **a credencial que migra no contêiner** (S5, decidido aceitar e declarar): o `HEALTHCHECK` e
    todo `docker exec` a recebem, e código no processo que serve pode lê-la em `/proc`. Há issue
    para levar a migração para fora do contêiner que serve;
  - quem tem o terminal do Dokploy tem o contêiner, e com ele a credencial;
  - uma execução de código arbitrário no processo que serve tem o papel que serve, e com ele lê e
    escreve todo dado de todo tenant. A feature fecha o **desligar as guardas**, e não o acesso a
    dado;
  - `TEMP` continua concedido a `PUBLIC` na base. Por isso toda função de trigger precisa de
    `search_path` fixo, e a conferência o verifica (S10).
- A avaliação do agente `security` foi feita em 2026-10-02, por quem não escreveu este desenho
  (`seguranca.md`). Ela vem antes do plano.
