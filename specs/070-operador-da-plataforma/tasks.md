---
description: "Tarefas da 070 — o operador da plataforma: suspender e reativar uma organização"
---

# Tasks: o operador da plataforma — suspender e reativar uma organização

**Input**: `specs/070-operador-da-plataforma/` — [spec.md](spec.md), [plan.md](plan.md),
[research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/),
[quickstart.md](quickstart.md), [seguranca.md](seguranca.md),
[seguranca-autenticacao.md](seguranca-autenticacao.md)

**Gerado em**: 2026-10-01, pelo `/speckit-tasks`. Não há `.specify/extensions.yml`: nenhum hook.

**Testes**: cada tarefa carrega o seu, no campo `Teste`. Não há tarefa sem forma de demonstrar que
ficou pronta.

**Organização**: por user story. A **US2 vem antes da US1**, embora as duas sejam P1: a spec diz que
a US2 "é o pré-requisito da US1" — não há quem suspenda sem o papel, a entrada e a sessão do
operador. A US1 continua sendo o defeito #1009 e o motivo da feature.

## Formato

```text
- [ ] TID [P?] [US?] Título curto e direto
  - **Pronta quando**: o que precisa já ser verdade para a tarefa começar
  - **Descrição**: o que fazer — caminhos, comandos, e o requisito (FR/SC) ou contrato
  - **Feita quando**: condições observáveis, cada uma conferível por outra pessoa
  - **Teste**: o comando ou a verificação que demonstra
```

- **[P]**: pode rodar em paralelo — arquivo distinto, sem dependência pendente
- **[US1] / [US2]**: a user story que a tarefa atende

## Regras que valem para toda tarefa desta lista

1. **Guarda de segurança nasce provada** (CLAUDE.md, AGENTS.md §14.0). Toda tarefa cujo `Teste`
   diz "defeito a injetar" só fecha com um comentário na issue contendo: o defeito injetado, o
   comando, o código de saída **reprovando**, e o código de saída **aprovando** depois de desfazer.
   Antes de injetar, **copiar o arquivo** para o scratchpad (`git checkout` apaga trabalho não
   commitado; memória da casa). Se a reinjeção **não** reproduz o defeito, o errado é a hipótese, e
   não o teste (lição L105): a tarefa volta para investigação, e não se ajusta o teste até passar.
2. **O veredito é o código de saída** (AGENTS.md §4): `mix test <arquivo> > /tmp/t.log 2>&1; echo
   "EXIT=$?"`, e nunca `| tail`.
3. **Teste de concorrência conta os dois lados da corrida** (lição L90): quem ganhou **e** quem
   perdeu, com o motivo de cada um. Teste de telemetria filtra pelo processo e desanexa o handler
   antes de afirmar (L42), e prova que mediu alguma coisa (L50).
4. **Tarefa fechada sem o critério como escrito não fecha** (L109): ou a spec é emendada no mesmo PR,
   ou a issue fica aberta como não concluída, com o motivo.
5. **Contrato antes do código** (AGENTS.md §12): toda tarefa que cria função pública tem o contrato
   em `contracts/` como primeiro item de `Pronta quando`. Se a implementação mostrar que ele errou,
   o contrato é corrigido **no mesmo commit**.
6. **Nenhum segredo real em fixture**: senha, código e segredo TOTP de teste são strings óbvias.

---

## Fase 1: Pré-requisitos e decisões (fora da feature)

**Propósito**: o que precisa ser verdade antes de qualquer linha em `lib/` ou `test/`. Nenhuma
destas tarefas escreve código da 070.

- [ ] T001 Conferir os pré-requisitos já mergeados
  - **Pronta quando**: nada além do repositório
  - **Descrição**: confirmar, com `gh pr view <n> --json state,mergedAt,baseRefName`, que os PRs
    **#1038** (#1033, `Tenants.ensure_active/1`, FR-012), **#1039** (#1034, `Access.operacional?/2`
    compara o tenant, O5), **#1040** (#1035, `ApiTokens.criar/4` confere o dono, O15) e **#1044**
    (#1042, `Sessions.avisar_encerramento/1`, pré-requisito da A2) estão mergeados em
    `development`. Em 2026-10-01 os quatro deram `MERGED`; a tarefa reconfere no dia em que a
    implementação começar, e confere no código de `origin/development` que existem
    `Tenants.ensure_active/1` e `Sessions.avisar_encerramento({:sessao, id})`
  - **Feita quando**: os quatro estão `MERGED` com `baseRefName = development`; as duas funções
    aparecem em `git grep` sobre `origin/development`; o resultado está colado na issue
  - **Teste**: `git grep -n "def ensure_active\|def avisar_encerramento" origin/development -- lib/`
    devolve as duas definições

- [ ] T002 Esperar o merge da correção da espera paralela
  - **Pronta quando**: nada além do repositório
  - **Descrição**: o PR **#1048** (issue #1046, achado **A1** nas contas de organização) precisa
    estar mergeado em `development`. `Platform.Credentials` **copia** a política de
    `Tenants.Auth` (research R2), e a cópia tem de nascer da forma corrigida — `FOR UPDATE` ou
    incremento atômico com `RETURNING`, a que o #1048 escolher. Em 2026-10-01 o PR está **aberto**
  - **Feita quando**: `gh pr view 1048` dá `MERGED`; a forma escolhida pela #1048 está escrita em
    uma linha no comentário da issue desta tarefa, para T023 copiar
  - **Teste**: `gh pr view 1048 --json state,mergedAt` com `state = MERGED`

- [ ] T003 Esperar o merge da correção do custo na espera
  - **Pronta quando**: nada além do repositório
  - **Descrição**: a issue **#1047** (achado **A3** nas contas de organização: a espera responde sem
    custo de hash e revela se o e-mail existe) precisa de PR aberto e mergeado em `development`.
    Em 2026-10-01 existe a branch `fix/1047-espera-paga-o-hash` e **nenhum PR**. Mesma razão de
    T002: a cópia nasce corrigida
  - **Feita quando**: o PR da #1047 está `MERGED` em `development`; o número dele está registrado
    nesta tarefa e em `plan.md`, "Pré-requisitos"
  - **Teste**: `gh pr list --head fix/1047-espera-paga-o-hash --state merged` devolve um PR

- [ ] T004 Medir o cabeçalho de IP no proxy de produção
  - **Pronta quando**: acesso ao servidor do Dokploy. **Dono: a pessoa mantenedora** (decisão 2 de
    `seguranca-autenticacao.md`); o agente não tem nem pede esse acesso
  - **Descrição**: confirmar em produção se o Traefik do Dokploy **sobrescreve** `x-forwarded-for`
    ou **acrescenta** ao valor que o cliente mandou. Forma sugerida: uma requisição com
    `X-Forwarded-For: 203.0.113.7` forjado, e ler o que chega à aplicação (log de acesso do
    Traefik ou um endpoint temporário fora do repositório). Achado **A4**. Sem esta medição, o
    limite por IP (T043) **não entra**, e fica só a espera por conta da #1046
  - **Feita quando**: o resultado ("sobrescreve" ou "acrescenta"), a data e o método estão
    registrados em `docs/seguranca/` ou num comentário da issue, sem nenhum segredo
  - **Teste**: o registro existe e diz qual dos dois; T043 lê esse registro como `Pronta quando`

- [ ] T005 Decidir a forma da área do operador
  - **Pronta quando**: nada além do repositório. **Dono: a pessoa mantenedora** (plan.md, pergunta 1)
  - **Descrição**: escolher entre **(a)** controllers com cookie próprio `_the_band_operator` e
    **(b)** `live_session` com chaves dentro do cookie de domínio (research R3.2). A avaliação de
    segurança e o plano recomendam (a). Se (a), emendar a FR-011 em `spec.md` trocando
    "`live_session`" por "pipeline, plug e cookie próprios". Se (b), `contracts/rotas-da-plataforma.md`
    e `contracts/sessao-do-operador.md` são reescritos **antes** de T035
  - **Feita quando**: a decisão está registrada em `plan.md`, pergunta 1, com data e quem decidiu;
    a FR-011 e os contratos dizem a mesma coisa
  - **Teste**: `grep -n "live_session" spec.md contracts/*.md` não contradiz a decisão escrita

- [ ] T006 Abrir o sprint backlog e as issues
  - **Pronta quando**: este `tasks.md` revisado pelo `/speckit-analyze` sem divergência aberta
  - **Descrição**: `/speckit-taskstoissues` (prefixo `070/TNNN`, tipo `task`, labels `security`
    onde couber) e a skill `sprint-backlog`, que lê `docs/sprints/licoes-aprendidas.md` — lições
    abertas que se aplicam aqui: L42, L50, L56, L90, L105, L108, L109. Lição L108: tarefa sem issue
    não entra em backlog
  - **Feita quando**: cada tarefa desta lista tem issue com o tipo e o prefixo; o sprint tem
    `sprint-backlog.md` com as lições aplicáveis listadas como restrição
  - **Teste**: `gh issue list --search "070/T" --state open` conta o mesmo número de tarefas abertas
    deste arquivo

- [ ] T007 Rebasear o trabalho sobre a integração
  - **Pronta quando**: T001, T002 e T003 concluídas
  - **Descrição**: rebasear `070-operador-da-plataforma` sobre `origin/development`, para que as
    migrações da 070 nasçam com timestamp posterior a qualquer migração já mergeada (research R11,
    a #879) e para que `lib/the_band/tenants/auth.ex` já traga as correções da #1046 e da #1047
  - **Feita quando**: `git log origin/development..HEAD` lista só commits da 070; `auth.ex` local
    contém a forma corrigida
  - **Teste**: `git merge-base --is-ancestor origin/development HEAD; echo $?` devolve `0`

---

## Fase 2: Fundação (bloqueia as duas user stories)

**Propósito**: as avaliações que ainda faltam, o protótipo, e o que as duas histórias usam.

**⚠️ Nenhuma tarefa das Fases 3 e 4 começa antes de T008, T010 e T011.** Nenhum controller ou
template começa antes de T012.

- [ ] T008 Conferir as emendas de segurança nos contratos
  - **Pronta quando**: as emendas de 2026-10-01 nos contratos, no `data-model.md` e no
    `research.md` estão commitadas
  - **Descrição**: o agente `security`, **que não escreveu as emendas**, compara
    `seguranca-autenticacao.md` §4 com o que entrou: A1 e A3 e A5 e A10 e A14 em
    `contracts/credenciais-do-operador.md`; A6, A13c, A14 e A15 em
    `contracts/concessao-do-operador.md`; A2 e A15 em `contracts/suspensao.md` e
    `contracts/sessoes-e-tokens-da-organizacao.md`; A7 em `contracts/eventos-de-acesso.md`; A8 e
    A12 em `contracts/rotas-da-plataforma.md`; A11 em `contracts/sessao-do-operador.md`; A9 em
    research R10; A11 e A13 em `data-model.md`
  - **Feita quando**: `seguranca-autenticacao.md` ganha a seção "Conferência das emendas", com um
    veredito por achado (`coberto` ou `falta`, e o quê); todo `falta` de A1, A2, A3, A5, A6 ou A9
    está corrigido no contrato antes de a tarefa fechar
  - **Teste**: a seção existe, lista os dezessete achados, e nenhum dos seis bloqueantes está como
    `falta`

- [ ] T009 Pesquisar a implementação do TOTP
  - **Pronta quando**: `contracts/segundo-fator-do-operador.md` e research R13 escritos (feito em
    2026-10-01)
  - **Descrição**: comparar **NimbleTOTP** e **RFC 6238 sobre `:crypto`** (`:crypto.mac(:hmac,
    :sha, …)`), pela tabela de research R13: versão, manutenção, licença, dependências
    transitivas, `mix hex.audit` e `mix deps.audit` com a dependência num branch de rascunho, se a
    janela e o reuso ficam com o chamador, e o custo de manter código criptográfico próprio.
    Decidir também se a tela leva QR code (só se o protótipo T012 o exigir). FR-016; AGENTS.md §3
    ("toda dependência nova precisa de justificativa escrita no plano")
  - **Feita quando**: `plan.md`, "Technical Context", troca "a decidir" pela escolha, com a versão
    exata, a justificativa e o que fica pior; se a escolha for dependência, a versão está fixada na
    tarefa T022
  - **Teste**: a revisão do `plan.md` por quem não fez a pesquisa encontra as três respostas
    (problema, agora ou previsão, o que piora; AGENTS.md §7.7) e a saída de `mix hex.audit` citada

- [ ] T010 Avaliar a segurança do TOTP antes do código
  - **Pronta quando**: T009 concluída
  - **Descrição**: avaliação do agente `security`, **feita por quem não escreveu o desenho** do
    TOTP, em `specs/070-operador-da-plataforma/seguranca-totp.md`. Cobrir no mínimo: o segredo em
    repouso (Cloak) e por onde ele passa em claro; o cadastro em dois passos e o código de
    cadastro no campo oculto; a janela de ±1 e o reuso (`totp_last_used_step` sob `FOR UPDATE`);
    os códigos de recuperação (80 bits, `sha256`, consumo atômico); a falha do segundo fator no
    mesmo contador da senha; o abandono entre os dois passos; o reinício e a nova concessão (A6);
    a biblioteca escolhida em T009; e os cenários de ataque para o QA. FR-016, A16
  - **Feita quando**: o arquivo existe com achados, severidade e veredito; cada achado alto ou
    crítico virou tarefa **bloqueante** nesta lista (acrescentada por `/speckit-converge` ou à mão),
    citada no `Pronta quando` das tarefas que dependem dele
  - **Teste**: `seguranca-totp.md` existe, diz quem avaliou e que não é quem desenhou, e o
    `/speckit-analyze` não acha achado alto sem tarefa

- [ ] T011 Emendar os contratos com o resultado do TOTP
  - **Pronta quando**: T009 e T010 concluídas
  - **Descrição**: aplicar a escolha da biblioteca e as emendas de `seguranca-totp.md` a
    `contracts/segundo-fator-do-operador.md`, `contracts/credenciais-do-operador.md`,
    `contracts/rotas-da-plataforma.md`, `contracts/eventos-de-acesso.md` e `data-model.md` §1 e
    §1a, **antes** de qualquer código. Se a avaliação não pedir emenda, registrar isso
  - **Feita quando**: os contratos não dizem mais "a decidir" sobre a biblioteca; cada emenda de
    `seguranca-totp.md` aponta o trecho de contrato que a cobre
  - **Teste**: `grep -n "a decidir\|NimbleTOTP, ou" contracts/ plan.md` só encontra a decisão
    tomada; o agente `security` confere as emendas, como em T008

- [ ] T012 Prototipar as telas do operador
  - **Pronta quando**: T005 decidida (controller ou `live_session` muda o que a tela pode fazer);
    T009 decidiu se há QR
  - **Descrição**: o agente **Design** desenha, **antes** de qualquer controller ou template, as
    cinco telas que o plano fixa: entrada com segundo fator; definição de senha; cadastro do segundo
    fator com o segredo e os códigos de recuperação mostrados **uma vez**; lista de organizações
    (nome, slug, estado, data do último episódio, e "nunca suspensa" com `<.absent>`, FR-007);
    histórico com o ato (razões vindas da base, nota, recusa como estado). Interface em inglês;
    design system de `docs/design-system.md`. Protótipo publicado e guardado em
    `specs/070-operador-da-plataforma/prototipo/`, com `PROMPT.md` e as decisões da pessoa
    mantenedora. **Bloqueante** de T039, T040 e T056
  - **Feita quando**: o protótipo está publicado e guardado na spec; a pessoa mantenedora o
    aprovou, com data registrada no `PROMPT.md`; o Product Owner registrou o link no backlog
  - **Teste**: o QA consegue ler o `PROMPT.md` §3 item a item contra cada tela; nenhuma tela mostra
    dado de domínio (pessoas, equipes, issues, contagens)

- [ ] T013 [P] Restringir o estado da organização
  - **Pronta quando**: T007 concluída; `contracts/sessoes-e-tokens-da-organizacao.md`, seção
    `TheBand.Tenants.Tenant`
  - **Descrição**: migração `priv/repo/migrations/<ts>_estado_da_organizacao_valido.exs` com
    `CHECK (status IN ('active','suspended'))` de nome `tenants_status_valido`; o `up` **conta** os
    valores fora da lista e **levanta** com a contagem (nunca mapeia); `down` explícito.
    `lib/the_band/tenants/tenant.ex`: `:status` sai do `cast`, entra `validate_inclusion/3` e
    `check_constraint/3`. Ajustar `test/the_band/tenants/organizacao_suspensa_test.exs:44`, que
    suspende pelo changeset, para escrever o estado por `update_all` com comentário dizendo por quê
    (research R6). O10. O episódio `not_recorded` para as já suspensas fica em T044, que cria a
    tabela
  - **Feita quando**: `Tenant.changeset(t, %{status: "suspended"})` não muda o estado; um `UPDATE`
    com `'Suspended'` reprova no banco; a migração com uma linha `status = 'x'` levanta dizendo
    quantas
  - **Teste**: `test/the_band/tenants/estado_da_organizacao_test.exs` — os três casos, e `mix
    ecto.migrate` seguido de `mix ecto.rollback --step 1` sem erro. **Defeito a injetar**: devolver
    `:status` ao `cast`; o primeiro caso precisa reprovar

- [ ] T014 [P] Declarar as razões de suspensão na base
  - **Pronta quando**: T007 concluída; `data-model.md` §5 (lista **proposta**)
  - **Descrição**: `priv/knowledge_base/rules/platform_tenant_suspension.yaml`, `derivation_rule:`
    de id `platform.tenant_suspension`, `provenance.source_type: project_decision`, na forma de
    `priv/knowledge_base/rules/access_account_lifecycle.yaml` (`suspend_reasons`,
    `reactivate_reasons`, `recorded_only: [not_recorded]`, `offered_only_against`, `note_required`).
    A lista passa pela revisão semântica e pela pessoa mantenedora no PR (FR-003)
  - **Feita quando**: `mix knowledge.validate` aceita o arquivo; a revisão semântica está registrada
    no PR; nenhum código de razão está fora do arquivo
  - **Teste**: `mix knowledge.validate > /tmp/kv.log 2>&1; echo "EXIT=$?"` dá `0`; com o `id`
    duplicado de propósito, dá diferente de zero

- [ ] T015 [P] Declarar a cláusula de revogação só registrada
  - **Pronta quando**: T007 concluída; `data-model.md` §6, `api_access_tokens`
  - **Descrição**: `priv/knowledge_base/rules/api_access_thresholds.yaml` ganha
    `clausulas_so_registradas: [organizacao_suspensa]` com rótulo pt-BR e en. FR-013
  - **Feita quando**: a chave existe; `ApiTokens.clausulas_de_revogacao/0` continua devolvendo só as
    oferecidas (afirmado em T047)
  - **Teste**: `mix knowledge.validate` dá `0`, e o teste de T047 lê a chave

- [ ] T016 [P] Ensinar o log a dizer o operador e a calar o segredo
  - **Pronta quando**: T007 concluída; `contracts/eventos-de-acesso.md`;
    `contracts/credenciais-do-operador.md` (A10)
  - **Descrição**: `config/config.exs`: `:operator_id` na lista de metadados do formatador (O14,
    research R12) e `config :phoenix, :filter_parameters` com os padrões atuais mais `"code"`,
    `"secret"` e `"totp"` (A10)
  - **Feita quando**: uma linha de log com `Logger.metadata(operator_id: "x")` imprime o campo; um
    parâmetro `code` sai `[FILTERED]`
  - **Teste**: `test/the_band/platform/log_do_operador_test.exs` — `Phoenix.Logger.filter_values/1`
    sobre `%{"setup_token" => "x", "second_factor_token" => "y", "code" => "z"}` devolve os três
    filtrados (cenário 9 de `seguranca-autenticacao.md`). **Defeito a injetar**: retirar `"code"`
    da lista; o terceiro precisa vazar e o teste reprovar

- [ ] T017 [P] Compartilhar a CSP entre as duas pipelines
  - **Pronta quando**: T007 concluída; `contracts/rotas-da-plataforma.md`, "A pipeline"
  - **Descrição**: em `lib/the_band_web/router.ex`, extrair a CSP de `:browser` (`router.ex:28-39`)
    para um atributo de módulo, sem mudar o valor, para a pipeline `:plataforma` (T036) usar o
    mesmo. Refatoração exigida pela feature (A8), sem mudança de comportamento
  - **Feita quando**: o cabeçalho `content-security-policy` de uma rota de domínio é byte a byte o de
    antes
  - **Teste**: `test/the_band_web/csp_test.exs` compara o cabeçalho de `GET /sign-in` com o valor
    literal de antes da extração

**Checkpoint**: avaliações fechadas, protótipo aprovado, estado e vocabulário no banco e na base.

---

## Fase 3: User Story 2 — o papel de operador existe, e não vaza dado de organização (P1)

**Objetivo**: existe um operador, fora de `users`, concedido só pelo comando, com senha e segundo
fator, que vê a lista de organizações e recebe a recusa em toda porta de domínio.

**Teste independente**: um operador abre `/platform/organizations` e vê nome, slug e estado; o
mesmo navegador em `/people`, `/teams/:id_de_B`, `/api/v1/people` e `/mcp` recebe a recusa de
anônimo, e nenhuma consulta de domínio roda; um admin de organização em `/platform/organizations`
recebe o `404` de um caminho inexistente.

- [ ] T018 [US2] Criar as tabelas do operador
  - **Pronta quando**: T008 concluída; T007 concluída; `data-model.md` §1 (sem as colunas do TOTP),
    §2 e §3
  - **Descrição**: `priv/repo/migrations/<ts>_operador_da_plataforma.exs` com
    `platform_operators`, `platform_operator_grants` (com `email_at_grant`, A13c) e
    `platform_operator_sessions` (com `last_seen_at`, A11); índices, `CHECK`s e os triggers
    `nao_apaga`, `so_revoga` (coluna a coluna com `IS DISTINCT FROM`, A13b) e `nao_trunca`
    (`BEFORE TRUNCATE … FOR EACH STATEMENT`, A13a). `@moduledoc` da migração diz que o trigger
    protege de código, e não de quem tem o banco (research R7). `execute/2` sempre com par de
    `down`. FR-002, FR-011
  - **Feita quando**: as três tabelas existem sem `tenant_id`; o índice parcial da concessão vigente
    recusa a segunda; o `down` remove triggers, funções e tabelas
  - **Teste**: `mix ecto.migrate` e `mix ecto.rollback --step 1` sem erro, e de novo `migrate`;
    `test/the_band/platform/tabelas_do_operador_test.exs` afirma o índice parcial

- [ ] T019 [US2] Provar que a concessão não se apaga nem se reescreve
  - **Pronta quando**: T018 concluída
  - **Descrição**: cenário 11 de `seguranca-autenticacao.md` e quickstart §7, para
    `platform_operator_grants`. FR-002, A13
  - **Feita quando**: `DELETE` levanta; `TRUNCATE` levanta; um `UPDATE` que preenche `revoked_at`
    **e** muda `granted_by_declared` levanta; um `UPDATE` que só preenche a revogação passa
  - **Teste**: `test/the_band/platform/concessao_nao_se_apaga_test.exs`. **Defeito a injetar**: o
    trigger de `UPDATE` comparando só `revoked_at`; o terceiro caso precisa passar a gravar e o teste
    reprovar. Segundo defeito: retirar o `BEFORE TRUNCATE`

- [ ] T020 [US2] Criar as colunas e a tabela do segundo fator
  - **Pronta quando**: T011 concluída; T018 concluída; `data-model.md` §1 (colunas do TOTP) e §1a
  - **Descrição**: `priv/repo/migrations/<ts>_segundo_fator_do_operador.exs`: em
    `platform_operators`, `totp_secret` (binário cifrado), `totp_confirmed_at`,
    `totp_last_used_step`, `enrollment_code_hash`, `enrollment_code_expires_at` e os quatro `CHECK`s;
    a tabela `platform_operator_recovery_codes` com os índices. FR-016
  - **Feita quando**: `totp_confirmed_at` preenchido com `totp_secret` nulo reprova no banco; o índice
    único `(operator_id, code_hash)` recusa o repetido
  - **Teste**: round trip `mix ecto.migrate` / `mix ecto.rollback --step 1`;
    `test/the_band/platform/tabelas_do_segundo_fator_test.exs` com os dois casos. **Defeito a
    injetar**: retirar o `CHECK` do segredo; o primeiro caso precisa gravar e o teste reprovar

- [ ] T021 [US2] Escrever os schemas do contexto da plataforma
  - **Pronta quando**: T018 e T020 concluídas
  - **Descrição**: `lib/the_band/platform/operator.ex`, `grant.ex`, `operator_session.ex`,
    `recovery_code.ex`, privados ao contexto. `redact: true` em `password_hash`, `setup_code_hash`,
    `enrollment_code_hash`, `totp_secret`, `token_hash` e `code_hash`; `totp_secret` com
    `TheBand.Encrypted.Binary`. Nenhum `has_many` para tabela de domínio
  - **Feita quando**: `inspect/1` de cada struct não mostra nenhum dos campos redigidos; a leitura
    direta de `platform_operators.totp_secret` devolve texto cifrado
  - **Teste**: `test/the_band/platform/schemas_test.exs` — `refute inspect(op) =~ "<valor>"` para
    cada campo, e a leitura crua da coluna difere do segredo em claro

- [ ] T022 [US2] Conferir o código do segundo fator
  - **Pronta quando**: `contracts/segundo-fator-do-operador.md` emendado por T011; T010 sem achado
    alto aberto; a dependência, se houver, fixada em `mix.exs` com a versão de T009
  - **Descrição**: `lib/the_band/platform/segundo_fator.ex`, **funções puras**: `gerar_segredo/0`,
    `uri/2`, `conferir/4` (janela ±1, `:reusado` para passo `<= ultimo_passo`, `agora` como
    argumento), `classificar/1`, `gerar_codigos_de_recuperacao/0`, `resumo/1`. FR-016
  - **Feita quando**: os vetores do RFC 6238, apêndice B (SHA-1), conferem; um código do passo
    `atual + 2` é recusado; o mesmo código com `ultimo_passo` igual ao passo dele devolve `:reusado`
  - **Teste**: `test/the_band/platform/segundo_fator_test.exs` com o relógio fixado. **Defeitos a
    injetar**, um por vez: alargar a janela para ±2 (o caso `atual + 2` precisa passar e o teste
    reprovar); retirar a comparação com `ultimo_passo` (o caso de reuso precisa passar e o teste
    reprovar)

- [ ] T023 [US2] Conferir a entrada do operador
  - **Pronta quando**: **A1** e **A3** emendados em `contracts/credenciais-do-operador.md` e
    conferidos por T008; T002 (#1048) e T003 (#1047) mergeadas e T007 rebaseada, para copiar a
    forma corrigida; T021 e T022 concluídas
  - **Descrição**: `lib/the_band/platform/credentials.ex`, `autenticar/3`: transação com
    `SELECT … FOR UPDATE` na linha do operador **antes** da espera e do hash (A1);
    `Bcrypt.no_user_verify/0` também na recusa por espera (A3); recusa única; segundo fator só
    depois da senha; código de recuperação consumido com `UPDATE … WHERE used_at IS NULL
    RETURNING`; sem concessão vigente não conta falha; sucesso grava `totp_last_used_step`, zera
    falhas depois de registrar quantas e grava `logged_in_at`. Comentário apontando para
    `Tenants.Auth` e o motivo da duplicação (research R2). FR-011, FR-016
  - **Feita quando**: operador sem concessão, sem senha, sem segundo fator confirmado, com senha
    errada, com TOTP errado e com TOTP reusado recebem todos `{:error, :invalid_credentials}`; o
    motivo interno de cada um aparece no evento; o sucesso devolve `{:ok, %Operator{}}`
  - **Teste**: `test/the_band/platform/credentials_autenticar_test.exs`, um caso por motivo

- [ ] T024 [US2] Provar a espera sob rajada paralela
  - **Pronta quando**: T023 concluída
  - **Descrição**: cenário 1 de `seguranca-autenticacao.md` (**A1**): operador com 3 falhas e
    `last_failed_at` agora; 10 `Task` chamam `autenticar/3` com senha errada ao mesmo tempo, com o
    sandbox em modo compartilhado
  - **Feita quando**: `failed_attempts` subiu exatamente 1; nove chamadas devolveram
    `{:throttled, _}` e uma registrou a falha (os dois lados contados, L90); com a senha certa e sem
    espera, uma das dez autentica (a guarda de que mediu)
  - **Teste**: `test/the_band/platform/espera_paralela_test.exs`. **Defeito a injetar**: retirar o
    `FOR UPDATE`; `failed_attempts` precisa subir mais de 1 e o teste reprovar

- [ ] T025 [US2] Provar que a espera paga o custo do hash
  - **Pronta quando**: T023 concluída
  - **Descrição**: cenário 2 de `seguranca-autenticacao.md` (**A3**): um operador em espera e um
    e-mail inexistente. Instrumentar a chamada a `Bcrypt.no_user_verify/0` e `verify_pass/2` por
    `:telemetry` ou contagem, **não** por cronômetro
  - **Feita quando**: as duas recusas passaram pelo custo do hash uma vez cada; a recusa por espera
    devolve `{:throttled, _}`
  - **Teste**: `test/the_band/platform/espera_paga_o_hash_test.exs`. **Defeito a injetar**: retirar o
    hash do ramo da espera; a contagem do primeiro caso precisa dar zero e o teste reprovar

- [ ] T026 [US2] Definir a senha e cadastrar o segundo fator
  - **Pronta quando**: **A5** e **A14** emendados em `contracts/credenciais-do-operador.md` e
    conferidos por T008; T011 concluída; T023 concluída
  - **Descrição**: `definir_senha/3` e `confirmar_segundo_fator/3` em `credentials.ex`, como o
    contrato: exigem concessão vigente (A14); consomem o código de definição e o de cadastro de
    forma **atômica** dentro da transação com `FOR UPDATE` (A5); a política de senha roda antes do
    consumo; o primeiro passo não habilita a entrada; o segundo gera os dez códigos de recuperação,
    sobe a época e encerra as sessões. Eventos de A7 (T033). FR-016, O4
  - **Feita quando**: depois só do primeiro passo, `autenticar/3` recusa; depois do segundo,
    autentica com o TOTP; o código de definição usado uma vez é recusado na segunda; operador sem
    concessão vigente recebe a recusa única no primeiro passo
  - **Teste**: `test/the_band/platform/credentials_definir_test.exs`, os quatro casos

- [ ] T027 [US2] Provar o código de uso único sob concorrência
  - **Pronta quando**: T026 concluída
  - **Descrição**: cenário 3 de `seguranca-autenticacao.md` (**A5**): duas `Task` chamam
    `definir_senha/3` com o mesmo código e senhas diferentes; o mesmo para o código de cadastro em
    `confirmar_segundo_fator/3`
  - **Feita quando**: exatamente uma devolve `{:ok, _}` e a outra `{:error, :invalid_credentials}`
    (os dois lados contados, L90); `setup_code_hash` fica nulo; vale a senha da que ganhou
  - **Teste**: `test/the_band/platform/codigo_de_uso_unico_test.exs`. **Defeito a injetar**: conferir
    o resumo em memória e gravar depois, sem lock; as duas precisam passar e o teste reprovar

- [ ] T028 [US2] Provar o segundo fator na entrada
  - **Pronta quando**: T026 concluída; os cenários de `seguranca-totp.md` (T010)
  - **Descrição**: a entrada exige o segundo fator a cada vez (FR-016): sem ele; com o mesmo código
    TOTP usado duas vezes; com um código de recuperação usado duas vezes em paralelo; mais os
    cenários que T010 escreveu
  - **Feita quando**: sem segundo fator e com TOTP reusado, recusa única; dos dois usos paralelos do
    mesmo código de recuperação, exatamente um passa; o evento `operador_recuperacao_usada` diz
    quantos restam
  - **Teste**: `test/the_band/platform/segundo_fator_na_entrada_test.exs`. **Defeitos a injetar**: não
    gravar `totp_last_used_step` no sucesso (o reuso precisa passar); consumir o código de
    recuperação sem `used_at IS NULL` no `WHERE` (os dois paralelos precisam passar)

- [ ] T029 [US2] Abrir e conferir a sessão do operador
  - **Pronta quando**: `contracts/sessao-do-operador.md` emendado (A11, A15) e conferido por T008;
    T021 concluída
  - **Descrição**: `lib/the_band/platform/sessions.ex`: `abrir/1`, `conferir/2` (os oito motivos,
    inclusive `:inativa` por `last_seen_at` de 30 min e `:sem_concessao` lida na mesma consulta),
    `encerrar/1`, `encerrar_do_operador/1`, `apagar_as_que_deixaram_de_valer/1`. Constantes de 8 h e
    30 min nomeadas, com o motivo. FR-011, FR-014
  - **Feita quando**: cada motivo é produzido por um caso; `last_seen_at` é gravado no máximo uma vez
    por minuto; nenhuma função aceita `%User{}`
  - **Teste**: `test/the_band/platform/sessions_test.exs`, um caso por motivo. **Defeito a injetar**:
    retirar a leitura da concessão da consulta; o caso `:sem_concessao` precisa dar `{:ok, …}` e o
    teste reprovar

- [ ] T030 [US2] Conceder, reiniciar e revogar o papel
  - **Pronta quando**: **A6**, A13c, A14 e A15 emendados em `contracts/concessao-do-operador.md` e
    conferidos por T008; T026 e T029 concluídas
  - **Descrição**: `lib/the_band/platform/grants.ex`: `conceder/3` (cria ou, se já existe sem
    concessão vigente, apaga senha, segundo fator, sobe a época e encerra sessões, A6; grava
    `email_at_grant`), `reiniciar_credencial/2` (com `FOR UPDATE` nas sessões, A15), `revogar/3`
    (encerra sessões e anula códigos pendentes, A14, FR-014), `vigente?/1`. FR-001, FR-002
  - **Feita quando**: revogar encerra a sessão do operador na mesma transação; conceder duas vezes
    seguidas devolve `{:error, :ja_concedido}`
  - **Teste**: `test/the_band/platform/grants_test.exs`, os dois casos

- [ ] T031 [US2] Provar que conceder de novo não devolve credencial
  - **Pronta quando**: T030 concluída
  - **Descrição**: cenário 4 de `seguranca-autenticacao.md` (**A6**): conceder, definir senha e
    segundo fator, revogar, conceder de novo
  - **Feita quando**: `autenticar(email, senha_antiga, totp_do_segredo_antigo)` devolve
    `{:error, :invalid_credentials}`; nenhuma sessão de antes passa em `conferir/2`; os códigos de
    recuperação antigos têm `used_at`
  - **Teste**: `test/the_band/platform/conceder_de_novo_test.exs`. **Defeitos a injetar**, juntos e
    depois um por vez: não anular `password_hash` nem `totp_secret` em `conceder/3`; juntos, a
    entrada antiga precisa autenticar e o teste reprovar; um por vez, a asserção sobre a coluna
    correspondente precisa reprovar

- [ ] T032 [US2] Comandos de operação para o papel
  - **Pronta quando**: T030 concluída; `contracts/concessao-do-operador.md`, seção `TheBand.Release`
  - **Descrição**: em `lib/the_band/release.ex`, `conceder_operador/3`,
    `reiniciar_credencial_do_operador/2` e `revogar_operador/3`, na forma de `release.ex:106-118`;
    nunca recebem senha; imprimem e-mail, ato e, uma vez, o código de definição com a validade.
    `encerrar_todas_as_sessoes/0` passa a encerrar também as do operador. FR-001, O11
  - **Feita quando**: a saída de `conceder_operador/3` não contém senha e contém o código uma vez;
    nenhum módulo de `TheBandWeb` referencia `TheBand.Platform.Grants`
  - **Teste**: `test/the_band/release_operador_test.exs` com `ExUnit.CaptureIO`, e um teste sobre a
    saída de `mix xref callers TheBand.Platform.Grants` que afirma zero chamadores sob
    `lib/the_band_web/`. **Defeito a injetar**: chamar `Grants.vigente?/1` de um controller de
    rascunho; o teste precisa reprovar

- [ ] T033 [P] [US2] Registrar os eventos de acesso do operador
  - **Pronta quando**: `contracts/eventos-de-acesso.md` emendado (A7) e conferido por T008; T016
    concluída
  - **Descrição**: em `lib/the_band/tenants/access_events.ex`, as funções do contrato, todas em
    `:warning`, inclusive `operador_senha_definida/1`, `operador_definicao_recusada/2`,
    `operador_segundo_fator_cadastrado/1`, `operador_cadastro_recusado/2` e
    `operador_recuperacao_usada/2`. Chamadas por T023, T026 e T030. FR-010, O14
  - **Feita quando**: um código de definição errado produz `operador_definicao_recusada` com
    `:codigo_errado`; o código, a senha e o segredo não aparecem em nenhuma linha capturada
  - **Teste**: `test/the_band/platform/eventos_do_operador_test.exs` com `capture_log`, e `refute
    log =~ codigo` (cenário 12). **Defeito a injetar**: retirar a chamada em `definir_senha/3`; o
    caso precisa reprovar

- [ ] T034 [P] [US2] Provar a paridade das duas autenticações
  - **Pronta quando**: T023 concluída
  - **Descrição**: as constantes de espera (livres, base, teto) e a forma da serialização de
    `Platform.Credentials` iguais às de `Tenants.Auth` depois da #1046 e da #1047 (quickstart §3;
    research R2)
  - **Feita quando**: o teste compara os valores lidos das duas, e não literais copiados
  - **Teste**: `test/the_band/platform/paridade_com_auth_test.exs`. **Defeito a injetar**: mudar o
    teto de um dos dois para 61 s; o teste precisa reprovar

- [ ] T035 [US2] Guardar a sessão do operador no cookie próprio
  - **Pronta quando**: T005 decidida como (a); `contracts/sessao-do-operador.md`; T029 concluída
  - **Descrição**: `lib/the_band_web/plataforma/sessao_do_operador.ex`: `conferir/1`, `abrir/2`,
    `soltar/1`, com `_the_band_operator`, `encrypt: true`, `http_only`, `secure` de
    `:cookie_de_sessao_seguro`, `same_site: "Strict"`, `path: "/platform"`, `max_age` de 8 h. É o
    único leitor do cookie, e nunca lê `"session_id"` nem `"session_secret"`
  - **Feita quando**: o `set-cookie` da entrada tem os cinco atributos; `TheBandWeb.Sessao` não
    menciona `_the_band_operator`
  - **Teste**: `test/the_band_web/plataforma/sessao_do_operador_test.exs` lê o cabeçalho e afirma os
    atributos; um teste textual sobre `lib/the_band_web/sessao.ex` sem comentários (memória "guarda
    que lê código reprova a prosa") afirma a ausência do nome

- [ ] T036 [US2] Montar a área do operador no roteador
  - **Pronta quando**: T005 decidida; `contracts/rotas-da-plataforma.md` emendado (A8, A12) e
    conferido por T008; T017 e T035 concluídas
  - **Descrição**: `lib/the_band_web/plataforma/operator_scope.ex` (plug que atribui
    `:current_operator` e grava `Logger.metadata(operator_id: …)`, nunca `user_id` nem
    `tenant_id`) e `require_operator/2` (`404` com `ErrorHTML`, sem redirecionar);
    `router.ex`: pipeline `:plataforma` sem `CurrentScope`, com a CSP compartilhada e
    `Cache-Control: no-store`; o escopo `/platform` com as rotas do contrato e o
    `match :*, "/platform/*caminho"` **por último** (A12). Controllers ainda vazios, que respondem
    `404` até T039 e T040. FR-009, FR-011
  - **Feita quando**: `GET /platform/organizations` anônimo dá `404`; um admin de organização com
    sessão válida recebe o mesmo `404`; nenhuma rota de `/platform` passa por `CurrentScope`
  - **Teste**: `test/the_band_web/plataforma/rotas_test.exs`. **Defeito a injetar**: trocar
    `require_operator` por `require_admin` (I4 de `seguranca.md`); o caso do admin precisa dar outra
    resposta e o teste reprovar

- [ ] T037 [US2] Provar que o 404 do operador é o de qualquer caminho
  - **Pronta quando**: T036 concluída
  - **Descrição**: cenário 10 de `seguranca-autenticacao.md` (**A12**): `GET
    /platform/organizations` anônimo e `GET /platform/nao-existe`
  - **Feita quando**: mesmo status, mesmo conjunto de cabeçalhos de segurança, e o mesmo corpo depois
    de retirar o `csrf-token`
  - **Teste**: `test/the_band_web/plataforma/nao_encontrado_test.exs`. **Defeito a injetar**: retirar
    o curinga do escopo; os cabeçalhos precisam diferir e o teste reprovar

- [ ] T038 [P] [US2] Provar os cabeçalhos da área do operador
  - **Pronta quando**: T036 concluída
  - **Descrição**: cenário 8 de `seguranca-autenticacao.md` (**A8**, risco residual aceito: mesma
    origem com CSP). Toda resposta de `/platform/*`, inclusive o `404`
  - **Feita quando**: toda resposta tem CSP com `script-src 'self'` sem `'unsafe-inline'`,
    `frame-ancestors 'none'` e `Cache-Control: no-store`
  - **Teste**: `test/the_band_web/plataforma/cabecalhos_test.exs` percorre as rotas de
    `TheBandWeb.Router.__routes__()` sob `/platform`. **Defeito a injetar**: a pipeline sem
    `put_secure_browser_headers`; o teste precisa reprovar

- [ ] T039 [US2] Telas de entrada, definição e cadastro
  - **Pronta quando**: **T012 aprovado** (protótipo); T023, T026 e T036 concluídas;
    `contracts/rotas-da-plataforma.md`
  - **Descrição**: controllers e templates em `lib/the_band_web/controllers/plataforma/` para
    `GET /platform/sign-in`, `POST /platform/session`, `GET /platform/setup`, `POST /platform/setup`,
    `POST /platform/setup/second-factor` e `DELETE /platform/session`, exatamente como o protótipo.
    Campos `email`, `password`, `setup_token`, `enrollment_token` e `second_factor_token` (A10). Os
    códigos de recuperação e o segredo aparecem **uma vez**. Texto em inglês, com o comentário de
    que é tela
  - **Feita quando**: o fluxo inteiro, do código de definição à entrada com TOTP, funciona no
    navegador; a recusa é a mesma frase em todos os casos; o segredo não aparece em nenhuma resposta
    depois da tela de cadastro
  - **Teste**: `test/the_band_web/plataforma/entrada_e_definicao_test.exs` com `Phoenix.ConnTest`;
    `refute html =~ segredo` na resposta da entrada e na do `GET /platform/setup`

- [ ] T040 [US2] Tela da lista de organizações
  - **Pronta quando**: **T012 aprovado**; T029 e T036 concluídas; `contracts/suspensao.md`,
    `listar_organizacoes/1`
  - **Descrição**: `lib/the_band/platform/suspensions.ex` com `listar_organizacoes/1` (confere a
    autorização por dentro; `select` explícito de `id`, `name`, `slug`, `status` e o último
    episódio com `LEFT JOIN LATERAL`; nunca `%Tenant{}` nem `Tenants.list_tenants/0`), fachada
    `lib/the_band/platform.ex` com `defdelegate`, e o controller de `GET /platform/organizations`.
    Antes de T044 existir, o `LEFT JOIN LATERAL` fica para T044; aqui `ultimo_episodio_em` é sempre
    "nunca suspensa" com `<.absent>`. FR-007, US2 cenário 2
  - **Feita quando**: o operador vê nome, slug e estado de todas as organizações; nenhuma coluna de
    domínio aparece; a ausência de episódio está escrita, e não em branco nem `—`
  - **Teste**: `test/the_band_web/plataforma/lista_de_organizacoes_test.exs` — duas organizações, e
    `refute html =~` o nome de uma pessoa de cada

- [ ] T041 [US2] Provar que o operador não lê domínio
  - **Pronta quando**: **A9** emendado em research R10 e conferido por T008; T039 e T040 concluídas
  - **Descrição**: `test/the_band_web/plataforma/operador_nao_le_dominio_test.exs`, research R10
    emendado: handler em `[:the_band, :repo, :query]` filtrado pelo processo; **lista permitida por
    rota** (os `GET` e os `POST` de entrada e definição só com `platform_*`, `tenant_suspensions` e
    `tenants`); `source` nulo reprova (L56); **toda consulta reprova se o SQL citar `"users"`**;
    guarda de que mediu (um membro de A registra consulta fora da lista, L50). SC-003, FR-007. Os
    dois `POST` de ato ganham a lista deles em T051
  - **Feita quando**: a coleta das rotas do operador tem mais de zero consultas e nenhuma fora da
    lista da rota; a guarda com o membro de A registra consultas de domínio
  - **Teste**: o próprio arquivo. **Defeitos a injetar**, um por vez, e cada um precisa reprovar:
    `OperatorScope` chama `TheBandWeb.Sessao.conferir/1` (cenário 7 da avaliação);
    `listar_organizacoes/1` pré-carrega `users`

- [ ] T042 [US2] Provar que o cookie do operador não abre domínio
  - **Pronta quando**: T036 concluída
  - **Descrição**: US2 cenário 4 e SC-003 nas três portas: com uma sessão de operador válida e o
    cookie forçado por `put_req_cookie` (que ignora `Path`), `GET /people`, `GET /teams/:id_de_B`,
    `GET /api/v1/people` e `POST /mcp`. Mesmo arquivo de T041 ou vizinho
  - **Feita quando**: as respostas são a recusa de anônimo (redirecionamento a `/sign-in`, `401`,
    `401`); nenhuma consulta toca `platform_*` durante essas requisições
  - **Teste**: `test/the_band_web/plataforma/cookie_do_operador_em_dominio_test.exs`. **Defeito a
    injetar**: `TheBandWeb.Sessao` passar a aceitar `_the_band_operator` como sessão; o teste precisa
    reprovar em `/people`

- [ ] T043 [US2] Limitar as tentativas por IP
  - **Pronta quando**: **T004 registrou que o Traefik sobrescreve** `x-forwarded-for` (decisão 2 da
    pessoa mantenedora); `contracts/rotas-da-plataforma.md` emendado **antes** do código com o
    desenho do limite (onde vive o contador, sem dependência nova, a janela e o teto com o motivo);
    T036 concluída
  - **Descrição**: `config/prod.exs` ganha `Plug.RewriteOn` com `:x_forwarded_for`, confiando só no
    proxy do Dokploy; limite por IP em `POST /platform/session`, `POST /platform/setup` e
    `POST /platform/setup/second-factor`, e a espera por conta passa a ser por conta **e** IP, o que
    fecha a negação de serviço de A4. **Se T004 registrar "acrescenta"**, esta tarefa **não** é
    implementada: fica aberta como não concluída, com o motivo, e o risco A4 entra na nota da
    release (T062) — nunca marcada `[x]` sem código (L109)
  - **Feita quando**: o décimo primeiro `POST` de um IP dentro da janela é recusado com a recusa
    única; outro IP continua entrando; um `X-Forwarded-For` forjado pelo cliente não muda o IP
    contado
  - **Teste**: `test/the_band_web/plataforma/limite_por_ip_test.exs`. **Defeito a injetar**: ler o
    primeiro valor de `x-forwarded-for` em vez do que o proxy escreveu; o caso forjado precisa
    passar e o teste reprovar

**Checkpoint**: a US2 se demonstra sozinha — operador entra com senha e TOTP, vê a lista, e o
domínio o recusa nas três portas.

---

## Fase 4: User Story 1 — suspender uma organização, e as sessões caem de verdade (P1) 🎯 MVP

**Objetivo**: o operador suspende e reativa uma organização, com razão; toda sessão e todo token da
organização caem na suspensão, nenhum volta na reativação, e a aba aberta cai junto.

**Teste independente**: com uma sessão aberta na organização A, suspender A e reativar A; o cookie
de antes vai para `/sign-in`. Com o encerramento retirado, o teste precisa dar `200`.

- [ ] T044 [US1] Criar o episódio de suspensão
  - **Pronta quando**: T008 concluída; T013 e T018 concluídas; `data-model.md` §4 e §6
  - **Descrição**: `priv/repo/migrations/<ts>_episodio_de_suspensao.exs`: `tenant_suspensions`
    com o índice parcial do aberto, os `CHECK`s, os triggers `nao_apaga`, `so_fecha` (coluna a
    coluna, liberando `updated_at`, A13b) e `nao_trunca` (A13a); em `api_access_tokens`, a coluna
    `revoked_by_suspension_id` e os dois `CHECK`s; e o `up` insere um episódio `not_recorded`, sem
    autor, para cada organização já `suspended` sem episódio. Schema `lib/the_band/platform/
    suspension.ex`. FR-006, SC-002
  - **Feita quando**: a consulta de `data-model.md` §7 devolve `0` depois da migração, inclusive com
    uma organização suspensa antes dela; o `down` volta ao estado anterior
  - **Teste**: round trip `mix ecto.migrate` / `mix ecto.rollback --step 1`, com uma organização
    `suspended` semeada antes; `test/the_band/platform/migracao_do_episodio_test.exs`

- [ ] T045 [US1] Provar que o episódio é um só e não se reescreve
  - **Pronta quando**: T044 concluída
  - **Descrição**: O9 e FR-006, quickstart §7: dois episódios abertos para a mesma organização;
    `DELETE`, `TRUNCATE` e `UPDATE` de `suspend_reason`
  - **Feita quando**: o segundo aberto é recusado pelo índice; as três escritas levantam; fechar o
    episódio (os quatro campos de reativação) passa
  - **Teste**: `test/the_band/platform/episodio_nao_se_reescreve_test.exs`. **Defeito a injetar**:
    retirar o índice parcial; o segundo aberto precisa gravar e o teste reprovar

- [ ] T046 [P] [US1] Encerrar as sessões de uma organização
  - **Pronta quando**: `contracts/sessoes-e-tokens-da-organizacao.md` emendado (A2) e conferido por
    T008; T007 concluída
  - **Descrição**: `TheBand.Tenants.Sessions.encerrar_da_organizacao/1` em
    `lib/the_band/tenants/sessions.ex`: recebe `%Tenant{}`, grava `ended_at` nas abertas com
    `update_all` e `select`, devolve os ids, e **não avisa** (quem avisa é quem chama, depois do
    `commit`). FR-004
  - **Feita quando**: com dois tenants povoados, as sessões de A têm `ended_at` e as de B não, e as
    de B são mais de zero
  - **Teste**: `test/the_band/tenants/encerrar_da_organizacao_test.exs` (cenário 5 de `seguranca.md`).
    **Defeito a injetar**: implementar com `girar_todas/0`; B precisa cair e o teste reprovar

- [ ] T047 [P] [US1] Revogar os tokens de uma organização suspensa
  - **Pronta quando**: `contracts/sessoes-e-tokens-da-organizacao.md`; T015 e T044 concluídas
  - **Descrição**: em `lib/the_band/tenants/api_tokens.ex`, `revogar_por_suspensao/2` (condição
    `revoked_at IS NULL` no `WHERE`, `revoked_by_user_id = NULL`, `revoked_by_suspension_id`,
    cláusula `organizacao_suspensa`) e `clausulas_registradas/0`; a tela de tokens escreve o autor
    como *"revoked when the organisation was suspended"*, e o select de revogação não ganha opção.
    FR-013, O12
  - **Feita quando**: os tokens vigentes de A ficam revogados com a cláusula; o token já revogado de
    A mantém o autor da primeira revogação; os de B continuam vigentes; a tela de tokens de A
    renderiza o autor sem erro com `revoked_by_user_id` nulo
  - **Teste**: `test/the_band/tenants/revogar_por_suspensao_test.exs` e um caso em
    `test/the_band_web/live/api_token_live_test.exs`. **Defeito a injetar**: retirar o filtro de
    tenant; os tokens de B precisam cair e o teste reprovar

- [ ] T048 [P] [US1] Ler as razões de suspensão da base
  - **Pronta quando**: T014 concluída
  - **Descrição**: `lib/the_band/platform/suspension_reasons.ex`, na forma de
    `lib/the_band/tenants/account_lifecycle.ex:165-198`: razões oferecidas, `recorded_only`,
    `offered_only_against`, `note_required`, `rotulo/1`. Base ausente devolve lista vazia, e o ato
    recusa com `:vocabulario_nao_declarado`. FR-003
  - **Feita quando**: `not_recorded` não está entre as oferecidas; `investigation_closed_no_compromise`
    só é oferecida contra `suspected_compromise`
  - **Teste**: `test/the_band/platform/suspension_reasons_test.exs`, incluindo a base sem a regra

- [ ] T049 [US1] Suspender uma organização numa transação
  - **Pronta quando**: **A2** e **A15** emendados em `contracts/suspensao.md` e conferidos por T008;
    o PR #1044 mergeado (T001); T029, T030, T044, T046, T047 e T048 concluídas
  - **Descrição**: `Platform.Suspensions.suspender/3` como `Ecto.Multi` com os passos nomeados de
    research R8: `:autorizacao` (sessão e concessão lidas com `FOR SHARE`, A15), `:razao`,
    `:estado` (`update_all` condicional `active → suspended`), `:episodio`, `:sessoes`, `:tokens`.
    **Depois do `commit`, e só depois**: `Sessions.avisar_encerramento({:sessao, id})` para cada id
    encerrado (A2) e o evento (T055). Fachada em `lib/the_band/platform.ex`. FR-003, FR-004, FR-013,
    FR-014
  - **Feita quando**: o retorno de cada recusa do contrato é produzido por um caso, e nenhum muda o
    estado; o sucesso deixa A `suspended`, com episódio aberto, sessões encerradas e tokens
    revogados
  - **Teste**: `test/the_band/platform/suspender_test.exs`, um caso por retorno do contrato, e o
    passo que recusou afirmado pelo nome do `Multi` (cenário 3 de `seguranca.md`)

- [ ] T050 [US1] Reativar uma organização sem devolver nada
  - **Pronta quando**: T049 concluída
  - **Descrição**: `Platform.Suspensions.reativar/3`: `:autorizacao`, `:razao`, `:estado`
    (`suspended → active`), `:episodio` (fecha o aberto), `:sessoes` (encerra **de novo**, FR-015);
    nenhum token volta (FR-013); depois do `commit`, o aviso por id (A2) e o evento. FR-005, FR-006
  - **Feita quando**: o episódio fecha com autor, instante e razão; `:nao_suspensa` e
    `:sem_episodio_aberto` são produzidos por casos; nenhum token de antes volta a valer
  - **Teste**: `test/the_band/platform/reativar_test.exs`, um caso por retorno

- [ ] T051 [US1] Provar que suspender derruba sessões e tokens
  - **Pronta quando**: T050 concluída; T041 concluída
  - **Descrição**: o teste independente da US1 e quickstart §4, com dois tenants: sessão e token de A
    antes; suspender; reativar; cookie e token de antes. Acrescentar a T041 a lista permitida dos
    dois `POST` de ato (`user_sessions` e `api_access_tokens` também). SC-001
  - **Feita quando**: o cookie de antes vai para `/sign-in` depois da suspensão e depois da
    reativação; o token de antes recebe `401` nos dois momentos; sessões e token de B continuam
    valendo e são mais de zero
  - **Teste**: `test/the_band_web/plataforma/suspensao_derruba_test.exs`. **Defeitos a injetar**, um
    por vez: retirar o passo `:sessoes` da suspensão (o cookie precisa dar `200`); retirar o passo
    `:tokens` (o token precisa dar `200`)

- [ ] T052 [US1] Provar a corrida entre entrar e suspender
  - **Pronta quando**: T050 concluída
  - **Descrição**: cenário 4 de `seguranca.md` (O8, FR-015): com A suspensa, inserir diretamente uma
    sessão de A (a entrada que leu `active` antes); reativar A; enviar o cookie
  - **Feita quando**: o cookie volta para `/sign-in`
  - **Teste**: `test/the_band_web/plataforma/corrida_da_reativacao_test.exs`. **Defeito a injetar**:
    retirar o passo `:sessoes` da reativação; a resposta precisa dar `200`

- [ ] T053 [US1] Provar que a aba aberta cai junto
  - **Pronta quando**: **A2** emendado; T050 concluída
  - **Descrição**: cenários 5 e 6 de `seguranca-autenticacao.md`: uma pessoa de A com `live/2`
    conectado em `/work`, e uma de B; suspender A pelo `POST` do operador; depois, a mesma montagem
    com uma sessão de A inserida durante a suspensão e uma aba conectada a ela, e reativar
    (lição L85: o `200` do HTTP não diz o que o socket faz)
  - **Feita quando**: a próxima mensagem do LiveView de A é o redirecionamento para `/sign-in`, e um
    `render_click` depois disso não executa; o LiveView de B continua respondendo; na reativação, a
    aba da sessão da corrida cai
  - **Teste**: `test/the_band_web/plataforma/aba_aberta_cai_test.exs`. **Defeitos a injetar**, um por
    vez: retirar o aviso depois do `commit` (a aba de A precisa continuar respondendo); avisar só em
    `suspender/3` (a aba da reativação precisa continuar); avisar **dentro** da transação (a aba
    precisa continuar, porque a hook reconfere antes do `commit`)

- [ ] T054 [US1] Provar a revogação com o formulário aberto
  - **Pronta quando**: T049 e T032 concluídas
  - **Descrição**: quickstart §5 e cenário 3 de `seguranca.md` (O6, FR-014, A15): o operador abre o
    formulário de suspensão; a concessão é revogada; o operador envia o formulário. E a variante do
    reinício de credencial em voo (A15)
  - **Feita quando**: A continua `active`, sem episódio novo; a resposta é o `404`; a sessão do
    operador tem `ended_at`
  - **Teste**: `test/the_band_web/plataforma/revogacao_em_voo_test.exs`. **Defeito a injetar**:
    conferir a autorização só no plug, e não dentro de `suspender/3`; a suspensão precisa acontecer e
    o teste reprovar

- [ ] T055 [P] [US1] Registrar os atos de plataforma no log
  - **Pronta quando**: T033 concluída; T049 concluída
  - **Descrição**: `AccessEvents.ato_de_plataforma/3` para `:organizacao_suspensa` e
    `:organizacao_reativada` e `operador_ato_recusado/3`, chamados depois do `commit`; o `tenant_id`
    do evento é o da organização afetada; o ator vem de `operator_id` no metadado. FR-010, O14,
    quickstart §9
  - **Feita quando**: a linha capturada tem `operator_id`, o `tenant_id` de A, o id do episódio e as
    contagens; a nota livre não aparece
  - **Teste**: `test/the_band/platform/eventos_dos_atos_test.exs` com `capture_log`. **Defeito a
    injetar**: retirar a chamada em `reativar/3`; o caso precisa reprovar

- [ ] T056 [US1] Tela do histórico e do ato
  - **Pronta quando**: **T012 aprovado**; T049, T050 e T048 concluídas; `contracts/rotas-da-plataforma.md`
  - **Descrição**: `organizacao/2` em `Suspensions` (histórico do mais novo ao mais antigo, razões por
    `SuspensionReasons.rotulo/1`), o `LEFT JOIN LATERAL` do último episódio em
    `listar_organizacoes/1`, e os controllers de `GET /platform/organizations/:slug`,
    `POST …/suspension` e `POST …/reactivation`, exatamente como o protótipo: só o ato que cabe ao
    estado, razões da base, nota obrigatória onde a base diz, recusa como estado com o motivo em
    inglês. FR-003, FR-006
  - **Feita quando**: suspender e reativar pela tela funcionam; slug inexistente dá o `404`; o
    histórico mostra quem, quando e por quê nas duas pontas, e `not_recorded` com o rótulo da base
  - **Teste**: `test/the_band_web/plataforma/historico_e_ato_test.exs`, com a razão fora da lista
    recusada e nada mudando

- [ ] T057 [US1] Medir o tempo do ato e a recusa em lote
  - **Pronta quando**: T056 concluída
  - **Descrição**: SC-004 (menos de um minuto pela tela, sem banco) medido no ambiente de
    desenvolvimento, com o roteiro de quickstart §4 passo 1; e FR-008 afirmada pela ausência de
    rota e de função que suspenda mais de uma organização
  - **Feita quando**: o tempo medido está registrado na issue com o método; nenhuma rota sob
    `/platform` aceita lista de organizações
  - **Teste**: o registro da medição; e um caso em `rotas_test.exs` que percorre
    `__routes__()` e afirma que nenhuma rota de ato fica fora de `/:slug/`

**Checkpoint**: a US1 se demonstra sozinha — suspender e reativar derrubam tudo, e nada volta.

---

## Fase 5: Acabamento e transversal

- [ ] T058 [P] Apagar as sessões vencidas do operador
  - **Pronta quando**: T029 concluída
  - **Descrição**: `lib/the_band/jobs/apaga_sessoes_antigas.ex` chama também
    `Platform.Sessions.apagar_as_que_deixaram_de_valer/1` (research R3.1), sem worker novo. A
    retenção dos códigos de recuperação segue o que T010 decidiu
  - **Feita quando**: uma sessão do operador encerrada há 91 dias some; uma de 89 dias fica
  - **Teste**: `test/the_band/jobs/apaga_sessoes_antigas_test.exs` com os dois casos

- [ ] T059 [P] Escrever o roteiro de operação do operador
  - **Pronta quando**: T032 concluída
  - **Descrição**: `docs/producao/runbook.md` ganha a seção do operador: os três comandos com
    `/app/bin/the_band eval`, que **a pessoa operadora roda o comando ela mesma, ou recebe o código
    por voz, nunca por chat** (A17), o cadastro do segundo fator, e o que fazer ao perder o celular
    (códigos de recuperação; depois, reinício pelo comando)
  - **Feita quando**: o roteiro não contém nenhum segredo de exemplo que pareça real; quem não
    escreveu o roteiro consegue conceder, definir e entrar seguindo só ele
  - **Teste**: execução do roteiro por outra pessoa no ambiente local, com o resultado na issue

- [ ] T060 Conferir a tela contra o protótipo
  - **Pronta quando**: T039, T040 e T056 concluídas
  - **Descrição**: o agente QA lê cada tela implementada contra o `PROMPT.md` §3 do protótipo,
    item a item (lição L103: a concordância é conferida por gente). Mudança necessária volta ao
    protótipo antes do código
  - **Feita quando**: cada item do `PROMPT.md` tem `confere` ou `diverge` com a captura de tela; não
    há `diverge` aberto
  - **Teste**: o registro de conferência guardado em `prototipo/conferencia.md`

- [ ] T061 Rodar o roteiro de validação e os gates
  - **Pronta quando**: todas as tarefas das Fases 3 e 4 concluídas, ou abertas com motivo
  - **Descrição**: quickstart.md §1 a §9; `mix gates > /tmp/gates-070.log 2>&1; echo "EXIT=$?"`;
    `mix sobelow`, `mix hex.audit` e `mix deps.audit` com a dependência do TOTP, se houver
  - **Feita quando**: cada passo do quickstart tem o resultado registrado; os gates dão `EXIT=0`,
    lido no log e não deduzido
  - **Teste**: os códigos de saída colados no PR, na seção *Evidência*

- [ ] T062 Escrever a nota de riscos da release
  - **Pronta quando**: T061 concluída
  - **Descrição**: para a skill `release`: as migrações (o `CHECK` que levanta com estado fora da
    lista, e o episódio `not_recorded`), medidas contra produção antes de publicar; os riscos
    residuais **A8** (mesma origem, CSP como defesa, decisão 3), **A17** (o código no terminal do
    Dokploy), **A4** se T043 não entrou, e o aparelho do segundo fator como o que sobra de O16
  - **Feita quando**: a nota existe com cada risco, quem o aceitou e quando
  - **Teste**: a revisão do Product Owner encontra os quatro itens

- [ ] T063 [P] Derivar os modelos da feature
  - **Pronta quando**: T044 e T020 concluídas
  - **Descrição**: o agente de modelos deriva das migrações o ERD das tabelas `platform_*` e
    `tenant_suspensions`, e a máquina de estados da organização e da credencial do operador
    (definição em dois passos), em Mermaid, com `arquivo:linha`
  - **Feita quando**: cada entidade e transição do modelo aponta para a migração ou a função que a
    cria
  - **Teste**: a revisão confere três `arquivo:linha` escolhidos ao acaso contra o código

- [ ] T064 Abrir o PR pelo template
  - **Pronta quando**: T061 e T062 concluídas; `git status --short` vazio
  - **Descrição**: corpo a partir de `.github/pull_request_template.md` (nunca `--body` à mão),
    tipo de merge declarado (squash, a branch morre no merge), issues com resumo na frente, campo
    `Sprint:`; revisor equipe `the-band` pela API; item no projeto com Iteration e Status conferidos.
    *O que este PR não resolve*: A4 se T043 não entrou, A8 e A17
  - **Feita quando**: `gh pr view <n> --json reviewRequests` não é vazio; o check
    `pr-tipo-de-merge` passa
  - **Teste**: as duas leituras coladas na issue desta tarefa

---

## Dependências e ordem

### Entre fases

- **Fase 1** (T001–T007): não depende de nada da feature. T002, T003, T004 e T005 dependem de
  outras pessoas ou PRs, e são o caminho crítico.
- **Fase 2** (T008–T017): T008 depende das emendas de 2026-10-01; T009 → T010 → T011; T012 depende de
  T005 e T009; T013–T017 dependem só de T007 e correm em paralelo.
- **Fase 3, US2** (T018–T043): depende de T008 e T011; as telas (T039, T040) dependem de T012.
- **Fase 4, US1** (T044–T057): depende de T029 e T030 (sessão e concessão do operador) e das telas
  da US2 só em T056. T046, T047 e T048 correm em paralelo assim que T008 fecha.
- **Fase 5** (T058–T064): depois do que cada uma cita.

### Os bloqueios de segurança, por achado

| achado | tarefa que o fecha | tarefas que esperam por ele |
|---|---|---|
| A1, alta | T002 (#1048), T023, T024 | T023–T028, T034 |
| A2, alta | T001 (#1044), T049, T050, T053 | T049–T053 |
| A3, média | T003 (#1047), T023, T025 | T023, T025, T034 |
| A5, média | T026, T027 | T026–T028, T039 |
| A6, média | T030, T031 | T030–T032 |
| A9, média | T041 | T051 |
| A4, média | T004, T043 | T043; sem T004, risco na release (T062) |
| FR-016 (TOTP) | T009, T010, T011, T022, T028 | T020, T022, T023, T026, T028 |
| tela | T012 | T039, T040, T056, T060 |

### Dentro de cada história

Migração → schema → função do contexto → prova da guarda (defeito injetado) → controller → tela.
A prova de cada guarda vem **logo depois** da função que ela guarda, e não no fim.

## Paralelismo

```text
# Fase 2, depois de T007:
T013 estado da organização    T014 razões na base    T015 cláusula registrada
T016 log e filtro             T017 CSP compartilhada

# US2, depois de T023:
T024 rajada paralela    T025 espera paga o hash    T034 paridade

# US1, depois de T008:
T046 encerrar da organização    T047 revogar tokens    T048 razões
```

## Estratégia de entrega

1. **Fase 1 inteira antes de qualquer código.** T002 e T003 são PRs de outra issue; T004 e T005
   são da pessoa mantenedora. Enquanto não chegam, a Fase 2 avança no que não depende deles
   (T008, T009, T013–T017).
2. **US2 até T038** entrega o operador que entra com senha e TOTP e uma área que responde `404` a
   todos os outros. Não é entregável sozinho em produção — um operador sem ato não resolve o #1009.
3. **US1** é o MVP de verdade: o #1009 fechado. A release só sai com US2 e US1 juntas.
4. T043 entra na mesma release **se** T004 chegar a tempo; se não, a release sai com A4 declarado.

## Contagem

| fase | tarefas |
|---|---|
| 1 — Pré-requisitos e decisões | 7 (T001–T007) |
| 2 — Fundação | 10 (T008–T017) |
| 3 — US2 | 26 (T018–T043) |
| 4 — US1 | 14 (T044–T057) |
| 5 — Acabamento | 7 (T058–T064) |
| **total** | **64** |
