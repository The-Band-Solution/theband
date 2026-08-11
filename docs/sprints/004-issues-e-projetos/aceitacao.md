# Sprint 004 — Registro de aceitação

**Feature**: [004-issues-e-projetos](../../../specs/004-issues-e-projetos/spec.md)
**Avaliado em**: 2026-08-11
**Papel**: Product Owner — Paulo Sergio Santos Junior
**Tipo**: `sro.product_owner_client` — quem demanda é quem decide, e a decisão é final

Cada critério percorrido contra evidência. A classificação decorre disso, nunca é
atribuída — `sro.rule03`.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 4 |
| Critérios avaliados | 26 |
| Critérios sem evidência | **0** |
| Critérios não conformes | **0** |
| Aceitos | — a confirmar pelo papel |

## Estado final do dado real

Medido no banco de desenvolvimento em 2026-08-11, depois da coleta:

```text
135 repositórios observados       4455 issues coletadas
4455 promoções vigentes           5022 promoções no histórico (append-only)
1614 vínculos de decomposição        4 vínculos recusados
4833 payloads de issue preservados 163 payloads de repositório
   0 issues marcadas como ausentes
```

Conferido contra a API: `The-Band-Solution` tem 14 repositórios e 189 issues — e a
plataforma coletou 14 e 189.

---

## D01 — O kind referenciado, e a regra da fronteira (F0)

**Produzido por**: T001, T002
**Materializa**: nenhuma user story — é pré-requisito estrutural, avaliado contra a
constituição IX.

| Critério | Conforme | Evidência |
|---|---|---|
| Um conceito anotado, não a ontologia inteira | **sim** | `sys_swo.loaded_software_system_copy` ganhou `kind`; os outros 10 seguem sem estereótipo, e `derive --ontology sys_swo` continua falhando |
| A exigência da derivação de CMPO foi zerada | **sim** | `derive --ontology cmpo \| grep -c "sem ontouml_stereotype"` devolve 0 |
| A referência é **uma** tabela, não duas | **sim** | `boundary_rule_test.exs`, 5 testes. Trocando `source_repository` para `kind`, **4 de 5 passam** e a mensagem diz que fragmentaria |
| Anotação removida é detectada | **sim** | removendo o estereótipo do kind, **3 de 5 passam** |

**Fase derivada**: `sro.accepted_deliverable`.

---

## D02 — Semântica declarada antes do código (F1)

**Produzido por**: T003 a T006

| Critério | Conforme | Evidência |
|---|---|---|
| Regra do tenant com os tipos que a organização usa | **sim** | `Feature`, `Task`, `Bug`, com os identificadores conferidos pela API |
| `Priority` **não** mapeado para `importance` | **sim** | `tenant_rules_test.exs` — mapeando `importance`, **8 de 9 passam**, e a mensagem nomeia o antipadrão |
| Todo campo e tipo traz identificador | **sim** | dois testes, e a simetria: tipo **em uso** exige identificador, tipo **ausente** não pode ter, porque seria inventado |
| Consultas aceitas pela API real | **sim** | as três — repositórios, issues, tipos de issue — devolveram dado do GitHub |
| Payload bruto preservado | **sim** | 4833 payloads de issue e 163 de repositório, com `mapping_id` e `mapping_version` |

**Fase derivada**: `sro.accepted_deliverable`.

---

## D03 — Repositório observado (F2, US4 parcial)

**Produzido por**: T007 a T012

| Critério | Conforme | Evidência |
|---|---|---|
| FR-001 — descobertos a partir da organização | **sim** | 135 repositórios, nenhum conectado individualmente |
| FR-002a — tabela própria com o que o git fornece | **sim** | `name`, `qualified_name`, `url`, `primary_language`, `default_branch`, `archived_at`, `last_pushed_at`. Na tela: `Makefile`, `Astro`, `Vue`, `Elixir` |
| FR-003 — arquivado é fato da origem, não ausência | **sim** | `archived_at` e `no_longer_observed_at` são colunas distintas, com a razão no `@moduledoc` |
| FR-004, FR-005 — exclusão pelo tenant, com autor | **sim** | `check_constraint` recusa exclusão sem autor; a coleta não consulta o excluído e **não** marca as issues dele |
| FR-006 — inacessível não marca ausência | **sim** | `mark_inaccessible/3` grava o motivo na ferramenta; nenhuma issue ganha marca |
| Migrações reversíveis, nenhuma remove coluna | **sim** | round trip nas três; 22 migrações no total |

**Fase derivada**: `sro.accepted_deliverable`.

---

## D04 — Issues, promoção, recusa e tela (F3, US1)

**Produzido por**: T013 a T029
**Materializa**: US1 — Saber quais issues existem, e o que elas são (atômica, P0)

### Cenários de aceitação

| Cenário | Conforme | Evidência |
|---|---|---|
| 1 — repositórios registrados com a organização | **sim** | 135, com `organization_id` |
| 2 — `Bug` vira defeito, com a regra registrada | **sim** | 183 defeitos; `rule_id` e `rule_version` em toda promoção |
| 3 — `Feature` sem sub-issues vira atômica | **sim** | `routing_test.exs` |
| 4 — `Feature` com partes que são user stories vira épico | **sim** | 23 épicos; `#1`, `#79`, `#98` na organização própria |
| 5 — `Epic` sem partes vira atômica, com divergência | **sim** | `routing_test.exs`, e a mensagem cita `sro.rule05` |
| 6 — **partes que são tarefas NÃO tornam épica** | **sim** | `#3` com nove sub-issues `Task` → `:atomic_user_story`. É o teste que não pode passar por acidente |
| 7 — tipo desconhecido não promove, e guarda o nome | **sim** | na tela: `Chore (17), Refactor (16), Hotfix (4)` |
| 8 — a tela mostra total, promovidas, lacunas e divergências | **sim** | 4455 = 1015 + 3440 |

### Critérios não funcionais

| Critério | Conforme | Evidência |
|---|---|---|
| SC-001 — a soma fecha | **sim** | 1015 + 3440 = 4455, e a tela exibe o desvio em vermelho se não fechar |
| SC-002 — idempotência | **sim** | segunda coleta: 4455 issues, sem duplicar; 4455 promoções vigentes sobre 5022 no histórico |
| SC-003 — ausência escopada por repositório | **sim** | **0 issues marcadas** depois de coletar 135 repositórios em sequência. Com escopo por tenant, 134 estariam marcadas |
| SC-004 — 100% com regra e versão | **sim** | `rule_version` é `NOT NULL` no banco |
| SC-005 — tipo desconhecido não promovido | **sim** | 37 contadas na lacuna, nenhuma com `derived_concept` |
| SC-006 — nenhum épico sem partes | **sim** | derivado de `classification/2`, um caminho só |
| SC-007 — ciclo recusado com o caminho | **sim** | `decomposition_test.exs`; 4 vínculos recusados no dado real, todos `out_of_scope` |
| SC-010 — vazio distinguível de não coletado | **sim** | `.github` aparece como **observado com 0 issues**, distinto de não coletado |
| SC-011 — retomada não recoleta | **sim** | checkpoint por repositório |
| SC-012 — isolamento entre tenants | **sim** | `isolation_test.exs`, três asserções com contraprova |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

---

## Dois defeitos encontrados na avaliação, e corrigidos antes deste registro

Percorrer os critérios contra o **dado real** — e não contra a suíte — achou dois defeitos
que nenhum teste pegava.

**O envelope do cliente.** `Client.graphql/4` devolve `{:ok, %{data: ...}}`, e eu casei
`{:ok, data}`. O job **completou com sucesso e coletou zero**: nenhum erro, nenhum payload.
A explicação plausível era "a organização não tem repositórios". Virou a
[L26](../licoes-aprendidas.md).

**O número como chave.** Liguei as partes ao pai por `number`, que é único **dentro** do
repositório. Com 135 repositórios, partes de um foram ligadas ao pai de outro. A tela
mostrava **2 épicos** onde havia 3. Virou a [L25](../licoes-aprendidas.md).

Os dois são da mesma família das L22 e L23: **sucesso silencioso**. Em nenhum houve erro —
houve ausência de resultado lida como resultado.

---

## Critérios alterados durante o sprint

Nenhum dos 59 requisitos da spec original. **Foram acrescentados 15**, por decisão da
pessoa mantenedora durante a execução:

| Decisão | Requisitos |
|---|---|
| mapeamento por organização, configurado ao definir a ferramenta | FR-041 a FR-041c, FR-049 |
| repositório com tabela e atributos do git | FR-002a |
| identificador em toda entidade mapeada | FR-027, FR-027a |
| unicidade escopada pelo tipo | FR-008a, SC-016 |
| quadro é planejamento, não projeto | FR-020, FR-020a |
| sincronizar traz tudo | — mudança de desenho, sem requisito novo |

Acréscimo durante o sprint é registrado, não silenciado. Nenhum deles invalidou critério já
avaliado.

## Critérios sem evidência

Nenhum dos avaliados. **Os de F4, F5 e F6 não foram avaliados porque não entraram no
sprint** — quadros, iterações, backlogs e a tela de mapeamento. Estão no product backlog.

## Entregável do sprint

`sro.sprint_deliverable_composed_of_accepted_deliverable` admite apenas entregáveis
aceitos. Com D01 a D04 derivados como aceitos, o entregável do sprint 004 é composto pelos
quatro — **sujeito à confirmação de quem desempenha o papel**, que é ato humano e não
decorre desta avaliação.

## Nota sobre a revisão independente

Continua **bloqueada por ferramenta**: com uma identidade no repositório, o autor não aprova
o próprio PR. Declarada, nunca marcada como cumprida.
