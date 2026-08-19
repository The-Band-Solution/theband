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
| Entender as tabelas e os schemas, e por que têm essa forma | [Modelo de dados](architecture/modelo-de-dados.md) |
| Colocar a aplicação em execução, e configurar o ambiente | [Deployment](deployment.md) |
| Entender o modelo conceitual | [Rede de ontologias](ontology/README.md) |
| Achar um conceito específico | [Índice de conceitos](ontology/concept-index.md) |
| Saber como dados externos viram conceitos | [Mapeamentos semânticos](integrations/mappings.md) |
| Entender de onde vem um número | [Necessidades de informação e medidas](metrics/README.md) |
| Saber por que uma decisão foi tomada | [ADRs](adr/README.md) |
| Ver o que ainda não foi decidido | [RFCs](rfc/README.md) |
| Entender as extensões ao método de transformação | [Pesquisa](research/extensions-to-one-table-per-kind.md) |
| Saber o que construir e em que ordem | [Backlog](backlog/README.md) |
| Começar pela integração com GitHub | [Backlog GitHub → SRO](backlog/github-to-sro.md) |
| Entender como o CI coletado vira conceito | [Verificação contínua](integrations/verificacao-continua.md) |
| Ler o que os sprints ensinaram | [Lições aprendidas](sprints/licoes-aprendidas.md) |
| Contribuir com código | [AGENTS.md](../AGENTS.md) na raiz |
| Abrir ou fechar um sprint | [skill sprint-backlog](../.claude/skills/sprint-backlog/SKILL.md) |

---

## Mapa da documentação

```text
docs/
├── architecture/     visão da arquitetura, fronteiras internas e modelo de dados
├── ontology/         modelo conceitual — GERADO da base de conhecimento
├── integrations/     fontes externas e mapeamentos — GERADO
├── metrics/          necessidades de informação e medidas — GERADO
├── processes/        processo de trabalho por feature
├── sprints/          backlogs, reviews e o registro acumulado de lições
├── backlog/          o que construir e em que ordem
├── rfc/              propostas abertas a comentário
├── research/         extensões ao método, com vistas a publicação
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

As Mix tasks equivalentes já existem, e são o que os gates chamam — `mix knowledge.validate`
e `mix knowledge.graph`. Os scripts continuam servindo para uso pontual fora do projeto
Elixir.

**Regenerar não é opcional.** Alterar a base sem regenerar deixa a documentação afirmando
um modelo que o sistema não carrega mais — e foi o que aconteceu por nove features: a
página dizia 12 ontologias quando a base já tinha 13.

---

## Estado atual

| Área | Estado |
|---|---|
| Base de conhecimento (UFO + SEON + Continuum) | 13 ontologias, 230 conceitos, 167 relações, 73 perguntas de competência |
| Mapeamentos semânticos | GitHub: 22 mapeamentos (4 derivados por tipo de issue), status *proposed* |
| Necessidades de informação e medidas | 6 e 5 |
| Aplicação Phoenix | em produção interna — multitenant, 23 rotas LiveView, 116 arquivos de teste |
| Conectores executáveis | GitHub, declarativo em GraphQL + YAML |

O roadmap completo está em [AGENTS.md](../AGENTS.md), seção 19.

## Interface

[design-system.md](design-system.md) — a gramática da evidência, a paleta, as três vozes tipográficas, WCAG 2.0 e mobile-first. **Normativo**: vale para toda tela nova.
