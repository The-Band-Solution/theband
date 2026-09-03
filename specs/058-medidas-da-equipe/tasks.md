---

description: "Tarefas da feature 058 — as medidas que faltam na tela da equipe"
---

# Tasks: As medidas que faltam na tela da equipe, e o elo com o projeto

**Input**: documentos em `/specs/058-medidas-da-equipe/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/medidas-e-periodos.md)

**Testes**: cada tarefa carrega o seu, no campo `Teste`.

**Nenhuma migração.** As três medidas saem de tabelas que já existem, e duas
colunas de período ganham o primeiro consumidor.

---

## Phase 1: Foundational — bloqueia as três histórias

- [ ] T001 A interseção de períodos, e o nulo que não é aberto
  - **Pronta quando**: o contrato em `contracts/medidas-e-periodos.md` está
    escrito (está); nada além do repositório
  - **Descrição**: `TheBand.Periodos.interseccao/1` em `lib/the_band/periodos.ex`,
    **pura**, sem consulta. Recebe lista de `%{inicio, fim}` e devolve
    `:intersecta`, `:nao_intersecta` ou `{:parcial, quais}`. Borda
    `[início, fim)`, a mesma da feature 057. **`nil` é desconhecido, nunca
    aberto** — `linked_at` e `started_at` são anuláveis, e tratá-los como abertos
    é o fallback silencioso que a 057 corrigiu no vínculo (R2, FR-009) Cobre FR-012.
  - **Feita quando**: período com borda nula que se sobrepõe devolve
    `{:parcial, _}` e **não** `:intersecta`; no instante exato do fim o veredito é
    `:nao_intersecta`; três e quatro períodos funcionam igual
  - **Teste**: `test/the_band/periodos_test.exs` — a tabela dos três estados, e o
    caso da borda: `[jan, 1º-jun)` contra `1º-jun` devolve `:nao_intersecta`

- [ ] T002 [P] Declarar o nível de equipe nas duas medidas existentes
  - **Pronta quando**: nada além do repositório
  - **Descrição**: em `priv/knowledge_base/measurements/`,
    `review_time_to_first_review_duration.yaml` e
    `ci_pipeline_success_rate_ratio.yaml` ganham o nível `team` em `scope.levels`,
    com as limitações do recorte: o tempo de revisão conta da **abertura** e
    descarta revisão de robô; a taxa do pipeline é dos **repositórios dos
    projetos**, e não de quem disparou. Princípio IV — medida não aparece em tela
    sem estar declarada — FR-021, FR-017, SC-009
  - **Feita quando**: as duas declaram `team`; as limitações novas estão escritas;
    nenhuma medida da feature aparece em tela sem estar aqui
  - **Teste**: `mix knowledge.validate` e `mix knowledge.graph` verdes, e o
    `scope.levels` das duas contém `team`

- [ ] T003 [P] Declarar a pergunta de quem trabalhou no projeto
  - **Pronta quando**: nada além do repositório
  - **Descrição**: necessidade de informação nova em
    `priv/knowledge_base/information_needs/`, com a pergunta, o stakeholder e a
    **decisão apoiada** — campo obrigatório, e por bom motivo: pergunta sem
    decisão produz painel que se olha e não se usa. É pergunta nova, e não nível
    novo de medida existente — FR-021, SC-009
  - **Feita quando**: a necessidade existe com os campos obrigatórios, e nomeia os
    conceitos e relações que ela exige
  - **Teste**: `mix knowledge.validate` verde, e a necessidade aparece na contagem
    de `information_need`

---

## Phase 2: User Story 2 — Quem trabalhou neste projeto, e quando (P1) 🎯 MVP

**Objetivo**: a pergunta que duas colunas de período existem para responder passa
a ter resposta.

**Teste independente**: ligar uma equipe a um projeto por um intervalo, mover uma
pessoa para dentro e para fora, e conferir que a interseção devolve exatamente
quem estava nos dois ao mesmo tempo.

- [ ] T004 [US2] Ler os períodos do vínculo equipe ↔ projeto
  - **Pronta quando**: T001 concluída
  - **Descrição**: consulta em `lib/the_band/ontology/seon/spo/queries.ex` que
    devolve os vínculos de um projeto **com `linked_at` e `unlinked_at`** — as
    colunas existem desde que a tabela foi criada e **nenhuma consulta as usava**.
    Vínculo encerrado **continua sendo devolvido**: desligar não apaga o que
    houve (FR-008) Cobre FR-012.
  - **Feita quando**: vínculo desligado aparece com o período em que vigeu;
    vínculo sem `linked_at` vem com `inicio: nil`, e não com uma data inventada
  - **Teste**: `test/the_band/ontology/seon/spo/projects_test.exs` — três
    vínculos: vigente, encerrado, e sem data de início

- [ ] T005 [US2] Responder quem trabalhou no projeto num intervalo
  - **Pronta quando**: T001 e T004 concluídas
  - **Descrição**: `SPO.who_worked_on/3`, a interseção de **três** períodos —
    pessoa ↔ equipe, equipe ↔ projeto, e a janela perguntada — usando
    `Periodos.interseccao/1`. Pessoa que alcança o projeto por duas equipes
    aparece **uma vez**, com as duas em `equipes`: duas linhas somariam a mesma
    pessoa (FR-007, FR-010) Cobre FR-001, SC-004.
  - **Feita quando**: equipe ligada de jan a jun com pessoa de mar a dez devolve
    a pessoa em abril e **não** em fevereiro; pessoa em duas equipes do mesmo
    projeto vem numa linha só
  - **Teste**: `projects_test.exs` — a matriz de perguntas do Cenário 3 do
    quickstart, e o caso das duas equipes

- [ ] T006 [P] [US2] Marcar o período parcialmente desconhecido
  - **Pronta quando**: T005 concluída
  - **Descrição**: o resultado carrega o veredito de `Periodos`, e a tela mostra a
    marca quando ele é `{:parcial, _}` (FR-009, SC-005). **Não** é nota de
    rodapé: quem lê precisa saber que aquela linha depende de uma borda que
    ninguém declarou — FR-018
  - **Feita quando**: vínculo sem `linked_at` produz linha com a marca visível; a
    tela nomeia **qual** borda é desconhecida
  - **Teste**: `test/the_band_web/live/teams_live/medidas_da_equipe_test.exs` — a
    marca no HTML, e o texto que diz qual borda falta

- [ ] T007 [US2] A seção na tela, com a ausência dita
  - **Pronta quando**: T005 concluída
  - **Descrição**: seção na tela do projeto listando quem trabalhou nele, com as
    equipes por onde cada pessoa chegou. Intervalo sem interseção mostra
    **ausência em texto**, e não lista vazia (FR-011) Cobre SC-004, SC-006.
  - **Feita quando**: a seção lista as pessoas com suas equipes; projeto sem
    interseção no período traz a frase de ausência
  - **Teste**: `medidas_da_equipe_test.exs` — projeto com e sem interseção, e a
    frase presente no segundo

---

## Phase 3: User Story 1 — O tempo até a primeira revisão (P1)

**Objetivo**: a medida que já é calculada chega à tela, recortada pela equipe.

**Teste independente**: abrir a tela de uma equipe cujas pessoas abriram
solicitações e conferir que só as delas aparecem; registrar uma saída e conferir
que as anteriores continuam contando.

- [ ] T008 [US1] Recortar a espera por revisão pela equipe
  - **Pronta quando**: T001 concluída; o contrato §2 está escrito
  - **Descrição**: `Quality.team_time_to_first_review/3`. O recorte é pela
    **ABERTURA** da solicitação: ela conta para a equipe quando quem a abriu
    pertencia a ela **na data de abertura**. Recortar pela data da revisão mediria
    a equipe de quem revisa, e a medida é uma espera **de quem abriu** (R3,
    FR-002). Só revisão **humana** encerra a contagem — `Quality` já filtra
    `author_type`, e esta função consome sem redefinir (R4) Cobre FR-001, SC-001, SC-002.
  - **Feita quando**: solicitação de quem saiu em 03-15 conta se aberta em 03-10 e
    não se aberta em 04-02; revisão de robô não encerra a contagem
  - **Teste**: `test/the_band/quality_test.exs` — o par de datas em torno da
    saída, e uma solicitação revisada primeiro por robô

- [ ] T009 [US1] A espera em curso, que não é tempo zero
  - **Pronta quando**: T008 concluída
  - **Descrição**: solicitação ainda sem revisão humana devolve
    `{:aguardando, ha_dias}`, e **nunca** some da lista nem vira zero (FR-004).
    As que mais interessam são justamente as que ninguém revisou — omiti-las faria
    a mediana **melhorar** quanto pior a equipe estivesse, e a medida andaria para
    o lado errado sem ninguém notar (R5) Cobre SC-003, FR-018.
  - **Feita quando**: uma revisada e uma aguardando aparecem as duas, com
    relatores distintos; nenhuma solicitação sem revisão é omitida
  - **Teste**: `quality_test.exs` — duas solicitações, e a asserção de que a lista
    tem duas entradas com formas diferentes

- [ ] T010 [P] [US1] A mesma espera, por pessoa
  - **Pronta quando**: T008 concluída
  - **Descrição**: `Quality.team_time_to_first_review_by_person/3`, agrupada por
    autor. A tela declara que a mediana por pessoa e a da equipe **respondem
    perguntas diferentes** e não devem ser reconciliadas (FR-005, FR-020)
  - **Feita quando**: cada pessoa aparece com suas solicitações; o texto sobre as
    duas perguntas está na tela
  - **Teste**: `medidas_da_equipe_test.exs` — duas pessoas com esperas distintas,
    e o texto presente

- [ ] T011 [US1] A seção na tela, com o que a medida descarta
  - **Pronta quando**: T009 e T010 concluídas; T002 concluída
  - **Descrição**: seção na tela da equipe com a espera por revisão, declarando
    que **descarta a revisão de robô** e que o tempo conta da abertura (FR-003,
    FR-019). Equipe sem solicitação no período diz a ausência em texto (FR-006) Cobre FR-017, FR-018.
  - **Feita quando**: os dois textos estão na tela; equipe sem solicitação traz a
    frase de ausência, e não zero
  - **Teste**: `medidas_da_equipe_test.exs` — os dois textos, e o caso da equipe
    vazia

---

## Phase 4: User Story 3 — A taxa do pipeline dos projetos desta equipe (P2)

**Objetivo**: a taxa existe pelo caminho que responde a pergunta certa, ou a
recusa nomeia o elo que falta.

**Teste independente**: equipe com projeto e repositórios devolve a taxa com o
caminho declarado; equipe sem projeto devolve o relator da recusa.

- [ ] T012 [US3] Os repositórios do projeto no período
  - **Pronta quando**: T001 e T004 concluídas
  - **Descrição**: `SPO.project_repositories_in/3`, usando
    `spo_project_repositories.linked_at` e `unlinked_at` — a segunda tabela de
    período que **nenhuma consulta usava**. Repositório desligado conta no
    intervalo em que esteve ligado — FR-012
  - **Feita quando**: repositório ligado e depois desligado aparece para o
    intervalo em que vigeu, e não para o de fora
  - **Teste**: `projects_test.exs` — repositório com os dois intervalos

- [ ] T013 [US3] A taxa pelo caminho do repositório, e não pelo ator
  - **Pronta quando**: T012 concluída; o contrato §4 está escrito
  - **Descrição**: `Verification.team_pipeline_rate/3` pelo caminho
    `repositório → projeto → equipe`. **`actor_person_id` NÃO é usado**: o ator é
    quem disparou, não quem cuida do código, e uma equipe cujo CI roda por
    agendamento apareceria quase vazia. Usá-lo produziria uma segunda taxa com o
    mesmo rótulo e denominador diferente — a L67 (R1, FR-013, FR-013b) Cobre SC-007.
  - **Feita quando**: execução disparada por alguém de fora da equipe num
    repositório do projeto dela **conta**; nenhuma referência a `actor_person_id`
    aparece nesta função
  - **Teste**: `test/the_band/verification_test.exs` — a execução do estranho que
    conta, e a asserção de que a consulta não junta em `eo_people` pelo ator

- [ ] T014 [P] [US3] As cinco fases, e o que fica fora da conta
  - **Pronta quando**: T013 concluída
  - **Descrição**: cada fase em seu campo, e **nenhuma somada a `falha`** —
    cancelar é decisão humana, e contá-la como quebra inflaria a taxa com o que
    ninguém quebrou. `em_andamento` fica **fora** de `execucoes_consideradas`:
    processo que não decidiu nada não é sucesso nem falha (FR-014, FR-015) Cobre SC-008.
  - **Feita quando**: interrompida, não executada e expirada aparecem separadas;
    `em_andamento` não entra em numerador nem denominador
  - **Teste**: `verification_test.exs` — uma execução de cada fase, e a soma dos
    campos batendo com o total observado

- [ ] T015 [US3] A recusa que nomeia o elo que falta
  - **Pronta quando**: T013 concluída
  - **Descrição**: equipe sem projeto declarado devolve
    `{:sem_projeto, %{equipe: nome}}` — e **não** uma taxa de zero. Zero diria que
    o pipeline falhou; a verdade é que a plataforma não sabe de quais
    repositórios aquela equipe cuida (FR-013a) Cobre FR-018, SC-007.
  - **Feita quando**: a função devolve o relator; a tela nomeia o elo que falta e
    **não** apresenta taxa nenhuma
  - **Teste**: `verification_test.exs` e `medidas_da_equipe_test.exs` — o relator,
    e o texto na tela

- [ ] T016 [US3] A taxa na tela, com o tamanho da amostra
  - **Pronta quando**: T014 e T015 concluídas; T002 concluída
  - **Descrição**: a seção mostra a taxa **com o caminho declarado e o número de
    execuções** sobre o qual foi calculada (FR-016). O tamanho não é enfeite: a
    cobertura do dado é desconhecida (R6), e uma taxa de 100% sobre três
    execuções não é a mesma afirmação que sobre trezentas — FR-017, SC-007
  - **Feita quando**: o número de execuções aparece junto da taxa; o caminho está
    escrito na tela
  - **Teste**: `medidas_da_equipe_test.exs` — a taxa, o caminho e a contagem
    presentes no HTML

---

## Phase 5: Polish

- [ ] T017 [P] Provar o isolamento entre tenants
  - **Pronta quando**: T005, T008 e T013 concluídas
  - **Descrição**: dois tenants povoados ao mesmo tempo, com equipes e projetos de
    mesmo nome. Consulta sem tenant é bug de segurança, não de correção — FR-022 — SC-010
  - **Feita quando**: nenhuma das funções novas devolve linha do outro tenant
  - **Teste**: um caso por função pública nova, cada um com os dois tenants

- [ ] T018 [P] Conferir o teto de consultas da tela
  - **Pronta quando**: T007, T011 e T016 concluídas
  - **Descrição**: as três seções somam no máximo **6 consultas** por render, e o
    teto de 16 da feature 057 continua valendo. Subir qualquer um dos dois é
    decisão, e aparece no arquivo do teste
  - **Feita quando**: o teste existente de teto continua passando; o novo mede o
    acréscimo das três seções
  - **Teste**: `teto_de_consultas_da_equipe_test.exs` — o número não cresce com o
    dado, e o teto não subiu

- [ ] T019 [P] Ver as medidas sem poder administrar
  - **Pronta quando**: T007, T011 e T016 concluídas
  - **Descrição**: ler as três medidas **não** exige escopo de administrar equipes
    — administrar não é ver, FR-023 — SC-011
  - **Feita quando**: pessoa com papel `member` abre a tela e lê as três; não vê
    controles de escrita
  - **Teste**: `medidas_da_equipe_test.exs` — dois usuários, um com escopo e outro
    sem

- [ ] T020 Medir a cobertura do dado, e escrevê-la na review
  - **Pronta quando**: T013 concluída; a chave mestra disponível no ambiente
  - **Descrição**: o **Cenário 0** do quickstart. Contar as verificações
    coletadas, os vínculos equipe ↔ projeto e os projeto ↔ repositório. A pesquisa
    não conseguiu medir (`:missing_master_key`), e uma taxa sobre amostra
    desconhecida não sustenta decisão. **Se os vínculos forem zero, a US3 entrega
    apenas o ramo da recusa — e isso é resultado, não falha**
  - **Feita quando**: os três números estão na review do sprint; a conclusão sobre
    a US3 está escrita a partir deles
  - **Teste**: os números medidos, com o comando que os produziu ao lado — a L30
    manda conferir contra a origem, e este é o momento

- [ ] T021 Fechar os gates e abrir o PR
  - **Pronta quando**: T001 a T020 concluídas
  - **Descrição**: `mix gates` é a definição única — o veredito é o **código de
    saída dela**. PR no template criado no #763, com o **tipo de merge declarado**
    e a lacuna de revisão dita se ela não puder ser obtida
  - **Feita quando**: `mix gates` sai com código 0; o PR está aberto com o tipo de
    merge preenchido e revisor pedido
  - **Teste**: `echo $?` imediatamente após `mix gates`, e o PR com o campo do
    template preenchido

---

## As issues

Criadas por `/speckit-taskstoissues`. **Tarefa sem issue é pendência explícita** —
esta seção é preenchida com os números reais, nunca inventados.

## Dependencies & Execution Order

```text
Phase 1 (T001–T003) ──→ bloqueia tudo
   ├─→ Phase 2 (US2) ──→ Phase 4 (US3, reusa a interseção e os períodos)
   ├─→ Phase 3 (US1)
   └────────────────────→ Phase 5 (Polish)
```

**T001 vai primeiro e sozinha**: as três histórias dependem dela, e é a única
puramente lógica — testável sem banco.

**US3 depende da US2**, e não só da fundação: `project_repositories_in/3` usa a
mesma leitura de período que T004 estabelece.

### Paralelismo

- T002 e T003 juntas, depois de T001
- T006 e T010 nas suas fases
- T014 depois de T013
- T017, T018 e T019 juntas, no fim

## Implementation Strategy

**MVP: a US2 sozinha.** Ela responde uma pergunta que hoje não tem resposta, e
duas colunas ganham o primeiro consumidor desde que foram criadas.

**Entrega incremental**: fases 1–2 → PR 1 · fase 3 → PR 2 · fase 4 → PR 3 ·
fase 5 junto do último.

## Notes

- **21 tarefas**, 3 user stories, nenhuma migração
- Toda tarefa tem `Pronta quando`, `Descrição`, `Feita quando` e `Teste`
- Nenhum `Teste` é `mix test` sozinho
- **T020 depende de acesso que esta sessão não tem** — está declarado, e não
  escondido atrás de uma estimativa
