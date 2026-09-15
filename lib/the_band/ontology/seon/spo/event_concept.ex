defmodule TheBand.Ontology.SEON.SPO.EventConcept do
  @moduledoc """
  A organização declara o que cada evento da timeline materializa — feature 066.

  ## Por que existe

  A lista de quais eventos viram `spo.performed_project_activity` vivia **escrita no código**
  desde a feature 004: cinco tipos numa cláusula de função, e todo o resto em nulo. Isso é o
  princípio IV cumprido pela metade — a semântica estava no Elixir, e ninguém podia perguntar
  a ela nem discordar dela.

  O YAML `github.timeline_event_vocabulary` passou a carregar o **padrão da casa**. Este
  módulo carrega a **discordância da organização**, que é legítima: *entrar num quadro* não é
  trabalho executado aqui, mas numa casa onde o cartão só entra quando alguém o pega, é.

  ## Prevalece na leitura, e nada é regravado

  A coleta continua gravando o `concept_id` do padrão. A leitura aplica a declaração vigente
  por cima — o mesmo desenho da declaração de fase por coluna, e pela mesma razão: revogar
  não pode exigir reescrever milhares de linhas.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO.Schemas.EventConceptDeclaration, as: Declaracao
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Declara o que um evento materializa. Declarar sobre um evento que já tem declaração vigente
  revoga a anterior na mesma transação.
  """
  @spec declarar(Tenant.t(), String.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, Declaracao.t()} | {:error, Ecto.Changeset.t()}
  def declarar(%Tenant{id: tenant_id}, event_type, target_concept, ator_id) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    anteriores =
      from(d in Declaracao,
        where: d.tenant_id == ^tenant_id and d.event_type == ^event_type and is_nil(d.revoked_at)
      )

    Repo.transaction(fn ->
      Repo.update_all(anteriores,
        set: [revoked_at: agora, revoked_by_user_id: ator_id, updated_at: agora]
      )

      attrs = %{
        "tenant_id" => tenant_id,
        "event_type" => event_type,
        "target_concept" => target_concept,
        "declared_by_user_id" => ator_id,
        "declared_at" => agora
      }

      case Repo.insert(Declaracao.declarar_changeset(%Declaracao{}, attrs)) do
        {:ok, declaracao} -> declaracao
        {:error, motivo} -> Repo.rollback(motivo)
      end
    end)
  end

  @doc "Revoga a declaração de um evento. Marca — e nunca apaga."
  @spec revogar(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Declaracao.t()} | {:error, :nao_encontrada | Ecto.Changeset.t()}
  def revogar(%Tenant{id: tenant_id}, id, ator_id) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.one(
           from(d in Declaracao,
             where: d.tenant_id == ^tenant_id and d.id == ^id and is_nil(d.revoked_at)
           )
         ) do
      nil ->
        {:error, :nao_encontrada}

      declaracao ->
        declaracao
        |> Declaracao.revogar_changeset(%{revoked_by_user_id: ator_id, revoked_at: agora})
        |> Repo.update()
    end
  end

  @doc "As declarações vigentes da organização."
  @spec vigentes(Tenant.t()) :: [Declaracao.t()]
  def vigentes(%Tenant{id: tenant_id}) do
    Repo.all(
      from(d in Declaracao,
        where: d.tenant_id == ^tenant_id and is_nil(d.revoked_at),
        order_by: [asc: d.event_type]
      )
    )
  end

  @doc "Os conceitos que a organização pode escolher, com rótulo e o que cada um afirma."
  @spec conceitos_admitidos() :: [map()]
  def conceitos_admitidos do
    case KnowledgeBase.rule("github.timeline_event_vocabulary") do
      {:ok, %{"admissible_concepts" => cs}} when is_list(cs) ->
        for c <- cs do
          %{
            id: c["id"],
            rotulo: get_in(c, ["label", "en"]) || c["id"],
            significa: get_in(c, ["means", "pt-BR"])
          }
        end

      _ ->
        []
    end
  end
end
