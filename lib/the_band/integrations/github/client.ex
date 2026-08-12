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

      # Etiquetada como transporte para que quem chama saiba que vale retentar,
      # sem precisar conhecer os structs de erro da biblioteca HTTP.
      {:error, %{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, reason} ->
        {:error, {:transport, reason}}
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

      {:error, %{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @doc """
  Traduz a falha para uma frase legível, dizendo o que aconteceu e o que fazer.

  **As frases vão para a tela** — a tela de ferramentas e a de repositório mostram este
  texto —, e por isso são em inglês, como todo texto de interface.

  Contrato: `contracts/github-connector.md`, seção "Contrato de mensagem".
  `%Req.TransportError{reason: :nxdomain}` não informa a quem opera que o
  endereço não pôde ser resolvido — e é essa pessoa que precisa decidir se
  confere a rede ou o cadastro.

  O motivo técnico não se perde: ele continua no log estruturado. Sai da
  mensagem, não do registro.
  """
  @spec describe_error(term()) :: String.t()
  def describe_error({:transport, :nxdomain}),
    do:
      "the instance address could not be resolved. Check the network connection " <>
        "and whether the registered address is correct"

  def describe_error({:transport, reason}) when reason in [:timeout, :closed, :econnrefused],
    do:
      "the instance did not answer in time or refused the connection. The collection " <>
        "will be retried"

  def describe_error({:transport, reason}),
    do:
      "network failure talking to the instance (#{inspect(reason)}). The collection will be " <>
        "retried"

  def describe_error(:unauthorized),
    do:
      "the tool refused the credential. It may have been revoked or expired — " <>
        "register a valid credential"

  def describe_error({:missing_scopes, escopos}),
    do:
      "the credential lacks the required scopes: #{Enum.join(escopos, ", ")}. " <>
        "Without them the collection would return zero teams, which is worse than failing"

  def describe_error({:organization_not_found, login}),
    do:
      "organisation #{inspect(login)} was not found on this instance. " <>
        "Use the organisation login — what comes after github.com/ — not the whole URL"

  def describe_error({:graphql_errors, [%{"message" => mensagem} | _]}),
    do: "the tool refused the query: #{mensagem}"

  def describe_error({:unexpected_status, status}) when status >= 500,
    do:
      "the instance answered with error #{status}. It is a source-server failure, and will be retried"

  def describe_error({:unexpected_status, status}),
    do: "the instance answered with unexpected status #{status}"

  def describe_error({:unexpected_status, status, _body}),
    do: describe_error({:unexpected_status, status})

  def describe_error(outro), do: "unclassified failure: #{inspect(outro)}"

  @doc """
  Diz se a falha é transitória — se vale retentar.

  A distinção importa porque tratá-las igual produz os dois erros opostos:
  desistir do que ia funcionar, e insistir no que nunca vai. Falha transitória
  **não** marca a sincronização como falha: ela permanece em andamento e o Oban
  retenta.

  **E não marca o repositório como inacessível.** Marcar o tira de
  `CMPO.list_collectable/2`, e nenhuma coleta seguinte o olha de novo — a marca é
  permanente na prática. Um `:nxdomain` de um instante custou 38 repositórios e 899 issues
  fora de toda observação, e o número só apareceu ao conferir a contagem contra a origem.
  """
  @spec transient?(term()) :: boolean()
  def transient?({:transport, _reason}), do: true
  def transient?({:unexpected_status, status}) when status >= 500, do: true
  def transient?({:unexpected_status, status, _body}) when status >= 500, do: true
  def transient?(_outro), do: false

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
