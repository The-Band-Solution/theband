# Base de conhecimento — The Band

Esta pasta é a **base de conhecimento declarativa** do The Band. Não é configuração:
é artefato de domínio, versionado, validado no CI e revisado como código.

## Origem

Todo o conteúdo deriva da tese de doutorado de Paulo Sérgio dos Santos Júnior
(UFES, 2023), *From Continuous Software Engineering Reference Ontologies to the
Integration of Data for Data-Driven Software Development*, que propõe a
(sub)rede ontológica **Continuum** integrada à **SEON**, ambas fundamentadas na **UFO**.

Cada arquivo declara `provenance` apontando para a seção da tese que o originou.

---

## O que cada pasta significa

```text
priv/knowledge_base/
├── manifest.yaml
├── schemas/
├── ontology/
│   ├── ufo/
│   ├── seon/
│   └── continuum/
├── mappings/
├── competency_questions/
├── information_needs/
├── measurements/
├── rules/
├── glossary/
├── examples/
└── sources/
```

### `manifest.yaml`

Inventário raiz da base. Declara quais ontologias existem, em que camada
(fundacional / core / domínio) e em que rede (SEON / Continuum) cada uma vive,
onde seus arquivos estão, e quais políticas de validação valem para todos os
YAMLs (modo estrito, rejeição de campos desconhecidos, proibição de ciclos,
obrigatoriedade de proveniência). É o primeiro arquivo que `mix knowledge.compile`
lê — nada é carregado sem estar registrado aqui.

### `schemas/`

**Contratos de forma dos YAMLs.** Um schema por tipo de artefato: ontologia,
módulo, pergunta de competência, mapeamento, necessidade de informação, medida.
`mix knowledge.validate` valida cada arquivo da base contra o schema
correspondente e falha o CI se um campo obrigatório sumir, um tipo mudar ou um
campo desconhecido aparecer. Sem schema, um YAML não pode entrar na base.

### `ontology/`

**O modelo conceitual — o coração da base.** Aqui vivem os conceitos, suas
definições, especializações, relações, cardinalidades e restrições. É a fonte da
verdade semântica: o domínio Elixir em `lib/the_band/ontology/` espelha esta
árvore, e nenhum conceito existe no código sem existir aqui primeiro.

Cada ontologia tem:

| Arquivo | Significado |
|---|---|
| `ontology.yaml` | Metadados: id, nome, versão, camada, rede, **dependências** e lista de módulos |
| `modules/<modulo>.yaml` | Conceitos e relações de uma subontologia/módulo |
| `competency_questions/*.yaml` | Perguntas que a ontologia deve conseguir responder |

Subpastas:

- **`ontology/ufo/`** — *Unified Foundational Ontology*. Camada fundacional.
  Não descreve Engenharia de Software; fornece as **categorias** com que todo o
  resto é classificado: objeto, evento, agente, papel, relator, disposição,
  situação, coletivo. Quando um conceito de SEON ou Continuum declara
  `classification.ufo_category`, ele aponta para cá. É o que impede o modelo de
  confundir um evento com um objeto ou um papel com um tipo.

- **`ontology/seon/`** — *Software Engineering Ontology Network*. Camada core e
  de domínio da Engenharia de Software. Uma pasta por ontologia:

  | Pasta | Ontologia | Do que trata |
  |---|---|---|
  | `eo/` | Enterprise Ontology | organização, pessoa, equipe, papel organizacional, alocação (team membership) |
  | `spo/` | Software Process Ontology | projeto, processo e atividade **planejados vs. executados**, artefatos, recursos, participação |
  | `sys_swo/` | System and Software Ontology | produto de software, item de software, sistema, programa, código, cópia carregada, hardware |
  | `rsro/` | Reference Software Requirements Ontology | requisito funcional e não funcional, artefato e documento de requisitos |
  | `cmpo/` | Configuration Management Process Ontology | repositório, branch, commit, checkout, check-in, conflito, change request, baseline |
  | `roost/` | Reference Ontology on Software Testing | caso de teste, código de teste, execução de teste, resultado, ambiente de teste |
  | `qapo/` | Quality Assurance Process Ontology | avaliação de aderência, critério de qualidade, relatório, não conformidade |
  | `osdef/` | Ontology on Software Defects, Errors and Failures | defect, fault (runtime defect), failure, vulnerabilidade, estados vulnerável e de falha |

- **`ontology/continuum/`** — Subrede de **Continuous Software Engineering**,
  desenvolvida na tese e integrada à SEON. Descreve o que **de fato ocorreu** nos
  projetos (por isso seus verbos de relação estão no passado):

  | Pasta | Ontologia | Do que trata |
  |---|---|---|
  | `sro/` | Scrum Reference Ontology | processo Scrum, cerimônias, papéis e times, product/sprint backlog, user stories, entregáveis aceitos e não aceitos |
  | `ciro/` | Continuous Integration Reference Ontology | processo de CI, continuous build, continuous test, continuous inspection, servidor e ambientes de CI |
  | `cdro/` | Continuous Deployment Reference Ontology | atividade de entrega contínua, processo de implantação contínua, código entregue e implantado, ambientes |

### `mappings/`

**A ponte entre o mundo externo e o modelo conceitual.** Um arquivo por
(fonte, entidade, conceito-alvo): como um Pull Request do GitHub vira um
`cmpo.change_request`, quais campos correspondem a quais atributos, qual a chave
natural, e — obrigatoriamente — **qual o grau de equivalência (`total`/`partial`),
a justificativa semântica e as limitações**. É aqui que se registra que um Pull
Request *não* é um merge. Sem mapeamento declarado, nenhum dado externo entra no
domínio.

Organização: `mappings/<provider>/<ontologia_alvo>/<entidade>.yaml`.

### `competency_questions/`

**Perguntas que a ontologia precisa saber responder** — no sentido de SABiO, são
os requisitos funcionais da ontologia. Ex.: *"Quais user stories foram definidas
no product backlog?"*. Cada pergunta lista os conceitos e relações necessários
para respondê-la, o que permite `mix knowledge.test` verificar que o modelo (e o
banco) realmente conseguem respondê-la. Uma pergunta que não passa é um buraco no
modelo, não um bug de query.

Esta pasta guarda perguntas transversais (que cruzam mais de uma ontologia); as
perguntas próprias de cada ontologia ficam dentro dela, em
`ontology/<rede>/<ontologia>/competency_questions/`.

### `information_needs/`

**Necessidades de informação dos stakeholders** — a pergunta de negócio que
justifica existir uma métrica. Ex.: *"Quanto tempo um Pull Request aguarda até a
primeira revisão?"*, com stakeholders, decisão apoiada, conceitos e relações
requeridos, e medidas candidatas. **Nenhuma medida e nenhum dashboard podem
existir sem uma entrada aqui.** É esta pasta que impede o produto de virar um
painel de números sem dono.

### `measurements/`

**Medidas e indicadores derivados.** Cada arquivo declara qual necessidade de
informação a medida responde, a fórmula, os insumos, a unidade, o tipo de valor,
os níveis de análise (PR, repositório, projeto, equipe), as **limitações** e as
**interpretações incorretas possíveis**. É o que permite responder "como este
número foi calculado?" sem abrir código.

### `rules/`

**Regras e axiomas que os diagramas não capturam.** Restrições de integridade
conceitual e regras de transformação — por exemplo, o axioma da tese de que toda
*Performed Scrum Development Task* executada em um sprint precisa estar ligada a
uma *User Story* do sprint backlog daquele sprint. Viram testes conceituais e,
quando cabível, constraints de banco.

### `glossary/`

**Termos e sinônimos**, em pt-BR e en, ligados aos conceitos formais. Serve à
comunicação com stakeholders, à documentação e à desambiguação de vocabulário das
ferramentas externas ("issue", "task", "card", "work item" não são a mesma coisa).

### `examples/`

**Instâncias de exemplo** dos conceitos — inclusive as instanciações reais usadas
na validação da tese. Servem de fixture para testes, de material de onboarding e
de prova de que o conceito representa situação do mundo real.

### `sources/`

**Catálogo das fontes externas** de dados: GitHub, GitLab, Azure DevOps, Jira,
Sonar. Descreve cada provedor, suas APIs, versões de schema, capacidades e
limites (rate limit, paginação). É metadado da fonte — as **queries e definições
executáveis** dos conectores ficam em `priv/connectors/<provider>/`.

---

## Por que um arquivo por módulo, e não por conceito

Um conceito por arquivo geraria ~200 arquivos e tornaria a revisão de uma mudança
semântica ilegível: conceito e relações apareceriam em diffs separados.
Agrupamos por **módulo/subontologia**, mesma granularidade dos módulos Elixir em
`lib/the_band/ontology/`. Um diff mostra a mudança conceitual inteira em um lugar só.

## Regra de dependência

Do mais específico para o mais geral. Permitido:

```text
SRO  → EO, SPO, SysSwO, RSRO
CIRO → SPO, SysSwO, CMPO, ROoST, QAPO, OSDEF
CDRO → SPO, SysSwO, CIRO
```

Proibido: `EO → SRO`, `SPO → CIRO`, `SysSwO → CDRO`. Verificado por `mix knowledge.graph`.

Conceito que já existe em ontologia mais geral é **reutilizado**, nunca duplicado.
`Person` mora em EO; SRO, CIRO e CDRO apenas a referenciam em papéis contextuais.

## Validação

```bash
mix knowledge.validate   # YAMLs contra os schemas
mix knowledge.compile    # YAML → estruturas Elixir
mix knowledge.graph      # dependências e ciclos
mix knowledge.test       # perguntas de competência e regras
mix knowledge.diff       # diff semântico entre versões
```

Nenhum YAML pode conter token, senha ou credencial.
