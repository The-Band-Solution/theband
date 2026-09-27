# Spec 069 — MCP com as mesmas funções da API, e a busca de pessoa

**Feature branch**: `069-mcp-busca-de-pessoas`
**Criada**: 2026-09-25 · **Reescrita**: 2026-09-27
**Estado**: rascunho
**Estende**: [062 — servidor MCP](../062-servidor-mcp/spec.md) · **Espelha**: [061 — API pública](../061-api-publica/spec.md)

**Pedidos e decisões da pessoa mantenedora**:

| Data | Pedido ou decisão |
|---|---|
| 2026-09-25 | *"implemente busca de pessoas e suas tarefas no mcp"* |
| 2026-09-25 | a busca casa **trecho**, sem diferenciar maiúscula nem acento; devolve **só o alcance do token** |
| 2026-09-27 | *"no mcp, quero as mesmas funções da api"* |
| 2026-09-27 | *"coloque uma opção de buscar por id do github"* |

A primeira versão desta spec (2026-09-25) tinha duas ferramentas, `people_search` e
`person_open_work`. O pedido de 2026-09-27 a amplia para as oito rotas da API. O trabalho da
pessoa passa a vir de `person_get`, como vem de `GET /api/v1/people/:id`, e `person_open_work`
deixa de existir.

## O que esta feature resolve

Um agente pelo MCP responde hoje só sobre **uma equipe cujo id ele já tem**. A API responde as
oito perguntas da 061. Medido em 2026-09-25 com o SDK oficial de Python: achar as tarefas de uma
pessoa custou 20 chamadas, e os 10 ids de equipe tiveram de sair do banco, **por fora do MCP**.

| Rota da API (061) | No MCP hoje | Nesta feature |
|---|---|---|
| `GET /teams` | — | `teams_list` |
| `GET /teams/:id` | — | `team_get` |
| `GET /teams/:id/members` | `team_roster` | fica como está |
| `GET /teams/:id/measures` | `team_open_work`, `team_review_wait` e `team_stale_work` | `team_measures`, a resposta inteira; as três ficam |
| `GET /people` | — | `people_list` |
| `GET /people/:id` | — | `person_get` |
| `GET /projects` | — | `projects_list` |
| `GET /syncs` | — | `syncs_list` |
| *(não existe na API)* | — | `people_search`: por trecho, ou pelo identificador do GitHub |

### O que esta feature NÃO é

- **Não é uma API nova.** Cada ferramenta espelha **uma** rota, com o mesmo veredito, o mesmo
  corpo e o mesmo corte. Se a rota muda, a ferramenta muda junto, e há teste que prova isso.
- **Não é escrita.** Como a 061 e a 062.
- **Não é ranking.** Nenhuma ferramenta ordena pessoa por medida.
- **Não é busca aproximada.** "barcelos" não acha "Barcellos".

## User Scenarios & Testing *(mandatory)*

### User Story 1 — O agente descobre por onde começar (Priority: P1)

O agente não sabe nenhum id. Pede `teams_list` e recebe as equipes que o token alcança; ou pede
`people_search` com o que sabe da pessoa.

**Por que P1**: sem descoberta, as outras ferramentas não têm entrada.

**Teste independente**: com um token novo e nenhum id conhecido, o agente chega a uma equipe e a
uma pessoa só pelo MCP.

**Cenários de aceitação**:

1. **Dado** um token cuja conta alcança 3 equipes, **quando** o agente pede `teams_list`,
   **então** recebe as 3, e nenhuma outra, como na API.
2. **Dado** uma pessoa "João Pedro Zamborlini Barcellos" no alcance, **quando** o agente busca
   `"barcel"`, `"BARCEL"` ou `"Zambôrlini"`, **então** ela aparece nas três; e `"barcelos"` não
   a acha.
3. **Dado** o login dela, `joaopbarcellos`, **quando** o agente busca pelo identificador do
   GitHub, **então** ela vem, e só ela. O mesmo vale para o id do nó (`U_…`).
4. **Dado** uma pessoa fora do alcance do token, **quando** o agente busca pelo trecho ou pelo
   identificador dela, **então** a resposta é idêntica à de uma busca sem resultado.

---

### User Story 2 — As mesmas respostas da API (Priority: P1)

Para cada uma das oito rotas, a ferramenta correspondente devolve o **mesmo corpo** que a rota
devolveria à mesma conta, com a mesma paginação.

**Por que P1**: é o pedido.

**Teste independente**: para cada par rota↔ferramenta, com a mesma conta e o mesmo dado, o
`data` da rota e o `value` da ferramenta são iguais.

**Cenários de aceitação**:

1. **Dado** uma pessoa no alcance, **quando** o agente pede `person_get`, **então** recebe o
   mesmo `data` de `GET /api/v1/people/:id`, inclusive `work.issues`, que são as tarefas
   atribuídas a ela.
2. **Dado** mais pessoas do que cabe numa página, **quando** o agente pede `people_list` com o
   cursor devolvido, **então** recebe a página seguinte, como `after` na API.
3. **Dado** uma equipe, **quando** o agente pede `team_measures`, **então** recebe as medidas com
   as ressalvas da base, como na rota.

---

### User Story 3 — O veredito é o mesmo em todas as portas (Priority: P1)

**Por que P1**: é a exigência de segurança da 062, e o #989 mostrou o custo de uma porta divergir.

**Teste independente**: para cada caminho de concessão e para a recusa, tela, API e MCP dão o
mesmo veredito, em cada ferramenta que recebe um alvo.

**Cenários de aceitação**:

1. **Dado** uma conta sem alcance sobre a pessoa, **quando** pede `person_get`, **então** recebe o
   que a API devolve para ela: a pessoa, com `work`, `changes` e `discussion_participation` em
   `null` (#989). A recusa fica registrada.
2. **Dado** um id de outro tenant ou inexistente, **então** a resposta é a mesma de "não
   encontrado" na API, e não distingue um caso do outro.
3. **Dado** um token revogado, **então** a chamada seguinte recebe 401.

### Edge Cases

- **Busca com menos de 3 ou mais de 100 caracteres** depois de aparar: erro de parâmetro.
- **Busca com `%`, `_`, `*` ou `\`**: caracteres literais, e não curinga.
- **Busca por identificador do GitHub com trecho** (`joaop`): não casa. A busca por identificador
  é **exata**; o trecho é a outra.
- **Login que mudou no GitHub**: o id do nó continua o mesmo, e é por isso que ele é aceito.
- **Equipe da pessoa fora do alcance**: `people_search` lista só as equipes que o token vê.
- **Cursor adulterado ou de outra ferramenta**: erro de parâmetro, como na API.
- **`page_size` acima do teto da API**: o teto da API vale, e a resposta diz o tamanho aplicado.
- **Nome ou título hostil**: sai em `untrusted_text`, com o marcador de caractere invisível.

## Requirements *(mandatory)*

### O espelho: uma ferramenta por rota

- **FR-001**: A lista de ferramentas passa a ter **treze**: as quatro da 062, as oito deste
  espelho (sete novas, porque `team_roster` já espelha `/members`) e `people_search`. A lista
  continua **fechada**, e o teste que a enumera passa a exigir as treze.
- **FR-002**: Cada ferramenta do espelho declara **a rota que espelha**. Para a mesma conta e o
  mesmo dado, o `value` da ferramenta é **igual** ao `data` da rota. Há um teste por par, e
  ferramenta sem rota declarada não entra.
- **FR-003**: O espelho **reusa a construção do corpo da API**, e não a reimplementa. Duas
  implementações do mesmo corpo divergem, e o #989 foi exatamente uma porta copiando a
  omissão da outra: com uma só, o conserto chega às duas.
- **FR-004**: Os argumentos são os da rota, **e só eles**: o id no caminho vira `team_id` ou
  `person_id`; `after` e `page_size` passam iguais. Nenhum outro argumento é aceito,
  incluindo `tenant_id`.
- **FR-005**: `team_measures` espelha a resposta inteira de `/teams/:id/measures`, inclusive a
  cobertura de competências, que as três ferramentas da 062 não trazem. As três continuam, com
  a descrição dizendo que são recortes de `team_measures`.

### A busca de pessoa, que a API não tem

- **FR-006**: `people_search` recebe **exatamente um** de dois argumentos: `query` (trecho) ou
  `github` (identificador). Os dois juntos, ou nenhum, é erro de parâmetro.
- **FR-007**: `query` casa como **trecho contínuo** do login ou do nome, sem diferenciar
  maiúscula nem acento, com **3 a 100** caracteres depois de aparar. Todo caractere é literal:
  sem curinga, expressão, operador ou semelhança.
- **FR-008**: `github` casa **exatamente**, sem diferenciar maiúscula, com o login **ou** com o
  identificador do nó guardado como `external_id`, e só para pessoas cuja origem é o GitHub.
  Devolve no máximo uma pessoa por instância de GitHub.
- **FR-009**: `people_search` devolve **no máximo 10** pessoas, ordenadas por login, e diz se
  cortou. Cada uma traz **só** `person_id`, login, nome em `untrusted_text` e as equipes
  vigentes que o token vê. O resto vem de `person_get`.
- **FR-010**: `people_search` devolve **só** quem `pode_ver/3` concede à conta, com o filtro
  aplicado **antes** do corte. Uma busca cujo único casamento está fora do alcance produz
  resposta **idêntica** à de uma busca sem casamento.
- **FR-011**: **Divergência proposital, declarada.** `people_list`, como `GET /api/v1/people`,
  lista o que a API lista. `people_search` é mais estrita: não mostra nem a identidade de quem
  está fora do alcance. A razão é a FR-032 da 062: o consumidor é um modelo.

### A emenda da FR-023 da 062

- **FR-012**: A FR-023 da 062 (*"nenhuma ferramenta aceita consulta arbitrária"*) é emendada para
  aceitar **três** tipos de entrada, e só três:
  1. **cursor e tamanho de página**, com o teto da API. Não escolhem o que se afirma, só quanto;
  2. **`query`** da busca por trecho, sob as condições da FR-007 e da FR-010;
  3. **`github`**, identificador exato.

  O que a FR-023 fecha continua fechado: o agente escolher **o que** a plataforma afirma
  (filtrar por campo arbitrário, ordenar por medida, montar consulta). Nenhuma das três faz isso.

### Herdado da 062 e da 061, sem mudança

- **FR-013**: O caminho único da 062 (argumento validado, alvo carregado **no tenant do token**,
  veredito, ferramenta, verificação de codificação, registro) vale para toda ferramenta. O que
  varia entre elas é o validador do argumento e o carregador do alvo, **declarados** na entrada
  do registro, e não um segundo caminho.
- **FR-014**: O alvo é carregado no tenant do token **antes** do veredito, e a ferramenta recebe o
  alvo carregado, nunca o id cru. O ramo admin de `pode_ver/3` concede qualquer UUID, então é o
  carregamento que isola os tenants (achado A4-1 da avaliação de segurança).
- **FR-015**: A recusa é resposta, com a forma da 062, e fica registrada com o evento da mesma
  natureza da tela e da API, **acrescido da porta e do `public_id` do token** (achado A5-1).
- **FR-016**: Lastro na base (FR-020 da 062). Cada ferramenta nova declara a pergunta de
  competência ou a necessidade de informação a que responde. Onde a base não tiver uma, ela é
  acrescentada **antes** do código, pela revisão semântica, ou a ferramenta não entra. A lista
  por ferramenta vai no plano.
- **FR-017**: A descrição de cada ferramenta declara o que ela **não responde** (FR-022 da 062).
- **FR-018**: Toda chamada é registrada por `public_id`, com a ferramenta e o alvo. A `query` e o
  `github` **não** são registrados como texto.
- **FR-019**: O mesmo limite de 120 chamadas por minuto por token, e o mesmo 401.
- **FR-020**: Nenhuma resposta traz e-mail, nível de acesso na origem, credencial ou valor
  derivado do token. A varredura em teste da 062 passa a cobrir as treze ferramentas.

### Key Entities

- **Par rota↔ferramenta**: a rota da 061, a ferramenta que a espelha, e o teste que prova a
  igualdade.
- **Pessoa localizada**: `person_id`, login, nome e equipes visíveis. É identidade de trabalho, e
  não perfil.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A pergunta *"quais tarefas estão alocadas para o Barcellos?"* é respondida com
  **2 chamadas** (`people_search` → `person_get`), contra as 20 de 2026-09-25, e sem nenhum dado
  tirado por fora do MCP.
- **SC-002**: Para as **8** rotas, o `value` da ferramenta e o `data` da rota são iguais, com a
  mesma conta e o mesmo dado: **8 de 8** pares.
- **SC-003**: Em cada ferramenta que recebe alvo, tela, API e MCP dão o mesmo veredito nos
  5 casos de `pode_ver/3`: **5 de 5**.
- **SC-004**: Uma busca cujo único casamento está fora do alcance e uma busca sem casamento
  produzem respostas **idênticas** byte a byte, pelo trecho e pelo identificador.
- **SC-005**: A varredura de segredo e de dado pessoal nas **treze** ferramentas encontra zero
  e-mails e zero níveis de acesso, e reprova com o defeito injetado.
- **SC-006**: O custo de cada ferramenta do espelho é o da rota que ela espelha, com a diferença
  nomeada quando houver (T028 da 062).
- **SC-007**: O cliente real (SDK oficial de Python) faz a pergunta do SC-001 de ponta a ponta.

## Fora de escopo

| Fora | Por quê |
|---|---|
| **o que a API não expõe** | mudanças, commits, arquivos, verificações, previsão, contas, credenciais: a 061 os deixou fora com razão (FR-021 dela), e o espelho não reabre por outra porta |
| **busca aproximada** | casar por semelhança é mapear por semelhança de nome (§6 do `AGENTS.md`) |
| **busca na API** | `people_search` é do MCP. Levá-la à API é outra decisão, com a sua avaliação |
| **escrita** | a mesma razão da 061 e da 062 |

## Segurança — o que o papel Security precisa avaliar antes do plano

A avaliação da versão de 2026-09-25 já produziu achados que valem aqui: A4-1 (o carregamento
no tenant antes do veredito), A4-2 (um caminho só), A4-3 (canal de tempo), A5-1 e A5-2 (o
registro da recusa), e o lateral que virou o #989. Faltam:

1. **O espelho herda o que a API expõe, e agora para um modelo.** `person_get` entrega a pessoa
   inteira: perfil, antipadrões, lead time, trabalho. Na API isso vai para uma integração; no
   MCP vai para um modelo, que pode guardar e indexar (FR-032 da 062). O Security diz se alguma
   parte do corpo não deve ir ao modelo.
2. **`people_list` é a lista do alcance, página a página.** A enumeração é a da API, e não maior.
   Confirmar.
3. **A busca por `github`** é exata e de um resultado: confirma se ela vaza existência por outra
   via (tempo, corte).
4. **Os pontos 1, 4 e 5 da versão anterior**: enumeração pela busca por trecho, a `query` como
   entrada, e a divergência proposital com a tela.

## Assumptions

- O servidor, a porta, o token, o registro e o limite são os da 062.
- O corpo de cada rota é o da API **depois** do hotfix v0.9.3 (#989). Espelhar antes seria copiar
  o furo, e por isso esta feature depende do hotfix no ar.
- O teto de página é o da API.
- "Sem acento" segue a normalização Unicode usual para português (é → e, ç → c, ã → a).

## Dependências

| Depende de | Estado |
|---|---|
| 062 (servidor MCP) | em `development`; PR #988 fecha as últimas tarefas |
| v0.9.3 (#989) | hotfix em preparação: `changes` e `discussion_participation` dentro do veredito |
| a construção dos corpos da API | existe nos controladores da 061; o plano decide como reusá-la |
