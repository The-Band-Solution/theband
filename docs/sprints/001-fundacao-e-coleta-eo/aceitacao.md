# Sprint 001 — Registro de aceitação

**Feature**: [001-github-eo-ingestion](../../../specs/001-github-eo-ingestion/spec.md)
**Avaliado em**: 2026-08-10
**Papel**: Product Owner — **a confirmar por Paulo Sérgio dos Santos Júnior**

**Tipo de Product Owner**: `sro.product_owner_client` — a pessoa mantenedora é
também quem demanda. Consequência: a decisão de aceitação é **final**, não
representativa, e não carrega o risco residual de divergência com um cliente
ausente.

> **Este documento propõe; não decide.** O agente avaliou cada critério contra
> evidência e derivou a classificação que a evidência sustenta. A fase de cada
> entregável só passa a valer quando a pessoa alocada ao papel confirmar.

## Resumo proposto

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 3 |
| Critérios de aceitação percorridos | 14 funcionais + 10 não funcionais |
| Aceitos, após a correção de #88 | 3 |
| Não aceitos na primeira avaliação | 1 — D01 |
| Critérios sem evidência | 0 |
| Tarefas executadas sem sucesso | 2 — T033, T038 |

---

## D01 — Ferramenta conectada com credencial protegida

**Materializa**: US1 (atômica) · [#3](https://github.com/The-Band-Solution/theband/issues/3)
**Produzido por**: T032 a T040 · issues [#37](https://github.com/The-Band-Solution/theband/issues/37) a [#45](https://github.com/The-Band-Solution/theband/issues/45)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — admin conecta o GitHub informando instância e credencial válida; a plataforma confirma o acesso e registra a ferramenta | funcional | **sim** | três organizações conectadas contra o GitHub real: `The-Band-Solution`, `ifesserra-lab`, `leds-conectafapes`; escopos devolvidos `gist, project, read:org, repo, workflow` |
| AC2 — credencial inválida ou sem permissão é recusada com explicação, e nada é gravado | funcional | **sim** | execução com token inválido devolveu `:unauthorized`; contagem de ferramentas antes 1, depois 1. Testes `credencial recusada não grava nada` e `escopo insuficiente recusa nomeando o que falta` |
| AC3 — a credencial aparece apenas por identificação parcial, nunca em forma utilizável | funcional | **sim** | tela exibe `••••••••••••••••slKb`; token ausente do HTML das quatro telas; `select secret` devolve `AES.GCM.1ddcd36a$…`; teste garante que nenhuma mensagem de erro vaza struct |
| AC4 — duas contas de serviço no mesmo GitHub coexistem e podem ser **usadas ou desativadas independentemente** | funcional | **sim**, após correção | ver a reavaliação abaixo. Cinco testes em `test/the_band/sources_test.exs`: desativar a em uso faz a outra ser usada; reativar devolve à escolha; sem nenhuma ativa a sincronização é recusada com `:no_active_credential`; desativar uma não altera a outra |
| AC5 — credencial que deixou de funcionar marca a ferramenta como precisando de atenção, com data e motivo, sem interromper as demais | funcional | **sim** | teste `marcar uma não afeta as outras do tenant`; teste `credencial revogada durante a coleta` verifica `status = needs_attention`, `needs_attention_since` preenchido e a sincronização em `interrupted` com progresso preservado |

**Critérios não funcionais atribuídos a esta user story**

| Critério | Conforme | Evidência |
|---|---|---|
| SC-001 — conectar e validar em menos de 2 minutos, sem consultar documentação | **sim** | formulário de uma tela, com validação imediata e mensagem do que faltou |
| SC-005 — nenhuma credencial recuperável a partir da base, dos registros ou da interface | **sim** | as três verificações de AC3, mais a rotação de chave que provou o segredo intacto só com a chave nova |

### Primeira avaliação — 2026-08-10

**Fase derivada**: `sro.not_accepted_deliverable` — falhava em AC4.

**Confirmada pela pessoa mantenedora**: "D01 fica como não aceito."

**Fase das tarefas**: T033 e T038, que produziram o cadastro de credenciais e a
tela, ficam `sro.non_successfully_performed_scrum_development_task` —
permanentemente. Elas foram executadas e não produziram entregável aceito, e essa
é a informação que a medida `rework.not_accepted_deliverable_ratio` calcula.

**O que faltava**: verificação de que desativar uma credencial faz a coleta passar
a usar a outra. `Sources.active_credential/1` escolhia a ativa mais recente, então
o comportamento provavelmente existia — **provavelmente não é evidência**.

**Destino escolhido**: nova tarefa pretendida
[#88](https://github.com/The-Band-Solution/theband/issues/88), ligada à mesma
US1. T033 e T038 **não** foram reabertas.

### Reavaliação — 2026-08-10, após #88

A correção encontrou mais do que o teste que faltava.

**Um defeito latente.** `active_credential/1` ordenava apenas por
`validated_at`. Duas credenciais cadastradas **no mesmo segundo** — o caso normal
quando as duas entram pelo mesmo formulário ou por script — empatavam, e o banco
resolvia o empate na ordem que quisesse. O mesmo estado do banco podia escolher
credenciais diferentes entre execuções.

Isso importa porque credenciais diferentes enxergam conjuntos diferentes: a mesma
sincronização traria dados diferentes sem nada ter mudado na origem, e o registro
diria qual credencial foi usada sem dizer **por que aquela**.

Corrigido com dois critérios de desempate — instante de criação e identificador —
cuja função é tornar a escolha determinística, não expressar preferência.

**Lacuna de contrato corrigida no mesmo commit**, como o princípio VI exige: o
contrato `connected-tools.md` não dizia qual credencial era escolhida entre as
ativas. Agora diz, com a razão.

**Honestidade sobre a força da evidência**: o teste de determinismo repete a
consulta vinte vezes e obtém sempre a mesma credencial. Isso não **prova** que a
versão anterior era instável na prática — o Postgres pode ser estável por
acidente de plano de execução. O que se afirma é mais fraco e suficiente: sem
critério de desempate, a ordenação é indeterminada por semântica de SQL, e
depender de acidente de implementação não é garantia.

**Fase derivada agora**: `sro.accepted_deliverable` — os cinco critérios
funcionais e os dois não funcionais de US1 conformes, com evidência.

**A fase das tarefas não muda.** T033 e T038 continuam
`sro.non_successfully_performed_scrum_development_task`, e #88 é uma tarefa nova
bem-sucedida. O esforço aparece duas vezes porque foi gasto duas vezes.

---

## D02 — Quadro de pessoas e equipes coletado

**Materializa**: US2 (atômica) · [#4](https://github.com/The-Band-Solution/theband/issues/4)
**Produzido por**: T041 a T060c · issues [#46](https://github.com/The-Band-Solution/theband/issues/46) a [#65](https://github.com/The-Band-Solution/theband/issues/65)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — a sincronização faz a plataforma conhecer a organização, suas pessoas e suas equipes | funcional | **sim** | três organizações coletadas: 3 organizações observadas, 72 pessoas, 10 equipes, 62 vínculos. `leds-conectafapes` sozinha: 128 registros coletados, 71 criados |
| AC2 — a segunda sincronização não duplica nem altera registro cuja origem não mudou | funcional | **sim** | segunda execução: `criados 0, atualizados 0`; contagens inalteradas de 6 → 6 pessoas e 2 → 2 equipes na primeira organização |
| AC3 — sincronização interrompida retoma de onde parou | funcional | **sim** | teste de retomada: com checkpoint gravado, a execução seguinte pede `after: cursor-1` — a página **seguinte**, não a primeira |
| AC4 — conta de automação é registrada e classificada separadamente, sem contar como pessoa | funcional | **sim, com ressalva** | teste `conta de automação é classificada pelo __typename do payload` verifica `bot` classificado e fora da contagem de pessoas. **Ressalva**: nenhuma automação apareceu nas três organizações reais — automações: 0. O caminho está provado por fixture, não observado em dado real |
| AC5 — o vínculo pessoa-equipe é preservado com o nível de acesso observado, e permanece pendente de papel | funcional | **sim** | 62 vínculos pendentes; tela de integrantes exibe `MAINTAINER` e `MEMBER` na coluna rotulada **acesso na plataforma**, com o papel organizacional marcado como pendente |
| AC6 — ao perceber a proximidade do limite de uso, pausa e retoma sozinha, sem perder progresso e sem falhar | funcional | **sim, com ressalva** | teste com janela simulada apertada devolve `{:snooze, n}`, preserva o cursor e mantém a sincronização em andamento. **Ressalva**: o limite real do GitHub nunca foi atingido — 4.656 pontos restantes na maior coleta |

**Critérios não funcionais atribuídos a esta user story**

| Critério | Conforme | Evidência |
|---|---|---|
| SC-002 — 100% das pessoas e equipes da origem registradas | **sim** | conferido contra as três organizações |
| SC-003 — segunda sincronização cria 0 e altera 0 | **sim** | ver AC2 |
| SC-006 — retomada consulta no máximo uma página a mais | **sim** | ver AC3 |
| SC-007 — correção de mapeamento aplicada sem consultar a origem | **sim** | reprocessamento de 32 payloads: 0 criados, 0 atualizados, 32 sem mudança; o teste roda sem expectativa no Mox da borda HTTP, então qualquer chamada ao GitHub o derruba |
| SC-009 — organização com até 100 pessoas e 20 equipes conclui sem intervenção manual, **mesmo atingindo o limite** | **parcialmente** | o volume está dentro do enunciado e foi exercitado: 64 pessoas e 8 times concluíram sem intervenção. A cláusula "mesmo atingindo o limite" está coberta por teste, não por ocorrência real |
| SC-010 — vínculos pendentes de papel apresentados explicitamente | **sim** | `62` no relatório da sincronização e no cabeçalho de `/equipes` |

**Fase derivada**: `sro.accepted_deliverable` — todos os critérios funcionais
conformes, com evidência.

**Ressalvas que acompanham a aceitação**, e que não a impedem: AC4 e AC6 estão
provados por teste e não por ocorrência em dado real. É a diferença entre "o
código trata o caso" e "o caso aconteceu e foi tratado". Registrar aqui é o que
permite alguém adiante saber qual das duas coisas foi verificada.

---

## D03 — Consulta com proveniência

**Materializa**: US3 (atômica) · [#5](https://github.com/The-Band-Solution/theband/issues/5)
**Produzido por**: T061 a T068 · issues [#66](https://github.com/The-Band-Solution/theband/issues/66) a [#73](https://github.com/The-Band-Solution/theband/issues/73)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — a lista de pessoas mostra cada pessoa com sua origem, seu identificador na ferramenta e a data da coleta | funcional | **sim** | `/pessoas` exibe as 72 com `github`, `https://github.com`, o identificador do GitHub e `collected_at` |
| AC2 — a lista de equipes mostra cada equipe, quem a integra, e quantos vínculos estão sem papel | funcional | **sim** | `/equipes` exibe as 10 com origem e identificador; `/equipes/:id` exibe integrantes com acesso na plataforma e papel pendente; cabeçalho traz a contagem de pendentes |
| AC3 — o usuário vê exclusivamente dados da própria organização | funcional | **sim** | dois tenants povoados; sessão de `outra-org` mostra 0 pessoas e 0 equipes; id de equipe alheia devolve redirecionamento, não o registro; nove testes de interface cobrem o percurso |

**Critérios não funcionais atribuídos a esta user story**

| Critério | Conforme | Evidência |
|---|---|---|
| SC-004 — 100% dos registros exibem origem, identificador e data | **sim** | conferido nas 72 linhas |
| SC-008 — usuário de uma organização não visualiza dado de outra por nenhum caminho | **sim** | ver AC3 |

**Fase derivada**: `sro.accepted_deliverable`.

### Uma observação sobre AC1 que pertence ao registro

O critério pede "sua origem". Ele foi escrito quando havia **uma** organização
observada, e "origem" significava sistema e instância. Com três organizações,
`github / https://github.com` deixou de identificar de onde a pessoa veio — e o
critério, tal como redigido, **continua atendido**.

Isso não muda a aceitação de D03: o entregável faz o que o critério pede. Mas
registra que **o critério não pegou o defeito** que a feature 002 existe para
corrigir. É informação sobre a qualidade do critério, e a responsabilidade por
ela é deste papel.

---

## Entregável do sprint

`sro.sprint_deliverable_composed_of_accepted_deliverable` admite **apenas**
entregáveis aceitos.

| Momento | Composição |
|---|---|
| primeira avaliação | **D02 e D03** — D01 fora, por falha em AC4 |
| após #88 | **D01, D02 e D03** |

O registro guarda os dois momentos de propósito. Um sprint cujo entregável
precisou de correção para ficar completo é diferente de um que nasceu completo, e
apagar a primeira avaliação apagaria essa diferença — que é exatamente a medida de
retrabalho que o produto existe para calcular.

---

## Critérios alterados durante o sprint

Nenhum critério de aceitação foi alterado. Duas **tarefas** tiveram a redação
corrigida — T005 e T019 —, porque prometiam mais do que entregavam; nenhum
critério de user story mudou.

## Critérios sem evidência

**Nenhum.** Os 14 critérios funcionais e os 10 não funcionais foram avaliados
contra evidência.

Havia um — AC4 da US1 — e ele foi fechado por #88. O registro dessa passagem está
na reavaliação de D01, não apagado daqui.

### Duas verificações que continuam sendo por teste, e não por ocorrência

Não impedem aceitação, e ficam registradas para que ninguém adiante confunda uma
coisa com a outra:

| Critério | Por que não houve ocorrência real |
|---|---|
| AC4 de **US2** — automação classificada separadamente | nenhuma conta de automação existe nas três organizações observadas |
| AC6 de **US2** — pausa antes do limite de uso | o limite real nunca foi atingido; a maior coleta terminou com 4.656 pontos restantes |
| Edge case — ausência não é remoção | exigiria **remover alguém de uma equipe real** na organização da pessoa mantenedora. Não foi feito, e não deve ser: o teste cobre o comportamento, e alterar a organização de outra pessoa para validar software é preço que não se paga |

---

## O que a aceitação **não** destrava

Duas coisas distintas estão pendentes, e confundi-las faria o merge acontecer sem
o que a constituição exige:

| O quê | De quem | Onde |
|---|---|---|
| **aceitação dos entregáveis** | Product Owner — este documento | `aceitacao.md` |
| **revisão independente do código** | Reviewer, alguém que não implementou | aprovação do pull request |

O princípio VII fala da segunda.

Aceitar D02 e D03 não aprova o código deles. São perguntas diferentes: o PO
pergunta se o entregue atende ao especificado; o revisor pergunta se o código
está correto, seguro e conforme.

### O merge aconteceu, e a revisão independente não

**2026-08-10** — [PR #89](https://github.com/The-Band-Solution/theband/pull/89)
mergeado na `main` em `45d21a0`, por decisão da pessoa mantenedora, com o CI
verde.

**`GET /repos/.../pulls/89/reviews` devolve lista vazia**, e o mesmo vale para #90 e
#91. Nenhuma aprovação formal foi registrada em nenhum dos três.

### A revisão aconteceu; o registro é que não

**Atestado pela pessoa mantenedora em 2026-08-10**: *"eu olhei e concordei, por isso
não coloquei comentário."* A leitura do código ocorreu antes de cada merge. O que não
existe é a aprovação formal no GitHub.

Isso importa mais do que parece, porque **corrige um erro de leitura do princípio VII
que este documento propagou**. A versão anterior desta seção dizia que o autor do PR é
quem implementou, e concluía que a revisão não podia ter acontecido. Está errado:

| Papel | Quem é | Como o GitHub vê |
|---|---|---|
| **quem implementou** | o agente — os commits trazem `Co-Authored-By: Claude Opus 5` | não aparece; não tem conta |
| **quem revisou** | `paulossjunior`, que leu e concordou | registrado como **autor** do PR, porque o PR foi aberto com o token dele |

O `422 Review cannot be requested from pull request author` é, neste projeto, **um
artefato de ferramenta e não um conflito de interesse**. O GitHub não tem como
expressar que o implementador é um agente sem conta, então atribui a autoria a quem
operou a ferramenta — e depois impede essa pessoa de revisar o que ela não escreveu.

### O que continua sendo verdade

| Pergunta | Resposta | Evidência |
|---|---|---|
| o entregue atende ao especificado? | **sim** | este documento, 14 critérios funcionais e 10 não funcionais |
| os gates de qualidade passam? | **sim** | oito gates verdes, local e no CI |
| o código foi lido por um humano que não o escreveu? | **sim** | atestado da pessoa mantenedora, 2026-08-10 |
| existe aprovação registrada e verificável? | **não** | `pulls/{89,90,91}/reviews` vazios |
| o código está na `main`? | **sim** | `45d21a0`, `41b8636`, `82ce72f` |

A quarta linha é a lacuna real, e ela é diferente da que este documento afirmava
antes. **Não falta revisão — falta prova de revisão.** A distinção não é formalismo:
atestado depende de quem lembra, e registro não. Um projeto cuja tese é proveniência
não pode ter a própria revisão sustentada por memória.

### O que fecharia a lacuna

Três caminhos, em ordem de solidez:

| Caminho | O que muda |
|---|---|
| **abrir os PRs com identidade de agente** — bot ou GitHub App | o implementador passa a ser o autor de fato, e `paulossjunior` pode **aprovar formalmente**. Resolve a causa, não o sintoma |
| aprovação de `Adylla027` ou `EduardoNFraiz` | segundo humano revisando; hoje já é possível, desde que a equipe `the-band` recebeu acesso |
| registrar o atestado no próprio PR, como comentário | mais fraco, e ainda melhor que nada: fica datado e público em vez de conversado |

**Nada disso é recuperável para #89, #90 e #91**: PR mergeado não recebe review. O
atestado acima é o registro que esses três terão.

**O que o merge muda para os sprints seguintes**: a exceção que o sprint 002 assumiu
deixa de ser sobre código fora da `main` e passa a ser sobre código **dentro** dela com
revisão atestada e não registrada. O risco diminuiu — não desapareceu.

---

## Decisões que aguardam o papel

**1. Confirmar ou alterar a classificação proposta**

| Entregável | Proposto |
|---|---|
| D01 — ferramenta conectada | **não aceito** — AC4 sem evidência |
| D02 — quadro coletado | aceito, com duas ressalvas registradas |
| D03 — consulta com proveniência | aceito |

**2. Destino da US1, se D01 for confirmado como não aceito**

| Opção | Quando cabe | O que acontece |
|---|---|---|
| volta ao product backlog | o valor continua de pé, sem urgência | sai da iteration, repriorizada por importância |
| entra no sprint 002 | a lacuna é pequena e vale fechar já | **nova** tarefa pretendida ligada à US1, no sprint backlog 002 |
| aceitar com a lacuna registrada | a independência de credenciais não é usada hoje | exige alterar a decisão de aceitação de forma explícita, não silenciosa |

A segunda parece a mais barata: falta um teste, não uma funcionalidade. Mas a
escolha é do papel.

**Não reabrir T033 nem T038.** Elas permaneceram executadas e sem sucesso;
reabri-las apagaria o registro de retrabalho, que é justamente o que a medida
`rework.not_accepted_deliverable_ratio` calcula. Nova tarefa pretendida, ligada à
mesma user story.
