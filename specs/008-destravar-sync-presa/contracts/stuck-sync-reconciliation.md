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

**Uma execução é considerada presa quando não existe trabalho ativo com aquele `sync_id` nos args,
e ela foi aberta há mais de um minuto.**

**Trabalho ativo são cinco estados** — `Oban.Job.states/0` menos os três terminais:

| Ativo | Não ativo |
|---|---|
| `suspended`, `scheduled`, `available`, `executing`, `retryable` | `completed`, `discarded`, `cancelled` |

A lista é derivada da função, **nunca copiada**: uma versão nova do Oban que acrescente estado
entraria em silêncio numa lista literal. A primeira versão deste contrato listava quatro e omitia
`suspended` — trabalho pausado, que vai executar —, e a reconciliação teria encerrado coleta viva.

**Idade não decide encerrar.** Ela só **impede**: execução aberta há menos de um minuto não é
candidata, porque abrir o registro e criar o trabalho são operações separadas e no intervalo a
execução tem a assinatura exata de "presa" (FR-011). Uma coleta de 16 minutos é indistinguível de
uma coleta morta pela idade, e FR-005 proíbe encerrar coleta viva.

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

## `TheBand.Ingestion.start_sync/3` — ampliada

O resultado da criação do trabalho passa a ser **conferido**. Hoje ele é descartado, e é um caminho
de travamento que ninguém veria: registro aberto, criação falha, e a execução fica `running` sem
nada para executá-la.

| Devolve | Quando |
|---|---|
| `{:ok, sync}` | registro aberto **e** trabalho criado |
| `{:error, :enqueue_failed}` | o registro foi aberto e o trabalho não pôde ser criado — a execução é **encerrada na hora**, com o motivo, e não deixada para a reconciliação |

Encerrar na hora e não esperar a reconciliação tem razão: o motivo seria errado. "O processo que a
executava não existe mais" afirma que houve processo — e aqui ele **nunca existiu**.

---

## Configuração da fila

```text
Oban.Plugins.Cron   */5 * * * *  → ReconcileStuckSyncs
```

**Sem `Oban.Plugins.Lifeline`, e a razão está medida em R1.** O resgate dele é
`state == "executing" and attempted_at < cut`, sem verificação de processo vivo. A constante de
tempo envelhece com o crescimento da coleta, e no dia em que a coleta passar dela existem duas
execuções da mesma coleta — sem aviso, porque cada uma funciona.

**Órfão é encerrado, não retomado.** A coleta nova recoleta desde o começo, e isso não duplica linha
porque a gravação é por chave natural. Custa consulta repetida à origem; não custa número errado.

---

## O que este contrato deliberadamente **não** declara

| Ausente | Por quê |
|---|---|
| `stuck?/1` público | convidaria a segunda implementação da decisão — FR-007 |
| `cancel_sync/3` | cancelar coleta **viva** é outra pergunta, e está fora do escopo |
| `retry_sync/2` | quem decide tentar de novo é quem administra; automatizar esconderia falha permanente |
| estado `stuck` | `interrupted` serve; a distinção vive no motivo e no autor |
| handler de telemetria | não veria o trabalho que morreu com o nó, porque nenhum evento é emitido — R4 |
| resgate automático de trabalho órfão | decide por tempo, sem saber se o processo vive — R1 |
