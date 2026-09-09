# Spec 062 — o servidor MCP: as perguntas da plataforma, respondidas a um agente

> **Estado: em especificação.** Não há código. Esta spec fica **atrás da 061** por
> dependência real, e não por prioridade: o servidor MCP é **consumidor** da API pública, e
> não um segundo caminho para os dados.

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
  API recusa, e o servidor MCP recusa — pela mesma razão e com a mesma mensagem. Três portas
  para o mesmo dado com três respostas diferentes é o mesmo furo contado três vezes.
- **FR-005**: A revogação do token vale na chamada seguinte, sem cache — herdado da Q3 da 061.

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
| **Q4** | Limite de taxa próprio ou o da 061? | o da 061. Dois limites para o mesmo token dariam duas respostas para "por que recusou" |

---

## Dependências

| Depende de | Estado |
|---|---|
| **spec 061** — token, veredito reusado, pipeline `:api`, recusa 401 única | especificada, **sem código** |
| `api.access.thresholds` na base de conhecimento | proposta na 061, valores a decidir com o PO |
| as **77 perguntas de competência** já declaradas | existem |
| `users.disabled_at` | **não existe** — a limitação de acesso órfão da 061 vale igual aqui, e por MCP é pior: o que saiu já está do outro lado |

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
   pode ir para o log.
