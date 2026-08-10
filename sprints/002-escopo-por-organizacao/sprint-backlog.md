# Sprint 002 — Escopo por organização

**Período**: 2026-08-24 a 2026-09-06 (14 dias)
**Feature**: [002-escopo-por-organizacao](../../specs/002-escopo-por-organizacao/spec.md)
**Plano**: [plan.md](../../specs/002-escopo-por-organizacao/plan.md)
**Análise ontológica**: [ontology-analysis.md](../../specs/002-escopo-por-organizacao/ontology-analysis.md)

## Objetivo do sprint

Cada pessoa e cada equipe passam a dizer de qual organização vieram, e o esquema
volta a corresponder ao modelo derivado da ontologia.

## Herança do sprint 001

**Nenhuma tarefa deste sprint começa antes de o que sobrou do anterior ter
destino.** É a regra que a skill `product-owner` passou a exigir no planejamento,
e ela existe porque escopo aberto sem destino não é trabalho, não é decisão e não
é descarte — é pendência que aparece para sempre.

Estado do sprint 001, avaliado em 2026-08-10 no
[registro de aceitação](../001-fundacao-e-coleta-eo/aceitacao.md): **os três
entregáveis foram aceitos**, D01 depois da correção de
[#88](https://github.com/The-Band-Solution/theband/issues/88). Aceitação não é
merge, e não é revisão de código — o que sobrou está abaixo, item por item.

| O que sobrou | Tipo | Destino |
|---|---|---|
| **T073 — abrir o pull request** · [#78](https://github.com/The-Band-Solution/theband/issues/78) | não executada | **Fase 0 deste sprint** |
| **Revisão independente do código** — princípio VII | bloqueada por terceiro | **bloqueador nomeado**: exige revisor que não implementou, e não existe esforço do time que produza essa pessoa. O PR é o que torna a revisão possível; enquanto ela não ocorrer, nada da 001 entra na `main` |
| **T072 — evidência do quickstart** · [#77](https://github.com/The-Band-Solution/theband/issues/77) | executada em parte | encerrada **com a limitação declarada**: V3, V4 e V8 estão provados por teste e não por ocorrência real. Já aceito assim no `aceitacao.md`, com a ressalva escrita |
| **Volume de SC-009** — 100 pessoas e 20 equipes | não executável | **descartada, com motivo**: exigiria uma organização de origem que não existe. O comportamento sob limite de uso está coberto por teste |
| **`Estimate` das issues** | não executada | **devolvida**: depende de estimativa feita com o time. Número inventado produziria métrica de fluxo apoiada em ficção |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | diferida por decisão registrada | **não entra aqui.** O `plan.md` da 001 declara: portar as três é trabalho comparável ao da feature inteira, e elas viram feature própria ligada à extração da biblioteca. O CI segue rodando os scripts Python, então o gate existe — muda o executor, não a exigência |

### A exceção, assumida

Este sprint parte do código da 001 **sem a revisão independente**, e a regra que
o parágrafo acima instituiu admite isso num caso só: quando o trabalho novo
**corrige um defeito do antigo**. É exatamente este caso — F3 conserta colunas
escritas à mão na 001, e esperar o merge manteria o defeito por mais um ciclo.

O preço está nomeado: se a revisão reprovar algo que esta feature toca, este
sprint herda o retrabalho. Consta na seção de riscos.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md) — doze lições, L01 a L12.
Seis se aplicam diretamente:

| Lição | O que muda neste sprint |
|---|---|
| **L03** — teste com dado inválido acha o que o caminho feliz esconde | Três tarefas têm o teste escrito como **violação**: T016 (um tenant pede a organização do outro), T007 (equipe organizacional sem organização) e T022 (derivada gravada como observada). É o que a L03 mandou fazer |
| **L08** — contrato escrito junto com o código descreve, não decide | Os **quatro contratos foram escritos antes** de qualquer código, e cada tarefa que cria API pública tem "o contrato existe" no `Pronta quando` |
| **L09** — um contrato pode contradizer a si mesmo | O contrato de reprocessamento da 001 se contradizia e só a implementação revelou. Aqui, cláusula inalcançável durante a implementação será tratada como **sintoma de contrato errado**, não como código a apagar |
| **L02** — servidor no ar duplica o efeito de job disparado por script | O retrofito (T011) roda por Oban. Nenhuma verificação vai chamar `perform/1` à mão com o servidor no ar |
| **L11** — configurar iterations do ProjectV2 recria as existentes | Nenhuma alteração na configuração de iterations enquanto houver sprint aberto. A correção do sprint anterior já custou uma reatribuição de 96 itens |
| **L12** — PR não aberto na hora passa a carregar outra feature | Foi por isso que a Fase 0 existe, e é a lição que criou a regra de não puxar trabalho novo. O PR da 002 é aberto **quando a tarefa pedir**, não no fim |

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
| **F0** | **Abrir o pull request da 001** | herança | Task | [#78](https://github.com/The-Band-Solution/theband/issues/78) | T073 da 001 | **feito** |
| **F0** | **Encerrar a evidência do quickstart** | herança | Task | [#77](https://github.com/The-Band-Solution/theband/issues/77) | T072 da 001 | **feito**, com limitação declarada |
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
F0 Herança → F1 Ontologia → F2 Transformação → F3 Esquema → US1 → US2 → US3
                                                     └────→ F7 Equipe derivada → F8
```

**F0 vem antes por regra, não por conveniência.** Herança colocada no fim da
lista é herança que não entra: quando o sprint aperta, o que fica para depois é o
que está no fim. Por isso o que sobrou do sprint anterior é a primeira coisa a
receber destino, e só depois o escopo novo é selecionado por importância.

A cadeia das três seguintes é rígida, e é a lição do achado F1 da análise:
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
| **A revisão independente da 001 reprovar algo que esta feature toca** | risco aceito e declarado, pela exceção registrada na seção de herança. O PR agora existe, então a revisão passou de impossível a pendente — o que reduz o tempo de exposição, não o risco |
| **O `mix knowledge.validate` passar onde o validador Python reprova** | ocorreu no sprint 001: depois do rename de `eo.sector`, o validador Elixir passou e o Python reprovou por proveniência de conceito sem `source_type`. O Elixir tem 4 verificações, o Python tem 11 — os dois gates **não** são equivalentes. Neste sprint a T003 fecha uma delas (mapeamento declarando relação inexistente). Enquanto as outras não forem portadas, **o gate Python é o que decide**, e ele roda no CI |
| **A regra nova do derivador alterar a derivação de outra ontologia** | T004 exige que a saída de todas as demais saia **idêntica**; é regressão obrigatória, não verificação opcional |
| **Remover coluna com dado dentro** | T005 reconfere antes de T006 migrar; se a contagem não der zero, a tarefa para e vira decisão |
| **A equipe derivada ser lida como observada** | três tarefas a protegem — T022 é o teste da violação |
| **`updateProjectV2Field` recriar iterations de novo** | não mexer na configuração de iterations enquanto houver sprint aberto; a correção deste sprint já custou uma reatribuição de 96 itens |

## Definition of Done do sprint

- [x] **cada item aberto do sprint 001 tem destino registrado** — concluído,
      devolvido, descartado com motivo, ou bloqueado com bloqueador nomeado
- [ ] quality gates verdes: `mix format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `dialyzer`, `test`
- [ ] `mix knowledge.validate` e `mix knowledge.graph` verdes, mais o validador Python
- [ ] a derivação das demais ontologias sai idêntica à de antes
- [ ] V1 a V10 do [quickstart](../../specs/002-escopo-por-organizacao/quickstart.md) executados, com evidência de cada um
- [ ] V9 devolve **zero** pessoas sem equipe
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **revisão independente** — a mesma lacuna do sprint 001; declarada, nunca marcada como cumprida por quem implementa
