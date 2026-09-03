# Aceitação — Feature 005: regras de mapeamento por organização

Avaliação de cada critério de sucesso da [spec](../../../specs/005-regras-de-mapeamento/spec.md),
**um a um, com evidência**. É a L18: critério atendido não é critério suficiente, e suíte
verde não é evidência de que *este* critério passou.

**Data**: 2026-08-12 · **PRs**: [#182](https://github.com/The-Band-Solution/theband/pull/182)
e [#183](https://github.com/The-Band-Solution/theband/pull/183), **mesclados**

Dado real no momento da avaliação, depois do recálculo:

```
4474 issues · 4474 com conceito · 1023 high · 3451 low · 488 divergências
35 764 promoções acumuladas (append-only) · 0 regras cadastradas
```

---

| # | Critério | Veredito | Evidência |
|---|---|---|---|
| SC-001 | mapeados os tipos declarados, nenhuma issue com tipo permanece sem conceito | **aceito** | as 110 issues com tipo `Task` e as 186 `Bug` têm conceito; nenhuma issue com tipo declarado ficou sem |
| SC-002 | `começa com [TASK]` promove só quem começa, não quem contém | **aceito** | teste `começa com não é contém`, com o caso `"STATUS"` explícito |
| SC-003 | nenhuma issue com tipo declarado é classificada por regra de título | **aceito** | teste `tipo declarado vence regra de título`; a etapa 2 **não é alcançada** quando a 1 decide |
| SC-004 | 100% das promoções por regra registram regra, versão, fonte e confiança | **aceito** | SQL: 1023 `high` + 3451 `low`, e nenhuma linha nova sem `evidence_source` |
| SC-005 | promoção por título é distinguível da por tipo declarado | **aceito** | `evidence_source` e `confidence` em toda linha nova; a tela mostra os dois |
| SC-006 | nenhuma expressão inválida, que case vazio ou lenta é gravada | **aceito** | `pattern_validator_test.exs` — cada recusa é um caso, e o teste é a violação |
| SC-007 | a prévia mostra a mesma contagem que o recálculo produz | **aceito, com o significado corrigido** | ver abaixo |
| SC-008 | gravar regra não gera requisição à origem | **aceito por construção** | nenhuma função de `Mapping` chama `Client.graphql/4`; o recálculo roda sem a chave mestra, e foi assim que rodei no dado real |
| SC-009 | executar o recálculo duas vezes produz o mesmo resultado | **aceito, medido no dado real** | segunda execução: `gravadas 0` nas três organizações |
| SC-010 | a tela distingue padrão que é tipo de padrão que não é | **aceito** | duas listas separadas; teste recusa `[Devops]` entre as propostas |
| SC-011 | ativar proposta registra a pessoa, nunca "sistema" | **aceito** | teste `ativar registra a pessoa como autora`; `created_by_id` é *not null* |
| SC-012 | atualização do catálogo não sobrescreve edição | **aceito** | composição em leitura; teste confere que o YAML não muda ao editar a regra |
| SC-013 | a tela mostra quanto do total ainda não tem conceito | **aceito** | `gap_summary/2` no cabeçalho do componente |
| SC-014 | regra desativada para de valer e continua consultável | **aceito** | teste `desativar não apaga`; não existe `delete_rule` |
| SC-015 | a ordem entre regras é determinística e visível | **aceito** | índice único em `(organization_id, position)`; teste inverte a ordem e a decisão acompanha |
| SC-016 | um tenant não alcança regra de outro | **aceito** | teste devolve `:not_found` e **recusa** a palavra "permissão" |
| SC-017 | nenhuma medida soma inferência e declaração sem dizer | **aceito** | não existe consulta que agregue sem `evidence_source`; a tela sempre mostra a confiança |

**17 aceitos. Nenhum sem evidência.**

---

## SC-007, e por que o veredito tem ressalva

O critério diz que a prévia mostra a mesma contagem que o recálculo produz. Ele **pegou um
defeito real**: a prévia dizia 1 e o recálculo gravava 90, porque cada um tinha a sua
comparação de "mudou".

Depois de corrigido, a regra estrutural mudou o **significado** da pergunta. Hoje são dois
pares de números, e os dois batem:

| prévia | recálculo | o que mede |
|---|---|---|
| `would_change` | — | o efeito **da regra**: com ela contra sem ela |
| `rows_to_write` | `written` | o que a gravação produz contra o que está gravado |

A distinção não é preciosismo: sem ela, a prévia atribuiria à regra tudo o que a etapa
estrutural decide — e a estrutura decidiria de todo modo. Dois testes mediam o antigo e foram
reescritos.

---

## O que a feature entregou, e o que ela **não** decidiu

**A tela existe e nenhuma regra foi cadastrada.** Isso não é falha: as 4474 issues ganharam
conceito pela **estrutura**, que não exige regra. O catálogo continua proposto, e a decisão de
ativar é de quem administra.

O número que importa não é "100% classificado" — é a proporção:

```
1023 por evidência forte (tipo declarado)
3451 pela mais fraca (estrutura)
```

E as **488 divergências** são o outro lado disso: user stories que o time declarou e que, pela
estrutura sozinha, seriam tarefas. Elas continuam user stories, com o aviso visível.

---

## Os dois defeitos que a conferência com a origem achou

Nenhum apareceu na suíte. Os dois apareceram ao comparar um número da plataforma com a origem.

**899 issues fora de toda coleta.** 38 repositórios marcados inacessíveis por um `:nxdomain`, e
a marca era permanente na prática. Corrigido nas duas pontas: transitório não marca, e a coleta
que alcança limpa.

**488 divergências calculadas e não gravadas.** `mudou_registro?/2` não comparava a
divergência. A tela mostrava zero, e quem lesse concluiria que nada diverge.

---

## Verificação dos gates

```text
mix gates → 9 gates verdes        (código de saída 0, não o texto — L22)
mix test  → 341 passed            (218 no início do sprint)
CI        → quality-gates SUCCESS nos dois PRs
```

## O que **não** foi verificado, e é declarado

| Item | Por quê |
|---|---|
| a tela com regra cadastrada, no dado real | nenhuma regra foi criada; a tela foi exercitada por teste de LiveView |
| limite de tempo da regex sobre 4474 títulos reais | medido sobre amostra de 200; o limite é por expressão, não por lote |
| revisão independente por outro agente | a constituição exige, e esta sessão não invoca agente sem pedido explícito — **lacuna declarada**, nunca marcada como cumprida |
