# Implementation Plan: A tela da equipe — PR 1, os membros (US1–US5 e as duas abas)

**Branch**: `feat/060-tela-da-equipe` (empilhada sobre `feat/vinculo-observado`) | **Date**: 2026-09-07 | **Spec**: [spec.md](spec.md)

**Input**: `spec.md` (83 FR, 21 SC, zero perguntas abertas — versão de 2026-09-07),
`prototipo/README.md` (decisões 1–9 e as dez respostas), `prototipo/PROMPT.md` §3,
`prototipo/team-dashboard-structure.html` (screen 2 · structure).

**Escopo desta PR**: user stories **US1 a US5** e as **duas abas** de `/teams/:id`. O Dashboard é
a tela de hoje com as seções de estrutura retiradas; a Estrutura é nova. US6–US9 (subequipes com
data, cartões, problemas agora, fluxo) ficam para a PR 2.

## Summary

`/teams/:id` vira duas telas na mesma rota, com a aba na URL (`?tab=dashboard|structure`). A
lista de membros deixa de ser a **evidência** da origem e passa a ser o **vínculo**
(`eo.team_membership`), uma linha por pessoa, agregando os vínculos com esta equipe e com as
subequipes vigentes. Na linha, quem gere a estrutura declara/altera o papel, registra a saída com
data e autor, marca o equívoco com razão — e cria papéis da organização sem sair da aba.

Quem gere é **administrador OU papel organizacional com a concessão *gerir estrutura da equipe***
(FR-006, FR-080–082). A concessão nasce como irmã da de visibilidade — mesma forma, mesma tela de
declaração (`/roles`) — e o veredito `pode_gerir_estrutura/3` **substitui**
`pode_declarar_estrutura/4`, cujo caminho por escopo `organization` de conta deixa de autorizar
escrita na estrutura.

Três coisas o código de hoje não faz e esta PR corrige: a saída não guarda autor
(`record_team_departure/5` ignora `_actor_id` — `commands.ex:110`); `promover` grava sem permissão
(`show.ex:163-181`); a guarda da coleta reconhece o equívoco mas **não** a saída declarada num
vínculo observado (`commands.ex:683-691`) — depois de uma saída com data, a coleta seguinte
recriaria o vínculo.

**A abordagem em uma frase**: um LiveView, dois carregamentos — `handle_params` lê a aba e carrega
só o que ela mostra —, comandos novos pequenos sobre o relator que já existe, e uma concessão nova
no molde da que já existe.

## Technical Context

**Language/Version**: Elixir ~> 1.17 (`mix.exs:8`) · **Dependencies**: Phoenix ~> 1.8.9, LiveView
~> 1.2.0, Ecto SQL ~> 3.13 — **nenhuma nova**. **Storage**: PostgreSQL multitenant; **duas
migrações** (ver `data-model.md`). **Testing**: ExUnit, `Phoenix.LiveViewTest`,
`TheBand.ContadorDeConsultas` para o teto; dois tenants nos testes de isolamento. **Interface**
em inglês; código e documentos em português.

**Performance**: o Dashboard **baixa** de teto (as seções de estrutura saem dele); a Estrutura
ganha teto próprio, **medido** e declarado em `teto_de_consultas_da_equipe_test.exs`, com a
asserção de constância (1 pessoa × 11 pessoas, mesmo número).

**Constraints**: `mix gates` verde; toda consulta recebe `%Tenant{}`; nenhuma linha removida
(SC-012); nenhuma ação de escrita fora da aba Estrutura (FR-003); nenhum nível de acesso da
plataforma na lista de membros (FR-008, SC-004).

**Scope**: 1 LiveView reorganizado (2 092 linhas), 5 comandos novos ou alterados, 4 consultas
novas, 1 módulo novo em EO (`StructureGrants`), 1 veredito novo em `Access`, 2 migrações, 1 módulo
YAML novo + 1 regra emendada, ~11 arquivos de teste tocados.

## Constitution Check

| Princípio | Situação | Como |
|---|---|---|
| **I** Domínio pelas ontologias | ✅ | a lista é o relator `eo.team_membership`; a concessão é declaração adjacente à EO, no mesmo lugar de `spo.activity_start_criterion` |
| **II** Fonte externa não é domínio | ✅ | conector intocado; só a guarda de `observar_vinculo/2` muda, por regra emendada (v3) |
| **III** Proveniência e idempotência | ✅ | saída ganha autor e instante; equívoco já tem o trio; nada é apagado |
| **IV** Semântica em YAML | ⚠️ **tarefa antes da tela** | a concessão e a regra v3 são pré-requisito (T002, T003) |
| **V** Monólito modular multitenant | ✅ | `%Tenant{}` em toda função nova; a tela não toca `Repo` |
| **VI** Spec Kit antes do código | ✅ | contratos em `contracts/` antes da primeira função pública (T001) |
| **VII** Gates e revisão independente | ⚠️ | revisão pedida à equipe `the-band`; lacuna declarada se não houver revisor |
| **VIII** Desenho que o problema justifica | ✅ | seis decisões com as três respostas, abaixo |
| **IX** Ontologias autônomas | ✅ | o módulo novo referencia só `eo.*` |
| **X** Responsabilidade única, em módulo e em tela | ✅ | duas abas = duas perguntas; toda escrita numa aba só; a exceção (dois pontos de entrada para declarar papel) está decidida na spec, FR-014 |
| **XI** Estado conferido, sinal nunca silenciado | ✅ | vereditos como relator; recusas nomeadas |

### ⚠️ IV — o que precisa existir em YAML antes da tela

| Artefato | Estado hoje | O que a PR 1 faz | Gate |
|---|---|---|---|
| `ontology/seon/eo/modules/role_grants.yaml` | **não existe**; `eo_role_visibility_grants` está no código e **não** na base — lacuna herdada da #369 | módulo novo com dois conceitos irmãos: `eo.role_visibility_grant` (o que já existe) e `eo.role_structure_management_grant` (novo); listado em `eo/ontology.yaml` | `mix knowledge.validate`, `mix knowledge.graph` |
| `rules/github_team_membership_evidence.yaml` | v2: "vínculo declarado não é tocado" | **v3**: saída declarada e equívoco em vínculo observado bloqueiam a recriação **enquanto a observação for contínua**; observação nova depois de ausência constatada é retorno (FR-026, FR-027) | `mix knowledge.validate` |
| `eo.team_membership` em `organizational_structure.yaml` | atributos `started_at`, `ended_at` | **sem mudança de conceito** — os atributos novos são proveniência da declaração, não semântica do relator | — |

**Não é ressalva, é tarefa**: T002 e T003, antes de qualquer tela.

### X — como as abas respeitam "uma tela mostra uma coisa"

- **Dashboard** responde *how this team is doing*; **Structure** responde *who is in it, in which
  squad, in which role*. Cada aba tem um cabeçalho de uma frase.
- **Toda escrita mora na Estrutura** (FR-003): os cinco eventos de escrita de hoje passam a
  existir só quando a aba é `structure`, mais os novos.
- **Nenhuma seção nas duas** (FR-002): a discordância sai do Dashboard e vai para a Estrutura; os
  projetos ficam em **leitura** no Dashboard e em **escrita** na Estrutura.
- **A exceção decidida**: declarar papel tem dois pontos de entrada na mesma aba — a linha e o
  lote (FR-014). A tensão foi pesada pela pessoa mantenedora e decidida; o plano não a reabre.

## Decisões de desenho — as três respostas do princípio VIII

### D1 — Um LiveView, aba em `handle_params`, carregamento por aba

**Problema concreto**: a tela carrega 23 consultas para tudo. Se as duas abas carregassem tudo, a
Estrutura pagaria o burn, a previsão e a espera por revisão sem mostrá-los.
**Existe agora?** Sim — o teto é teste e reprova a primeira consulta a mais.
**O que piora**: `handle_params` ganha um `case`; `load/1` vira dois. Mitigado: as seções da
Estrutura nascem como **componentes funcionais**, como as da 057 já são.
**Alternativas recusadas**: (a) dois LiveViews e duas rotas — a spec fixa uma rota e `?tab=`
(FR-001); (b) dividir o módulo já — a PR 2 vai reescrever o Dashboard inteiro (US7–US9), e dividir
agora obrigaria a dividir de novo. **Dívida com prazo**: a PR 2 extrai o Dashboard.

### D2 — A aba na URL via `live_patch`, e a tabela do roster carrega a aba

**Problema**: recarregar ou compartilhar precisa cair na aba (FR-001, SC-007); paginar o roster
não pode devolver ao Dashboard. **Existe**: `TabelaLive.query/4` já aceita `extra`.
**Recusado**: aba em `assign` só, trocada por `phx-click` — perde o link (issue #292). Aba
inválida (`?tab=x`) é **dita** e cai no Dashboard.

### D3 — A lista é por VÍNCULO, agregada por pessoa, em consulta paginada

**Problema**: `list_team_members/3` lê a evidência e devolve nível de acesso — nada do que FR-010
pede e o que FR-008 proíbe. **O que piora**: agregação por pessoa com paginação não cabe numa
consulta só; são **quatro** constantes, nenhuma por linha.
**Recusado**: (a) agregar em Elixir sobre todos os vínculos sem paginar — quebra na equipe derivada
(31+); (b) `jsonb_agg` numa consulta só — ilegível em revisão e sem precedente na casa.

### D4 — Saída e equívoco são do PAR pessoa–equipe; alterar papel é do VÍNCULO

**Problema**: `vigente/3` usa `Repo.one`, e FR-018 permite dois papéis simultâneos — hoje
`record_team_departure/5` e `record_team_membership_mistake/5` **levantariam**
`Ecto.MultipleResultsError`. **Decisão**: saída e equívoco operam sobre **todos** os vínculos
vigentes do par (`update_all`); alterar papel opera sobre **um** (`membership_id`).
**O que piora**: não dá para registrar equívoco de um dos dois papéis — mas isso é papel errado,
e para isso existe alterar. Dito na tela.

### D5 — A concessão de gestão é tabela irmã, não coluna em `eo_role_visibility_grants`

**Problema**: aquela tabela confere **ver**; FR-080 pede **gerir**, e 045 FR-022 separa os dois de
propósito. **O que piora**: duas tabelas com a mesma forma. Mitigado: os dois conceitos nascem
**juntos** no mesmo módulo YAML, e `EO.StructureGrants` espelha `EO.Visibility` função a função.
**Recusado**: (a) coluna `kind` na tabela de visibilidade — misturaria o que não é visibilidade;
(b) reusar `access_scope_grants` (por **conta**) — a decisão é por **papel**.

### D6 — `pode_gerir_estrutura/3` substitui `pode_declarar_estrutura/4`

**Problema**: `access.ex:175-189` autoriza admin **ou** escopo de **conta**. FR-006 fecha a lista
em admin **ou** papel com concessão. **Existe**: só dois chamadores (`show.ex:98,129`).
**O que piora**: quem hoje age por escopo `organization` de conta **deixa de agir** até um
administrador conceder *gerir estrutura* ao papel dessa pessoa. **Não há migração de dados**:
escopo é da conta, concessão é do papel. A transição é declarada no PR e no `quickstart.md`; antes
do merge mede-se no banco quantas contas não-admin têm escopo `organization` vigente.
`pode_ver_equipe/3` **não muda** — FR-007 confirma os quatro caminhos.

### O que **não** foi introduzido, e por quê

| Não feito | Por quê |
|---|---|
| LiveComponent com estado por linha | uma linha aberta por vez; um `assign` basta |
| tabela de histórico de papel | alterar = encerrar + declarar; o histórico **é** a linha encerrada |
| segundo `role` de plataforma ("manager") | FR-080 proíbe; gestor é papel organizacional com concessão |
| migração de escopo → concessão | não há mapeamento conta→papel sem inventar papel (D6) |
| cache do veredito nos eventos | "esconder o botão não é autorização" (FR-006) |

## Ordem de implementação (fatias verticais)

| Fase | O que entra | Chega à tela? |
|---|---|---|
| **0** | contratos; YAML da concessão; regra v3 | não |
| **1** | tabela e módulo da concessão; `pode_gerir_estrutura/3`; `/roles` concede | `/roles` |
| **2** | **as abas + a lista por vínculo** (US1) | **sim — primeira fatia com tela** |
| **3** | saída com data e autor (US3) | sim |
| **4** | equívoco em observado e declarado (US4) | sim |
| **5** | declarar/alterar papel na linha + lote (US2) | sim |
| **6** | papéis da organização na Estrutura (US5) | sim |
| **7** | escrita de projeto na Estrutura; tenants; gates; docs | sim |

A fase 2 vem antes das ações porque as quatro operam sobre linhas que precisam existir. A fase 1
vem antes da 2 porque a primeira tela já precisa decidir quem vê botão.

## O teto de consultas

| Tela | Hoje | Sai | Entra | Declarar |
|---|---|---|---|---|
| Dashboard | 23 | 7 consultas de estrutura | `team_size/2` no cabeçalho | **medir** e baixar. Sem folga |
| Estrutura | — | — | cabeçalho (3); roster (4); discordância (1); papéis (1) + contagens (1) + concessões (2); `team_wholes` (1); projetos (2); veredito (0–2) | **novo `@teto_da_estrutura`**, medido, com constância |

`carregar_competencias/1` continua lendo a evidência para os ids dos antipadrões — é o Dashboard,
não muda nesta PR, e está anotado em `research.md` R12.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| `Repo.one` em `vigente/3` com dois papéis | exceção na saída/equívoco | D4: `update_all`; teste com dois papéis |
| quem age por escopo `organization` perde a escrita | administradora concede à mão | D6; medição antes do merge; recusa nomeia *sem concessão* |
| ~11 arquivos de teste mudam de aba | PR grande de revisar | as mudanças são listadas tarefa a tarefa |
| a guarda v3 bloquear o **retorno** legítimo | quem saiu e voltou não ganha vínculo | a guarda vale enquanto a observação for contínua; teste dos dois casos |
| "Remove" no protótipo × "ocultar" na spec | rótulo que mente | proposta **"Hide"**; ver Perguntas abertas |
| a PR 2 reescreve o Dashboard | a divisão do módulo seria refeita | D1: seções como funções separadas |

## Perguntas abertas

1. **Rótulo do botão de ocultar papel**: protótipo diz *Remove*; FR-033 diz *ocultar*. Proposta: *Hide*.
2. **Equívoco em pessoa com dois vínculos vigentes**: por par (proposta D4) ou por vínculo?
3. **Retorno depois de saída declarada em vínculo observado** (FR-026 × FR-027): proposta — a
   guarda bloqueia enquanto a evidência não tiver `no_longer_observed_at`.
4. **Categoria UFO da concessão**: proposta `normative_description`/`kind`. Quem mantém a base confirma.
5. **`declared_at` em `eo_team_memberships`**: proposta acrescentar. Confirmar que não é ampliação.
6. **Ordem da lista de membros**: proposta vigentes → saíram → equívocos, nome dentro de cada grupo.

## Complexity Tracking

Nenhuma violação. Os dois ⚠️ são **tarefa** (IV) e **lacuna a declarar** (VII). A dívida com prazo
(D1: extrair o Dashboard na PR 2) está registrada.
