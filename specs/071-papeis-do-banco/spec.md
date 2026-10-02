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
5. **Given** a mesma bateria, **When** ela roda com o papel que migra, **Then** as tentativas dos
   cenários 1 a 3 passam. É a prova de que o teste mede o privilégio, e não outra coisa.

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
   ambiente dele, **Then** ela não está lá.
4. **Given** a credencial do papel que migra ausente no deploy, **When** o contêiner sobe, **Then**
   a migração roda com a credencial que serve, como hoje, a aplicação sobe, e o log do deploy e a
   conferência de FR-009 dizem "separação NÃO em vigor" (decisão da pessoa mantenedora,
   2026-10-02).

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

- **FR-001**: O processo que serve MUST conectar ao banco com um papel que **não é dono** de nenhuma
  tabela do esquema e **não é superusuário**.
- **FR-002**: O papel que serve MUST ter só os privilégios que a aplicação usa:
  - ler, inserir, alterar e apagar linhas em todas as tabelas da aplicação, incluindo as do Oban;
  - usar as sequências.

  Ele MUST NOT ter `TRUNCATE`, `REFERENCES`, `TRIGGER`, nem nenhum privilégio de alterar estrutura.
- **FR-003**: Desligar ou apagar um trigger, apagar uma constraint, truncar uma tabela e mudar
  `session_replication_role` MUST ser recusados ao papel que serve, por falta de privilégio.
- **FR-004**: A migração MUST rodar no entrypoint com um papel que é dono do esquema, por uma
  credencial **separada** da que serve.
- **FR-005**: Toda tabela e sequência criada por migração MUST nascer com os privilégios de FR-002
  para o papel que serve, sem passo manual: por privilégios padrão, e por uma concessão inicial às
  que já existem.
- **FR-006**: O entrypoint MUST tirar a credencial do papel que migra do ambiente **antes** de
  iniciar o servidor. Ela não pode estar no ambiente do processo que serve.
- **FR-007**: Os comandos de release que rodam por `eval` MUST usar o papel que serve, salvo
  `rollback/2`, que usa o papel que migra. Nenhum comando de release escreve o esquema fora de
  migração.
- **FR-008**: Se a credencial do papel que migra faltar no deploy, a migração MUST rodar com a
  credencial que serve, como hoje, e a aplicação MUST subir. O log do deploy MUST dizer, numa linha
  própria, "separação NÃO em vigor", e a conferência de FR-009 MUST dizer o mesmo, com o motivo.
  **Decidido pela pessoa mantenedora em 2026-10-02**: manter a produção no ar. O G1 continua aberto
  até as credenciais existirem, e isso fica declarado na nota da release.
- **FR-009**: Uma conferência operável pela pessoa mantenedora MUST dizer, contra o ambiente, se a
  separação está em vigor:
  - o papel que serve não é dono nem superusuário;
  - as tentativas de FR-003 são recusadas.

  A conferência não pode alterar nada.
- **FR-010**: O roteiro de operação MUST cobrir:
  - a criação dos dois papéis, sem superusuário para o que serve;
  - a concessão inicial;
  - a troca das credenciais no painel;
  - a conferência de FR-009;
  - o backup e a restauração com os papéis novos.

  Nenhum valor de credencial pode aparecer no roteiro.
- **FR-011**: Um teste MUST provar FR-003 conectado com um papel equivalente ao que serve, e MUST
  ser visto reprovando quando o papel tem privilégio de dono.
- **FR-012**: As credenciais dos dois papéis MUST NOT passar por chat, commit, log ou mensagem de
  erro. A conferência e os logs nomeiam o papel, e nunca a senha.

### Key Entities

- **Papel que migra**: dono do esquema; criado por quem opera; usado só pelo passo de migração e
  pelo `rollback`.
- **Papel que serve**: sem posse e sem superusuário; usado por toda requisição, job e comando de
  release que não migra.
- **Privilégios padrão**: a regra do banco que dá ao papel que serve os privilégios de FR-002 em
  cada tabela e sequência nova criada pelo papel que migra.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com o papel que serve, 4 de 4 tentativas de desligar guardas (trigger, constraint,
  truncamento, réplica de sessão) são recusadas, e 0 guardas ficam desligadas depois delas.
- **SC-002**: Com o papel que migra, as mesmas 4 tentativas passam, no ambiente de teste. É a prova
  de que a medição mede.
- **SC-003**: A suíte inteira da aplicação passa com o processo conectado pelo papel que serve. Ou
  seja, nenhuma funcionalidade dependia de ser dono.
- **SC-004**: Depois do deploy que introduz os papéis, a conferência de FR-009 contra a produção
  diz "em vigor". Antes de a pessoa mantenedora criar os papéis, ela diz "não em vigor", e diz por
  quê.
- **SC-005**: Um backup feito antes da troca é restaurado depois dela, e a aplicação serve sem
  intervenção manual nos privilégios.

## Assumptions

- **O papel que migra é o dono atual das tabelas em produção**, qualquer que seja ele. A feature
  **cria só o papel que serve** e não transfere posse. Transferir posse (`REASSIGN OWNED`) exigiria
  superusuário e não é necessário para fechar o G1. Se a pessoa mantenedora preferir um dono
  dedicado (`the_band_owner`) no lugar do `postgres`, é passo do roteiro, opcional.
- O backup do Dokploy roda com o usuário administrativo do banco, e não com o papel que serve. Ele
  preserva os `GRANT`s, porque o `pg_dump` os inclui por padrão. A restauração os recria.
- `LISTEN/NOTIFY`, usado pelo Oban, não exige privilégio de tabela.
- **O que esta feature não fecha** (risco residual, para a nota da release):
  - quem tem o terminal do Dokploy tem o contêiner, e pode ler a credencial do papel que migra no
    ambiente do contêiner antes do `unset`, ou abrir uma VM por `eval` com ela;
  - uma execução de código arbitrário dentro do processo que serve não tem a credencial (FR-006),
    mas tem o papel que serve, e com ele lê e escreve todo dado de todo tenant.

  A feature fecha o **desligar as guardas**, e não o acesso a dado.
- A avaliação do agente `security` vem antes do plano (AGENTS §14.0: acesso e dependência de
  infraestrutura). Ela é de quem não escreveu este desenho.
