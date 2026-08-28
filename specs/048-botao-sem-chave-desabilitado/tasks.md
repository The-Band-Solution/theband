# Tasks: Gerar só com chave — o botão diz antes do clique

**Input**: specs/048-botao-sem-chave-desabilitado/ — spec.md, plan.md, research.md,
contracts/estado-da-chave.md, quickstart.md

**Tests**: cada tarefa carrega o seu; a guarda nasce pela violação (L03).

## Phase 1: Setup

- [ ] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch `048-botao-sem-chave-desabilitado` na main atual
  - **Descrição**: `mix gates > /tmp/gates_048_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_048_baseline.log`, run TERMINADA antes de qualquer edição (L60 + lição do baseline contaminado)
  - **Feita quando**: log com `EXIT=0` na última linha, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_048_baseline.log` = `EXIT=0`

## Phase 2: Foundational

- [ ] T002 A guarda do domínio, pela violação
  - **Pronta quando**: T001 concluída; `contracts/estado-da-chave.md` escrito (está)
  - **Descrição**: `Profiles.request/3` recusa `{:error, :sem_chave}` quando
    `AI.origem_da_chave(tenant) == :nenhuma`, ANTES de enfileirar; `{:ambiente, _}`
    continua aceito (research R2/R3). `Runs.credencial/1` e `AI.opcoes/1`
    INTOCADAS. O teste nasce antes, pela violação
  - **Feita quando**: sem chave nenhuma, `request/3` devolve `{:error, :sem_chave}` e a fila Oban fica vazia; com ambiente, enfileira como hoje
  - **Teste**: `test/the_band/profiles_test.exs` — as duas direções (recusa sem job; ambiente enfileira), e o teste existente da mensal inalterado

## Phase 3: US1 — O botão desabilitado diz o que falta (P1)

- [ ] T003 [US1] A página da pessoa diz antes do clique
  - **Pronta quando**: T002 concluída
  - **Descrição**: `people_live/show.ex` — assign do estado da chave no mount
    (1 leitura, `origem_da_chave/1`); "Generate again" e "Generate profile" ganham
    `disabled` real quando `:nenhuma`, com a frase adaptada por `@operacao_menu`
    (quem opera recebe o caminho AI provider; quem não, "quem opera configura") —
    contrato §frase. O handler `gerar_perfil` traduz `{:error, :sem_chave}` em
    flash de erro (defesa em profundidade, cenário 4)
  - **Feita quando**: sem chave → botões `disabled` + frase; com ambiente ou tenant → habilitados sem frase; evento forçado recusado com flash
  - **Teste**: `test/the_band_web/live/botao_sem_chave_test.exs` — sem chave (disabled+frase, evento forçado recusado), com chave (habilitado, frase ausente), dois leitores (frases diferentes)

- [ ] T004 [US1] A geração mensal diz antes do clique, tenant-only
  - **Pronta quando**: T003 concluída (mesmo teste de tela cresce)
  - **Descrição**: `profile_run_live/index.ex` — assign via `AI.fetch/1` (credencial
    do TENANT; ambiente NÃO habilita — FR-011 da 044); "Turn on" e "Run now"
    `disabled` com a mesma frase adaptada; a recusa nomeada existente da tela fica
    exatamente como está (cenário 4)
  - **Feita quando**: sem credencial do tenant (mesmo com ambiente) → desabilitados + frase; com credencial → habilitados; recusa do domínio intacta
  - **Teste**: mesmo arquivo — a assimetria do quickstart §5 provada: ambiente habilita a pessoa e NÃO habilita a mensal

## Phase 4: Polish

- [ ] T005 Gates verdes e PR no padrão
  - **Pronta quando**: T001–T004 concluídas
  - **Descrição**: `mix gates > /tmp/gates_048.log 2>&1; echo "EXIT=$?" >> /tmp/gates_048.log`; quickstart §1–§5 executado com evidências (capturas dos dois estados); PR no padrão 1.6.0
  - **Feita quando**: EXIT=0 no log; evidências guardadas; PR aberto
  - **Teste**: `tail -1 /tmp/gates_048.log` = `EXIT=0`; seção Issues do PR com a US e resumo por tarefa

## Dependencies

```text
T001 → T002 → T003 → T004 → T005
```

US1 é a única story — MVP = tudo. Sem [P]: T003/T004 compartilham o arquivo de
teste e a sequência prova a assimetria entre os caminhos.
