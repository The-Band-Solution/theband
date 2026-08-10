---
name: "speckit-tasks"
description: "Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts."
argument-hint: "Optional task generation constraints"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/tasks.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before tasks generation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_tasks` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing command invocations from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing. Run it the same way you would run the command yourself in this agent/session (the invocation may differ from the literal `{command}` id shown above, e.g. a skills-mode agent runs it as `/skill:speckit-...` or `$speckit-...`). Emitting the block alone does not run the hook.
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Outline

1. **Setup**: Run `.specify/scripts/bash/setup-tasks.sh --json` from repo root and parse FEATURE_DIR, TASKS_TEMPLATE, and AVAILABLE_DOCS list. `FEATURE_DIR` and `TASKS_TEMPLATE` must be absolute paths when provided. `AVAILABLE_DOCS` is a list of document names/relative paths available under `FEATURE_DIR` (for example `research.md` or `contracts/`). For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (interface contracts), research.md (decisions), quickstart.md (test scenarios)
   - **IF EXISTS**: Load `.specify/memory/constitution.md` for project principles and governance constraints
   - Note: Not all projects have all documents. Generate tasks based on what's available.

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories
   - If contracts/ exists: Map interface contracts to user stories
   - If research.md exists: Extract decisions for setup tasks
   - Generate tasks organized by user story (see Task Generation Rules below)
   - Generate dependency graph showing user story completion order
   - Create parallel execution examples per user story
   - Validate task completeness (each user story has all needed tasks, independently testable)

4. **Generate tasks.md**: Read the tasks template from TASKS_TEMPLATE (from the JSON output above) and use it as structure. If TASKS_TEMPLATE is empty, fall back to `.specify/templates/tasks-template.md`. Fill with:
   - Correct feature name from plan.md
   - Phase 1: Setup tasks (project initialization)
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)
   - Phase 3+: One phase per user story (in priority order from spec.md)
   - Each phase includes: story goal, independent test criteria, implementation tasks
   - Final Phase: Polish & cross-cutting concerns
   - Every task follows the Task Format below: short title, then `Pronta quando`,
     `Descrição`, `Feita quando` and `Teste`
   - File paths and commands live in `Descrição`, never in the title
   - Dependencies section showing story completion order
   - Parallel execution examples per story
   - Implementation strategy section (MVP first, incremental delivery)

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_tasks`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_tasks` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue to the Completion Report.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing command invocations from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Mandatory hook** (`optional: false`) — **You MUST emit `EXECUTE_COMMAND:` for each mandatory hook**:
    ```
    ## Extension Hooks

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing. Run it the same way you would run the command yourself in this agent/session (the invocation may differ from the literal `{command}` id shown above, e.g. a skills-mode agent runs it as `/skill:speckit-...` or `$speckit-...`). Emitting the block alone does not run the hook.
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```

## Completion Report

Output path to generated tasks.md and summary:
- Total task count
- Task count per user story
- Parallel opportunities identified
- Independent test criteria for each story
- Suggested MVP scope (typically just User Story 1)
- Format validation: confirm EVERY task has a short title without commands, plus
  the four fields — `Pronta quando`, `Descrição`, `Feita quando`, `Teste`. Report
  any task missing one of them by ID; a task without a test is not ready to be
  handed to anyone

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Every task carries a test.** Not "tests are optional": a task whose completion
cannot be demonstrated is a task nobody can accept. See *Test* below for what
counts when the task produces no code.

### Task Format (REQUIRED)

A task is a **short title** plus four fields. The title says *what*; the fields
say when it can start, what to do, when it is finished, and how that is proven.

```text
- [ ] TID [P?] [US?] Short, direct title
  - **Pronta quando**: what must already be true for this task to start
  - **Descrição**: what to do — file paths, commands, and the requirement or
    contract that justifies it
  - **Feita quando**: observable conditions, each one checkable by someone else
  - **Teste**: the command or verification that demonstrates it
```

Field labels are written in the **project's language** — the example above and
those below use pt-BR because this project's artifacts are in pt-BR.

#### The title

**Short and direct. No commands, no file paths, no flags.** Those belong in
`Descrição`. A title is read in a list of seventy; it has to say what the task is
in a glance, and a title carrying `mix phx.new . --app the_band --no-mailer`
says nothing at a glance.

| ✅ | ❌ |
|---|---|
| `Gerar o projeto Phoenix` | `Rodar mix phx.new . --app the_band --module TheBand --database postgres` |
| `Cifrar a credencial em repouso` | `Implementar lib/the_band/vault.ex com Cloak.Vault e AES-GCM 256` |
| `Recusar o boot sem chave mestra` | `Fazer application.ex checar THE_BAND_MASTER_KEY antes do supervisor` |
| `Tela de pessoas com proveniência` | `LiveView /pessoas em lib/the_band_web/live/people_live/index.ex` |

Aim for **three to six words**, starting with a verb. If the title needs a comma
to stay honest, the task is probably two tasks.

#### Pronta quando — Definition of Ready

What must **already be true** before anyone starts. It exists to stop work that
will have to be redone.

Draw from what actually blocks:

- **the contract exists** — the constitution requires the API contract in
  `specs/<feature>/contracts/` before the first public function. For any task
  that adds public API, this is the first item;
- **the decision was taken** — a task that depends on an open question in
  `research.md` or an unresolved `[NEEDS CLARIFICATION]` is not ready;
- **the dependency is done** — name the task ID, not "the previous one";
- **the input exists** — fixture, migration, credential, seeded data.

`Pronta quando: nada além do repositório` is a legitimate answer for the first
tasks of the Setup phase. Write it rather than leaving the field empty.

#### Descrição — where the commands live

Everything the title deliberately left out: exact paths, exact commands, flags,
and the **requirement (FR/SC) or contract** that justifies the task.

This is also where a constraint that is easy to get wrong is stated — not as
trivia, but because someone will otherwise get it wrong. Example: "gravar o
checkpoint **depois** de processar a página, nunca antes".

#### Feita quando — Definition of Done

Observable conditions, in the **past tense of a fact**, each checkable by someone
who did not do the work.

The trap to avoid is restating the title. `Feita quando: o vault está
implementado` says nothing — it is the title with a verb changed.

| ✅ | ❌ |
|---|---|
| `a leitura direta da tabela devolve texto cifrado` | `a credencial está cifrada` |
| `a aplicação não sobe sem THE_BAND_MASTER_KEY, e a mensagem diz o que fazer` | `FR-005a implementado` |
| `a contagem do cabeçalho bate com a listagem sob qualquer filtro` | `a tela funciona` |

Two or three conditions is usually right. More than five means the task is too
big.

#### Teste — how it is proven

The command, the assertion, or the verification. **Every task has one**, and the
form follows what the task produces:

| Task produces | Test is |
|---|---|
| domain code | the test file and what it asserts |
| a screen | what has to be visible, and what must **not** be |
| a migration | the round trip: `mix ecto.migrate` then rollback |
| a connector | contract test with the HTTP edge mocked, using a captured payload |
| configuration or a quality gate | the command that fails when it is wrong |
| documentation or a contract | the artifact that reads it, or the review that compares it against the code |

Two rules about this field:

- **`mix test` alone is not a test.** It says the suite passed, not that *this*
  task works. Name the file, the case, or the assertion;
- **for anything with a security or semantic invariant, the test is the
  violation**, not the happy path. "The credential does not appear in the HTML"
  proves more than "the screen renders".

### Full example

```text
- [ ] T014 Cifrar a credencial em repouso
  - **Pronta quando**: o contrato em `contracts/credential-rotation.md` está
    escrito; T007 (configuração de runtime) concluída
  - **Descrição**: `lib/the_band/vault.ex` com `Cloak.Vault`, AES-GCM de 256
    bits e chave mestra vinda do ambiente. A cifragem acontece no `Ecto.Type`,
    nunca no código de aplicação — FR-005, research.md R3
  - **Feita quando**: a leitura direta de `tool_credentials` devolve texto
    cifrado; nenhum caminho da aplicação grava o segredo em claro
  - **Teste**: `test/the_band/vault_test.exs` — o valor cifrado não contém o
    texto claro, e decifrar devolve o original
```

### Format rules that still hold

1. **Checkbox**: always `- [ ]`
2. **Task ID**: `T001`, `T002`… sequential, in execution order
3. **[P] marker**: only when parallelizable — different files, no pending dependency
4. **[US] label**: required in user story phases, absent in Setup, Foundational and Polish

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Interfaces/UI needed for that story
     - The test of each task, in its own `Teste` field
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
   - Map each interface contract → to the user story it serves
   - The contract is a **Definition of Ready** item for every task that adds
     public API: it must exist before the task starts, per the constitution

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships → service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure → Setup phase (Phase 1)
   - Foundational/blocking tasks → Foundational phase (Phase 2)
   - Story-specific setup → within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Models → Services → Endpoints → Integration, each task
    carrying its own test in the `Teste` field
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns

## Done When

- [ ] tasks.md generated with all phases and task IDs
- [ ] every task has a short title, with no commands or paths in it
- [ ] every task has `Pronta quando`, `Descrição`, `Feita quando` and `Teste`
- [ ] no `Feita quando` merely restates its title, and no `Teste` is just `mix test`
- [ ] Extension hooks dispatched or skipped according to the rules in Mandatory Post-Execution Hooks above
- [ ] Completion reported to user with task count, story breakdown, and MVP scope
