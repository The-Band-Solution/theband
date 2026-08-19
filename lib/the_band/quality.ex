defmodule TheBand.Quality do
  @moduledoc """
  A leitura das avaliações de artefato — `qapo.artifact_evaluation`, feature 039.

  ## O que a QAPO obriga esta leitura a não afirmar

  `qapo.artifact_evaluation` é a atividade que "avalia objetivamente a aderência". Ela não
  atesta conformidade: o mapeamento declara que **aprovação é ausência de bloqueio, não
  ausência de não conformidade**. Então nenhuma função aqui devolve "conforme" — devolvem o
  estado cru, e a tela mostra o que a origem disse.

  ## Bot é separado de pessoa em toda contagem

  A limitação do mapeamento manda classificá-los à parte, e o motivo é a medida: se a
  primeira "revisão" de uma solicitação foi um bot, o tempo até a primeira revisão humana
  continua correndo. Somá-los mediria o robô.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @humano "User"

  @doc """
  As avaliações de uma solicitação, em ordem de submissão.

  Uma consulta. Vazio significa "nenhuma avaliação coletada", e quem chama distingue isso
  de "não revisada" olhando `reviews_total` da solicitação — as duas frases nunca são a
  mesma.
  """
  @spec for_change_request(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def for_change_request(%Tenant{id: tenant_id}, change_request_id) do
    Repo.all(
      from a in "collected_artifact_evaluations",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            a.collected_change_request_id == type(^change_request_id, :binary_id) and
            is_nil(a.no_longer_observed_at),
        order_by: [asc_nulls_last: a.external_submitted_at],
        select: %{
          id: type(a.id, :binary_id),
          state: a.state,
          body: a.body,
          submitted_at: a.external_submitted_at,
          author_login: a.author_login,
          author_type: a.author_type,
          author_person_id: type(a.author_person_id, :binary_id)
        }
    )
  end

  @doc """
  O tempo até a primeira revisão **humana** — a medida
  `review_time_to_first_review_duration`, que estava escrita e sem dado.

  Devolve uma linha por solicitação avaliada, com o intervalo em segundos entre a abertura e
  a primeira avaliação submetida por pessoa.

  ## Os três filtros são da medida, não da conveniência

  `submitted_at` não nulo exclui rascunho — a medida diz "excluir solicitações em rascunho".
  `author_type = "User"` exclui bot — "revisões automáticas devem ser excluídas ou
  classificadas separadamente". E `min` porque a pergunta é sobre a **primeira**.

  Solicitação sem avaliação humana **não aparece**: ela não tem tempo até a primeira
  revisão, e devolvê-la com zero afirmaria revisão instantânea.
  """
  @spec time_to_first_review(Tenant.t(), keyword()) :: [map()]
  def time_to_first_review(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from c in "collected_change_requests",
        join: a in "collected_artifact_evaluations",
        on: a.collected_change_request_id == c.id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at) and
            is_nil(a.no_longer_observed_at) and not is_nil(a.external_submitted_at) and
            a.author_type == @humano,
        group_by: [c.id, c.number, c.title, c.external_created_at],
        order_by: [desc: c.external_created_at],
        limit: ^Keyword.get(opts, :limit, 50),
        select: %{
          id: type(c.id, :binary_id),
          number: c.number,
          title: c.title,
          opened_at: c.external_created_at,
          first_review_at: min(a.external_submitted_at),
          seconds:
            fragment(
              "extract(epoch from (min(?) - ?))::bigint",
              a.external_submitted_at,
              c.external_created_at
            )
        }
    )
  end

  @doc """
  O painel: quantas solicitações foram avaliadas por pessoa, por bot, e quantas por ninguém.

  **Uma consulta**, e as três colunas nunca somam entre si porque medem coisas diferentes.
  `nao_medido` é solicitação coletada antes de a plataforma guardar `reviews_total` — nulo é
  desconhecido, nunca zero.
  """
  @spec resumo(Tenant.t()) :: map()
  def resumo(%Tenant{id: tenant_id}) do
    linhas =
      Repo.all(
        from c in "collected_change_requests",
          left_join: a in "collected_artifact_evaluations",
          on: a.collected_change_request_id == c.id and is_nil(a.no_longer_observed_at),
          where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.no_longer_observed_at),
          group_by: c.id,
          select: %{
            total: c.reviews_total,
            humanas: fragment("count(?) filter (where ? = ?)", a.id, a.author_type, @humano),
            de_bot: fragment("count(?) filter (where ? <> ?)", a.id, a.author_type, @humano)
          }
      )

    %{
      avaliadas_por_pessoa: Enum.count(linhas, &(&1.humanas > 0)),
      so_por_bot: Enum.count(linhas, &(&1.humanas == 0 and &1.de_bot > 0)),
      sem_avaliacao: Enum.count(linhas, &(&1.total == 0)),
      nao_medido: Enum.count(linhas, &is_nil(&1.total))
    }
  end

  @doc """
  Quem revisou o quê — a participação `qapo.stakeholder_performed_artifact_evaluation`.

  Bot aparece com `person_id` nulo e não é somado a pessoa: forçar uma pessoa para o robô
  inventaria participação que não existe.
  """
  @spec by_reviewer(Tenant.t(), keyword()) :: [map()]
  def by_reviewer(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from a in "collected_artifact_evaluations",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and is_nil(a.no_longer_observed_at) and
            not is_nil(a.external_submitted_at),
        group_by: [a.author_login, a.author_type, a.author_person_id],
        order_by: [desc: count(a.id)],
        limit: ^Keyword.get(opts, :limit, 50),
        select: %{
          login: a.author_login,
          author_type: a.author_type,
          person_id: type(a.author_person_id, :binary_id),
          evaluations: count(a.id),
          approved: fragment("count(?) filter (where ? = 'APPROVED')", a.id, a.state),
          changes_requested:
            fragment("count(?) filter (where ? = 'CHANGES_REQUESTED')", a.id, a.state)
        }
    )
  end
end
