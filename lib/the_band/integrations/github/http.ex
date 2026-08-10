defmodule TheBand.Integrations.GitHub.HTTP do
  @moduledoc """
  Borda HTTP do conector do GitHub.

  Existe como behaviour por um motivo só: é o **único** ponto que o Mox
  substitui nos testes. Módulo de domínio próprio nunca é mockado — mock de
  domínio esconde erro em vez de revelá-lo (AGENTS.md §7.6).
  """

  @type response :: %{status: integer(), body: map() | binary(), headers: map()}

  @callback post(url :: String.t(), body :: map(), token :: String.t()) ::
              {:ok, response()} | {:error, term()}

  @callback get(url :: String.t(), token :: String.t()) ::
              {:ok, response()} | {:error, term()}

  @doc "Implementação configurada. Em teste, o Mox."
  @spec impl() :: module()
  def impl, do: Application.get_env(:the_band, :github_http_client, __MODULE__.Req)
end
