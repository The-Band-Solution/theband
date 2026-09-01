# Tasks: A organização declara suas equipes

**Input**: specs/055-equipes-declaradas/ — spec.md, plan.md, research.md,
data-model.md, contracts/equipes-declaradas.md, quickstart.md

**Tests**: cada tarefa carrega o seu, e **as violações vêm primeiro**. Aqui a
violação tem forma específica: o defeito que esta feature pode introduzir não é
recusar demais, é **apagar**. Um caminho feliz que prove "a saída foi registrada"
passaria numa implementação que deleta a linha — e é justamente a correção fácil.

**Nota de desenho**: o conceito da composição nasce **na ontologia antes da
tabela** (princípio I, e a lição da #527). Se alguém sentir necessidade de
`mix ecto.gen.migration` antes do YAML, a ordem inverteu e o plano precisa ser
revisto.

## Phase 1: Setup

- [x] T001 Abrir baseline dos gates
  - **Pronta quando**: nada além do repositório; branch nascida de `development`
  - **Descrição**: `mix gates > /tmp/gates_055_baseline.log 2>&1; echo "EXIT=$?" >> /tmp/gates_055_baseline.log`, execução TERMINADA antes de editar. O veredito é o código de saída, dentro do log, e nada roda depois dele (L60, princípio XI)
  - **Feita quando**: `EXIT=0` na última linha, sem edição concorrente
  - **Teste**: `tail -1 /tmp/gates_055_baseline.log` devolve `EXIT=0`

## Phase 2: Foundational

- [x] T002 O conceito da composição entra na ontologia
  - **Pronta quando**: T001
  - **Descrição**: a relação `eo.team_part_of_team` no módulo `organizational_structure.yaml` — **não em módulo novo**. O módulo existente já traz `eo.organization_part_of_organization` (`part_whole`, `temporal: historical_relation`) e `eo.team`: a composição de equipes é a mesma forma entre outros dois nós, e módulo novo para uma relação seria estrutura sem problema que a justifique. **Corrigido em relação ao plano durante a execução, com a razão — L82**
  - **Feita quando**: o validador aceita, e a relação **aparece em `docs/ontology/eo.md`** depois de regenerar — que é o que a #527 exigia provar
  - **Teste**: `.venv/bin/python3 scripts/validate_knowledge_base.py` sai `0` e conta uma relação a mais (174 → 175); `grep team_part_of_team docs/ontology/eo.md` devolve linha

- [x] T003 A migração: a composição e o equívoco
  - **Pronta quando**: T002; `data-model.md` lido
  - **Descrição**: tabela de composição com `tenant_id`, `parte_id`, `todo_id`, `started_at`, `ended_at`, `declared_by_user_id`, `ended_by_user_id`, e **índice parcial único** em `(tenant_id, parte_id, todo_id)` onde `ended_at` é nulo. Mais três colunas em `eo_team_memberships`: `invalidado_em`, `invalidado_por_user_id`, `motivo_invalidacao`. Nenhuma coluna existente muda
  - **Feita quando**: `mix ecto.migrate` e o rollback voltam ao esquema anterior sem resíduo
  - **Teste**: a ida e a volta — `mix ecto.migrate` seguido de `mix ecto.rollback`, e o `structure.sql` conferido nos dois estados
  - **ACRESCENTADO durante a execução**: a migração também **recria o `eo_team_memberships_vigente_index`**. Ele nasceu em 2026-08-14 com `where: "ended_at IS NULL"`, e sem o segundo termo um vínculo invalidado continuaria ocupando a vaga única — **vincular de novo depois de corrigir um engano seria recusado pelo banco**, deixando quem errou sem saída. O custo da decisão 2 do plano não vive só nas consultas: vive no índice

## Phase 3: US2 — A pessoa entra, sai, e o que ela fez continua lá (P1)

**Objetivo**: o vínculo declarado, a saída que preserva o período, e o equívoco
que não apaga.

**Teste independente**: vincular, registrar saída, e conferir que um painel de
período anterior mostra o mesmo número antes e depois.

> Esta fase vem antes da US1 **de propósito**. O invariante mais caro da feature
> está aqui, e ele é o que decide o desenho das outras duas.

- [x] T004 [US2] A violação: registrar saída não pode apagar
  - **Pronta quando**: T003
  - **Descrição**: `test/the_band/ontology/seon/eo/team_membership_test.exs` — escrever PRIMEIRO o caso do SC-003: um vínculo com período, um número medido para aquele período, a saída registrada com data posterior, e **o mesmo número medido de novo**. Falha agora porque a função não existe — é o ponto (L77)
  - **Feita quando**: o caso existe e falha por ausência da função, não por sintaxe
  - **Teste**: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/team_membership_test.exs` reprova com função indefinida

- [x] T005 [US2] Vincular pessoa, com papel e início
  - **Pronta quando**: T004 escrito e reprovando
  - **Descrição**: comando em `eo/commands.ex` que grava o vínculo declarado com `declared_by_user_id` — distinto do `record_derived_team_membership/2`, que é derivado (research R1). Recusa quando já existe vínculo vigente, pela **violação do índice parcial**, e não por consulta prévia: a consulta prévia perde a corrida entre duas abas, como a 052 provou
  - **Feita quando**: o vínculo nasce com autor e início; a segunda tentativa vigente devolve `{:error, motivo}` nomeando desde quando o primeiro vale
  - **Teste**: o caso da duplicata vigente, e o caso **concorrente** — duas chamadas simultâneas produzem **um** vínculo, e a perdedora lê a violação como "já existe"

- [x] T006 [US2] Registrar a saída
  - **Pronta quando**: T005
  - **Descrição**: comando que grava `ended_at` e quem registrou. **Nenhuma linha é removida** (C2 do contrato). Data no passado é aceita — quem declara sabe mais que a plataforma; data no **futuro** é recusada, porque afirmaria um fato que ainda não aconteceu
  - **Feita quando**: T004 passa inteiro; a pessoa aparece no histórico com o período fechado
  - **Teste**: o caso do SC-003 (o número que não muda), mais o caso da data futura recusada

- [x] T007 [US2] Registrar o equívoco, sem apagar
  - **Pronta quando**: T006
  - **Descrição**: comando que preenche `invalidado_em`, `invalidado_por_user_id` e `motivo_invalidacao`. O vínculo deixa de valer para **qualquer** período, e o registro permanece. **`Repo.delete` não aparece nesta feature** — se aparecer, o desenho mudou
  - **Feita quando**: o vínculo invalidado não conta em período nenhum; a linha continua consultável com a razão
  - **Teste**: o caso do equívoco, e `grep -rn "Repo.delete" lib/the_band/ontology/seon/eo/commands.ex` devolvendo **zero**

- [x] T008 [US2] "Vigente" passa a ter duas condições, em todo lugar
  - **Pronta quando**: T007
  - **Descrição**: varrer `eo/queries.ex` e `eo/visibility.ex` por toda consulta que hoje decide vigência por `ended_at` nulo, e acrescentar `invalidado_em` nulo. É o custo declarado da decisão 2 do plano, e a caça aos irmãos que a L81 exige: derivar o padrão e varrer o repositório **antes** de entregar
  - **Feita quando**: nenhuma consulta de vínculo vigente considera só uma condição; o que a varredura achou está migrado ou nomeado nas pendências
  - **Teste**: `grep -rn "ended_at)" lib/the_band/ontology/seon/eo/ | grep -v invalidado` devolve zero linhas de consulta de vigência; e um vínculo invalidado **não** aparece na visibilidade de painel

## Phase 4: US1 — A organização cria a equipe que o GitHub não conhece (P1)

**Objetivo**: criar equipe declarada da estrutura, distinguível da observada.

**Teste independente**: criar pela tela e encontrá-la na lista, marcada como
declarada.

- [x] T009 [US1] A equipe da estrutura, ao lado da equipe de projeto
  - **Pronta quando**: T003
  - **Descrição**: função irmã de `create_declared_team/3` em `eo/commands.ex`, com organização e o tipo da estrutura. **Não generalizar a existente** — decisão 4 do plano: organização nula é *exigida* lá e *proibida* aqui, e uma função com invariante condicional ao parâmetro é a que ninguém lê depois
  - **Feita quando**: a equipe nasce com organização, autor e proveniência `the_band/declared`; a função da 028 continua intacta
  - **Teste**: o caso da equipe criada, e a suíte da 028 verde sem alteração
  - **ACRESCENTADO durante a execução**: a recusa de nome repetido exigiu uma **migração** que o plano não previa — índice parcial único em `(tenant_id, organization_id, name)` **onde a origem é declarada**. Só entre declaradas: homônima de uma observada é fato do mundo, não erro; e incluir as observadas faria a COLETA falhar quando o GitHub tivesse dois times de mesmo nome

- [x] T010 [US1] A tela cria, e diz de onde a equipe veio
  - **Pronta quando**: T009
  - **Descrição**: em `teams_live/index.ex`, a ação de criar, e a coluna de origem na lista. A distinção observada × declarada **não pode ser carregada só por cor** (FR-002) — texto ou marca legível sem cor. Só quem administra vê a ação
  - **Feita quando**: a equipe criada aparece na lista marcada; quem não administra não vê o botão
  - **Teste**: teste de tela que assere a **palavra** que distingue as origens, e falha se ela virar só classe de cor; e o caso de quem não administra

## Phase 5: US3 — Equipe dentro de equipe (P2)

**Objetivo**: a estrutura da organização existe na plataforma, sem ciclo.

**Teste independente**: compor duas equipes e ver nas duas telas; tentar fechar
ciclo e ser recusado.

- [ ] T011 [US3] A violação: o ciclo de comprimento 3
  - **Pronta quando**: T003
  - **Descrição**: `test/the_band/ontology/seon/eo/team_composition_test.exs` — escrever PRIMEIRO `A⊂B`, `B⊂C`, e a tentativa `C⊂A`. O caso do vizinho direto (`A⊂B`, `B⊂A`) passa em implementação ingênua; **o de comprimento 3 é o que prova**
  - **Feita quando**: os dois casos existem e falham por ausência da função
  - **Teste**: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/team_composition_test.exs` reprova por função indefinida

- [ ] T012 [US3] Compor e descompor, com a recusa que diz o caminho
  - **Pronta quando**: T011 escrito e reprovando
  - **Descrição**: comandos de compor e descompor, com a detecção de ciclo caminhando em memória sobre o grafo carregado numa consulta (decisão 3 do plano). A recusa **nomeia o caminho** que fecharia o ciclo — *"A faz parte de B, que faz parte de C"* —, não apenas que fecha
  - **Feita quando**: T011 passa; descompor mantém a equipe e o histórico dela
  - **Teste**: os dois ciclos, e a asserção sobre o **conteúdo** da mensagem de recusa — que reprova se ela virar genérica

- [ ] T013 [US3] A estrutura nas duas telas
  - **Pronta quando**: T012
  - **Descrição**: em `teams_live/show.ex`, a seção do que a equipe contém e de quem ela faz parte, com as ações de compor e descompor para quem administra
  - **Feita quando**: as duas direções aparecem; a ação some para quem não administra
  - **Teste**: teste de tela com uma composição montada, conferindo que a equipe de cima lista a de baixo **e vice-versa**

## Phase 6: A discordância, e o polimento

- [ ] T014 As duas afirmações, quando coleta e declaração discordam
  - **Pronta quando**: T008 e T013
  - **Descrição**: na tela da equipe, quando a evidência observada mostra a pessoa e o vínculo declarado diz que ela saiu, mostrar **as duas**, identificando a origem de cada uma (FR-012). Escolher uma — mesmo a mais recente — esconde que o GitHub não foi atualizado, que é informação sobre a organização
  - **Feita quando**: o caso da discordância aparece com as duas origens nomeadas
  - **Teste**: teste de tela com evidência e vínculo em desacordo, que **falha se a tela mostrar só uma** das afirmações

- [ ] T015 Gates verdes, PR no padrão e revisão CONFERIDA
  - **Pronta quando**: T001 a T014
  - **Descrição**: `mix gates` com o código de saída dentro do log; PR no padrão da casa — issues com resumo na frente —, e revisão pedida **e conferida** com `gh pr view <n> --json reviewRequests`, porque o comando de pedir sai zero mesmo sem pedir ninguém (L89, L14)
  - **Feita quando**: `EXIT=0`; o PR existe com revisor **não vazio** no JSON, e está no board
  - **Teste**: `tail -1 /tmp/gates_055.log` = `EXIT=0`; `gh pr view <n> --json reviewRequests` devolve lista não vazia

## Dependências e ordem

```text
T001 → T002 → T003 ─┬→ T004 → T005 → T006 → T007 → T008 ─┐
                    ├→ T009 → T010                        ├→ T014 → T015
                    └→ T011 → T012 → T013 ────────────────┘
```

**Paralelizáveis** depois de T003: as três fases de história — `T004…`, `T009…` e
`T011…` — tocam arquivos diferentes.

**MVP**: T001 a T008. Com elas, o vínculo declarado existe e o histórico
sobrevive — que é o invariante que a feature inteira protege. Sem tela ainda,
mas com o domínio correto.

**O que não é MVP e não é opcional**: T008. A segunda condição de vigência é o
custo declarado da decisão 2; deixá-la para depois significa que um vínculo
invalidado continua contando em algum lugar, e ninguém saberá qual.
