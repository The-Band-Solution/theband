defmodule TheBand.Tenants.AccountDisablement do
  @moduledoc """
  Um episódio de desativação de conta — aberto e fechado, nunca apagado.

  ## Por que é episódio, e não par de colunas em `users`

  Porque o par de colunas cabe **um**, e porque reativar apagava. A versão anterior fazia
  `disabled_at: nil, disabled_by_user_id: nil` na reativação — um `delete` escrito como
  `update`: depois dela, ninguém desativou aquela conta nunca. E uma conta desativada duas
  vezes perdia a primeira.

  Aqui a desativação **abre** com autor, instante e razão, e a reativação **fecha** com
  autor, instante e razão. Fechar não toca na abertura. É a forma de `ScopeGrant`, e pela
  mesma razão: o que um incidente de acesso precisa reconstruir é o que aconteceu, não o
  que está acontecendo.

  ## O equívoco, e o que ele faz

  `enable_reason == "disabled_by_mistake"` marca o episódio como equívoco: ele **deixa de
  contar** como desligamento e continua visível, na forma de
  `TeamMembership.invalidated_at`. Equívoco é dito, não removido.

  ## A razão vem do vocabulário declarado

  As cláusulas de `disable_reason` e `enable_reason` vivem em `access.account_lifecycle`,
  na base de conhecimento. O changeset **valida contra a base**, e não contra uma lista
  escrita aqui: lista em constante de módulo muda num diff e ninguém percebe que a
  plataforma passou a afirmar outra coisa (FR-069, e o precedente de
  `team.dashboard.thresholds`).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TheBand.Tenants.AccountLifecycle

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "account_disablements" do
    field :tenant_id, :binary_id
    field :user_id, :binary_id

    field :disabled_at, :utc_datetime
    field :disabled_by_user_id, :binary_id
    field :disable_reason, :string
    field :disable_note, :string

    field :enabled_at, :utc_datetime
    field :enabled_by_user_id, :binary_id
    field :enable_reason, :string
    field :enable_note, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Abre o episódio — a desativação, com autor, instante e razão.

  A nota é obrigatória para as razões que `access.account_lifecycle.note_required`
  declara, e opcional nas demais. Exigi-la em toda parte produziria `asdf`, que é pior
  que ausência porque **parece registro**.
  """
  @spec abrir_changeset(map()) :: Ecto.Changeset.t()
  def abrir_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :tenant_id,
      :user_id,
      :disabled_by_user_id,
      :disable_reason,
      :disable_note
    ])
    |> put_change(:disabled_at, DateTime.utc_now(:second))
    |> validate_required([:tenant_id, :user_id, :disabled_by_user_id, :disable_reason])
    |> validate_inclusion(:disable_reason, AccountLifecycle.codigos_de_desativacao(),
      message: "não está no vocabulário declarado em access.account_lifecycle"
    )
    |> exige_nota(:disable_reason, :disable_note, AccountLifecycle.nota_exigida_ao_desativar())
    |> unique_constraint([:tenant_id, :user_id], name: :account_disablements_aberto_index)
  end

  @doc """
  Fecha o episódio — a reativação, com autor, instante e razão.

  **Não toca em nenhum campo da abertura.** O `cast` lista só os quatro campos do
  fechamento, e é isso que faz a garantia ser estrutural em vez de disciplina.
  """
  @spec fechar_changeset(t(), map()) :: Ecto.Changeset.t()
  def fechar_changeset(%__MODULE__{} = episodio, attrs) do
    episodio
    |> cast(attrs, [:enabled_by_user_id, :enable_reason, :enable_note])
    |> put_change(:enabled_at, DateTime.utc_now(:second))
    |> validate_required([:enabled_by_user_id, :enable_reason])
    |> validate_inclusion(:enable_reason, AccountLifecycle.codigos_de_reativacao(),
      message: "não está no vocabulário declarado em access.account_lifecycle"
    )
    |> exige_nota(:enable_reason, :enable_note, AccountLifecycle.nota_exigida_ao_reativar())
    |> valida_investigacao(episodio)
  end

  @doc "O episódio está aberto? — `enabled_at` nulo, na forma de `ScopeGrant.vigente?/1`."
  @spec aberto?(t()) :: boolean()
  def aberto?(%__MODULE__{enabled_at: nil}), do: true
  def aberto?(_), do: false

  @doc """
  O episódio foi um equívoco? — fechado com `disabled_by_mistake`.

  Quem conta desligamentos **exclui** estes: a desativação não devia ter acontecido, e
  contá-la faria a medida afirmar um desligamento que ninguém decidiu. Continua visível.
  """
  @spec equivoco?(t()) :: boolean()
  def equivoco?(%__MODULE__{enable_reason: "disabled_by_mistake"}), do: true
  def equivoco?(_), do: false

  @doc "A abertura registrou autor? O backfill pode não ter — a coluna nasceu depois do ato."
  @spec autor_registrado?(t()) :: boolean()
  def autor_registrado?(%__MODULE__{disabled_by_user_id: nil}), do: false
  def autor_registrado?(_), do: true

  defp exige_nota(changeset, campo_razao, campo_nota, razoes_que_exigem) do
    if get_field(changeset, campo_razao) in razoes_que_exigem do
      changeset
      |> update_change(campo_nota, &normaliza/1)
      |> validate_required([campo_nota],
        message: "é obrigatória para esta razão"
      )
    else
      update_change(changeset, campo_nota, &normaliza/1)
    end
  end

  # Espaço em branco não é nota. Sem isto, `validate_required` aceitaria `"   "` e a
  # obrigatoriedade seria decorativa.
  defp normaliza(nil), do: nil

  defp normaliza(texto) when is_binary(texto) do
    case String.trim(texto) do
      "" -> nil
      limpo -> limpo
    end
  end

  defp normaliza(outro), do: outro

  # `investigation_closed_no_compromise` só existe contra uma desativação por suspeita de
  # comprometimento. Oferecê-la sempre faria a plataforma sugerir que houve investigação
  # onde não houve; aceitá-la sempre faria o registro afirmar isso. A tela não a oferece,
  # e o domínio também recusa — esconder na tela não é a defesa.
  defp valida_investigacao(changeset, %__MODULE__{disable_reason: abertura}) do
    razao = get_field(changeset, :enable_reason)
    exigida = AccountLifecycle.abertura_exigida_pela_reativacao(razao)

    if is_nil(exigida) or exigida == abertura do
      changeset
    else
      add_error(
        changeset,
        :enable_reason,
        "só é oferecida contra uma desativação por #{exigida}"
      )
    end
  end
end
