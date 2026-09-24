defmodule TheBand.Tenants.ApiAccessLog do
  @moduledoc """
  O registro de **leitura bem-sucedida** pela API pública — achado A1, 2026-09-22.

  ## A pergunta que isto passa a responder

  *"Esta credencial leu o painel de quem, e quantas vezes?"*

  Antes desta tabela a resposta era **"não se sabe"** — e a FR-024 da spec 045 aponta o
  registro de acesso como o caminho para perceber agregação. `AccessEvents` registra só
  recusa; `api_access_tokens.last_used_at` é um carimbo sobrescrito.

  ## O que entra, e o que nunca entra

  Entra: qual credencial (pelo **id público**), qual tenant, qual rota, qual alvo quando há,
  e quando.

  **Não entra o corpo da resposta.** O registro diz *quem leu o quê*, nunca *o que leu* —
  gravá-lo criaria uma segunda cópia do dado, com a mesma sensibilidade e sem o veredito na
  frente.

  **Não entra o segredo do token.** O `public_id` já é o identificador de busca, e é o que
  aparece na tela de tokens.

  ## `target_id` nulo é ausência dita

  Listagens não têm alvo. Nulo aqui significa *esta chamada não mirava um item*, e não *o
  alvo se perdeu*.
  """
  use Ecto.Schema

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "api_access_reads" do
    field :tenant_id, :binary_id
    field :token_public_id, :string
    field :route, :string
    field :target_id, :binary_id
    field :occurred_at, :utc_datetime_usec
  end

  @doc """
  Grava uma leitura. Chamada **depois** de a resposta ter saído com sucesso.

  Nunca levanta: um registro que derruba a resposta que ele observa trocaria um problema de
  auditoria por um de disponibilidade. A falha vai ao log, e o `:ok` é da requisição.
  """
  @spec registrar(map()) :: :ok
  def registrar(%{tenant_id: tenant_id, token_public_id: publico, route: rota} = attrs) do
    # UUID em **texto**, e não `Ecto.UUID.dump!/1`: com um schema, `insert_all` converte
    # sozinho, e a forma binária é recusada. A primeira versão passava o binário, e as 120
    # gravações falharam — todas resgatadas pelo `rescue`, todas invisíveis na resposta.
    {1, nil} =
      Repo.insert_all(__MODULE__, [
        %{
          tenant_id: tenant_id,
          token_public_id: publico,
          route: rota,
          target_id: attrs[:target_id],
          occurred_at: DateTime.utc_now()
        }
      ])

    :ok
  rescue
    erro ->
      require Logger

      # O `rescue` protege a **resposta**, não o registro: derrubar a requisição que se
      # observa trocaria um problema de auditoria por um de disponibilidade. Mas ele esconde
      # a falha, e foi o que aconteceu — por isso o teste afirma que a linha EXISTE, e não
      # apenas que nada levantou.
      Logger.warning("api: registro de leitura falhou · #{Exception.message(erro)}")
      :ok
  end

  @doc """
  Quantas leituras esta credencial fez na janela, **por rota**.

  É a consulta que a FR-024 pede. Devolve `%{rota => contagem}` — e não um total: volume
  anômalo numa rota é fato diferente de volume distribuído entre todas, e um número só não
  distingue os dois.

  Mapa **vazio** quando não houve leitura alguma. Não é zero por rota: rota que ninguém
  chamou não é rota chamada zero vezes.
  """
  @spec contar_por_rota(Tenant.t(), String.t(), pos_integer()) :: %{String.t() => pos_integer()}
  def contar_por_rota(%Tenant{id: tenant_id}, token_public_id, janela_em_segundos) do
    desde = DateTime.add(DateTime.utc_now(), -janela_em_segundos, :second)

    from(r in __MODULE__,
      where:
        r.tenant_id == ^tenant_id and r.token_public_id == ^token_public_id and
          r.occurred_at >= ^desde,
      group_by: r.route,
      select: {r.route, count(r.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  O uso de uma credencial na janela, **por rota**: quantas leituras e qual foi a última.

  É o que o painel da tela mostra — `R2.21` a `R2.23`. Ordenado pela contagem, decrescente,
  porque quem investiga procura onde o volume está.

  Lista **vazia** quando não houve leitura na janela. Não é uma linha por rota com zero: rota
  que ninguém chamou não é rota chamada zero vezes, e a diferença entre *não consultei* e
  *consultei e não achei* é a mesma que separa ausência de nada.
  """
  @spec uso_por_rota(Tenant.t(), String.t(), pos_integer()) :: [
          %{route: String.t(), reads: pos_integer(), last_one: DateTime.t()}
        ]
  def uso_por_rota(%Tenant{id: tenant_id}, token_public_id, janela_em_segundos) do
    desde = DateTime.add(DateTime.utc_now(), -janela_em_segundos, :second)

    from(r in __MODULE__,
      where:
        r.tenant_id == ^tenant_id and r.token_public_id == ^token_public_id and
          r.occurred_at >= ^desde,
      group_by: r.route,
      order_by: [desc: count(r.id), asc: r.route],
      select: %{route: r.route, reads: count(r.id), last_one: max(r.occurred_at)}
    )
    |> Repo.all()
  end

  @doc """
  As leituras de uma credencial, da mais recente para a mais antiga.

  Para quem investiga: a contagem diz **quanto**, esta diz **o quê**.
  """
  @spec listar_por_token(Tenant.t(), String.t(), keyword()) :: [map()]
  def listar_por_token(%Tenant{id: tenant_id}, token_public_id, opts \\ []) do
    from(r in __MODULE__,
      where: r.tenant_id == ^tenant_id and r.token_public_id == ^token_public_id,
      order_by: [desc: r.occurred_at],
      limit: ^Keyword.get(opts, :limit, 100)
    )
    |> Repo.all()
  end
end
