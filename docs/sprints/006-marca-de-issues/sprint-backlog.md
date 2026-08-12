# Sprint 006 — a marca de trabalho no repositório

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [007 — marca de issues](../../specs/007-marca-de-issues/spec.md)
**Plano**: [plan.md](../../specs/007-marca-de-issues/plan.md) ·
**Análise**: rodada antes do código, seis correções aplicadas

## Objetivo do sprint

Ao fim deste sprint, quem abre `/work` sabe **onde há trabalho sem ler nenhum número** — e a
tela nunca afirma coleta que não houve.

70% das 135 linhas não têm trabalho a mostrar. Hoje descobrir isso exige percorrer 135
contagens; a marca responde de relance, com forma, texto e rótulo acessível.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 31 lições. As que entram como **restrição**
deste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L08** | Sprint 002 | contrato de API escrito **antes** da primeira função pública — [contracts/repository-work-mark.md](../../specs/007-marca-de-issues/contracts/repository-work-mark.md), commitado antes de qualquer código |
| **L11** | Sprint 002 | **não** vou tocar a configuração de iterations. Ver "Sprint no GitHub" |
| **L18** | Sprint 003 | critério atendido não é suficiente: a aceitação avalia cada um dos 11 SC com evidência, nunca a suíte verde |
| **L21** | Sprint 004 | nada de função pública sem consumidor visível: a consulta agrupada de F1 só é entregue com a marca de F3 na mesma fatia |
| **L22**, **L23** | Sprint 004 | gate conferido por **código de saída**, `mix gates`, sem `\| tail`; aviso de verificação pulada é reprovação |
| **L27** | Sprint 005 | ciclo completo antes do código — spec, checklist, pesquisa, plano, data-model, contrato, quickstart, tarefas e **análise**. É a segunda feature a cumprir isto na ordem, e a primeira em que a análise achou defeito de desenho |
| **L28** | Sprint 005 | "calcula" e "está gravado" são afirmações diferentes: T004 tem teste que confere a data **no banco**, não só a chamada |
| **L29** | Sprint 005 | repositório inacessível **não** recebe a data, e a ausência dela é informação — não estado permanente que tira dado de circulação. A coleta que alcançar grava |
| **L30** | Sprint 005 | V9 mede os 41 repositórios **no dado real**, com SQL contra o banco, e não só na suíte |
| **L31** | Sprint 005 | T002 muda o significado da coluna de contagem — de todas para vigentes. A mudança está declarada em R3 e no plano, e não foi resolvida ajustando número esperado |

**A L27 é a que este sprint verifica de verdade.** Ela diz que decisão de desenho examinada
depois do código já foi tomada. Aqui a análise rodou antes e achou o defeito A1 — a marca
decidindo pela data antes da contagem, o que faria a tela mentir sobre 41 repositórios. Nenhum
teste de unidade pegaria: cada peça funciona. A pergunta que pegou foi *o que a tela diz no dia
da migração?*, e ela só existe porque houve fase de análise.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não existe para este sprint**, e é limitação declarada — não esquecimento.

O campo `Iteration` tem uma única iteração (`Sprint 002 — Escopo por organização`, 2026-08-10).
Os sprints 003, 004, 005 e agora o 006 rodam sem iteração própria pelo mesmo motivo:
**configurar iterations do ProjectV2 recria as existentes** — é a L11, e ela custou reatribuir 96
itens.

Consequência aceita: `flow.throughput` e `flow.wip.count` não separam 003 a 006 por iteração.

**Tipos de issue**: a organização tem `Task`, `Bug` e `Feature` habilitados, e **não** tem `Epic`
nem `User Story`. Épico e user story são tipados `Feature`, como nos sprints anteriores. Criar
tipo altera a configuração da organização, e a decisão é da pessoa mantenedora — segue no product
backlog. A hierarquia carrega o que o tipo não carrega, e é dela que a regra de roteamento decide:
`Feature` com sub-issues `Feature` é épico; `Feature` cujas filhas são `Task` é user story
atômica.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Achar onde há trabalho, sem ler número | [#185](https://github.com/The-Band-Solution/theband/issues/185) | [#186](https://github.com/The-Band-Solution/theband/issues/186) | P1 | 17 | feito |
| US2 | Ir do repositório para as issues dele | [#185](https://github.com/The-Band-Solution/theband/issues/185) | [#187](https://github.com/The-Band-Solution/theband/issues/187) | P1 | 1 | feito |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a *complexity* —
dificuldade para o time. Campo em branco significa **desconhecido**, nunca zero.

**US2 tem complexity 1 porque a navegação já existe** desde a feature 006. O que ela pede é
garantia: os 94 repositórios sem trabalho **continuam** clicáveis, porque a tela deles explica
por que estão vazios.

## Tarefas

Detalhadas em [007/tasks.md](../../specs/007-marca-de-issues/tasks.md). Cada tarefa é filha da
**user story que ela atende** — nunca do épico: tarefa sob épico viola `sro.rule07`, e é o aviso
que a própria feature 006 passou a mostrar.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Contar issues por repositório numa consulta | US1 | [#188](https://github.com/The-Band-Solution/theband/issues/188) | 3 | F1 | feito |
| T002 | Trocar as 135 consultas por uma | US1 | [#189](https://github.com/The-Band-Solution/theband/issues/189) | 2 | F1 | feito |
| T003 | Registrar quando as issues foram coletadas | US1 | [#190](https://github.com/The-Band-Solution/theband/issues/190) | 2 | F2 | feito |
| T004 | Gravar a data no fim da fase de issues | US1 | [#191](https://github.com/The-Band-Solution/theband/issues/191) | 3 | F2 | feito |
| T005 | Exibir a marca com três canais | US1 | [#192](https://github.com/The-Band-Solution/theband/issues/192) | 5 | F3 | feito |
| T006 | Dizer que houve trabalho e não há vigente | US1 | [#193](https://github.com/The-Band-Solution/theband/issues/193) | 2 | F3 | feito |
| T007 | Manter todo repositório clicável | US2 | [#194](https://github.com/The-Band-Solution/theband/issues/194) | 1 | F3 | feito |

Tarefa não recebe `Priority`: herda a da user story que atende. Duas fontes divergiriam, e a
divergência não teria como ser resolvida.

**Total: 18 de complexity, sete tarefas.** É o sprint mais pequeno até aqui, e é de propósito: a
feature acrescenta uma coluna, uma consulta e cerca de 15 linhas de markup.

## O critério que a análise acrescentou, e é o mais importante do sprint

**Depois da migração de T003, todos os 135 repositórios têm `issues_collected_at` nulo** — nenhuma
coleta anterior registrou a data. E **41 deles têm issues vigentes**, um com 2 514.

Se a marca decidir pela data antes da contagem, a tela diz `no collection recorded` sobre esses 41.
Não é lacuna: é a plataforma **afirmando** que nunca olhou um repositório de que ela tem 2 514
issues coletadas. A ordem é fixa:

```
contagem > 0                → cheia,     "N issues"
contagem 0 e data presente  → vazia,     "collected, no issues"
contagem 0 e data nula      → tracejada, "no collection recorded"
```

Está em FR-005a, na descrição de T005, no contrato, em SC-008, e é medido por V9 contra o banco.

## Escopo confirmado

**Feature 007 completa — F1 a F3, T001 a T007.** É o MVP, e a análise corrigiu isto: a versão
anterior do plano dizia F1+F3, e sem a coluna de F2 a marca diria `collected, no issues` sobre 94
repositórios de que **não há registro de coleta** — afirmando coleta que ela não tem como provar.

**Afirmação falsa não é MVP — é defeito com menos código.**

O único corte que produz estado honesto é **F1 sozinha**: 135 consultas viram 1, a tela fica mais
rápida, e nada muda visivelmente.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| ordenar ou filtrar a lista por trabalho | não foi pedido; a marca resolve a varredura |
| marca na tela de sincronização | lá o repositório é fase de execução — FR-013 |
| a marca dizer o estado de observação | a coluna `state` já diz — FR-004 |
| componente `<.work_mark>` | um chamador só; o segundo justifica — R1 |
| contagem que muda com a tela aberta | a tela não é ao vivo; recarregar resolve — caso de borda 4 |
| criar os tipos `Epic` e `User Story` na organização | altera configuração da organização; decisão da pessoa mantenedora |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **a marca decidir pela data antes da contagem** | ordem em FR-005a; V9 mede os 41 no dado real; teste que dá issues sem data e exige `N issues` |
| gravar a data para uns repositórios e não outros | gravar no **mesmo ponto** do checkpoint; teste exige os dois juntos |
| `{:error, :not_found}` derrubar a fase de coleta | T004 registra em log e segue; teste exclui o repositório antes de marcar |
| coluna e marca discordarem | uma consulta, um mapa, dois leitores — FR-010, SC-007 |
| marca só por cor | forma e texto obrigatórios; teste remove a cor |
| a troca para "vigentes" mudar número em silêncio | no dado real nenhuma issue é não vigente; a mudança está declarada em R3 |

**Dependência de branch**: esta feature usa o design system e o `stacked`, que vivem na branch
`007-interface-em-ingles` — [PR #184](https://github.com/The-Band-Solution/theband/pull/184),
**aguardando revisão humana**. A branch desta feature é `008-marca-de-issues` e sai de lá; se o
#184 não for incorporado, este trabalho vai junto com ele.

O número da branch difere do diretório da spec de propósito, e está explicado em R5 da pesquisa.

## Definition of Done do sprint

- [x] `mix gates` verde pelo **código de saída** — dez gates, em `main` (`277d159`)
- [x] base de conhecimento válida, com o validador Python de fato executado — 96 artefatos
- [x] V1 a V9 verificados, **menos V7** (360 px): SC-009 declarado **não verificado** na aceitação
- [x] V9 medido **no dado real**: os 41 aparecem com trabalho; o maior tem 2 514 issues e nenhuma data
- [x] as sete issues encerradas
- [x] PR [#195](https://github.com/The-Band-Solution/theband/pull/195) com revisor `the-band` **conferido** por `requested_reviewers`, ligado ao projeto
- [x] [`sprint-review.md`](sprint-review.md) escrito, separando feito de não feito
- [x] `licoes-aprendidas.md` atualizado — L32 e L33
- [x] [`aceitacao.md`](../../specs/007-marca-de-issues/aceitacao.md) — 11 SC avaliados um a um
