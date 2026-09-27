# Spec 062 — o servidor MCP: as perguntas da plataforma, respondidas a um agente

> **Estado: planejada, com 26 tarefas abertas e uma feita (T009, a revisão independente).** Não há código. Esta spec ficava
> **atrás da 061** por dependência real, e não por prioridade: o servidor MCP é **consumidor**
> da API pública, e não um segundo caminho para os dados.
>
> **Reconciliada contra o código em 2026-09-24.** Entre o plano (2026-09-22) e hoje, a 061
> ganhou o registro de leitura e o limite por token (#936, #938), o token sem prazo e o motivo
> da revogação (#939). Isso mudou a FR-004 e acrescentou a FR-024 e a FR-025. Ver
> [Dependências](#dependências).

**Origem**: [`docs/backlog/servidor-mcp.md`](../../docs/backlog/servidor-mcp.md), que estava
marcado **bloqueado** no [README do backlog](../../docs/backlog/README.md) com a razão exata:
*"depende de decidir autenticação e tenant"*. Era a decisão 1 daquele documento, e a
[spec 061](../061-api-publica/spec.md) a tomou em 2026-09-09.

---

## O que esta feature resolve

Hoje as respostas da plataforma existem e só um olho humano as alcança. A 061 abre a porta
para um **programa**. Esta feature abre para um **modelo** — e as duas portas não são a mesma,
por uma razão que não é técnica:

**um modelo não sabe perguntar pela ressalva.**

Uma pessoa que vê `median wait: 0.16 h` na tela vê, ao lado, *"medido sobre 19 membros — 17
observados sem papel declarado, 2 declarados"*, e a frase muda o que ela conclui. Um agente
que recebe `0.16` num campo JSON relata `0.16`. A ressalva não some por má-fé: some porque
ninguém a pediu.

Por isso a regra desta feature é mais forte que a da 061:

> **Toda resposta de toda ferramenta carrega a proveniência e as limitações declaradas da
> medida, no mesmo objeto** — não como campo opcional, não como texto anexo, e não atrás de
> uma segunda chamada.

É o princípio IV aplicado a um consumidor que não sabe perguntar.

### O que esta feature NÃO é

**Não é uma ferramenta por tabela.** `list_teams`, `get_issue`, `count_people` seriam a
tradução do esquema para o protocolo, e entregariam ao agente o trabalho de reconstruir as
perguntas — que é exactamente o trabalho que a plataforma existe para ter feito.

**Não é um segundo caminho para os dados.** O servidor chama a **API da 061**, com um token da
061, e o veredito é o mesmo `Tenants.Access`. Um servidor que consultasse o `Repo` direto
criaria a segunda verdade sobre acesso que a 061 recusou.

**Não é escrita.** Ver *Fora de escopo*.

---

## Requirements *(mandatory)*

### A porta: o que a 061 já resolveu, e o que esta spec herda

- **FR-001**: O servidor autentica na plataforma com um **token da 061**. Não existe emissão
  de credencial própria desta feature, e não existe segundo modelo de acesso.
- **FR-002**: O tenant vem **do token**, nunca de argumento de ferramenta. Uma ferramenta que
  aceitasse `tenant_id` como parâmetro seria o achado A01-2 da avaliação de segurança da 061,
  com outro nome.
- **FR-003**: O alcance é **recomputado a cada chamada** pelo veredito único
  (`Access.scopes/2`, `pode_ver/3`, `pode_ver_equipe/3`). O servidor MUST NOT guardar escopo,
  papel ou lista de organizações — nem em memória entre chamadas.
- **FR-004**: A **paridade é tripla e provada por teste**: o que a tela recusa por veredito, a
  API recusa, e o servidor MCP recusa, pelo **mesmo veredito e pela mesma razão**. Três portas
  para o mesmo dado com três vereditos diferentes é o mesmo furo contado três vezes.
  **A forma da recusa é de cada porta, e não precisa coincidir**: a API responde `404`, porque
  ali `403` confirmaria que o recurso existe; o MCP responde `state: "refused"`, porque um
  agente que recebe erro de transporte não distingue *não pode ver* de *o servidor caiu*
  (FR-013). *Emendada em 2026-09-24: a versão anterior pedia "a mesma mensagem", e isso
  contradizia a FR-013.*
- **FR-005**: A revogação do token vale na chamada seguinte, sem cache — herdado da Q3 da 061.
- **FR-006**: O servidor **não guarda o token** — nem em disco, nem em memória entre chamadas,
  nem em variável de ambiente própria. Ele recebe o token na chamada, verifica, responde e
  esquece. É a mesma decisão da 061 (FR-079 a FR-082), e aqui ela tem um alcance a mais: um
  servidor que guardasse tokens de vários clientes seria um cofre de credenciais de terceiros
  que ninguém pediu.
- **FR-007**: **Onde o token fica é responsabilidade do cliente**, e a plataforma MUST dizer
  isso na documentação em vez de presumir. O cliente MCP guarda o token na configuração dele —
  um arquivo no disco de quem usa, fora do alcance de qualquer trava desta plataforma. As duas
  consequências que a documentação MUST declarar:
  1. **revogação é o único controle que a plataforma tem** sobre um token que já saiu. Não há
     como apagá-lo do outro lado;
  2. **o token no arquivo de configuração do cliente é um segredo em disco**, e a orientação é
     a mesma de qualquer credencial: fora do repositório, fora do histórico de terminal, e
     revogado quando a máquina sai de uso.
- **FR-008**: Nenhuma resposta de ferramenta MUST conter o token, parte dele além do prefixo
  público, ou qualquer valor derivado dele. O consumidor é um modelo que pode repetir o que
  recebe — e o que ele repete pode ser registrado, cacheado e indexado do outro lado.

### O registro e o limite: herdados da 061, e o que o MCP acrescenta

*Acrescentado em 2026-09-24.* O plano e a avaliação de segurança citavam a FR-024 sem que ela
estivesse nesta spec.

- **FR-024**: Herdada da **spec 045**: aceita-se o risco de **agregação**, em que alguém que
  alcança muitos itens reconstrói por acumulação o que o veredito recusa direto, e o
  **registro de acesso** é o caminho para percebê-lo. Por MCP, isso exige que toda leitura
  **concedida** deixe linha no registro da 061 (`api_access_reads`), com o **nome da
  ferramenta** e o **alvo** (`team_id`), e sem o corpo da resposta. Uma linha que diz só
  `/mcp` não permite responder *"esta credencial leu o painel de qual equipe?"*, e então a
  FR-024 fica apoiada em nada.
- **FR-025**: **Recusa não é leitura.** A recusa sai como resposta de ferramenta, em HTTP
  `200` (FR-013), e MUST NOT ser gravada no registro de leitura. Gravá-la faria o registro
  afirmar que a credencial leu o que lhe foi negado. A recusa vai para o registro de recusa,
  com a razão.
- **FR-026**: **O limite é o da 061, um só por token.** `/mcp` e `/api/v1` gastam o mesmo limite
  (`api.access.thresholds`, regra `rate_limit`). Um limite por porta daria ao mesmo token o
  dobro da vazão, e duas respostas para *"por que recusou"*.

### A forma da resposta: a proveniência não é opcional

- **FR-010**: Toda resposta de ferramenta que devolve **medida** carrega, no mesmo objeto:
  o valor; a **composição** sobre a qual foi calculado; a **janela**; a marca de origem
  (`observado`, `derivado` ou `declarado`); e o **identificador e versão da regra** quando o
  valor é derivado.
- **FR-011**: Toda resposta que devolve medida carrega as **interpretações incorretas**
  declaradas na base de conhecimento para aquela medida (`misinterpretations`). Não é campo
  opcional, e não é texto de rodapé: é parte do objeto.
- **FR-012**: **Ausência vem nomeada, nunca como zero.** Os três estados da casa são
  distintos no protocolo: *conferido e nada encontrado*, *não conferido* (com o que falta), e
  *recusado* (com a razão). Um agente que recebe `0` onde a resposta é "não observado" relata
  zero, e ninguém vê a diferença.
- **FR-013**: **Recusa é resposta, não erro.** Quando o veredito nega, a ferramenta devolve a
  recusa **com a razão declarada**, e não uma exceção nem uma lista vazia. Lista vazia por
  falta de permissão é o "sucesso silencioso" que esta casa já registrou oito vezes.
- **FR-014**: Toda resposta carrega **quando o dado foi coletado**. Um agente que responde
  hoje sobre uma coleta de anteontem precisa poder dizer isso.

### As ferramentas: uma por pergunta que a plataforma se compromete a responder

- **FR-020**: A lista de ferramentas deriva das **perguntas de competência** declaradas na
  base de conhecimento — **77** hoje, concentradas em **seis** das catorze ontologias — SRO (37), CIRO (14), CDRO (13), EO (5), CMO (4) e SMPO (4); as outras oito não declaram nenhuma, e isso limita o que se pode oferecer. Não se
  inventa ferramenta que a base não declare como pergunta respondível.

  **Emendada em 2026-09-24, por decisão da pessoa mantenedora:** o lastro pode ser uma
  **pergunta de competência** ou uma **necessidade de informação** declarada na base. As duas
  são perguntas que a plataforma se compromete a responder: a primeira vem das ontologias, e a
  segunda é a do GQM, à qual as medidas respondem (`answers_information_need`). A emenda veio
  do T006: `team_open_work` e `team_review_wait` não têm pergunta de competência, e têm
  necessidade de informação (`flow.work_in_progress` e `review.time_to_first_review`). As
  alternativas descartadas foram cortar as duas ferramentas, e com elas o exemplo que justifica
  a feature, ou declarar perguntas novas na ontologia, contra o princípio IX.
- **FR-021**: O primeiro corte MUST ser **pequeno e vertical**: as perguntas que as telas já
  respondem, e cujo caminho de dados está provado. Uma ferramenta que responde de verdade vale
  mais que doze que devolvem `{}`.
- **FR-022**: Cada ferramenta declara, na própria descrição, **o que ela não responde** — a
  mesma disciplina do `what_this_is_not` que o schema da base de conhecimento exige.
- **FR-023**: Nenhuma ferramenta aceita **consulta arbitrária** (SQL, filtro livre, campo de
  ordenação vindo do argumento). Lista fechada, casada uma a uma — a FR-077 da 061.

### O que nunca sai

- **FR-030**: Credencial, segredo e qualquer campo que a interface já esconde MUST NOT sair
  por MCP, em nenhuma forma — nem mascarado, nem em campo de depuração.
- **FR-031**: `platform_access_level` (o `MAINTAINER` do GitHub) MUST NOT sair. A tela deixou
  de exibi-lo por decisão registrada — era nível de acesso de administração lido como papel —,
  e sair por MCP seria a afirmação falsa voltando por outra porta.
- **FR-032**: O consumidor remoto torna o vazamento **pior**, e isto é requisito e não nota: o
  que sai por MCP pode ser cacheado e indexado do outro lado, fora do alcance de qualquer
  revogação. A regra é a da tela, aplicada com margem maior.

---

## Success Criteria *(mandatory)*

- **SC-001**: 100% das respostas de medida carregam proveniência, composição e janela —
  medido por teste que percorre todas as ferramentas registradas, e não por amostra.
- **SC-002**: 0 respostas com `0` onde o estado é *não conferido* ou *recusado*.
- **SC-003**: 100% das recusas trazem a razão declarada; 0 recusas apresentadas como lista
  vazia.
- **SC-004**: paridade tela ↔ API ↔ MCP provada para **todos** os vereditos de
  `pode_ver_equipe/3` (os quatro caminhos) e `pode_ver/3`.
- **SC-005**: 0 ocorrências de segredo, credencial ou `platform_access_level` em qualquer
  resposta — verificado por teste que varre o objeto inteiro, não os campos esperados.
- **SC-006**: token revogado é recusado na chamada seguinte.

---

## Fora de escopo

| Fora | Por quê |
|---|---|
| **escrita por MCP** | a plataforma grava `declared_by_user_id`, e **um agente não é uma pessoa**. Não há autor honesto para a proveniência — a mesma razão que mantém a 061 só-leitura, e aqui ela é mais forte: o agente age sem que ninguém confirme o ato |
| **OAuth e instalação como aplicação** | é a opção 2 da decisão 1 do backlog. A 061 escolheu token; mudar isso é decisão nova, com ADR |
| **servidor local por instalação** | resolveria o multitenant fazendo desaparecer o acesso remoto, que é o ponto |
| **ferramenta que responda pergunta que a base não declara** | seria a plataforma afirmando o que não se comprometeu a afirmar |
| **cache de resposta** | pela razão da Q3 da 061: cache que atrasa revogação é decisão de segurança disfarçada de desempenho. E aqui há um segundo motivo — o outro lado já cacheia |

---

## Perguntas abertas

| # | Pergunta | Recomendação |
|---|---|---|
| **Q1** | O servidor roda **dentro** do monólito (uma rota a mais) ou como processo separado que chama a API por HTTP? | **dentro**, na primeira versão: chamar a própria API por HTTP de dentro do mesmo nó paga rede para não ganhar isolamento nenhum. Mas MUST usar a mesma fronteira de contexto que a API usa — nunca o `Repo` — para que a extração posterior seja mecânica |
| **Q2** | Quantas ferramentas no primeiro corte, e quais? | as perguntas que a **tela da equipe** já responde: quem está na equipe, o que cada um tem aberto, quanto o trabalho espera por revisão, o que está parado. Quatro, com caminho de dados provado |
| **Q3** | A resposta é JSON estruturado ou texto para o modelo ler? | **estruturado**, com a proveniência em campo próprio. Texto convida o modelo a resumir, e o resumo é onde a ressalva morre — e esta casa já mediu que regra pedida ao modelo é ignorada, enquanto regra virada em schema é obedecida |
| **Q4** | Limite de taxa próprio ou o da 061? | **Respondida em 2026-09-24**: o da 061, que agora existe (#936, #938). É a FR-026. Em 2026-09-22 a resposta era verdadeira no papel e falsa no código: não havia limite nenhum |

---

## Dependências

> **Conferida contra o código em 2026-09-24**, e antes em 2026-09-21. Das duas vezes havia
> linha desatualizada. Uma tabela de dependências que ninguém reconfere vira premissa de
> desenho, e premissa de desenho é o que faz alguém planejar em torno de um bloqueio que já
> caiu. Na segunda vez a premissa era o contrário: o plano mandava **criar** o que a 061 já
> tinha acabado de criar.

| Depende de | Estado |
|---|---|
| **spec 061** — token, veredito reusado, pipeline `:api`, recusa 401 única | **entregue**: token no [#930](https://github.com/The-Band-Solution/theband/pull/930), rotas e Swagger no [#933](https://github.com/The-Band-Solution/theband/pull/933), detalhe de equipe no [#934](https://github.com/The-Band-Solution/theband/pull/934). 24 de 24 tarefas |
| `api.access.thresholds` na base de conhecimento | **aplicada**: `rate_limit` com 120 por minuto e janela de 60 s, `applied: true`. Os valores continuam como **proposta** (`status: proposed`), e mudam ali, e não no código |
| **registro de leitura** (`ApiReadLog`, `api_access_reads`) | **existe** desde o #936, com retenção indefinida e o painel do #939. **Não enxerga o MCP como está**: grava o molde da rota e `params["id"]`, e no MCP os dois saem vazios. Ver FR-024 e a T021 |
| **limite por token** (`ApiRateLimit`) | **existe** desde o #936, com janela deslizante desde o #938. Vale para `/mcp` se `/mcp` passar pela mesma pipeline. Ver FR-026 |
| **token sem prazo** e **motivo da revogação** | **existem** desde o #939. O primeiro pesa na FR-007: um token sem prazo guardado na configuração do cliente vale até ser revogado |
| as **77 perguntas de competência** já declaradas | existem |
| `users.disabled_at` | **existe** desde a migração `20260910050000`, e `api_auth.ex` já recusa token de conta desativada por `User.ativa?/1`. A limitação de acesso órfão que esta linha declarava **não vale mais** |

### O que a 061 entregou, e que esta feature consome

Medido contra o código em 2026-09-21, e não contra o que a spec afirma:

| Caminho | O que responde |
|---|---|
| `GET /api/v1/teams` · `/teams/:id` | a equipe, a composição, e os três números do roster que nunca se somam |
| `GET /api/v1/teams/:id/members` | quem pertence, com `origin` por **vínculo** |
| `GET /api/v1/teams/:id/measures` | trabalho aberto/parado/fechado, as **duas** medianas de espera, cobertura de competências |
| `GET /api/v1/people` · `/people/:id` | a pessoa inteira, com veredito de `pode_ver/3` e recusa registrada |

**As quatro perguntas do primeiro corte (Q2) já têm caminho de dados provado** — é o que a
FR-021 exige antes de oferecer ferramenta.

### Duas coisas que a 061 aprendeu e esta feature herda

1. **O corpo tem de dizer o que a medida NÃO é.** Ao implementar `/teams/:id/measures`
   medimos, na equipe `LEDS - ConectaFapes`: **23** esperas revisadas com mediana de
   **0,2 h**, e **79** ainda aguardando com mediana de **46 dias**. Um campo único de
   segundos, com uma mediana só, teria respondido *"12 minutos"*. A FR-010 desta spec pede
   exatamente isso, e agora há um número que mostra o tamanho do erro que ela evita;
2. **`null` e `[]` são afirmações diferentes**, e a API já as separa: `competencies: null`
   quer dizer *não houve leitura*; `[]` quer dizer *houve, e nada foi demonstrado*. É a
   FR-012 desta spec, já provada num consumidor.

---

## Segurança — o que o papel Security precisa avaliar

A avaliação da 061 cobre o token e a porta HTTP. **Esta feature acrescenta uma superfície que
aquela não tem**, e ela precisa de avaliação própria:

1. **o consumidor é um modelo**, e o que sai pode ser repetido, cacheado e indexado fora do
   alcance de qualquer revogação. Qual é a consequência disso para o que se decide expor;
2. **injeção de instrução pelo conteúdo**: título de issue, nome de equipe e comentário são
   texto escrito por gente de fora, e chegam ao modelo pela resposta da ferramenta. O que a
   plataforma faz para que conteúdo não seja lido como instrução;
3. **agregação**: quatro ferramentas que cada uma respeita o veredito podem, combinadas,
   responder uma pergunta que nenhuma delas responderia sozinha. É risco de desenho, não de
   implementação;
4. **o registro**: o que se conta de uso por MCP para que abuso seja detectável, e o que não
   pode ir para o log. *Em 2026-09-24 o registro existe, e a pergunta mudou*: ele distingue as
   ferramentas e os alvos, e deixa de fora as recusas? Ver FR-024 e FR-025.
