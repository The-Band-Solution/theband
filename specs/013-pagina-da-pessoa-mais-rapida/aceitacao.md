# Aceitação — feature 013, a página da pessoa que não varre tudo

**Avaliada em**: 2026-08-12 · **Branch**: `019-a-pagina-da-pessoa-que-nao-varre-tudo`
**Método**: cada critério avaliado um a um, com a medida ao lado. **Medido na aplicação em
execução**, com o banco de desenvolvimento real — o mesmo dos números do "antes".

---

## A medida, antes e depois

Cinco aberturas por pessoa, mesmo método dos dois lados (render HTTP inicial):

| pessoa | designadas | antes | depois |
|---|---:|---:|---:|
| tadeuaugustovs | 288 | **6,12 s** | **0,031 s** |
| MateusLannes | 276 | 5,51 s | 0,030 s |
| joaomrpimentel | 221 | 4,55 s | 0,033 s |
| marcelasfl | 191 | 4,53 s | 0,035 s |
| Ilhe8l | 201 | 4,08 s | 0,038 s |
| LuizRojas | 177 | 3,85 s | 0,035 s |
| luanotoni | 173 | 3,58 s | 0,033 s |
| vinicius-je | 350 | 0,09 s | 0,033 s |
| `/work` | — | 322 ms | **120 ms** |
| `/people` | — | 25 ms | 29 ms |

**A pior página caiu 197 vezes.** A variação entre a mais lenta e a mais rápida saiu de **setenta
vezes** para **1,4**.

---

## Requisitos funcionais — 10 de 10

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | o custo não cresce com o histórico | **aceito** | `custo_da_vigente_test.exs` — dobrar o histórico não dobra as linhas lidas |
| FR-002 | as issues da pessoa por índice, sem varredura | **aceito** | migração `20260812230000`; `Bitmap Index Scan` no plano do dado real |
| FR-003 | o conceito é o da promoção mais recente | **aceito** | `promocao_vigente_test.exs` — promoção nova muda a vigente |
| FR-004 | desempate determinístico | **aceito** | cinco leituras seguidas com empate montado devolvem a mesma |
| FR-005 | nada é apagado | **aceito** | o teste assere que a promoção anterior continua na tabela |
| FR-006 | issue sem promoção aparece, sem conceito | **aceito** | e **não** entra nas contagens — os dois casos |
| FR-007 | escopo por tenant | **aceito** | o teste do tenant vizinho |
| FR-008 | conteúdo idêntico | **aceito** | **seis retratos, seis `diff` vazios** |
| FR-009 | medida registrada antes e depois | **aceito** | a tabela acima, cinco medidas por linha |
| FR-010 | teste que falha se o custo voltar a crescer | **aceito** | `custo_da_vigente_test.exs`, com guarda contra medida vazia |

## Critérios de sucesso — 9 de 9

| # | Critério | Veredito | Medida |
|---|---|---|---|
| SC-001 | qualquer pessoa abaixo de 200 ms | **aceito** | a pior é **38 ms** |
| SC-001b | a variação cai de 70× para menos de 3× | **aceito** | **1,4×** — 0,030 s a 0,043 s |
| SC-002 | deixa de ler 44 289 linhas de promoção | **aceito** | o plano lê ~2 por issue exibida |
| SC-002b | `LIMIT 100` custa menos que `LIMIT 25` custava | **aceito** | 3,0 ms contra 6 326 ms |
| SC-003 | sem varredura de designações no plano | **aceito** | `Bitmap Index Scan` sobre o índice novo |
| SC-004 | `/work` abaixo de 200 ms | **aceito** | **120 ms** |
| SC-005 | conteúdo idêntico em cada tela | **aceito** | os seis `diff` |
| SC-006 | histórico dobrado não dobra o custo | **aceito** | teste automatizado, medindo linhas lidas |
| SC-007 | nenhuma promoção some | **aceito** | contagem depois **maior** que antes, no próprio teste |

---

## O que a implementação achou, e a spec não previa

| # | Achado | Onde ficou |
|---|---|---|
| 1 | **o teste de custo passava vazio**: a regex procurava `"Relation Name"` antes de `"Actual Rows"`, e o JSON do Postgres vem em **ordem alfabética**. `0 <= 0 × 1,5` passa sempre | a guarda `simples > 0`, que pegou; e a leitura passou a percorrer o plano |
| 2 | **em lateral, linhas são por loop**: contar só `Actual Rows` diria que a consulta lê duas linhas, quando lê duas **por issue exibida** | `Actual Rows × Actual Loops` |
| 3 | a `vigente` do **pai** precisa de binding próprio | `vigente_do_pai/1`, apontando para o vínculo e não para a issue da linha |
| 4 | `evidence_source` tem check constraint com três valores | o teste usa `declared_type`, não um valor inventado |

## O que ficou como dívida declarada

| Dívida | Por quê |
|---|---|
| `mapping/queries.ex` mantém a **segunda** definição de promoção vigente | reusar exigiria expor subconsulta pela fronteira pública, que a ADR 0003 proíbe. As duas ordens foram alinhadas, e a duplicação está escrita no código |
| o `DISTINCT ON` continua onde a pergunta é **agregada** | lateral por linha só ganha quando há poucas linhas para decorar; `gap_summary/2` agrega uma organização inteira |

## Veredito

**Feature aceita.** Dez requisitos funcionais e nove critérios de sucesso, todos com evidência
medida — e a prova de que a resposta não mudou são seis `diff` vazios, não a impressão de que as
telas continuam parecidas.
