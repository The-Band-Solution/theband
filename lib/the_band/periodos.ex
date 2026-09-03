defmodule TheBand.Periodos do
  @moduledoc """
  A interseção de períodos — feature 058.

  **Função pura.** Não consulta nada, e é por isso que mora aqui: intersectar
  datas não pertence a EO, SPO nem CIRO, e pôr a regra dentro de uma delas
  obrigaria as outras a alcançá-la.

  ## A borda

  `[início, fim)` — fechada no início, aberta no fim. A mesma convenção da
  feature 057. No instante exato do fim já não está dentro.

  ## As duas pontas nulas significam coisas diferentes

  É a razão de este módulo existir, e a assimetria é do domínio, não do código:

  | ponta | nulo significa |
  |---|---|
  | `inicio` | **não se sabe desde quando** — `eo_team_memberships.started_at` é anulável de propósito |
  | `fim` | **ainda vigente** — `ended_at` e `unlinked_at` nulos são o vínculo em curso |

  Tratar `inicio` nulo como *desde sempre* afirmaria o que ninguém disse: é o
  fallback silencioso que a feature 057 corrigiu no vínculo.

  Tratar `fim` nulo como *desconhecido* seria o erro oposto, e pior na prática —
  a maioria dos vínculos está em curso, e a marca de dúvida apareceria em quase
  toda linha até deixar de significar coisa alguma.

  Por isso o veredito tem **três** estados, e só a ponta de início produz o
  terceiro:

      :intersecta                              se sobrepõem, e o início é conhecido
      :nao_intersecta                          não se sobrepõem
      {:parcial, [:inicio_desconhecido]}       se sobrepõem, e falta o início

  Quem consome trata os três. É o custo de não mentir sobre o que se sabe.
  """

  @type periodo :: %{inicio: DateTime.t() | nil, fim: DateTime.t() | nil}
  @type borda :: :inicio_desconhecido
  @type veredito :: :intersecta | :nao_intersecta | {:parcial, [borda()]}

  @doc """
  O veredito da interseção de dois ou mais períodos.

  ## O que "não intersecta" significa quando há nulo

  A ausência de borda **não impede** a recusa: dois períodos com início nulo cujos
  fins são disjuntos continuam sendo `:nao_intersecta`, porque o que se sabe já
  basta para negar. O `{:parcial, _}` só aparece quando a sobreposição **depende**
  de uma borda que ninguém declarou.

  Dizer `{:parcial, _}` para um caso que já se sabe negativo seria o erro
  simétrico: transformar conhecimento em dúvida.

  ## Exemplos

      iex> jan = ~U[2026-01-01 00:00:00Z]
      iex> jun = ~U[2026-06-01 00:00:00Z]
      iex> TheBand.Periodos.interseccao([
      ...>   %{inicio: jan, fim: jun},
      ...>   %{inicio: jan, fim: nil}
      ...> ])
      :intersecta

      iex> jan = ~U[2026-01-01 00:00:00Z]
      iex> jun = ~U[2026-06-01 00:00:00Z]
      iex> TheBand.Periodos.interseccao([
      ...>   %{inicio: jan, fim: jun},
      ...>   %{inicio: nil, fim: nil}
      ...> ])
      {:parcial, [:inicio_desconhecido]}

      iex> jan = ~U[2026-01-01 00:00:00Z]
      iex> jun = ~U[2026-06-01 00:00:00Z]
      iex> TheBand.Periodos.interseccao([
      ...>   %{inicio: jan, fim: jun},
      ...>   %{inicio: jun, fim: nil}
      ...> ])
      :nao_intersecta
  """
  @spec interseccao([periodo()]) :: veredito()
  def interseccao([]), do: :nao_intersecta
  def interseccao([_um]), do: :intersecta

  def interseccao(periodos) when is_list(periodos) do
    if disjuntos?(periodos), do: :nao_intersecta, else: veredito_com_bordas(periodos)
  end

  @doc """
  Se um instante cai dentro do período, com a borda `[início, fim)`.

  Nulo é permissivo aqui **de propósito**: quem chama já sabe que a borda é
  desconhecida, porque `interseccao/1` disse. Esta função responde a pergunta
  restrita "o que se sabe contradiz?", e não "o que se sabe confirma?".
  """
  @spec contem?(periodo(), DateTime.t()) :: boolean()
  def contem?(%{inicio: inicio, fim: fim}, quando) do
    depois_do_inicio?(inicio, quando) and antes_do_fim?(fim, quando)
  end

  # ------------------------------------------------------------------ privados

  # Dois períodos se sobrepõem quando cada um começa antes do fim do outro.
  # Com nulo, a comparação é otimista: o que se sabe não contradiz. A recusa só
  # sai quando duas bordas CONHECIDAS se cruzam na ordem errada.
  defp disjuntos?(periodos) do
    Enum.any?(pares(periodos), fn {a, b} -> not sobrepoe?(a, b) end)
  end

  defp pares(lista) do
    for {a, i} <- Enum.with_index(lista),
        {b, j} <- Enum.with_index(lista),
        i < j,
        do: {a, b}
  end

  defp sobrepoe?(%{inicio: ia, fim: fa}, %{inicio: ib, fim: fb}) do
    comeca_antes_do_fim?(ia, fb) and comeca_antes_do_fim?(ib, fa)
  end

  # `[início, fim)`: começar exatamente no fim do outro já é estar fora.
  defp comeca_antes_do_fim?(nil, _fim), do: true
  defp comeca_antes_do_fim?(_inicio, nil), do: true
  defp comeca_antes_do_fim?(inicio, fim), do: DateTime.compare(inicio, fim) == :lt

  defp veredito_com_bordas(periodos) do
    case bordas_desconhecidas(periodos) do
      [] -> :intersecta
      bordas -> {:parcial, bordas}
    end
  end

  # Só a ponta de INÍCIO produz dúvida. `fim` nulo é o vínculo em curso — um fato,
  # e não uma lacuna.
  defp bordas_desconhecidas(periodos) do
    if Enum.any?(periodos, &is_nil(&1.inicio)), do: [:inicio_desconhecido], else: []
  end

  defp depois_do_inicio?(nil, _quando), do: true
  defp depois_do_inicio?(inicio, quando), do: DateTime.compare(inicio, quando) != :gt

  defp antes_do_fim?(nil, _quando), do: true
  defp antes_do_fim?(fim, quando), do: DateTime.compare(fim, quando) == :gt
end
