defmodule TheBand.Platform.Suspensions do
  @moduledoc """
  Listar, suspender e reativar organizações — spec 070. Contrato em
  `specs/070-operador-da-plataforma/contracts/suspensao.md`.

  Depende de: nenhuma ontologia. Usa `TheBand.Tenants` **só pelas funções públicas**: este módulo
  não lê nem escreve a tabela `tenants`, nem usa o schema `Tenant` em consulta (constituição,
  princípio X, letra D; achado D1).

  **Toda função recebe a sessão do operador e confere a autorização por dentro** (FR-014, O6).
  """
  alias TheBand.Platform.{OperatorSession, Sessions}
  alias TheBand.Tenants

  @type resumo :: %{
          id: Ecto.UUID.t(),
          name: String.t(),
          slug: String.t(),
          status: String.t(),
          ultimo_episodio_em: DateTime.t() | nil
        }

  @doc """
  Todas as organizações, por nome, com o estado e o último episódio de suspensão (FR-007).

  `ultimo_episodio_em` é `nil` — "nunca suspensa" — até `tenant_suspensions` existir (T044); a
  composição com ela entra em T056, como a segunda das duas consultas do contrato.
  """
  @spec listar_organizacoes(OperatorSession.t()) :: {:ok, [resumo()]} | {:error, :nao_autorizado}
  def listar_organizacoes(%OperatorSession{} = sessao) do
    with :ok <- Sessions.autorizada(sessao) do
      {:ok, Enum.map(Tenants.resumos_para_a_plataforma(), &Map.put(&1, :ultimo_episodio_em, nil))}
    end
  end
end
