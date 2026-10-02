defmodule TheBand.Platform.Sessions do
  @moduledoc """
  A sessão do operador da plataforma — spec 070. Contrato em
  `specs/070-operador-da-plataforma/contracts/sessao-do-operador.md`.

  Depende de: nenhuma ontologia. Tabela própria (`platform_operator_sessions`), lida só aqui, e
  nunca por `TheBand.Tenants.Sessions` nem por `TheBandWeb.Sessao`.

  Nesta tarefa (T026) entra só `encerrar_do_operador/1`, que os três passos do cadastro chamam.
  Abrir e conferir a sessão é a T029.
  """
  import Ecto.Query

  alias TheBand.Platform.{Operator, OperatorSession}
  alias TheBand.Repo

  @doc """
  Encerra toda sessão aberta do operador e devolve quantas. Roda **dentro da transação de quem
  chama**, e não abre a sua.
  """
  @spec encerrar_do_operador(Operator.t()) :: {:ok, non_neg_integer()}
  def encerrar_do_operador(%Operator{id: id}) do
    {n, _} =
      Repo.update_all(
        from(s in OperatorSession, where: s.operator_id == ^id and is_nil(s.ended_at)),
        set: [ended_at: DateTime.utc_now(:second)]
      )

    {:ok, n}
  end
end
