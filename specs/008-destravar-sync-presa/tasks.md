# Tarefas — Feature 008: destravar a sincronização presa

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/stuck-sync-reconciliation.md](contracts/stuck-sync-reconciliation.md) · **Quickstart**:
[quickstart.md](quickstart.md)

**Nove tarefas, três fases.** O plano tem três padrões e oito recusas; o conjunto de tarefas segue o
mesmo tamanho.

**A análise mudou uma tarefa de assunto.** T006 configurava o resgate automático de trabalho órfão;
depois de a leitura da fonte mostrar que ele decide por tempo **sem saber se o processo vive**, o
resgate saiu, e T006 passou a cobrir o terceiro caminho de travamento — o trabalho que não nasce,
que a mesma análise achou.

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
    `args->>'sync_id'`. **Trabalho ativo são cinco estados**, e a lista é **derivada de
    `Oban.Job.states/0` menos os três terminais** — `completed`, `discarded`, `cancelled` —, nunca
    copiada:

    ```
    ativo:      suspended  scheduled  available  executing  retryable
    não ativo:  completed  discarded  cancelled
    ```

    A análise achou a lista errada: a primeira versão tinha **quatro** e omitia `suspended`, que é
    trabalho pausado — vai executar. A reconciliação teria encerrado coleta viva por causa de uma
    lista escrita de memória. E `discarded` **não** é ativo: é o caso que carrega a falha para o
    motivo.
    A ligação é pelos args porque o sync **não guarda** id de job, e pôr um lá seria identificador
    de fila dentro do domínio — R3, com critério de reversão escrito
  - **Feita quando**: para um sync com job `executing`, devolve o job; para um sync sem job nenhum,
    devolve ausência; job de **outro** sync não é devolvido
  - **Teste**: `test/the_band/ingestion/reconcile_stuck_syncs_test.exs` — os **cinco** estados
    ativos num caso cada, inserindo o job **de verdade** em `oban_jobs`. E a asserção que impede a
    lista de envelhecer: ela **compara com `Oban.Job.states/0`** e falha se o Oban acrescentar
    estado que ninguém classificou

- [ ] T003 Decidir se a execução está presa
  - **Pronta quando**: T002 concluída
  - **Descrição**: `Ingestion.reconcile_stuck_syncs/0`, pública, na fronteira do módulo. Encerra
    toda execução `running` **sem trabalho ativo**, com `finish/3` e `:interrupted`.
    **A idade não decide encerrar; ela só impede.** Execução aberta há **menos de um minuto** não é
    candidata: abrir o registro e criar o trabalho são operações separadas, e no intervalo a execução
    tem a assinatura exata de "presa" (FR-011, R2).

    Fora dessa carência, a idade **não** entra: uma coleta de 16 min 25 s — a mais longa medida, com
    3 641 registros — é indistinguível de uma coleta morta pela idade, e encerrar coleta viva é o
    defeito **oposto**: pior que o problema original, porque derruba trabalho em andamento (FR-005).
    Atravessa tenants de propósito: é manutenção da plataforma, e está declarado no Constitution
    Check
  - **Feita quando**: execução `running` sem trabalho fica `interrupted`; execução `running` **com**
    trabalho `executing` continua `running`; execução aberta há 10 segundos **continua** `running`;
    execução já encerrada não é tocada
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

## Fase F2 — O gatilho automático, e o trabalho que não nasce

**Aqui o bloqueio sai sozinho**, e é o valor central: SC-001 e SC-002 passam a valer.

- [ ] T006 Encerrar quando o trabalho não nasce
  - **Pronta quando**: T003 concluída; o contrato declara `{:error, :enqueue_failed}`
  - **Descrição**: em `lib/the_band/ingestion.ex`, `handle_open/3` passa a **conferir o resultado**
    da criação do trabalho. Hoje ele é descartado — `enqueue/3` chama `Oban.insert/1` e o retorno
    vai para o vazio —, e se a criação falhar o registro fica `running` sem nada para executá-lo.
    **É o terceiro caminho de travamento**, e foi a análise desta feature que o achou lendo a
    abertura da execução: não está nos 5 descartados nem no órfão, porque ninguém saberia se já
    aconteceu.
    Falhando, a execução é encerrada **na hora**, com motivo próprio, e **não** deixada para a
    reconciliação — o motivo dela seria errado: "o processo que a executava não existe mais" afirma
    que houve processo, e aqui ele nunca existiu (FR-011a)
  - **Feita quando**: com a criação do trabalho falhando, `start_sync/3` devolve
    `{:error, :enqueue_failed}` e a execução fica `interrupted` com o motivo; a ferramenta aceita
    coleta nova **sem** esperar os 5 minutos da reconciliação
  - **Teste**: `test/the_band/ingestion/enqueue_failure_test.exs` — forçar a falha na criação e
    exigir que **nenhuma** execução fique `running`. A asserção que importa é a ausência de
    `running`, não o valor devolvido

- [ ] T007 Reconciliar a cada cinco minutos
  - **Pronta quando**: T003 concluída
  - **Descrição**: `lib/the_band/jobs/reconcile_stuck_syncs.ex`, worker Oban na fila
    **`ingestion`** — a fila existe; declarar worker em fila não configurada deixa o job
    `available` para sempre, e aconteceu nesta sessão com uma fila `:sync` inexistente. Chamar
    `Ingestion.reconcile_stuck_syncs/0` e **nada mais**: reimplementar a decisão aqui é o que
    FR-007 proíbe.
    Agendar por `{Oban.Plugins.Cron, crontab: [{"*/5 * * * *", TheBand.Jobs.ReconcileStuckSyncs}]}`
    em `config/config.exs`.
    **Silencioso quando não acha nada** — nenhum log de "reconciliei 0": ruído periódico treina
    quem lê a ignorar o log, e aí o log que importa passa batido.
    **Nenhum `Oban.Plugins.Lifeline`**: R1 mostrou que o resgate dele decide por tempo sem saber se
    o processo vive, e a constante envelhece com o crescimento da coleta. Órfão é **encerrado**, e a
    coleta nova recoleta — sem duplicar linha, porque a gravação é por chave natural
  - **Feita quando**: o worker roda e encerra execução presa sem ninguém abrir a tela; com nada
    preso, não escreve log; a fila do worker é `ingestion`
  - **Teste**: `test/the_band/jobs/reconcile_stuck_syncs_test.exs` — `perform/1` sobre um sync
    preso encerra; um teste de configuração que exige o worker **na fila `ingestion`** e agendado no
    crontab; e a asserção que fixa a decisão de R1: **`Lifeline` não está nos plugins**. Presumir
    configuração é como o job da fila `:sync` ficou parado para sempre

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
    direta** sobre execução viva devolvendo `:job_alive` mesmo sem botão na tela: é o SC-008a, e sem
    ele a tela seria a única defesa. E o de outro tenant, exigindo não encontrado e **nenhuma**
    menção a permissão

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
                 ├──→ T006
                 └──→ T007
```

T006 e T007 dependem de T003 e **não** um do outro: um confere a criação do trabalho, o outro agenda
a reconciliação. Podem ir em paralelo.

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
| FR-010 (órfão não é resgatado) | T007 — e a **ausência** de tarefa configurando resgate |
| FR-011 (carência da execução recém-aberta) | T003 |
| FR-011a (trabalho que não nasce) | T006 |
| FR-012 (estado e motivo em texto) | T009 |
| FR-013 (isolamento entre tenants) | T008 |
| FR-014 (encerrar duas vezes não muda nada) | T005 |
| FR-015 (escopo é a tela de sincronizações) | T008 — e a ausência de tarefa para outra tela |

| FR-016 (a verificação alcança todos os tenants) | T003, T007 |

**17 de 17 requisitos com tarefa.** SC-001 a SC-011, mais SC-008a e SC-008b, verificados por V1 a V9
do [quickstart](quickstart.md).

**Duas coberturas são por ausência, e é de propósito**: FR-010 é atendido por **não** existir tarefa
configurando resgate automático, e FR-015 por **não** existir tarefa para outra tela. Requisito
atendido por ausência precisa estar escrito, ou alguém acrescenta o que ele proíbe.

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
| handler de telemetria | não veria o trabalho que morreu com o nó, porque nenhum evento é emitido — R4 |
| resgate automático de trabalho órfão | decide por tempo, sem saber se o processo vive; a constante envelhece com a coleta — R1 |
| fila própria para a reconciliação | ela compete por slot em `ingestion`, e com 5 coletas espera — atrasa, não impede. Fila nova é desenho por antecipação |
| estado `stuck` | `interrupted` serve; a distinção vive no motivo e no autor |
