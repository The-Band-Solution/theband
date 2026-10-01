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
