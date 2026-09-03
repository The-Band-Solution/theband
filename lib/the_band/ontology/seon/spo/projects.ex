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

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO.Schemas.Project
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectBoard
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectOrganization
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectRepository
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectTeam
  alias TheBand.Periodos
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
  Projetos declarados ligados (vigentes) a QUALQUER das equipes — feature 045.

  Uma passada para todas as equipes (L38): é a leitura de que o escopo project
  derivado nasce, e ligação desfeita (`unlinked_at`) some daqui.
  """
  @spec projects_of_teams(Tenant.t(), [Ecto.UUID.t()]) :: [
          %{project_id: Ecto.UUID.t(), project_name: String.t(), team_id: Ecto.UUID.t()}
        ]
  def projects_of_teams(%Tenant{id: tenant_id}, team_ids) when is_list(team_ids) do
    Repo.all(
      from v in ProjectTeam,
        join: p in Project,
        on: p.id == v.project_id,
        where:
          v.tenant_id == ^tenant_id and v.team_id in ^team_ids and is_nil(v.unlinked_at) and
            is_nil(p.removed_at),
        order_by: [asc: p.name],
        select: %{project_id: p.id, project_name: p.name, team_id: v.team_id}
    )
  end

  @doc "Nomes de projetos declarados por id — feature 045, rótulo de concessões."
  @spec projects_by_ids(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t()}
  def projects_by_ids(%Tenant{id: tenant_id}, ids) when is_list(ids) do
    Repo.all(
      from p in Project,
        where: p.tenant_id == ^tenant_id and p.id in ^ids and is_nil(p.removed_at),
        select: {p.id, p.name}
    )
    |> Map.new()
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
  Quem trabalhou neste projeto, e quando — feature 058, US2.

  A resposta é a interseção de **três períodos**: pessoa ↔ equipe, equipe ↔
  projeto, e a janela perguntada. `TheBand.Periodos.interseccao/1` decide cada
  uma, e o veredito viaja junto de cada linha.

  ## Uma pessoa, uma linha, e as equipes por onde ela chegou

  A mesma pessoa pode alcançar o projeto por mais de uma equipe. Ela aparece
  **uma vez**, com todas em `equipes` — duas linhas somariam a mesma pessoa, e
  quem contasse a lista mediria participações em vez de gente.

  ## Desligar não apaga

  Vínculo encerrado continua contando no intervalo em que vigeu. É a mesma regra
  que a feature 055 estabeleceu para a saída de uma pessoa, aplicada ao vínculo
  entre equipe e projeto.

  ## O veredito parcial não é detalhe

  Quando uma borda é desconhecida, a linha vem com `{:parcial, quais}`. Quem
  apresenta **precisa mostrar isso**: a linha depende de uma data que ninguém
  declarou, e omitir a marca afirmaria o que a plataforma não sabe.
  """
  @spec who_worked_on(Tenant.t(), Ecto.UUID.t(), Periodos.periodo()) :: [map()]
  def who_worked_on(%Tenant{} = tenant, project_id, janela) do
    tenant
    |> project_teams_with_period(project_id)
    |> Enum.flat_map(&pessoas_da_equipe_no_periodo(tenant, &1, janela))
    |> juntar_por_pessoa()
    |> Enum.sort_by(& &1.name)
  end

  # Cada membro da equipe vira um candidato, com o veredito dos TRÊS períodos.
  # `:nao_intersecta` é descartado aqui; `:intersecta` e `{:parcial, _}` seguem.
  defp pessoas_da_equipe_no_periodo(tenant, %{team_id: team_id, name: nome, periodo: pe}, janela) do
    tenant
    |> EO.team_memberships_with_period(team_id)
    |> Enum.map(fn m ->
      {m, Periodos.interseccao([m.periodo, pe, janela])}
    end)
    |> Enum.reject(fn {_m, v} -> v == :nao_intersecta end)
    |> Enum.map(fn {m, v} ->
      %{
        person_id: m.person_id,
        name: m.name,
        login: m.login,
        equipes: [%{team_id: team_id, name: nome}],
        periodo: v
      }
    end)
  end

  # A mesma pessoa por duas equipes vira UMA linha. O veredito mais fraco vence:
  # se um dos caminhos depende de borda desconhecida, a linha inteira depende —
  # dizer `:intersecta` porque o outro caminho é certo esconderia a dúvida.
  defp juntar_por_pessoa(linhas) do
    linhas
    |> Enum.group_by(& &1.person_id)
    |> Enum.map(fn {_pid, [primeira | _] = todas} ->
      %{
        primeira
        | equipes: todas |> Enum.flat_map(& &1.equipes) |> Enum.uniq_by(& &1.team_id),
          periodo: veredito_mais_fraco(Enum.map(todas, & &1.periodo))
      }
    end)
  end

  defp veredito_mais_fraco(vereditos) do
    parciais =
      vereditos
      |> Enum.flat_map(fn
        {:parcial, bordas} -> bordas
        _ -> []
      end)
      |> Enum.uniq()

    if parciais == [], do: :intersecta, else: {:parcial, parciais}
  end

  @doc """
  As equipes de um projeto **com o período de cada vínculo** — feature 058, T004.

  Diferente de `list_project_teams/2`, que filtra `is_nil(unlinked_at)` e por isso
  só enxerga o presente. Aqui o vínculo **encerrado continua sendo devolvido**,
  com o intervalo em que vigeu: desligar não apaga o que houve, e é essa a
  pergunta que `linked_at` e `unlinked_at` existem para responder.

  As duas colunas estão na tabela desde que ela foi criada e **nenhuma consulta as
  usava**.

  `inicio: nil` significa **desde quando não se sabe**, e nunca "desde sempre" —
  quem decide o que fazer com isso é `TheBand.Periodos.interseccao/1`.
  """
  @spec project_teams_with_period(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def project_teams_with_period(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectTeam,
        join: t in "eo_teams",
        on: t.id == v.team_id,
        where: v.tenant_id == ^tenant_id and v.project_id == ^project_id,
        order_by: [asc: t.name, asc: v.linked_at],
        select: %{
          team_id: v.team_id,
          name: t.name,
          periodo: %{inicio: v.linked_at, fim: v.unlinked_at}
        }
    )
  end

  @doc """
  Os repositórios de um projeto **com o período de cada vínculo** — feature 058, T012.

  Mesma forma de `project_teams_with_period/2`, sobre a segunda tabela de período
  que ninguém consultava. Existe para a US3: a taxa do pipeline é dos
  repositórios dos projetos da equipe, e não de quem disparou a execução.
  """
  @spec project_repositories_with_period(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def project_repositories_with_period(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectRepository,
        where: v.tenant_id == ^tenant_id and v.project_id == ^project_id,
        order_by: [asc: v.linked_at],
        select: %{
          observed_repository_id: v.observed_repository_id,
          periodo: %{inicio: v.linked_at, fim: v.unlinked_at}
        }
    )
  end

  @doc """
  As equipes vigentes de um projeto, **com a proveniência junto** — a tela separa a
  declarada da observada (FR-008), porque o produto existe para essa distinção.

  Só as **vigentes**. Para o histórico com período, ver
  `project_teams_with_period/2`.
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

  @typedoc """
  Uma janela em que a pessoa esteve no projeto, **por uma equipe**.

  **Os dois nulos têm sentidos opostos, e é de propósito.**

  `ended_at: nil` significa **em curso** — o vínculo aberto é o que não terminou.

  `started_at: nil` significa **desconhecido** — a entrada na equipe não foi registrada.
  `eo_team_memberships.started_at` é anulável, e a promoção da feature 043 nem sempre sabe
  desde quando a pessoa está lá.

  Colapsar os dois faria "está no projeto desde março" e "não sabemos desde quando" virarem
  a mesma linha na tela. A tela precisa distinguir, e por isso o retorno distingue.
  """
  @type janela :: %{
          started_at: DateTime.t(),
          ended_at: DateTime.t() | nil,
          team_id: Ecto.UUID.t(),
          team_name: String.t()
        }

  @doc """
  Quem esteve neste projeto, **e quando** — a interseção de dois períodos que já existem.

  ## O que ninguém calculava

  Alguém na equipe de **janeiro a junho**, com a equipe no projeto de **março a dezembro**,
  esteve no projeto de **março a junho**. Nenhuma das duas colunas diz isso sozinha, e
  derivação sem nome vira consulta copiada em três telas que divergem na quarta.

      início = max(entrada na equipe, vínculo da equipe com o projeto)
      fim    = min(saída da equipe,   desvínculo da equipe do projeto)

  ## É leitura, e não conceito gravado

  A feature 042 enfrentou a mesma pergunta e respondeu *"resolve na leitura, nunca
  materializa"* — porque o gravado abre uma janela em que ele discorda do declarado. Aqui o
  argumento é o mesmo e mais forte: os dois períodos que compõem a interseção são
  **editáveis**, e uma interseção gravada envelheceria no instante seguinte a qualquer
  correção de data.

  ## As janelas NÃO são fundidas

  Pessoa em duas equipes do mesmo projeto tem duas janelas, e elas continuam duas. Fundir
  `jan–mar` com `jul–set` em `jan–set` afirmaria presença em abril, maio e junho — meses em
  que ela não esteve. E fundir janelas que se sobrepõem apagaria **por qual equipe** ela
  entrou, que é a pergunta seguinte de quem lê.

  Quem precisa de um total conta **pessoas distintas**, nunca janelas — é a mesma regra que
  `team_size/2` segue desde a feature 043.

  ## A pessoa entra pela equipe

  Não há vínculo direto pessoa ↔ projeto nesta base, e por isso não há dois caminhos que
  possam discordar. Se um dia houver, esta função ganha uma segunda origem e a proveniência
  de cada janela passa a importar — a estrutura de retorno já a carrega em `team_id`.

  ## Uma consulta

  A interseção é feita no banco. Trazer as duas listas e cruzar em memória custaria uma
  consulta por equipe, e o número de equipes por projeto não é limitado.
  """
  @spec project_participation(Tenant.t(), Ecto.UUID.t()) :: [
          %{person_id: Ecto.UUID.t(), name: String.t(), janelas: [janela()]}
        ]
  def project_participation(%Tenant{id: tenant_id}, project_id) do
    Repo.all(
      from v in ProjectTeam,
        join: m in "eo_team_memberships",
        on: m.team_id == v.team_id and m.tenant_id == v.tenant_id,
        join: p in "eo_people",
        on: p.id == m.person_id,
        join: t in "eo_teams",
        on: t.id == v.team_id,
        # A interseção é vazia quando a pessoa saiu da equipe antes de a equipe entrar
        # no projeto, ou quando a equipe saiu antes de a pessoa entrar. Nos dois casos
        # ela não esteve no projeto, e não aparecer é a resposta correta.
        where:
          v.tenant_id == ^tenant_id and v.project_id == ^project_id and
            (is_nil(m.ended_at) or is_nil(v.linked_at) or m.ended_at >= v.linked_at) and
            (is_nil(v.unlinked_at) or m.started_at <= v.unlinked_at),
        order_by: [asc: p.name, asc: t.name],
        select: %{
          person_id: type(m.person_id, :binary_id),
          name: p.name,
          team_id: type(v.team_id, :binary_id),
          team_name: t.name,
          # `LEAST` e `GREATEST` do PostgreSQL **ignoram nulo**, e é isso que os torna certos
          # para o fim e perigosos para o começo.
          #
          # No fim, nulo significa **em curso**, e `LEAST(fim, nulo)` devolver o outro fim é
          # o que se quer: o lado aberto não encurta a janela.
          #
          # No começo, nulo significa **desconhecido**. `GREATEST(nulo, vinculo)` devolveria
          # o vínculo, e a tela mostraria uma data de entrada que ninguém declarou. O `CASE`
          # propaga o desconhecido em vez de preenchê-lo.
          #
          # O `type/2` em volta dos dois porque a consulta é sem esquema: sem ele o Postgrex
          # devolve `NaiveDateTime`, o `@type` diria `DateTime.t()` mentindo, e quem
          # formatasse na tela quebraria. Foi o mesmo defeito da feature 042.
          started_at:
            type(
              fragment(
                "CASE WHEN ? IS NULL THEN NULL ELSE GREATEST(?, COALESCE(?, ?)) END",
                m.started_at,
                m.started_at,
                v.linked_at,
                m.started_at
              ),
              :utc_datetime
            ),
          ended_at: type(fragment("LEAST(?, ?)", m.ended_at, v.unlinked_at), :utc_datetime)
        }
    )
    |> Enum.group_by(& &1.person_id)
    |> Enum.map(fn {person_id, linhas} ->
      %{
        person_id: person_id,
        name: hd(linhas).name,
        janelas: Enum.map(linhas, &Map.take(&1, [:started_at, :ended_at, :team_id, :team_name]))
      }
    end)
    |> Enum.sort_by(& &1.name)
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
