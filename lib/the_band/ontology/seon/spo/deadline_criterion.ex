defmodule TheBand.Ontology.SEON.SPO.DeadlineCriterion do
  @moduledoc """
  De onde vem o prazo de uma atividade — issue #368.

  ## O GitHub não tem campo de prazo na issue

  A sondagem achou **33 pares (quadro, campo) de data**, em 13 nomes e duas línguas.
  `End date` é fim planejado num quadro e fim real noutro, com o mesmo nome; `End Date` e
  `End date` diferem só na caixa. Adotar o primeiro campo de data que aparecer faria o
  mesmo número significar coisas diferentes conforme o quadro.

  ## Três origens, e elas não se excluem

  Decisão da pessoa mantenedora em 2026-08-26: o prazo pode vir do **campo do quadro**, do
  **sprint** ou do **marco** — e *"se uma task está dentro do sprint, o prazo dela é do
  sprint E do milestone"*. Medido no mesmo dia sobre 5.216 issues: **304 têm as duas
  origens ao mesmo tempo**, e **640 estão em mais de uma caixa de tempo**.

  Por isso `resolve/2` devolve **lista**, e nunca um prazo só. Colapsar escolheria em
  silêncio qual das datas conta.

  ## O horizonte não é sprint, e o prazo dele diz outra coisa

  Depois da #514, a caixa em que a tarefa está pode ser sprint de 13 dias ou horizonte de
  planejamento de 84. As duas produzem um fim, e são coisas diferentes: o fim do sprint é
  quando a caixa de execução fecha; o fim do horizonte é o limite do período para o qual o
  trabalho **havia sido planejado**. A proveniência distingue — `:sprint` e
  `:planning_horizon` são origens separadas na resposta, e somá-las produziria atraso de
  84 dias medido contra uma caixa de 13.

  ## Ausência é declarada, nunca zero

  Alvo sem critério devolve lista vazia, e **43% das issues não alcançam origem alguma**.
  Lista vazia é "não sabemos o prazo", e não "não tem prazo" nem "está no prazo".
  """
  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.ActivityDeadlineCriterion
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type alvo :: {:board, Ecto.UUID.t()} | {:project, Ecto.UUID.t()}
  @type prazo :: %{
          quando: Date.t(),
          origem: :board_field | :sprint | :planning_horizon | :milestone,
          rotulo: String.t()
        }

  @doc """
  Declara uma origem de prazo. **Acrescenta, não substitui.**

  Diferente da 042: lá o critério de início é um só, porque um instante de início é um só.
  Aqui sprint e marco valem juntos, e declarar o segundo revogando o primeiro apagaria
  metade do prazo sem ninguém pedir.
  """
  @spec declare(Tenant.t(), alvo(), String.t(), String.t() | nil, Ecto.UUID.t()) ::
          {:ok, ActivityDeadlineCriterion.t()} | {:error, Ecto.Changeset.t()}
  def declare(%Tenant{id: tenant_id}, alvo, source, field_name, actor_id) do
    %ActivityDeadlineCriterion{}
    |> ActivityDeadlineCriterion.changeset(
      Map.merge(chave_do_alvo(alvo), %{
        tenant_id: tenant_id,
        source: source,
        field_name: field_name,
        declared_by_user_id: actor_id,
        declared_at: DateTime.utc_now(:second)
      })
    )
    |> Repo.insert()
  end

  @doc "Revoga UMA origem. Marca, e nunca apaga."
  @spec revoke(Tenant.t(), alvo(), String.t(), String.t() | nil, Ecto.UUID.t()) ::
          {:ok, non_neg_integer()} | {:error, :not_declared}
  def revoke(%Tenant{id: tenant_id}, alvo, source, field_name, actor_id) do
    agora = DateTime.utc_now(:second)

    consulta =
      from(c in ActivityDeadlineCriterion,
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and c.source == ^source and
            is_nil(c.revoked_at)
      )
      |> onde_alvo(alvo)
      |> onde_campo(field_name)

    case Repo.update_all(consulta,
           set: [revoked_at: agora, revoked_by_user_id: actor_id, updated_at: agora]
         ) do
      {0, _} -> {:error, :not_declared}
      {n, _} -> {:ok, n}
    end
  end

  @doc "As origens vigentes deste alvo — pode haver mais de uma, e é o caso esperado."
  @spec current(Tenant.t(), alvo()) :: [ActivityDeadlineCriterion.t()]
  def current(%Tenant{id: tenant_id}, alvo) do
    from(c in ActivityDeadlineCriterion,
      where: c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at),
      order_by: [asc: c.source, asc: c.field_name]
    )
    |> onde_alvo(alvo)
    |> Repo.all()
  end

  @doc """
  Os prazos de cada issue, com a proveniência junto — **todos** os aplicáveis.

  Devolve `%{issue_id => [prazo]}`. Issue sem origem alcançável não aparece com zero: sai
  com lista vazia, que a tela nomeia.
  """
  @spec resolve(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [prazo()]}
  def resolve(_tenant, []), do: %{}

  def resolve(%Tenant{} = tenant, issue_ids) do
    vigentes = origens_por_quadro(tenant)

    prazos =
      [
        de_campo_do_quadro(tenant, issue_ids, vigentes),
        de_caixa_de_tempo(tenant, issue_ids, vigentes),
        de_marco(tenant, issue_ids, vigentes)
      ]
      |> List.flatten()
      |> Enum.group_by(& &1.issue_id, &Map.delete(&1, :issue_id))

    Map.new(issue_ids, fn id ->
      {id, prazos |> Map.get(id, []) |> Enum.sort_by(& &1.quando, Date)}
    end)
  end

  # --------------------------------------------------------------------------- privadas

  # Quais origens cada quadro declarou. O critério do quadro prevalece sobre o do projeto,
  # como na 042 — e um quadro que declara qualquer coisa não herda mais nada do projeto,
  # porque herdar em parte faria a tela mostrar origem que ninguém declarou ali.
  defp origens_por_quadro(%Tenant{id: tenant_id}) do
    do_quadro =
      Repo.all(
        from c in ActivityDeadlineCriterion,
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at) and
              not is_nil(c.observed_project_id),
          select: %{
            board_id: type(c.observed_project_id, :binary_id),
            source: c.source,
            field_name: c.field_name
          }
      )

    do_projeto =
      Repo.all(
        from c in ActivityDeadlineCriterion,
          join: v in "spo_project_boards",
          on: v.project_id == c.project_id and is_nil(v.unlinked_at),
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and is_nil(c.revoked_at) and
              not is_nil(c.project_id),
          select: %{
            board_id: type(v.observed_project_id, :binary_id),
            source: c.source,
            field_name: c.field_name
          }
      )

    proprios = MapSet.new(do_quadro, & &1.board_id)
    herdados = Enum.reject(do_projeto, &MapSet.member?(proprios, &1.board_id))

    Enum.group_by(do_quadro ++ herdados, & &1.board_id)
  end

  defp de_campo_do_quadro(%Tenant{id: tenant_id}, issue_ids, vigentes) do
    pares =
      for {board_id, origens} <- vigentes,
          %{source: "board_field", field_name: campo} <- origens,
          do: {board_id, campo}

    if pares == [] do
      []
    else
      quadros = Enum.map(pares, &elem(&1, 0))
      permitido = MapSet.new(pares)

      Repo.all(
        from i in "project_items",
          join: v in "item_field_values",
          on: v.project_item_id == i.id,
          join: d in "project_field_definitions",
          on: d.id == v.project_field_definition_id,
          where:
            i.tenant_id == type(^tenant_id, :binary_id) and
              i.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
              i.observed_project_id in type(^quadros, {:array, :binary_id}) and
              is_nil(i.no_longer_observed_at) and
              not is_nil(fragment("? ->> 'date'", v.raw_value)),
          select: %{
            issue_id: type(i.collected_issue_id, :binary_id),
            board_id: type(i.observed_project_id, :binary_id),
            rotulo: d.name,
            texto: fragment("? ->> 'date'", v.raw_value)
          }
      )
      |> Enum.filter(&MapSet.member?(permitido, {&1.board_id, &1.rotulo}))
      |> Enum.flat_map(&como_prazo(&1, :board_field))
    end
  end

  # A caixa de tempo. `field_name` do sprint decide se é sprint ou horizonte — é a
  # separação que a #514 entregou, e sem ela um prazo de 84 dias entraria como sprint.
  defp de_caixa_de_tempo(tenant, issue_ids, vigentes) do
    case quadros_com(vigentes, "sprint") do
      [] -> []
      quadros -> tenant |> caixas(issue_ids, quadros) |> Enum.map(&caixa_como_prazo/1)
    end
  end

  defp caixas(%Tenant{id: tenant_id}, issue_ids, quadros) do
    Repo.all(
      from si in "sro_sprint_issues",
        join: s in "sro_sprints",
        on: s.id == si.sprint_id,
        join: o in "observed_projects",
        on: o.number == s.board_number and o.tenant_id == s.tenant_id,
        left_join: p in "smpo_iteration_field_roles",
        on:
          p.observed_project_id == o.id and p.field_name == s.field_name and
            p.tenant_id == s.tenant_id and is_nil(p.revoked_at),
        where:
          si.tenant_id == type(^tenant_id, :binary_id) and
            si.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
            is_nil(si.no_longer_observed_at) and
            o.id in type(^quadros, {:array, :binary_id}) and
            not is_nil(s.ended_on),
        select: %{
          issue_id: type(si.collected_issue_id, :binary_id),
          quando: s.ended_on,
          rotulo: s.title,
          papel: p.role
        }
    )
  end

  defp quadros_com(vigentes, origem),
    do: for({b, os} <- vigentes, Enum.any?(os, &(&1.source == origem)), do: b)

  # O papel declarado decide a origem. Sem a #514 as duas caixas cairiam como `:sprint`, e
  # um atraso medido contra 84 dias apareceria como atraso de sprint de 13.
  defp caixa_como_prazo(%{papel: "planning_horizon"} = linha),
    do: %{
      issue_id: linha.issue_id,
      quando: linha.quando,
      origem: :planning_horizon,
      rotulo: linha.rotulo
    }

  defp caixa_como_prazo(linha),
    do: %{issue_id: linha.issue_id, quando: linha.quando, origem: :sprint, rotulo: linha.rotulo}

  defp de_marco(%Tenant{id: tenant_id}, issue_ids, vigentes) do
    quadros = quadros_com(vigentes, "milestone")

    if quadros == [] do
      []
    else
      Repo.all(
        from i in "project_items",
          join: ci in "collected_issues",
          on: ci.id == i.collected_issue_id,
          where:
            i.tenant_id == type(^tenant_id, :binary_id) and
              i.collected_issue_id in type(^issue_ids, {:array, :binary_id}) and
              i.observed_project_id in type(^quadros, {:array, :binary_id}) and
              is_nil(i.no_longer_observed_at) and not is_nil(ci.milestone_due_on),
          distinct: true,
          select: %{
            issue_id: type(i.collected_issue_id, :binary_id),
            quando: ci.milestone_due_on,
            origem: type(^"milestone", :string),
            rotulo: ci.milestone_title
          }
      )
      |> Enum.map(&%{&1 | origem: :milestone})
    end
  end

  # Texto da origem vira data, ou nada. Data ilegível é ausência, e nunca hoje.
  defp como_prazo(%{texto: texto} = linha, origem) do
    case Date.from_iso8601(texto) do
      {:ok, d} -> [%{issue_id: linha.issue_id, quando: d, origem: origem, rotulo: linha.rotulo}]
      _ -> []
    end
  end

  defp chave_do_alvo({:board, id}), do: %{observed_project_id: id}
  defp chave_do_alvo({:project, id}), do: %{project_id: id}

  defp onde_alvo(consulta, {:board, id}),
    do: where(consulta, [c], c.observed_project_id == type(^id, :binary_id))

  defp onde_alvo(consulta, {:project, id}),
    do: where(consulta, [c], c.project_id == type(^id, :binary_id))

  defp onde_campo(consulta, nil), do: where(consulta, [c], is_nil(c.field_name))
  defp onde_campo(consulta, campo), do: where(consulta, [c], c.field_name == ^campo)
end
