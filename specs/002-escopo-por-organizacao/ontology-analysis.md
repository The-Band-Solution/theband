# Análise ontológica — feature 002

**Feita antes do `/speckit-plan`**, conforme AGENTS.md §12: toda feature
ontológica identifica ontologia principal, dependências, conceitos e relações
afetados, cardinalidades, constraints, perguntas de competência, YAMLs,
mapeamentos, migrações e riscos semânticos.

**Ontologia principal**: EO (Enterprise Ontology), camada core da SEON.
**Depende de**: nenhuma. EO é das mais gerais; nada acima dela muda.
**Não toca**: SPO, SysSwO, SRO, CMPO — nenhuma relação de dependência é criada.

---

## O que EO declara hoje

10 conceitos, 7 relações.

```text
organization ─────────part_of──> organization   (matriz e subsidiária)
organizational_unit ──part_of──> organization
organization ──recognizes─> organizational_role
team_membership ─allocates─> team_member
team_membership ──to────> team
team_membership ──to play─> organizational_role
team_member ───is played by─> person
```

Conceitos: `organization`, `organizational_unit`, `organizational_part`,
`person`, `organizational_role`, `team`, `organizational_team`, `project_team`,
`team_member`, `team_membership`.

> **Renomeação de 2026-08-10**, feita antes desta análise ser concluída:
> `eo.sector` passou a se chamar `eo.organizational_unit`, e o `role_mixin` que
> ocupava esse nome passou a `eo.organizational_part`. Decisão da pessoa
> mantenedora, alinhando o vocabulário ao uso corrente em modelagem corporativa.
> As categorias UFO e os critérios de identidade permanecem intactos — mudaram os
> nomes, não o que eles significam.

---

## Achados

### F1 — Existem colunas que nenhuma relação ontológica sustenta

`eo_teams.organization_id` e `eo_people.organization_id` estão **no banco** e
**não estão no modelo derivado**:

```text
$ derive_information_model.py --ontology eo

┌─ eo_teams   (eo.team, kind)
│    type    enum   NOT NULL  {organizational_team, project_team}
└─                                    ← nenhuma organization_id

┌─ eo_people   (eo.person, kind)
│    name    string NOT NULL
│    email   string NULL
└─                                    ← nenhuma organization_id
```

Eu as escrevi à mão na migração da feature 001. Isso viola a **ADR 0004, D4**:
o modelo de informação é derivado, nunca escrito à mão — justamente para que
esquema e ontologia não divirjam.

**Esta é a causa raiz.** O diagnóstico anterior — "o mapeamento aponta para um
caminho que não existe no payload" — era o sintoma. A causa é que as colunas
foram inventadas, e o mapeamento não tinha para onde escrever de forma legítima.
Corrigir só o mapeamento manteria colunas sem lastro conceitual.

**Severidade: alta.** Enquanto existirem, qualquer regeneração do modelo produz
um esquema diferente do que está no banco, sem que nada avise.

### F2 — EO afirma em prosa vínculos que não declara em relação

| Conceito | O que a definição afirma | Relação declarada |
|---|---|---|
| `eo.organizational_team` | "Equipe **ligada a uma organização**, e não a um projeto específico" | nenhuma |
| `eo.organization` | "Agente social que reconhece papéis organizacionais e **emprega pessoas**" | só `recognizes`, para papel |

Definição não é modelo. O que está em prosa não gera coluna, não é verificável e
não pode ser consultado — e foi exatamente essa lacuna que permitiu a F1 passar
despercebida.

### F3 — Pessoa e organização: EO já tem caminho, e ele não serve a esta fonte

Existe um caminho declarado, e ele é intencional:

```text
person ← team_member ← team_membership → organizational_role ← recognizes ← organization
```

EO liga pessoa a organização **pelo papel que a organização reconhece**. Não há
aresta direta, e a ausência é desenho, não esquecimento: a SEON evita afirmar
vínculo entre pessoa e organização sem dizer *sob qual condição*.

O caminho existe e está **indisponível para o GitHub**, porque exige papel
organizacional — que a fonte não fornece.

**Decisão: não acrescentar relação pessoa↔organização em EO.**

Duas razões, e a segunda é a que decide:

1. o caminho já existe; acrescentar aresta direta criaria duas formas de
   responder à mesma pergunta, que podem discordar;
2. **"emprega" não é "aparece entre os membros no GitHub".** Contribuidor
   externo, estudante, parceiro e ex-integrante aparecem como membros sem
   qualquer vínculo empregatício. Mapear um no outro afirmaria o que a origem não
   afirma — o mesmo erro que a regra do vínculo com equipe já recusa.

**Decisão final, após a medição abaixo e a decisão de projeto de F4b**: não há
vínculo direto entre pessoa e organização. A organização de uma pessoa é lida
pelas equipes dela, e a equipe derivada garante que toda pessoa tenha ao menos
uma. Um segundo vínculo, direto, criaria dois caminhos para a mesma pergunta —
exatamente o que este achado recusa acrescentar em EO.

#### A medição que levou até aqui

A leitura natural do modelo é: uma equipe pertence a uma organização, uma pessoa
está em uma ou mais equipes, **logo** a organização da pessoa sai das equipes
dela. O formato está certo, e mesmo assim o caminho não é suficiente.

Medido sobre os dados reais das três organizações observadas:

| | |
|---|---|
| pessoas conhecidas | 72 |
| em ao menos uma equipe | 54 |
| **em equipe nenhuma** | **18** |

E na origem, `ifesserra-lab` tem **5 membros e 0 times**.

Derivar a organização apenas pela equipe perderia 25% das pessoas e **uma das
três organizações por inteiro** — ela sumiria da consulta sem que nada avisasse,
porque não haveria linha nenhuma dizendo que ela existe no quadro.

A causa é da fonte, não do modelo: o GitHub lista membros da organização
independentemente de participação em times. Ser membro da organização e integrar
uma equipe são **duas observações distintas**, e a segunda não implica a primeira
nem vice-versa.

Duas saídas eram possíveis: um segundo vínculo, direto entre pessoa e
organização, ou uma equipe que acolhesse quem está fora das equipes observadas.
**A decisão de projeto escolheu a segunda** — ver F4b. Com ela, todo membro passa
a estar em alguma equipe, o caminho pela equipe fica completo, e o vínculo direto
deixa de ser necessário.

### F4 — Equipe e organização: a relação falta, e declará-la é fiel

Aqui o caso é oposto ao F3. A definição de `eo.organizational_team` **já afirma**
o vínculo; declará-lo não inventa semântica, torna explícito o que o conceito diz
de si.

Proposta:

```yaml
- id: eo.organizational_team_belongs_to_organization
  name: belongs to
  label: { pt-BR: "pertence a", en: "belongs to" }
  source: eo.organizational_team
  target: eo.organization
  type: association
  cardinality: { source: many, target: one }
```

Três decisões dentro dela:

- **parte do subkind, não do kind.** `eo.project_team` liga-se a um projeto —
  conceito de SPO —, não a uma organização. Pôr a relação em `eo.team` obrigaria
  toda equipe de projeto a ter organização, o que é falso em projeto entre
  organizações;
- **`association`, não `part_whole`.** Uma equipe é coletivo de pessoas; a
  organização é agente social. "Ligada a" não é "parte de" —
  `eo.organizational_unit` é parte, e a distinção entre unidade e equipe é
  justamente essa. Ver o risco R1 abaixo;
- **`many → one`.** Uma equipe organizacional pertence a exatamente uma
  organização; uma organização tem várias.

### F4b — Decisão de projeto: equipe padrão para organização sem times

**Decisão da pessoa mantenedora, 2026-08-10**: toda organização observada que
tenha membros fora de suas equipes recebe uma equipe com o nome da organização, e
esses membros são vinculados a ela.

Dois casos, e a regra cobre os dois com um enunciado só:

| Caso | Medido | Efeito |
|---|---|---|
| organização sem nenhuma equipe | `ifesserra-lab`: 5 membros, 0 times | os 5 vão para a equipe derivada |
| organização com equipes e membros fora delas | 18 de 72 pessoas sem equipe | só os de fora vão para a derivada |
| organização com todos em equipes | `The-Band-Solution`: 6 membros, todos em times | **nenhuma** equipe derivada é criada |

O terceiro caso importa: equipe derivada vazia seria registro sem referente.

**A leitura que sustenta a decisão**: `eo.team` é "coletivo de pessoas que
desempenham papéis organizacionais em conjunto". Quando a organização não se
subdivide em times, o coletivo é a própria organização. A equipe padrão não
inventa um agrupamento — ela nomeia o agrupamento que já existe por omissão.

**As duas condições que a mantêm honesta**, e sem as quais ela vira dado falso:

1. **A equipe derivada nunca se apresenta como observada.** Ela não tem
   identificador na origem, porque não existe na origem. Sua proveniência declara
   `source_type: derivation`, e sua Application Reference é da derivação, não do
   GitHub — algo como `derived:default_team:<id externo da organização>`. Gravá-la
   como se viesse do GitHub afirmaria o que a fonte não afirma, que é o erro que a
   regra do vínculo com equipe existe para recusar.
2. **A contagem de equipes distingue observadas de derivadas.** "10 equipes" e
   "10 equipes, 1 derivada" respondem perguntas diferentes. Alguém que compare o
   número da plataforma com o do GitHub precisa entender a diferença sem
   investigar.

**O que a decisão substitui**: a evidência direta entre pessoa e organização
deixa de ser necessária. Com a equipe derivada acolhendo quem está de fora, todo
membro passa a estar em alguma equipe da organização, e o caminho
`pessoa → equipe → organização` fica completo.

Isso **simplifica** a feature: some uma tabela, some um caminho de escrita, e some
a possibilidade de os dois caminhos discordarem.

**O que a decisão custa**: a equipe derivada não existe na ferramenta de origem.
Ela precisa se declarar derivada em todo lugar onde aparece — na contagem, na
listagem e na proveniência. Sem isso, a plataforma passa a afirmar que existe um
time que não existe, e quem comparar com o GitHub encontrará uma diferença que
nada explica.

**Formalização**: regra de derivação declarada em
`rules/github_default_team.yaml`, no mesmo formato de
`github_team_membership_evidence` — o que materializa, o que **não** materializa,
com a razão, e as limitações.

### F5 — A transformação não gera chave estrangeira para associação

`derive_information_model.py` produz FK a partir de exatamente dois casos:

| Origem | Resultado |
|---|---|
| `part_whole` entre duas tabelas | FK na tabela da parte |
| relação cujo source é `relator` | FK na tabela do relator |

Uma `association` de subkind elevado para kind **não produz nada**. Declarar a
relação de F4 sem mexer na transformação não faz a coluna aparecer.

A regra que falta: *associação com destino em kind e cardinalidade `many → one`
vira chave estrangeira na tabela do kind de origem*. Quando a origem é subkind
elevado, a FK é **anulável**, e a obrigatoriedade passa a depender do
discriminador — `organization_id NOT NULL` apenas onde
`type = 'organizational_team'`, o que é `check_constraint`, não `NOT NULL`.

A mudança é no artefato `transformations/ontology_to_information_model.yaml` e no
script que o implementa.

### F6 — Mapeamentos declaram relação que a ontologia não tem

```yaml
# github/eo/team.yaml e github/eo/user.yaml
relations:
  organization:
    target_ontology: eo
    target_concept: eo.organization
```

Os dois declaram um vínculo com `eo.organization`. **Nenhum dos dois tem relação
correspondente em EO** — e o validador não percebe, porque só confere se o
*conceito* existe, não se a *relação* existe.

Validação que falta: *mapeamento que declara relação precisa apontar para relação
declarada na ontologia de destino*. Sem ela, um mapeamento pode prometer um
vínculo que nada materializa — que é precisamente o que aconteceu aqui.

### F7 — EO não tem nenhuma pergunta de competência

```text
priv/knowledge_base/ontology/seon/eo/
├── ontology.yaml
└── modules/organizational_structure.yaml
```

Não há `competency_questions/`. As CQ12, CQ14 e CQ16 que as regras de mapeamento
citam são **de SRO**, não de EO.

Consequência prática: não existe forma declarada de testar se EO responde ao que
deveria responder. As perguntas desta feature — "quais pessoas foram observadas
em uma organização", "a quais organizações uma conta está vinculada", "quais
equipes pertencem a uma organização" — não têm onde ser registradas como
critério.

A feature deveria criar `eo/competency_questions/eo_competency_questions.yaml`.
Sem isso, o `mix knowledge.test` não tem o que verificar em EO.

### F8 — `eo.project_team` também não declara vínculo com projeto

Mesma natureza de F2, do outro lado da hierarquia. **Fora de escopo**: a relação
teria destino em SPO, e a direção de dependência precisa ser conferida antes.
Registrado para não se perder.

---

## O que muda, e o que não muda

| Artefato | Mudança | Por quê |
|---|---|---|
| `eo/modules/organizational_structure.yaml` | **+1 relação** `organizational_team_belongs_to_organization` | F4 — torna explícito o que a definição já afirma |
| `eo/competency_questions/` | **novo arquivo** com as CQs de organização, pessoa e equipe | F7 — sem CQ, EO não é testável |
| `transformations/ontology_to_information_model.yaml` | **+1 regra** de associação para FK | F5 — sem ela a relação não vira coluna |
| `scripts/derive_information_model.py` | implementa a regra nova | F5 |
| `mappings/github/eo/team.yaml` | aponta para a relação agora existente; corrige o caminho de origem | F6 |
| `mappings/github/eo/user.yaml` | **remove** `relations.organization`; declara o vínculo como evidência | F3, F6 — a relação não existe e não deve existir |
| `rules/github_organization_membership_evidence.yaml` | **novo** | F3 — irmão da regra de vínculo com equipe |
| `validate_knowledge_base.py` | valida relação declarada em mapeamento | F6 |
| Migrações | remove as duas colunas de F1; recria `eo_teams.organization_id` **derivada**; cria a tabela de evidência | F1 |

**O que explicitamente não muda:**

- **nenhuma relação pessoa↔organização entra em EO** (F3);
- **nenhum conceito novo em EO.** A evidência não é conceito ontológico: é
  registro de observação, como já é a evidência de vínculo com equipe;
- **nenhuma outra ontologia é tocada.** A direção de dependência permanece
  intacta, e `mix knowledge.graph` deve continuar verde.

---

## Riscos semânticos

**R1 — Escolher `part_whole` por conveniência do gerador.** A transformação já
converte parthood em FK; declarar a relação de F4 como `part_whole` faria a coluna
aparecer sem tocar no script. Seria modelar de trás para frente: a equipe passaria
a ser *parte* da organização, apagando a distinção que separa
`eo.organizational_unit` — que é parte — de `eo.team` — que é coletivo. **A relação é associação, e a transformação
é que precisa mudar.**

**R2 — Confundir evidência com alocação.** O vínculo observado entre conta e
organização não é emprego, não é alocação e não é papel. Se em algum momento ele
aparecer numa consulta chamado de "membro da organização" sem qualificação, a
distinção terá sido perdida na camada de leitura — exatamente como o nível de
acesso na plataforma não pode aparecer como "cargo".

**R3 — Contagens que "não fecham" sendo tratadas como defeito.** Uma pessoa em
duas organizações conta uma vez no total e duas vezes por organização. A spec fixa
isso em FR-015 e SC-004 porque a reação natural a uma soma que não fecha é
consertá-la, e o conserto seria contar a mesma pessoa duas vezes.

**R4 — Remover colunas com dado dentro.** As colunas de F1 estão nulas em 100%
dos registros — conferido: 0 de 72 pessoas e 0 de 10 equipes preenchidas. Remover
é seguro **hoje**; o plano deve reconferir antes de migrar.

---

## Pendências que o plano precisa resolver

1. Como a transformação expressa "FK anulável cuja obrigatoriedade depende do
   discriminador" — `check_constraint` gerado, ou declarado à parte?
2. Se as CQs novas de EO exigem dado semeado para o `mix knowledge.test` rodar, e
   de onde ele vem.
3. Se a evidência de vínculo com organização e a de vínculo com equipe devem
   compartilhar estrutura, ou permanecer duas tabelas — são o mesmo padrão, e a
   terceira ocorrência é que justificaria abstrair (constituição, princípio VIII).
