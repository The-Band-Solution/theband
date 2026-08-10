---

description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Testes**: cada tarefa carrega o seu, no campo `Teste`. Não há tarefa sem forma
de demonstrar que ficou pronta.

**Organização**: as tarefas são agrupadas por user story, para que cada uma possa
ser implementada, testada e entregue de forma independente.

## Formato

```text
- [ ] TID [P?] [US?] Título curto e direto
  - **Pronta quando**: o que precisa já ser verdade para a tarefa começar
  - **Descrição**: o que fazer — caminhos, comandos, e o requisito (FR/SC) ou
    contrato que a justifica
  - **Feita quando**: condições observáveis, cada uma conferível por outra pessoa
  - **Teste**: o comando ou a verificação que demonstra
```

- **[P]**: pode rodar em paralelo — arquivo distinto, sem dependência pendente
- **[US]**: a user story que a tarefa atende (US1, US2, US3…)
- **Título sem comandos e sem caminhos.** Eles vivem em `Descrição`: um título é
  lido numa lista de setenta, e precisa dizer o que a tarefa é num relance
- `Feita quando` **não repete o título**. "o vault está implementado" é o título
  com um verbo trocado, e não dá para conferir
- `Teste` **não é `mix test`**. Isso diz que a suíte passou, não que *esta*
  tarefa funciona — nomeie o arquivo, o caso ou a asserção

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /speckit-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Gerar a estrutura do projeto
  - **Pronta quando**: nada além do repositório
  - **Descrição**: estrutura conforme a decisão de estrutura do `plan.md`
  - **Feita quando**: a árvore de diretórios corresponde ao plano; nenhum
    diretório vazio foi criado antecipadamente
  - **Teste**: a compilação roda limpa a partir da raiz

- [ ] T002 Fixar as versões das dependências
  - **Pronta quando**: T001 concluída; as versões estão decididas em `research.md`
  - **Descrição**: fixar as versões exatas no manifesto, com a justificativa de
    cada dependência nova registrada no plano
  - **Feita quando**: o arquivo de lock está commitado; nenhuma versão está aberta
    onde a pesquisa pediu fixação
  - **Teste**: a instalação de dependências resolve sem conflito, do zero

- [ ] T003 [P] Configurar formatador e linter
  - **Pronta quando**: T002 concluída
  - **Descrição**: configuração do formatador e do linter no modo estrito exigido
    pela constituição
  - **Feita quando**: os dois rodam sem apontar nada no código existente
  - **Teste**: os comandos de verificação de formato e de lint retornam zero

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Exemplos de tarefas de fundação (ajuste ao seu projeto):

- [ ] T004 Criar o esquema base do banco
  - **Pronta quando**: o modelo de dados está aprovado em `data-model.md`
  - **Descrição**: migração das tabelas comuns, com as colunas obrigatórias de
    identidade e proveniência exigidas pela constituição
  - **Feita quando**: as restrições existem no banco, e não apenas no changeset;
    a migração tem `down` explícito
  - **Teste**: aplicar e reverter a migração deixa o banco no estado anterior

- [ ] T005 [P] Escopo de acesso por organização
  - **Pronta quando**: T004 concluída
  - **Descrição**: toda consulta de domínio recebe o tenant explicitamente;
    nenhuma o busca do dicionário de processo
  - **Feita quando**: nenhuma função pública de leitura existe sem o parâmetro de
    tenant
  - **Teste**: dois tenants povoados, e a listagem de um não devolve nada do outro

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Implementação da User Story 1

O teste de cada tarefa vive no campo `Teste` dela. Não há uma seção de testes
separada: teste que mora longe da tarefa é teste que ninguém escreve.

- [ ] T010 [P] [US1] Modelar [entidade principal]
  - **Pronta quando**: o contrato do módulo está escrito em `contracts/`;
    T004 concluída
  - **Descrição**: schema e migração de [entidade], com as invariantes que a
    especificação declara — [FR-XXX]
  - **Feita quando**: gravar sem [campo obrigatório] é recusado pelo banco, não
    apenas pelo changeset
  - **Teste**: o teste da **violação** — a escrita inválida devolve erro nomeando
    o que faltou

- [ ] T011 [US1] [Ação principal da user story]
  - **Pronta quando**: T010 concluída
  - **Descrição**: [o que fazer], em [caminho]. [Restrição que é fácil errar, e
    por que importa] — [FR-XXX], contrato [nome]
  - **Feita quando**: [condição observável]; [segunda condição]
  - **Teste**: [arquivo] — [o que a asserção prova]

- [ ] T012 [US1] Tela de [o que a pessoa vê]
  - **Pronta quando**: T011 concluída; o contrato de telas está escrito
  - **Descrição**: [rota] exibindo [o que], com os estados vazio, carregando e
    sem permissão — contrato de telas
  - **Feita quando**: o estado vazio diz **por que** está vazio; a contagem do
    cabeçalho bate com a listagem sob qualquer filtro
  - **Teste**: teste de interface — o que precisa estar visível, e o que **não**
    pode aparecer

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Implementação da User Story 2

Mesma forma da US1: título curto, e os quatro campos em cada tarefa. Uma tarefa
que integra com a US1 declara isso em `Pronta quando`, citando o ID — não "a
anterior".

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Implementação da User Story 3

Mesma forma.

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Atualizar a documentação
  - **Pronta quando**: as user stories estão concluídas
  - **Descrição**: refletir em `docs/` e no README o que a feature entregou, e o
    que ela deliberadamente não entregou
  - **Feita quando**: nenhum documento descreve comportamento que não existe
  - **Teste**: seguir o guia do zero, num ambiente limpo, e chegar ao resultado
    descrito

- [ ] TXXX Rodar os quality gates
  - **Pronta quando**: todas as tarefas de implementação concluídas
  - **Descrição**: os gates obrigatórios da constituição, sem exceção e sem
    desabilitar check para o pipeline passar
  - **Feita quando**: todos verdes, com a saída registrada
  - **Teste**: os próprios gates — a saída de cada um é a evidência

- [ ] TXXX Executar os cenários do quickstart
  - **Pronta quando**: os gates estão verdes
  - **Descrição**: percorrer cada cenário de `quickstart.md` e registrar a
    evidência de cada um
  - **Feita quando**: todo cenário tem resultado registrado — inclusive os que
    **não** puderam ser executados, com o motivo
  - **Teste**: o próprio percurso; a evidência vai para o `sprint-review.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (if tests requested):
Task: "Contract test for [endpoint] in tests/contract/test_[name].py"
Task: "Integration test for [user journey] in tests/integration/test_[name].py"

# Launch all models for User Story 1 together:
Task: "Create [Entity1] model in src/models/[entity1].py"
Task: "Create [Entity2] model in src/models/[entity2].py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
