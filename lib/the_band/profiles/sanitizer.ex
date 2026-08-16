defmodule TheBand.Profiles.Sanitizer do
  @moduledoc """
  Tira as citações dos três campos do resumo — feature 026.

  ## Por que isto é código, e não uma linha a mais no prompt

  O resumo é definido como a parte **sem citação**: quem lê ali está decidindo se vale ler o
  resto, não conferindo evidência, e um número sem título não diz nada a quem não vai abrir a
  issue. Os campos `destaques` e `lacunas` têm lugar próprio para os números.

  Na validação de 2026-08-15 a regra foi pedida ao modelo **quatro vezes**, com formulações
  diferentes, e ignorada nas quatro. Quando a regra é verificável mecanicamente, aplicá-la é
  melhor que pedi-la.

  ## O que a saída estruturada consertou

  A versão anterior operava sobre **prosa**, e tinha de adivinhar onde o resumo terminava
  procurando o primeiro subtítulo. Em 2026-08-16 o modelo respondeu sem subtítulo algum: a
  limpeza tratou os 6651 caracteres como resumo e apagou **dezenove** citações — a evidência
  inteira, em silêncio.

  Com o schema, os três campos são endereçáveis. Não há estrutura a adivinhar, e o pior caso
  desapareceu junto com a adivinhação.
  """

  @campos ~w(forcas evolucao atencao)

  # Duas formas aparecem: o grupo entre parênteses, e a enumeração solta no fim da frase,
  # que leva junto o conectivo que a introduz — senão sobra frase terminando em conjunção.
  @grupo ~r/\s*\((?:#\d+(?:\s*[,e]\s*)?)+\)/
  @solta ~r/,?\s*(?:como|em|nas?|nos?)?\s*#\d+(?:\s*(?:,|e)\s*#\d+)*/
  @conectivo_orfao ~r/,?\s+(?:como|tais como|por exemplo)\s*([.;,])/
  @espaco_antes_da_pontuacao ~r/ +([.,;:])/
  @parenteses_vazios ~r/\(\s*\)/
  @parenteses_com_sobra ~r/\(\s+/

  @doc """
  Limpa os três campos do resumo e devolve `{conteudo, quantas_sairam}`.

  Só toca em `resumo`. `destaques`, `lacunas` e `trajetoria` ficam intactos — é onde a
  evidência mora, e tirá-la de lá deixaria o texto sem lastro.
  """
  @spec clean_summary(map()) :: {map(), non_neg_integer()}
  def clean_summary(%{"resumo" => resumo} = conteudo) when is_map(resumo) do
    {limpo, saidas} =
      Enum.reduce(@campos, {resumo, 0}, fn campo, {acc, total} ->
        case Map.get(acc, campo) do
          texto when is_binary(texto) ->
            {t, n} = limpar(texto)
            {Map.put(acc, campo, t), total + n}

          _ ->
            {acc, total}
        end
      end)

    {Map.put(conteudo, "resumo", limpo), saidas}
  end

  # Sem `resumo` o changeset já recusa; aqui a ausência não é consertada em silêncio.
  def clean_summary(conteudo) when is_map(conteudo), do: {conteudo, 0}

  defp limpar(texto) do
    {sem_citacao, saidas} =
      Enum.reduce([@grupo, @solta], {texto, 0}, fn padrao, {t, acumulado} ->
        {Regex.replace(padrao, t, ""), acumulado + length(Regex.scan(padrao, t))}
      end)

    limpo =
      sem_citacao
      |> then(&Regex.replace(@conectivo_orfao, &1, "\\1"))
      |> then(&Regex.replace(@espaco_antes_da_pontuacao, &1, "\\1"))
      |> then(&Regex.replace(@parenteses_vazios, &1, ""))
      |> then(&Regex.replace(@parenteses_com_sobra, &1, "("))
      |> String.trim()

    {limpo, saidas}
  end
end
