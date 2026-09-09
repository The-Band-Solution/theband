defmodule TheBand.Ingestion.Janela do
  @moduledoc """
  O que toda etapa faz quando a janela de cota fecha no meio — ADR 0006 §5, ADR 0007.

  Duas funções, e as sete etapas as usam do mesmo jeito:

  - `ate_fechar/2` percorre os resultados (de uma lista ou de um `async_stream`) e **para
    no primeiro** que diz `sem_janela: true`, devolvendo `{:sem_janela, reset}`. As tarefas
    em voo terminam; as não iniciadas nunca começam. Sem isso, cada repositório seguinte
    pediria licença ao gestor, seria recusado, e a etapa "completaria" com buracos — que é
    o sucesso silencioso que a ADR 0006 §5 fechou nas verificações.
  - `segundos_ate/1` traduz o reset em espera para o Oban, com a folga de um minuto.
  """

  @folga_segundos 60
  @espera_padrao_segundos 900

  @doc """
  Percorre `enumeravel` aplicando `traduzir` a cada item e para na janela fechada.

  Devolve a lista de resultados, ou `{:sem_janela, reset}` no primeiro resultado com
  `sem_janela: true`. Serve tanto para uma lista de repositórios (`traduzir` coleta) quanto
  para um `async_stream` já em andamento (`traduzir` desembrulha `{:ok, r}` / `{:exit, m}`).
  """
  @spec ate_fechar(Enumerable.t(), (term() -> map())) ::
          [map()] | {:sem_janela, DateTime.t() | nil}
  def ate_fechar(enumeravel, traduzir) do
    enumeravel
    |> Enum.reduce_while([], fn item, acumulado ->
      case traduzir.(item) do
        %{sem_janela: true} = parada -> {:halt, {:sem_janela, Map.get(parada, :reset)}}
        resultado -> {:cont, [resultado | acumulado]}
      end
    end)
    |> case do
      {:sem_janela, _reset} = parada -> parada
      resultados -> Enum.reverse(resultados)
    end
  end

  @doc "Segundos até o reset, com um minuto de folga; quinze minutos quando o reset é desconhecido."
  @spec segundos_ate(DateTime.t() | nil) :: pos_integer()
  def segundos_ate(%DateTime{} = reset),
    do: max(DateTime.diff(reset, DateTime.utc_now(), :second) + @folga_segundos, @folga_segundos)

  def segundos_ate(_desconhecido), do: @espera_padrao_segundos
end
