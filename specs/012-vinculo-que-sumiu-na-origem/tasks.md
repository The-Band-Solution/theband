# Tarefas — Feature 012: o vínculo que sumiu na origem

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/decomposition-absence.md](contracts/decomposition-absence.md)
**Branch**: `016-vinculo-que-sumiu-na-origem` · **Nenhuma migração** — a coluna existe desde
2026-08-11

Oito tarefas em quatro fases. Cada uma tem teste, e nenhuma delas é `mix test` sozinho.

**Ordem que é dependência**: F1 marca · F2 chama no lugar certo · F3 prova que a tela recebe o dado ·
F4 confere no dado real.

**F1 sozinha não é entregável**: função que ninguém chama não marca nada. É a **L21**, e é por isso
que F1 e F2 estão no mesmo sprint.

---

## F1 — a marca

### T001 [US1] Marcar o vínculo não revisto

- **Pronta quando**: o contrato existe em `contracts/decomposition-absence.md`, com as sete garantias
  e a lista do que a função não faz; a decisão do escopo está em `research.md` D1.
- **Descrição**: `mark_decomposition_links_no_longer_observed/3` em
  `lib/the_band/work_items/commands.ex`, ao lado de `mark_issues_no_longer_observed/3`, com
  `defdelegate` em `lib/the_band/work_items.ex`. Um `Repo.update_all` só: os vínculos cujo
  `parent_issue_id` está na subconsulta dos ids de `collected_issues` daquele
  `observed_repository_id` e daquele tenant, com `last_observed_at < ^desde` e
  `is_nil(no_longer_observed_at)` — FR-001, FR-003, FR-009. **Grava `DateTime.utc_now(:second)`, não
  o `desde`**: o `desde` é o corte, e a data é quando se notou (FR-002, research D2). **Sem aridade
  2** — a L19 impedida no tipo, como a irmã.
- **Feita quando**: um vínculo cujo pai está no repositório informado e cujo `last_observed_at` é
  anterior ao corte fica com data; um vínculo do **mesmo** pai revisto depois do corte continua nulo;
  um vínculo de **outro** repositório não é tocado; e um vínculo já marcado mantém a data antiga.
- **Teste**: `test/the_band/work_items_test.exs` — quatro casos, e um deles é a violação: montar
  vínculo em dois repositórios, chamar com o id de um, e exigir que o do outro continue vigente.

### T002 [P] [US1] Preservar a vigência de quem voltou

- **Pronta quando**: T001 feita.
- **Descrição**: nenhum código novo — `record_decomposition_link/2` já zera
  `no_longer_observed_at` e preserva `observed_at` por `base.observed_at || now`. A tarefa é o
  **teste** que fixa isso como contrato (FR-006), em `test/the_band/work_items_test.exs`, porque a
  ressurreição é a metade do mecanismo que ninguém lembra de testar.
- **Feita quando**: um vínculo marcado como ausente e depois regravado volta com
  `no_longer_observed_at` nulo; e o `observed_at` dele é **o mesmo** de antes da marca.
- **Teste**: `test/the_band/work_items_test.exs` — comparar `observed_at` antes e depois da
  ressurreição, e exigir igualdade; o teste falha se alguém trocar o `||` por atribuição direta.

### T003 [P] [US1] Fixar a idempotência da marca

- **Pronta quando**: T001 feita.
- **Descrição**: teste que chama a função **duas vezes** com o mesmo corte e exige `{:ok, 0}` na
  segunda — FR-008 e G4 do contrato. E um segundo caso: chamar de novo com corte **posterior**, e
  exigir que a data do vínculo já marcado **não** mude (FR-009).
- **Feita quando**: a segunda chamada devolve zero; nenhuma data muda entre as duas; e o caso do
  corte posterior não reescreve marca existente.
- **Teste**: `test/the_band/work_items_test.exs` — comparar o mapa `{id => no_longer_observed_at}`
  antes e depois da segunda chamada, exigindo igualdade de todos os valores.

### T004 [P] [US3] Barrar o alcance a outro tenant

- **Pronta quando**: T001 feita.
- **Descrição**: teste com **dois** tenants, cada um com vínculo defasado, chamando a função para um
  só — FR-010, princípio V. O caso existe porque `decomposition_links` não é lida por
  `tenant_id` na cláusula de repositório: o escopo vem do `parent_issue_id`, e um erro aqui seria
  silencioso.
- **Feita quando**: o vínculo do tenant chamado fica marcado; o do outro continua vigente; e a
  contagem devolvida é 1, não 2.
- **Teste**: `test/the_band/work_items_test.exs` — asserção sobre o vínculo do **outro** tenant,
  que é onde o defeito apareceria.

---

## F2 — a chamada, no ramo certo

### T005 [US1] Marcar ao fim da coleta do repositório

- **Pronta quando**: T001 feita.
- **Descrição**: chamar a função em `coletar_issues/2` de
  `lib/the_band/ingestion/github_work_items.ex`, no ramo `{:ok, nodes, total}`, **depois** de
  `vincular(ctx, nodes)` e ao lado de `mark_issues_no_longer_observed/3`, com `ctx.started_at` como
  corte — FR-004, research D4. **Depois de `vincular/2` e não antes**: antes marcaria todos os
  vínculos e a renovação limparia parte, deixando dois estados para o mesmo fato dentro da mesma
  execução. O número entra no mapa devolvido pela fase como `vinculos_ausentes` — FR-013.
- **Feita quando**: uma coleta em que o pai deixou de declarar uma parte marca **aquele** vínculo; os
  outros vínculos do mesmo repositório continuam vigentes; e o mapa da fase traz o número.
- **Teste**: `test/the_band/ingestion/github_work_items_test.exs` — duas coletas com a borda HTTP
  fingida: a primeira traz o pai com duas partes, a segunda com uma. Exigir um vínculo marcado, um
  vigente, e `vinculos_ausentes: 1` no resultado.

### T006 [US3] Não marcar o que não foi olhado

- **Pronta quando**: T005 feita.
- **Descrição**: teste que cobre os três casos de repositório não coletado — falha transitória, falha
  permanente e repositório fora de `list_collectable/2` —, exigindo **zero** vínculos marcados em
  todos. FR-005, e é a feature 009 inteira: um `:nxdomain` de um instante já custou 38 repositórios
  e 899 issues. Cobrir também o caso do vínculo entre repositórios: pai em `A`, filha em `B`,
  coletar só `B`, e exigir que o vínculo continue vigente (FR-003, e são 57 no dado real).
- **Feita quando**: coleta com erro transitório não marca nada; com erro permanente também não;
  repositório inacessível não é sequer coletado; e o vínculo cujo pai está em outro repositório
  sobrevive à coleta da filha.
- **Teste**: `test/the_band/ingestion/github_work_items_test.exs` — quatro casos, cada um
  asserindo `no_longer_observed_at` **nulo**, que é a asserção que falha se a chamada escorregar
  para fora do ramo `{:ok, …}`.

### T007 [P] [US1] Dizer no log o que deixou de ser declarado

- **Pronta quando**: T005 feita.
- **Descrição**: `Logger.info` em `coletar_issues/2` nomeando o repositório e o número, **somente
  quando o número é maior que zero** — FR-013. A linha que aparece em toda execução treina quem lê a
  ignorá-la, e é a mesma razão pela qual a tela de sincronizações esconde `0 unreachable`. **Nenhum
  campo novo em `syncs` e nenhum número novo na tela** — research D5.
- **Feita quando**: a coleta que marca escreve uma linha com nome do repositório e número; a coleta
  que não marca nada **não** escreve linha nenhuma; e `syncs` continua com os mesmos campos.
- **Teste**: `test/the_band/ingestion/github_work_items_test.exs` — `ExUnit.CaptureLog`, exigindo a
  linha no primeiro caso e **ausência** dela no segundo.

---

## F3 — a tela recebe o dado

### T008 [US2] Provar que a lista diz que o vínculo acabou

- **Pronta quando**: T005 feita; e a feature 011 incorporada — o rótulo e a contagem que exclui o
  ausente vivem no PR [#264](https://github.com/The-Band-Solution/theband/pull/264).
- **Descrição**: teste de LiveView em `test/the_band_web/live/` sobre `/work/repositories/:id`, com o
  estado montado **pela coleta**, não por `insert` direto: coletar duas vezes, a segunda sem a parte.
  Exigir o texto *"absent: this link existed and is not present now"* na linha, e exigir que uma
  issue com um pai vigente e um vínculo ausente **não** diga "more than one parent" — FR-011, FR-012.
  Montar pelo caminho real é o que separa este teste de uma asserção sobre um `fixture` que ninguém
  produz na prática — e é justamente o defeito que a feature corrige: o estado existia no código e
  nunca no dado.
- **Feita quando**: o texto do vínculo ausente aparece na linha; a contagem de pais não conta o
  ausente; e nenhum dos dois depende de cor.
- **Teste**: o próprio arquivo de teste — `render` da lista depois da segunda coleta, com asserção
  sobre o texto **e** sobre a ausência de "more than one parent".

---

## F4 — a conferência que precisa de pessoa

### T009 Conferir no dado real

- **Pronta quando**: T001 a T008 feitas; os dez gates verdes por código de saída; e a pessoa
  mantenedora com a chave mestra no terminal dela.
- **Descrição**: seguir [quickstart.md](quickstart.md) — retrato antes (`1666|0`), sincronizar, e as
  três conferências: os que a origem largou saem da vigência, **só** eles, e nenhum repositório não
  coletado é tocado. Depois a conferência de tela em `/work/repositories/<id>` de `eo_lib`, com as 29
  issues. **A chave mestra não entra no chat nem no repositório.**
- **Feita quando**: a contagem de marcados deixa de ser zero; no `theband` os 157 revistos continuam
  vigentes; a contagem de marcados em repositório inacessível é zero; e alguém **olhou** a coluna em
  `eo_lib`.
- **Teste**: as três consultas SQL do quickstart, com a saída colada no `sprint-review.md`. **Sem
  olho humano na tela, o item fica declarado como pendente** — asserção em HTML não substitui olhar,
  e há quatro telas em `RETOMAR.md` provando que a distinção é real.

---

## Dependências

```text
T001 ──┬── T002 [P]
       ├── T003 [P]
       ├── T004 [P]
       └── T005 ──┬── T006
                  ├── T007 [P]
                  └── T008 (também depende do PR #264)
                             │
                             └── T009
```

**Paralelizáveis**: T002, T003 e T004 tocam o mesmo arquivo de teste em casos diferentes e não
dependem entre si; T007 toca o mesmo arquivo que T006 e vai por último entre os dois.

## Estratégia

**MVP**: T001 + T005. Marca e é chamada — o dado passa a chegar no estado que a tela já exibe.

**O que não entra**: `refused_links`, ciclos, [#261](https://github.com/The-Band-Solution/theband/issues/261)
e [#262](https://github.com/The-Band-Solution/theband/issues/262). São defeitos vizinhos com issue
própria, e refatoração oportunista no mesmo diff precisa de critério de revisão diferente.

## Cobertura dos requisitos

| Requisito | Tarefa |
|---|---|
| FR-001, FR-003 | T001, T006 |
| FR-002 | T001 |
| FR-004 | T005 |
| FR-005 | T006 |
| FR-006 | T002 |
| FR-007 | T001 |
| FR-008, FR-009 | T003 |
| FR-010 | T004 |
| FR-011, FR-012 | T008 |
| FR-013 | T005, T007 |
| FR-014 | nenhuma — `refused_links` fica fora, e a tarefa é **não** tocá-la |
| SC-001 a SC-004, SC-006 | T009 |
| SC-005 | T003 |
