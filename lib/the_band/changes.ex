defmodule TheBand.Changes do
  @moduledoc """
  A leitura das mudanças — feature 032.

  Responde o rastreio nos dois sentidos: da issue para quem a implementou, e da pessoa
  para o que ela mudou. Cada função é **número fixo de consultas** — o defeito da feature
  007 (135 por render) nasceu de consultar por linha.

  ## As três leituras da pessoa nunca são somadas

  Abrir uma solicitação, integrá-la e executar um commit são atos distintos, com
  participações distintas na ontologia (`cmpo.stakeholder_submitted_change_request`,
  `cmpo.stakeholder_performed_checkin`, `cmpo.stakeholder_performed_commit`). Somá-las
  produziria um número de "contribuições" que não corresponde a nada.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  As solicitações que atendem uma issue — o rastro do escopo para a mudança.

  Uma consulta. Vazio significa "nenhuma solicitação reconhecida atende esta issue", e
  quem chama decide se isso é ausência de coleta ou ausência de vínculo, olhando
  `changes_collected_at` do repositório — as duas coisas nunca são a mesma frase.
  """
  @spec for_issue(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def for_issue(%Tenant{id: tenant_id}, issue_id) do
    Repo.all(
      from v in "change_request_issues",
        join: c in "collected_change_requests",
        on: c.id == v.collected_change_request_id,
        where:
          v.tenant_id == type(^tenant_id, :binary_id) and
            v.collected_issue_id == type(^issue_id, :binary_id) and
            is_nil(v.no_longer_observed_at) and
            is_nil(c.no_longer_observed_at),
        order_by: [desc: c.external_created_at],
        select: %{
          id: type(c.id, :binary_id),
          number: c.number,
          title: c.title,
          state: c.state,
          author_login: c.author_login,
          author_person_id: type(c.author_person_id, :binary_id),
          merged_by_login: c.merged_by_login,
          merged_by_person_id: type(c.merged_by_person_id, :binary_id),
          created_at: c.external_created_at,
          merged_at: c.external_merged_at,
          source_branch: c.source_branch,
          target_branch: c.target_branch
        }
    )
    |> Enum.map(&normalizar/1)
  end

  @doc "Uma solicitação pelo id, escopada por tenant."
  @spec get(Tenant.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, :not_found}
  def get(%Tenant{id: tenant_id}, id) do
    consulta =
      from c in "collected_change_requests",
        where: c.tenant_id == type(^tenant_id, :binary_id) and c.id == type(^id, :binary_id),
        select: %{
          id: type(c.id, :binary_id),
          observed_repository_id: type(c.observed_repository_id, :binary_id),
          number: c.number,
          title: c.title,
          body: c.body,
          state: c.state,
          author_login: c.author_login,
          author_person_id: type(c.author_person_id, :binary_id),
          merged_by_login: c.merged_by_login,
          merged_by_person_id: type(c.merged_by_person_id, :binary_id),
          created_at: c.external_created_at,
          merged_at: c.external_merged_at,
          closed_at: c.external_closed_at,
          source_branch: c.source_branch,
          target_branch: c.target_branch,
          changed_files: c.changed_files,
          commits_total: c.commits_total,
          commits_collected: c.commits_collected
        }

    case Repo.one(consulta) do
      # Id de outro tenant devolve :not_found, nunca o registro.
      nil -> {:error, :not_found}
      solicitacao -> {:ok, normalizar(solicitacao)}
    end
  end

  @doc """
  Os commits de uma solicitação, com **todos** os autores de cada um.

  Duas consultas: os commits, e os autores em lote. Uma consulta de autores por commit
  seria o defeito de sempre — e commits com dois autores são o caso comum aqui.
  """
  @spec commits_of(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def commits_of(%Tenant{id: tenant_id}, change_request_id) do
    commits =
      Repo.all(
        from c in "collected_commits",
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and
              c.change_request_id == type(^change_request_id, :binary_id) and
              is_nil(c.no_longer_observed_at),
          order_by: [asc: c.external_committed_at],
          select: %{
            id: type(c.id, :binary_id),
            sha: c.sha,
            headline: c.message_headline,
            committed_at: c.external_committed_at,
            additions: c.additions,
            deletions: c.deletions
          }
      )

    autores = autores_de(tenant_id, Enum.map(commits, & &1.id))

    Enum.map(commits, fn c ->
      c
      |> normalizar()
      |> Map.put(:autores, Map.get(autores, c.id, []))
    end)
  end

  @doc """
  As issues que uma solicitação atende — o outro sentido do rastro.
  """
  @spec attended_issues(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def attended_issues(%Tenant{id: tenant_id}, change_request_id) do
    Repo.all(
      from v in "change_request_issues",
        join: i in "collected_issues",
        on: i.id == v.collected_issue_id,
        where:
          v.tenant_id == type(^tenant_id, :binary_id) and
            v.collected_change_request_id == type(^change_request_id, :binary_id) and
            is_nil(v.no_longer_observed_at),
        order_by: [asc: i.number],
        select: %{
          id: type(i.id, :binary_id),
          number: i.number,
          title: i.title,
          state: i.state
        }
    )
  end

  @doc """
  O que uma pessoa mudou, em três leituras **nunca somadas**: as solicitações que abriu,
  as que integrou e os commits que executou.

  Três consultas, uma por leitura. A de commits inclui os casos em que a pessoa é
  co-autora e não autora principal — é `cmpo.stakeholder_performed_commit` com
  cardinalidade `many` na origem, e achatar isso apagaria autoria compartilhada.
  """
  @spec by_person(Tenant.t(), Ecto.UUID.t(), keyword()) :: map()
  def by_person(%Tenant{id: tenant_id}, person_id, opts \\ []) do
    limite = Keyword.get(opts, :limit, 20)

    %{
      abertas: solicitacoes_por_papel(tenant_id, person_id, :autor, limite),
      integradas: solicitacoes_por_papel(tenant_id, person_id, :integrador, limite),
      commits: commits_da_pessoa(tenant_id, person_id, limite)
    }
  end

  @doc """
  Lista as solicitações, com busca e paginação.

  A busca **lê a forma** do que foi digitado em vez de exigir que quem procura escolha o
  filtro antes: SHA, número, `@pessoa` ou palavras livres. Ver `interpretar_busca/1`.
  """
  @spec list(Tenant.t(), keyword()) :: [map()]
  def list(%Tenant{id: tenant_id}, opts \\ []) do
    limite = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    tenant_id
    |> consulta_de_lista(Keyword.get(opts, :search, ""))
    |> order_by([c], desc: c.external_created_at)
    |> limit(^limite)
    |> offset(^offset)
    |> select([c], %{
      id: type(c.id, :binary_id),
      number: c.number,
      title: c.title,
      state: c.state,
      author_login: c.author_login,
      author_person_id: type(c.author_person_id, :binary_id),
      merged_by_login: c.merged_by_login,
      created_at: c.external_created_at,
      merged_at: c.external_merged_at,
      # **A contagem é DERIVADA das entradas, nunca do contador gravado.** O campo
      # `commits_collected` existe e mentiria aqui: ele nasceu depois da primeira coleta,
      # e todo registro anterior a ela tem nulo — a tela mostraria "0 commits" para
      # solicitações que têm dez. É a regra da casa, e ela pegou este defeito na tela.
      commits_collected:
        fragment(
          "(SELECT count(*) FROM collected_commits co WHERE co.change_request_id = ? AND co.no_longer_observed_at IS NULL)",
          c.id
        ),
      # O total da ORIGEM continua vindo do campo: ele não é contável daqui, e é o que
      # revela truncamento.
      commits_total: c.commits_total
    })
    |> Repo.all()
    |> Enum.map(&normalizar/1)
  end

  @doc "Quantas solicitações a busca encontra — o denominador da paginação."
  @spec count(Tenant.t(), keyword()) :: non_neg_integer()
  def count(%Tenant{id: tenant_id}, opts \\ []) do
    tenant_id
    |> consulta_de_lista(Keyword.get(opts, :search, ""))
    |> Repo.aggregate(:count)
  end

  @doc """
  Os commits, com busca e paginação. Aceita `person_id` para escopar a uma pessoa —
  incluindo os commits em que ela é **co-autora**.
  """
  @spec list_commits(Tenant.t(), keyword()) :: [map()]
  def list_commits(%Tenant{id: tenant_id}, opts \\ []) do
    limite = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    tenant_id
    |> consulta_de_commits(Keyword.get(opts, :search, ""), Keyword.get(opts, :person_id))
    |> order_by([c], desc: c.external_committed_at)
    |> limit(^limite)
    |> offset(^offset)
    |> select([c, cr], %{
      id: type(c.id, :binary_id),
      sha: c.sha,
      headline: c.message_headline,
      committed_at: c.external_committed_at,
      additions: c.additions,
      deletions: c.deletions,
      change_request_id: type(cr.id, :binary_id),
      change_request_number: cr.number
    })
    |> Repo.all()
    |> Enum.map(&normalizar/1)
  end

  @doc "Quantos commits a busca encontra."
  @spec count_commits(Tenant.t(), keyword()) :: non_neg_integer()
  def count_commits(%Tenant{id: tenant_id}, opts \\ []) do
    tenant_id
    |> consulta_de_commits(Keyword.get(opts, :search, ""), Keyword.get(opts, :person_id))
    |> Repo.aggregate(:count)
  end

  @doc """
  A linha do tempo de uma issue: ela, as solicitações que a atendem e os commits delas,
  todos com os instantes que a origem entregou.

  **Nada é interpolado.** Cada marca é um instante observado — criação, fechamento,
  merge, commit. O que a tela desenha entre eles é o intervalo, e o **vão** entre a
  abertura da issue e a primeira mudança é a leitura que lista nenhuma dá.

  **Recebe as solicitações já carregadas** em vez de consultá-las de novo: a tela que a
  desenha já as tem para a seção de mudanças, e reconsultar era uma consulta a mais por
  render — o teste-guarda de custo pegou.
  """
  @spec timeline_of_issue(Tenant.t(), map(), [map()]) :: map()
  def timeline_of_issue(%Tenant{} = tenant, issue, solicitacoes) do
    commits =
      case solicitacoes do
        [] -> []
        _ -> commits_de(tenant, Enum.map(solicitacoes, & &1.id))
      end

    marcas =
      [issue.external_created_at, issue.external_closed_at] ++
        Enum.flat_map(solicitacoes, &[&1.created_at, &1.merged_at]) ++
        Enum.map(commits, & &1.committed_at)

    instantes = marcas |> Enum.reject(&is_nil/1) |> Enum.map(&para_utc/1)

    %{
      issue: issue,
      solicitacoes: solicitacoes,
      commits: commits,
      de: Enum.min_by(instantes, & &1, DateTime, fn -> nil end),
      ate: Enum.max_by(instantes, & &1, DateTime, fn -> nil end),
      # O vão: da abertura da issue até a primeira mudança registrada. `nil` quando não
      # há solicitação — e aí a ausência é a leitura.
      vao_ate_primeira: vao_ate_primeira(issue, solicitacoes)
    }
  end

  defp commits_de(%Tenant{id: tenant_id}, change_ids) do
    Repo.all(
      from c in "collected_commits",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.change_request_id in type(^change_ids, {:array, :binary_id}) and
            is_nil(c.no_longer_observed_at),
        order_by: [asc: c.external_committed_at],
        select: %{
          id: type(c.id, :binary_id),
          sha: c.sha,
          headline: c.message_headline,
          committed_at: c.external_committed_at,
          change_request_id: type(c.change_request_id, :binary_id)
        }
    )
    |> Enum.map(&normalizar/1)
  end

  defp vao_ate_primeira(%{external_created_at: nil}, _), do: nil
  defp vao_ate_primeira(_issue, []), do: nil

  defp vao_ate_primeira(issue, solicitacoes) do
    primeira =
      solicitacoes
      |> Enum.map(& &1.created_at)
      |> Enum.reject(&is_nil/1)
      |> Enum.min_by(& &1, DateTime, fn -> nil end)

    primeira && DateTime.diff(primeira, para_utc(issue.external_created_at), :second)
  end

  defp para_utc(%DateTime{} = dt), do: dt
  defp para_utc(%NaiveDateTime{} = dt), do: DateTime.from_naive!(dt, "Etc/UTC")

  @doc """
  Interpreta o que foi digitado, e **diz qual decisão tomou**.

  Devolve `{forma, valor}` — e a tela mostra a forma ao lado do campo. Sem isso, alguém
  procura um número de issue e recebe um commit cujo SHA começa igual, sem saber por quê.

      iex> TheBand.Changes.interpretar_busca("17e4f16")
      {:sha, "17e4f16"}
      iex> TheBand.Changes.interpretar_busca("#427")
      {:numero, 427}
      iex> TheBand.Changes.interpretar_busca("@ana")
      {:pessoa, "ana"}
      iex> TheBand.Changes.interpretar_busca("rastreio do commit")
      {:palavras, ["rastreio", "do", "commit"]}
  """
  @spec interpretar_busca(String.t()) :: {atom(), term()}
  def interpretar_busca(termo) when is_binary(termo) do
    termo = String.trim(termo)

    cond do
      termo == "" ->
        {:vazia, nil}

      # Sete ou mais hexadecimais: é SHA. Abaixo disso a chance de colidir com número
      # ou palavra é alta demais para decidir sozinho.
      Regex.match?(~r/^[0-9a-f]{7,40}$/i, termo) ->
        {:sha, String.downcase(termo)}

      Regex.match?(~r/^#?\d+$/, termo) ->
        {:numero, termo |> String.trim_leading("#") |> String.to_integer()}

      String.starts_with?(termo, "@") ->
        {:pessoa, String.trim_leading(termo, "@")}

      true ->
        # Várias palavras ESTREITAM, nunca alargam: quem digita duas está procurando o
        # que tem as duas. `OU` devolveria mais resultados a cada palavra digitada, que é
        # o contrário do que quem busca espera.
        {:palavras, String.split(termo, ~r/\s+/, trim: true)}
    end
  end

  # ------------------------------------------------------------------- privados

  defp consulta_de_lista(tenant_id, termo) do
    base =
      from c in "collected_change_requests",
        where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at)

    estreitar_lista(base, tenant_id, interpretar_busca(termo || ""))
  end

  # Uma cláusula por forma de busca: o `case` acumulava a interpretação e a consulta na
  # mesma função, e o Credo estava certo em recusar.
  defp estreitar_lista(base, _tenant_id, {:vazia, _}), do: base

  defp estreitar_lista(base, _tenant_id, {:numero, n}) do
    from c in base, where: c.number == ^n
  end

  defp estreitar_lista(base, _tenant_id, {:pessoa, login}) do
    from c in base,
      where: ilike(c.author_login, ^"%#{login}%") or ilike(c.merged_by_login, ^"%#{login}%")
  end

  # SHA numa lista de solicitações procura a que TEM o commit. Devolver vazio aqui diria
  # que o commit não existe, quando ele só não é uma solicitação.
  defp estreitar_lista(base, tenant_id, {:sha, sha}) do
    from c in base,
      where:
        c.id in subquery(
          from co in "collected_commits",
            where:
              co.tenant_id == type(^tenant_id, :binary_id) and
                ilike(co.sha, ^"#{sha}%") and not is_nil(co.change_request_id),
            select: co.change_request_id
        )
  end

  defp estreitar_lista(base, _tenant_id, {:palavras, palavras}) do
    Enum.reduce(palavras, base, fn palavra, consulta ->
      from c in consulta,
        where:
          ilike(c.title, ^"%#{palavra}%") or ilike(c.body, ^"%#{palavra}%") or
            ilike(c.source_branch, ^"%#{palavra}%")
    end)
  end

  defp consulta_de_commits(tenant_id, termo, person_id) do
    base =
      from c in "collected_commits",
        left_join: cr in "collected_change_requests",
        on: cr.id == c.change_request_id,
        where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at)

    base
    |> escopar_por_pessoa(tenant_id, person_id)
    |> estreitar_commits(tenant_id, interpretar_busca(termo || ""))
  end

  defp estreitar_commits(base, _tenant_id, {:vazia, _}), do: base

  defp estreitar_commits(base, _tenant_id, {:sha, sha}) do
    from [c, _cr] in base, where: ilike(c.sha, ^"#{sha}%")
  end

  defp estreitar_commits(base, _tenant_id, {:numero, n}) do
    from [_c, cr] in base, where: cr.number == ^n
  end

  defp estreitar_commits(base, tenant_id, {:pessoa, login}) do
    from [c, _cr] in base,
      where:
        c.id in subquery(
          from a in "commit_authors",
            where:
              a.tenant_id == type(^tenant_id, :binary_id) and
                ilike(a.author_login, ^"%#{login}%") and is_nil(a.no_longer_observed_at),
            select: a.collected_commit_id
        )
  end

  defp estreitar_commits(base, _tenant_id, {:palavras, palavras}) do
    Enum.reduce(palavras, base, fn palavra, consulta ->
      from [c, _cr] in consulta,
        where:
          ilike(c.message_headline, ^"%#{palavra}%") or ilike(c.message_body, ^"%#{palavra}%")
    end)
  end

  # Escopar por pessoa passa pelos AUTORES, e não por uma coluna do commit: é assim que
  # a co-autoria entra. Quem só participa como co-autor apareceria vazio de outro jeito.
  defp escopar_por_pessoa(consulta, _tenant_id, nil), do: consulta

  defp escopar_por_pessoa(consulta, tenant_id, person_id) do
    from [c, _cr] in consulta,
      where:
        c.id in subquery(
          from a in "commit_authors",
            where:
              a.tenant_id == type(^tenant_id, :binary_id) and
                a.author_person_id == type(^person_id, :binary_id) and
                is_nil(a.no_longer_observed_at),
            select: a.collected_commit_id
        )
  end

  defp solicitacoes_por_papel(tenant_id, person_id, papel, limite) do
    base =
      from c in "collected_change_requests",
        where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at),
        order_by: [desc: c.external_created_at],
        limit: ^limite,
        select: %{
          id: type(c.id, :binary_id),
          number: c.number,
          title: c.title,
          state: c.state,
          created_at: c.external_created_at,
          merged_at: c.external_merged_at
        }

    consulta =
      case papel do
        :autor ->
          from c in base, where: c.author_person_id == type(^person_id, :binary_id)

        :integrador ->
          from c in base, where: c.merged_by_person_id == type(^person_id, :binary_id)
      end

    consulta |> Repo.all() |> Enum.map(&normalizar/1)
  end

  defp commits_da_pessoa(tenant_id, person_id, limite) do
    Repo.all(
      from a in "commit_authors",
        join: c in "collected_commits",
        on: c.id == a.collected_commit_id,
        left_join: cr in "collected_change_requests",
        on: cr.id == c.change_request_id,
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            a.author_person_id == type(^person_id, :binary_id) and
            is_nil(a.no_longer_observed_at) and
            is_nil(c.no_longer_observed_at),
        order_by: [desc: c.external_committed_at],
        limit: ^limite,
        select: %{
          id: type(c.id, :binary_id),
          sha: c.sha,
          headline: c.message_headline,
          committed_at: c.external_committed_at,
          # `false` aqui significa co-autoria: a pessoa entrou pelo trailer
          # Co-Authored-By, e a tela diz isso em vez de apresentar como autoria única.
          is_primary: a.is_primary,
          change_request_id: type(cr.id, :binary_id),
          change_request_number: cr.number
        }
    )
    |> Enum.map(&normalizar/1)
  end

  defp autores_de(_tenant_id, []), do: %{}

  defp autores_de(tenant_id, commit_ids) do
    Repo.all(
      from a in "commit_authors",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            a.collected_commit_id in type(^commit_ids, {:array, :binary_id}) and
            is_nil(a.no_longer_observed_at),
        order_by: [desc: a.is_primary],
        select: %{
          commit_id: type(a.collected_commit_id, :binary_id),
          login: a.author_login,
          person_id: type(a.author_person_id, :binary_id),
          name: a.author_name,
          is_primary: a.is_primary
        }
    )
    |> Enum.group_by(& &1.commit_id)
  end

  # As consultas são schemaless e o Postgrex devolve NaiveDateTime — normalizar aqui
  # evita que cada chamador descubra do jeito difícil.
  defp normalizar(registro) do
    Map.new(registro, fn
      {chave, %NaiveDateTime{} = dt} ->
        {chave, dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:second)}

      {chave, valor} ->
        {chave, valor}
    end)
  end
end
