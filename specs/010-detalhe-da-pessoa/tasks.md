# Tarefas — Feature 010: o detalhe da pessoa

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/person-detail.md](contracts/person-detail.md) · **Quickstart**:
[quickstart.md](quickstart.md)

**Nove tarefas, três fases.** Dois padrões introduzidos, cinco recusados, **nenhuma migração** — a
feature só lê.

Ordem: F1 → F2 → F3.

**MVP**: as três. F1 e F2 **não são entregáveis sozinhas** — função pública testada e sem consumidor
visível não é funcionalidade entregue, e é a L21. Por isso a página está no mesmo sprint.

**F1 vem primeiro porque é o achado da feature**: 88 evidências de vínculo e **zero** vínculos
materializados. Sem ela a tela mostraria trabalho e esconderia a distinção que o produto existe para
fazer.

---

## Fase F1 — O que a origem declara sobre a pessoa

- [ ] T001 [US2] Listar as equipes que a origem declara
  - **Pronta quando**: o contrato em `contracts/person-detail.md` declara `list_person_teams/2`
  - **Descrição**: acrescentar a função em `lib/the_band/ontology/seon/eo/queries.ex`, com o
    `defdelegate` em `lib/the_band/ontology/seon/eo.ex`. **Uma consulta**, juntando
    `eo_team_membership_evidence` com `eo_teams` e `eo_organizations`, devolvendo por equipe: nome,
    **organização** (FR-007), `platform_access_level`, `observed_at`, `last_observed_at`,
    `no_longer_observed_at` e se a evidência foi **promovida** — `promoted_membership_id` não nulo.

    **`platform_access_level` é dado da ferramenta**, e o nome do campo tem de dizer isso: `MEMBER` e
    `MAINTAINER` são permissões, não papéis. Nenhum campo devolvido pode se chamar `role`
    (FR-004)
  - **Feita quando**: para uma pessoa em duas equipes de organizações diferentes, a consulta devolve
    as duas com a organização de cada; a evidência não promovida vem marcada como não promovida
  - **Teste**: `test/the_band/ontology/seon/eo/person_teams_test.exs` — o caso que importa é a pessoa
    em **duas organizações**, exigindo que cada linha diga qual é; e a asserção de que **nenhuma chave
    do mapa se chama `role`**

- [ ] T002 [US2] Contar os papéis cadastrados
  - **Pronta quando**: T001 concluída
  - **Descrição**: `EO.count_roles/1`, lendo `eo_organizational_roles`. Existe para a tela
    **explicar** a não promoção com base no **dado**, e não em texto fixo — R4.

    **Medido, e é o que afia o terceiro caso**: `eo_organizational_roles` tem só `code` e `name` —
    catálogo do tenant, sem pessoa nem equipe —, e `eo_team_memberships.organizational_role_id` é
    **NOT NULL**. Então a contagem responde *"é possível promover alguém?"*, e a **ausência de linha**
    em `eo_team_memberships` responde *"e esta pessoa?"*.

    Três casos, **todos verificáveis**, e o terceiro é impossível hoje e vai existir:

    | promovida? | papéis | a tela diz |
    |---|---:|---|
    | sim | — | o vínculo existe, com o papel |
    | não | **0** | não promovida **porque nenhum papel foi cadastrado** — impossível para qualquer pessoa |
    | não | > 0 | não promovida **porque ninguém alocou papel a esta pessoa nesta equipe** — a #100 |

    A versão anterior desta tarefa dizia, no terceiro caso, *"a causa não é a ausência de papel"* —
    frase plausível e sem conteúdo, que a análise recusou. Texto fixo daria a explicação errada com
    convicção no dia em que alguém cadastrar papel, e ninguém notaria
  - **Feita quando**: devolve **0** no dado real; devolve 1 depois de um papel inserido no teste
  - **Teste**: o mesmo arquivo de T001 — zero e um, e a asserção de que a contagem é **por tenant**

---

## Fase F2 — O trabalho derivado

- [ ] T003 [US3] Contar designações e autorias separadas
  - **Pronta quando**: o contrato declara as duas funções
  - **Descrição**: `count_assigned_to/2` e `count_authored_by/2` em
    `lib/the_band/work_items/queries.ex`, com os `defdelegate` em `lib/the_band/work_items.ex`.

    **São duas funções, não uma com parâmetro de papel.** O nome é onde a distinção sobrevive: uma
    `count_issues_of_person/2` obrigaria quem chama a explicar qual sentido queria, e quem lê a
    descobrir. Contam **issues vigentes** — `no_longer_observed_at` nulo, nos dois lados.

    **Nenhuma função devolve a soma**, e o contrato não a oferece: 4 232 designações e 4 241 autorias
    não se somam (FR-009).

    **A issue manda sobre a designação**, e é o achado A2 da análise: há duas marcas de ausência — em
    `collected_issues` e em `issue_assignees` —, e issue ausente **não conta** nem com designação
    vigente. A pessoa não trabalha no que a plataforma não observa mais (FR-008a). Sem esta regra
    escrita, a implementação escolheria em silêncio
  - **Feita quando**: para uma pessoa com 12 designações e 7 autorias, devolvem **12** e **7**;
    designação ausente não conta; **issue ausente com designação vigente também não**
  - **Teste**: `test/the_band/work_items/person_work_test.exs` — as duas contagens; a designação
    ausente; e o caso que a análise achou: **issue ausente com designação vigente**, exigindo que não
    conte. **Nenhum teste soma as duas**, porque nada no código deveria poder somá-las

- [ ] T004 [US3] Filtrar issues por pessoa, com dois nomes
  - **Pronta quando**: T003 concluída
  - **Descrição**: `escopo/2` em `lib/the_band/work_items/queries.ex` ganha **duas** opções distintas
    — `assigned_to:` e `authored_by:` —, usadas por `list_issues/2`, que já pagina.

    **Nunca uma opção `person_id:`** que sirva às duas: a mesma palavra para duas coisas esconde qual
    delas está sendo pedida, e é a **L34** aplicada antes de doer.

    A ordem estável continua `observed_repository_id`, `number`, `id` — ordenar só por número daria
    páginas que se sobrepõem, porque o número repete entre repositórios
  - **Feita quando**: as duas opções devolvem conjuntos **diferentes** para a mesma pessoa; a
    paginação e a ordem seguem valendo
  - **Teste**: o mesmo arquivo de T003 — uma pessoa designada numa issue e autora de outra, exigindo
    que cada opção devolva **só** a sua. Se as duas devolverem o mesmo conjunto, o filtro está
    ignorando o papel

- [ ] T005 [US3] Agrupar os repositórios da pessoa
  - **Pronta quando**: T003 concluída
  - **Descrição**: `repositories_of_person/2` em `WorkItems`, **uma consulta agrupada**, devolvendo
    por repositório as **duas** contagens: designadas e abertas por ela.

    **Nunca a soma**, e nunca uma consulta por repositório: a feature 007 nasceu com 135 consultas por
    render exatamente por não decidir isto (FR-016).

    **Ela NÃO devolve o nome do repositório**, e é de propósito: o nome é de **CMPO**, e `WorkItems`
    juntar `cmpo_source_repositories` quebraria a fronteira que o princípio IX protege. Quem chama
    resolve com **uma** consulta — `CMPO.list_observed/1` virando mapa —, como o `onde/2` da feature
    007. **Uma consulta por repositório violaria FR-016**, e foi o achado A1 da análise.

    O vínculo pessoa-repositório é **derivado** — a origem nunca o declarou —, e quem chama precisa
    receber a evidência para poder dizer isso na tela (FR-010)
  - **Feita quando**: uma pessoa com issues em dois repositórios recebe as duas linhas, com as duas
    contagens em cada; desenhar isso faz **uma** consulta
  - **Teste**: o mesmo arquivo de T003 — dois repositórios, e a asserção de que a linha traz
    `assigned` e `authored` **separados**

---

## Fase F3 — A página

- [ ] T006 [US1] Abrir a página da pessoa
  - **Pronta quando**: T001 concluída; o contrato declara `fetch_person/2`
  - **Descrição**: `EO.fetch_person/2` e o LiveView em
    `lib/the_band_web/live/people_live/show.ex`, com a rota `/people/:id` em
    `lib/the_band_web/router.ex`. O identificador é o **interno**: login é da origem, muda, e não é
    único entre instâncias — a L25.

    A página mostra identidade e proveniência: origem, identificador na origem, e desde quando é
    observada (FR-002). Pessoa de outro tenant devolve **não encontrado**, nunca "sem permissão" —
    confirmar existência já é vazamento (FR-015)
  - **Feita quando**: a página abre para as 75 pessoas; a de outro tenant responde não encontrado; a
    proveniência aparece
  - **Teste**: `test/the_band_web/live/person_detail_test.exs` — o caso que importa é o **de outro
    tenant**, exigindo não encontrado e `refute html =~ "permission"`

- [ ] T007 [US1] Ligar o nome à página
  - **Pronta quando**: T006 concluída
  - **Descrição**: em `lib/the_band_web/live/people_live/index.ex`, o nome da pessoa passa a ser link
    para `/people/:id` (FR-001). Hoje não é link, e não existe para onde ir.

    O alvo de toque no telefone vem do design system e já existe; a tarefa é não quebrá-lo
  - **Feita quando**: toda linha da lista tem link; o link não cobre nem substitui o resto da célula
  - **Teste**: o mesmo arquivo de T006 — contar os links da lista e exigir **um por pessoa**

- [ ] T008 [US2] Dizer o que a plataforma não promoveu
  - **Pronta quando**: T002 e T006 concluídas
  - **Descrição**: a seção de equipes na página, com um **componente privado do LiveView** para a
    origem da relação — três formas, e as três com texto e rótulo acessível:

    ```
    equipe declarada pela origem   → sólida     observado
    repositório onde ela aparece   → hachurada  derivado
    vínculo que deixou de existir  → tracejada  ausente, com a data
    ```

    **Privado do LiveView**, e não em `TheBandWeb.UI`: há **dois** usos na mesma tela — a lista de
    equipes e a de repositórios —, que é exatamente o limiar do projeto. A análise corrigiu a
    contagem: "vínculo ausente" **não** é um terceiro uso, porque é a mesma lista de equipes com a
    forma mudando conforme `no_longer_observed_at`.

    O critério de promoção para `TheBandWeb.UI` é o segundo consumidor **fora** desta tela — R5.

    A explicação da não promoção vem do **dado** (T002), com os três casos — e o terceiro é
    verificável, não vago: com papéis cadastrados e **sem linha** em `eo_team_memberships` para aquela
    pessoa e equipe, a causa é *ninguém alocou papel a ela nesta equipe*, que é a #100. E **nenhum texto** usa a
    palavra *role* ao lado de `MEMBER` ou `MAINTAINER` (FR-004).

    Vínculo com `no_longer_observed_at` aparece **com a data**, dizendo que houve vínculo e ele não
    está presente — as duas falhas típicas são omitir e mostrar como atual (FR-006)
  - **Feita quando**: a página diz que nenhuma evidência foi promovida e **por quê**; a equipe traz a
    organização e o nível de acesso; o vínculo que saiu aparece tracejado com a data; com a cor
    removida os três estados continuam distinguíveis
  - **Teste**: o mesmo arquivo de T006 — quatro asserções que importam: a frase da não promoção muda
    quando existe papel; `refute html =~ ~r/role/i` na seção de equipes; o vínculo ausente **aparece**
    e não como atual; e o teste que remove as classes de cor e ainda distingue as três formas

- [ ] T009 [US3] Mostrar o trabalho sem somar
  - **Pronta quando**: T005 e T006 concluídas
  - **Descrição**: as seções de issues e repositórios na página. Designadas e abertas **separadas**,
    com rótulos distintos, e a lista paginada com o total no cabeçalho (FR-008, FR-011).

    **A soma é proibida** (FR-009): 12 designações e 7 autorias mostram 12 e 7, **nunca 19**.

    Os repositórios aparecem **hachurados**, com a evidência nomeada — designação, autoria, ou as duas
    (FR-010). E a ausência é **nomeada**: pessoa sem designação e sem autoria tem as duas ausências
    ditas, nunca `0` sozinho (FR-013)
    O nome de cada repositório vem do mapa de **CMPO** (A1), montado com **uma** consulta
  - **Feita quando**: os dois números aparecem separados e a soma não aparece; cada repositório traz
    **nome e organização**, com a marca de derivado e a evidência; pessoa sem trabalho tem as duas
    ausências nomeadas; a lista pagina; desenhar a página faz **oito** consultas
  - **Teste**: o mesmo arquivo de T006 — três asserções que importam. A que **procura o número
    proibido**: com 12 e 7, `refute html =~ ">19<"`, o mesmo formato que na feature 006 achou um
    defeito real que eu havia introduzido. A que exige **nome de repositório** na linha, e não
    identificador. E a que **conta as consultas** de uma renderização, exigindo **oito** — "um número
    que não cresce" não é asserção, e era o que o quickstart dizia

---

## Dependências

```text
T001 → T002 ──────────────┐
T003 → T004               ├──→ T006 → T007
   └──→ T005 ─────────────┘        └──→ T008
                                   └──→ T009
```

T001 antes de T002 porque a contagem de papéis só faz sentido ao lado das evidências que ela explica.
T006 é a página, e nada dela pode ser verificado antes.

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T001 e T003 | fronteiras diferentes: EO e WorkItems |
| T004 e T005 | consultas diferentes, no mesmo módulo mas em pontos distintos |
| T008 e T009 | seções diferentes da mesma página |

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 (o nome é link) | T007 |
| FR-002 (identidade e proveniência) | T006 |
| FR-003, FR-007 (equipes com nível de acesso e organização) | T001, T008 |
| FR-004 (nível de acesso **não** é papel) | T001, T008 — e o teste com `refute` |
| FR-005 (a não promoção é explicada) | T002, T008 |
| FR-006 (vínculo ausente com data) | T008 |
| FR-008, FR-011 (designadas e abertas, paginadas) | T004, T009 |
| FR-008a (issue ausente não conta) | T003 — e o teste do cruzamento |
| **FR-009 (a soma é proibida)** | T003, T009 — e o teste procura o número proibido |
| FR-010 (repositório é derivado) | T005, T009 |
| FR-012 (forma e texto, nunca só cor) | T008 |
| FR-013 (ausência nomeada) | T009 |
| FR-014 (abre para qualquer pessoa) | T006 |
| FR-015 (isolamento entre tenants) | T006 |
| FR-016 (nenhuma consulta por linha) | T005 |
| FR-017 (legível em 360 px) | T008, T009 |

**18 de 18 requisitos com tarefa.** SC-001 a SC-012, mais SC-009a, verificados por V1 a V10 do
[quickstart](quickstart.md).

## Estratégia de entrega

**As três fases são o MVP**, e o corte por fase não produz entrega: F1 e F2 são consultas sem
consumidor, e a L21 diz que isso não é funcionalidade entregue.

**O corte possível é por user story**, e a ordem é a da spec: US1 (a página abre, com proveniência),
US2 (as equipes e a não promoção), US3 (o trabalho). Cada uma é verificável sozinha, e US1 sem as
outras duas já entrega o clique que hoje não existe.

## Fora do escopo, e ficou de fora

| Item | Por quê |
|---|---|
| cadastrar papel, ou promover a evidência | é a #99 e a #100; esta feature **exibe** a ausência |
| módulo que monte a página | dissolveria a fronteira entre EO e WorkItems — princípio IX |
| `count_issues_of_person/2` | produziria a soma que FR-009 proíbe |
| derivar papel de nível de acesso | mapear por semelhança de nome — princípio II |
| um lugar para as 288 issues sem autor | não têm pessoa; e a spec não inventa tela para elas |
| ordenar ou filtrar as issues da pessoa | não foi pedido; a paginação resolve |
