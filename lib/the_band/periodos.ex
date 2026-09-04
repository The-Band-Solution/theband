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
  basta para negar.

  Dizer `{:parcial, _}` para um caso que já se sabe negativo seria o erro
  simétrico: transformar conhecimento em dúvida.

  ## A marca só aparece quando a sobreposição DEPENDE da borda que falta

  **Corrigido em 2026-09-04**, e é a segunda correção deste trecho — a primeira
  (2026-09-03) foi da documentação, para parar de prometer o que o código não
  fazia. Esta é do código.

  O que havia:

      defp bordas_desconhecidas(periodos) do
        if Enum.any?(periodos, &is_nil(&1.inicio)), do: [:inicio_desconhecido], else: []
      end

  Qualquer início nulo marcava, mesmo quando a sobreposição era certa por outro
  caminho:

      membro  = jan–dez     (início conhecido)
      vinculo = jan–dez     (início conhecido)
      janela  = ?–jun       (início nulo)

  A sobreposição jan–jun está **inteira** dentro das duas pontas conhecidas: não
  importa onde a janela comece, ela existe. O veredito, ainda assim, era
  `{:parcial, [:inicio_desconhecido]}`.

  **Por que isso importava mais depois da feature 058:** a tela passou a mostrar a
  marca. Uma equipe cujos vínculos não têm `started_at` a veria em toda linha, e
  marca que aparece sempre não distingue nada — que é exatamente o que este módulo
  diz querer evitar duas seções acima.

  ### A regra, e por que ela é essa

  Um período de início desconhecido é `[x, fim)` com `x < fim`: sabe-se que
  terminou (ou termina) em `fim`, e não desde quando vale. O **pior caso** é `x`
  imediatamente antes de `fim` — o vínculo mais curto possível.

  A sobreposição é **certa** quando existe instante comum mesmo nesse pior caso:

      S = maior dos inícios conhecidos           (nenhum: -infinito)
      E = menor dos fins conhecidos              (nenhum: +infinito)
      P = menor dos fins dos períodos SEM início (fim nulo: +infinito)

      certa  <=>  P > S  e  P <= E

  `P` é o instante crítico: o único lugar onde os períodos de início desconhecido
  certamente estão é logo antes do fim deles.

  Sem nenhum início nulo não há dúvida a levantar, e o veredito é `:intersecta`.

  ### O que a mudança custa a quem chama

  `{:parcial, _}` passou a significar algo **mais forte**: a resposta depende de
  uma data que ninguém declarou. Quem já tratava os três estados continua correto;
  o que muda é que a marca aparece menos, e quando aparece, aparece por um motivo.

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

  E o caso que a correção de 2026-09-04 mudou: o início desconhecido está numa
  ponta cujo fim cai DENTRO do outro período, então a sobreposição existe sem
  depender de onde ele começou.

      iex> jan = ~U[2026-01-01 00:00:00Z]
      iex> jun = ~U[2026-06-01 00:00:00Z]
      iex> dez = ~U[2026-12-01 00:00:00Z]
      iex> TheBand.Periodos.interseccao([
      ...>   %{inicio: jan, fim: dez},
      ...>   %{inicio: nil, fim: jun}
      ...> ])
      :intersecta

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
  #
  # E a dúvida só é levantada quando a sobreposição DEPENDE dela: o pior caso de um
  # período `[?, fim)` é começar imediatamente antes de `fim`, e se ainda assim
  # houver instante comum, não há o que duvidar.
  defp bordas_desconhecidas(periodos) do
    sem_inicio = Enum.filter(periodos, &is_nil(&1.inicio))

    cond do
      sem_inicio == [] -> []
      sobreposicao_certa?(periodos, sem_inicio) -> []
      true -> [:inicio_desconhecido]
    end
  end

  # `P` é o instante crítico — o único lugar onde os períodos de início
  # desconhecido certamente estão. A sobreposição é certa quando ele cabe depois
  # de todos os inícios conhecidos e antes de todos os fins conhecidos.
  defp sobreposicao_certa?(periodos, sem_inicio) do
    case menor_fim(sem_inicio) do
      {:ok, critico} ->
        depois_de_todos_os_inicios?(periodos, critico) and
          cabe_antes_dos_fins?(periodos, critico)

      # Algum período sem início tem fim nulo: ele pode ter começado depois de
      # tudo e ainda estar em curso, e não há instante que se possa garantir.
      :indeterminado ->
        false
    end
  end

  defp menor_fim(periodos) do
    if Enum.any?(periodos, &is_nil(&1.fim)) do
      :indeterminado
    else
      {:ok, periodos |> Enum.map(& &1.fim) |> Enum.min_by(&DateTime.to_unix/1)}
    end
  end

  # O instante imediatamente ANTES de `critico` precisa estar depois de cada
  # início conhecido — daí a comparação estrita.
  defp depois_de_todos_os_inicios?(periodos, critico) do
    periodos
    |> Enum.reject(&is_nil(&1.inicio))
    |> Enum.all?(&(DateTime.compare(&1.inicio, critico) == :lt))
  end

  defp cabe_antes_dos_fins?(periodos, critico) do
    periodos
    |> Enum.reject(&is_nil(&1.fim))
    |> Enum.all?(&(DateTime.compare(critico, &1.fim) != :gt))
  end

  defp depois_do_inicio?(nil, _quando), do: true
  defp depois_do_inicio?(inicio, quando), do: DateTime.compare(inicio, quando) != :gt

  defp antes_do_fim?(nil, _quando), do: true
  defp antes_do_fim?(fim, quando), do: DateTime.compare(fim, quando) == :gt
end
