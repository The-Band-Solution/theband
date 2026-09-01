# Sprint 026 — Registro de aceitação

**Features**: [050-em-producao](../../specs/050-em-producao/spec.md) ·
[052-primeira-conta-do-ambiente](../../specs/052-primeira-conta-do-ambiente/spec.md) ·
herança de [047](../../specs/047-mensagens-internacionalizadas/spec.md) e
[051](../../specs/051-cadastro-por-github/spec.md)
**Avaliado em**: 2026-09-01, na `development` (todos os PRs mergeados), com
evidência executada nesta avaliação — gates, medição HTTP contra o endereço real
e a medição do SC-004 que faltava.
**Papel**: Product Owner — avaliação proposta pelo agente e **CONFIRMADA pela
pessoa alocada ao papel em 2026-09-01**, nos vereditos como propostos: 5
entregáveis aceitos, 3 não aceitos, e as user stories recusadas com o destino
escrito em vez de encerradas.
**Tipo de PO**: `sro.product_owner_client` — quem demanda é quem mantém.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 8 |
| Aceitos | 5 |
| Não aceitos | 3 |
| Tarefas executadas com sucesso | 12 |
| Tarefas executadas sem sucesso | 7 (as sete da 050, pelos entregáveis D5 e D6) |

**A recusa aqui é de avaliação incompleta, não de defeito.** Os três não aceitos
falham por **critério sem evidência** — nenhum falhou por comportamento errado
observado. A distinção importa: o destino não é reescrever o que existe, é medir
o que não foi medido.

---

## D1 — As frases nascidas em função de origem passam pela borda

**Produzido por**: 047/T014 · [#617](https://github.com/The-Band-Solution/theband/issues/617) ·
PR [#630](https://github.com/The-Band-Solution/theband/pull/630)
**Materializa**: 047/US1 — erros no catálogo · [#573](https://github.com/The-Band-Solution/theband/issues/573)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| As 5 frases em literal saem do domínio e nascem no catálogo | funcional | sim | PR #630, gates verdes na branch; `mix mensagens.verificar` EXIT=0 |
| A caça aos irmãos (L81) varre a forma `(erro\|ok\|error\|aviso): funcao(` antes de entregar | processo | sim | executada no sprint backlog, **zero restantes** |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

---

## D2 — O verificador vê a classe função-origem (salto de um nó)

**Produzido por**: 047/T015 · [#634](https://github.com/The-Band-Solution/theband/issues/634) ·
PR [#635](https://github.com/The-Band-Solution/theband/pull/635)
**Materializa**: 047/US1 · [#573](https://github.com/The-Band-Solution/theband/issues/573)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| O verificador alcança a frase que nasce uma chamada atrás | funcional | sim | `test/mix/tasks/mensagens_verificar_test.exs` +53 linhas no PR #635 |
| A classe morre inteira, e não só o contraexemplo (L81) | funcional | sim | 7 msgids novos em `sistema.pot`/`errors.pot`; contrato e pendências da 047 atualizados no mesmo PR |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.
**Ressalva registrada**: a aceitação definitiva da 047/US1 pertence à feature 047
e depende de nova avaliação sobre o conjunto — aqui se aceita **a tarefa de
herança**, que era o que o sprint 026 se comprometeu a entregar.

---

## D3 — A busca diz a organização e a observação terminada

**Produzido por**: 051/T009 · [#618](https://github.com/The-Band-Solution/theband/issues/618) ·
PR [#631](https://github.com/The-Band-Solution/theband/pull/631)
**Materializa**: 051/US2 — associar o GitHub · [#598](https://github.com/The-Band-Solution/theband/issues/598)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| O resultado da busca mostra a ORGANIZAÇÃO (edge case dos homônimos) | funcional | sim | `test/the_band_web/live/accounts_elo_test.exs`; PR #631 |
| A OBSERVAÇÃO TERMINADA é dita na tela | funcional | sim | mesmo teste; PR #631 |
| O comentário que contradizia o contrato saiu, e o contrato ganhou a nota (L82) | processo | sim | PR #631, contrato da 051 com data e razão |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

---

## D4 — A imagem, o CD e o runbook

**Produzido por**: 050/T001–T007 · [#623](https://github.com/The-Band-Solution/theband/issues/623)–[#629](https://github.com/The-Band-Solution/theband/issues/629) ·
PR [#632](https://github.com/The-Band-Solution/theband/pull/632)
**Materializa**: nada sozinho — é a **fundação** de 050/US1–US3. Avaliado como
entregável intermediário; os critérios das três user stories são avaliados em D5.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| A imagem builda e recusa subir sem as variáveis (violação primeiro) | funcional | sim | CI "a imagem de produção builda" verde; `docker run` sem env recusando |
| O CD publica com a tag da versão e falha dizendo o que falta | funcional | sim | contrato `contracts/pipeline-de-release.md`; provado no release v0.1.0 — a falha do webhook disse *"a imagem e a tag existem, mas NÃO houve delivery"* |
| O runbook descreve o caminho no Dokploy | não funcional | sim | `docs/producao/runbook.md`, executado por pessoa em 2026-09-01 |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase das tarefas T001–T007**: derivada de D5, não desta linha — ver a nota lá.

---

## D5 — A produção no ar (v0.1.0) e sua medição

**Produzido por**: releases [#636](https://github.com/The-Band-Solution/theband/pull/636) (v0.1.0) e
[#641](https://github.com/The-Band-Solution/theband/pull/641) (v0.2.0), medição em
PR [#639](https://github.com/The-Band-Solution/theband/pull/639)
**Materializa**: 050/US1 ([#620](https://github.com/The-Band-Solution/theband/issues/620)),
050/US2 ([#621](https://github.com/The-Band-Solution/theband/issues/621)),
050/US3 ([#622](https://github.com/The-Band-Solution/theband/issues/622))

### 050/US1 — A plataforma num endereço estável

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — HTTP simples leva ao HTTPS | funcional | **sim** | medido nesta avaliação, 2026-09-01 11:52 UTC: `http://…/sign-in` → **301** com `Location: https://…/sign-in` |
| AS2 — credenciais válidas abrem os painéis com dado real | funcional | **sim** | a pessoa mantenedora entrou em produção e disparou a coleta: **125 repositórios, 4895 issues, 15 quadros, 3981 itens**, conferidos contra a origem |
| AS3 — migração pendente roda antes de a versão atender | funcional | **sim, parcial** | o v0.1.0 subiu sobre banco vazio e o log deu a ordem `migrações aplicadas.` → `Running TheBandWeb.Endpoint`. **A metade "o dado anterior permanece" não foi exercida**: nenhum release posterior levou migração |
| AS4 — sessão válida sobrevive ao release | funcional | **NÃO AVALIADO** | ninguém estava com sessão aberta durante o deploy do v0.2.0, e nada foi medido |
| AS5 — a janela de indisponibilidade é curta | não funcional | **NÃO AVALIADO** | SC-002 registra: *"a janela de indisponibilidade não foi cronometrada"* |
| SC-001 — pessoa de fora entra e vê painel em menos de 2 min | não funcional | **NÃO AVALIADO** | a porta responde em 0,65s (medido agora), e havia conta desde a 052 — mas o percurso completo nunca foi cronometrado |
| SC-002 — release em menos de 15 min de procedimento | não funcional | sim | CD: build+push+tag em **1m43s**; entrega pelo webhook em **11s** |

**Fase derivada**: `sro.not_accepted_deliverable` — três critérios sem evidência
(AS4, AS5, SC-001).
**O que faltou**: medir, não construir. Cronometrar o próximo release com uma
sessão aberta responde AS4, AS5 e SC-002-janela de uma vez; SC-001 se cronometra
com um relógio e uma aba anônima.
**Destino da user story**: **volta ao product backlog** como tarefa nova de
medição ligada à mesma US atômica — nunca reabrindo #620.

### 050/US2 — Os dados sobrevivem

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — cópia íntegra e datada existe **fora** da máquina de produção | funcional | **NÃO AVALIADO** | o backup foi agendado no Dokploy; **não há evidência de destino fora da máquina** |
| AS2 — a restauração sobe a plataforma com os mesmos números | funcional | **não em produção** | ensaio **local** conforme em 2026-08-31 (`eo_people=88 eo_teams=12 eo_organizations=3` → 88/12/3, conferido pela própria imagem). SC-003 registra: *"não atendido em produção"* |
| AS3 — a falha da rotina de cópia é visível para quem administra | funcional | **NÃO AVALIADO** | nenhuma falha foi provocada; nada diz como ela apareceria |
| SC-006 — a rotina roda 7 dias seguidos | não funcional | **não medível ainda** | agendada em 2026-09-01; o prazo vence em 2026-09-08 |

**Fase derivada**: `sro.not_accepted_deliverable` — falha em AS1 e AS3 por
ausência de evidência, e AS2 só tem a metade local.
**O que faltou**: o ensaio contra o backup do Dokploy, **antes de haver dado que
importe** — e essa janela está se fechando: a produção já tem 4895 issues
coletadas.
**Destino da user story**: **primeira da fila do sprint 027**, com bloqueador
nomeado (exige acesso ao painel do Dokploy, que é da pessoa mantenedora).

### 050/US3 — A produção recusa o regime de desenvolvimento

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — os seeds de desenvolvimento são recusados em produção | funcional | **sim, por leitura** | `priv/repo/seeds.exs:17` levanta quando `env == :prod`. **Não foi executado no ambiente real** — lacuna de prova, não de comportamento |
| AS2 — sem a chave mestra a plataforma recusa subir, dizendo o que falta | funcional | sim | `rel/entrypoint.sh` confere as variáveis e derruba; a violação está no CI (`docker run` sem env) |
| AS3 — nenhum segredo em log, página de erro ou imagem | funcional | sim | `docker history` e `Config.Env`: **0** ocorrências; log do contêiner: **0** |
| SC-004 — zero segredos no repositório, imagem e logs | não funcional | sim | mesma medição, registrada em `medicao-do-primeiro-release.md` |
| SC-005 — 100% das rotas de dados recusam sem sessão | não funcional | sim | 19 de 21 devolvem 302 (as 2 restantes são públicas por desenho). **Reconferido nesta avaliação**: `/people /teams /organizations /work /syncs /accounts /roles` → **302 em todas** |

**Fase derivada**: `sro.accepted_deliverable` — **com ressalva nomeada** em AS1
(conformidade por leitura de código, sem execução no ambiente real).
**Fase da tarefa**: as tarefas T001–T007 produziram D4 (aceito) e D5 (dois
entregáveis não aceitos) — logo
`sro.non_successfully_performed_scrum_development_task`, pela regra de que uma
tarefa com vários entregáveis conta uma vez mesmo com um só recusado.

---

## D6 — A primeira conta nasce do ambiente

**Produzido por**: 052/T001–T006, T010–T014 · **sem issues no GitHub** (ver
"Lacunas de processo") · PR [#640](https://github.com/The-Band-Solution/theband/pull/640) ·
release v0.2.0 [#641](https://github.com/The-Band-Solution/theband/pull/641)
**Materializa**: 052/US1, 052/US2, 052/US3

### 052/US1 — Instalar sem console

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — sobe com as quatro variáveis, cria organização e admin, e o log diz e-mail e organização | funcional | sim | executado contra a **imagem real**: 1 organização e 1 admin, na ordem `migrações aplicadas.` → `primeira conta criada:` → `Running TheBandWeb.Endpoint` |
| AS2 — a pessoa entra com aquelas credenciais e tem poder de administração | funcional | sim | `POST /session` → 302; `/people` → 200 **com** a sessão e 302 sem. E em produção: a pessoa mantenedora entrou |
| AS3 — a senha NÃO aparece em nenhuma linha do log | funcional | sim | varredura do log da subida: **0 ocorrências**; testes "o retorno de sucesso não carrega a senha" e "o changeset de recusa não carrega a senha" |
| SC-001 — instala sem abrir console | não funcional | sim | a produção v0.2.0 nasceu assim, pelo painel |
| SC-003 — zero ocorrências da senha nos registros | não funcional | sim | mesma varredura |

**Fase derivada**: `sro.accepted_deliverable`.

### 052/US2 — Reiniciar não duplica nem sobrescreve

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — sobe de novo e nada é criado; o log diz que já existe administrador | funcional | sim | reinício contra a imagem real disse `já existe administrador` e manteve 1 admin |
| AS2 — a senha trocada pela interface continua valendo | funcional | sim | teste "a senha trocada pela interface sobrevive a cinco subidas (SC-005)" |
| AS3 — e-mail diferente não cria uma segunda conta | funcional | sim | teste "e-mail DIFERENTE também não cria um segundo" |
| SC-004 — dez subidas seguidas produzem **exatamente uma** pessoa com marca de administração | não funcional | **sim — medido nesta avaliação** | `bootstrap_sc004_test.exs`: dez chamadas → **1 administrador, 1 organização**, com `%{criada: 1, ja_existe: 9}` |
| SC-005 — a senha trocada sobrevive a cinco subidas | não funcional | sim | o teste homônimo |

**Fase derivada**: `sro.accepted_deliverable`.
**Achado desta avaliação, corrigido aqui**: as duas injeções feitas para provar o
teste do SC-004 encontraram um **teste fraco** no FR-005. Desligando a leitura da
corrida perdida — o perdedor passando a devolver `{:error, changeset}` em vez de
`{:ok, :ja_existe}` —, **os 16 testes continuavam verdes**: o teste da corrida
contava só o vencedor. O perdedor é justamente quem a FR-005 promete atender, e
numa segunda subida real ele é o caminho comum. A asserção do perdedor foi
acrescentada, e com ela a mesma injeção reprova (15/16).
**Nota**: até esta avaliação o SC-004 estava conforme *por argumento* — a unicidade
vinha de `unique_index(:tenants, [:slug])` e `unique_index(:users, [:email])`, e
o teste mais próximo exercia duas chamadas. Argumento não é evidência: o teste
das dez subidas foi escrito e executado aqui, e entra no repositório junto deste
registro.

### 052/US3 — A ausência é dita, e não derruba

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AS1 — sem nenhuma variável, a plataforma atende e o log nomeia as ausentes | funcional | sim | contra a imagem: o log nomeou as quatro e `/sign-in` respondeu **200** |
| AS2 — com três das quatro, nada é criado — nem organização órfã | funcional | sim | testes "falta parcial não deixa organização órfã" e "faltando duas variáveis, a lista traz as DUAS" |
| AS3 — valor recusado pelas regras do cadastro comum: nada é criado, o log diz qual regra recusou, e a plataforma sobe | funcional | sim | contra a imagem, com slug inválido: a recusa nomeou a regra e nada foi criado; testes de senha curta e slug com espaço |
| SC-006 — subir sem variável alguma mantém a plataforma respondendo, nomeando cada ausente | não funcional | sim | mesma execução |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase das tarefas 052**: `sro.successfully_performed_scrum_development_task`.

---

## D7 — A porta pública fala pela metáfora

**Produzido por**: PR [#637](https://github.com/The-Band-Solution/theband/pull/637) —
**sem tarefa e sem issue**
**Materializa**: **nenhuma user story do sprint backlog 026**

Copy da tela de entrada movida para o catálogo (7 msgids novos), três achados de
imagem corrigidos (o painel sumia em 390px), e o ensaio da imagem virando
executável.

**Fase derivada**: **não classificável por critérios** — não há user story, logo
não há critério de aceitação. Pelo axioma `sro.rule01`, entregável que não
materializa história do sprint backlog é escopo que entrou sem passar pelo
planejamento. **Registrado, não aceito nem recusado.**

---

## D8 — A barra não diz 100% enquanto a coleta ainda anda

**Produzido por**: PR [#642](https://github.com/The-Band-Solution/theband/pull/642) —
**sem tarefa e sem issue**
**Materializa**: **nenhuma user story do sprint backlog 026**

Correção nascida da própria produção: o denominador crescia junto com o
coletado, e a barra marcava 100% durante a coleta inteira; a fase de quadros não
tinha linha na tela. 14 gates verdes, 9/9 testes.

**Fase derivada**: **não classificável por critérios**, pela mesma razão de D7.
É defeito encontrado em produção — pela regra de roteamento seria `osdef.defect`,
e defeito não é user story.

---

## Critérios alterados durante o sprint

Nenhum. Os critérios avaliados são os que estavam escritos em `spec.md` no
fechamento — 050 desde 2026-08-30, 052 desde 2026-09-01.

## Critérios sem evidência

| Critério | User story | O que falta |
|---|---|---|
| AS4 — sessão sobrevive ao release | 050/US1 | abrir sessão, publicar um release, conferir que ela continua valendo |
| AS5 — janela de indisponibilidade curta | 050/US1 | cronometrar o próximo deploy |
| SC-001 — entrar e ver painel em menos de 2 min | 050/US1 | cronometrar o percurso completo, de fora |
| AS1 — cópia fora da máquina de produção | 050/US2 | conferir o destino do backup do Dokploy |
| AS2 — restauração em produção | 050/US2 | executar o ensaio contra o backup real (SC-003) |
| AS3 — falha de backup visível | 050/US2 | provocar a falha e ver o que aparece |
| SC-006 — 7 dias de rotina | 050/US2 | tempo: vence em 2026-09-08 |
| AS1 — seeds recusados no ambiente real | 050/US3 | executar o seed contra produção (só leitura da recusa) |

## Lacunas de processo

Nomeadas porque não se fecham sozinhas:

1. **A 052 inteira foi implementada sem issues no GitHub.** O ciclo foi
   `/speckit-specify` → `plan` → `tasks` → implementação, sem
   `/speckit-taskstoissues`. O commit cita `052/T001–T006, T010–T012, T014` — que
   são as tarefas do `tasks.md`, não issues. Consequência: essas tarefas não
   existem no board, e `flow.wip.count` subconta o sprint inteiro.
2. **A 052 não estava no sprint backlog 026.** Entrou no meio, e é a **exceção
   legítima** — corrige a P3 da 050 (*"a primeira conta não tem caminho no
   produto"*), e esperar o sprint seguinte manteria a produção inacessível. O que
   faltou foi **registrar a exceção nos riscos**, e não a exceção em si.
3. **Seis PRs foram mergeados sem revisor pedido**: #635, #637, #638, #639, #640
   e #642. Os três primeiros do sprint (#630, #631, #632) pediram revisão a duas
   pessoas, e **nenhuma revisou** — `reviews` vazio nos nove. Distinguindo o que
   a skill manda distinguir: não há **revisão registrada** em PR algum do sprint;
   nos seis sem pedido não houve nem pedido. Quem implementou foi o agente e a
   pessoa mantenedora figura como `author`, o que a torna revisora legítima — mas
   isso é **revisão atestada sem registro**, e o atestado não foi escrito.
4. **As issues #620–#629 seguem abertas.** É o correto pela DoD (encerrar após a
   aceitação) — e por isso o destino delas depende da confirmação deste registro.

## O que aconteceu com as issues, depois da confirmação

Executado em 2026-09-01, logo após a confirmação:

| Issue | Ação | Razão |
|---|---|---|
| #622 (050/US3) | **encerrada** | entregável aceito, com a ressalva do AS1 registrada no comentário |
| #623–#629 (050/T001–T007) | **encerradas** | tarefas executadas. A fase delas é `non_successfully_performed` porque alimentam o D5, e isso está escrito em cada comentário — encerrar a issue não apaga a fase |
| #620 (050/US1) | **segue aberta**, com destino | volta ao product backlog como tarefa nova de medição |
| #621 (050/US2) | **segue aberta**, primeira da fila do 027 | com o bloqueador nomeado: acesso ao painel do Dokploy |
| #648–#662 (052/T001–T015) | **criadas e encerradas** | registro retroativo da lacuna 1 abaixo. Cada uma diz que nasceu depois do trabalho — a data de abertura não mente por omissão |

A criação retroativa **não conserta** o que a lacuna custou: `flow.wip.count`
subcontou o sprint 026 enquanto ele corria, e isso é irrecuperável. O que ela
recupera é a rastreabilidade daqui para a frente.

## Destino das user stories

| User story | Issue | Destino |
|---|---|---|
| 050/US1 | [#620](https://github.com/The-Band-Solution/theband/issues/620) | volta ao product backlog — **tarefa nova de medição**, não reabertura |
| 050/US2 | [#621](https://github.com/The-Band-Solution/theband/issues/621) | **primeira da fila do sprint 027**, com bloqueador nomeado: acesso ao painel do Dokploy |
| 050/US3 | [#622](https://github.com/The-Band-Solution/theband/issues/622) | concluída — encerrar após a confirmação, com a ressalva do AS1 nas pendências |
| 052/US1–US3 | — (sem issue) | concluídas; a lacuna é a ausência das issues, registrada acima |
| 047/US1 | [#573](https://github.com/The-Band-Solution/theband/issues/573) | as duas tarefas de herança foram aceitas; a US pertence à 047 e é avaliada lá |
| 051/US2 | [#598](https://github.com/The-Band-Solution/theband/issues/598) | tarefa de herança aceita; encerrar #618 |
