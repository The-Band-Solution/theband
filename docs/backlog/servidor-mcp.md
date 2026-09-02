# Um servidor MCP para os dados da plataforma

Pedido da pessoa mantenedora em 2026-09-02. **Ainda não é spec** — é o registro do
que foi pedido e das decisões que precisam vir antes.

> *"cria um servidor MCP para que o OpenAI, claude.ai ou outro agente consuma os
> dados"*

O The Band responde perguntas sobre organizações, equipes, pessoas e trabalho,
com proveniência em cada registro. Hoje só a interface as responde. Um servidor
MCP faria a mesma resposta chegar a um agente — e a agentes de terceiros.

## Por que isto não é "expor o banco por uma API"

A plataforma inteira existe para separar **o que foi observado** do **que foi
derivado** e do **que foi declarado**. Uma ferramenta MCP que devolve números sem
essa marca destrói a distinção no ponto de entrega — e o consumidor do outro lado
é um modelo, que vai afirmar o número sem a ressalva.

**Toda resposta de toda ferramenta precisa carregar a proveniência**, e as
limitações declaradas da medida junto. É a regra que o princípio IV já exige das
telas, aplicada a um consumidor que não sabe perguntar.

Duas consequências práticas:

- ferramenta que devolve uma medida devolve também as **interpretações
  incorretas** declaradas em `priv/knowledge_base/` — não como texto opcional, e
  sim no mesmo objeto;
- ausência vem **nomeada**. Um agente que recebe `0` onde a resposta é
  "não observado" vai relatar zero, e ninguém verá a diferença.

## Decisões que precisam vir antes de qualquer código

### 1. Autenticação e tenant — a mais importante

Consulta sem tenant é bug de segurança (princípio V). Um servidor MCP acessível de
fora precisa responder **de qual tenant** cada chamada fala, e a resposta não pode
vir do próprio pedido.

Sem isso decidido, não há o que implementar. As opções aparentes:

| Opção | O que implica |
|---|---|
| token por tenant, emitido na plataforma | o tenant vem do token, nunca do argumento; revogável |
| OAuth com a conta da pessoa | o tenant vem da sessão; mais trabalho, e é o caminho que claude.ai espera |
| servidor local por instalação | some o problema de multitenant; some também o acesso remoto |

### 2. Leitura, escrita, ou as duas

Um servidor só de leitura é muito mais barato de acertar. Escrita — declarar
equipe, registrar saída — traz o problema de **quem é o autor**: a plataforma
grava `declared_by_user_id`, e um agente não é uma pessoa.

Recomendação a discutir: **começar somente-leitura**, e tratar escrita como
decisão separada com o autor resolvido antes.

### 3. Quais perguntas o servidor responde

Não é "uma ferramenta por tabela". As perguntas de competência já declaradas na
base de conhecimento são a lista natural de candidatas — e a que a plataforma
existe para responder.

### 4. O que nunca sai

Credencial, segredo, e qualquer campo que a interface já esconde. A regra que
vale na tela vale aqui, e o consumidor remoto torna o vazamento pior: o que sai
por MCP pode ser cacheado e indexado do outro lado.

## Relação com o que já existe

| Já existe | Serve para |
|---|---|
| API pública de cada módulo ontológico | é a fronteira que as ferramentas devem chamar — nunca `Repo` |
| medidas declaradas em YAML, com limitações | vira o conteúdo obrigatório de cada resposta |
| perguntas de competência | a lista de ferramentas candidatas |
| `tenant_id` em toda consulta | o que a autenticação precisa alimentar |

## Prioridade

**Depende da decisão 1.** Enquanto autenticação e tenant não estiverem resolvidos,
não entra em sprint — implementar antes produziria um servidor que precisa ser
refeito, ou pior, um que vaza entre tenants.

Registrado em 2026-09-02, sem sprint atribuído.
