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

#### `eo.sector` — Sector

*Setor*

Agente social interno a uma organização, com responsabilidades próprias, que não constitui uma organização em si. Um departamento, uma diretoria, uma gerência. Diferentemente de uma organização, não existe fora daquela que o contém: extinta a organização, o setor não sobrevive a ela.

<sub>categoria UFO: `social_agent`</sub>

Exemplos: *a diretoria de tecnologia de uma empresa*; *o departamento de qualidade*

#### `eo.organizational_unit` — Organizational Unit

*Unidade Organizacional*

Papel assumido por uma organização ou por um setor quando é parte de uma organização maior. Não é um tipo de organização: é a posição ocupada numa estrutura.
Classifica indivíduos de dois kinds distintos — uma subsidiária é uma organização que é unidade da matriz, enquanto um departamento é um setor que é unidade da mesma organização. Por isso é não-sortal, e por isso é antirrígido: uma reestruturação desfaz a unidade sem destruir a organização ou o setor que a ocupava.

<sub>categoria UFO: `social_role` · papel de `ufo.agent`</sub>

Exemplos: *uma subsidiária, que é organização e unidade da matriz*; *o departamento de qualidade, que é setor e unidade da organização*

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
| `is part of` | `eo.sector` | `eo.organization` | many → one | part_whole |
| `recognizes` | `eo.organization` | `eo.organizational_role` | one → many | association |
| `allocates` | `eo.team_membership` | `eo.team_member` | one → one | association |
| `allocates to team` | `eo.team_membership` | `eo.team` | many → one | association |
| `to play` | `eo.team_membership` | `eo.organizational_role` | many → one | association |
| `is played by` | `eo.team_member` | `eo.person` | many → one | association |

- **`eo.organization_part_of_organization`** — Uma organização pode ser parte de outra — é o caso da subsidiária dentro do grupo. É relação de parthood, não de generalização: a subsidiária não é um tipo de matriz, é uma organização que ocupa posição na estrutura da matriz. Por ser contingente, admite início e fim.
- **`eo.sector_part_of_organization`** — Todo setor é parte de exatamente uma organização, e não existe fora dela. A cardinalidade obrigatória no destino é o que distingue setor de organização: uma organização pode não ser parte de nada.


---

[← Rede de ontologias](README.md)

