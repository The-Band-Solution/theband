defmodule TheBand.Profiles.Sanitizer do
  @moduledoc """
  Tira do resumo as citações que o modelo insiste em pôr lá — feature 026.

  ## Por que isto é código, e não uma linha a mais no prompt

  O resumo é definido como a parte **sem citação**: quem lê ali está decidindo se vale ler o
  resto, não conferindo evidência, e um número sem título não diz nada a quem não vai abrir a
  issue. As seções seguintes carregam os números.

  Na validação de 2026-08-15 a regra foi pedida ao modelo **quatro vezes**, com formulações
  diferentes, e ignorada nas quatro — uma delas com um parágrafo carregando dezessete números
  entre parênteses.

  **Quando a regra é verificável mecanicamente, aplicá-la é melhor que pedi-la.** Pedir e não
  conferir produz um texto que viola a própria regra e parece cumpri-la.

  ## O que a limpeza tem de cobrir, e o que aprendeu apanhando

  Três formas apareceram, e as três estão aqui:

  1. o grupo entre parênteses — `(#199, #200)`;
  2. a enumeração solta no fim da frase — `..., como #458, #459 e #449`, que leva junto o
     `como` que a introduz, senão sobra frase terminando em conjunção;
  3. o parêntese que fica pela metade — `( no resumo do período 3)`, quando só parte do
     conteúdo era citação.

  A contagem é devolvida de propósito: limpeza silenciosa é a mesma classe de defeito que a
  limpeza existe para conter.
  """

  # Ordem importa: o grupo entre parênteses sai antes da enumeração solta, senão a segunda
  # regra comeria o `#` de dentro do parêntese e deixaria os parênteses vazios.
  @grupo ~r/\s*\((?:#\d+(?:\s*[,e]\s*)?)+\)/
  @solta ~r/,?\s*(?:como|em|nas?|nos?)?\s*#\d+(?:\s*(?:,|e)\s*#\d+)*/
  @conectivo_orfao ~r/,?\s+(?:como|tais como|por exemplo)\s*([.;,])/
  @espaco_antes_da_pontuacao ~r/ +([.,;:])/
  @parenteses_vazios ~r/\(\s*\)/
  @parenteses_com_sobra ~r/\(\s+/

  @doc """
  Limpa o trecho anterior ao primeiro subtítulo e devolve `{texto, quantas_sairam}`.

  O corte é no primeiro subtítulo **depois do título**. O título é ele próprio um cabeçalho,
  e cortar na primeira ocorrência deixaria o resumo vazio e a limpeza sem efeito — **sem
  erro**, que é o pior jeito de não funcionar.
  """
  @spec clean_summary(String.t()) :: {String.t(), non_neg_integer()}
  def clean_summary(texto) when is_binary(texto) do
    case String.split(texto, "\n", parts: 2) do
      [_unica_linha] ->
        {texto, 0}

      [titulo, apos] ->
        {resumo, resto} = separar(apos)
        {limpo, saidas} = limpar(titulo <> "\n" <> resumo)
        {limpo <> resto, saidas}
    end
  end

  defp separar(apos) do
    case String.split(apos, ~r/^##+ /m, parts: 2) do
      [resumo] -> {resumo, ""}
      [resumo, resto] -> {resumo, "## " <> resto}
    end
  end

  defp limpar(trecho) do
    {sem_citacao, saidas} =
      Enum.reduce([@grupo, @solta], {trecho, 0}, fn padrao, {texto, acumulado} ->
        {Regex.replace(padrao, texto, ""), acumulado + length(Regex.scan(padrao, texto))}
      end)

    limpo =
      sem_citacao
      |> then(&Regex.replace(@conectivo_orfao, &1, "\\1"))
      |> then(&Regex.replace(@espaco_antes_da_pontuacao, &1, "\\1"))
      |> then(&Regex.replace(@parenteses_vazios, &1, ""))
      |> then(&Regex.replace(@parenteses_com_sobra, &1, "("))

    {limpo, saidas}
  end
end
