defmodule TheBand.MCP.Ausencia do
  @moduledoc """
  Os três estados da ausência, que **nunca** saem pelo valor (feature 062, FR-012, FR-013).

  | Estado | No protocolo | Carrega |
  |---|---|---|
  | conferido, e nada encontrado | `checked` | o valor, que pode ser zero — é o **único** caso em que zero é resposta |
  | não conferido | `not_checked` | **o que falta** para conferir |
  | recusado | `refused` | **a razão**, no vocabulário da regra |

  Um agente que recebe `0` onde a resposta é *"não observado"* relata zero, e ninguém vê a
  diferença. E uma lista vazia por falta de permissão é o sucesso silencioso que esta casa já
  registrou nove vezes. Por isso o estado vai em campo próprio, `state`, e a recusa é
  **resposta**, e não exceção.
  """
end
