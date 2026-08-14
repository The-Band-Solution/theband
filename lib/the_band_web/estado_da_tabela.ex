defmodule TheBandWeb.EstadoDaTabela do
  @moduledoc """
  Lê busca, ordenação e página **do endereço**, e devolve também o que não deu para ler.

  ## Por que no endereço

  Estado que vive só no socket some ao recarregar, e o endereço não é compartilhável: quem pede
  ajuda sobre uma lista precisa descrever o que digitou em vez de mandar o link. É o corte
  declarado da feature 017 — FR-010 e SC-006, escritos e não entregues (issue #292).

  ## Parâmetro inválido é **dito**

  `?ordem=inexistente` não pode derrubar a tela nem ordenar em silêncio por outra coisa. As duas
  saídas são ruins pelo mesmo motivo: quem mandou o link acha que está vendo o que pediu.

  Por isso `ler/2` devolve `{estado, avisos}`. O estado sempre existe — cai no padrão quando o
  parâmetro não serve —, e cada aviso nomeia o parâmetro, o valor recebido e o que foi usado no
  lugar. Quem chama decide como mostrar; o que não pode é engolir.

  Um único módulo para as duas telas porque a regra é uma: `/work` e a página do repositório
  ordenariam por critérios diferentes se cada uma escrevesse a sua, e a divergência apareceria
  como link que abre diferente do que o outro vê.
  """

  @direcoes ~w(asc desc)

  @typedoc "Busca, ordenação e página, prontos para a consulta."
  @type estado :: %{
          busca: String.t(),
          ordem: {atom(), :asc | :desc} | nil,
          pagina: pos_integer()
        }

  @doc """
  Lê os parâmetros. `campos` é a lista de colunas que a tela ordena, como átomos.

  Devolve `{estado, avisos}`, com `avisos` vazio quando tudo foi entendido.
  """
  @spec ler(map(), [atom()], String.t() | nil) :: {estado(), [String.t()]}
  def ler(params, campos, prefixo \\ nil) do
    {ordem, aviso_ordem} = ordem(params, campos, prefixo)
    {pagina, aviso_pagina} = pagina(params, prefixo)

    estado = %{busca: busca(params, prefixo), ordem: ordem, pagina: pagina}

    {estado, Enum.reject([aviso_ordem, aviso_pagina], &is_nil/1)}
  end

  # O nome do parâmetro no endereço. Sem prefixo é `q`, `ordem`, `dir`, `pagina` — o endereço
  # que a feature 019 entregou, e que não pode mudar. Com prefixo é `<prefixo>_q`, e ele
  # existe porque quatro telas têm mais de uma tabela: dois `?q=` no mesmo endereço não dizem
  # de qual tabela cada um é.
  defp chave(nome, nil), do: nome
  defp chave(nome, prefixo), do: "#{prefixo}_#{nome}"

  @doc """
  Monta a query string a partir do estado, omitindo o que está no padrão.

  Omitir o padrão é o que mantém `/work` como `/work` enquanto ninguém buscou nem ordenou —
  um endereço cheio de `?q=&ordem=&pagina=1` sugere que alguém escolheu aquilo.
  """
  @spec para_query(estado(), keyword()) :: [{String.t(), term()}]
  def para_query(estado, extra \\ []) do
    prefixo = Map.get(estado, :prefixo)

    # A ordem dos parâmetros é fixa — o que a tela filtra primeiro aparece primeiro. Endereço
    # que muda de ordem sozinho parece endereço diferente para quem compara dois links.
    (Enum.map(extra, fn {k, v} -> {to_string(k), v} end) ++
       [{chave_de_query("q", prefixo), estado.busca}] ++
       ordem_em_query(estado.ordem, prefixo) ++
       [{chave_de_query("pagina", prefixo), estado.pagina}])
    |> Enum.reject(fn {chave, valor} ->
      valor in [nil, ""] or (chave == chave_de_query("pagina", prefixo) and valor == 1)
    end)
  end

  # **Chave de texto, e não átomo.** `String.to_atom` sobre nome composto criaria átomo a
  # partir de configuração de tela, e é a construção que o Sobelow já reprovou aqui uma vez.
  # `Plug.Conn.Query` codifica chave de texto igual.
  defp chave_de_query(nome, nil), do: nome
  defp chave_de_query(nome, prefixo), do: "#{prefixo}_#{nome}"

  defp ordem_em_query(nil, _prefixo), do: []

  defp ordem_em_query({campo, dir}, prefixo),
    do: [{chave_de_query("ordem", prefixo), campo}, {chave_de_query("dir", prefixo), dir}]

  @doc """
  A ordem seguinte ao clicar numa coluna.

  Clicar de novo na mesma inverte; clicar noutra recomeça crescente. É o que a pessoa espera, e
  é o que dispensa um segundo controle para escolher a direção.
  """
  @spec proxima_ordem({atom(), :asc | :desc} | nil, atom()) :: {atom(), :asc | :desc}
  def proxima_ordem({campo, :asc}, campo), do: {campo, :desc}
  def proxima_ordem(_atual, campo), do: {campo, :asc}

  defp busca(params, prefixo) do
    params |> Map.get(chave("q", prefixo), "") |> to_string() |> String.trim()
  end

  defp ordem(params, campos, prefixo) do
    bruto = Map.get(params, chave("ordem", prefixo))
    dir = Map.get(params, chave("dir", prefixo), "asc")
    permitidos = Enum.map(campos, &Atom.to_string/1)

    cond do
      bruto in [nil, ""] ->
        {nil, nil}

      bruto not in permitidos ->
        {nil,
         "Sorting by “#{bruto}” is not available on this table — showing the default order. " <>
           "Available: #{Enum.join(permitidos, ", ")}."}

      dir not in @direcoes ->
        # O campo é válido e a direção não. Ordenar crescente **e dizer** é melhor do que
        # descartar a ordenação inteira: quem mandou o link pediu por aquela coluna.
        {{campo(bruto, campos), :asc},
         "Sort direction “#{dir}” is not one of asc or desc — sorted ascending."}

      true ->
        {{campo(bruto, campos), String.to_existing_atom(dir)}, nil}
    end
  end

  # O átomo sai da lista que a tela declarou, e nunca do texto recebido. Converter o parâmetro
  # é deixar quem manda a URL criar átomo, que é vazamento de memória por requisição.
  defp campo(bruto, campos), do: Enum.find(campos, &(Atom.to_string(&1) == bruto))

  defp pagina(params, prefixo) do
    case Map.get(params, chave("pagina", prefixo)) do
      nil ->
        {1, nil}

      bruto ->
        case Integer.parse(to_string(bruto)) do
          {n, ""} when n >= 1 -> {n, nil}
          _ -> {1, "Page “#{bruto}” is not a page number — showing the first page."}
        end
    end
  end
end
