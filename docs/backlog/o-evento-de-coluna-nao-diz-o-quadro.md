# O evento de mudança de coluna não diz de qual quadro

**Registrado em 2026-09-16**, depois da recoleta da timeline (PR #924). A origem
**oferece** o campo, e a consulta não o pede — é a terceira vez que este repositório
constrói sobre uma limitação que nunca foi verificada.

---

## O que acontece

`ProjectV2ItemStatusChangedEvent` é o evento que diz *"este cartão foi para a coluna X"*.
A consulta `issues.graphql` pede dele:

```graphql
... on ProjectV2ItemStatusChangedEvent { id createdAt actor { login } previousStatus status }
```

`status` é o **nome da coluna**, e só. O evento gravado não guarda de que quadro ele veio.

## Por que isso importa, medido

No quadro 43 (Conecta Fapes) há **377 cartões na coluna Done cuja issue está aberta na
origem**. Depois da recoleta, todos os 377 têm um evento de chegada a `Done` — antes da
recoleta, nenhum tinha.

Só que **235 dessas 377 issues estão em dois quadros ao mesmo tempo**, e as outras 142 em
um só. Para essas 235, o evento de chegada a `Done` que encontramos pode ser do outro
quadro: os dois têm coluna chamada `Done`, e o evento não distingue.

| | |
|---|---|
| cartões Done + issue aberta, no quadro 43 | 377 |
| com evento de chegada a Done, após a recoleta | 377 |
| dessas, em **um** quadro — atribuição certa | 142 |
| dessas, em **dois** quadros — atribuição ambígua | 235 |

A medida por mês fica com a mesma ressalva. Ela hoje diz: abril 11, maio 82, junho 39,
julho 240, agosto 5.

## Uma issue pode ter mais de uma conclusão, e isso é legítimo

Levantado pela pessoa mantenedora em 2026-09-16, e medido em seguida. Uma issue em dois
quadros pode chegar a `Done` nos dois, em datas diferentes — são duas conclusões
verdadeiras, e não uma duplicata. Hoje elas se somam numa contagem só.

Das 3 091 issues com chegada a `Done`, 191 têm mais de uma:

| chegadas a Done | issues | dias entre a primeira e a última (média / máximo) |
|---|---|---|
| 1 | 2 900 | — |
| 2 | 179 | 48,6 / 342 |
| 3 | 12 | 31,6 / 155 |

**A causa dominante não é o segundo quadro — é o retorno.** Cruzando com o número de
quadros de cada issue:

| quadros | chegadas a Done | issues |
|---|---|---|
| 1 | 1 | 1 793 |
| 1 | 2 | 144 |
| 1 | 3 | 7 |
| 2 | 1 | **286** |
| 2 | 2 | 13 |
| 2 | 3 | 2 |

151 issues têm várias conclusões num quadro só: o cartão foi a `Done`, voltou, e foi de
novo. Isso é pergunta do critério de fim (066), não deste item.

**As 286 são o problema deste item.** Estão em dois quadros e têm **uma** chegada a
`Done`. Essa chegada é de um dos dois, e a plataforma credita aos dois.

## O erro que isso já produz, medido

No quadro 43, cartões que **não** estão em `Done` e mesmo assim carregam um evento de
chegada a `Done`:

| coluna no quadro 43 | cartões | com evento de Done |
|---|---|---|
| In Validation | 37 | 16 |
| Homologation | 279 | 13 |
| In Progress | 25 | 7 |
| To Do | 32 | 5 |
| Backlog | 73 | 3 |
| Paused | 15 | 1 |
| Desaprovado | 8 | 1 |

São 46 cartões. Cada um admite duas leituras que os dados não separam: o cartão foi a
`Done` neste quadro e voltou, ou a conclusão é do outro quadro e nunca aconteceu aqui. A
primeira é histórico; a segunda é entrega creditada que não existiu.

## A origem dá o campo

Introspecção feita em 2026-09-16 contra a API do GitHub:

```
campos de ProjectV2ItemStatusChangedEvent:
  actor, createdAt, id, previousStatus, project, status, wasAutomated
```

`project` é um `ProjectV2`. Pedir `project { id number title }` resolve a ambiguidade na
raiz — não há heurística a inventar.

## O que fazer

1. acrescentar `project { id number }` ao fragmento em `priv/connectors/github/queries/issues.graphql`;
2. gravar o quadro junto da ocorrência — provavelmente em `payload`, já que a atividade
   não tem coluna para isso, e decidir se merece coluna própria é parte do item;
3. incrementar a versão da fase `issues` em `QueryVersion` — é campo novo, e sem o
   incremento o corte incremental nunca revisita o histórico;
4. **recolher de novo.** O custo medido da recoleta completa do `conectafapes-project`
   foram 299 pontos de cota para 2 665 issues. A base inteira deve ficar na ordem de mil;
5. refazer a medida das 377 com o quadro certo, e comparar com a de hoje.

O passo 4 é o que torna este item caro, e é por isso que ele não entrou no PR #924.

## Por que isto reincide

É o mesmo defeito do identificador do evento, corrigido no mesmo PR: a consulta não pedia
`id` porque um comentário afirmava que *"a timeline do GitHub não dá identificador ao
evento"*. Ninguém tinha perguntado. Aqui ninguém perguntou tampouco.

**A regra que falta:** ao escrever que a origem não oferece alguma coisa, colar a consulta
de introspecção junto, com data. Comentário antigo não é evidência.
