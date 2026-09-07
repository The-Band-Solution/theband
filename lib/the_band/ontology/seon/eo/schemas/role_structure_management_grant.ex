defmodule TheBand.Ontology.SEON.EO.Schemas.RoleStructureManagementGrant do
  @moduledoc """
  O que um papel na organização permite **gerir** — spec 060, FR-080 a FR-082.

  Irmã de `RoleVisibilityGrant`, com o verbo trocado: aquela confere **ver** o painel de
  trabalho; esta confere **declarar a estrutura** — o papel de cada pessoa, a saída, o
  equívoco, a composição de subequipes, os papéis da organização e a ligação a projeto.

  Não é conceito da EO de referência: é a declaração adjacente, e desde 2026-09-07 as duas
  estão na base, em `priv/knowledge_base/ontology/seon/eo/modules/role_grants.yaml`. A de
  visibilidade vivia no código desde agosto **sem conceito declarado**, e as duas nasceram
  juntas na base para fechar a lacuna em vez de dobrá-la.

  ## Ver e mexer são decisões separadas

  A spec 045 (FR-022) as separa de propósito, e por isso são duas tabelas e não uma coluna
  `kind`: quem precisa das duas recebe as duas, e o registro diz qual é qual.

  ## Dois escopos, e nenhum booleano

  `team` alcança as equipes em que a pessoa tem o papel; `organization`, todas as equipes da
  organização. Um `is_manager` booleano perderia **quem concedeu, quando e até onde** — e numa
  decisão de escrita essas são as três perguntas seguintes.

  ## Nada vem por nome

  `Tech Leader` parece liderança e `Coordenador` também; a mesma organização pode ter um
  `Tech Lead` que é senioridade técnica e não coordena ninguém. Aqui o erro por padrão de nome
  é mais caro que na irmã: excesso de visibilidade concedido ninguém reclama; excesso de
  gestão concedido **reescreve a estrutura** de quem não deveria.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @escopos ~w(team organization)

  @type t :: %__MODULE__{}

  schema "eo_role_structure_management_grants" do
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
    # A duplicata vem do índice **parcial** — só o banco sabe o que está vigente no instante
    # da escrita. Sem declarar aqui, a violação levanta `Ecto.ConstraintError` em vez de
    # virar resposta, e a tela não teria o que exibir.
    |> unique_constraint(:scope, name: :eo_concessao_de_gestao_vigente_index)
  end
end
