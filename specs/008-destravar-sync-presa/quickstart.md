# Quickstart — Feature 008: destravar a sincronização presa

Oito verificações. Os números vêm do banco de desenvolvimento, medidos em 2026-08-12: **32
execuções — 28 concluídas, 2 com falha, 2 interrompidas à mão —, 5 trabalhos descartados e 1
executando desde 2026-08-09** num nó que não existe mais.

A execução legítima mais longa levou **16 min 25 s** e coletou 3 641 registros. É desse número que
sai o `rescue_after`.

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix ecto.migrate
mix phx.server            # localhost:4000/syncs
```

---

## V1 — O que está preso hoje, antes de qualquer coisa

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select s.id, s.status, s.started_at,
       (select count(*) from oban_jobs j
         where j.args->>'sync_id' = s.id::text
           and j.state in ('available','scheduled','executing','retryable')) as trabalhos_ativos
  from syncs s where s.status = 'running';"
```

**Esperado, antes da feature**: pode haver linha com `trabalhos_ativos = 0` — é exatamente a
execução presa. Depois da feature, essa linha **não sobrevive** a 5 minutos.

**O que NÃO pode aparecer depois**: linha `running` com `trabalhos_ativos = 0` por mais de 5
minutos.

---

## V2 — A ferramenta volta a aceitar coleta

Com uma execução presa, tentar sincronizar pela tela.

**Esperado**: a coleta **começa**. Antes da feature, a resposta era "já existe uma sincronização em
andamento" — sobre uma execução morta há três dias.

**É o SC-001**, e é a feature inteira: sem isto, a única saída era SQL.

---

## V3 — O bloqueio sai sem ninguém abrir a tela

```bash
mix test test/the_band/ingestion/reconcile_stuck_syncs_test.exs
```

E no servidor, deixando uma execução presa e **não** abrindo `/syncs`:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select status, error_reason, interrupted_by_user_id from syncs where id = '<id-preso>';"
```

**Esperado**, em até 5 minutos: `interrupted`, com motivo, e `interrupted_by_user_id` **nulo** —
porque quem encerrou foi a plataforma.

**É o SC-002.** Se a verificação só rodasse ao carregar a tela, a ferramenta ficaria bloqueada até
alguém olhar.

---

## V4 — Os motivos são diferentes por causa

```bash
mix test test/the_band/ingestion/reconcile_stuck_syncs_test.exs -o "motivo"
```

**Esperado**:

| causa | motivo |
|---|---|
| trabalho descartado | a falha que o trabalho registrou, com as tentativas |
| nenhum trabalho | `o processo que a executava não existe mais` |

**O que NÃO pode**: os dois com o mesmo texto, e nenhum deles a palavra "erro" sozinha. Um motivo
genérico apagaria a distinção entre falha transitória e permanente — a L29.

---

## V5 — Coleta viva NÃO é encerrada

```bash
mix test test/the_band/ingestion/reconcile_stuck_syncs_test.exs -o "viva"
```

**Esperado**: com um trabalho em `executing`, a execução continua `running`. O teste cria o trabalho
**de verdade** na tabela da fila, e não simula a resposta.

**É o defeito oposto, e é pior que o problema original.** Encerrar tudo que está `running`
destravaria a ferramenta e derrubaria a coleta de 3 641 registros no meio — SC-005.

---

## V6 — Quem encerrou aparece por extenso

Abrir `/syncs`.

**Esperado**:

| encerrada por | a tela diz |
|---|---|
| pessoa | o nome de quem decidiu |
| plataforma | **`the platform`** |

**O que NÃO pode**: `—` para os dois casos. O nulo afirma "não foi pessoa", e a tela precisa dizer
isso — SC-007.

---

## V7 — A ação só aparece onde é segura

Abrir `/syncs` com uma execução viva e uma presa.

**Esperado**: a ação de encerrar aparece **só** na presa. Na viva, não existe botão.

E, se alguém tentar de todo modo — pela requisição direta —, a resposta é `:job_alive`, não o
encerramento. **A tela não é a defesa; a decisão reconfere** — SC-006.

---

## V8 — O trabalho órfão retoma, e não recoleta

```bash
mix test test/the_band/ingestion/reconcile_stuck_syncs_test.exs -o "retoma"
```

**Esperado**: trabalho resgatado continua pelos cursores gravados em `sync_checkpoints`, e o número
de registros **não dobra**.

**Falha típica**: recomeçar do zero, e os contadores da execução somarem duas vezes. É a L02 — a
coleta duplicada trouxe 32 registros em vez de 16, e o número pareceu plausível.

---

## O `rescue_after`, conferido contra o dado

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select max(finished_at - started_at) from syncs where status = 'completed';"
```

**Esperado hoje**: `00:16:25`. O `rescue_after` é 60 minutos — 3,7× isso.

**O gatilho de revisão está em R2**: quando alguma execução `completed` passar de **30 minutos**, o
valor precisa subir. Metade da margem gasta é o aviso, e resgatar coleta viva duplica registro.

---

## Os dez gates

```bash
mix gates
```

**Esperado**: `10 gates verdes`, e **código de saída zero**. Conferir pelo texto não basta — o
validador Python avisa que pulou e sai diferente de zero, e foi a L23.
