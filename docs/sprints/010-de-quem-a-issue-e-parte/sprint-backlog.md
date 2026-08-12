# Sprint 010 — de quem cada issue é parte

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [011 — de quem cada issue é parte](../../specs/011-de-quem-a-issue-e-parte/spec.md)
**Plano**: [plan.md](../../specs/011-de-quem-a-issue-e-parte/plan.md)
**Origem**: [#246](https://github.com/The-Band-Solution/theband/issues/246), pedida durante o sprint 009
**Análise**: rodada antes do código, **quatro correções** — duas delas requisitos **sem tarefa nenhuma**

## Objetivo do sprint

Ao fim deste sprint, a lista de issues de um repositório diz, em cada linha, **de quem aquela issue é
parte** — e diz **qual** relação é.

São **1 630** issues com pai e **2 899** sem. Das 1 666 relações, **293 violam a `sro.rule07`** e
**33** a rede de ontologias não nomeia. A coluna existe para não achatar isso numa palavra.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 39 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L08** | Sprint 002 | contrato antes da primeira função pública — `contracts/issue-parent.md` |
| **L18** | Sprint 003 | a aceitação avalia os 15 SC com evidência, nunca a suíte verde |
| **L20** | Sprint 003 | `order_by` determinístico em `list_parents/2`; é a lição que **achou** o defeito da `fetch_parent/2` |
| **L21** | Sprint 004 | F1 são consultas sem consumidor; a coluna está no mesmo sprint |
| **L22**, **L23** | Sprint 004 | gate por código de saída |
| **L25** | Sprint 004 | o número da issue **não identifica** — 57 vínculos têm pai em outro repositório |
| **L27** | Sprint 005 | ciclo completo antes do código — sexta feature seguida |
| **L28** | Sprint 005 | "a função devolve" e "a tela mostra" são afirmações diferentes: os testes vão ao HTML |
| **L30** | Sprint 005 | os números vêm do banco — e **pegaram um erro meu**: 1 666 é vínculo, não issue |
| **L32** | Sprint 006 | a tela não afirma o que não observou: o pai sem conceito é dito, não inventado |
| **L34** | Sprint 007 | **dois `nil` diferentes** — "não tem pai" e "pai sem conceito" — separados por cláusula |
| **L36** | Sprint 008 | quando duas medidas parecem se contradizer, o elo é hipótese |
| **L38** | Sprint 009 | o custo é medido pela **diferença** e pela **constância**, e `live/2` faz dois renders |

**A L30 pegou um erro dentro da própria spec.** A primeira versão escreveu "1 666 issues com pai" e
derivou 2 863 como complemento. 1 666 é a contagem de **vínculos**; as issues são **1 630**, e a
diferença de 36 são exatamente as issues com mais de um pai. Duas grandezas com nomes parecidos,
somadas sem conferir contra a origem — no documento que existe para medir.

**A L34 entra antes de doer, de novo.** Aqui a palavra perigosa é o `nil` do conceito do pai: em
`rule07/2` significa **não tem pai**, e na coluna significa **o pai não foi promovido**. Passar um
pelo outro faria a tela dizer *task without parent* sobre uma issue que tem pai.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não existe para este sprint** — limitação declarada desde o sprint 004. Configurar
iterations do ProjectV2 recria as existentes (L11), e já custou reatribuir 96 itens.

**Tipos**: a organização tem `Task`, `Bug` e `Feature`. Épico e user stories são tipados `Feature`.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Ver de quem a issue é parte, sem abrir a issue | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#249](https://github.com/The-Band-Solution/theband/issues/249) | P1 | 8 | a fazer |
| US2 | Saber qual relação é, e quando ela está errada | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#250](https://github.com/The-Band-Solution/theband/issues/250) | P1 | 8 | a fazer |
| US3 | Não ser enganado quando há mais de um pai | [#248](https://github.com/The-Band-Solution/theband/issues/248) | [#251](https://github.com/The-Band-Solution/theband/issues/251) | P2 | 8 | a fazer |

**US3 é P2 e entra igual.** São 36 issues de 1 630 — e é exatamente onde uma escolha silenciosa passa
despercebida. Deixá-la fora entregaria uma coluna que mente em 36 linhas.

## Tarefas

Detalhadas em [011/tasks.md](../../specs/011-de-quem-a-issue-e-parte/tasks.md). Cada tarefa é filha da
**user story que ela atende** — nunca do épico.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Nomear a relação do vínculo | US2 | [#252](https://github.com/The-Band-Solution/theband/issues/252) | 3 | F1 | a fazer |
| T002 | Buscar os pais em lote | US1 | [#253](https://github.com/The-Band-Solution/theband/issues/253) | 3 | F1 | a fazer |
| T003 | Mostrar o pai na linha | US1 | [#254](https://github.com/The-Band-Solution/theband/issues/254) | 5 | F2 | a fazer |
| T004 | Dizer qual relação é | US2 | [#255](https://github.com/The-Band-Solution/theband/issues/255) | 5 | F2 | a fazer |
| T005 | Nomear o repositório do pai | US3 | [#256](https://github.com/The-Band-Solution/theband/issues/256) | 3 | F2 | a fazer |
| T006 | Dizer que há mais de um pai | US3 | [#257](https://github.com/The-Band-Solution/theband/issues/257) | 3 | F2 | a fazer |
| T007 | Marcar o vínculo ausente | US2 | [#258](https://github.com/The-Band-Solution/theband/issues/258) | 3 | F3 | a fazer |
| T008 | Dizer pai sem conceito | US2 | [#259](https://github.com/The-Band-Solution/theband/issues/259) | 2 | F3 | a fazer |
| T009 | Medir o custo do render | US1 | [#260](https://github.com/The-Band-Solution/theband/issues/260) | 3 | F3 | a fazer |

**Total: 30 de complexity, nove tarefas.** Uma abaixo do sprint 009, e sem migração: a feature só lê.

## O que a análise mudou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | **FR-003 e SC-004 não tinham tarefa nenhuma.** Os textos da relação — `attends`, `composes` — não nomeiam o **conceito** do pai, e sem ele os 12 vínculos cujo pai é defeito ficariam sem nome. É a redução que o pedido original fazia e que a FR-003 existe para impedir | T003 mostra o conceito, e o teste monta o caso do pai defeito |
| **A2** | FR-016 e SC-011 estavam **sem asserção** | o teste de T003 exige não encontrado para repositório de outro tenant |
| **A3** | o teste de T002 citava `Ecto.Adapters.SQL.query_count/1`, que **não existe** | `contar_consultas/1`, por telemetria, que já existe em `person_detail_test.exs` |
| **A4** | T009 mediria **quatro** e reprovaria sem defeito nenhum: `live/2` faz **dois** renders | a diferença bruta é dividida por dois, como a feature 010 já faz |

**E o plano tinha achado três antes disso**, todas por medida: a contagem de vínculos confundida com
issues, a relação decidida pela dupla em vez do conceito da filha, e a segunda fronteira do nome do
repositório — a mesma que a análise da feature 010 achou no A1 dela.

## Os dois defeitos que a medida achou fora da feature

| # | O que é | Registro |
|---|---|---|
| 1 | `fetch_parent/2` com `limit: 1` **sem `order_by`** — pai arbitrário para as 36 issues com mais de um, e **esconde** que há outro | [#261](https://github.com/The-Band-Solution/theband/issues/261) |
| 2 | filha promovida a **defeito** não cai em `list_composition/2`, nem em `list_attendance/2`, nem em `list_unpromoted_parts/2` — **33 vínculos** invisíveis no detalhe do pai | [#262](https://github.com/The-Band-Solution/theband/issues/262) |

**Nenhum dos dois é corrigido neste sprint**: os dois são de outra tela. **Registrar é o que distingue
dívida de omissão.**

## Escopo confirmado

**Feature 011 completa — F1 a F3, T001 a T009.**

F1 são função e consulta sem consumidor, e a **L21** diz que isso não é funcionalidade entregue.

**O corte possível é por user story**: US1 sozinha — T002 e T003 — já entrega o pedido literal. O que
ela não entrega é a distinção entre as relações, e é aí que estão as 293 violações.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| dar `order_by` a `fetch_parent/2` | é a #261, e é outra tela |
| mostrar os 33 vínculos de defeito no detalhe do pai | é a #262, e é outra tela |
| corrigir as 293 violações na origem | a plataforma observa e avisa; corrigir é decisão do time |
| escolher qual pai vale, entre os 36 | a plataforma não decide isso pelo time |
| a linhagem completa na coluna | é outra pergunta — princípio X; o detalhe já responde |
| a mesma coluna em `/work` | a lista lá é do tenant inteiro, e a pergunta ali é outra |
| filtrar a lista por pai | não foi pedido |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **encher 2 091 células de aviso** chamando o axioma com pai nulo | `relacao/2` só é chamada quando há pai; o teste faz `refute` na célula da tarefa sem pai |
| dizer *task without parent* sobre issue que **tem** pai | a cláusula de `:pai_sem_conceito` vem antes; o teste separa os dois `nil` |
| chamar de composição o vínculo de defeito | FR-004a; o teste exige o texto de "não nomeada" nos 33 |
| `KeyError` em 2 899 linhas | `Map.get(pais, id, [])` — `list_parents/2` não cria chave para issue sem pai |
| pai arbitrário nas 36 | ordem `number, id`; o teste renderiza duas vezes e compara |
| `#12` apontar para a issue errada | o nome do repositório quando difere; 57 vínculos |
| consulta por linha | duas consultas, uma por fronteira; o teste mede diferença **e** constância |

**Nenhuma dependência de outra branch.** A `015-de-quem-a-issue-e-parte` sai de `main`, e não há
migração.

## Definition of Done do sprint

- [ ] `mix gates` verde pelo **código de saída** — dez gates
- [ ] V1 a V12 do [quickstart](../../specs/011-de-quem-a-issue-e-parte/quickstart.md) verificados
- [ ] **no dado real**: a lista de um repositório mostra pai, conceito e relação, com as 293 avisando
- [ ] a invariante conferida: atendimento + violação + composição + não nomeada = **1 666**
- [ ] as nove issues encerradas ou repriorizadas com justificativa
- [ ] PR com revisor pedido e **conferido** por `requested_reviewers` (L14), ligado ao projeto
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] `aceitacao.md` com os 15 SC avaliados um a um
- [ ] **a tela olhada em 360 px** — e não só asserida em HTML, que é a dívida que atravessou quatro
      sprints
