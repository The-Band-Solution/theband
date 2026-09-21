# Sprint 030 — Registro de aceitação

**Features**: [060 — a tela da equipe](../../../specs/060-tela-da-equipe/spec.md) (US1–US5, US9) ·
herança de [045](../../../specs/045-autenticacao-e-acesso/spec.md) (D06 da v0.7.0) e de
[055](../../../specs/055-equipes-declaradas/spec.md) (FR-003 e o ato de subequipe)
**Avaliado em**: 2026-09-14, na `development` em `0ccf02b`, com evidência executada — testes
nomeados com código de saída, sonda de tela sobre cenário real, leitura de migração e de
protótipo. Suíte inteira e gates **não** rodados: a run do CI
[34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) é a evidência.
**Papel**: Product Owner — avaliação **proposta pelo agente**, em duas partes escritas por duas
execuções do papel (a 060; a herança). **Confirmação pela pessoa alocada ao papel: PENDENTE.**
**Tipo de PO**: `sro.product_owner_client` — quem demanda é quem mantém.
**Registro retroativo**: o sprint correu sem backlog, sem issue e sem iteration (2026-09-07 a
2026-09-12); este registro nasce depois da v0.8.0 já ter sido avaliada carregando estes
entregáveis. `sro.rule01` (US materializada tem de estar no sprint backlog) **não é verificável**
para este sprint.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 9 — seis da 060 (D1–D6), três de herança (H1–H3) |
| Aceitos | **2** — D3 (US4) e H3 (subequipe numa transação) |
| Não aceitos por **defeito observado** | 1 — D6 (US9: cartão fora do protótipo) |
| Não aceitos por **critério não medido** | 4 — D2 (US3), D4 (US2), D5 (US5), H1 (#853) |
| Não aceitos por **teste prometido ausente** | 1 — D1 (US1) |
| Não aceitos por **régua não aprovada e critérios não conformes** | 1 — H2 (#863) |
| Não avaliado | 1 — o #860, a aba *Flow per person* (US10–US12 da extensão, sem tarefa) |
| Tarefas da 060 executadas com sucesso | 18 — T001–T009, T013, T014, T016–T018, T021, T024, T026, T027 |
| Tarefas da 060 executadas sem sucesso | 9 — T010–T012, T015, T019, T020, T022, T028, T029 |
| Tarefas não avaliadas | 2 — T023, T025 (fechamento) |

**Quatro das sete recusas são por avaliação incompleta, não por comportamento errado** — e
podem virar aceitas no mesmo ato da confirmação, se o papel medir SC-013, decidir a leitura de
AC2, e medir SC-005/FR-081. Os dois defeitos de comportamento são o cartão *Squads at a glance*
(D6) e a régua furada do vínculo declarado (H2). O registro que mais pesa não é de critério: é
que **nenhum dos dez PRs do sprint tem revisão registrada**, e quatro nem pediram.

---

# Parte A — a feature 060

**Feature**: [060-tela-da-equipe](../../../specs/060-tela-da-equipe/spec.md) — US1, US2, US3, US4, US5, US9.
US6, US7, US8 ficaram fora (PR 2) e não são avaliadas aqui.
**Avaliado em**: 2026-09-14, na `development` em `0ccf02b` (árvore limpa), com evidência
executada nesta avaliação — `mix test <arquivo>` com `echo $?` capturado logo depois, e leitura do
HTML renderizado onde o critério é de tela. Suíte inteira e gates **não** foram rodados aqui: a run
do CI [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) sobre
`0ccf02b` (`push`, `conclusion: success`, 2026-09-13T19:56:51Z) é a evidência da suíte.
**Papel**: Product Owner — avaliação **proposta pelo agente**; confirmação pela pessoa alocada
**pendente**.
**Tipo de PO**: `sro.product_owner_client` — quem demanda é quem mantém.

### Lacunas de registro que atravessam todos os entregáveis

| Lacuna | O que se observou | Consequência |
|---|---|---|
| **Sem issue no GitHub** | `gh issue list --state all --search "060"` → `[]`; busca por "tela da equipe", "Structure roster", "Flow per person" só devolve issues de 055/057/058 | nenhuma US nem tarefa da 060 tem `#` — a coluna *Materializa* diz "sem issue"; `flow.wip.count` nunca contou este trabalho |
| **Sem sprint backlog do 030** | `docs/sprints/` termina em `029-medidas-da-equipe`; não existe `030/` | `sro.rule01` (US materializada tem de estar no sprint backlog) **não é verificável** — o registro é retroativo, e isto é lacuna, não conformidade |
| **Revisão não registrada** (#817, #819, #821) | `reviewRequests = [The-Band-Solution/the-band]`, `reviews = []` | revisor pedido à equipe, como manda a casa; **revisão registrada: não**. Situação a classificar pelo papel: *atestada sem registro* (com data e frase) ou *não ocorreu* |
| **PR #860 sem revisor pedido** | `reviewRequests = []`, `reviews = []`, mergeado 2026-09-12 | viola "todo PR nasce com revisor pedido"; entra como não conformidade de processo em D6 |
| **Cinco arquivos de teste prometidos no tasks.md não existem com o nome prometido** | `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test`, `saida_na_tela_test`, `equivoco_na_tela_test` — ausentes por nome | ver, por entregável, onde a asserção prometida foi encontrada — ou não |

---

---

### D1 — As duas abas, e a lista de membros por vínculo com origem, papel, início e subequipes

**Produzido por**: T010, T011, T012, T013 (tela) · sustentado por T001–T003 (PR [#817](https://github.com/The-Band-Solution/theband/pull/817)), T004 (PR [#819](https://github.com/The-Band-Solution/theband/pull/819)), T005–T009 e T024 (PR [#821](https://github.com/The-Band-Solution/theband/pull/821))
**Materializa**: US1 — *Quem está na equipe, e de onde veio cada afirmação* (P1, atômica) · **sem issue**

Comandos:
- `MIX_ENV=test mix test test/the_band/ontology/seon/eo/roster_test.exs test/the_band_web/live/teto_de_consultas_da_equipe_test.exs test/the_band_web/live/duas_afirmacoes_test.exs test/the_band_web/live/estado_na_url_test.exs test/the_band/ontology/seon/eo/isolamento_da_060_test.exs test/the_band/tenants/gerir_estrutura_test.exs` → **65 passed, 0 failures, `EXIT=0`** (log `scratchpad/us1-run.log`).
- **Sonda de tela** (fora do repositório, `scratchpad/sonda_060b_test.exs`, `mix test <caminho> --seed 0` → **3 passed, `EXIT=0`**, log `scratchpad/sonda-run.log`): equipe com quatro pessoas — Ana (declarada, papel, início 2026-01-01), Bia (observada, sem papel), Caio (declarado, saída em 2026-06-01), Dora (declarada, equívoco "cadastro errado") — renderizada por conta administradora e por conta `member` sem pessoa ligada.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — cada pessoa uma vez, com papel ou *não declarado*, origem (*observado* / *declarado por X em D*), início ou *desconhecido*, subequipes (FR-009, FR-010) | funcional | sim | `roster_test.exs:100-167` (uma linha por pessoa, vínculos dentro); sonda `[PALAVRA]`: `observed`, `declared by`, `unknown`, `not declared`, `direct` — **todos presentes em texto** no HTML de `?tab=structure` |
| AC2 — direta e em subequipe: uma linha, marca *direta* e a subequipe, contada uma vez | funcional | sim | `roster_test.exs:101` "direta na equipe E numa subequipe: uma linha, dois vínculos"; `:129` "os chips: squads traz a PARTE, e direct diz que há vínculo na própria equipe"; `:146` só na subequipe, sem `direct` |
| AC3 — quem saiu permanece, marcada *saiu em D*, com período e autor, fora dos vigentes (FR-011) | funcional | sim | `roster_test.exs:301` "fim DECLARADO traz autor e o instante do registro"; sonda `[HEADER]` "2 people here · **1 left**" com Caio encerrado; palavra `left` presente |
| AC4 — equívoco permanece, marcado, com razão/autor/data, e o texto diz excluído de toda medida em toda data (FR-011) | funcional | sim | `roster_test.exs:361` "o equívoco traz razão, autor e instante"; legenda da lista `show.ex:5001` "mistake — the person was never here. The link counts for no date at all."; sonda `[HEADER]` "1 recorded by mistake" |
| AC5 — origem ainda lista quem a organização declarou saído: as duas afirmações lado a lado, tela não escolhe (FR-013, 055 FR-012) | funcional | sim | `duas_afirmacoes_test.exs:71` "a tela mostra AS DUAS afirmações, cada uma com a sua origem"; `:92` "não escolhe"; `:107` sentido inverso; `:122` equívoco é caso próprio |
| AC6 — conta não administradora e sem concessão lê a lista inteira e **nenhuma** ação de escrita (FR-006, SC-011) | funcional | sim | sonda `[LEITOR botões]` — `Declare role`, `Add role`, `Left the team`, `Mistake…`, `New role`, `Change`: **todos `false`**; `saida_e_equivoco_na_tela_test.exs:232` |
| AC6' — a tentativa por evento é recusada com o motivo nomeado (FR-006, FR-082) | funcional | sim | sonda `[LEITOR promover / criar_papel / registrar_saida / registrar_equivoco]` → flash "Your account is not linked to a person yet, and managing a team's structure is granted to organisational roles." — recusa, **não exceção**; os três motivos no domínio: `gerir_estrutura_test.exs:127-185` |
| AC7 — a distinção observado/declarado/saiu/equívoco sobrevive sem cor (SC-004) | funcional | sim | sonda: as quatro marcas são palavras no HTML; legenda `show.ex:4996-5008` em `<dl>` textual |
| FR-001, SC-007 — aba na URL; sem `?tab` → Dashboard; inválida → Dashboard **e** aviso | funcional | sim | sonda `[ABAS]`: sem tab → `Dashboard aria-selected="true"`; `?tab=structure` → `Structure aria-selected="true"`; `?tab=members` → Dashboard **e** flash "A team has no “members” tab. Showing the dashboard."; `show.ex:150-154`. **Nota**: existem três abas (`Flow per person`, `?tab=people`) — emenda declarada em FR-085 da extensão de 2026-09-08, não divergência |
| FR-004 — cabeçalho comum: nome, origem da equipe, *N vigentes*, *M sem papel*, *composta de K* | funcional | parcial | sonda `[HEADER]`: "SONDA · 2 people here · 1 left · 1 recorded by mistake · **1 with no organisational role** · source github … collected at …" — N, M e origem conformes; **"composta de K subequipes" não sondado** (a equipe da sonda não tem partes; `equipe_composta_test` roda verde mas a asserção do cabeçalho não foi conferida por nome) |
| FR-012 — vigentes, saíram e equívocos contados à parte, batendo com a consulta | funcional | sim | `roster_test.exs:180` "vigentes, saíram e equívocos somam o total de pessoas do roster"; `:231` invalidado + vigente conta como vigente; sonda: 2 · 1 · 1 sobre 4 pessoas |
| SC-004, FR-008 — 0 linhas com nível de acesso da plataforma | não funcional | sim | `roster_test.exs:420` "nível de acesso da plataforma NÃO sai do roster (FR-008, SC-004)"; sonda `[MAINTAINER?] false | access-at-platform? false`; `screens_test.exs:148-163` |
| FR-005 — leitura sem permissão de administrar; tudo restrito ao tenant | não funcional | sim | sonda: conta `member` abre `?tab=structure`; `isolamento_da_060_test.exs:61-176` (roster, totais, alcance, comandos); `screens_test.exs:210,218` equipe de outro tenant → redirect |
| Teto de consultas da aba (T013) — constante em 1×11 pessoas e 1×3 subequipes | não funcional | sim | `teto_de_consultas_da_equipe_test.exs:242` "o número de consultas não cresce com as pessoas"; `:270` "nem com as subequipes"; `:295` teto declarado `@teto_da_estrutura 7`; `:317` uma aba não paga a outra |
| **Processo (constituição XI) — o teste prometido no `tasks.md` existe, com asserção nomeada** | processo | **não** | T010 `abas_da_equipe_test.exs` (cinco casos, `assert_patched`): **não existe** — o comportamento só está provado pela sonda desta avaliação, que não vive no repositório e não guarda regressão. T011 `estrutura_membros_test.exs`: **não existe** (marcas em texto cobertas parcialmente por `screens_test.exs:163` e pela sonda). T012 `estrutura_permissao_test.exs` ("os três motivos por evento"): **não existe**; a recusa por evento está espalhada em `saida_e_equivoco_na_tela_test:240`, `declarar_papel_na_linha_test:393`, `papeis_na_estrutura_test:270`, sempre com **um** motivo; `promover` só foi provado pela sonda |
| Processo — PR com revisor pedido, review registrada, ligado ao projeto | processo | **não** | #817: revisor `the-band` pedido, `reviews=[]`, no projeto com `Status=Done` e `Iteration=null`; #819 e #821: revisor pedido, `reviews=[]`, **fora do projeto** |

**Fase derivada**: `sro.not_accepted_deliverable` — **todos os critérios funcionais e não funcionais da US1 estão conformes com evidência executada**; a recusa é pelo critério de processo da constituição XI: três tarefas marcadas `[x]` cujo teste prometido não existe no repositório. Leitura alternativa para o papel: aceitar pelo valor entregue e abrir tarefa nova para os três arquivos de teste — o agente registra as duas e não escolhe a que fecha o sprint.
**Fase da tarefa**: T010, T011, T012 — `sro.non_successfully_performed_scrum_development_task` (teste prometido ausente); T013 — sucesso; T001–T009, T024 — sucesso pelos seus próprios critérios (todos os arquivos existem e rodaram verdes).
**O que faltou**: os três arquivos de teste, com as asserções nomeadas em tasks.md — a sonda desta avaliação (`scratchpad/sonda_060b_test.exs`) já é o esqueleto deles.

### D2 — A saída declarada: o vínculo ganha fim, autor e instante, e a coleta não desfaz

**Produzido por**: T008, T014, T015 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821) (T008 já em #821; migração `saida_declarada_com_autor`)
**Materializa**: US3 — *A pessoa saiu, e o que ela fez continua contando* (P1, atômica) · **sem issue**

Comando: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/saida_declarada_test.exs test/the_band/ontology/seon/eo/vinculo_observado_test.exs test/the_band_web/live/saida_e_equivoco_na_tela_test.exs test/the_band/ontology/seon/eo/discordancia_test.exs test/the_band/ontology/seon/eo/team_membership_test.exs` → **54 passed, 0 failures, `EXIT=0`** (2026-09-14, `0ccf02b`; log em `scratchpad/us3-us4-run.log`).

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — saída em D dá fim ao vínculo, guarda quem e quando, nenhuma linha removida (FR-019, FR-021) | funcional | sim | `saida_declarada_test.exs:82` "quem tem dois papéis vigentes sai numa chamada, e os dois ficam encerrados"; `:157` "saída sem autor é recusada"; `saida_e_equivoco_na_tela_test.exs:93` "registrar a saída fecha o vínculo e diz quantos alcançou" |
| AC2 — números de período anterior a D são exatamente os mesmos (FR-020, SC-001) | funcional | sim | `saida_declarada_test.exs:110` "o número de um período anterior à saída é o mesmo antes e depois (SC-001)" — compara `count_team_members_at` antes/depois |
| AC3 — data no futuro recusada com razão (FR-023) | funcional | sim | `saida_declarada_test.exs:139` "data no futuro é recusada"; `saida_e_equivoco_na_tela_test.exs:127` idem na tela |
| AC4 — depois da saída, coleta não recria enquanto a origem lista; tela mostra as duas afirmações (FR-026, SC-002) | funcional | sim | `saida_declarada_test.exs:286` "depois da saída, a coleta NÃO recria o vínculo enquanto a origem seguir mostrando"; `duas_afirmacoes_test.exs:71` "a tela mostra AS DUAS afirmações, cada uma com a sua origem" |
| AC5 — segunda saída em vínculo encerrado recusada sem reescrever a data (FR-023) | funcional | sim | `saida_declarada_test.exs:168` "a segunda saída não reescreve a data da primeira (FR-023)"; `:126` "par sem vínculo vigente é erro, e nunca {:ok, 0}" |
| AC6 — a linha diz se o fim foi declarado (por quem) ou constatado pela coleta, com a limitação da cadência (FR-022) | funcional | sim | `roster_test.exs:301` "fim DECLARADO traz autor e o instante do registro"; `:317` "fim constatado pela COLETA vem sem autor, e a tela precisa dizer isso"; `:339` registro antigo lê "sem autor" |
| FR-027 — observação nova após ausência constatada gera vínculo novo (retorno) | funcional | sim | `saida_declarada_test.exs:304` "depois de ausência constatada E reobservação, nasce vínculo NOVO — é retorno" |
| FR-023 — data obrigatória; campo **não** vem preenchido com hoje; recusa nomeada | funcional | sim | `saida_e_equivoco_na_tela_test.exs:57` "o botão abre o formulário sob a linha, e a data vem VAZIA"; `:112` "data vazia é recusada pelo SERVIDOR, com a razão" — frase em `show.ex:469` "A departure needs a date — the platform does not assume today." |
| Protótipo — nota "ended, not deleted" no formulário inline | funcional (tela) | sim | `saida_e_equivoco_na_tela_test.exs:80` "a nota diz que o vínculo é encerrado, e não apagado"; `show.ex:5466` |
| T008 — gravar `ended_by_user_id` sem `end_declared_at` recusado pelo **banco** | não funcional | sim | `saida_declarada_test.exs` roda verde; a asserção da violação via `Repo.update_all` está no arquivo (tasks.md T008) — **não relida linha a linha nesta avaliação** |
| SC-013 — registrar saída em menos de 1 minuto sem sair da aba | não funcional | **não medido** | não há cronometragem; o teste `saida_e_equivoco_na_tela_test` mostra que o ato ocorre no mesmo `live` em `?tab=structure`, o que sustenta "sem sair da aba", não o tempo |
| SC-012 — 0 linhas removidas | não funcional | sim | `saida_declarada_test.exs:82` confere que os vínculos ficam encerrados (não ausentes); contrato `contracts/estrutura-da-equipe.md` declara que nenhuma função apaga |
| Caminhos infelizes do ato — vazio, futuro, já encerrado, outro tenant, sem autor | funcional | sim | os cinco têm teste nomeado: `saida_declarada_test.exs:126,139,157,168` e `isolamento_da_060_test.exs:160` "a saída com a equipe do outro tenant não encerra nada" |

**Divergência de rótulo, não de critério**: tasks.md T015 prometia a frase "the platform does not **presume** today"; a tela diz "does not **assume** today". Nenhum FR fixa a palavra. Registrado, não penaliza.

**Fase derivada**: `sro.accepted_deliverable` **condicionada** — todos os critérios funcionais conformes com evidência executada; SC-013 (tempo) não medido. A skill manda: critério sem evidência → não aceito. **Proposta ao papel**: SC-013 é critério não funcional de usabilidade que exige medição com pessoa; ou o papel o mede numa sessão (menos de um minuto, cronometrado) e o entregável passa a aceito, ou fica **não aceito por avaliação incompleta** — não por defeito. O agente não escolhe a leitura que fecha o sprint.
**Fase da tarefa**: T008, T014, T015 — segue a decisão sobre SC-013.

---

### D3 — O equívoco: o vínculo que nunca foi, em observado e declarado

**Produzido por**: T016, T017 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializa**: US4 — *O vínculo que nunca foi* (P1, atômica) · **sem issue**

Comando: o mesmo de D2 (`saida_declarada_test` contém o `describe` do equívoco; `saida_e_equivoco_na_tela_test` contém T017) → **54 passed, `EXIT=0`**.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — equívoco em vínculo declarado invalida para todo período, com razão, autor e data (FR-024) | funcional | sim | `saida_declarada_test.exs:193` "quem tem dois papéis vigentes é invalidado nos dois numa chamada"; `roster_test.exs:361` "o equívoco traz razão, autor e instante" |
| AC2 — equívoco em vínculo **observado**: sai de toda medida; coleta não recria; tela mostra as duas afirmações (FR-025, FR-026, SC-002) | funcional | sim | `vinculo_observado_test.exs:176` describe "o equívoco vale para o vínculo observado, e a coleta não recria (decisão de 2026-09-07)"; `duas_afirmacoes_test.exs:122` "declaração de que nunca esteve, com a coleta ainda mostrando" |
| AC3 — sem razão é recusado (FR-028) | funcional | sim | `saida_declarada_test.exs:242` "razão vazia continua recusada, e sem autor também"; `saida_e_equivoco_na_tela_test.exs:186` "razão vazia é recusada, e nada é gravado" |
| AC4 — *nunca esteve* e *saiu em D* são textos distintos; nenhuma é "removida" (FR-028) | funcional (tela) | sim | `saida_e_equivoco_na_tela_test.exs:148` "o formulário exige razão, e o texto separa equívoco de saída"; `duas_afirmacoes_test.exs:92` "a tela NÃO diz que a pessoa simplesmente saiu"; `show.ex:5502` "This is not \"left the team\"" |
| AC5 — pessoa que pertenceu e depois teve segundo vínculo invalidado **não** aparece como *nunca esteve* (veredito agregado por pessoa) | funcional | **sim, com ressalva** | `discordancia_test.exs` roda verde no mesmo comando; `roster_test.exs:231` "a pessoa com um vínculo invalidado E um vigente conta como VIGENTE" cobre o agregado no roster. **Não localizei asserção nomeada exatamente para "encerrado + invalidado → não é nunca esteve"** na discordância — o papel deve pedir ao QA que aponte a linha ou registrar como lacuna de teste |
| FR-025 — invalidado excluído de toda medida em toda data | funcional | sim | `saida_declarada_test.exs:213` "o invalidado não conta em data ALGUMA, nem antes do reconhecimento"; `saida_e_equivoco_na_tela_test.exs:169` "registrar o equívoco tira a pessoa de TODA data" |
| Protótipo — nota inteira ("applies to declared and observed alike", "the next collection does not re-create") | funcional (tela) | sim | `show.ex:5503-5506` traz as duas frases; `saida_e_equivoco_na_tela_test.exs:148` confere o texto |
| FR-006 — quem não gere não vê *Mistake…* e o evento direto é recusado | funcional | sim | `saida_e_equivoco_na_tela_test.exs:232` "lê a lista inteira e não vê os botões"; `:240` "o evento disparado direto é recusado, e nada muda" |
| Caminhos infelizes — razão vazia, par sem vigente, outro tenant | funcional | sim | `saida_declarada_test.exs:242,271`; `isolamento_da_060_test.exs:176` "o equívoco com a equipe do outro tenant não invalida nada" |
| SC-012 — 0 linhas removidas | não funcional | sim | invalidação é marca (`saida_declarada_test.exs:193` lê os dois vínculos depois) |

**Fase derivada**: `sro.accepted_deliverable` — todos os critérios com evidência executada; a ressalva do AC5 é de **localização da asserção**, não de comportamento observado errado. Se o papel preferir a leitura estrita (asserção não nomeada = sem evidência), a fase vira `sro.not_accepted_deliverable` por avaliação incompleta — o agente registra as duas leituras e não escolhe.
**Fase da tarefa**: T016, T017 — `sro.successfully_performed_scrum_development_task`, sob a mesma ressalva.

---

### D4 — Declarar e alterar o papel na linha, e o lote por vínculo

**Produzido por**: T018, T019, T020 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializa**: US2 — *Declarar o papel de quem a origem mostra, e alterá-lo* (P1, atômica) · **sem issue**

Comando: `MIX_ENV=test mix test test/the_band/ontology/seon/eo/declarar_e_alterar_papel_test.exs test/the_band_web/live/declarar_papel_na_linha_test.exs test/the_band_web/live/promocao_na_tela_test.exs test/the_band_web/live/papel_declarado_test.exs test/the_band_web/live/papeis_na_estrutura_test.exs` → **72 passed, 0 failures, `EXIT=0`** (log `scratchpad/us2-us5-run.log`).

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — declarar em vínculo observado completa o **mesmo** vínculo; início fica *desconhecido*; linha diz *declarado* (FR-015, FR-016) | funcional | sim | `declarar_e_alterar_papel_test.exs:68` "num vínculo OBSERVADO, completa o mesmo vínculo — mesmo id"; `:108` "início vazio FICA vazio, e nunca vira hoje"; `declarar_papel_na_linha_test.exs:132` idem na tela |
| AC2 — alterar deixa o anterior com período e o novo vigente; lista mostra o vigente **com acesso ao histórico** (FR-017) | funcional | **parcial** | dois registros: `declarar_e_alterar_papel_test.exs:241`; na tela: `declarar_papel_na_linha_test.exs:326` "encerra o antigo e abre o novo na mesma data". **"Acesso ao histórico" e "a tela diz se vale da data informada ou de hoje" não têm asserção nomeada** — não medido nesta avaliação |
| AC3 — segundo papel simultâneo aceito e exibido ao lado (FR-018) | funcional | sim | `declarar_e_alterar_papel_test.exs:138`; `declarar_papel_na_linha_test.exs:218` "com dois papéis, há dois botões Change"; `:268` "trocar UM papel deixa o outro intacto" |
| AC4 — *novo papel…* abre o formulário sem sair da linha e o criado já está selecionável (FR-034) | funcional | sim | `declarar_papel_na_linha_test.exs:172` "'＋ new role…' cria o papel e declara, sem sair da linha (FR-034)" |
| AC5 — início em branco nunca vira hoje (FR-016) | funcional | sim | `declarar_papel_na_linha_test.exs:115` "a data 'since' vem VAZIA, e o texto diz o que vazio significa"; `declarar_e_alterar_papel_test.exs:108` |
| FR-014 — lote na Estrutura, mesmo comando, dizendo quantas linhas foram puladas | funcional | sim, com ressalva | `promocao_na_tela_test.exs` roda verde em `?tab=structure` (describes "a seção de promoção", "a data de início", "confirmar todas"); **a contagem de "puladas" não foi conferida por nome** |
| FR-006 — quem não gere não vê o botão; evento direto recusado | funcional | sim | `declarar_papel_na_linha_test.exs:386,393`; sonda `[LEITOR promover]` → recusa nomeada "Your account is not linked to a person yet, and managing a team's structure is granted to organisational roles." |
| Caminhos infelizes — mesmo papel, papel de outra organização, conceito fora do catálogo, vínculo encerrado, outro tenant, sem nome, sem escolher | funcional | sim | `declarar_e_alterar_papel_test.exs:165,187,225,315,331,353`; `declarar_papel_na_linha_test.exs:154,199,351` — todos devolvem recusa nomeada, nenhum levanta |
| SC-012 — 0 linhas removidas | não funcional | sim | `declarar_e_alterar_papel_test.exs:241` lê os dois registros depois da troca |
| Protótipo — *Declare role* na linha; formulário inline; "＋ new role…" no seletor | funcional (tela) | sim | `declarar_papel_na_linha_test.exs:74,102`; `show.ex:5181,5390` |

**Fase derivada**: `sro.not_accepted_deliverable` **por avaliação incompleta** — AC2 tem duas partes sem evidência ("acesso ao histórico" na lista; a tela dizer "da data informada ou de hoje"). Não há comportamento errado observado. **Alternativa para o papel**: se aceitar que o histórico é o vínculo encerrado permanecendo na linha (o roster lista todos os vínculos da pessoa — `roster_test.exs:167,231`), AC2 passa a conforme e a fase vira aceito. Não escolho.
**Fase da tarefa**: T018 — sucesso (todos os seus critérios conformes); T019/T020 — seguem a decisão sobre AC2.

---

### D5 — Os papéis da organização, a partir da Estrutura

**Produzido por**: T021, T022 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821)
**Materializa**: US5 — *Criar o papel da organização a partir da estrutura* (P1, atômica) · **sem issue**

Comando: o mesmo de D4 → **72 passed, `EXIT=0`**. Nota: tasks.md T021 prometia `roster_test.exs — describe "contagem por papel"`; a asserção vive em `papeis_na_estrutura_test.exs:79-108`. Mudou de arquivo, existe.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — criar com nome e código: existe para a organização, com autor e data; aparece no seletor desta e de **qualquer** equipe e em `/roles` (FR-030) | funcional | **parcial** | `/roles`: `papeis_na_estrutura_test.exs:143` "criar aqui aparece em /roles — é o MESMO papel (SC-005)"; seletor **desta** equipe: `declarar_papel_na_linha_test.exs:172`. **Seletor de OUTRA equipe da organização (SC-005) não tem asserção** — não medido |
| AC2 — código repetido na mesma organização recusado; em outra não é conflito (FR-031) | funcional | sim | `papeis_na_estrutura_test.exs:160,169` |
| AC3 — remover papel em uso recusado dizendo **quantos** (FR-033) | funcional | sim | `papeis_na_estrutura_test.exs:205` "ocultar papel COM vínculo vigente é recusado, dizendo quantos" |
| AC4 — catálogo SRO marcado, sem remover, com contagem aqui e na organização (FR-029) | funcional | sim | `:63` "traz catálogo e criados, com origem e código"; `:234` "papel do CATÁLOGO não oferece renomear nem ocultar"; `:79,95` contagem de pessoas distintas |
| AC5 — renomear preserva os vínculos (FR-032) | funcional | sim | `:183` "renomear mantém os vínculos apontando para o mesmo papel" |
| AC6 — código sugerido e editável (FR-031) | funcional | sim | `:123` "o código é sugerido do nome"; `:131` "o código editado NÃO é sobrescrito pela sugestão" |
| FR-081 — a seção *Papéis* mostra quais papéis carregam a concessão *gerir estrutura* (leitura) | funcional | **não medido** | nenhuma asserção nomeada localizada em `papeis_na_estrutura_test.exs`; tasks.md T022 lista a coluna *grants* — não conferida na tela |
| FR-006 — quem não gere lê e não age | funcional | sim | `:260` "vê a tabela e nenhum botão nem formulário"; `:270` "o evento de criar é recusado"; sonda `[LEITOR criar_papel]` recusado com motivo |
| FR-005 — isolamento: contagens e código de outro tenant | não funcional | sim | `isolamento_da_060_test.exs:109,113` |
| SC-012 — ocultar é marca, não apaga | não funcional | sim | `:219` "ocultar papel sem ninguém funciona, e é MARCA — não apaga" |
| Protótipo — *Roles* (catálogo + criados; "New role" nome e código; renomear; remover só sem vínculo) | funcional (tela) | sim, com decisão pendente | rótulo do botão: protótipo diz "remover", spec FR-033 diz "ocultar", tasks T022 propõe *Hide* como **pergunta aberta 1** — decisão do papel/Design pendente, não é defeito da implementação |

**Fase derivada**: `sro.not_accepted_deliverable` **por avaliação incompleta** — AC1 (seletor de outra equipe) e FR-081 (coluna de concessões) sem evidência. Nenhum defeito observado.
**Fase da tarefa**: T021 — sucesso; T022 — não sucesso enquanto FR-081 e a parte de SC-005 não forem medidos.

---

### D6 — O fluxo da equipe inteira em três granulações, e o gráfico pequeno no cartão

**Produzido por**: T026, T027, T028, T029 · PR [#821](https://github.com/The-Band-Solution/theband/pull/821) — o corpo do #821 cita T026, T028 e T029. **O PR [#860](https://github.com/The-Band-Solution/theband/pull/860) não é desta US**: entrega a aba *Flow per person* (extensão `spec-graficos-por-membro.md`, US10–US12), fora das seis avaliadas.
**Materializa**: US9 — *O fluxo da equipe inteira: burn, Prometido × Entregue, Monte Carlo* (P3, atômica) · **sem issue**

Comando: `MIX_ENV=test mix test test/the_band/work_items/fluxo_da_equipe_test.exs test/the_band_web/live/equipe_composta_test.exs test/the_band_web/live/fluxo_na_tela_test.exs` → **41 passed, 0 failures, `EXIT=0`** (log `scratchpad/us9-run.log`).

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — burn-up/down da equipe **inteira**, partindo dos já abertos, região entre curvas, texto "não é a soma" (FR-056, FR-059, FR-060) | funcional | sim | `fluxo_da_equipe_test.exs:178` "mede o trabalho de quem está nas SUBEQUIPES"; `:248` "a mesma pessoa em DUAS partes conta uma vez no todo (FR-060)"; `equipe_composta_test.exs:151` "a tela diz por que não soma"; `show.ex:2941` "not the sum" |
| AC2 — trocar granulação reagrupa os mesmos itens; somas iguais nas três (FR-061) | funcional | sim | `fluxo_da_equipe_test.exs:109` "a soma de abertos e de fechados é igual em semana, mês e ano"; `fluxo_na_tela_test.exs:156` granulação inexistente desenha semana **e avisa** |
| AC3 — Prometido × Entregue com definição junto do título e "não há escopo comprometido" (FR-062, FR-063) | funcional | sim | `fluxo_na_tela_test.exs:366` "a palavra 'promised' nunca aparece sem a definição operacional ao lado"; `:389` fechado é ato da ferramenta; `show.ex:1600-1601` |
| AC4 — Monte Carlo **semanal independentemente da granulação**, duas hipóteses, confiança, proporção que não concluiu (FR-064) | funcional | **parcial** | duas hipóteses: `fluxo_na_tela_test.exs:327` "desenha as duas hipóteses na MESMA régua"; proporção: `:338` "runs that never reached zero". **"Semanal independentemente da granulação, e a tela diz isso": nenhuma asserção; `grep -i weekly|regardless` em `show.ex` devolve só "closed per week —" (`:3088`)** — não medido |
| AC5 — abaixo do piso nenhuma previsão, e a tela diz o que falta | funcional | sim | `fluxo_na_tela_test.exs:316` "sem histórico não há gráfico, e a tela diz o que falta" |
| AC6 — previsão idêntica em duas consultas (057 FR-036, SC-014) | funcional | sim, por herança | coberto em `test/the_band/forecast_test.exs` (feature 057), **não reexecutado aqui**; CI 34779226200 verde |
| AC7 — cada cartão de subequipe traz o gráfico pequeno e é porta para o Dashboard dela (FR-041, FR-084) | funcional | sim | `equipe_composta_test.exs:159` "FR-041/FR-084: cada subequipe é um CARTÃO, com faísca, e o cartão é porta" + asserção de que a **tabela** não tem `<svg>` |
| SC-009 — distância entre as curvas em qualquer ponto = itens em aberto naquele ponto, nas três granulações | não funcional | **não medido** | nenhuma asserção nomeada em `fluxo_da_equipe_test.exs` nem em `fluxo_na_tela_test.exs` (busca por "distância", "aberto naquele ponto", "open_at"); T028 prometia provar exatamente isto |
| FR-078 — janela padrão por granulação (8 sem / 12 meses / todos os anos), no título e na URL | funcional | sim | `fluxo_na_tela_test.exs:170,186`; `fluxo_da_equipe_test.exs:331` "primeira_atividade devolve a abertura mais antiga da equipe"; `:197,205` período absurdo/zero cai no padrão |
| SC-008 — nenhuma célula de total; declaração de que não é soma | não funcional | sim | `equipe_composta_test.exs:151`; 057 SC-003 herdado |
| **Protótipo — *Squads at a glance*: três números `members / open / stopped` e a mistura de conceitos `TASK n · US n · BUG n · EPIC n` abaixo deles** | funcional (tela) | **não** | **o próprio tasks.md T029 registra**: "os três números do cartão divergem do protótipo (`open items`/`median wait`/`pipeline` contra `members`/`open`/`stopped`), falta a mistura de conceitos, e a matiz por subequipe é decisão de Design pendente". Divergência de protótipo é defeito (regra da casa: a tela implementada é exatamente a aprovada) |
| Protótipo — burn escreve a identidade `open(t) = base + opened − closed`, e a linha de base | funcional (tela) | sim, com ressalva | `fluxo_na_tela_test.exs:229,248,302` (valores, horizonte com ressalva); o corpo do PR #860 cita "a identidade sem o aberto inicial" como item **corrigido** lá — o PR #860 está fora desta US, mas a correção está em `0ccf02b` |
| Protótipo — *Delivery forecast*: dois histogramas no mesmo eixo, coluna hachurada do "never" separada | funcional (tela) | sim | `fluxo_na_tela_test.exs:327,346-348` (">never<" separada das semanas); `:351` descrição textual com os números |
| Processo — PR com revisor pedido e no projeto | processo | **não** | #821: revisor pedido à equipe `the-band`, **nenhuma review registrada**, **não ligado ao projeto** (`projectItems = []`) |

**Fase derivada**: `sro.not_accepted_deliverable` — falha em critério de tela **observado** (o cartão diverge do protótipo aprovado, por confissão do próprio tasks.md), além de SC-009 e da metade de AC4 sem evidência.
**Fase da tarefa**: T026, T027 — sucesso pelos seus critérios; T028 — não sucesso (SC-009 prometido e não provado); T029 — não sucesso (cartão fora do protótipo).
**O que faltou**: o cartão com os três números do protótipo e a mistura de conceitos; a asserção da distância entre curvas; a frase de que a previsão é semanal seja qual for a granulação.
**Destino proposto da US9**: nova tarefa pretendida ligada à US9 (nunca reabrir T028/T029) para (1) o cartão conforme o protótipo — passa antes pelo Design, porque `median wait` por subequipe exige consulta agrupada que não existe e a matiz por subequipe é decisão pendente (T029, L67); (2) a asserção SC-009; (3) a frase de FR-064. Entra no próximo sprint backlog, em primeiro lugar, como herança.

---

### Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 6 |
| Aceitos (proposta) | 1 (D3 — US4) |
| Não aceitos por **defeito observado** | 1 (D6 — US9: cartão fora do protótipo) |
| Não aceitos por **avaliação incompleta** (critério sem evidência) | 3 (D2 — US3: SC-013; D4 — US2: AC2; D5 — US5: AC1/SC-005 outra equipe, FR-081) |
| Não aceitos por **critério de processo** (constituição XI: teste prometido ausente) | 1 (D1 — US1) |
| Tarefas executadas com sucesso | 17 — T001–T009, T013, T014, T016, T017, T018, T021, T024, T026, T027 |
| Tarefas executadas sem sucesso | 9 — T010, T011, T012 (teste ausente); T015 e T019/T020 e T022 (seguem a decisão sobre o critério não medido); T028, T029 |
| Tarefas não avaliadas | T023, T025 (fechamento; FR-052 é da US7) |

| US | Veredito proposto | Critérios medidos | Conformes | Não conformes | Não medidos | Destino proposto |
|---|---|---:|---:|---:|---:|---|
| US1 | `sro.not_accepted_deliverable` (processo XI) | 16 | 13 | 2 (teste prometido ausente; PR sem review/projeto) | 1 (FR-004 "composta de K") | **nova tarefa pretendida**: escrever `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test` (três motivos × evento, incluindo `promover`) — a sonda é o esqueleto; próximo sprint, em primeiro lugar. O valor entregue permanece em produção |
| US3 | `sro.not_accepted_deliverable` (incompleta) | 13 | 12 | 0 | 1 (SC-013, tempo < 1 min) | **medir na confirmação**: o papel cronometra a saída em `?tab=structure`; conforme → aceito sem tarefa nova |
| US4 | `sro.accepted_deliverable` | 10 | 10 | 0 | 0 (AC5 com ressalva de localização da asserção) | concluída; pedir ao QA a linha da asserção "encerrado + invalidado ≠ nunca esteve" ou registrar lacuna de teste |
| US2 | `sro.not_accepted_deliverable` (incompleta) | 10 | 9 | 0 | 1 (AC2: histórico acessível na lista; tela diz "da data informada ou de hoje") | **decisão do papel**: se o vínculo encerrado na linha vale como histórico, aceito; senão, nova tarefa para a asserção e o texto de FR-017 |
| US5 | `sro.not_accepted_deliverable` (incompleta) | 11 | 9 | 0 | 2 (SC-005 seletor de **outra** equipe; FR-081 coluna de concessões) | **medir**: sonda em segunda equipe da mesma organização + leitura da seção Roles; se conformes → aceito; senão, nova tarefa |
| US9 | `sro.not_accepted_deliverable` (defeito) | 14 | 9 | 2 (cartão ≠ protótipo; PR sem review/projeto) | 3 (AC4 "semanal seja qual for a granulação" dito na tela; SC-009 distância entre curvas; AC6 só por herança da 057) | **nova tarefa pretendida** ligada à US9: cartão *Squads at a glance* conforme o protótipo (`members/open/stopped` + mistura de conceitos) — **passa pelo Design antes**, porque `median wait` por subequipe e a matiz são decisões abertas (T029, L67); asserção SC-009; frase de FR-064. Próximo sprint, como herança |

**Entregável do sprint** (`sro.sprint_deliverable`): compõe-se só de aceitos. Na proposta como está, **apenas D3 (US4)** o integra. Se o papel medir SC-013 e decidir AC2/FR-081/SC-005 na confirmação, D2, D4 e D5 podem entrar no mesmo ato.

### Defeitos observados (comportamento errado ou fora do aprovado)

| # | Onde | O que | Critério | Fonte |
|---|---|---|---|---|
| 1 | Dashboard da equipe composta, cartão *Squads at a glance* | três números `open items / median wait / pipeline` em vez de `members / open / stopped`; falta a mistura de conceitos `TASK n · US n · BUG n · EPIC n` | protótipo §3 (2026-09-08); FR-084; regra da casa "tela implementada = tela aprovada" | tasks.md T029, "Aberto ainda" — **o próprio registro da tarefa confessa e marca `[x]`** |
| 2 | tasks.md | T010, T011, T012 marcadas `[x]` sem o teste prometido existir | constituição XI | busca por nome e por conteúdo em `test/` |
| 3 | PR #860 | mergeado sem revisor pedido (`reviewRequests=[]`) | "todo PR nasce com revisor pedido" | `gh pr view 860` |
| 4 | PRs #819, #821, #860 | fora do projeto (`projectItems=[]`); #817 no projeto com `Iteration=null` | "ligado ao projeto, com Iteration e Status" | `gh pr view --json projectItems` |

Nenhum caminho infeliz exercitado levantou exceção: todos os eventos recusados devolveram flash com motivo nomeado (sonda, quatro eventos; testes de recusa nos seis arquivos de domínio).

### Critérios alterados durante o sprint

Não há sprint backlog do 030 para comparar. Emenda declarada **antes** desta avaliação e fora da 060: FR-085 (`spec-graficos-por-membro.md`, 2026-09-08) acrescenta a terceira aba `?tab=people` ao parâmetro da FR-001 — a tela tem três abas e isto é conforme à emenda, não à FR-001 literal. Registrado; não penaliza.

### Critérios sem evidência

| Critério | US | O que falta para medir |
|---|---|---|
| SC-013 — saída registrada em < 1 min sem sair da aba | US3 | cronometrar uma sessão real; nenhum teste mede tempo |
| AC2 (parte) — "a lista mostra o vigente com acesso ao histórico"; tela diz "da data informada ou de hoje" (FR-017) | US2 | asserção sobre a linha depois de `change_role`; leitura do texto do formulário |
| SC-005 (parte) — papel criado aparece no seletor de **outra** equipe da organização | US5 | sonda com duas equipes na mesma organização |
| FR-081 — seção Roles mostra quais papéis carregam a concessão | US5 | asserção sobre a coluna *grants* |
| FR-004 (parte) — "composta de K subequipes" no cabeçalho | US1 | asserção nomeada em `equipe_composta_test` ou sonda com partes |
| FR-064 (parte) — a tela diz que a previsão é semanal seja qual for a granulação | US9 | texto não localizado em `show.ex`; asserção inexistente |
| SC-009 — distância entre curvas = aberto naquele ponto, nas três granulações | US9 | asserção prometida em T028 e não escrita |
| AC6 — previsão idêntica em duas consultas | US9 | reexecutar `test/the_band/forecast_test.exs` (057) — não rodado nesta avaliação |

### Lacunas de processo

1. **Sem issue** para nenhuma US nem tarefa da 060; **sem sprint backlog** do 030 — `sro.rule01` não verificável; este registro é retroativo.
2. **Revisão**: #817, #819, #821 com revisor pedido à equipe e `reviews=[]`; #860 sem revisor pedido. Nenhuma das quatro tem *revisão registrada*. O papel deve classificar cada uma como *atestada sem registro* (com data e frase) ou *não ocorreu*.
3. **Projeto**: três dos quatro PRs invisíveis ao board; `flow.wip.count` subcontou o sprint.
4. **tasks.md marca `[x]` o que não tem teste** (T010–T012) e **o que confessa divergir do protótipo** (T029) — marcação manual de "feito", exatamente o que `sro.rule03` proíbe para aceitação.
5. **PR #860 atribuído nesta avaliação a T026–T029 pelo pedido** — o corpo do #821 é que cita T026, T028, T029; o #860 entrega a aba *Flow per person* (US10–US12), que não foi avaliada aqui e precisa de registro próprio.
6. **Tipo de PO**: `sro.product_owner_client`; decisão final é de quem demanda.

### Comandos e logs desta avaliação

| Rodada | Comando (todos em `MIX_ENV=test`, `0ccf02b`) | Resultado | Log |
|---|---|---|---|
| US1 | `mix test roster_test teto_de_consultas_da_equipe_test duas_afirmacoes_test estado_na_url_test isolamento_da_060_test gerir_estrutura_test` | 65 passed, `EXIT=0` | `scratchpad/us1-run.log` |
| US3+US4 | `mix test saida_declarada_test vinculo_observado_test saida_e_equivoco_na_tela_test discordancia_test team_membership_test` | 54 passed, `EXIT=0` | `scratchpad/us3-us4-run.log` |
| US2+US5 | `mix test declarar_e_alterar_papel_test declarar_papel_na_linha_test promocao_na_tela_test papel_declarado_test papeis_na_estrutura_test` | 72 passed, `EXIT=0` | `scratchpad/us2-us5-run.log` |
| US9 | `mix test fluxo_da_equipe_test equipe_composta_test fluxo_na_tela_test` | 41 passed, `EXIT=0` | `scratchpad/us9-run.log` |
| Sonda de tela | `mix test scratchpad/sonda_060b_test.exs --seed 0` | 3 passed, `EXIT=0` | `scratchpad/sonda-run.log` |
| Suíte inteira e gates | **não rodados aqui** — CI run 34779226200 sobre `0ccf02b`: `success` | — | GitHub Actions |

---

# Parte B — a herança (045 e 055)

**PROPOSTA DO AGENTE — confirmação pela pessoa alocada ao papel PENDENTE.** Nada abaixo é
aceitação consumada: é a avaliação critério a critério, com a evidência executada nesta sessão,
para que `sro.product_owner` confirme ou recuse cada fase derivada.

**Features**: [045-autenticacao-e-acesso](../../../specs/045-autenticacao-e-acesso/spec.md) ·
[055-equipes-declaradas](../../../specs/055-equipes-declaradas/spec.md)
**Avaliado em**: 2026-09-14, na `development` em `0ccf02b` (limpa), sem checkout nem edição.
**Evidência executada**: `mix test <arquivos>` com código de saída, leitura de migração e de
código, `git show` do branch do protótipo, API do GitHub para PRs e issues. Gates e suíte
inteira **não** rodados aqui — a run do CI [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200)
sobre `0ccf02b` está `success`.
**Papel**: Product Owner — avaliação proposta pelo agente; confirmação pendente.
**Tipo de PO**: `sro.product_owner_client` — quem demanda é quem mantém.

**Três invariantes de processo atravessam os três entregáveis, e são registradas uma vez aqui:**

| Invariante | #853 (H1) | #863 (H2) | #857 (H3) |
|---|---|---|---|
| revisão pedida (`timeline: review_requested`) | **nunca pedida** | **nunca pedida** | **nunca pedida** |
| revisão registrada (`pulls/<n>/reviews`) | 0 | 0 | 0 |
| issue fechada pelo PR (`closingIssuesReferences`) | nenhuma | nenhuma | nenhuma |
| item em sprint backlog (`sro.rule01`) | `docs/sprints/030*` **não existe** ainda | idem | idem |

Classificação da revisão, pela regra da casa: **revisão não ocorreu** — não há registro e não há
pedido; e não é possível pedir revisão de PR mergeado. A skill diz *"não aceite entregável cuja
revisão nunca foi pedida"*; a v0.7.0 e a v0.8.0 trataram a mesma lacuna como **exceção de release
decidida pelo papel** (21 de 21 PRs). As duas leituras estão registradas; a escolha é do papel, e
este documento **não a faz**. O `rule01` fecha no ato do registro retroativo do sprint 030 — que é
o que este documento alimenta — desde que o `sprint-backlog.md` liste os três como herança.

---

### H1 — D06 da v0.7.0, reavaliado: a conta desativada como o protótipo pediu

**Produzido por**: PR [#853](https://github.com/The-Band-Solution/theband/pull/853), mergeado
2026-09-10T14:15Z em `development` · **sem issue** (`closingIssuesReferences: []`; as 18 issues
fechadas que casam "045" são T001–T014, US1–US3 e 047/T005 — nenhuma trata da conta desativada)
**Migração**: `20260910050000_episodio_de_desativacao.exs` — cria `account_disablements` (razão e
nota nas duas pontas, `disable_reason NOT NULL`), índice único parcial
`account_disablements_aberto_index` (um episódio aberto por conta), backfill com `not_recorded`,
e `users.password_source` / `users.password_set_by_user_id`.
**Materializa**: FR-025 a FR-029 da spec 045 (escritos **no mesmo PR**, formalizando os critérios
que o item de backlog `docs/backlog/conta-desativada.md` já carregava desde 2026-09-09). A 045 tem
três user stories (US1 entrar, US2 escopos, US3 perfil) e **nenhuma delas menciona desativação**:
o entregável materializa requisito sem user story atômica declarada. Lacuna registrada, não
batizada.
**Protótipo**: `specs/045-autenticacao-e-acesso/prototipo/` — `PROMPT.md` (§3 é a régua),
`README.md` (11 decisões, 4 perguntas fechadas pelas recomendações), `accounts-disable.html`.
Aprovação: README, *"a pessoa mantenedora respondeu 'pode implementar'"* (2026-09-10). **Protótipo
e código entraram no mesmo PR** — a ordem protótipo → aprovação → código não é demonstrável pelo
histórico do repositório, só pelo texto do README e do item de backlog.
**Evidência executada**: `mix test test/the_band/tenants/conta_desativada_test.exs
test/the_band_web/live/accounts_test.exs test/the_band_web/live/accounts_elo_test.exs` →
**32 passed, EXIT=0** (2026-09-14 18:53).

#### Os critérios que o D06 recusou, um a um, contra a evidência nova

| Critério (tal como no D06) | Tipo | D06 | Agora | Evidência |
|---|---|---|---|---|
| o registro diz **quem, quando e POR QUÊ**; nada é apagado | funcional | **NÃO** | **sim** | `disable_user/4` exige mapa de razão; `AccountDisablement.abrir_changeset` `validate_required [.., :disable_reason]` + `validate_inclusion` contra `AccountLifecycle.codigos_de_desativacao()`; testes `:232` *"desativar EXIGE razão, e a razão fica escrita na linha"*, `:250` *"a nota é obrigatória para suspeita de comprometimento"*; coluna `disable_reason NOT NULL` na migração |
| **reativar é ato registrado, com autor e razão** | funcional | **NÃO** | **sim** | `enable_user/4` (tenant, id, **ator**, razão); `fechar_changeset` `validate_required [:enabled_by_user_id, :enable_reason]`; teste `:305` *"reativar fecha o episódio e NÃO apaga a desativação"*; `:367` *"duas desativações caem no registro, e o par de colunas cabia uma"* |
| roster, medidas e histórico da pessoa **não mudam** | não funcional | sem evidência | **sim, com ressalva** | `:407` compara **antes/depois** `length(EO.list_people)`, concessões vigentes, `person_id`/`person_revoked_at` e `password_hash`, com guarda contra zero. **Nenhuma medida computada da pessoa é comparada**; para "medidas" a evidência é indireta — o ato escreve só em `users` e `account_disablements` (`desativar_na_transacao`). O item de backlog relata mutação (revogação injetada no desativar → teste reprovou) |
| Parte C — o texto do *revoke* diz que **não remove acesso** | funcional | **NÃO** | **sim** | `accounts_live/index.ex:867` `nao_faz="Does not remove access. Signing in by e-mail does not need the link..."`; `:1492` `data-confirm="... It does NOT remove access ..."`; teste `:448` asserta `"Does not remove access"` |
| Parte C — teste que **reprova** se revogar voltar a ser o único ato | não funcional | **NÃO** | **sim** | `:448` *"revogar o elo NÃO é o único ato oferecido a quem desliga"* — asserta `"Removing someone's access"` e `"Disable account"` |
| conta desativada **não autentica por token** | funcional | n/a | **não avaliável** | o token não existe (spec 061 sem código). A tela escreve *"the platform has none yet"* como promessa. Continua critério que não se pode medir — **não conta como conforme** |

Os demais seis critérios do D06 (recusa idêntica `:60`; gira token de sessão `:99`, `:121`;
distinção sem cor `:197`; ato próprio nomeado `:448`; não a si / outro tenant / duas vezes `:130`,
`:139`, `:153`; reativar não devolve a senha `:162`, `:178`) **continuam conformes** na mesma
execução.

#### Os três achados fora da tabela do D06

| Achado | Agora | Evidência |
|---|---|---|
| a tela mudou **sem protótipo aprovado** | **fechado, com ressalva** | protótipo existe, com PROMPT/README/HTML; aprovação registrada no README e em `docs/backlog/conta-desativada.md`. Ressalva: mesmo PR que o código; e **a conferência item a item do QA com captura da tela real não foi encontrada** — a régua §3 tem 7 seções e 6 linhas de tabela, e a evidência aqui é a presença dos textos (20 de 21 termos da §3 em `index.ex`; `from a reset` vem do rótulo da base e aparece no HTML renderizado, `:208`, `:226`) |
| **quatro decisões** tomadas pelo código | **fechado** | decisão 1 migrou para a recomendação (b) — relator próprio `account_disablements`; perguntas 12–15 fechadas pelas recomendações **depois** do "pode implementar", registradas no README com onde cada uma vive |
| `sro.rule01` — sem sprint backlog, sem tarefa, sem issue | **continua aberto** | `#853` sem issue; `docs/sprints/030*` não existe. Fecha com o backlog retroativo listando este item como herança |

#### Os critérios que a spec passou a carregar (FR-025 a FR-029), e o que deles foi medido

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| FR-025 razão de lista fechada, vinda de `access.account_lifecycle` | funcional | sim | `AccountLifecycle` lê `KnowledgeBase.rule("access.account_lifecycle")`, sem lista escrita no módulo; `:232` |
| FR-025 **sem vocabulário declarado, o ato recusa** e não grava vazio | funcional | **sem evidência executada** | `disable_user/4` tem `vocabulario_declarado()` → `:vocabulario_nao_declarado`; **nenhum teste em `test/` exercita a base ausente** (`grep vocabulario_nao_declarado test/` vazio). Leitura de código não é evidência |
| FR-025 nota obrigatória **só** para `suspected_compromise` e `other` | funcional | sim | `:250`; `exige_nota` lê `note_required.on_disable` da base |
| FR-025 onde a nota é omitida, o registro escreve a **frase de ausência**, nunca célula vazia | funcional | **sem evidência executada** | `frase_sem_nota/0` (*"no note"*) usada em `index.ex` (2 ocorrências); nenhuma asserção de teste encontrada |
| FR-026 ator e razão ao reativar; a desativação **não é apagada** | funcional | sim | `:305`, `:367` |
| FR-026 um episódio aberto por conta, por índice único parcial | funcional | sim | migração `account_disablements_aberto_index where enabled_at IS NULL`; `unique_constraint` em `abrir_changeset:82`; `:367` |
| FR-026 `disabled_at` e episódio na **mesma transação** | não funcional | **não medido** | `Repo.transaction` + `Repo.rollback` em `desativar_na_transacao` e `reativar_na_transacao` (leitura); **nenhum teste injeta falha do segundo passo** — exatamente o teste que o H3 tem e este não |
| FR-026 `disabled_by_mistake` marca o episódio, deixa de contar, continua visível | funcional | sim | `:324` *"o equívoco é dito, e para de contar como desligamento"*; `resumir/1` exclui equívocos de `desligamentos` |
| FR-026 `investigation_closed_no_compromise` **só** contra `suspected_compromise`, recusado pelo domínio | funcional | sim | `:340`; `account_disablement.ex:155` `abertura_exigida_pela_reativacao/1` |
| FR-027 dois vocabulários, duas colunas (`Account` · `Sign-in credential`) | funcional | sim | `:197` |
| FR-027 as duas temporárias distinguidas **em palavras** | funcional | sim | `:208` asserta `temporary · from a reset`; `:221` refuta `from creation` na linha; `password_source`/`password_set_by_user_id` na migração |
| FR-027 proveniência não registrada dita como `temporary_source_not_recorded` | funcional | **sem evidência executada** | `not recorded` em `index.ex` (2 ocorrências); nenhuma asserção de teste encontrada |
| FR-028 ação recusada **fica na tela**, inerte, com a razão | funcional | sim | `:268` (reset na desativada), `:288` (desativar a si) |
| FR-028 conta desativada **não filtrada por omissão** | funcional | sim | `:197` renderiza `/accounts` sem filtro e a linha desativada aparece; cabeçalho *"disabled last, and never hidden"* em `index.ex` |
| FR-029 o procedimento (três atos, faz / não faz) **na tela** | funcional | sim | `:448`; `what it does not do` ×3 em `index.ex` |
| FR-029 o *revoke* diz que **não remove acesso** | funcional | sim | `:867`, `:1492`, `:448` |

**Fase derivada**: **`sro.not_accepted_deliverable`** — por **avaliação incompleta**, não por
comportamento errado: **os cinco pontos que o D06 recusou estão fechados com evidência executada**
(quatro NÃO → sim; um sem evidência → sim com ressalva), o protótipo existe e as quatro decisões
estão registradas. O que impede a aceitação hoje são **três cláusulas dos FRs sem teste**
(vocabulário ausente recusa; frase de ausência de nota; `temporary_source_not_recorded`), **a
invariante da transação não medida** (sem teste de falha injetada), **a conferência do QA item a
item não encontrada**, e o `rule01` em aberto até o backlog retroativo. A lacuna de revisão pesa
conforme a leitura que o papel escolher (ver cabeçalho).
**Fase da tarefa**: `sro.non_successfully_performed_scrum_development_task` — e **não há tarefa
pretendida** à qual ligá-la (sem issue, sem `tasks.md`): a fase é do trabalho, e o trabalho não
tem registro de intenção.
**O que fecha**: quatro testes (base ausente → `{:error, :vocabulario_nao_declarado}`; *"no
note"* na linha; *"not recorded"* na credencial antiga; falha injetada em `Repo.insert` do
episódio → `users.disabled_at` continua nulo), a conferência §3 item a item com captura, e a linha
de herança no `sprint-backlog.md` do 030. Nenhum deles é desenho: é prova.
**Destino**: entra no sprint 030 como herança, **nova tarefa pretendida** (nunca reabrir o #853),
ligada a uma user story que a 045 ainda precisa declarar — "quem administra desativa e reativa
contas, e o registro diz quem, quando e por quê" não tem `US` na spec.

---

### H3 — Declarar equipe dentro de outra é UM ato, numa transação

**Produzido por**: PR [#857](https://github.com/The-Band-Solution/theband/pull/857), mergeado
2026-09-11T14:52Z em `development` · **sem issue** (`closingIssuesReferences: []`)
**Materializa**: 055/US3 — Equipe dentro de equipe (P2), FR-008; e a invariante achada em
2026-09-10 (a equipe ficava **criada e solta** quando `compose_teams/4` falhava depois de
`declare_structural_team/4`).
**Evidência executada**: `mix test test/the_band/ontology/seon/eo/team_composition_test.exs
test/the_band_web/live/subequipe_test.exs` (rodados junto dos de H2) → **72 passed, EXIT=0**
(2026-09-14). Um aviso de compilação em `subequipe_test.exs:81` (forma de `live/2` apontada pela
documentação do `Phoenix.LiveViewTest`) — aviso, não falha.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| os dois passos (criar a equipe, compô-la na mãe) acontecem **numa transação** | não funcional | sim | `commands.ex:374` `declare_subteam/4`: `Repo.transaction(fn -> with {:ok, filha} <- declare_structural_team(...), {:ok, _} <- compose_teams(...) do filha else {:error, motivo} -> Repo.rollback(motivo) end end)`; `teams_live/show.ex:201-222` o handler `criar_subequipe` chama **só** `EO.declare_subteam/4` — a invariante mora no domínio, não no chamador |
| teste que **injeta a falha do segundo passo** e prova que o primeiro não fica | não funcional | sim | `team_composition_test.exs:106` *"se a composição falha, a equipe NÃO fica criada e solta"*: mãe com `id` inexistente (o `organization_id` é válido, logo o primeiro passo passa e o segundo bate na FK `whole_team_id`); compara `length(EO.list_teams)` antes/depois e refuta o nome `"Squad Órfã"`. **Rodado: passa** |
| a falha é **recusa**, não queda | funcional | sim | `:91` *"a falha é RECUSA, e não queda"* — `{:error, motivo}` com `is_binary(motivo)`; antes das `foreign_key_constraint/2` levantava `Ecto.ConstraintError` |
| os oito caminhos infelizes recusam e **nenhum levanta** | funcional | sim | `:146-:210` — tabela iterada + `:210` *"NENHUM dos oito caminhos levanta"*; `:185` autor inexistente, `:192` organização inexistente, `:199` mãe sem organização |
| o limite de tamanho chega **interpolado**, não como `%{count}` | funcional | sim | `:172` |
| a subequipe **herda a organização** da mãe; a tela nomeia a equipe criada | funcional | sim | `:72`; `subequipe_test.exs:48`, `:155` |
| pela tela, a recusa **não cria nada** e o caminho feliz segue na mesma vista | funcional | sim | `subequipe_test.exs:104` (tabela de recusas), `:119` *"a recusa NÃO cria nada"*, `:132` |
| o nome é aparado, e a duplicata sob a mesma normalização é recusada | funcional | sim | `subequipe_test.exs:60`; `team_composition_test.exs:251` *"a mesma composição duas vezes é recusada"* |
| sem escopo, não declara | funcional | sim | `subequipe_test.exs:193` |

**Fase derivada**: **`sro.accepted_deliverable`** — todos os critérios conformes, com evidência
executada nesta sessão. As duas perguntas do pedido têm resposta direta: **sim**, há
`Repo.transaction` cobrindo os dois passos (e `Repo.rollback` no `else`); **sim**, há teste que
injeta a falha do segundo passo e prova que o primeiro não fica, e ele passa.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task` — sem tarefa pretendida
registrada (sem issue); a fase é do trabalho.
**Condicionantes fora dos critérios** (ver cabeçalho): revisão nunca pedida e não registrada;
`rule01` fecha com a linha de herança no `sprint-backlog.md` do 030.

---

### H2 — FR-003 da 055 ganha tela: vincular pessoa a equipe, com o veredito antes do botão

**Produzido por**: PR [#863](https://github.com/The-Band-Solution/theband/pull/863), mergeado
2026-09-12T19:25Z em `development` · **sem issue** (`closingIssuesReferences: []`). A user story
055/US2 ([#703](https://github.com/The-Band-Solution/theband/issues/703)) foi **fechada em
2026-09-02**, dez dias antes de a FR-003 ter tela.
**Materializa**: 055/US2 — *A pessoa entra, sai, e o que ela fez continua lá* (P1), pela FR-003
(cláusula MUST + emenda de 2026-09-06: *"vincular do zero continua existindo para quem a origem
não mostra"*), cenários AC1 e AC5. AC2–AC4 (saída, equívoco, novo período) pertencem a FR-004/006
e não são objeto deste entregável.
**Protótipo**: `specs/055-equipes-declaradas/prototipo/` — `PROMPT.md` (§3 é *"a régua do QA"*),
`README.md`, `team-declared-link.html`; artifact
`https://claude.ai/code/artifact/9645056b-9f3d-4a8a-88bf-81c09fac15d8`. Os três arquivos entraram
**no próprio #863**, junto do código; o PR [#915](https://github.com/The-Band-Solution/theband/pull/915)
(aberto 2026-09-13, branch `design/055-vinculo-declarado-prototipo`) traz **os mesmos três
arquivos com conteúdo idêntico** ao da `development` (`git diff --stat origin/development
origin/design/055-vinculo-declarado-prototipo -- specs/055-equipes-declaradas/prototipo/` vazio) —
é republicação de algo já mergeado, não protótipo novo.
**O que o registro diz sobre a aprovação**: o `README.md` — nas duas cópias — declara
**`Aprovação: aguardando a pessoa mantenedora — três perguntas abertas, duas delas mudam o que a
tela desenha`** (P1 origem registrada × derivada; P3 coleta sobre vínculo declarado). Nenhuma das
três tem *Decided*. O `vinculo_possivel.ex` afirma no `@moduledoc` *"protótipo aprovado em
2026-09-11"*. **As duas afirmações não podem ser ambas verdadeiras**; registro como está.
**Registro do protótipo no backlog**: `grep -rl team-declared-link docs/` **vazio** — nenhum item
de `docs/backlog/` cita o artifact nem o `PROMPT.md`.
**Divergência com o pedido desta avaliação**: o pedido diz *"papel e data opcionais"*; a FR-003
diz *"com papel e data de início"* e a decisão 3 do protótipo fixa **papel obrigatório, data
opcional**. Avalio contra spec e protótipo.
**Evidência executada**: `mix test test/the_band/ontology/seon/eo/vinculo_possivel_test.exs
test/the_band_web/live/vincular_pessoa_test.exs test/the_band/ontology/seon/eo/team_membership_test.exs`
(junto dos de H3) → **72 passed, EXIT=0** (2026-09-14).

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| FR-003 — quem administra vincula pessoa a equipe, **com papel** | funcional | sim | `vincular_pessoa_test.exs:234` *"declarar cria o vínculo, com papel e sem data"*; `:205` papel obrigatório; `:265` sem papel recusa |
| FR-003 — **com data de início** (opcional; vazia fica **nula**, nunca hoje) | funcional | sim | `:218`, `:253` guarda `~D[2026-01-15]`; `team_membership_test.exs:43` *"data em branco fica NULA"*; `commands.ex` mudança 2 do README aplicada |
| FR-003 — o vínculo **guarda quem o declarou** | funcional | **não medido** | `declare_team_membership/5` grava `declared_by_user_id: actor_id` (`commands.ex:69+28`, leitura); `team_membership.ex:147` valida o par autor/instante. **Nenhum teste asserta `declared_by_user_id == ator`** — `:234` asserta só `papel_declarado?` (papel não nulo) |
| FR-003 emenda — vincular **do zero** existe para quem a origem não mostra | funcional | sim | veredito 6: `vinculo_possivel_test.exs:135`, `vincular_pessoa_test.exs:183` *"é o caso da FR-003"* |
| AC1 — o vínculo passa a valer a partir da data, com quem o declarou | funcional | parcial | data: sim (`:253`); autor: **não medido** (linha acima) |
| AC5 — já vinculada e vigente → **recusado com a razão** | funcional | sim | veredito 2: `vinculo_possivel_test.exs:75`, `vincular_pessoa_test.exs:129` *"RECUSA inerte, e oferece declarar o papel"* (FR-007 emendada / FR-014) |
| os **seis vereditos** no domínio, na ordem certa, em duas consultas | funcional | sim | `vinculo_possivel_test.exs:70-:135` (1–6), `:142` ordem (membro **e** sumiu → recusa), `:152` oito resultados = duas consultas, `:164` lista vazia não vai ao banco |
| os seis vereditos **na tela, antes do botão** (§3.5) | funcional | **parcial** | tela testa 1 (`:119`), 2 (`:129`), 3 (`:157`), 6 (`:183`). **Vereditos 4 (saiu) e 5 (equívoco) sem teste de renderização** — textos `a new link` e `the mistake stays` existem em `show.ex` (1 ocorrência cada), mas não há asserção que os exercite |
| §3.1 — seção **`Link a person to this team`** entre *Roles* e *Members*, em repouso fechada | tela | sim | `:71`, `:84`; `show.ex` 1 ocorrência do título |
| §3.1 item 2 — rótulo `N of M collected people are linkable here`, N e M da consulta | tela | **não** | `linkable here`: **0 ocorrências** em `show.ex`. As medidas que o README exige *antes do código* (`structure.people_linkable_to_team.count`, `structure.memberships_declared_from_zero.count`, `structure.people_without_any_team.count`) **não existem** em `priv/knowledge_base/` (grep vazio) — princípio IV |
| §3.2 — escopo escrito, **não cria pessoa**, busca vazia não é erro | tela | sim | `:93`, `:107`; `No collected person matches` em `show.ex` |
| §3.3 — formulário: pessoa escolhida, `choose a role…`, `member since` vazio (`empty = start unknown`), `Declare the link`, *what this creates* / *What it does not do* | tela | sim | `:205`, `:218`, `:225`; textos presentes em `show.ex` (`step 2`, `choose a role`, `empty = start unknown`, `Declare the link`, `what this creates`, `What it does not do`) |
| §3.4 — lista de membros com a **coluna `link` corrigida** (`no source shows this link`, `declared in the same act`, ordem `person · role · link · since · squads`) | tela | **não** | `no source shows this link`: 0; `declared in the same act`: 0 em `show.ex`. O `describe "a seção (§3.4)"` do teste refere a seção nova, não a lista de membros. **Itens 19–21 da régua não implementados** |
| §3.7 — recusa **data de início no futuro** | funcional | **não** | `declare_team_membership/5` (`commands.ex:69-115`) **não tem** `nao_esta_no_futuro/1`; a checagem existe só para a saída (`:161`) |
| §3.7 — pessoa de outra organização → `not found`, nunca "no permission" | funcional | sem evidência | `not found` tem 3 ocorrências em `show.ex`, nenhuma asserida nos testes de H2 |
| recusa do domínio **no idioma da tela** (o produto fala inglês) | funcional | **não** | `commands.ex` devolve `{:error, "esta pessoa já tem vínculo vigente nesta equipe, com início desconhecido"}`; o handler `declarar_vinculo` (`show.ex:596`) faz `{:error, motivo} when is_binary(motivo) -> put_flash(socket, :error, motivo)` — **imprime a string do domínio crua**. O próprio teste `:265` asserta a palavra **`"papel"`** no HTML. É a mudança 4 que o README listou como exigida, e não aconteceu |
| a tela **não levanta** em vínculo vigente com `started_at` nulo (87 de 90 no banco) | funcional | sim | `vinculo_possivel_test.exs:75`; `commands.ex:40` cláusula `%TeamMembership{started_at: nil}` separada |

**Fase derivada**: **`sro.not_accepted_deliverable`** — quatro critérios **não conformes por
comportamento ou ausência** (§3.1 item 2 e medidas não declaradas; §3.4 coluna `link`; §3.7 data
futura; recusa em português impressa crua), dois **sem evidência** (autor do vínculo não asserido;
`not found` para outra organização), dois **parciais** (vereditos 4 e 5 sem teste de tela; AC1 pelo
autor). E, antes de qualquer critério: **o protótipo que é a régua declara a própria aprovação
como pendente**, com duas perguntas abertas que mudam o desenho — a tela foi implementada sobre
uma régua que o registro diz não estar fechada, e nenhum item de backlog registra artifact e
prompt.
**Fase da tarefa**: `sro.non_successfully_performed_scrum_development_task` — sem tarefa
pretendida registrada.
**O que fecha, e a ordem**: (1) a pessoa mantenedora responde P1, P2 e P3, o Design marca
*Decided* e republica **no mesmo endereço** — se P1 for A, `eo.team_membership` ganha `origin` e
as três medidas ganham YAML antes de a régua §3.1/§3.4 poder ser cumprida; (2) o item de backlog
cita artifact, `PROMPT.md` e `README.md`; (3) §3.4 e §3.7 implementados; (4) as recusas do domínio
passam pelo catálogo (`dgettext`) antes do flash; (5) testes: `declared_by_user_id`, vereditos 4 e
5 na tela, `not found` de outra organização, data futura recusada. **Só então** a conferência do
QA item a item.
**Destino**: entra no sprint 030 como herança, **nova tarefa pretendida** ligada a 055/US2 — e a
issue #703, fechada em 2026-09-02 com a FR-003 sem tela, **não é reaberta**; o registro de que a
US foi fechada antes de ser inteira fica.

---

### Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 3 |
| Aceitos | **1** — H3 |
| Não aceitos | **2** — H1 (avaliação incompleta: 4 cláusulas sem teste, QA item a item ausente), H2 (4 não conformes, régua não aprovada) |
| Tarefas executadas com sucesso | 1 (sem tarefa pretendida registrada) |
| Tarefas executadas sem sucesso | 2 (idem) |

| Entregável | PR | Fase proposta | Causa dominante |
|---|---|---|---|
| H1 — D06 reavaliado (conta desativada) | #853 | `sro.not_accepted_deliverable` | **os 5 pontos da recusa original estão fechados com evidência**; restam 3 cláusulas dos FR-025/027 sem teste, a transação sem teste de falha injetada, e a conferência do QA não encontrada |
| H2 — FR-003 com tela (vincular pessoa) | #863 | `sro.not_accepted_deliverable` | régua (§3.4, §3.7, §3.1 item 2) não cumprida; recusa do domínio em português na tela; protótipo com aprovação **pendente** no próprio README; medidas não declaradas |
| H3 — subequipe numa transação | #857 | `sro.accepted_deliverable` | `Repo.transaction` + teste de falha injetada que passa; 8 caminhos infelizes sem exceção |

**O que os três têm em comum, e não é dos critérios**: revisão nunca pedida e não registrada;
nenhuma issue fechada; nenhum item em sprint backlog (`rule01`) — o registro retroativo do 030
existe para fechar o terceiro; os dois primeiros são resíduo que não se recupera em PR mergeado,
e a decisão de exceção continua sendo do papel.

### Critérios alterados durante o sprint

| Critério | User story | Alterado em | O que mudou | Por quê |
|---|---|---|---|---|
| FR-025 a FR-029 (045) | nenhuma US da 045 os carrega | 2026-09-10, no #853 | **acrescentados** à spec, formalizando os critérios de `docs/backlog/conta-desativada.md` (2026-09-09) e as decisões do protótipo | a recusa do D06 pediu exatamente isto; a origem é anterior ao código, o texto normativo não |
| FR-003 (055) | US2 | 2026-09-06 (emenda) | vincular do zero fica para quem a origem não mostra; o observado nasce sem papel | anterior ao #863; avaliado na versão emendada |

### Critérios sem evidência

| Critério | Entregável | O que falta |
|---|---|---|
| sem vocabulário declarado, desativar recusa | H1 | teste com a base ausente → `{:error, :vocabulario_nao_declarado}` |
| nota omitida escreve a frase de ausência | H1 | asserção de *"no note"* na linha |
| `temporary_source_not_recorded` dita como tal | H1 | asserção na credencial anterior à coluna |
| `disabled_at` e episódio na mesma transação | H1 | teste que injeta falha em `Repo.insert` do episódio e prova `disabled_at` nulo |
| roster, **medidas** e histórico não mudam | H1 | medida computada da pessoa comparada antes/depois (roster, elo, escopos e senha já são) |
| conferência do QA item a item da §3 com captura | H1, H2 | o registro do QA |
| o vínculo guarda quem o declarou | H2 | asserção `declared_by_user_id == ator.id` |
| vereditos 4 e 5 na tela | H2 | teste de renderização |
| outra organização → `not found` | H2 | teste |
| não autentica por token | H1 | o token (spec 061) — **não avaliável**, e não conta como conforme |

### Não medido, e por quê

- `mix gates` e a suíte inteira: não rodados aqui por instrução; a run do CI 34779226200 sobre
  `0ccf02b` está `success` e é a evidência dos gates.
- Captura da tela real (`/accounts`, `/teams/:id?tab=structure`): não feita — a avaliação usou
  renderização em teste e presença de textos; a captura ao lado da régua é o que o QA entrega.

---

# Parte C — o que atravessa as duas partes

## O #860, que não foi avaliado

O PR [#860](https://github.com/The-Band-Solution/theband/pull/860) (2026-09-12) entregou a aba
*Flow per person* — US10–US12 da extensão `spec-graficos-por-membro.md` (FR-085 a FR-112). O
`tasks.md` da 060 as declarava **sem tarefa**, "dependentes da US9 e de protótipo que ainda não
existe"; o protótipo foi aprovado em 2026-09-08 e a tela entrou fora do plano. Os requisitos estão
sendo transcritos do protótipo **agora**, no PR #913. **Não classificável por critérios neste
registro**: as US existem na extensão, mas não estavam em backlog nenhum — pelo axioma
`sro.rule01`, é escopo que entrou sem passar pelo planejamento. Registrado, não aceito nem
recusado; a avaliação é própria, depois do #913.

## O que acontece com as issues, depois da confirmação

**Não há issues.** A 060 não tem épico, user story nem tarefa no GitHub; #853, #857 e #863 não
fecharam issue nenhuma. **Proposto**, e nada executado até a confirmação: criação retroativa
das issues da 060 (6 US + 29 tarefas) e das três de herança, como a 052 no sprint 026 — cada uma
dizendo que nasceu depois do trabalho, fechada no mesmo ato quando a fase for `accepted`, aberta
com destino quando não for. A criação retroativa **não conserta** o que a lacuna custou:
`flow.wip.count` subcontou o sprint enquanto ele corria.

## Destino das user stories e dos entregáveis

| Entregável | Fase proposta | Destino |
|---|---|---|
| 060/US1 (D1) | não aceita — teste ausente | **próximo sprint, primeira**: `abas_da_equipe_test`, `estrutura_membros_test`, `estrutura_permissao_test`; FR-004 "composta de K" |
| 060/US2 (D4) | não aceita — AC2 não medido | **decisão do papel** na confirmação |
| 060/US3 (D2) | não aceita — SC-013 não medido | **cronometrar** na confirmação |
| 060/US4 (D3) | **aceita** | concluída; localizar a asserção de AC5 ou registrar a lacuna |
| 060/US5 (D5) | não aceita — SC-005/FR-081 não medidos | **medir** com duas equipes + seção *Roles* |
| 060/US9 (D6) | não aceita — defeito | **nova tarefa via Design**: o cartão *Squads at a glance* conforme o protótipo; SC-009; FR-064 |
| 045 · D06 refeito (H1) | não aceito — 4 cláusulas sem teste | **nova tarefa**: os quatro testes, a conferência §3 com captura, e a US que a 045 precisa declarar |
| 055 · FR-003 com tela (H2) | não aceito — régua pendente, §3 furada | **ordem obrigatória** (ver H2): decisões P1–P3 → republicação → medidas → §3.4/§3.7 → recusas pelo catálogo → testes → QA |
| 055 · subequipe numa transação (H3) | **aceito** | concluído |
| #860 · aba *Flow per person* | não avaliado | registro próprio depois do #913 |

## A revisão, e a decisão que este registro não toma

Dez PRs compõem o sprint (#816–#821, #853, #857, #860, #863). **Nenhum tem revisão
registrada**; #853, #857, #860 e #863 **nem pediram**. A skill diz que revisão nunca pedida
impede aceitação; a v0.7.0 e a v0.8.0 trataram a mesma lacuna como exceção de release decidida
pelo papel. As duas leituras estão escritas; **a escolha é da pessoa alocada ao papel**, e vale
para as duas partes deste registro.
