# Feature Specification: O limite de tentativas por origem nas duas entradas

**Feature Branch**: `fix/1229-limite-por-ip-na-entrada`

**Created**: 2026-10-05

**Status**: Draft — emendada em 2026-10-05 com a [avaliação de segurança](seguranca.md), anotada
*(seguranca.md, Ln)* em cada requisito que ela mudou. A M1 (o que a produção faz antes da #1063) segue a decisão 2 da 070, já tomada pela pessoa mantenedora em 2026-10-01, e pode ser revista por configuração, sem código.

**Input**: o defeito de segurança [#1229](https://github.com/The-Band-Solution/theband/issues/1229)
(*a entrada aceita tentativas sem limite para identificador que não resolve*, achado S12 e
decisão D7 da 074) e a tarefa [#1106](https://github.com/The-Band-Solution/theband/issues/1106)
(070/T043, *limitar as tentativas por IP* na entrada do operador). As duas pedem o mesmo
mecanismo, e as duas dependem da medição [#1063](https://github.com/The-Band-Solution/theband/issues/1063)
(070/T004), que é da pessoa mantenedora.

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| a espera crescente da entrada das contas é **por conta**, no banco (`failed_attempts`, `last_failed_at`), e só começa depois de três falhas | `lib/the_band/tenants/auth.ex:36-37`, `:229-260` |
| o identificador que não resolve **nunca** entra em espera: paga `Bcrypt.no_user_verify/0` e recusa | `auth.ex:66-71` |
| a entrada do operador copia a mesma espera, por operador | `lib/the_band/platform/credentials.ex:36-117` |
| a recusa de `POST /session` é uma frase (*flash*) e um redirecionamento a `/sign-in`, igual para todo motivo | `lib/the_band_web/controllers/session_controller.ex:24-50` |
| a recusa de `POST /platform/session` é a página de entrada re-renderizada com `422`, igual para `:invalid_credentials` e `{:throttled, _}` | `lib/the_band_web/plataforma/entrada_controller.ex:22-38` |
| os outros três `POST` públicos de `/platform` (`/setup`, `/setup/second-factor`, `/setup/recovery-codes`) também verificam senha ou código, e têm cada um a sua recusa | `lib/the_band_web/plataforma/cadastro_controller.ex:24-100`; `router.ex:174-182` |
| **a aplicação não lê o endereço do cliente em lugar nenhum**: `grep remote_ip\|x-forwarded-for` em `lib/` é vazio, e `config/prod.exs:14-15` só reescreve o esquema (`x_forwarded_proto`) | medido em 2026-10-05 |
| em produção a aplicação roda atrás do Traefik do Dokploy: o endereço do **socket** é o do proxy, igual para todo visitante | `docs/producao/runbook.md`; `seguranca-autenticacao.md` da 070, A4 |
| **`Plug.RewriteOn` com `:x_forwarded_for`, o caminho que a 070 previa, lê o valor mais à ESQUERDA do cabeçalho e não confere quem o mandou**: se o Traefik acrescenta em vez de sobrescrever, o valor mais à esquerda é o que o cliente escreveu | `deps/plug/lib/plug/rewrite_on.ex:133-137` |
| já existe um limite de taxa em ETS, por token, com janela deslizante em fatias e os números na base de conhecimento | `lib/the_band_web/plugs/api_rate_limit.ex`; `priv/knowledge_base/rules/api_access_thresholds.yaml`, `rate_limit` |
| a telemetria da 074 declara os motivos de `entrar_com_senha` numa lista fechada; motivo emitido e não declarado reprova o gate | `priv/knowledge_base/rules/journey_entrar_e_sair.yaml`; `test/the_band/telemetria/taxonomia_test.exs` |
| a #1063 (medir o cabeçalho no proxy de produção) está **aberta**, sem resultado registrado | `gh issue view 1063`, 2026-10-05 |

A linha do `Plug.RewriteOn` muda o desenho que a 070 deixou escrito: mesmo com a medição
dizendo "sobrescreve", a ferramenta lê o lado errado do cabeçalho no dia em que um segundo proxy
entrar na frente. Esta spec não usa `Plug.RewriteOn` para o endereço.

## O que se vê ao final

**Quem tenta adivinhar** identificadores ou senhas, de um mesmo endereço, passa a receber a
**mesma recusa de sempre** a partir da tentativa que passa do limite, sem nenhuma diferença de
frase, de status ou de cabeçalho que diga que o limite foi atingido. **Quem entra certo** não
vê nada de novo. **Quem opera** vê no painel da 074 o motivo novo,
`limite_por_origem`, e lê no log de subida de onde a plataforma está tirando o endereço — do
socket, do cabeçalho do proxy, ou de lugar nenhum declarado (produção antes da #1063, quando o
limite só observa) —, porque a diferença muda o que o limite protege.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A campanha contra a entrada das contas é freada pela origem (Priority: P1)

Quem manda tentativas de entrada em `POST /session`, de um mesmo endereço de origem, a partir da
tentativa que passa do limite recebe a recusa única, e a plataforma não verifica senha nenhuma
para ela, nem lê conta nem paga hash: o limite é por origem e é conferido antes de qualquer
leitura que dependa do identificador, então o tempo não diz nada sobre conta *(seguranca.md, L5)*.
Vale para
identificador que não resolve, que é o defeito da #1229, e para qualquer outro.

**Why this priority**: é o defeito de segurança aberto (#1229). Hoje a campanha de adivinhação de
e-mails não tem freio, consome CPU de bcrypt à vontade, e enche a fila de telemetria da 074.

**Independent Test**: de um endereço, mandar as tentativas do limite com identificadores
inexistentes, e mais uma. A última recebe a mesma resposta das anteriores, byte a byte, e o passo
`entrar_com_senha` dela chega com `limite_por_origem`. De outro endereço, uma entrada certa entra.

**Acceptance Scenarios**:

1. **Given** um endereço que já gastou o limite na janela, **When** ele manda mais uma tentativa,
   com qualquer identificador, **Then** a resposta é a mesma frase, o mesmo status e o mesmo
   destino da recusa por senha errada, e nenhuma senha é verificada.
2. **Given** o mesmo endereço no limite, **When** ele manda a senha **certa** de uma conta
   existente, **Then** a resposta é a mesma recusa, e a conta não entra (sem oráculo: a senha
   certa não se distingue).
3. **Given** um endereço no limite, **When** outro endereço tenta entrar com a senha certa,
   **Then** entra.
4. **Given** a recusa por limite, **When** se contam os hashes e as consultas, **Then** são zero:
   o limite não verifica nada e não lê conta *(seguranca.md, L5)*.
5. **Given** a recusa por limite, **When** quem opera procura, **Then** o passo chega com
   `falhou` e `limite_por_origem`, sem identificador de conta, sem o que foi digitado, e sem o
   endereço.
6. **Given** a janela passou, **When** o mesmo endereço tenta de novo, **Then** volta a ser
   atendido.

---

### User Story 2 - A mesma freada nas quatro portas públicas do operador (Priority: P1)

Os quatro `POST` públicos de `/platform` — `session`, `setup`, `setup/second-factor` e
`setup/recovery-codes` — contam no mesmo limite por origem, com a recusa de cada porta
inalterada.

**Why this priority**: é a #1106 (070/T043) e o achado A4 da 070. Quem descobre o e-mail do
operador hoje faz tentativas sem limite de endereço, e as quatro portas verificam segredo.

**Independent Test**: de um endereço, gastar o limite em `POST /platform/session` e mandar mais
uma: a resposta é a página de recusa de sempre, `422`. Um `POST /platform/setup` do mesmo
endereço também é recusado com a recusa daquela porta. De outro endereço, o operador entra.

**Acceptance Scenarios**:

1. **Given** um endereço que gastou o limite, **When** manda o próximo `POST` a qualquer uma das
   quatro portas, **Then** recebe a recusa daquela porta, idêntica à recusa por credencial
   errada, e nenhum segredo é verificado.
2. **Given** um `X-Forwarded-For` forjado pelo cliente, **When** a confiança no cabeçalho está
   desligada (o padrão), **Then** o endereço contado não muda.
3. **Given** a recusa por limite numa porta do operador, **When** se contam os eventos de custo
   de hash, **Then** são zero *(seguranca.md, L5)*.

---

### User Story 3 - Quem opera sabe de onde vem o endereço, e só confia no proxy depois de medir (Priority: P1)

A plataforma nunca confia num cabeçalho por padrão. Declarado o **socket**, conta por ele; sem
declaração em produção, conta pelo socket e só **observa**; e só passa a ler o cabeçalho do proxy
quando a configuração o liga **e** nomeia os proxies de rede local em que confia. Mesmo ligada, só
lê o cabeçalho quando a requisição chega de um desses proxies, e usa o valor mais à direita que não
é de proxy confiável — o que **o proxy** escreveu, e nunca o que o cliente escreveu. O estado vai
para o log de subida.

**Why this priority**: sem isto, as US1 e US2 ou confiam num cabeçalho forjável — e quem ataca
escolhe o próprio endereço, o que é pior que não ter limite —, ou contam todo mundo como um
endereço só, sem que ninguém saiba. A medição #1063 é o que autoriza ligar a confiança.

**Independent Test**: sem configuração, uma requisição com `X-Forwarded-For: 203.0.113.7` é
contada pelo endereço do socket. Com a confiança ligada e o socket fora da lista de proxies, a
mesma coisa. Com a confiança ligada e o socket dentro da lista, é contada pelo último valor do
cabeçalho; um valor forjado à esquerda não muda nada.

**Acceptance Scenarios**:

1. **Given** produção sem declaração, **When** a aplicação sobe, **Then** o log diz que o limite
   está só observado, porque a origem é o proxy; e 11 falhas de um endereço não são recusadas,
   mas a transição fica registrada.
2. **Given** nenhuma configuração, **When** chega um `X-Forwarded-For` qualquer, **Then** ele
   é ignorado.
3. **Given** a confiança ligada com uma lista de proxies, **When** a requisição vem de fora da
   lista, **Then** o cabeçalho é ignorado.
4. **Given** a confiança ligada e a requisição vinda de um proxy da lista, **When** o cabeçalho
   tem `203.0.113.7, 198.51.100.9`, **Then** o endereço contado é `198.51.100.9`, o que o proxy
   acrescentou.
5. **Given** a confiança ligada e um cabeçalho ausente, vazio ou malformado, **When** a requisição
   vem de um proxy da lista, **Then** o endereço contado é o do socket, e não um valor inventado.

### Edge Cases

- **Vários usuários atrás de um mesmo endereço (NAT, escritório, rede da universidade)**: dividem
  o limite, mas o limite conta **falhas**: uma turma que entra certa não o gasta *(seguranca.md,
  L8)*. Enquanto uma campanha durar, a senha certa dos vizinhos é recusada — risco declarado.
- **Produção antes da #1063**: o socket é o proxy, e todo visitante é a mesma origem. Recusar ali
  seria um teto global, que nega a entrada a todos a ~0,04 requisição por segundo. Por isso o
  estado **não declarado** conta e registra, e não recusa (FR-005; *seguranca.md*, L1, M1). A
  #1229 e a A4 continuam abertas em produção até a #1063, declaradas.
- **IPv6**: uma pessoa controla, em geral, um prefixo `/64` inteiro. Contar por endereço completo
  deixaria cada tentativa vir de um endereço novo.
- **Reinício da aplicação**: o estado do limite pode se perder; a espera por conta, que está no
  banco, continua.
- **Mais de uma instância**: cada uma conta sozinha, se o estado for local.
- **Requisição sem o formulário completo**: em `POST /session` é `400` do Phoenix antes de
  qualquer código desta spec, e não conta; nas portas do operador o campo ausente vira `""` e conta
  *(seguranca.md, L7)*.
- **Requisição sem token de CSRF**: recusada antes, e não conta — senão qualquer site gastaria a
  cota de quem o visita *(seguranca.md, L7)*.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: As cinco portas — `POST /session` e os quatro `POST` públicos de `/platform` —
  MUST contar, por **origem** e dentro de uma janela, as tentativas que chegariam a verificar um
  segredo, e recusar a que passa do limite. A contagem acontece **depois** do CSRF e das
  pré-conferências que não verificam segredo (a confirmação diferente e a caixa desmarcada do
  cadastro), e **dentro do contexto, antes de resolver** conta ou operador, numa função só para as
  cinco portas. Dois baldes: `contas` (`POST /session`) e `operador` (as quatro portas de
  `/platform`) *(seguranca.md, L7)*.
- **FR-002**: A recusa por limite MUST ser idêntica à recusa por credencial errada da mesma
  porta: frase, status, destino e **conjunto de cabeçalhos** (salvo o token de CSRF). Sem `429`,
  sem `retry-after`, sem `x-ratelimit-*` *(seguranca.md, L9)*.
- **FR-003**: A recusa por limite MUST NOT verificar a senha, o código ou o segundo fator, MUST
  NOT consultar conta ou operador, e MUST NOT pagar o custo de hash: o tempo dela pode ser menor,
  e isso não distingue nada que dependa de conta, porque o limite é conferido antes de qualquer
  leitura que dependa do identificador *(seguranca.md, L5)*.
- **FR-004**: A recusa por limite MUST NOT registrar falha em conta nem em operador, e a senha
  certa no limite MUST NOT zerar a espera da conta *(seguranca.md, L9)*.
- **FR-005**: A origem tem **três estados**, e nenhum liga por ausência de configuração *(seguranca.md,
  L1, L3)*:
  - **socket declarado** (desenvolvimento, teste, ou produção exposta diretamente, por variável):
    conta pelo endereço do socket, e **recusa**;
  - **proxy** (produção depois da #1063, por variável): cabeçalho nomeado e lista de proxies
    confiáveis; conta pela origem lida, e **recusa**;
  - **não declarada** (produção hoje): conta pelo socket, **registra** a transição para o limite,
    e **não recusa** — a decisão 2 da 070 (2026-10-01), *"sem a medição, o limite por IP não
    entra"*, aplicada.

  A aplicação MUST recusar subir com lista de proxies malformada, com `/0`, ou com faixa que não
  seja de rede local (RFC 1918, `100.64.0.0/10`, laço local, `fc00::/7`), e com estado
  desconhecido.
- **FR-006**: Em `proxy`, o cabeçalho MUST ser lido só quando o socket pertence à lista; as linhas
  dele são juntadas na ordem, e a origem é o valor **mais à direita que não pertence à lista**.
  Valor ausente, vazio ou que não é endereço estrito (`127.1`, porta, zona, colchetes) faz valer o
  socket. Nenhum outro cabeçalho (`Forwarded`, `X-Real-IP`, `CF-Connecting-IP`) é lido
  *(seguranca.md, L4, L12)*.
- **FR-007**: O endereço MUST ser normalizado antes de tudo: IPv4 mapeado em IPv6
  (`::ffff:0:0/96`) vira IPv4, **antes** da lista e do prefixo; IPv6 conta pelo `/64`; IPv4 pelo
  endereço inteiro; socket que não é endereço tem uma origem fixa nomeada *(seguranca.md, L2)*.
- **FR-008**: O limite conta **falhas**: o incremento é atômico, incondicional e **anterior** a
  qualquer verificação; no sucesso, e só nele, devolve **exatamente um**, na fatia em que
  incrementou, com piso zero e sem criar chave. O limite, a janela e o teto de memória MUST morar
  na base de conhecimento, numa regra própria *(seguranca.md, L8)*.
- **FR-009**: A aplicação MUST dizer no log de subida o estado da origem, o cabeçalho e a lista,
  sem nenhum segredo.
- **FR-010**: A recusa por limite em `POST /session` MUST emitir o passo `entrar_com_senha` com
  `falhou` e o motivo novo `limite_por_origem`, declarado na taxonomia da 074; o passo MUST NOT
  levar o endereço, o identificador digitado, nem identificador de conta.
- **FR-011**: O endereço MUST NOT ir para a telemetria nem para `Logger.metadata`. No log, uma
  linha por **transição** para o limite (não por recusa), com o balde, o estado e o **prefixo
  truncado** (IPv4 `/24`, IPv6 `/48`), nunca o endereço inteiro *(seguranca.md, L10)*.
- **FR-012**: O estado do limite MUST ter um processo dono supervisionado, que a cada fatia apaga
  **todas** as fatias fora da janela e registra quando passa do teto de tamanho; a tabela que
  renasce vazia é registrada *(seguranca.md, L6, L11)*.
- **FR-013**: A espera por conta (045 FR-016) e a do operador MUST continuar como estão.

### Key Entities

- **Origem**: o endereço de quem tenta, normalizado (IPv4 inteiro, IPv6 pelo `/64`), e a fonte
  de onde foi lido (socket ou cabeçalho do proxy).
- **Limite por origem**: quantas tentativas uma origem faz numa janela, por entrada; regra da
  base de conhecimento.
- **Estado da origem**: configuração de ambiente — `socket`, `proxy` (com o cabeçalho e os proxies
  de rede local) ou não declarada; a confiança no cabeçalho nunca liga sem as duas variáveis.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: De um mesmo endereço, a tentativa que passa do limite é recusada nas cinco portas,
  e nenhuma senha, código ou segundo fator é verificado para ela.
- **SC-002**: A resposta da recusa por limite é idêntica, byte a byte (salvo o token de CSRF), à
  da recusa por credencial errada da mesma porta, e nenhuma consulta de conta nem hash é feito
  para ela.
- **SC-003**: Com a configuração padrão, nenhum valor de `X-Forwarded-For` muda o endereço
  contado; com a confiança ligada, um valor forjado à esquerda também não.
- **SC-004**: Outro endereço continua entrando enquanto um está no limite.
- **SC-005**: Nenhuma conta entra em espera por causa de tentativas recusadas pelo limite.
- **SC-006**: Toda guarda desta spec é vista reprovando com o defeito injetado antes de ser
  aceita.

## Assumptions

- Uma instância da aplicação em produção (Dokploy, um contêiner). Com N instâncias o limite
  efetivo é N × o declarado, e a segunda instância é a condição de revisão *(seguranca.md, L11)*.
  Deploy reinicia a contagem; a espera por conta, no banco, continua.
- A medição #1063 é da pessoa mantenedora, em produção; esta spec entrega o mecanismo e o
  procedimento, e **não** liga a confiança no cabeçalho.
- Sem dependência nova: o mecanismo de ETS da `ApiRateLimit` já resolve o mesmo problema.

## Fora de escopo

- A espera por **conta e origem** que a #1106 menciona (fechar a negação de serviço A4 contra o
  operador): só faz sentido com o endereço real, e fica como tarefa aberta até a #1063.
- Lista de endereços permitidos para `/platform` no Traefik (P2 (b) da 070): fora do repositório.
- Ligar a confiança no proxy em produção: depois da #1063, por configuração, sem código.
- A troca de senha (`POST /profile/password`) verifica a senha atual sem espera nem contador
  (*seguranca.md*, L14): issue própria, porque o freio ali é por conta.
- A fila de telemetria continua recebendo os passos da campanha (*seguranca.md*, L13): a defesa é o
  contador anterior ao descarte da S12 da 074.
