# Sprint 005 — mapeamento por organização e detalhe da issue

**Período**: 2026-08-11 a 2026-08-17 (cadência de uma semana)
**Features**: [005 — regras de mapeamento](../../../specs/005-regras-de-mapeamento/spec.md) ·
[006 — detalhe da issue](../../../specs/006-detalhe-da-issue/spec.md)
**Planos**: [005/plan.md](../../../specs/005-regras-de-mapeamento/plan.md) ·
[006/plan.md](../../../specs/006-detalhe-da-issue/plan.md)

## Objetivo do sprint

Ao fim deste sprint, o produto sabe **o que cada issue é** — e quem lê consegue ver **por
que**, issue por issue.

Duas metades da mesma pergunta: a 005 decide o conceito de 3406 issues que hoje não têm
nenhum; a 006 mostra, para qualquer issue, o que foi coletado, quem decidiu, com que regra e
com que confiança.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 26 lições. As que entram como **restrição**
deste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L08** | Sprint 002 | contrato de API escrito antes da primeira função pública nas duas features — e o da 006 foi **corrigido** quando a implementação mostrou dois desvios |
| **L11** | Sprint 002 | **não** vou tocar a configuração de iterations. Ver "Sprint no GitHub" |
| **L13** | Sprint 002 | `nil` e `""` distinguidos na tela do corpo da issue, e no valor — não na data |
| **L18** | Sprint 003 | critério atendido não é suficiente: a aceitação avalia cada SC com evidência, não a suíte verde |
| **L20** | Sprint 004 | promoção vigente é a última por `inserted_at` em microssegundo, e o recálculo da 005 mantém isso |
| **L21** | Sprint 004 | nada de função pública sem consumidor visível: a 005 só é entregue com a tela (F5) |
| **L22** | Sprint 004 | gate conferido por **código de saída**, nunca por texto com `\| tail` |
| **L23** | Sprint 004 | aviso de verificação pulada é reprovação |
| **L25** | Sprint 004 | ligação por `external_id`, nunca por `number` — vale para a prévia da 005, que agrupa por padrão e não por número |
| **L26** | Sprint 004 | casar o envelope certo do cliente GraphQL; a coleta da 006 usa o mesmo caminho já corrigido |

**A lição nova deste sprint já é conhecida, e é sobre processo**: implementar antes do plano
custou duas decisões examinadas tarde na 006. Entra na review como L27 se se confirmar.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
campo `Iteration` de 7 dias

**Iteração**: **não existe para este sprint**, e é limitação declarada — não esquecimento.

O campo tem uma iteração ativa (`Sprint 002 — Escopo por organização`, 2026-08-10) e uma
concluída. Os sprints 003 e 004 também rodaram sem iteração própria, pelo mesmo motivo:
**configurar iterations do ProjectV2 recria as existentes** — é a L11, e ela custou reatribuir
96 itens.

Consequência aceita: `flow.throughput` e `flow.wip.count` não conseguem separar 003, 004 e 005
por iteração. A alternativa — mexer na configuração — tem custo conhecido e maior.

**Decisão pendente**, herdada do sprint 004: corrigir a janela do sprint 002 e criar as
iterações que faltam, aceitando a reatribuição. Continua no product backlog.

## User stories selecionadas

### Feature 006 — entregue nesta sessão

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Ver tudo o que a plataforma sabe de uma issue | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#145](https://github.com/The-Band-Solution/theband/issues/145) | P1 | 5 | feito |
| US2 | Navegar a decomposição com as duas relações separadas | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#146](https://github.com/The-Band-Solution/theband/issues/146) | P1 | 5 | feito |
| US3 | Ver o que viola a regra, na própria issue | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#147](https://github.com/The-Band-Solution/theband/issues/147) | P2 | 3 | feito |
| US4 | Ver todas as issues de um repositório | [#144](https://github.com/The-Band-Solution/theband/issues/144) | [#148](https://github.com/The-Band-Solution/theband/issues/148) | P1 | 3 | feito |

**PR**: [#149](https://github.com/The-Band-Solution/theband/pull/149), com a equipe `the-band`
como revisora — **conferido** por `gh api .../requested_reviewers`, porque o `gh` engole a recusa
em silêncio (L14). Status `In review` no projeto, não `Done`: o código está implementado e
testado, e **não** foi incorporado nem aceito. Marcar `Done` antes do merge seria declarar
sucesso sem evidência — e eu marquei, e corrigi.

### Feature 005 — a fazer

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Começar com um catálogo pronto, e editá-lo | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#140](https://github.com/The-Band-Solution/theband/issues/140) | P1 | 8 | a fazer |
| US2 | Mapear um tipo que a plataforma não reconhece | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#141](https://github.com/The-Band-Solution/theband/issues/141) | P1 | 5 | a fazer |
| US3 | Resgatar issues sem tipo por padrão de título | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#142](https://github.com/The-Band-Solution/theband/issues/142) | P1 | 8 | a fazer |
| US4 | Não mapear o que não é tipo | [#139](https://github.com/The-Band-Solution/theband/issues/139) | [#143](https://github.com/The-Band-Solution/theband/issues/143) | P2 | 3 | a fazer |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a *complexity* —
dificuldade para o time. Campo em branco significa **desconhecido**, nunca zero.

## Tarefas

### Feature 006 — T001 a T020, todas feitas

Detalhadas em [006/tasks.md](../../../specs/006-detalhe-da-issue/tasks.md). Quatro fases: campos
na origem e no banco; leituras com a separação na API; axioma como função pura; as duas telas.

**Sem issue individual por tarefa**, e é diferença em relação ao sprint 004 — que criou 29.
O motivo: a implementação já estava feita quando o backlog abriu, e criar 20 issues para
fechá-las no mesmo minuto produziria rastro falso de fluxo. As user stories #145 a #148
carregam o rastro, e `tasks.md` carrega o detalhe. **Isso é declarado, não omitido.**

### Feature 005 — T001 a T025, a fazer

Detalhadas em [005/tasks.md](../../../specs/005-regras-de-mapeamento/tasks.md).

| Fase | Tarefas | Atende | O que entrega |
|---|---|---|---|
| F1 | T001–T008 | US1, US2 | tabela de regras, validação das três recusas, comandos com autor obrigatório |
| F2 | T009–T014 | US2, US3, US4 | segunda etapa em `Routing`, confiança, decisão "não é tipo" |
| F3 | T015–T020 | US2, US3 | prévia, recálculo assíncrono, idempotência |
| F4 | T021–T023 | US1 | catálogo composto por organização, com contagem |
| F5 | T024–T025 | US1–US4 | a tela, na sincronização, alcançada pela organização |

As 25 tarefas existem como issues tipadas `Task`, cada uma **filha da user story que ela
atende** — nunca do épico: tarefa sob épico viola `sro.rule07`, e é exatamente o que a feature
006 passou a avisar. A tabela com os números está em [a seção seguinte](#issues-das-tarefas).

## Escopo confirmado

**Feature 005 completa — F1 a F5, T001 a T025.** Decisão da pessoa mantenedora em 2026-08-11.

A razão é a L21: função pública testada e sem consumidor visível não é funcionalidade
entregue. Uma feature de mapeamento sem a tela de mapeamento é o caso exato que a lição
descreve, e a fatia vertical exige tela e backend juntos.

**O que foi recusado, e continua registrado como saída se a semana não couber**: cortar por
**user story**, não por camada — entregar US2 e US3 completas, que juntas cobrem as 3443 issues
sem conceito, e deixar US1 (catálogo) e US4 ("não é tipo") para o sprint seguinte. Cortar F5
deixaria a feature sem consumidor, e é o que a L21 proíbe.

## Issues das tarefas

Cada tarefa é filha da **user story que ela atende** — nunca do épico. Tarefa sob épico
viola `sro.rule07`, e é exatamente o aviso que a feature 006 passou a mostrar: o produto
ingerindo o próprio repositório encontraria a violação que este processo tivesse criado.

| # | Tarefa | Atende | Issue | Estimate | Fase |
|---|---|---|---|---|---|
| T001 | Criar a tabela de regras | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#150](https://github.com/The-Band-Solution/theband/issues/150) | 3 | F1 |
| T002 | Criar a tabela de decisão não é tipo | [#143](https://github.com/The-Band-Solution/theband/issues/143) | [#151](https://github.com/The-Band-Solution/theband/issues/151) | 2 | F1 |
| T003 | Acrescentar proveniência à promoção | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#152](https://github.com/The-Band-Solution/theband/issues/152) | 2 | F1 |
| T004 | Validar o padrão antes de qualquer escrita | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#153](https://github.com/The-Band-Solution/theband/issues/153) | 5 | F1 |
| T005 | Criar regra com autor obrigatório | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#154](https://github.com/The-Band-Solution/theband/issues/154) | 3 | F1 |
| T006 | Alterar regra criando versão | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#155](https://github.com/The-Band-Solution/theband/issues/155) | 2 | F1 |
| T007 | Desativar sem apagar | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#156](https://github.com/The-Band-Solution/theband/issues/156) | 2 | F1 |
| T008 | Listar as regras na ordem de aplicação | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#157](https://github.com/The-Band-Solution/theband/issues/157) | 2 | F1 |
| T009 | Ler a regra da organização na decisão por tipo | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#158](https://github.com/The-Band-Solution/theband/issues/158) | 3 | F2 |
| T010 | Acrescentar a etapa de título, e só depois | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#159](https://github.com/The-Band-Solution/theband/issues/159) | 5 | F2 |
| T011 | Aplicar as quatro formas de comparação | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#160](https://github.com/The-Band-Solution/theband/issues/160) | 3 | F2 |
| T012 | Registrar fonte da evidência e confiança | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#161](https://github.com/The-Band-Solution/theband/issues/161) | 3 | F2 |
| T013 | Ligar a promoção à regra que decidiu | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#162](https://github.com/The-Band-Solution/theband/issues/162) | 2 | F2 |
| T014 | Declarar e reverter não é tipo | [#143](https://github.com/The-Band-Solution/theband/issues/143) | [#163](https://github.com/The-Band-Solution/theband/issues/163) | 3 | F2 |
| T015 | Calcular a prévia sem consultar a origem | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#164](https://github.com/The-Band-Solution/theband/issues/164) | 5 | F3 |
| T016 | Provar que prévia e efeito coincidem | [#142](https://github.com/The-Band-Solution/theband/issues/142) | [#165](https://github.com/The-Band-Solution/theband/issues/165) | 3 | F3 |
| T017 | Recalcular na fila que já existe | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#166](https://github.com/The-Band-Solution/theband/issues/166) | 5 | F3 |
| T018 | Gravar promoção nova, preservando a anterior | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#167](https://github.com/The-Band-Solution/theband/issues/167) | 2 | F3 |
| T019 | Tornar o recálculo idempotente | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#168](https://github.com/The-Band-Solution/theband/issues/168) | 3 | F3 |
| T020 | Preservar a promoção na reobservação | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#169](https://github.com/The-Band-Solution/theband/issues/169) | 3 | F3 |
| T021 | Ler o catálogo e compor com as regras da organização | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#170](https://github.com/The-Band-Solution/theband/issues/170) | 5 | F4 |
| T022 | Contar quantas issues cada proposta casaria | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#171](https://github.com/The-Band-Solution/theband/issues/171) | 3 | F4 |
| T023 | Ativar proposta e ativar todas, com autoria | [#140](https://github.com/The-Band-Solution/theband/issues/140) | [#172](https://github.com/The-Band-Solution/theband/issues/172) | 3 | F4 |
| T024 | Componente de regras na tela de sincronização | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#173](https://github.com/The-Band-Solution/theband/issues/173) | 8 | F5 |
| T025 | Alcançar as regras pela organização | [#141](https://github.com/The-Band-Solution/theband/issues/141) | [#174](https://github.com/The-Band-Solution/theband/issues/174) | 3 | F5 |

Tarefa **não** recebe `Priority`: prioridade é da user story, e a tarefa herda a dela.
Duas fontes divergiriam, e a divergência não teria como ser resolvida.

## Fora do escopo deste sprint

| Item | Por quê |
|---|---|
| mapeamento campo de quadro → atributo | FR-037 da 005 o exclui explicitamente; campo não é tipo |
| coleta de quadros e iterações (004 F4) | fase não implementada da feature 004; continua no product backlog |
| comentários e timeline da issue | multiplicaria o consumo da origem por issue |
| corrigir a janela do sprint 002 e criar iterações | custo da L11; decisão pendente |
| papéis Scrum e associação com pessoas (#98–#100) | product backlog, sem iteration |
| renomear e remover credencial (#104) | product backlog, sem iteration |
| paridade Elixir/Python no validador | dívida declarada: 4 verificações contra 12 |

## Riscos e dependências

| Risco | Efeito | Mitigação |
|---|---|---|
| expressão regular patológica | prende o processo da tela | avaliação em `Task` com limite, sobre títulos reais |
| prévia divergir do efeito | alguém aprova vendo 3 e reclassifica 900 | uma função de decisão só; T016 compara as duas |
| recálculo de 3440 issues | sync travado, ou timeout | fila `transformation`, que **já existe**; progresso na tela |
| job em fila não configurada | fica `available` para sempre | usar `transformation`; conferir estado `completed` no teste |
| catálogo reordenado | desliga decisões já tomadas | chave `(where, how, pattern)`, nunca o índice |
| sync em `running` para sempre | bloqueia toda coleta da ferramenta | **defeito declarado e não corrigido** — ver abaixo |

**Defeito conhecido e não corrigido**: um job Oban `discarded` deixa o `sync` em `running`, e o
índice `syncs_one_running_per_tool_index` passa a bloquear qualquer coleta nova daquela
ferramenta, sem caminho pela interface. A saída hoje é SQL, registrada em
[RETOMAR.md](../RETOMAR.md). **Candidato a entrar neste sprint** se o recálculo assíncrono
aumentar a exposição.

## Definition of Done do sprint

- [ ] nove gates verdes por `mix gates`, conferidos por **código de saída**
- [ ] base de conhecimento válida, inclusive o validador Python
- [ ] cada SC das duas features avaliado **um a um, com evidência** — nunca "a suíte passou"
- [ ] `aceitacao.md` sem nenhum critério sem evidência
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] PR com revisor **conferido** por `gh pr view --json reviewRequests`
- [ ] `sprint-review.md` com feito e **não feito** separados
- [ ] `licoes-aprendidas.md` atualizado

## Lacuna de processo declarada

A constituição exige revisão independente por outro agente antes de incorporar. Esta sessão
**não invoca agente sem pedido explícito** — a condição não pode ser satisfeita, e a lacuna é
declarada, nunca marcada como cumprida.
