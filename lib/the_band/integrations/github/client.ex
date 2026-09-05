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
  Busca os arquivos de um commit — **REST, e não GraphQL**.

  Medido em 2026-08-18: o GraphQL expõe `changedFilesIfAvailable` (a contagem) e a
  `tree` (a árvore inteira do repositório naquele commit), mas **não o diff**. A lista de
  arquivos alterados só existe na REST, e é uma requisição por commit — o que decidiu o
  escopo da coleta (issue #429).
  """
  @spec commit_files(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, term()}
  def commit_files(instance_url, token, repositorio, sha) do
    url = api_base(instance_url) <> "/repos/#{repositorio}/commits/#{sha}"

    with {:ok, body} <- url |> HTTP.impl().get(token) |> resposta_rest() do
      {:ok, body["files"] || []}
    end
  end

  @doc """
  As execuções de verificação de um repositório — REST, e também sem alternativa.

  O GraphQL do GitHub expõe `CheckSuite` e `CheckRun`, que são a camada de *checks*; o
  **workflow run** do Actions — com `event`, `run_attempt` e `conclusion` — só existe na
  REST. Como `event` é o que decide o subtipo da CIRO e `conclusion` decide a fase,
  coletar pelo GraphQL perderia justamente os dois eixos que o modelo separa.

  `created` aceita o filtro `>=AAAA-MM-DD`, e é o incremental: ao contrário de
  `pullRequests`, aqui a origem filtra por data e não é preciso parar cedo na paginação.
  """
  @spec workflow_runs(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, %{total: integer(), runs: [map()]}} | {:error, term()}
  def workflow_runs(instance_url, token, repositorio, opcoes \\ []) do
    pagina = Keyword.get(opcoes, :page, 1)
    por_pagina = Keyword.get(opcoes, :per_page, 100)
    desde = Keyword.get(opcoes, :since)

    consulta =
      [{"per_page", por_pagina}, {"page", pagina}]
      |> then(fn q ->
        if desde, do: q ++ [{"created", ">=" <> Date.to_iso8601(desde)}], else: q
      end)
      |> URI.encode_query()

    url = api_base(instance_url) <> "/repos/#{repositorio}/actions/runs?" <> consulta

    with {:ok, body} <- url |> HTTP.impl().get(token) |> resposta_rest() do
      {:ok, %{total: body["total_count"] || 0, runs: body["workflow_runs"] || []}}
    end
  end

  @doc """
  Os jobs de uma execução — os processos componentes que ela materializou.

  `filter=latest` é deliberado: numa reexecução, o que interessa é a tentativa vigente.
  Trazer todas faria o mesmo job aparecer duas vezes e a contagem de componentes mentir.
  """
  @spec run_jobs(String.t(), String.t(), String.t(), integer()) ::
          {:ok, %{total: integer(), jobs: [map()]}} | {:error, term()}
  def run_jobs(instance_url, token, repositorio, run_id) do
    url =
      api_base(instance_url) <>
        "/repos/#{repositorio}/actions/runs/#{run_id}/jobs?per_page=100&filter=latest"

    with {:ok, body} <- url |> HTTP.impl().get(token) |> resposta_rest() do
      {:ok, %{total: body["total_count"] || 0, jobs: body["jobs"] || []}}
    end
  end

  defp resposta_rest({:ok, %{status: 200, body: body}}), do: {:ok, body}

  # **403 com a janela zerada é rate limit, não credencial recusada.** O GitHub usa o
  # mesmo status para as duas coisas, e `x-ratelimit-remaining: 0` é o que distingue.
  # Tratar como credencial faria a coleta parar e marcar a ferramenta por engano.
  defp resposta_rest({:ok, %{status: status, headers: headers}})
       when status in [403, 429] do
    if esgotou_janela?(headers) do
      {:error, {:rate_limited, reset_de(headers)}}
    else
      {:error, :unauthorized}
    end
  end

  defp resposta_rest({:ok, %{status: 401}}), do: {:error, :unauthorized}

  # 404 num commit que a plataforma já coletou significa que ele saiu da origem —
  # force-push reescreve história. É fato sobre o repositório, não falha da coleta.
  defp resposta_rest({:ok, %{status: 404}}), do: {:error, :not_found_at_source}

  defp resposta_rest({:ok, %{status: status}}), do: {:error, {:unexpected_status, status}}
  defp resposta_rest({:error, %{reason: reason}}), do: {:error, {:transport, reason}}
  defp resposta_rest({:error, reason}), do: {:error, {:transport, reason}}

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

  # Truncado **aqui**, onde a mensagem é montada, e não pela largura da coluna: o texto vem da
  # origem e não tem tamanho garantido. Antes desta truncagem, a coluna era `varchar(255)` com
  # 27 caracteres de folga, e um valor maior derrubaria a fase de coleta — a L05.
  def describe_error({:graphql_errors, [%{"message" => mensagem} | _]}),
    do: "the tool refused the query: #{String.slice(mensagem, 0, 400)}"

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

  # Erro de GraphQL chega com **sucesso de transporte** — HTTP 200 e `errors` no corpo —, e
  # antes desta cláusula caía no caso geral como permanente. Foi assim que uma falha interna
  # da origem, de 2026-08-12 às 12:32:29, tirou um repositório de circulação: a mensagem pede
  # para reportar o incidente com um identificador, o que é o oposto de permanente.
  #
  # **Numa lista, vence o permanente.** A origem pode responder "não encontrado" para um campo
  # e falha interna para outro; tratar como transitório faria a plataforma insistir num
  # recurso que não existe.
  def transient?({:graphql_errors, errors}) when is_list(errors) and errors != [],
    do: Enum.all?(errors, &erro_do_momento?/1)

  def transient?(_outro), do: false

  # O rate limit chega aqui quando a pausa não o alcançou antes — e ele se cura esperando.
  #
  # **A origem usa DUAS grafias**, medido em 2026-09-04 numa coleta real que esgotou a cota:
  #
  #     %{"type" => "RATE_LIMITED"}                          o que o código conhecia
  #     %{"type" => "RATE_LIMIT", "code" => "graphql_rate_limit",
  #       "message" => "API rate limit already exceeded for user ID ..."}
  #
  # Com só a primeira, a segunda caía na cláusula do erro permanente logo abaixo: sem
  # `snooze`, cinco tentativas queimadas em minutos, e o sync inteiro em `failed` — quando
  # bastava esperar a janela reabrir. O dado já coletado ficava, e a coleta parava de vez.
  #
  # A lista é FECHADA de propósito. Casar por `String.contains?("RATE")` pegaria também um
  # erro de outra família que mencionasse a palavra, e insistir num erro permanente é o
  # oposto do que esta função existe para decidir.
  @tipos_de_rate_limit ~w(RATE_LIMITED RATE_LIMIT)

  defp erro_do_momento?(%{"type" => tipo}) when tipo in @tipos_de_rate_limit, do: true

  # O `code` é a segunda testemunha: a resposta que trouxe `RATE_LIMIT` também trouxe
  # `graphql_rate_limit` ali. Se a origem mudar o `type` de novo, o `code` ainda decide.
  defp erro_do_momento?(%{"code" => "graphql_rate_limit"}), do: true

  # "Não encontrado" e "sem escopo" se repetem: o repositório não existe, ou a credencial não
  # o alcança. Escopo não muda sozinho.
  defp erro_do_momento?(%{"type" => tipo}) when is_binary(tipo), do: false

  # Sem `type`, decide a mensagem. A assinatura da falha interna da origem é estável e vem
  # com identificador de incidente — é o payload que produziu a 39ª marca no dado real.
  defp erro_do_momento?(%{"message" => mensagem}) when is_binary(mensagem),
    do: String.contains?(mensagem, "Something went wrong while executing your query")

  # O desconhecido é **permanente**, e a ordem das correções é a razão: marcar de menos
  # deixaria repositório apagado sendo consultado a cada coleta, para sempre. Marcar de mais
  # deixou de ser permanente, porque a coleta seguinte tenta de novo.
  defp erro_do_momento?(_erro), do: false

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

  @doc """
  Este erro é o limite de taxa da origem? — e portanto **se cura esperando**, e não
  tentando de novo.

  Existe separada de `transient?/1` porque as duas decisões são diferentes. Transitório
  responde *"vale insistir?"*; esta responde *"insistir AGORA adianta?"* — e para o rate
  limit a resposta é **não**: a janela leva até uma hora, e as tentativas do Oban se
  esgotam em minutos.

  Medido em 2026-09-04: uma coleta real esgotou a cota, o erro foi classificado como
  transitório, o Oban retentou cinco vezes em poucos minutos, e o job foi descartado —
  todas as tentativas dentro da mesma janela fechada.
  """
  @spec rate_limit?(term()) :: boolean()
  def rate_limit?({:graphql_errors, errors}) when is_list(errors),
    do: Enum.any?(errors, &erro_de_taxa?/1)

  def rate_limit?({:rate_limited, _reset}), do: true
  def rate_limit?(_outro), do: false

  defp erro_de_taxa?(%{"type" => tipo}) when tipo in @tipos_de_rate_limit, do: true
  defp erro_de_taxa?(%{"code" => "graphql_rate_limit"}), do: true
  defp erro_de_taxa?(_outro), do: false

  @doc """
  Quantos segundos faltam para a janela reabrir.

  Consulta `/rate_limit`, que **não consome cota** — é a única chamada possível com a
  cota esgotada. Quando ela própria falha, devolve o padrão em vez de levantar: não saber
  quanto falta não é motivo para desistir da coleta.
  """
  @spec segundos_ate_reabrir(String.t(), String.t(), non_neg_integer()) :: non_neg_integer()
  def segundos_ate_reabrir(instance_url, token, padrao \\ 900) do
    case HTTP.impl().get(api_base(instance_url) <> "/rate_limit", token) do
      {:ok, %{status: 200, body: %{"resources" => %{"graphql" => %{"reset" => reset}}}}} ->
        # Um minuto de folga: reabrir no instante exato do reset às vezes ainda recusa.
        max(reset - System.system_time(:second) + 60, 60)

      _ ->
        padrao
    end
  end

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

  defp esgotou_janela?(headers) do
    cabecalho(headers, "x-ratelimit-remaining") == "0"
  end

  defp reset_de(headers) do
    case cabecalho(headers, "x-ratelimit-reset") do
      nil ->
        # Sem o cabeçalho, uma janela inteira é o palpite seguro: o GitHub as conta por
        # hora, e chutar menos faria a espera não resolver nada.
        DateTime.add(DateTime.utc_now(), 3600, :second)

      valor ->
        case Integer.parse(valor) do
          {epoch, _} -> DateTime.from_unix!(epoch)
          :error -> DateTime.add(DateTime.utc_now(), 3600, :second)
        end
    end
  end

  defp cabecalho(headers, nome) when is_map(headers) do
    case Map.get(headers, nome) do
      [valor | _] -> valor
      valor when is_binary(valor) -> valor
      _ -> nil
    end
  end

  defp cabecalho(headers, nome) when is_list(headers) do
    Enum.find_value(headers, fn
      {chave, valor} -> if String.downcase(to_string(chave)) == nome, do: to_string(valor)
      _ -> nil
    end)
  end

  defp cabecalho(_headers, _nome), do: nil
end
