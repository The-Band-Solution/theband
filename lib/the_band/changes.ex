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

  # ------------------------------------------------------------------- privados

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
