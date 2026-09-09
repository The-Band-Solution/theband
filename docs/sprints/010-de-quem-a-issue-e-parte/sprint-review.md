# Sprint 010 — Review

**Período**: 2026-08-12 · **Feature**: [011 — de quem cada issue é parte](../../../specs/011-de-quem-a-issue-e-parte/spec.md)
**Aceitação**: [aceitacao.md](../../../specs/011-de-quem-a-issue-e-parte/aceitacao.md) — **12 de 13** critérios

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 9 | 9 |
| Entregáveis aceitos | 9 | 9 |
| Critérios de sucesso | 13 | 12 |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#252](https://github.com/The-Band-Solution/theband/issues/252) | `Axioms.relacao/2` — cinco respostas, chamando `rule07/2` | sim |
| T002 | [#253](https://github.com/The-Band-Solution/theband/issues/253) | `WorkItems.list_parents/2` — uma consulta, todos os pais, ordem determinística | sim |
| T003 | [#254](https://github.com/The-Band-Solution/theband/issues/254) | a coluna `part of`, com o **conceito** do pai e a ausência nomeada | sim |
| T004 | [#255](https://github.com/The-Band-Solution/theband/issues/255) | os cinco textos em `ConceptLabel.relacao/1` | sim |
| T005 | [#256](https://github.com/The-Band-Solution/theband/issues/256) | o nome do repositório do pai, só quando difere | sim |
| T006 | [#257](https://github.com/The-Band-Solution/theband/issues/257) | mais de um pai dito, contando só o vigente | sim |
| T007 | [#258](https://github.com/The-Band-Solution/theband/issues/258) | vínculo ausente tracejado, com a data | sim |
| T008 | [#259](https://github.com/The-Band-Solution/theband/issues/259) | pai sem conceito dito, sem inventar | sim |
| T009 | [#260](https://github.com/The-Band-Solution/theband/issues/260) | o custo medido: 10 antes, **12** depois, e constante | sim |

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| a tela olhada em **360 px** | precisa de navegador e de olho humano | pessoa mantenedora, e é o **quinto** sprint com este item |
| a coluna vista **no dado real** | a plataforma sobe com a chave mestra, que eu não peço nem recebo | pessoa mantenedora |

**Nenhuma tarefa ficou de fora.** As duas linhas acima são verificação, não implementação.

## Evidências

```
mix gates → 10 gates verdes, 497 testes, veredito por código de saída
```

A invariante no dado real:

```
atendimento 1 143 · violação 293 · composição 197 · não nomeada 33  =  1 666 vínculos
```

O custo, medido contra `main` em 2026-08-12: a página fazia **10** consultas por render e passa a
fazer **12** — duas, uma por fronteira. Página de 2 issues e página de 50: **igual**.

## Dívida gerada

| Dívida | O que é |
|---|---|
| `list_parents/2` e `fetch_parent/2` coexistem | duas funções para a mesma relação, vista de baixo. A nova devolve todos os pais; a antiga escolhe um sem ordem, e é a #261 |
| a coluna não diz a **linhagem** | mostra o pai, não o avô. É decisão do princípio X, e vira dívida se alguém pedir a cadeia |

## Os três defeitos achados fora da feature

| # | O que é | Registro |
|---|---|---|
| 1 | `fetch_parent/2` com `limit: 1` **sem `order_by`** — pai arbitrário nas 36, e esconde que há outro | [#261](https://github.com/The-Band-Solution/theband/issues/261) |
| 2 | filha promovida a **defeito** fora das três listas do detalhe do pai — **33** vínculos invisíveis | [#262](https://github.com/The-Band-Solution/theband/issues/262) |
| 3 | vínculo de decomposição **nunca** marcado como ausente — a coluna sabe exibir, o dado nunca chega | [#263](https://github.com/The-Band-Solution/theband/issues/263) |

**Os três nasceram de medir para escrever a spec**, não de rodar teste. Nenhum deles produz erro:
todos produzem tela que parece completa.

## O que a fase de análise achou, e vale contar de novo

**Quinta feature seguida em que a análise achou defeito antes do código.** Desta vez foram quatro, e
**duas eram requisitos sem tarefa nenhuma**:

| # | Achado |
|---|---|
| A1 | **FR-003 e SC-004 sem cobertura**: `attends` e `composes` não nomeiam o **conceito** do pai, e sem ele os 12 vínculos com pai defeito ficariam sem nome — a redução que o pedido original fazia |
| A2 | FR-016 e SC-011 **sem asserção** de tenant |
| A3 | o teste citava `Ecto.Adapters.SQL.query_count/1`, que **não existe** |
| A4 | T009 mediria **quatro** e reprovaria sem defeito: `live/2` faz dois renders |

E o plano, antes disso, achou três — todas por medida: vínculo confundido com issue, a relação
decidida pela dupla em vez do conceito da filha, e a segunda fronteira do nome do repositório.

## Lições deste sprint

Quatro, e as quatro são acionáveis. Rascunho consolidado em
[licoes-aprendidas.md](../licoes-aprendidas.md) como **L40 a L43**.

1. **Duas grandezas com nomes parecidos, e o complemento derivado de uma delas.** Contei 1 666
   vínculos, chamei de issues e derivei "2 863 sem pai" por subtração. As issues eram 1 630 e a
   diferença — 36 — era o próprio caso de borda da feature. → **L40**
2. **O teste que compara uma coisa com ela mesma passa sempre.** A constância do custo comparava a
   mesma página duas vezes: igualdade garantida, medida nenhuma. → **L41**
3. **Mensagem atrasada de telemetria entra na contagem seguinte.** Um 22 apareceu onde a página faz
   20, e eu quase escrevi uma explicação para o 22. → **L42**
4. **Quando o axioma responde a pergunta errada, o erro não é no axioma.** `rule07/2` trata "tarefa
   sem pai" como violação, e chamá-lo com pai nulo encheria 2 091 células de aviso. A correção foi a
   **precondição**, não um filtro sobre a resposta dele. → **L43**
