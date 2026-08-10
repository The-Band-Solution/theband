# Contrato — ferramentas conectadas

**Feature**: 001 · **Requisitos**: FR-002, FR-003, FR-004, FR-010

## O que identifica uma ferramenta conectada

Três coisas, e as três são necessárias:

| Parte | Responde | Exemplo |
|---|---|---|
| `tool_type` | qual ferramenta | `github` |
| `instance_url` | **onde** ela roda | `https://github.com`, `https://git.interno.example` |
| `organization_login` | **qual** organização observar naquela instância | `leds-conectafapes` |

A instância não determina a organização. Um mesmo `https://github.com` hospeda
todas as organizações do mundo, e um cliente da plataforma pode ter várias — é
comum: uma empresa com `acme` e `acme-labs`, ou um laboratório com uma
organização por programa.

```elixir
unique_index(:connected_tools, [:tenant_id, :tool_type, :instance_url, :organization_login])
```

**Correção de contrato.** A primeira versão do esquema tinha a unicidade sobre
`[:tenant_id, :tool_type, :instance_url]`, sem a organização. `organization_login`
entrou numa migração posterior e a restrição não foi revisada. O efeito era que
uma organização cliente conseguia registrar **um único** `github.com`, e portanto
observar uma única organização — limite que o domínio não pede e que nenhum
requisito declara.

`organization_login` é anulável, porque uma ferramenta futura pode não ter esse
conceito. O índice usa `NULLS NOT DISTINCT`: sem isso o Postgres trataria cada
`NULL` como distinto, e a mesma ferramenta sem organização poderia ser cadastrada
várias vezes — a duplicata que a restrição existe para impedir.

## API pública

Módulo: `TheBand.Sources`.

```elixir
@spec connect_tool(Tenant.t(), attrs :: map()) ::
        {:ok, %{tool: ConnectedTool.t(), credential: ToolCredential.t()}}
        | {:error, :unauthorized | {:missing_scopes, [String.t()]} | Ecto.Changeset.t()}

@spec add_credential(Tenant.t(), ConnectedTool.t(), attrs :: map()) ::
        {:ok, ToolCredential.t()} | {:error, term()}

@spec list_connected_tools(Tenant.t()) :: [ConnectedTool.t()]
@spec fetch_connected_tool(Tenant.t(), Ecto.UUID.t()) ::
        {:ok, ConnectedTool.t()} | {:error, :not_found}
@spec active_credential(ConnectedTool.t()) :: ToolCredential.t() | nil

@spec mark_needs_attention(ConnectedTool.t(), reason :: String.t()) ::
        {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
@spec clear_needs_attention(ConnectedTool.t()) ::
        {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
```

`attrs` de `connect_tool/2`: `tool_type`, `instance_url`, `organization_login`,
`secret`, `label`. Chaves em string ou átomo — a tela envia string, os testes
enviam átomo.

## Garantias

**A credencial é validada antes de qualquer gravação** (FR-006). Acesso **e**
escopo: token sem `read:org` conecta e devolve zero equipes, o que é pior que
falhar, porque a organização apareceria vazia sem que ninguém soubesse por quê.

**Falha não grava nada.** Nem a ferramenta, nem a credencial. Gravar a ferramenta
e deixar a credencial para depois produziria uma conexão meio-feita que ninguém
sabe se funciona — por isso as duas entram na mesma transação.

**Reconectar a mesma ferramenta não duplica.** `connect_tool/2` sobre uma
combinação já existente atualiza a ferramenta e **acrescenta** a credencial: é
como uma segunda conta de serviço entra (FR-004).

**Uma organização cliente pode observar várias organizações de origem**, na mesma
instância ou em instâncias diferentes. Cada uma é uma ferramenta conectada com
sua própria credencial, seu próprio estado e sua própria sincronização — inclusive
o bloqueio de FR-018, que é por ferramenta e não por instância.

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| descobrir automaticamente as organizações do token | a credencial costuma enxergar mais organizações do que o cliente quer trazer. Coletar todas por conveniência traria dado de terceiro para dentro do tenant |
| `delete_connected_tool/2` | apagar a ferramenta deixaria órfãos os registros que ela originou, e a proveniência aponta para ela. Desativar é o caminho; apagar exige decidir o que fazer com o coletado |
| trocar a organização de uma ferramenta já conectada | seria a mesma linha apontando para duas origens ao longo do tempo, e a proveniência dos registros antigos passaria a mentir. Conecte outra ferramenta |
| credencial compartilhada entre ferramentas | credenciais diferentes enxergam conjuntos diferentes; qual foi usada fica registrado em cada sincronização |
