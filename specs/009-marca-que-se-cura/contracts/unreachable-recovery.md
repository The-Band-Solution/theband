# Contrato — a recuperação do repositório inacessível

Feature 009. Escrito **antes** da mudança, como o princípio VII exige.

**Nenhuma função pública nova.** Três assinaturas existentes mudam de comportamento, e uma coluna
entra.

---

## `TheBand.Ontology.SEON.CMPO.list_collectable(tenant, connected_tool_id)`

**Comportamento novo**: rejeita **só** o repositório excluído pelo tenant. O inacessível **volta**
para a lista.

| Situação | Antes | Depois |
|---|---|---|
| observado, sem marca | na lista | na lista |
| **inacessível** | fora | **na lista** — a coleta tenta de novo |
| excluído pelo tenant | fora | fora |
| excluído **e** inacessível | fora | fora — a exclusão vence |

**A exclusão é decisão de alguém; a inacessibilidade é inferência da plataforma.** O nome da função
não muda porque ele já dizia o certo — era a implementação que discordava.

---

## `TheBand.Ontology.SEON.CMPO.mark_inaccessible(tenant, observed_repository_id, reason)`

**Comportamento novo**: a data é gravada **na primeira** falha e **preservada** nas seguintes. O
motivo é sempre atualizado.

| Chamada | `inaccessible_since` | `inaccessible_reason` |
|---|---|---|
| primeira | agora | o motivo |
| segunda, terceira… | **inalterada** | o motivo **da última** falha |

Assim "desde quando" responde desde quando, e não "quando alguém olhou por último".

---

## `TheBand.Integrations.GitHub.Client.transient?(reason)`

**Comportamento novo**: julga `{:graphql_errors, errors}`, que hoje cai no caso geral e devolve
`false`.

| Erro da origem | Devolve | Por quê |
|---|---|---|
| `{:transport, _}` | `true` | como hoje |
| `{:unexpected_status, s}` com `s >= 500` | `true` | como hoje |
| `{:graphql_errors, [%{"type" => "NOT_FOUND"}]}` | **`false`** | não existe, ou o token não alcança |
| `{:graphql_errors, [%{"type" => "FORBIDDEN"}]}` | **`false`** | falta escopo, e escopo não muda sozinho |
| `{:graphql_errors, [%{"type" => "RATE_LIMITED"}]}` | **`true`** | e a pausa a trata antes |
| `{:graphql_errors, [%{"message" => "Something went wrong… Please include `…`"}]}` | **`true`** | falha interna da origem, com identificador de incidente |
| lista com naturezas mistas | **`false`** | vence o permanente — FR-008 |
| erro sem `type` e sem essa assinatura | **`false`** | o desconhecido é permanente, e a cura o torna reversível |

**A ordem das decisões importa**: primeiro tornar a marca reversível — é a mesma feature —, depois
classificar melhor. Marcar de menos deixaria repositório apagado sendo consultado para sempre.

---

## `TheBand.Ingestion.GithubWorkItems.collect(ctx)`

**Comportamento novo**: o resultado passa a dizer quantos repositórios não foram alcançados.

```text
%{organization_id: _, repositories: _, issues: _, unreachable: non_neg_integer()}
```

E o registro de sincronização recebe o mesmo número em `repositories_unreachable`.

**Zero é um fato aqui**, e não ausência: a coleta que alcançou todos não alcançou zero. O que era
ausência é o estado de hoje — a plataforma não sabendo quantos deixou de alcançar, com 39 caídos e a
tela dizendo "concluída".

---

## O que este contrato deliberadamente **não** declara

| Ausente | Por quê |
|---|---|
| `permanent?/1` | seria a negação de `transient?/1` com outro nome, e duas fontes para uma decisão |
| `list_unreachable/2` | a lista de repositórios já expõe a marca; uma consulta própria teria zero chamadores |
| `retry_repository/2` | a coleta é a tentativa; um caminho manual seria o segundo caminho para a mesma decisão |
| `last_attempt_at` | o registro de sincronização já data a última tentativa |
