# Tarefas: o servidor MCP — as perguntas da equipe, respondidas a um agente

**Feature**: 062 · **Branch**: `062-servidor-mcp` · **Data**: 2026-09-22 · **Reconciliado**: 2026-09-24

**Entrada**: [`plan.md`](./plan.md) · [`spec.md`](./spec.md) ·
[`research.md`](./research.md) · [`data-model.md`](./data-model.md) ·
[`contracts/ferramentas.md`](./contracts/ferramentas.md) ·
[`quickstart.md`](./quickstart.md) · [`seguranca.md`](./seguranca.md)

---

## Reconciliado contra o código em 2026-09-24

Estas tarefas foram escritas em 2026-09-22, e no dia seguinte o #936 e o #938 **resolveram na
061** os dois achados altos que definiam o tamanho da fatia. A reconciliação
(`/speckit-analyze`, 2026-09-24) mediu o que existe e trocou cinco tarefas:

| # | O que as tarefas diziam | O que existe | O que mudou aqui |
|---|---|---|---|
| **A1** | nenhuma leitura bem-sucedida é registrada | `TheBandWeb.Plugs.ApiReadLog` na pipeline `:api_autenticada`, a tabela `api_access_reads`, `ApiAccessLog.uso_por_rota/3` e o painel do #939 | T021 **herda** o registro, em vez de criá-lo. T023 foi **removida**, porque a falta da API HTTP já foi consertada |
| **A2** | não há limite de taxa na 061 | `TheBandWeb.Plugs.ApiRateLimit`: 120 por minuto por token, com janela deslizante | T024 vira **teste do limite compartilhado**. T025 foi **removida**, porque a alternativa dela deixou de existir |
| **A6** | *(novo)* | o registro grava `route` pelo molde da rota e `target_id` por `params["id"]`. No MCP, as duas coisas saem vazias | T021 |
| **A7** | *(novo)* | o registro grava todo status `2xx`, e a recusa do MCP sai em `200` | T022 |
| **A3** | injeção de instrução pelo conteúdo | sem mudança | US1, T014 |

**A6 e A7 exigem mexer no `ApiReadLog`**, que é código da 061 **em produção**. A mudança é
pequena, mas passa a fazer parte desta fatia, e está dita aqui para que ninguém a descubra no
diff.

**A autoavaliação continua sendo autoavaliação.** Ver T009: a revisão independente vem antes
de qualquer código.

---

## Fase 1 — Preparação

- [ ] **T009** Obter a revisão independente do desenho reconciliado
  - **Pronta quando**: a reconciliação de 2026-09-24 commitada
  - **Descrição**: o agente `security` avalia `spec.md`, `plan.md`, `seguranca.md` e
    `contracts/`, **e o código que o desenho reusa**: `api_read_log.ex`, `api_rate_limit.ex`,
    `api_auth.ex` e `access.ex`. A autoavaliação de 2026-09-22 errou justamente onde importava:
    não viu que a recusa do MCP seria gravada como leitura (A7). É a lacuna I4, e o princípio
    VII
  - **Feita quando**: a avaliação está escrita por quem não escreveu o desenho, e cada
    achado alto virou tarefa. Se falhar de novo, a lacuna é **declarada** no `seguranca.md`,
    e nunca marcada como cumprida
  - **Teste**: revisão. O documento nomeia quem avaliou e o que leu

- [ ] **T001** Travar a dependência do protocolo
  - **Pronta quando**: T009 concluída ou declarada impossível
  - **Descrição**: acrescentar `{:ex_mcp, "~> 1.5"}` a `mix.exs`, com o comentário dizendo
    **por que esta e não as outras** — research.md D1: `hermes_mcp` não publica desde
    2025-08, `fastest_mcp` está em 0.x e tem 586 downloads. É a **única** dependência nova
    da feature. **A cadência também vai no comentário**: 1.3.0 em 05/09, 1.4.0 em 17/09,
    1.5.0 em 21/09. Uma versão a cada ~7 dias, e o `~> 1.5` aceita as próximas 1.x. Quem
    atualizar o `mix.lock` precisa saber que vai puxar uma biblioteca em movimento
  - **Feita quando**: `mix deps.get` resolve; `mix.lock` registra a versão; o comentário no
    `mix.exs` nomeia o que fica pior (biblioteca jovem e em movimento) e a mitigação (camada
    fina)
  - **Teste**: `mix deps.get && mix compile --warnings-as-errors` — e `mix hex.audit` sem
    aviso novo

- [ ] **T002** Criar o esqueleto do contexto MCP
  - **Pronta quando**: T001 concluída
  - **Descrição**: `lib/the_band/mcp/` com `ferramentas.ex`, `envelope.ex` e `ausencia.ex`
    vazios mas com `@moduledoc` dizendo a responsabilidade de cada um. A separação entre
    `lib/the_band/mcp/` (as respostas) e `lib/the_band_web/` (o transporte) é o que torna a
    troca de biblioteca um trabalho de adaptador — plan.md, *Structure Decision*
  - **Feita quando**: os três módulos compilam; nenhum deles referencia `TheBandWeb`
  - **Teste**: `test/the_band/mcp/fronteira_test.exs` — primeira asserção: nenhum módulo de
    `lib/the_band/mcp/` referencia `TheBandWeb`

---

## Fase 2 — Fundação (bloqueia todas as histórias)

- [ ] **T003** Expor a medida da base de conhecimento
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `KnowledgeBase` expõe `rule/1`, `mapping/1`, `axiom/1` e `list/1`, e
    **não expõe `measurement/1`** — o `fetch/2` é privado. Acrescentar a função pública em
    `lib/the_band/ontology/knowledge_base.ex`. É pré-requisito da FR-011: sem ela não há de
    onde tirar `limitations` e `misinterpretations`
  - **Feita quando**: `KnowledgeBase.measurement(id)` devolve `{:ok, mapa}` para uma medida
    que existe e `:error` para uma que não; o `@spec` acompanha as irmãs
  - **Teste**: `test/the_band/ontology/knowledge_base_test.exs` — a medida
    `flow.per_person.readings` volta com `misinterpretations` **não vazia**, porque uma
    função que devolvesse sempre `[]` passaria num teste que só checasse a chave

- [ ] **T004** Montar o envelope de proveniência
  - **Pronta quando**: T003 concluída; `data-model.md` escrito
  - **Descrição**: `lib/the_band/mcp/envelope.ex` monta `value`, `composition`, `window`,
    `origin`, `rule`, `measurement_id`, `limitations`, `misinterpretations` e `collected_at`.
    **`rule` é `nil` para medida** — o schema de `measurement` não tem `version`, e inventar
    uma afirmaria versionamento que a base não declara. **`window: nil` é dito, não omitido**
  - **Feita quando**: o envelope de uma medida traz `limitations` não vazia lida da base;
    `rule` vem preenchido só quando a origem é regra; `window: nil` aparece como chave
  - **Teste**: `test/the_band/mcp/envelope_test.exs` — percorre **todas** as ferramentas
    registradas (SC-001), e ao menos uma tem de trazer `misinterpretations` não vazia; se
    todas vierem `[]`, o teste passou sem ler a base

- [ ] **T005** Nomear os três estados da ausência
  - **Pronta quando**: T002 concluída
  - **Descrição**: `lib/the_band/mcp/ausencia.ex` com `:conferido_e_nada`, `:nao_conferido`
    (carregando **o que falta**) e `:recusado` (carregando **a razão**). No protocolo saem em
    campo `state` próprio — `checked`, `not_checked`, `refused` —, e **nunca pelo valor**.
    FR-012, e o defeito que ela impede tem nove ocorrências registradas nesta casa
  - **Feita quando**: os três são distinguíveis sem olhar `value`; `not_checked` não compila
    sem `missing`; `refused` não compila sem `reason`
  - **Teste**: `test/the_band/mcp/ausencia_test.exs` — os três aparecem na execução, e
    `checked` com `value: 0` é o **único** caso em que zero é resposta

- [ ] **T006** Abrir o registro de ferramentas
  - **Pronta quando**: T002 concluída
  - **Descrição**: `lib/the_band/mcp/ferramentas.ex` com a **lista fechada**, casada uma a
    uma. Nenhuma ferramenta genérica, nenhum filtro livre, nenhum campo de ordenação vindo
    de argumento — FR-023. O protocolo exige `tools/list`, e é o registro que o responde
  - **Feita quando**: `Ferramentas.listar/0` devolve as quatro; acrescentar uma sem entrada
    no registro não a torna alcançável; **cada entrada nomeia o id da pergunta de competência**
    que responde (FR-020)
  - **Teste**: `test/the_band_web/mcp/protocolo_test.exs` — `tools/list` devolve
    exatamente `team_roster`, `team_open_work`, `team_review_wait` e `team_stale_work`. E
    `test/the_band/mcp/ferramentas_test.exs`: o id de pergunta de cada uma **existe na base de
    conhecimento**. Ferramenta sem pergunta declarada, ou com id que a base não tem, reprova
    nomeando a ferramenta. É o que impede inventar ferramenta que a base não declara

- [ ] **T007** Servir o MCP autenticado
  - **Pronta quando**: T006 concluída
  - **Descrição**: escopo `/mcp` em `lib/the_band_web/router.ex`, com
    `pipe_through [:api, :api_autenticada]`, **a mesma pipeline** de `/api/v1`, e não só o
    `ApiAuth`. A pipeline autentica, limita e registra, nessa ordem. Pôr só o `ApiAuth` deixaria
    o MCP sem limite e sem registro, e nada reprovaria. O tenant vem da linha do token, nunca
    de argumento (FR-002); o alcance é recomputado a cada chamada e nada é guardado (FR-003)
  - **Feita quando**: chamada sem token é recusada com o `401` do formato único; o tenant e a
    conta dona vêm do token; nenhum estado sobrevive entre chamadas; `/mcp` passa pelos três
    plugs
  - **Teste**: `test/the_band_web/mcp/protocolo_test.exs` — sem cabeçalho `Authorization`,
    a chamada não alcança ferramenta alguma; um argumento `tenant_id` é **ignorado**, não
    obedecido; e a rota `/mcp`, lida na tabela do roteador, tem `ApiRateLimit` e `ApiReadLog`
    na pipeline. O controle é o plug, e não o nome da pipeline

- [ ] **T008** Guardar a fronteira do banco
  - **Pronta quando**: T002 concluída
  - **Descrição**: teste que varre `lib/the_band/mcp/` e reprova se algum módulo referenciar
    `TheBand.Repo` ou `Ecto.Query`. É o que torna a extração posterior um **mover** e não um
    reescrever (research.md D2). **Ler o fonte com comentários e `@moduledoc` removidos** —
    a prosa que explica a proibição contém as palavras proibidas, e isso já reprovou duas
    vezes neste repositório
  - **Feita quando**: o teste passa com os módulos atuais; acrescentar `alias TheBand.Repo`
    a qualquer um deles o faz reprovar, nomeando o arquivo
  - **Teste**: `test/the_band/mcp/fronteira_test.exs` — provado com o defeito injetado:
    inserir `Repo` num módulo e ver reprovar, depois restaurar

---

## Fase 3 — US1 (P1): o agente responde sobre a equipe sem perder a ressalva

**Objetivo**: as quatro perguntas da tela da equipe, respondidas com a proveniência no
mesmo objeto.

**Teste independente**: um cliente MCP lista as quatro ferramentas, chama cada uma sobre uma
equipe real, e **consegue dizer a ressalva** a partir do que recebeu — sem segunda chamada.

- [ ] **T010** [P] [US1] Responder quem está na equipe
  - **Pronta quando**: T004, T005, T006 concluídas; `contracts/ferramentas.md` escrito
  - **Descrição**: `lib/the_band/mcp/ferramentas/team_roster.ex`, chamando `EO` — nunca o
    `Repo`. `origin` vive no **vínculo**, não na pessoa: alguém pode ser observado numa
    equipe e declarado noutra, e as duas afirmações valem ao mesmo tempo. `current`, `left`
    e `mistakes` **não se somam**. A composição declara o alcance: a equipe **mais** as
    partes vigentes
  - **Feita quando**: uma equipe composta devolve o roster da equipe e das partes; os três
    números vêm separados, sem total; `origin` aparece por vínculo e fala inglês
  - **Teste**: `test/the_band/mcp/ferramentas_test.exs` — exercita a função **sem** subir a
    biblioteca MCP, e afirma que `origin` de dois vínculos da mesma pessoa pode divergir

- [ ] **T011** [P] [US1] Responder o que cada um tem aberto
  - **Pronta quando**: T004, T005, T006 concluídas
  - **Descrição**: `team_open_work.ex`, chamando `TeamWork`. **Pessoa sem tarefa aberta não
    vira linha com zero**: ela não aparece em `by_person`, e `totals.members` diz quantas
    existem. Somar as duas leituras responderia outra pergunta
  - **Feita quando**: pessoa sem tarefa está ausente da lista e presente na contagem de
    membros; cada tarefa traz idade em dias e a marca de parada
  - **Teste**: `test/the_band/mcp/ferramentas_test.exs` — uma equipe com membro sem tarefa
    aberta: o membro **não** aparece em `by_person`, e `totals.members` o conta

- [ ] **T012** [P] [US1] Responder a espera por revisão
  - **Pronta quando**: T004, T005, T006 concluídas
  - **Descrição**: `team_review_wait.ex`, chamando `Quality`. **Duas leituras, nunca
    somadas**: `reviewed` em horas e `waiting` em dias, cada uma com o seu denominador.
    Omitir as em curso faria a mediana **melhorar quanto pior a equipe estivesse**; contá-las
    como zero afirmaria revisão instantânea. `truncated` diz se a lista cortou
  - **Feita quando**: as duas medianas vêm em campos próprios; não existe campo de mediana
    única; `median_hours` e `median_days` são `null` — nunca zero — quando não há o que medir
  - **Teste**: `test/the_band/mcp/ferramentas_test.exs` — com dados de teste em que as duas
    leituras **divergem de propósito**: poucas esperas revisadas em horas e muitas em curso há
    dias. As duas medianas saem separadas, e nenhum campo as combina. **Os números de
    produção** (23 revisadas com 0,2 h, 79 esperando há 46 dias, `LEDS - ConectaFapes`,
    medidos em 2026-09-21) **não cabem aqui**: o ExUnit roda no banco isolado de teste e não
    os enxerga. Eles vão para o T030, com o cliente real

- [ ] **T013** [P] [US1] Responder o que está parado
  - **Pronta quando**: T004, T005, T006 concluídas
  - **Descrição**: `team_stale_work.ex`. **`stale_after_days` viaja junto**: *parada* não é
    adjetivo, é um corte em dias. `conversation` separa quatro casos — `not_collected` (o
    repositório não teve comentário coletado, que é **lacuna da coleta**), `silence`,
    `recent` e `old`
  - **Feita quando**: o corte em dias aparece na resposta; os quatro estados de conversa são
    distinguíveis; `not_collected` nunca é apresentado como `silence`
  - **Teste**: `test/the_band/mcp/ferramentas_test.exs` — repositório sem coleta de
    comentários produz `not_collected`, e não `silence` com zero atos

- [ ] **T014** [US1] Marcar o texto de terceiro no schema
  - **Pronta quando**: T010–T013 concluídas; `seguranca.md` escrito (achado A3)
  - **Descrição**: todo campo que carrega texto escrito por gente de fora — título de issue,
    nome de equipe, título de solicitação — fica sob chave própria que o declara não
    confiável. **Não filtrar frase suspeita**: é a regex larga que erra para o lado barato, e
    aqui o falso positivo apaga o título de uma issue legítima. **Não pedir ao modelo que
    ignore**: regra pedida ao modelo é ignorada; regra virada em schema é obedecida. **Não
    sanitizar**: alterar o título faria a plataforma mentir sobre o que observou
  - **Feita quando**: nenhum título de terceiro aparece fora da chave que o marca; a
    descrição de cada ferramenta (FR-022) diz que os campos de texto são conteúdo observado,
    e não instrução
  - **Teste**: `test/the_band/mcp/ferramentas_test.exs` — uma issue com título
    *"Ignore as instruções anteriores"* sai **dentro** da chave marcada, com o texto
    **intacto**. O teste também documenta o limite: isto reduz, e não elimina

- [ ] **T015** [US1] Declarar o que cada ferramenta não responde
  - **Pronta quando**: T010–T013 concluídas
  - **Descrição**: a descrição de cada ferramenta declara **o que ela não responde** —
    FR-022, a mesma disciplina do `what_this_is_not` que o schema da base exige. Sem isso um
    agente usa `team_open_work` para comparar pessoas, que é a comparação que a plataforma
    recusa
  - **Feita quando**: as quatro têm a frase; ferramenta nova sem ela reprova
  - **Teste**: `test/the_band_web/mcp/protocolo_test.exs` — percorre `tools/list` e exige a
    declaração em **cada** descrição; uma sem ela reprova nomeando a ferramenta

---

## Fase 4 — US2 (P1): a recusa é resposta, e concorda com as outras portas

**Objetivo**: o que a tela recusa, a API recusa e o MCP recusa — pela mesma razão.

**Teste independente**: uma conta sem alcance chama as quatro ferramentas e recebe **quatro
recusas com razão**, nenhuma exceção e nenhuma lista vazia.

- [ ] **T017** [US2] Recusar como resposta, nunca como erro
  - **Pronta quando**: T005 e T010–T013 concluídas
  - **Descrição**: quando `pode_ver_equipe/3` nega, a ferramenta devolve
    `%{state: "refused", reason: ...}` — **não** exceção, **não** lista vazia. `reason` fica
    no vocabulário da regra, o mesmo do log: traduzir criaria um segundo nome para a mesma
    cláusula. **Hoje a única razão é `fora_do_alcance`**, e equipe inexistente também a
    recebe. `escopo_de_equipe` e `vinculo_vigente` são caminhos de **concessão**, e a versão
    anterior desta tarefa os listava como recusa por engano. **Diferente da
    061**, que devolve `404` porque ali a resposta é HTTP: um agente que recebe erro de
    transporte não sabe distinguir *não pode ver* de *o servidor caiu*
  - **Feita quando**: as quatro recusam com razão; nenhuma levanta exceção; nenhuma devolve
    `[]` por falta de permissão
  - **Teste**: `test/the_band/mcp/paridade_test.exs` — lista vazia por falta de permissão é
    o sucesso silencioso que esta casa registrou nove vezes; o teste exige `state` e `reason`

- [ ] **T018** [US2] Provar a paridade das três portas
  - **Pronta quando**: T017 concluída
  - **Descrição**: para os **quatro** caminhos de `pode_ver_equipe/3` — `admin`,
    `escopo_de_equipe`, `escopo_da_organizacao`, `vinculo_vigente` — e para
    `fora_do_alcance`, a tela, a API e o MCP concordam. SC-004. Três portas para o mesmo dado
    com três respostas é o mesmo furo contado três vezes
  - **Feita quando**: os cinco vereditos são exercidos nas três portas; nenhuma concede onde
    outra nega
  - **Teste**: `test/the_band/mcp/paridade_test.exs` — e a guarda contra o teste vazio: ao
    menos um caminho tem de **conceder**, senão "todas negam" passaria com as três quebradas

- [ ] **T019** [US2] Recusar token revogado na chamada seguinte
  - **Pronta quando**: T007 concluída
  - **Descrição**: SC-006. Sem cache, herdado da Q3 da 061. A revogação vale na próxima
    chamada, sem reiniciar nada — e o servidor **não guarda o token** entre chamadas (FR-006)
  - **Feita quando**: revogar o token faz a chamada seguinte recusar; nenhuma cópia do token
    sobrevive em memória entre chamadas
  - **Teste**: `test/the_band_web/mcp/protocolo_test.exs` — chamada aceita, revogação,
    chamada recusada, na mesma execução

---

## Fase 5 — US3 (P1): a leitura fica registrada, e o abuso é detectável

**Objetivo**: o MCP herda o registro e o limite que a 061 já tem, **e o registro passa a
enxergar o MCP**. Sem o T021 e o T022, o MCP passaria pela pipeline e o registro gravaria
linhas que não dizem nada, ou pior: diriam que uma recusa foi leitura.

**Teste independente**: depois de N chamadas, é possível responder *"esta credencial leu o
painel de qual equipe, por qual ferramenta, e quantas vezes?"*. E nenhuma recusa aparece como
leitura.

> **Reescrita em 2026-09-24.** A versão de 2026-09-22 mandava **criar** o registro e o limite.
> Os dois foram criados na 061 pelo #936 e pelo #938, antes de a 062 começar. As tarefas antigas
> teriam produzido um segundo registro e um segundo limite para o mesmo token.

- [ ] **T021** [US3] Fazer o registro enxergar a ferramenta e o alvo
  - **Pronta quando**: T007 concluída
  - **Descrição**: o `ApiReadLog` grava `route` pelo **molde da rota** do Phoenix e
    `target_id` por `params["id"]` (`lib/the_band_web/plugs/api_read_log.ex:60-80`). No MCP,
    toda chamada é `POST /mcp`, e a ferramenta e o `team_id` vão **no corpo JSON-RPC**. Sem
    esta tarefa, toda linha sai com `route: "/mcp"` e `target_id: nil`, e o painel do #939
    mostra uma linha só. É o achado **A6**.

    O conserto: a camada MCP escreve a ferramenta e o alvo em `conn.private`
    (`:api_read_route`, `:api_read_target`), e o `ApiReadLog` **prefere esses valores** quando
    existirem. `route` vira `mcp:team_roster`, e `target_id` é o `team_id`. Mexe em código da
    061 em produção, e por isso as rotas de `/api/v1` precisam continuar gravando exatamente o
    que gravam hoje.

    `initialize`, `tools/list` e as notificações **não são leitura de dado** e não marcam
    `conn.private`. Decidir aqui se elas deixam de ser gravadas ou se entram como
    `mcp:protocolo`, e **escrever a decisão**
  - **Feita quando**: uma chamada de `team_roster` sobre a equipe X deixa uma linha com
    `route: "mcp:team_roster"` e `target_id` = X; as rotas de `/api/v1` gravam o mesmo que
    antes; o corpo da resposta e o segredo do token não aparecem na linha
  - **Teste**: `test/the_band_web/mcp/registro_test.exs` — três chamadas de ferramentas
    diferentes sobre equipes diferentes produzem três linhas **distintas** em `route` e em
    `target_id`. E `test/the_band_web/plugs/api_read_log_test.exs` continua verde **sem
    alteração**, que é a prova de que a 061 não mudou

- [ ] **T022** [US3] A recusa não é gravada como leitura
  - **Pronta quando**: T017 e T021 concluídas
  - **Descrição**: o `ApiReadLog` grava todo status `2xx`, e pela FR-013 a recusa do MCP sai
    em `200`, como resultado de ferramenta. Sem esta tarefa, o registro afirma que a
    credencial **leu** a equipe que lhe foi **negada**. É o contrário do fato, com a forma de
    registro. É o achado **A7**.

    O conserto: o registro do MCP exige **marca explícita de concessão** em `conn.private`,
    escrita só quando o veredito concede. Sem marca, não há linha. A recusa vai para
    `AccessEvents`. `painel_recusado/4` é por **pessoa**, então a recusa de **equipe** precisa
    de evento próprio ou de generalização. Decidir aqui, e escrever por quê
  - **Feita quando**: uma recusa não deixa linha em `api_access_reads` e deixa um evento de
    recusa com o `team_id` e a razão; uma concessão deixa a linha e nenhum evento de recusa
  - **Teste**: `test/the_band_web/mcp/registro_test.exs` — uma conta fora do alcance chama
    `team_roster`: zero linhas de leitura, um evento de recusa. **Guarda contra o teste
    vazio**: na mesma execução, uma conta com alcance chama e deixa **uma** linha. Senão
    "nenhuma linha" passaria com o registro desligado

- ~~**T023**~~ — *removida em 2026-09-24.* Mandava levar ao backlog a falta de registro da
  API HTTP. A falta foi consertada no #936, e o item seria backlog de algo já entregue.

- [ ] **T024** [US3] Provar que o limite é um só por token
  - **Pronta quando**: T007 concluída
  - **Descrição**: o `ApiRateLimit` conta por token, 120 por minuto, em janela deslizante
    (`api.access.thresholds`, regra `rate_limit`). A Q4 decidia *"o limite é o da 061"*, e
    agora isso é verdade **se** `/mcp` passar pela mesma pipeline. O teste prova que as duas
    portas gastam o **mesmo** limite. Dois limites dariam ao mesmo token o dobro da vazão, e
    duas respostas para *"por que recusou"*
  - **Feita quando**: chamadas alternadas entre `/api/v1` e `/mcp` com o mesmo token esgotam
    **um** limite; a recusa em `/mcp` é o `429` do formato único, com limite, janela e
    reabertura, na camada HTTP e não como erro JSON-RPC
  - **Teste**: `test/the_band_web/mcp/limite_test.exs` — com um limite pequeno configurado no
    teste: metade das chamadas por `/api/v1` e metade por `/mcp`, e a chamada N+1, em
    qualquer das duas portas, é recusada. **Guarda**: um segundo token, na mesma execução,
    **não** é recusado. Senão o teste passaria com um limite global

- ~~**T025**~~ — *removida em 2026-09-24.* Era a alternativa ao T024 caso não houvesse limite
  ("declarar a ausência"). O limite existe desde o #936.

---

## Fase 6 — Polimento e transversais

- [ ] **T027** Varrer o objeto inteiro por segredo
  - **Pronta quando**: T010–T013 concluídas
  - **Descrição**: SC-005. A varredura olha o **objeto inteiro serializado**, e não os
    campos esperados — campo novo que vaze não estaria na lista de esperados. Procura o valor
    do token, o segredo isolado, `platform_access_level` e qualquer e-mail
  - **Feita quando**: as quatro varreduras devolvem zero em todas as ferramentas
  - **Teste**: `test/the_band_web/mcp/segredo_nao_vaza_test.exs` — e a guarda contra a
    varredura vazia: ela tem de **encontrar** o `team_id`, que está lá de propósito

- [ ] **T028** Medir o custo contra a rota HTTP
  - **Pronta quando**: T010 concluída
  - **Descrição**: `team_roster` tem de custar as mesmas consultas que
    `GET /api/v1/teams/:id/members`. Duas portas para o mesmo dado com custos diferentes
    significam que uma tem consulta a mais — e a que tem a mais faz trabalho que a outra
    provou desnecessário
  - **Feita quando**: os dois custos são iguais; a diferença, se houver, é nomeada
  - **Teste**: `test/the_band_web/mcp/custo_test.exs` — com `ContadorDeConsultas`, e a
    mensagem de falha diz **o que** entrou a mais

- [ ] **T029** Escrever o que o cliente precisa saber
  - **Pronta quando**: T007, T014 e T024 concluídas
  - **Descrição**: a documentação diz **onde o token fica é responsabilidade do cliente**
    (FR-007) e acrescenta o que a FR-032 implica: **o que o agente lê pode sair do controle
    da plataforma**, ser cacheado e indexado do outro lado, fora do alcance de qualquer
    revogação. A FR-007 já diz isso do token; falta dizer do **conteúdo**.

    E uma terceira consequência, que o #939 criou: **o token pode não ter prazo**. Na
    configuração do cliente, um token sem prazo vale até alguém revogá-lo, e a máquina que o
    guarda pode sair de uso sem que ninguém lembre dele. A orientação: para MCP, preferir
    token **com** prazo, e revogar com o motivo `suspeita de vazamento` quando a máquina sai
    de uso sem controle. Também dizer o `401` e o `429` da camada HTTP, do contrato
  - **Feita quando**: as três consequências estão escritas; a revogação é apresentada como o
    **único** controle sobre o que já saiu
  - **Teste**: revisão contra `seguranca.md`, achado A5 — a documentação diz as três coisas,
    e não só a do token

- [ ] **T030** Provar ponta a ponta com um cliente
  - **Pronta quando**: T010–T024 concluídas
  - **Descrição**: configurar um cliente MCP real apontando para `/mcp`, com o token no
    cabeçalho. **Não é verificável por código de status**: foi o que aconteceu com o Swagger
    da 061 — `HTTP 200`, tela em branco, política bloqueando o script
  - **Feita quando**: o cliente lista as quatro; `team_review_wait` permite dizer *"23
    revisadas em 0,2 h; outras 79 esperam há 46 dias"* — e não *"12 minutos"*; token revogado
    é recusado na chamada seguinte
  - **Teste**: os passos 1, 2 e 3 de [`quickstart.md`](./quickstart.md), §9, **com o
    cliente** e não com `curl`

- [ ] **T031** Fechar os gates
  - **Pronta quando**: T009 e T001 a T030 concluídas, exceto as removidas (T023, T025)
  - **Descrição**: `mix gates`, com o **código de saída** como veredito. Qualquer comando
    depois dele substitui o código que vale — em execução de fundo, o código vai **dentro**
    do log; em primeiro plano, a linha termina em `exit $ec`
  - **Feita quando**: os 16 gates rodam e o código de saída é 0; nenhum aviso novo de Credo,
    Sobelow ou dialyzer
  - **Teste**: `mix gates; echo "EXIT=$?"` com o `echo` **colado** — e o número lido, não
    presumido. Isto já falhou nesta sessão: o `echo` devolveu 0 com um teste reprovando

---

## Dependências

```
T009 (revisão independente) ──▶ T001 ──▶ T002 ──▶ T008 (fronteira)
                                             └▶ T006 ──▶ T007 ──▶ T019, T021, T024
T003 ──▶ T004 ──┐
T005 ───────────┼──▶ T010 [P] T011 [P] T012 [P] T013 [P] ──▶ T014, T015
                          └──▶ T017 ──▶ T018
                          │      └──▶ T022 (com T021)
                          └──▶ T027, T028
T007, T014, T024 ──▶ T029
tudo ──▶ T030 ──▶ T031
```

**T023 e T025 foram removidas** em 2026-09-24 e não entram no grafo. Os números ficam, para
que as referências antigas não passem a apontar para outra tarefa.

---

## Execução paralela

| Grupo | Tarefas | Por que podem ir juntas |
|---|---|---|
| as quatro ferramentas | T010, T011, T012, T013 | arquivos diferentes, mesma fundação pronta |
| as guardas transversais | T027, T028 | testes independentes, sobre código já escrito |

---

## Estratégia de entrega

**MVP = US1.** As quatro ferramentas respondendo com a ressalva no objeto já entrega o que
a feature existe para fazer: *um modelo não sabe perguntar pela ressalva, e por isso ela vai
junto.*

**US2 e US3 não são opcionais para a entrega**, e a razão de estarem separadas é serem
testáveis por conta própria — não serem adiáveis. Entregar US1 sem US3 deixaria a FR-024
apoiada em nada.

---

## Fora desta fatia, declarado

| Fora | Por quê |
|---|---|
| as outras **73** perguntas de competência | não têm tela, e portanto não têm caminho de dados provado (FR-021) |
| OAuth e instalação como aplicação | a 061 escolheu token; mudar é decisão nova, com ADR |
| escrita por MCP | um agente não é uma pessoa, e não há autor honesto para a proveniência |
| cache de resposta | cache que atrasa revogação é decisão de segurança disfarçada de desempenho |
| o servidor como processo separado | Q1: dentro do monólito na primeira versão, com a fronteira que torna a extração mecânica |
| a escolha da janela das medidas | 56 dias, fixos e declarados |

---

## A lacuna que continua aberta

**I4 — não houve revisão independente do desenho.** Quatro tentativas por agente falharam em
2026-09-21/22: dois travaram sem escrever nada, duas foram recusadas por indisponibilidade
da ferramenta.

A avaliação de segurança que originou A1, A2 e A3 foi escrita por **quem escreveu o
desenho**, e vale menos exatamente onde mais importaria. O princípio VII **não** está
cumprido, e não deve ser marcado como tal.

**Em 2026-09-24 ela virou tarefa, a T009**, e bloqueia o T001. A reconciliação mostrou o custo
de não tê-la: a autoavaliação não viu que o desenho gravaria a recusa como leitura (A7), e
esse é o tipo de erro que outro par de olhos pega.
