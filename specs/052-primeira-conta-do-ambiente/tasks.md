# Tasks: A primeira conta nasce do ambiente

**Input**: specs/052-primeira-conta-do-ambiente/ — spec.md, plan.md, research.md,
data-model.md, contracts/primeira-conta.md, quickstart.md

> **Issues criadas retroativamente em 2026-09-01** — #648 a #662, uma por tarefa,
> na ordem T001→#648 … T015→#662. O ciclo desta feature pulou o
> `/speckit-taskstoissues`, e as tarefas foram executadas sem issue; a lacuna e o
> que ela custou estão no [fechamento do sprint 026](../../docs/sprints/026-heranca-e-a-producao/aceitacao.md#lacunas-de-processo).
> As caixas abaixo foram marcadas na mesma data, contra o que o PR #640 entregou.

**Tests**: cada tarefa carrega o seu; as violações primeiro (senha curta, variável
ausente, admin já existente).

**Nota de desenho**: **nenhuma migração**. A garantia do FR-005 já está nos índices
únicos de `tenants.slug` e `users.email` (research R1). Se durante a implementação
alguém sentir necessidade de `mix ecto.gen.migration`, o desenho mudou e o plano
precisa ser revisto antes do código.

## Phase 1: Setup

- [x] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch nascida de `development`
  - **Descrição**: `mix gates > /tmp/gates_052_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_052_baseline.log`, run TERMINADA antes de editar. O veredito é o código de saída, e nada roda depois dele (L60)
  - **Feita quando**: `EXIT=0` na última linha, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_052_baseline.log` = `EXIT=0`

## Phase 2: Foundational

- [x] T002 O contrato lido, e a ausência de migração confirmada
  - **Pronta quando**: T001
  - **Descrição**: conferir contra o código que os três changesets que o contrato reaproveita existem e validam o que ele afirma — `Tenant.changeset/2` (slug `^[a-z0-9-]+$`, único), `User.changeset/2` (e-mail obrigatório e único, papel entre os conhecidos), `User.senha_changeset/3` (mínimo 12, hash dentro do changeset). Conferir também que `unique_index(:tenants, [:slug])` e `unique_index(:users, [:email])` estão no esquema — é neles que o FR-005 se apoia
  - **Feita quando**: as cinco afirmações do contrato conferidas uma a uma contra o código; qualquer divergência corrigida NO CONTRATO, no mesmo commit, com a razão escrita
  - **Teste**: `grep -n "unique_index(:tenants, \[:slug\])\|unique_index(:users, \[:email\])" priv/repo/migrations/20260809120000_create_tenants_and_users.exs` devolve as duas linhas; e a revisão do contrato linha a linha contra `lib/the_band/tenants/user.ex` e `tenant.ex`

## Phase 3: US1 — Instalar sem console (P1)

**Objetivo**: quatro variáveis no painel, implantar, entrar. Nenhum console.

**Teste independente**: subir contra um banco vazio com as quatro variáveis e
entrar pela tela de entrada com aquelas credenciais.

- [x] T003 [US1] A violação: a senha não pode vazar
  - **Pronta quando**: T002
  - **Descrição**: `test/the_band/tenants/bootstrap_test.exs` — escrever PRIMEIRO os casos que provam o FR-006: nem o retorno `:criada` nem o changeset de erro carregam a senha. O teste falha agora, porque o módulo não existe; é o ponto (L77 — verificador novo nasce com teste que NÃO passa por ele)
  - **Feita quando**: os dois casos existem e falham por ausência do módulo, não por erro de sintaxe
  - **Teste**: `mix test test/the_band/tenants/bootstrap_test.exs` reprova nomeando `TheBand.Tenants.Bootstrap` como indefinido
- [x] T004 [US1] Criar a primeira conta a partir do ambiente
  - **Pronta quando**: T003; contrato `contracts/primeira-conta.md` escrito (está)
  - **Descrição**: `lib/the_band/tenants/bootstrap.ex` com `criar_primeira_conta(ambiente \\ &System.get_env/1)`. Lê as quatro variáveis da lista FECHADA, cria organização e conta NUMA TRANSAÇÃO (FR-004), com `role: "admin"`, e devolve `{:ok, :criada, %{email:, slug:}}` — **sem a senha**. O parâmetro `ambiente` existe para o teste injetar sem `System.put_env/2`, que vaza entre testes assíncronos
  - **Feita quando**: T003 passa; uma organização e uma conta com marca de administração existem depois da chamada contra banco vazio; a senha não aparece em nenhum campo do retorno
  - **Teste**: `test/the_band/tenants/bootstrap_test.exs` — "cria quando não há admin" e os dois de vazamento do T003
- [x] T005 [US1] O release semeia, e o entrypoint chama
  - **Pronta quando**: T004
  - **Descrição**: `TheBand.Release.semear_primeira_conta/0` em `lib/the_band/release.ex`, usando `Ecto.Migrator.with_repo/2` como `migrate/0` já faz — sobe o repositório sem a árvore de supervisão, para os coletores não começarem a puxar trabalho. Traduz o relator nas quatro frases do contrato e imprime. Uma linha em `rel/entrypoint.sh`, DEPOIS de `Release.migrate()`. **Nunca sai diferente de zero** — o `set -e` derrubaria o contêiner, e a ausência das variáveis é caso previsto (FR-007)
  - **Feita quando**: o quickstart §2 passa — `migrações aplicadas.` seguido de `primeira conta criada: <email>, admin de <slug>.`; a senha não aparece no log
  - **Teste**: quickstart §2 executado, com `docker compose --profile producao logs app | grep -c "$THE_BAND_ADMIN_SENHA"` devolvendo **0** (SC-003)
- [x] T006 [US1] Entrar com a conta recém-criada
  - **Pronta quando**: T005
  - **Descrição**: percorrer o quickstart §3 — abrir a tela de entrada e autenticar com o e-mail e a senha das variáveis. Nenhum código novo; é a prova de que a conta criada serve para o que existe (SC-001)
  - **Feita quando**: a sessão abre e a pessoa vê a plataforma com poder de administração
  - **Teste**: `curl -s -o /dev/null -w "%{http_code}" localhost:4001/sign-in` = 200, e a entrada real no navegador com captura de tela do painel já autenticado

## Phase 4: US2 — Reiniciar não duplica nem sobrescreve (P1)

**Objetivo**: a criação roda em todo boot e não faz nada quando já foi feita.

**Teste independente**: subir duas vezes com as mesmas variáveis e conferir que a
segunda não altera conta alguma.

- [x] T007 [US2] A violação: a senha trocada não pode voltar
  - **Pronta quando**: T004
  - **Descrição**: em `bootstrap_test.exs`, o caso que separa esta feature de um defeito — criar, trocar a senha pelo caminho que já existe, chamar `criar_primeira_conta` cinco vezes com a variável no valor ANTIGO, e afirmar que a senha trocada continua valendo. Provar com `Auth`, comparando o hash em vigor, e não por ausência de erro (SC-005)
  - **Feita quando**: o caso existe e reprova se a criação deixar de checar a existência antes de escrever
  - **Teste**: `test/the_band/tenants/bootstrap_test.exs` — "senha trocada sobrevive a cinco subidas"
- [x] T008 [US2] Não criar quando já existe administrador
  - **Pronta quando**: T007
  - **Descrição**: em `bootstrap.ex`, a consulta de existência ANTES de ler o ambiente e de abrir transação — no caminho comum a função faz uma consulta e para. A pergunta é "existe alguma pessoa com marca de administração", nunca "existe este e-mail" (FR-002)
  - **Feita quando**: T007 passa; com admin existente, devolve `:ja_existe` e a contagem de contas não muda; um e-mail DIFERENTE nas variáveis também devolve `:ja_existe`
  - **Teste**: os três casos em `bootstrap_test.exs` — "não cria quando há admin", "e-mail diferente não cria segundo", "senha trocada sobrevive"
- [x] T009 [US2] A corrida não produz dois administradores
  - **Pronta quando**: T008
  - **Descrição**: o teste de duas chamadas concorrentes (`Task.async` x2 contra o mesmo banco), afirmando UM administrador ao fim. A violação de unicidade que o perdedor recebe é lida como `:ja_existe`, e não como erro — research R1. **Nenhum lock novo**: a garantia é dos índices que já existem
  - **Feita quando**: o teste passa; existe exatamente uma conta com marca de administração; o retorno do perdedor é `:ja_existe`
  - **Teste**: `test/the_band/tenants/bootstrap_test.exs` — "duas chamadas concorrentes produzem um admin"

## Phase 5: US3 — A ausência é dita, e não derruba (P2)

**Objetivo**: variável faltando ou recusada não impede a plataforma de subir, e o
log nomeia o que houve.

**Teste independente**: subir contra banco vazio sem nenhuma variável e conferir
que a plataforma atende requisições.

- [x] T010 [US3] Nomear todas as variáveis ausentes
  - **Pronta quando**: T008
  - **Descrição**: em `bootstrap.ex`, `{:error, {:faltando, [atom]}}` com a lista COMPLETA — não o primeiro que faltou. Quem esqueceu duas variáveis descobre as duas numa subida, e não em duas. `THE_BAND_ADMIN_NOME` é opcional (contrato) e não entra na lista
  - **Feita quando**: faltando duas variáveis, a lista traz as duas; nada é criado — nem organização sozinha, nem conta sem organização
  - **Teste**: `bootstrap_test.exs` — "ausência nomeia todas", e o caso que afirma zero organizações depois de uma falta parcial
- [x] T011 [US3] A recusa vem dos changesets que já existem
  - **Pronta quando**: T010
  - **Descrição**: valor presente mas inválido devolve `{:error, %Ecto.Changeset{}}` vindo de `Tenant.changeset/2` ou `User.senha_changeset/3` — nenhuma validação nova (research R5, FR-008). Limpar o campo virtual de senha do changeset devolvido, para que o erro não carregue o segredo
  - **Feita quando**: senha de 11 caracteres é recusada pelo `senha_changeset`; slug com espaço é recusado pelo `Tenant.changeset`; nada é criado nos dois casos; nenhum dos changesets carrega a senha
  - **Teste**: `bootstrap_test.exs` — "recusa vem do changeset existente" usando 11 caracteres, valor que SÓ aquele changeset recusa; se uma cópia da validação existisse, o número passaria
- [x] T012 [US3] A plataforma sobe sem as variáveis
  - **Pronta quando**: T011; T005
  - **Descrição**: percorrer o quickstart §5 e §6 — sem nenhuma variável, e com valores inválidos. O `semear_primeira_conta/0` imprime e sai zero nos dois casos; o endpoint sobe (FR-007)
  - **Feita quando**: nos dois percursos o log NOMEIA o que houve e `/sign-in` responde 200, sem conta alguma
  - **Teste**: quickstart §5 e §6 com as saídas coladas na evidência, e `curl -s -o /dev/null -w "%{http_code}" localhost:4001/sign-in` = 200 em ambos
- [x] T013 [US3] Organização existente é reaproveitada
  - **Pronta quando**: T011
  - **Descrição**: banco restaurado pode ter organizações e nenhum administrador. Slug já presente: a conta nasce DENTRO da organização existente, sem tentar criar uma segunda (FR-011). Sem isto, uma instalação restaurada ficaria sem caminho de entrada — o problema que a feature existe para eliminar
  - **Feita quando**: com a organização já criada e nenhum admin, a chamada devolve `:criada` e existe UMA organização ao fim
  - **Teste**: `bootstrap_test.exs` — "organização existente é reaproveitada", contando organizações antes e depois

## Phase 6: Polish

- [x] T014 O runbook ganha a primeira conta
  - **Pronta quando**: T012
  - **Descrição**: `docs/producao/runbook.md` §8 — as quatro variáveis, onde defini-las, o que o log diz em cada um dos quatro casos, e a recomendação de REMOVER o valor da senha do painel depois do primeiro acesso (FR-012). Dizer também o custo aceito: enquanto a variável existir, a senha é legível por quem tem acesso ao painel
  - **Feita quando**: a seção é executável por uma pessoa sem esta sessão aberta; o custo está dito no lugar onde alguém vai ler, e não escondido
  - **Teste**: revisão cruzada contra o contrato e o quickstart §7 — nenhum passo do caminho feliz exige console
- [x] T015 Gates verdes e PR no padrão
  - **Pronta quando**: T001–T014
  - **Descrição**: `mix gates > /tmp/gates_052.log 2>&1; echo "EXIT=$?" >> /tmp/gates_052.log`; quickstart §1–§6 com evidências; PR para `development` no padrão 1.6.0, com a seção Issues trazendo resumo por tarefa
  - **Feita quando**: EXIT=0; as evidências do quickstart olhadas uma a uma; PR aberto com revisor pedido
  - **Teste**: `tail -1 /tmp/gates_052.log` = `EXIT=0`, e a seção Issues do PR com resumo por tarefa, não lista de números

## Dependencies

```text
T001 → T002 → T003 → T004 ─┬─ T005 → T006          (US1, o MVP)
                           ├─ T007 → T008 → T009   (US2)
                           └─ T010 → T011 → T013   (US3)
                                       ↓
                              T012 (precisa de T005)
                                       ↓
                                T014 → T015
```

**MVP = T001–T006.** Com eles, uma instalação nova é acessível sem console — que
é a feature inteira do ponto de vista de quem instala.

A US2 é P1 junto com a US1, e não P2, por um motivo que vale repetir aqui: a
criação roda em **todo** boot. Sem T007–T009, a US1 entrega um defeito pior que o
problema que resolve — a senha do painel voltando a valer depois de a pessoa ter
trocado pela interface.

## Paralelismo

Depois de T004, os três ramos são independentes: T005/T006 tocam `release.ex` e
`entrypoint.sh`; T007–T009 e T010–T013 tocam `bootstrap.ex` e o teste. Os dois
últimos ramos escrevem no mesmo arquivo — **não** são `[P]` entre si.

T005 e T007 podem correr em paralelo. É o único par com `[P]` legítimo, e por
isso nenhuma tarefa acima leva a marca: marcar paralelismo que não existe faz
alguém tentar e descobrir o conflito no meio.
