defmodule TheBand.Tenants.Schemas.UserSession do
  @moduledoc """
  Uma sessão aberta — feature 064, T009, FR-004. Desenho em
  `specs/064-segredo-em-repouso/data-model.md`.

  Depende de: nenhuma ontologia. É infraestrutura de acesso, como `ApiAccessToken`.

  ## O bruto não existe aqui

  A linha guarda `token_hash`, o SHA-256 do token. O valor bruto vive só no cookie, que é
  assinado. Quem lê um dump, mesmo tendo o `SECRET_KEY_BASE`, não monta um cookie válido: o
  resumo não devolve o bruto.

  `Inspect` exclui `token_hash`. O resumo sozinho não abre sessão, mas é um verificador, e
  verificador não vai para log. Foi um struct com segredo dentro, numa mensagem de erro, que
  deixou um token do GitHub oito dias em `oban_jobs.errors`.

  ## `password_epoch` é da linha, e não do cookie

  É a época da senha com que a sessão nasceu. No cookie, quem tem o `SECRET_KEY_BASE` a
  reassinaria com a época nova (achado S2). Ela não é segredo: ver `TheBand.Tenants.User`.

  ## O que este schema não faz

  Não gera o token, não resume, não confere e não encerra: isso é `TheBand.Tenants.Sessions`
  (T011). Aqui fica só a forma da linha e o que ela recusa gravar.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Inspect, except: [:token_hash]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_sessions" do
    field :tenant_id, :binary_id
    field :user_id, :binary_id
    field :token_hash, :binary
    field :password_epoch, :integer

    # Nulo é **aberta**. A validade de 7 dias não escreve aqui: é lida contra `inserted_at` a
    # cada conferência, e a retenção (T020) cobre a sessão que venceu sem ser encerrada.
    field :ended_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @campos ~w(tenant_id user_id token_hash password_epoch)a

  @doc "A linha nova. O encerramento não passa por aqui — tem caminho próprio."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sessao, attrs) do
    sessao
    |> cast(attrs, @campos)
    |> validate_required(@campos)
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id, name: :user_sessions_user_id_fkey)
  end
end
