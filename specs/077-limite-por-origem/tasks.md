# Tasks: o limite de tentativas por origem nas duas entradas

**Input**: [spec.md](spec.md), [seguranca.md](seguranca.md), [plan.md](plan.md),
[research.md](research.md), [contracts/limite-por-origem.md](contracts/limite-por-origem.md)

Convenções: 👤 = ato da pessoa mantenedora, que nenhum agente faz. **Defeito a injetar** = o que se
muda de propósito para ver o teste reprovar antes de aceitar a guarda (CLAUDE.md, *guarda de
segurança nasce provada*). Antes de injetar, **copiar o arquivo**; depois de restaurar, conferir
com `diff`. Todo comando de verificação redireciona a saída para arquivo e lê o código de saída
antes (AGENTS §4). Os cenários `Qn` são os de [seguranca.md](seguranca.md).

## Fase 0: a medição que é da pessoa mantenedora

- [ ] T001 👤 Medir o cabeçalho de IP no proxy de produção — **é a #1063 (070/T004), que já existe;
  esta spec não abre outra issue para ela**
  - **Pronta quando**: acesso ao servidor do Dokploy. Dono: a pessoa mantenedora; nenhum agente tem
    nem pede esse acesso
  - **Descrição**: o procedimento de `docs/producao/runbook.md` §15.2 (o mesmo de
    [seguranca.md](seguranca.md), *Procedimento seguro da medição #1063*): eco `traefik/whoami`
    fixado por digest, num domínio `sslip.io` temporário; `curl` sem credencial, com
    `X-Forwarded-For` forjado em uma e em duas linhas, `Forwarded` e `X-Real-IP`; o `RemoteAddr`
    e a sub-rede; o caminho pelo Cloudflare, se ligado; a porta 4000 publicada ou não; o eco
    derrubado
  - **Feita quando**: a #1063 tem um comentário com data, método, versão do Traefik, para cada caso
    "sobrescreve" ou "acrescenta", a sub-rede do proxy, se há Cloudflare e se a porta está
    publicada — só endereços de documentação e `<endereço de quem mediu>`
  - **Teste**: o comentário existe e responde às seis perguntas; T012 o lê como `Pronta quando`

## Fase 1: a base de conhecimento

- [ ] T002 A regra `access.origin_limit` e o motivo `limite_por_origem`
  - **Pronta quando**: o contrato §4 e §6 escritos
  - **Descrição**: `priv/knowledge_base/rules/access_origin_limit.yaml` com o limite (10 falhas),
    a janela (300 s), as fatias (10), o teto da tabela (200 000), os prefixos do log (24 e 48) e
    o prefixo da chave IPv6 (64), cada um com a razão; `journey_entrar_e_sair.yaml` ganha
    `limite_por_origem` em `entrar_com_senha`; `taxonomia_test.exs` ganha o motivo na régua
  - **Feita quando**: `mix knowledge.validate` e `mix knowledge.test` saem `0`; a taxonomia lê o
    motivo novo
  - **Teste**: `test/the_band/telemetria/taxonomia_test.exs`. **Defeito a injetar**: tirar
    `limite_por_origem` do YAML; o teste da régua reprova

## Fase 2: a origem e o contador (fundação, bloqueia as US)

- [ ] T003 `TheBand.Origem`: normalizar, analisar estrito, prefixo e CIDR
  - **Pronta quando**: contrato §1
  - **Descrição**: a struct; `normalizar/1` desmapeia `::ffff:0:0/96` e nomeia o que não é
    endereço; `de_endereco/2` dá a chave (IPv4 inteiro, IPv6 `/64`) e o prefixo (`/24`, `/48`);
    `analisar_estrito/1` com `String.trim/1` e `:inet.parse_strict_address/1`; `pertence?/2`
  - **Feita quando**: Q13, Q14 e a parte de análise de Q15 passam
  - **Teste**: `test/the_band/origem_test.exs`. **Defeito a injetar**: (a) aplicar o `/64` sem
    desmapear (Q13 reprova: dois IPv4 viram uma origem); (b) `:inet.parse_address/1` no lugar do
    estrito (`127.1` passa e o teste reprova)

- [ ] T004 `TheBand.Origem.Configuracao`: os três estados, e a recusa de subir
  - **Pronta quando**: T003
  - **Descrição**: `ler!/1` sobre `System.get_env()`; `frase/1`; `config/runtime.exs` (produção)
    chama `ler!/1`; `config/dev.exs` e `config/test.exs` declaram `%{estado: :socket}`
  - **Feita quando**: Q17 passa — `0.0.0.0/0`, `::/0`, `8.8.8.0/24`, `abc`, lista vazia e estado
    desconhecido levantam com a mensagem que nomeia a variável e **não** contém o valor; sem
    `THE_BAND_ORIGEM` o estado é `:nao_declarada`
  - **Teste**: `test/the_band/origem/configuracao_test.exs`. **Defeito a injetar**: aceitar faixa
    não local (o caso `8.8.8.0/24` reprova)

- [ ] T005 `TheBandWeb.Origem.de/1`: a origem da conexão
  - **Pronta quando**: T004
  - **Descrição**: contrato §3 — socket nos estados `:socket` e `:nao_declarada`; em `:proxy`, só
    com o socket na lista, as linhas juntadas na ordem, o mais à direita não confiável, e o socket
    quando o valor não é estrito; nenhum outro cabeçalho
  - **Feita quando**: Q9, Q10, Q11, Q12, Q15 e Q16 passam
  - **Teste**: `test/the_band_web/origem_test.exs`. **Defeitos a injetar**: (a) ler o cabeçalho sem
    conferir o socket (Q10); (b) o primeiro valor, como o `Plug.RewriteOn` (Q11); (c) só a primeira
    linha (Q11, duas linhas); (d) não desmapear o socket antes da lista (Q12)

- [ ] T006 `TheBand.LimitePorOrigem`: o processo dono, conferir, devolver e varrer
  - **Pronta quando**: T002, T003
  - **Descrição**: contrato §4 — GenServer supervisionado, dono da tabela; `conferir/2,3`
    incrementa antes e lê depois; `{:recusa, :transicao}` uma vez por janela, com a linha de log
    só com o prefixo; `{:observado, …}` no estado não declarado; `devolver/1` com piso zero e sem
    criar chave; `varrer/1` global, a cada fatia, com o teto; entra em `TheBand.Application`
    depois da base de conhecimento e antes do endpoint
  - **Feita quando**: Q4 (20 paralelas, exatamente 10 seguem), Q7, Q8, Q18 (a parte do retorno),
    Q21 e a parte de log de Q22 passam
  - **Teste**: `test/the_band/limite_por_origem_test.exs`. **Defeitos a injetar**: (a) ler a soma
    antes de incrementar (Q4 reprova); (b) zerar a contagem no sucesso (Q7); (c) `update_counter`
    de devolução com valor padrão (Q8, chave negativa); (d) varrer só a chave tocada (Q21); (e)
    logar a chave em vez do prefixo (Q22)

- [ ] T007 A origem nos testes
  - **Pronta quando**: T003
  - **Descrição**: `test/support/origem_de_teste.ex` com `nova/0` (um `/64` de documentação por
    chamada, estado `:socket`); `TheBandWeb.ConnCase` importa `Phoenix.ConnTest` sem `build_conn/0`
    e oferece o seu, com origem própria por conexão (plano, decisão 5)
  - **Feita quando**: a suíte inteira passa com o limite ligado, sem teste de outra feature tocado
    a não ser para fornecer a origem
  - **Teste**: o `mix test` inteiro; um teste em `limite_por_origem_test.exs` afere que duas
    chamadas de `nova/0` dão chaves diferentes

## Fase 3: User Story 1 — a entrada das contas (P1) 🎯 o defeito #1229

- [ ] T008 [US1] A conferência em `Tenants.Auth`, antes de resolver
  - **Pronta quando**: T006, T007; contrato §5
  - **Descrição**: `authenticate/3` exige `opts[:origem]`; `conferir(:contas, origem)` é a primeira
    coisa; a recusa sai `{:error, :invalid_credentials}` sem consulta, sem hash, sem
    `registrar_falha/1`, com o passo `limite_por_origem` sem conta; o sucesso devolve a ficha; os
    custos de hash de `Tenants.Auth` passam a emitir `[:the_band, :tenants, :custo_do_hash]`;
    `SessionController.create/2` passa `TheBandWeb.Origem.de(conn)`; as chamadas de teste passam a
    origem
  - **Feita quando**: Q1, Q2, Q3, Q5 (contas), Q6, Q20 e Q22 (telemetria) passam em
    `POST /session`
  - **Teste**: `test/the_band_web/limite_por_origem_na_entrada_test.exs`. **Defeitos a injetar**:
    (a) conferir o limite depois de `resolver/1` (Q5: consultas a `users` deixam de ser zero);
    (b) pagar `no_user_verify` na recusa (Q5: um hash); (c) `registrar_falha/1` na recusa (Q6);
    (d) deixar a senha certa passar no limite (Q2); (e) chave sem a origem (Q3)

## Fase 4: User Story 2 — as quatro portas do operador (P1) — a #1106

- [ ] T009 [US2] A conferência em `Platform.Credentials`, nas quatro portas
  - **Pronta quando**: T006, T007; contrato §5
  - **Descrição**: `autenticar/4`, `definir_senha/4`, `confirmar_segundo_fator/4` e
    `concluir_cadastro/3` recebem a origem; `conferir(:operador, origem)` antes de
    `operador_por_email/1`; recusa sem consulta, sem `custo_do_hash`, sem evento por requisição; o
    sucesso devolve a ficha; os dois controllers passam `TheBandWeb.Origem.de(conn)`, com as
    pré-conferências do cadastro antes
  - **Feita quando**: a décima primeira falha de uma origem é recusada nas quatro portas com a
    recusa daquela porta; outra origem continua entrando; um `X-Forwarded-For` forjado não muda a
    origem contada; Q5 (zero `custo_do_hash`) e Q19 passam
  - **Teste**: `test/the_band_web/plataforma/limite_por_ip_test.exs` (o nome da #1106).
    **Defeitos a injetar**: (a) conferir depois de `operador_por_email/1` (Q5); (b) conferir no
    controller antes da confirmação (Q19); (c) ler o primeiro valor de `x-forwarded-for` com a
    confiança ligada (o caso forjado passa e o teste reprova)

## Fase 5: User Story 3 — o estado da origem, dito e documentado (P1)

- [ ] T010 [US3] A linha do log de subida
  - **Pronta quando**: T004, T006
  - **Descrição**: `TheBand.Application` diz `Configuracao.frase/1` ao subir: `info` em `socket` e
    `proxy`; `warning` em `nao_declarada`, dizendo que o limite só observa porque a origem é o proxy
  - **Feita quando**: as três frases saem como o contrato §2 diz, sem segredo
  - **Teste**: `test/the_band/origem/configuracao_test.exs`, a frase de cada estado. **Defeito a
    injetar**: a frase do não declarado dizer que o limite está ligado

- [ ] T011 [US3] O runbook: a origem, a medição e como ligar
  - **Pronta quando**: T004
  - **Descrição**: `docs/producao/runbook.md` §15 — os três estados e as três variáveis; o
    procedimento da medição #1063; como ligar `proxy` depois dela, e a conferência de fora; §13.7
    passa a apontar para o §15
  - **Feita quando**: o §15 existe e o §13.7 não diz mais que o limite "ainda não existe"
  - **Teste**: revisão; `grep -n "THE_BAND_ORIGEM" docs/producao/runbook.md` devolve as três
    variáveis

- [ ] T012 👤 Ligar a origem pelo proxy em produção, e conferir de fora
  - **Pronta quando**: T001 (#1063) registrada; a 077 em produção
  - **Descrição**: no painel do Dokploy, `THE_BAND_ORIGEM=proxy`, `THE_BAND_ORIGEM_CABECALHO` e
    `THE_BAND_ORIGEM_PROXIES` com a sub-rede medida; redeploy; runbook §15.3
  - **Feita quando**: a linha do log de subida diz `proxy` com a lista; de uma máquina, 11 falhas
    com identificador inexistente — a 11.ª recusada e a transição no log; de outra rede, a entrada
    certa entra. Registrado na #1229 e na #1106
  - **Teste**: o comentário na #1229 com o log de subida e o resultado de fora

## Dependências

T002, T003 → T004 → T005; T002 + T003 → T006; T003 → T007; T006 + T007 → T008, T009; T004 + T006
→ T010; T004 → T011. T001 → T012. **A #1229 e a #1106 só fecham com a T012**: até lá, em produção, o
limite observa e não recusa (`seguranca.md`, L1).
