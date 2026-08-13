# Plano de implementação: a página da pessoa que não varre tudo

**Feature**: `specs/013-pagina-da-pessoa-mais-rapida/` · **Branch**: `019-a-pagina-da-pessoa-que-nao-varre-tudo`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: pedido da pessoa mantenedora, 2026-08-12

---

## Summary

A promoção vigente de uma issue passa a ser resolvida **por issue exibida**, e não varrendo as
44 289 promoções do tenant. Mais um índice que responde a pergunta que a página da pessoa faz.

**Medido no banco real, antes de escrever este plano**: a consulta dominante cai de **41,5 ms para
3,19 ms**, e o plano de execução fica **sem nenhuma varredura sequencial**.

## O que este plano decide antes de tudo

**Não é uma feature de tela. É uma consulta que responde a pergunta errada.**

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| como resolver a vigente | `LATERAL` com `LIMIT 1` por issue, sobre o índice que já existe | materializar viola a **ADR 0004 D7**; booleano é antipadrão declarado |
| onde corrigir | na função que as **16** consultas usam | corrigir na página deixaria a causa de pé em quinze lugares |
| o índice novo | `issue_assignees (person_id, no_longer_observed_at)` | sem ele, achar as issues da pessoa continua lendo 4 232 para devolver 350 |
| o desempate | `inserted_at DESC, id DESC` | seguro barato: hoje o empate é impossível na prática — microssegundo, zero casos —, e a ordem deixa de depender disso |
| como verificar | conteúdo **idêntico**, tela por tela, mais medida por diferença e constância | "ficou mais rápido" sem conferir o conteúdo é otimização que muda a resposta |

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 — **uma** migração, só índice |
| Escala medida | 4 529 issues · 44 289 promoções · 4 232 designações · 75 pessoas |
| Fronteiras | **WorkItems** (promoção, designação) — nenhuma nova |
| Arquivos | `work_items/queries.ex`, uma migração, e os testes |
| Telas alteradas | **nenhuma** — e isso é requisito, não efeito colateral (FR-008) |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo, nenhum conceito alterado. A promoção vigente continua sendo **derivada**; só
muda como ela é encontrada.

### II. Fonte externa não é domínio — **não se aplica**

Nada toca a origem.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e é o eixo**

**O histórico não é tocado**: 44 289 promoções continuam lá, e a FR-005 e a SC-007 exigem que a
contagem depois seja maior ou igual. A mudança é de **leitura**.

**O desempate (D4) entra como seguro**, não como correção: com `inserted_at` em microssegundo o
empate é impossível na prática, e a medida dá zero.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhuma regra de mapeamento muda.

### V. Monólito modular multitenant — **conforme**

Todas as consultas continuam escopadas por tenant, e o `LATERAL` carrega `tenant_id` na cláusula —
conferido no `EXPLAIN` da pesquisa.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist e pesquisa commitados antes deste plano. **Nada implementado.** O sprint 012 abre com
`sprint-backlog` antes da primeira linha.

### VII. Quality gates e revisão independente — **conforme, com a lacuna de sempre declarada**

Dez gates verdes por código de saída antes do PR; revisão pedida à equipe `the-band`. A revisão
independente depende de pessoa, e enquanto não vier fica declarada.

### VIII. Desenho que o problema justifica — **conforme**, registro abaixo

### IX. Ontologias modulares e autônomas — **conforme**

Nenhuma fronteira cruzada. `issue_promotions` e `collected_issues` já convivem em WorkItems.

### X. Responsabilidade única — **conforme**

`promocoes_vigentes/1` continua fazendo uma coisa: dizer qual é a promoção vigente. Muda **como**,
não **o quê**.

---

## Registro das decisões de desenho (princípio VIII)

### P1 — `LATERAL` no lugar da subconsulta única

| Pergunta | Resposta |
|---|---|
| **Que problema concreto resolve** | 44 289 linhas lidas e 3,8 MB ordenados para decorar 25 — 33 dos 41 ms |
| **Existe agora ou é previsão** | **existe agora**, medido com `EXPLAIN (ANALYZE, BUFFERS)` |
| **O que fica pior** | `LATERAL` é menos familiar que `join` para quem lê; e o custo passa a ser **por linha exibida** — uma tela que exiba 500 linhas paga 500 buscas de índice, em vez de uma varredura. **Para páginas de 25 a 50, ganha; para exportação sem paginação, perderia** |

**O limiar está declarado**: a maior página do sistema tem 50 linhas, e a maior lista de partes
medida tem 2 514 — essa **não** usa a resolução por linha, e fica registrada como caso a conferir na
fase de tarefas.

### P2 — Índice `(person_id, no_longer_observed_at)`

| Pergunta | Resposta |
|---|---|
| **Que problema concreto resolve** | varredura de 4 232 designações, descartando 3 882, a cada abertura da página da pessoa |
| **Existe agora ou é previsão** | **existe agora**, e está no plano de execução |
| **O que fica pior** | mais um índice a manter na escrita: `replace_assignees/3` roda uma vez por issue por coleta — 4 529 escritas pagam a atualização. É barato, e a alternativa é a leitura pagar sempre |

### P3 — O desempate determinístico

**Não é correção de defeito, e eu cheguei a escrever que era.** `inserted_at` é
`utc_datetime_usec` — a docstring de `list_issues/2` já dizia isso, e eu afirmei o contrário sem
conferir. Com microssegundo, o empate exige duas escritas no mesmo microssegundo, e a medida dá zero.

Entra como **seguro barato**: custa nada, e tira a ordem da dependência de o carimbo continuar tendo
essa precisão.

### P4 — O que foi recusado, e por quê

| Recusado | Razão |
|---|---|
| materializar a vigente em coluna | ADR 0004 D7 — situação derivável não se materializa |
| booleano `is_current` | antipadrão declarado no `AGENTS.md` §7.7 |
| view materializada | defasagem que a tela não teria como dizer |
| apagar promoção antiga | princípio III; o histórico é proveniência |
| cache | esconde o custo em vez de removê-lo |

---

## Project Structure

```text
specs/013-pagina-da-pessoa-mais-rapida/
├── spec.md · plan.md · research.md
├── data-model.md · quickstart.md
├── contracts/promocao-vigente.md
└── checklists/requirements.md

lib/the_band/work_items/
└── queries.ex                    # promocoes_vigentes/1 — o ponto único

priv/repo/migrations/
└── <ts>_index_designacao_por_pessoa.exs

test/the_band/work_items/
└── promocao_vigente_test.exs     # vigência, desempate, e o custo que não cresce
test/the_band_web/live/
└── person_detail_test.exs        # já existe: a contagem de consultas entra aqui
```

**Structure Decision**: nenhum arquivo novo de código. Uma migração, uma função reescrita, testes.

---

## Fases

| Fase | O que |
|---|---|
| **F1** | o contrato de `promocoes_vigentes/1`, e o teste que fixa vigência e desempate **antes** da reescrita |
| **F2** | a reescrita com `LATERAL`, e a migração do índice |
| **F3** | a prova de que o conteúdo não mudou — tela por tela, lado a lado |
| **F4** | a medida antes/depois nas três telas, com cinco repetições |

**F3 é a fase que ninguém pula.** Uma otimização que muda a resposta não é otimização; é defeito com
tempo melhor. E o defeito seria **silencioso**: a tela continuaria abrindo.

---

## Riscos

| Risco | Mitigação |
|---|---|
| **a resposta mudar** em alguma das 16 consultas | F3 compara conteúdo antes e depois em cada tela afetada |
| `LATERAL` perder para páginas grandes | o limiar está declarado; a lista de 2 514 partes é conferida na fase de tarefas |
| a medida enganar por cache quente | comparar `Buffers: shared hit` junto do tempo, e cinco repetições |
| medir o dobro por causa do LiveView | **L38** — dois renders em `live/2`; o mesmo método dos dois lados |
| o índice novo pesar na escrita | medir a coleta antes e depois; ela roda 4 529 vezes `replace_assignees/3` |
| empate de `inserted_at` já existir hoje | contar antes; o desempate entra mesmo se for zero |

---

## Complexity Tracking

| Violação | Por que é necessária | Alternativa mais simples recusada porque |
|---|---|---|
| nenhuma | — | — |

**Sem tabela nova, sem coluna nova, sem módulo novo, sem cache, sem `behaviour`.** Uma migração de
índice e uma consulta reescrita.
