# Sprint 002 — Escopo por organização

**Período**: 2026-08-10 a 2026-08-16 (7 dias — cadência semanal)
**Feature**: [002-escopo-por-organizacao](../../../specs/002-escopo-por-organizacao/spec.md)
**Plano**: [plan.md](../../../specs/002-escopo-por-organizacao/plan.md)
**Análise ontológica**: [ontology-analysis.md](../../../specs/002-escopo-por-organizacao/ontology-analysis.md)

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
| **T073 — abrir o pull request** · [#78](https://github.com/The-Band-Solution/theband/issues/78) | não executada | **concluída na Fase 0**: [PR #89](https://github.com/The-Band-Solution/theband/pull/89), com a tabela de mapeamentos semânticos. Mergeado em `45d21a0` |
| **Revisão independente do código** — princípio VII | era bloqueio estrutural; **destravado em 2026-08-10** | A causa era permissão: o repositório tinha um colaborador só, o autor. Concedido `pull` à equipe `the-band`, o pedido de revisão passou a funcionar — feito no [PR #91](https://github.com/The-Band-Solution/theband/pull/91), e quem revisa é `Adylla027` ou `EduardoNFraiz`. **Resíduo irrecuperável**: o #89 foi mergeado sem revisão e não há como pedir revisão de PR mergeado. Lição L15 |
| **T072 — evidência do quickstart** · [#77](https://github.com/The-Band-Solution/theband/issues/77) | executada em parte | encerrada **com a limitação declarada**: V3, V4 e V8 estão provados por teste e não por ocorrência real. Já aceito assim no `aceitacao.md`, com a ressalva escrita |
| **Volume de SC-009** — 100 pessoas e 20 equipes | não executável | **descartada, com motivo**: exigiria uma organização de origem que não existe. O comportamento sob limite de uso está coberto por teste |
| **`Estimate` das issues** | não executada | **devolvida**: depende de estimativa feita com o time. Número inventado produziria métrica de fluxo apoiada em ficção |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | diferida por decisão registrada | **não entra aqui.** O `plan.md` da 001 declara: portar as três é trabalho comparável ao da feature inteira, e elas viram feature própria ligada à extração da biblioteca. O CI segue rodando os scripts Python, então o gate existe — muda o executor, não a exigência |

### A exceção, assumida — e o que o merge mudou nela

Este sprint parte do código da 001 **sem a revisão independente**, e a regra que
o parágrafo acima instituiu admite isso num caso só: quando o trabalho novo
**corrige um defeito do antigo**. É exatamente este caso — F3 conserta colunas
escritas à mão na 001.

**2026-08-10**: o [PR #89](https://github.com/The-Band-Solution/theband/pull/89)
foi mergeado na `main` em `45d21a0`, por decisão da pessoa mantenedora, com o CI
verde e **sem nenhuma aprovação registrada** — `pulls/89/reviews` devolve lista
vazia.

Isso não reduziu o risco; **mudou o lugar dele.** Antes era código não revisado
fora da linha principal, visível como branch pendente. Agora é código não revisado
**dentro** da linha principal, indistinguível do resto. É a forma mais difícil de
lembrar que a dívida existe, e é a razão de este parágrafo existir.

**A causa da revisão nunca ter acontecido foi encontrada, e era outra.** Não era
agenda: o repositório tinha **um colaborador só**, `paulossjunior`, e nenhuma equipe
com acesso. Revisão só pode ser pedida a colaborador, e o autor não pode ser revisor —
então havia **zero revisores possíveis**. A exigência atravessou o sprint 001 inteiro
como "revisão pendente", indistinguível de item que só precisava de tempo. Registrado
em [L14](../licoes-aprendidas.md) e [L15](../licoes-aprendidas.md).

**Destravado em 2026-08-10, com duas chamadas de API**: `pull` concedido à equipe
`the-band` — o mínimo que revisão exige — e o pedido de revisão feito à equipe em vez
de a uma pessoa. Pedir à equipe é o que **produz** a independência: o pedido fica
aberto a qualquer membro, e o autor, sendo membro, não pode atendê-lo. Quem revisa é
`Adylla027` ou `EduardoNFraiz`.

**Correção do próprio registro.** Este documento afirmava que a revisão da 001 não
havia acontecido. A pessoa mantenedora corrigiu: *"eu olhei e concordei, por isso não
coloquei comentário."* A leitura ocorreu; **falta a prova, não a revisão.**

A conclusão errada vinha de ler o campo `author` do GitHub como se nomeasse quem
implementou. Não nomeia: quem implementou é o agente, cujos commits trazem
`Co-Authored-By: Claude Opus 5` e que não tem conta. O `422` é artefato de ferramenta,
não conflito de interesse. Registrado como [L16](../licoes-aprendidas.md).

**O que fecha a lacuna de vez** é abrir os PRs com identidade de agente — bot ou GitHub
App. Aí o implementador é o autor de fato, e `paulossjunior` pode aprovar formalmente o
que não escreveu. Enquanto isso, #89, #90 e #91 ficam com o atestado datado no
`aceitacao.md`, porque PR mergeado não recebe review.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md) — dezesseis lições, L01 a L16.
Dez se aplicam diretamente:

| Lição | O que muda neste sprint |
|---|---|
| **L03** — teste com dado inválido acha o que o caminho feliz esconde | Três tarefas têm o teste escrito como **violação**: T016 (um tenant pede a organização do outro), T007 (equipe organizacional sem organização) e T022 (derivada gravada como observada). É o que a L03 mandou fazer |
| **L08** — contrato escrito junto com o código descreve, não decide | Os **quatro contratos foram escritos antes** de qualquer código, e cada tarefa que cria API pública tem "o contrato existe" no `Pronta quando` |
| **L09** — um contrato pode contradizer a si mesmo | O contrato de reprocessamento da 001 se contradizia e só a implementação revelou. Aqui, cláusula inalcançável durante a implementação será tratada como **sintoma de contrato errado**, não como código a apagar |
| **L02** — servidor no ar duplica o efeito de job disparado por script | O retrofito (T011) roda por Oban. Nenhuma verificação vai chamar `perform/1` à mão com o servidor no ar |
| **L11** — configurar iterations do ProjectV2 recria as existentes | Aplicada **na prática**, ao mudar a cadência para 7 dias: snapshot de todos os 97 itens **antes**, reatribuição por `item id` e não por número de issue, e conferência contra o snapshot depois. Os 97 ficaram órfãos, como a lição previu, e os 87 voltaram ao lugar |
| **L12** — PR não aberto na hora passa a carregar outra feature | Foi por isso que a Fase 0 existe, e é a lição que criou a regra de não puxar trabalho novo. O PR da 002 é aberto **quando a tarefa pedir**, não no fim |
| **L13** — secret referenciado e não cadastrado chega como string vazia | Onde a ausência tem tratamento, vazio recebe o mesmo. Vale para toda leitura de ambiente que esta feature acrescentar |
| **L14** — `gh` engole o pedido de revisão recusado | Ao abrir o PR desta feature, conferir `gh pr view <n> --json reviewRequests`. Lista vazia significa que ninguém foi pedido, não importa o que o comando disse |
| **L16** — o autor do PR não é quem implementou | Ao registrar revisão, distinguir "não ocorreu" de "sem prova". O campo `author` do GitHub responde quem abriu o PR, nunca quem escreveu o código |
| **L15** — não há revisor possível num repositório de um colaborador só | A revisão independente era pendência de **permissão**, não de agenda. Destravada neste sprint: `pull` à equipe `the-band`, e pedido de revisão à equipe. Todo PR desta feature nasce com `team_reviewers[]=the-band` |

As demais foram consideradas e não se aplicam: L01 (não há gerador nesta
feature), L04 (nenhuma consulta nova ao GitHub), L05 e L07 (correções já
incorporadas), L06 (disciplina de caminho absoluto, já em uso), L10 (não há
rotação de chave aqui).

## Sprint no GitHub

**Iteration**: Sprint 002 — Escopo por organização · 2026-08-10 a 2026-08-16 · 7 dias
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Primeira ocorrência.** Ao criar a iteration do sprint 002, a API do
ProjectV2 recriou a do sprint 001 com identificador novo, e os 77 itens dele
ficaram órfãos — `updateProjectV2Field` substitui o conjunto de iterations e não
aceita `id` nas existentes. Os itens foram reatribuídos, e no caminho 10 itens de
**outros repositórios** (`eo_lib`, `theband-frontend`, `theband-backend` e um
pull request) foram atribuídos por engano ao sprint 001 e depois limpos. Virou a
[L11](../licoes-aprendidas.md).

**Segunda ocorrência, esta deliberada.** Mudar a cadência para 7 dias exige mexer
na mesma configuração, então a L11 foi aplicada como procedimento:

| Passo | Resultado |
|---|---|
| snapshot antes — item, repositório, número e iteration de cada um | 97 itens: 76 no sprint 001, 11 no sprint 002, 10 sem iteration |
| `updateProjectV2Field` com `duration: 7` | as duas iterations recriadas, **97 itens órfãos** |
| reatribuição pelo `item id` do snapshot | 87 reatribuídos, 0 falhas |
| conferência contra o snapshot | 76 · 11 · 10 sem iteration, e os 10 sem são de **outros repositórios** |

Duas coisas fizeram diferença. Reatribuir pelo **`item id`**, que não muda quando a
iteration é recriada, em vez de casar por número de issue — número não é único num
projeto que agrega vários repositórios, e foi o segundo erro da primeira vez. E ter
o snapshot **antes**: sem ele a informação de qual item pertencia a qual sprint
simplesmente não existiria em lugar nenhum.

**Descoberta nova.** A iteration do sprint 001, com data no passado, saiu de
`iterations` e apareceu em **`completedIterations`** — com identificador próprio,
`2849580c`. Um script que leia só `iterations` não a encontra e conclui que ela
deixou de existir. Está em [L11](../licoes-aprendidas.md).

## Duração — como foi dimensionada

**Escopo**: 27 tarefas em 8 fases · **5 níveis** de dependência
**Caminho crítico**:

```text
nível 1  Ontologia (T001–T003)
nível 2  Transformação (T004)          ── só depois de a relação existir
nível 3  Esquema (T005–T008)           ── só depois de a derivação produzir a coluna
nível 4  US1 (T009–T012) ‖ Equipe derivada (T020–T024)
nível 5  US2 (T013–T017) ‖ US3 (T018–T019) ‖ Polish (T025–T027)
```

Cinco níveis, não oito fases: US1 e a equipe derivada dependem ambas do esquema e
não uma da outra, então ocupam **um** nível. O mesmo vale para US2, US3 e Polish.

**Vazão usada**: **nenhuma.** Não é premissa declarada nem dado — é ausência, e a
razão está abaixo.

**Piso de fatia vertical**: **nível 4.** Os três primeiros níveis são ontologia,
transformação e esquema — infraestrutura sem consumidor visível. O primeiro
entregável que materializa user story é US1, no nível 4. Um sprint de três níveis
fecha na aritmética e **não produz `sro.sprint_deliverable`**.

**Duração proposta**: **4 dias** para o MVP (níveis 1 a 4), **5 dias** para a feature
inteira.

**Confiança**: **baixa.** Um dia por nível é premissa, não observação.

**Duração decidida**: **7 dias — uma semana**, por decisão da pessoa mantenedora em
2026-08-10, como cadência padrão do projeto.

A decisão é de cadência, não deste sprint: sprint de duração fixa é o que torna a
vazão comparável entre sprints, e comparabilidade é condição declarada da
`flow.throughput.rate`. Cadência variável por sprint tornaria a série ilegível — foi
por isso que a proposta de 2 a 3 dias sob demanda foi descartada em favor de uma
semana fixa.

Sete dias **acomodam a feature inteira** com folga sobre os 5 dias do caminho
crítico. A folga não é escopo disponível: é onde caberá o nível 3, que remove
colunas com migração e reconferência e é o mais provável de estourar.

### Por que 2 ou 3 dias não cabem nesta feature

Não é conservadorismo: é a cadeia. Os três primeiros níveis são rígidos — coluna
antes de relação foi exatamente o erro que criou este trabalho —, e o primeiro
consumidor visível está no quarto. **Três dias comprariam os três níveis de
infraestrutura e nenhuma tela.**

Encurtar teria de vir de cortar escopo, e o escopo que sobraria não é entregável.
Duração é a maior entre volume, caminho crítico e piso vertical — aqui o piso
vertical é que manda.

**A partir da 003, sprints de 2 a 3 dias são viáveis.** O que os impede aqui é esta
feature começar por três níveis de correção estrutural. Uma feature cujo primeiro
nível já toca tela cabe em dois dias.

### Por que a vazão não entrou na conta

Três razões, e as três estão declaradas na própria `flow.throughput.rate`:

| Razão | O que a medida diz |
|---|---|
| **histórico de um sprint** | "um sprint isolado não descreve o fluxo" — há uma observação, não uma vazão |
| **a janela do sprint 001 não continha as tarefas dele** | corrigido neste planejamento: a iteration passou a 2026-08-03 → 08-09, que contém 09/08. Antes a vazão dele era **zero**; agora é **76 tarefas em 7 dias**. Um valor, não uma série |
| **a duração era desigual** | "comparar sprints exige duração constante". Com 14 dias no 001 e 7 no 002 a comparação não existiria. A cadência semanal resolve isso **a partir daqui** — e o 001 só é comparável porque sua janela foi reescrita para 7 dias, o que é ajuste de registro, não de trabalho realizado |

Há ainda a armadilha que a medida nomeia: **"usar a vazão como meta a bater a torna
alvo, e alvo deixa de ser medida"**. Dimensionar duração pela vazão é legítimo;
escolher a duração para atingir uma vazão produz tarefa fechada no board antes de o
trabalho terminar.

**Consequência prática: corrigir as datas da iteration deixou de ser cosmético.**
Enquanto o sprint 001 tiver janela que não contém as próprias tarefas, a vazão dele
é zero, e nenhum sprint seguinte pode ser dimensionado por série. A decisão 1 do
planejamento virou pré-requisito de todo dimensionamento futuro.

### O que invalida esta conta

- **granularidade mudar**: 27 tarefas aqui e 76 no sprint 001 não são a mesma
  unidade. Decompor mais fino eleva a vazão sem mais trabalho feito;
- **um nível levar mais de um dia**: o nível 3 remove colunas com migração e
  reconferência, e é o mais provável de estourar;
- **as três primeiras fases não serem rígidas de fato**: se a derivação já emitisse
  a chave, o nível 2 sairia e a cadeia encurtaria um dia;
- **trabalho que não virou tarefa**: revisão, apoio, espera por terceiro. A medida
  declara que isso consome capacidade e não aparece na contagem.

## Planejamento — `sro.planning_meeting`

**Realizado em 2026-08-10.** A ordem seguida é a que a skill `product-owner` passou
a exigir: herança antes de escopo novo, e importância só depois.

| Passo | Resultado |
|---|---|
| 1. listar o que está aberto do sprint anterior | 6 itens, na tabela de herança acima |
| 2. dar destino a cada um | 6 destinos: 2 concluídos, 1 encerrado com limitação, 1 descartado com motivo, 1 devolvido, 1 bloqueado com bloqueador nomeado |
| 3. herança em primeiro lugar | Fase 0, antes de F1 |
| 4. selecionar escopo novo por importância | as 9 issues abaixo, com o MVP declarado |

**Conclusão: F1 está liberada.** Nenhum item do sprint 001 permanece sem destino,
o que é a condição da regra — e não é o mesmo que dizer que tudo do 001 ficou
pronto. A revisão independente segue pendente, com bloqueador nomeado.

### Duas decisões que o planejamento levou ao papel, e que foram tomadas

**1. Cadência semanal, e as datas corrigidas.** As datas da iteration contradiziam
o que aconteceu, e a contradição zerava as medidas de fluxo:

| | Antes | Agora |
|---|---|---|
| Sprint 001 | início 2026-08-10, 14 dias → terminaria 2026-08-23 | **2026-08-03 a 2026-08-09**, 7 dias |
| Sprint 002 | início 2026-08-24, 14 dias | **2026-08-10 a 2026-08-16**, 7 dias |

O defeito era que **as tarefas do sprint 001 foram executadas antes da data em que a
iteration dizia que ele começou** — 2026-08-09, fora da janela. `flow.throughput.rate`
e `flow.wip.count` atribuem tarefa a sprint por janela de datas, então os dois
devolviam **zero** para o sprint 001: um sprint que produziu 76 tarefas aparecia sem
trabalho algum. Resíduo da [L11](../licoes-aprendidas.md), onde os itens foram
consertados e a data não.

Agora a janela 03→09/08 contém 09/08, e o sprint 002 começa **hoje**, sem as duas
semanas vazias que a configuração anterior deixava.

**A correção custou o que a L11 previu**, e a mitigação funcionou. Mudar `duration`
de 14 para 7 recriou as duas iterations e deixou **todos os 97 itens órfãos**. O
snapshot tirado antes — item, repositório, número e iteration de cada um — permitiu
reatribuir os 87 que tinham iteration: 76 no sprint 001, 11 no sprint 002, e os 10
sem iteration ficaram sem, porque são de **outros repositórios**. Reatribuir pelo
`item id` do snapshot, e não pelo número da issue, é o que evitou repetir o segundo
erro da L11.

**2. Épico #79 recebeu importância P0** — a da parte mais importante, entre US1 (P0),
US2 (P1) e US3 (P2). É decisão do papel, não derivação, e por isso foi tomada por
quem desempenha o papel em vez de gravada por conveniência. As tarefas #83 a #87
seguem **sem** `Priority`, o que é o correto: tarefa herda a da user story que
atende.

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
| **A revisão independente da 001 nunca acontecer** | deixou de ser risco de atraso e passou a ser **impedimento estrutural**: uma conta só não pode revisar o próprio PR. Fechar exige duas identidades — decisão de infraestrutura, fora deste sprint. Até então, todo entregável carrega a lacuna declarada |
| **O código não revisado estar na `main`** | mergeado em `45d21a0` sem aprovação registrada. O risco não diminuiu com o merge: ficou indistinguível do resto do código, e é por isso que está escrito na herança e aqui |
| **As medidas de fluxo devolverem zero para o sprint 001** | as datas da iteration não correspondem ao que ocorreu, e a correção não foi feita porque mexer em iterations causou a L11. Decisão pendente, registrada no planejamento |
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
- [ ] V1 a V10 do [quickstart](../../../specs/002-escopo-por-organizacao/quickstart.md) executados, com evidência de cada um
- [ ] V9 devolve **zero** pessoas sem equipe
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **revisão independente** — a mesma lacuna do sprint 001; declarada, nunca marcada como cumprida por quem implementa
