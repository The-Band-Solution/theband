<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# EO — Enterprise Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **37 of 42** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Trata de aspectos organizacionais: organizações, pessoas, equipes, papéis organizacionais e a alocação de pessoas a papéis em equipes.

| | |
|---|---|
| **Id** | `eo` |
| **Version** | 1.0.0 |
| **Layer** | Core |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.eo` |
| **Depends on** | [ufo](ufo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.1 — EO, SPO e SysSwO (Figura 16) |

## Modules

- **[Organizational Structure](#organizational-structure)** — `pt-BR` Organizações, pessoas, equipes e papéis. O ponto central é que ser membro de equipe não é uma propriedade da pessoa: é um papel alocado por uma relação contextual (Team Membership).
- **[Role Grants](#role-grants)** — `pt-BR` O que um papel organizacional **permite** na plataforma: ver o painel de trabalho de quem, e gerir a estrutura de qual equipe.
Não é conceito da EO de referência. É a **declaração adjacente** — o mesmo lugar ontológico que `spo.activity_start_criterion` ocupa para o instante de início: a rede não responde quem pode o quê nesta plataforma, e inventar a resposta dentro da ontologia seria pôr decisão de produto na camada que descreve o mundo.
A concessão é **por papel**, e nunca inferida do nome dele. `Tech Leader` parece liderança e `Coordenador` também; a mesma organização pode ter um `Tech Lead` que é senioridade técnica e não chefia ninguém. O erro por padrão de nome é caro nas duas direções, e mais caro na da gestão: excesso de visibilidade concedido ninguém reclama; excesso de gestão concedido reescreve a estrutura de quem não deveria.
Toda concessão tem autor, data e revogação **por marca** — revogar nunca apaga a linha, porque quem concedeu, quando, e até quando, é a pergunta que mais se faz depois.

---

## Organizational Structure

<a id="organizational-structure"></a>

`pt-BR` Organizações, pessoas, equipes e papéis. O ponto central é que ser membro de equipe não é uma propriedade da pessoa: é um papel alocado por uma relação contextual (Team Membership).

*Source: `pt-BR` Tese, Seção 2.2.2.1, Figura 16*

### Concepts

#### `eo.organization` — Organization

*pt-BR: Organização*

`pt-BR` Agente social que reconhece papéis organizacionais e emprega pessoas.

<sub>UFO category: `social_agent`</sub>

#### `eo.organizational_unit` — Organizational Unit

*pt-BR: Unidade Organizacional*

`pt-BR` Agente social interno a uma organização, com responsabilidades próprias, que não constitui uma organização em si. Um departamento, uma diretoria, uma gerência. Diferentemente de uma organização, não existe fora daquela que o contém: extinta a organização, a unidade não sobrevive a ela.

<sub>UFO category: `social_agent`</sub>

Examples: `pt-BR` *a diretoria de tecnologia de uma empresa*; *o departamento de qualidade*

#### `eo.organizational_part` — Organizational Part

*pt-BR: Parte Organizacional*

`pt-BR` Papel assumido por uma organização ou por uma unidade organizacional quando é parte de uma organização maior. Não é um tipo de organização: é a posição ocupada numa estrutura.
Classifica indivíduos de dois kinds distintos — uma subsidiária é uma organização que é parte da matriz, enquanto um departamento é uma unidade organizacional que é parte da mesma organização. Por isso é não-sortal, e por isso é antirrígido: uma reestruturação desfaz a posição sem destruir a organização ou a unidade que a ocupava.

<sub>UFO category: `social_role` · role of `ufo.agent`</sub>

Examples: `pt-BR` *uma subsidiária, que é organização e parte da matriz*; *o departamento de qualidade, que é unidade organizacional e parte da organização*

#### `eo.person` — Person

*pt-BR: Pessoa*

`pt-BR` Agente humano. É o conceito de identidade das pessoas em toda a rede: SRO, CIRO e CDRO referenciam pessoas apenas por meio de papéis.

<sub>UFO category: `agent`</sub>

| Attribute | Type | Required |
|---|---|---|
| `name` | string | yes |
| `email` | string | no |

#### `eo.organizational_role` — Organizational Role

*pt-BR: Papel Organizacional*

`pt-BR` Papel social reconhecido pela organização, atribuído a agentes quando são contratados, incluídos em uma equipe, alocados ou participam de atividades.

<sub>UFO category: `social_role` · role of `ufo.agent`</sub>

Examples: `pt-BR` *gerente de projeto*; *designer*; *programador*

#### `eo.team` — Team

*pt-BR: Equipe*

`pt-BR` Coletivo de pessoas que desempenham papéis organizacionais em conjunto.

<sub>UFO category: `collective`</sub>

#### `eo.organizational_team` — Organizational Team

*pt-BR: Equipe Organizacional*

`pt-BR` Equipe ligada a uma organização, e não a um projeto específico.

<sub>UFO category: `collective` · specializes `eo.team`</sub>

Examples: `pt-BR` *a equipe de marketing de uma organização de software*

#### `eo.project_team` — Project Team

*pt-BR: Equipe de Projeto*

`pt-BR` Equipe ligada a um projeto.

<sub>UFO category: `collective` · specializes `eo.team`</sub>

Examples: `pt-BR` *a equipe de desenvolvimento de um projeto*

#### `eo.team_member` — Team Member

*pt-BR: Membro de Equipe*

`pt-BR` Pessoa ligada a uma equipe, desempenhando nela um papel organizacional.
É papel, não tipo. Em UFO, um papel é um sortal antirrígido que especializa o kind que lhe dá identidade: quem é membro de equipe é, antes de tudo, uma pessoa — e continua sendo a mesma pessoa ao deixar a equipe. Por isso a identidade fica em eo.person, e o vínculo com a equipe vive em eo.team_membership, que carrega equipe, papel e período.
A mesma pessoa pode ser membro de várias equipes ao mesmo tempo, com papéis diferentes em cada uma.

<sub>UFO category: `role` · role of `eo.person`</sub>

#### `eo.team_membership` — Team Membership

*pt-BR: Alocação em Equipe*

`pt-BR` Relação social que aloca um membro de equipe para desempenhar um papel organizacional em uma equipe. É o relator que conecta pessoa, papel e equipe — e o lugar onde vive a temporalidade da alocação.

<sub>UFO category: `relator` · role of `eo.person`</sub>

| Attribute | Type | Required |
|---|---|---|
| `started_at` | datetime | no |
| `ended_at` | datetime | no |

Examples: `pt-BR` *A alocação de John como programador na equipe de desenvolvimento do projeto X.*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `is part of` | `eo.organization` | `eo.organization` | many → zero_or_one | part_whole |
| `is part of` | `eo.team` | `eo.team` | many → many | part_whole |
| `is part of` | `eo.organizational_unit` | `eo.organization` | many → one | part_whole |
| `belongs to` | `eo.organizational_team` | `eo.organization` | many → one | association |
| `recognizes` | `eo.organization` | `eo.organizational_role` | one → many | association |
| `allocates` | `eo.team_membership` | `eo.team_member` | one → one | association |
| `allocates to team` | `eo.team_membership` | `eo.team` | many → one | association |
| `to play` | `eo.team_membership` | `eo.organizational_role` | many → one | association |
| `is played by` | `eo.team_member` | `eo.person` | many → one | association |

- **`eo.organization_part_of_organization`** — `pt-BR` Uma organização pode ser parte de outra — é o caso da subsidiária dentro do grupo. É relação de parthood, não de generalização: a subsidiária não é um tipo de matriz, é uma organização que ocupa posição na estrutura da matriz. Por ser contingente, admite início e fim.
- **`eo.team_part_of_team`** — `pt-BR` Uma equipe pode ser parte de outra — é o caso da célula dentro do departamento, ou do time dentro da frente. Mesma forma que eo.organization_part_of_organization: é parthood entre coletivos, não generalização, e por ser contingente admite início e fim.
A cardinalidade é muitos para muitos porque a estrutura real não é árvore: a mesma equipe pode compor mais de uma frente ao mesmo tempo, e limitar a um todo forçaria a organização a escolher qual das verdades registrar.
A relação é ACÍCLICA por restrição, e não por construção: nada no modelo impede declarar A parte de B e B parte de A, e um ciclo faria qualquer agregação pela hierarquia não terminar. A recusa é da aplicação.
O período é da RELAÇÃO, não das equipes: uma equipe que deixou de ser parte de outra continua existindo com o histórico dela intacto — a composição terminou, a equipe não.
- **`eo.organizational_unit_part_of_organization`** — `pt-BR` Toda unidade organizacional é parte de exatamente uma organização, e não existe fora dela. A cardinalidade obrigatória no destino é o que a distingue de uma organização: uma organização pode não ser parte de nada.
- **`eo.organizational_team_belongs_to_organization`** — `pt-BR` Uma equipe organizacional pertence a exatamente uma organização, e uma organização tem várias. A definição de eo.organizational_team já afirmava esse vínculo em prosa; declará-lo não inventa semântica, torna explícito o que o conceito diz de si.
Parte do subkind e não do kind: eo.project_team liga-se a um projeto — um conceito de SPO —, não a uma organização. Pôr a relação em eo.team obrigaria toda equipe de projeto a ter organização, o que é falso em projeto entre organizações.
É association e não part_whole. Uma equipe é coletivo de pessoas; a organização é agente social. "Pertence a" não é "é parte de", e a distinção entre eo.organizational_unit — que é parte — e eo.organizational_team é justamente essa. Declará-la como parthood faria o derivador gerar a chave estrangeira sem esforço, ao custo de apagar a distinção.


---

## Role Grants

<a id="role-grants"></a>

`pt-BR` O que um papel organizacional **permite** na plataforma: ver o painel de trabalho de quem, e gerir a estrutura de qual equipe.
Não é conceito da EO de referência. É a **declaração adjacente** — o mesmo lugar ontológico que `spo.activity_start_criterion` ocupa para o instante de início: a rede não responde quem pode o quê nesta plataforma, e inventar a resposta dentro da ontologia seria pôr decisão de produto na camada que descreve o mundo.
A concessão é **por papel**, e nunca inferida do nome dele. `Tech Leader` parece liderança e `Coordenador` também; a mesma organização pode ter um `Tech Lead` que é senioridade técnica e não chefia ninguém. O erro por padrão de nome é caro nas duas direções, e mais caro na da gestão: excesso de visibilidade concedido ninguém reclama; excesso de gestão concedido reescreve a estrutura de quem não deveria.
Toda concessão tem autor, data e revogação **por marca** — revogar nunca apaga a linha, porque quem concedeu, quando, e até quando, é a pergunta que mais se faz depois.

*Source: `pt-BR` Issue #369 (concessão de visibilidade, 2026-08-26); spec 045 FR-022 (ver e mexer são decisões separadas); spec 060 FR-080 a FR-082 (concessão de gestão, decisão da pessoa mantenedora em 2026-09-07)*

### Concepts

#### `eo.role_visibility_grant` — Role Visibility Grant

*pt-BR: Concessão de visibilidade por papel*

`pt-BR` Declaração de que quem desempenha um papel organizacional, **com vínculo vigente**, alcança o painel de trabalho das pessoas da sua equipe (alcance `team`) ou da sua organização (alcance `organization`).
O alcance é o que a declaração diz, e não um booleano: `is_leader` perderia quem concedeu, quando, e até onde — e numa decisão de visibilidade essas três são as perguntas seguintes.

<sub>UFO category: `normative_description`</sub>

| Attribute | Type | Required |
|---|---|---|
| `scope` | enum | yes |
| `declared_at` | datetime | yes |
| `revoked_at` | datetime | no |

Examples: `pt-BR` *quem é Scrum Master vê o painel de quem está nas equipes em que ele é Scrum Master*; *quem é Diretor de Tecnologia vê o painel de toda a organização*

#### `eo.role_structure_management_grant` — Role Structure Management Grant

*pt-BR: Concessão de gestão da estrutura por papel*

`pt-BR` Declaração de que quem desempenha um papel organizacional, **com vínculo vigente**, pode declarar a estrutura de uma equipe — o papel de cada pessoa, a saída, o equívoco, a composição de subequipes, os papéis da organização e a ligação a projeto — nas equipes em que tem o papel (alcance `team`) ou em todas as da organização (alcance `organization`).
**Ver e mexer são decisões separadas** (spec 045, FR-022): a concessão de visibilidade não confere gestão, e a de gestão não confere visibilidade. Quem precisa das duas recebe as duas, e o registro diz qual é qual.

<sub>UFO category: `normative_description`</sub>

| Attribute | Type | Required |
|---|---|---|
| `scope` | enum | yes |
| `declared_at` | datetime | yes |
| `revoked_at` | datetime | no |

Examples: `pt-BR` *quem é Scrum Master declara o papel e a saída de quem está na sua equipe*; *quem é Gerente de Engenharia gere a estrutura de todas as equipes da organização*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `granted to` | `eo.role_visibility_grant` | `eo.organizational_role` | many → one | association |
| `granted to` | `eo.role_structure_management_grant` | `eo.organizational_role` | many → one | association |



---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | Which organizational teams belong to an organization? | `eo.organization`, `eo.organizational_team` |
| `CQ02` | Which organizations is a person linked to? | `eo.person`, `eo.team_member`, `eo.team_membership`, `eo.organizational_team`, … |
| `CQ03` | Which people were observed in an organization? | `eo.organization`, `eo.organizational_team`, `eo.team_membership`, `eo.team_member`, … |
| `CQ04` | Which organizational units are part of an organization? | `eo.organization`, `eo.organizational_unit` |
| `CQ05` | Which organizational roles does an organization recognize? | `eo.organization`, `eo.organizational_role` |

- **CQ01** — `pt-BR` É a pergunta mais direta que a relação acrescentada na feature 002 torna respondível. Antes dela a organização e suas equipes coexistiam na base sem vínculo declarado, e a resposta não existia — as colunas que a fingiam foram escritas à mão e ficaram nulas em 100% dos registros.
Vale para eo.organizational_team e não para eo.team: eo.project_team liga-se a um projeto, e uma equipe de projeto entre organizações não pertence a nenhuma delas.
- **CQ02** — `pt-BR` **EO não define relação direta entre pessoa e organização, e esta pergunta não inventa uma.** O caminho passa pela equipe: a pessoa é membro de equipe por uma alocação, e a equipe organizacional pertence à organização.
A consequência é declarada e não é acidente: **pessoa que não está em equipe alguma não aparece em organização alguma.** Vínculo direto exigiria papel organizacional, que a ferramenta de origem não fornece — o mesmo motivo pelo qual a participação em equipe é tratada como evidência observada, e não como alocação.
É essa lacuna que a decisão da equipe derivada endereça: organização cujos membros não estão em equipe nenhuma recebe uma equipe com o nome dela, para que o caminho exista.
- **CQ03** — `pt-BR` A inversa de eo.cq02, e não é redundante: percorre o mesmo caminho na direção em que a plataforma de fato consulta — a partir da organização observada.
Duas coisas que a resposta **não** afirma. Não afirma que a pessoa trabalha na organização: afirma que foi observada em uma equipe que pertence a ela. "Observada" é o limite do que a origem sustenta. E a mesma pessoa pode aparecer em mais de uma organização, porque a identidade é a conta e não o indivíduo — a soma das respostas por organização pode ser maior que o total de pessoas conhecidas, e isso está correto.
- **CQ04** — `pt-BR` Existe para manter visível a distinção que a feature 002 quase apagou. Unidade organizacional é **parte** da organização; equipe organizacional **pertence** a ela. Duas perguntas separadas, dois tipos de relação, e ver as duas lado a lado é o que impede alguém de declarar a segunda como parthood para conveniência do derivador.
- **CQ05** — `pt-BR` A pergunta que explica por que as outras param onde param. O papel organizacional é o que ligaria pessoa a organização sem passar por equipe, e a ferramenta de origem não o fornece: MAINTAINER e MEMBER são nível de acesso na plataforma, não cargo.
Hoje a resposta é vazia para toda organização observada, e vazia é a resposta certa — não zero, e não uma inferência a partir do nível de acesso.


---

[← Ontology network](README.md)

