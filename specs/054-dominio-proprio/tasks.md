# Tasks: O domínio próprio, e a origem que passa a ser declarada

**Input**: specs/054-dominio-proprio/ — spec.md, plan.md, research.md,
data-model.md, contracts/origens-aceitas.md, quickstart.md

**Tests**: cada tarefa carrega o seu, e **as violações vêm primeiro** — a
ausência que restringe (C2), a origem estranha que é recusada (C7). O caminho
feliz sozinho passaria numa implementação que aceita qualquer origem, que é
exatamente o defeito que esta feature não pode introduzir.

**Nota de desenho**: **nenhuma migração, nenhuma entidade, nenhum registro
próprio de recusa**. As três ausências são decisões, e estão justificadas no
[plan.md](plan.md). Se durante a implementação alguém sentir necessidade de
`mix ecto.gen.migration` ou de um `Logger.error` nosso para a origem recusada, o
desenho mudou e o plano precisa ser revisto **antes** do código.

> **Issues criadas retroativamente em 2026-09-01** — #664 a #677. As executadas
> (T001–T010, T013 → #664–#674) nasceram já encerradas, dizendo que vieram depois
> do trabalho; as três abertas (T011 → #675, T012 → #676, T014 → #677) carregam o
> estado medido e os passos. O ciclo desta feature também pulou o
> `/speckit-taskstoissues` — **segunda ocorrência da mesma lacuna**, depois da
> 052, e é o que a torna padrão em vez de esquecimento.

**Nota de escopo**: três tarefas são **marcos de pessoa** — dependem de acesso ao
provedor de DNS e ao painel de quem hospeda, e nenhuma quantidade de código as
executa. Estão marcadas `[MARCO — pessoa]` e ficam no fim, porque o repositório
precisa estar pronto antes de o primeiro endereço mudar.

## Phase 1: Setup

- [x] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch nascida de `development`
  - **Descrição**: `mix gates > /tmp/gates_054_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_054_baseline.log`, execução TERMINADA antes de editar qualquer arquivo. O veredito é o código de saída, escrito dentro do log, e nada roda depois dele (L60, princípio XI)
  - **Feita quando**: `EXIT=0` na última linha do log, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_054_baseline.log` devolve `EXIT=0`

## Phase 2: Foundational

- [x] T002 Confirmar a comparação que a lista impõe
  - **Pronta quando**: T001; `contracts/origens-aceitas.md` escrito
  - **Descrição**: conferir contra `deps/phoenix/lib/phoenix/socket/transport.ex` as três afirmações que o contrato faz e das quais tudo depende: (a) o padrão do endpoint é `check_origin: true` e compara **só o host**; (b) com lista, a comparação inclui esquema e porta, com `nil` casando qualquer valor; (c) requisição **sem** cabeçalho de origem não é checada. Qualquer divergência é corrigida NO CONTRATO, no mesmo commit, com a razão (L82)
  - **Feita quando**: as três afirmações conferidas linha a linha; a tabela "o que muda em relação a hoje" do contrato bate com o que a fonte faz
  - **Teste**: `grep -n "check_origin: true" deps/phoenix/lib/phoenix/endpoint/supervisor.ex` e `grep -n "is_nil(origin) or check_origin == false" deps/phoenix/lib/phoenix/socket/transport.ex` devolvem linha; a revisão do contrato contra `origin_allowed?/2` registrada no PR

## Phase 3: US2 — As telas vivas funcionam nos dois endereços (P1)

**Objetivo**: a lista de origens deixa de ser derivada do endereço que gera
links, e passa a ser declarada — sem que a ausência de declaração libere nada.

**Teste independente**: subir com uma origem extra declarada e conferir que as
duas conectam; subir sem nenhuma e conferir que só a principal conecta.

> Esta é a primeira fase de implementação **de propósito**, embora seja a US2. A
> US1 sem ela publica um defeito: o segundo endereço responde 200 e não é
> interativo. O repositório precisa estar pronto antes de o DNS mudar.

- [x] T003 [US2] A violação: a ausência não pode liberar
  - **Pronta quando**: T002
  - **Descrição**: `test/the_band_web/origens_test.exs` — escrever PRIMEIRO os casos que provam C2 e C7 do contrato: `nil` e `""` produzem **exatamente** `["https://<host>"]`, e **nenhum** valor de entrada produz lista que aceite origem arbitrária (nem `"*"`, nem `"true"`, nem só vírgulas). O teste falha agora porque o módulo não existe — é o ponto (L77)
  - **Feita quando**: os casos existem e falham por ausência do módulo, não por erro de sintaxe
  - **Teste**: `MIX_ENV=test mix test test/the_band_web/origens_test.exs` reprova com `TheBandWeb.Origens is not available`

- [x] T004 [US2] A lista de origens vira função pura
  - **Pronta quando**: T003 escrito e reprovando
  - **Descrição**: `lib/the_band_web/origens.ex` com `aceitas/2`, conforme o contrato: host principal sempre primeiro (C1), ausência restringe (C2), ordem preservada (C3), espaços e entradas vazias descartados (C4), entrada sem esquema recebe `https://` (C5), sem duplicatas (C6). Função **pura** — não lê o ambiente por dentro; quem lê é o `runtime.exs`. É o que a torna testável, e é a razão de o módulo existir (decisão 1 do plano)
  - **Feita quando**: T003 passa inteiro; os sete invariantes do contrato têm caso próprio; o módulo não chama `System.get_env/1`
  - **Teste**: `MIX_ENV=test mix test test/the_band_web/origens_test.exs` verde; `grep -c "System.get_env(" lib/the_band_web/origens.ex` devolve `0` — com o parêntese: o moduledoc **menciona** `System.get_env/1` em prosa, de propósito, para explicar por que a função é pura

- [x] T005 [US2] O endpoint passa a declarar as origens
  - **Pronta quando**: T004
  - **Descrição**: em `config/runtime.exs`, no bloco de produção, acrescentar `check_origin: TheBandWeb.Origens.aceitas(host, System.get_env("THE_BAND_ORIGENS_EXTRAS"))` à configuração do endpoint. O `host` é o mesmo que já alimenta `url:` — as duas coisas continuam existindo, e é justamente a separação delas que o FR-004 pede
  - **Feita quando**: a configuração do endpoint traz `check_origin` com lista; subir em produção sem a variável nova mantém o comportamento de hoje
  - **Teste**: com `MIX_ENV=prod` e as variáveis obrigatórias definidas, `mix run --no-start -e 'Application.get_env(:the_band, TheBandWeb.Endpoint)[:check_origin] |> IO.inspect()'` imprime `["https://exemplo.test"]`; com `THE_BAND_ORIGENS_EXTRAS=https://outro.test` imprime os dois, nessa ordem.
    **Corrigido durante a execução**: a primeira redação usava `TheBandWeb.Endpoint.config/2`, que exige o endpoint no ar e levanta com `--no-start`; e sem `--no-start` a subida exigiria banco. `Application.get_env/2` lê a mesma configuração que o `runtime.exs` acabou de escrever, sem subir nada

- [x] T006 [US2] A variável nova entra no exemplo do ambiente
  - **Pronta quando**: T005
  - **Descrição**: `.env.example` ganha `THE_BAND_ORIGENS_EXTRAS=` com o comentário que diz o que ela é — **por onde as pessoas chegam**, diferente do `PHX_HOST`, que é **o endereço que a plataforma escreve nos links**. Sem essa frase, as duas voltam a ser confundidas, que é a causa raiz da P1 da 050
  - **Feita quando**: a variável aparece com valor vazio e o comentário distingue as duas perguntas; nada no `.env.example` sugere que deixá-la vazia libere origens
  - **Teste**: `grep -A 3 "THE_BAND_ORIGENS_EXTRAS" .env.example` mostra o comentário com a distinção

## Phase 4: US3 — A declaração é de quem opera, e a recusa é visível (P2)

**Objetivo**: quem opera vê qual lista está em vigor, e a recusa aparece nomeando
a origem — em vez de virar uma tela que não atualiza.

**Teste independente**: tentar conectar de uma origem não declarada e encontrar a
recusa no registro, nomeando-a.

- [x] T007 [US3] Provar que a recusa nomeia a origem
  - **Pronta quando**: T005
  - **Descrição**: teste que exerce o transporte com uma origem fora da lista e **captura o registro**, afirmando que a mensagem contém a origem que tentou. O FR-008 já é atendido pelo Phoenix (research R2) — esta tarefa não escreve registro nenhum, ela **prova** que o registro existe, e é ela que avisa no dia em que a biblioteca mudar
  - **Feita quando**: o teste afirma sobre a origem dentro da mensagem capturada, e não apenas sobre o 403; um comentário no teste diz por que não escrevemos registro próprio (decisão 3 do plano)
  - **Teste**: `MIX_ENV=test mix test test/the_band_web/origens_recusa_test.exs` — verde com a origem na mensagem, e reprova se a asserção da origem for removida

- [x] T008 [US3] A limitação da origem ausente, escrita onde se lê
  - **Pronta quando**: T007
  - **Descrição**: registrar no moduledoc de `lib/the_band_web/origens.ex` a limitação que o contrato declara: requisição **sem** cabeçalho de origem não é checada pelo transporte, e contra cliente programático a defesa é a sessão. Sem isso, quem ler os testes concluirá "só quem está na lista conecta", que é falso (research R3)
  - **Feita quando**: o moduledoc traz a limitação com a razão, e aponta para o contrato
  - **Teste**: `grep -n "sem o cabeçalho" lib/the_band_web/origens.ex` devolve linha; a revisão confere que a frase descreve o comportamento verificado em R3, e não uma promessa

## Phase 5: US1 — A plataforma atende no nome próprio (P1)

**Objetivo**: o nome novo atende cifrado, e o antigo não para.

**Teste independente**: abrir os dois endereços de fora e ver a tela de entrada;
e ver o socket aceito nos dois.

- [x] T009 [US1] O runbook ganha a ordem do domínio
  - **Pronta quando**: T005; `quickstart.md` escrito
  - **Descrição**: nova seção `§9` em `docs/producao/runbook.md` com os passos **na ordem em que precisam acontecer** e a razão de cada ordem (research R5): DNS sem intermediário → certificado emitido → intermediário ligado com cifra ponta a ponta → conferência do socket. Incluir o que dá errado em cada inversão — certificado que não sai, laço de redirecionamento, tela que não atualiza —, porque é a inversão que acontece na prática
  - **Feita quando**: a seção existe com os quatro passos numerados, cada um com o sintoma de tê-lo feito fora de ordem; a variável `THE_BAND_ORIGENS_EXTRAS` aparece no passo em que é preenchida
  - **Teste**: leitura dirigida — alguém que não escreveu a seção executa os passos no ambiente e não precisa perguntar nada fora dela. Enquanto o marco não acontece, a revisão do PR confere a seção contra `research.md` R4, R5 e R6

- [x] T010 [US1] A medida dos dois endereços, escrita para ser executada
  - **Pronta quando**: T009
  - **Descrição**: `scripts/medir-enderecos.sh` com as medidas do `quickstart.md` — HTTP dos dois endereços, redirecionamento do HTTP simples, e o **handshake do socket** com origem própria e com origem não declarada. O script imprime a tabela de leitura dos códigos (403 = recusa, 400 = handshake incompleto com origem ACEITA), porque ler 400 como falha faria a feature parecer quebrada
  - **Feita quando**: o script roda contra um endereço dado por argumento; sai com código diferente de zero quando o socket é recusado no endereço que deveria aceitar
  - **Teste**: `bash scripts/medir-enderecos.sh https://theband.5.189.161.85.sslip.io` contra a produção de hoje — sai `0` e imprime `200` e o handshake aceito; e com uma origem inventada no lugar da própria, sai diferente de zero

- [ ] T011 [US1] [MARCO — pessoa] O DNS aponta, e o certificado sai
  - **ESTADO MEDIDO EM 2026-09-01**: o DNS **já foi apontado**, com o proxy do
    Cloudflare **ligado**, e o domínio **não foi adicionado no painel**. Medido:
    `https://theband.dev/sign-in` devolve **526**; o certificado que a origem
    serve para esse nome é `CN=TRAEFIK DEFAULT CERT`, autoassinado; e
    `Host: theband.dev` direto na origem devolve **404** — não existe rota. Sem
    rota, o desafio do Let's Encrypt devolve 404 e o certificado nunca sai. É a
    inversão que o `§9` previa, acontecendo
  - **Pronta quando**: T009 e T010 mergeados **e a release que os carrega em
    produção** (v0.3.0); acesso ao provedor de DNS e ao painel
  - **Descrição**: seguir o `§9` do runbook — registro do nome e do `www` apontando para o IP da produção, **sem** o intermediário na frente; publicar o nome no painel de quem hospeda; esperar o certificado. Só depois ligar o intermediário, em modo que cifra também até a aplicação. `.dev` não tem plano B: sem certificado, o navegador recusa antes de qualquer requisição (research R4)
  - **Feita quando**: `https://theband.dev/sign-in` responde 200 com certificado válido para o nome; `http://theband.dev/sign-in` devolve 301; `www` chega ao mesmo lugar
  - **Teste**: `bash scripts/medir-enderecos.sh https://theband.dev` — HTTP conforme, e o handshake do socket **aceito** com a própria origem

- [ ] T012 [US1] [MARCO — pessoa] A declaração das duas origens
  - **Pronta quando**: T011
  - **Descrição**: no painel de quem hospeda, `PHX_HOST=theband.dev` e `THE_BAND_ORIGENS_EXTRAS=https://theband.5.189.161.85.sslip.io`; reimplantar. A ordem importa: declarar a origem extra **antes** de trocar o `PHX_HOST` evita a janela em que o endereço antigo fica sem socket
  - **Feita quando**: os dois endereços aceitam o socket, medidos separadamente (SC-002); o endereço antigo não teve interrupção durante a troca (SC-004)
  - **Teste**: `bash scripts/medir-enderecos.sh` nos dois endereços, com a medida contínua do passo 6 do `quickstart.md` rodando durante a troca — toda linha `200`

## Phase 6: Polish

- [x] T013 Gates verdes, PR no padrão e revisão CONFERIDA
  - **Pronta quando**: T003 a T010 concluídas
  - **Descrição**: `mix gates` com o código de saída dentro do log; abrir o PR no padrão da casa — issues com resumo na frente, e revisão pedida **e conferida depois de pedir** com `gh pr view <n> --json reviewRequests`, porque o comando de pedir sai com zero mesmo sem pedir ninguém (L89, L14)
  - **Feita quando**: `EXIT=0`; o PR existe com revisor listado no JSON, e está no board com `Iteration` e `Status`
  - **Teste**: `tail -1 /tmp/gates_054.log` = `EXIT=0`; `gh pr view <n> --json reviewRequests` devolve lista **não vazia**

- [ ] T014 A P1 da 050 é encerrada, dizendo o que a substituiu
  - **Pronta quando**: T012 (os dois endereços medidos)
  - **Descrição**: em `specs/050-em-producao/pendencias.md`, marcar a P1 como encerrada com a data, o que a substituiu (FR-004 a FR-008 desta feature) e o que a medição encontrou. Pendência encerrada sem dizer o que a fechou vira dúvida na próxima leitura
  - **Feita quando**: a P1 aparece encerrada, com data e link para esta feature; o gatilho original está citado, mostrando que ele disparou como previsto
  - **Teste**: `grep -n -A 5 "^## P1" specs/050-em-producao/pendencias.md` mostra o encerramento com data e destino

## Dependências e ordem

```text
T001 → T002 → T003 → T004 → T005 ─┬→ T006
                                   ├→ T007 → T008
                                   └→ T009 → T010 → T013
                                                 └→ T011 → T012 → T014
```

**Paralelizáveis** depois de T005: `T006`, `T007` e `T009` tocam arquivos
diferentes e não dependem entre si.

**MVP**: T001 a T005. Com elas, a plataforma aceita dois endereços declarados —
e é o que precisa existir **antes** de qualquer mudança de DNS. Publicar o nome
novo sem isso é publicar o defeito.

**O que não é MVP e não é opcional**: T010. Sem a medida escrita, a validação da
feature vira leitura de código HTTP, e é exatamente isso que a L85 registra como
insuficiente.
