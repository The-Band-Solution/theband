# Tarefas — Feature 008: destravar a sincronização presa

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/stuck-sync-reconciliation.md](contracts/stuck-sync-reconciliation.md) · **Quickstart**:
[quickstart.md](quickstart.md)

**Nove tarefas, três fases.** O plano tem quatro padrões e seis recusas; o conjunto de tarefas
segue o mesmo tamanho.

Ordem: F1 → F2 → F3, e é dependência.

**MVP**: F1 e F2. Com as duas, o bloqueio sai sozinho — que é o problema inteiro da issue #175. F3
acrescenta o caso que a plataforma não consegue provar, e o **quem encerrou** na tela.

**F1 não é entregável sozinha, e isto está declarado**: a decisão sem gatilho não destrava nada. É
a L21 — função pública testada e sem consumidor não é funcionalidade entregue —, e é por isso que
F2 está no mesmo sprint.

---

## Fase F1 — A decisão, e o motivo por causa

Vem primeiro porque **é o que os três gatilhos chamam**. Implementar gatilho antes da decisão
produziria a decisão escrita três vezes, que é o que FR-007 proíbe — e o projeto já pagou por dois
caminhos para a mesma decisão em `classification/2`, na prévia contra o recálculo, e na coleta
contra o recálculo.

- [ ] T001 Registrar quem encerrou a execução
  - **Pronta quando**: `data-model.md` descreve a coluna; nada mais
  - **Descrição**: migração acrescentando `interrupted_by_user_id` (`binary_id`, FK para `users`,
    **anulável**) a `syncs`, mais o campo no schema e no `cast` de
    `lib/the_band/ingestion/sync.ex`. **Sem check constraint exigindo autor** — e a diferença em
    relação a `observed_repositories_exclusion_has_author` é o ponto: exclusão só acontece por
    decisão de alguém, encerramento também acontece pela plataforma. Exigir autor forçaria inventar
    um usuário-sistema, ou atribuir a decisão a quem não a tomou. Nulo **afirma** "foi a
    plataforma" (FR-009, R6)
  - **Feita quando**: a migração sobe e desce sem erro; um sync gravado sem autor persiste com
    nulo; um sync gravado com autor persiste o id
  - **Teste**: round trip — `mix ecto.migrate`, `mix ecto.rollback --step 1`, `mix ecto.migrate`.
    E a asserção que importa: **inserir `interrupted` sem autor não levanta** — se levantar, a
    constraint entrou onde não devia

- [ ] T002 Achar o trabalho de uma execução
  - **Pronta quando**: o contrato declara a ligação por args; T001 concluída
  - **Descrição**: função privada em `lib/the_band/ingestion.ex` que consulta `Oban.Job` por
    `args->>'sync_id'`. **Trabalho ativo é `available`, `scheduled`, `executing` ou `retryable`** —
    quatro estados, e omitir `retryable` faria a plataforma encerrar execução que vai tentar de
    novo. `discarded` **não** é ativo, e é o caso que carrega a falha para o motivo.
    A ligação é pelos args porque o sync **não guarda** id de job, e pôr um lá seria identificador
    de fila dentro do domínio — R3, com critério de reversão escrito
  - **Feita quando**: para um sync com job `executing`, devolve o job; para um sync sem job nenhum,
    devolve ausência; job de **outro** sync não é devolvido
  - **Teste**: `test/the_band/ingestion/reconcile_stuck_syncs_test.exs` — os quatro estados ativos
    num caso cada, inserindo o job **de verdade** em `oban_jobs`. A asserção que importa é
    `retryable` contar como ativo

- [ ] T003 Decidir se a execução está presa
  - **Pronta quando**: T002 concluída
  - **Descrição**: `Ingestion.reconcile_stuck_syncs/0`, pública, na fronteira do módulo. Encerra
    toda execução `running` **sem trabalho ativo**, com `finish/3` e `:interrupted`.
    **A idade não entra na decisão.** Uma coleta de 16 min 25 s — a mais longa medida, com 3 641
    registros — é indistinguível de uma coleta morta pela idade, e encerrar coleta viva é o defeito
    **oposto**: pior que o problema original, porque derruba trabalho em andamento (FR-005).
    Atravessa tenants de propósito: é manutenção da plataforma, e está declarado no Constitution
    Check
  - **Feita quando**: execução `running` sem trabalho fica `interrupted`; execução `running` **com**
    trabalho `executing` continua `running`; execução já encerrada não é tocada
  - **Teste**: o mesmo arquivo de T002 — e o teste que mais importa é o do **defeito oposto**: um
    job `executing` inserido de verdade na tabela da fila, e a execução **continua** `running`.
    Simular a resposta da consulta faria o teste passar sem medir nada

- [ ] T004 Dizer por que a execução morreu
  - **Pronta quando**: T003 concluída
  - **Descrição**: o motivo gravado em `error_reason` depende da causa: job `discarded` carrega a
    falha que o job registrou, com a contagem de tentativas; **ausência** de job diz `o processo
    que a executava não existe mais`.
    **Nunca inventar falha que ninguém observou** — FR-003. Um motivo genérico apagaria a
    distinção entre falha transitória e permanente, e é a L29: um `:nxdomain` de um instante tirou
    38 repositórios e 899 issues de circulação porque a falha do momento foi tratada como
    permanente
  - **Feita quando**: dois syncs presos por causas diferentes têm motivos **diferentes**; o motivo
    da ausência não contém a palavra "erro"; o motivo do descarte contém o que o job registrou
  - **Teste**: o mesmo arquivo — um caso com job `discarded` com erro conhecido, um caso sem job
    nenhum, e a asserção de que os dois textos **diferem**

- [ ] T005 Não mudar o encerramento já feito
  - **Pronta quando**: T004 concluída
  - **Descrição**: a decisão age **só** sobre `status = "running"`. Dois gatilhos podem disparar no
    mesmo instante — o trabalho periódico e a tela —, e o segundo não pode sobrescrever o motivo
    nem o autor do primeiro (FR-014). `interrupt_sync/3` devolve `{:error, :not_running}` para
    execução já encerrada, em vez de encerrar de novo
  - **Feita quando**: chamar a reconciliação duas vezes seguidas deixa motivo e autor do primeiro
    encerramento intactos; a segunda chamada devolve lista vazia
  - **Teste**: o mesmo arquivo — encerrar por pessoa, reconciliar em seguida, e conferir que
    `interrupted_by_user_id` **continua** preenchido. É a asserção que pega o gatilho automático
    apagando a decisão humana

---

## Fase F2 — Os gatilhos automáticos

**Aqui o bloqueio sai sozinho**, e é o valor central: SC-001 e SC-002 passam a valer.

- [ ] T006 Resgatar trabalho de nó morto
  - **Pronta quando**: T003 concluída — o resgate precisa da reconciliação para o caso que ele
    marca como descartado
  - **Descrição**: acrescentar `{Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)}` aos
    plugins em `config/config.exs`. **O valor fica escrito mesmo sendo o padrão**: padrão que
    ninguém escreveu é padrão que ninguém revisa, e este precisa subir quando a coleta mais longa
    crescer.
    Sessenta minutos são **3,7×** a execução legítima mais longa medida — 16 min 25 s. Um
    `rescue_after` curto resgataria coleta viva, e ela rodaria **duas vezes**: é a L02, onde a
    coleta duplicada trouxe 32 registros em vez de 16 e o número pareceu plausível.
    O comentário na configuração registra de onde saiu o número e o gatilho de revisão de R2 — se
    alguma execução `completed` passar de 30 minutos, o valor sobe
  - **Feita quando**: a aplicação sobe com o plugin ativo; o valor de `rescue_after` está legível
    na configuração, com a justificativa ao lado
  - **Teste**: teste de configuração que lê os plugins e exige `Lifeline` com `rescue_after` de
    3 600 000 ms — **falha se alguém baixar o valor sem discutir**, que é o ponto

- [ ] T007 Reconciliar a cada cinco minutos
  - **Pronta quando**: T003 concluída; T006 concluída
  - **Descrição**: `lib/the_band/jobs/reconcile_stuck_syncs.ex`, worker Oban na fila
    **`ingestion`** — a fila existe; declarar worker em fila não configurada deixa o job
    `available` para sempre, e aconteceu nesta sessão com uma fila `:sync` inexistente. Chamar
    `Ingestion.reconcile_stuck_syncs/0` e **nada mais**: reimplementar a decisão aqui é o que
    FR-007 proíbe.
    Agendar por `{Oban.Plugins.Cron, crontab: [{"*/5 * * * *", TheBand.Jobs.ReconcileStuckSyncs}]}`
    em `config/config.exs`.
    **Silencioso quando não acha nada** — nenhum log de "reconciliei 0": ruído periódico treina
    quem lê a ignorar o log, e aí o log que importa passa batido
  - **Feita quando**: o worker roda e encerra execução presa sem ninguém abrir a tela; com nada
    preso, não escreve log; a fila do worker é `ingestion`
  - **Teste**: `test/the_band/jobs/reconcile_stuck_syncs_test.exs` — `perform/1` sobre um sync
    preso encerra; e um teste de configuração que exige o worker **na fila `ingestion`** e agendado
    no crontab. Presumir a configuração é como o job da fila `:sync` ficou parado para sempre

---

## Fase F3 — A tela

- [ ] T008 Encerrar a execução presa pela tela
  - **Pronta quando**: T005 concluída; o contrato declara `interrupt_sync/3` e `interruptible?/1`
  - **Descrição**: `Ingestion.interrupt_sync/3` grava o autor e devolve
    `{:error, :job_alive}` quando há trabalho ativo, `{:error, :not_found}` para execução de outro
    tenant — **nunca "sem permissão"**, porque a mensagem não confirma existência (FR-013).
    Em `lib/the_band_web/live/sync_live/index.ex`: chamar a reconciliação **ao carregar**, e
    oferecer a ação de encerrar apenas quando `interruptible?/1` for verdadeiro (FR-008).
    `interruptible?/1` é consulta de **exibição**; a decisão **reconfere** — tela que confia no
    próprio botão decide com dado de segundos atrás, e nesse intervalo a coleta pode ter voltado a
    executar
  - **Feita quando**: a ação aparece só na execução que a plataforma não prova viva; encerrar grava
    o autor; a requisição direta sobre execução com trabalho ativo devolve `:job_alive`; execução
    de outro tenant devolve não encontrado
  - **Teste**: `test/the_band_web/live/stuck_sync_test.exs` — o caso que importa é a **requisição
    direta** sobre execução viva devolvendo `:job_alive` mesmo sem botão na tela. E o de outro
    tenant, exigindo não encontrado e **nenhuma** menção a permissão

- [ ] T009 Dizer quem encerrou a execução
  - **Pronta quando**: T008 concluída
  - **Descrição**: na lista de execuções, exibir quem encerrou: o nome da pessoa, ou **`the
    platform`** por extenso quando o autor é nulo. **Nunca `—` para os dois casos** — o nulo
    afirma "não foi pessoa", e um travessão apagaria a afirmação, o que o design system proíbe
    (ausência é nomeada). O motivo aparece em texto, e o estado não é carregado só por cor
    (FR-012)
  - **Feita quando**: execução encerrada por pessoa mostra o nome; encerrada pela plataforma mostra
    `the platform`; com a cor removida, o estado continua legível
  - **Teste**: o mesmo arquivo de T008 — dois syncs encerrados, um por pessoa e um pela plataforma,
    exigindo textos **diferentes**; e `refute html =~ "—"` na célula de quem encerrou

---

## Dependências

```text
T001 → T002 → T003 → T004 → T005 → T008 → T009
                 └──→ T006 → T007
```

T006 e T007 dependem de T003 porque o Lifeline **cria** o caso `discarded` que a reconciliação
precisa cobrir — descoberto lendo a fonte do plugin, em R1.

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T006 e T004 | configuração e texto de motivo não se tocam |
| T009 e T007 | tela e worker, arquivos diferentes |

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 (encerrar e destravar) | T003 |
| FR-002, FR-003 (motivo por causa, sem inventar falha) | T004 |
| FR-004 (nada é apagado) | T003 — `finish/3` só atualiza estado, motivo e autor |
| FR-005 (não encerrar coleta viva) | T002, T003 — e é o teste do defeito oposto |
| FR-006 (sem depender da tela) | T007 |
| FR-007 (um caminho, vários gatilhos) | T003, T007, T008 |
| FR-008 (ação só onde é segura) | T008 |
| FR-009 (autor, ausente quando é a plataforma) | T001, T008, T009 |
| FR-010, FR-011 (retomar, e o tempo declarado) | T006 |
| FR-012 (estado e motivo em texto) | T009 |
| FR-013 (isolamento entre tenants) | T008 |
| FR-014 (encerrar duas vezes não muda nada) | T005 |
| FR-015 (escopo é a tela de sincronizações) | T008 — e a ausência de tarefa para outra tela |

**15 de 15 requisitos com tarefa.** SC-001 a SC-011 verificados por V1 a V8 do
[quickstart](quickstart.md).

## Estratégia de entrega

**F1+F2 é o MVP**, e resolve a issue #175: o bloqueio sai sozinho, sem SQL e sem ninguém abrir a
tela.

**F1 sozinha não entrega nada visível**, e está declarado: decisão sem gatilho não destrava. A L21
proíbe entregar função pública sem consumidor, e é por isso que F2 não é opcional.

**F3 cobre o que a plataforma não consegue provar** — o trabalho consta como executando e quem
administra sabe que o processo morreu. É P2 na spec, e é a parte que precisa de mais cuidado:
encerrar coleta viva derruba trabalho em andamento.

## Fora do escopo, e ficou de fora

| Item | Por quê |
|---|---|
| cancelar coleta **em andamento** | é outra pergunta, e ninguém pediu |
| painel de trabalhos da fila | a tela mostra coleta, não infraestrutura |
| repetir a coleta automaticamente | quem decide tentar de novo é quem administra |
| handler de telemetria | não veria o descarte feito pelo Lifeline, que muda linha em SQL — R4 |
| estado `stuck` | `interrupted` serve; a distinção vive no motivo e no autor |
