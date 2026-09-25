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

  ## Um construtor por estado, e cada um exige o que o estado carrega

  Não há `new(state, ...)` genérico, de propósito: com ele, `not_checked` sem `missing` seria uma
  chamada válida. Aqui `nao_conferido/1` sem argumento é erro de **compilação** (a função de
  aridade zero não existe), e com argumento vazio é recusado na hora. `value` é `nil` nos dois
  estados de ausência, e nunca `0`.
  """

  @typedoc "Os três estados, com a chave que cada um exige."
  @type t ::
          %{state: String.t(), value: term()}
          | %{state: String.t(), value: nil, missing: String.t()}
          | %{state: String.t(), value: nil, reason: String.t()}

  @doc """
  Conferido: o valor é resposta, **inclusive zero**. É o único estado em que `0` afirma algo.
  """
  @spec conferido(term()) :: t()
  def conferido(valor), do: %{state: "checked", value: valor}

  @doc """
  Não conferido: diz **o que falta** para a plataforma poder responder. Sem `missing`, a
  ausência voltaria a ser indistinguível de *"conferido, e nada"*.
  """
  @spec nao_conferido(String.t()) :: t()
  def nao_conferido(falta) when is_binary(falta) and byte_size(falta) > 0,
    do: %{state: "not_checked", value: nil, missing: falta}

  @doc """
  Recusado: diz **a razão**, no vocabulário da regra (`fora_do_alcance`), o mesmo do log.
  Traduzir criaria um segundo nome para a mesma cláusula.
  """
  @spec recusado(atom() | String.t()) :: t()
  def recusado(razao) when is_atom(razao) and not is_nil(razao) and not is_boolean(razao),
    do: recusado(Atom.to_string(razao))

  def recusado(razao) when is_binary(razao) and byte_size(razao) > 0,
    do: %{state: "refused", value: nil, reason: razao}
end
