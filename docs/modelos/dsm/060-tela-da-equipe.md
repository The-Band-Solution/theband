# DSM — feature 060, a tela da equipe

<!-- DERIVADO de specs/060-tela-da-equipe/spec.md (US1 a US9, FR-001 a FR-083, SC-001 a SC-021),
     specs/060-tela-da-equipe/tasks.md (T001 a T025, "Dependências e ordem", "Dependências
     externas desta PR"), specs/060-tela-da-equipe/plan.md (D1 a D6, "Ordem de implementação",
     "Perguntas abertas"), specs/060-tela-da-equipe/data-model.md (§1, §2, §3.1, §3.2, §5);
     código: lib/the_band_web/live/teams_live/show.ex:62-181,
     lib/the_band/ontology/seon/eo/commands.ex:110, 155, 214-241, 683-691, 1453,
     lib/the_band/ontology/seon/eo/queries.ex:110-242, 391-453,
     lib/the_band/ontology/seon/eo/visibility.ex:102-160,
     lib/the_band/tenants/access.ex:175-195, 261-299;
     priv/repo/migrations/20260901230000_composicao_de_equipes_e_o_equivoco.exs:52,
     20260827060000_concessao_de_visibilidade.exs:45-74
     em 2026-09-07. Conferido contra as fontes nesta data. Regenerar ao mudar a fonte. -->

## O que esta matriz responde

Nove histórias, quatro PRs propostas. A pergunta é **o que precisa vir antes do quê**, e onde o
fatiamento em PRs cria retrabalho. A recomendação de ordem é **proposta**, dirigida ao Product
Owner — quem decide é ele.

## A legenda

| Sigla | História | Prioridade |
|---|---|---|
| **US1** | Quem está na equipe, e de onde veio cada afirmação — a aba Estrutura e a lista por vínculo | P1 |
| **US2** | Declarar o papel de quem a origem mostra, e alterá-lo | P1 |
| **US3** | A pessoa saiu, e o que ela fez continua contando | P1 |
| **US4** | O vínculo que nunca foi — o equívoco com razão | P1 |
| **US5** | Criar o papel da organização a partir da Estrutura | P1 |
| **US6** | As subequipes: quem compõe esta equipe, desde quando | P2 |
| **US7** | O Dashboard reorganizado: medidas com composição, projetos declarados, e o que está fora deles | P2 |
| **US8** | A visão geral do gestor: *Problemas agora* e *Pessoas* | P2 |
| **US9** | O fluxo da equipe inteira: burn, *Prometido × Entregue*, Monte Carlo | P3 |

Natureza da marca: `D` dado (i lê o que j grava) · `T` tela (i mostra o que j produz, ou vive na
tela que j cria) · `R` regra (i precisa da declaração que j cria) · `E` esquema (i precisa da
coluna ou tabela de j).

## Matriz 1 — na ordem da spec

Célula `(i, j)` marcada = **i depende de j**.

|         | US1 | US2 | US3 | US4 | US5 | US6 | US7 | US8 | US9 |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **US1** |  —  |     |  E  |     |     |     |     |     |     |
| **US2** |  T  |  —  |     |     |  R  |     |     |     |     |
| **US3** |  T  |     |  —  |     |     |     |     |     |     |
| **US4** |  T  |     |     |  —  |     |     |     |     |     |
| **US5** |  T  |  T  |     |     |  —  |     |     |     |     |
| **US6** |  T  |     |     |     |     |  —  |  T  |     |  T  |
| **US7** |  T  |     |     |     |     |  D  |  —  |     |     |
| **US8** |  T  |     |     |     |     |  D  |  D  |  —  |     |
| **US9** |  T  |     |     |     |     |  D  |  T  |     |  —  |

### De onde sai cada marca

| Célula | Natureza | A frase da fonte |
|---|---|---|
| (US1, US3) | `E` | FR-011: *"Vínculo encerrado MUST permanecer na lista, marcado saiu em D, com o período e com quem registrou"* — e FR-021 diz *"Hoje o comando de encerrar grava só a data"*. As colunas `ended_by_user_id` e `end_declared_at` são de `data-model.md` §1, e sem elas a linha de US1 não tem o que renderizar |
| (US2, US1) | `T` | FR-015: *"declarar o papel **na linha da pessoa**"*. A linha é de US1 |
| (US2, US5) | `R` | FR-034: o seletor *"MUST oferecer novo papel…, que abre o formulário de FR-030 sem sair da linha"*; `tasks.md` T019 deixa o cenário 4 `@tag :pending` até T022 |
| (US3, US1) | `T` | US3: *"registra, na linha da pessoa, que ela saiu"*; `tasks.md` T015 |
| (US4, US1) | `T` | US4: *"marca, com uma razão escrita"*, na linha; `tasks.md` T017 |
| (US5, US1) | `T` | FR-029: *"A **Estrutura** MUST listar os papéis da organização"* — a aba é de US1 |
| (US5, US2) | `T` | `tasks.md` T022: *"Ao criar com `linha_de_retorno`, reabrir a linha (destrava T019 c4)"* — o formulário de US5 tem de saber voltar à linha de US2 |
| (US6, US1) | `T` | FR-035: a lista de composições vive na aba Estrutura |
| (US6, US7) | `T` | FR-041 e US6 cenário 6: *"clicar no cartão de uma subequipe … abre o Dashboard daquela subequipe"*. O cartão é artefato do Dashboard, que US7 reorganiza |
| (US6, US9) | `T` | FR-041 e US6 cenário 6 falam do *"gráfico pequeno"* do cartão; o gráfico pequeno é FR-058, requisito de US9 |
| (US7, US1) | `T` | FR-001 a FR-003 (as abas) e FR-043 (*N membros — X observados, Y declarados* em toda medida), que lê a agregação do roster de US1 |
| (US7, US6) | `D` | FR-056: o conjunto é a união distinta *"pela composição vigente **na data do evento**"*. Hoje `compose_teams/4` exige `started_at` e grava *agora* (`commands.ex:233`; migração `20260901230000:52`; spec, tabela *Módulos*), então a composição não tem passado — e a medida de período anterior sairia errada |
| (US8, US1) | `T` | FR-065 (a seção vem antes das medidas, no Dashboard) e FR-068 (*"(f) leva à aba Estrutura"*) |
| (US8, US6) | `D` | FR-070 (contagem **distinta** sobre o conjunto de FR-056) e FR-073 (*Pessoas* agrupadas por subequipe) |
| (US8, US7) | `D` | FR-065 (g): o cartão de *trabalho fora de projeto declarado* conta o que FR-053 (US7) define; FR-071: o cartão do pipeline depende dos projetos declarados que US7 lê |
| (US9, US1) | `T` | os gráficos vivem no Dashboard, que existe como aba a partir de US1 |
| (US9, US6) | `D` | FR-056, igual a (US7, US6) |
| (US9, US7) | `T` | FR-058: *"e um gráfico pequeno em cada cartão de subequipe"* — o cartão é de US7 |

### O que a fonte **não** sustenta, e por isso não foi marcado

- **(US1, US2)** — US1 mostra papel *ou* `papel não declarado` (FR-010). Sem US2 a lista funciona,
  com todas as linhas dizendo *não declarado*. É completude, não bloqueio.
- **(US1, US4)** — o trio do equívoco já existe no esquema desde a migração
  `20260901230000:76-80`. US1 lê colunas que estão lá.
- **(US4, US3)** — FR-028 exige que os **textos** sejam distintos, e o cenário 4 de US4 lê as duas
  linhas lado a lado. É co-desenho de rótulo, não dependência de construção.
- **(US7, US9)** — ver o ciclo 3 abaixo: FR-041 põe o gráfico pequeno no cartão, mas os cenários
  de aceitação de US7 não o mencionam. A marca ficou em (US6, US9), e a ambiguidade está declarada.
- **(US8, US2)** — o cartão (f) conta membros sem papel por `count_memberships_pending_role/2`, que
  já existe (055 FR-018).

## Matriz 2 — reordenada

Ordem: **US1, US3, US2, US5, US4, US6, US7, US9, US8**.

|         | US1 | US3 | US2 | US5 | US4 | US6 | US7 | US9 | US8 |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **US1** |  —  |  E  |     |     |     |     |     |     |     |
| **US3** |  T  |  —  |     |     |     |     |     |     |     |
| **US2** |  T  |     |  —  |  R  |     |     |     |     |     |
| **US5** |  T  |     |  T  |  —  |     |     |     |     |     |
| **US4** |  T  |     |     |     |  —  |     |     |     |     |
| **US6** |  T  |     |     |     |     |  —  |  T  |  T  |     |
| **US7** |  T  |     |     |     |     |  D  |  —  |     |     |
| **US9** |  T  |     |     |     |     |  D  |  T  |  —  |     |
| **US8** |  T  |     |     |     |     |  D  |  D  |     |  —  |

Sobram **quatro marcas acima da diagonal** — `(US1, US3)`, `(US2, US5)`, `(US6, US7)` e
`(US6, US9)`. Cada uma é um ciclo, e nenhuma reordenação as elimina.

### Os blocos

| Bloco | Histórias | O que o mantém junto |
|---|---|---|
| **B1** | US1, US3 | a coluna da saída: US1 a **lê**, US3 a **escreve** |
| **B2** | US2, US5 | o seletor de papel abre o formulário de papel, e o formulário volta à linha |
| **B3** | US4 | nada depende dele; ele depende só da linha de US1 |
| **B4** | US6, US7, US9 | o cartão de subequipe: US6 clica nele, US7 o desenha, US9 põe o gráfico dentro — e US7 e US9 leem a composição com data que US6 declara |
| **B5** | US8 | lê US1, US6 e US7; ninguém o lê |

Ordem entre blocos: **B1 → {B2, B3} → B4 → B5**. B2 e B3 são independentes entre si.

## Os ciclos, e o corte de cada um

### Ciclo 1 — `US1 ⇄ US3`: a coluna que uma lê e a outra escreve

US1 precisa renderizar *"saiu em D, registrado por X"* (FR-011, FR-022); as colunas
`ended_by_user_id` e `end_declared_at` não existem (`data-model.md` §1). US3 precisa da linha de
US1 para pôr o botão.

**Corte proposto**: **declarar o esquema antes das duas**. É o que o `tasks.md` já faz — T008
(migração + schema) está na **Fase 2**, antes da lista (T009, T011) e três fases antes da saída
(T014). A DSM confirma a posição de T008 e diz por que ela não é arbitrária: sem separar a coluna
da história, as duas histórias se esperam.

*Custo se o corte não for feito*: US1 nasce sem a coluna do autor, renderiza `saiu em D` sem quem
registrou, e é reaberta na fase da saída — a mesma linha da tabela editada duas vezes.

### Ciclo 2 — `US2 ⇄ US5`: o seletor e o formulário

US2 precisa de *"＋ novo papel…"* no seletor (FR-034); US5 precisa reabrir a linha de US2 depois de
criar (T022).

**Corte proposto**: **declarar o contrato do retorno antes das duas** — o `linha_de_retorno` que
T022 já nomeia — e **manter as duas na mesma PR**. É bloco, não ordem: separá-las em duas PRs faria
a primeira entregar um caminho que leva a lugar nenhum. O `tasks.md` já as ordena T019 → T022 com o
cenário 4 de US2 em `@tag :pending`, que é a forma honesta de atravessar um ciclo dentro de uma PR:
a lacuna fica **marcada**, não escondida.

### Ciclo 3 — `US6 ⇄ US7 ⇄ US9`: o cartão de subequipe

É o ciclo caro, e o único que **contraria o fatiamento proposto**.

O cartão de subequipe no Dashboard aparece em três lugares da spec:

- **FR-041**, sob o título *"As subequipes"* — logo, requisito de **US6** —, e diz *"cada subequipe
  MUST ser um cartão com as mesmas medidas da tabela **e um gráfico pequeno**, e clicar no cartão
  ou no gráfico MUST abrir o Dashboard daquela subequipe"*;
- **US6, cenário 6**, que é critério de aceitação de US6: *"clica no cartão de uma subequipe **ou no
  gráfico pequeno dele**"*;
- **FR-058**, sob *"O fluxo da equipe inteira"* — requisito de **US9** —, que diz *"e um gráfico
  pequeno em cada cartão de subequipe"*.

E o cartão é artefato do Dashboard, cuja reorganização é **US7** (FR-002, FR-044).

**Corte proposto ao Product Owner**: mover FR-041 de lugar.

1. **o cartão e a porta** (clicar abre o Dashboard da subequipe) passam a ser requisito e
   aceitação de **US7**;
2. **o gráfico pequeno dentro do cartão** passa a ser requisito e aceitação de **US9**;
3. **US6** fica com FR-035 a FR-040 e FR-042 — a seção *Subequipes* da aba Estrutura — e com os
   cenários 1 a 5 e 7. O cenário 6 muda de dono.

Com esse corte, B4 se desfaz em `US6 → US7 → US9`, todas as marcas caem abaixo da diagonal, e o
fatiamento PR 2 → PR 3 → PR 4 passa a valer.

## A DSM concorda com o fatiamento proposto?

O `tasks.md` propõe **PR 1 = US1–US5 · PR 2 = US6 · PR 3 = US7–US8 · PR 4 = US9**.

| PR | Veredito | Por quê |
|---|---|---|
| **PR 1 = US1–US5** | **concorda** | os blocos B1, B2 e B3 estão no topo da ordem e não dependem de nada de B4 nem de B5. A DSM acrescenta duas ordens **dentro** da PR: B1 primeiro (a coluna antes da lista) e B2 inteiro numa fatia só. As duas já estão no `tasks.md` |
| **PR 2 = US6** | **discorda como as histórias estão escritas** | US6 tem duas marcas acima da diagonal — em US7 e em US9. O cenário 6 dela **não é avaliável** ao fim da PR 2: o cartão é da PR 3 e o gráfico pequeno é da PR 4. Com o corte do ciclo 3, passa a concordar |
| **PR 3 = US7–US8** | **concorda** | (US8, US7) é `D` e não tem reverso: dentro da PR, US7 antes de US8. É bloco correto |
| **PR 4 = US9** | **concorda, com uma ressalva** | se o gráfico pequeno do cartão continuar em US9, a PR 4 volta ao componente de cartão que a PR 3 construiu. É retrabalho de um componente — pequeno, mas é exatamente o que esta matriz existe para mostrar. Alternativa: o gráfico pequeno viaja com o cartão na PR 3, e a PR 4 entrega só a série da equipe inteira, o *Prometido × Entregue* e o Monte Carlo |

### Um fatiamento alternativo da PR 1, se o tamanho incomodar

A DSM permite três PRs no lugar de uma, e não recomenda nenhuma delas — só diz que são possíveis:

1. **PR 1a** = a coluna da saída (T008) + US1 (as abas e a lista) — B1 sem a escrita;
2. **PR 1b** = US3 e US4 (saída e equívoco) — B1 fecha, B3 entra;
3. **PR 1c** = US2 e US5 (papel na linha e papéis da organização) — B2 inteiro.

*O custo*: `show.ex` tem 2 138 linhas e é tocado nas três; são três revisões do mesmo módulo e
três medições do teto de consultas (T013). *O ganho*: a primeira tela chega antes, e cada PR tem
uma pergunta só. **Decisão do Product Owner.**

## Matriz 3 — as dependências externas da PR 1

Quatro itens que não são história e que a PR 1 precisa ter antes de a tela existir.

| Sigla | Item | Tarefa |
|---|---|---|
| **E1** | `priv/knowledge_base/ontology/seon/eo/modules/role_grants.yaml` (novo) + `role_grants` em `eo/ontology.yaml` — declara as **duas** concessões, a de visibilidade (que existe no código desde a #369 e nunca foi declarada) e a de gestão | T002 |
| **E2** | regra `github_team_membership_evidence.yaml` → **v3**: saída declarada e equívoco em vínculo observado bloqueiam a recriação enquanto a observação for contínua | T003 |
| **E3** | migração `saida_declarada_com_autor`: `declared_at`, `ended_by_user_id`, `end_declared_at` e os dois `CHECK` | T008 |
| **E4** | migração `concessao_de_gestao_da_estrutura`: tabela `eo_role_structure_management_grants` com o índice parcial | T004 |

Célula marcada = a história **depende** do item externo.

|         | E1 | E2 | E3 | E4 |
|---------|:--:|:--:|:--:|:--:|
| **US1** | R  |    | E  | R  |
| **US2** | R  |    | E  | R  |
| **US3** | R  | R  | E  | R  |
| **US4** | R  | R  |    | R  |
| **US5** | R  |    |    | R  |

E entre os itens: **E4 depende de E1** (`R`) — princípio IV, SC-015: a declaração na base vem
**antes** da tabela e da tela. É por isso que E1 aparece marcado em toda linha: nenhuma história
alcança E4 sem passar por ele.

### O que cada coluna destrava

- **E1** — sem o YAML, a concessão não pode ser criada (SC-015: *100% das medidas e recortes novos
  têm YAML na base antes de aparecer na tela*). Fecha, de passagem, a lacuna herdada da #369: a
  concessão de visibilidade está em `eo_role_visibility_grants` (migração `20260827060000:45`) e
  não está declarada na base.
- **E2** — destrava US3 (FR-026: depois da saída, a coleta não recria) e US4 (FR-027: observação
  nova depois de ausência constatada é retorno). Sem ela, a saída declarada num vínculo observado
  é **desfeita pela coleta seguinte** — ver `estados/vinculo-de-equipe.md`, achado 1.
- **E3** — destrava a **leitura** de US1 (FR-010 *declarado por X em D*, FR-011 *com quem
  registrou*, FR-022 *fim declarado × fim constatado*), a de US2 (`declared_at`) e a **escrita** de
  US3.
- **E4** — destrava toda ação de escrita (FR-006) e o cenário 6 de US1 (*quem não gere lê a lista
  inteira e não vê ação nenhuma*).

### O item externo que a PR 2 vai precisar, e ninguém listou ainda

`eo_team_compositions.started_at` é `null: false` (migração `20260901230000:52`) e
`compose_teams/4` grava *agora* (`commands.ex:233`). FR-037 exige *"data de início **ou em branco = desconhecido**"*.
É uma **quinta** migração, e ela não está na lista de dependências externas da PR 1 porque é da
PR 2 — mas as marcas `(US7, US6)`, `(US8, US6)` e `(US9, US6)` desta matriz dependem dela: sem
composição com passado, o conjunto de FR-056 *na data do evento* não existe. **Vale declará-la
junto do fatiamento da PR 2.**

## `[NEEDS CLARIFICATION]`

1. **A quem pertence FR-041?** O requisito está sob *"As subequipes"* (US6), o cartão é do
   Dashboard (US7) e o gráfico pequeno é FR-058 (US9). A proposta deste documento é o corte do
   ciclo 3; a decisão é de quem prioriza. **A quem**: Product Owner.
2. **A que PR pertence o conjunto de FR-056** (a união distinta de membros da equipe inteira)?
   US7, US8 e US9 o exigem, e a spec o classifica como *derivado, não persistido* (Key Entities).
   Quem construir primeiro paga; quem vier depois reusa. E ele precisa de **emenda de medida na
   base antes da tela** (`spec.md`, *Base de conhecimento*, linha *"o conjunto de membros da
   equipe composta"*), o que o torna também um item externo. **A quem**: Product Owner, com quem
   mantém a base.
3. **A PR 4 pode encostar no cartão da PR 3?** Se sim, o gráfico pequeno fica em US9 e a ressalva
   da PR 4 é aceita como custo. Se não, ele viaja na PR 3. **A quem**: Product Owner.
