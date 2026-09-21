<!-- Auditoria pontual. Fontes: `gh` contra The-Band-Solution/theband e a árvore de
     `origin/development` em df5875a (Merge PR #865), ambas lidas em 2026-09-13.
     Não é documento derivado com gerador: refazer é repetir o procedimento da §7. -->

# Issues abertas sem motivo — auditoria de 2026-09-13

**Papel**: Product Owner. **Entrega**: a lista com evidência. **Nada foi fechado** — a
decisão de fechar é de quem desempenha o papel.

**Régua**: uma issue só entra em "fechar" quando existe arquivo, teste ou registro em
`origin/development` que prove o trabalho feito. Issue sem essa prova fica em
*suspeitas* ou em *não verificado*, nunca em *fechar*.

---

## 1. O universo real, medido antes de opinar

O contexto recebido falava em "500+ issues". A contagem na origem, hoje:

| | Quantidade | Como foi medido |
|---|---:|---|
| issues no repositório | **625** | `search/issues?q=repo:…+is:issue` |
| abertas | **34** | mesma consulta com `is:open` |
| fechadas | **591** | mesma consulta com `is:closed` |

**O defeito do "Fecha #123" já foi limpo.** Das 34 abertas, **nenhuma** é issue de
tarefa `NNN/TXXX` de spec anterior à 064. As 354 issues que seguem a convenção estão
todas fechadas, exceto as 19 da 064 criadas hoje. A hipótese que motivou esta auditoria
— PRs em português que nunca fecharam nada — não tem resíduo aberto: se produziu órfãs,
elas foram fechadas à mão em algum momento.

Isso muda a pergunta. O problema deste backlog não é issue que devia fechar e não
fechou; é **trabalho entregue que nunca teve issue** (§6) e **issue criada sem lastro na
spec** (§5).

### As 34 abertas, separadas

| Grupo | Quantas | Veredito |
|---|---:|---|
| spec 064 — T001–T019, US1–US3, épico (#866–#888) | 23 | **corretamente abertas**, com uma ressalva em §5 |
| itens de produto e épicos anteriores | 11 | avaliadas uma a uma em §3 e §4 |

**A 064 confere.** `specs/064-segredo-em-repouso/tasks.md` traz T001 a T016 e **nenhuma
caixa marcada**; `lib/the_band/segredo.ex` e `test/the_band/segredo_test.exs` existem
porque vieram do PR #864, e o próprio `tasks.md` declara isso em vez de fingir tarefa:
*"Já mergeado no PR #864, e por isso ausente daqui"*. Nenhuma das 19 tarefas foi
implementada, e nenhuma é candidata a fechamento.

**Cuidado com um número**: o `#697` que aparece na spec 064 e no PR #864 é a **linha da
tabela `oban_jobs`** que foi redigida, não a issue #697 — que existe, é `055/T011: A
violação: o ciclo de comprimento 3`, e está fechada desde a feature 055. Fechar a issue
#697 por causa desse texto seria fechar a coisa errada pelo motivo certo.

---

## 2. Veredito

**Nenhuma das 34 issues abertas reúne evidência completa para fechamento.** Duas chegam
perto e estão em §4 com o item que falta nomeado. Três deveriam ser decididas — não
fechadas por trabalho feito, mas resolvidas porque não têm lastro (§5).

| # | Título curto | Veredito | Onde |
|---|---|---|---|
| #356 | T024 — custo real de uma rodada | continua aberta | §3.1 |
| #363 | competência como unidade do perfil | continua aberta | §3.2 |
| #397 | equipe composta por equipes | **suspeita** — metade entregue | §4.1 |
| #504 | ÉPICO dashboards da equipe | continua aberta | §3.3 |
| #507 | o painel da equipe | **suspeita** — escopo estreitado quase todo entregue | §4.2 |
| #526 | valores que o mapa não traduz | continua aberta | §3.4 |
| #568 | promover e rebaixar administrador | continua aberta | §3.5 |
| #620 | 050/US1 — endereço estável | continua aberta | §3.6 |
| #621 | 050/US2 — os dados sobrevivem | continua aberta | §3.7 |
| #801 | Oban para sem produzir erro | continua aberta | §3.8 |
| #802 | ÉPICO observabilidade da jornada | continua aberta | §3.9 |
| #882 #883 #884 | 064/T017–T019 — idade da credencial | **sem lastro na spec** | §5 |

---

## 3. As que continuam abertas, com a prova de que o trabalho não está feito

Ausência de evidência não é evidência de ausência — então cada linha abaixo traz uma
**afirmação positiva sobre o código**, e não "não achei nada".

### 3.1 · #356 — T024: medir o custo real de uma rodada

| O que a issue pede | O que a origem diz |
|---|---|
| rodada completa contra o provedor de verdade, número anotado na spec | `specs/027-geracao-mensal-de-perfis/tasks.md:227` — `- [ ] T024`, caixa vazia |
| `SC-002` confirmado ou corrigido junto com N | `specs/027-geracao-mensal-de-perfis/spec.md:195` ainda fixa o SC-002 sobre *"a base medida em 2026-08-16"*, e `:25` ainda cita **1,63 milhão** de tokens, que a própria spec declara superado |

**O bloqueio caiu, a medição não aconteceu.** A issue #454 — *"a rodada grava só metade
da conta"* — está **CLOSED em 2026-08-24**, e `lib/the_band/profiles/run_entry.ex:37-38`
tem `input_tokens` **e** `output_tokens`, agregados em `runs.ex:282-283` e exibidos em
`profile_run_live/index.ex:321-330`. O que falta é rodar e anotar, e isso não é código:
`tasks.md:279` diz por quê — *"é a única tarefa que produz um número que nenhum teste
produz"*.

### 3.2 · #363 — a competência como unidade do perfil

`priv/profiles/perfil_schema.json` continua na forma que a issue descreve como errada:

| A issue pede | O schema tem hoje |
|---|---|
| `competencias: [{area, itens: [{nome, evidencia: [{numero, titulo}]}]}]` | nenhuma chave `competencias` no arquivo |
| habilidade junto da tarefa que a materializa | `"habilidades"` na linha 20, `array` de `string`; `"destaques"` numa seção separada, linha 95 |
| evidência com número **e** título | linhas 131–137: `"evidencia"` é `array` de `integer`, com a descrição *"Task numbers present in the material"* |
| `recomendacoes` vira `observacoes` | `"recomendacoes"` continua na linha 218, e no `required` da linha 15 |

Quatro afirmações verificáveis, quatro negativas. A issue está intacta.

### 3.3 · #504 — ÉPICO: dashboards na tela da equipe

**As três dependências caíram, e o que dá nome ao épico não foi entregue.**

| Dependência | Estado |
|---|---|
| #505 — período de participação | **CLOSED** em 2026-08-26 |
| #506 — as perguntas do painel | **CLOSED** em 2026-09-01 |
| feature 042 — critério de início | **entregue**: `specs/042-criterio-de-inicio/tasks.md` com **24 de 24** marcadas, e as 24 issues #459–#482 todas fechadas |

E ainda assim o pedido literal do épico — *"Throughput da equipe, throughput
individual"* — **não existe em lugar nenhum do código**, e o código diz isso com todas
as letras:

- `lib/the_band/work_items/person_work.ex:101` — *"Não é `flow.throughput.rate`. Aquela
  medida exige critério de início declarado e fim…"*
- `lib/the_band_web/live/people_live/show.ex:768` — *"**This is not throughput**:
  throughput needs a declared start…"*
- `lib/the_band_web/live/teams_live/show.ex:1279` — *"'Working in progress' here is not
  `flow.wip.count`"*

A feature 042 declarou o critério; **ninguém escreveu a medida sobre ele**. Essa é a
diferença entre a dependência ter caído e o épico estar pronto, e ela não aparece em
nenhum registro do repositório — a última revisão do épico, em
`docs/sprints/029-medidas-da-equipe/sprint-review.md:253`, ainda dizia que a 042 estava
"sem código", o que deixou de ser verdade em 2026-09-04.

**Recomendação**: manter aberta e **corrigir o texto do épico**, que hoje cita três
bloqueios inexistentes. O bloqueio real passou a ser um só: `flow.throughput.rate` não
tem implementação.

### 3.4 · #526 — a tela dos valores que a origem devolveu e o mapa não traduz

A prova é o próprio código citando a issue como pendente:

> `lib/the_band/quality/verdict.ex:33` — *"A issue #526 é a tela que muda isso — com os
> valores não traduzidos visíveis, `keep_raw` passa a ser seguro."*

`priv/knowledge_base/mappings/github/qapo/review.yaml` continua com `unmapped: reject`, e
não há nenhum módulo de tela para valores fora do `value_map`. O
`lib/the_band/mapping/schemas/unmapped_pattern_decision.ex` que existe é outra coisa —
padrão de mapeamento não reconhecido, da feature 005 —, e confundi-lo com este fecharia a
issue sem que a tela existisse.

### 3.5 · #568 — promover, rebaixar, e o guarda do último admin

Três negativas, cada uma verificável:

| O que a issue promete | O que há |
|---|---|
| promover e rebaixar por administrador, com proveniência | `lib/the_band_web/live/accounts_live/index.ex` tem **16** `handle_event`, e nenhum toca em papel: criar, reset, filtrar, abrir/fechar busca, buscar pessoa, associar, revogar elo, e o par desativar/reativar |
| `/accounts` ganha os controles | a mesma tela só **lê** o papel — `:685` e `:688`, um `badge` quando `role == "admin"` e um `—` quando não |
| o guarda de FR-009 vira código testado | nenhuma ocorrência de guarda de último administrador em `lib` ou `test`; `lib/the_band/tenants/user.ex:97` casta `:role` só no changeset de criação |

O que a aceitação do sprint 023 registrou continua valendo palavra por palavra: o tenant
não fica sem admin porque **o vetor não existe**.

### 3.6 · #620 — 050/US1: a plataforma num endereço estável

Recusada em `docs/sprints/026-heranca-e-a-producao/aceitacao.md` por **três critérios sem
evidência** (AS4, AS5, SC-001) — e o registro de release mais recente confirma que
continuam sem:

> `docs/releases/v0.7.0.md:829` — *"**050/US1** — o endereço estável | AS4, SC-001,
> SC-002, SC-004 e SC-005 sem evidência, pela **terceira** release seguida"*

E um dos critérios **não se recupera**: `docs/releases/v0.6.0.md:646` registra que o AS4
*"exigia uma sessão aberta antes das 13:39Z"*. Fechar esta issue exigiria medir na
próxima release, não conferir código.

### 3.7 · #621 — 050/US2: os dados sobrevivem

A pendência mais antiga do produto, e a mais claramente documentada:

> `docs/releases/v0.7.0.md:911` — *"A **050/US2** segue **não aceita** por isso, e
> continua sendo a primeira pendência de produção."*
> `:828` — *"o §6 do runbook — o backup restaurado de verdade | **bloqueado em recurso**:
> a conta no destino S3 **não existe**"*

O que existe é ensaio de **migração** contra dado real —
`docs/producao/ensaio-2026-09-09-migracao-conta-desativada.md`. A própria v0.7.0 separa as
duas perguntas: *"a migração roda sobre dado real?"* — sim, medido; *"o backup existe de
verdade?"* — não, desde a v0.1.0. Tratá-las como a mesma fecharia a issue com a evidência
da outra.

**Bloqueador nomeado**: criar a conta no destino S3 é decisão de quem administra. Pelo
procedimento do papel, isso é o que libera trabalho novo — não fechamento.

### 3.8 · #801 — o Oban pode parar sem produzir erro nenhum

A issue pede três coisas. Duas continuam ausentes e a terceira foi entregue para outra
pergunta:

| O que fecharia | Estado |
|---|---|
| rota de saúde comparando `max(completed_at)` com o relógio | `lib/the_band_web/router.ex:60` tem **uma** rota nova, `get "/version"` — e `version_controller.ex` declara explicitamente que responde **só a versão**: *"Nada de ambiente, host, commit, dependências ou estado do banco"* |
| healthcheck do contêiner apontando para ela | `compose.yaml:24` continua `pg_isready -U postgres`, exatamente o que a issue aponta como cego |
| `/syncs` dizendo *"a fila não avança há X"* | nenhuma consulta dessa forma em `lib` |

A rota `/version`, entregue pelo PR #859 (achado H7), responde *"que versão está no ar"*.
A #801 pergunta *"a fila anda?"*. São perguntas diferentes sobre o mesmo silêncio.

### 3.9 · #802 — ÉPICO: observabilidade da jornada com OpenTelemetry

Zero ocorrências de `opentelemetry` ou `otel` em `mix.exs` e em `lib`. A issue declara que
exige **ADR antes de qualquer código**, e nenhum ADR foi aberto. Aberta com razão.

---

## 4. Suspeitas, com o item que falta nomeado

Estas duas têm a maior parte do trabalho em `development`. Nenhuma tem **tudo**, e por
`sro.rule03` a avaliação incompleta não classifica como pronta. Vão para decisão, com a
opção de fechar acompanhada do que se perde.

### 4.1 · #397 — equipe composta por equipes

Metade entregue, e a própria issue já registra isso num comentário de 2026-09-04. Confirmei
contra o código, e o diagnóstico se mantém:

| O que a issue pediu | Estado | Evidência |
|---|---|---|
| equipe formada por outras equipes, muitos-para-muitos | **entregue** | `priv/repo/migrations/20260901230000_composicao_de_equipes_e_o_equivoco.exs`; `lib/the_band/ontology/seon/eo/schemas/team_composition.ex` |
| aciclicidade, com recusa que **nomeia o caminho** | **entregue** | `eo/commands.ex:310-318` — `{:error, "isto fecharia um ciclo: " <> caminho}`; `test/…/team_composition_test.exs:32` — `describe "o ciclo é recusado (FR-009)"`, com o ciclo de comprimento 3 antes do de 2 |
| membro herdado **não** vira membership; o que sobe é a leitura | **entregue** | `eo/queries.ex:215` — `team_members_at/4` com `opts[:escopo]`, comentado como FR-056 da 060 |
| a tela da equipe composta | **entregue** | `teams_live/show.ex:2400-2485` — uma linha por subequipe, **sem total**; `test/the_band_web/live/equipe_composta_test.exs`, `subequipe_test.exs`, `detalhe_da_subequipe_test.exs` |
| **rollup das competências**, com o denominador dito na tela | **NÃO entregue** | `lib/the_band/profiles/team_skills.ex:276-281` — `membros/3` chama `EO.team_members_at(tenant, team_id, quando)` **sem** `:escopo`; e `teams_live/show.ex:4204` chama `Profiles.team_coverage(tenant, team.id)`, também sem. Nenhuma frase do tipo *"inclui N pessoas de M sub-equipes"* existe na tela |
| hierarquia **observada** (`parentTeam` do GitHub) | **NÃO entregue** | `priv/knowledge_base/mappings/github/eo/team.yaml:61` — *"a hierarquia é registrada como atributo e não como relação ontológica"* |

**O resíduo não é cosmético.** Numa equipe composta, o cabeçalho conta pessoas com alcance
da equipe inteira e a matriz de competências conta só os diretos — os dois números
aparecem no mesmo scroll, discordando. É a mesma classe de defeito que o QA achou em
2026-09-08 nos cartões de trabalho parado, e que a FR-056 da 060 corrigiu **para os outros
consumidores do vínculo, não para este**.

**Decisão a tomar**: fechar #397 e abrir uma issue só para o rollup, ou manter #397 aberta
com o escopo reduzido a ele. A primeira opção é mais limpa e custa uma issue nova; a
segunda mantém o histórico, ao custo de uma issue cujo título já não descreve o que falta.

### 4.2 · #507 — o painel da equipe

O escopo desta issue **foi estreitado por decisão registrada** no comentário de
2026-09-01, depois que a #506 foi respondida:

> *"o painel entrega **só o que calcula hoje** — `ci.pipeline_success_rate.ratio` e
> `review.time_to_first_review.duration`. As outras três medidas aparecem como **NÃO
> CALCULÁVEIS**, cada uma nomeando o que falta."*

Contra esse escopo, e não contra o texto original:

| Item do escopo estreitado | Estado | Evidência |
|---|---|---|
| `review.time_to_first_review.duration` na tela | **entregue** | `teams_live/show.ex:2674` e `:4309` — `Quality.team_time_to_first_review/3`; `test/…/teams_live/medidas_da_equipe_test.exs:226` — `describe "a espera por revisão (US1)"` |
| `ci.pipeline_success_rate.ratio` na tela | **entregue**, com a recusa nomeada | `show.ex:4407-4418` e a seção `id="taxa-do-pipeline"` em `:6018`; a recusa em `:6024-6029` — *"No rate for … This is not a rate of zero: zero would say the pipeline failed"*; teste em `medidas_da_equipe_test.exs:372` |
| `flow.wip.count` dita como não calculável | **entregue** | `show.ex:1279` |
| `flow.throughput.rate` dita como não calculável | **parcial** | dita na página da pessoa (`people_live/show.ex:768`), **não** na tela da equipe |
| `rework.not_accepted_deliverable_ratio` dita como não calculável | **NÃO entregue** | zero ocorrências de `rework` em `teams_live/show.ex` |

Sprint 029 entregou as três user stories da feature 058 —
`docs/sprints/029-medidas-da-equipe/sprint-review.md:9-24`, com #765, #766 e #767 fechadas
—, e o painel existe como aba `Dashboard` de `/teams/:id`.

**O que impede o fechamento**: a terceira medida não calculável nunca chegou à tela. A
decisão de 2026-09-01 dizia *"não como zero, e não omitidas"*, e ela está omitida. É um
critério, e critério sem evidência não está atendido.

**Recomendação**: não fechar ainda. É provavelmente a issue mais barata de fechar do
backlog — falta uma seção dizendo que o retrabalho não se calcula porque a aceitação só
existe em markdown, nos `aceitacao.md` dos sprints.

---

## 5. Criadas hoje sem lastro na spec — #882, #883, #884

**Não são candidatas a fechamento por trabalho feito.** São candidatas a decisão, e o
problema é de direção oposta: pedem tarefa que a spec não sustenta.

| Issue | Título | Fase que a issue declara |
|---|---|---|
| #882 | 064/T017: Saber a idade de cada credencial | *"Fase 5 — A idade da credencial (FR-016 a FR-019)"* |
| #883 | 064/T018: Pedir a troca na tela que administra | idem |
| #884 | 064/T019: Registrar a data da troca | idem |

Quatro divergências, todas verificáveis:

1. **`specs/064-segredo-em-repouso/tasks.md` vai de T001 a T016.** Não há T017, T018 nem
   T019 — e o `git log` do arquivo mostra **um único commit** (`acf1e34`, *"tasks(064): 16
   tarefas"*): a versão de 19 tarefas nunca existiu no repositório.
2. **A "Fase 5" do `tasks.md` é outra coisa** — *"O que fica escrito"*, com T015 e T016. Os
   números de fase colidem.
3. **`specs/064-segredo-em-repouso/spec.md` tem US1, US2 e US3, e para na FR-015.** Não há
   US4 nem FR-016 a FR-019. Pelo `sro.rule07`, tarefa se liga a user story atômica; estas
   três não se ligam a nenhuma.
4. **O `tasks.md` põe o tema fora de escopo**: *"A rotação do token do GitHub — ato
   operacional, adiado para 2026-10-12"*.

A justificativa nas três issues é a mesma e é legítima — *"Requisito da pessoa
mantenedora, 2026-09-13: pedir a troca da credencial a cada três meses"*. O requisito
existe; o que falta é o lastro.

**Duas saídas, e as duas são decisão sua:**

| Saída | O que implica |
|---|---|
| a spec 064 ganha US4 e FR-016 a FR-019, e o `tasks.md` ganha T017–T019 | as três issues passam a ter lastro e seguem abertas |
| as três são fechadas como *not planned* e o requisito vira item de backlog próprio | o pedido de 2026-09-13 não se perde, e a 064 fica do tamanho que a spec descreve |

O que **não** cabe é deixá-las como estão: são tarefas que nenhum `tasks.md` planeja e
nenhum entregável pode materializar, e enquanto existirem a 064 parece ter 19 tarefas
quando tem 16.

---

## 6. O achado lateral, e ele explica por que há tão pouca issue aberta

Procurando issue aberta sem trabalho, encontrei o contrário: **trabalho entregue sem issue
nenhuma.**

| Spec | `tasks.md` | Issues no GitHub |
|---|---|---|
| 057 — tela da equipe complexa | completo | 43 |
| 058 — medidas da equipe | completo | 25 |
| **060 — tela da equipe** | **29 de 29 marcadas** | **0** |
| 059, 061, 062, 063 | só `spec.md`, sem plano nem tarefas | 0 — esperado |

A feature **060** é a maior tela do produto, entregue e em produção pelas v0.6.0 e v0.7.0,
e **não existe no GitHub**. Nenhuma issue foi criada, logo nenhuma pode ser fechada, e o
Projects v2 nunca viu o sprint que a produziu. `flow.wip.count` subconta exatamente esse
trabalho, e o board mostra um produto mais parado do que ele está.

Isso também é o que faz esta auditoria devolver pouco: o backlog de issues abertas está
enxuto porque **parte do trabalho recente nunca entrou nele**. As issues de 059, 061, 062
e 063 não existem por razão legítima — são specs sem plano e sem tarefas. A da 060 não.

E há um resíduo de escopo que **nenhuma issue carrega**: os quatro gráficos por membro —
WIP, prometido × realizado, throughput e Monte Carlo — especificados em
`specs/060-tela-da-equipe/spec-graficos-por-membro.md` como US10 a US12, e declarados
ausentes em `docs/funcionalidades/tela-da-equipe.md:606-612`, *"sem protótipo aprovado — e
a casa não implementa tela sem ele"*. Hoje o único ponteiro para eles no GitHub é o épico
#504, que não fala deles. **Fechar #504 e #507 sem criar as issues da 060 apagaria esse
escopo do board.**

---

## 7. O que não consegui verificar

Cada linha é lacuna de prova, não conclusão.

| O que | Por quê | O que a fecharia |
|---|---|---|
| **o estado de cada issue no Projects v2** | não consultei o board — `Iteration`, `Status` e importância de nenhuma das 34 foram lidos | consulta GraphQL ao projeto, item a item |
| **os comentários das 23 issues da 064** | li apenas o corpo de #882–#884 e contei comentários das outras 11; pode haver decisão registrada em comentário que eu não abri | ler `comments` das 23 |
| **se a #620 foi medida fora do repositório** | a conclusão vem de `docs/releases/v0.7.0.md`. Se alguém cronometrou o AS4 ou o SC-001 e não registrou, eu não teria como saber — e *revisão atestada sem registro* é diferente de *não ocorreu* | a pessoa mantenedora afirmar, com data |
| **se o ensaio de restauração do §6 aconteceu fora do registro** | mesma razão, para a #621 | idem |
| **a intenção por trás de #882–#884** | vejo que o `tasks.md` nunca teve T017–T019; **não** vejo se foram criadas antes do `tasks.md` ser escrito, ou acrescentadas de propósito para capturar o pedido de hoje | quem as criou dizer qual dos dois |
| **se a matriz de competências realmente diverge do cabeçalho numa equipe composta** | a divergência é dedução de leitura do código, não observação na tela | abrir `/teams/:id` de uma equipe com subequipe e comparar os dois números |
| **se `flow.throughput.rate` existe em algum módulo que eu não grepei** | busquei por `throughput` em `lib` e achei só negações explícitas; uma implementação com outro nome escaparia | procurar pela fórmula na base de conhecimento e pelo consumidor dela |
| **releases e branches fora de `origin/development`** | tudo foi lido contra `df5875a`. Trabalho na `main` que não voltou por back-merge ficaria invisível aqui | `git log origin/main ^origin/development` |

---

## 8. O que proponho, em ordem

1. **#882, #883, #884** — decidir entre emendar a spec 064 ou fechar como *not planned*.
   É a única pendência desta auditoria que não depende de trabalho de ninguém, só de uma
   escolha, e enquanto durar a 064 tem dois tamanhos.
2. **#507** — escrever a seção que diz que `rework.not_accepted_deliverable_ratio` não se
   calcula, e então fechar. É o fechamento mais barato do backlog.
3. **#397** — escolher entre fechar e abrir uma issue para o rollup de competências, ou
   reduzir o escopo da própria #397 a ele.
4. **Criar as issues da feature 060**, ao menos das US10 a US12, antes de qualquer decisão
   sobre #504. Sem elas, fechar o épico apaga o escopo.
5. **Corrigir o texto do #504**, que cita três bloqueios já inexistentes e omite o único
   real: `flow.throughput.rate` não tem implementação.
6. **#620, #621, #801, #802, #568, #526, #363, #356** — nenhuma ação. Estão abertas pelo
   motivo certo, e a #621 com bloqueador nomeado: a conta no destino S3.
