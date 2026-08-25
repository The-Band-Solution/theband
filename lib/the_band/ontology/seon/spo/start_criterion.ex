defmodule TheBand.Ontology.SEON.SPO.StartCriterion do
  @moduledoc """
  Declarar, revogar e **resolver** o critério de início — issue #370.

  ## A escala, e por que ela existe

  Um projeto pode ter mais de um quadro (feature 041), e quadros podem ter processos
  diferentes. A precedência é:

      1. o quadro que declarou
      2. o projeto que declarou
      3. nulo — e a tela conta quantos

  Quadro **sem** critério não vence: ele só entra na escala quando declarou.

  ## O desempate, e as duas datas que não servem

  Quando a issue está em mais de um quadro com critério, vence o de
  `spo_project_boards.linked_at` **mais recente** — a data em que alguém associou o quadro ao
  projeto.

  `collected_at` foi descartado com medição: empata em **0,0 segundo em 100% dos 414 casos**
  medidos em 2026-08-24, porque as duas linhas são gravadas na mesma varredura. Ordenar por
  ele devolveria resultado não-determinístico. E ele significa *quando nós olhamos*, não
  quando a organização decidiu.

  `AddedToProjectV2Event` também não serve: o payload coletado tem `__typename`, `actor` e
  `createdAt` — **não identifica o quadro**.

  ## Empate real não é desempatado

  Dois vínculos com o mesmo `linked_at` — associação em lote, que é o jeito natural de povoar
  um projeto — devolvem `criterio_ambiguo`. Escolher o primeiro faria exatamente o que a
  `FR-007` da feature 022 proíbe, num lugar onde ninguém procuraria.

  ## Resolução em LOTE, e não por issue

  `resolve_start/2` recebe lista e devolve mapa. Com 19.200 atividades, a versão unitária é
  N+1 — e a decisão de resolver na leitura só se sustenta em lote.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.ActivityStartCriterion
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @typedoc "O alvo da declaração: o projeto da SPO, ou o quadro do Projects v2."
  @type alvo :: {:project, Ecto.UUID.t()} | {:board, Ecto.UUID.t()}

  @typedoc "De onde o critério aplicado veio — a FR-013 exige mostrar isto junto do número."
  @type origem :: {:board, Ecto.UUID.t(), String.t()} | {:project, Ecto.UUID.t(), String.t()}

  @doc """
  Declara o critério de um alvo. Redeclarar **revoga o anterior** e cria o novo.

  Não é `update`: a `FR-010` manda preservar quem declarou antes, e sobrescrever apagaria o
  histórico da decisão.

  `{:error, :unknown_event_type}` quando o tipo não existe na coleta — retorno, e não exceção,
  porque é erro previsto de negócio (princípio VIII).
  """
  @spec declare(Tenant.t(), alvo(), String.t(), Ecto.UUID.t()) ::
          {:ok, ActivityStartCriterion.t()} | {:error, :unknown_event_type | Ecto.Changeset.t()}
  def declare(%Tenant{id: tenant_id} = tenant, alvo, event_type, actor_id) do
    if coletado?(tenant, event_type),
      do: Repo.transaction(fn -> substituir(tenant, tenant_id, alvo, event_type, actor_id) end),
      else: {:error, :unknown_event_type}
  end

  defp coletado?(tenant, event_type) do
    event_type in Enum.map(collected_event_types(tenant), & &1.event_type)
  end

  # Revoga e insere na mesma transação. **Não é `update`**: a FR-010 manda preservar quem
  # declarou antes, e sobrescrever apagaria o histórico da decisão.
  defp substituir(tenant, tenant_id, alvo, event_type, actor_id) do
    agora = DateTime.utc_now(:second)
    revogar_vigente(tenant, alvo, actor_id, agora)

    attrs =
      Map.merge(campo_do_alvo(alvo), %{
        tenant_id: tenant_id,
        event_type: event_type,
        declared_by_user_id: actor_id,
        declared_at: agora
      })

    case Repo.insert(ActivityStartCriterion.changeset(%ActivityStartCriterion{}, attrs)) do
      {:ok, criterio} -> criterio
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @doc "Revoga o critério vigente de um alvo — **marca**, e nunca apaga."
  @spec revoke(Tenant.t(), alvo(), Ecto.UUID.t()) ::
          {:ok, ActivityStartCriterion.t()} | {:error, :not_found}
  def revoke(%Tenant{} = tenant, alvo, actor_id) do
    case current(tenant, alvo) do
      nil ->
        {:error, :not_found}

      criterio ->
        agora = DateTime.utc_now(:second)
        {1, _} = marcar_revogado(criterio.id, actor_id, agora)
        {:ok, %{criterio | revoked_at: agora, revoked_by_user_id: actor_id}}
    end
  end

  @doc "O critério **vigente** daquele alvo, sem escala. É o que a tela de declaração mostra."
  @spec current(Tenant.t(), alvo()) :: ActivityStartCriterion.t() | nil
  def current(%Tenant{id: tenant_id}, alvo) do
    Repo.one(
      from c in ActivityStartCriterion,
        where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at),
        where: ^condicao_do_alvo(alvo)
    )
  end

  @doc """
  Os quadros do projeto que **têm critério próprio** — e que portanto vão ignorar a declaração
  do projeto.

  Existe para a `FR-014`: a tela precisa dizer isso **antes** de a pessoa gravar. Depois seria
  informação inútil.
  """
  @spec boards_overriding(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def boards_overriding(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from c in ActivityStartCriterion,
        join: v in "spo_project_boards",
        on: v.observed_project_id == c.observed_project_id and is_nil(v.unlinked_at),
        join: q in "observed_projects",
        on: q.id == c.observed_project_id,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at) and
            v.project_id == type(^project_id, :binary_id),
        select: %{
          id: type(c.observed_project_id, :binary_id),
          title: q.title,
          event_type: c.event_type
        }
    )
  end

  @doc """
  Os tipos de evento que a coleta traz, com o volume de cada um — `FR-012`.

  **Não recomenda.** Devolver "sugerido" faria a plataforma escolher com passos extras, que é
  o que a `FR-007` da feature 022 proíbe. Mostrar volume é informar; recomendar é escolher.
  """
  @spec collected_event_types(Tenant.t()) :: [%{event_type: String.t(), occurrences: integer()}]
  def collected_event_types(%Tenant{id: tenant_id}) do
    Repo.all(
      from a in "spo_performed_project_activities",
        where: a.tenant_id == type(^tenant_id, :binary_id) and not is_nil(a.activity_type),
        group_by: a.activity_type,
        order_by: [desc: count(a.id)],
        select: %{event_type: a.activity_type, occurrences: count(a.id)}
    )
  end

  @typedoc """
  O que a resolução devolve por issue.

  As três ausências são **valores distintos, nunca `nil`** — `nil` colapsaria as três, e a
  `FR-009` proíbe agregá-las. Cada uma vira uma frase diferente na tela, e cada frase diz o
  que fazer.
  """
  @type resolucao ::
          {:ok, DateTime.t(), origem()}
          | {:missing, :sem_criterio}
          | {:missing, {:criterio_ambiguo, [map()]}}
          | {:missing, {:evento_nao_coletado, String.t()}}

  @doc """
  O instante de início de cada issue, resolvido pela escala — **em lote**.

  Recebe lista e devolve mapa. Nunca uma issue por chamada: com 19.200 atividades a versão
  unitária é N+1, e a decisão de resolver na leitura só se sustenta em lote.

  ## A origem acompanha o instante

  `{:ok, quando, origem}` — e a origem diz de qual quadro ou projeto o critério veio. A
  `FR-013` exige que a tela mostre isso junto do número, e devolver só o `DateTime` tornaria
  a proveniência impossível sem segunda consulta.

  ## Vale a PRIMEIRA ocorrência

  Uma tarefa que voltou ao Backlog e saiu de novo começou quando começou — `FR-011`.
  Recomeçar não apaga o começo.
  """
  @spec resolve_start(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => resolucao()}
  def resolve_start(_tenant, []), do: %{}

  def resolve_start(%Tenant{} = tenant, issue_ids) do
    criterios = criterio_por_issue(tenant, issue_ids)
    tipos = criterios |> Map.values() |> Enum.flat_map(&tipos_de/1) |> Enum.uniq()
    primeiros = primeira_ocorrencia(tenant, issue_ids, tipos)

    Map.new(issue_ids, fn issue_id ->
      {issue_id, resolver_uma(Map.get(criterios, issue_id), issue_id, primeiros)}
    end)
  end

  defp tipos_de({:ok, _origem, event_type}), do: [event_type]
  defp tipos_de(_), do: []

  defp resolver_uma(nil, _issue_id, _primeiros), do: {:missing, :sem_criterio}

  defp resolver_uma({:ambiguo, quadros}, _issue_id, _primeiros),
    do: {:missing, {:criterio_ambiguo, quadros}}

  defp resolver_uma({:ok, origem, event_type}, issue_id, primeiros) do
    case Map.get(primeiros, {issue_id, event_type}) do
      nil -> {:missing, {:evento_nao_coletado, event_type}}
      quando -> {:ok, quando, origem}
    end
  end

  # A escala, aplicada em UMA consulta para todas as issues.
  #
  #   1. quadro que declarou — desempate por `linked_at` mais recente
  #   2. projeto que declarou
  #   3. nada
  #
  # Empate real de `linked_at` não é desempatado: devolve `:ambiguo`, e a plataforma NÃO
  # escolhe. Escolher o primeiro faria o que a FR-007 da feature 022 proíbe, num lugar onde
  # ninguém procuraria.
  defp criterio_por_issue(%Tenant{id: tenant_id}, issue_ids) do
    pelo_quadro =
      Repo.all(
        from i in "project_items",
          join: v in "spo_project_boards",
          on: v.observed_project_id == i.observed_project_id and is_nil(v.unlinked_at),
          join: c in ActivityStartCriterion,
          on: c.observed_project_id == i.observed_project_id and is_nil(c.revoked_at),
          join: q in "observed_projects",
          on: q.id == i.observed_project_id,
          where:
            i.tenant_id == type(^tenant_id, :binary_id) and
              i.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
              is_nil(i.no_longer_observed_at),
          select: %{
            issue_id: type(i.collected_issue_id, :binary_id),
            board_id: type(i.observed_project_id, :binary_id),
            title: q.title,
            event_type: c.event_type,
            linked_at: v.linked_at
          }
      )

    pelo_projeto =
      Repo.all(
        from i in "project_items",
          join: v in "spo_project_boards",
          on: v.observed_project_id == i.observed_project_id and is_nil(v.unlinked_at),
          join: c in ActivityStartCriterion,
          on: c.project_id == v.project_id and is_nil(c.revoked_at),
          join: p in "spo_projects",
          on: p.id == v.project_id,
          where:
            i.tenant_id == type(^tenant_id, :binary_id) and
              i.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
              is_nil(i.no_longer_observed_at),
          select: %{
            issue_id: type(i.collected_issue_id, :binary_id),
            project_id: type(v.project_id, :binary_id),
            name: p.name,
            event_type: c.event_type
          }
      )

    por_projeto = Map.new(pelo_projeto, &{&1.issue_id, &1})

    pelo_quadro
    |> Enum.group_by(& &1.issue_id)
    |> Map.new(fn {issue_id, candidatos} -> {issue_id, decidir(candidatos)} end)
    |> entao_o_projeto(por_projeto)
  end

  # O quadro vence o projeto — mas só quando declarou. Por isso o projeto entra depois, e só
  # para as issues que o quadro não resolveu.
  defp entao_o_projeto(pelo_quadro, por_projeto) do
    Enum.reduce(por_projeto, pelo_quadro, fn {issue_id, p}, acc ->
      Map.put_new(acc, issue_id, {:ok, {:project, p.project_id, p.name}, p.event_type})
    end)
  end

  defp decidir([um]), do: {:ok, {:board, um.board_id, um.title}, um.event_type}

  defp decidir(candidatos) do
    mais_recente =
      candidatos |> Enum.map(& &1.linked_at) |> Enum.max(NaiveDateTime, fn -> nil end)

    case Enum.filter(candidatos, &(&1.linked_at == mais_recente)) do
      [um] ->
        {:ok, {:board, um.board_id, um.title}, um.event_type}

      empatados ->
        # Associação em lote produz `linked_at` iguais, e é o jeito natural de povoar um
        # projeto. A plataforma NÃO desempata: nomeia o empate e devolve a decisão.
        {:ambiguo, Enum.map(empatados, &Map.take(&1, [:board_id, :title, :linked_at]))}
    end
  end

  # A PRIMEIRA ocorrência de cada tipo, por issue. Uma consulta para todas — sem isto a
  # resolução seria N+1, e a decisão de resolver na leitura se inverteria.
  defp primeira_ocorrencia(_tenant, _issue_ids, []), do: %{}

  defp primeira_ocorrencia(%Tenant{id: tenant_id}, issue_ids, tipos) do
    Repo.all(
      from a in "spo_performed_project_activities",
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            a.subject_id in type(^issue_ids, {:array, :binary_id}) and
            a.activity_type in ^tipos,
        group_by: [a.subject_id, a.activity_type],
        select: {type(a.subject_id, :binary_id), a.activity_type, min(a.occurred_at)}
    )
    |> Map.new(fn {issue_id, tipo, quando} -> {{issue_id, tipo}, quando} end)
  end

  # ------------------------------------------------------------------ privados

  defp campo_do_alvo({:project, id}), do: %{project_id: id}
  defp campo_do_alvo({:board, id}), do: %{observed_project_id: id}

  defp condicao_do_alvo({:project, id}),
    do: dynamic([c], c.project_id == type(^id, :binary_id))

  defp condicao_do_alvo({:board, id}),
    do: dynamic([c], c.observed_project_id == type(^id, :binary_id))

  defp revogar_vigente(tenant, alvo, actor_id, agora) do
    case current(tenant, alvo) do
      nil -> :ok
      criterio -> marcar_revogado(criterio.id, actor_id, agora)
    end
  end

  defp marcar_revogado(id, actor_id, agora) do
    Repo.update_all(
      from(c in ActivityStartCriterion, where: c.id == type(^id, :binary_id)),
      set: [revoked_at: agora, revoked_by_user_id: actor_id, updated_at: agora]
    )
  end
end
