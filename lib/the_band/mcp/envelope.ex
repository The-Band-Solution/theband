defmodule TheBand.MCP.Envelope do
  @moduledoc """
  O envelope de proveniência que **toda** resposta de medida carrega (feature 062, FR-010,
  FR-011, FR-014).

  Um modelo não sabe perguntar pela ressalva. Uma pessoa que vê `0,2 h` na tela vê, ao lado,
  *"23 revisadas; outras 79 ainda aguardam, há 46 dias"*. Um agente que recebe `0.2` num campo
  relata `0.2`. Por isso a ressalva vai **no mesmo objeto**, e não como campo opcional, texto
  anexo ou segunda chamada.

  Os campos estão em `specs/062-servidor-mcp/data-model.md`: `value`, `composition`, `window`,
  `origin`, `rule`, `measurement_id`, `limitations`, `misinterpretations` e `collected_at`.

  ## As regras que este módulo aplica, e por quê

  - **As ressalvas são lidas da base de conhecimento, e nunca escritas aqui** (princípio IV).
    Vêm de uma **medida** (`limitations` e `misinterpretations`) ou de um **mapeamento**, que
    declara `limitations` e não declara interpretação errada. Então `misinterpretations: []`
    diz *a base foi lida, e não declara nenhuma*, e não *ninguém olhou*.
  - **Id que não existe na base levanta erro.** Uma ferramenta que cita uma medida que a base
    não tem responderia sem ressalva, e é esse o defeito que a feature existe para impedir.
    Falhar alto é melhor que responder mudo.
  - **`rule` só existe quando `origin` é `derived`.** O schema de medida não tem versão, e o de
    regra tem. Uma regra ao lado de um dado observado afirmaria uma derivação que não houve.
  - **`window` tem de ser passado, mesmo `nil`.** *"Quantos estão abertos agora"* não tem
    janela, e dizer `nil` é diferente de esquecer: omitir o campo faria o consumidor supor que
    há uma janela, e que ele não a recebeu.
  """

  alias TheBand.Ontology.KnowledgeBase

  @origens ~w(observed derived declared)

  @typedoc "De onde vêm as ressalvas: uma medida ou um mapeamento, pelo id na base."
  @type ressalvas :: {:medida, String.t()} | {:mapeamento, String.t()}

  @type t :: %{
          value: term(),
          composition: map(),
          window: map() | nil,
          origin: String.t(),
          rule: %{id: String.t(), version: pos_integer()} | nil,
          measurement_id: String.t() | nil,
          limitations: [term(), ...],
          misinterpretations: [term()],
          collected_at: DateTime.t() | nil
        }

  @doc """
  Monta o envelope. `:value`, `:composition`, `:window`, `:origin`, `:collected_at` e
  `:ressalvas` são obrigatórios, e `:window` e `:collected_at` são obrigatórios **mesmo quando
  `nil`**. `:regra` é opcional, e só vale com `origin: "derived"`.
  """
  @spec montar(keyword()) :: t()
  def montar(opts) do
    origem = Keyword.fetch!(opts, :origin)

    unless origem in @origens do
      raise ArgumentError, "origem #{inspect(origem)} não é da casa: #{Enum.join(@origens, ", ")}"
    end

    {medida_id, limitacoes, interpretacoes} = ressalvas!(Keyword.fetch!(opts, :ressalvas))

    %{
      value: Keyword.fetch!(opts, :value),
      composition: Keyword.fetch!(opts, :composition),
      window: Keyword.fetch!(opts, :window),
      origin: origem,
      rule: regra!(Keyword.get(opts, :regra), origem),
      measurement_id: medida_id,
      limitations: limitacoes,
      misinterpretations: interpretacoes,
      collected_at: Keyword.fetch!(opts, :collected_at)
    }
  end

  defp ressalvas!({:medida, id}) do
    medida = buscar!(&KnowledgeBase.measurement/1, id, "a medida")
    {id, limitacoes!(medida, id), List.wrap(medida["misinterpretations"])}
  end

  defp ressalvas!({:mapeamento, id}) do
    mapeamento = buscar!(&KnowledgeBase.mapping/1, id, "o mapeamento")
    {nil, limitacoes!(mapeamento, id), []}
  end

  defp regra!(nil, _origem), do: nil

  defp regra!(id, "derived") do
    regra = buscar!(&KnowledgeBase.rule/1, id, "a regra")
    %{id: id, version: regra["version"]}
  end

  defp regra!(id, origem) do
    raise ArgumentError,
          "a regra #{inspect(id)} foi passada com origem #{inspect(origem)}: " <>
            "só um valor derivado tem regra"
  end

  defp buscar!(consulta, id, tipo) do
    case consulta.(id) do
      {:ok, artefato} -> artefato
      :error -> raise ArgumentError, "a base de conhecimento não tem #{tipo} #{inspect(id)}"
    end
  end

  # A base exige `minItems: 1`. Se chegar vazia, a resposta sairia sem ressalva, e isso é o
  # defeito que o envelope existe para impedir, e não um caso a tolerar.
  defp limitacoes!(%{"limitations" => [_ | _] = limitacoes}, _id), do: limitacoes

  defp limitacoes!(_artefato, id) do
    raise ArgumentError,
          "#{inspect(id)} não declara limitations, e a resposta sairia sem ressalva"
  end
end
