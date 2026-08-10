defmodule TheBand.Integrations.GitHub.HTTP.Req do
  @moduledoc """
  Implementação real da borda HTTP, sobre Req.

  Backoff exponencial vale para erro de rede e 5xx. **Rate limit não passa por
  aqui**: não é erro, é informação de capacidade, e quem o trata é o conector,
  pausando antes de esgotar a janela (research.md R6).
  """

  @behaviour TheBand.Integrations.GitHub.HTTP

  @impl true
  def post(url, body, token) do
    [
      url: url,
      json: body,
      headers: headers(token),
      retry: :transient,
      max_retries: 3,
      receive_timeout: 30_000
    ]
    |> Req.new()
    |> Req.post()
    |> normalize()
  end

  @impl true
  def get(url, token) do
    [url: url, headers: headers(token), retry: :transient, max_retries: 3]
    |> Req.new()
    |> Req.get()
    |> normalize()
  end

  defp headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/vnd.github+json"},
      {"user-agent", "the-band/0.1"},
      # `GraphQL-Features` habilita os campos de tipo de issue usados adiante.
      {"x-github-next-global-id", "1"}
    ]
  end

  defp normalize({:ok, %Req.Response{status: status, body: body, headers: headers}}),
    do: {:ok, %{status: status, body: body, headers: headers}}

  defp normalize({:error, reason}), do: {:error, reason}
end
