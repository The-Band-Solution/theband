# Plano — Validador Elixir à paridade com o Python (#177)

**Spec**: [spec.md](./spec.md) · **Branch**: `029-validador-a-paridade`

## Contexto técnico

| | |
|---|---|
| Onde mexe | `lib/the_band/ontology/yaml_validator.ex`, `yaml_loader.ex`, `schema_check.ex` (novo), `lib/mix/tasks/gates.ex`, `scripts/validate_knowledge_base.py` |
| Não mexe | base de conhecimento — nenhum YAML muda; a base já era válida |
| Entrada | os artefatos que `YamlLoader.load_all/1` devolve, incluindo os `schemas/*.schema.yaml` |
| Saída | `:ok` ou `{:error, [String.t()]}`, uma linha por problema, nomeando o arquivo |

## Decisões de projeto

Princípio VIII exige, para cada padrão introduzido, três respostas: qual problema concreto
resolve, se o problema **existe agora**, e o que piora.

### D1 — Um índice montado uma vez, em vez de varredura por referência

**Problema**: são 220 conceitos e 144 relações; quase toda verificação pergunta "este id
existe?". Varrer a lista a cada pergunta é quadrático.
**Existe agora**: sim — nove das treze verificações precisam do índice.
**Piora**: o índice é construído mesmo quando só uma verificação roda. Custo medido:
irrelevante diante do I/O de ler 96 arquivos.

### D2 — Verificador de JSON Schema próprio, sem dependência nova

**Problema**: era a única das treze que só o Python fazia, e depender do Python é depender do
`.venv` (L23).
**Existe agora**: sim.
**Piora**: um construto de schema não implementado deixa de ser verificado. O custo está
contido porque `construto_nao_suportado/2` **reprova** o construto desconhecido em vez de
ignorá-lo — o schema não pode crescer para além do que o gate mede sem alguém ver. Detalhe e
alternativa descartada em `TheBand.Ontology.SchemaCheck`.

### D3 — A ontologia de um id vem do prefixo, não do módulo

**Problema**: derivar do módulo faz um módulo sem `module.ontology` produzir `nil`, e aí toda
referência dele reprova.
**Existe agora**: sim — foram 130 falsos positivos na primeira execução.
**Piora**: o id passa a ser contrato mais forte. Aceitável: a primeira das treze verificações
existe exatamente para garantir o formato `ontologia.conceito`.

### D4 — Tabela literal de tipos no carregador, em vez de `String.to_existing_atom`

**Problema**: a existência do átomo dependia de qual módulo já tinha sido carregado. Antes de
`app.config`, `:ontology` não existia, as 12 ontologias viravam `unknown`, e a validação
reprovava a base com **124 problemas inventados**; depois de `app.config`, a mesma base passava.
**Existe agora**: sim — foi o defeito que travou o boot durante esta feature.
**Piora**: um tipo novo precisa ser acrescentado à tabela. É o objetivo: tipo desconhecido vira
`unknown` explicitamente, e não átomo silencioso.

### D5 — A concordância entre os dois validadores é gate, não teste

**Problema**: FR-007 pede comparar as duas saídas sobre a mesma base, e a comparação precisa do
`.venv`.
**Existe agora**: sim.
**Piora**: quem roda só `mix test` não vê a comparação. Foi o que decidiu: nos gates o venv já
está provisionado pelo gate anterior; em `mix test` ele ainda não existe, e um teste que falha
por ferramenta ausente reprovaria o CI limpo por ordem de execução, não por defeito.

## Constitution Check

| Princípio | Como este plano atende |
|---|---|
| I — ontologia como fonte | nenhum YAML muda; o plano só mede o que já está declarado |
| VII — quality gates | acrescenta o 13º gate, e `mix gates` continua a definição única |
| VIII — o que se constrói se justifica | D1 a D5 acima |
| IX — dependência declarada | a verificação de dependência entre ontologias passa a existir do lado Elixir |

## Fases

**Fase 0 — medir.** Contar as verificações dos dois lados, lendo os dois validadores. Registrado
na spec: Python 11, Elixir 4, e uma que só o Elixir tem.

**Fase 1 — as nove verificações que faltavam**, uma a uma, cada uma com o teste da violação que
ela pega.

**Fase 2 — a de forma (JSON Schema)**, com o subconjunto de construtos que os schemas usam.

**Fase 3 — o segredo no Python**, para a paridade valer nos dois sentidos.

**Fase 4 — o gate de concordância.**
