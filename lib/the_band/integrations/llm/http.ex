defmodule TheBand.Integrations.LLM.HTTP do
  @moduledoc """
  Borda HTTP do provedor de modelo de linguagem — feature 026.

  Existe como behaviour por um motivo só: é o **único** ponto que o Mox substitui nos testes.
  Módulo de domínio próprio nunca é mockado — mock de domínio esconde erro em vez de
  revelá-lo (`AGENTS.md` §7.6). É a mesma forma de `TheBand.Integrations.GitHub.HTTP`, e pelo
  mesmo motivo.

  ## `:empty_response` é ramo próprio, e não caso de `{:ok, _}`

  Um `200` com texto vazio **não é sucesso**. Casar `{:ok, _}` largo aqui reproduziria a L26
  do projeto — o job completa, nada é coletado, e ninguém percebe. Quem consome precisa
  conseguir distinguir "o provedor respondeu e não escreveu nada" de "o provedor escreveu".

  ## A credencial não sai daqui

  Provedores devolvem a chave dentro do texto de alguns erros — medido em 2026-08-15, a
  mensagem de chave suspensa do Google trazia a chave inteira. Toda mensagem que este módulo
  devolve passa por `redigir/2` antes.
  """

  @type resposta :: %{text: String.t(), model: String.t(), usage: map()}

  @callback complete(prompt :: String.t(), material :: String.t(), opts :: keyword()) ::
              {:ok, resposta()}
              | {:error, {:http, integer(), String.t()}}
              | {:error, {:empty_response, String.t() | nil}}
              | {:error, term()}

  @doc "Implementação configurada. Em teste, o Mox."
  @spec impl() :: module()
  def impl, do: Application.get_env(:the_band, :llm_http_client, __MODULE__.Req)

  @doc """
  Substitui a chave em qualquer texto antes de ele circular.

  Chamada em toda mensagem de erro, e não só nas que "parecem" conter segredo: a lista de
  quais mensagens vazam a chave é do provedor, e muda sem aviso.
  """
  @spec redigir(String.t(), String.t() | nil) :: String.t()
  def redigir(texto, nil), do: to_string(texto)
  def redigir(texto, ""), do: to_string(texto)
  def redigir(texto, chave), do: texto |> to_string() |> String.replace(chave, "«API_KEY»")
end
