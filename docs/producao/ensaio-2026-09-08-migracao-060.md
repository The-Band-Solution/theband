# Ensaio da migração `20260908010000` sobre dado real — 2026-09-08

O que esta release traz de mais arriscado é uma migração que **altera dados**:
`20260908010000_saida_declarada_com_autor.exs` acrescenta três colunas, faz backfill de
`declared_at` e cria duas CHECKs.

Ela **quebrou** no banco de desenvolvimento antes de eu a corrigir, e o motivo é o que este
ensaio mede: `CREATE CONSTRAINT` valida as linhas existentes **no instante da criação**, e as
CHECKs vinham antes do backfill. Passava em banco vazio — que é o da suíte — e reprovava em
qualquer banco com vínculo declarado.

## O que foi ensaiado, e o que NÃO foi

**Ensaiado**: a migração aplicada a uma cópia restaurada do banco de desenvolvimento, a partir
do estado **pré-migração** — que é o estado em que a produção está.

**Não ensaiado**: o §6 do runbook — baixar o backup do destino S3, restaurar num banco novo do
Dokploy e conferir os números na tela de uma instância de ensaio. Aqueles passos são marcos da
pessoa (exigem VPS e acesso ao S3), e continuam pendentes. Este ensaio **não os substitui**:
ele responde "a migração roda sobre dado real?", e não "o backup existe de verdade?".

## O procedimento

```bash
pg_dump the_band_dev > /tmp/ensaio.sql        # cópia
createdb band_ensaio && psql band_ensaio < /tmp/ensaio.sql
# volta ao estado da produção: derruba as três colunas, as duas CHECKs, e a linha
# de schema_migrations
# roda a migração na ordem do arquivo, numa transação
```

## Os números

| medida | antes | depois |
|---|---:|---:|
| vínculos (`eo_team_memberships`) | **90** | **90** |
| com `declared_by_user_id` preenchido | 34 | 34 |
| com `declared_at` preenchido | — (coluna não existia) | **34** |
| **par incompleto** (autor sem instante) | — | **0** |
| encerrados (`ended_at`) | 0 | 0 |
| fim com autor (`ended_by_user_id`) | — | 0 |

O `UPDATE` do backfill reportou **34 linhas** — exatamente as que têm autor. Nenhuma linha
perdida, nenhum par incompleto, e as duas CHECKs criadas sem violação.

## A prova de que a ordem importava

Voltei o ensaio ao estado pré-migração e tentei **na ordem errada** — a CHECK antes do
backfill. Sobre as mesmas 90 linhas:

```
ERROR:  check constraint "eo_declaracao_tem_autor" of relation
        "eo_team_memberships" is violated by some row
```

A transação abortou e a constraint não foi criada. É o mesmo erro que apareceu no banco de
desenvolvimento, e é a razão de a ordem no arquivo ser backfill → CHECKs.

## O que isto permite afirmar sobre a produção

As duas CHECKs são **satisfeitas por construção** num banco pré-migração, e o ensaio o
confirma empiricamente:

- `eo_declaracao_tem_autor` só falharia com `declared_at` preenchido e autor nulo. Antes da
  migração a coluna não existe, então toda linha entra com `declared_at` nulo — e o backfill a
  preenche exatamente onde há autor;
- `eo_saida_declarada_completa` só falharia com autor ou instante do fim preenchidos. As duas
  colunas nascem nesta migração, nulas em toda linha.

O que o ensaio **não** garante é o tempo: 90 linhas num contêiner local não dizem quanto o
`UPDATE` custa sobre um volume maior. Em produção o número de vínculos é da mesma ordem, e a
migração roda numa transação — se ela falhar, falha inteira, e o esquema fica como estava.
