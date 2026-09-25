defmodule TheBand.MCP.Envelope do
  @moduledoc """
  O envelope de proveniência que **toda** resposta de medida carrega (feature 062, FR-010,
  FR-011, FR-014).

  Um modelo não sabe perguntar pela ressalva. Uma pessoa que vê `0,2 h` na tela vê, ao lado,
  *"23 revisadas; outras 79 ainda aguardam, há 46 dias"*. Um agente que recebe `0.2` num campo
  relata `0.2`. Por isso a ressalva vai **no mesmo objeto**, e não como campo opcional, texto
  anexo ou segunda chamada.

  Os campos estão em `specs/062-servidor-mcp/data-model.md`: `value`, `composition`, `window`,
  `origin`, `rule`, `measurement_id`, `limitations`, `misinterpretations` e `collected_at`.
  **`limitations` e `misinterpretations` são lidas da base de conhecimento** em tempo de
  resposta, e nunca escritas aqui (princípio IV). **`window: nil` é dito, e não omitido**, e
  `rule` é `nil` para medida, porque o schema de medida não tem versão.
  """
end
