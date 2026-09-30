# Contrato — a retenção das sessões (T020)

Decisão P3 de 2026-09-28, em [seguranca-us2.md](../seguranca-us2.md). FR-015. O módulo é o de
[sessoes.md](sessoes.md).

## `Sessions.apagar_as_que_deixaram_de_valer(agora \\ DateTime.utc_now()) :: {:ok, non_neg_integer()}`

Apaga de `user_sessions` a linha que deixou de valer **há mais de 90 dias**, por uma de duas
condições:

| condição | por quê |
|---|---|
| `ended_at < agora − 90 dias` | a sessão encerrada: saída, senha definida, desativação, giro |
| `inserted_at < agora − 97 dias` (7 de validade + 90) | a sessão que **venceu sem ninguém a encerrar**. Ela não escreve `ended_at`, e sem esta condição seria o registro permanente da FR-015 |

Devolve quantas apagou. É o **único** caminho que apaga. O `agora` é parâmetro para o teste
medir as bordas sem esperar dias.

## `TheBand.Jobs.ApagaSessoesAntigas`

Worker do Oban, na fila `ingestion`, agendado pelo `Oban.Plugins.Cron` todo dia às 04:00. Não
decide nada: chama a função acima. Silencioso quando não acha nada.

## O que se perde, e por que é aceito

A linha, com o carimbo de abertura e de encerramento. O evento de acesso continua no log
(`AccessEvents`). Guardada para sempre, a linha seria trilha de atividade de pessoa em todo
backup, e é isso que a P3 decidiu não guardar.

## O que não cobre

- **Cópias já tiradas.** Um backup de antes da poda continua com a linha até ele mesmo expirar.
- **Os outros registros de pessoa.** A decisão P3 é sobre `user_sessions`, e só sobre ela.
