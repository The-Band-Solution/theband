defmodule TheBand.ContadorDeConsultas do
  @moduledoc """
  A definição ÚNICA do contador de consultas dos testes de custo — issue #372.

  Eram quatro cópias com variações sutis, e a variação era o defeito: o handler de
  telemetria é **global** — conta toda consulta do BEAM na janela —, e cada exclusão
  aprendida numa cópia não chegava às outras. As três exclusões, e a mordida que
  ensinou cada uma:

  1. **as tabelas do Oban** (`oban_jobs`, `oban_peers`) — o `Oban.Stager` consulta a cada
     segundo, e um tick dentro da janela virava consulta atribuída à tela. Reprovava em
     máquina carregada, com o código certo (L42). A `source` não basta: o Oban consulta
     por SQL cru, e aí ela vem nula enquanto o texto diz `oban_jobs` — foi o 30 contra 31
     que derrubou a cobertura no PR #297;
  2. **`pg_notify`** — o notificador do Oban avisando um insert de job de **outro**
     processo; não é a página consultando. Foi o #372: o mesmo commit passou num gatilho
     do CI e reprovou no outro com +1 consulta que a tela não fez;
  3. **`schema_migrations`** — infraestrutura de setup, nunca custo de página.

  A caixa é esvaziada **antes** de anexar: mensagem atrasada da medição anterior entrava
  na contagem desta — um 22 onde a página faz 20. Número que muda entre execuções não
  mede nada.
  """

  @ignoradas ~w(oban_jobs oban_peers schema_migrations)

  @doc "Quantas consultas a função disparou."
  @spec contar((-> any())) :: non_neg_integer()
  def contar(fun) do
    fun |> listar() |> length()
  end

  @doc """
  As consultas que a função disparou, como assinaturas legíveis — `source` quando há,
  o começo do SQL quando não. É o que permite ao teste dizer **o que** entrou entre duas
  medições, e não só que o número mudou.
  """
  @spec listar((-> any())) :: [String.t()]
  def listar(fun) do
    ref = make_ref()
    pai = self()

    esvaziar(ref)

    handler = fn _evento, _medidas, %{query: query} = meta, _config ->
      if contavel?(query, meta), do: send(pai, {ref, :consulta, assinatura(query, meta)})
    end

    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], handler, nil)
    fun.()
    :telemetry.detach({__MODULE__, ref})

    drenar(ref, [])
  end

  defp contavel?(query, meta) do
    String.starts_with?(query, "SELECT") and
      to_string(meta[:source]) not in @ignoradas and
      not String.contains?(query, "oban_") and
      not String.starts_with?(query, "SELECT pg_notify")
  end

  defp assinatura(query, meta) do
    case to_string(meta[:source]) do
      "" -> query |> String.slice(0, 60) |> String.replace(~r/\s+/, " ")
      origem -> origem
    end
  end

  defp esvaziar(ref) do
    receive do
      {^ref, :consulta, _} -> esvaziar(ref)
    after
      0 -> :ok
    end
  end

  defp drenar(ref, acc) do
    receive do
      {^ref, :consulta, assinatura} -> drenar(ref, [assinatura | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
