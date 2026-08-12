# Pesquisa — a página da pessoa que não varre tudo

**Feature**: `013-pagina-da-pessoa-mais-rapida` · **Data**: 2026-08-12
**Método**: aplicação **em execução**, log do servidor, `EXPLAIN (ANALYZE, BUFFERS)` no banco de
desenvolvimento. Nenhum número aqui veio de suspeita.

---

## D1 — Onde o tempo está, medido e não estimado

| Tela | Tempo (5 medidas) | Consultas | Consulta dominante |
|---|---:|---:|---|
| `/people` | 25 ms · variação < 6% | 9 | nenhuma acima de 3 ms |
| `/people/:id` | **0,09 s a 6,12 s** conforme a pessoa | 13 | **6 326 ms** numa só, no pior caso |
| `/work` | 322 ms · variação < 1% | 15 | quatro acima de 40 ms |

**A primeira medida desta pesquisa pegou a exceção.** Medi `vinicius-je` — 85 ms — e concluí que a
tela custava 85 ms. A pessoa mantenedora apontou uma página de **2 s**, e a medida das oito com mais
trabalho mostrou o quadro real:

| pessoa | designadas | tempo |
|---|---:|---:|
| tadeuaugustovs | 288 | **6,12 s** |
| MateusLannes | 276 | 5,51 s |
| joaomrpimentel | 221 | 4,55 s |
| marcelasfl | 191 | 4,53 s |
| Ilhe8l | 201 | 4,08 s |
| LuizRojas | 177 | 3,85 s |
| luanotoni | 173 | 3,58 s |
| vinicius-je | **350** | **0,09 s** |

**Quem tem mais trabalho é a mais rápida** — e é essa inversão que prova que o custo não vem da
página. É a **L30** cobrando de novo: uma medida não descreve uma distribuição.

---

## D2 — A causa: a promoção vigente é calculada para o tenant inteiro

**Decisão**: trocar a subconsulta única por uma resolução **por linha exibida**.

**A evidência, do plano de execução de hoje**:

```text
Seq Scan on issue_promotions  (44 289 linhas)            8,8 ms
  Sort (3 822 kB, quicksort)                            33,1 ms
    Unique → 4 512 linhas
      Merge Left Join com as 350 issues da pessoa
        Limit 25
Execution Time: 41,5 ms
```

O `DISTINCT ON (collected_issue_id) … ORDER BY inserted_at DESC` roda **sobre todas as promoções do
tenant**, sem qualquer relação com a pessoa da tela. Depois o resultado inteiro é cruzado, e 25
linhas sobrevivem.

**Custa 33 dos 41 ms, e cresce com o histórico, não com a tela**: 9,8 promoções por issue hoje, 13 no
máximo, mais a cada coleta.

**A alternativa, medida no mesmo banco**: resolver a vigente **por issue**, com `LATERAL` e `LIMIT 1`
sobre o índice `(collected_issue_id, inserted_at)` que já existe.

```text
Index Scan Backward using issue_promotions_collected_issue_id_inserted_at_index
  loops=350 · 0,004 ms por loop
Execution Time: 3,19 ms
```

| | antes | depois |
|---|---:|---:|
| tempo da consulta | **41,5 ms** | **3,19 ms** |
| linhas de promoção lidas | 44 289 | ~2 por issue exibida |
| ordenação em memória | 3 822 kB | nenhuma |

**Treze vezes mais rápida, sem tabela nova, sem coluna nova e sem apagar nada.**

**E uma alternativa que parecia barata, medida antes de virar tarefa**: enxugar a projeção da
subconsulta para as nove colunas que a tela usa. **Não resolve — 5 738 ms**, contra 6 326 da versão
completa. A largura não é a causa; a estratégia de execução é. Com duas colunas o planejador faz uma
ordenação só (35 ms), com nove ele faz **163 451** ordenações em grupo. A tela não é sintonizável por
projeção.

**Alternativas descartadas**:

| Alternativa | Por que não |
|---|---|
| materializar a promoção vigente numa coluna | **viola a ADR 0004 D7** — situação derivável não é materializada; criaria um terceiro lugar para discordar do mesmo fato |
| marcar a vigente com um booleano `is_current` | booleano no lugar do relator, antipadrão declarado no `AGENTS.md` §7.7; e exigiria escrita a cada coleta |
| view materializada | mesmo problema do D7, mais defasagem: a tela mostraria promoção antiga sem dizer que é antiga |
| apagar promoções antigas | o histórico **é** proveniência — princípio III, e a FR-005 proíbe |
| cache em memória | esconde o custo em vez de removê-lo; a primeira visita de cada pessoa continua pagando **6 s**, e cada coleta invalida tudo |
| **enxugar a projeção** | medido: **5 738 ms**. A largura não é a causa |
| paginar de 100 em 100 | medido: `LIMIT 5` custa 6 300 ms e `LIMIT 100` custa 6 648. A varredura acontece **antes** do limite, e cada lote pagaria de novo |

---

## D3 — O segundo custo: a designação não tem índice pela pessoa

**Decisão**: índice em `issue_assignees (person_id, no_longer_observed_at)`.

**A evidência**:

```text
Seq Scan on issue_assignees
  Filter: (no_longer_observed_at IS NULL) AND (person_id = …)
  Rows Removed by Filter: 3 882      ← lê 4 232 para devolver 350
```

Os índices existentes são `(collected_issue_id, login)` e
`(collected_issue_id, no_longer_observed_at)` — os dois respondem *"quem é designado desta issue"*.
**Nenhum responde a pergunta que a página da pessoa faz**, que é a inversa.

**Medido com o índice criado no banco de desenvolvimento** (criado, medido e **removido** — o
definitivo vem por migração):

```text
Bitmap Index Scan on (person_id, no_longer_observed_at)
  0,036 ms · rows=350          ← contra 0,63 ms de varredura
```

**Com as duas mudanças juntas**: `Execution Time: 3,19 ms`, e **zero** varreduras sequenciais no
plano.

---

## D4 — O desempate, e um erro meu que o código já contradizia

`DISTINCT ON (collected_issue_id) … ORDER BY collected_issue_id, inserted_at DESC` não tem
desempate explícito.

**Eu escrevi que isso era defeito, alegando que `inserted_at` tinha precisão de segundo. É falso.**
O schema declara `timestamps(type: :utc_datetime_usec)`, a coluna tem precisão **6** no banco, e a
docstring de `list_issues/2` já dizia, por extenso: *"`inserted_at` em microssegundo desempata, e é a
L20 aplicada aqui"*. Afirmei o contrário de um fato que o código documentava.

**O que sobra, depois da correção**: com microssegundo, empate exige duas escritas no mesmo
microssegundo — e a medida de hoje dá **zero**. O desempate por `id` entra como **seguro barato**, e
não como correção de defeito: ele custa nada e torna a FR-004 verificável sem depender da precisão
do relógio continuar sendo essa.

**Quantas issues estão nessa situação hoje — medido (T001)**:

```sql
select count(*) from (
  select collected_issue_id from issue_promotions
   group by collected_issue_id, inserted_at having count(*) > 1) t;
→ 0
```

**Zero, e o desempate entra assim mesmo.** A coleta idempotente grava uma promoção por execução, e
execuções não caem no mesmo segundo — hoje. O que impede o empate é acidente de cadência, não regra:
duas execuções concorrentes de ferramentas diferentes no mesmo tenant produziriam o caso, e ele
apareceria como conceito que muda entre renders, sem erro nenhum.

---

## D5 — O alcance, e por que a correção não pode ser só na tela pedida

A subconsulta de promoção vigente aparece **16 vezes** em `work_items/queries.ex` e **24** no código
todo. Toda tela que diz o conceito de uma issue paga a varredura.

**Decisão**: corrigir **na função que todas usam** — `promocoes_vigentes/1` —, não na página.

**O que fica pior**: uma mudança num ponto altera o plano de execução de dezesseis consultas. É
justamente por isso que a FR-008 exige conteúdo **idêntico** e a verificação é por comparação lado a
lado, tela por tela.

---

## D6 — Como medir, e a armadilha da L38

**Decisão**: medir sempre pela **diferença** e pela **constância**, com cinco repetições, e usar o
mesmo método antes e depois.

**A armadilha**: `live/2` faz **dois** renders. Uma medida ingênua conta o dobro e atribui à consulta
o que é do framework. Os números desta pesquisa vêm do render HTTP inicial, medidos igualmente dos
dois lados da comparação.

**E a segunda armadilha, do banco**: `EXPLAIN ANALYZE` repetido esquenta o cache. Por isso a
comparação relata `Buffers: shared hit` junto do tempo — a queda de 41,5 para 3,19 ms vem de **ler
menos linhas**, não de ler as mesmas mais rápido.
