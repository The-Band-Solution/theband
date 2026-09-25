# Spec 069 — MCP: localizar uma pessoa, e o trabalho aberto dela

**Feature branch**: `069-mcp-busca-de-pessoas`
**Criada**: 2026-09-25
**Estado**: rascunho
**Estende**: [062 — servidor MCP](../062-servidor-mcp/spec.md)
**Decisões da pessoa mantenedora (2026-09-25)**: a busca casa **trecho**, sem diferenciar
maiúscula nem acento; a busca devolve **só o alcance do token**.

## O que esta feature resolve

Pergunta feita em 2026-09-25: *"quais tarefas estão alocadas para o Barcellos?"*. Hoje o MCP
não responde, e a razão está no desenho da 062: toda ferramenta pede um `team_id`, e nenhuma
diz quais equipes existem nem onde uma pessoa está.

Isso foi **medido** com um cliente real (SDK oficial de Python, `mcp` 2.2.0):

- para achar a pessoa, os 10 `team_id` do tenant saíram do banco, **por fora do MCP**;
- foram 20 chamadas: um `team_roster` por equipe para achar a pessoa, e um `team_open_work`
  por equipe para achar as tarefas;
- a primeira busca, por "barcelos", não achou ninguém. A pessoa é "Barcellos".

Um agente não tem banco para consultar por fora. Para ele a pergunta simplesmente não tem
resposta.

### O que esta feature NÃO é

- **Não é ranking.** `person_open_work` responde sobre **uma** pessoa. Não compara, não soma
  entre pessoas, não mede produtividade. A descrição da ferramenta diz isso (FR-022 da 062).
- **Não é busca aproximada.** "barcelos" continua não achando "Barcellos". Casar por
  semelhança é a forma como esta casa inventa correspondência (ver *Fora de escopo*).
- **Não é listagem de equipes.** A lacuna de descoberta de equipe fica registrada, e não é
  resolvida aqui.
- **Não é escrita.** Como toda a 062.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Localizar uma pessoa pelo que se sabe dela (Priority: P1)

Quem usa um agente sabe um pedaço do nome ou do login, e não o `person_id`. O agente pede
`people_search` com esse pedaço e recebe as pessoas que casam, com o id que as outras
ferramentas aceitam.

**Por que P1**: sem ela, a US2 não tem por onde começar.

**Teste independente**: com uma conta que alcança a pessoa, `people_search("barcel")` devolve
a pessoa cujo nome contém "Barcellos", com `person_id`, login, nome e equipes. Com uma conta
que não a alcança, a mesma busca devolve lista vazia, **igual** à de um nome que não existe.

**Cenários de aceitação**:

1. **Dado** uma pessoa "João Pedro Zamborlini Barcellos" no alcance, **quando** o agente busca
   `"barcel"`, `"BARCEL"` ou `"Zambôrlini"`, **então** ela aparece nas três.
2. **Dado** o mesmo, **quando** busca `"barcelos"`, **então** ela **não** aparece, porque
   "barcelos" não é trecho de "Barcellos".
3. **Dado** a pessoa fora do alcance do token, **quando** busca `"barcel"`, **então** a resposta
   é idêntica à de uma busca sem nenhum resultado: não confirma que ela existe.
4. **Dado** uma busca com menos de 3 caracteres depois de tirar espaços, **então** é recusada
   como erro de parâmetro, e não como lista vazia.
5. **Dado** mais de 10 pessoas no alcance que casam, **então** vêm 10, e a resposta diz que
   foi cortada.

---

### User Story 2 — O trabalho aberto de uma pessoa (Priority: P1)

Com o `person_id`, o agente pede `person_open_work` e recebe as tarefas abertas atribuídas
àquela pessoa, **em todas as equipes e projetos**, com a proveniência e as ressalvas.

**Por que P1**: é a pergunta que motivou a feature.

**Teste independente**: para a pessoa medida em 2026-09-25, `person_open_work` devolve as
mesmas tarefas abertas que a tela da pessoa mostra como *assigned, not done*, e **uma** chamada
basta, não vinte.

**Cenários de aceitação**:

1. **Dado** uma pessoa com tarefas abertas em duas equipes, **quando** o agente pede
   `person_open_work`, **então** vêm as das duas, cada uma com o conceito
   (`sro.intended_scrum_development_task`, `sro.atomic_user_story`, `osdef.defect`…), há quanto
   tempo está aberta e se está parada.
2. **Dado** uma pessoa membro de uma **parte** de equipe composta, **então** as tarefas dela
   aparecem. Não depende de por qual equipe se chegou até ela (ver #987).
3. **Dado** qualquer resposta, **então** ela carrega o envelope da 062: origem, data da coleta,
   janela e as ressalvas lidas da base, e o título de cada tarefa em `untrusted_text`.
4. **Dado** uma pessoa sem nenhuma tarefa aberta, **então** a resposta é `checked` com lista
   vazia, e isso é distinguível de recusa e de "não foi possível ler".

---

### User Story 3 — A recusa é a mesma das outras portas (Priority: P1)

**Por que P1**: é a mesma exigência de segurança da 062, US2. Três portas com três vereditos é
o mesmo furo contado três vezes.

**Teste independente**: para cada caminho de concessão de `pode_ver/3` e para a recusa, a tela
da pessoa, `GET /api/v1/people/:id` e `person_open_work` dão o mesmo veredito sobre o
**trabalho**.

**Cenários de aceitação**:

1. **Dado** uma conta sem alcance sobre a pessoa, **quando** pede `person_open_work`, **então**
   recebe `refused` com razão `fora_do_alcance`, sem nenhuma tarefa, e a recusa fica registrada
   como a da tela.
2. **Dado** um `person_id` de outro tenant ou inexistente, **então** a resposta é a mesma da
   recusa: não distingue "não existe" de "não pode ver".
3. **Dado** um token revogado, **então** a chamada seguinte recebe 401, como na 062.

---

### Edge Cases

- **Equipe da pessoa fora do alcance**: a pessoa está no alcance, mas pertence também a uma
  equipe que o token não vê. `people_search` lista **só** as equipes que o token vê. Listar as
  outras vazaria o nome de uma equipe fora do alcance.
- **Nome com acento, ou query com acento**: casa nos dois sentidos, "Zambôrlini" acha
  "Zamborlini" e vice-versa.
- **Query com `%`, `_`, `*` ou `\`**: são caracteres literais, e não curinga. "a%b" procura o
  trecho "a%b".
- **Query só com espaços, ou com 2 letras e espaços em volta**: erro de parâmetro (mínimo 3
  depois de aparar).
- **Query muito longa**: acima de 100 caracteres, erro de parâmetro. Nenhum nome real passa
  disso, e o limite impede usar a busca como canal de carga.
- **Nome hostil** (instrução embutida, caractere invisível): sai em `untrusted_text`, com o
  marcador de caractere invisível, como o texto de terceiro da 062.
- **Pessoa que saiu de todas as equipes**: continua localizável se estiver no alcance, com
  lista de equipes vigentes vazia.
- **Mais de 200 tarefas abertas**: vêm 200, com `truncated: true`, como no `team_open_work`.
- **Tarefa sem atribuição**: não aparece para ninguém. A resposta não a atribui a quem a abriu.

## Requirements *(mandatory)*

### As duas ferramentas

- **FR-001**: A lista de ferramentas passa de quatro para **seis**: as quatro da 062,
  `people_search` e `person_open_work`. A lista continua fechada (FR-023 da 062), e o teste que
  a enumera passa a exigir as seis.
- **FR-002**: `people_search` recebe **só** `query`, texto. Qualquer outro argumento é erro de
  parâmetro, incluindo `tenant_id`, `limit` e `team_id`.
- **FR-003**: `query` casa como **trecho contínuo** do login **ou** do nome, sem diferenciar
  maiúscula nem acento. Não há curinga, expressão regular, operador nem semelhança: todo
  caractere é literal.
- **FR-004**: `query` tem de **3 a 100** caracteres depois de aparar os espaços das pontas.
  Fora disso, erro de parâmetro.
- **FR-005**: `people_search` devolve **no máximo 10** pessoas, em ordem **determinística** e
  declarada (por login). A resposta diz se foi cortada. Não há ordenação por relevância, porque
  relevância seria a plataforma decidindo quem "casa mais".
- **FR-006**: Cada pessoa devolvida traz **só**: `person_id`, login, nome (em `untrusted_text`)
  e as equipes **vigentes** que o token vê, com nome em `untrusted_text`. Não traz e-mail, nível
  de acesso na origem, contagem de trabalho, perfil nem nada que permita comparar pessoas.
- **FR-007**: `person_open_work` recebe **só** `person_id` (UUID). Qualquer outro argumento é
  erro de parâmetro.
- **FR-008**: `person_open_work` devolve as tarefas **abertas** atribuídas à pessoa, **em todo o
  tenant**, pela mesma fonte que a tela da pessoa usa para *assigned, not done*. Cada tarefa traz
  o conceito ontológico, `issue_id`, título em `untrusted_text`, dias em aberto e se está parada
  pelo limiar declarado.
- **FR-009**: A resposta de `person_open_work` carrega o envelope da 062, com as ressalvas lidas
  da base, e nunca escritas no código.
- **FR-010**: `person_open_work` corta em **200** tarefas, com `truncated: true` e o limite na
  resposta.

### O alcance: o veredito é o da tela e o da API

- **FR-011**: `people_search` devolve **só** pessoas para as quais `pode_ver/3` concede à conta
  dona do token. O filtro de alcance é aplicado **antes** do corte em 10. Cortar antes deixaria
  quem está fora do alcance ocupar vaga, e o número de resultados vazaria que ela existe.
- **FR-012**: Uma busca cujo único casamento está fora do alcance devolve resposta
  **byte a byte idêntica** à de uma busca sem casamento.
- **FR-013**: `person_open_work` passa pelo **caminho único** da 062: argumento validado →
  pessoa buscada no tenant do token → `pode_ver/3` → ferramenta → verificação de codificação →
  registro. Não há segundo caminho.
- **FR-014**: Recusa de `person_open_work` é **resposta** (`refused`, `fora_do_alcance`, `value:
  nil`), e não erro. `person_id` inexistente ou de outro tenant recebe a **mesma** recusa.
- **FR-015**: A recusa fica registrada com o **mesmo** evento da tela da pessoa
  (`painel_recusado`), com a conta, o tenant e a pessoa pedida.
- **FR-016**: **Divergência proposital com a tela, declarada**: a tela mostra a **identidade**
  de qualquer pessoa do tenant e esconde só o trabalho. `people_search` não mostra nem a
  identidade de quem está fora do alcance. A razão é a FR-032 da 062: o consumidor é um modelo,
  e o que ele lê pode ser guardado e indexado do outro lado. A regra da tela, aplicada com
  margem maior.

### A emenda da FR-023 da 062

- **FR-017**: A FR-023 da 062 é emendada para dizer: *nenhuma ferramenta aceita consulta
  arbitrária; `people_search.query` é texto para **localizar**, e não filtro*. A emenda vale
  **só** porque as cinco condições abaixo valem juntas. Se uma cair, a emenda cai:
  1. **um só campo**, `query`, e mais nenhum;
  2. **um só modo de casar** (trecho literal), sem operador, curinga nem expressão;
  3. **um teto** de 10 resultados, fixo e fora do alcance do argumento;
  4. **o alcance do token é aplicado antes do teto** (FR-011), então a busca não mostra nada
     que a conta já não possa ver pela tela ou pela API;
  5. **a resposta não carrega medida.** Não dá para ordenar pessoas por nada além do login.

  O que a FR-023 fecha é o agente **escolher o que a plataforma afirma**: filtrar por campo
  arbitrário, ordenar por medida, montar consulta. Com as cinco condições, a busca não afirma
  nada novo. Ela diz o `person_id` de quem a conta já vê.

### Herdado da 062, sem mudança

- **FR-018**: Lastro na base (FR-020 da 062). `person_open_work` responde à `sro.cq19` lida no
  sentido inverso (*de quais tarefas uma pessoa está encarregada*), pela relação
  `sro.developer_in_charge_of_development_task`. Se a revisão semântica decidir que o sentido
  inverso pede pergunta própria, ela é acrescentada à base **antes** do código.
  `people_search` responde à `sro.cq15` (*quem são os membros*), porque localiza membros.
- **FR-019**: A descrição de cada ferramenta nova declara o que ela **não responde** (FR-022 da
  062). `person_open_work`: não compara pessoas, não mede produtividade, e tarefa atribuída não
  quer dizer tarefa em execução. `people_search`: não diz se a pessoa existe fora do alcance, e
  não é lista do tenant.
- **FR-020**: Cada chamada fica registrada por `public_id` do token, com a ferramenta e o alvo:
  a pessoa em `person_open_work`, e **nenhum alvo** em `people_search`. A `query` **não** é
  registrada, porque é texto livre de quem pergunta e pode conter o que não devia.
- **FR-021**: O mesmo limite de 120 chamadas por minuto por token, e o mesmo 401.
- **FR-022**: Nenhuma resposta contém e-mail, nível de acesso na origem, credencial ou valor
  derivado do token. A varredura em teste da 062 passa a cobrir as seis ferramentas.

### Key Entities

- **Pessoa localizada**: `person_id`, login, nome e equipes vigentes visíveis. É **identidade
  de trabalho**, e não perfil.
- **Tarefa aberta atribuída**: item de trabalho aberto cujo responsável na origem é a pessoa.
  Ontologicamente é `sro.intended_scrum_development_task`, `sro.atomic_user_story` ou
  `osdef.defect`, pelo roteamento de tipo já existente. "Atribuída" é o `assignee` da origem, e
  a ressalva diz que isso não prova execução.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A pergunta *"quais tarefas estão alocadas para o Barcellos?"* é respondida com
  **2 chamadas** (`people_search("barcel")` → `person_open_work`), contra as 20 de 2026-09-25,
  e sem nenhum dado tirado por fora do MCP.
- **SC-002**: Para a pessoa medida, o total de tarefas abertas de `person_open_work` é **igual**
  ao *assigned, not done* da tela da pessoa, medido nos mesmos dados.
- **SC-003**: Em teste com 5 casos (4 concessões e a recusa de `pode_ver/3`), tela, API e
  `person_open_work` dão o mesmo veredito em **5 de 5**.
- **SC-004**: Uma busca cujo único casamento está fora do alcance e uma busca sem casamento
  produzem respostas **idênticas** byte a byte.
- **SC-005**: A varredura de segredo e de dado pessoal nas **seis** ferramentas encontra **zero**
  e-mails e zero níveis de acesso, e reprova com o defeito injetado.
- **SC-006**: O custo de `person_open_work` **não cresce** com o número de tarefas (1 contra 50),
  e o de `people_search` não cresce com o número de pessoas do tenant.
- **SC-007**: Cliente real (o SDK oficial de Python, como no T030 da 062) faz a pergunta do
  SC-001 de ponta a ponta.

## Fora de escopo

| Fora | Por quê |
|---|---|
| **busca aproximada** (tolerar erro de digitação) | casar por semelhança é mapear por semelhança de nome, que esta casa proíbe (§6 do `AGENTS.md`, e a lição *padrão largo inventa mais*): o casamento errado vira resposta, e ninguém percebe |
| **listar equipes** (`teams_list`) | resolve a outra metade da descoberta. Fica registrada como lacuna: é outra superfície de enumeração, com avaliação própria |
| **o trabalho de várias pessoas numa chamada** | abriria a comparação que o `team_open_work` recusa. Um agente pode iterar pessoa a pessoa, e esse risco é avaliado pelo Security (ver abaixo), e não resolvido por uma ferramenta que o facilite |
| **tarefas fechadas, histórico, perfil ou competências da pessoa** | outras perguntas, outro lastro |
| **escrita** | a mesma razão da 062 |

## Segurança — o que o papel Security precisa avaliar antes do plano

1. **Enumeração pela busca.** Com mínimo de 3 caracteres e teto de 10, dá para percorrer
   `aaa`…`zzz` (17 576 buscas, cerca de 2,5 h a 120/min) e listar quem está no alcance. O
   argumento desta spec é que isso **não amplia** a exposição, porque a conta já vê essas
   pessoas pela tela e pela API. O Security confirma ou derruba, e diz se o registro precisa
   marcar busca em rajada.
2. **Comparação por iteração.** Um agente pode pedir `person_open_work` de cada pessoa e montar
   o ranking que a plataforma recusa. A plataforma não impede isso sem impedir a pergunta
   legítima. O Security avalia se a descrição basta ou se é preciso um controle (limite próprio,
   aviso no registro).
3. **Dado de pessoa exposto a modelo** (FR-032 da 062). Os títulos das tarefas de uma pessoa,
   juntos, dizem mais sobre ela do que o roster. O alcance mínimo do token (documentado em
   `docs/api/mcp.md`) passa a pesar mais.
4. **A `query` como entrada.** Texto de quem pergunta, que vai para uma consulta: injeção,
   normalização de acento, tamanho. E não registrar a `query` (FR-020): o Security confirma se
   isso tira evidência necessária numa investigação.
5. **A divergência da FR-016.** Ser mais estrito que a tela é seguro por construção, mas o
   Security confirma que nenhum outro caminho do MCP devolve a identidade de quem está fora do
   alcance.

## Assumptions

- O servidor, a porta, o token, o registro e o limite são os da 062, já em `development`.
- A fonte de "atribuída" é a mesma da tela da pessoa (`assignees` do GitHub, mapeado para
  `eo.person`). Tarefas de outras fontes seguem o que o mapeamento já traz.
- O limiar de "parada" é o mesmo do `team_stale_work`, lido da base.
- O teto de 10 é suficiente para localizar: quem digita um trecho de 3 letras que casa mais de
  10 pessoas refina a busca. O corte é declarado, então o agente sabe que precisa refinar.
- "Sem acento" segue a normalização Unicode usual para português (é → e, ç → c, ã → a).
- A #987 (o `is_composed` do `team_open_work`) não bloqueia esta feature, porque
  `person_open_work` lê pela pessoa, e não pela equipe.

## Dependências

| Depende de | Estado |
|---|---|
| 062 (servidor MCP) | em `development`; PR #988 fecha as últimas tarefas |
| `pode_ver/3` e o evento `painel_recusado` | existem, e a tela os usa |
| a fonte de *assigned, not done* da tela da pessoa | existe |
| `sro.cq19` e `sro.cq15` na base | existem; o sentido inverso da cq19 passa pela revisão semântica |
