defmodule TheBandWeb.Api.V1.Erro do
  @moduledoc """
  O formato único de erro da API — FR-020.

  **Um formato para todos os códigos**, para que quem integra escreva um tratador e não seis.

  ## `404` e não `403` para recurso de outro tenant

  `403` afirma *"isto existe e você não pode"*, e essa afirmação é vazamento de existência:
  cruzando identificadores, quem chama descobre o que há no outro tenant sem receber um byte
  de conteúdo.

  ## A mensagem nunca diz qual das causas ocorreu

  Para `401`, ela é a mesma para inexistente, revogado, expirado e conta desativada. O
  `request_id` é o que liga a recusa muda ao motivo real, no log interno.
  """

  @tipo %{
    unauthorized: {401, "The credential presented is not usable."},
    not_found: {404, "No such resource for this credential."},
    method_not_allowed: {405, "This API is read-only."},
    # A mensagem é substituída pelo plug do limite, que acrescenta o número e a janela: uma
    # recusa por taxa que não diz o limite faz quem integra tentar de novo imediatamente.
    too_many_requests: {429, "Too many requests for this credential."},
    internal_error: {500, "Something went wrong on our side."}
  }

  @doc "O corpo do erro, na forma única."
  @spec corpo(atom(), String.t()) :: map()
  def corpo(codigo, request_id) do
    {_status, mensagem} = Map.fetch!(@tipo, codigo)

    %{error: %{code: to_string(codigo), message: mensagem, request_id: request_id}}
  end

  @doc "O status HTTP de cada código."
  @spec status(atom()) :: pos_integer()
  def status(codigo), do: @tipo |> Map.fetch!(codigo) |> elem(0)

  @doc "Os códigos declarados — a lista que o contrato e o Swagger leem."
  @spec codigos() :: [atom()]
  def codigos, do: Map.keys(@tipo)
end
