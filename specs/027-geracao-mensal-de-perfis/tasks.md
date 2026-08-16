# Tasks: Geração mensal dos perfis de competência

**Feature**: 027 · **Branch**: `027-geracao-mensal-de-perfis` · **Data**: 2026-08-16

**Entrada**: [spec.md](./spec.md) · [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [research.md](./research.md) · [quickstart.md](./quickstart.md)

## Formato

```text
- [ ] TID [P?] [US?] Título curto
  - **Pronta quando**: o que precisa ser verdade para começar
  - **Descrição**: o que fazer — caminhos, comandos, e o requisito que justifica
  - **Feita quando**: condições observáveis, conferíveis por outra pessoa
  - **Teste**: o comando ou a verificação que demonstra
```

`[P]` = paralelizável (arquivo diferente, sem dependência pendente). `[US1]` = pertence à User Story 1.

## Path Conventions

Monólito modular. Domínio em `lib/the_band/`, interface em `lib/the_band_web/`, testes espelhando a estrutura em `test/`.

---

## Phase 0: Já entregue nesta branch

O commit `5cc4d68` entregou a credencial por organização — `FR-010` a `FR-013`. Está aqui porque a Fase 2 depende dela, e porque tarefa concluída sem registro é tarefa que alguém refaz.

- [x] T001 Credencial do provedor por organização
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `lib/the_band/ai.ex`, `lib/the_band/ai/provider_credential.ex`, migração `20260816120000`, e `verify/2` na borda `LLM.HTTP` — `FR-010` a `FR-013`
  - **Feita quando**: a leitura direta de `ai_provider_credentials` devolve texto cifrado; chave recusada não grava nada; modelo que o provedor não lista é recusado com a lista do que a chave alcança
  - **Teste**: `test/the_band/ai_test.exs` — 19 casos, incluindo `:binary.match` na coluna crua e isolamento entre organizações

- [x] T002 Tela da credencial em `/ai`
  - **Pronta quando**: T001 concluída
  - **Descrição**: `lib/the_band_web/live/ai_live/index.ex`, rota admin, entrada na navegação — `FR-012`
  - **Feita quando**: os três estados aparecem com frases diferentes; o segredo não está no HTML em momento algum
  - **Teste**: `test/the_band_web/live/chave_do_modelo_test.exs` — 12 casos, incluindo `refute html =~ @chave` depois de gravar

---

## Phase 1: Setup

- [ ] T003 Fila própria para as rodadas
  - **Pronta quando**: nada além do repositório
  - **Descrição**: acrescentar `rodadas: 1` às filas Oban em `config/config.exs`, ao lado de `perfis: 1`. A fila é separada porque uma rodada de 35 minutos na fila `perfis` deixaria toda geração pedida a mão esperando — `plan.md`, tabela do princípio VIII
  - **Feita quando**: a fila aparece na configuração e um job enfileirado nela executa sem disputar espaço com `perfis`
  - **Teste**: `test/the_band/profiles/run_worker_test.exs` enfileira nas duas filas e afirma que as duas executam; a asserção falha se `rodadas` não existir

- [ ] T004 [P] Limiares de regeneração na base de conhecimento
  - **Pronta quando**: T003 concluída
  - **Descrição**: regra `regeneration` em `priv/knowledge_base/rules/profile_thresholds.yaml`, com `min_new_closed_tasks: 10` e `max_profile_age_months: 3`, sob a chave de topo `derivation_rule:` que o carregador reconhece — `FR-009`, research.md R4. **Não** usar a chave `rules:`: é a issue #320, e o arquivo ficaria inalcançável por `KnowledgeBase.rule/1`
  - **Feita quando**: `KnowledgeBase.rule("profile.thresholds")` devolve os dois valores; o YAML declara a medição de origem e a data
  - **Teste**: `mix knowledge.validate` passa; um caso em `test/the_band/ontology/knowledge_base_test.exs` lê os dois números pela API pública

- [ ] T005 Validação recusa limiar ausente ou inválido
  - **Pronta quando**: T004 concluída
  - **Descrição**: a validação da base reprova quando `min_new_closed_tasks` ou `max_profile_age_months` faltam, são zero ou negativos — `FR-009`. Nenhum padrão embutido no código: um padrão silencioso faria a rodada usar um número que ninguém escolheu
  - **Feita quando**: remover o campo do YAML faz `mix knowledge.validate` sair com código diferente de zero, e a mensagem nomeia o campo
  - **Teste**: caso que carrega um YAML sem o campo e afirma `{:error, _}` com o nome do campo na mensagem

---

## Phase 2: Foundational — bloqueia todas as user stories

- [ ] T006 [P] Migração dos eventos de automação
  - **Pronta quando**: [data-model.md](./data-model.md) escrito
  - **Descrição**: tabela `profile_automation_events` com `tenant_id`, `event`, `actor_user_id` **não anulável**, `occurred_at`, e `check_constraint` restringindo `event` a `enabled`/`disabled`. Ausência de evento significa desligada — é o que faz a `FR-018c` valer sem migração de dados
  - **Feita quando**: `mix ecto.migrate` sobe e `mix ecto.rollback` desce; inserir `event: "paused"` é recusado **pelo banco**
  - **Teste**: `mix ecto.migrate && mix ecto.rollback && mix ecto.migrate`; e um `Repo.query` inserindo valor fora da lista, afirmando a violação de constraint

- [ ] T007 [P] Migração das rodadas
  - **Pronta quando**: [data-model.md](./data-model.md) escrito
  - **Descrição**: tabela `profile_runs` conforme o data model, com índice parcial em `[:tenant_id]` onde `finished_at IS NULL` — é a consulta que a `FR-003` faz para recusar a segunda rodada. `credential_last_four` não anulável: é o que torna a `SC-006` verificável pelo registro
  - **Feita quando**: migração sobe e desce; o índice parcial existe no banco
  - **Teste**: round trip da migração, e `\d profile_runs` mostrando o índice parcial

- [ ] T008 [P] Migração das entradas de rodada
  - **Pronta quando**: T007 concluída
  - **Descrição**: tabela `profile_run_entries` com `unique_index [:profile_run_id, :person_id]` — é o guarda de idempotência da research.md R2, e precisa ser constraint de banco, não só validação de changeset. `check_constraint` fechando os três motivos de pulo
  - **Feita quando**: migração sobe e desce; inserir duas entradas da mesma pessoa na mesma rodada é recusado pelo banco
  - **Teste**: round trip, e inserção duplicada afirmando `Ecto.ConstraintError`

- [ ] T009 [P] Schemas das três tabelas
  - **Pronta quando**: T006, T007 e T008 concluídas
  - **Descrição**: `lib/the_band/profiles/automation_event.ex`, `run.ex` e `run_entry.ex`, com changesets validando o que as constraints garantem — changeset sozinho não é integridade, e constraint sozinha devolve exceção onde deveria haver `{:error, changeset}`
  - **Feita quando**: combinação inválida — `skipped` sem motivo, `generated` com motivo — devolve changeset inválido antes de chegar ao banco
  - **Teste**: `test/the_band/profiles/run_entry_test.exs` cobrindo as quatro combinações de `outcome` e `reason`

---

## Phase 3: User Story 1 — o perfil está lá quando eu abro (P1) 🎯

**Meta**: passado um mês sem ninguém clicar, quem teve trabalho novo tem perfil novo.

**Teste independente**: com o disparo manual e material novo para uma pessoa, a rodada executa e o perfil dela fica mais recente, sem nenhuma interação além do disparo.

- [ ] T010 [US1] Ler os limiares sem padrão embutido
  - **Pronta quando**: T004 e T005 concluídas; [contracts/regeneration.md](./contracts/regeneration.md) escrito
  - **Descrição**: `Regeneration.thresholds/0` em `lib/the_band/profiles/regeneration.ex`, lendo `profile.thresholds` — `FR-009`. Devolve `{:error, _}` quando falta, nunca um número
  - **Feita quando**: com o YAML correto devolve `%{n: 10, m_months: 3}`; com o campo removido devolve erro, e nenhum caminho substitui por constante
  - **Teste**: dois casos em `test/the_band/profiles/regeneration_test.exs`, um deles carregando base sem o campo

- [ ] T011 [US1] Decidir quem entra na rodada, e por qual motivo não
  - **Pronta quando**: T010 concluída; contrato de `due?/3` escrito
  - **Descrição**: `Regeneration.due?/3` e `select/1`, com os seis ramos na ordem do contrato — `FR-005` a `FR-008`. Devolve `:generate` ou `{:skip, motivo}`, nunca booleano: a `FR-014` conta por motivo, e booleano obrigaria quem chama a redescobrir o porquê. A contagem parte do **fim do recorte**; a idade, da **data de geração**
  - **Feita quando**: os seis ramos têm caso próprio; quem nunca teve perfil gera sem passar pela regra de mudança; quem teve a observação encerrada é pulado com o motivo dele
  - **Teste**: `test/the_band/profiles/regeneration_test.exs` — um caso por ramo, e um caso que fixa a fronteira: N−1 tarefas novas com perfil de 2 meses é `{:skip, :no_new_work}`, N tarefas é `:generate`

- [ ] T012 [US1] Ligar e desligar com autor
  - **Pronta quando**: T009 concluída; [contracts/automation.md](./contracts/automation.md) escrito
  - **Descrição**: `lib/the_band/profiles/automation.ex` com `enable/2`, `disable/2`, `enabled?/1`, `state/1` e `history/1` — `FR-018`, `FR-018b`, `FR-019`. Estado derivado do evento mais recente, nunca de coluna: é o desenho que a issue #178 corrigiu em `ConnectedTool` pelo mesmo motivo
  - **Feita quando**: `state/1` distingue nunca-ligada de desligada-por-alguém; ligar sem credencial devolve `:no_credential` e não grava evento; ligar o que já está ligado devolve `:already_enabled`
  - **Teste**: `test/the_band/profiles/automation_test.exs` — as três respostas de `state/1`, os dois erros, e um caso provando que desligar não apaga o evento anterior

- [ ] T013 [US1] Abrir, registrar e encerrar a rodada
  - **Pronta quando**: T009 e T012 concluídas; [contracts/runs.md](./contracts/runs.md) escrito
  - **Descrição**: `lib/the_band/profiles/runs.ex` com `start/2`, `record/3`, `finish/2`, `latest/1`, `list/2` e `summary/1` — `FR-003`, `FR-014`, `FR-016`, `FR-017`. As sete contagens de `summary/1` saem de agregação sobre as entradas, **nunca** de coluna
  - **Feita quando**: `start/2` recusa com `:already_running` enquanto houver rodada sem `finished_at`; `latest/1` devolve `:never_ran` em vez de lista vazia; `record/3` devolve `:already_recorded` na segunda tentativa da mesma pessoa
  - **Teste**: `test/the_band/profiles/runs_test.exs` — a recusa da segunda rodada, a contagem por motivo com entradas dos quatro tipos, e o isolamento entre dois tenants

- [ ] T014 [US1] A geração devolve o consumo
  - **Pronta quando**: T009 concluída
  - **Descrição**: `lib/the_band/profiles/generate_worker.ex` passa a devolver os tokens de entrada que a borda já traz em `usage`, para a rodada gravar em `input_tokens` — `FR-020`, research.md R6. Nulo quando não houve chamada; nunca zero, que significaria "chamou e não consumiu"
  - **Feita quando**: a geração devolve o perfil **e** o consumo; a geração pedida a mão continua funcionando igual
  - **Teste**: caso em `test/the_band/profiles/generate_worker_test.exs` afirmando o número de tokens vindo do `usage` do Mox

- [ ] T014a [US1] O material continua sendo o histórico inteiro
  - **Pronta quando**: T014 concluída
  - **Descrição**: teste de regressão sobre `Profiles.Material` — `FR-022`, `SC-009`. A decisão de 2026-08-16 foi que cada geração lê o histórico inteiro da pessoa, e **não** o que entrou desde o perfil anterior. Nenhum código novo é esperado aqui: a 026 já monta assim, e esta tarefa existe para que a otimização "mandar só o delta" não entre depois sem alguém perceber
  - **Feita quando**: o início do recorte de duas gerações consecutivas da mesma pessoa é o mesmo, e é a data da primeira tarefa observada dela
  - **Teste**: caso em `test/the_band/profiles/material_test.exs` — gera, acrescenta tarefas novas, gera de novo, e afirma `period_from` idêntico nas duas

- [ ] T015 [US1] A rodada executa sequencialmente, com checkpoint
  - **Pronta quando**: T011, T013 e T014 concluídas
  - **Descrição**: `lib/the_band/profiles/run_worker.ex` — percorre `select/1` em ordem, chama a geração, grava a entrada **depois** de cada desfecho, e pula quem já tem entrada nesta rodada. A condição de observação é reavaliada **no momento da geração**, e não só no da seleção: a rodada leva dezenas de minutos
  - **Feita quando**: matar o job no meio e reexecutar não gera segundo perfil para quem já foi gerado; cada pessoa considerada tem exatamente uma entrada
  - **Teste**: `test/the_band/profiles/run_worker_test.exs` — executa o worker duas vezes sobre a mesma rodada e afirma que a contagem de perfis não mudou e que o Mox não foi chamado de novo

- [ ] T016 [US1] Falha de credencial encerra a rodada
  - **Pronta quando**: T015 concluída
  - **Descrição**: `401`/`403` do provedor encerram a rodada com `{:ended_early, motivo}`, porque a próxima pessoa falharia igual; limite de taxa e falha transitória marcam a pessoa como `failed` e a rodada continua — `FR-016`. O motivo gravado é o texto **já redigido** pela borda: a chave nunca entra na tabela nem no log
  - **Feita quando**: com `401` na terceira pessoa, as duas primeiras continuam gravadas e a rodada fecha como encerrada; com `429`, a rodada chega ao fim com uma falha registrada
  - **Teste**: dois casos no `run_worker_test.exs`, um por código; e uma asserção de que a chave não aparece em `ended_reason`

- [ ] T016a [US1] Quem falhou volta na rodada seguinte
  - **Pronta quando**: T016 concluída
  - **Descrição**: garantir que `failed` não cria fila de repetição própria — `FR-016a`. A pessoa volta a ser avaliada pela `due?/3` normal na rodada seguinte, e é isso que a impede de ficar esperando o mês que vem por engano
  - **Feita quando**: uma pessoa que falhou numa rodada é considerada na seguinte, e gera se atender ao critério de mudança
  - **Teste**: caso no `run_worker_test.exs` — falha na rodada A, e na rodada B a mesma pessoa aparece com `outcome: generated`

- [ ] T017 [US1] O cron mensal enfileira uma rodada por organização
  - **Pronta quando**: T012, T013 e T015 concluídas
  - **Descrição**: `lib/the_band/profiles/monthly_worker.ex`, entrada `{"0 3 1 * *", …}` no `Oban.Plugins.Cron` de `config/config.exs` — `FR-001`, `FR-001a`. Varre os tenants com automação ligada **e** credencial gravada; organização sem chave não abre rodada (`FR-011`). Momento único, no fuso do servidor: um momento por fuso faria a mesma rodada existir várias vezes
  - **Feita quando**: executar o worker enfileira uma rodada para cada tenant elegível e nenhuma para os demais; tenant desligado não recebe rodada
  - **Teste**: `test/the_band/profiles/monthly_worker_test.exs` com três tenants — ligado com chave, ligado sem chave, desligado — afirmando uma única rodada enfileirada

- [ ] T017a [US1] Subir a versão não gera nada
  - **Pronta quando**: T017 concluída
  - **Descrição**: prova de que a `FR-018a` e a `SC-010` valem na prática — instalação com organizações, pessoas e credenciais, e **zero** eventos de automação. Nenhum perfil pode nascer de um deploy
  - **Feita quando**: com organizações que passariam em tudo e nenhum evento gravado, o cron enfileira zero rodadas e nenhum perfil é criado
  - **Teste**: caso no `monthly_worker_test.exs` — dois tenants completos, sem evento algum, afirmando zero jobs enfileirados e zero perfis

---

## Phase 4: User Story 2 — ver o que a rodada fez, e o que custou (P1)

**Meta**: quem administra sabe, sem log, se a rodada executou, quem gerou, quem pulou por qual motivo, e quanto consumiu.

**Teste independente**: com uma rodada contendo os três desfechos, a tela nomeia os três com contagem por motivo.

- [ ] T018 [US2] Tela da geração automática
  - **Pronta quando**: T012 e T013 concluídas
  - **Descrição**: `lib/the_band_web/live/profile_run_live/index.ex`, rota `/profiles` no escopo admin, entrada na navegação ao lado de `/ai` — `FR-017`, `FR-024`. Tela **própria**: `/ai` responde com que conta trabalhamos, `/syncs` o que foi coletado, e esta se a geração está funcionando (princípio X). Interface em inglês (`FR-026`)
  - **Feita quando**: a tela mostra o estado da automação com quem ligou e quando; perfil `member` não a alcança; nenhuma frase da tela está em português
  - **Teste**: `test/the_band_web/live/rodada_test.exs` — redirecionamento do `member`, e os três estados de `state/1` com frases distintas

- [ ] T019 [US2] Os nove números de cada rodada
  - **Pronta quando**: T018 concluída
  - **Descrição**: a lista de rodadas exibe início, fim, consideradas, geradas, puladas **pelos três motivos separados**, falhas e tokens — `FR-014`, `SC-004`, `SC-005`. Cada linha mostra também a **origem** da rodada, automática ou pedida por alguém, com o nome de quem pediu (`FR-015`) — é aqui que a origem aparece, e não na aba da pessoa. Sem interação além de abrir a tela. Números observados levam marca de proveniência com texto, e não só cor (`FR-025`)
  - **Feita quando**: os três motivos aparecem em números separados, nunca somados; a origem de cada rodada é legível; a ausência é nomeada — *nunca ligou* é frase diferente de *executou e não gerou ninguém*
  - **Teste**: caso com uma rodada de três desfechos afirmando os três números e a origem; e um caso sem rodada alguma afirmando a frase de ausência

- [ ] T020 [US2] Ligar dispara a primeira rodada
  - **Pronta quando**: T018 e T017 concluídas
  - **Descrição**: o botão de ligar chama `Automation.enable/2`, que grava o evento e abre a rodada na hora — `FR-004a`. Sem credencial, o botão não promete: a tela diz que não é possível ligar
  - **Feita quando**: ligar faz aparecer uma rodada aberta sem esperar o dia 1; sem credencial, nenhuma rodada é aberta e a tela nomeia o motivo
  - **Teste**: dois casos na tela, um com credencial e outro sem, afirmando a presença e a ausência da rodada

- [ ] T020a [US2] Pedir uma rodada a mão
  - **Pronta quando**: T018 e T013 concluídas
  - **Descrição**: botão de disparo manual na tela, restrito a quem administra — `FR-004`. Passa `trigger: :manual` e `requested_by`, e é o que torna a US2 verificável sem esperar o dia 1. A recusa da `FR-003` aparece nomeada: *já existe uma rodada em execução*, e não silêncio
  - **Feita quando**: o disparo abre uma rodada com origem `manual` e o nome de quem pediu; com rodada aberta, o segundo disparo é recusado com a frase, e nenhuma segunda linha aparece
  - **Teste**: dois casos no `rodada_test.exs` — o disparo que abre, e o que é recusado com rodada em execução

- [ ] T021 [US2] Uma organização não vê a rodada da outra
  - **Pronta quando**: T019 concluída
  - **Descrição**: toda consulta da tela leva tenant — `FR-017`, `AGENTS.md` §14: ausência de filtro de tenant é bug de segurança, não de correção
  - **Feita quando**: com duas organizações, cada uma vê só as próprias rodadas, e a de outra organização não aparece nem por identificador direto
  - **Teste**: caso com dois tenants no `rodada_test.exs`, afirmando `refute html =~` o identificador da rodada alheia

---

## Phase 5: User Story 3 — mudar os limiares sem mexer no código (P2)

**Meta**: quem administra ajusta N e M sem depender de uma versão nova da aplicação.

**Teste independente**: alterar o YAML e disparar a rodada muda o conjunto de pessoas geradas, sem recompilar.

- [ ] T022 [US3] O limiar novo vale na rodada seguinte
  - **Pronta quando**: T011 e T015 concluídas
  - **Descrição**: garantir que `Regeneration` lê os limiares **a cada rodada**, e não em atributo de módulo avaliado em compilação — `FR-009`, US3. Atributo de módulo congelaria o valor no build, e a mudança no YAML não teria efeito
  - **Feita quando**: mudar N de 10 para 3 entre duas rodadas muda quem é selecionado, sem recompilar
  - **Teste**: caso que roda a seleção, altera o valor carregado na base, roda de novo e afirma o conjunto diferente

---

## Phase 6: Polish & Cross-Cutting

- [ ] T023 Registro operacional sem chave e sem material
  - **Pronta quando**: T015 concluída
  - **Descrição**: o log da rodada leva tenant, identificador, contagens e motivos — e **não** leva a chave nem o material enviado ao provedor. O material é texto de tarefas de pessoas reais — `FR-027`, `FR-013`
  - **Feita quando**: nenhuma linha de log da rodada contém a chave nem trecho do material
  - **Teste**: caso capturando o log de uma rodada completa e afirmando ausência das duas coisas

- [ ] T024 Medir o custo real de uma rodada
  - **Pronta quando**: T015 e T017 concluídas; credencial real disponível
  - **Descrição**: executar uma rodada completa contra o provedor de verdade e anotar tokens de entrada e duração — `FR-021`. É medição, não estimativa: os 1,63 milhão de tokens são de antes de as tarefas em aberto saírem do material, e a `SC-002` depende deste número
  - **Feita quando**: o número medido está registrado na spec, e `SC-002` foi confirmado ou corrigido junto com N
  - **Teste**: a própria tela da rodada exibindo o total; o número anotado em `spec.md` com a data

- [ ] T025 Quality gates verdes
  - **Pronta quando**: todas as tarefas de implementação concluídas
  - **Descrição**: `mix gates` — os treze, e **nunca** com `| tail` nem `| grep`: o veredito é o código de saída
  - **Feita quando**: `mix gates` sai com código 0
  - **Teste**: a saída completa do comando, com o código de saída impresso

- [ ] T026 Percorrer o quickstart a mão
  - **Pronta quando**: T025 concluída
  - **Descrição**: os sete passos de [quickstart.md](./quickstart.md), incluindo os dois que nenhuma suíte cobre — revogar a chave no meio da rodada, e desligar durante uma execução
  - **Feita quando**: os sete passos produziram o esperado, e o que divergiu virou defeito registrado ou correção de spec
  - **Teste**: o registro do percurso, passo a passo, com o que apareceu na tela em cada um

---

## Dependencies & Execution Order

### Entre fases

```text
Phase 0 (entregue)  →  Phase 1 (setup)  →  Phase 2 (tabelas)  →  Phase 3 (US1)
                                                                      ↓
                                          Phase 5 (US3)  ←  Phase 4 (US2)
                                                                      ↓
                                                              Phase 6 (polish)
```

### Entre user stories

- **US1 não depende de US2** para funcionar, mas **não pode ser entregue sozinha**: sem a tela, é infraestrutura sem consumidor visível, o que o princípio VI proíbe. As duas são P1 por isso;
- **US3 depende de US1**: sem seleção implementada não há o que reconfigurar.

### Paralelismo

- **T006, T007, T008** — três migrações, arquivos diferentes, sem dependência entre si (T008 referencia T007 por chave estrangeira, então entra depois);
- **T004** roda em paralelo com a Fase 2 inteira: YAML não toca em migração;
- **T010 e T012** são módulos diferentes com contratos escritos, e podem sair juntos.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + US1 + US2.** Não é "US1 apenas": a rodada sem tela não é entregável neste projeto, e o primeiro enunciado da feature seria *"nada ainda"*.

**Entrega incremental**: cada fase fecha com gates verdes. A Fase 3 fecha com a rodada funcionando por disparo manual — o cron da T017 é a última peça, e é a menor.

**A T024 não é opcional.** Ela é a única tarefa que produz um número que nenhum teste produz, e `SC-002` depende dele. Fixar N e M sem ela é escolher o corte com o número errado.

## Notes

- Toda função pública tem contrato em [contracts/](./contracts/) **antes** de ser escrita. Quando a implementação mostrar que o contrato estava errado, corrigir no mesmo commit, com a razão;
- Mock só na borda HTTP do provedor. Nenhum módulo de domínio próprio é mockado;
- Ausência é nula, nunca zero: `input_tokens` nulo é "não houve chamada", e zero seria "chamou e não consumiu";
- A lacuna do princípio VII — revisão independente — fica **declarada**, nunca marcada como cumprida;
- **Quatro requisitos não têm tarefa, e é de propósito.** `FR-002` (não acoplar ao sync), `FR-017a` (sem expurgo), `FR-020a` (sem teto) e `FR-023` (não apagar perfil anterior) são requisitos de **não fazer**: cumpre-se não escrevendo código. Ficam sem teste que os proteja de regressão, e é a fragilidade conhecida desta feature — quem revisar um PR futuro que acrescente expurgo ou teto precisa saber que os quatro foram decididos, e não esquecidos.
