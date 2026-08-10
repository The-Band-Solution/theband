# Contrato — reprocessamento de mapeamentos corrigidos

**Feature**: 001 · **Fase**: 1 · **Requisito**: FR-017 · **Critério**: SC-007

Escrito **antes** da implementação, conforme o princípio VI da constituição.

## O problema que resolve

Um mapeamento semântico erra. Descobre-se depois — às vezes semanas depois, quando
alguém percebe que o número não bate. Sem este caminho, corrigir o YAML exigiria
coletar tudo de novo: gastar a janela de API, e depender de a origem ainda ter o
mesmo estado, o que para dado histórico simplesmente não vale.

O payload bruto foi preservado justamente para isso (FR-011). Reprocessar é ler
de `raw_payloads`, reaplicar o mapeamento corrigido e reescrever pelo módulo
ontológico.

## API pública

Módulo: `TheBand.SemanticIntegration`.

```elixir
@type report :: %{
        reprocessed: non_neg_integer(),
        created: non_neg_integer(),
        updated: non_neg_integer(),
        unchanged: non_neg_integer(),
        skipped: non_neg_integer(),
        skip_reasons: %{String.t() => non_neg_integer()}
      }

@spec reprocess_mappings(Tenant.t(), opts :: keyword()) :: {:ok, report()} | {:error, term()}
```

`opts` aceitas:

| `opts` | Efeito |
|---|---|
| `:raw_entity_type` | restringe a um tipo — `"github.user"`, `"github.team"`… Ausente, reprocessa todos |

## Garantias

**Zero consultas à origem.** É a garantia central, e é o que SC-007 mede. O módulo
não conhece `TheBand.Integrations.GitHub.Client`, e a verificação não é por
inspeção de código: o teste roda **sem registrar nenhuma expectativa no Mox da
borda HTTP**, de modo que qualquer chamada faz o teste falhar por si só.

**Idempotente pelo mesmo mecanismo da coleta.** Reprocessar sem ter mudado o
mapeamento devolve `updated: 0` — o upsert por Application Reference já compara
os atributos e não escreve quando nada mudou. Não há caminho separado, e é
proposital: um segundo mecanismo de idempotência seria um segundo lugar para
discordar.

**Proveniência preservada, `collected_at` intocado.** O reprocessamento não é uma
observação nova: o dado continua tendo sido coletado quando foi. Sobrescrever
`collected_at` com o instante do reprocessamento apagaria quando a plataforma de
fato viu aquilo, que é metade do valor da proveniência.

**Mapeamento aplicado é o da base carregada no boot.** Corrigir o YAML exige
reiniciar antes de reprocessar (research.md R4). O relatório não tenta esconder
isso — se a base em memória for a antiga, o reprocessamento reaplica a antiga.

## Erros

| Retorno | Quando |
|---|---|
| `{:error, :no_raw_payloads}` | não há payload preservado para o tenant e o tipo pedido |

**É o único erro de lote.** Todo o resto — payload apontando para mapeamento que
não existe mais, atributo que o conceito rejeita, proveniência incompleta — entra
em `skipped` com o motivo contado em `skip_reasons`, e o lote segue.

**Correção de contrato.** A primeira versão deste documento também previa
`{:error, {:unknown_mapping, id}}` como retorno de lote, e isso contradizia a
frase seguinte dele mesmo: um mapeamento quebrado não pode impedir a correção dos
outros. Derrubar o lote inteiro por causa de um registro tornaria a correção
refém do pior dado da base — exatamente o oposto do que FR-017 existe para
permitir. Prevalece a contagem em `skipped`.

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| reprocessar um registro isolado por id | a correção é de **mapeamento**, e mapeamento vale para o tipo inteiro; reprocessar um só produziria base metade nova e metade velha, sem que ninguém soubesse qual linha é qual |
| forçar reescrita mesmo sem mudança | inflaria `record_version` sem que a origem tivesse mudado, quebrando a única leitura confiável de "isto mudou de verdade" |
| apagar e recriar em vez de atualizar | quebraria toda referência existente ao `id`, que é o que `one table per kind` foi escolhido para evitar (ADR 0004, D1) |
| recoletar quando o payload não existir | seria consulta à origem, exatamente o que FR-017 proíbe. Sem payload, o registro entra em `skipped` |

## Orquestração

`TheBand.Jobs.ReprocessMappings`, worker Oban na fila `:transformation`, com
`tenant_id` nos args e validado antes de executar. Reprocessamento é uso
explicitamente previsto para o Oban (AGENTS.md §7.5), e a fila separada existe
para que um lote grande não bloqueie a coleta.

O resultado é publicado por PubSub no mesmo tópico da sincronização, como
`{:reprocess_finished, report}`.

## Tela

Botão **"Reprocessar mapeamentos"** em `/sincronizacoes`, ao lado de
"Sincronizar", com o relatório exibido ao terminar. Sem tela, o caminho existiria
sem consumidor visível — o que o princípio VI proíbe.

O texto ao lado do botão diz o que ele faz e o que não faz: reaplica os
mapeamentos aos dados já coletados, **sem consultar a ferramenta**.
