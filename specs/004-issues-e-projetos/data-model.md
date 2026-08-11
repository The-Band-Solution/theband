# Modelo de dados e de classes — Feature 004

Derivado, não desenhado. Tudo abaixo saiu de
`scripts/derive_information_model.py`, exceto as tabelas de plataforma, que são
infraestrutura e não conceito.

---

## 1. As três camadas, e onde cada coisa mora

```
┌────────────────────────────────────────────────────────────────────────┐
│  PLATAFORMA — o que o GitHub respondeu, e o que a plataforma decidiu   │
│                                                                        │
│  observed_repositories ──┬── collected_issues ──┬── issue_promotions   │
│         │                │                      ├── decomposition_    │
│         │                │                      │     links           │
│         │                │                      └── refused_links     │
│         │                │                                            │
│         └── observed_projects ──┬── project_field_definitions          │
│                                 ├── project_items ── item_field_values │
│                                 └── project_iterations                 │
└──────────────────┬─────────────────────────────────────────────────────┘
                   │  promoção: a regra versionada decide
┌──────────────────▼─────────────────────────────────────────────────────┐
│  DOMÍNIO — derivado das ontologias                                     │
│                                                                        │
│  sys_swo_loaded_software_system_copies   ◄── kind referenciado          │
│      type ∈ {source_repository}              (criado uma vez só)        │
│      └── cmpo_source_repositories            extensão de CMPO          │
│                                                                        │
│  sro_user_stories        status ∈ {atomic_user_story, epic}  DERIVADO   │
│  sro_intended_scrum_development_tasks                                  │
│  osdef_defects                                                         │
│  sro_sprints             sro_sprint_backlogs    sro_product_backlogs   │
│  spo_intended_project_processes   iteração futura — intenção            │
└────────────────────────────────────────────────────────────────────────┘
```

**A fronteira decide tudo.** Uma issue coletada tem `issue_type` — o nome que o
GitHub deu. Uma user story não tem: ela tem `title`, `importance` e `complexity`,
porque é isso que a SRO define. O campo do GitHub não atravessa.

---

## 2. Domínio: o que a derivação produz

### 2.1 O kind referenciado, e por que ele aparece aqui

`cmpo.source_repository` é `subkind` de `sys_swo.loaded_software_system_copy`.
Pela **regra da fronteira** (constituição IX), atravessar a fronteira é referência:
o repositório é um valor de discriminador na tabela do kind, e não uma tabela
própria de CMPO.

Saída real do derivador, depois de anotar **um** conceito:

```
tabelas de kinds referenciados em outras ontologias — criar se ainda não
existirem, uma vez só:

┌─ sys_swo_loaded_software_system_copies  (sys_swo.loaded_software_system_copy,
│                                          kind de sys_swo)
└─

valores de discriminador contribuídos a kinds de outras ontologias:

   sys_swo.loaded_software_system_copy.type += {source_repository}
```

**Uma tabela, não duas.** É o que preserva a promessa da referência: a próxima
ontologia que precisar de "cópia carregada de sistema de software" — um ambiente
de build, um servidor de CI — aponta para a **mesma** tabela e acrescenta o seu
valor de discriminador. Nada do que já existe é alterado.

Os outros 10 conceitos da SysSwO continuam sem estereótipo, e isso está correto:
anotar a ontologia inteira para registrar um repositório é o pré-requisito
disfarçado que o princípio IX nomeia.

### 2.2 A extensão de CMPO

O repositório tem atributos que só ele tem, e eles não sobem para a tabela do
kind — iriam conviver com servidores de CI e ambientes de build, produzindo
colunas nulas em toda linha que não é repositório.

Saída real do derivador, depois de declarar os atributos do conceito:

```
┌─ cmpo_source_repositories   (estende sys_swo.loaded_software_system_copy
│                              [outra ontologia] onde type='source_repository')
│    loaded_software_system_copy_id  uuid      NOT NULL  → FK (extension)
│    name                            string    NOT NULL
│    qualified_name                  string    NOT NULL
│    url                             string    NOT NULL
│    description                     text      NULL
│    primary_language                string    NULL
│    default_branch                  string    NULL
│    archived_at                     datetime  NULL
│    external_created_at             datetime  NULL
│    last_pushed_at                  datetime  NULL
└─
```

**A tabela só existe porque o conceito declara atributos.** Um `subkind` sem
atributos contribui apenas um valor de discriminador na tabela do kind e desaparece —
foi o que a primeira versão deste documento descreveu, e estava incompleta. Declarar
os atributos em `cmpo.source_repository` é o que faz a extensão ser emitida.

Os atributos são o que **qualquer hospedagem de Git** fornece, não o que o GitHub
fornece. A Application Reference, `tenant_id`, `internal_id` e o par de observação
vivem na tabela do kind, que é onde a identidade mora.

### Três coisas que o repositório **não** guarda, e por quê

| Fora | Motivo |
|---|---|
| `is_fork` booleano | ser fork é dizer que esta cópia deriva de **outra cópia** — relação, não propriedade. Um booleano guardaria que existe origem e perderia qual é: o antipadrão "booleano no lugar do relator" |
| a lista completa de linguagens | exigiria conceito próprio para linguagem e relação com peso. Um array sem semântica declarada não responde nada |
| `licenseInfo`, `diskUsage` | licença é conceito de outra ontologia; tamanho em disco é métrica da hospedagem, não do item de configuração |

E uma declarada em vez de escondida: **`primary_language` é calculada pela origem
sobre o código**, e não é propriedade da cópia carregada em si. Fica no repositório
porque é onde a origem a fornece, com a atribuição escrita no mapeamento em vez de
presumida.

`default_branch` guarda o **nome** do ramo, não referência a `cmpo.branch`. A relação
existe na base — `cmpo.branch_belongs_to_repository` —, e apontar para ela exigiria
coletar ramos, fora do escopo desta feature.

**`archived_at` e `no_longer_observed_at` são coisas diferentes**, e confundi-las
seria o defeito. Arquivado é fato da origem: o GitHub diz. Não mais observado é
inferência da plataforma: comparou coletas e não achou. Um repositório arquivado
continua sendo observado.

**A exclusão pelo tenant não é nenhuma das duas** — está na camada de plataforma,
em `observed_repositories`, porque é decisão de quem administra e não fato do
mundo.

### 2.3 Os alvos das promoções

Já existem na derivação da SRO. Nenhuma coluna nova:

```
┌─ sro_user_stories   (sro.user_story, kind)
│    title                  string    NOT NULL
│    importance             decimal   NULL
│    complexity             decimal   NULL
│    status                 enum      NOT NULL  {atomic_user_story, epic}
│    product_backlog_id     uuid      NOT NULL  → FK (parthood)
│    sprint_backlog_id      uuid      NULL      → FK (parthood)
└─

┌─ sro_sprints   (sro.sprint, kind)
│    start_date             datetime  NULL
│    end_date               datetime  NULL
│    sprint_backlog_id      uuid      NOT NULL  → FK (association)
└─

┌─ sro_sprint_backlogs    (kind)
┌─ sro_product_backlogs   (kind)
```

**`importance` fica nula neste tenant.** O quadro real não tem campo numérico de
importância, e ausência é nula — nunca zero. Preencher com zero transformaria
lacuna em decisão, e a ordem derivada mentiria sem avisar.

### 2.4 A coluna que existe na derivação e **não** será materializada

```
sro_user_stories.status   enum   {atomic_user_story, epic}
```

O derivador a imprime porque `epic` e `atomic_user_story` são `phase`, e phase vira
discriminador. **Esta feature não a cria**, e a migração precisa dizer isso, ou a
próxima pessoa a acrescenta achando que faltava.

A razão é a ADR 0004 D7: a classificação é situação, e situação é derivada. Uma
user story vira épico ao ganhar partes e deixa de ser ao perdê-las — a issue #98
deste repositório nasceu sem partes e ganhou duas no mesmo dia. Um valor gravado na
primeira coleta estaria errado na segunda.

A derivação fica numa função, com **um caminho só**, como `observation_ended?/1`:

```elixir
@spec classification(Tenant.t(), Ecto.UUID.t()) :: :epic | :atomic_user_story
def classification(%Tenant{id: tenant_id}, user_story_id)
```

A tela e a consulta de escopo usam a mesma função. Dois caminhos discordariam.

---

## 3. O mapeamento por organização observada

Decisão da pessoa mantenedora em 2026-08-11: o mapeamento entre os conceitos da
organização e os da ontologia é configurado **na tela de definição da ferramenta**, e
vale **por organização**.

```
┌─ tool_concept_mappings   (por organização observada)
│    connected_tool_id     uuid    NOT NULL  ← o escopo: uma organização, uma instância
│    tenant_id             uuid    NOT NULL
│    kind                  enum    NOT NULL  {issue_type, project_field}
│    source_name           string  NOT NULL  "Feature", "Spike", "Estimate"
│    source_external_id    string  NULL      obrigatório para campo de quadro
│    target_concept        string  NULL      "sro.user_story", "osdef.defect"
│    target_attribute      string  NULL      "sro.user_story.complexity"
│    decided_by            enum    NOT NULL  {structure, declaration}
│    declared_by_user_id   uuid    NOT NULL  decisão tem autor
│    declared_at           datetime NOT NULL
│
│  UNIQUE (connected_tool_id, kind, source_name)
└─
```

**`connected_tool_id` e não `tenant_id` como escopo.** A ferramenta conectada **é** a
organização: a identidade dela é tenant, tipo, instância e organização. Guardar o
mapeamento nela é guardá-lo por organização sem criar um segundo lugar que possa
divergir do primeiro.

O que isso permite, e um mapeamento por tenant impediria: uma organização usa
`Feature`, outra usa `História`, e as duas convivem. Sem esse escopo, a segunda
organização a ser conectada viraria lacuna permanente — e a lacuna não teria culpado,
porque nenhuma das duas está errada.

### Três coisas que o desenho separa de propósito

**`decided_by`** distingue o que a estrutura decide do que a declaração decide.
`Feature` roteia para dois conceitos e quem escolhe é a estrutura — `decided_by:
structure`, e `target_concept` fica `sro.user_story`, o abstrato. `Bug` é
`declaration`, com destino concreto.

**`source_external_id` obrigatório em tudo.** Decisão da pessoa mantenedora em
2026-08-11: é o identificador que liga a entidade do modelo à da organização, e é ele
que faz o mapeamento sobreviver a renomeação.

Eu havia escrito que tipo de issue não tinha identificador estável e que o nome seria
a chave. **Estava errado** — o GraphQL devolve `issueType.id`:

```
Feature  IT_kwDODHSRm84BlVJy
Task     IT_kwDODHSRm84BlVJw
Bug      IT_kwDODHSRm84BlVJx
```

`source_name` continua gravado, para leitura humana e para a tela mostrar o que a
organização chama de quê. Mas a chave é o identificador.

**`declared_by_user_id` não é anulável.** Ao contrário do evento de observação, que
pode vir de processo, um mapeamento é sempre decisão de alguém. Sem autor não há como
responder "quem decidiu que Spike é uma user story".

### A precedência, e por que o YAML continua existindo

```
regra global em rules/github_issue_type_routing.yaml     padrão da rede
  └─ regra do tenant em rules/tenants/<tenant>.yaml      padrão do tenant
       └─ tool_concept_mappings                          desta organização
```

O YAML é o **padrão do qual a configuração parte**, e a linha da tabela sobrescreve
apenas para aquela organização — FR-049. As duas têm o mesmo efeito na promoção, e são
distinguíveis pela proveniência: a do YAML passou por revisão de código, a da tela não.
Quem lê uma medida derivada precisa poder saber qual das duas a sustenta.

**Conectar não é bloqueado por mapeamento pendente** (FR-041c). Sem linha nenhuma, o
padrão vale e os tipos não reconhecidos aparecem como lacuna — que é o que a US1 já
mostra.

---

## 4. Plataforma: as tabelas de coleta

### 4.1 `observed_repositories`

O que a plataforma decidiu sobre cada repositório — separado do repositório em si,
que é domínio.

| Coluna | Por que existe |
|---|---|
| `connected_tool_id` | por qual ferramenta foi observado |
| `source_repository_id` | o registro de domínio |
| `excluded_at`, `excluded_by_user_id` | FR-004: exclusão é decisão, com autor |
| `inaccessible_since`, `inaccessible_reason` | FR-006: virou privado ou sumiu do alcance da credencial |

**`excluded_at` e `inaccessible_since` não se misturam.** Excluído é decisão do
tenant; inacessível é falha de alcance. As duas impedem a coleta e **nenhuma das
duas marca ausência** — é o que FR-005 e FR-006 exigem, e é a L19 aplicada: só
marca ausência quem foi realmente olhado.

### 4.2 `collected_issues`

```
tenant_id            uuid      NOT NULL
observed_repository_id uuid    NOT NULL   ← o escopo da ausência
issue_type           string    NULL       o nome que o GitHub deu, cru
number               integer   NOT NULL   para exibir, nunca para identificar
title                string    NOT NULL
state                string    NOT NULL
source_system        string    NOT NULL ┐
source_instance      string    NOT NULL ├ Application Reference
external_id          string    NOT NULL ┘  o id GLOBAL
collected_at         datetime  NOT NULL
last_observed_at     datetime  NULL
no_longer_observed_at datetime NULL

UNIQUE (tenant_id, source_system, source_instance, external_id)
```

**`number` não é identidade.** Mover uma issue entre repositórios cria outro número
no destino e preserva o da origem — duas linhas para a mesma issue. O identificador
global não muda.

**`issue_type` é texto livre e fica cru.** Normalizá-lo na coleta destruiria o dado
que a lacuna precisa mostrar: FR-034 manda exibir *o nome do tipo encontrado*.

### 4.3 `issue_promotions`

```
collected_issue_id   uuid      NOT NULL
declared_concept     string    NULL     o que o tipo declarado indicava
derived_concept      string    NULL     o que a estrutura decidiu — nulo se não promoveu
target_table         string    NULL     onde o registro de domínio foi criado
target_id            uuid      NULL
rule_id              string    NOT NULL github.issue_type_routing
rule_version         integer   NOT NULL
divergence_reason    text      NULL     preenchido quando declarado ≠ derivado
skip_reason          string    NULL     type_unknown | type_absent | ...
promoted_at          datetime  NOT NULL
```

**Três estados, e o desenho os distingue:**

| `derived_concept` | `skip_reason` | Significa |
|---|---|---|
| preenchido | nulo | promovida |
| nulo | preenchido | não promovida, e o motivo está aqui |
| preenchido | nulo, `divergence_reason` preenchido | promovida **contra** o rótulo declarado |

O terceiro é o que a tela mostra em FR-035, e é o dado mais interessante para quem
administra o processo: épico abandonado sem decomposição, ou user story que cresceu
e virou épico sem retipagem.

`rule_version` é o que permite responder *"por que esta issue foi classificada assim
em março"* depois de a regra mudar — e ela vai mudar, tem `status: proposed`.

### 4.4 `decomposition_links` e `refused_links`

```
decomposition_links          refused_links
  parent_issue_id              parent_issue_id
  child_issue_id               child_issue_id
  observed_at                  reason        cycle | out_of_scope
  last_observed_at             cycle_path    text — o caminho que fechava
  no_longer_observed_at        refused_at
```

`refused_links` existe porque FR-017 manda **nomear** o caminho que fecha o ciclo, e
um vínculo descartado em memória não tem como ser nomeado depois da coleta.

**Declarado no plano como previsão, não como problema existente**: nunca observei
ciclo de sub-issues em dado real. Critério de reversão escrito — se ficar vazia
depois de duas coletas reais em todos os tenants, vira contagem no relatório do
`sync`.

`reason: out_of_scope` cobre o edge case 3: a parte está em repositório fora do
escopo observado. A relação existe e é registrada; a parte não é promovida.

### 4.5 Projeto, campos e itens

```
observed_projects                project_field_definitions
  connected_tool_id                observed_project_id
  spo_project_id      ← domínio    field_external_id   ← a IDENTIDADE
  number                           name                ← muda, e não importa
  title                            data_type
  application reference            options              jsonb, quando seleção única

project_items                    item_field_values
  observed_project_id              project_item_id
  collected_issue_id   NULL        project_field_definition_id
  is_draft             boolean     raw_value            jsonb — sempre guardado
  application reference            interpreted_as       string NULL — atributo da
                                                        ontologia, se mapeado

project_iterations
  observed_project_id
  iteration_external_id
  title, start_date, duration_days
  sro_sprint_id                    NULL  ← quando start_date já passou
  spo_intended_process_id          NULL  ← quando ainda não chegou
```

**A identidade do campo é `field_external_id`** (FR-027). Renomear "Priority" para
"Prioridade" muda `name` e não cria campo novo, nem invalida o mapeamento.

**`raw_value` é sempre gravado; `interpreted_as` só quando há mapeamento
declarado** (FR-025). Um campo chamado `Priority` **não** é `importance`: importance
é decimal com escala declarada, Priority é seleção única cujos valores o tenant
inventou. Converter por semelhança de nome é o antipadrão nomeado em `AGENTS.md`
§7.7.

**Exatamente um dos dois preenchido, nunca os dois** (FR-030, SC-009c). Iteração
futura é *planning que não foi feito* — `spo.specific_intended_project_process`,
categoria UFO `intention`. Iteração iniciada é `sro.sprint`, `complex_action`.

A troca acontece **na coleta seguinte ao início**, não no instante do início: a
plataforma afirma o que observou, não o que o calendário implica.

**O quadro não tem coluna de promoção.** `observed_projects` não aponta para
conceito nenhum, porque quadro é planejamento e visualização — não empreendimento.
Quem promove é o conteúdo dele.

---

## 5. O modelo de classes

### 5.1 Fronteiras de módulo

```
lib/the_band/
│
├── work_items.ex                    ◄── fronteira: coleta e promoção de issues
│   └── work_items/
│       ├── commands.ex  queries.ex
│       └── schemas/                     PRIVADOS
│           ├── collected_issue.ex
│           ├── issue_promotion.ex
│           ├── decomposition_link.ex
│           └── refused_link.ex
│
├── projects.ex                      ◄── fronteira: projeto, campos, itens
│   └── projects/schemas/*.ex            PRIVADOS
│
├── ontology/seon/cmpo.ex            ◄── fronteira: repositório
│   └── cmpo/schemas/source_repository.ex
│
└── ontology/continuum/sro.ex        ◄── fronteira: user story, sprint, backlogs
    └── sro/schemas/*.ex
```

**Cada módulo raiz contém apenas `defdelegate`** (ADR 0003). Nenhum módulo alcança
os schemas de outro, e nenhum chama `Repo` sobre tabelas alheias.

**A fronteira é o módulo raiz e não o schema**, pelo mesmo motivo de sempre: o
schema é a forma da tabela, e a tabela é derivada — ela muda quando a ontologia
muda. Dependentes do schema fariam cada mudança de derivação quebrar consumidores
por toda a aplicação, e a pressão para não mexer na derivação venceria a semântica.

### 5.2 Quem chama quem

```
Jobs.SyncGithubSRO
    │
    ├─▶ WorkItems.record_collected_issue/2         plataforma
    │        │
    │        └─▶ SemanticIntegration.Mapper        aplica a regra versionada
    │                 │
    │                 ├─▶ SRO.upsert_user_story_from_source/2
    │                 ├─▶ SRO.upsert_intended_task_from_source/2
    │                 └─▶ OSDEF.upsert_defect_from_source/2
    │
    ├─▶ WorkItems.record_promotion/2               grava a decisão e a divergência
    ├─▶ WorkItems.record_decomposition_link/2      recusa ciclo aqui, não no banco
    └─▶ CMPO.upsert_source_repository_from_source/2
```

**O mapper é quem promove, e ele lê a regra do YAML.** Nenhum `case` sobre nome de
tipo em código Elixir: a regra é semântica, e o princípio IV manda que semântica
viva em YAML versionado. Um `case` no código tornaria a mudança de regra um deploy
em vez de um commit revisável na base de conhecimento.

**A recusa de ciclo é no comando**, não em `check_constraint`. O próprio axioma
`sro.rule04` diz por quê: *"uma constraint de banco sozinha não pega ciclo
transitivo em auto-relacionamento; é preciso checar o caminho até a raiz"*.

### 5.3 API pública, e o que ela não expõe

```elixir
# WorkItems
record_collected_issue(tenant, attrs)      :: {:ok, issue} | {:error, term}
record_promotion(tenant, attrs)            :: {:ok, promotion}
record_decomposition_link(tenant, attrs)   :: {:ok, link} | {:error, {:cycle, path}}
list_issues(tenant, opts)                  :: [issue]
count_by_promotion(tenant, opts)           :: %{concept => count}
count_gaps_by_reason(tenant, opts)         :: %{reason => count}
list_divergences(tenant, opts)             :: [divergence]
mark_issues_no_longer_observed(tenant, repository_id, collection_started_at)

# SRO
classification(tenant, user_story_id)      :: :epic | :atomic_user_story
list_user_stories(tenant, opts)            :: [user_story]
product_backlog(tenant, project_id)        :: [item]     itens sem iteração
sprint_backlog(tenant, sprint_id)          :: [item]     itens com iteração iniciada
```

| Ausente | Por quê |
|---|---|
| `create_user_story/2` | não há cadastro manual nesta feature; expor convidaria a criar registro sem proveniência |
| `set_classification/3` | a classificação é derivada. Uma função para gravá-la é a porta para materializar situação |
| `delete_issue/2` | ausência marca, nunca apaga |
| qualquer função devolvendo `Ecto.Query` | vaza o schema e permite compor fora da fronteira, contornando o filtro de tenant |

**Nota sobre `mark_issues_no_longer_observed/3`**: a assinatura exige
`repository_id`. Não é conveniência — é a L19 impedida no tipo. Uma versão sem esse
argumento marcaria as issues de repositórios que aquela coleta nunca olhou, em
volume muito maior que as três organizações do defeito original.

---

## 6. O que **não** é materializado

| Não existe como coluna | Onde vive |
|---|---|
| `sro_user_stories.status` (épico/atômica) | derivado dos vínculos de decomposição |
| pertencimento a product backlog ou sprint backlog | derivado da atribuição de iteração do item |
| `is_epic` booleano | é o antipadrão "booleano no lugar do relator" |
| tipo de issue normalizado | `issue_type` fica cru; a promoção guarda o conceito |
| `sro.scrum_project` | não é promovido: adotar Scrum não é observável |
| `spo.software_project` a partir do quadro | quadro é planejamento; empreendimento vem de cadastro declarado |
| `sro.planning_meeting` | o quadro é o resultado de planejar, não a cerimônia |
| histórico de mudança de item | fora de escopo por custo de consumo |

---

## 7. Migrações

Uma por fase, cada uma explicando no `@moduledoc` por que a forma é essa —
inclusive as ausências deliberadas, que são o que ninguém recupera depois.

| Fase | Cria |
|---|---|
| F0 | nada. Anota `sys_swo.loaded_software_system_copy` como `kind` |
| F2 | `sys_swo_loaded_software_system_copies`, `cmpo_source_repositories`, `observed_repositories` |
| F3 | `collected_issues`, `issue_promotions`, `decomposition_links`, `refused_links` |
| F4 | `observed_projects`, `project_field_definitions`, `project_items`, `item_field_values`, `project_iterations`, `spo_intended_project_processes` |

**Nenhuma migração desta feature remove coluna**, e nenhuma cria
`sro_user_stories.status`.
