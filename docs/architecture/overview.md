# Arquitetura do The Band

O **modelo de dados** — tabelas, schemas Ecto e a razão da forma de cada um — está
em [modelo-de-dados.md](modelo-de-dados.md).

## 1. O problema

Organizações de software usam dezenas de ferramentas — GitHub, GitLab, Azure DevOps,
Jira, Sonar, CI/CD, monitoramento, controle de tempo. Cada uma tem seu modelo de dados,
seu vocabulário e sua noção própria do que é "uma tarefa", "um bug", "uma entrega".

Juntar esses dados em um data lake não resolve: os nomes coincidem, os conceitos não.
Um Pull Request não é um merge. Uma issue do Jira pode ser uma user story, um requisito
ou um defeito, dependendo de um campo. Um *code smell* do Sonar não é um defeito.
Somar números vindos de sistemas que discordam sobre o que estão contando produz
indicadores que parecem confiáveis e não são.

The Band ataca isso pela semântica: os dados são harmonizados contra **ontologias de
referência**, e cada dado carrega sua proveniência. Assim é possível responder não só
"qual o cycle time da equipe", mas "de onde esse número veio, como foi calculado e
quais dados o sustentam".

## 2. Origem

A arquitetura deriva da tese de doutorado de Paulo Sérgio dos Santos Júnior
(UFES, 2023). Lá, The Band é o componente de integração de dados do ambiente
*Immigrant*, construído sobre **Continuum** — uma (sub)rede ontológica de Continuous
Software Engineering integrada à **SEON** e fundamentada na **UFO**.

A tese descreve The Band como um *Federated Information System*: serviços autônomos
baseados em ontologia (OBS), cada um com seu repositório (OBDR), comunicando-se por um
message broker para manter consistência.

## 3. Da tese para esta implementação

Esta implementação **preserva a semântica e simplifica a topologia**. As camadas da
tese viram fronteiras internas de um monólito modular, não serviços separados.

| Camada da tese | Aqui | Por quê |
|---|---|---|
| Application Integration Layer (ASAs, Extract Components) | `lib/the_band/integrations/`, `ingestion/`, `priv/connectors/` | mesma responsabilidade, sem processo separado |
| Internal Data Communication Layer (message broker, Transform/Load) | Oban + `semantic_integration/` | Oban entrega filas, retries e agendamento sobre o PostgreSQL que já existe |
| Federated Ontology-Based Service Layer (OBS + OBDR) | `lib/the_band/ontology/<rede>/<ontologia>/` + tabelas prefixadas | cada ontologia é um módulo com API pública e schemas privados |
| Federated Data Access Layer | `analytics/`, `reportify/`, LiveView e APIs | mesma responsabilidade |

**O que não muda.** Os módulos ontológicos continuam autônomos entre si: um só fala com
o outro pela API pública, nunca pelos schemas Ecto. A federação vira disciplina de
fronteira em vez de fronteira de rede — o que é reversível quando um módulo justificar
virar serviço.

**O que a tese exige e permanece obrigatório no modelo de dados:**

- `internal_id` — identidade estável do dado entre módulos ontológicos;
- `record_version` — versão do registro, para detectar dessincronização;
- **Application Reference** — `source_system` + `source_instance` + `external_id`,
  ligando cada registro à entidade de origem na ferramenta externa.

Sem esses três, não há rastreabilidade — e sem rastreabilidade o dado não serve ao
propósito do sistema.

## 4. Fluxo dos dados

```text
Fontes externas (GitHub, GitLab, Jira, Sonar…)
  → conectores declarativos (definição YAML + query GraphQL, executados com Req)
  → payload bruto + proveniência          ← nada é descartado nesta etapa
  → mapeamento semântico (YAML)           ← equivalência, justificativa e limitações
  → validação semântica
  → API pública do módulo ontológico      ← o conector nunca escreve no schema
  → PostgreSQL / Ecto (tabelas prefixadas pela ontologia)
  → necessidades de informação → medidas → indicadores
  → Reportify → Phoenix LiveView e APIs
```

Uma entidade externa alimenta **várias** ontologias. Um Pull Request do GitHub produz:

- **CMPO** — a solicitação de mudança;
- **EO** — autor e revisores como pessoas;
- **SPO** — atividades e participações;
- **SysSwO** — artefatos alterados;
- **CIRO** — possível gatilho de pipeline.

Cada um desses é um mapeamento próprio, com suas próprias limitações declaradas.

## 5. Organização do domínio

O núcleo é organizado **pelas ontologias**, não pelas ferramentas. Não existe módulo
`TheBand.GitHub` no domínio: GitHub é fonte, não conceito.

```text
lib/the_band/ontology/
├── ufo/                                    camada fundacional
├── seon/{eo,spo,sys_swo,rsro,cmpo,          core e domínio da SEON
│         roost,qapo,osdef}/
└── continuum/{sro,ciro,cdro}/              Continuous Software Engineering
```

Cada módulo ontológico expõe API pública pelo módulo raiz e mantém `schemas/`,
`commands/`, `queries/`, `services/`, `relations/`, `constraints/` e `events/`
como detalhes internos.

A direção das dependências vai do específico para o geral e é verificada
automaticamente. O grafo completo está em [Rede de ontologias](../ontology/README.md).

## 6. Base de conhecimento

O modelo conceitual não vive no código: vive em `priv/knowledge_base/`, como YAML
versionado, validado e revisado. O código **carrega** esse modelo.

Isso é decisão arquitetural, não conveniência — ver
[ADR 0002](../adr/0002-yaml-como-base-de-conhecimento.md). A consequência prática é que
uma mudança conceitual aparece como diff revisável por quem entende do domínio, e não
como alteração espalhada por schemas e migrações.

## 7. Multitenancy

Uma base PostgreSQL, tabelas compartilhadas, `tenant_id` em toda entidade relevante,
políticas de acesso. Sem banco por tenant.

Toda query de domínio recebe o tenant explicitamente; todo job Oban carrega e valida
`tenant_id`. Ausência de filtro de tenant é tratada como falha de segurança, não como
bug de correção.

Os YAMLs da base de conhecimento são globais. Extensão por tenant só entra via feature
especificada.

## 8. Stack

```text
Elixir / Erlang OTP     Phoenix + LiveView
Ecto + PostgreSQL       Oban (filas, retries, agendamento)
Req (HTTP)              ExUnit + Mox
Credo + Dialyzer        ExDoc
Docker Compose (dev)    Phoenix Releases (deploy)
```

Fora da fundação, por decisão explícita: Python, Go, frontend TypeScript separado,
NATS, Kafka, RabbitMQ, Apache AGE, Neo4j, pgvector, Kubernetes, microserviços.
Cada um exige feature própria, análise comparativa e ADR — ver
[ADR 0001](../adr/0001-monolito-modular-elixir.md).

## 9. Observabilidade

Todo processamento registra, quando aplicável: `tenant_id`, `correlation_id`,
`source_system`, `source_instance`, `external_id`, `internal_id`, `ontology`,
`concept`, `mapping_id`, `schema_version`, `record_version`, `job_id`, `attempt`,
`duration`, `record_count`, `checkpoint`, `status`, `error_code`, `error_reason`.

Métricas operacionais: duração da coleta; registros coletados, transformados,
rejeitados e duplicados; atraso de sincronização; falhas por fonte; retries; jobs Oban;
falhas de validação de YAML; perguntas de competência com erro.

## 10. Restrições que a arquitetura impõe

- Conector não escreve em schema Ecto de módulo ontológico.
- Módulo ontológico não acessa schema de outro módulo.
- Modelo de API externa não vira modelo de domínio.
- Conceito existente em ontologia mais geral é reutilizado, nunca duplicado.
- Processamento repetido é idempotente.
- Todo dado integrado preserva proveniência.
- Nenhuma medida existe sem necessidade de informação declarada.
- Nenhum mapeamento existe sem justificativa semântica e limitações explícitas.
