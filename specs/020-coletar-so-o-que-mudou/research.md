# Research — coletar só o que mudou

**Feature** `020-coletar-so-o-que-mudou` · **Data**: 2026-08-14

Três perguntas que a spec deixou abertas de propósito, e uma quarta que apareceu ao ler o código.

---

## R1 — O GraphQL do GitHub filtra issues por data de atualização?

**Decisão**: sim, por `filterBy: {since: DateTime}` no conector `issues`, combinado com
`orderBy: {field: UPDATED_AT, direction: DESC}`.

**Fundamento**: o tipo `IssueFilters` da API v4 tem o campo `since`, documentado como *"list
issues that have been updated at or after the given time"*. `IssueOrderField` aceita
`UPDATED_AT`.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| ordenar por `UPDATED_AT DESC` e parar na primeira issue antiga | funciona sem `since`, e é frágil: uma issue com data futura por relógio da origem pararia a página inteira |
| a API REST, que aceita `since` desde sempre | o conector inteiro é GraphQL; misturar dobra a autenticação, a paginação e o tratamento de rate limit |
| baixar tudo e comparar `updatedAt` em memória | não economiza o que custa — o custo é a ida à origem, não a comparação |

> **NÃO MEDIDO AQUI.** Isto é o que o schema documenta, e este repositório mede antes de
> construir. Verificar exige o token, que é da pessoa mantenedora, e é **uma** consulta. É a
> primeira tarefa do plano, e nada é construído em cima antes dela.

---

## R2 — Comentário em issue altera `updatedAt`?

**Decisão**: sim — e a consequência prática é que o corte por `updatedAt` é **conservador**,
não agressivo: ele traz mais do que o estritamente alterado, e nunca menos.

**Fundamento**: `updatedAt` na issue do GitHub muda com comentário, rótulo, designação, estado,
tipo e vínculo de sub-issue. É um carimbo de "algo nesta issue mudou", e não de "o corpo mudou".

**Por que isso é bom aqui.** A plataforma coleta rótulos, designados, tipo, estado e a lista de
partes. Todos entram no `updatedAt`. Um carimbo que muda demais produz coleta redundante; um que
muda de menos produz dado que não chega — e o segundo é o que não se pode aceitar.

> **NÃO MEDIDO AQUI**, pelo mesmo motivo do R1, e verificado pela mesma tarefa: uma issue
> comentada e não editada tem de aparecer na janela.

---

## R3 — Qual saída para a FR-012

**Decisão**: **nenhuma das duas que a spec listou.** Ler o código mostrou que a pergunta estava
mal posta, e a resposta certa é a terceira.

### O que a spec supunha

Que a coleta incremental **deixaria de marcar** o vínculo ausente, e que o conserto seria uma
passada completa periódica ou a origem informar remoção.

### O que o código faz

`mark_decomposition_links_no_longer_observed/3` marca por **repositório inteiro**:

```elixir
l.parent_issue_id in subquery(pais) and   # todos os pais do repositório
l.last_observed_at < ^desde and
is_nil(l.no_longer_observed_at)
```

Numa coleta que relê 34 issues de um repositório com 4295, os outros **4261 pais não são
revistos** — e todos os vínculos deles ficam com `last_observed_at < desde`.

**A marca não pararia de funcionar. Ela marcaria tudo.** Os 52 vínculos legitimamente ausentes
viriam acompanhados de milhares de falsos, e a plataforma passaria a afirmar que a origem largou
uma decomposição que ela nunca largou.

Isto é pior que o risco que a spec descreveu, e é a razão de a FR-012 existir.

### A saída

**Escopar a marca ao conjunto que foi efetivamente relido.** A função passa a receber os
identificadores dos pais percorridos, em vez do repositório:

```
mark_decomposition_links_no_longer_observed(tenant, parent_issue_ids, desde)
```

"Não apareceu" volta a significar algo em relação **ao que foi olhado**, que é a L19 — e é o que
a assinatura por repositório dizia enquanto a coleta era completa, por acidente.

### E o que sobra de risco

Um vínculo removido na origem só é visto se o **pai** entrar na janela. Isso depende de remover
uma sub-issue alterar o `updatedAt` do pai.

| Se altera | Se não altera |
|---|---|
| a marca continua exata, e a coleta completa periódica é só rede de segurança | o vínculo removido só é visto na próxima coleta completa |

**A verificação é a mesma tarefa do R1**, com um caso a mais: remover uma sub-issue e conferir se
o `updatedAt` do pai muda.

**A rede de segurança entra de qualquer jeito**, e não como plano B: uma coleta completa
periódica, com a cadência declarada na tela. O custo dela está medido — **6min 01s** para as três
organizações, em 2026-08-14.

---

## R4 — A fase de EO continua completa

**Decisão**: organização, membros e equipes continuam sendo coletados por inteiro. A coleta
incremental vale só para repositórios e issues.

**Fundamento**: medido em 2026-08-14.

| Fase | Registros | Duração aproximada |
|---|---:|---|
| EO — organização, membros, equipes | 445 na maior | segundos |
| trabalho — repositórios e issues | 4295 na maior | **5min 08s** |

O caro é o trabalho. E `mark_evidence_no_longer_observed/3`, que marca a evidência de vínculo
pessoa-equipe, tem exatamente o mesmo formato do problema do R3 — só que a fase dela continua
completa, então ela continua correta sem mudança alguma.

**Tornar EO incremental economizaria segundos e criaria o mesmo risco de novo.** Fica fora.

---

## R5 — O corte por repositório vem antes do corte por issue

**Decisão**: as duas histórias entram, e nesta ordem — repositório primeiro.

**Fundamento**: medido em 2026-08-14, na `leds-conectafapes`.

```
121 repositórios · 106 sem push desde a última revisão · 4295 issues
```

O corte por repositório elimina **87,6%** do trabalho sem tocar na consulta de issues, e usa dado
que já está no banco: `cmpo_source_repositories.last_pushed_at`, preenchido nos **160**
repositórios observados.

O corte por issue só rende dentro dos 15 repositórios restantes. É a história 3, P2, e depende do
R1 estar verificado.

---

## R6 — Onde a contagem estava sendo jogada fora

**Decisão**: os chamadores passam o resultado real da escrita, em vez de `:unchanged` fixo.

**Fundamento**: `Ingestion.tally/2` já distingue `:created`, `:updated` e `:unchanged` — e
`github_work_items.ex:121` e `:408` chamam `tally(:unchanged)` literalmente, para todo repositório
e toda issue.

Medido: `records_updated` é **zero nas 38 execuções** que existem no banco. `records_created` tem
valor em **4**, e as quatro são da fase de EO, que passa `record.outcome`.

**O upsert já devolve o que aconteceu** — é o que a fase de EO usa. A informação existe e é
descartada na linha seguinte.

---

## O que fica pendente de medida

| # | O que verificar | Como | Bloqueia |
|---|---|---|---|
| 1 | `filterBy: {since:}` existe e filtra | uma consulta com a chave mestra | história 3 |
| 2 | comentário altera `updatedAt` | comentar numa issue e reconsultar | história 3 |
| 3 | remover sub-issue altera `updatedAt` do pai | remover e reconsultar | a exatidão da FR-012 |

As três são a **primeira tarefa** do plano, e nenhuma linha de coleta incremental é escrita antes
delas. Construir sobre suposição de API é o defeito que a L23 descreve: verificação que não
aconteceu lida como verificação que passou.
