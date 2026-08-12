# Aceitação — Feature 007: a marca de trabalho no repositório

**Sprint**: [006](../../docs/sprints/006-marca-de-issues/sprint-backlog.md) ·
**PR**: [#195](https://github.com/The-Band-Solution/theband/pull/195), incorporado em
2026-08-12T12:21:51Z
**Avaliado em**: 2026-08-12, contra `main` em `277d159`

**Suíte verde não é evidência de critério atendido** — é a L18. Cada critério abaixo tem a
medida que o sustenta, e onde a evidência é o teste, o teste é nomeado.

## Os dez gates, em `main`

```
$ mix gates > /tmp/gates_main.txt 2>&1; echo "código de saída: $?"
código de saída: 0

10 gates verdes.
```

370 testes. Conferido por **código de saída**, nunca por texto — L22.

## O dado real, depois da migração

```sql
select count(*) as observados,
       count(*) filter (where issues_collected_at is not null) as com_data,
       count(*) filter (where issues_collected_at is null and exists (
         select 1 from collected_issues i
          where i.observed_repository_id = r.id and i.no_longer_observed_at is null)) as sem_data_com_issues,
       count(*) filter (where not exists (
         select 1 from collected_issues i
          where i.observed_repository_id = r.id and i.no_longer_observed_at is null)) as sem_vigentes,
       count(*) filter (where inaccessible_since is not null and exists (
         select 1 from collected_issues i
          where i.observed_repository_id = r.id and i.no_longer_observed_at is null)) as inacessiveis_com_issues
  from observed_repositories r;

 135 | 0 | 41 | 94 | 5
```

E o repositório que dá peso ao achado A1:

```sql
 conectafapes-project | 2514 | sem_data = t
 plataformas-project  |  647 | sem_data = t
 agentes-project      |  526 | sem_data = t
```

**Nenhum dos 135 tem data**, e o maior tem 2 514 issues coletadas. Se a marca decidisse pela
data, a tela diria `no collection recorded` sobre ele.

---

## Critérios de sucesso

| # | Critério | Evidência | Veredito |
|---|---|---|---|
| SC-001 | identificar os que têm trabalho **sem ler número** | a marca tem forma e texto próprios na célula `work`, independentes da coluna `issues`; 41 cheias contra 94 tracejadas no dado real | **atendido** |
| SC-002 | os três estados distinguíveis com a cor removida | `work_mark_test.exs`, "sem cor, a distinção sobrevive" — remove as classes de cor e exige três formas distintas. **Conferido por reprovação**: com forma igual e só cor variando, o teste falha | **atendido** |
| SC-003 | cada marca anunciada por leitor de tela por extenso | `marca_rotulo/3` em `sr-only`, com frase diferente por estado; asserido no mesmo arquivo | **atendido** |
| SC-004 | nenhum repositório com contagem desconhecida aparece como zero | o texto do terceiro estado é `no collection recorded`, e a coluna `issues` mostra `0` **ao lado** da marca tracejada — o número é da coluna, a afirmação é da marca | **atendido, com ressalva registrada abaixo** |
| SC-005 | todos os 135 continuam navegáveis | `work_mark_test.exs`, "todo repositório continua clicável, inclusive os vazios" — exige link nos três estados | **atendido** |
| SC-006 | a lista faz o mesmo número de consultas, ou menos | `por_repositorio/2` chama `count_collected_by_repository/2` **uma vez**; eram 135. Uma consulta nova entrou para o quarto texto — total **2**, contra 135 | **atendido** |
| SC-007 | coluna e marca mostram o mesmo número | `work_mark_test.exs`, "não há contagem ao lado de marca vazia" — casa `data-label="issues"` e o texto da marca na mesma linha | **atendido** |
| SC-008 | repositório com issues e sem registro aparece como tendo trabalho | os **41** medidos acima; `work_mark_test.exs`, "a ordem de decisão é a contagem primeiro". **Conferido por reprovação**: invertendo a ordem, 5 testes falham | **atendido** |
| SC-009 | legível e tocável em 360 px | a marca vive na mesma `<td>` com `data-label`, e o `stacked` do design system converte a tabela em cartões por CSS — o mesmo HTML. **Não houve conferência visual** | **não verificado** |
| SC-010 | um tenant não alcança repositório de outro | `count_by_repository_test.exs`, "não conta issue de outro tenant" — a consulta de outro tenant devolve `%{}` | **atendido** |
| SC-011 | a tela de sincronização permanece sem a marca | nenhuma tarefa tocou `sync_live/`; `git diff` do PR não inclui o arquivo | **atendido** |

**10 de 11 atendidos. SC-009 não foi verificado** — a estrutura está lá e ninguém olhou a tela
em 360 px. Declarar atendido seria declarar sucesso sem evidência.

## A ressalva do SC-004

A coluna `issues` mostra `0` para os 94 repositórios sem trabalho vigente, e a marca ao lado diz
`no collection recorded`. O critério pede que **a marca** não trate desconhecido como zero, e ela
não trata: o texto dela nomeia a ausência do registro.

Mas na mesma linha existe um `0`, e ele é a contagem — que é verdadeira: não há issue vigente. As
duas informações são diferentes e ambas verdadeiras, e é por isso que a marca não substituiu a
coluna nem a coluna substituiu a marca.

**Se a leitura conjunta ainda confundir, o ajuste é na coluna, não na marca** — e é decisão da
pessoa mantenedora, não desta feature.

---

## Requisitos funcionais

| # | Requisito | Onde | Veredito |
|---|---|---|---|
| FR-001 a FR-003 | a marca, três estados, três canais | `work_item_live/index.ex`, célula `work` | atendido |
| FR-004 | não repete o que a coluna `state` diz | a marca não lê `excluded_at`, `inaccessible_since` nem `archived_at` | atendido |
| FR-005 | desconhecido não aparece como zero | `no collection recorded`, texto próprio | atendido |
| **FR-005a** | **a contagem decide primeiro** | `marca/2`, `cond` com a contagem no primeiro ramo; 41 repositórios dependem disso | atendido |
| FR-006 | funciona na tabela e no cartão | mesmo HTML, `data-label="work"` | estrutura entregue, **visual não conferido** |
| FR-007 a FR-009 | navegação e toque | link em toda linha; alvo de toque vem do design system | atendido |
| FR-010 | um número, dois consumidores | os dois leem `@por_repositorio` | atendido |
| FR-011 | não aumentar consultas | 135 → 2 | atendido |
| FR-012 | isolamento entre tenants | consulta filtra por `tenant_id`; teste de outro tenant | atendido |
| FR-013 | escopo é `/work` | a tela de sincronização não foi tocada | atendido |

**14 de 14 com implementação.** FR-006 tem a estrutura e não a conferência visual.

---

## O que a feature entregou além do planejado, e por quê

| Item | Motivo |
|---|---|
| `repositories_with_absent_issues/2` | o quarto texto não é derivável da contagem de vigentes — o contrato declarava duas funções e faltava uma |
| `no collection recorded` em vez de `not collected yet` | o texto anterior afirmava que a coleta não ocorreu, e dos 94 com data nula a coleta visitou **61** |
| tolerância a `:not_found` em `clear_inaccessible/2` | o teste de T004 achou: a corrida derrubava a fase **um ponto antes** do código novo |

## O que ficou sem exercício no dado real

**O quarto texto — `no current work` — tem zero ocorrências em produção:**

```sql
select count(*) from collected_issues where no_longer_observed_at is not null;
 0
```

Nenhuma issue está marcada como ausente hoje, então o caminho existe, tem teste, e **nunca
apareceu na tela**. Está declarado aqui em vez de contado como verificado no dado real — é a L30
aplicada na direção honesta: medir contra a origem também significa dizer quando a origem não tem
o caso.

## Veredito

**Aceito, com uma verificação pendente e nenhuma dívida escondida.**

Sete tarefas entregues, 16 testes próprios, 10 gates verdes em `main`, e os dois defeitos que
importavam conferidos por reprovação. O que falta é olhar a tela em 360 px — e isso não se
substitui por asserção em HTML.
