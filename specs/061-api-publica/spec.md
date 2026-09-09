# Feature Specification: A API pública com token — o The Band consumido de fora

**Feature Branch**: `feat/061-api-publica`

**Created**: 2026-09-08

**Status**: Draft — escrita pelo papel de Product Owner a pedido da pessoa
mantenedora em 2026-09-08. **Nenhuma decisão de arquitetura é tomada aqui**: a
seção *Impacto* nomeia o que exige ADR, e a seção *Perguntas abertas* o que exige
resposta humana antes do `/speckit-plan`. A tela de tokens **não tem protótipo
aprovado** — e sem ele esta spec não é decomposta em tarefas (ver *O protótipo vem
antes do código*).

**Input**: User description, textual: *"Faça uma especificação de adicionar no The
Band a funcionalidade de ser consumido via API. Para consumir a API o cliente
precisa de um token que será gerado na área administrativa. A API precisa de ter
Swagger."*

## O que esta feature resolve

Hoje o The Band só responde para olho humano. As respostas existem — equipes,
membros, medidas, pessoas, projetos, sincronizações —, e **a única porta é o
LiveView**. Quem quer o mesmo número num painel próprio, numa planilha ou num
agente não tem por onde entrar.

O `router.ex` já declara a pipeline `:api` (`plug :accepts, ["json"]`) e **nenhuma
rota passa por ela**. A pipeline está lá desde o gerador; a porta nunca foi aberta.

Duas coisas que esta feature **não** é:

**Não é "expor o banco por JSON".** A plataforma inteira existe para separar o que
foi **observado** do que foi **derivado** e do que foi **declarado**. Uma resposta
que entrega número sem essa marca destrói a distinção exatamente no ponto de
entrega — e o consumidor do outro lado pode ser um modelo, que vai afirmar o número
sem a ressalva. O argumento está escrito em
[`docs/backlog/servidor-mcp.md`](../../docs/backlog/servidor-mcp.md) e vale igual
aqui.

**Não é um segundo modelo de acesso.** O veredito de quem vê o quê é
`TheBand.Tenants.Access` — `scopes/2`, `pode_ver/3`, `pode_ver_equipe/3` —, e ele já
resolve o problema. Um token que trouxesse permissão própria criaria uma segunda
verdade sobre acesso, e a segunda verdade divergiria da primeira no primeiro sprint.

### O que esta feature desbloqueia

[`docs/backlog/servidor-mcp.md`](../../docs/backlog/servidor-mcp.md) está marcado
**bloqueado** no [README do backlog](../../docs/backlog/README.md) com a razão
exata: *"depende de decidir autenticação e tenant"*. É a decisão 1 daquele
documento, e é o que esta feature decide. O servidor MCP continua fora de escopo
aqui — mas deixa de estar bloqueado quando esta entrar.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quem administra gera um token, e vê o valor uma única vez (Priority: P1)

Quem administra o tenant abre a área administrativa, cria um token com um rótulo
("painel do diretor", "planilha do RH"), e **o valor em claro aparece uma única
vez**, com o aviso de que não voltará. A lista de tokens mostra o rótulo, os
**últimos quatro caracteres**, quem gerou, quando, e o **último uso** — nunca o
valor.

**Why this priority**: sem token não há API. É a única história desta feature que
não depende de nenhuma outra, e as duas P1 seguintes dependem dela.

**Independent Test**: criar um token, copiar o valor, recarregar a tela e conferir
que o valor não aparece em nenhum lugar da página, do HTML servido, do log da
aplicação nem do banco em claro.

**Acceptance Scenarios**:

1. **Given** uma conta administradora, **When** ela cria um token com rótulo,
   **Then** a tela mostra o valor em claro **uma vez**, com aviso explícito de que
   não será mostrado de novo, e ação de copiar.
2. **Given** o token acabou de ser criado, **When** a pessoa recarrega ou navega e
   volta, **Then** o valor em claro **não** aparece, e a linha mostra
   `••••••••••••••••` seguido dos quatro últimos caracteres.
3. **Given** um token nunca usado, **When** a lista é aberta, **Then** a coluna de
   último uso diz **"nunca usado"** — não uma data vazia e não a data de criação.
4. **Given** um token usado, **When** a lista é aberta, **Then** o último uso mostra
   a data e hora da **última chamada aceita**.
5. **Given** uma conta que não é administradora, **When** ela tenta abrir a tela de
   tokens, **Then** o acesso é recusado com motivo nomeado.
6. **Given** um token criado, **When** se inspeciona o registro no banco, **Then**
   **não existe** coluna alguma com o valor em claro nem reversível ao valor em
   claro.

---

### User Story 2 - O cliente chama a API e recebe dado do seu tenant (Priority: P1)

Um cliente com token faz `GET /api/v1/teams` com `Authorization: Bearer <token>` e
recebe as equipes **do tenant do token** — nem mais, nem menos. O recorte é o mesmo
que a conta dona do token vê na tela.

**Why this priority**: é o valor da feature. Sem ela o token não serve para nada.

**Independent Test**: com dois tenants povoados, chamar o mesmo endpoint com o
token de cada um e conferir que nenhum identificador do outro tenant aparece em
nenhuma resposta.

**Acceptance Scenarios**:

1. **Given** um token válido do tenant A, **When** o cliente chama
   `GET /api/v1/teams`, **Then** recebe `200` com as equipes do tenant A, no
   recorte da conta dona do token.
2. **Given** um token do tenant A e um identificador de equipe do tenant B,
   **When** o cliente chama `GET /api/v1/teams/<id-do-B>`, **Then** recebe `404` —
   e **não** `403`, porque para este token aquele recurso não existe.
3. **Given** uma requisição sem cabeçalho `Authorization`, **When** ela chega,
   **Then** a resposta é `401` no formato de erro padrão.
4. **Given** uma resposta que carrega medida, **When** o cliente a lê, **Then o
   objeto traz a proveniência** de cada afirmação e as **limitações declaradas** da
   medida no mesmo objeto — não em documentação apartada.
5. **Given** um dado não observado, **When** ele é serializado, **Then** vem
   **nomeado** como não observado, e **nunca** como `0` nem como `null` mudo.
6. **Given** uma coleção com mais itens que o tamanho de página, **When** o cliente
   pede a página seguinte, **Then** recebe os itens seguintes sem repetição nem
   omissão.

---

### User Story 3 - Quem administra revoga, e o cliente passa a receber recusa (Priority: P1)

Quem administra revoga um token na área administrativa. A chamada seguinte daquele
cliente é recusada. A linha do token **continua na lista**, marcada como revogada,
com data e quem revogou.

**Why this priority**: um token que não se revoga é um segredo permanente. Emitir
sem poder revogar é pior que não emitir.

**Independent Test**: chamar um endpoint com sucesso, revogar, e chamar de novo —
a segunda chamada é recusada, e a lista mostra a revogação sem apagar a linha.

**Acceptance Scenarios**:

1. **Given** um token em uso, **When** quem administra o revoga, **Then** a chamada
   seguinte com aquele token recebe `401`.
2. **Given** um token revogado, **When** a lista é aberta, **Then** a linha
   **existe**, marcada revogada, com data e quem revogou — **0** linhas removidas
   fisicamente.
3. **Given** um token revogado, **When** alguém tenta reativá-lo, **Then** não há
   ação de reativar: revogação é definitiva, e o caminho é gerar outro.
4. **Given** um token revogado, **When** o cliente lê a recusa, **Then** a resposta
   é **indistinguível** da recusa de token inexistente ou expirado (ver FR-014).

---

### User Story 4 - Swagger navegável, e o contrato que ele descreve (Priority: P2)

Quem vai integrar abre um endereço, vê os endpoints, os parâmetros, os formatos de
resposta e os de erro, e **experimenta com o próprio token**. A descrição é gerada
do código, não mantida à mão.

**Why this priority**: P2 porque as três P1 entregam uma API consumível — com
`curl` e a spec em prosa. O Swagger encurta a integração de horas para minutos, e
o pedido da pessoa mantenedora é explícito, mas não é o que faz a API existir.

**Independent Test**: abrir a interface, executar um `GET` com token válido e ver a
resposta real; conferir que um endpoint acrescentado no código aparece na descrição
sem edição manual de nenhum arquivo de documentação.

**Acceptance Scenarios**:

1. **Given** a aplicação em execução, **When** alguém abre o endereço do Swagger,
   **Then** vê **todos** os endpoints de `/api/v1`, com parâmetros e formato de
   resposta.
2. **Given** a interface aberta, **When** a pessoa informa um token e executa uma
   chamada, **Then** recebe a resposta real da aplicação.
3. **Given** um endpoint novo no código, **When** a descrição é regerada, **Then**
   ele aparece — e a divergência entre código e descrição é **detectável no CI**.
4. **Given** o documento OpenAPI, **When** ele é validado, **Then** passa por
   validador de esquema OpenAPI sem erro.
5. **Given** a interface do Swagger, **When** um token é informado nela, **Then**
   ele **não** é persistido pela aplicação nem aparece em log.

---

### User Story 5 - Limite de taxa por token (Priority: P2)

Um cliente que chama demais é contido: recebe `429`, com quanto falta para
reabrir, e os cabeçalhos que dizem quanto do saldo resta. A plataforma continua
respondendo aos outros.

**Why this priority**: P2 porque a API sem limite funciona — até o primeiro cliente
com laço mal escrito. É contenção de risco operacional, não valor novo, e um teto
único de infraestrutura mitiga parcialmente enquanto isso.

**Independent Test**: com um limite baixo configurado, disparar chamadas acima dele
com um token e conferir `429` para ele e `200` para outro token no mesmo instante.

**Acceptance Scenarios**:

1. **Given** um token que excedeu o limite na janela, **When** ele chama de novo,
   **Then** recebe `429` no formato de erro padrão, com o tempo até reabrir.
2. **Given** um token contido, **When** outro token chama no mesmo instante,
   **Then** o outro recebe `200` — a contenção é **por token**, não global.
3. **Given** qualquer resposta aceita, **When** o cliente lê os cabeçalhos,
   **Then** encontra limite, restante e reabertura.
4. **Given** a janela reaberta, **When** o cliente chama, **Then** volta a ser
   atendido sem intervenção humana.

---

### User Story 6 - O que a API expõe além do primeiro corte (Priority: P3)

O que ficou fora do primeiro corte — escrita, o rastro de mudanças, verificações,
previsão, os dados brutos coletados — é decidido **depois**, por pedido de quem
integra, e não por antecipação.

**Why this priority**: P3 porque é escopo cuja demanda ainda não existe. Cada
endpoint acrescentado é contrato público que passa a ter custo de manutenção
permanente — e contrato público, nesta casa, **exige ADR para mudar**. Abrir o que
ninguém pediu é assumir custo sem valor observado.

**Independent Test**: não aplicável — é um marcador de escopo. A verificação é que
nenhuma outra história desta feature entregue endpoint fora da lista de FR-020.

---

### Edge Cases

- **Token válido cuja conta dona foi desativada ou removida.** O token não pode
  sobreviver à conta que o define — é dela que ele herda o alcance. **Recusa**, e o
  mesmo `401` uniforme (FR-016).
- **Token válido cuja pessoa perdeu todos os vínculos.** `Access.scopes/2` lê as
  relações vigentes a cada chamada: o alcance encolhe sozinho, sem job e sem
  coluna. A resposta fica menor; não vira erro.
- **Senha da conta dona trocada.** A sessão de navegador cai por divergência de
  `session_token` (FR-015 da 045). O token de API **não** é sessão — ver a pergunta
  Q4: se ele cai também, trocar senha derruba integrações silenciosamente.
- **Dois tokens da mesma conta.** Legítimo, e é o caso comum: um por integração,
  para revogar uma sem derrubar as outras.
- **Token no corpo, na query string ou em cookie.** Não é aceito: só o cabeçalho
  `Authorization`. Query string vaza para log de servidor e para histórico de
  navegador.
- **Token com prefixo certo e resto inválido.** Mesma recusa uniforme. O prefixo
  serve para varredura de segredo vazado, não para triagem de validade.
- **Chamada concorrente com o mesmo token.** Permitida. O carimbo de último uso é
  o mais recente, e escrevê-lo não serializa as chamadas (ver Q6).
- **Coleção vazia.** `200` com lista vazia e a distinção dita: *nada encontrado*
  não é o mesmo que *não coletado*.

---

## Requirements *(mandatory)*

### O token: forma, geração e guarda

- **FR-001**: O token gerado tem **prefixo fixo que o identifica como desta
  plataforma** — proposta: `tbnd_` —, seguido da parte aleatória. O prefixo existe
  para que varredura de segredo em repositório, log e histórico de terminal
  reconheça o vazamento sem saber o valor.
- **FR-002**: A parte aleatória tem no mínimo **32 bytes de entropia** de gerador
  criptográfico, codificada em alfabeto seguro para URL e para copiar e colar.
- **FR-003**: O sistema guarda **apenas o hash** do token. Não existe coluna com o
  valor em claro, e **não existe coluna cifrada reversível ao valor em claro**.
- **FR-004**: FR-003 é uma **divergência deliberada** do padrão da casa para
  segredo. `TheBand.Sources.ToolCredential` cifra com Cloak
  (`TheBand.Encrypted.Binary`) **porque precisa recuperar o segredo** para chamar o
  GitHub. Aqui o valor nunca é usado de volta: só comparado. Guardar reversível
  seria manter um segredo recuperável sem ter uso para a recuperação.
- **FR-005**: A escolha da função de hash é **decisão de arquitetura e de
  segurança**, e não é tomada nesta spec. O que a spec exige: a comparação acontece
  em **tempo constante**, e a função é adequada a **uma verificação por
  requisição** — o `bcrypt_elixir` usado para senha custa ~100 ms por verificação
  por desenho, e esse custo é a proteção de um segredo de baixa entropia escolhido
  por gente, não de um segredo de 32 bytes gerado por máquina. Ver Q1 e *Impacto*.
- **FR-006**: O valor em claro é apresentado **uma única vez**, na resposta da
  criação. Não há endpoint, tela, exportação nem consulta que o mostre de novo.
- **FR-007**: O registro guarda os **quatro últimos caracteres** para distinguir um
  token do outro na interface, reusando o padrão de
  `ToolCredential.last_four/1` e `masked/1` — quatro caracteres não reduzem
  materialmente o espaço de busca de um segredo de 32 bytes.
- **FR-008**: O esquema do token deriva `Inspect` **excluindo** o valor e o hash, e
  marca os campos como `redact`, como `ToolCredential` faz. É a proteção no lugar
  onde o vazamento acontece de fato: um `inspect/1` em mensagem de erro, em log de
  exceção ou em telemetria escrita às pressas.
- **FR-009**: Cada token tem **rótulo obrigatório** informado por quem cria, e
  registra quem criou (`created_by_user_id`), quando, o tenant e a conta dona.
- **FR-010**: Cada token registra o **último uso** — o instante da última chamada
  **aceita**. Token nunca usado tem último uso ausente, e a interface diz *"nunca
  usado"*, não uma data.
- **FR-011**: O token pode ter **expiração opcional**. Ausência de expiração é
  permitida e **explícita na interface**, nunca padrão silencioso.
- **FR-012**: Revogação é por **marca** (`revoked_at`, `revoked_by_user_id`),
  jamais por remoção de linha — mesma regra de toda a plataforma. Revogação é
  definitiva: não há reativação.

### O contrato de acesso

- **FR-013**: A autenticação é `Authorization: Bearer <token>`. Token em query
  string, em corpo ou em cookie **não é aceito** — query string vaza para log de
  proxy e para histórico de navegador.
- **FR-014**: Toda rota da API vive sob `/api/v1/`. A versão está no caminho, e não
  em cabeçalho: é o que permite servir duas versões ao mesmo tempo quando a
  primeira quebra.
- **FR-015**: A política de versionamento — o que é mudança compatível, o que
  obriga `v2`, e por quanto tempo `v1` continua servida — é **contrato público**, e
  contrato público **exige ADR** nesta casa (ver *Impacto*). Não é decidida aqui.
- **FR-016**: **Token inexistente, revogado e expirado recebem a mesma resposta**:
  `401`, com o mesmo código de erro e o mesmo texto. O motivo real é registrado
  **do lado de dentro**, no log estruturado da aplicação, com o identificador da
  requisição.

  **Justificativa** — a recomendação é sim, resposta única, por três razões:

  | Razão | O que a distinção causaria |
  |---|---|
  | oráculo de existência | *"revogado"* confirma que aquele valor **existiu**. Quem varre valores passa a saber quais acertou, e um token revogado é candidato a ter sido usado em outro lugar |
  | oráculo de ciclo de vida | *"expirado"* informa a política de expiração do tenant sem autenticação nenhuma |
  | superfície de mensagem | três mensagens são três lugares por onde um detalhe interno escapa; uma é um lugar |

  **O que a decisão custa**, e como se paga: quem integra perde a razão da recusa
  e não sabe se deve pedir token novo ou corrigir o cabeçalho. Paga-se com duas
  coisas, e as duas são obrigatórias — sem elas a decisão vira só opacidade:
  **(a)** a tela de tokens mostra o estado real de cada token a quem administra, e
  **(b)** o corpo do erro traz um **identificador de requisição** que quem
  administra correlaciona ao motivo registrado internamente.
- **FR-017**: O escopo do token no primeiro corte é **somente leitura**. Nenhum
  método além de `GET` (e `HEAD`) é servido em `/api/v1`.

  **Por quê**: toda escrita nesta plataforma registra **quem declarou** —
  `declared_by_user_id`, com proveniência declarada. Um token não é uma pessoa, e a
  pergunta *"quem declarou isto"* não tem resposta honesta quando a resposta é "uma
  integração". Atribuir a escrita à conta dona do token seria registrar como
  declaração humana algo que nenhuma pessoa declarou — e a proveniência é a tese do
  produto. É o mesmo argumento da decisão 2 de
  [`servidor-mcp.md`](../../docs/backlog/servidor-mcp.md), e vale igual aqui.
- **FR-018**: Toda coleção é **paginada**, com tamanho de página padrão e **máximo**
  declarados. Pedido acima do máximo é atendido no máximo, e a resposta diz o
  tamanho efetivo — não recusa a chamada.
- **FR-019**: A resposta de coleção traz metadados de paginação suficientes para
  percorrer tudo sem repetição nem omissão. **A presença de total de itens é
  pergunta aberta** (Q5): contar o total é uma consulta a mais em toda chamada, e
  total ausente é melhor que total estimado.
- **FR-020**: O erro tem **um formato único** para todos os códigos, com: código de
  erro estável e legível por máquina, mensagem em prosa para gente, e o
  identificador da requisição. Nenhum erro traz rastro de pilha, nome de módulo,
  SQL, nem o valor do token.

### O que a API expõe no primeiro corte

- **FR-021**: A API expõe **apenas consultas que já existem e já são apresentadas
  em tela**. Nenhum endpoint é criado para dado que a plataforma não tem, nem para
  agregação que nenhuma tela calcula hoje.

  **Entra**:

  | Recurso | Rota | Por que entra | Tela de origem |
  |---|---|---|---|
  | equipes | `GET /api/v1/teams`, `/teams/:id` | o recorte já é resolvido por `Access.pode_ver_equipe/3` | `/teams`, `/teams/:id` |
  | membros da equipe | `GET /api/v1/teams/:id/members` | o vínculo com origem — observado, declarado, saiu, equívoco — é o dado mais pedido | `/teams/:id` |
  | medidas da equipe | `GET /api/v1/teams/:id/measures` | é o que a integração quer levar para painel próprio | `/teams/:id` |
  | pessoas | `GET /api/v1/people`, `/people/:id` | `Access.pode_ver/3` já responde por pessoa | `/people`, `/people/:id` |
  | projetos | `GET /api/v1/projects` | vínculo declarado equipe↔projeto | `/projects` |
  | sincronizações | `GET /api/v1/syncs` | responde *"o dado está atualizado?"*, que toda integração pergunta | `/syncs` |

  **Fica fora**, e a razão de cada um:

  | Fora | Por quê |
  |---|---|
  | qualquer escrita | FR-017 — não há autor honesto |
  | contas, concessões, papéis | administração de acesso pela API amplia a superfície para o recurso que **governa** o acesso |
  | credenciais e ferramentas conectadas | são segredo; API que os lista é API que os vaza |
  | provedor e chaves de AI | idem, e a chave é do tenant |
  | dados brutos coletados | o volume é de ordem diferente, e o valor da plataforma é o dado promovido, não o bruto |
  | mudanças, commits, arquivos, verificações | volume e recorte fino; nenhuma demanda de integração observada — é a US6 |
  | previsão e Monte Carlo | número derivado com piso e limitação forte; entregá-lo por API antes de a tela estabilizar é entregar número que muda de significado |
  | operações de coleta (disparar sync) | é escrita, e é escrita que consome cota de terceiro (ADR 0007) |

- **FR-022**: Toda afirmação que a resposta carrega traz a **proveniência** —
  observado, derivado ou declarado, com a origem. É o princípio IV aplicado a um
  consumidor que não sabe perguntar.
- **FR-023**: Resposta que carrega **medida** traz, no mesmo objeto, as
  **limitações declaradas** em `priv/knowledge_base/` e as **interpretações
  incorretas** registradas — copiadas, não resumidas. Não como campo opcional, e
  não em documentação apartada.
- **FR-024**: **Ausência vem nomeada.** Não observado, não coletado e zero medido
  são **três valores distintos** na serialização. Um consumidor que recebe `0` onde
  a resposta é *"não observado"* vai relatar zero, e ninguém verá a diferença.

### Autorização: o token herda, não inventa

- **FR-025**: O token pertence a **um tenant** e a **uma conta** daquele tenant. O
  tenant vem **do token**, nunca de parâmetro, de cabeçalho, de subdomínio nem do
  corpo da requisição.
- **FR-026**: **O que o token alcança é exatamente o que aquela conta alcança.** A
  autorização é `TheBand.Tenants.Access` — `scopes/2`, `pode_ver/3`,
  `pode_ver_equipe/3` —, sem nenhum ramo condicional novo para a origem API.
- **FR-027**: O alcance é **lido a cada chamada**, nunca gravado no token.
  `Access.scopes/2` já funciona assim por decisão registrada: *"encerrou o fato,
  fechou o escopo — sem job, sem coluna, sem segunda verdade"*. Um token que
  carregasse escopo materializado seria a segunda verdade que a 045 removeu.
- **FR-028**: A **leitura alternativa existe e é decisão, não detalhe** (Q2):

  | Leitura | O que ganha | O que custa |
  |---|---|---|
  | **token pertence a uma conta** (proposta) | zero modelo de autorização novo; alcance encolhe sozinho quando o vínculo encerra; revogar a conta revoga o alcance | o alcance da integração muda quando a pessoa muda de equipe — sem ninguém tocar na integração |
  | token pertence ao tenant, com escopo próprio | alcance estável, independente de pessoa | **é o segundo modelo de acesso**, e diverge do primeiro; e alguém tem de decidir o alcance inicial, que na prática vira "tudo" |

  A recomendação é a primeira, e o custo dela é real: **a integração pode parar de
  ver dado sem que nada nela mude**. Mitigação proposta — a tela de tokens mostra,
  por token, o alcance vigente da conta dona, para que a mudança seja visível antes
  de ser reclamada.
- **FR-029**: Papel administrador da plataforma **não amplia** o alcance do token.
  `Access` já não olha `users.role` para conceder visão (FR-022 da 045):
  *administrar não é ver*. Quem administra e precisa ver por API recebe concessão,
  como na tela.

### O que o token nunca pode fazer

- **FR-030**: **Escrever na estrutura.** Nenhum vínculo, papel, saída, equívoco,
  composição, concessão ou projeto é criado, alterado ou encerrado por token.
- **FR-031**: **Atravessar tenant.** Nenhuma consulta da API é emitida sem tenant.
  Identificador de outro tenant informado no caminho responde `404`, nunca `403` —
  `403` confirmaria que o recurso existe.
- **FR-032**: **Aparecer em log.** Nem em log de acesso, nem de erro, nem de
  exceção, nem em telemetria, nem em rastro de requisição. O que se registra é o
  **identificador do token**, nunca o valor nem o hash.
- **FR-033**: **Aparecer em mensagem de erro**, em corpo de resposta, em página de
  erro ou em cabeçalho de resposta.
- **FR-034**: **Sobreviver à revogação.** A recusa vale a partir da revogação, e a
  latência aceitável entre revogar e recusar é **pergunta aberta** (Q3) —
  qualquer cache de validação a torna diferente de zero, e um número não declarado
  é pior que um número alto.
- **FR-035**: **Escalar além da conta dona.** Não há parâmetro, cabeçalho nem
  endpoint que amplie o alcance de um token depois de emitido.
- **FR-036**: **Ser aceito fora de `/api/v1`.** Token não abre sessão de navegador,
  não é aceito em rota de LiveView e não substitui autenticação de tela.

### Limite de taxa

- **FR-037**: O limite é **por token**, e não por tenant nem por endereço de rede:
  a unidade que se revoga precisa ser a unidade que se contém.
- **FR-038**: A resposta de contenção é `429` no formato de erro padrão, com o
  tempo até reabrir. Toda resposta aceita traz cabeçalhos com limite, restante e
  reabertura.
- **FR-039**: **Não há precedente reutilizável de mecanismo**; há precedente de
  **doutrina**. A [ADR 0007](../../docs/adr/0007-gestor-de-cotas.md) governa a cota
  que o The Band **consome** do GitHub, e a decisão central dela não transporta: a
  origem conta por nós, e *"um gestor não precisa contar requisições: precisa ler o
  que a última resposta disse"*. Aqui **o The Band é a origem** — ninguém conta por
  nós, e contar é o problema todo.

  O que **se reusa** da ADR 0007, e vale reusar:

  | Da ADR 0007 | Aqui |
  |---|---|
  | *"decidir antes, e num só lugar"* — o inventário achou seis portas de saída com quatro políticas | uma porta única de entrada com uma política, desde a primeira rota |
  | a origem informa o saldo em cabeçalho em toda resposta | a API informa o saldo em cabeçalho em toda resposta — a plataforma trata quem a consome como quer ser tratada |
  | teto de concorrência, não só taxa por janela | um cliente com 100 chamadas simultâneas dentro do limite ainda derruba a aplicação |

  Se o mecanismo é processo, tabela, ETS ou dependência é **decisão de
  arquitetura** — ver *Impacto*.

### Swagger / OpenAPI

- **FR-040**: A descrição OpenAPI é **gerada do código**, e a divergência entre
  código e descrição é **detectável no CI**. Descrição mantida à mão diverge no
  primeiro endpoint, e descrição errada é pior que ausente: quem integra a segue.
- **FR-041**: A interface navegável permite informar um token e executar chamadas
  reais. O token informado nela não é persistido pela aplicação.
- **FR-042**: A descrição documenta **o formato de erro** (FR-020) e **as recusas**
  — inclusive que `401` é uniforme (FR-016) e por quê.
- **FR-043**: **A escolha da dependência exige decisão registrada, e esta spec não
  a toma.** Candidata proposta: **`open_api_spex`**. O que ela custa:

  | Custo | O que significa |
  |---|---|
  | dependência nova em runtime | terceira biblioteca de terceiros no caminho da requisição, junto de `bandit` e `phoenix` |
  | anotação no controlador | cada ação declara `operation` com esquemas; sem isso, a rota não aparece na descrição — e "não aparece" é silencioso |
  | esquema declarado em módulo Elixir | o esquema é código, e código de esquema divergir do serializador é possível — FR-040 existe por isso |
  | interface do Swagger UI servida | ativos estáticos de terceiro sob a CSP restritiva já declarada no `router.ex`; `script-src 'self'` **não** serve CDN, e o ativo precisa vir do próprio domínio |
  | acoplamento de versão ao Phoenix | biblioteca que se pluga no roteador acompanha mudança de versão maior do Phoenix |

  **O ganho que sustenta o custo**: a descrição sai do código, o que faz FR-040 ser
  possível. Alternativas — escrever o documento OpenAPI à mão, ou gerá-lo de teste
  de contrato — **não** foram avaliadas aqui, e a avaliação pertence à ADR.

- **FR-044**: **Quem alcança a interface do Swagger é decisão de segurança** (Q7):
  aberta, atrás de sessão, ou só fora de produção. Interface aberta expõe o mapa
  completa da superfície a quem não tem token — e o mapa é útil para quem varre.

### A tela de tokens

- **FR-045**: A tela vive na **área administrativa**, sob o mesmo `require_admin`
  de `/accounts` e `/access-scopes` — credencial é gestão, não operação, e é a
  leitura já registrada de FR-023 da 045.
- **FR-046**: A lista mostra, por token: rótulo, máscara com os quatro últimos
  caracteres, quem criou, quando, último uso ou *"nunca usado"*, expiração ou *"sem
  expiração"*, e o estado — ativo, revogado, expirado.
- **FR-047**: A lista mostra o **alcance vigente da conta dona** de cada token, para
  que a consequência de FR-028 seja visível antes de ser reclamada.
- **FR-048**: A criação apresenta o valor **uma vez**, com aviso explícito, ação de
  copiar, e a instrução de guardá-lo em gerenciador de segredo. O valor **não**
  aparece em nenhuma renderização posterior.
- **FR-049**: A revogação pede confirmação nomeando o rótulo do token — revogar o
  token errado interrompe a integração de terceiro.

### Key Entities

- **Token de API**: pertence a um tenant e a uma conta; tem rótulo, hash, quatro
  últimos caracteres, criador, criação, expiração opcional, último uso, marca de
  revogação com autor. **Não** tem escopo próprio (FR-027) e **não** tem o valor em
  claro (FR-003).
- **Registro de uso**: o instante da última chamada aceita, por token (FR-010). Se
  isso é um campo atualizado ou uma série de eventos é **pergunta aberta** (Q6) — a
  segunda responde *"o que essa integração andou consultando"*, a primeira não.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **0** ocorrências do valor em claro de um token em log, em resposta
  HTTP, em página renderizada e no banco — verificável gerando um token, exercendo
  a API, e varrendo os quatro lugares pelo valor conhecido.
- **SC-002**: Para **100%** das combinações de dois tenants e dos endpoints de
  FR-021, a resposta com o token do tenant A contém **0** identificadores do tenant
  B — verificável por varredura automatizada.
- **SC-003**: Token inexistente, revogado e expirado produzem respostas **byte a
  byte idênticas**, exceto o identificador da requisição — verificável comparando
  as três.
- **SC-004**: **100%** das recusas têm o motivo real recuperável no log interno
  pelo identificador da requisição — verificável recusando as três e localizando as
  três razões distintas.
- **SC-005**: Depois da revogação, **0** chamadas com aquele token são atendidas
  além da latência declarada em Q3 — verificável revogando durante chamadas em
  laço.
- **SC-006**: **0** métodos além de `GET` e `HEAD` respondem em `/api/v1` —
  verificável percorrendo `POST`, `PUT`, `PATCH` e `DELETE` em todas as rotas.
- **SC-007**: **100%** dos objetos de medida na resposta trazem proveniência e as
  limitações declaradas; **0** medidas sem elas — verificável por varredura do
  esquema de resposta.
- **SC-008**: **0** campos numéricos em que *não observado* e *zero medido* sejam
  indistinguíveis — verificável construindo os dois casos e comparando.
- **SC-009**: Percorrer uma coleção de mais de três páginas devolve **cada item
  exatamente uma vez** — verificável comparando o conjunto paginado com a consulta
  direta.
- **SC-010**: **100%** dos endpoints de FR-021 aparecem na descrição OpenAPI, e o
  documento passa por validador de esquema sem erro; um endpoint acrescentado sem
  descrição **falha o CI**.
- **SC-011**: Sob limite excedido por um token, outro token recebe `200` em
  **100%** das tentativas no mesmo intervalo.
- **SC-012**: **0** linhas de token removidas fisicamente em toda operação desta
  feature, incluindo revogação.
- **SC-013**: A tela renderizada de tokens contém, por linha, o estado e o último
  uso em texto, e **0** ocorrências de valor em claro ou de hash.
- **SC-014**: A recusa por escopo devolve **`404`** e não `403` em **100%** dos
  casos de recurso de outro tenant — verificável cruzando identificadores.
- **SC-015**: **0** endpoints em `/api/v1` fora da lista de FR-021 — verificável
  comparando a tabela de rotas com a lista.

---

## Fora de escopo

| Fora | Por quê |
|---|---|
| **qualquer escrita pela API** | FR-017 — não há autor honesto para a proveniência |
| **servidor MCP** | é outro item de backlog ([`servidor-mcp.md`](../../docs/backlog/servidor-mcp.md)), e esta feature o **desbloqueia** sem realizá-lo. Um servidor MCP é um consumidor desta API, não um segundo caminho |
| **OAuth, autenticação de terceiro, aplicação instalável** | é a opção 2 daquele documento; token é a opção 1, e é a que a pessoa mantenedora pediu |
| **webhook de saída / notificação** | é a plataforma chamando o cliente; problema inverso, com entrega, repetição e assinatura próprios |
| **cota comercial, plano, cobrança por chamada** | não há decisão de produto sobre isso |
| **API de administração** — criar conta, conceder escopo, conectar ferramenta | administrar acesso pela API amplia a superfície no recurso que governa o acesso |
| **token gerado pela própria pessoa não administradora** | o pedido diz *"gerado na área administrativa"*. Autoatendimento é decisão posterior |
| **SDK ou cliente em qualquer linguagem** | a descrição OpenAPI permite gerá-lo; manter um é compromisso permanente |
| **`v2` e depreciação de `v1`** | FR-015 — política de versionamento é ADR |
| **exportação em CSV ou planilha** | formato de arquivo é outra feature; a API entrega JSON |

---

## Premissas

1. **A pipeline `:api` do `router.ex` está declarada e sem uso.** Esta feature é a
   primeira a passar rota por ela. Verificado no `router.ex` em 2026-09-08.
2. **`TheBand.Tenants.Access` é o veredito único e serve a este caso sem
   alteração.** `scopes/2`, `pode_ver/3` e `pode_ver_equipe/3` respondem por pessoa
   e por equipe. **Se algum endpoint de FR-021 precisar de uma pergunta que `Access`
   não responde hoje** — projeto e sincronização, provavelmente —, isso é lacuna a
   levantar no `/speckit-plan`, não a improvisar no controlador.
   [NEEDS CLARIFICATION: `Access` responde por projeto e por sync, ou o recorte
   desses dois vem de outro lugar?]
3. **Não há nada de OpenAPI no `mix.exs`.** Conferido em 2026-09-08: a lista de
   dependências não traz `open_api_spex`, `phoenix_swagger` nem equivalente. É
   dependência nova, não configuração de existente.
4. **A CSP do `router.ex` é restritiva por decisão registrada** (`script-src
   'self'`), e o ativo do Swagger UI precisa ser servido do próprio domínio.
   Afrouxar a CSP para acomodar CDN é decisão que **contraria** um achado do
   Sobelow já tratado (issue #288) — e não se toma aqui.
5. **A pessoa mantenedora quer o primeiro corte pequeno.** A leitura vem do
   `spec.md` da 060 e do padrão dos itens de backlog: fatia vertical, consumidor
   visível, escopo cortado antes de a cadência ceder.
6. **O padrão de segredo da casa é `ToolCredential`**, e esta spec o segue em
   `last_four`, `masked/1`, `redact` e `@derive {Inspect, except: [...]}`,
   divergindo **só** na guarda (FR-004), com a razão escrita.
7. **Um cliente típico chama de minuto em minuto, não de segundo em segundo.** É
   premissa que dimensiona o limite de taxa, e **não foi medida** — nenhuma
   integração existe. Se estiver errada, o limite escolhido está errado.

---

## Perguntas abertas

Nenhuma tem resposta nesta spec. As três primeiras **bloqueiam** o
`/speckit-plan`; as demais podem ser respondidas durante ele.

| # | Pergunta | Leituras | Recomendação |
|---|---|---|---|
| **Q1** | Que função de hash guarda o token? | hash criptográfico rápido de uso único, ou derivação de chave lenta como a da senha | **rápido**, porque o segredo tem 32 bytes de entropia de máquina e o custo lento é proteção contra dicionário, que aqui não se aplica — **mas a decisão é do papel Security, e o custo por requisição é de arquitetura** |
| **Q2** | O token pertence à conta ou ao tenant? | FR-028, as duas leituras com custo | **à conta**, aceitando que o alcance da integração mude quando a pessoa mudar de equipe, e tornando isso visível na tela (FR-047) |
| **Q3** | Qual latência entre revogar e recusar é aceitável? | zero (consulta ao banco em toda chamada), ou um teto declarado com cache | **declarar o número**, qualquer que seja. Cache não declarado é revogação que não se sabe quando vale |
| **Q4** | Trocar a senha da conta dona derruba os tokens dela? | sim (coerente com a sessão, FR-015 da 045), ou não (token é credencial própria) | **não** — derrubar integrações porque alguém trocou a senha é interrupção silenciosa de terceiro. Mas a leitura oposta é defensável se a troca de senha significar suspeita de comprometimento |
| **Q5** | A resposta de coleção traz total de itens? | sim (consulta a mais por chamada), ou só *tem próxima página* | **só *tem próxima***, e declarar a ausência. Total estimado é pior que total ausente |
| **Q6** | Uso do token é campo atualizado ou série de eventos? | campo (barato, responde *"ainda está em uso?"*), ou série (responde *"o que andou consultando"*, e cresce sem teto) | **campo** no primeiro corte, com a lacuna declarada: não haverá auditoria de o que foi consultado |
| **Q7** | Quem alcança a interface do Swagger? | aberta, atrás de sessão, ou só fora de produção | **atrás de sessão** — quem integra tem conta; o mapa completo da superfície não precisa ser público |
| **Q8** | A expiração tem padrão? | sem expiração por padrão, ou padrão de N dias | **sem expiração, dita explicitamente** — padrão silencioso de expiração derruba integração meses depois, sem ninguém ligar as duas coisas |

---

## O protótipo vem antes do código

`.claude/agents/product-owner.md` é explícito: **toda spec com tela começa pelo
protótipo**, e *"spec com tela e sem protótipo aprovado é spec incompleta: você não
a leva adiante nem a decompõe em tarefas"*.

Esta feature tem tela: a de tokens da área administrativa (US1, US3, FR-045 a
FR-049).

Consequências, e nenhuma é negociável:

1. **A US1 e a US3 não são decompostas em tarefas** antes de o papel de **Design**
   desenhar a tela e o protótipo ser aprovado pela pessoa mantenedora.
2. O item de backlog e esta spec passam a citar o **endereço do protótipo**, o
   **`PROMPT.md`** que o gerou e o **`README.md`** das decisões — como a 060 faz.
   Enquanto não existirem, o registro está incompleto, e está dito aqui.
3. A aceitação da tela usa a seção *estrutura aprovada* do `PROMPT.md` como régua,
   item a item, com a captura da tela real ao lado.
4. **A US2, a US4 e a US5 não têm tela** e não dependem do protótipo. É por elas que
   o trabalho pode começar, se a priorização decidir começar.

Duas perguntas de desenho que o Design vai encontrar, e que pertencem a ele
levantar: **como se mostra um segredo uma única vez** sem que a pessoa o perca por
distração; e **como se mostra o alcance vigente da conta dona** (FR-047) sem
transformar a linha do token numa segunda tela de concessões.

---

## Segurança — o que o papel Security precisa avaliar

**A superfície é nova e é a maior já aberta nesta plataforma.** Até aqui, todo
acesso a dado passava por sessão de navegador com senha e por `Access`. Esta
feature abre uma porta que atende **sem navegador, sem senha e sem gente**.

O que segue é a **lista do que precisa ser avaliado** pelo papel Security, e
nenhuma avaliação é feita aqui. Cenário de ataque não é escrito nesta spec.

| # | O que avaliar | Por que aqui |
|---|---|---|
| S1 | **A função de hash e o custo por requisição** (Q1, FR-005) | é a decisão que separa "segredo guardado" de "segredo guardado errado", e a única com custo em toda chamada |
| S2 | **Entropia e formato do token** (FR-001, FR-002) | 32 bytes é proposta, não veredito; e o prefixo precisa ser reconhecível por varredura de segredo sem colidir com outros |
| S3 | **Comparação em tempo constante** (FR-005) | comparação ingênua de hash é canal lateral mensurável |
| S4 | **A recusa uniforme, e o que ela ainda revela** (FR-016) | a resposta é igual; **o tempo de resposta pode não ser**, e tempo distingue |
| S5 | **Enumeração de recursos por `404` vs `403`** (FR-031, SC-014) | a regra está escrita; falta conferir que **nenhum** caminho vaza a distinção, inclusive por tempo e por tamanho de resposta |
| S6 | **Onde o token pode escapar**: log de acesso, log de exceção, telemetria, rastro, mensagem de erro, cabeçalho de resposta, página de erro (FR-032, FR-033) | o inventário tem de ser feito uma vez, e a proteção do `Inspect` cobre um dos lugares, não todos |
| S7 | **Limite de taxa como proteção, não só como cortesia** (FR-037 a FR-039) | sem teto de concorrência, o limite por janela não protege a aplicação |
| S8 | **Exposição da interface do Swagger** (Q7, FR-044) | o documento OpenAPI é o mapa completo da superfície |
| S9 | **A CSP e o ativo do Swagger UI** (premissa 4) | afrouxar a CSP reabriria um achado do Sobelow já tratado (#288) |
| S10 | **Latência de revogação** (Q3, FR-034) | é o intervalo em que um segredo comprometido continua servindo |
| S11 | **O token não abre sessão** (FR-036) | conferir que nenhuma rota de LiveView aceita `Bearer`, e que o token não vira cookie |
| S12 | **Herança de alcance sem ramo novo** (FR-026) | qualquer `if origem == :api` no caminho de autorização é o começo do segundo modelo de acesso |
| S13 | **Segredo em trânsito** | a API só é servida sobre TLS; `Strict-Transport-Security` e o comportamento em `http://` precisam ser conferidos |
| S14 | **`open_api_spex` como dependência em runtime** (FR-043) | biblioteca nova no caminho da requisição entra no escopo do `mix_audit` e do `sobelow` |

---

## Impacto

### Telas

| Tela | O que muda |
|---|---|
| **nova** — tokens de API na área administrativa | US1, US3; sob `require_admin`, junto de `/accounts` e `/access-scopes`. **Passa pelo Design antes do código** |
| **nova** — interface do Swagger | US4; o alcance dela é Q7 |

### Rotas

| Rota | Situação |
|---|---|
| `/api/v1/...` (FR-021) | **novas**, primeiras a passar pela pipeline `:api` já declarada |
| pipeline `:api` | precisa de autenticação por token e do formato de erro; hoje só tem `:accepts` |
| tela de tokens | nova rota no escopo `require_admin` |
| interface do Swagger | nova; o escopo depende de Q7 |

### Módulos

| Módulo | O que é |
|---|---|
| esquema e contexto do token de API | **novo**; onde ele vive — em `Tenants` junto de `Access` e `Auth`, ou em contexto próprio — é decisão de arquitetura |
| plug de autenticação por token | **novo**; irmão de `Plugs.CurrentScope`, e não uma variação dele: um lê sessão, o outro lê cabeçalho |
| plug de limite de taxa | **novo**, e o mecanismo é decisão de arquitetura (FR-039) |
| serialização com proveniência e limitações (FR-022 a FR-024) | **novo**, e é a parte mais fácil de fazer errado: um serializador que omite a proveniência passa em todo teste funcional |
| `TheBand.Tenants.Access` | **não muda** — FR-026. Se precisar mudar, é sinal de que o segundo modelo de acesso começou |
| `TheBand.Sources.ToolCredential` | **não muda**; serve de padrão, não de base |

### Migração

- tabela de tokens de API: tenant, conta, rótulo, hash, quatro últimos caracteres,
  criador, expiração, último uso, marca de revogação com autor;
- índice que sustente a busca por hash em toda requisição;
- **nenhuma** alteração destrutiva em tabela existente.

### Base de conhecimento

FR-023 exige que a resposta carregue as limitações declaradas da medida. **Não há
medida nova nesta feature** — o que há é a exigência de que as declarações
existentes em `priv/knowledge_base/` cheguem à resposta. Se alguma medida exposta
por FR-021 **não tiver** limitações declaradas na base, isso é lacuna a fechar antes
de a medida ser servida, pelo papel de Ontologia.

### O que exige ADR

Conferido em [`docs/adr/README.md`](../../docs/adr/README.md), seção *Quando
escrever uma ADR*, em 2026-09-08. **A lista não nomeia "dependência nova"** como
gatilho genérico — e é honesto dizer isso, porque foi o que o pedido pediu para
verificar. O gatilho que se aplica é outro, e é mais forte:

> *"alterar contratos públicos"*

**Uma API pública é um contrato público**, e criá-la é o caso mais forte desse
gatilho, não o mais fraco: até hoje não havia contrato público nenhum. Logo:

| Decisão | Exige ADR | Gatilho |
|---|---|---|
| **abrir uma API pública, e a política de versionamento** (FR-014, FR-015) | **sim** | *alterar contratos públicos* — é a criação do primeiro |
| **a recusa uniforme** (FR-016) | **sim**, dentro da ADR da API | é comportamento do contrato, e a justificativa precisa sobreviver a quem vier depois e achar que é bug |
| **somente leitura no primeiro corte** (FR-017) | **sim**, dentro da mesma ADR | delimita o contrato, e a razão é a proveniência do autor |
| **o token herda o alcance da conta** (FR-026, Q2) | **sim** — ou na ADR da API, ou em ADR própria | toca o modelo de acesso, e a alternativa **é** um segundo modelo |
| **`open_api_spex` como dependência** (FR-043) | **a avaliar pelo Software Architect** | não é gatilho da lista por si; entra na ADR da API como decisão de implementação do contrato, ou fica fora dela. **Esta spec não decide, e recomenda que a ADR da API a absorva** — a descrição gerada é o que torna FR-040 possível, e isso é propriedade do contrato |
| **o mecanismo do limite de taxa** (FR-039) | **a avaliar pelo Software Architect** | se for processo governando estado compartilhado, é vizinho da ADR 0007 e provavelmente merece registro |
| **a função de hash** (Q1, FR-005) | decisão de **Security**, registrada onde Security registrar | não é gatilho de ADR pela lista |

**Nenhuma dessas decisões é tomada aqui.** Product Owner não abre ADR — a linha
está em `.claude/agents/product-owner.md`, e o dono é o Software Architect.

### Documentos de outros papéis que esta feature afeta

| Documento | O que muda |
|---|---|
| [`docs/backlog/servidor-mcp.md`](../../docs/backlog/servidor-mcp.md) | a **decisão 1** (autenticação e tenant) passa a ter resposta; o item deixa de estar bloqueado por ela quando esta feature entrar |
| [`docs/backlog/README.md`](../../docs/backlog/README.md) | linha nova para esta feature, e o estado do MCP a revisar |
| [`docs/adr/README.md`](../../docs/adr/README.md) | ADR nova a listar, quando escrita |
| `priv/knowledge_base/` | nada de novo; a exigência é que o já declarado chegue à resposta (FR-023) |
