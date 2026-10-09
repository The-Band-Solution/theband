# Contrato: a base de conhecimento bilíngue

Issue #1312, filha do #1267. Escrito **antes** da mudança de schema e de leitor.

## O que muda na forma

Quatro campos da base passam a carregar o texto em inglês ao lado do português.

| campo | schema | forma antes | forma depois |
|---|---|---|---|
| `concepts[].definition` | `module` | `{pt-BR}` | `{pt-BR, en}`: só acrescenta `en`, a forma já admitia |
| `module.description` | `module` | `{pt-BR}` | `{pt-BR, en}`: idem |
| `competency_questions[].question` | `competency-question` | `{pt-BR}` | `{pt-BR, en}`: idem |
| `semantics.justification` | `mapping` | string (pt-BR) | string **ou** `{pt-BR, en}` com `pt-BR` obrigatório |
| `limitations[]` (do mapeamento) | `mapping` | lista de string (pt-BR) | lista de string **ou** `{pt-BR, en}` com `pt-BR` obrigatório |

Os dois últimos são os únicos que mudam de forma. Os dois apontam para `$defs/text` em
`common.schema.yaml`, que aceita **as duas formas** (`anyOf`, o construto que `SchemaCheck` já
verifica; `oneOf` e `minLength` ele não verifica, e por isso não são usados): um YAML
que ainda tem string continua válido, e nenhum YAML existente precisa mudar para o schema passar.
`pt-BR` é obrigatório no mapa porque a base nasce em português: um mapa só com `en` seria texto
traduzido sem o original.

`limitations` e `misinterpretations` das **medidas** não mudam neste contrato.

## O que os leitores devolvem

A regra é uma: **quem lia `pt-BR` continua recebendo `pt-BR`, e da mesma forma de antes**. O `en`
existe para o site gerado, e nenhum leitor Elixir passa a devolver inglês por causa deste contrato.

### `TheBand.Ontology.KnowledgeBase.pt_br/1` (nova)

```elixir
@spec pt_br(String.t() | %{required(String.t()) => String.t()}) :: String.t()
```

- string → a própria string;
- mapa com `"pt-BR"` → o valor de `"pt-BR"`;
- qualquer outra coisa → `FunctionClauseError`. Um campo de texto sem `pt-BR` é YAML que o
  validador deveria ter recusado; devolver `""` ou `nil` seria fallback silencioso.

### `TheBand.SemanticIntegration.Mapper.limitations/1`

Assinatura igual: `limitations(String.t()) :: [String.t()]`. Cada item passa por `pt_br/1`, então
continua sendo lista de string em português, com o item em mapa ou em string.

### `TheBand.MCP.Envelope.montar/1`

`limitations` do envelope continua lista de string em português, vindo de mapeamento ou de medida.
É o que um cliente MCP recebe hoje, e o que o teste `segredo_nao_vaza_test.exs` confere com `=~`.
Expor o mapa `{pt-BR, en}` ao cliente MCP seria mudar o contrato do envelope (062,
`data-model.md`), e não é o que esta issue faz.

### Validadores

- `YamlValidator` (Elixir): `semantics.justification` vazia continua reprovada, seja `""`, seja
  mapa com `pt-BR` vazio. A busca de lastro em `limitations` (`lastro?/4`) já usa `inspect/1` e
  lê as duas formas.
- `scripts/validate_knowledge_base.py`: a forma vem do schema (`jsonschema`); a presença, de
  `if not sem.get("justification")`, que vale para string e mapa.

### `scripts/generate_docs.py`

A página em português continua idêntica byte a byte: o texto vem de `pt-BR` quando o campo é mapa.

## O que não muda, e por quê

- **ids, nomes de conceito e rótulos** não se traduzem: `name` já está em inglês, e `label` já
  tinha `en`;
- **nenhum leitor passa a preferir `en`**. Preferir inglês numa tela ou no MCP é decisão de produto
  com spec própria;
- a semântica: o `en` é tradução do `pt-BR`, e a revisão semântica por amostragem está em
  [`../revisao-semantica-base-en.md`](../revisao-semantica-base-en.md).
