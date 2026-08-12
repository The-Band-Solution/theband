# Contrato — reconciliar a execução presa

Feature 008. Escrito **antes** da primeira função pública, como o princípio VII exige.

**Duas funções e um trabalho periódico.** Nenhum módulo novo no domínio.

---

## `TheBand.Ingestion`

### `reconcile_stuck_syncs() :: {:ok, [Sync.t()]}`

Encerra **toda** execução `running` cujo trabalho não existe mais, em qualquer tenant. Devolve as
que encerrou — lista vazia é o caso normal.

Atravessa tenants **de propósito**: é manutenção da plataforma, e nenhum dado de um tenant chega a
outro. Está declarado no Constitution Check do plano para não parecer descuido.

**Uma execução é considerada presa quando não existe trabalho em `available`, `scheduled`,
`executing` ou `retryable` com aquele `sync_id` nos args.** Idade **não** entra na decisão: uma
coleta de 16 minutos é indistinguível de uma coleta morta pela idade, e FR-005 proíbe encerrar
coleta viva.

O motivo depende da causa:

| O que se acha na fila | Motivo gravado |
|---|---|
| trabalho `discarded` | a falha que ele registrou, com a contagem de tentativas |
| **nenhum** trabalho | `o processo que a executava não existe mais` |

**Nunca inventa falha que ninguém observou** — FR-003. Ausência de trabalho é dita como ausência.

**Idempotente**: age só sobre `running`. Chamar duas vezes não altera motivo nem autor do primeiro
encerramento — FR-014.

**Silenciosa quando não acha nada.** Nenhum log de "reconciliei 0": ruído periódico treina quem lê
a ignorar o log.

### `interrupt_sync(tenant, sync_id, user) :: {:ok, Sync.t()} | {:error, :not_found | :job_alive | :not_running}`

Encerra por **decisão humana**, e grava o autor.

| Devolve | Quando |
|---|---|
| `{:ok, sync}` | encerrada, com `interrupted_by_user_id` preenchido |
| `{:error, :not_found}` | não existe, **ou é de outro tenant** — a mensagem não confirma existência (FR-013) |
| `{:error, :job_alive}` | há trabalho ativo: encerrar derrubaria coleta viva, e é pior que o problema |
| `{:error, :not_running}` | já encerrada; o motivo e o autor originais **permanecem** |

`:job_alive` é a defesa que o `:not_found` não dá: sem ela, a ação humana seria o caminho para
quebrar FR-005 por engano.

### `interruptible?(sync) :: boolean()`

Se a tela deve **oferecer** a ação. Verdadeiro só quando a execução está `running` e a plataforma
não consegue provar que o trabalho está vivo — FR-008.

É consulta de exibição, e **não** a decisão: quem decide é `interrupt_sync/3`, que reconfere. Uma
tela que confia no próprio botão decide com dado de segundos atrás.

---

## `TheBand.Jobs.ReconcileStuckSyncs`

Trabalho periódico, fila **`ingestion`** — a fila existe, e declarar worker em fila não configurada
deixa o job `available` para sempre.

Chama `reconcile_stuck_syncs/0`. **Não** reimplementa a decisão: um caminho, vários gatilhos —
FR-007.

Agendado a cada **5 minutos** por `Oban.Plugins.Cron`. É o atraso máximo aceitável entre a coleta
morrer e a ferramenta voltar a aceitar coleta.

---

## Configuração da fila

```text
Oban.Plugins.Lifeline  rescue_after: 60 minutos
Oban.Plugins.Cron      */5 * * * *  → ReconcileStuckSyncs
```

**O `rescue_after` fica escrito mesmo sendo o padrão.** Um padrão que ninguém escreveu é um padrão
que ninguém revisa — e este precisa subir quando a coleta mais longa crescer. Hoje ele é 3,7× a
execução legítima mais longa medida: 16 min 25 s.

**Resgatar é voltar a executar**, e é o que se quer: o trabalho retoma pelos cursores já gravados,
sem recoletar — FR-010. Só é seguro porque a coleta é idempotente por desenho.

---

## O que este contrato deliberadamente **não** declara

| Ausente | Por quê |
|---|---|
| `stuck?/1` público | convidaria a segunda implementação da decisão — FR-007 |
| `cancel_sync/3` | cancelar coleta **viva** é outra pergunta, e está fora do escopo |
| `retry_sync/2` | quem decide tentar de novo é quem administra; automatizar esconderia falha permanente |
| estado `stuck` | `interrupted` serve; a distinção vive no motivo e no autor |
| handler de telemetria | não veria o descarte feito pelo Lifeline — R4 |
