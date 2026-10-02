---
description: "Tarefas da 070 — o operador da plataforma: suspender e reativar uma organização"
---

# Tasks: o operador da plataforma — suspender e reativar uma organização

**Input**: `specs/070-operador-da-plataforma/` — [spec.md](spec.md), [plan.md](plan.md),
[research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/),
[quickstart.md](quickstart.md), [seguranca.md](seguranca.md),
[seguranca-autenticacao.md](seguranca-autenticacao.md), [seguranca-totp.md](seguranca-totp.md)

**Emendado em 2026-10-01** pelo `/speckit-analyze` (D1, O1, S1–S4, C1, C2, U1, D2, T1, L1–L7, A1):
tarefas novas T003a, T023a, T030a, T038a e T046a; ordem circular desfeita; contagem refeita.
**Reemendado em 2026-10-01** pela reanálise (O3, O4, O5, P1, L1) e pela conferência de segurança das
emendas D1 (D1-b, D1-c, D1-d de `seguranca-autenticacao.md`): T033 separada de `definir_senha/3`,
T051 e T054 esperam T056, T053 chama o contexto direto, a coluna de `api_access_tokens` passou de
T044 para T047. Na segunda passada: **T044a** nova (o trigger de constraint adiado de D1-a, decidido
pela pessoa mantenedora), e `suspender/3` e `reativar/3` passam a receber o slug (U1 da reanálise),
em T049, T050, T053 e T056. Na terceira (E1, T1, U2–U4, C1, C2, F1): o trigger de §4a sem o `CASE`
no `DECLARE`, T044a com `create_tenant/1`, T056 com PRG; e T033, T056 e T028a **movidas no arquivo** para
antes de quem depende delas, com os IDs inalterados. O grafo de `Pronta quando` foi conferido
acíclico por script. Contagem: 71.

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

- [x] T001 Conferir os pré-requisitos já mergeados
  - **Pronta quando**: nada além do repositório
  - **Descrição**: confirmar, com `gh pr view <n> --json state,mergedAt,baseRefName`, que os PRs
    **#1038** (#1033, `Tenants.ensure_active/1`, FR-012), **#1039** (#1034, `Access.operacional?/2`
    compara o tenant, O5), **#1040** (#1035, `ApiTokens.criar/4` confere o dono, O15) e **#1044**
    (#1042, `Sessions.avisar_encerramento/1`, pré-requisito da A2) estão mergeados em
    `development`. Em 2026-10-01 os quatro deram `MERGED` (`gh pr view <n> --json state`,
    reconferido no fim do dia: #1038 22:36Z, #1039 22:36Z, #1040 22:37Z, #1044 22:37Z); a tarefa
    reconfere no dia em que a implementação começar, e confere no código de `origin/development`
    que existem `Tenants.ensure_active/1` (`tenants.ex:89-90`) e
    `Sessions.avisar_encerramento({:sessao, id})` (`sessions.ex:146-149`). Confere também o
    **#1051** (#1050, `Release.girar_sessoes/0` por `rpc`), que T032 estende: `MERGED` em
    2026-10-01 23:59Z
  - **Feita quando**: os quatro estão `MERGED` com `baseRefName = development`; as duas funções
    aparecem em `git grep` sobre `origin/development`; o resultado está colado na issue
  - **Teste**: `git grep -n "def ensure_active\|def avisar_encerramento" origin/development -- lib/`
    devolve as duas definições

- [x] T002 Esperar o merge da correção da espera paralela
  - **Pronta quando**: nada além do repositório
  - **Descrição**: o PR **#1048** (issue #1046, achado **A1** nas contas de organização) precisa
    estar mergeado em `development`. `Platform.Credentials` **copia** a política de
    `Tenants.Auth` (research R2), e a cópia tem de nascer da forma corrigida — `FOR UPDATE` ou
    incremento atômico com `RETURNING`, a que o #1048 escolher
  - **Feita quando**: `gh pr view 1048` dá `MERGED`; a forma escolhida pela #1048 está escrita em
    uma linha no comentário da issue desta tarefa, para T023 copiar
  - **Teste**: `gh pr view 1048 --json state,mergedAt` com `state = MERGED`
  - **Andamento (2026-10-01)**: **mergeado** em 2026-10-01 23:06Z (`gh pr view 1048 --json
    state` → `MERGED`). A forma é `FOR UPDATE`, com `Repo.transaction/1` devolvendo o resultado da
    verificação (conferido por T008, `contracts/credenciais-do-operador.md`). **Falta** o
    comentário na issue, que só existe depois de T006; por isso a tarefa continua aberta (L109)

- [x] T003 Esperar o merge da correção do custo na espera
  - **Pronta quando**: nada além do repositório
  - **Descrição**: a issue **#1047** (achado **A3** nas contas de organização: a espera responde sem
    custo de hash e revela se o e-mail existe) precisa de PR aberto e mergeado em `development`.
    Mesma razão de T002: a cópia nasce corrigida
  - **Feita quando**: o PR da #1047 está `MERGED` em `development`; o número dele está registrado
    nesta tarefa e em `plan.md`, "Pré-requisitos"
  - **Teste**: `gh pr list --head fix/1047-espera-paga-o-hash --state merged` devolve um PR
  - **Andamento (2026-10-01)**: o PR é o **#1049** (registrado aqui e em `plan.md`,
    "Pré-requisitos"). No `/speckit-analyze` ele constava aberto; reconferido no fim do dia,
    `gh pr view 1049 --json state` → **`MERGED`** (23:58Z), e a issue #1047 está fechada. Os dois
    critérios estão cumpridos; marcar `[x]` quando T006 der a issue em que se cola a saída

- [x] T003a Esperar o merge da rotação que recifra todos os campos cifrados — **bloqueante** (seguranca-totp.md T3)
  - **Pronta quando**: nada além do repositório
  - **Descrição**: a issue **#1052** (`bug` + `security`; achado **T3** de `seguranca-totp.md`,
    decisão da pessoa mantenedora em 2026-10-01: issue separada e anterior) precisa estar mergeada
    em `development` pelo PR **#1053**: `mix the_band.rotate_key` passa a recifrar **todos** os
    campos cifrados, inclusive `ai_provider_credentials.secret`, que é o defeito de hoje, e existe em
    produção. A 070 só **acrescenta** `platform_operators.totp_secret` a essa lista (T021), e a
    lista precisa existir antes. Pela regra "corrigir antes de implementar", vem antes da 070 na
    mesma superfície (Cloak). Em 2026-10-01 o PR #1053 está **aberto** (`gh pr view 1053 --json
    state` → `OPEN`)
  - **Feita quando**: `gh pr view 1053` dá `MERGED` com `baseRefName = development`; a forma da
    lista de campos (onde ela vive, como se acrescenta um) está escrita em uma linha no comentário
    da issue desta tarefa, para T021 copiar
  - **Teste**: `gh pr view 1053 --json state,mergedAt,baseRefName` com `state = MERGED`

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

- [x] T005 Decidir a forma da área do operador — **decidido em 2026-10-01: controllers + cookie próprio**; FR-011 emendada
  - **Pronta quando**: nada além do repositório. **Dono: a pessoa mantenedora** (plan.md, pergunta 1)
  - **Descrição**: escolher entre **(a)** controllers com cookie próprio `_the_band_operator` e
    **(b)** `live_session` com chaves dentro do cookie de domínio (research R3.2). A avaliação de
    segurança e o plano recomendam (a). Se (a), emendar a FR-011 em `spec.md` trocando
    "`live_session`" por "pipeline, plug e cookie próprios". Se (b), `contracts/rotas-da-plataforma.md`
    e `contracts/sessao-do-operador.md` são reescritos **antes** de T035
  - **Feita quando**: a decisão está registrada em `plan.md`, pergunta 1, com data e quem decidiu;
    a FR-011 e os contratos dizem a mesma coisa
  - **Teste**: `grep -n "live_session" spec.md contracts/*.md` não contradiz a decisão escrita

- [x] T006 Abrir o sprint backlog e as issues — feita em 2026-10-02: 74 issues (épico #1056, US1 #1057, US2 #1058, tarefas #1059–#1129) e `docs/sprints/035-operador-da-plataforma/sprint-backlog.md`; a iteration Sprint 035 fica pendente da pessoa mantenedora
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

- [x] T008 Conferir as emendas de segurança nos contratos — feita em 2026-10-01 pelo agente `security`; seção "Conferência das emendas" em seguranca-autenticacao.md, os seis bloqueantes cobertos
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

- [x] T009 Pesquisar a implementação do TOTP — feita em 2026-10-01: NimbleTOTP == 1.0.0, hex.audit e deps.audit com código 0; sem QR (recomendação, decisão no protótipo T012)
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

- [x] T010 Avaliar a segurança do TOTP antes do código — feita em 2026-10-01 pelo agente `security`, que não escreveu o desenho; seguranca-totp.md: T1 alta e T2 média emendadas nos contratos, T1 virou T028a (bloqueante), T3 entrou em T021; o resto fica para T011
  - **Pronta quando**: T009 concluída
  - **Descrição**: avaliação do agente `security`, **feita por quem não escreveu o desenho** do
    TOTP, em `specs/070-operador-da-plataforma/seguranca-totp.md`. Cobrir no mínimo: o segredo em
    repouso (Cloak) e por onde ele passa em claro; o cadastro em dois passos (**histórico**: era o
    desenho quando esta tarefa foi escrita; hoje são três, emenda T012, Q3 (b)) e o código de
    cadastro no campo oculto; a janela de ±1 e o reuso (`totp_last_used_step` sob `FOR UPDATE`);
    os códigos de recuperação (80 bits, `sha256`, consumo atômico); a falha do segundo fator no
    mesmo contador da senha; o abandono entre os passos; o reinício e a nova concessão (A6);
    a biblioteca escolhida em T009; e os cenários de ataque para o QA. FR-016, A16
  - **Feita quando**: o arquivo existe com achados, severidade e veredito; cada achado alto ou
    crítico virou tarefa **bloqueante** nesta lista (acrescentada por `/speckit-converge` ou à mão),
    citada no `Pronta quando` das tarefas que dependem dele
  - **Teste**: `seguranca-totp.md` existe, diz quem avaliou e que não é quem desenhou, e o
    `/speckit-analyze` não acha achado alto sem tarefa

- [x] T011 Emendar os contratos com o resultado do TOTP — feita em 2026-10-01 pelo agente `security`; seguranca-totp.md §3, "Emendas de T011", aponta o trecho de cada um (T4, T5, T6, T8; T9–T11 em plan.md "Riscos"; T12 novo, o passo 2 contando só em `failed_attempts`, mantido com a razão); cenários C14–C21 do código de guarda em §4. Limite: as emendas de T011 foram escritas e conferidas pelo mesmo agente — a conferência independente fica para a revisão do PR
  - **Pronta quando**: T009 e T010 concluídas
  - **Descrição**: aplicar a escolha da biblioteca e as emendas de `seguranca-totp.md` a
    `contracts/segundo-fator-do-operador.md`, `contracts/credenciais-do-operador.md`,
    `contracts/rotas-da-plataforma.md`, `contracts/eventos-de-acesso.md` e `data-model.md` §1 e
    §1a, **antes** de qualquer código. Se a avaliação não pedir emenda, registrar isso
  - **Feita quando**: os contratos não dizem mais "a decidir" sobre a biblioteca; cada emenda de
    `seguranca-totp.md` aponta o trecho de contrato que a cobre
  - **Teste**: `grep -n "a decidir\|NimbleTOTP, ou" contracts/ plan.md` só encontra a decisão
    tomada; o agente `security` confere as emendas, como em T008
  - **Andamento (2026-10-01)**: a metade da biblioteca está aplicada a
    `contracts/segundo-fator-do-operador.md` (NimbleTOTP `== 1.0.0`: comparação de `valid?/3`,
    janela ±1 por três chamadas, `since: ultimo_passo * 30`, sem QR até T012). **Continua aberta**:
    depende de T010, e as emendas de `seguranca-totp.md` ainda não existem
  - **Andamento (2026-10-01, depois de T010 e do protótipo)**: T009 e T010 feitas; T1 e T2
    emendados pela própria T010 (seguranca-totp.md §3) e decididos pela pessoa mantenedora; QR
    decidido (sem QR, `segundo-fator-do-operador.md`, `uri/2`); o cadastro em três passos (Q3 (b))
    aplicado a `credenciais-do-operador.md`, `data-model.md` §1, `concessao-do-operador.md` e
    `eventos-de-acesso.md`. **Continua aberta**: os achados que seguranca-totp.md §3 deixou para
    esta tarefa — **T4** (`load_in_query: false` em `totp_secret`), **T5** (segredo e códigos só na
    resposta do `POST`, nunca por flash, sessão, redirect ou `GET`), **T6** (`[0-9]` literal em
    `classificar/1`), **T8** (`invalidated_at` em §1a, separado de `used_at`), **T9** e **T11**
    (texto do roteiro) — não estão em contrato nenhum (`grep` por `load_in_query`,
    `invalidated_at`, `put_flash` e `[0-9]` em `contracts/` e `data-model.md` não acha nada), e o
    agente `security` ainda não conferiu as emendas
  - **Andamento (2026-10-01, fechamento)**: T4, T5, T6 e T8 aplicados e apontados em
    seguranca-totp.md §3 ("Emendas de T011"); T9–T11 registrados como riscos residuais em `plan.md`,
    "Riscos", e levados a T059 e T062; o fluxo de três passos reconferido contra A1, A3 e A5 (§2,
    "o terceiro passo"), com uma emenda (o custo do hash nas recusas do passo 2 não estava escrito);
    a contagem do passo 2 só em `failed_attempts` avaliada como T12 e mantida, com a razão no
    contrato; "dois passos" corrigido em research R13, `plan.md` item 14 e T063. O `grep` do Teste
    acha só "quem precisa **decidir** chama `autenticar/3`" (`credenciais-do-operador.md`, "NÃO
    expõe"), que não é sobre a biblioteca

- [x] T012 Prototipar as telas do operador — **aprovado em 2026-10-01** (versão 2, https://claude.ai/artifact/KWYR2rPJX1V4FukhszDVFA)
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
  - **Andamento (2026-10-01)**: protótipo **v2 publicado** em
    https://claude.ai/artifact/KWYR2rPJX1V4FukhszDVFA, guardado em `prototipo/`, **aguardando
    aprovação** da pessoa mantenedora. Decisões já tomadas sobre ele: sem QR (base32 + URI em
    texto); `confirm_slug` nos dois atos (Q2 (a)); cadastro em três passos, com a confirmação de
    guarda dos códigos de recuperação (Q3 (b)); contagens de sessões e tokens só no evento (Q4 (b)).
    As três primeiras já estão emendadas nos contratos

- [x] T013 [P] Restringir o estado da organização
  - **Pronta quando**: T007 concluída; `contracts/sessoes-e-tokens-da-organizacao.md`, seção
    `TheBand.Tenants.Tenant`
  - **Descrição**: migração `priv/repo/migrations/<ts>_estado_da_organizacao_valido.exs` com
    `CHECK (status IN ('active','suspended'))` de nome `tenants_status_valido`; o `up` **conta** os
    valores fora da lista e **levanta** com a contagem (nunca mapeia); `down` explícito.
    `lib/the_band/tenants/tenant.ex`: `:status` sai do `cast`, entra `validate_inclusion/3` e
    `check_constraint/3`. Ajustar os **dois** testes que suspendem pelo changeset e deixam de
    suspender quando `:status` sai do `cast`: `test/the_band/tenants/organizacao_suspensa_test.exs:44`
    e `test/the_band_web/api/organizacao_suspensa_test.exs:38` (`mudar_status/2`, usado em `:52` e
    `:71`), para escreverem o estado por `update_all` com comentário dizendo por quê, como
    `test/the_band/jobs/organizacao_inativa_test.exs:56` já faz (research R6; achado C2). O10. O episódio `not_recorded` para as já suspensas fica em T044, que cria a
    tabela. Esses testes continuam verdes depois do trigger adiado de T044a só porque
    o sandbox não faz `COMMIT`: o comentário deles diz isso (`data-model.md` §4a)
  - **Feita quando**: `Tenant.changeset(t, %{status: "suspended"})` não muda o estado; um `UPDATE`
    com `'Suspended'` reprova no banco; a migração com uma linha `status = 'x'` levanta dizendo
    quantas; os dois testes ajustados continuam verdes, e a guarda deles (`assert t.status ==
    status`, `assert suspenso.status == "suspended"`) continua lá
  - **Teste**: `test/the_band/tenants/estado_da_organizacao_test.exs` — os três casos, e `mix
    ecto.migrate` seguido de `mix ecto.rollback --step 1` sem erro. **Defeito a injetar**: devolver
    `:status` ao `cast`; o primeiro caso precisa reprovar

- [x] T014 [P] Declarar as razões de suspensão na base — lista aprovada pela pessoa mantenedora em 2026-10-01, como em data-model §5
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

- [x] T015 [P] Declarar a cláusula de revogação só registrada
  - **Pronta quando**: T007 concluída; `data-model.md` §6, `api_access_tokens`
  - **Descrição**: `priv/knowledge_base/rules/api_access_thresholds.yaml` ganha
    `clausulas_so_registradas: [organizacao_suspensa]` com rótulo pt-BR e en. FR-013
  - **Feita quando**: a chave existe; `ApiTokens.clausulas_de_revogacao/0` continua devolvendo só as
    oferecidas (afirmado em T047)
  - **Teste**: `mix knowledge.validate` dá `0`, e o teste de T047 lê a chave

- [x] T016 [P] Ensinar o log a dizer o operador e a calar o segredo
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

- [x] T017 [P] Compartilhar a CSP entre as duas pipelines
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
    `totp_last_used_step`, `second_factor_failures` (seguranca-totp.md T1), `enrollment_code_hash`,
    `enrollment_code_expires_at`, `ack_code_hash` e `ack_code_expires_at` (código de guarda, emenda
    T012) e os `CHECK`s de `data-model.md` §1, inclusive o par do código de guarda e o que só o
    admite entre os passos 2 e 3;
    a tabela `platform_operator_recovery_codes` com os índices. FR-016
  - **Feita quando**: `totp_confirmed_at` preenchido com `totp_secret` nulo reprova no banco;
    `ack_code_hash` preenchido com `totp_confirmed_at` preenchido reprova no banco; o índice
    único `(operator_id, code_hash)` recusa o repetido
  - **Teste**: round trip `mix ecto.migrate` / `mix ecto.rollback --step 1`;
    `test/the_band/platform/tabelas_do_segundo_fator_test.exs` com os dois casos. **Defeito a
    injetar**: retirar o `CHECK` do segredo; o primeiro caso precisa gravar e o teste reprovar

- [ ] T021 [US2] Escrever os schemas do contexto da plataforma
  - **Pronta quando**: T018 e T020 concluídas; **T003a concluída** (a #1052, PR #1053, mergeada: a
    lista de campos cifrados da rotação existe) e a branch rebaseada de novo sobre
    `origin/development`, como T007
  - **Descrição**: `lib/the_band/platform/operator.ex`, `grant.ex`, `operator_session.ex`,
    `recovery_code.ex`, privados ao contexto. `redact: true` em `password_hash`, `setup_code_hash`,
    `enrollment_code_hash`, `ack_code_hash`, `totp_secret`, `token_hash` e `code_hash`; `totp_secret` com
    `TheBand.Encrypted.Binary` e **`load_in_query: false`** (T4 de seguranca-totp.md, emenda T011;
    cenário C13, no teste de `OperatorScope` de T036); `recovery_code.ex` com `used_at` **e**
    `invalidated_at` (T8). Nenhum `has_many` para tabela de domínio. **T3 de seguranca-totp.md
    (bloqueia a release)**: `platform_operators.totp_secret` entra na lista de campos que
    `mix the_band.rotate_key` recifra, na forma que a #1052 (T003a) deixou. Decidido em
    2026-10-01: a lista de **todos** os campos cifrados (inclusive `ai_provider_credentials.secret`)
    é a issue #1052, separada e anterior; esta tarefa só acrescenta `totp_secret` a ela. O
    cenário C10, que **entra** depois de rotacionar, precisa de `autenticar/3` e fica em T023a
  - **Feita quando**: `inspect/1` de cada struct não mostra nenhum dos campos redigidos; a leitura
    direta de `platform_operators.totp_secret` devolve texto cifrado; depois de
    `mix the_band.rotate_key`, a coluna decifra com a chave nova sozinha, e a tarefa reporta a
    contagem de `platform_operators`
  - **Teste**: `test/the_band/platform/schemas_test.exs` — `refute inspect(op) =~ "<valor>"` para
    cada campo, e a leitura crua da coluna difere do segredo em claro; e um caso na suíte da
    rotação que a #1052 criou, com um operador semeado

- [ ] T022 [US2] Conferir o código do segundo fator
  - **Pronta quando**: `contracts/segundo-fator-do-operador.md` emendado por T011; T010 sem achado
    alto aberto; a dependência fixada em `mix.exs` com a versão de T009: `{:nimble_totp, "== 1.0.0"}`
    (sem `~>`: versão nova só com `mix hex.audit` e `mix deps.audit` refeitos; plan.md, Technical Context)
  - **Descrição**: `lib/the_band/platform/segundo_fator.ex`, **funções puras**: `gerar_segredo/0`,
    `uri/2`, `conferir/4` (janela ±1, `:reusado` para passo `<= ultimo_passo`, `agora` como
    argumento), `classificar/1` (só ASCII, conferido antes de normalizar: T6, cenário C11),
    `gerar_codigos_de_recuperacao/0`, `resumo/1`. Cenário **C2** de seguranca-totp.md (T2: 128 bits
    por código). FR-016
  - **Feita quando**: os vetores do RFC 6238, apêndice B (SHA-1), conferem (os seis últimos dígitos
    de cada vetor de oito, porque NimbleTOTP fixa seis); um código do passo
    `atual + 2` é recusado; o mesmo código com `ultimo_passo` igual ao passo dele devolve `:reusado`;
    **C2**: `gerar_codigos_de_recuperacao/0` dá 10 códigos distintos, cada um decodifica para **16**
    bytes, e `classificar/1` dá `:recuperacao` para os 26 caracteres com e sem hífen e `:malformado`
    para um código de 16 caracteres
  - **Teste**: `test/the_band/platform/segundo_fator_test.exs` com o relógio fixado. **Defeitos a
    injetar**, um por vez: alargar a janela para ±2 (o caso `atual + 2` precisa passar e o teste
    reprovar); retirar a comparação com `ultimo_passo` (o caso de reuso precisa passar e o teste
    reprovar); **voltar a 10 bytes** por código de recuperação (C2 precisa reprovar)

- [ ] T033 [P] [US2] Registrar os eventos de acesso do operador
  - **Pronta quando**: `contracts/eventos-de-acesso.md` emendado (A7) e conferido por T008; T016
    concluída
  - **Descrição**: em `lib/the_band/tenants/access_events.ex`, as funções do contrato, todas em
    `:warning`, inclusive `operador_senha_definida/1`, `operador_definicao_recusada/2`,
    `operador_segundo_fator_cadastrado/1`, `operador_cadastro_recusado/2` e
    `operador_recuperacao_usada/2`. **Só as funções de evento**: quem as chama (T023, T026, T030)
    depende desta tarefa, e não o contrário. A asserção de que `definir_senha/3` emite o evento é de
    T026 (achado O3 do `/speckit-analyze`: a versão anterior desta tarefa exigia `definir_senha/3`,
    e fechava o ciclo T023 → T033 → T026 → T023). FR-010, O14
  - **Feita quando**: cada função do contrato, chamada **direto** em `AccessEvents` com os
    argumentos do contrato, emite uma linha em `:warning` com o nome do evento e o motivo
    (`operador_definicao_recusada(op, :codigo_errado)` dá a linha com `:codigo_errado`); passando
    código, senha e segredo de fixture nos argumentos que os aceitam, nenhum deles aparece em nenhuma
    linha capturada
  - **Teste**: `test/the_band/platform/eventos_do_operador_test.exs` com `capture_log`, chamando
    `AccessEvents` direto, sem `Credentials`, e `refute log =~ codigo` (cenário 12). **Defeito a
    injetar**: incluir o código no metadado de `operador_definicao_recusada/2`; o `refute` precisa
    reprovar

- [ ] T023 [US2] Conferir a entrada do operador
  - **Pronta quando**: **A1** e **A3** emendados em `contracts/credenciais-do-operador.md` e
    conferidos por T008; T002 (#1048) e T003 (#1047) mergeadas e T007 rebaseada, para copiar a
    forma corrigida; T021, T022 e **T033** concluídas (os eventos que esta tarefa emite; achado O3)
  - **Descrição**: `lib/the_band/platform/credentials.ex`, `autenticar/3`: transação com
    `SELECT … FOR UPDATE` na linha do operador **antes** da espera e do hash (A1);
    `Bcrypt.no_user_verify/0` também na recusa por espera (A3); recusa única; segundo fator só
    depois da senha; código de recuperação consumido com `UPDATE … WHERE used_at IS NULL
    RETURNING`; **com `totp_confirmed_at` nulo, recusa antes de classificar o segundo fator e antes
    de qualquer consumo de código de recuperação** (os códigos já têm hash desde o passo 2 do
    cadastro, e não valem até `concluir_cadastro/2`); sem concessão vigente não conta falha; sucesso grava `totp_last_used_step`, zera
    falhas depois de registrar quantas e grava `logged_in_at`; o limite próprio do segundo fator
    (`second_factor_failures`, trava em 10, **T1** de seguranca-totp.md). Comentário apontando para
    `Tenants.Auth` e o motivo da duplicação (research R2). FR-011, FR-016
  - **Feita quando**: operador sem concessão, sem senha, sem segundo fator confirmado (inclusive
    depois do passo 2, com TOTP certo **e** com um código de recuperação válido, que continua sem
    `used_at`), com senha errada, com TOTP errado e com TOTP reusado recebem todos
    `{:error, :invalid_credentials}`; o
    motivo interno de cada um aparece no evento; o sucesso devolve `{:ok, %Operator{}}`
  - **Teste**: `test/the_band/platform/credentials_autenticar_test.exs`, um caso por motivo

- [ ] T023a [US2] Provar que a rotação da chave alcança o segredo TOTP — **bloqueia a release** (seguranca-totp.md T3)
  - **Pronta quando**: T003a, T021 e T023 concluídas
  - **Descrição**: cenário **C10** de seguranca-totp.md: cifrar com a chave A, cadastrar o segundo
    fator de um operador, rotacionar para B com `mix the_band.rotate_key`, remover A do ambiente, e
    entrar por `autenticar/3` com o TOTP do segredo. Separado de T021 porque precisa da entrada
    (achado O1 do `/speckit-analyze`)
  - **Feita quando**: o operador entra com o TOTP depois da rotação sem a chave antiga; a tarefa de
    rotação reporta a contagem de `platform_operators`
  - **Teste**: `test/the_band/platform/rotacao_da_chave_test.exs`. **Defeito a injetar**: tirar
    `platform_operators` da lista da rotação; a entrada precisa falhar e o teste reprovar. É o
    critério "C10 verde" de T064

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
    conferidos por T008; T011 concluída; T023 e **T033** concluídas (os eventos de A7; achado O3)
  - **Descrição**: `definir_senha/3`, `confirmar_segundo_fator/3` e `concluir_cadastro/2` em
    `credentials.ex`, os **três passos** do cadastro (emenda T012, Q3 (b);
    `contracts/segundo-fator-do-operador.md`, "O fluxo de cadastro"), como o contrato: exigem
    concessão vigente (A14); consomem o código de definição, o de cadastro e o de guarda de forma
    **atômica** dentro da transação com `FOR UPDATE` (A5); a política de senha roda antes do
    consumo; o primeiro passo não habilita a entrada; o segundo grava `totp_last_used_step` e os dez
    `sha256` dos códigos de recuperação, anula o código de cadastro e emite o código de guarda, **sem**
    gravar `totp_confirmed_at`, **sem** subir a época e **sem** encerrar sessões; o terceiro consome o
    código de guarda, grava `totp_confirmed_at`, sobe `password_epoch` e encerra as sessões do
    operador. Eventos de A7 (T033). Cenários C14, C19, C20 e C21 de seguranca-totp.md
    (reconferência de T011; C15 está em T027, C17 em T039; **C16 e C18**, que pedem
    `reiniciar_credencial/2` e `revogar/3`, estão em T030a, depois de T030 — achado O1). FR-016, O4
  - **Feita quando**: depois só do primeiro passo, `autenticar/3` recusa; depois do segundo,
    `autenticar/3` **ainda recusa**, com o TOTP certo e com um código de recuperação dos dez, e o
    código de recuperação continua sem `used_at`; depois do terceiro, autentica com o TOTP e com um
    código de recuperação; o código de definição usado uma vez é recusado na segunda; o código de
    cadastro não abre o passo 3; operador sem concessão vigente recebe a recusa única no primeiro
    passo e no terceiro; um código de definição errado em `definir_senha/3` produz, no
    `capture_log`, `operador_definicao_recusada` com `:codigo_errado` (vinda de T033, achado O3)
  - **Teste**: `test/the_band/platform/credentials_definir_test.exs`, um caso por frase acima.
    **Defeitos a injetar**, um por vez: gravar `totp_confirmed_at` em `confirmar_segundo_fator/3`;
    o caso "depois do segundo, ainda recusa" precisa autenticar e o teste reprovar. Retirar a
    chamada a `AccessEvents.operador_definicao_recusada/2` em `definir_senha/3`; o caso do código
    de definição errado precisa reprovar (vindo de T033)

- [ ] T027 [US2] Provar o código de uso único sob concorrência
  - **Pronta quando**: T026 concluída
  - **Descrição**: cenário 3 de `seguranca-autenticacao.md` (**A5**): duas `Task` chamam
    `definir_senha/3` com o mesmo código e senhas diferentes; o mesmo para o código de cadastro em
    `confirmar_segundo_fator/3` e para o código de guarda em `concluir_cadastro/2`
  - **Feita quando**: exatamente uma devolve `{:ok, _}` e a outra `{:error, :invalid_credentials}`
    (os dois lados contados, L90); `setup_code_hash` fica nulo; vale a senha da que ganhou
  - **Teste**: `test/the_band/platform/codigo_de_uso_unico_test.exs`. **Defeito a injetar**: conferir
    o resumo em memória e gravar depois, sem lock; as duas precisam passar e o teste reprovar

- [ ] T028 [US2] Provar o segundo fator na entrada
  - **Pronta quando**: T026 e T033 concluídas (C9 afirma o evento); os cenários de
    `seguranca-totp.md` (T010): C3, C4, C5, C9, C12. **C6 e C7** pedem `revogar/3` e
    `reiniciar_credencial/2` e estão em T030a; **C8** pede os controllers e está em T039 (achado O1)
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
    `encerrar/1`, `encerrar_do_operador/1` (recebe `%Operator{}`; chamadores no contrato:
    `revogar/3`, `conceder/3`, `reiniciar_credencial/2`, `definir_senha/3`, `concluir_cadastro/2`),
    `encerrar_todas/0` (só para o giro de `Release`, T032), `apagar_as_que_deixaram_de_valer/1`.
    Constantes de 8 h e 30 min nomeadas, com o motivo. FR-011, FR-014
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
    (encerra sessões e anula códigos pendentes — de definição, de cadastro e de guarda —, A14,
    FR-014), `vigente?/1`. `conceder/3` e `reiniciar_credencial/2` também anulam o código de guarda
    (emenda T012). FR-001, FR-002
  - **Feita quando**: revogar encerra a sessão do operador na mesma transação; conceder duas vezes
    seguidas devolve `{:error, :ja_concedido}`
  - **Teste**: `test/the_band/platform/grants_test.exs`, os dois casos

- [ ] T030a [US2] Provar a revogação e o reinício no meio do cadastro
  - **Pronta quando**: T030 concluída (e, por ela, T026); cenários C6, C7, C16 e C18 de
    seguranca-totp.md
  - **Descrição**: os cenários do cadastro em três passos que dependem de `revogar/3` e de
    `reiniciar_credencial/2`, tirados de T026 e T028 para desfazer a ordem circular (achado O1 do
    `/speckit-analyze`). **C6**: passo 1 → `revogar/3` → passo 2 com código de cadastro e TOTP
    certos; depois `conceder/3` e o mesmo par antigo. **C7**: o mesmo com `reiniciar_credencial/2`.
    **C16**: passo 2 em `agora`, passo 3 em `agora + 10 min + 1 s` com o código de guarda certo;
    depois `reiniciar_credencial/2` e os três passos de novo (a guarda). **C18**: passo 2 →
    `revogar/3` (e, noutro caso, `reiniciar_credencial/2`) → passo 3 com o código de guarda certo.
    FR-016, A14
  - **Feita quando**: C6 e C7 recusados, `refute` `totp_confirmed_at`, e depois da nova concessão
    `totp_secret` nulo; C16 recusa única e `refute` `totp_confirmed_at`, e o refeito entra; C18
    recusa única, `ack_code_hash` nulo depois do ato e nenhum código de recuperação vale em
    `autenticar/3`
  - **Teste**: `test/the_band/platform/cadastro_interrompido_test.exs`. **Defeitos a injetar**, um
    por vez: `revogar/3` sem anular `enrollment_code_hash` (C6); `reiniciar_credencial/2` sem anular
    o código de cadastro (C7); retirar a conferência de `ack_code_expires_at` (C16); `revogar/3` sem
    anular `ack_code_hash` (C18)

- [ ] T028a [US2] Provar o limite próprio do segundo fator — **bloqueante** (seguranca-totp.md T1, alta)
  - **Pronta quando**: T023 concluída com `second_factor_failures`; **T030 concluída** (a asserção
    "`reiniciar_credencial/2` destrava" precisa dela; achado O1); `contracts/credenciais-do-operador.md`,
    "limite próprio do segundo fator"
  - **Descrição**: cenários C1 e C1b de `seguranca-totp.md`. C1: senha certa e 10 TOTP errados,
    avançando `agora` além da espera a cada vez; depois o TOTP **certo**. C1b: 10 senhas erradas com
    qualquer código, e depois senha e TOTP certos. **Bloqueia T036 e T039**: a área do operador não
    vai ao ar sem este limite provado
  - **Feita quando**: em C1, antes da 10ª falha um código certo entra (a guarda de que mediu), e
    depois dela o certo é recusado com `:invalid_credentials`, evento `:segundo_fator_travado`, sem
    sessão aberta; `reiniciar_credencial/2` destrava. Em C1b, `second_factor_failures` fica 0 e a
    entrada legítima passa
  - **Teste**: `test/the_band/platform/limite_do_segundo_fator_test.exs`. **Defeitos a injetar**, um
    por vez: contar só em `failed_attempts` (o 11º passa e C1 reprova); incrementar o contador antes
    de conferir a senha (C1b reprova)

- [ ] T031 [US2] Provar que conceder de novo não devolve credencial
  - **Pronta quando**: T030 concluída
  - **Descrição**: cenário 4 de `seguranca-autenticacao.md` (**A6**): conceder, definir senha e
    segundo fator, revogar, conceder de novo
  - **Feita quando**: `autenticar(email, senha_antiga, totp_do_segredo_antigo)` devolve
    `{:error, :invalid_credentials}`; nenhuma sessão de antes passa em `conferir/2`; os códigos de
    recuperação antigos não usados têm `invalidated_at`, e o usado guarda o `used_at` (T8)
  - **Teste**: `test/the_band/platform/conceder_de_novo_test.exs`. **Defeitos a injetar**, juntos e
    depois um por vez: não anular `password_hash` nem `totp_secret` em `conceder/3`; juntos, a
    entrada antiga precisa autenticar e o teste reprovar; um por vez, a asserção sobre a coluna
    correspondente precisa reprovar

- [ ] T032 [US2] Comandos de operação para o papel
  - **Pronta quando**: T030 concluída; `contracts/concessao-do-operador.md`, seção `TheBand.Release`;
    a **#1050** (PR **#1051**) em `development` — criou `Release.girar_sessoes/0`, por `rpc`, que esta
    tarefa estende (`MERGED` em 2026-10-01 23:59Z; T001 reconfere)
  - **Descrição**: em `lib/the_band/release.ex`, `conceder_operador/3`,
    `reiniciar_credencial_do_operador/2` e `revogar_operador/3`, na forma de `release.ex:106-125` de
    `development`; nunca recebem senha; imprimem e-mail, ato e, uma vez, o código de definição com a
    validade. `encerrar_todas_as_sessoes/0` (por `eval`, aplicação parada) **e**
    `girar_sessoes/0` (por `rpc`, no nó que serve) passam a encerrar também as do operador, por
    `Platform.Sessions.encerrar_todas/0`, e a frase de saída diz as duas contagens. A suspensão e a
    reativação pelo operador **não** precisam de `rpc`: são um `POST` atendido pelo nó que serve, e o
    aviso do #1044 sai do PubSub desse nó. FR-001, O11
  - **Feita quando**: a saída de `conceder_operador/3` não contém senha e contém o código uma vez;
    `girar_sessoes/0` e `encerrar_todas_as_sessoes/0` encerram uma sessão de operador aberta e
    dizem a contagem; nenhum módulo de `TheBandWeb` referencia `TheBand.Platform.Grants`
  - **Teste**: `test/the_band/release_operador_test.exs` com `ExUnit.CaptureIO`, e um teste sobre a
    saída de `mix xref callers TheBand.Platform.Grants` que afirma zero chamadores sob
    `lib/the_band_web/`. **Defeito a injetar**: chamar `Grants.vigente?/1` de um controller de
    rascunho; o teste precisa reprovar

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
    conferido por T008; T017 e T035 concluídas; **T028a** concluída (seguranca-totp.md T1)
  - **Descrição**: `lib/the_band_web/plataforma/operator_scope.ex` (plug que atribui
    `:current_operator` e grava `Logger.metadata(operator_id: …)`, nunca `user_id` nem
    `tenant_id`) e `require_operator/2` (`404` com `ErrorHTML`, sem redirecionar);
    `router.ex`: pipeline `:plataforma` sem `CurrentScope`, com a CSP compartilhada e
    `Cache-Control: no-store`; o escopo `/platform` com as rotas do contrato e o
    `match :*, "/platform/*caminho"` **por último** (A12). Controllers ainda vazios, que respondem
    `404` até T039 e T040. FR-009, FR-011
  - **Feita quando**: `GET /platform/organizations` anônimo dá `404`; um admin de organização com
    sessão válida recebe o mesmo `404`; nenhuma rota de `/platform` passa por `CurrentScope`;
    `current_operator.totp_secret` é `nil` (C13 de seguranca-totp.md, T4)
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

- [ ] T038a [P] [US2] Ler as organizações para a área do operador, do lado de `Tenants`
  - **Pronta quando**: `contracts/sessoes-e-tokens-da-organizacao.md`, seção
    `resumos_para_a_plataforma/0` e `resumo_para_a_plataforma/1` (emenda D1); T007 concluída
  - **Descrição**: em `lib/the_band/tenants.ex`, `resumos_para_a_plataforma/0` (todas, por `name`) e
    `resumo_para_a_plataforma/1` (pelo `slug`, `{:error, :not_found}` se não houver), com `select`
    explícito de `id`, `name`, `slug` e `status` num mapa; sem `join`, sem contagem, sem `%Tenant{}`.
    É a leitura que `Platform.Suspensions` usa no lugar de consultar `tenants` (constituição,
    princípio X, letra D; achado D1). FR-007
  - **Feita quando**: com duas organizações, cada resumo tem **exatamente** as chaves `:id`,
    `:name`, `:slug` e `:status`; o SQL capturado por telemetria cita só essas colunas de `tenants`;
    slug inexistente dá `{:error, :not_found}`; `mix xref callers` sobre
    `resumos_para_a_plataforma/0` e `resumo_para_a_plataforma/1` não mostra **nenhum chamador fora de
    `TheBand.Platform`** em `lib/` (achado D1-b de `seguranca-autenticacao.md`: a leitura existe para
    a área do operador, e uma tela de domínio que a use contorna o escopo por tenant)
  - **Teste**: `test/the_band/tenants/resumos_para_a_plataforma_test.exs`, mais um caso sobre a saída
    de `mix xref callers` das duas funções. **Defeitos a injetar**, um por vez: devolver
    `Repo.all(Tenant)` sem o `select` (a asserção das chaves e a das colunas precisam reprovar);
    chamar `Tenants.resumos_para_a_plataforma/0` de uma tela de domínio de rascunho em
    `lib/the_band_web/live/` (o caso do `xref` precisa reprovar)

- [ ] T039 [US2] Telas de entrada, definição e cadastro
  - **Pronta quando**: **T012 aprovado** (protótipo); T023, T026, T028a e T036 concluídas;
    `contracts/rotas-da-plataforma.md`
  - **Descrição**: controllers e templates em `lib/the_band_web/controllers/plataforma/` para
    `GET /platform/sign-in`, `POST /platform/session`, `GET /platform/setup`, `POST /platform/setup`,
    `POST /platform/setup/second-factor`, `POST /platform/setup/recovery-codes` (o passo 3,
    `Credentials.concluir_cadastro/2`, emenda T012 Q3 (b)) e `DELETE /platform/session`, exatamente
    como o protótipo. Campos `email`, `password`, `setup_token`, `enrollment_token`,
    `acknowledgement_token`, `codes_stored` e `second_factor_token` (A10). O segredo em base32 e a
    URI em texto, **sem QR**; os códigos de recuperação e o segredo aparecem **uma vez**. O
    controller do passo 3 confere `codes_stored` **antes** de chamar o contexto: sem a caixa,
    re-renderiza a recusa da caixa com o `acknowledgement_token`, sem os códigos, sem consumir nada.
    **T5 (emenda T011)**: o segredo, a URI e os códigos saem só na resposta renderizada do `POST`,
    nunca por flash, sessão, redirect ou `GET` (`rotas-da-plataforma.md`, "A exibição única");
    cenários C8 e C17 de seguranca-totp.md. Texto em inglês, com o comentário de que é tela
  - **Feita quando**: o fluxo inteiro, do código de definição à confirmação da guarda dos códigos e
    à entrada com TOTP, funciona no navegador; antes do passo 3, a entrada é recusada; sem a caixa,
    o passo 3 não consome o código de guarda e a resposta não traz os códigos; a recusa é a mesma
    frase em todos os casos; o segredo não aparece em nenhuma resposta depois da tela de cadastro, e
    os códigos de recuperação em nenhuma depois da resposta de `POST /platform/setup/second-factor`
  - **Teste**: `test/the_band_web/plataforma/entrada_e_definicao_test.exs` com `Phoenix.ConnTest`;
    `refute html =~ segredo` na resposta da entrada e na do `GET /platform/setup`

- [ ] T040 [US2] Tela da lista de organizações
  - **Pronta quando**: **T012 aprovado**; T029, T036 e **T038a** concluídas; `contracts/suspensao.md`,
    `listar_organizacoes/1`
  - **Descrição**: `lib/the_band/platform/suspensions.ex` com `listar_organizacoes/1` (confere a
    autorização por dentro; **compõe** com `Tenants.resumos_para_a_plataforma/0`, de T038a, e
    **não** consulta a tabela `tenants` nem usa o schema `Tenant`: constituição, princípio X, letra
    D, achado D1; nunca `%Tenant{}` nem `Tenants.list_tenants/0`), fachada `lib/the_band/platform.ex`
    com `defdelegate`, e o controller de `GET /platform/organizations`. O último episódio vem da
    própria `Platform`, em `tenant_suspensions`, e entra em T056, depois de T044; aqui
    `ultimo_episodio_em` é sempre "nunca suspensa" com `<.absent>`. FR-007, US2 cenário 2
  - **Feita quando**: o operador vê nome, slug e estado de todas as organizações; nenhuma coluna de
    domínio aparece; a ausência de episódio está escrita, e não em branco nem `—`
  - **Teste**: `test/the_band_web/plataforma/lista_de_organizacoes_test.exs` — duas organizações, e
    `refute html =~` o nome de uma pessoa de cada

- [ ] T041 [US2] Provar que o operador não lê domínio
  - **Pronta quando**: **A9** emendado em research R10 e conferido por T008; T039 e T040 concluídas
  - **Descrição**: `test/the_band_web/plataforma/operador_nao_le_dominio_test.exs`, research R10
    emendado: handler em `[:the_band, :repo, :query]` filtrado pelo processo; **lista permitida por
    rota** (os `GET` e os `POST` de entrada e definição só com `platform_*`, `tenant_suspensions` e
    `tenants`; `tenants` só pelas leituras de T038a, e nos `GET` o `SELECT` sem outra coluna de
    `tenants` além de `id`, `name`, `slug` e `status`, emenda D1); `source` nulo reprova (L56); **toda consulta reprova se o SQL citar `"users"`**;
    guarda de que mediu (um membro de A registra consulta fora da lista, L50). SC-003, FR-007. Os
    dois `POST` de ato ganham a lista deles em T051
  - **Feita quando**: a coleta das rotas do operador tem mais de zero consultas e nenhuma fora da
    lista da rota; a guarda com o membro de A registra consultas de domínio
  - **Teste**: o próprio arquivo. **Defeitos a injetar**, um por vez, e cada um precisa reprovar:
    `OperatorScope` chama `TheBandWeb.Sessao.conferir/1` (cenário 7 da avaliação);
    `listar_organizacoes/1` pré-carrega `users`; `Tenants.resumos_para_a_plataforma/0` devolve
    `%Tenant{}` inteiro

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
    proxy do Dokploy; limite por IP nos **quatro** `POST` que o contrato lista: `POST /platform/session`,
    `POST /platform/setup`, `POST /platform/setup/second-factor` e
    `POST /platform/setup/recovery-codes` (achado C1), e a espera por conta passa a ser por conta **e** IP, o que
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
    coluna, liberando `updated_at`, A13b) e `nao_trunca` (A13a); e o `up` insere um episódio
    `not_recorded`, sem autor, para cada organização já `suspended` sem episódio. Schema
    `lib/the_band/platform/suspension.ex`. **Não toca `api_access_tokens`**: a coluna
    `revoked_by_suspension_id` é de `Tenants` e nasce em T047, numa migração própria (achado L1;
    constituição, princípio X, letra D; `plan.md`, Constitution Check). FR-006, SC-002
  - **Feita quando**: a consulta de `data-model.md` §7 devolve `0` depois da migração, inclusive com
    uma organização suspensa antes dela; o `down` volta ao estado anterior
  - **Teste**: round trip `mix ecto.migrate` / `mix ecto.rollback --step 1`, com uma organização
    `suspended` semeada antes; `test/the_band/platform/migracao_do_episodio_test.exs`

- [ ] T044a [US1] O banco recusa estado sem episódio — trigger de constraint adiado (D1-a)
  - **Pronta quando**: `data-model.md` §4a; T013 e **T044** concluídas (a migração desta roda
    **depois** da de T044, que cria `tenant_suspensions` e insere os `not_recorded`)
  - **Descrição**: `priv/repo/migrations/<ts>_estado_tem_episodio.exs`, migração **da `Platform`**
    (exceção declarada à letra D, só no banco: `plan.md`, Constitution Check e decisão 16): a função
    `tenant_estado_tem_episodio()` e os dois `CONSTRAINT TRIGGER … DEFERRABLE INITIALLY DEFERRED`, em
    `tenants` (`AFTER INSERT OR UPDATE OF status`) e em `tenant_suspensions` (`AFTER INSERT OR UPDATE
    OF reactivated_at`), como `data-model.md` §4a. O `up`, **antes** de criar os triggers, roda a
    consulta de §7 e a recíproca e **levanta** com as contagens se alguma não der zero (o trigger não
    confere linhas antigas); o `down` apaga os triggers e a função. Decisão da pessoa mantenedora em
    2026-10-01 (achado D1-a de `seguranca-autenticacao.md`). O10, SC-002
  - **Feita quando**: dentro de uma transação, `Repo.update_all` direto em `tenants.status` para
    `suspended`, sem episódio, é **recusado** quando a conferência acontece (erro com o nome
    `tenant_estado_tem_episodio`); o mesmo para reativar por `update_all` com o episódio aberto, e
    para abrir um episódio numa organização `active`; a sequência legítima — `status` primeiro, depois
    o episódio, na mesma transação — **passa**; `Tenants.create_tenant/1` de uma organização `active`
    **passa**, e o `INSERT` de uma organização já `suspended` sem episódio é **recusado** (achado T1
    da terceira reanálise: toda escrita em `tenants` passa pelo trigger, e a criação é a mais comum); o round trip `mix ecto.migrate` / `mix ecto.rollback
    --step 1` volta ao estado anterior; com uma organização `suspended` sem episódio semeada antes, o
    `up` levanta dizendo quantas
  - **Teste**: `test/the_band/platform/estado_tem_episodio_test.exs`. O sandbox nunca faz `COMMIT`,
    então cada caso força a conferência com `SET CONSTRAINTS ALL IMMEDIATE` no fim da transação (é
    o `COMMIT` visto de dentro do sandbox). **Por `ALL`, e não pelo nome** (G3 da conferência de
    2026-10-02): pelo nome, com o trigger removido o comando falha com `constraint … does not exist`,
    que também é `Postgrex.Error`, e o caso de recusa ficaria verde sem a defesa. E a asserção é
    sobre `postgres.constraint == "tenant_estado_tem_episodio"`, e não só sobre a classe do erro.
    Mais dois casos: uma tabela temporária `tenant_suspensions` com linha aberta na mesma transação
    **não** faz passar o estado sem episódio (G2, `search_path` fixo); e o `up` começa com o `LOCK
    TABLE` (G4). **Defeitos a injetar**, um por vez: o trigger **removido** (o `update_all` sem
    episódio passa e o teste reprova); o trigger criado **`NOT DEFERRABLE`** (imediato) — a sequência
    legítima, estado antes do episódio, é recusada no primeiro `UPDATE` e o teste reprova; voltar o
    `CASE TG_TABLE_NAME … NEW.tenant_id` para o `DECLARE` (o caso de `create_tenant/1` reprova com
    `record "new" has no field "tenant_id"`; achado E1); tirar o `SET search_path` da função (o caso
    da tabela temporária reprova; G2)

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

- [ ] T046a [US1] Trocar o estado da organização dentro de um `Multi`, do lado de `Tenants`
  - **Pronta quando**: `contracts/sessoes-e-tokens-da-organizacao.md`, seção
    `trocar_estado_no_multi/5` (emenda D1); T013 concluída (o `CHECK` e `:status` fora do `cast`);
    **T038a concluída** — as duas editam `lib/the_band/tenants.ex`, e por isso esta não é `[P]`
    (achado P1)
  - **Descrição**: em `lib/the_band/tenants.ex`, `trocar_estado_no_multi(multi, nome, %Tenant{}, de,
    para)`: acrescenta ao `multi` o passo `nome`, com `update_all` condicional `WHERE id = ^id AND
    status = ^de`, `updated_at` junto; uma linha → `{:ok, %Tenant{status: para}}`; zero linhas →
    `{:error, :estado_mudou}` se a organização existe, `{:error, :not_found}` se não; só os pares
    `{"active", "suspended"}` e `{"suspended", "active"}`, por cabeça de função. É a escrita do estado
    que `Platform.Suspensions` usa no lugar de escrever na tabela `tenants` (constituição,
    princípio X, letra D; achado D1). O10
  - **Feita quando**: dentro de `Repo.transaction/1` sobre um `Multi`, `active → suspended` muda o
    estado; a segunda vez devolve `:estado_mudou` e não muda nada; id inexistente devolve
    `:not_found`; com um passo seguinte que falha, o estado volta (o `ROLLBACK` alcança a troca);
    `mix xref callers` não mostra **nenhum chamador fora de `TheBand.Platform.Suspensions`** em
    `lib/` (achado O5: quando esta tarefa fecha, `Suspensions` ainda não a chama, e "único chamador"
    seria falso; a asserção de que ela é chamada, e só por ela, é de T049)
  - **Teste**: `test/the_band/tenants/trocar_estado_test.exs`, um caso por frase. **Defeitos a
    injetar**, um por vez: retirar `status == ^de` do `WHERE` (a segunda troca precisa gravar e o
    teste reprovar); chamá-la de um módulo de rascunho fora da `Platform` (o teste do `xref` precisa
    reprovar); executar o `update_all` **na construção** do `Multi`, fora dele, devolvendo um passo
    que só repete o resultado (o caso do `ROLLBACK` precisa ser **visto reprovando**: o estado fica
    `suspended` depois do passo seguinte falhar; achado D1-c de `seguranca-autenticacao.md`)

- [ ] T047 [P] [US1] Revogar os tokens de uma organização suspensa
  - **Pronta quando**: `contracts/sessoes-e-tokens-da-organizacao.md`; T015 e T044 concluídas (T044
    cria `tenant_suspensions`, alvo da FK)
  - **Descrição**: a migração do lado de `Tenants`, `priv/repo/migrations/<ts>_revogacao_por_suspensao.exs`
    (posterior à de T044), acrescenta a `api_access_tokens` a coluna `revoked_by_suspension_id` e os
    dois `CHECK`s de `data-model.md` §6, com `down` explícito, e o campo entra no schema
    `lib/the_band/tenants/schemas/api_access_token.ex`. É de `Tenants` porque a tabela é de `Tenants` (achado L1; constituição,
    princípio X, letra D): `Platform` não altera tabela alheia, e `Tenants` só recebe o id do
    episódio por argumento, sem ler `tenant_suspensions`. Em `lib/the_band/tenants/api_tokens.ex`,
    `revogar_por_suspensao/2` (condição
    `revoked_at IS NULL` no `WHERE`, `revoked_by_user_id = NULL`, `revoked_by_suspension_id`,
    cláusula `organizacao_suspensa`) e `clausulas_registradas/0`; a tela de tokens escreve o autor
    como *"revoked when the organisation was suspended"*, e o select de revogação não ganha opção.
    FR-013, O12
  - **Feita quando**: o round trip `mix ecto.migrate` / `mix ecto.rollback --step 1` da migração
    desta tarefa volta ao estado anterior, e os dois `CHECK`s recusam cláusula sem episódio e
    episódio sem cláusula; os tokens vigentes de A ficam revogados com a cláusula; o token já revogado de
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
    o PR #1044 mergeado (T001); T029, T030, T044, **T044a**, T046, **T046a**, T047 e T048 concluídas;
    `contracts/suspensao.md` emendado por **U1** (recebe o slug)
  - **Descrição**: `Platform.Suspensions.suspender(sessao, slug, attrs)` — recebe o **slug** da rota,
    e não `tenant_id` (achado U1) — como `Ecto.Multi` com os passos nomeados de
    research R8: `:autorizacao` (sessão e concessão lidas com `FOR SHARE`, A15), `:razao`,
    `:estado` (**`Tenants.trocar_estado_no_multi(multi, :estado, tenant, "active", "suspended")`**,
    de T046a, com `:estado_mudou` traduzido para `:ja_suspensa`; o `%Tenant{}` vem de
    **`Tenants.get_by_slug/1`**, chamada uma vez, por `Suspensions`, antes do `Multi` — a única
    leitura de `tenants` do ato, `nil` dá `:not_found` (U1); `Platform` não consulta nem escreve a
    tabela `tenants`, achado D1), `:episodio`, `:sessoes`, `:tokens`.
    **Depois do `commit`, e só depois**: `Sessions.avisar_encerramento({:sessao, id})` para cada id
    encerrado (A2) e o evento (T055). Fachada em `lib/the_band/platform.ex`. FR-003, FR-004, FR-013,
    FR-014
  - **Feita quando**: o retorno de cada recusa do contrato é produzido por um caso, e nenhum muda o
    estado; o sucesso deixa A `suspended`, com episódio aberto, sessões encerradas e tokens
    revogados; `mix xref callers` sobre `Tenants.trocar_estado_no_multi/5` mostra **pelo menos um
    chamador, e só `TheBand.Platform.Suspensions`** (a asserção que saiu de T046a, achado O5); o
    `%Tenant{}` lido por `Tenants.get_by_slug/1` **não sai de `Suspensions`**: nenhum retorno de
    `suspender/3` nem de `reativar/3`, sucesso ou recusa, contém `%Tenant{}` (achado D1-d de
    `seguranca-autenticacao.md`); no sucesso, o ato faz **um** `SELECT` em `tenants`, além do
    `UPDATE` do passo `:estado` (contado pela telemetria de `[:the_band, :repo, :query]` filtrada pelo
    processo, U1); o sucesso satisfaz o trigger de T044a
  - **Teste**: `test/the_band/platform/suspender_test.exs`, um caso por retorno do contrato, e o
    passo que recusou afirmado pelo nome do `Multi` (cenário 3 de `seguranca.md`); no caso de
    sucesso, `SET CONSTRAINTS ALL IMMEDIATE` depois do ato, para o trigger adiado de T044a conferir
    dentro do sandbox; o caso do `xref`;
    e, para cada retorno, uma busca recursiva no termo devolvido que `refute` qualquer
    `%TheBand.Tenants.Tenant{}`. **Defeitos a injetar**, um por vez: devolver o `Multi` inteiro de
    `Repo.transaction/1` no sucesso (o `%Tenant{}` do passo `:estado` sai, e o caso precisa
    reprovar); trocar a chamada por um `update_all` local em `tenants` (o caso do `xref` precisa
    reprovar por zero chamadores)

- [ ] T050 [US1] Reativar uma organização sem devolver nada
  - **Pronta quando**: T049 concluída
  - **Descrição**: `Platform.Suspensions.reativar(sessao, slug, attrs)`, com o slug resolvido como
    em T049 (U1): `:autorizacao`, `:razao`, `:estado`
    (`Tenants.trocar_estado_no_multi/5`, `suspended → active`, com `:estado_mudou` traduzido para
    `:nao_suspensa`; achado D1), `:episodio` (fecha o aberto), `:sessoes` (encerra **de novo**, FR-015);
    nenhum token volta (FR-013); depois do `commit`, o aviso por id (A2) e o evento. FR-005, FR-006
  - **Feita quando**: o episódio fecha com autor, instante e razão; `:nao_suspensa` e
    `:sem_episodio_aberto` são produzidos por casos; nenhum token de antes volta a valer
  - **Teste**: `test/the_band/platform/reativar_test.exs`, um caso por retorno. O caso
    `:sem_episodio_aberto` monta o estado por `update_all` sem episódio, o que só é possível porque o
    sandbox não faz `COMMIT` (fora dele, T044a o recusa): é a defesa para quem desligou o trigger; no
    sucesso, `SET CONSTRAINTS ALL IMMEDIATE` depois do ato, como em T049

- [ ] T056 [US1] Tela do histórico e do ato
  - **Pronta quando**: **T012 aprovado**; T038a, T040, T048, T049 e T050 concluídas;
    `contracts/rotas-da-plataforma.md`, `contracts/suspensao.md`
  - **Descrição**: `organizacao/2` em `Suspensions` (o resumo por `Tenants.resumo_para_a_plataforma/1`,
    de T038a; o histórico de `tenant_suspensions`, do mais novo ao mais antigo, razões por
    `SuspensionReasons.rotulo/1`), o último episódio em `listar_organizacoes/1` — **uma** consulta da
    `Platform` em `tenant_suspensions` (`max(suspended_at)` por `tenant_id`), composta em memória com
    os resumos pelo `id`, sem `join` com `tenants` (achado D1) e sem consulta por organização —, e os
    controllers de `GET /platform/organizations/:slug`,
    `POST …/suspension` e `POST …/reactivation` — estes entregam o `:slug` da rota a `suspender/3` e
    `reativar/3` **sem ler `tenants`** antes (U1); o **sucesso redireciona** (PRG) para
    `GET /platform/organizations/:slug`, e a **recusa re-renderiza** a página, com o resumo lido por
    `organizacao/2` **depois** do ato (achado U3); `confirm_slug` diferente re-renderiza pela mesma
    leitura, e se ela der `:not_found` o `404` vence (achado U4) —, exatamente como o protótipo: só o ato que cabe ao
    estado, razões da base, nota obrigatória onde a base diz, recusa como estado com o motivo em
    inglês. FR-003, FR-006
  - **Feita quando**: suspender e reativar pela tela funcionam, e o sucesso responde `302` para a
    página da organização; slug inexistente dá o `404`, inclusive com `confirm_slug` diferente; o
    histórico mostra quem, quando e por quê nas duas pontas, e `not_recorded` com o rótulo da base
  - **Teste**: `test/the_band_web/plataforma/historico_e_ato_test.exs`, com a razão fora da lista
    recusada e nada mudando. A telemetria filtrada pelo processo conta os `SELECT` em `tenants` de
    cada `POST`: **um** no sucesso (o de `get_by_slug/1`, e o redirecionamento não lê na mesma
    requisição); **dois** na recusa do ato (o do ato e o do resumo para re-renderizar); **um** no
    `confirm_slug` diferente (só o do resumo; o ato não é chamado) (U1, U3). **Defeito a injetar**:
    o controller chamar `resumo_para_a_plataforma/1` **antes** do ato; o sucesso conta dois e o teste
    reprova. Caso do U4: slug inexistente com `confirm_slug` diferente dá `404`, e não `422`

- [ ] T051 [US1] Provar que suspender derruba sessões e tokens
  - **Pronta quando**: T050 concluída; T041 concluída; **T056 concluída** (os dois `POST` de ato,
    que o teste exercita e cuja lista permitida entra em T041; achado O4)
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
    conectado em `/work`, e uma de B; suspender A chamando **`Platform.suspender/3` direto**, com o
    slug de A e uma sessão de operador de fixture; depois, a mesma montagem com uma sessão de A inserida durante
    a suspensão e uma aba conectada a ela, e reativar por `Platform.reativar/3` (lição L85: o `200`
    do HTTP não diz o que o socket faz). Sem o `POST`: o que se prova é o aviso depois do `commit`,
    que vive no contexto; o controller só o chama. Assim a prova da A2 não espera a tela (achado O4)
  - **Feita quando**: a próxima mensagem do LiveView de A é o redirecionamento para `/sign-in`, e um
    `render_click` depois disso não executa; o LiveView de B continua respondendo; na reativação, a
    aba da sessão da corrida cai
  - **Teste**: `test/the_band_web/plataforma/aba_aberta_cai_test.exs`. **Defeitos a injetar**, um por
    vez: retirar o aviso depois do `commit` (a aba de A precisa continuar respondendo); avisar só em
    `suspender/3` (a aba da reativação precisa continuar); avisar **dentro** da transação (a aba
    precisa continuar, porque a hook reconfere antes do `commit`)

- [ ] T054 [US1] Provar a revogação com o formulário aberto
  - **Pronta quando**: T049 e T032 concluídas; **T056 concluída** (o formulário e o `POST` de ato,
    cuja resposta `404` é o que se afirma; achado O4)
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
    `:organizacao_reativada` e `operador_ato_recusado/3` (para todo `{:error, …}` do contrato:
    `:nao_autorizado`, `:not_found`, `:ja_suspensa`, `:nao_suspensa`, `:sem_episodio_aberto`,
    `:vocabulario_nao_declarado` e o changeset resumido; `contracts/eventos-de-acesso.md`), chamados
    depois do `commit` ou da recusa; o `tenant_id`
    do evento é o da organização afetada; o ator vem de `operator_id` no metadado. FR-010, O14,
    quickstart §9
  - **Feita quando**: a linha capturada tem `operator_id`, o `tenant_id` de A, o id do episódio e as
    contagens; a nota livre não aparece; cada motivo de recusa produz uma linha de
    `operador_ato_recusado` com ele
  - **Teste**: `test/the_band/platform/eventos_dos_atos_test.exs` com `capture_log`. **Defeito a
    injetar**: retirar a chamada em `reativar/3`; o caso precisa reprovar

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
    retenção dos códigos de recuperação segue T8 (`data-model.md` §1a): apaga os com
    `coalesce(used_at, invalidated_at)` há mais de 90 dias, e **nunca** um vigente
  - **Feita quando**: uma sessão do operador encerrada há 91 dias some; uma de 89 dias fica
  - **Teste**: `test/the_band/jobs/apaga_sessoes_antigas_test.exs` com os dois casos

- [ ] T059 [P] Escrever o roteiro de operação do operador
  - **Pronta quando**: T032 concluída
  - **Descrição**: `docs/producao/runbook.md` ganha a seção do operador: os três comandos com
    `/app/bin/the_band eval`, que **a pessoa operadora roda o comando ela mesma, ou recebe o código
    por voz, nunca por chat** (A17), o cadastro do segundo fator nos três passos, e o que fazer ao
    perder o celular: o código de recuperação dá **uma** entrada, mas não revoga o aparelho perdido,
    cujo segredo continua valendo — aparelho perdido é **reinício pelo comando**, mesmo havendo
    códigos (T9 de seguranca-totp.md). E, antes da primeira concessão, conferir o NTP do servidor
    com `timedatectl` (T11): deriva acima de 30 s recusa todo código e trava o segundo fator
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
    Dokploy), **A4** se T043 não entrou, e o aparelho do segundo fator como o que sobra de O16;
    e os de seguranca-totp.md (emenda T011, `plan.md` "Riscos"): **T9** (sem notificação ao
    operador na troca de fator e no reuso), **T10** (TOTP não resiste a phishing em tempo real) e
    **T11** (o NTP medido, ou "não medido")
  - **Feita quando**: a nota existe com cada risco, quem o aceitou e quando
  - **Teste**: a revisão do Product Owner encontra os quatro itens e os três de seguranca-totp.md

- [ ] T063 [P] Derivar os modelos da feature
  - **Pronta quando**: T044 e T020 concluídas
  - **Descrição**: o agente de modelos deriva das migrações o ERD das tabelas `platform_*` e
    `tenant_suspensions`, e a máquina de estados da organização e da credencial do operador
    (definição em três passos, emenda T012), em Mermaid, com `arquivo:linha`
  - **Feita quando**: cada entidade e transição do modelo aponta para a migração ou a função que a
    cria
  - **Teste**: a revisão confere três `arquivo:linha` escolhidos ao acaso contra o código

- [ ] T064 Abrir o PR pelo template
  - **Pronta quando**: T061 e T062 concluídas; **T023a concluída com C10 verde** (seguranca-totp.md
    T3: a release não sai sem a rotação alcançar o segredo TOTP); `git status --short` vazio
  - **Descrição**: corpo a partir de `.github/pull_request_template.md` (nunca `--body` à mão),
    tipo de merge declarado (squash, a branch morre no merge), issues com resumo na frente, campo
    `Sprint:`; revisor equipe `the-band` pela API; item no projeto com Iteration e Status conferidos.
    *O que este PR não resolve*: A4 se T043 não entrou, A8 e A17
  - **Feita quando**: `gh pr view <n> --json reviewRequests` não é vazio; o check
    `pr-tipo-de-merge` passa; a seção *Evidência* traz o código de saída de
    `test/the_band/platform/rotacao_da_chave_test.exs` (C10) igual a zero
  - **Teste**: as duas leituras coladas na issue desta tarefa

---

## Dependências e ordem

### Entre fases

- **Fase 1** (T001–T007 e T003a): não depende de nada da feature. T002, T003, T003a, T004 e T005
  dependem de outras pessoas ou PRs, e são o caminho crítico. Em 2026-10-01, só T003a (PR #1053) e
  T004 (a medição do Traefik) ainda esperam por fora.
- **Fase 2** (T008–T017): T008 depende das emendas de 2026-10-01; T009 → T010 → T011; T012 depende de
  T005 e T009; T013–T017 dependem só de T007 e correm em paralelo.
- **Fase 3, US2** (T018–T043, com T023a, T028a, T030a e T038a): depende de T008 e T011; as telas
  (T039, T040) dependem de T012; T021 e T023a dependem de T003a (#1052).
- **Fase 4, US1** (T044–T057, com T044a e T046a): depende de T029 e T030 (sessão e concessão do operador) e
  das telas da US2 só em T056. T046, T046a, T047 e T048 têm dependências **diferentes**, e o
  paralelismo de cada uma está em "Paralelismo", abaixo.
- **Fase 5** (T058–T064): depois do que cada uma cita.

### Os bloqueios de segurança, por achado

| achado | tarefa que o fecha | tarefas que esperam por ele |
|---|---|---|
| A1, alta | T002 (#1048), T023, T024 | T023–T028a, T034 |
| A2, alta | T001 (#1044), T049, T050, T053 | T049–T053 |
| A3, média | T003 (#1047, PR #1049), T023, T025 | T023, T025, T034 |
| A5, média | T026, T027 | T026–T028, T039 |
| A6, média | T030, T031 | T030–T032 |
| A9, média | T041 | T051 |
| A4, média | T004, T043 | T043; sem T004, risco na release (T062) |
| **T1**, alta (seguranca-totp.md) | **T028a** (com T023 e T030) | T036, T039 |
| **T3**, média (seguranca-totp.md) | **T003a** (#1052, PR #1053), T021, **T023a** (C10) | T021, T023a; a **release** (T064, "C10 verde") |
| FR-016 (TOTP) | T009, T010, T011, T022, T028, **T028a**, T030a | T020, T022, T023, T026, T028, T028a, T030a |
| D1 (constituição X, D) | **T038a**, **T046a** | T040, T049, T050, T056 |
| **D1-a**, média (seguranca-autenticacao.md; decidido em 2026-10-01) | **T044a** (o trigger adiado) | T049, T050 |
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

# US2, a leitura de Tenants, a qualquer momento depois de T007:
T038a resumos para a plataforma

# US1 — cada uma com a sua dependência real (achado O2), em arquivos distintos entre si:
T046   encerrar da organização    depois de T007 e T008 (o contrato emendado por A2)
T046a  trocar o estado no Multi   depois de T013 e de T038a (o mesmo lib/the_band/tenants.ex;
                                  achado P1: não é [P] e não corre junto com T038a)
T047   revogar tokens             depois de T015 e T044 (a tabela tenant_suspensions, alvo da FK
                                  da coluna que a própria T047 cria do lado de Tenants)
T048   razões                     depois de T014
```

T046, T046a e T048 podem correr juntas já na Fase 2, assim que T007, T013, T014 e **T038a** fecham
— T046a espera T038a porque as duas editam `lib/the_band/tenants.ex`, e a ordem é T038a → T046a
(achado P1). T047 só depois de T044, que é da Fase 4.

## Estratégia de entrega

1. **Fase 1 inteira antes de qualquer código.** T002, T003 e T003a são PRs de outra issue; T004 e
   T005 são da pessoa mantenedora. Enquanto não chegam, a Fase 2 avança no que não depende deles
   (T008, T009, T013–T017).
2. **US2 até T038** entrega o operador que entra com senha e TOTP e uma área que responde `404` a
   todos os outros. Não é entregável sozinho em produção — um operador sem ato não resolve o #1009.
3. **US1** é o MVP de verdade: o #1009 fechado. A release só sai com US2 e US1 juntas, e com C10
   verde (T023a, seguranca-totp.md T3).
4. T043 entra na mesma release **se** T004 chegar a tempo; se não, a release sai com A4 declarado.

## Contagem

| fase | tarefas |
|---|---|
| 1 — Pré-requisitos e decisões | 8 (T001–T007, T003a) |
| 2 — Fundação | 10 (T008–T017) |
| 3 — US2 | 30 (T018–T043, T023a, T028a, T030a, T038a) |
| 4 — US1 | 16 (T044–T057, T044a, T046a) |
| 5 — Acabamento | 7 (T058–T064) |
| **total** | **71** |

A contagem anterior dizia 64 e não contava a T028a, acrescentada por T010 (achado T1 do
`/speckit-analyze`); as outras cinco (T003a, T023a, T030a, T038a, T046a) entraram com as correções
do mesmo `/speckit-analyze`. A T044a (71ª) entrou com a decisão de D1-a. Concluídas em 2026-10-01: T005, T008, T009, T010, T011 e T012 (6).
