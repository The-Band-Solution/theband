defmodule TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole do
  @moduledoc """
  `eo.organizational_role` — papel social reconhecido pela organização.

  Catálogo reificado: papel é **linha**, não valor de enum (ADR 0004, D6). Papel
  novo é um `INSERT`, não uma migração.

  Esta tabela nasce vazia na feature 001: o GitHub não fornece papel
  organizacional, e `MAINTAINER`/`MEMBER` não são papéis.

  ## Da ORGANIZAÇÃO, e não do tenant — issue #317

  A feature 043 trocou o escopo. A equipe sempre teve `organization_id`; o papel não tinha, e
  um papel cadastrado vazava para as três organizações do tenant, que não compartilham
  vocabulário nenhum. É a mesma classe do defeito de escopo da issue #446.

  ## Duas origens, e exatamente uma por linha

  `catalog_concept_id` preenchido significa que o papel veio da rede —
  `sro.product_owner_role` e os outros três filhos de `sro.scrum_role`.
  `declared_by_user_id` preenchido significa que alguém o escreveu na tela.

  A `CHECK` do banco garante que é uma e só uma. Sem ela um papel afirmaria as duas origens, e
  a tela não teria o que mostrar como proveniência.

  **O papel do catálogo só vira linha quando alguém o usa** — ver `EO.RoleCatalog`. Até lá ele
  existe na composição, sem `id`.

  ## O código é a identidade

  Nome é editável; código não. Trocar o código faria os vínculos existentes apontarem para
  outra coisa sem que nada avisasse, e nenhuma função pública o permite.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "eo_organizational_roles" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :organization_id, :binary_id

    field :code, :string
    field :name, :string

    # `sro.scrum_master_role` quando vem da rede; nulo quando alguém declarou.
    field :catalog_concept_id, :string
    field :declared_by_user_id, :binary_id
    field :updated_by_user_id, :binary_id

    # Ocultar NÃO é apagar: vínculos que já usam o papel continuam válidos.
    field :hidden_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [
      :tenant_id,
      :organization_id,
      :internal_id,
      :record_version,
      :code,
      :name,
      :catalog_concept_id,
      :declared_by_user_id,
      :hidden_at
    ])
    |> validate_required([:tenant_id, :organization_id, :internal_id, :code, :name])
    |> validate_origem_unica()
    # **O erro cai em `:code`**, e não em `:tenant_id`. `unique_constraint/2` com lista põe a
    # mensagem no primeiro campo, e ninguém digita o tenant: quem preenche o formulário
    # preenche o código, e é lá que a mensagem precisa aparecer.
    |> unique_constraint(:code, name: :eo_organizational_roles_por_organizacao_index)
    |> check_constraint(:catalog_concept_id,
      name: :papel_tem_uma_origem_so,
      message: "papel vem do catálogo OU é declarado por alguém, nunca os dois"
    )
  end

  @doc """
  Renomeia — e **não** alcança `code`.

  O código é a identidade. Uma função que o alterasse faria os vínculos existentes apontarem
  para outra coisa sem que nada avisasse, e por isso ela não existe.
  """
  @spec rename_changeset(t(), map()) :: Ecto.Changeset.t()
  def rename_changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :updated_by_user_id])
    |> validate_required([:name])
  end

  # A `CHECK` do banco é a garantia; esta validação é para o erro chegar ao formulário em vez
  # de virar `Ecto.ConstraintError`.
  defp validate_origem_unica(changeset) do
    conceito = get_field(changeset, :catalog_concept_id)
    autor = get_field(changeset, :declared_by_user_id)

    case {conceito, autor} do
      {nil, nil} ->
        add_error(
          changeset,
          :catalog_concept_id,
          "papel precisa de uma origem: catálogo ou pessoa"
        )

      {c, a} when is_binary(c) and not is_nil(a) ->
        add_error(
          changeset,
          :catalog_concept_id,
          "papel não pode vir do catálogo e ser declarado"
        )

      _ ->
        changeset
    end
  end
end
