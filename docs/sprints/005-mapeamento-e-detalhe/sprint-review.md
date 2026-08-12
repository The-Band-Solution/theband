# Sprint 005 — Review

**Período**: 2026-08-11 a 2026-08-12
**Features**: [005 — regras de mapeamento](../../specs/005-regras-de-mapeamento/spec.md) ·
[006 — detalhe da issue](../../specs/006-detalhe-da-issue/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Features | 2 | 2 |
| User stories | 8 | 8 |
| Tarefas | 25 (005) + 20 (006) | 45 |
| Testes | — | 218 → **341** |
| Entregáveis aceitos | — | 30 critérios de 30 |

Três PRs mesclados: [#149](https://github.com/The-Band-Solution/theband/pull/149) (006),
[#182](https://github.com/The-Band-Solution/theband/pull/182) e
[#183](https://github.com/The-Band-Solution/theband/pull/183) (005).

## O que foi feito

### Feature 006 — detalhe da issue

| US | Issue | Entregável | Aceito |
|---|---|---|---|
| US1 | [#145](https://github.com/The-Band-Solution/theband/issues/145) | 9 campos novos coletados; corpo, autor, designados, rótulos, marco, quadros | sim |
| US2 | [#146](https://github.com/The-Band-Solution/theband/issues/146) | composição e atendimento em seções separadas, **nunca somadas** | sim |
| US3 | [#147](https://github.com/The-Band-Solution/theband/issues/147) | `sro.rule07` como função pura, usada pelos dois caminhos | sim |
| US4 | [#148](https://github.com/The-Band-Solution/theband/issues/148) | tela do repositório com contagem que soma o total | sim |

Aceitação em [aceitacao.md](aceitacao.md): 12 aceitos, 1 parcial, nenhum sem evidência.

### Feature 005 — regras de mapeamento

| US | Issue | Entregável | Aceito |
|---|---|---|---|
| US1 | [#140](https://github.com/The-Band-Solution/theband/issues/140) | catálogo composto em leitura, ativação com autoria | sim |
| US2 | [#141](https://github.com/The-Band-Solution/theband/issues/141) | regra por tipo declarado, com validação e prévia | sim |
| US3 | [#142](https://github.com/The-Band-Solution/theband/issues/142) | regra por título, com confiança menor | sim |
| US4 | [#143](https://github.com/The-Band-Solution/theband/issues/143) | declarar que um padrão **não** é tipo, reversível | sim |

Aceitação em [aceitacao-005.md](aceitacao-005.md): 17 de 17, nenhum sem evidência.

### Fora do plano, e entregue

Quatro coisas entraram durante o sprint, pedidas pela pessoa mantenedora ou descobertas ao
conferir número contra a origem:

| O quê | Por que entrou |
|---|---|
| **classificação por estrutura** | regra nova: folha é tarefa, quem tem US é épico |
| **`divergence_kind`** | a frase explicava e não deixava contar |
| **cartão de execução reorganizado** | barras lado a lado insinuavam comparação que não existe |
| **dois defeitos de coleta** | 899 issues fora de observação; 488 divergências não gravadas |

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| iteração do sprint no Projects v2 | configurar recria as existentes — L11, 96 itens | [#176](https://github.com/The-Band-Solution/theband/issues/176) |
| revisão independente por agente | a sessão não invoca agente sem pedido explícito | **lacuna declarada** |
| defeito do sync travado em `running` | subiu de prioridade com o worker novo, e não coube | [#175](https://github.com/The-Band-Solution/theband/issues/175) |
| ressincronizar com a chave | depende de quem tem a chave | próxima sessão |

## Entregáveis não aceitos

**Nenhum.** Os 30 critérios das duas features foram avaliados um a um e todos têm evidência.

Dois foram aceitos **com ressalva escrita**: SC-013 da 006 (idempotência campo a campo entre
duas coletas reais não medida) e SC-007 da 005 (o significado de "a mesma contagem" mudou com a
regra estrutural, e o documento diz qual é hoje).

## Evidências

```text
mix gates → 9 gates verdes            (código de saída 0)
mix test  → 341 passed                (218 no início)
CI        → SUCCESS nos três PRs
```

Recálculo executado no dado real:

```text
4474 issues · 4474 com conceito · 1023 high · 3451 low · 488 divergências
2,1s para 4280 issues; segunda execução grava zero
```

## Dívida gerada

| O quê | Por que foi aceita |
|---|---|
| 3451 issues classificadas por evidência `low` | a alternativa era 77% sem conceito; a confiança está gravada em cada linha |
| a tela de regras nunca usada no dado real | nenhuma regra foi cadastrada — a estrutura resolveu sem regra |
| `promoções` cresceram para 35 764 linhas | append-only é a escolha; o custo aparece se a leitura ficar lenta |
| substituição que apaga designado e rótulo | R3 da pesquisa, com critério de reversão escrito |

## Lições deste sprint

Quatro, e três são o mesmo defeito com roupas diferentes: **o número que a plataforma mostra
não é o número que ela tem.**

- **L28** — calcular e não gravar é pior que não calcular
- **L29** — falha transitória que marca estado permanente tira dado de circulação em silêncio
- **L30** — conferir o número contra a origem acha o que a suíte não acha
- **L31** — regra nova muda o significado de teste que passava

Consolidadas em [licoes-aprendidas.md](../licoes-aprendidas.md).
