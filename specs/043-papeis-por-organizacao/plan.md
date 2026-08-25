# Implementation Plan: Papéis por organização, e a promoção das evidências de vínculo

**Branch**: `043-papeis-por-organizacao` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/043-papeis-por-organizacao/spec.md`
**Fecha**: [#317](https://github.com/The-Band-Solution/theband/issues/317)

## Summary

Três mudanças que destravam a cadeia parada: **12 equipes, 101 evidências, 0 vínculos, 0 papéis** — com `organizational_role_id` sendo `NOT NULL`.

1. O cadastro de papéis passa a ser **por organização**.
2. Os quatro papéis do Scrum que a **SRO** nomeia ficam disponíveis em toda organização, **compostos na leitura** e materializados só quando usados.
3. A promoção de evidência a vínculo ganha tela, com autor — e **sem** o nível de acesso da origem.

## Technical Context

**Language/Version**: Elixir 1.20 · OTP 28
**Primary Dependencies**: Phoenix 1.8, LiveView, Ecto, PostgreSQL
**Storage**: PostgreSQL — `eo_organizational_roles` ganha `organization_id` e `catalog_concept_id`
**Testing**: ExUnit, `Phoenix.LiveViewTest`
**Project Type**: web application
**Constraints**: `EO.Constraints.platform_access_level_is_not_a_role/1` já existe e continua valendo
**Scale/Scope**: 3 organizações, 12 equipes, 101 evidências, 4 papéis de catálogo, **0 linhas a migrar**

Nenhum NEEDS CLARIFICATION. As quatro decisões vieram da pessoa mantenedora em 2026-08-24 e estão no `checklists/requirements.md` com a frase de origem.

## Constitution Check

| princípio | como esta feature o atende |
|---|---|
| **I. Domínio pelas ontologias** | o catálogo **é** a SRO. Os papéis não são inventados aqui |
| **II. Fonte externa não é domínio** | `MAINTAINER`/`MEMBER` continuam crus na evidência, e não viram papel |
| **III. Proveniência** | papel declarado tem autor; vínculo promovido tem autor; catálogo tem o conceito de origem |
| **IV. Semântica em YAML** | nada novo entra na rede — os quatro papéis **já estão** em `sro/modules/scrum_stakeholders.yaml` |
| **V. Multitenant** | e mais: o escopo passa de tenant para **organização**, que é o defeito que a feature conserta |
| **VI. Spec Kit antes do código** | spec escrita e validada |
| **VII. Gates e revisão** | 13 gates, revisão independente |
| **VIII. Desenho que o problema justifica** | ver **Registro das decisões**, abaixo |
| **IX. Ontologias modulares** | EO não ganha dependência: o catálogo é lido da SRO **pela camada de aplicação**, não por relação entre ontologias |
| **X. Responsabilidade única** | papéis na tela da organização; promoção na tela da equipe. Cada uma no seu alvo |

### Sobre o princípio IX, e um cuidado

O catálogo lê conceitos de **SRO** para popular papéis de **EO**. Isso **não** é dependência entre ontologias: nenhuma relação nova é declarada no YAML, e nenhuma ontologia passa a citar a outra. É a aplicação lendo a rede — a mesma coisa que `EO.suggested_roles/0` já faz hoje.

Se em algum momento aparecer a tentação de declarar `eo.organizational_role` como especialização de `sro.scrum_role`, **isso** seria dependência, e o princípio IX exigiria justificá-la. Não é o que este plano faz.

---

## Registro das decisões de desenho — princípio VIII

### Decisão 1 — O catálogo é composto na leitura, e a linha só nasce quando usada

Os quatro papéis da SRO **não** viram linhas em toda organização. `list_roles/2` compõe as entradas do catálogo com as linhas existentes, e a linha é materializada na primeira promoção que a usar.

**Que problema concreto resolve.** Semear cria 3 organizações × 4 papéis = 12 linhas que ninguém declarou, e o número cresce com cada organização nova. Pior: se a SRO renomear um papel, as linhas semeadas **divergem da rede em silêncio** — e a rede é a fonte da verdade (princípio I).

**Esse problema existe agora?** **Existe.** A `FR-002` exige os quatro em toda organização, e há três organizações — o defeito seria imediato, não hipotético. E o caso de borda *"a rede ganha um quinto papel"* está na spec: com composição ele aparece na leitura seguinte; com semeadura exige migração.

**O que fica pior.** Um papel do catálogo **não tem `id`** enquanto não é usado, e a tela precisa lidar com duas formas de identificar a mesma coisa: `catalog_concept_id` antes, `id` depois. É complexidade real, e ela vaza para o seletor de papel.

E há um risco de corrida: duas promoções simultâneas com o mesmo papel de catálogo tentariam materializar duas linhas. Resolvido com `on_conflict` no índice único — não com transação serializável, que seria caro para o caso raro.

**Alternativa descartada**: semear na criação da organização. Mais simples de ler, e faz a plataforma afirmar papéis que a rede talvez já não nomeie.

### Decisão 2 — `organization_id` nasce `NOT NULL`, sem coluna nula intermediária

**Que problema concreto resolve.** Nulo significaria *"papel de todo o tenant"* — que é exatamente o comportamento que a feature existe para corrigir. Manter a opção manteria o defeito disponível.

**Esse problema existe agora?** **Existe**, e é a `FR-001`. E há **zero linhas para migrar**: é a única janela em que `NOT NULL` sai de graça.

**O que fica pior.** Nada, neste momento — e essa é a razão de fazer agora. Em qualquer momento futuro, custaria decidir o que fazer com as linhas existentes.

### Decisão 3 — O índice único troca de forma, e isso é o bloqueio real

`UNIQUE (tenant_id, code)` passa a `UNIQUE (tenant_id, organization_id, code)`.

**Que problema concreto resolve.** Com o índice atual, a **segunda** organização a materializar `scrum_master` bate na constraint. O catálogo em todas as organizações é **impossível** sem esta troca.

**Esse problema existe agora?** **Existe**, e é bloqueante — não é melhoria.

**O que fica pior.** Perde-se a garantia de que um código é único no tenant. É deliberado: a `FR-006` diz que dois papéis de mesmo código em organizações diferentes **são papéis diferentes**.

### Decisão 4 — Nenhuma tabela nova, e nenhum estado de "ativação"

O `Mapping` tem `activate_catalog_rule/4`: a pessoa **ativa** uma proposta do catálogo. Aqui **não**.

**Que problema resolve.** Nenhum — e por isso não entra. A `FR-002` diz que os quatro estão disponíveis **sem cadastro prévio**, e um passo de ativação é cadastro prévio com outro nome. A `SC-001` mede isso: **zero passos** antes de poder promover.

**O que ficaria pior se entrasse.** Uma tela a mais entre a pessoa e o que ela quer fazer, para resolver um problema que o `Mapping` tem e este não: lá a proposta **muda dado** (reclassifica issues), e ativar é decisão de peso. Aqui o papel só passa a existir na lista.

---

## Project Structure

### Documentation (this feature)

```text
specs/043-papeis-por-organizacao/
├── spec.md
├── plan.md              ← este arquivo
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── papeis.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
priv/repo/migrations/
├── ..._roles_por_organizacao.exs        organization_id, catalog_concept_id, o índice
└── (nenhuma tabela nova)

lib/the_band/ontology/seon/eo/
├── role_catalog.ex                      os quatro da SRO, compostos com as linhas
├── commands.ex                          (toca: declarar papel, promover evidência)
├── queries.ex                           (toca: list_roles/2 por organização)
└── constraints.ex                       (toca: papel do vínculo é da org da equipe)

lib/the_band_web/live/
├── roles_live/index.ex                  (toca: passa a ser por organização)
└── teams_live/show.ex                   (toca: promover evidência; RETIRA o nível de acesso)

test/the_band/ontology/seon/eo/
└── papeis_por_organizacao_test.exs

test/the_band_web/live/
└── promocao_de_evidencia_test.exs       inclui a SC-005a — a violação
```

**Structure Decision**: sem módulo novo além do `role_catalog.ex`, que existe porque a composição catálogo × linhas é lógica própria e testável sozinha. O resto toca o que já existe.

---

## Complexity Tracking

| o que | por quê | o que se paga |
|---|---|---|
| catálogo composto na leitura | evita 12 linhas que ninguém declarou, e divergência silenciosa da rede | papel sem `id` até ser usado; `on_conflict` na materialização |
| `organization_id` obrigatório | nulo manteria o defeito disponível | nada agora — e é por isso que é agora |
| índice com organização | sem ele o catálogo em todas as orgs é impossível | perde-se unicidade por tenant, deliberadamente |

**Nada mais.** Sem tabela nova, sem estado de ativação, sem behaviour, sem cache.

---

## O que este plano NÃO faz

- **Não sugere papel.** Nem por acesso — a `FR-011` proíbe —, nem por comportamento.
- **Não remove `platform_access_level`.** Continua coletado e continua visível nas telas de equipe e de pessoa, onde é fato sobre a ferramenta. Sai **só** da tela de promoção.
- **Não implementa hierarquia de equipes** — [#397](https://github.com/The-Band-Solution/theband/issues/397), que depende desta.
- **Não migra papel algum.** Há zero.

## Dependências

**Nenhuma pendente.** `eo_team_membership_evidence` já tem as 101 linhas; `eo_team_memberships` já tem `declared_by_user_id`; `EO.Constraints.platform_access_level_is_not_a_role/1` já existe desde a feature 021; e os quatro papéis já estão na SRO.

Esta feature liga peças que já existem.
