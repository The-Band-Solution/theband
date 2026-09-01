# Feature Specification: O domínio próprio, e a origem que passa a ser declarada

**Feature Branch**: `feat/054-dominio-proprio`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "O domínio próprio theband.dev serve a plataforma, com Cloudflare à frente do Dokploy, e a origem do socket deixa de depender do PHX_HOST — a P1 da 050 vira requisito porque passa a existir um segundo endereço"

## Por que agora

A 050 pôs a plataforma no ar num endereço derivado do IP
(`theband.5.189.161.85.sslip.io`) e **adiou o domínio próprio** (FR-013). A
pendência [P1 da 050](../050-em-producao/pendencias.md) registrou o que
aconteceria no dia em que existisse um segundo endereço, e declarou o gatilho:
*"o dia em que houver um segundo endereço — domínio próprio com o `sslip.io`
ainda respondendo"*. **O domínio foi comprado. O gatilho disparou**, e a
pendência deixa de ser pendência: vira requisito desta feature.

O que a P1 descreve não é inconveniência. A plataforma aceita a conexão das
telas vivas **apenas da origem igual ao endereço que ela usa para gerar links**.
Com dois endereços, um dos dois responde **200 no HTTP e recusa a conexão viva**
— a página carrega, nenhuma tela atualiza, e nada diz o que houve. Esta produção
já pagou esse preço uma vez: 79 tentativas de conexão registradas no log
enquanto, para quem olhava, era só uma barra de carregamento que não terminava.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A plataforma atende no nome que a organização escolheu (Priority: P1)

Quem chega digita `theband.dev` e vê a tela de entrada, cifrada, sem aviso do
navegador. O endereço antigo continua atendendo — ninguém que tenha o link
guardado descobre a mudança por um erro.

**Why this priority**: é a feature. Um endereço derivado de IP é endereço
emprestado: muda com a máquina, não se escreve num cartão, e não sustenta a
identidade de quem publica.

**Independent Test**: de uma rede que não é a de desenvolvimento, abrir
`theband.dev` e ver a tela de entrada; abrir o endereço antigo e ver a mesma
coisa.

**Acceptance Scenarios**:

1. **Given** o nome publicado, **When** alguém abre `http://theband.dev`,
   **Then** é levada ao HTTPS com certificado **válido para esse nome** — nunca
   uma página sem cifra, nunca um aviso de certificado.
2. **Given** o nome publicado, **When** alguém abre o endereço antigo,
   **Then** ele continua atendendo com certificado válido — a transição não
   quebra link guardado.
3. **Given** que o certificado do nome novo ainda **não** foi emitido, **When**
   se avalia publicar, **Then** o nome **não** é anunciado: em `.dev` o navegador
   recusa HTTP por decisão do próprio TLD, e sem certificado não existe página a
   mostrar — nem insegura.

---

### User Story 2 - As telas vivas funcionam nos dois endereços (Priority: P1)

Quem entra por qualquer um dos endereços vê as telas atualizarem sozinhas —
busca que filtra enquanto se digita, progresso de coleta que anda, validação que
responde. Não é "a página abre": é a plataforma inteira funcionando.

**Why this priority**: mesma prioridade da US1 porque **a US1 sozinha entrega um
defeito**. Publicar o segundo endereço sem esta história é publicar uma
plataforma que parece no ar e não é interativa — e sem mensagem de erro alguma.

**Independent Test**: abrir uma tela viva por cada endereço e conferir que ela
atualiza sem recarregar; e conferir que a conexão viva foi aceita, não só que a
página respondeu.

**Acceptance Scenarios**:

1. **Given** os dois endereços publicados, **When** alguém abre uma tela viva por
   `theband.dev`, **Then** a conexão viva é **aceita** e a tela atualiza sem
   recarregar.
2. **Given** os dois endereços publicados, **When** alguém abre a mesma tela pelo
   endereço antigo, **Then** o mesmo acontece.
3. **Given** uma origem que **não** foi declarada, **When** ela tenta abrir a
   conexão viva, **Then** é **recusada** — resolver o problema aceitando qualquer
   origem trocaria um defeito visível por um buraco silencioso.

---

### User Story 3 - Quem opera declara os endereços, e a recusa é visível (Priority: P2)

Quem opera diz quais endereços atendem. A plataforma não adivinha pelo nome, não
aceita todo mundo, e quando recusa uma origem isso fica registrado onde quem
opera olha.

**Why this priority**: P2 porque as duas primeiras já entregam valor. Mas sem
esta, o próximo endereço — homologação, domínio de campanha, a volta do
`sslip.io` depois de uma troca de IP — repete a mesma investigação do zero.

**Independent Test**: subir sem declarar endereço extra e conferir que o
comportamento é o de hoje; declarar um segundo e conferir que os dois passam a
ser aceitos.

**Acceptance Scenarios**:

1. **Given** nenhuma origem extra declarada, **When** a plataforma sobe, **Then**
   ela aceita **apenas** o endereço principal — exatamente o comportamento de
   hoje, sem configurar nada.
2. **Given** uma ou mais origens extras declaradas, **When** a plataforma sobe,
   **Then** todas passam a ser aceitas, e a lista em vigor é observável por quem
   opera.
3. **Given** uma tentativa de conexão de origem não declarada, **When** ela é
   recusada, **Then** a recusa aparece no registro com a origem que tentou — a
   recusa muda de sucesso silencioso para evento legível.

---

### Edge Cases

- **O intermediário cifra até ele e não até a plataforma.** Se quem está à frente
  aceitar HTTPS de fora e falar HTTP com a plataforma, e a plataforma exigir
  HTTPS, nasce um laço de redirecionamento — a página nunca carrega, e o erro não
  nomeia a causa.
- **O intermediário não repassa conexões vivas.** O HTTP responde 200 e as telas
  não atualizam: exatamente a classe de defeito que a US2 existe para fechar, com
  origem diferente.
- **O certificado não é emitido porque o intermediário estava à frente durante a
  emissão.** O desafio de emissão precisa alcançar quem publica; com o
  intermediário no caminho, ele pode nunca chegar.
- **`www.theband.dev`.** Quem digita com `www` não pode encontrar erro.
- **O endereço antigo depende do IP.** Trocar de máquina muda o nome derivado do
  IP; o endereço antigo é temporário por construção, e a declaração de origens
  precisa poder acompanhar sem novo release.
- **Um endereço declarado que ainda não resolve.** Declarar antes de o DNS
  propagar não pode derrubar a plataforma.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST atender em `theband.dev` sob HTTPS, com
  certificado válido para esse nome.
- **FR-002**: Uma requisição em HTTP simples ao nome novo MUST ser levada ao
  HTTPS.
- **FR-003**: `www.theband.dev` MUST levar ao mesmo lugar que o nome sem `www` —
  nunca a um erro.
- **FR-004**: As origens aceitas para a conexão das telas vivas MUST vir de uma
  **lista declarada**, e não de um único valor derivado do endereço usado para
  gerar links. As duas coisas são diferentes: uma é *por onde as pessoas chegam*,
  a outra é *que endereço a plataforma escreve nos links*.
- **FR-005**: Sem nenhuma origem extra declarada, o comportamento MUST ser
  idêntico ao de hoje — aceitar apenas o endereço principal. Ninguém precisa
  configurar nada para continuar no estado atual.
- **FR-006**: A lista de origens aceitas MUST poder mudar **sem novo release** —
  é configuração de ambiente, não decisão de código.
- **FR-007**: A plataforma MUST NOT aceitar origem arbitrária. Não existe estado
  "aceita todas": a ausência de declaração restringe, nunca libera.
- **FR-008**: Uma conexão recusada por origem MUST ser registrada com a origem
  que tentou, em nível que quem opera vê sem instrumentação extra.
- **FR-009**: O endereço antigo (`theband.5.189.161.85.sslip.io`) MUST continuar
  atendendo enquanto durar a transição, com o mesmo comportamento do nome novo.
- **FR-010**: O runbook de produção MUST descrever, na ordem em que precisam
  acontecer: a declaração do DNS, a emissão do certificado, a entrada do
  intermediário, o modo de cifra ponta a ponta, e a conferência das conexões
  vivas.
- **FR-011**: Nenhuma credencial nova (token de DNS, chave de API do
  intermediário) MUST entrar no repositório ou na imagem publicada. Onde houver,
  vive no painel de quem hospeda — o mesmo invariante que a 050 já mede.
- **FR-012**: A verificação de que a feature está entregue MUST medir a **conexão
  viva**, e não apenas a resposta HTTP. Um 200 não é evidência de que as telas
  funcionam — é a lição L85, registrada por esta mesma classe de defeito.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem digita o nome próprio no navegador vê a tela de entrada
  cifrada, **sem aviso algum do navegador**, em menos de 3 segundos.
- **SC-002**: Uma tela viva conecta e atualiza sem recarregar **pelos dois
  endereços**, medida em cada um separadamente. Uma medida só não vale: o defeito
  que esta feature evita aparece exatamente quando um endereço funciona e o outro
  não.
- **SC-003**: **100%** das tentativas de conexão viva de uma origem não declarada
  são recusadas, e **100%** delas aparecem no registro nomeando a origem.
- **SC-004**: **Zero** interrupção no endereço antigo durante toda a transição,
  medida por requisição antes, durante e depois da mudança.
- **SC-005**: **Zero** credenciais novas no repositório e na imagem publicada,
  medidas pela mesma varredura que a 050 já usa.
- **SC-006**: Subir sem declarar origem extra alguma mantém o comportamento
  atual, provado por um caso que falha se a ausência passar a liberar em vez de
  restringir.

## Assumptions

- **O domínio já foi comprado e a zona de DNS é administrável** por quem opera. A
  compra e a titularidade estão fora desta feature.
- **O intermediário é opcional, e a spec exige o comportamento, não a
  ferramenta.** Cloudflare é a escolha atual de quem opera; se ele sair, os
  critérios continuam valendo. Nomear a ferramenta nos critérios amarraria a
  aceitação a um fornecedor.
- **A emissão e a renovação do certificado continuam com quem já as faz hoje** —
  a plataforma não passa a emitir certificado.
- **O endereço antigo continua enquanto o IP não mudar.** Aposentá-lo é decisão
  futura, e esta feature não a toma: ela só garante que os dois convivem. Quando a
  decisão vier, a lista declarada de FR-004 é o lugar onde ela se aplica.
- **Fora de escopo**: e-mail no domínio, subdomínio de homologação, cache ou CDN
  do intermediário, e qualquer mudança na tela de entrada. Esta feature muda por
  onde se chega, não o que se vê ao chegar.
- **A plataforma continua atrás de um intermediário que termina a cifra e repassa
  a requisição** — é o arranjo de hoje, e a 050 já registrou que ele depende de o
  intermediário enviar o cabeçalho que diz que a origem era cifrada
  ([P2](../050-em-producao/pendencias.md)). Esta feature acrescenta um segundo
  intermediário na frente do primeiro, e por isso a cifra ponta a ponta entra no
  runbook (FR-010).
