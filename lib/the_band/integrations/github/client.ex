defmodule TheBand.Integrations.GitHub.Client do
  @moduledoc """
  Cliente do GitHub: valida credencial e executa as consultas do conector.

  GraphQL por padrão; REST só com justificativa (AGENTS.md §10). Toda consulta
  pede `rateLimit { cost remaining resetAt }` — o limite do GraphQL é por
  **complexidade da consulta**, não por número de requisições, e reagir ao 403
  perderia a janela inteira.
  """

  alias TheBand.Integrations.GitHub.HTTP

  @required_scopes ~w(read:org)

  @doc """
  Valida a credencial contra a ferramenta (FR-006).

  Verifica acesso **e** escopo. Token sem `read:org` passa na conexão e devolve
  zero times — o que é pior que falhar, porque a organização apareceria vazia
  sem que ninguém soubesse por quê.
  """
  @spec verify_credential(String.t(), String.t()) ::
          {:ok, %{login: String.t(), scopes: [String.t()]}}
          | {:error, :unauthorized | {:missing_scopes, [String.t()]} | term()}
  def verify_credential(instance_url, token) do
    case HTTP.impl().get(api_base(instance_url) <> "/user", token) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        scopes = scopes_from(headers)
        missing = @required_scopes -- scopes

        if missing == [] do
          {:ok, %{login: body["login"], scopes: scopes}}
        else
          {:error, {:missing_scopes, missing}}
        end

      {:ok, %{status: status}} when status in [401, 403] ->
        {:error, :unauthorized}

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Executa uma consulta GraphQL.

  Devolve também a informação de rate limit, para que quem pagina possa pausar
  **antes** de esgotar a janela.
  """
  @spec graphql(String.t(), String.t(), String.t(), map()) ::
          {:ok, %{data: map(), rate_limit: map() | nil}} | {:error, term()}
  def graphql(instance_url, token, query, variables \\ %{}) do
    url = graphql_endpoint(instance_url)

    case HTTP.impl().post(url, %{query: query, variables: variables}, token) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} when errors != [] ->
        {:error, {:graphql_errors, errors}}

      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, %{data: data, rate_limit: data["rateLimit"]}}

      {:ok, %{status: status}} when status in [401, 403] ->
        {:error, :unauthorized}

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Decide se é hora de pausar (FR-016, research.md R6).

  A regra é `remaining < cost * 2`. A margem de duas vezes cobre a variação de
  custo entre páginas — uma consulta pode custar mais que a anterior, e reagir
  só quando `remaining < cost` deixaria a última página sem folga.
  """
  @spec pause_needed?(map() | nil) :: {:pause_until, DateTime.t()} | :continue
  def pause_needed?(nil), do: :continue

  def pause_needed?(%{"cost" => cost, "remaining" => remaining, "resetAt" => reset_at})
      when is_integer(cost) and is_integer(remaining) do
    if remaining < cost * 2 do
      case DateTime.from_iso8601(reset_at) do
        {:ok, dt, _} -> {:pause_until, dt}
        _ -> :continue
      end
    else
      :continue
    end
  end

  def pause_needed?(_), do: :continue

  defp api_base("https://github.com"), do: "https://api.github.com"
  defp api_base(url), do: String.trim_trailing(url, "/") <> "/api/v3"

  defp graphql_endpoint("https://github.com"), do: "https://api.github.com/graphql"
  defp graphql_endpoint(url), do: String.trim_trailing(url, "/") <> "/api/graphql"

  defp scopes_from(headers) do
    headers
    |> Enum.find_value(fn
      {"x-oauth-scopes", value} -> value
      _ -> nil
    end)
    |> case do
      nil -> []
      [value | _] -> split_scopes(value)
      value when is_binary(value) -> split_scopes(value)
    end
  end

  defp split_scopes(value) do
    value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end
end
