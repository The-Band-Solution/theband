defmodule TheBand.Mapping.PatternValidator do
  @moduledoc """
  Recusa o padrão que não pode ser gravado — **função pura, sem banco**.

  Regex é código que a pessoa escreve e que roda no servidor. Três recusas, e cada uma
  devolve o que a pessoa precisa para corrigir:

  | Recusa | Por que |
  |---|---|
  | não compila | com a **posição** do erro, que é o que permite corrigir |
  | casa string vazia | `.*` grava sem erro e reclassifica **todas** as issues |
  | lenta demais | `:re` não tem limite de passos; quantificador aninhado custa segundos |

  ## A mesma função valida na prévia e na gravação

  Prévia e efeito por caminhos diferentes é o que o SC-007 proíbe: alguém aprovaria uma
  regra vendo um número e gravaria outro.

  ## `Regex.compile/2`, nunca `compile!/2`

  Padrão inválido é erro **previsto** — a pessoa está escrevendo a expressão. O princípio
  VIII manda erro previsto ser retorno, e exceção aqui viraria página de erro no meio de
  um formulário.

  ## A amostra é de títulos reais

  Uma expressão rápida em `"abc"` pode ser lenta no título de 200 caracteres que o time
  escreve. Medir sobre string sintética responderia a pergunta errada.
  """

  @limite_ms 100

  @typedoc "Por que o padrão foi recusado."
  @type motivo ::
          {:does_not_compile, String.t(), non_neg_integer()}
          | :matches_empty
          | {:too_slow, pos_integer()}

  @doc "O limite de avaliação, em milissegundos. Vem do catálogo (`limits.max_evaluation_ms`)."
  @spec limite_ms() :: pos_integer()
  def limite_ms, do: @limite_ms

  @doc """
  Valida o padrão para a forma de comparação, contra uma amostra de títulos reais.

  Comparação literal — `equals`, `starts_with`, `contains` — só recusa texto vazio: ela não
  compila nada e não tem como ser lenta.
  """
  @spec validate(String.t(), String.t(), [String.t()]) :: :ok | {:error, motivo()}
  def validate(_how, pattern, _sample) when pattern in [nil, ""], do: {:error, :matches_empty}

  def validate("regex", pattern, sample) do
    with {:ok, regex} <- compilar(pattern),
         :ok <- recusar_vazio(regex) do
      medir(regex, sample)
    end
  end

  def validate(_literal, _pattern, _sample), do: :ok

  @doc """
  A recusa em português, com o que a pessoa precisa para corrigir.

  A posição do erro entra na mensagem porque é ela que diz **onde** consertar — sem ela, a
  pessoa relê a expressão inteira procurando o parêntese que faltou.
  """
  @spec explicar(motivo()) :: String.t()
  def explicar({:does_not_compile, razao, posicao}),
    do: "a expressão não compila: #{razao}, na posição #{posicao}"

  def explicar(:matches_empty),
    do:
      "a expressão casa texto vazio, e casaria todas as issues da organização — " <>
        "uma regra que casa tudo não classifica nada"

  def explicar({:too_slow, limite}),
    do:
      "a expressão passou de #{limite}ms sobre títulos reais desta organização; " <>
        "quantificadores aninhados são a causa usual"

  defp compilar(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> {:ok, regex}
      {:error, {razao, posicao}} -> {:error, {:does_not_compile, to_string(razao), posicao}}
      {:error, razao} -> {:error, {:does_not_compile, inspect(razao), 0}}
    end
  end

  # O teste mais direto para o caso perigoso: uma expressão que casa vazio grava sem erro
  # e reclassifica tudo.
  defp recusar_vazio(regex),
    do: if(Regex.match?(regex, ""), do: {:error, :matches_empty}, else: :ok)

  # Numa `Task`, e não em linha: `:re` não tem limite de passos, e uma expressão
  # patológica prenderia o processo da tela até o navegador desistir.
  defp medir(_regex, []), do: :ok

  defp medir(regex, sample) do
    tarefa = Task.async(fn -> Enum.each(sample, &Regex.match?(regex, &1)) end)

    case Task.yield(tarefa, @limite_ms) || Task.shutdown(tarefa, :brutal_kill) do
      {:ok, _} -> :ok
      _ -> {:error, {:too_slow, @limite_ms}}
    end
  end
end
