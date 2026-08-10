# Contrato — ciclo de observação de uma ferramenta

**Feature**: 003 · **Requisitos**: FR-001 a FR-014 · **Research**: [R1, R2, R4, R5, R6](../research.md)

Complementa o [contrato de ferramentas conectadas da feature 001](../../001-github-eo-ingestion/contracts/connected-tools.md), que continua valendo — inclusive nas duas ausências que ele declarou, e que este contrato resolve **sem** contrariá-las.

## API pública

Módulo: `TheBand.Sources`.

```elixir
@spec end_observation(Tenant.t(), ConnectedTool.t(), attrs :: map()) ::
        {:ok, %{tool: ConnectedTool.t(), event: ObservationEvent.t(), impact: impact()}}
        | {:error, :confirmation_mismatch | Ecto.Changeset.t()}

@spec resume_observation(Tenant.t(), ConnectedTool.t(), credential_attrs :: map()) ::
        {:ok, %{tool: ConnectedTool.t(), event: ObservationEvent.t(), credential: ToolCredential.t()}}
        | {:error, :unauthorized | {:missing_scopes, [String.t()]} | Ecto.Changeset.t()}

@spec observation_ended?(ConnectedTool.t()) :: boolean()
@spec observation_history(Tenant.t(), ConnectedTool.t()) :: [ObservationEvent.t()]

@spec observation_impact(Tenant.t(), ConnectedTool.t()) :: impact()
```

```elixir
@type impact :: %{
        teams: non_neg_integer(),
        derived_teams: non_neg_integer(),
        evidence_links: non_neg_integer(),
        people_exclusive: non_neg_integer(),
        people_shared: non_neg_integer(),
        preserved_payloads: non_neg_integer()
      }
```

## `observation_impact/2` — o que a tela mostra antes de confirmar

Devolve **o que o encerramento vai marcar**, e é a mesma função que o encerramento usa
para gravar `impact` no evento. Uma segunda contagem, escrita para a tela, divergiria da
que age — e o número que a pessoa vê antes de confirmar tem de ser o número que
acontece.

`people_exclusive` e `people_shared` são separados de propósito. São perguntas
diferentes, e juntá-las esconde a única que assusta:

```text
ifesserra-lab   people_exclusive: 4   people_shared: 1
```

`preserved_payloads` aparece para dizer **zero apagados**: o número existe na tela para
que ninguém suponha que encerrar destrói o histórico de coleta.

## `end_observation/3` — o que faz, na ordem

```text
1. confere a confirmação        attrs.confirmation == tool.organization_login
2. calcula o impacto            a mesma função da tela
3. numa transação:
   a. grava o evento `ended`    com o impacto, o autor e o motivo
   b. marca equipes             da organização, inclusive a derivada
   c. marca vínculos            que apontam para essas equipes
   d. marca pessoas             só as sem nenhum vínculo vigente restante
   e. destrói as credenciais    apaga as linhas — FR-007
4. interrompe a coleta em curso se houver
```

**A confirmação é comparada com o `organization_login`**, e o erro é
`:confirmation_mismatch` — nomeado, para a tela dizer o que está errado em vez de
"inválido". FR-003, e a decisão da pessoa mantenedora de exigir digitar o nome.

**A ordem de (b) a (d) não é arbitrária.** As pessoas são marcadas **por último**, porque
a decisão depende dos vínculos já marcados: uma pessoa é marcada quando não lhe resta
nenhum vínculo vigente, e isso só é verdade depois de (c). Inverter marcaria pessoa que
ainda tinha vínculo, e é exatamente o defeito que a primeira versão da spec tinha.

**Tudo numa transação.** Um encerramento parcial — credencial destruída e registros não
marcados — deixaria a plataforma coletando de uma ferramenta sem credencial e afirmando
observar o que não observa.

### Idempotência

Encerrar ferramenta já encerrada devolve `{:ok, ...}` com `impact` zerado e **grava um
segundo evento `ended`**. Não é erro: alguém tentou, e o registro diz que tentou. A
alternativa — recusar — faria a segunda tentativa parecer falha quando o estado desejado
já vale.

## `resume_observation/3` — o que volta a ser vigente, e o que não

```text
1. valida a credencial nova     contra a ferramenta, como em connect_tool/2
2. numa transação:
   a. grava o evento `resumed`
   b. grava a credencial nova
3. a coleta seguinte é que devolve vigência aos registros
```

**A retomada não desmarca nada por si.** Isso é decisão, e é o que R6 sustenta: só a
coleta pode dizer se a origem ainda mostra o registro. Desmarcar no ato da retomada
ressuscitaria vínculo que a origem já não tem — a plataforma passaria a afirmar
observação que não ocorreu.

**Credencial nova é obrigatória** porque a anterior foi destruída (FR-013). A função não
tem parâmetro para reusar credencial: não existe o que reusar.

## `observation_ended?/1` — a derivação, num lugar só

Lê o último evento da ferramenta. Sem evento, **vigente** — é o que faz as ferramentas
existentes continuarem observadas sem migração de dado.

**Esta função é o único caminho.** A tela e o filtro de coleta a usam, e o risco que o
plano nomeia é dois caminhos discordarem: a plataforma coletaria do que a tela mostra
como encerrado.

## Garantias

**Nenhum registro observado é apagado** (FR-004). As contagens de pessoas, equipes, vínculos e
payloads são iguais antes e depois — SC-001 mede isso, e é a garantia central.

**Nada é marcado se tiver vigência em outra ferramenta** (FR-005, FR-006). Uma pessoa em três
organizações perde um vínculo e mantém dois. SC-003 mede.

**Nenhuma coleta consulta origem encerrada** (FR-008). O filtro usa `observation_ended?/1`, e o
teste roda **sem expectativa no Mox da borda HTTP** — qualquer chamada o derruba.

**A coleta em andamento é interrompida, não morta** (FR-027). Vai para `interrupted` com o
motivo, preservando progresso e checkpoints, pelo mesmo caminho que a credencial
revogada já usa. Matar o job deixaria a sincronização em `running` para sempre, e o
índice que impede coletas simultâneas continuaria bloqueando.

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| `delete_connected_tool/2` | **a recusa da feature 001 permanece, e agora é medição**: as cascatas `connected_tools → syncs → raw_payloads` destruiriam 472 payloads preservados, e com eles a capacidade de reprocessar mapeamento corrigido. Encerrar é o caminho |
| alterar tipo, instância ou organização | recusa mantida: a mesma linha apontando para duas origens ao longo do tempo faria a proveniência dos registros antigos mentir. Outra organização é outra ferramenta |
| `unmark_records/2` ou equivalente | desmarcar por decisão afirmaria observação que não ocorreu. Só a coleta devolve vigência |
| encerrar em lote | o impacto de cada ferramenta precisa estar à vista de quem confirma, e um lote esconde o de cada uma |
| apagar dado coletado | não é o que encerrar significa, e contraria o princípio III. Exclusão de dado pessoal, se for necessária, é feature própria com o seu próprio registro de decisão |
| desfazer um encerramento | não existe: o caminho é retomar, que é um evento novo. Desfazer apagaria o evento, e evento não se apaga |
