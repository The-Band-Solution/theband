# Quickstart — provar que a coleta traz menos e não perde nada

**Feature** `020-coletar-so-o-que-mudou`

Duas provas, e elas respondem coisas diferentes: a **automatizada** monta o caso e roda sem rede;
a **do dado real** exige a chave mestra e a origem respondendo, e é da pessoa mantenedora.

---

## 0. Antes de qualquer coisa — a verificação que bloqueia o resto

Três perguntas, três consultas, uma sessão de `iex`. **Nenhuma linha de coleta incremental é
escrita antes disto.**

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
iex -S mix
```

| # | O que perguntar | O que confirma |
|---|---|---|
| 1 | `issues(filterBy: {since: "..."})` devolve menos que sem o filtro | R1 — o filtro existe e filtra |
| 2 | comentar numa issue e reconsultar: ela aparece na janela | R2 — comentário altera `updatedAt` |
| 3 | remover uma sub-issue e reconsultar o **pai**: ele aparece na janela | R3 — a marca continua exata sem coleta completa |

**A terceira decide o desenho.** Se o pai não entrar na janela, o vínculo removido só é visto na
coleta completa periódica — e a cadência dela deixa de ser rede de segurança para virar o
mecanismo principal.

Se alguma responder diferente do esperado, **o `research.md` é corrigido antes de qualquer
código**, e o contrato junto.

---

## 1. Os treze gates

```bash
mix gates
echo $?     # 0, e o veredito é este número
```

`mix gates` é a definição única. **Nunca com `| tail`** — o corte esconde a falha.

---

## 2. A prova automatizada

### Que a contagem diz a verdade

```bash
mix test test/the_band/ingestion/contagem_da_execucao_test.exs
```

| Caso | Espera |
|---|---|
| issue que não existia | `records_created` +1, `records_updated` inalterado |
| issue existente com conteúdo diferente | `records_updated` +1, `records_created` inalterado |
| issue idêntica | nenhum dos dois; `records_collected` +1 |
| execução interrompida no meio | os números do que já foi feito, **nunca zero** |

### Que a marca continua exata

```bash
mix test test/the_band/ingestion/marca_escopada_test.exs
```

| Caso | Espera |
|---|---|
| coleta completa, um vínculo largado pela origem | **aquele** marcado, e nenhum outro |
| coleta incremental que relê 1 de 100 pais | **zero** marcados entre os 99 não relidos |
| repositório pulado inteiro | **zero** marcados nele |
| lista de pais vazia | `{:ok, 0}` — e nada tocado |

O segundo caso é o que este plano existe para impedir. Sem o escopo, ele marcaria 99.

### Que pular é decidido pelo dado, e dito

```bash
mix test test/the_band/ingestion/pular_sem_atividade_test.exs
```

| Caso | Espera |
|---|---|
| `last_pushed_at` anterior à revisão | pulado, com motivo `:sem_push_desde_a_revisao` |
| `last_pushed_at` posterior | percorrido |
| nunca revisto | percorrido |
| sem `last_pushed_at` | percorrido — ausência de data não é ausência de mudança |
| interrompido no meio de um repositório | `issues_collected_at` **não** gravado |

### Que duas coletas seguidas não mexem em nada

```bash
mix test test/the_band/ingestion/idempotencia_incremental_test.exs
```

Nenhuma data muda na segunda. É o princípio III, e é o teste que pega gravação escondida.

**Sem mock de módulo de domínio.** Só a borda HTTP é simulada; o estado é montado pelo caminho
real — gravar issue, gravar vínculo, coletar de novo.

---

## 3. A prova no dado real — **precisa da pessoa mantenedora**

### Antes: o retrato de hoje

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where sr.last_pushed_at < r.issues_collected_at) as parados,
       count(*) as total
  from observed_repositories r
  join cmpo_source_repositories sr on sr.id = r.source_repository_id
  join connected_tools c on c.id = r.connected_tool_id
 where c.organization_login = 'leds-conectafapes';"
```

Esperado em 2026-08-14: **106 de 121**.

### Depois de uma coleta incremental

| # | O que conferir | Esperado |
|---|---|---|
| 1 | duração | menos de **um décimo** dos 6min 01s medidos hoje |
| 2 | repositórios consultados | no máximo **15** dos 121 — é o SC-005 |
| 3 | vínculos marcados | continua **52**, e nenhum a mais |
| 4 | `records_created` numa coleta que traz 502 novas | diz **502** — é o SC-006 |
| 5 | issues vigentes | continua **5031**, mais o que a origem tiver criado |

**A terceira é a que importa.** Se ela subir, a marca ficou escopada errado — e o número que
aparece é o tamanho do estrago.

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where no_longer_observed_at is not null) as marcados,
       count(*) as total
  from decomposition_links;"
```

Esperado: `52|1727` antes **e depois**.

### E a conferência de tela — olho humano, e não há substituto

`/syncs`: o cartão da execução diz **incremental**, quantos repositórios foram pulados e por quê,
e os três números fecham com o total percorrido.

Uma execução que diz "0 pulados" numa coleta incremental sobre 121 repositórios parados está
mentindo — e é o tipo de número que passa despercebido porque zero parece resultado.

---

## 4. Dependência declarada

A fase 0 depende da chave mestra e da origem respondendo. **As fases 1 e 2 não dependem** — a
contagem e o escopo da marca são consertos que valem por si, com a coleta ainda completa, e são
pré-requisito para provar que o corte não mudou o resultado.
