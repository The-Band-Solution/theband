defmodule TheBand.ReviewNetwork.Parameters do
  @moduledoc """
  Os parâmetros da rede de revisão, lidos da base de conhecimento — feature 073, T013 (FR-005,
  FR-008, FR-011, FR-013; research.md R11; revisao-semantica.md, seção 3).

  Duas regras, que mudam por razões diferentes:

  - `review.network.parameters` — janelas, k, amostra mínima: a **apresentação**;
  - `review.network.edge` — os estados que contam e a ordem das exclusões: o **significado** da
    aresta.

  E as medidas que respondem à necessidade `review.concentration`, cuja versão vai para a
  proveniência da leitura (FR-011), junto com a das duas regras.

  **Levanta, e nunca devolve valor de reserva**, quando uma regra, uma chave ou uma medida falta
  (princípio IV; precedente `TheBandWeb.Plugs.ApiRateLimit`): em constante, o número muda num diff
  de código e ninguém percebe que a plataforma passou a afirmar outra coisa.

  **A ordem das exclusões é conferida, e não lida para decidir**: `Classification` a implementa
  (bot ou aplicativo → sem pessoa ligada → auto-revisão), e se a base declarar outra, a carga
  levanta em vez de a rede passar a discordar da base em silêncio.

  O grupo mínimo (3) não é lido: com a Q4 os grupos são do recorte, e a regra não tem caso nesta
  fatia.

  Depende de: `TheBand.Ontology.KnowledgeBase`.
  """

  alias TheBand.Ontology.KnowledgeBase

  @parametros "review.network.parameters"
  @aresta "review.network.edge"
  @necessidade "review.concentration"

  # A ordem que `Classification` implementa, nos códigos da base.
  @ordem_implementada ~w(bot_or_app unlinked_person self_review)

  @type t :: %{
          windows: [pos_integer()],
          default_window: pos_integer(),
          ks: [pos_integer()],
          minimum_sample: pos_integer(),
          counted_states: [String.t()],
          knowledge_versions: %{String.t() => pos_integer()}
        }

  @doc "Os parâmetros da base, ou levanta dizendo o que falta."
  @spec fetch!() :: t()
  def fetch! do
    necessidade = artefato!(&KnowledgeBase.information_need/1, @necessidade)
    ids = Map.get(necessidade, "candidate_measurements") || falha!(@necessidade, "sem medidas")

    medidas = Map.new(ids, fn id -> {id, artefato!(&KnowledgeBase.measurement/1, id)} end)

    from_rules!(
      artefato!(&KnowledgeBase.rule/1, @parametros),
      artefato!(&KnowledgeBase.rule/1, @aresta),
      medidas
    )
  end

  @doc """
  Lê e valida as duas regras e as medidas já carregadas. Levanta dizendo a regra e a chave quando
  falta uma, ou quando um valor não é o que a regra promete (inteiros positivos, k crescente,
  padrão dentro da lista, a ordem das exclusões que o código implementa).
  """
  @spec from_rules!(map(), map(), %{String.t() => map()}) :: t()
  def from_rules!(parametros, aresta, medidas) do
    janelas = valor!(parametros, @parametros, ["window_days", "values", "allowed"])
    padrao = valor!(parametros, @parametros, ["window_days", "values", "default"])
    ks = valor!(parametros, @parametros, ["k_values", "values", "k"])
    minimo = valor!(parametros, @parametros, ["min_reviews", "values", "min_reviews"])
    estados = valor!(aresta, @aresta, ["counted_states", "values", "states"])
    ordem = valor!(aresta, @aresta, ["exclusions", "values", "order"])

    inteiros_positivos!(@parametros, "window_days.allowed", janelas)
    inteiros_positivos!(@parametros, "k_values.k", ks)
    inteiros_positivos!(@parametros, "min_reviews", [minimo])

    unless padrao in janelas,
      do: falha!(@parametros, "window_days.default fora de window_days.allowed")

    unless ks == Enum.sort(Enum.uniq(ks)), do: falha!(@parametros, "k_values.k não é crescente")

    unless is_list(estados) and estados != [] and Enum.all?(estados, &is_binary/1),
      do: falha!(@aresta, "counted_states.states não é lista de estados")

    unless ordem == @ordem_implementada,
      do: falha!(@aresta, "exclusions.order difere da que a classificação implementa")

    %{
      windows: janelas,
      default_window: padrao,
      ks: ks,
      minimum_sample: minimo,
      counted_states: estados,
      knowledge_versions:
        medidas
        |> Map.new(fn {id, medida} -> {id, versao!(medida, id)} end)
        |> Map.put(@parametros, versao!(parametros, @parametros))
        |> Map.put(@aresta, versao!(aresta, @aresta))
    }
  end

  defp artefato!(buscar, id) do
    case buscar.(id) do
      {:ok, artefato} -> artefato
      :error -> raise "#{id} ausente da base de conhecimento"
    end
  end

  defp valor!(regra, id, caminho) do
    case get_in(regra, ["rules" | caminho]) do
      nil -> falha!(id, "#{Enum.join(caminho, ".")} ausente")
      valor -> valor
    end
  end

  defp versao!(artefato, id) do
    case Map.get(artefato, "version") do
      v when is_integer(v) and v > 0 -> v
      _ -> falha!(id, "version ausente ou inválida")
    end
  end

  defp inteiros_positivos!(id, nome, valores) do
    unless is_list(valores) and valores != [] and Enum.all?(valores, &(is_integer(&1) and &1 > 0)),
      do: falha!(id, "#{nome} não é lista de inteiros positivos")
  end

  defp falha!(id, motivo), do: raise("#{id} inconsistente: #{motivo}")
end
