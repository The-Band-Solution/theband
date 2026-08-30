# Tasks: O The Band em produção

**Input**: specs/050-em-producao/ — spec.md, plan.md, research.md,
contracts/pipeline-de-release.md, quickstart.md

**Tests**: cada tarefa carrega o seu; as violações primeiro (sem env, tag repetida).

**Nota de sprint**: o sprint 026 abre com a HERANÇA (#617 função-origem, #618 busca
da 051) antes destas — decisão da aceitação do 025.

## Phase 1: Setup

- [x] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch da feature nascida de `development` (Gitflow 1.7.0)
  - **Descrição**: `mix gates > /tmp/gates_050_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_050_baseline.log`, run TERMINADA antes de editar (L60)
  - **Feita quando**: `EXIT=0` na última linha, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_050_baseline.log` = `EXIT=0`

## Phase 2: Foundational

- [x] T002 A imagem, pela violação
  - **Pronta quando**: T001; contrato `pipeline-de-release.md` escrito (está)
  - **Descrição**: `Dockerfile` multi-stage (research R2 — mesma base glibc nos dois estágios, deps `--only prod`, `assets.deploy`, `mix release`, runtime não-root com `rel/entrypoint.sh` ADOTADO) + `.dockerignore`. Nenhum segredo em ARG/ENV
  - **Feita quando**: quickstart §1 e §2 passam — build limpo, recusa sem env NOMEANDO a variável, migração antes do endpoint, /sign-in 200
  - **Teste**: os dois logs do quickstart com EXIT esperados; `docker history` sem segredo

- [x] T003 O CI builda a imagem quando ela muda
  - **Pronta quando**: T002
  - **Descrição**: job condicional em `ci.yml` (paths: Dockerfile, .dockerignore, rel/**) que roda `docker build` — a imagem quebrada reprova o PR, não o deploy. Os 14 gates intocados
  - **Feita quando**: PR desta feature mostra o job verde; PR que não toca Docker não o roda
  - **Teste**: as duas execuções visíveis no CI do próprio PR

## Phase 3: US1 — A plataforma num endereço estável (P1)

- [x] T004 [US1] O workflow de CD conforme o contrato
  - **Pronta quando**: T003
  - **Descrição**: `.github/workflows/cd.yml` — push em `main`: versão do mix.exs (tag repetida FALHA nomeando — a violação), build, ghcr `vX.Y.Z`+`latest` com GITHUB_TOKEN, tag git anotada, webhook do Dokploy com `--fail` (`secrets.DOKPLOY_WEBHOOK_URL`), idempotente por versão. Cada passo ecoa veredito (L60)
  - **Feita quando**: o YAML valida (`act -n` ou actionlint); os cinco passos do contrato presentes com as falhas nomeadas
  - **Teste**: actionlint/dry-run verde; revisão contra a tabela do contrato linha a linha

- [x] T005 [US1] O runbook do Dokploy no Contabo
  - **Pronta quando**: T004
  - **Descrição**: `docs/producao/runbook.md` — §1 VPS+Dokploy (marco: pessoa mantenedora), §2 segredos (lista FECHADA do contrato; nunca no chat), §3 app por imagem ghcr com auto-deploy DESLIGADO + registry privado se for o caso, §4 Postgres+backup agendado, §5 rollback pela imagem anterior, §6 o primeiro release (PO, FR-016) com SC-001/002/004/005 medidos
  - **Feita quando**: cada seção executável por uma pessoa sem esta sessão aberta; os marcos com pessoas NOMEADOS como paradas
  - **Teste**: revisão cruzada contra contrato e quickstart §4–§5 — nenhum passo manual no caminho feliz além dos marcos

## Phase 4: US2 — Os dados sobrevivem (P2)

- [x] T006 [US2] O ensaio de restauração, escrito para ser executado
  - **Pronta quando**: T005
  - **Descrição**: seção do runbook + checklist de evidência (FR-008/SC-003): backup → restore em banco vazio → painéis conferidos contra números anotados ANTES. Executável no primeiro release, ANTES de dado real; falha da rotina de backup visível (FR-007)
  - **Feita quando**: o procedimento nomeia comandos, evidências e o critério de "bateu"
  - **Teste**: dry-run local: dump do Postgres de dev → restore em banco novo → subir o contêiner contra ele → /people confere

## Phase 5: Polish

- [ ] T007 Gates verdes e PR no padrão
  - **Pronta quando**: T001–T006
  - **Descrição**: `mix gates > /tmp/gates_050.log 2>&1; echo "EXIT=$?" >> /tmp/gates_050.log`; quickstart §1–§3 com evidências; PR para `development` no padrão 1.6.0, com revisor pedido ao abrir e no board
  - **Feita quando**: EXIT=0; evidências olhadas; PR aberto no padrão
  - **Teste**: `tail -1` do log; a seção Issues com resumo por tarefa

## Dependencies

```text
T001 → T002 → T003 → T004 → T005 → T006 → T007
```

MVP = T002–T004 (imagem + CD): com eles, o primeiro release fica a três marcos
humanos de distância. Sem [P]: cadeia estrita — cada peça consome a anterior.
