defmodule TheBand.Ontology.SEON.SPO.Projects do
  @moduledoc """
  O projeto, a hierarquia e os repositórios dele — feature 025.

  ## Os dois axiomas são verificados aqui, antes de persistir

  `spo.rule01.project_hierarchy_is_acyclic` e
  `spo.rule02.project_has_at_most_one_parent`, declarados em
  `priv/knowledge_base/rules/spo_axioms.yaml`.

  O segundo é estrutural — a coluna `parent_id` só cabe um valor. O primeiro **não pode
  ser constraint de banco**: ciclo exige fecho transitivo, e o Postgres só o alcançaria
  com gatilho recursivo. A verificação percorre os ancestrais do pai proposto, e a
  mensagem **nomeia o caminho** — quem cadastrou precisa saber onde desfazer.

  ## A fase é derivada, e nunca gravada

  Simples e complexo saem de ter filhos. Um campo gravado divergiria da estrutura no
  primeiro dia, e a plataforma já tem postura para isso na regra de roteamento de
  issues: **estrutura vence a declaração**.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.Project
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectBoard
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectOrganization
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectRepository
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectTeam
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue

  # ------------------------------------------------------------------------ escritas

  @doc """
  Cadastra um projeto. Projeto é declaração, e por isso exige autor.
  """
  @spec create_project(Tenant.t(), map(), Ecto.UUID.t()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(%Tenant{id: tenant_id}, attrs, actor_id) do
    %Project{}
    |> Project.changeset(
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.merge(%{"tenant_id" => tenant_id, "declared_by_user_id" => actor_id})
    )
    |> Repo.insert()
  end

  @doc """
  Declara que um projeto é parte de outro.

  Recusa em dois casos, e cada um com a razão que a pessoa precisa para agir:

    * **já tem pai** — `{:error, {:already_has_parent, nome}}`, com o nome do pai atual.
      A restrição é sobre simultaneidade, não imutabilidade: desfazer e refazer é
      permitido;
    * **formaria ciclo** — `{:error, {:cycle, caminho}}`, com o caminho nomeado.
  """
  @spec set_parent(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Project.t()}
          | {:error, {:already_has_parent, String.t()} | {:cycle, [String.t()]} | :not_found}
  def set_parent(%Tenant{} = tenant, project_id, parent_id) do
    with {:ok, projeto} <- fetch_project(tenant, project_id),
         {:ok, pai} <- fetch_project(tenant, parent_id),
         :ok <- sem_pai_vigente(tenant, projeto),
         :ok <- sem_ciclo(tenant, projeto, pai) do
      projeto
      |> Project.changeset(%{parent_id: pai.id})
      |> Repo.update()
    end
  end

  @doc """
  Desfaz o vínculo com o pai. É o que permite trocar de pai sem apagar o projeto.
  """
  @spec clear_parent(Tenant.t(), Ecto.UUID.t()) :: {:ok, Project.t()} | {:error, :not_found}
  def clear_parent(%Tenant{} = tenant, project_id) do
    with {:ok, projeto} <- fetch_project(tenant, project_id) do
      projeto |> Project.changeset(%{parent_id: nil}) |> Repo.update()
    end
  end

  @doc """
  Associa um repositório observado ao projeto. Decisão tem autor.
  """
  @spec link_repository(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectRepository.t()} | {:error, Ecto.Changeset.t()}
  def link_repository(%Tenant{id: tenant_id}, project_id, observed_repository_id, actor_id) do
    agora = DateTime.utc_now(:second)

    chave = %{
      tenant_id: tenant_id,
      project_id: project_id,
      observed_repository_id: observed_repository_id
    }

    # Reassociar um repositório que saiu **revive o vínculo encerrado** em vez de criar
    # outro: o índice único é parcial sobre os vigentes, e duas linhas vigentes para o
    # mesmo par não podem existir.
    # `get_by` com `nil` é proibido no Ecto — comparação com nulo precisa de `is_nil`, e
    # a mensagem dele diz exatamente isso.
    vigente =
      Repo.one(
        from v in ProjectRepository,
          where:
            v.tenant_id == ^tenant_id and v.project_id == ^project_id and
              v.observed_repository_id == ^observed_repository_id and is_nil(v.unlinked_at)
      )

    case vigente do
      nil ->
        %ProjectRepository{}
        |> ProjectRepository.changeset(
          Map.merge(chave, %{linked_by_user_id: actor_id, linked_at: agora})
        )
        |> Repo.insert()

      existente ->
        {:ok, existente}
    end
  end

  @doc """
  Desfaz o vínculo com um repositório — **marca**, e nunca apaga.
  """
  @spec unlink_repository(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectRepository.t()} | {:error, :not_found}
  def unlink_repository(%Tenant{id: tenant_id}, vinculo_id, actor_id) do
    case Repo.get_by(ProjectRepository, id: vinculo_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      vinculo ->
        vinculo
        |> ProjectRepository.changeset(%{
          unlinked_at: DateTime.utc_now(:second),
          unlinked_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  @doc """
  Associa um **quadro** observado ao projeto — issue #367.

  ## Um projeto pode ter mais de um quadro

  Decisão da pessoa mantenedora, 2026-08-24. Não há "o quadro do projeto": há os quadros
  dele. O Conecta Fapes tem quatro, e lê-lo por um só fazia dez meses de entrega sumirem.

  Quadro é `observed_projects` — o Projects v2 coletado —, e não `spo_projects`. O GitHub
  chama o quadro de "project", e é daí que vem a colisão de nomes.

  Decisão tem autor, como o vínculo com repositório.
  """
  @spec link_board(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectBoard.t()} | {:error, Ecto.Changeset.t()}
  def link_board(%Tenant{id: tenant_id}, project_id, observed_project_id, actor_id) do
    agora = DateTime.utc_now(:second)

    chave = %{
      tenant_id: tenant_id,
      project_id: project_id,
      observed_project_id: observed_project_id
    }

    # Reassociar um quadro que saiu **revive o vínculo encerrado** em vez de criar outro: o
    # índice único é parcial sobre os vigentes, e duas linhas vigentes para o mesmo par não
    # podem existir. `is_nil` e não `get_by` com nulo — o Ecto proíbe o segundo.
    vigente =
      Repo.one(
        from v in ProjectBoard,
          where:
            v.tenant_id == ^tenant_id and v.project_id == ^project_id and
              v.observed_project_id == ^observed_project_id and is_nil(v.unlinked_at)
      )

    case vigente do
      nil ->
        %ProjectBoard{}
        |> ProjectBoard.changeset(
          Map.merge(chave, %{linked_by_user_id: actor_id, linked_at: agora})
        )
        |> Repo.insert()

      existente ->
        {:ok, existente}
    end
  end

  @doc """
  Desfaz o vínculo com um quadro — **marca**, e nunca apaga.

  A pergunta "desde quando este quadro é deste projeto" só tem resposta se o encerramento
  preservar o começo.
  """
  @spec unlink_board(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectBoard.t()} | {:error, :not_found}
  def unlink_board(%Tenant{id: tenant_id}, vinculo_id, actor_id) do
    case Repo.get_by(ProjectBoard, id: vinculo_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      vinculo ->
        vinculo
        |> ProjectBoard.changeset(%{
          unlinked_at: DateTime.utc_now(:second),
          unlinked_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  @doc """
  Os quadros **vigentes** do projeto, com título e contagem de itens.

  Traz o título junto porque a pergunta que a tela faz é "quais quadros", e um identificador
  sem nome obrigaria uma segunda consulta para cada linha.
  """
  @spec list_project_boards(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_project_boards(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectBoard,
        join: q in "observed_projects",
        on: q.id == v.observed_project_id,
        where:
          v.tenant_id == ^tenant_id and v.project_id == ^project_id and is_nil(v.unlinked_at),
        order_by: [asc: q.title],
        select: %{
          id: type(v.id, :binary_id),
          observed_project_id: type(v.observed_project_id, :binary_id),
          title: q.title,
          number: q.number,
          closed: q.closed,
          linked_at: v.linked_at,
          # Fechado na origem **não** é desvinculado aqui: o quadro encerrado continua sendo
          # do projeto, e é o que preserva o histórico que a #367 mostrou sumindo.
          items:
            fragment(
              "(select count(*) from project_items x where x.observed_project_id = ?)",
              v.observed_project_id
            )
        }
    )
  end

  @doc """
  Edita nome e período de um projeto declarado — feature 028, FR-001.

  Não alcança `parent_id`: mover na hierarquia é `set_parent/3`, porque mover tem regra
  própria (ciclo) e misturá-las faria a validação de ciclo rodar em edição de nome.
  """
  @spec update_project(Tenant.t(), Ecto.UUID.t(), map(), Ecto.UUID.t()) ::
          {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_project(%Tenant{id: tenant_id}, project_id, attrs, actor_id) do
    case Repo.get_by(Project, id: project_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      projeto ->
        projeto
        |> Project.changeset(
          attrs
          |> Map.new(fn {k, v} -> {to_string(k), v} end)
          |> Map.take(["name", "started_on", "ended_on"])
          |> Map.put("updated_by_user_id", actor_id)
        )
        |> Repo.update()
    end
  end

  @doc """
  Remove um projeto declarado — **marca, nunca apaga** (FR-002).

  `:has_parts` quando existem subprojetos vigentes (FR-003): as partes são movidas ou
  removidas primeiro, porque remover em cascata apagaria declarações que ninguém pediu
  para apagar. Não existe undelete — declarar de novo é criar de novo, com autor novo.
  """
  @spec remove_project(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Project.t()} | {:error, :not_found | :has_parts}
  def remove_project(%Tenant{id: tenant_id} = tenant, project_id, actor_id) do
    partes =
      Repo.one(
        from p in Project,
          where:
            p.tenant_id == ^tenant_id and p.parent_id == ^project_id and is_nil(p.removed_at),
          select: count(p.id)
      )

    case {Repo.get_by(Project, id: project_id, tenant_id: tenant_id), partes} do
      {nil, _} ->
        {:error, :not_found}

      {_projeto, n} when n > 0 ->
        {:error, :has_parts}

      {projeto, 0} ->
        _ = tenant

        projeto
        |> Project.changeset(%{
          removed_at: DateTime.utc_now(:second),
          removed_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  @doc """
  Associa uma organização observada ao projeto — feature 028, FR-004.

  O mesmo desenho do vínculo com repositório: reassociar revive o vigente em vez de
  duplicar, e o índice único parcial garante um vigente por par.
  """
  @spec link_organization(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectOrganization.t()} | {:error, Ecto.Changeset.t()}
  def link_organization(%Tenant{id: tenant_id}, project_id, organization_id, actor_id) do
    vigente =
      Repo.one(
        from v in ProjectOrganization,
          where:
            v.tenant_id == ^tenant_id and v.project_id == ^project_id and
              v.organization_id == ^organization_id and is_nil(v.unlinked_at)
      )

    case vigente do
      nil ->
        %ProjectOrganization{}
        |> ProjectOrganization.changeset(%{
          tenant_id: tenant_id,
          project_id: project_id,
          organization_id: organization_id,
          linked_by_user_id: actor_id,
          linked_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      existente ->
        {:ok, existente}
    end
  end

  @doc "Desfaz o vínculo com uma organização — marca, nunca apaga."
  @spec unlink_organization(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectOrganization.t()} | {:error, :not_found}
  def unlink_organization(%Tenant{id: tenant_id}, vinculo_id, actor_id) do
    case Repo.get_by(ProjectOrganization, id: vinculo_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      vinculo ->
        vinculo
        |> ProjectOrganization.changeset(%{
          unlinked_at: DateTime.utc_now(:second),
          unlinked_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  @doc "As organizações vigentes de um projeto, com o vínculo junto."
  @spec list_project_organizations(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_project_organizations(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectOrganization,
        join: o in "eo_organizations",
        on: o.id == v.organization_id,
        where:
          v.tenant_id == ^tenant_id and v.project_id == ^project_id and is_nil(v.unlinked_at),
        order_by: [asc: o.login],
        select: %{id: v.id, organization_id: v.organization_id, login: o.login, name: o.name}
    )
  end

  @doc """
  Associa uma equipe ao projeto — feature 028, FR-006.

  A equipe pode ser observada ou declarada; o vínculo não distingue, e a tela distingue
  pela proveniência da equipe.
  """
  @spec link_team(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectTeam.t()} | {:error, Ecto.Changeset.t()}
  def link_team(%Tenant{id: tenant_id}, project_id, team_id, actor_id) do
    vigente =
      Repo.one(
        from v in ProjectTeam,
          where:
            v.tenant_id == ^tenant_id and v.project_id == ^project_id and
              v.team_id == ^team_id and is_nil(v.unlinked_at)
      )

    case vigente do
      nil ->
        %ProjectTeam{}
        |> ProjectTeam.changeset(%{
          tenant_id: tenant_id,
          project_id: project_id,
          team_id: team_id,
          linked_by_user_id: actor_id,
          linked_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      existente ->
        {:ok, existente}
    end
  end

  @doc "Desfaz o vínculo com uma equipe — marca, nunca apaga."
  @spec unlink_team(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ProjectTeam.t()} | {:error, :not_found}
  def unlink_team(%Tenant{id: tenant_id}, vinculo_id, actor_id) do
    case Repo.get_by(ProjectTeam, id: vinculo_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      vinculo ->
        vinculo
        |> ProjectTeam.changeset(%{
          unlinked_at: DateTime.utc_now(:second),
          unlinked_by_user_id: actor_id
        })
        |> Repo.update()
    end
  end

  @doc """
  Os projetos vigentes de uma equipe — o mesmo vínculo, lido do lado da equipe.

  Uma consulta só: é a tela da equipe que chama, e por-projeto seria o N+1 que a casa
  já pagou uma vez (feature 007).
  """
  @spec list_team_projects(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_team_projects(%Tenant{id: tenant_id}, team_id) do
    Repo.all(
      from v in ProjectTeam,
        join: p in Project,
        on: p.id == v.project_id,
        where:
          v.tenant_id == ^tenant_id and v.team_id == ^team_id and is_nil(v.unlinked_at) and
            is_nil(p.removed_at),
        order_by: [asc: p.name],
        select: %{project_id: p.id, nome: p.name, link_id: v.id}
    )
  end

  @doc """
  As equipes vigentes de um projeto, **com a proveniência junto** — a tela separa a
  declarada da observada (FR-008), porque o produto existe para essa distinção.
  """
  @spec list_project_teams(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_project_teams(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectTeam,
        join: t in "eo_teams",
        on: t.id == v.team_id,
        where:
          v.tenant_id == ^tenant_id and v.project_id == ^project_id and is_nil(v.unlinked_at),
        order_by: [asc: t.name],
        select: %{
          id: v.id,
          team_id: v.team_id,
          name: t.name,
          declared: t.source_instance == "declared",
          source_system: t.source_system
        }
    )
  end

  # ------------------------------------------------------------------------ leituras

  @doc """
  Os projetos do tenant, **com a fase derivada** de ter filhos.

  Uma consulta para os projetos e outra para os pais que têm filho — e não uma por
  projeto, que seria o N+1.
  """
  @spec list_projects(Tenant.t()) :: [Project.t()]
  def list_projects(%Tenant{id: tenant_id}) do
    projetos =
      Repo.all(
        from p in Project,
          where: p.tenant_id == ^tenant_id and is_nil(p.removed_at),
          order_by: [asc: p.name]
      )

    com_filho =
      Repo.all(
        from p in Project,
          where: p.tenant_id == ^tenant_id and not is_nil(p.parent_id),
          select: p.parent_id,
          distinct: true
      )
      |> MapSet.new()

    Enum.map(
      projetos,
      &%{&1 | phase: if(MapSet.member?(com_filho, &1.id), do: :complex, else: :simple)}
    )
  end

  @spec fetch_project(Tenant.t(), Ecto.UUID.t()) :: {:ok, Project.t()} | {:error, :not_found}
  def fetch_project(%Tenant{id: tenant_id}, id) do
    case Repo.get_by(Project, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      projeto -> {:ok, %{projeto | phase: fase(tenant_id, projeto.id)}}
    end
  end

  @doc "Os repositórios **vigentes** do projeto."
  @spec list_project_repositories(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_project_repositories(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectRepository,
        where:
          v.tenant_id == ^tenant_id and v.project_id == ^project_id and is_nil(v.unlinked_at),
        select: %{
          id: v.id,
          observed_repository_id: v.observed_repository_id,
          linked_at: v.linked_at
        }
    )
  end

  @doc """
  As issues do projeto, **pela travessia** projeto → repositórios → issues.

  `opts[:incluir_subprojetos]` percorre a árvore. As issues vindas de subprojeto são
  distinguíveis pelo campo `via`, e não somadas às diretas sem aviso — FR-014.
  """
  @spec list_project_issues(Tenant.t(), Ecto.UUID.t(), keyword()) :: [map()]
  def list_project_issues(%Tenant{id: tenant_id} = tenant, project_id, opts \\ []) do
    diretos = repositorios_de(tenant_id, [project_id])

    descendentes =
      if opts[:incluir_subprojetos], do: descendentes(tenant, project_id), else: []

    herdados = repositorios_de(tenant_id, descendentes) -- diretos

    issues(tenant_id, diretos, :direct) ++ issues(tenant_id, herdados, :subproject)
  end

  @doc """
  Quantas issues o projeto alcança, separadas por origem.

  As duas contagens vêm separadas, e **não somadas**: "veio de repositório meu" e "veio
  de subprojeto" são fatos diferentes, e um total esconderia de onde o número veio.
  """
  @spec count_project_issues(Tenant.t(), Ecto.UUID.t()) :: %{
          direct: integer(),
          subproject: integer()
        }
  def count_project_issues(%Tenant{} = tenant, project_id) do
    todas = list_project_issues(tenant, project_id, incluir_subprojetos: true)

    %{
      direct: Enum.count(todas, &(&1.via == :direct)),
      subproject: Enum.count(todas, &(&1.via == :subproject))
    }
  end

  # ------------------------------------------------------------------------ privadas

  defp fase(tenant_id, project_id) do
    existe? =
      Repo.exists?(
        from p in Project, where: p.tenant_id == ^tenant_id and p.parent_id == ^project_id
      )

    if existe?, do: :complex, else: :simple
  end

  defp sem_pai_vigente(_tenant, %Project{parent_id: nil}), do: :ok

  defp sem_pai_vigente(tenant, %Project{parent_id: pai_id}) do
    case fetch_project(tenant, pai_id) do
      {:ok, pai} -> {:error, {:already_has_parent, pai.name}}
      _ -> :ok
    end
  end

  # **Percorre os ancestrais do pai proposto**, e não os do filho: o ciclo se forma se o
  # projeto já estiver acima do pai. Constraint de banco não alcança fecho transitivo, e
  # é por isso que a regra declara `test_and_db_constraint` com a verificação no comando.
  defp sem_ciclo(tenant, %Project{id: id, name: nome}, %Project{id: pai_id}) when id == pai_id do
    _ = tenant
    {:error, {:cycle, [nome, nome]}}
  end

  defp sem_ciclo(tenant, projeto, pai) do
    caminho = subir(tenant, pai, [pai.name])

    if projeto.id in Enum.map(ancestrais(tenant, pai), & &1.id) do
      {:error, {:cycle, [projeto.name | caminho] ++ [projeto.name]}}
    else
      :ok
    end
  end

  defp ancestrais(tenant, projeto), do: ancestrais(tenant, projeto, [])

  defp ancestrais(_tenant, %Project{parent_id: nil}, acc), do: acc

  defp ancestrais(tenant, %Project{parent_id: pai_id}, acc) do
    case fetch_project(tenant, pai_id) do
      {:ok, pai} -> ancestrais(tenant, pai, [pai | acc])
      _ -> acc
    end
  end

  defp subir(tenant, projeto, acc) do
    Enum.map(ancestrais(tenant, projeto), & &1.name) ++ acc
  end

  defp descendentes(%Tenant{id: tenant_id} = tenant, project_id) do
    filhos =
      Repo.all(
        from p in Project,
          where: p.tenant_id == ^tenant_id and p.parent_id == ^project_id,
          select: p.id
      )

    filhos ++ Enum.flat_map(filhos, &descendentes(tenant, &1))
  end

  defp repositorios_de(_tenant_id, []), do: []

  defp repositorios_de(tenant_id, project_ids) do
    Repo.all(
      from v in ProjectRepository,
        where:
          v.tenant_id == ^tenant_id and v.project_id in ^project_ids and is_nil(v.unlinked_at),
        select: v.observed_repository_id,
        distinct: true
    )
  end

  defp issues(_tenant_id, [], _via), do: []

  defp issues(tenant_id, repositorios, via) do
    Repo.all(
      from i in CollectedIssue,
        where:
          i.tenant_id == ^tenant_id and i.observed_repository_id in ^repositorios and
            is_nil(i.no_longer_observed_at),
        order_by: [asc: i.number],
        select: %{
          id: i.id,
          number: i.number,
          title: i.title,
          state: i.state,
          observed_repository_id: i.observed_repository_id
        }
    )
    |> Enum.map(&Map.put(&1, :via, via))
  end
end
