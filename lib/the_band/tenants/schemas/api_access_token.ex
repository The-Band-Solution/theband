defmodule TheBand.Tenants.Schemas.ApiAccessToken do
  @moduledoc """
  A credencial que abre a API pública — spec 061, FR-001 a FR-012.

  ## `Inspect` derivado, e por que ele é a primeira linha do arquivo

  O schema exclui `token_hash` de `inspect/1`. Sem isso, um `IO.inspect` de depuração, um
  relatório de erro do Oban, ou uma exceção que carregue o struct despejam o verificador no
  log.

  **Não é hipótese.** Um token do GitHub ficou **oito dias em texto claro** em
  `oban_jobs.errors`, de 2026-09-04 a 2026-09-12, e está registrado no backlog. O caminho foi
  exatamente esse: um struct com segredo dentro, numa mensagem de erro.

  O valor em claro não precisa ser excluído — ele **não existe** aqui. Vive só no campo
  virtual `value`, preenchido uma vez no retorno da criação, e nunca lido do banco porque não
  está lá.

  ## O estado não é coluna

  `ativo`, `revogado` e `expirado` são **leitura** contra o instante da requisição, feita por
  `estado/2`. Coluna de estado exigiria job para virar expirado, e job cria a janela entre
  vencer e ser marcado — acesso concedido por atraso de fila (decisão Q3).

  ## O que este schema não faz

  Não valida o formato do token nem gera o segredo: isso é `TheBand.Tenants.ApiTokens`. Aqui
  só a forma da linha e o que ela recusa gravar.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @type estado :: :ativo | :revogado | :expirado

  @derive {Inspect, except: [:token_hash, :value]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_access_tokens" do
    field :tenant_id, :binary_id
    field :user_id, :binary_id

    field :label, :string
    field :public_id, :string
    field :token_hash, :binary
    field :last_four, :string

    field :created_by_user_id, :binary_id

    # Nulo é **"sem expiração"**, e quem renderiza escreve isso — nunca uma data vazia.
    field :expires_at, :utc_datetime

    # Nulo é **"nunca usado"**, e quem renderiza escreve isso — nunca a data de criação. Um
    # token recém-gerado e um que ninguém usou há meses são a mesma coisa para esta coluna.
    field :last_used_at, :utc_datetime

    field :revoked_at, :utc_datetime
    field :revoked_by_user_id, :binary_id

    # O valor em claro. **Virtual**, preenchido uma vez, e nunca lido do banco — FR-006.
    field :value, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id user_id label public_id token_hash last_four
             created_by_user_id expires_at)a
  @obrigatorios ~w(tenant_id user_id label public_id token_hash last_four)a

  @doc "A linha nova. Revogação e carimbo de uso não passam por aqui — têm caminho próprio."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(token, attrs) do
    token
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> update_change(:label, &String.trim/1)
    |> validate_length(:label, min: 1, max: 120)
    |> validate_length(:last_four, is: 4)
    |> unique_constraint([:tenant_id, :public_id],
      name: :api_access_tokens_tenant_id_public_id_index
    )
  end

  @doc """
  O estado, **lido** contra um instante — e nunca gravado.

  A ordem das cláusulas é a decisão: **revogado vence expirado**. Um token revogado que também
  passou da data é revogado, porque foi um ato de alguém; dizer "expirado" apagaria o ato e
  faria parecer que o relógio resolveu.
  """
  @spec estado(t(), DateTime.t()) :: estado()
  def estado(%__MODULE__{revoked_at: %DateTime{}}, _agora), do: :revogado

  def estado(%__MODULE__{expires_at: %DateTime{} = expira}, agora) do
    if DateTime.compare(expira, agora) == :gt, do: :ativo, else: :expirado
  end

  def estado(%__MODULE__{}, _agora), do: :ativo
end
