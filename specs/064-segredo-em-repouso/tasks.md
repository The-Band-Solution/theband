# Tasks: segredo em repouso

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Decisões**: [research.md](research.md)

**Contrato**: [contracts/varre-segredos.md](contracts/varre-segredos.md) · **Validação**: [quickstart.md](quickstart.md)

---

## A ordem não segue a prioridade da spec, e o motivo está escrito

A spec prioriza US1 (P1) → US2 (P2) → US3 (P3). As fases abaixo executam
**US1 → US3 → US2**, e a troca é deliberada:

- **US1 continua em primeiro** porque é o único trabalho que **o tempo torna impossível de
  fazer depois**. O que passa para uma cópia não se desfaz, e a decisão de mandar o backup
  para um segundo host já foi tomada. Prioridade e irreversibilidade concordam aqui.
- **US3 sobe na frente de US2** porque o que sobrou dela é barato, sem migração, e fecha a
  **mesma classe de defeito já medida** no outro caminho. US2 é a maior e a única com
  migração de dado em uso: adiantar US3 reduz risco **enquanto** US2 é construída.

**Já mergeado no PR #864, e por isso ausente daqui**: `TheBand.Segredo` existe, e a linha
`oban_jobs` #697 foi redigida. Nenhuma tarefa abaixo os refaz.

---

## Fase 1 — Fundação

- [x] **T001** Declarar os padrões de segredo em um lugar só — [#866](https://github.com/The-Band-Solution/theband/issues/866) — *feita em 2026-09-28*
  - **Pronta quando**: o contrato em `contracts/varre-segredos.md` está escrito — e está
  - **Descrição**: `lib/the_band/segredo/padroes.ex`, com uma lista de `%{tipo, nome, regex, exemplo_valido}` cobrindo token do GitHub, chave de provedor de modelos e token de sessão. O `exemplo_valido` **não é enfeite**: é o material do controle positivo da T003. FR-014 exige declarar o tipo antes de existir coluna; padrão espalhado por script diverge, e a divergência aparece como "zero" no script que ficou para trás
  - **Feita quando**: nenhum outro arquivo do repositório define regex de segredo; cada padrão traz um exemplo que ele próprio casa
  - **Teste**: `test/the_band/segredo/padroes_test.exs` — para cada padrão declarado, `Regex.match?(regex, exemplo_valido)` é verdadeiro **e** o exemplo não casa nenhum dos outros padrões

---

## Fase 2 — US1 (P1): nenhum segredo em claro chega a um backup

**Objetivo**: quem opera consegue, antes de cada cópia nova, procurar segredo em claro num
dump — e saber que a procura enxerga.

**Teste independente da história**: varrer um dump e obter zero; plantar um valor e obter um.

- [x] **T002** Criar a tarefa de varredura — [#867](https://github.com/The-Band-Solution/theband/issues/867) — *feita em 2026-09-28*
  - **Pronta quando**: T001 concluída
  - **Descrição**: `lib/mix/tasks/the_band.varre_segredos.ex`, aceitando `--dump CAMINHO` **ou** `--banco`, e `--saida CAMINHO`. Sem argumento, recusa e explica — varrer "o que estiver por aí" é o padrão que acha o lugar errado. Os dois juntos também recusam. FR-008
  - **Feita quando**: `--dump` lê arquivo e relata por padrão; `--banco` varre as colunas de texto do banco configurado; o relatório nomeia **o que procurou**, e não só o que achou
  - **Teste**: `test/mix/tasks/varre_segredos_test.exs` — sem argumento, código de saída `3`; com os dois, `3`; com `--dump` de arquivo inexistente, `3`

- [x] **T003** Embutir o controle positivo na varredura — [#868](https://github.com/The-Band-Solution/theband/issues/868) — *feita em 2026-09-28*
  - **Pronta quando**: T002 concluída
  - **Descrição**: antes de relatar, a tarefa planta o `exemplo_valido` de cada padrão no material que vai varrer e confirma que o encontra. Em `--dump`, numa **cópia** do arquivo, apagada depois; em `--banco`, numa transação com `ROLLBACK` em `after` — nunca só no caminho feliz. Se o controle falhar, a tarefa **sai com 2** e não relata contagem. FR-009, e é a L104 virada em código
  - **Feita quando**: nenhum plantio toca o material original; o relatório traz a linha do controle positivo; um resultado "limpo" sem essa linha é impossível de produzir
  - **Teste**: `test/mix/tasks/varre_segredos_test.exs` — com um padrão cujo `exemplo_valido` foi adulterado para não casar, a saída é `2`, **não** `0`. É o teste que distingue esta tarefa de um `grep`

- [x] **T004** [P] Recusar imprimir o valor encontrado — [#869](https://github.com/The-Band-Solution/theband/issues/869) — *feita em 2026-09-28*
  - **Pronta quando**: T002 concluída
  - **Descrição**: ao achar, relatar tabela, coluna, deslocamento e **tamanho** — nunca o valor. Quem investiga vai ao lugar; a saída não vira mais uma cópia do segredo. Contrato, seção *O que a tarefa NUNCA faz*
  - **Feita quando**: nenhuma saída da tarefa contém o valor casado, em nenhum modo, nem em `--saida`
  - **Teste**: no mesmo arquivo — planta um valor conhecido, roda, e `refute saida =~ valor`, inclusive no arquivo de `--saida`

- [x] **T005** Varrer o banco de desenvolvimento e registrar — [#870](https://github.com/The-Band-Solution/theband/issues/870) — *feita em 2026-09-28*
  - **Pronta quando**: T003 e T004 concluídas
  - **Descrição**: rodar `mix the_band.varre_segredos --banco --saida docs/seguranca/varreduras/`. FR-010 pede ato repetível **com registro datado**; sem o registro, ninguém sabe se a varredura anterior aconteceu
  - **Feita quando**: existe um relatório datado em `docs/seguranca/varreduras/`; o código de saída dele está no arquivo
  - **Teste**: o relatório existe, traz a linha do controle positivo, e `grep -c "RESULTADO: limpo"` devolve 1 — ou, se não estiver limpo, a ocorrência está no relatório

---

## Fase 3 — US3 (P3, antecipada): segredo nunca chega a registro de diagnóstico

**Objetivo**: fechar a mesma classe de defeito já medida no caminho do GitHub, onde ela ainda
está aberta — e remover a via pela qual um registro com segredo se torna permanente.

**Teste independente**: forçar exceção nos caminhos que usam credencial e conferir que o
registro não contém o valor, e contém o suficiente para investigar.

- [x] **T006** Fechar o segredo no caminho do provedor de modelos — [#871](https://github.com/The-Band-Solution/theband/issues/871) — *feita em 2026-09-28*
  - **Pronta quando**: nada além do repositório — `TheBand.Segredo` já existe (PR #864)
  - **Descrição**: `lib/the_band/integrations/llm/http/req.ex`, linhas 41 e 93, passam o segredo como binário nu. Embrulhar na borda onde ele é lido e abrir só na montagem do cabeçalho, como em `github/http/req.ex:43`. Padrão já justificado — `AGENTS.md` §7.7 dispensa rejustificar dentro do problema que o motivou. FR-006, research R7
  - **Feita quando**: nenhum `Bearer " <>` recebe binário nu em `lib/`; as assinaturas que recebem segredo declaram `Segredo.t()`
  - **Teste**: `test/the_band/segredo_llm_test.exs` — força `FunctionClauseError` no caminho que recebe a chave, e `refute Exception.format(...) =~ chave`. **Mais a reinjeção**: o mesmo caminho com binário nu vaza. Sem ela, o teste passaria numa implementação que não protege nada — foi assim que meu primeiro teste desta feature quase me enganou

- [x] **T007** [P] Preencher as datas de encerramento ausentes — [#872](https://github.com/The-Band-Solution/theband/issues/872) — *feita em 2026-09-28*
  - **Pronta quando**: T005 concluída — varrer antes de mexer, porque mexer altera o material
  - **Descrição**: migração em `priv/repo/migrations/` que preenche `cancelled_at` onde está nulo em registros `cancelled`, usando a data disponível mais próxima do fim. Medido em 2026-09-12: quatro registros de 2026-09-04 são **permanentes**, porque a regra de poda do Oban é `cancelled_at < ^time` e `NULL` nunca a satisfaz. Um deles carregava o segredo. FR-015
  - **Feita quando**: nenhum registro `cancelled` tem `cancelled_at` nulo; a migração é idempotente
  - **Teste**: round trip — `mix ecto.migrate`, contar zero nulos, `mix ecto.rollback`, e a contagem volta ao que era

- [x] **T008** Verificar registro terminado sem data — [#873](https://github.com/The-Band-Solution/theband/issues/873) — *feita em 2026-09-28*
  - **Pronta quando**: T007 concluída
  - **Descrição**: `lib/mix/tasks/the_band.confere_encerramentos.ex`, que conta registros em estado terminal sem a data do encerramento e **sai com 1** se houver algum, nomeando-os. Acrescentar ao `mix gates`. Sem isto, a T007 é um `UPDATE` que ninguém repete. FR-015, SC-008
  - **Feita quando**: a tarefa sai com `0` no estado atual; entra na lista dos gates; a mensagem de falha diz **qual** registro e por que ele escaparia da poda
  - **Teste**: reinjeção — anular o `cancelled_at` de um registro faz a tarefa sair com `1`; desfazer devolve `0`. Um verificador que nunca falha não distingue *conferido* de *não olhou*

---

## Fase 4 — US2 (P2): o token de sessão deixa de ser legível no banco

**Objetivo**: quem lê o banco não consegue se passar por ninguém — **nem tendo a chave que
assina o cookie**.

**Teste independente**: ler a coluna, montar um cookie com o `SECRET_KEY_BASE` real, e a
entrada recusar. Hoje isso **é aceito**, e o teste que o mede já existe:
`test/the_band_web/cookie_de_sessao_evidencia_test.exs`, afirmação 3.

> **Emendada em 2026-09-28** pela avaliação de segurança [seguranca-us2.md](seguranca-us2.md)
> (achados S1–S15) e pelas decisões P1–P6 da pessoa mantenedora. O desenho antigo migrava as
> sessões vivas (T012); a decisão P1 trocou isso por **todos entram de novo**. Cada tarefa diz
> os achados que fecha.

- [x] **T009** Criar a tabela de sessões — [#874](https://github.com/The-Band-Solution/theband/issues/874) — *feita em 2026-09-29*
  - **Pronta quando**: [data-model.md](data-model.md) emendado — e está
  - **Descrição**: migração criando `user_sessions` com `tenant_id` e `user_id` não nulos, FK composta `(user_id, tenant_id) → users(id, tenant_id)` com `on_delete: :delete_all` (exige o índice único `users(id, tenant_id)`, criado na mesma migração), `token_hash` `bytea` **não nulo e único**, `password_epoch` não nulo, `inserted_at` e `ended_at`. **Sem `last_seen_at`** (P2, S10). Fecha S2 (a época mora na linha) e S9
  - **Feita quando**: os índices existem (único em `token_hash`; `user_id`; `tenant_id`; `ended_at`; `inserted_at`); o round trip funciona
  - **Teste**: `mix ecto.migrate` e `mix ecto.rollback`, ambos com saída `0`; dois registros com o mesmo `token_hash` levantam `Ecto.ConstraintError`; linha com `user_id` do tenant A e `tenant_id` de B levanta `Ecto.ConstraintError` — e, com a FK composta removida, **não** levanta (S9)

- [x] **T010** [P] Acrescentar a época de senha — [#875](https://github.com/The-Band-Solution/theband/issues/875) — *feita em 2026-09-29*
  - **Pronta quando**: nada além do repositório
  - **Descrição**: coluna `users.password_epoch`, `integer`, não nula, padrão `0`, incrementada **atomicamente** em toda definição de senha. **NÃO É SEGREDO, e o schema precisa dizer isso por escrito**: quem a lê não ganha nada, porque sozinha não abre sessão nenhuma. Research R2. Fecha S13
  - **Feita quando**: a coluna existe com padrão `0`; o `@moduledoc` ou o comentário de campo declara que ela não é segredo e por quê; incrementa nos **cinco** chamadores de `senha_changeset/3` (`auth.ex` primeira definição, troca própria, cadastro e reinício; `bootstrap.ex`)
  - **Teste**: round trip da migração; `test/the_band/tenants/password_epoch_test.exs` confere o incremento em cada um dos cinco — **o reinício por quem administra primeiro**, porque é a ferramenta de expulsar conta comprometida — e que login **não** incrementa

- [ ] **T011** Abrir, conferir e encerrar sessão — [#876](https://github.com/The-Band-Solution/theband/issues/876)
  - **Pronta quando**: T009 e T010 concluídas
  - **Descrição**: `lib/the_band/tenants/sessions.ex`. `abrir/1` devolve `{sessão, Segredo.t()}` guardando só `sha256(bruto)` e a época lida na mesma leitura que conferiu a senha. `conferir/2` acha pela chave primária, compara o resumo por `secure_compare/2` em memória (forma da ADR 0010, S8), exige `ended_at` nulo, `inserted_at` a menos de **7 dias** e época igual à de `users`; ausência de qualquer parte é recusa por cabeça de função. `encerrar/1`, `encerrar_da_conta/2` e `girar_todas/0` escrevem `ended_at`, nunca apagam. SHA-256 e **não bcrypt**: 32 bytes de entropia real, e o custo do bcrypt viraria latência em toda requisição. Fecha S2, S4, S6, S8, S11
  - **Feita quando**: o bruto nunca é persistido; sessão encerrada, vencida ou de época velha não vale; `Tenants.disable_user` encerra as sessões da conta **na mesma transação** do episódio (S1)
  - **Teste**: `test/the_band/tenants/sessions_test.exs` — o bruto **não** aparece em coluna nenhuma (`refute` contra a tabela inteira); `conferir/2` com o resumo em vez do bruto recusa; sessão de 8 dias recusa; desativar e reativar não devolve a sessão; `FunctionClauseError` forçado no caminho do bruto não o imprime, e a reinjeção com binário nu **vaza**

- [ ] **T012** Girar o token antigo de todas as contas — [#877](https://github.com/The-Band-Solution/theband/issues/877)
  - **Pronta quando**: T011 concluída
  - **Descrição**: migração, **no mesmo deploy da T013**, que grava um valor aleatório novo em `users.session_token` de toda conta, em **SQL puro** (`gen_random_bytes`), sem parâmetro nem laço em Elixir — nada do valor passa pelo log do migrador (S11). A leitura nova não usa a coluna; o giro existe para um **rollback** do código não reabrir nenhum valor que já esteve num backup. **Decisão P1**: as sessões vivas não são migradas, e cada pessoa entra de novo uma vez, anunciado na nota da release. Fecha S7
  - **Feita quando**: nenhum valor de `users.session_token` anterior à migração existe depois dela; a migração é idempotente no efeito (rodar de novo gira de novo, e nada passa a valer)
  - **Teste**: `test/the_band_web/troca_de_sessao_test.exs` — cookie montado com o token de antes, migração aplicada, e a requisição vai a `/sign-in`, **tanto** pelo código novo **quanto** pela conferência antiga (a do rollback)

- [ ] **T013** Ler a sessão pela nova tabela — [#878](https://github.com/The-Band-Solution/theband/issues/878)
  - **Pronta quando**: T012 concluída
  - **Descrição**: `current_scope.ex` e `hooks.ex` passam a chamar `Sessions.conferir/2` — **o mesmo ponto**, para a validade valer no plug também (S6). `session_controller.ex` abre sessão por `Sessions.abrir/1` e põe o id e o bruto no cookie; `delete/2` chama `Sessions.encerrar/1` antes de soltar o cookie (S5); `set_password` usa a mesma conferência, e não comparação de campo própria (S3). As definições de senha encerram as outras sessões da conta. `test/support/conn_case.ex` abre sessão por `Sessions`. A recusa continua sendo a mensagem única, sem distinguir motivo na tela — os motivos seguem no log, como hoje. Fecha S1, S3, S5, S6
  - **Feita quando**: as cinco formas de encerrar (sair, definir senha, desativar, giro, validade) valem no servidor; a tela não diz qual delas foi; nenhum código em `lib/` lê `users.session_token`
  - **Teste**: `cookie_de_sessao_evidencia_test.exs` — a afirmação 3 passa a ler **o que está na linha** de `user_sessions` (o que o dump dá) e vai a `/sign-in`, **com o par positivo**: o bruto de `abrir/1`, com a mesma chave, é aceito. Mais: sair e reenviar o cookie guardado → `/sign-in` (S5); `POST /set-password` com cookie de sessão encerrada → `/sign-in` e `password_hash` inalterado (S3); sessão de 8 dias em `POST /profile/password` → `/sign-in` (S6)

- [ ] **T014** Remover a coluna antiga — [#879](https://github.com/The-Band-Solution/theband/issues/879)
  - **Pronta quando**: T013 concluída **e em produção** — não antes
  - **Descrição**: migração **separada** que remove `users.session_token`. Separada de propósito: enquanto a coluna existe, voltar atrás custa um deploy; depois de apagá-la, custa um backup. E o padrão de token de sessão da varredura é **aposentado** junto, porque o controle positivo dele planta numa tabela temporária de mesmo nome e continuaria dizendo "limpo" sobre uma coluna que não existe (S12)
  - **Feita quando**: a coluna não existe; nenhum código a referencia; `Padroes.todos/0` não declara mais o padrão da coluna
  - **Teste**: abrir sessão real, `pg_dump`, busca **literal** do bruto → 0 ocorrências; e o mesmo teste, antes da T014, acha o bruto de uma conta em `users.session_token` — sem o par, o 0 não mede nada

- [ ] **T020** Apagar as sessões que deixaram de valer há 90 dias — [#1007](https://github.com/The-Band-Solution/theband/issues/1007)
  - **Pronta quando**: T011 concluída
  - **Descrição**: job Oban diário que apaga de `user_sessions` a linha com `ended_at` há mais de 90 dias **ou** `inserted_at` há mais de 97 (7 de validade + 90). As duas condições: sessão vencida não escreve `ended_at`, e sem a segunda ela seria o registro permanente da FR-015. **Decisão P3**
  - **Feita quando**: o job está no `Oban.Plugins.Cron`; linha encerrada há 91 dias some, há 89 fica; sessão vencida sem `ended_at` também some
  - **Teste**: `test/the_band/jobs/limpa_sessoes_test.exs` — as quatro bordas (89 e 91 dias por `ended_at`, 96 e 98 por `inserted_at`); e, com a segunda condição removida, a sessão vencida **fica**

---

## Fase 5 — A idade da credencial (FR-016 a FR-019)

**Objetivo**: quem administra vê há quanto tempo cada credencial está em uso, e é **pedido** a
trocar depois de três meses. Pedir, não impedir.

**Teste independente**: uma credencial com data de quatro meses atrás faz a tela pedir a
troca; uma de ontem, não; uma sem data aparece como **idade desconhecida**.

- [ ] **T017** Saber a idade de cada credencial — [#882](https://github.com/The-Band-Solution/theband/issues/882)
  - **Pronta quando**: nada além do repositório — `validated_at` já existe nos dois schemas
  - **Descrição**: função única que classifica uma credencial em `:no_prazo`, `:vencida` ou `:idade_desconhecida`, a partir de `validated_at` e da data da última troca. Vale para `tool_credentials` **e** `ai_provider_credentials` — são o mesmo tipo de segredo (FR-002) e a política é a mesma. Sem data, é `:idade_desconhecida`, **nunca** `:no_prazo`: ausência de data não é prova de juventude — FR-019, mesma família da FR-015
  - **Feita quando**: os três estados são distinguíveis; o limite de três meses vive num lugar só, não espalhado por tela
  - **Teste**: `test/the_band/credenciais/idade_test.exs` — data de 4 meses atrás dá `:vencida`; de ontem, `:no_prazo`; **`nil` dá `:idade_desconhecida`, e o teste afirma explicitamente que não é `:no_prazo`**. É a violação, não o caminho feliz

- [ ] **T018** Pedir a troca na tela que administra — [#883](https://github.com/The-Band-Solution/theband/issues/883)
  - **Pronta quando**: T017 concluída
  - **Descrição**: nas telas de credencial de ferramenta e de provedor de modelos, mostrar o pedido com **há quanto tempo** ela está em uso — *"registrada há 4 meses"*, não *"credencial antiga"*. O primeiro é acionável; o segundo, não. A coleta **não para**: é pedido, não bloqueio. FR-016, FR-017
  - **Feita quando**: a tela distingue os três estados; nenhuma ação é impedida pelo estado `:vencida`
  - **Teste**: `test/the_band_web/live/idade_da_credencial_test.exs` — com credencial de 4 meses, o HTML traz o pedido **e o tempo**; com a de ontem, não traz nada; e uma coleta disparada com credencial vencida **continua funcionando**. O último é o que impede a política virar queda de serviço

- [ ] **T019** [P] Registrar a data da troca — [#884](https://github.com/The-Band-Solution/theband/issues/884)
  - **Pronta quando**: T017 concluída
  - **Descrição**: trocar o segredo grava a data e zera a contagem. Sem esse registro, a próxima cobrança não sabe se a anterior foi atendida, e a tela pede de novo a quem acabou de trocar. FR-018
  - **Feita quando**: depois da troca, o estado volta a `:no_prazo`; a data anterior não é perdida
  - **Teste**: no mesmo arquivo da T017 — credencial vencida, troca, e o estado vira `:no_prazo`; a data da troca fica gravada

## Fase 6 — O que fica escrito

- [ ] **T015** Documentar o efeito de uma restauração sobre as sessões — [#880](https://github.com/The-Band-Solution/theband/issues/880)
  - **Pronta quando**: T013 concluída — a resposta decorre do desenho
  - **Descrição**: seção no `docs/producao/runbook.md` com os três casos: sessão aberta **depois** do backup cai; aberta antes e ainda válida continua; **encerrada entre o backup e o desastre volta a valer** — o que mais surpreende. FR-013, research R5
  - **Feita quando**: os três casos estão escritos; o procedimento de restauração termina com o giro de sessões como passo **obrigatório** (P5)
  - **Teste**: revisão contra o código da T011 — alguém que nunca leu o runbook chega à resposta certa sobre os três casos em menos de um minuto. FR-013 e SC-006 são documento, e o teste é a leitura
  - **Emenda de 2026-09-28 (P5)**: depois de restaurar um backup, encerrar todas as sessões é passo **obrigatório** do procedimento, e não recomendado — as sessões que a restauração ressuscita são justamente as encerradas por segurança

- [ ] **T016** [P] Escrever o procedimento de girar todas as sessões — [#881](https://github.com/The-Band-Solution/theband/issues/881)
  - **Pronta quando**: T011 concluída
  - **Descrição**: procedimento no runbook usando `Sessions.girar_todas/0`, com **quando** usá-lo: suspeita de exposição, depois da varredura de produção da FR-010, depois de uma restauração. Mecanismo é do plano; o ato é de quem opera — foi a separação que permitiu a T012 não derrubar ninguém
  - **Feita quando**: o procedimento existe e diz que ele **encerra a sessão de todo mundo**, sem eufemismo
  - **Teste**: `test/the_band/tenants/sessions_test.exs` — `girar_todas/0` escreve `ended_at` em todas as sessões abertas, e uma requisição com cookie anterior passa a ser recusada
  - **Emenda de 2026-09-28 (P5)**: depois de restaurar um backup, encerrar todas as sessões é passo **obrigatório** do procedimento, e não recomendado — as sessões que a restauração ressuscita são justamente as encerradas por segurança

---

## As issues

Criadas por `/speckit-taskstoissues` em 2026-09-13. **Tarefa sem issue é pendência explícita** — os números abaixo são os reais, conferidos contra o GitHub depois de criar.

| tarefa | issue |
|---|---|
| T001 | [#866](https://github.com/The-Band-Solution/theband/issues/866) |
| T002 | [#867](https://github.com/The-Band-Solution/theband/issues/867) |
| T003 | [#868](https://github.com/The-Band-Solution/theband/issues/868) |
| T004 | [#869](https://github.com/The-Band-Solution/theband/issues/869) |
| T005 | [#870](https://github.com/The-Band-Solution/theband/issues/870) |
| T006 | [#871](https://github.com/The-Band-Solution/theband/issues/871) |
| T007 | [#872](https://github.com/The-Band-Solution/theband/issues/872) |
| T008 | [#873](https://github.com/The-Band-Solution/theband/issues/873) |
| T009 | [#874](https://github.com/The-Band-Solution/theband/issues/874) |
| T010 | [#875](https://github.com/The-Band-Solution/theband/issues/875) |
| T011 | [#876](https://github.com/The-Band-Solution/theband/issues/876) |
| T012 | [#877](https://github.com/The-Band-Solution/theband/issues/877) |
| T013 | [#878](https://github.com/The-Band-Solution/theband/issues/878) |
| T014 | [#879](https://github.com/The-Band-Solution/theband/issues/879) |
| T015 | [#880](https://github.com/The-Band-Solution/theband/issues/880) |
| T016 | [#881](https://github.com/The-Band-Solution/theband/issues/881) |
| T017 | [#882](https://github.com/The-Band-Solution/theband/issues/882) |
| T018 | [#883](https://github.com/The-Band-Solution/theband/issues/883) |
| T019 | [#884](https://github.com/The-Band-Solution/theband/issues/884) |
| T020 | [#1007](https://github.com/The-Band-Solution/theband/issues/1007) |

A convenção do repositório é `NNN/TXXX`, e o prefixo da spec **não é enfeite**: sem ele, deduplicar por `T001` casaria as 354 issues das specs anteriores e a próxima execução não criaria nada.

---

## As issues de história e de épico

Criadas em 2026-09-13, depois das de tarefa — a convenção `NNN/USx:` e `ÉPICO:` já existia no
repositório (ver `058/US1`, `058/US2`, `058/US3`) e eu não a tinha seguido.

| nível | issue | labels |
|---|---|---|
| épico | [#888](https://github.com/The-Band-Solution/theband/issues/888) — segredo em repouso | `epic` `security` |
| US1 (P1, escopo mínimo) | [#885](https://github.com/The-Band-Solution/theband/issues/885) | `us` `security` |
| US2 | [#886](https://github.com/The-Band-Solution/theband/issues/886) | `us` `security` |
| US3 | [#887](https://github.com/The-Band-Solution/theband/issues/887) | `us` `security` |

**Um tipo, várias características.** O tipo vem da ontologia `continuum` — `sro.epic`,
`sro.user_story`, `sro.intended_scrum_development_task` —, e é **um só**. Os demais dizem
sobre o quê a issue é: `security` nas 23, mais `bug` na T007 (defeito medido), `enhancement`
na T008 e nas T017–T019, e `documentation` nas T015–T016.

A regra está no `AGENTS.md`, seção 12.

## Dependências

```
T001 ──> T002 ──> T003 ──┬──> T005 ──> T007 ──> T008
                 T004 ───┘
T006  (independente — só depende do #864, já mergeado)

T009 ──┬──> T011 ──> T012 ──> T013 ──> T014     (T012 e T013 no MESMO deploy; T014 na release seguinte)
T010 ──┘         ├──> T016
                 └──> T020
                      T013 ──> T015
```

**Em paralelo**: T004 com T003 · T006 com toda a fase 2 · T010 com T009 · T016 com T015

## Escopo mínimo

**T001 a T005** — a US1 inteira. Entrega sozinha o que o tempo torna impossível depois: a
capacidade de varrer um dump **antes** da primeira cópia para o segundo host, com a prova de
que a varredura enxerga.

Nada mais precisa estar pronto para isso valer.

## O que estas tarefas não cobrem

- **A rotação do token do GitHub** — ato operacional, adiado para 2026-10-12
- **Rodar a varredura em produção** — a T002 a torna possível; executá-la é de quem opera
- **O caminho até o MinIO** — `pg_dump → varredura → restauração` está coberto; `→ destino remoto →` não
- **De onde vieram os quatro registros cancelados sem data** — incógnita declarada em R6; a T008 impede que voltem, sem explicar a origem
