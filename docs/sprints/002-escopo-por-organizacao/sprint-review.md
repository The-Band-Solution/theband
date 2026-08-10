# Sprint Review 002 — Escopo por organização

**Período**: 2026-08-10 a 2026-08-16 (cadência semanal)
**Encerrado em**: 2026-08-10
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separa o que foi entregue do que não foi. Nada aqui é marcado como pronto sem
evidência — saída de comando, número conferido contra a origem, ou tela renderizada.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | **1** — US1 |
| Fases | 8 | 6 — F0, F1, F2, F3, F7, F8 |
| Tarefas do `tasks.md` | 27 | **20** |
| Testes | — | 81 → **129** |

**O MVP declarado no backlog era F1, F2, F3, US1 e F7. Os cinco saíram.** US2 e US3
não, e estão na seção do que não foi feito.

## Resultado por user story

| # | User story | Entregável | Estado |
|---|---|---|---|
| US1 | Saber de qual organização veio cada registro | D01 — organização em cada pessoa e equipe, nas consultas e nas telas | **aceito** em 2026-08-10, com duas ressalvas |
| US2 | Consultar uma organização de cada vez | — | **não feita**; o filtro por organização existe nas consultas, a tela de seleção não |
| US3 | Enxergar quem atravessa organizações | — | **não feita**; a consulta responde, a sinalização na tela não |

A coluna é **derivada** do [registro de aceitação](aceitacao.md), nunca preenchida
direto: review sem registro de aceitação é afirmação sem prova.

**Entregável do sprint**: composto de **D01**. As duas ressalvas acompanham a aceitação
e não a diluem — colisão de slug garantida pelo modelo e não observada em dado, e
esvaziamento da equipe derivada coberto por teste e não por ocorrência.

**Nenhuma tarefa foi executada sem sucesso.** As quatro cuja definição estava errada
tiveram a *definição* corrigida, não o entregável recusado, e a distinção é o que a
medida de retrabalho calcula.

## Evidência, verificação por verificação

Executado contra o banco de desenvolvimento com as três organizações reais.

### V1 — a derivação passa a produzir a coluna

Regressão sobre as 11 ontologias, com baseline refeito a partir do `HEAD` mais o
conserto de determinismo e nada mais:

```text
ontologias que mudaram com a regra nova:
  MUDOU: eo    ← só ela

diff de EO:
+ │    organization_id        uuid      NULL      → FK (association)
+ │    check: organization_id IS NOT NULL OR type <> 'organizational_team'
+ eo.organizational_team_belongs_to_organization: associação →
    eo_teams.organization_id anulável, obrigatória quando type='organizational_team'
```

### V2 — o esquema corresponde ao modelo derivado

```text
eo_teams.organization_id:              [["organization_id", "YES"]]   nullable
check:                                 eo_teams_organizational_team_has_organization
eo_people.organization_id existe?      0                              removida
```

E a restrição recusa o que deve recusar:

```text
insert type='organizational_team' sem organization_id  → ERROR 23514 check_violation
insert type='project_team'        sem organization_id  → INSERT 0 1
```

### V3 — retrofito sem consultar a origem

```text
equipes sem organização ANTES:  10
atribuídas:                     10
sem resolver:                    0
DEPOIS:                          0

leds-conectafapes: 8 · The-Band-Solution: 2
```

Zero chamadas ao GitHub, e a garantia não é por inspeção: os cinco testes rodam
**sem expectativa no Mox da borda HTTP**, então qualquer chamada os derruba.

### V4 e V5 — a equipe derivada, e nunca passando por observada

**Os três casos da regra ocorreram em dado real**, o que é diferente de estarem
cobertos por fixture:

```text
The-Band-Solution    6 membros, todos em times   → nenhuma derivada (FR-007)
ifesserra-lab        5 membros, 0 times          → derivada com 5
leds-conectafapes   64 membros, 15 fora          → derivada com 15
```

E a proveniência de cada derivada:

```text
LEDS - ConectaFapes   source_system=the_band  derived:default_team:O_kgDOCqjXpg
  níveis de acesso dos 15 vínculos: [nil]

ifesserra-lab         source_system=the_band  derived:default_team:O_kgDODw6Ftw
  níveis de acesso dos 5 vínculos:  [nil]
```

`[nil]` é o resultado, não uma omissão: a origem não conhece estes vínculos, então
não informa nível. Gravar `MEMBER` faria "observado como membro comum" e "a origem
não sabe deste vínculo" ficarem indistinguíveis.

### V6 — as contagens que não fecham, e estão certas

```text
leds-conectafapes  64
The-Band-Solution   6
ifesserra-lab       5
total de pessoas   72 · soma por organização  75
```

A soma é **maior** que o total, e está correto: três pessoas atravessam
organizações. A tela carrega a nota que explica isso, porque sem ela o primeiro a
somar conclui que há defeito.

### V7 — filtrar por organização

```text
ifesserra-lab: 5 pessoas, 1 equipe
```

O filtro existe nas consultas (`opts[:organization_id]`), e é o que US2 usaria. **A
tela de seleção não foi feita** — ver o que não foi entregue.

### V8 — quem atravessa organizações

```text
2 pessoas em mais de uma organização
  EduardoNFraiz: leds-conectafapes, The-Band-Solution
  Paulo:         leds-conectafapes, The-Band-Solution, ifesserra-lab
```

A consulta responde. **A sinalização na tela de pessoas existe** — o selo "em N
organizações" — mas a tela dedicada de US3 não foi feita.

### V9 — nenhuma pessoa fica sem organização

**É a prova de o caminho ter ficado completo, e o critério SC-003a do MVP.**

```text
ANTES da derivação:  18 pessoas sem organização alcançável
DEPOIS:               0
```

### V10 — isolamento entre organizações clientes

```text
tenant novo vê: 0 pessoas, 0 equipes, 0 organizações
```

## Quality gates

| Gate | Resultado |
|---|---|
| `mix format --check-formatted` | passou |
| `mix compile --warnings-as-errors` | passou |
| `mix credo --strict` | passou — `found no issues` |
| `mix dialyzer` | passou — `done (passed successfully)` |
| `mix test` | passou — **129 testes** (eram 81) |
| `mix knowledge.validate` | passou |
| `mix knowledge.graph` | passou — 24 módulos |
| `scripts/validate_knowledge_base.py` | passou — 86 artefatos |
| **derivação reproduzível** (gate novo) | passou — 4 ontologias, duas execuções idênticas |

## O que **não** foi entregue

Declarado explicitamente. Nenhum destes está marcado como pronto em lugar nenhum.

| Item | Tarefas | Por quê |
|---|---|---|
| **US2 — consultar uma organização de cada vez** | T013 a T017 | O filtro por organização existe nas consultas e é testado; falta a tela: seletor com contagem por organização, e a distinção entre estado vazio e filtro vazio. Fora do MVP declarado no backlog |
| **US3 — enxergar quem atravessa organizações** | T018, T019 | A consulta responde e a tela de pessoas já sinaliza "em N organizações"; falta a tela dedicada e `list_people_in_several_organizations/2` do contrato |
| **A restrição de equipe derivada no banco** | — | As duas invariantes de T022 são de aplicação, não `check_constraint`. Declarar em SQL o padrão `derived:` exigiria uma restrição sobre o formato do identificador, e isso engessaria o padrão no esquema. Dívida declarada, não esquecimento |
| **Ocorrência real de esvaziamento da derivada** | T023 | Coberto por dois testes. Exigiria uma pessoa entrar num time real do GitHub entre duas coletas — mesma classe de limitação de "ausência não é remoção" no sprint 001 |
| **Revisão independente** | — | Ver a seção seguinte |

## A revisão independente, agora possível

Era **impossível** neste repositório até 2026-08-10: um colaborador só, que é o autor
de todo PR, e nenhuma equipe com acesso. Foi tratada como pendência de agenda por um
sprint inteiro, e era pendência de permissão — lição
[L15](../licoes-aprendidas.md).

Destravada com duas chamadas de API: `pull` concedido à equipe `the-band`, e o pedido
de revisão feito **à equipe** em vez de a uma pessoa. Pedir à equipe é o que produz a
independência: o pedido fica aberto a qualquer membro, e o autor, sendo membro, não
pode atendê-lo.

**O resíduo não se recupera**: os PRs #89, #90 e #91 foram mergeados sem aprovação
registrada. O código da feature 001 está na `main` sem nunca ter passado por revisão
registrada, e o `aceitacao.md` do sprint 001 continua dizendo isso.

## Defeitos encontrados durante o sprint

Todos corrigidos. Os três primeiros só apareceram porque algo foi **executado**, não
implementado.

| Defeito | Onde apareceu | Correção |
|---|---|---|
| **A derivação não era função da ontologia** | a regressão obrigatória de T004 acusou 10 das 11 ontologias como alteradas, e nenhuma havia mudado | `sorted` em quatro pontos; gate de reprodutibilidade no CI; [L17](../licoes-aprendidas.md) |
| **A equipe derivada acolhia o tenant inteiro** | V9 no banco real: `ifesserra-lab`, com 5 membros, recebeu 72 pessoas | "de uma organização" passou a significar **membro observado**, lido do payload preservado |
| **A minha regra de associação gerava autorreferência** | `eo_people.person_id`, a partir de `eo.team_member_is_person` | papel materializa por relator (ADR 0004 D5/D6), nunca por coluna; dois guardas |
| **CI vermelho por secret não cadastrado** | o PR abriu o pipeline pela primeira vez | secret referenciado e ausente chega como string vazia; [L13](../licoes-aprendidas.md) |
| **`gh` engole o pedido de revisão recusado** | `--reviewer` saiu com código zero e não atribuiu ninguém | conferência obrigatória de `reviewRequests`; [L14](../licoes-aprendidas.md) |
| **`collect_team_members` percorria todas as equipes do tenant** | apareceu ao introduzir a equipe derivada, que não tem integrantes na origem | escopado à organização da coleta e às observadas |

## Tarefas cuja definição estava errada

Quatro, corrigidas no lugar em vez de contornadas. Cada correção está escrita na
própria tarefa, no `tasks.md`.

| Tarefa | O que dizia | O que era |
|---|---|---|
| T001 | conferir a relação na saída de `mix knowledge.graph` | a task imprime **uma linha** sobre dependências e nunca lista relações — inverificável |
| T003 | "a base atual continua passando" | não continuava: **12 vínculos sem lastro**, não um |
| T007 | criar coluna e `check_constraint` juntos | impossível num banco povoado; a restrição virou migração própria, **depois** do retrofito |
| T020 | o mapeamento de equipe referencia a regra | `derivation.rule_id` ali marcaria **toda equipe observada** como derivada |

## Dívida gerada

| O quê | Por quê foi aceita |
|---|---|
| **Três lastros para vínculo de mapeamento**, e um deles é limitação declarada | Decisão da pessoa mantenedora. A verificação do F6 revelou 10 vínculos sem lastro fora do escopo, em 5 ontologias que a análise excluiu. Fechar de verdade exige declarar 10 relações, e isso é feature própria |
| **`provenance` em relação e `note` em `relations` do mapeamento** | Dois campos novos no schema da base. Ambos com razão escrita no próprio schema, e nenhum inventa conceito |
| **As duas invariantes da derivada são de aplicação** | Sem `check_constraint` correspondente. Um caminho de escrita que não passe pelo changeset pode gravar equipe derivada malformada |
| **Paridade Elixir/Python continua aberta** | O validador Elixir tem 4 verificações, o Python tem 12 agora. O gate Python é o que decide, e roda no CI |

## Lições deste sprint

Cinco entraram no registro acumulado: L13, L14, L15, L16 e L17. As três mais caras
têm a mesma forma — **a configuração parecia certa e o efeito não existia**, e só a
execução revelou.
