# Feature 032 — Tarefas

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md)

## Phase 1: Nota (F1–F2)

- [x] T001 Migração das quatro tabelas + `changes_collected_at` per plan F1
- [x] T002 Quatro schemas Ecto, com `commit_authors` em tabela (cardinalidade `many`) per FR-004
- [x] T003 Consulta `change_requests.graphql` — PRs com commits aninhados, dois `totalCount` per FR-001
- [x] T004 Ingestão incremental parando cedo (a origem não filtra por data) per FR-001
- [x] T005 Fase na MESMA sincronização, depois das issues per FR-010
- [x] T006 Coleta real: 5.032 solicitações, 16.416 commits, 1.078 vínculos, 23min per SC-001
- [x] T006a Paginação dos commits além da primeira página — "não coletado" era limitação
  nossa, não da origem

## Phase 2: Música (F3)

- [x] T007 `Changes` — for_issue, get, commits_of, attended_issues, by_person per SC-003

## Phase 3: Telas (F4–F6)

- [x] T008 Seção "Change requests" no detalhe da issue, com os dois vazios distintos per FR-006
- [x] T009 Tela `/work/changes/:id` com commits, autores e issues atendidas per FR-008
- [x] T010 Seção "Changes" na pessoa — três leituras nunca somadas per FR-007
- [x] T011 Verificação ao vivo do rastreio completo per SC-002

## Phase 4: Pendente — a lista e a busca (proposta aprovada em 2026-08-18)

- [ ] T012 `/work/changes` — a lista de solicitações, com filtros
- [ ] T013 A busca que lê a forma do que foi digitado (SHA, #número, @pessoa, texto) —
  e **palavras-chave** livres, casando em título de solicitação, mensagem de commit e
  nome de branch. Várias palavras estreitam (E, nunca OU): "rastreio commit" acha o que
  tem as duas, porque quem digita duas palavras está estreitando, não alargando.
- [ ] T014 `/people/:id/commits` — a lista de commits da pessoa
- [ ] T015 A linha do tempo issue → solicitação → commits

## Phase 5: Os arquivos que a mudança tocou (pedido em 2026-08-18)

- [ ] T016 Coletar os arquivos modificados por commit — é `cmpo.artifact_copy`, que a CMPO
  já tem: "cópia de um artefato sob controle de versão". A relação
  `cmpo.commit_sends_copy_to_target_branch` também já existe e hoje aponta para o alvo sem
  a cópia; com isto ela fecha.
  **O que decidir antes**: o `files` do GraphQL é paginado por commit, e são 16.416 commits
  — medir o custo antes de coletar tudo, e considerar coletar só dos commits de PRs com
  vínculo a issue (1.078), que é onde o rastreio consome.
- [ ] T017 Mapeamento `github.commit_file.to.cmpo.artifact_copy`, com a limitação do
  diff (a plataforma guarda QUE arquivo mudou, nunca o conteúdo)
- [ ] T018 Os arquivos na tela do commit e da solicitação — e a pergunta que eles
  destravam: "quem mexeu neste arquivo, e por qual issue"
