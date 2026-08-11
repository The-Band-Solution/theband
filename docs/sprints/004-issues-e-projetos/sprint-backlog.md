# Sprint 004 — Issues e projetos das organizações observadas

**Período**: 2026-08-11 a 2026-08-17 (7 dias — cadência semanal)
**Feature**: [004-issues-e-projetos](../../../specs/004-issues-e-projetos/spec.md)
**Plano**: [plan.md](../../../specs/004-issues-e-projetos/plan.md)
**Tarefas**: [tasks.md](../../../specs/004-issues-e-projetos/tasks.md) — 42, das quais 29 neste sprint

## Objetivo do sprint

A plataforma passa a saber **qual trabalho existe** nas organizações observadas — e a
mostrar, ao lado, o que ela não conseguiu classificar e por quê.

## O que este sprint faz diferente por causa das lições

Vinte e quatro lições no [registro acumulado](../licoes-aprendidas.md). Estas entram
como restrição:

| Lição | O que muda aqui |
|---|---|
| **L19** — marca de ausência por tenant marca o que é de outra organização | `mark_issues_no_longer_observed/3` **exige** `repository_id` na assinatura, e a versão de aridade 2 não existe. A L19 impedida no tipo, num volume quatro vezes maior: 14 repositórios em vez de 3 organizações |
| **L21** — função testada sem consumidor não é entregue | nenhuma fase termina em API sem tela. T028 fecha a US1; as cinco funções de consulta (T021) existem porque a tela as usa, não antes |
| **L22** — gate diferencial sem gate de sucesso | `mix gates` confere **código de saída** de cada derivação, não só o diff. Foi o que deixou o gate vermelho por semanas |
| **L23** — aviso de verificação pulada é reprovação | `mix gates` provisiona o venv, e o validador Python valida **forma**. Nenhum gate roda com `\| tail` |
| **L24** — caminho do ambiente limpo não é testado por quem tem o ambiente | T001 é exercitada com o `.venv` removido, e as migrações com rollback |
| **L18** — um critério atendido não é suficiente | 7 dos 15 SC são pela violação. T023 confere que `#3` **não** é épico; T022 confere que **0** issues de outro repositório foram marcadas |
| **L11** — configurar iterations recria as existentes | **nenhuma alteração de iteration.** Ver a limitação abaixo |
| **L12** — PR não aberto na hora carrega outra feature | o PR #105 está aberto desde o planejamento, e recebe os commits do sprint |
| **L03** — dado inválido acha o que o caminho feliz esconde | os testes usam o dado real, que já contém uma violação de `sro.rule07` — uma tarefa sem pai |

## Herança — tudo com destino antes de escopo novo

Regra da skill `product-owner`. Item aberto sem destino não é trabalho, não é decisão
e não é descarte.

| O que sobrou | De onde | Destino |
|---|---|---|
| **#81, #82** — US2 e US3 da feature 002 | sprint 002 | product backlog, sem iteration — decisão tomada |
| **#98, #99, #100** — papéis Scrum | decisão de cadastro manual | product backlog, sem iteration |
| **#104** — US3 da feature 003, telas T019 a T022 | sprint 003 | product backlog, sem iteration |
| **Reparo do dado histórico da L19** | feature 001 | acontece na próxima coleta real de cada organização — não se desmarca o que não se sabe se a origem mostrava |
| **Janela da iteration do sprint 002** | sprint 002 | **decisão pendente**: corrigir exige mexer em iterations, causa da L11, que custou reatribuir 96 itens |
| **Iteration dos sprints 003 e 004** | — | **não existem**, pelo mesmo motivo. Limitação declarada abaixo |
| **Paridade Elixir/Python** | sprints 001 e 002 | dívida declarada: 4 verificações contra 12. O gate Python é o que decide, e roda no `mix gates` |
| **`connected_tools.status` materializa situação** | feature 001 | dívida declarada, contra a ADR 0004 D7. **Não ampliada**: esta feature não materializa `sro_user_stories.status` |
| **RSRO e SYS_SWO sem estereótipo** | base de conhecimento | eram 16 conceitos; a regra da fronteira reduziu a exigência desta feature a **um** — a T001. Os outros 15 ficam como dívida declarada |
| **Aprovação de revisão registrada** | sprints 001 a 003 | **bloqueada por ferramenta**: com uma identidade, o autor não aprova o próprio PR. Fecha com bot ou GitHub App |
| **F4 e F5 da feature 004** | esta feature | **fora deste sprint**, com o custo declarado abaixo |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteration: não existe para este sprint** — e é limitação declarada, não esquecimento.

O campo de iteração do projeto tem duas iterations configuradas: `Sprint 001` e
`Sprint 002`. Acrescentar `Sprint 003` e `Sprint 004` exige alterar a configuração do
campo, que é exatamente o que causou a [L11](../licoes-aprendidas.md) — a alteração
recriou as iterations existentes com novos identificadores, e 96 itens perderam a
atribuição.

O escopo do sprint é rastreado por este documento e pelas issues, que estão no
projeto. A ordem do backlog usa `Priority`.

### Tipos de issue desta organização

`Epic` e `User Story` **não existem** na organização, e **não foram criados**. A
organização usa `Feature`, `Task` e `Bug`, e a regra de roteamento já aceita `Feature`
como user story atômica.

Criar os tipos alteraria a configuração da organização para casar com um documento —
e inverteria a precedência que a própria regra declara: a estrutura vence o rótulo.
O mapeamento está em
[`rules/tenants/the_band_solution.yaml`](../../../priv/knowledge_base/rules/tenants/the_band_solution.yaml),
e a US3 desta feature entrega a tela que o torna ajustável sem editar YAML.

## User stories selecionadas

| # | User story | Tipo | Issue | Priority | Estimate | Cenários | Neste sprint |
|---|---|---|---|---:|---:|---:|---|
| US1 | Saber quais issues existem, e o que elas são | Feature | [#106](https://github.com/The-Band-Solution/theband/issues/106) | P0 | — | 8 | **sim** |
| US2 | Enxergar os quadros e o que cada item carrega | Feature | [#107](https://github.com/The-Band-Solution/theband/issues/107) | P1 | — | 9 | não |
| US3 | Ver e ajustar o mapeamento dos tipos | Feature | — | P1 | — | 8 | não |
| US4 | Restringir quais repositórios são observados | Feature | [#108](https://github.com/The-Band-Solution/theband/issues/108) | P2 | — | 4 | **parcial** |

`Priority` carrega a *importance* — valor para a organização. `Estimate` carrega a
*complexity*. **`Estimate` em branco significa desconhecido, não zero**: nenhuma
estimativa foi feita, e preencher com zero mediria como se a decisão tivesse sido
tomada.

**US3 não tem issue ainda** — foi especificada depois da criação das issues, e é
pendência explícita em vez de link inventado.

**US4 entra parcialmente**: a exclusão de repositório e o repositório inacessível
(T011, T012) são a base da US1, porque definem o escopo da marca de ausência. A tela
de gestão de repositórios fica fora.

## Tarefas

| # | Tarefa | Fase | Atende | Issue | [P] | Estado |
|---|---|---|---|---|---|---|
| T001 | Anotar o kind referenciado | F0 | US1 | [#109](https://github.com/The-Band-Solution/theband/issues/109) | — | a fazer |
| T002 | Provar que a referência é uma tabela só | F0 | US1 | [#110](https://github.com/The-Band-Solution/theband/issues/110) | — | a fazer |
| T003 | Declarar a regra do tenant | F1 | US1 | [#111](https://github.com/The-Band-Solution/theband/issues/111) | sim | a fazer |
| T004 | Escrever a consulta de repositórios | F1 | US1 | [#112](https://github.com/The-Band-Solution/theband/issues/112) | sim | a fazer |
| T005 | Escrever as consultas de issues | F1 | US1 | [#113](https://github.com/The-Band-Solution/theband/issues/113) | sim | a fazer |
| T006 | Declarar o conector de issues | F1 | US1 | [#114](https://github.com/The-Band-Solution/theband/issues/114) | — | a fazer |
| T007 | Migrar a tabela do kind referenciado | F2 | US1 | [#115](https://github.com/The-Band-Solution/theband/issues/115) | — | a fazer |
| T008 | Migrar a extensão do repositório | F2 | US1 | [#116](https://github.com/The-Band-Solution/theband/issues/116) | — | a fazer |
| T009 | Migrar o repositório observado | F2 | US1 | [#117](https://github.com/The-Band-Solution/theband/issues/117) | — | a fazer |
| T010 | Descobrir os repositórios da organização | F2 | US1 | [#118](https://github.com/The-Band-Solution/theband/issues/118) | — | a fazer |
| T011 | Excluir repositório da observação | F2 | US4 | [#119](https://github.com/The-Band-Solution/theband/issues/119) | — | a fazer |
| T012 | Marcar repositório inacessível | F2 | US4 | [#120](https://github.com/The-Band-Solution/theband/issues/120) | — | a fazer |
| T013 | Migrar a issue coletada | F3 | US1 | [#121](https://github.com/The-Band-Solution/theband/issues/121) | — | a fazer |
| T014 | Migrar a promoção da issue | F3 | US1 | [#122](https://github.com/The-Band-Solution/theband/issues/122) | — | a fazer |
| T015 | Migrar vínculos e recusas | F3 | US1 | [#123](https://github.com/The-Band-Solution/theband/issues/123) | — | a fazer |
| T016 | Gravar a issue coletada | F3 | US1 | [#124](https://github.com/The-Band-Solution/theband/issues/124) | — | a fazer |
| T017 | Promover pela regra versionada | F3 | US1 | [#125](https://github.com/The-Band-Solution/theband/issues/125) | — | a fazer |
| T018 | Gravar a divergência entre declarado e derivado | F3 | US1 | [#126](https://github.com/The-Band-Solution/theband/issues/126) | — | a fazer |
| T019 | Relatar por repositório o que foi promovido | F3 | US1 | [#127](https://github.com/The-Band-Solution/theband/issues/127) | — | a fazer |
| T020 | Registrar mudança de classificação entre coletas | F3 | US1 | [#128](https://github.com/The-Band-Solution/theband/issues/128) | — | a fazer |
| T021 | Consultas de issues, promoções e lacunas | F3 | US1 | [#129](https://github.com/The-Band-Solution/theband/issues/129) | — | a fazer |
| T022 | Registrar a lacuna com o nome do tipo | F3 | US1 | [#130](https://github.com/The-Band-Solution/theband/issues/130) | — | a fazer |
| T023 | Derivar épico de atômica | F3 | US1 | [#131](https://github.com/The-Band-Solution/theband/issues/131) | — | a fazer |
| T024 | Recusar ciclo no comando | F3 | US1 | [#132](https://github.com/The-Band-Solution/theband/issues/132) | — | a fazer |
| T025 | Registrar referência fora do escopo | F3 | US1 | [#133](https://github.com/The-Band-Solution/theband/issues/133) | — | a fazer |
| T026 | Marcar ausência por repositório | F3 | US1 | [#134](https://github.com/The-Band-Solution/theband/issues/134) | — | a fazer |
| T027 | Interromper coleta pelo limite de consumo | F3 | US1 | [#135](https://github.com/The-Band-Solution/theband/issues/135) | — | a fazer |
| T028 | Tela de issues com lacunas | F3 | US1 | [#136](https://github.com/The-Band-Solution/theband/issues/136) | — | a fazer |
| T029 | Provar o isolamento entre tenants | F3 | US1 | [#137](https://github.com/The-Band-Solution/theband/issues/137) | — | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Fora do escopo deste sprint

| Item | Tarefas | Custo declarado |
|---|---|---|
| **F4 — quadros, campos e iterações** | T030 a T039 | sem elas não há sprint, backlog nem valor de campo. **A dependência é nessa direção**: item de quadro aponta para issue, e entregar quadros antes produziria backlogs vazios |
| **F5 — tela de quadros** | T040 | idem |
| **US3 — tela de mapeamento** | ainda sem tarefas | a regra do tenant fica declarada em YAML (T003), e ajustá-la exige editar o repositório. **A lacuna fica visível pela US1 e inendereçável pela interface** até esta tela existir |
| **Fechamento** | T041, T042 | dependem do MVP |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **Errar composição por atendimento** — tarefa como parte de user story | é o defeito da feature. T023 usa os seis casos reais, e a asserção que importa é `#3` com nove sub-issues **não** ser épico. Se ela falhar, 78 tarefas se ligam a épicos |
| **Repetir a L19 em 14 repositórios** | `repository_id` obrigatório na assinatura, e T022 testa com dois repositórios e duas coletas em sequência |
| **Volume de issues estourar o limite de consumo** | checkpoint **por repositório**; retomar não recomeça o repositório inteiro (T027) |
| **Sub-issues indisponíveis na instância** | detectar e **declarar** que a distinção épico/atômica não é feita. Nunca cair para heurística de lista em markdown |
| **A regra de roteamento estar errada** | tem `status: proposed`. A feature a **mede**: a lacuna por motivo é a métrica que diz onde ela erra. Corrigir é consequência, não pré-requisito |
| **`refused_links` nascer e ficar vazia** | declarado no plano como **previsão**, com critério de reversão: vazia depois de duas coletas reais em todos os tenants, vira contagem no relatório. T041 registra a contagem |

## Definition of Done do sprint

- [ ] `mix gates` verde — os nove, conferidos por código de saída
- [ ] os seis casos estruturais reais classificam certo, e `#3` **não** é épico
- [ ] a marca de ausência não atravessa repositório, provado com dois repositórios e duas coletas
- [ ] a soma de promovidas e não promovidas é igual ao total coletado, sob qualquer filtro
- [ ] issue de tipo desconhecido não promovida, e contada **com o nome do tipo**
- [ ] a divergência entre tipo declarado e conceito derivado está **gravada**, não só derivada
- [ ] V1 a V8 do quickstart executadas contra o dado real, com os números registrados
- [ ] a tela de issues no ar, mostrando promoções, lacunas e divergências
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `aceitacao.md` percorrendo os critérios, um a um, com evidência
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **revisão independente** — declarada, nunca marcada como cumprida por quem implementa
