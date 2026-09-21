defmodule TheBand.Ontology.SEON.EO.Profiles do
  @moduledoc """
  Comando e consulta dos perfis derivados — feature 026.

  A tabela é **somente-acréscimo**: não existe função de atualizar. O perfil vigente é o mais
  recente, e os anteriores continuam legíveis.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.PersonProfile
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc "Grava uma geração. Nunca sobrescreve a anterior."
  @spec record(Tenant.t(), map()) :: {:ok, PersonProfile.t()} | {:error, Ecto.Changeset.t()}
  def record(%Tenant{id: tenant_id}, attrs) do
    %PersonProfile{}
    |> PersonProfile.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  @doc "O perfil vigente — o mais recente."
  @spec current(Tenant.t(), binary()) :: {:ok, PersonProfile.t()} | {:error, :not_found}
  def current(%Tenant{id: tenant_id}, person_id) do
    from(p in PersonProfile,
      where: p.tenant_id == ^tenant_id and p.person_id == ^person_id,
      order_by: [desc: p.generated_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      perfil -> {:ok, perfil}
    end
  end

  @doc """
  O perfil vigente de **várias** pessoas numa consulta só: `%{person_id => perfil}`.

  Existe porque a listagem de pessoas mostra as competências de cada linha, e chamar
  `current/2` por linha faria uma consulta por pessoa — 50 idas ao banco para desenhar uma
  página, e o custo cresce com a coleta (lição L38).

  `DISTINCT ON (person_id)` com `generated_at` descendente: a tabela é somente-acréscimo, e
  o vigente é o mais recente de cada pessoa.

  **Pessoa sem perfil não aparece no mapa**, e a chave ausente é o que quem chama precisa
  distinguir: "não houve leitura" é afirmação diferente de "houve leitura e nada foi
  demonstrado" (FR-023). Devolver a chave com `nil` achataria as duas.
  """
  @spec current_for_people(Tenant.t(), [binary()]) :: %{binary() => PersonProfile.t()}
  def current_for_people(_tenant, []), do: %{}

  def current_for_people(%Tenant{id: tenant_id}, person_ids) do
    from(p in PersonProfile,
      distinct: p.person_id,
      order_by: [asc: p.person_id, desc: p.generated_at],
      where: p.tenant_id == ^tenant_id and p.person_id in ^person_ids
    )
    |> Repo.all()
    |> Map.new(&{&1.person_id, &1})
  end

  @doc """
  As competências que um perfil demonstra: domínio, e as tarefas concluídas que o sustentam.

  **Função pura** — não consulta nada. Recebe o perfil e lê `content["destaques"]`.

  A célula é `tarefas`: **tarefas concluídas** que evidenciam o domínio. Entrega, nunca
  promessa — tarefa aberta é intenção e não demonstra nada. Por isso a filtragem exige
  `tarefas > 0`: um destaque sem tarefa concluída é texto do modelo sem evidência, e
  contá-lo faria a matriz de competências afirmar o que nada sustenta.

  `evidencia` traz os números das issues, para que cada competência desça até o registro.

  Devolve `[]` quando há perfil e nenhum destaque com tarefa — e isso **não** é o mesmo que
  não haver perfil. Quem não tem perfil não chega aqui: quem chama distingue os dois casos
  antes, porque "nenhuma competência demonstrada" e "não havia material para ler" são
  afirmações diferentes, e confundi-las transformaria lacuna do registro em julgamento da
  pessoa (FR-023).
  """
  @spec competencies(PersonProfile.t() | %{content: map()}) :: [
          %{
            nome: String.t(),
            tarefas: pos_integer(),
            demonstrou: String.t() | nil,
            evidencia: [integer()],
            periodos: [integer()],
            mais_recente: String.t() | nil
          }
        ]
  def competencies(%{content: content}) do
    for d <- content["destaques"] || [],
        is_binary(d["dominio"]),
        is_integer(d["tarefas"]) and d["tarefas"] > 0 do
      %{
        nome: d["dominio"],
        tarefas: d["tarefas"],
        demonstrou: d["demonstrou"],
        evidencia: List.wrap(d["evidencia"]),
        periodos: List.wrap(d["periodos"]),
        mais_recente: d["mais_recente"]
      }
    end
  end

  def competencies(_sem_conteudo), do: []

  @doc "Todas as gerações, da mais recente para a mais antiga."
  @spec list(Tenant.t(), binary()) :: [PersonProfile.t()]
  def list(%Tenant{id: tenant_id}, person_id) do
    from(p in PersonProfile,
      where: p.tenant_id == ^tenant_id and p.person_id == ^person_id,
      order_by: [desc: p.generated_at]
    )
    |> Repo.all()
  end
end
