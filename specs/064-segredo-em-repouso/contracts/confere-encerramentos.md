# Contrato — o registro encerrado carrega a data do encerramento (T007 e T008)

FR-015, SC-008, research R6.

## A regra que decide quem sai da tabela, medida na dependência

A poda do Oban 2.23.1 (`deps/oban/lib/oban/engines/basic.ex`, `prune_jobs/3`) apaga por idade,
e cada estado terminal é comparado **por uma coluna diferente**:

| estado | coluna comparada com o corte | pode ser nula? |
|---|---|---|
| `completed` | `scheduled_at` | não — `NOT NULL` na tabela |
| `cancelled` | `cancelled_at` | **sim** |
| `discarded` | `discarded_at` | **sim** |

`NULL < corte` nunca é verdadeiro. Um registro `cancelled` sem `cancelled_at`, ou `discarded` sem
`discarded_at`, **nunca** é podado. É isso que esta página conserta e depois vigia.

Medido no banco de desenvolvimento em 2026-09-28: 4 registros `cancelled` sem `cancelled_at`
(ids 529, 542, 697 e 708, de 2026-09-04, todos `SyncGitHubEO`), 0 `discarded` sem data.

## T007 — a migração `PreencheDatasDeEncerramento`

**`up`**: para cada par (estado, coluna) acima em que a coluna pode ser nula, preenche a coluna
onde ela está nula com

```
LEAST(GREATEST(attempted_at, cancelled_at, discarded_at, completed_at, scheduled_at, inserted_at), now())
```

— a data **mais tardia** que o registro tem, porque é a mais próxima do fim dele. O `LEAST(…, now())`
existe porque `scheduled_at` pode estar no futuro, num job cancelado antes de rodar, e uma data de
encerramento no futuro adiaria a poda pelo mesmo tanto.

Cada registro preenchido recebe em `meta` a chave `"064_preencheu"` com o nome da coluna. A
chave é o que torna o `down` exato.

**`down`**: volta a anular **só** a coluna dos registros que têm a chave, e tira a chave. Registro
que já tinha data antes da migração não é tocado.

**Idempotente**: a segunda execução do `up` não acha coluna nula, e não muda nada.

**O que o `down` não devolve**: o registro que a poda **já apagou** depois do `up`. É o efeito
pretendido — um dos quatro carregava o segredo —, e é irreversível por natureza.

## T008 — `mix the_band.confere_encerramentos`

```
mix the_band.confere_encerramentos
```

| código | significa |
|---|---|
| `0` | nenhum registro terminal sem a coluna que a poda compara |
| `1` | pelo menos um |

A falha **nomeia** cada registro: `id`, `worker`, `estado`, a coluna nula e a frase de por que
ele escapa da poda. No máximo 20 linhas, e o total.

**O que ela NÃO imprime, e por quê**: `args`, `errors` e `meta`. São as colunas onde o segredo
foi achado em 2026-09-12 — o verificador de uma feature de segredo não pode ser mais uma cópia
dele.

**Em `mix gates`**, depois de `testes`. Ela confere o banco do ambiente em que roda:

- **localmente**, o de desenvolvimento, que é onde os quatro existiam;
- **no CI**, o de teste, que é recriado a cada execução e por isso sai sempre `0`. No CI o gate
  prova que a tarefa roda, **não** que produção está limpa.

## O que esta página não cobre

- **Produção.** A release não tem `mix`, então a tarefa não roda lá. A migração roda no deploy,
  e a poda apaga os registros preenchidos na primeira passada seguinte, que é de minutos.
- **De onde vieram os quatro.** Incógnita declarada em R6. A T008 impede que voltem sem ninguém
  saber, mas não explica a origem.
