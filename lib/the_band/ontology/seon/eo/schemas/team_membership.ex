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

    # QUANDO a declaração foi feita — o "em D" de "declarado por X em D" (FR-010). Não é
    # `inserted_at`: o vínculo OBSERVADO que foi completado com um papel nasceu antes da
    # declaração, e o `updated_at` dele some na escrita seguinte.
    field :declared_at, :utc_datetime

    # QUEM registrou a saída, e QUANDO registrou (FR-021, FR-022). Sem eles, fim declarado e
    # fim constatado pela coleta são a mesma coisa — uma data. `ended_at` é a data DA SAÍDA,
    # podendo ser retroativa; `end_declared_at` é o instante do registro. Colapsá-las faria
    # "saiu em março, declarado em setembro" virar "saiu em setembro", e o número já
    # apresentado para o período anterior mudaria.
    field :ended_by_user_id, :binary_id
    field :end_declared_at, :utc_datetime

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
      :declared_at,
      :ended_by_user_id,
      :end_declared_at,
      :invalidated_at,
      :invalidated_by_user_id,
      :invalidation_reason
    ])
    |> validate_required([:tenant_id, :internal_id, :person_id, :team_id])
    # O papel é obrigatório na DECLARAÇÃO, e ausente no vínculo OBSERVADO (2026-09-06). O
    # relator da ontologia exige os três; a plataforma materializa o observado com o papel
    # declaradamente ausente, e a tela diz isso. Declarar sem papel continua recusado.
    |> validar_papel_da_declaracao()
    |> validar_saida_declarada()
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

  # A DECLARAÇÃO É UM PAR, e a regra vale nas duas direções — decisão da pessoa mantenedora
  # em 2026-09-07.
  #
  # A metade que já existia: quem declara precisa dizer o papel. A metade que faltava: quem
  # grava um papel precisa dizer **quem** o declarou. As duas são declaração incompleta, e
  # barrar só uma era a assimetria que deixava passar `Developer` sem autor.
  #
  # Por que isso importa na tela: a origem do vínculo é derivada de `declared_by_user_id` —
  # sem autor, a linha é apresentada como **observada**, que significa "a origem mostra a
  # pessoa, e o papel não foi declarado". Um vínculo com papel e sem autor sairia como
  # "observado · Developer", contradizendo-se na frente de quem lê.
  #
  # Varrido antes de mudar: 24 chamadas gravavam papel sem autor, **todas em teste**; nenhum
  # caminho de produção, e zero linhas assim no banco de desenvolvimento (90 vínculos). Não
  # há fato consumado a preservar — só uma porta que ninguém tinha atravessado.
  #
  # O vínculo OBSERVADO continua legítimo: sem papel **e** sem autor, é a coleta afirmando
  # participação e nada mais (ADR 0008).
  defp validar_papel_da_declaracao(changeset) do
    papel = get_field(changeset, :organizational_role_id)
    autor = get_field(changeset, :declared_by_user_id)

    cond do
      autor && is_nil(papel) ->
        add_error(changeset, :organizational_role_id, "a declaração exige um papel")

      papel && is_nil(autor) ->
        add_error(changeset, :declared_by_user_id, "o papel declarado exige quem o declarou")

      true ->
        changeset
    end
  end

  # A SAÍDA DECLARADA também é um par: quem registrou e quando registrou andam juntos, e só
  # existem sobre um fim que existe. O banco impõe o trio (`eo_saida_declarada_completa`); o
  # changeset o traduz, para a recusa chegar à tela em vez de levantar.
  defp validar_saida_declarada(changeset) do
    autor = get_field(changeset, :ended_by_user_id)
    registrado = get_field(changeset, :end_declared_at)
    fim = get_field(changeset, :ended_at)

    cond do
      is_nil(autor) and is_nil(registrado) ->
        changeset

      is_nil(autor) or is_nil(registrado) ->
        add_error(changeset, :ended_by_user_id, "quem registrou a saída e quando andam juntos")

      is_nil(fim) ->
        add_error(changeset, :ended_at, "a saída registrada exige a data em que a pessoa saiu")

      true ->
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
