# Quickstart — Feature 007: a marca de trabalho no repositório

Nove verificações. Os números vêm do dado real, medidos em 2026-08-12: **135 repositórios, 41 com
issues vigentes, 94 sem, 38 inacessíveis** — e 4474 issues no total.

Dos 41 com issues, **5 estão inacessíveis** — e a marca conta os dois, porque o estado de
observação é da coluna `state` (FR-004).

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix ecto.migrate
mix phx.server            # localhost:4000/work
```

---

## V1 — A marca distingue os três estados

Abra `/work`.

**Esperado**, nas três formas:

| repositório | marca | texto |
|---|---|---|
| `theband` (194 issues) | preenchida | `194 issues` |
| um dos 94 sem issue, já coletado | vazia | `collected, no issues` |
| um recém-observado, sem coleta | tracejada | `not collected yet` |

**O que NÃO pode aparecer**: `0` como quantidade em nenhum dos dois últimos.

---

## V2 — Sem cor, a distinção sobrevive

```bash
mix test test/the_band_web/live/work_mark_test.exs -o "sem cor"
```

**Esperado**: o teste remove a cor e ainda distingue os três — pela forma e pelo texto. É WCAG
1.4.1, e a regra é do design system.

---

## V3 — Zero e desconhecido são frases diferentes

```bash
mix test test/the_band_web/live/work_mark_test.exs -o "desconhecido"
```

**Esperado**: `collected, no issues` para quem tem `issues_collected_at`, `not collected yet` para
quem não tem. **Se os dois textos forem iguais, o teste falha** — é o defeito que a feature existe
para não ter.

---

## V4 — A tela faz UMA consulta de contagem, não 135

```bash
mix test test/the_band/work_items/count_by_repository_test.exs
```

E no log do servidor, ao abrir `/work`:

```bash
grep -c "count(i0.\"id\")" /tmp/the_band_server.log
```

**Esperado**: **1** por render, não 135. A feature **reduz** o custo da tela.

**Falha típica**: a marca lê de uma segunda consulta → 2 por render, e o número cresce com a
coleta.

---

## V5 — Coluna e marca nunca discordam

```bash
mix test test/the_band_web/live/work_mark_test.exs -o "mesmo número"
```

**Esperado**: para cada linha, o número da coluna é o mesmo que a marca resume. Um mapa, dois
leitores — FR-010.

---

## V6 — Todo repositório continua clicável

```bash
mix test test/the_band_web/live/work_mark_test.exs -o "clicável"
```

**Esperado**: os 135 têm link, **inclusive os 94 sem issue**. A tela deles explica por que estão
vazios, e é isso que alguém procura ao clicar num vazio.

---

## V7 — A marca funciona no cartão do telefone

Abra `/work` em 360 px de largura.

**Esperado**: a tabela vira cartões, e a marca aparece na linha do repositório com o rótulo
`repository` ao lado — o mesmo HTML, convertido pelo `stacked`.

---

## V8 — Excluído e inacessível não recebem a data

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where issues_collected_at is not null) as com_data,
       count(*) filter (where inaccessible_since is not null and issues_collected_at is null) as inacessiveis_sem_data
  from observed_repositories;"
```

**Esperado**: os inacessíveis **não** têm data — a plataforma não os consultou, e a ausência da
data é a informação.

**E o oposto também vale**: depois de uma coleta que os alcance, eles ganham a data e a marca
muda sozinha.

---

## V9 — Nenhum dos 41 aparece como "não coletado"

**É a verificação que a análise acrescentou**, e a que pega o defeito mais grave possível nesta
feature: depois da migração **todos** os 135 repositórios têm `issues_collected_at` nulo, e 41
deles têm issues dentro. Se a marca decidir pela data antes da contagem, a tela diz
`not collected yet` sobre um repositório com 2 514 issues.

```bash
mix test test/the_band_web/live/work_mark_test.exs -o "contagem primeiro"
```

E no dado real, depois de abrir `/work`:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) from observed_repositories r
 where r.issues_collected_at is null
   and exists (select 1 from collected_issues i
                where i.observed_repository_id = r.id and i.no_longer_observed_at is null);"
```

**Esperado**: o número que sair dali — 41 hoje — é quantos repositórios a tela **precisa** mostrar
como tendo trabalho apesar de não haver data. Nenhum deles pode exibir `not collected yet`.

**Falha típica**: `if repo.issues_collected_at == nil, do: :desconhecido` como primeiro ramo.

---

## Os dez gates

```bash
mix gates
```

**Esperado**: `10 gates verdes`, e código de saída zero. Conferir pelo texto não basta — o
validador Python avisa que pulou e sai diferente de zero, e foi a L23.
