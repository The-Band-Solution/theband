# Implementation Plan: Pessoas e equipes separadas por organização observada

**Branch**: `002-escopo-por-organizacao` | **Date**: 2026-08-10 | **Spec**: [spec.md](spec.md)

**Entrada**: [spec.md](spec.md) · [ontology-analysis.md](ontology-analysis.md)

A análise ontológica foi feita **antes** deste plano e é seu insumo principal.
Nove achados, e o F1 muda a causa do problema: as colunas que deveriam carregar o
vínculo **não existem no modelo derivado** — foram escritas à mão na feature 001,
contra a ADR 0004, D4. Corrigir o mapeamento sem corrigir isso manteria colunas
sem lastro conceitual.

## Summary

A organização de uma pessoa passa a ser lida **pelas equipes dela**. Para que o
caminho seja completo, toda organização com membros fora de suas equipes ganha
uma equipe com o nome da organização, e esses membros são vinculados a ela.

Quatro movimentos, nesta ordem:

1. **Ontologia** — declarar a relação entre equipe organizacional e organização,
   que hoje só existe na prosa da definição;
2. **Transformação** — ensinar o derivador a gerar chave estrangeira a partir de
   associação, que hoje ele só faz para parthood e relator;
3. **Esquema** — remover as duas colunas inventadas e receber `organization_id`
   pela derivação, agora legítima;
4. **Coleta e telas** — a equipe derivada, o retrofito do que já foi coletado, e
   as consultas por organização.

Nenhuma dependência nova. Nenhuma tabela nova.

## Technical Context

**Language/Version**: Elixir 1.20.2 / OTP 29 — inalterado desde a feature 001

**Primary Dependencies**: nenhuma nova. Phoenix, Ecto, Oban, Req, `yaml_elixir`,
`cloak_ecto` já estão fixados em `mix.exs`

**Storage**: PostgreSQL 17, mesma base, mesmas convenções de `tenant_id`

**Testing**: ExUnit + Mox na borda HTTP; testes de tela com `Phoenix.LiveViewTest`

**Ferramentas de conhecimento**: `derive_information_model.py` e
`validate_knowledge_base.py` são alterados — são a cadeia de derivação declarada,
e a mudança é nelas, não em volta delas

**Performance Goals**: nenhuma meta de latência é requisito. O que é medido é
comportamental: SC-004 (as contagens fecham com a sobreposição) e SC-005
(retrofito sem consultar a origem)

**Constraints**: a equipe derivada **não existe na ferramenta de origem** e
precisa se declarar derivada em todo lugar onde aparece. O retrofito não pode
consultar o GitHub

**Scale/Scope**: 3 organizações observadas, 72 pessoas, 10 equipes coletadas —
o quadro real onde o defeito apareceu, e onde a correção é verificável

## Constitution Check

Contra a [constituição v1.2.0](../../.specify/memory/constitution.md), princípio a princípio.

| # | Princípio | Veredito | Como esta feature o satisfaz |
|---|---|---|---|
| I | Domínio organizado pelas ontologias | **PASS** | A relação equipe↔organização entra **em EO**, e a coluna passa a vir da derivação. É o oposto do que a feature 001 fez: lá a coluna veio do código, aqui vem do modelo. Nenhum conceito novo é criado — a equipe derivada é instância de `eo.team`, não um tipo à parte |
| II | Fonte externa não é domínio | **PASS com atenção** | A equipe derivada **não vem da fonte**, e é justamente por isso que ela declara `source_system` da plataforma, não do GitHub. O risco de ela ser lida como observada é real e está tratado em FR-005, FR-011 e FR-017 |
| III | Proveniência e idempotência | **PASS** | A equipe derivada tem Application Reference completa, apontando para a derivação. Seu `external_id` é determinístico a partir da organização, então reprocessar produz a mesma equipe — sem duplicar e sem alternar |
| IV | Semântica declarada em YAML versionado | **PASS** | A relação nova, a regra da equipe derivada e as perguntas de competência de EO entram na base. A regra de transformação também é declarada, no artefato que já existe para isso |
| V | Monólito modular multitenant | **PASS** | Nenhum módulo novo. As escritas continuam pela API pública de EO; as consultas continuam recebendo o tenant |
| VI | Spec Kit, contrato e fatia vertical | **PASS** | spec → análise ontológica → este plano. Os contratos são escritos antes do código. A fatia termina nas telas de pessoas e equipes filtráveis por organização |
| VII | Quality gates e revisão independente | **PASS com lacuna declarada** | Os oito gates valem. **A revisão independente continua pendente** — a feature 001 tampouco a obteve, e a lacuna não pode ser marcada como cumprida por quem implementa |
| VIII | Desenho que o problema justifica | **PASS** | Três respostas registradas abaixo para cada padrão introduzido |

### Princípio VIII — as três respostas

**Padrão 1: distinção observado / derivado, carregada pela proveniência existente**

| Pergunta | Resposta |
|---|---|
| Qual problema concreto resolve? | a equipe com o nome da organização não existe no GitHub; sem distinguir, "10 equipes" da plataforma não bate com o GitHub e nada explica a diferença |
| Existe agora? | sim — `ifesserra-lab` tem 0 times na origem e passará a ter 1 na plataforma |
| O que fica pior? | toda consulta de equipe passa a ter duas leituras possíveis — com e sem derivadas — e quem escrever a próxima precisa escolher conscientemente |

**Decisão que evita um padrão**: a distinção **não** ganha coluna nova. Ela já
cabe em `source_system`, que toda tabela alimentada por fonte externa tem por
exigência do princípio III. Equipe observada tem `source_system: "github"`;
derivada tem `source_system: "the_band"`. Acrescentar uma coluna `origin` seria
repetir o erro do F1 — inventar campo onde já existe um que responde.

**Padrão 2: regra de associação para chave estrangeira na transformação**

| Pergunta | Resposta |
|---|---|
| Qual problema concreto resolve? | a relação equipe↔organização é `association`, e o derivador só gera FK para `part_whole` e relator; sem a regra, declarar a relação não produz coluna |
| Existe agora? | sim — é a primeira associação `many → one` entre kinds da base, e a segunda já está à vista (`project_team` → projeto, F8) |
| O que fica pior? | o derivador passa a ter três caminhos para gerar FK, e a leitura da saída exige saber qual regra a produziu. Mitigado porque cada FK sai anotada com sua origem, como as atuais |

**Padrão 3: retrofito do que já foi coletado**

| Pergunta | Resposta |
|---|---|
| Qual problema concreto resolve? | 72 pessoas e 10 equipes já coletadas ficariam sem organização até alguém recoletar tudo, gastando janela de API por dado que já está preservado |
| Existe agora? | sim, e é medido: 0 de 10 equipes com organização preenchida |
| O que fica pior? | mais um caminho de escrita sobre `eo_teams`, além da coleta. Mitigado por ele reusar o mesmo comando público de EO, e não escrever direto |

**O que deliberadamente não é abstraído**: a evidência de vínculo com equipe e a
regra da equipe derivada permanecem separadas, ainda que ambas gravem em
`eo_team_membership_evidence`. São duas ocorrências; a terceira é que justificaria
extrair um mecanismo comum.

## Project Structure

### Documentation (this feature)

```text
specs/002-escopo-por-organizacao/
├── spec.md                  # concluído — 24 FR, 10 SC, 3 user stories
├── checklists/requirements.md
├── ontology-analysis.md     # concluído — 9 achados, insumo deste plano
├── plan.md                  # este arquivo
├── research.md              # Fase 0
├── data-model.md            # Fase 1
├── contracts/               # Fase 1
│   ├── ontology-eo.md              acréscimos à API pública de EO
│   ├── derived-team.md             a equipe derivada e seu vínculo
│   ├── information-model.md        a regra nova da transformação
│   └── screens.md                  filtro por organização nas telas
└── quickstart.md            # Fase 1
```

### Source Code

Somente o que muda. Nenhum diretório novo.

```text
priv/knowledge_base/
├── ontology/seon/eo/
│   ├── modules/organizational_structure.yaml    +1 relação
│   └── competency_questions/                    NOVO — F7
├── rules/github_default_team.yaml               NOVO — a equipe derivada
├── mappings/github/eo/{team,user}.yaml          corrigidos — F6
└── transformations/ontology_to_information_model.yaml   +1 regra — F5

scripts/
├── derive_information_model.py                  implementa a regra nova
└── validate_knowledge_base.py                   valida relação de mapeamento — F6

priv/repo/migrations/                            remove as colunas de F1; recebe a derivada

lib/the_band/
├── ontology/seon/eo/{commands,queries,constraints}/   organização de equipe, consultas por organização
├── semantic_integration.ex                      retrofito
└── jobs/sync_github_eo.ex                       cria a equipe derivada ao fim da coleta

lib/the_band_web/live/{people_live,teams_live}/  filtro por organização

test/                                            um teste por invariante nova
```

**Structure Decision**: nenhuma mudança estrutural. A feature altera a cadeia
declarativa — ontologia, transformação, mapeamentos, regras — e o código que a
consome. É o caminho que o projeto já definiu; o que a feature 001 fez de errado
foi **contorná-lo**, escrevendo coluna à mão.

## Complexity Tracking

| Violação | Por que é necessária | Alternativa mais simples, e por que foi rejeitada |
|---|---|---|
| A equipe derivada é dado que não existe na origem | decisão da pessoa mantenedora, registrada na spec. Torna completo o caminho `pessoa → equipe → organização`, e com isso dispensa um segundo vínculo direto | Um vínculo direto pessoa↔organização foi considerado e **rejeitado por ela**: criaria dois caminhos para a mesma pergunta, que podem discordar sem que nada avise |
| Alterar `derive_information_model.py`, que é Python | é a cadeia de derivação declarada do projeto, e `scripts/README.md` já a registra como transitória até virar Mix task. Não é tecnologia nova | Escrever a coluna à mão na migração foi rejeitado — é exatamente o defeito F1 que esta feature corrige |
| Remover colunas existentes do esquema | `eo_people.organization_id` e `eo_teams.organization_id` não existem no modelo derivado; enquanto ficarem, regenerar o modelo produz esquema diferente do banco sem aviso | Mantê-las preenchidas foi rejeitado: `eo_people.organization_id` é semanticamente errada — a pessoa pertence a várias organizações, e a coluna alternaria de valor a cada coleta |

## Constitution Check — reavaliação após a Fase 1

O desenho não introduziu violação nova, e resolveu duas tensões que estavam em
aberto quando o gate foi avaliado a primeira vez.

| # | O que a Fase 1 acrescentou |
|---|---|
| I | A coluna `organization_id` passa a sair da derivação, anotada como `association` — deixa de ser invenção do código e passa a ter lastro na ontologia. A regressão exigida no V1 do quickstart garante que nenhuma outra ontologia mude |
| II | **Tensão resolvida sem coluna nova**: a distinção observado/derivado cabe em `source_system`, que já existe por exigência do princípio III. Acrescentar `origin` teria repetido o F1 |
| III | A equipe derivada tem `external_id` determinístico a partir da organização, então reprocessar não duplica. O vínculo derivado tem `platform_access_level` **nulo** — ausência é nula, e gravar `MEMBER` para manter a coluna obrigatória inventaria dado |
| IV | A regra da equipe derivada e a regra de associação são **declaradas** em YAML, não embutidas. O validador passa a reprovar mapeamento que declare relação inexistente — a verificação que faltava para este defeito ser pego |
| V | Nenhum módulo novo; as escritas continuam pela API pública de EO |
| VI | Quatro contratos escritos **antes** do código. `list_*` e `count_*` recebem as mesmas `opts` novas, mantendo a regra que existe desde a 001 |
| VII | A revisão independente **continua pendente**, e continua declarada |
| VIII | Três padrões introduzidos, três respostas cada. E um padrão **evitado** com a razão registrada: a coluna `origin` que não existirá |

Duas decisões de contrato merecem registro por nascerem de defeito real:

- **quem chama `upsert_derived_team/3` não decide a proveniência.** A função a
  monta. Deixar aberto permitiria gravar equipe derivada como observada, que é o
  único jeito de esta feature produzir dado falso;
- **`list_teams/2` mostra derivadas por padrão.** Esconder é pior que marcar: quem
  não vê a equipe não sabe que ela existe, e a contagem de pessoas passa a não
  fechar sem explicação.

## Fases

- **Fase 0 — pesquisa**: concluída — [research.md](research.md), R1 a R5.
- **Fase 1 — desenho e contratos**: concluída — [data-model.md](data-model.md),
  [contracts/](contracts/) e [quickstart.md](quickstart.md).
- **Fase 2 — tarefas**: `/speckit-tasks`, fora do escopo deste comando.
