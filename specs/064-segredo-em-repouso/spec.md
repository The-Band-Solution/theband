# Feature Specification: Todo segredo protegido em repouso — e "protegido" é diferente por tipo

**Feature Branch**: `064-segredo-em-repouso`

**Created**: 2026-09-12

**Status**: Draft

**Input**: User description: *"todas as senhas devem ser criptografadas no banco de dados"*

---

## A premissa do pedido, corrigida pela medição

O pedido diz **criptografar as senhas**. Medido no banco em 2026-09-12, e a correção importa
porque a leitura literal seria um **retrocesso**:

| o que está guardado | como | é o tratamento certo? |
|---|---|---|
| `users.password_hash` | **bcrypt** (`character varying`) | **sim, e cifrar seria pior** |
| `tool_credentials.secret` | cifrado AES.GCM (`bytea`) | sim |
| `ai_provider_credentials.secret` | cifrado AES.GCM (`bytea`) | sim |
| `users.session_token` | **texto claro** (`character varying`) | **não — é o achado** |

**Senha não se cifra: senha se resume (hash).** Cifra é reversível por quem tem a chave, e é
por isso que ela é o tratamento certo para credencial de terceiro — a plataforma precisa
apresentá-la ao GitHub depois. Uma senha a plataforma nunca precisa recuperar: precisa apenas
**comparar**. Cifrar `password_hash` criaria um caminho para ler a senha de alguém, que hoje
não existe — e a chave mestra passaria a ser a chave de todas as contas.

Então esta feature **não** troca o hash. Ela cobre o que o pedido de facto protege: **nenhum
segredo em claro no banco**, e o achado é outro do que se pensava.

## Os dois achados, medidos e não deduzidos

### 1. `users.session_token` em texto claro

**Correção de 2026-09-13.** A primeira redação dizia *"quem a tem entra como aquela pessoa,
sem senha e sem segundo fator"*. **Está errado**, e foi escrito sem ler o caminho inteiro.

Medido depois: a sessão é um **cookie assinado** com o `SECRET_KEY_BASE`, que **não está no
banco**. O valor desta coluna é comparado com o que veio nesse cookie — não com algo que o
cliente apresente direto. Quem lê um dump **não** entra: falta a assinatura.

O que é verdade, e continua bastando para a correção: o valor é **metade** de uma credencial
de duas partes. A outra metade é o `SECRET_KEY_BASE`, que vive no ambiente. Quem tem **as
duas** assume qualquer conta; quem tem só uma, não assume nenhuma.

E as duas metades estão hoje em lugares com exposições muito diferentes — uma no ambiente, a
outra legível em **toda cópia do banco**. Um vazamento do `SECRET_KEY_BASE` tornaria cada
backup suficiente para assumir todas as contas.

Isso **rebaixa a severidade** e **não dispensa o conserto**. O detalhe da medição está em
[research.md, R1](research.md#r1--o-que-o-session_token-é-de-fato).

E a decisão de 2026-09-12 manda o backup para um **segundo host** — ou seja, essa coluna passa
a existir em mais um lugar, fora da máquina que a produção protege.

### 2. Um token do GitHub em claro dentro de `oban_jobs.errors`

Verificado por medição em 2026-09-12: a linha de erro tem 8 766 bytes, contém um argumento de
**40 caracteres** logo após `graphql(`, e ele **termina no mesmo `last_four`** da credencial
guardada em `tool_credentials`.

**O mecanismo**: o token é argumento nu de `Client.graphql/5`. Quando uma exceção sobe daquela
chamada, a lista de argumentos vai no quadro de pilha, `Exception.format/3` a imprime, e o
Oban grava o texto. O `redact: true` do schema protege o `inspect` da **struct**, e não o
argumento solto que já foi decifrado.

**A consequência de ordem**: a faxina automática de registros antigos está configurada para 7
dias, e **esta linha ela nunca vai apagar**. Medido em 2026-09-12: a linha tem 8 dias, está no
estado *cancelada*, e a data de cancelamento dela está **vazia**. A faxina pergunta *"data de
cancelamento é anterior ao prazo?"* — e essa pergunta, feita sobre um campo vazio, nunca
responde sim. A linha é permanente. As outras três canceladas do mesmo dia estão na mesma
situação.

Ou seja, a proteção que se poderia supor **não existe em dois níveis**: ela não alcança as
cópias já tiradas, e neste caso não alcança nem o banco. O que passa para uma cópia não se
desfaz — e aqui o original também não sai sozinho.

### O que já foi feito nessa linha, em 2026-09-12

A pessoa mantenedora decidiu **manter o registro e tirar o segredo**. Feito: os 40 caracteres
foram trocados por uma marca de redação, e o registro do erro continua inteiro — mesmo estado,
mesma linha, 8 766 → 8 754 bytes. O banco inteiro foi varrido em seguida (259 colunas de
texto), zero ocorrências, e a varredura foi **provada com um caso positivo plantado e
desfeito** — sem isso ela não distinguiria limpo de cego.

Duas coisas que isso **não** resolve, e são o motivo de a spec existir:

1. **O valor esteve legível por oito dias.** Redigir alcança o banco, não alcança dump nenhum
   já tirado. A rotação é o único ato que invalida o que foi exposto, e é ação de quem tem
   acesso ao GitHub — registrada em
   [`docs/backlog/rotacionar-o-token-que-vazou.md`](../../docs/backlog/rotacionar-o-token-que-vazou.md).
2. **A causa foi corrigida no caminho do GitHub, e não nos demais.** `TheBand.Segredo`
   embrulha o valor assim que ele sai do cofre e só se abre na montagem do cabeçalho HTTP —
   é a FR-006 atendida ali. O caminho do provedor de modelos ainda passa o segredo como
   binário nu; nenhuma ocorrência foi medida nele, e ausência de medida não é ausência de
   risco.

### O mecanismo exato, que custou um teste falhando para ser encontrado

O primeiro teste que escrevi levantava uma exceção com `raise` dentro da função e **não
reproduzia nada**: os argumentos não apareciam no texto formatado. A máquina virtual só
guarda a lista de argumentos no quadro de pilha quando o erro nasce da **própria chamada** —
nenhuma cláusula casou. É essa a forma gravada em `oban_jobs.errors`, com os argumentos
impressos um a um.

Isso muda o que o requisito precisa dizer: não basta *"não registre o segredo"*. O valor
chega ao texto **sem ninguém o registrar**, por um caminho que nenhuma revisão de código
que procure chamadas de log encontraria.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nenhum segredo em claro chega a um backup (Priority: P1)

Quem opera a plataforma tira uma cópia do banco e a envia para outro host. Hoje essa cópia
carrega tokens de sessão vivos e, pelo menos numa linha medida, um token de acesso ao GitHub —
em texto que se lê sem chave nenhuma.

**Why this priority**: é o único dos três com **perda irreversível**. Corrigir depois não
alcança a cópia já escrita, e cada cópia tirada antes da correção guarda o segredo para
sempre. As outras duas histórias podem ser corrigidas com o sistema em uso.

**Independent Test**: varrer um dump do banco com o padrão de cada tipo de segredo e obter
**zero** ocorrências — e provar que a varredura acha, injetando um valor conhecido antes.

**Acceptance Scenarios**:

1. **Given** um dump do banco de produção, **When** ele é varrido pelos padrões de segredo
   declarados, **Then** o resultado é **zero ocorrências**, e o relatório diz quais padrões
   foram procurados e em quantos bytes.
2. **Given** um segredo conhecido gravado propositalmente numa coluna de diagnóstico,
   **When** a varredura roda, **Then** ela **o encontra** — uma varredura que nunca acha nada
   não prova ausência, prova que não olha.
3. **Given** a varredura acusando uma ocorrência, **When** quem opera decide, **Then** a
   credencial é **rotacionada** antes de qualquer cópia, e apagar a linha **não** substitui a
   rotação: segredo que apareceu, apareceu.

---

### User Story 2 - O token de sessão deixa de ser legível no banco (Priority: P2)

Uma pessoa entra na plataforma e sua sessão passa a valer. O valor que prova essa sessão fica
guardado de um jeito que **não permite** a quem lê o banco se passar por ela.

**Why this priority**: fecha a credencial ao portador. Vem depois da P1 porque a P1 impede que
o problema se multiplique em cópias, e esta o resolve na origem.

**Independent Test**: ler a coluna direto no banco, tentar usar o valor lido como sessão, e a
entrada **recusar** — com a mensagem única de sempre, sem nomear o motivo.

**Acceptance Scenarios**:

1. **Given** uma sessão viva, **When** alguém lê a coluna diretamente no banco e apresenta o
   valor lido **junto com a chave que assina o cookie**, **Then** a plataforma **recusa**, e a
   recusa é a mensagem única — não dizer *"token inválido"* é o que impede enumerar.

   *A chave faz parte do cenário de propósito*: sem ela a recusa já acontece hoje, e o teste
   passaria sem medir nada. O que se exige é que ler o banco não baste **nem para quem tem a
   outra metade**.
2. **Given** a mudança aplicada, **When** uma pessoa com sessão aberta age, **Then** a sessão
   dela continua valendo **ou** é encerrada de forma anunciada; o que **não** pode é ela cair
   sem explicação.
3. **Given** uma restauração de backup, **When** a plataforma sobe contra o banco restaurado,
   **Then** o que acontece com as sessões daquele instante está **escrito no runbook**, e não
   é descoberto no dia.

---

### User Story 3 - Segredo nunca chega a log, erro ou campo de diagnóstico (Priority: P3)

Um job falha. A plataforma registra o que aconteceu para quem for investigar — e o registro
**não** contém o segredo que o job usava.

**Why this priority**: é a origem do achado 2, e sem ela o problema volta na próxima função
que receba um segredo como argumento. Vem por último porque as duas primeiras estancam o que
já existe.

**Independent Test**: forçar uma exceção na chamada que recebe o segredo e conferir que o
registro guardado **não** o contém — e que contém o suficiente para investigar.

**Acceptance Scenarios**:

1. **Given** uma função que recebe um segredo, **When** uma exceção sobe dela, **Then** o
   registro do erro mostra a chamada e **não** mostra o segredo.
2. **Given** o mesmo erro, **When** quem investiga o lê, **Then** ele consegue dizer **qual**
   credencial falhou — por rótulo ou pelos últimos quatro caracteres —, sem que o valor
   apareça.
3. **Given** um segredo novo acrescentado ao sistema, **When** alguém o passa adiante,
   **Then** o tipo dele **impede** que chegue a texto por construção, e não por disciplina de
   quem escreve.

---

### Edge Cases

- **Segredo que já está numa cópia tirada.** Não há correção possível no arquivo: o caminho é
  **rotacionar** a credencial e registrar a data. A spec trata isso como ato de operação, e
  não como defeito a consertar no código.
- **A varredura que não acha nada.** É o resultado esperado e o mais perigoso de aceitar: sem
  um caso positivo conhecido, ela não distingue *limpo* de *não olhou*.
- **Rotacionar o token de sessão derruba quem está dentro.** Aceitável se anunciado;
  inaceitável se silencioso.
- **Segredo em coluna de diagnóstico de terceiro.** O Oban é uma dependência: o campo de erro
  é dele, e a plataforma não escolhe o formato. O que a plataforma escolhe é **o que entrega**
  a ele.
- **A chave mestra.** Ela não está no banco — conferido: nenhuma coluna `%master%` ou
  `%vault%` existe. Se um dia estiver, a cifra das credenciais deixa de proteger o dump, e
  esta spec é onde a proibição fica escrita.
- **Backup restaurado num ambiente de teste.** A cópia leva os mesmos segredos; quem restaura
  em ambiente menos protegido move o risco junto.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Senha de conta MUST ser guardada como **resumo (hash)** com sal, e MUST NOT ser
  guardada cifrada nem em claro. Cifra é reversível por quem tem a chave, e criaria um caminho
  para ler a senha de alguém — caminho que hoje não existe.
- **FR-002**: Credencial de terceiro que a plataforma precisa **apresentar** — token de
  ferramenta, chave de provedor de modelo — MUST ser guardada cifrada, com a chave **fora do
  banco**.
- **FR-003**: A chave que decifra as credenciais MUST NOT ser guardada em nenhuma tabela, e
  MUST NOT estar no mesmo lugar que a cópia do banco. Um dump que carregue os dois não tem
  cifra nenhuma.
- **FR-004**: Token de sessão MUST NOT ser legível no banco de forma que permita a quem o lê
  se passar pela pessoa. *(O tratamento — resumo, cifra ou substituição — é decisão de plano;
  o requisito é a propriedade.)*
- **FR-005**: Nenhum segredo MUST chegar a log, mensagem de erro, campo de diagnóstico ou
  telemetria — **em nenhum nível**, inclusive os que não se publicam em produção.
- **FR-006**: A proibição da FR-005 MUST ser garantida **pelo tipo do dado**, e não pela
  disciplina de quem escreve. Um segredo passado adiante MUST NOT poder virar texto por
  acidente — incluindo em lista de argumentos de quadro de pilha.
- **FR-007**: Um registro de erro que envolva credencial MUST permitir dizer **qual**
  credencial falhou — por rótulo ou pelos últimos quatro caracteres — **sem** conter o valor.
- **FR-008**: A plataforma MUST oferecer uma **varredura** que procure, num dump ou no banco,
  os padrões de cada tipo de segredo que ela guarda, e MUST relatar quais padrões procurou.
- **FR-009**: A varredura MUST ser provada por um **caso positivo conhecido**: com um segredo
  plantado, ela o encontra. Varredura que nunca acha nada não distingue limpo de cego.
- **FR-010**: A varredura MUST rodar **antes da primeira cópia** para um destino novo, e o
  resultado MUST ficar registrado com a data. O que passa para uma cópia não se desfaz.
- **FR-011**: Achada uma ocorrência, a credencial MUST ser **rotacionada**, e apagar a linha
  MUST NOT ser tratado como substituto: segredo que apareceu, apareceu.
- **FR-012**: A remoção automática de registros antigos MUST NOT ser contada como proteção,
  por duas razões independentes: ela não alcança as cópias já tiradas, e ela **não alcança
  todo registro que se supõe alcançar** — um registro sem a data que a regra de idade consulta
  fica fora dela para sempre. Medido em 2026-09-12: quatro registros de 8 dias permanentes sob
  uma política de 7, um deles carregando o segredo.
- **FR-016**: Toda credencial de terceiro MUST ter **idade conhecida**, e a plataforma MUST
  **pedir a troca** quando ela passar de **três meses** sem ser trocada. Pedir, e não impedir:
  a coleta continua, e quem decide trocar é a pessoa mantenedora.
- **FR-017**: O pedido de troca MUST ser visível **onde a credencial é administrada**, e MUST
  dizer **há quanto tempo** ela está em uso — não apenas que está velha. *"Registrada há 4
  meses"* é acionável; *"credencial antiga"* não.
- **FR-018**: Trocar a credencial MUST zerar a contagem, e a data da troca MUST ficar
  registrada. Sem o registro, a próxima cobrança não sabe se a anterior foi atendida.
- **FR-019**: Uma credencial cuja idade **não se sabe** MUST ser mostrada como *idade
  desconhecida*, e MUST NOT ser contada como dentro do prazo. Ausência de data não é prova de
  juventude — é a mesma família do registro sem data de encerramento da FR-015.
- **FR-015**: Um registro que a plataforma dá por encerrado MUST carregar a data do
  encerramento. Sem ela, toda regra que apaga por idade o ignora em silêncio — e o registro
  que escapa por esse caminho é justamente o que falhou, que é o que tende a carregar segredo.
- **FR-013**: O efeito de uma restauração sobre as sessões vivas MUST estar escrito no
  procedimento de restauração, e MUST NOT ser descoberto durante um desastre.
- **FR-014**: Segredo novo acrescentado ao sistema MUST declarar a que tipo pertence — resumo,
  cifra reversível, ou não-guardável — **antes** de existir coluna para ele.

### Key Entities

- **Segredo**: um valor cuja leitura por terceiro causa dano. Tem **tipo**, e o tipo decide o
  tratamento: *senha* (resumo), *credencial de terceiro* (cifra reversível), *prova de sessão*
  (a decidir no plano), *chave mestra* (nunca no banco).
- **Registro de diagnóstico**: o que a plataforma guarda quando algo falha. Tem dono externo
  (o executor de tarefas), e a plataforma controla **o que entrega** a ele, não o formato.
- **Cópia do banco**: um dump, e todo lugar para onde ele vai. Herda todos os segredos do
  instante em que foi tirado, e **não se corrige depois**.
- **Varredura**: o ato de procurar padrões de segredo num dump ou no banco, com um caso
  positivo que prova que ela enxerga.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Uma varredura sobre a cópia mais recente do banco devolve **zero** ocorrências
  de segredo em claro, e o relatório nomeia cada padrão procurado.
- **SC-002**: A mesma varredura, com um segredo plantado, o **encontra** — em cem por cento
  das execuções de verificação.
- **SC-003**: Quem lê o banco diretamente **não consegue** assumir a sessão de ninguém —
  **nem tendo a chave que assina o cookie**. A tentativa é recusada, com a mensagem única.
  Sem a cláusula da chave, este critério já estaria satisfeito hoje e não mediria nada.
- **SC-004**: Forçada uma falha em cada caminho que usa credencial, **nenhum** registro de
  erro contém o valor da credencial — e **todos** permitem identificar qual delas era.
- **SC-005**: Existe um registro datado da varredura feita **antes** da primeira cópia para
  cada destino novo.
- **SC-006**: O procedimento de restauração diz o que acontece com as sessões vivas, e alguém
  que nunca o leu chega à resposta certa em menos de um minuto.
- **SC-007**: Nenhuma senha de conta é recuperável a partir do banco, nem por quem tem todas
  as chaves da plataforma.
- **SC-009**: Nenhuma credencial com mais de três meses de uso passa despercebida: a tela que
  a administra pede a troca, e diz há quanto tempo ela está lá.
- **SC-010**: Uma credencial sem data conhecida aparece como **idade desconhecida**, e não
  como dentro do prazo — quem olha a tela consegue dizer quais são os dois casos.
- **SC-008**: Nenhum registro encerrado existe sem a data do encerramento — a consulta que os
  procura devolve **zero**, e uma regra de idade aplicada à tabela não deixa nenhum para trás.

---

### O que esta política NÃO é

**Não é expiração.** A credencial continua funcionando depois dos três meses, e a coleta não
para. Expirar automaticamente transformaria uma boa prática em queda de serviço num dia que
ninguém escolheu — e a plataforma coleta de fonte de terceiro, onde uma parada silenciosa
vira dado faltando que só se descobre depois.

**Não é substituto da rotação por exposição.** Três meses é o prazo do que **não** aconteceu
nada. Um segredo que apareceu em claro precisa ser trocado **agora**, e é o caso aberto em
`docs/backlog/rotacionar-o-token-que-vazou.md`. Confundir os dois faria alguém adiar a
urgente até o vencimento da rotineira.

**O prazo teria pegado o caso real**: a credencial `…omAX` foi registrada em 2026-09-04. Em
2026-12-04 ela venceria por esta política — mas ela já precisava de troca em 2026-09-12, por
exposição. São gatilhos diferentes.

## Assumptions

- **O hash de senha não muda.** `bcrypt` com sal é o tratamento certo, e a leitura literal do
  pedido — *"criptografar as senhas"* — seria um retrocesso. Esta suposição está no corpo da
  spec porque ela **contraria o texto do pedido**, e quem discordar precisa ver isso escrito.
- **A cifra das credenciais de terceiro já está certa** — AES.GCM com chave fora do banco,
  conferido em 2026-09-12. A spec a **descreve** para que ela não seja desfeita por engano, e
  não propõe mudá-la.
- **A medição vale para o banco de desenvolvimento.** O mecanismo do achado 2 é código
  compartilhado, mas **se há linha com token em produção, ninguém mediu ainda** — e a FR-010
  existe por isso.
- **O executor de tarefas continua sendo o Oban**, e o campo de erro continua sendo dele. Se
  mudar, o requisito não muda: a plataforma controla o que entrega.
- O tratamento do token de sessão (FR-004) fica para o plano. A spec declara a **propriedade**
  — não dá para se passar por alguém lendo o banco —, e não o mecanismo.

---

## Dependencies

- A decisão de 2026-09-12 de enviar o backup para um **segundo host** é o que torna a P1
  urgente: mais um lugar guardando os mesmos segredos.
- O item `backup-restaurado-de-verdade` do backlog depende desta spec para a **ordem**: a
  varredura vem **antes** da primeira cópia.
- A avaliação de segurança `2026-09-12-destino-de-backup-em-segundo-host.md` levantou o achado
  2; esta spec o transforma em requisito.

## Out of Scope

- **A topologia do destino de backup** — segundo host, provedor, conta, TLS. É outra decisão,
  e está no item de backlog do MinIO.
- **A rotação da credencial encontrada**: é ato de operação, e quem o faz é quem tem acesso ao
  GitHub. A spec exige que aconteça (FR-011); não a executa.
- **Cifrar o banco inteiro em repouso** (disco, volume, provedor). É defesa de outra camada e
  não substitui nenhum requisito aqui — cifra de volume protege o disco roubado, e não o dump
  legítimo copiado para outro host.
