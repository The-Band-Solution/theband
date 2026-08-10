# Sprint 002 — Escopo por organização

**Período**: 2026-08-24 a 2026-09-06 (14 dias)
**Feature**: [002-escopo-por-organizacao](../../specs/002-escopo-por-organizacao/spec.md)
**Plano**: [plan.md](../../specs/002-escopo-por-organizacao/plan.md)
**Análise ontológica**: [ontology-analysis.md](../../specs/002-escopo-por-organizacao/ontology-analysis.md)

## Objetivo do sprint

Cada pessoa e cada equipe passam a dizer de qual organização vieram, e o esquema
volta a corresponder ao modelo derivado da ontologia.

## O sprint 001 continua aberto

Registrado aqui em vez de omitido: **os entregáveis do sprint 001 não foram
aceitos.** A revisão independente que a constituição exige no princípio VII não
foi obtida, e quem implementou não pode assiná-la.

Consequências concretas para este sprint:

- as 77 issues do sprint 001 permanecem abertas, e continuam atribuídas à
  iteration dele;
- a feature 001 está em `feature/001-github-eo-ingestion`, sem merge;
- este sprint parte desse código mesmo assim, porque a correção que ele faz **é
  de um defeito da 001** — esperar o merge para corrigir manteria o defeito em
  produção por mais um ciclo.

Se a revisão independente reprovar algo da 001, este sprint herda o retrabalho.
É risco aceito, e está na seção de riscos.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md) — dez lições, L01 a L10.
Quatro se aplicam diretamente:

| Lição | O que muda neste sprint |
|---|---|
| **L03** — teste com dado inválido acha o que o caminho feliz esconde | Três tarefas têm o teste escrito como **violação**: T016 (um tenant pede a organização do outro), T007 (equipe organizacional sem organização) e T022 (derivada gravada como observada). É o que a L03 mandou fazer |
| **L08** — contrato escrito junto com o código descreve, não decide | Os **quatro contratos foram escritos antes** de qualquer código, e cada tarefa que cria API pública tem "o contrato existe" no `Pronta quando` |
| **L09** — um contrato pode contradizer a si mesmo | O contrato de reprocessamento da 001 se contradizia e só a implementação revelou. Aqui, cláusula inalcançável durante a implementação será tratada como **sintoma de contrato errado**, não como código a apagar |
| **L02** — servidor no ar duplica o efeito de job disparado por script | O retrofito (T011) roda por Oban. Nenhuma verificação vai chamar `perform/1` à mão com o servidor no ar |

As demais foram consideradas e não se aplicam: L01 (não há gerador nesta
feature), L04 (nenhuma consulta nova ao GitHub), L05 e L07 (correções já
incorporadas), L06 (disciplina de caminho absoluto, já em uso), L10 (não há
rotação de chave aqui).

## Sprint no GitHub

**Iteration**: Sprint 002 — Escopo por organização · 2026-08-24 a 2026-09-06 · 14 dias
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Ocorrência registrada.** Ao criar a iteration do sprint 002, a API do
ProjectV2 recriou a do sprint 001 com identificador novo, e os 77 itens dele
ficaram órfãos — `updateProjectV2Field` substitui o conjunto de iterations e não
aceita `id` nas existentes. Os itens foram reatribuídos, e no caminho 10 itens de
**outros repositórios** (`eo_lib`, `theband-frontend`, `theband-backend` e um
pull request) foram atribuídos por engano ao sprint 001 e depois limpos. Estado
conferido: 77 itens no sprint 001, 9 no sprint 002, e os alheios sem iteration,
como estavam. Vira lição.

## Escopo — 9 issues em vez de 27

Decisão da pessoa mantenedora: ser mais econômico que na feature 001, onde foram
77 issues. As 27 tarefas do `tasks.md` vivem como **checklist no corpo** de cada
issue, então a granularidade não se perde e o progresso continua visível.

### Épico

| Issue | Título |
|---|---|
| [#79](https://github.com/The-Band-Solution/theband/issues/79) | Pessoas e equipes separadas por organização observada |

### User stories

| # | User story | Tipo | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|
| US1 | Saber de qual organização veio cada registro | Feature | [#80](https://github.com/The-Band-Solution/theband/issues/80) | P0 | — | 5 cenários |
| US2 | Consultar uma organização de cada vez | Feature | [#81](https://github.com/The-Band-Solution/theband/issues/81) | P1 | — | 5 cenários |
| US3 | Enxergar quem atravessa organizações | Feature | [#82](https://github.com/The-Band-Solution/theband/issues/82) | P2 | — | 3 cenários |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a
*complexity*, e está **em branco de propósito**: nenhuma estimativa foi feita com
o time, e preencher com número inventado produziria métrica de fluxo apoiada em
ficção. Campo em branco significa desconhecido, não zero.

A escala do projeto é P0/P1/P2 e a da spec é P1/P2/P3 — o mapeamento preserva a
**ordem**, não o rótulo. Ler "P0" como "a mais importante das três".

### Tarefas

| # | Tarefa | Atende | Tipo | Issue | Tarefas do `tasks.md` | Estado |
|---|---|---|---|---|---|---|
| F1 | Declarar o vínculo na ontologia | épico | Task | [#83](https://github.com/The-Band-Solution/theband/issues/83) | T001–T003 | a fazer |
| F2 | Gerar chave estrangeira a partir de associação | épico | Task | [#84](https://github.com/The-Band-Solution/theband/issues/84) | T004 | a fazer |
| F3 | Corrigir o esquema escrito à mão | épico | Task | [#85](https://github.com/The-Band-Solution/theband/issues/85) | T005–T008 | a fazer |
| — | Tarefas da US1 | US1 | checklist em #80 | — | T009–T012 | a fazer |
| — | Tarefas da US2 | US2 | checklist em #81 | — | T013–T017 | a fazer |
| — | Tarefas da US3 | US3 | checklist em #82 | — | T018–T019 | a fazer |
| F7 | Criar a equipe derivada | épico | Task | [#86](https://github.com/The-Band-Solution/theband/issues/86) | T020–T024 | a fazer |
| F8 | Fechar a feature | épico | Task | [#87](https://github.com/The-Band-Solution/theband/issues/87) | T025–T027 | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## A ordem não é negociável

```text
F1 Ontologia → F2 Transformação → F3 Esquema → US1 → US2 → US3
                                        └────→ F7 Equipe derivada → F8
```

A cadeia das três primeiras é rígida, e é a lição do achado F1 da análise:
**coluna escrita antes de a relação existir** foi exatamente o erro que criou
este trabalho. Nenhuma tarefa que dependa de `eo_teams.organization_id` começa
antes de a derivação produzi-la.

## MVP

**F1, F2, F3, US1 e F7.** A equipe derivada não é opcional no MVP, e a primeira
versão do `tasks.md` errava ao dizer que podia ficar para depois.

A razão é o critério SC-003a: nenhuma pessoa conhecida pode ficar sem
organização. Sem a equipe derivada, as 18 pessoas que não estão em equipe alguma
continuam sem — inclusive as 5 de `ifesserra-lab`, que não tem nenhum time.
Entregar sem ela corrigiria o defeito para 54 das 72 pessoas e o manteria para as
outras 18, sem a tela dizer por quê.

## Fora do escopo deste sprint

| O quê | Por quê |
|---|---|
| Papéis organizacionais | o vínculo segue sendo evidência; promovê-lo a alocação é feature própria |
| Reconciliação de identidade | duas contas da mesma pessoa continuam dois registros |
| Medidas por organização | o vínculo passa a existir; as medidas vêm depois |
| Hierarquia entre organizações observadas | `parent_organization_id` existe e nada a preenche |
| Vínculo de `eo.project_team` com projeto | achado F8 da análise; o destino é SPO e a direção de dependência precisa ser conferida antes |
| Autenticação com senha | continua sendo feature própria, como no sprint 001 |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **A revisão independente da 001 reprovar algo que esta feature toca** | risco aceito e declarado. O código da 001 é a base desta correção, e esperar o merge manteria o defeito por mais um ciclo |
| **A regra nova do derivador alterar a derivação de outra ontologia** | T004 exige que a saída de todas as demais saia **idêntica**; é regressão obrigatória, não verificação opcional |
| **Remover coluna com dado dentro** | T005 reconfere antes de T006 migrar; se a contagem não der zero, a tarefa para e vira decisão |
| **A equipe derivada ser lida como observada** | três tarefas a protegem — T022 é o teste da violação |
| **`updateProjectV2Field` recriar iterations de novo** | não mexer na configuração de iterations enquanto houver sprint aberto; a correção deste sprint já custou uma reatribuição de 96 itens |

## Definition of Done do sprint

- [ ] quality gates verdes: `mix format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `dialyzer`, `test`
- [ ] `mix knowledge.validate` e `mix knowledge.graph` verdes, mais o validador Python
- [ ] a derivação das demais ontologias sai idêntica à de antes
- [ ] V1 a V10 do [quickstart](../../specs/002-escopo-por-organizacao/quickstart.md) executados, com evidência de cada um
- [ ] V9 devolve **zero** pessoas sem equipe
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **revisão independente** — a mesma lacuna do sprint 001; declarada, nunca marcada como cumprida por quem implementa
