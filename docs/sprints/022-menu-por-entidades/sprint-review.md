# Sprint 022 — Review

**Período**: 2026-08-28 (aberto e fechado no mesmo dia)
**Feature**: [046-menu-por-entidades](../../specs/046-menu-por-entidades/spec.md)
**PR**: [#543](https://github.com/The-Band-Solution/theband/pull/543), merge `380d90f`

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 11 | 11 |
| Entregáveis aceitos | 3 | 3 |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#532](https://github.com/The-Band-Solution/theband/issues/532) | Branch e baseline dos gates (com a ressalva do baseline contaminado — ver lições) | sim |
| T002 | [#533](https://github.com/The-Band-Solution/theband/issues/533) | `nav_area/1` puro, 18 caminhos testados por tabela | sim |
| T003 | [#534](https://github.com/The-Band-Solution/theband/issues/534) | Barra com as 4 entidades, `aria-current="true"` na seção ativa | sim |
| T004 | [#535](https://github.com/The-Band-Solution/theband/issues/535) | Settings em três seções; Operação só admin (FR-003) | sim |
| T005 | [#536](https://github.com/The-Band-Solution/theband/issues/536) | Nove rotas movidas inalteradas; gating de /tools intocado | sim |
| T006 | [#537](https://github.com/The-Band-Solution/theband/issues/537) | `work_tabs/1` com os seis destinos exatos | sim |
| T007 | [#538](https://github.com/The-Band-Solution/theband/issues/538) | Sub-abas nas seis telas de trabalho (SC-004: 1 clique) | sim |
| T008 | [#539](https://github.com/The-Band-Solution/theband/issues/539) | `EO.organization_overview/1` conforme contrato corrigido | sim |
| T009 | [#540](https://github.com/The-Band-Solution/theband/issues/540) | `/organizations` com ausências nomeadas e grupo de órfãos | sim |
| T010 | [#541](https://github.com/The-Band-Solution/theband/issues/541) | Tela × SQL: orgs 3/3, equipes 2/9/0, projetos 2/15/9, 0 órfãos | sim |
| T011 | [#542](https://github.com/The-Band-Solution/theband/issues/542) | 13 gates verdes + capturas 1280px sem rolagem lateral | sim |

**Aceitação**: avaliada critério a critério pelo agente product-owner em 2026-08-28,
com reexecução dos 5 arquivos de teste da feature (28 passed, EXIT=0), SQL direto no
banco dev e inspeção do markup mergeado. Veredito: **3/3 user stories aceitas** —
registrado nas issues [#529](https://github.com/The-Band-Solution/theband/issues/529),
[#530](https://github.com/The-Band-Solution/theband/issues/530) e
[#531](https://github.com/The-Band-Solution/theband/issues/531). Confirmada pela pessoa
mantenedora ao autorizar o merge nesta sessão.

## O que não foi feito

Nada — as 11 tarefas do backlog foram executadas e aceitas.

## Entregáveis não aceitos

Nenhum.

## Evidências

- 13 gates verdes (`mix gates`, saída em log com veredito pelo código de saída).
- Verificação contra a origem (T010) reproduzida pelo product-owner na aceitação.
- Capturas 1280px: /organizations, /people, /work — sem rolagem lateral (SC-005).
- Revisão independente por outro agente, sem achados — comentário no PR #543.
- Duas correções de contrato no commit da implementação, com razão (constituição VI):
  projetos fora da EO (fronteira de módulo) e vínculo projeto→organização pela cadeia
  `connected_tool_id → organization_login` — o casamento por `source_instance` seria
  100% órfão, desmentido pelo código da coleta antes de tocar o banco.

## Dívida gerada

- **Testes a endurecer** (apontado na aceitação): o teste do Settings não fixa os
  títulos "Trabalho" e "Vocabulário" (só "Operação"); o cenário de viewport estreito
  (FR-008) não tem teste automatizado — evidência por markup e captura.
- **Lacuna de prova na revisão**: a revisão independente está atestada em comentário,
  mas não há aprovação formal em `pulls/543/reviews` — o merge foi autorizado pela
  pessoa mantenedora em sessão, com o pedido à equipe `the-band` ainda aberto.
- **Duplicidade visual em /work**: a página conserva links internos antigos
  ("Change requests · Continuous verification · Files") redundantes com as sub-abas
  novas — limpeza pertence a uma tarefa própria, não entrou nesta feature.
- Tipos de issue `Epic`/`User Story` seguem inexistentes na organização (limitação
  herdada; criá-los exige aval da pessoa mantenedora).

## Lições deste sprint

Ver o [registro acumulado](../licoes-aprendidas.md) — L60 ganhou nova ocorrência
(EXIT ecoado fora do log) e L71 nasceu (testes que documentam o requisito antigo
caem em lote quando o requisito muda de lugar).
