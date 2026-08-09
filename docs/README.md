# Documentação — The Band

The Band é uma plataforma de **integração semântica de dados de Engenharia de Software**.
Coleta dados das ferramentas usadas ao longo do desenvolvimento, harmoniza esses dados
contra ontologias de referência, preserva proveniência e responde necessidades de
informação com dados rastreáveis e explicáveis.

Base científica: tese de doutorado de Paulo Sérgio dos Santos Júnior (UFES, 2023),
*From Continuous Software Engineering Reference Ontologies to the Integration of Data
for Data-Driven Software Development*.

---

## Por onde começar

| Se você quer… | Vá para |
|---|---|
| Entender o que o sistema é e como está organizado | [Arquitetura](architecture/overview.md) |
| Entender o modelo conceitual | [Rede de ontologias](ontology/README.md) |
| Achar um conceito específico | [Índice de conceitos](ontology/concept-index.md) |
| Saber como dados externos viram conceitos | [Mapeamentos semânticos](integrations/mappings.md) |
| Entender de onde vem um número | [Necessidades de informação e medidas](metrics/README.md) |
| Saber por que uma decisão foi tomada | [ADRs](adr/README.md) |
| Saber o que construir e em que ordem | [Backlog de CRUD](backlog/crud-entities.md) |
| Começar pela integração com GitHub | [Backlog GitHub → SRO](backlog/github-to-sro.md) |
| Contribuir com código | [AGENTS.md](../AGENTS.md) na raiz |

---

## Mapa da documentação

```text
docs/
├── architecture/     visão da arquitetura e das fronteiras internas
├── ontology/         modelo conceitual — GERADO da base de conhecimento
├── integrations/     fontes externas e mapeamentos — GERADO
├── metrics/          necessidades de informação e medidas — GERADO
├── processes/        processo de trabalho por feature
├── backlog/          o que construir e em que ordem
└── adr/              decisões arquiteturais registradas
```

### Páginas geradas

`docs/ontology/`, `docs/integrations/mappings.md` e `docs/metrics/README.md` são
**derivados de `priv/knowledge_base/`** e não devem ser editados à mão — a edição
faria a documentação divergir do modelo que o sistema realmente carrega.

Para regenerá-las depois de alterar a base:

```bash
python3 scripts/validate_knowledge_base.py   # a base precisa estar válida antes
python3 scripts/generate_docs.py
```

Quando o projeto Elixir existir, esses scripts serão substituídos pelas Mix tasks
`mix knowledge.validate` e `mix knowledge.docs`, com o mesmo contrato.

---

## Estado atual

| Área | Estado |
|---|---|
| Base de conhecimento (UFO + SEON + Continuum) | 12 ontologias, 219 conceitos, 141 relações, 64 perguntas de competência |
| Mapeamentos semânticos | GitHub: 13 mapeamentos (4 derivados por tipo de issue), status *proposed* |
| Necessidades de informação e medidas | 3 e 3, como exemplos de referência |
| Aplicação Phoenix | não iniciada — feature `001 Fundação Phoenix e governança` |
| Conectores executáveis | não iniciados — feature `025 Motor declarativo GraphQL/YAML` |

O roadmap completo está em [AGENTS.md](../AGENTS.md), seção 19.
