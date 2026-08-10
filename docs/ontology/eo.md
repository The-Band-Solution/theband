<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# EO — Enterprise Ontology

> Trata de aspectos organizacionais: organizações, pessoas, equipes, papéis organizacionais e a alocação de pessoas a papéis em equipes.

| | |
|---|---|
| **Id** | `eo` |
| **Versão** | 1.0.0 |
| **Camada** | Core |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.eo` |
| **Depende de** | [ufo](ufo.md) |
| **Origem** | Tese, Seção 2.2.2.1 — EO, SPO e SysSwO (Figura 16) |

## Módulos

- **[Organizational Structure](#organizational-structure)** — Organizações, pessoas, equipes e papéis. O ponto central é que ser membro de equipe não é uma propriedade da pessoa: é um papel alocado por uma relação contextual (Team Membership).

---

## Organizational Structure

<a id="organizational-structure"></a>

Organizações, pessoas, equipes e papéis. O ponto central é que ser membro de equipe não é uma propriedade da pessoa: é um papel alocado por uma relação contextual (Team Membership).

*Fonte: Tese, Seção 2.2.2.1, Figura 16*

### Conceitos

#### `eo.organization` — Organization

*Organização*

Agente social que reconhece papéis organizacionais e emprega pessoas.

<sub>categoria UFO: `social_agent`</sub>

#### `eo.organizational_unit` — Organizational Unit

*Unidade Organizacional*

Agente social interno a uma organização, com responsabilidades próprias, que não constitui uma organização em si. Um departamento, uma diretoria, uma gerência. Diferentemente de uma organização, não existe fora daquela que o contém: extinta a organização, a unidade não sobrevive a ela.

<sub>categoria UFO: `social_agent`</sub>

Exemplos: *a diretoria de tecnologia de uma empresa*; *o departamento de qualidade*

#### `eo.organizational_part` — Organizational Part

*Parte Organizacional*

Papel assumido por uma organização ou por uma unidade organizacional quando é parte de uma organização maior. Não é um tipo de organização: é a posição ocupada numa estrutura.
Classifica indivíduos de dois kinds distintos — uma subsidiária é uma organização que é parte da matriz, enquanto um departamento é uma unidade organizacional que é parte da mesma organização. Por isso é não-sortal, e por isso é antirrígido: uma reestruturação desfaz a posição sem destruir a organização ou a unidade que a ocupava.

<sub>categoria UFO: `social_role` · papel de `ufo.agent`</sub>

Exemplos: *uma subsidiária, que é organização e parte da matriz*; *o departamento de qualidade, que é unidade organizacional e parte da organização*

#### `eo.person` — Person

*Pessoa*

Agente humano. É o conceito de identidade das pessoas em toda a rede: SRO, CIRO e CDRO referenciam pessoas apenas por meio de papéis.

<sub>categoria UFO: `agent`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `name` | string | sim |
| `email` | string | não |

#### `eo.organizational_role` — Organizational Role

*Papel Organizacional*

Papel social reconhecido pela organização, atribuído a agentes quando são contratados, incluídos em uma equipe, alocados ou participam de atividades.

<sub>categoria UFO: `social_role` · papel de `ufo.agent`</sub>

Exemplos: *gerente de projeto*; *designer*; *programador*

#### `eo.team` — Team

*Equipe*

Coletivo de pessoas que desempenham papéis organizacionais em conjunto.

<sub>categoria UFO: `collective`</sub>

#### `eo.organizational_team` — Organizational Team

*Equipe Organizacional*

Equipe ligada a uma organização, e não a um projeto específico.

<sub>categoria UFO: `collective` · especializa `eo.team`</sub>

Exemplos: *a equipe de marketing de uma organização de software*

#### `eo.project_team` — Project Team

*Equipe de Projeto*

Equipe ligada a um projeto.

<sub>categoria UFO: `collective` · especializa `eo.team`</sub>

Exemplos: *a equipe de desenvolvimento de um projeto*

#### `eo.team_member` — Team Member

*Membro de Equipe*

Pessoa ligada a uma equipe, desempenhando nela um papel organizacional.
É papel, não tipo. Em UFO, um papel é um sortal antirrígido que especializa o kind que lhe dá identidade: quem é membro de equipe é, antes de tudo, uma pessoa — e continua sendo a mesma pessoa ao deixar a equipe. Por isso a identidade fica em eo.person, e o vínculo com a equipe vive em eo.team_membership, que carrega equipe, papel e período.
A mesma pessoa pode ser membro de várias equipes ao mesmo tempo, com papéis diferentes em cada uma.

<sub>categoria UFO: `role` · papel de `eo.person`</sub>

#### `eo.team_membership` — Team Membership

*Alocação em Equipe*

Relação social que aloca um membro de equipe para desempenhar um papel organizacional em uma equipe. É o relator que conecta pessoa, papel e equipe — e o lugar onde vive a temporalidade da alocação.

<sub>categoria UFO: `relator` · papel de `eo.person`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `started_at` | datetime | não |
| `ended_at` | datetime | não |

Exemplos: *A alocação de John como programador na equipe de desenvolvimento do projeto X.*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `is part of` | `eo.organization` | `eo.organization` | many → zero_or_one | part_whole |
| `is part of` | `eo.organizational_unit` | `eo.organization` | many → one | part_whole |
| `belongs to` | `eo.organizational_team` | `eo.organization` | many → one | association |
| `recognizes` | `eo.organization` | `eo.organizational_role` | one → many | association |
| `allocates` | `eo.team_membership` | `eo.team_member` | one → one | association |
| `allocates to team` | `eo.team_membership` | `eo.team` | many → one | association |
| `to play` | `eo.team_membership` | `eo.organizational_role` | many → one | association |
| `is played by` | `eo.team_member` | `eo.person` | many → one | association |

- **`eo.organization_part_of_organization`** — Uma organização pode ser parte de outra — é o caso da subsidiária dentro do grupo. É relação de parthood, não de generalização: a subsidiária não é um tipo de matriz, é uma organização que ocupa posição na estrutura da matriz. Por ser contingente, admite início e fim.
- **`eo.organizational_unit_part_of_organization`** — Toda unidade organizacional é parte de exatamente uma organização, e não existe fora dela. A cardinalidade obrigatória no destino é o que a distingue de uma organização: uma organização pode não ser parte de nada.
- **`eo.organizational_team_belongs_to_organization`** — Uma equipe organizacional pertence a exatamente uma organização, e uma organização tem várias. A definição de eo.organizational_team já afirmava esse vínculo em prosa; declará-lo não inventa semântica, torna explícito o que o conceito diz de si.
Parte do subkind e não do kind: eo.project_team liga-se a um projeto — um conceito de SPO —, não a uma organização. Pôr a relação em eo.team obrigaria toda equipe de projeto a ter organização, o que é falso em projeto entre organizações.
É association e não part_whole. Uma equipe é coletivo de pessoas; a organização é agente social. "Pertence a" não é "é parte de", e a distinção entre eo.organizational_unit — que é parte — e eo.organizational_team é justamente essa. Declará-la como parthood faria o derivador gerar a chave estrangeira sem esforço, ao custo de apagar a distinção.


---

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quais equipes organizacionais pertencem a uma organização? | `eo.organization`, `eo.organizational_team` |
| `CQ02` | A quais organizações uma pessoa está vinculada? | `eo.person`, `eo.team_member`, `eo.team_membership`, `eo.organizational_team`, … |
| `CQ03` | Quais pessoas foram observadas em uma organização? | `eo.organization`, `eo.organizational_team`, `eo.team_membership`, `eo.team_member`, … |
| `CQ04` | Quais unidades organizacionais compõem uma organização? | `eo.organization`, `eo.organizational_unit` |
| `CQ05` | Quais papéis organizacionais uma organização reconhece? | `eo.organization`, `eo.organizational_role` |

- **CQ01** — É a pergunta mais direta que a relação acrescentada na feature 002 torna respondível. Antes dela a organização e suas equipes coexistiam na base sem vínculo declarado, e a resposta não existia — as colunas que a fingiam foram escritas à mão e ficaram nulas em 100% dos registros.
Vale para eo.organizational_team e não para eo.team: eo.project_team liga-se a um projeto, e uma equipe de projeto entre organizações não pertence a nenhuma delas.
- **CQ02** — **EO não define relação direta entre pessoa e organização, e esta pergunta não inventa uma.** O caminho passa pela equipe: a pessoa é membro de equipe por uma alocação, e a equipe organizacional pertence à organização.
A consequência é declarada e não é acidente: **pessoa que não está em equipe alguma não aparece em organização alguma.** Vínculo direto exigiria papel organizacional, que a ferramenta de origem não fornece — o mesmo motivo pelo qual a participação em equipe é tratada como evidência observada, e não como alocação.
É essa lacuna que a decisão da equipe derivada endereça: organização cujos membros não estão em equipe nenhuma recebe uma equipe com o nome dela, para que o caminho exista.
- **CQ03** — A inversa de eo.cq02, e não é redundante: percorre o mesmo caminho na direção em que a plataforma de fato consulta — a partir da organização observada.
Duas coisas que a resposta **não** afirma. Não afirma que a pessoa trabalha na organização: afirma que foi observada em uma equipe que pertence a ela. "Observada" é o limite do que a origem sustenta. E a mesma pessoa pode aparecer em mais de uma organização, porque a identidade é a conta e não o indivíduo — a soma das respostas por organização pode ser maior que o total de pessoas conhecidas, e isso está correto.
- **CQ04** — Existe para manter visível a distinção que a feature 002 quase apagou. Unidade organizacional é **parte** da organização; equipe organizacional **pertence** a ela. Duas perguntas separadas, dois tipos de relação, e ver as duas lado a lado é o que impede alguém de declarar a segunda como parthood para conveniência do derivador.
- **CQ05** — A pergunta que explica por que as outras param onde param. O papel organizacional é o que ligaria pessoa a organização sem passar por equipe, e a ferramenta de origem não o fornece: MAINTAINER e MEMBER são nível de acesso na plataforma, não cargo.
Hoje a resposta é vazia para toda organização observada, e vazia é a resposta certa — não zero, e não uma inferência a partir do nível de acesso.


---

[← Rede de ontologias](README.md)

