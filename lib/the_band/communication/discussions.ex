defmodule TheBand.Communication.Discussions do
  @moduledoc """
  A leitura da comunicação — feature 030.

  Aqui nascem os **derivados** da CMO: o ato de comentar (um por comentário, no
  `external_published_at`), a discussão (o conjunto dos comentários de um artefato) e a
  participação (`cmo.discussion_participation` — pessoa × discussão, fundada nos atos).
  Nenhum deles é armazenado: são calculados na leitura, e por isso carregam hachura e
  rótulo de derivado na tela.

  ## Número fixo de consultas

  Uma por função, sempre — inclusive `last_act_for_issues/2`, que resolve N issues numa
  consulta agregada. Consulta por linha é o defeito que a feature 007 pagou com 135 por
  render.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type comentario :: %{
          id: Ecto.UUID.t(),
          body: String.t() | nil,
          author_login: String.t() | nil,
          author_person_id: Ecto.UUID.t() | nil,
          published_at: DateTime.t() | nil,
          edited_at: DateTime.t() | nil,
          no_longer_observed_at: DateTime.t() | nil
        }

  # A consulta é schemaless, e o Postgrex devolve NaiveDateTime — normalizar aqui evita
  # que cada chamador descubra isso do jeito difícil (mesma decisão do TeamSkills).
  defp utc(nil), do: nil
  defp utc(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp utc(%NaiveDateTime{} = dt),
    do: dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:second)

  @doc """
  A discussão de uma issue: os comentários vigentes, em ordem de publicação.

  Comentário não mais observado (apagado na origem) NÃO entra — mas a marca fica no
  banco: marca, nunca apaga.
  """
  @spec for_issue(Tenant.t(), Ecto.UUID.t()) :: [comentario()]
  def for_issue(%Tenant{id: tenant_id}, collected_issue_id) do
    Repo.all(
      from c in "collected_issue_comments",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.collected_issue_id == type(^collected_issue_id, :binary_id) and
            is_nil(c.no_longer_observed_at),
        order_by: [asc: c.external_published_at],
        select: %{
          id: type(c.id, :binary_id),
          body: c.body,
          author_login: c.author_login,
          author_person_id: type(c.author_person_id, :binary_id),
          published_at: c.external_published_at,
          edited_at: c.external_edited_at,
          no_longer_observed_at: c.no_longer_observed_at
        }
    )
    |> Enum.map(&%{&1 | published_at: utc(&1.published_at), edited_at: utc(&1.edited_at)})
  end

  @doc """
  As discussões de que uma pessoa participou: issue, contagem de atos, primeiro e
  último. Uma consulta agregada, nunca uma por issue.

  É `cmo.discussion_participation` materializada na leitura — e a contagem é de **atos
  de comentar**, não de tarefas: participação nunca é apresentada como execução.
  """
  @spec participation_of(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def participation_of(%Tenant{id: tenant_id}, person_id, opts \\ []) do
    limite = Keyword.get(opts, :limit, 50)

    Repo.all(
      from c in "collected_issue_comments",
        join: i in "collected_issues",
        on: i.id == c.collected_issue_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.author_person_id == type(^person_id, :binary_id) and
            is_nil(c.no_longer_observed_at),
        group_by: [i.id, i.number, i.title, i.state],
        order_by: [desc: max(c.external_published_at)],
        limit: ^limite,
        select: %{
          issue_id: type(i.id, :binary_id),
          number: i.number,
          title: i.title,
          state: i.state,
          atos: count(c.id),
          primeiro: min(c.external_published_at),
          ultimo: max(c.external_published_at)
        }
    )
    |> Enum.map(&%{&1 | primeiro: utc(&1.primeiro), ultimo: utc(&1.ultimo)})
  end

  @doc """
  O último ato de comentar de cada issue da lista — uma consulta para N issues.

  Issue ausente do mapa devolvido **não tem discussão coletada**: quem chama decide se
  isso significa "sem conversa" ou "coleta não passou", olhando `comments_collected_at`
  do repositório. As duas coisas nunca são a mesma frase na tela.
  """
  @spec last_act_for_issues(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => map()}
  def last_act_for_issues(_tenant, []), do: %{}

  def last_act_for_issues(%Tenant{id: tenant_id}, issue_ids) do
    Repo.all(
      from c in "collected_issue_comments",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
            is_nil(c.no_longer_observed_at),
        group_by: c.collected_issue_id,
        select: {
          type(c.collected_issue_id, :binary_id),
          %{atos: count(c.id), ultimo: max(c.external_published_at)}
        }
    )
    |> Map.new(fn {id, dados} -> {id, %{dados | ultimo: utc(dados.ultimo)}} end)
  end
end
