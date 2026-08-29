defmodule TheBandWeb.TabelaLive do
  @moduledoc """
  A fiação da tabela — os três eventos que toda tela com `data_table` responde.

  ## Por que funções, e não um `use` que injeta os `handle_event`

  Um macro que injeta cláusulas de `handle_event` esconde de quem lê a tela quais eventos ela
  responde, e a ordem das cláusulas passa a depender de onde o `use` foi escrito. A tela
  continua declarando os três eventos — em uma linha cada — e delega o corpo:

      def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
      def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
      def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  Três linhas visíveis valem mais que zero linhas mágicas: quem abre a tela vê o que ela faz.

  ## Toda tabela tem identidade, e por quê

  Quatro telas do repositório têm **duas ou mais** tabelas — a página da pessoa, o detalhe do
  repositório, a lista de trabalho e as regras de mapeamento. Sem identidade, os dois `buscar`
  chegam iguais ao `handle_event`, e o `?q=` do endereço não diz de qual tabela é.

  Por isso o estado é um **mapa por id**, e não três assigns soltos. E por isso cada tabela
  declara um prefixo de parâmetro: a primeira de uma tela usa `q`, `ordem`, `dir` e `pagina`
  — que é o endereço que a feature 019 entregou e que não pode mudar —, e as demais usam
  `<prefixo>_q` e companhia.

  ## `caminho/3` é da tela, e tem de ser

  Cada tela tem endereço próprio e parâmetros próprios. A função que monta o endereço é o
  único pedaço que não dá para compartilhar, e é por isso que ela é o argumento. Ela recebe o
  id da tabela porque uma tela com duas tabelas monta o mesmo endereço com parâmetros
  diferentes.

  ## Buscar e ordenar voltam para a página 1

  Buscar na página 7 e permanecer nela mostraria uma tabela vazia com a paginação afirmando
  que há mais — o resultado novo quase nunca tem sete páginas. O mesmo vale para ordenar: a
  página 7 de outra ordenação é outro conjunto de linhas, e ninguém pediu por ele.
  """

  use Gettext, backend: TheBandWeb.Gettext

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_patch: 2, put_flash: 3]

  alias TheBandWeb.EstadoDaTabela

  @doc """
  Lê o estado de todas as tabelas da tela a partir do endereço.

  `tabelas` é uma lista de `{id, campos_ordenaveis, prefixo}`. O prefixo `nil` é o da primeira
  tabela — parâmetros sem prefixo, que é o endereço da feature 019.
  """
  def aplicar(socket, params, tabelas) do
    {estados, avisos} =
      Enum.reduce(tabelas, {%{}, []}, fn {id, campos, prefixo}, {acc, avisos} ->
        {estado, novos} = EstadoDaTabela.ler(params, campos, prefixo)

        {Map.put(acc, id, Map.merge(estado, %{campos: campos, prefixo: prefixo})),
         avisos ++ novos}
      end)

    socket |> assign(tabelas: estados) |> avisar(avisos)
  end

  @doc """
  A query string com o estado de **todas** as tabelas da tela, aplicando a mudança a uma.

  Existe aqui, e não em cada tela, porque a regra é a mesma em todas: trocar de página numa
  tabela não pode apagar a busca da outra. A tela só decide o caminho:

      defp caminho(socket, id, mudancas) do
        ~p"/people/\#{socket.assigns.pessoa.id}?\#{Tabela.query(socket, id, mudancas)}"
      end

  A ordem dos parâmetros é estável — ordenada por id de tabela —, porque endereço que muda de
  ordem sozinho parece endereço diferente para quem compara dois links.
  """
  def query(socket, id, mudancas, extra \\ []) do
    tabelas =
      socket.assigns.tabelas
      |> Enum.sort_by(fn {chave, _} -> chave end)
      |> Enum.flat_map(&EstadoDaTabela.para_query(com_mudancas(&1, id, mudancas)))

    # O `extra` passa pelo mesmo corte que o resto: filtro vazio vira `?repositorio=` no
    # endereço, que sugere uma escolha que ninguém fez. É a FR-005 da feature 019.
    extra
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
    |> Kernel.++(tabelas)
  end

  defp com_mudancas({id, estado}, id, mudancas), do: Map.merge(estado, Map.new(mudancas))
  defp com_mudancas({_outra, estado}, _id, _mudancas), do: estado

  @doc "Nova busca, sempre a partir da primeira página."
  def buscar(%{"q" => q} = params, socket, caminho) do
    id = id_da_tabela(params, socket)
    {:noreply, push_patch(socket, to: caminho.(socket, id, busca: q, pagina: 1))}
  end

  @doc """
  Alterna a ordenação da coluna clicada.

  A mesma coluna clicada de novo inverte a direção; outra coluna começa crescente — é o que
  `EstadoDaTabela.proxima_ordem/2` decide, e a decisão vive lá porque a mesma regra vale para
  o endereço digitado à mão.
  """
  def ordenar(%{"campo" => campo} = params, socket, caminho) do
    id = id_da_tabela(params, socket)
    estado = socket.assigns.tabelas[id]

    # O átomo sai da lista declarada pela tela, nunca do texto recebido.
    case Enum.find(estado.campos, &(Atom.to_string(&1) == campo)) do
      # **Dito, e não engolido.** É a mesma regra da feature 019: ordenar em silêncio por
      # outra coisa faz quem clicou acreditar que a lista mudou. Aqui o clique só pode vir de
      # DOM adulterado — e mesmo assim a tela responde, em vez de não fazer nada.
      nil ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext(
             "errors",
             "Column %{campo} is not sortable here. Sortable: %{nomes}.",
             campo: campo,
             nomes: nomes(estado.campos)
           )
         )}

      encontrado ->
        ordem = EstadoDaTabela.proxima_ordem(estado.ordem, encontrado)
        {:noreply, push_patch(socket, to: caminho.(socket, id, ordem: ordem, pagina: 1))}
    end
  end

  @doc "Vai para a página pedida, sem mexer em busca nem ordenação."
  def pagina(%{"n" => n} = params, socket, caminho) do
    id = id_da_tabela(params, socket)

    case Integer.parse(to_string(n)) do
      {numero, ""} when numero >= 1 ->
        {:noreply, push_patch(socket, to: caminho.(socket, id, pagina: numero))}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "Page %{n} is not a page number. Showing the same.", n: n)
         )}
    end
  end

  # A tabela que emitiu. Uma tela com uma tabela só não precisa dizer qual — e a única que
  # existe é a resposta certa. Com duas, o valor vem do próprio botão.
  defp id_da_tabela(%{"tabela" => id}, _socket) when is_binary(id) and id != "", do: id
  defp id_da_tabela(_params, socket), do: socket.assigns.tabelas |> Map.keys() |> List.first()

  defp nomes(campos), do: campos |> Enum.map_join(", ", &Atom.to_string/1)

  defp avisar(socket, []), do: socket
  defp avisar(socket, avisos), do: put_flash(socket, :error, Enum.join(avisos, " "))
end
