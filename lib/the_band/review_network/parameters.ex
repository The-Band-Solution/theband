defmodule TheBand.ReviewNetwork.Parameters do
  @moduledoc """
  Os parâmetros da rede de revisão, lidos da base de conhecimento — feature 073, T013 (FR-008,
  FR-011, FR-013; research.md R11).

  As janelas, o k, a amostra mínima e os estados que contam moram na regra
  `review.network.parameters`, e não no código: em constante, o número muda num diff de código e
  ninguém percebe que a plataforma passou a afirmar outra coisa.

  **Levanta, e nunca devolve valor de reserva**, quando a regra falta ou uma chave falta (princípio
  IV; precedente `TheBandWeb.Plugs.ApiRateLimit`). Até a base receber a proposta de
  `specs/073-rede-de-revisao/proposta-base/` (T003, T004), a regra **não existe** e esta função
  levanta: é o que deve acontecer, e ninguém a chama enquanto o gatilho (T020) não existe.

  **Os nomes das chaves são os da proposta**, e a revisão semântica (T003) pode trocá-los; aí só
  este módulo muda (`contracts/review-network.md`, *Os parâmetros entram pela fachada*).

  O grupo mínimo (3, decidido em 2026-10-03) **não** é lido: com a Q4, os grupos são do recorte,
  e a regra não tem caso nesta fatia.

  Depende de: `TheBand.Ontology.KnowledgeBase`.
  """

  alias TheBand.Ontology.KnowledgeBase

  @regra "review.network.parameters"

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
    case KnowledgeBase.rule(@regra) do
      {:ok, regra} -> from_rule!(regra)
      :error -> raise "regra #{@regra} ausente da base de conhecimento"
    end
  end

  @doc """
  Lê e valida a regra já carregada. Levanta dizendo a chave quando falta uma, ou quando um valor
  não é o que a regra promete (inteiros positivos, k crescente, padrão dentro da lista).
  """
  @spec from_rule!(map()) :: t()
  def from_rule!(regra) do
    janelas = valor!(regra, ["window_days", "values", "allowed"])
    padrao = valor!(regra, ["window_days", "values", "default"])
    ks = valor!(regra, ["k_values", "values", "k"])
    minimo = valor!(regra, ["min_reviews", "values", "min_reviews"])
    estados = valor!(regra, ["counted_states", "values", "states"])
    versao = Map.get(regra, "version")

    inteiros_positivos!("window_days.allowed", janelas)
    inteiros_positivos!("k_values.k", ks)
    inteiros_positivos!("min_reviews", [minimo])
    inteiros_positivos!("version", [versao])

    unless padrao in janelas, do: falha!("window_days.default fora de window_days.allowed")
    unless ks == Enum.sort(Enum.uniq(ks)), do: falha!("k_values.k não é crescente")

    unless is_list(estados) and estados != [] and Enum.all?(estados, &is_binary/1),
      do: falha!("counted_states.states não é lista de estados")

    %{
      windows: janelas,
      default_window: padrao,
      ks: ks,
      minimum_sample: minimo,
      counted_states: estados,
      knowledge_versions: %{@regra => versao}
    }
  end

  defp valor!(regra, caminho) do
    case get_in(regra, ["rules" | caminho]) do
      nil -> falha!("#{Enum.join(caminho, ".")} ausente")
      valor -> valor
    end
  end

  defp inteiros_positivos!(nome, valores) do
    unless is_list(valores) and valores != [] and Enum.all?(valores, &(is_integer(&1) and &1 > 0)),
      do: falha!("#{nome} não é lista de inteiros positivos")
  end

  defp falha!(motivo), do: raise("regra #{@regra} inconsistente: #{motivo}")
end
