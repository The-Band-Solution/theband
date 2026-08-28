# Tasks: Mensagens internacionalizadas

**Input**: specs/047-mensagens-internacionalizadas/ — spec.md, plan.md, research.md,
contracts/catalogo-de-mensagens.md, data-model.md, quickstart.md

**Tests**: cada tarefa carrega o seu em `Teste`; o verificador nasce pelo teste da
violação (L03).

**Organization**: Setup → Foundational → US1 (P1) → US2 (P2) → US3 (P3) → Polish.

## Phase 1: Setup

- [ ] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch `047-mensagens-internacionalizadas` na main atual
  - **Descrição**: rodar `mix gates > /tmp/gates_047_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_047_baseline.log` e esperar TERMINAR antes de qualquer edição (lição do sprint 022: baseline contaminado por edição concorrente). Registrar o EXIT no log (L60)
  - **Feita quando**: o log existe com `EXIT=0` na última linha, e nenhum arquivo foi editado antes do fim da run
  - **Teste**: `tail -1 /tmp/gates_047_baseline.log` mostra `EXIT=0`

## Phase 2: Foundational

- [ ] T002 Configurar locales e domínios do catálogo
  - **Pronta quando**: T001 concluída; contrato `contracts/catalogo-de-mensagens.md` escrito (está)
  - **Descrição**: `config/config.exs` ganha `config :the_band, TheBandWeb.Gettext, default_locale: "en", allowed_locales: ["en", "pt"]`; criar `priv/gettext/pt/LC_MESSAGES/` com `errors.po` e `sistema.po` vazios válidos e os `.pot` dos dois domínios — estrutura do data-model.md. Nenhuma frase migra aqui
  - **Feita quando**: `mix compile` verde; `Gettext.known_locales(TheBandWeb.Gettext)` devolve `["en", "pt"]`
  - **Teste**: `test/the_band_web/gettext_test.exs` — locales conhecidos e default "en"

- [ ] T003 Verificador de literais, começando pela violação
  - **Pronta quando**: T002 concluída
  - **Descrição**: `lib/mix/tasks/mensagens.verificar.ex` conforme o contrato: AST via `Code.string_to_quoted/2` sobre `lib/the_band_web/**/*.ex`, reprovando `put_flash/3` com literal/interpolação/concatenação fora de gettext, exit 1 com `arquivo:linha`. Fronteira do contrato: HEEx, Logger, raise e IO.puts fora. O teste nasce ANTES, pela violação (L03)
  - **Feita quando**: task reprova fixture com literal plantado apontando linha; aprova gettext, variável e chamada de função; exit codes 1/0 corretos
  - **Teste**: `test/mix/tasks/mensagens_verificar_test.exs` — fixtures das duas direções (reprova literal e interpolação; aprova dgettext e variável)

- [ ] T004 O gate "mensagens no catálogo"
  - **Pronta quando**: T003 concluída — o gate só entra quando a task já prova o veredito
  - **Descrição**: entrada `{"mensagens no catálogo", {:mix, ["mensagens.verificar"]}}` em `@gates` de `lib/mix/tasks/gates.ex`. ATENÇÃO: o gate nasce VERMELHO — a medição por AST na execução encontrou **137** literais em 17 arquivos (o grep do plano dizia 55: perdia multilinha, concatenação e a forma pipe — corrigido aqui com a razão, e é o argumento do verificador por AST); as fases seguintes o tornam verde, cobrado na run completa em T011
  - **Feita quando**: `mix gates` lista o gate novo; `mix mensagens.verificar` roda isolada e enumera os 137 pontos atuais
  - **Teste**: `mix mensagens.verificar > /tmp/v.log 2>&1; echo "EXIT=$?" >> /tmp/v.log` — EXIT=1 e contagem igual à medida (137), no log

## Phase 3: US1 — Toda mensagem de erro sai do catálogo (P1)

- [ ] T005 [US1] As mensagens da 045 migram sem mudar um byte
  - **Pronta quando**: T004 concluída
  - **Descrição**: `session_controller.ex` — `@mensagem_unica` vira `defp mensagem_unica, do: dgettext("errors", "Credenciais inválidas.")` chamada nos mesmos pontos (research R4); `plugs/current_scope.ex` e flashes de erro do fluxo de autenticação/acesso embrulhados em `dgettext("errors", ...)`. PROIBIDO alterar texto: msgid = frase exata de hoje (contrato)
  - **Feita quando**: os flashes desses arquivos passam no verificador; a tela de login recusa com a mesma frase de antes
  - **Teste**: `test/the_band_web/live/login_test.exs` INALTERADO e verde (byte-idêntico via Enum.uniq) — SC-004; `git diff --stat` do arquivo de teste vazio

- [ ] T006 [US1] Os flashes de erro dos LiveViews migram para errors
  - **Pronta quando**: T005 concluída
  - **Descrição**: nos 12 arquivos medidos (source_live 33, roles_live 18, sync_live 15, people_live/show 15, board_live 14, profile_run 10, projects 9, ai_live 8, repository_live 5, tabela_live 3, e controllers), embrulhar os `put_flash(:error, ...)` em `dgettext("errors", ...)`, interpolação virando `%{placeholder}` (contrato §msgid 2). Decisões de vocabulário migram com comentário (FR-007). Rodar `mix gettext.extract --merge` ao fim
  - **Feita quando**: `mix mensagens.verificar` não aponta nenhum `:error`; `errors.pot` contém as chaves extraídas com os comentários
  - **Teste**: suíte das telas afetadas verde SEM edição de teste (texto preservado — L71); `grep -c 'put_flash(:error, "' lib/` = 0

## Phase 4: US2 — Mensagens do sistema no mesmo regime (P2)

- [ ] T007 [US2] As confirmações e avisos migram para sistema
  - **Pronta quando**: T006 concluída
  - **Descrição**: os `put_flash(:info, ...)` dos mesmos arquivos embrulhados em `dgettext("sistema", ...)`, mesmas regras (texto exato, placeholders nomeados, comentários de decisão). `mix gettext.extract --merge` ao fim
  - **Feita quando**: `mix mensagens.verificar` exit 0 — zero literais em ralos; `sistema.pot` existe com as chaves
  - **Teste**: `mix mensagens.verificar > /tmp/v.log 2>&1; echo "EXIT=$?" >> /tmp/v.log` com EXIT=0 no log; suíte das telas verde sem edição de teste

- [ ] T008 [US2] As pendências de tela, medidas e nomeadas
  - **Pronta quando**: T007 concluída
  - **Descrição**: `specs/047-mensagens-internacionalizadas/pendencias.md` — uma linha por tela com texto HEEx fora do verificador v1 (notices, estados vazios, títulos), com contagem MEDIDA por grep (nunca estimada — [[limitacao-declarada-sem-olhar-o-dado]]), para queima em sprints futuros
  - **Feita quando**: toda tela com texto HEEx aparece com contagem e caminho; o documento diz explicitamente o que o verificador v1 não cobre
  - **Teste**: revisão cruzada — para 2 telas da lista, o grep citado reproduz a contagem escrita

## Phase 5: US3 — Um idioma escolhido, dois disponíveis (P3)

- [ ] T009 [US3] O relatório de lacunas
  - **Pronta quando**: T007 concluída (os .pot/.po existem povoados)
  - **Descrição**: `lib/mix/tasks/mensagens.lacunas.ex` conforme contrato: lê os `.po`, lista msgids com msgstr vazio por idioma/domínio, exit 0 sempre (relatório, não gate — FR-006)
  - **Feita quando**: `mix mensagens.lacunas` imprime `en: 0` (msgid é a frase) e `pt: N` com as chaves nomeadas
  - **Teste**: `test/mix/tasks/mensagens_lacunas_test.exs` — .po de fixture com 1 lacuna aparece nomeada; .po completo imprime 0

- [ ] T010 [US3] A troca de idioma provada, com pt nascendo pelas recusas
  - **Pronta quando**: T009 concluída
  - **Descrição**: traduzir em `pt/errors.po` as recusas de acesso e navegação (as frases migradas em T005/T006 que são inglês); teste com `Gettext.put_locale/2` provando que a mesma tela responde na tradução; lacunas restantes ficam visíveis no relatório — nunca silenciosas
  - **Feita quando**: com locale pt, uma recusa migrada aparece em português; com en (default), tudo como antes; `mix mensagens.lacunas` enumera o que restou
  - **Teste**: `test/the_band_web/live/idioma_test.exs` — mesma rota, dois locales, duas frases; e a frase pt veio do .po (editar o msgstr no fixture muda a asserção)

## Phase 6: Polish

- [ ] T011 Gates verdes e PR no padrão
  - **Pronta quando**: T001–T010 concluídas
  - **Descrição**: `mix gates > /tmp/gates_047.log 2>&1; echo "EXIT=$?" >> /tmp/gates_047.log` (14 gates, L60); executar o quickstart §1–§4 e guardar evidências; PR no padrão da constituição 1.6.0 — bloco por US com tabela por tarefa e resumo na frente
  - **Feita quando**: EXIT=0 no log dos 14 gates; quickstart validado; PR aberto no padrão
  - **Teste**: `tail -1 /tmp/gates_047.log` = `EXIT=0`; a seção Issues do PR tem as três US com resumo por tarefa

## Dependencies

```text
T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008
                                            T007 → T009 → T010 → T011
                                            T008 ────────────────↗
```

US1 (T005–T006) é o MVP: gate + erros no catálogo já entregam o pedido nuclear.
US2 fecha o inventário; US3 compra a troca de idioma. Sem paralelismo real: as
fases tocam os mesmos 12 arquivos em sequência (marcador [P] ausente de propósito).

## Implementation Strategy

MVP = Phase 1–3 (US1). Cada fase deixa a suíte verde; o gate novo só é exigido
verde em T007 (fim da migração dos ralos) e cobrado na run completa em T011.
