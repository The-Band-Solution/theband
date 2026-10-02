# Tasks: Os papéis do banco — o que migra e o que serve

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/papeis.md](contracts/papeis.md), [quickstart.md](quickstart.md), [seguranca.md](seguranca.md)

**Tarefas humanas** são marcadas com **👤 pessoa mantenedora**. São as que dependem de acesso à
produção ou ao Dokploy. Nenhuma credencial passa por chat, commit ou log (FR-012).

## Fase 1: Setup

- [ ] T001 Conferir o estado de partida
  - **Pronta quando**: nada além do repositório
  - **Descrição**: confirmar em `development` que:
    - `rel/entrypoint.sh` migra com `DATABASE_URL`;
    - `config/runtime.exs` lê só `DATABASE_URL`;
    - o `HEALTHCHECK` do `Dockerfile` roda `rpc`.

    Registrar a versão do PostgreSQL do CI (`.github/workflows/ci.yml`) e a do `compose.yaml` (S8).
  - **Feita quando**: os quatro fatos estão no PR, com `arquivo:linha`
  - **Teste**: a revisão confere os quatro `arquivo:linha` contra o código

## Fase 2: Fundação

- [ ] T002 Conceder os privilégios de quem serve
  - **Pronta quando**: `contracts/papeis.md`, seção `conceder/2`; T001
  - **Descrição**: `lib/the_band/papeis.ex`, `conceder(repo, papel_que_serve)`, os seis passos do
    contrato.
    - O nome do papel entra por `format('%I', $1)` dentro de um bloco `DO`, nunca por interpolação
      Elixir.
    - Levanta, sem credencial na mensagem, se o papel não existe ou se é igual a `current_user`.
    - FR-002, FR-005, R2.
  - **Feita quando**: depois de conceder, um papel novo:
    - lê, insere, altera e apaga em toda tabela, menos `schema_migrations`, onde só lê;
    - não tem `TRUNCATE`, `REFERENCES` nem `TRIGGER`;
    - rodar duas vezes dá o mesmo estado.
  - **Teste**: `test/the_band/papeis_test.exs`, "conceder": `has_table_privilege` para cada
    privilégio, em toda tabela. **Defeitos a injetar**, um por vez:
    - acrescentar `TRUNCATE` à lista (A1);
    - tirar o `REVOKE` de `schema_migrations` (A4).

- [ ] T003 Provar que quem serve não desliga as guardas
  - **Pronta quando**: T002
  - **Descrição**: em `papeis_test.exs`, `async: false`, os cenários A1, A3, A4 e A10 de
    `seguranca.md`.
    - Num `CREATE ROLE serve_t_<n> NOLOGIN` do sandbox, concedido por `conceder/2` (o mesmo artefato
      da produção), fazer `SET LOCAL ROLE`.
    - Cada tentativa vai num `SAVEPOINT`.
    - Asserir antes que mediu: `current_user` e `rolsuper`.
    - Como esta branch não tem as guardas da 070, usar um trigger e uma constraint criados no próprio
      teste, e, quando a 070 estiver em `development`, também os reais.
    - FR-003, FR-011, SC-001, SC-002.
  - **Feita quando**:
    - as tentativas de FR-003 dão `42501`;
    - depois delas, `tgenabled = 'O'`, a constraint existe e as contagens não mudaram;
    - o controle positivo (A10) passa com o `postgres`, por tentativa.
  - **Teste**: o próprio arquivo. **Defeitos a injetar**:
    - `GRANT <dono> TO <papel>` (A2);
    - `ALTER SCHEMA public OWNER TO <papel>` (A3).

    Cada um tem de reprovar.

- [ ] T004 Conferir no banco se a separação está em vigor
  - **Pronta quando**: `contracts/papeis.md`, seção `conferir/1`; T002
  - **Descrição**: `Papeis.conferir(repo)` devolve o relator de `data-model.md`. A leitura de
    catálogo e as tentativas seguem a FR-009 e a R3: `lock_timeout` de 200 ms, sempre `ROLLBACK`, e
    só `42501` conta como recusa. Também `Papeis.pendentes(repo)`, pela R4.
  - **Feita quando**:
    - com o papel do teste, o relator é `{:em_vigor, []}`;
    - com cada defeito de A2, A3 e A5, é `:nao_em_vigor` com o motivo certo;
    - com o papel que migra igual ao que serve, é `:mesma_credencial` (A8);
    - depois da conferência, nada mudou.
  - **Teste**: `papeis_test.exs`, "conferir", um caso por motivo. **Defeito a injetar**: aceitar
    qualquer `Postgrex.Error` como recusa; o caso `lock_not_available` precisa reprovar.

## Fase 3: US1 — quem serve não desliga as guardas (P1)

- [ ] T005 [US1] A suíte inteira como quem serve
  - **Pronta quando**: T002
  - **Descrição**: rodar a suíte com o `Repo` de teste conectado por um papel concedido por
    `conceder/2`, na forma do quickstart §2. Inclui a fumaça do Oban ligado: enfileirar, executar e
    apagar um job (S9). SC-003.
  - **Feita quando**: a suíte dá `EXIT=0` como quem serve; a fumaça do Oban passa
  - **Teste**: o log com o `EXIT`, colado na issue. Qualquer `42501` na suíte é funcionalidade que
    dependia de ser dono, e vira tarefa

## Fase 4: US2 — a migração continua sozinha no deploy (P1)

- [ ] T006 [US2] Migrar e conceder com a credencial que migra
  - **Pronta quando**: `contracts/papeis.md`, seção `TheBand.Release`; T002
  - **Descrição**: `Release.migrate/0` migra e chama `conceder/2` com o usuário de
    `THE_BAND_URL_QUE_SERVE`. `Ecto.InvalidURLError` é traduzido sem a URL (S6, FR-012).
  - **Feita quando**:
    - depois de `migrate/0`, o papel que serve tem os privilégios de FR-002;
    - uma URL com `/` na senha dá a frase, sem a senha (A7).
  - **Teste**: `test/the_band/release_papeis_test.exs`. **Defeito a injetar**: deixar a exceção
    subir crua; o `refute` da senha precisa reprovar.

- [ ] T007 [US2] Os três estados sem a credencial que migra
  - **Pronta quando**: T004 e T006
  - **Descrição**: `Release.migrar_sem_credencial/0`, com os três estados de R4:
    - quem serve é dono: migra, e a linha diz "NÃO em vigor";
    - não é dono e não há pendente: sobe sem migrar;
    - não é dono e há pendente: levanta nomeando `DATABASE_MIGRATION_URL`.

    A linha sai do relator. FR-008, decisões de 2026-10-02.
  - **Feita quando**: os três estados são produzidos por casos, e a mensagem do terceiro nomeia a
    variável e não contém credencial
  - **Teste**: `release_papeis_test.exs`, um caso por estado. **Defeito a injetar**: usar a
    `Ecto.Migrator` para ler as pendentes; o segundo estado precisa reprovar com `42501`.

- [ ] T008 [US2] O entrypoint com as duas credenciais
  - **Pronta quando**: T006 e T007
  - **Descrição**: `rel/entrypoint.sh` na forma do contrato.
    - A credencial que migra vai só na linha do `eval` da migração.
    - `unset DATABASE_MIGRATION_URL` antes do `exec`.
    - `semear_primeira_conta` roda com o `DATABASE_URL`.
    - Nenhum `set -x` e nenhum eco de variável.

    FR-004, FR-006.
  - **Feita quando**:
    - no contêiner de pé, o nome da variável aparece 0 vezes em `/proc/1/environ`;
    - o processo do `HEALTHCHECK` a tem, e o número vai para a nota (limite S5);
    - `config/runtime.exs` e `lib/` não contêm o nome da variável.
  - **Teste**: o quickstart §3, com o resultado na issue. Um teste em `release_papeis_test.exs` lê
    `config/runtime.exs` e o código de `lib/`, sem comentários, e afirma a ausência do nome (A6).
    **Defeito a injetar**: tirar o `unset`; a contagem do PID 1 precisa dar 1.

- [ ] T009 [US2] O aviso a cada subida
  - **Pronta quando**: T004
  - **Descrição**: em `lib/the_band/application.ex`, um `Task` sem link, depois do `Repo`, roda
    `Papeis.conferir/1` e emite `Logger.warning` quando o veredito não é `:em_vigor`. Uma falha vira
    `:inconclusivo` e não derruba o boot. R5.
  - **Feita quando**: com o papel de dono, o boot do teste emite a linha; com a conferência
    levantando, o boot continua
  - **Teste**: `release_papeis_test.exs` com `capture_log`. **Defeito a injetar**: o `Task` linkado;
    o caso da conferência que levanta precisa derrubar o processo de teste.

- [ ] T010 [US2] A conferência por `rpc`
  - **Pronta quando**: T004
  - **Descrição**: `Release.conferir_papeis/0` traduz o relator em frase, com os motivos e sem
    credencial. O runbook diz o comando `rpc`. FR-009.
  - **Feita quando**: a frase de cada veredito existe; a saída nunca contém senha nem URL
  - **Teste**: `release_papeis_test.exs`, um caso por veredito, com `refute` da URL do teste na
    saída.

## Fase 5: US3 — o roteiro, e o backup restaurável (P2)

- [ ] T011 [US3] Escrever o roteiro dos papéis
  - **Pronta quando**: T008 e T010
  - **Descrição**: `docs/producao/runbook.md` §14. Cobre:
    - conferir `rolsuper` e a posse antes, e não supor;
    - criar `the_band_owner` e `the_band_app`, com senha `openssl rand -hex 32`;
    - o `REASSIGN OWNED BY postgres TO the_band_owner`, na base da aplicação, como `postgres`;
    - por que nunca `GRANT <dono> TO <quem serve>`;
    - as duas variáveis no Dokploy **antes** do merge;
    - a conferência por `rpc`;
    - o `rollback/2` com a credencial na linha.

    FR-010, S11.
  - **Feita quando**: o roteiro não contém credencial que pareça real; quem não escreveu o roteiro o
    segue num ambiente local e chega à conferência "em vigor"
  - **Teste**: a execução por outra pessoa, com o resultado na issue

- [ ] T012 [US3] O ensaio de restauração com os papéis
  - **Pronta quando**: T011
  - **Descrição**: o runbook §6 passa a:
    - criar os papéis no cluster de ensaio;
    - restaurar o backup;
    - subir servindo pela credencial que serve;
    - terminar com a conferência.

    SC-005, S7.
  - **Feita quando**: um backup de antes da troca, restaurado, serve, e a conferência diz "em vigor"
  - **Teste**: o ensaio local registrado em `docs/producao/`, com o `EXIT` de cada passo

## Fase 6: Produção — 👤 pessoa mantenedora

- [ ] T013 👤 Medir o papel de hoje em produção
  - **Pronta quando**: T011
  - **Descrição**: no terminal do banco no Dokploy, rodar as consultas do roteiro §14.1 (`rolsuper`, a
    posse da base, as opções do backup agendado). Registrar o resultado sem credencial
  - **Feita quando**: a issue diz se o `DATABASE_URL` de hoje é superusuário, quem é o dono, e se o
    backup usa `--no-acl`
  - **Teste**: o registro na issue, conferido contra a saída colada (sem senha)

- [ ] T014 👤 Criar os papéis e transferir a posse
  - **Pronta quando**: T013
  - **Descrição**: o runbook §14.2: criar `the_band_owner` e `the_band_app` e rodar `REASSIGN OWNED`.
    As senhas são geradas e guardadas pela pessoa mantenedora, e nunca passam por chat
  - **Feita quando**: os dois papéis existem, e `the_band_owner` é dono de todo objeto da base
  - **Teste**: as consultas de §14.3, coladas sem senha

- [ ] T015 👤 Configurar as duas credenciais no Dokploy
  - **Pronta quando**: T014; **antes** do merge da feature
  - **Descrição**: `DATABASE_MIGRATION_URL` com `the_band_owner`, e `DATABASE_URL` com `the_band_app`
  - **Feita quando**: depois do deploy, `rpc` da conferência diz "em vigor" (SC-004)
  - **Teste**: a saída da conferência colada na issue #1131

## Fase 7: Acabamento

- [ ] T016 Escrever a nota de riscos da release
  - **Pronta quando**: T008
  - **Descrição**: o risco residual de `seguranca.md`:
    - o acesso a dado por quem serve;
    - o Dokploy, que tem a credencial;
    - S5, com o número medido em T008 e a #1140;
    - FR-008, que pode deixar a produção em "NÃO em vigor".
  - **Feita quando**: cada risco tem quem aceitou e quando
  - **Teste**: a revisão do Product Owner encontra os quatro

- [ ] T017 Rodar os gates e abrir o PR
  - **Pronta quando**: T002 a T012 e T016
  - **Descrição**: `mix gates > log 2>&1; echo "GATES_EXIT=$?" >> log`; corpo pelo template; revisor
    `the-band`; issues com resumo
  - **Feita quando**: `GATES_EXIT=0` lido no log; `reviewRequests` não vazio
  - **Teste**: as duas leituras coladas no PR

## Dependências

- T001 → T002 → (T003, T004, T005, T006).
- T004 → T007, T009, T010.
- T006 → T007 → T008.
- T008, T010 → T011 → T012.
- T011 → T013 → T014 → T015.
- T008 → T016 → T017.

**Paralelo**:
- T003, T004, T005 e T006, depois de T002;
- T009 e T010, depois de T004.

## Estratégia

**MVP**: T002–T004 e T006–T008, que fecham o G1 no código e provam isso. A US3 e a Fase 6 levam a
correção à produção. **A #1131 só fecha com a conferência dizendo "em vigor" em produção** (T015,
SC-004), e não com o merge.
