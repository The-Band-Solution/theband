# Tasks: a definição de pronto declarada — fatia 1 (US1 + US2)

**Input**: `plan.md`, `data-model.md`, `contracts/declaracao-de-fase.md`, `prototipo/`.
**Testes**: cada tarefa carrega o seu. Nenhuma feita sem a asserção nomeada verde.
**Ordem**: fatia vertical. A primeira tarefa que chega à tela é a **T005**.

## Fase 0 — a base de conhecimento (princípio IV)

- [x] **T001** A regra `github.project_item_status` e o vocabulário reconhecido de pronto
  - **Descrição**: `priv/knowledge_base/rules/github_project_item_status.yaml` — os quatro
    destinos admitidos com o id do conceito, o vocabulário que gera proposta (*Done*,
    *Concluído*, *Closed*, *Concluida*…), o `does_not_materialize` (`sro.accepted_deliverable`,
    `sro.sprint_deliverable`) com a razão (`sro.rule03`), e a limitação de que o quadro não é
    conceito da rede. FR-021
  - **Feita quando**: a base valida; `KnowledgeBase.rule("github.project_item_status")` devolve
    os destinos e o vocabulário
  - **Teste**: o gate da base de conhecimento, e um teste que lê os destinos da regra

## Fase 1 — a declaração

- [x] **T002** A tabela e o schema
  - **Descrição**: migração `spo_item_phase_declarations` conforme `data-model.md`, com o
    índice parcial sobre os vigentes; schema com o changeset validando `target_concept` contra
    a regra da T001. FR-001, FR-002
  - **Teste**: declarar duas vezes a mesma opção vigente reprova pelo índice; revogar e
    redeclarar passa

- [x] **T003** Comandos: declarar e revogar
  - **Descrição**: `declare_item_phase/3` (declarar sobre vigente revoga a anterior na mesma
    transação) e `revoke_item_phase/3`, conforme o contrato. FR-002, FR-005
  - **Teste**: o "Replace" numa transação — se a criação falha, a anterior **continua vigente**

- [x] **T004** Consultas: vocabulário, propostas e contagem
  - **Descrição**: `status_vocabulary/2` — toda opção observada na ordem observada, com itens
    aberta/fechada de hoje, a declaração vigente e a proposta. FR-003, FR-004, FR-006
  - **Teste**: opção sem declaração cujo nome casa o vocabulário vem com `proposta`; com
    declaração vigente vem sem proposta

## Fase 2 — US1: a tela do quadro

- [x] **T005 [US1]** O cartão *What each column means*, exatamente o protótipo
  - **Descrição**: no `board_live/index.ex`, depois de *Start criterion*: a tabela das opções,
    o formulário dos destinos, a caixa de recusa da aceitação citando `sro.rule03`, a proposta
    visivelmente diferente da ativa, e a revogada sob a ativa. FR-001, FR-006, FR-022
  - **Teste**: teste de tela — a opção sem decisão diz "no decision"; a proposta diz "proposed";
    ativar grava autor e instante e a tela os mostra

- [ ] **T006 [US1]** Quem não administra lê e não vê ação
  - **Descrição**: o formulário e o revogar só para quem administra a organização; o evento é
    recusado com motivo. FR-005
  - **Teste**: conta sem administração renderiza sem botão, e o evento devolve recusa nomeada

## Fase 3 — US2: as duas afirmações

- [ ] **T007 [US2]** A leitura por item, em uma consulta
  - **Descrição**: `phase_of_items/2` — uma afirmação por quadro em que o item está, com o
    estágio e a fase. FR-007, FR-009
  - **Teste**: 100 itens custam o mesmo número de consultas que 10

- [ ] **T008 [US2]** As duas afirmações no detalhe do item
  - **Descrição**: ao lado de *fechada na origem*, a *concluída pelo quadro* com a marca
    declarado, o nome do quadro e o estágio; as quatro ausências escritas. FR-007 a FR-012
  - **Teste**: item Done com issue aberta mostra as duas; sem declaração diz "not declared";
    fora de quadro diz "in no board"

- [ ] **T009 [US2]** As duas afirmações na listagem
  - **Descrição**: a listagem `/work` sem que o custo cresça com as linhas. FR-011
  - **Teste**: o teste de custo da listagem

## Fase 4 — o desacordo e os gates

- [ ] **T010** O desacordo do quadro
  - **Descrição**: os dois números sob o cartão, com a definição por extenso, ou *não
    declarado*. FR-013, FR-014
  - **Teste**: com declaração, os dois números; sem, a frase

- [ ] **T011** Gates, quickstart e a conferência contra o protótipo
  - **Descrição**: `mix gates` verde; a conferência item a item da seção 3 do `PROMPT.md`
  - **Teste**: `echo $?` imediatamente após `mix gates`

## O que estas tarefas não cobrem

Os períodos de estágio (FR-024/025), a escolha da definição das medidas (FR-016/017/019), o
desacordo por pessoa, o *em andamento* no painel (FR-020). Fatia seguinte.
