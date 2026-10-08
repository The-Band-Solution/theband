# Implementation Plan: o limite de tentativas por origem nas duas entradas

**Branch**: `fix/1229-limite-por-ip-na-entrada` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Input**: [spec.md](spec.md), emendada pela [avaliação de segurança](seguranca.md) (L1–L14)
**Contrato**: [contracts/limite-por-origem.md](contracts/limite-por-origem.md) | **Pesquisa**: [research.md](research.md)

## Summary

Um contador por origem, em ETS, com janela deslizante em fatias, conferido **dentro do contexto
de autenticação e antes de resolver o identificador**, nas cinco portas que verificam segredo sem
sessão: `POST /session` (balde `contas`) e os quatro `POST` públicos de `/platform` (balde
`operador`). Conta falhas — incremento antes, devolução de um no sucesso. A recusa por limite é a
recusa comum de cada porta, sem hash e sem consulta. A origem tem três estados: `socket`
declarado (dev, teste), `proxy` (cabeçalho e lista de proxies de rede local, depois da #1063) e
**não declarada** — produção hoje —, em que o limite conta e registra a transição, e **não recusa**
(L1, decisão 2 da 070).

**O que a pessoa vê**: quem ataca, a mesma recusa; quem opera, o motivo `limite_por_origem` no
painel da 074, a linha do estado da origem no log de subida, e a linha da transição para o limite.

## Technical Context

**Language/Version**: Elixir `~> 1.17` (`mix.exs:8`; local 1.20.2 / OTP 29), sem mudança
**Primary Dependencies**: as existentes — Phoenix, Plug, Bandit, `:ets`, `:inet`. **Nenhuma nova**
(ver *Dependência*, abaixo)
**Storage**: ETS (o contador); PostgreSQL sem migração — a espera por conta continua onde está
**Testing**: ExUnit, `Phoenix.ConnTest`; contagem de hashes pelo evento
`[:the_band, :platform, :custo_do_hash]` e por um evento novo de custo em `Tenants.Auth`; contagem
de consultas pelo `[:the_band, :repo, :query]`
**Target Platform**: o contêiner do Dokploy, uma instância
**Performance Goals**: a recusa por limite custa um `update_counter` e dez `lookup`; nenhum bcrypt
**Constraints**: nenhuma diferença de resposta entre recusa por limite e recusa comum; nenhum
endereço na telemetria; o prefixo truncado só na linha da transição
**Scale/Scope**: cinco portas, dois baldes, uma regra nova na base de conhecimento

## Constitution Check

| princípio | como esta feature o cumpre |
|---|---|
| I. Ontologias | nenhuma ontologia tocada; `TheBand.Origem` e `TheBand.LimitePorOrigem` são infraestrutura de acesso, como `Tenants.Auth` |
| II. Fonte externa ≠ domínio | não se aplica |
| III. Proveniência e idempotência | não se aplica (nada de fonte externa) |
| IV. YAML versionado | os números moram em `priv/knowledge_base/rules/access_origin_limit.yaml`; o motivo novo em `journey_entrar_e_sair.yaml` |
| V. Multitenant | a recusa por limite não lê tenant nenhum; o limite é anterior ao tenant, porque o identificador é global |
| VI. Spec Kit, contrato antes | contrato em `contracts/`; tarefas com issue; fatia vertical: a recusa nas telas e o motivo no painel |
| VII. Gates e revisão | `mix gates` com `GATES_EXIT`; revisão pedida à equipe `the-band`; revisão **não obtida** declarada |
| VIII. Desenho justificado | ver abaixo — cada peça com as três perguntas |
| IX. Ontologias modulares | não se aplica |
| X. Uma coisa por módulo | origem (normalizar), configuração (ler o ambiente), resolução pela conexão (web), contador (contar) — quatro módulos, quatro razões de mudar |
| XI. Estado conferido | o código de saída lido no log; cópia antes de injetar defeito, `diff` depois |

**Ressalva registrada (princípio I da constituição, aprovação).** A spec, o plano e as tarefas
não passaram por aprovação humana antes do código. A execução foi pedida de ponta a ponta pela
pessoa mantenedora para estas duas issues; a lista fechada de motivos de parada que o `AGENTS.md`
deveria ter **não existe no arquivo** (conferido em 2026-10-05: nenhuma ocorrência de "lista
fechada", "motivos de parada" ou "onze", nem em `git log -S`). A lacuna fica declarada no PR, e o PR
é o ponto de aprovação.

## Decisões de desenho — as três perguntas do princípio VIII

### 1. Um contador próprio em ETS, e não `Hammer` nem banco

1. **Problema**: contar falhas por origem, com incremento atômico e devolução na mesma fatia, poda
   global e dono supervisionado. **Existe agora** (#1229).
2. **Por que não `Hammer`**: dependência nova (AGENTS §3) para o que `:ets.update_counter/4` já faz
   na `ApiRateLimit`; e o `Hammer` não oferece a devolução de um na fatia do incremento (L8), que é
   o que deixa o limite contar falhas. **Por que não banco**: uma escrita por tentativa faz a
   campanha escrever no banco (L11).
3. **O que piora**: deploy zera a contagem; N instâncias multiplicam o limite por N (declarado; a
   segunda instância é a condição de revisão).

### 2. Não reaproveitar o plug `ApiRateLimit`

O precedente anuncia o limite (`429`, `retry-after`, `x-ratelimit-*`, log por recusa) e poda só a
chave tocada — os dois são defeitos aqui (L6, L9). Duplicar a ideia das fatias é barato; abstrair
os dois num módulo comum agora seria a generalidade especulativa de §7.7, com dois usos de
semânticas opostas (anunciar e esconder). Fica a nota: na terceira contagem por fatia, abstrair.

### 3. A conferência dentro do contexto, e não num plug

1. **Problema**: a recusa por limite precisa sair pelo mesmo `{:error, :invalid_credentials}`
   de todo motivo, sem resolver conta, e emitir o passo da 074 no mesmo lugar (L7).
2. Um plug antes do controller teria de **reproduzir** a recusa de cada uma das cinco portas — a
   segunda porta de autorização que envelhece. E contaria antes das pré-conferências do cadastro.
3. **O que piora**: as funções públicas de autenticação ganham a origem na assinatura, e os testes
   que as chamam passam a fornecê-la. Isso é o que torna o esquecimento um erro, e não um buraco.

### 4. Três estados de origem, e o não declarado só observa

L1 e a decisão 2 da 070. O estado é **nomeado** (`:nao_declarada`) para não ser um fallback
silencioso: o log de subida o diz, e o retorno `{:observado, …}` é o que o teste afere. Mudar a
produção para recusar é uma variável de ambiente, e a escolha é da pessoa mantenedora (M1).

### 5. A origem nos testes de interface

`Phoenix.ConnTest.build_conn/0` dá `127.0.0.1` a toda requisição. Com o limite, os testes
assíncronos que entram e erram dividiriam um contador, e reprovariam conforme a ordem. A
`ConnCase` passa a importar o `build_conn/0` da casa, que dá a cada conexão uma origem de
documentação própria (`2001:db8:<n>::1`, um `/64` por chamada). `recycle/1` preserva o endereço
(`deps/phoenix/lib/phoenix/test/conn_test.ex:476-483`). Os testes do limite fixam a origem que
querem. Os testes de domínio usam `TheBand.OrigemDeTeste.nova/0`.

### O que **não** entra

- A espera por conta **e** origem (#1106, descrição): sem o endereço real é igual à espera por conta.
  Fica com a #1106, que continua aberta até a #1063.
- Confiar nas faixas do Cloudflare (L4): fora da lista de rede local por construção.
- `POST /profile/password` (L14): issue própria.

## Project Structure

### Documentation (this feature)

```text
specs/077-limite-por-origem/
├── spec.md  seguranca.md  plan.md  research.md  tasks.md
├── contracts/limite-por-origem.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/the_band/origem.ex                         struct, normalização, análise estrita, CIDR
lib/the_band/origem/configuracao.ex            os três estados, lidos do ambiente
lib/the_band/limite_por_origem.ex              o processo dono, conferir/devolver/varrer
lib/the_band_web/origem.ex                     a origem da conexão
lib/the_band/tenants/auth.ex                   a conferência antes de resolver
lib/the_band/platform/credentials.ex           a conferência antes de operador_por_email
lib/the_band_web/controllers/session_controller.ex
lib/the_band_web/plataforma/entrada_controller.ex  cadastro_controller.ex
lib/the_band/application.ex                    o filho e a linha do log de subida
config/dev.exs  config/test.exs  config/runtime.exs
priv/knowledge_base/rules/access_origin_limit.yaml   (nova)
priv/knowledge_base/rules/journey_entrar_e_sair.yaml (motivo novo)
test/support/origem_de_teste.ex  test/support/conn_case.ex
test/the_band/origem_test.exs  test/the_band/origem/configuracao_test.exs
test/the_band/limite_por_origem_test.exs  test/the_band_web/origem_test.exs
test/the_band_web/limite_por_origem_na_entrada_test.exs
test/the_band_web/plataforma/limite_por_ip_test.exs   (o nome que a #1106 pede)
docs/producao/runbook.md                       §15, a origem e a medição #1063
```

## Como o teste prova

Os cenários Q1–Q22 de `seguranca.md` viram testes, cada um com o defeito a injetar. Dois pontos:

- **zero hashes**: na porta do operador, o evento `custo_do_hash` já existe; em `Tenants.Auth`, os
  `Bcrypt.no_user_verify/0` e `verify_pass/2` passam por uma função que emite
  `[:the_band, :tenants, :custo_do_hash]` — o mesmo desenho, para a mesma asserção sem cronômetro;
- **resposta idêntica**: compara status, `location`, *flash* e o conjunto de cabeçalhos da recusa
  por limite com o da recusa comum, tirando o token de CSRF e os cabeçalhos de identificação de
  requisição.

## A ordem, e o que bloqueia o quê

Origem e configuração → contador → as portas das contas → as portas do operador → log de subida e
runbook. A confiança no cabeçalho em produção espera a #1063 (👤), e não bloqueia o merge.

## Complexity Tracking

| desvio | por que é preciso | a alternativa mais simples, rejeitada |
|---|---|---|
| a assinatura das funções de autenticação muda, e ~100 chamadas de teste mudam junto | a origem obrigatória é o que impede uma porta sem limite | `opts[:origem]` opcional: deixaria a porta sem limite a um esquecimento |
