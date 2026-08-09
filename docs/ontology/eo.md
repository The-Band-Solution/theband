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

Parte de uma organização com responsabilidades próprias.

<sub>categoria UFO: `social_agent` · especializa `eo.organization`</sub>

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

<sub>categoria UFO: `social_role`</sub>

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

Pessoa que desempenha um papel organizacional em uma equipe específica. É papel, não tipo: a mesma pessoa pode ser membro de várias equipes, com papéis diferentes, em períodos diferentes.

<sub>categoria UFO: `role` · papel de `eo.person`</sub>

#### `eo.team_membership` — Team Membership

*Alocação em Equipe*

Relação social que aloca um membro de equipe para desempenhar um papel organizacional em uma equipe. É o relator que conecta pessoa, papel e equipe — e o lugar onde vive a temporalidade da alocação.

<sub>categoria UFO: `relator`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `started_at` | datetime | não |
| `ended_at` | datetime | não |

Exemplos: *A alocação de John como programador na equipe de desenvolvimento do projeto X.*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `recognizes` | `eo.organization` | `eo.organizational_role` | one → many | association |
| `allocates` | `eo.team_membership` | `eo.team_member` | one → one | association |
| `allocates to team` | `eo.team_membership` | `eo.team` | many → one | association |
| `to play` | `eo.team_membership` | `eo.organizational_role` | many → one | association |
| `is played by` | `eo.team_member` | `eo.person` | many → one | association |



---

[← Rede de ontologias](README.md)

