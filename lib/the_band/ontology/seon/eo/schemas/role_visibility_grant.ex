defmodule TheBand.Ontology.SEON.EO.Schemas.RoleVisibilityGrant do
  @moduledoc """
  O que um papel na organização permite ver — issue #369.

  Não é conceito da EO: é a **declaração** que decide de quem o painel de trabalho é
  alcançável por quem tem aquele papel. O mesmo lugar que `spo.activity_start_criterion`
  ocupa para o instante de início, e `smpo.iteration_field_role` para o papel do campo.

  ## Dois escopos, e nenhum booleano

  `team` alcança quem está nas equipes em que a pessoa tem o papel. `organization` alcança
  quem está na organização. Um `is_leader` booleano perderia **quem concedeu e quando**, e
  numa decisão de visibilidade essa é a pergunta que mais se faz depois.

  ## Nada vem por nome

  `Tech Leader` parece liderança e `Coordenador` também, e a mesma organização pode ter um
  `Tech Lead` que é senioridade técnica e não chefia ninguém. Aqui o erro por padrão de
  nome é mais caro que nas irmãs: **excesso de visibilidade concedido ninguém reclama.**
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @escopos ~w(team organization)

  @type t :: %__MODULE__{}

  schema "eo_role_visibility_grants" do
    field :tenant_id, :binary_id
    field :organizational_role_id, :binary_id
    field :scope, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "Os escopos que a tela oferece. Uma lista só — a tela lê daqui."
  @spec escopos() :: [String.t()]
  def escopos, do: @escopos

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(concessao, attrs) do
    concessao
    |> cast(attrs, [
      :tenant_id,
      :organizational_role_id,
      :scope,
      :declared_by_user_id,
      :declared_at,
      :revoked_by_user_id,
      :revoked_at
    ])
    |> validate_required([
      :tenant_id,
      :organizational_role_id,
      :scope,
      :declared_by_user_id,
      :declared_at
    ])
    |> validate_inclusion(:scope, @escopos)
    |> unique_constraint(:scope, name: :eo_concessao_vigente_do_papel_index)
  end
end
