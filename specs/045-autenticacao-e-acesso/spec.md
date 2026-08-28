# Feature Specification: Autenticação e papel de acesso

**Feature Branch**: `045-autenticacao-e-acesso`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "Autenticação real e gestão de perfil e papel de acesso, preparando o sistema para produção. Hoje a entrada é sem senha: a tela lista as pessoas cadastradas e a sessão abre por escolha — lacuna declarada. A feature cobre: (1) tela de login com autenticação de verdade (e-mail e senha, produção) e logout; (2) tela de configuração de perfil da pessoa usuária (nome, e-mail, senha, elo com pessoa observada); (3) gestão de papel de acesso na plataforma com quatro níveis de escopo: administrador (gerencia tudo no tenant), person (vê o próprio painel), team (vê os painéis da equipe), project (vê os painéis do projeto). O papel de acesso decide o que a pessoa pode ver e mexer na plataforma — não confundir com o papel organizacional da ontologia (Developer Role, Tech Leader), que é outro vocabulário. Escopo por tenant continua valendo em toda consulta."

## O problema

A entrada da plataforma hoje é uma lacuna declarada: a tela de sign-in lista todas as
contas cadastradas e qualquer visitante abre sessão como qualquer uma delas, inclusive
como administrador. Em desenvolvimento isso serviu; em produção é a ausência de porta.
Além disso, o papel de plataforma conhece só dois valores — administrador e membro — e
"membro" não distingue quem deveria ver apenas o próprio painel de quem acompanha uma
equipe ou um projeto inteiro.

Esta feature fecha a porta (senha de verdade, sessão que se encerra) e substitui o
papel binário por escopos de acesso **acumulativos** — person como piso, team, project
e organization somando por derivação ou concessão, administrador como marca de gestão
noutro eixo —, mantendo intocado o vocabulário dos papéis organizacionais da ontologia
(Developer Role, Tech Leader), que dizem o que a pessoa **faz** na organização — não o
que ela pode **ver e mexer** na plataforma.

## O axioma do acesso

> **A pessoa tem acesso aos dados com os quais está relacionada.**

Todo o modelo de escopo deriva desta frase. O elo declarado diz **quem a conta é**
entre as pessoas observadas; o vínculo com a equipe e a alocação ao projeto dizem
**com o que essa pessoa se relaciona**; o escopo de acesso segue essas relações — por
isso person é o piso de quem tem elo, e os escopos team e project derivados nascem do
fato e fecham com ele (FR-020). A **concessão** existe para o que a relação não cobre:
ver uma equipe, um projeto ou uma organização inteira sem estar relacionado. E
**administrar** não é ver — é o outro eixo (FR-022). A recusa é o mesmo axioma lido
pelo avesso: sem relação e sem concessão, o painel fecha — e diz por quê (FR-011).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entrar com e-mail ou usuário do GitHub, e sair (Priority: P1)

Uma pessoa cadastrada chega à tela de entrada, digita o seu identificador — e-mail ou
usuário do GitHub — e a senha, e abre sessão na sua organização. Quem erra não entra e
recebe uma mensagem que não revela se o identificador existe. Quem está logado encerra
a própria sessão pelo menu, e a sessão encerrada não serve mais para nada. A lista de
contas para escolher deixa de existir.

**Why this priority**: é a condição de produção. Enquanto qualquer visitante abre
sessão como administrador, nenhuma outra regra de acesso significa coisa alguma — os
quatro níveis de escopo protegeriam uma casa sem porta.

**Independent Test**: com duas contas cadastradas (uma com senha definida, outra não),
entrar com a senha correta, falhar com senha errada, falhar com e-mail inexistente,
sair, e confirmar que a sessão encerrada não acessa nenhuma tela protegida.

**Acceptance Scenarios**:

1. **Given** uma conta com senha definida, **When** a pessoa entra com e-mail e senha
   corretos, **Then** a sessão abre na organização da conta e a pessoa vê a tela
   inicial.
2. **Given** uma conta com senha definida e elo vigente com uma pessoa observada,
   **When** a pessoa entra com o usuário do GitHub dessa pessoa e a senha correta,
   **Then** a sessão abre igual à entrada por e-mail.
3. **Given** uma conta com senha definida, **When** a pessoa digita a senha errada,
   **Then** a entrada é recusada com mensagem única ("credenciais inválidas") que não
   diz qual parte errou.
4. **Given** um identificador — e-mail ou usuário do GitHub — que não identifica conta
   nenhuma, **When** alguém tenta entrar, **Then** a recusa é idêntica à de senha
   errada — mesma mensagem, sem revelar que o identificador não existe.
5. **Given** uma conta cujo elo com a pessoa observada foi revogado, **When** ela
   tenta entrar pelo usuário do GitHub, **Then** a entrada é recusada com a mesma
   mensagem única — e a entrada por e-mail continua funcionando.
6. **Given** uma sessão aberta, **When** a pessoa encerra a sessão, **Then** volta à
   tela de entrada e nenhuma tela protegida abre sem novo login.
7. **Given** a tela de entrada, **When** qualquer visitante a acessa, **Then** ela não
   lista conta nenhuma — pede identificador e senha, e nada além.
8. **Given** uma conta criada antes desta feature (sem senha), **When** ela tenta
   entrar, **Then** a plataforma recusa e orienta a procurar quem administra para
   receber uma senha temporária.

---

### User Story 2 - Escopos de acesso acumulativos (Priority: P2)

O acesso à visão é **acumulativo**: a conta enxerga a união dos escopos vigentes, e
nenhum escopo subtrai outro.

- **person é o piso, não um papel**: toda conta com elo vigente vê o próprio painel.
  Ninguém atribui — é o default de quem existe na plataforma.
- **team e project somam por cima**, por dois caminhos: **derivados** das relações da
  pessoa observada (vínculo vigente com equipe, alocação vigente a projeto —
  automáticos, exibidos com a marca de derivado e a origem, fecham sozinhos quando o
  fato deixa de ser observado ou o elo é revogado), ou **concedidos** por
  administrador a quem precisa ver sem estar relacionado — com alvo obrigatório (qual
  equipe, qual projeto) e proveniência (quem concedeu, quando).
- **organization** é o escopo mais largo: vê todos os painéis de uma organização e
  alcança as telas operacionais dela — Syncs, Tools, AI. Só existe por concessão, com
  a organização como alvo — nunca derivado. É o "dono da organização" no vocabulário
  da plataforma.
- **administrador** sai do eixo da visão: é quem **mexe** — contas, concessões,
  ferramentas, credenciais. Ser administrador não abre painel nenhum; quem administra
  e também precisa ver recebe organization por concessão, como qualquer conta.

A tela de gestão mostra, por conta, todos os escopos vigentes — derivados com hachura
e origem, concedidos com quem e quando — e é onde se concede e se revoga.

**Why this priority**: é o motivo de existir da porta. Sem os escopos, todo mundo
logado continua vendo tudo — a entrada com senha protege o tenant de fora, mas não
gradua o acesso por dentro.

**Independent Test**: com quatro contas — uma só com elo (piso), uma com vínculo de
equipe, uma com concessão organization, uma administradora sem concessão — verificar
que cada uma vê exatamente a união dos seus escopos, e que só a administradora alcança
a tela de gestão.

**Acceptance Scenarios**:

1. **Given** uma conta com elo vigente e nenhum escopo além do piso, **When** ela abre
   a lista de pessoas, **Then** alcança o próprio painel e nenhum outro — sem que
   ninguém tenha atribuído nada.
2. **Given** uma conta com elo vigente cuja pessoa observada tem vínculo vigente na
   equipe X, **When** ela navega pelos painéis, **Then** vê o próprio painel e os da
   equipe X — e a tela de gestão mostra o escopo como derivado do vínculo.
3. **Given** uma conta com elo vigente cuja pessoa observada está alocada ao projeto
   Y, **When** ela navega pelos painéis, **Then** vê também os painéis das pessoas
   alocadas ao projeto Y, com o escopo exibido como derivado da alocação.
4. **Given** uma conta sem relação com a equipe X, **When** um administrador concede
   escopo team da equipe X, **Then** ela passa a ver os painéis da equipe X, e a
   concessão registra quem concedeu e quando.
5. **Given** uma conta com concessão organization da organização Z, **When** ela
   navega pelos painéis, **Then** vê todos os painéis das pessoas da organização Z —
   e nada de outra organização do tenant.
6. **Given** uma conta administradora sem concessão de visão e sem elo, **When** ela
   navega pelos painéis, **Then** não vê painel nenhum — administrar não é ver — mas
   alcança a gestão de contas, concessões e ferramentas.
7. **Given** uma conta sem marca de administrador e sem concessão organization —
   piso, team ou project —, **When** ela tenta abrir Syncs, Tools, AI ou a gestão de
   concessões, **Then** a plataforma recusa e diz por quê; essas entradas nem aparecem
   no menu dela.
8. **Given** uma conta com concessão organization da organização Z, **When** ela abre
   Syncs, Tools ou AI, **Then** vê e opera o que pertence à organização Z — e nada
   das outras organizações do tenant. A gestão de contas e concessões continua só de
   administrador.
9. **Given** a única conta administradora do tenant, **When** ela tenta abrir mão do
   próprio papel de administradora, **Then** a plataforma recusa — um tenant nunca
   fica sem administrador.
10. **Given** uma tentativa de conceder team sem dizer a equipe, project sem o projeto
    ou organization sem a organização, **When** o formulário é enviado, **Then** a
    concessão é recusada com o motivo.
11. **Given** um escopo derivado de vínculo com a equipe X, **When** o vínculo deixa
    de ser observado (ou o elo da conta é revogado), **Then** o escopo fecha sozinho
    na navegação seguinte — sem ato de administração. A união do que resta continua
    valendo.

---

### User Story 3 - Configurar o próprio perfil (Priority: P3)

Toda pessoa logada abre a tela do próprio perfil e vê: nome, e-mail, os escopos de
acesso vigentes (cada um com alvo e origem — piso, derivado ou concedido), e o elo com
a pessoa observada (declarado por quem e quando, se houver). Ela edita o próprio nome
e troca a própria senha — confirmando a senha atual. O que ela **não** faz ali:
conceder escopo a si nem declarar o próprio elo — esses dois seguem sendo atos de
administração, e a tela diz isso em vez de esconder os campos.

**Why this priority**: fecha o ciclo da conta — quem entra com senha precisa poder
trocá-la sem chamar quem administra. Vem depois dos outros dois porque depende da porta
(US1) e ganha sentido com os níveis (US2).

**Independent Test**: logar com uma conta de nível person, abrir o perfil, trocar nome
e senha, sair, e entrar de novo com a senha nova.

**Acceptance Scenarios**:

1. **Given** uma sessão aberta, **When** a pessoa abre o próprio perfil, **Then** vê
   nome, e-mail, os escopos vigentes com alvo e origem, e o estado do elo com a pessoa
   observada.
2. **Given** a tela de perfil, **When** a pessoa troca a senha informando a senha atual
   correta e uma nova válida, **Then** a senha muda, e a próxima entrada exige a nova.
3. **Given** a tela de perfil, **When** a pessoa erra a senha atual ao tentar trocá-la,
   **Then** a troca é recusada e a senha vigente permanece.
4. **Given** a tela de perfil de uma conta não administradora, **When** a pessoa
   procura onde ampliar o próprio acesso, **Then** encontra os escopos exibidos como
   informação, com a indicação de que concessão é ato de quem administra e derivação
   acompanha as relações.
5. **Given** uma conta administradora criando ou reiniciando a senha de outra conta,
   **When** a senha temporária é gerada, **Then** ela é exibida uma única vez, e a
   primeira entrada com ela obriga a definição de uma senha nova.

---

### Edge Cases

- Usuário do GitHub **renomeado na origem**: a plataforma reconhece o nome que a
  coleta registrou — o critério de identidade da pessoa observada é o id do GitHub,
  não o nome. Até a próxima coleta, o nome novo não entra; o e-mail sempre entra.
- Conta com papel person **sem elo declarado** com pessoa observada: entra, mas a
  plataforma diz que nenhum painel está alcançável e por quê ("não declararam quem você
  é") — não abre painel nenhum por ausência, nem esconde o motivo.
- Elo com pessoa observada **revogado** enquanto a sessão está aberta: o painel próprio
  deixa de abrir na navegação seguinte, com o motivo.
- Concessão team cuja equipe foi removida (project cujo projeto foi encerrado, ou
  organization cuja organização saiu de observação): o escopo
  fecha — a conta segue vendo só a união dos outros escopos vigentes — e a tela de
  gestão marca a concessão como órfã. Com organization órfã, o acesso operacional
  (Syncs, Tools, AI) fecha junto.
- Duas sessões da mesma conta em navegadores diferentes: a troca de senha numa delas
  encerra a outra na próxima ação.
- Administrador revoga uma concessão enquanto a conta navega: a união nova vale na
  próxima ação da conta, não só no próximo login.
- Tentativas repetidas de senha errada na mesma conta: a plataforma desacelera as
  tentativas (espera crescente) sem bloquear a conta permanentemente.
- Sessão aberta há mais tempo que o limite de validade: a próxima ação volta à tela de
  entrada, preservando para onde a pessoa ia.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST exigir identificador — e-mail ou usuário do GitHub — e
  senha para abrir sessão, e a tela de entrada MUST NOT listar contas cadastradas.
- **FR-002**: A recusa de entrada MUST usar mensagem única que não distingue
  identificador inexistente, elo revogado, ambiguidade ou senha errada.
- **FR-003**: A senha MUST ser armazenada de forma irreversível — ilegível até para
  quem administra o banco — e MUST NOT aparecer em log, exportação ou tela depois de
  definida.
- **FR-004**: A pessoa logada MUST poder encerrar a própria sessão, e a sessão
  encerrada MUST NOT dar acesso a tela protegida nenhuma.
- **FR-005**: Toda tela exceto a de entrada MUST exigir sessão aberta; o acesso sem
  sessão MUST redirecionar à entrada preservando o destino pretendido.
- **FR-006**: O acesso à visão MUST ser acumulativo — a conta enxerga a união dos
  escopos vigentes: **person** (piso de toda conta com elo vigente: o próprio painel),
  mais os escopos **team**, **project** e **organization** que somarem por derivação
  ou concessão. Escopo de acesso é vocabulário da plataforma, distinto do papel
  organizacional da ontologia.
- **FR-007**: Concessão de escopo MUST exigir alvo — team: uma equipe; project: um
  projeto; organization: uma organização do tenant. Concessão sem alvo MUST ser
  recusada com o motivo. Escopo organization MUST existir só por concessão, nunca por
  derivação.
- **FR-008**: Somente administrador MUST poder conceder e revogar escopos e o papel de
  administrador, e cada concessão MUST registrar quem concedeu e quando.
- **FR-009**: A plataforma MUST recusar a operação que deixaria o tenant sem nenhuma
  conta administradora.
- **FR-010**: Cada escopo MUST abrir exatamente: person — o próprio painel via elo
  vigente; team — os painéis das pessoas com vínculo vigente na equipe-alvo; project —
  os painéis das pessoas alocadas ao projeto-alvo; organization — todos os painéis das
  pessoas da organização-alvo.
- **FR-011**: A recusa de acesso a um painel MUST nomear o motivo (sem elo declarado,
  fora dos escopos vigentes, alvo de concessão que não existe mais) — nunca uma recusa
  genérica.
- **FR-012**: A tela de perfil MUST permitir à própria pessoa editar nome e trocar
  senha mediante confirmação da senha atual, e MUST exibir — sem permitir editar —
  todos os escopos vigentes com alvo e origem (piso, derivado, concedido) e o estado
  do elo com a pessoa observada.
- **FR-013**: Administrador MUST poder criar conta e reiniciar senha alheia por senha
  temporária exibida uma única vez; a primeira entrada com senha temporária MUST
  obrigar a definição de senha nova antes de qualquer outra tela.
- **FR-014**: Conta anterior a esta feature, sem senha definida, MUST ser recusada na
  entrada com orientação de procurar quem administra — nunca aceita sem senha.
- **FR-015**: A troca de senha MUST encerrar as demais sessões abertas da conta.
- **FR-016**: Tentativas seguidas de senha errada MUST ser desaceleradas com espera
  crescente, sem bloqueio permanente da conta.
- **FR-017**: O escopo por tenant MUST continuar valendo em toda consulta — nenhum
  escopo, inclusive administrador e organization, MUST enxergar dado de outro tenant.
- **FR-018**: A regra vigente de visibilidade por liderança declarada (a própria
  pessoa, o líder declarado da equipe dela, o responsável da organização) MUST
  continuar valendo; o papel de acesso MUST somar escopo a ela, nunca subtrair o que
  ela já concede.
- **FR-019**: O usuário do GitHub MUST identificar a conta através do elo vigente com
  a pessoa observada — nunca por campo digitado no cadastro. Elo revogado ou ausente:
  só o e-mail identifica. Usuário do GitHub que resolve para mais de uma conta (a
  mesma pessoa observada em mais de um tenant): não identifica nenhuma, e o e-mail
  resolve.
- **FR-020**: A conta com elo vigente MUST receber automaticamente escopo team de
  cada equipe com vínculo vigente da pessoa observada, e escopo project de cada
  projeto a que ela está alocada. O escopo derivado MUST se declarar como derivado —
  marca visual e origem nomeada (o vínculo ou a alocação) — e MUST fechar sozinho
  quando o fato de origem deixa de ser observado ou o elo é revogado.
- **FR-021**: Escopo derivado MUST NOT ser concedido nem revogado à mão — a tela de
  gestão o exibe, nomeia a origem, e não oferece revogação; o caminho para fechá-lo é
  o fato (fim do vínculo ou da alocação) ou a revogação do elo.
- **FR-022**: Ser administrador MUST NOT abrir painel nenhum por si — administrar é
  mexer, ver é escopo. Quem administra e precisa ver recebe concessão como qualquer
  conta. Isto revê a decisão de 2026-08-27 ("admin da plataforma vê tudo"), que
  existia por falta do vocabulário que organization agora dá.
- **FR-023**: As telas operacionais — Syncs, Tools, AI — MUST exigir marca de
  administrador ou concessão organization vigente: administrador alcança tudo no
  tenant; organization alcança o que pertence à organização-alvo. Conta fora dessas
  duas condições MUST NOT ver essas entradas no menu, e o acesso direto por URL MUST
  ser recusado com o motivo. A gestão de contas e concessões MUST continuar exclusiva
  de administrador.

### Key Entities

- **Conta de usuária**: quem entra na plataforma. E-mail (identidade de entrada que
  sempre vale), nome, credencial de senha (irreversível), marca de administrador, elo
  opcional com pessoa observada — que, enquanto vigente, também dá entrada pelo
  usuário do GitHub e o piso person —, pertence a exatamente um tenant. Já existe;
  ganha credencial e escopos acumulativos.
- **Escopo de acesso**: nível (team | project | organization) com alvo obrigatório
  (equipe, projeto ou organização) e origem — **derivado** (do vínculo ou da alocação
  da pessoa observada; fecha com o fato) ou **concedido** (por administrador, com quem
  e quando). person é piso implícito do elo vigente, não um registro. Vocabulário da
  plataforma — não é o papel organizacional da ontologia.
- **Papel de administrador**: marca da conta que pode mexer — contas, concessões,
  ferramentas, credenciais. Não abre painel nenhum (FR-022).
- **Sessão**: o período entre entrada e saída de uma conta. Expira por tempo, encerra
  por logout, e cai quando a senha da conta muda.
- **Elo com pessoa observada**: já existe (declarado, revogável, com proveniência). O
  nível person depende dele para alcançar o próprio painel.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nenhuma tela protegida responde sem sessão aberta — verificado
  percorrendo todas as rotas da plataforma sem login: 100% redirecionam à entrada.
- **SC-002**: Visitante sem senha correta não abre sessão nenhuma: entrada com senha
  errada, identificador inexistente, elo revogado ou conta sem senha falha em 100% das
  tentativas, com a mesma mensagem.
- **SC-003**: Com quatro contas — piso, vínculo de equipe, concessão organization e
  administradora sem concessão — cada uma alcança exatamente a união dos seus escopos
  e nenhum painel além, verificado com dois tenants povoados: 0 vazamentos entre
  escopos e entre tenants.
- **SC-004**: Uma pessoa cadastrada entra na plataforma em menos de 30 segundos a
  partir da tela de entrada, no primeiro uso da senha definitiva.
- **SC-005**: 100% das concessões de escopo registram quem concedeu e quando, visível
  na tela de gestão; 100% dos escopos derivados exibem a marca de derivado e a origem.
- **SC-006**: Toda recusa de acesso a painel exibe motivo específico — 0 recusas
  genéricas nas verificações dos cenários de aceitação.
- **SC-007**: Após logout ou troca de senha, 0 ações aceitas com a sessão antiga.

## Assumptions

- **Recuperação de senha por e-mail fica fora desta entrega.** A plataforma não envia
  e-mail hoje, e o caminho de quem esqueceu a senha é quem administra reiniciá-la por
  senha temporária (FR-013). Auto-serviço de recuperação é feature própria, quando
  houver envio de e-mail.
- **O papel binário atual (admin | member) é substituído pelo modelo acumulativo.**
  Contas `admin` existentes viram administrador **e recebem concessão organization**
  na migração — sem ela perderiam a visão que têm hoje, e a virada de chave não pode
  rebaixar ninguém em silêncio. Contas `member` não recebem nada: o piso person cobre
  o mínimo, e o resto deriva das relações ou vem por concessão — nunca por padrão
  largo.
- **Escopos somam; administrador é marca, não escopo.** Uma conta acumula quantos
  escopos as relações e as concessões derem — a visão é a união. O papel de
  administrador é on/off por conta e vive noutro eixo: mexer, não ver (FR-022).
- **"Dono da organização" = concessão organization.** Nenhum conceito novo de dono:
  quem tem organization vigente é quem, além de ver todos os painéis da organização,
  opera Syncs, Tools e AI dela (FR-023). Se um dia dono precisar ser mais que isso
  (transferir posse, conceder a outros), vira registro próprio — hoje não precisa.
- **A derivação amplia a decisão de visibilidade de 2026-08-26 (issue #369).** Aquela
  decisão dava o painel à própria pessoa, ao líder declarado e ao responsável da
  organização; com o escopo derivado, colegas de equipe e de projeto passam a se ver.
  É mudança deliberada da pessoa mantenedora nesta spec, não efeito colateral —
  registrada aqui para a regra antiga não ser lida como bug.
- **A regra de visibilidade por liderança declarada (issue #369) permanece.** O papel
  de acesso soma escopo; um líder declarado com papel person continua vendo os painéis
  da equipe que lidera (FR-018).
- **Cadastro de conta continua ato administrativo (sign up).** Não há auto-registro:
  quem administra cria a conta — e-mail, nome e, se for o caso, concessões — e entrega a senha
  temporária por canal próprio, fora da plataforma. A primeira entrada obriga a troca
  (FR-013). Auto-registro aberto criaria conta sem papel nem elo num tenant que é, por
  definição, fechado; convite por link fica para quando houver envio de e-mail.
- **A entrada pelo usuário do GitHub reusa o elo declarado.** Nenhum campo novo de
  cadastro: o usuário do GitHub vem da pessoa observada ligada à conta (issue #369), e
  vale enquanto o elo estiver vigente (FR-019).
- **Requisitos de senha**: comprimento mínimo de 12 caracteres, sem exigência de
  composição — regra simples e verificável, alinhada a prática corrente.
- **Sessão expira em 7 dias de inatividade** — padrão razoável para ferramenta interna
  de trabalho; ajustável quando produção mostrar necessidade.
