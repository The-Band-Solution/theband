defmodule TheBand.Integrations.LLM.HTTP.Req do
  @moduledoc """
  A implementação real da borda do provedor, sobre `Req`.

  Fala a API de *chat completions*, que é o formato que os provedores usados aqui expõem. A
  chave vem de `API_KEY` no ambiente — nunca de arquivo do repositório, nunca de argumento.
  """

  @behaviour TheBand.Integrations.LLM.HTTP

  alias TheBand.Integrations.LLM.HTTP

  @url "https://api.openai.com/v1/chat/completions"
  @modelo_padrao "gpt-5.4-mini"

  @impl true
  def complete(prompt, material, opts \\ []) do
    chave = System.get_env("API_KEY")
    modelo = opts[:model] || System.get_env("AI_MODEL") || @modelo_padrao

    if chave in [nil, ""] do
      {:error, :missing_credential}
    else
      chamar(prompt, material, modelo, chave, opts)
    end
  end

  defp chamar(prompt, material, modelo, chave, opts) do
    corpo =
      %{
        model: modelo,
        messages: [
          %{role: "system", content: prompt},
          %{role: "user", content: material}
        ]
      }
      |> talvez_estruturado(opts[:schema])

    Req.post(@url,
      json: corpo,
      headers: [{"authorization", "Bearer " <> chave}],
      receive_timeout: opts[:timeout] || 300_000,
      retry: :transient
    )
    |> interpretar(modelo, chave)
  end

  # **Saída estruturada, quando há schema.** `strict: true` faz o provedor recusar responder
  # fora do formato, em vez de responder em prosa e deixar quem consome adivinhar. Foi o que
  # aconteceu antes de existir schema: o modelo largou os subtítulos, a limpeza tratou o
  # documento inteiro como resumo, e apagou a evidência toda em silêncio.
  defp talvez_estruturado(corpo, nil), do: corpo

  defp talvez_estruturado(corpo, schema),
    do: Map.put(corpo, :response_format, %{type: "json_schema", json_schema: schema})

  # Cada ramo termina em algo nomeado. Nenhum devolve silêncio.
  defp interpretar({:ok, %{status: 200, body: body}}, modelo, chave) do
    texto =
      body
      |> get_in(["choices", Access.at(0), "message", "content"])
      |> to_string()
      |> String.trim()

    razao = get_in(body, ["choices", Access.at(0), "finish_reason"])

    if texto == "" do
      {:error, {:empty_response, razao}}
    else
      {:ok, %{text: texto, model: body["model"] || modelo, usage: body["usage"] || %{}}}
    end
  rescue
    # Corpo em formato inesperado é falha, e não texto vazio: as duas pedem investigação
    # diferente, e achatá-las esconderia mudança de contrato do provedor.
    e -> {:error, {:unexpected_body, HTTP.redigir(Exception.message(e), chave)}}
  end

  defp interpretar({:ok, %{status: status, body: body}}, _modelo, chave) do
    msg = get_in(body, ["error", "message"]) || inspect(body, limit: 5)
    {:error, {:http, status, HTTP.redigir(msg, chave)}}
  end

  defp interpretar({:error, e}, _modelo, chave) do
    {:error, {:network, HTTP.redigir(Exception.message(e), chave)}}
  end
end
