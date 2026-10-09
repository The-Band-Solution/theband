# A saúde da fila — um verificador fora do Oban (issue #801)

**O defeito, medido em 2026-09-04 no desenvolvimento:** o servidor ficou de pé por quatro dias
respondendo `200` em toda rota, com o banco no ar, e **nenhum job foi processado**. A fila
acumulou 524. Nada acusou:
- a aplicação respondia normalmente;
- o healthcheck só olhava o Postgres;
- `TheBand.Jobs.ReconcileStuckSyncs`, o guarda desta família de defeito, **é um job do Oban**, e
  parou junto.

Esta página é o contrato do verificador que fica **fora** do Oban.

## A regra: `TheBand.Saude.fila/2`

| estado | quando |
|---|---|
| `:ok` | o último job completado tem menos de **15 minutos** |
| `{:parada, minutos}` | o último job completado tem 15 minutos ou mais |
| `{:parada, minutos}` | nunca houve job completado, **e** existe job esperando (`available`) há 15 minutos ou mais. É o banco onde o Oban nunca rodou |
| `:ok` | nunca houve job completado e não há nada esperando: instalação nova, antes do primeiro ciclo do `Cron` |

**Por que 15 minutos:** o `Oban.Plugins.Cron` agenda `ReconcileStuckSyncs` e `ScheduleDueSyncs`
**a cada 5 minutos** (`config/config.exs`). Numa fila saudável, algum job completa pelo menos a
cada 5 minutos. Três ciclos sem nenhum é fila parada, e não lentidão. O limiar é
configurável em `config :the_band, :fila_parada_apos_minutos`.

**O que ela lê:** `max(completed_at)` e o `scheduled_at` mais antigo de `available` em
`oban_jobs`. São duas consultas, e **nenhuma das duas passa pelo Oban**.

## O `Cron` numa fila só dele — achado S1, 2026-10-01

A regra conta com o `Cron` completando algo a cada 5 minutos. Até 2026-10-01, os jobs do `Cron`
(`ReconcileStuckSyncs`, `ScheduleDueSyncs`, `ApagaSessoesAntigas`) estavam na fila `ingestion`,
a mesma da coleta, que tem 5 vagas, e cada coleta ocupa uma vaga por horas. **Cinco coletas
simultâneas faziam a regra dizer "parada" com a fila trabalhando**, o healthcheck marcava
`unhealthy`, e reiniciar o contêiner mataria as coletas. A avaliação de segurança achou o caminho
lendo o código, e não houve medição.

Agora eles estão na fila **`manutencao`**, com 2 vagas, e `test/the_band/jobs/fila_do_cron_test.exs`
reprova se algum worker do `crontab` voltar para a fila da coleta.

**O falso negativo que continua (S8):** o veredito é da instalação inteira. Uma fila que segue
completando mascara outra parada. A `ingestion` saturada ou parada com o `Cron` andando **não** é
acusada por esta regra.

## `TheBand.Saude.leitura/2` — o que a tela `/syncs` precisa (issue #801, parte 3)

Decisão Q3 de 2026-10-01: **uma função nova, ao lado de `fila/2`**, que fica intacta, e com ela
`/health` e o healthcheck. A tela precisa de mais do que o veredito: distinguir os dois casos de
parada e mostrar os horários.

```elixir
%{
  estado: :andando | :parada | :sem_historico,
  causa: :ultimo_completado | :esperando_mais_antigo | nil,
  ultimo_completado_em: DateTime.t() | nil,
  esperando_desde: DateTime.t() | nil,
  parada_ha_minutos: non_neg_integer() | nil,
  conferido_em: DateTime.t()
}
```

| `estado` | quando | `causa` |
|---|---|---|
| `:andando` | o último completado tem menos de 15 min | `nil` |
| `:parada` | o último completado tem 15 min ou mais | `:ultimo_completado` |
| `:parada` | nunca completou, e o job esperando mais antigo tem 15 min ou mais | `:esperando_mais_antigo` |
| `:sem_historico` | nunca completou, e nada espera há 15 min | `nil` |

O veredito é **o mesmo** de `fila/2`, pela mesma regra e pelo mesmo limiar: `fila/2` passa a ser
calculada a partir de `leitura/2`, e as duas não podem discordar.

**Uma exceção ao princípio V, escrita como exceção** (achado S3 da avaliação de 2026-10-01).
`oban_jobs` é da instalação, e não de um tenant: os jobs do `Cron` não têm tenant, e filtrar por
tenant faria toda organização sem coleta recente ver "parada" para sempre. Por isso `leitura/2`
**não** filtra por tenant, e por isso ela devolve só um **agregado escalar**:

- **devolve:** o veredito, a causa, dois horários (o último completado e o esperando mais antigo),
  os minutos de parada e a hora da conferência;
- **nunca devolve:** linhas, `args`, `errors`, `meta`, nome de worker, nome de fila, contagem de
  jobs, nem nada que identifique um tenant.

**Quem vê:** a tela `/syncs`, que exige `require_operacao` (admin ou escopo de organização). O
veredito em si já é público em `/health`.

**O que a tela mostra com a fila andando** (decisão P-1 de 2026-10-01, achado S2): só o veredito e
a hora da conferência, **sem** o horário do último job. Esse horário pode ser de outra organização,
e entre dois ciclos do `Cron` revelaria o minuto em que ela terminou uma coleta. Com a fila
parada, o horário aparece, porque ele é o fato que o aviso afirma, e nesse caso ele é antigo.

**Onde a reconferência é armada** (achado S4): o timer de 60 segundos é armado **só no `mount`**
conectado, e rearmado **só no próprio `handle_info`**, que lê `leitura/2` e **não** chama o
`load/1` da tela. O `load/1` roda a reconciliação, que é uma escrita global, e é chamado em dez
pontos; armar o timer nele multiplicaria os timers a cada evento.

## As duas portas

### `GET /health`, sem autenticação

| resposta | corpo (texto puro) |
|---|---|
| `200` | `ok` |
| `503` | `queue stalled` |

**Não diz mais do que isso.** Sem minutos, sem contagem, sem nome de fila nem de worker: a rota
não tem sessão, e cada campo a mais seria superfície nova por conveniência. Quem opera vê o
detalhe no `/syncs` ou no log. É a mesma decisão do `/version`.

### O healthcheck do contêiner

```dockerfile
HEALTHCHECK … CMD /app/bin/the_band rpc 'IO.puts(TheBand.Release.saude_da_fila())' | grep -qx ok
```

O `rpc` executa **dentro do nó que está servindo**, pelo cookie da própria release, e não abre
porta nova. A escolha foi da pessoa mantenedora em 2026-09-30, contra instalar `curl` na imagem.
Com a fila parada, o contêiner fica `unhealthy`, e o orquestrador pode reiniciá-lo.

**`saude_da_fila/0` nunca derruba o nó.** Ela devolve `"ok"` ou `"parada"`, e quem decide é o
`grep` do lado de fora. Uma função chamada por `rpc` que parasse o nó transformaria o
verificador num defeito.

## O que este contrato NÃO cobre

- **A tela `/syncs` dizendo "a fila não avança há X".** É mudança de tela, e passa pelo protótipo
  antes do código. Fica numa entrega seguinte da #801.
- **A causa raiz** do Oban que parou em 2026-09-04. Continua desconhecida: o verificador detecta,
  mas não explica.
- **Se o Dokploy reinicia um contêiner `unhealthy`.** Em modo swarm, sim. Isso não foi medido na
  produção deste projeto.
