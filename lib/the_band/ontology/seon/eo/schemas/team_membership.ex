defmodule TheBand.Ontology.SEON.EO.Schemas.TeamMembership do
  @moduledoc """
  O vínculo de pessoa a equipe **com papel organizacional** — `eo.team_membership`.

  ## O que ele é, e o que a evidência é

  `TeamMembershipEvidence` guarda o que a origem **mostrou**: a pessoa aparece na equipe, com
  um nível de acesso da plataforma. Este relator guarda o que alguém **afirmou**: a pessoa
  desempenha aquele papel, naquela equipe, naquele período.

  São duas tabelas desde 2026-08-09, e é de propósito. A alternativa — uma coluna dizendo
  `observado` ou `declarado` — deixaria metade dos campos nulos em metade das linhas:
  evidência tem nível de acesso e marca de ausência; vínculo tem papel, período e autor.

  ## Por que ele estava vazio — e o vínculo OBSERVADO (emenda de 2026-09-06)

  `organizational_role_id` era obrigatório, e nenhum papel havia sido cadastrado. Medido em
  2026-08-14: **101 evidências, zero vínculos, zero papéis** — os três números são o mesmo
  fato.

  Medido de novo em 2026-09-06, com a coleta real: 59 evidências nas 8 equipes do GitHub,
  zero vínculos, toda medida por equipe vazia, e 78% das solicitações fora de qualquer
  medida. A decisão da pessoa mantenedora: a participação observada na ferramenta **vira
  vínculo na coleta**, com o papel declaradamente ausente — `organizational_role_id` nulo e
  `declared_by_user_id` nulo é o vínculo **observado**. Quem administra declara o papel
  depois, no mesmo vínculo. Declaração continua exigindo papel: é a validação abaixo.

  ## O período, e o que a ausência dele significa

  `started_at` nulo significa **não se sabe desde quando**, e nunca "começou hoje". Quem aloca
  pode não saber a data, e inventá-la afirmaria algo que ninguém disse.

  `ended_at` nulo é o vínculo vigente. Encerrar grava a data e **não apaga a linha** — a pessoa
  desempenhou aquele papel, e isso continua verdade depois de ela sair.

  ## O autor

  `declared_by_user_id` é o que distingue declaração de observação quando as duas convivem.
  Anulável de propósito: proibir nulo obrigaria a inventar um usuário-sistema para qualquer
  vínculo que não venha de alguém digitando — e autor falso mente mais que autor ausente.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "eo_team_memberships" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :person_id, :binary_id
    field :team_id, :binary_id
    field :organizational_role_id, :binary_id

    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    field :declared_by_user_id, :binary_id

    # Feature 055 — o EQUÍVOCO: o vínculo que nunca vigeu.
    #
    # Diferente de `ended_at`, que diz "esteve e não está mais". Aqui o período
    # inteiro deixa de valer, e a RAZÃO é o que distingue um engano registrado no
    # mesmo dia da entrada de alguém que entrou e saiu no mesmo dia.
    #
    # Vigente passa a ser `ended_at` nulo **E** `invalidated_at` nulo — as duas
    # condições, em toda consulta.
    field :invalidated_at, :utc_datetime
    field :invalidated_by_user_id, :binary_id
    field :invalidation_reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :record_version,
      :person_id,
      :team_id,
      :organizational_role_id,
      :started_at,
      :ended_at,
      :declared_by_user_id,
      :invalidated_at,
      :invalidated_by_user_id,
      :invalidation_reason
    ])
    |> validate_required([:tenant_id, :internal_id, :person_id, :team_id])
    # O papel é obrigatório na DECLARAÇÃO, e ausente no vínculo OBSERVADO (2026-09-06). O
    # relator da ontologia exige os três; a plataforma materializa o observado com o papel
    # declaradamente ausente, e a tela diz isso. Declarar sem papel continua recusado.
    |> validar_papel_da_declaracao()
    |> validar_periodo()
    |> unique_constraint([:tenant_id, :person_id, :team_id],
      name: :eo_team_memberships_observado_vigente_index
    )
    # A duplicata vem do índice **parcial** — só o banco sabe o que está vigente no instante
    # da escrita. Sem declarar aqui, a violação levanta `Ecto.ConstraintError` em vez de
    # virar resposta, e a tela não teria o que exibir.
    |> unique_constraint([:person_id, :team_id, :organizational_role_id],
      name: :eo_team_memberships_vigente_index
    )
  end

  defp validar_papel_da_declaracao(changeset) do
    if get_field(changeset, :declared_by_user_id) &&
         is_nil(get_field(changeset, :organizational_role_id)) do
      add_error(changeset, :organizational_role_id, "a declaração exige um papel")
    else
      changeset
    end
  end

  # Fim antes do começo é dado impossível, e a recusa é do changeset — não do banco. A
  # mensagem precisa chegar à tela, e constraint devolveria erro sem lugar para exibir.
  defp validar_periodo(changeset) do
    inicio = get_field(changeset, :started_at)
    fim = get_field(changeset, :ended_at)

    if inicio && fim && DateTime.compare(fim, inicio) == :lt do
      add_error(changeset, :ended_at, "não pode ser anterior ao início")
    else
      changeset
    end
  end
end
