defmodule TheBand.Mapping.PatternValidator do
  @moduledoc """
  Recusa o padrão que não pode ser gravado — **função pura, sem banco**.

  Regex é código que a pessoa escreve e que roda no servidor. Três recusas, e cada uma
  devolve o que a pessoa precisa para corrigir:

  | Recusa | Por que |
  |---|---|
  | não compila | com a **posição** do erro, que é o que permite corrigir |
  | casa string vazia | `.*` grava sem erro e reclassifica **todas** as issues |
  | cara demais | quantificador aninhado faz o motor tentar 2ⁿ divisões do texto |

  ## A mesma função valida na prévia e na gravação

  Prévia e efeito por caminhos diferentes é o que o SC-007 proíbe: alguém aprovaria uma
  regra vendo um número e gravaria outro.

  ## `Regex.compile/2`, nunca `compile!/2`

  Padrão inválido é erro **previsto** — a pessoa está escrevendo a expressão. O princípio
  VIII manda erro previsto ser retorno, e exceção aqui viraria página de erro no meio de
  um formulário.

  ## A amostra é de títulos reais

  Uma expressão rápida em `"abc"` pode ser cara no título de 245 caracteres que o time
  escreve. Medir sobre string sintética responderia a pergunta errada.

  ## O orçamento é de PASSOS, e não de milissegundos — issue #501

  A versão anterior disparava um `Task` e dava 100 ms de cronômetro. O `@moduledoc` dizia
  que *"`:re` não tem limite de passos"*, e **isso é falso**: o PCRE aborta o backtracking
  sozinho, e o nosso cronômetro competia com o freio dele.

  Quem vencia dependia da máquina. O platô do motor foi medido em **95 ms** na máquina da
  issue e em **185 ms** na de quem consertou — contra um limite fixo de 100 ms. Mesmo
  código, veredito oposto, e o teste do guarda virou sorteio.

  `match_limit` conta **unidades de trabalho do motor**, não segundos. O mesmo número
  significa o mesmo esforço em qualquer máquina; o tempo que aquele esforço leva varia, e
  deixa de importar para a decisão.

  ## De onde vem o número

  Medido contra **300 títulos reais** desta base: cinco de seis padrões plausíveis concluem
  com **100 passos**, e o mais caro — `.*[Ss]print.*` — precisa de **1.000**. O patológico
  `^(a+)+$` estoura **10.000** e é recusado em 0,2 ms.

  O orçamento é **100.000**: cem vezes o legítimo mais caro medido, e ainda recusa o
  patológico em 2 ms.

  **A limitação**: este tenant tem **zero** regras regex gravadas. Os seis padrões medidos
  foram escritos por quem consertou, não observados em uso. A folga de 100× é contra o que
  se imagina que alguém escreveria — e por isso erra para o lado largo, porque orçamento
  apertado recusa regra legítima de outra pessoa.

  ## `:report_errors`, e por que não é detalhe

  Sem ele, estourar o orçamento devolve `:nomatch` — **o mesmo que "não casou"**. A tela
  diria *"sua regra não pega nada"* quando a verdade é *"sua regra é cara demais para
  avaliar"*. Duas situações com ações diferentes, colapsadas numa resposta só.
  """

  @orcamento_passos 100_000

  @typedoc "Por que o padrão foi recusado."
  @type motivo ::
          {:does_not_compile, String.t(), non_neg_integer()}
          | :matches_empty
          | {:too_expensive, pos_integer()}

  @doc """
  O orçamento de avaliação, em **passos de backtracking**. Vem do catálogo
  (`limits.max_evaluation_steps`).

  Passo não é milissegundo: é unidade de trabalho do motor, e o mesmo número custa o mesmo
  esforço em qualquer máquina.
  """
  @spec orcamento_passos() :: pos_integer()
  def orcamento_passos, do: @orcamento_passos

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

  # 047/T014 (#617): as frases de recusa MORAVAM aqui, em literal — o domínio
  # fabricando texto de tela, contra a regra do contrato do catálogo ("a camada
  # web traduz o motivo em frase"). Elas se mudaram para a borda
  # (mapping_rules.humanizar/1), byte a byte, via catálogo; este módulo devolve
  # a TUPLA do motivo e nada mais. A posição do erro segue na tupla — é ela que
  # diz ONDE consertar, e a borda a interpola.

  # `Regex.compile/2` devolve `{:error, {razão, posição}}` e nada mais — o dialyzer
  # confirma. Uma cláusula extra para `{:error, razão}` nunca casaria, e cláusula morta é
  # pior que ausência: quem lê acredita que o caso existe.
  defp compilar(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> {:ok, regex}
      {:error, {razao, posicao}} -> {:error, {:does_not_compile, to_string(razao), posicao}}
    end
  end

  # O teste mais direto para o caso perigoso: uma expressão que casa vazio grava sem erro
  # e reclassifica tudo.
  defp recusar_vazio(regex),
    do: if(Regex.match?(regex, ""), do: {:error, :matches_empty}, else: :ok)

  # Em linha, e não numa `Task`: o orçamento limita o motor por dentro, então não há o que
  # matar de fora. A versão anterior precisava da `Task` porque acreditava que o motor não
  # parava sozinho.
  defp medir(_regex, []), do: :ok

  defp medir(regex, sample) do
    compilado = Regex.re_pattern(regex)

    if Enum.any?(sample, &estourou?(compilado, &1)),
      do: {:error, {:too_expensive, @orcamento_passos}},
      else: :ok
  end

  # Os três desfechos são distintos de propósito. `:nomatch` é resposta — o título não casa,
  # e isso é informação. `{:error, :match_limit}` é ausência de resposta, e a `:report_errors`
  # é o que impede as duas de voltarem iguais.
  defp estourou?(compilado, titulo) do
    opcoes = [
      {:match_limit, @orcamento_passos},
      {:match_limit_recursion, @orcamento_passos},
      :report_errors
    ]

    case :re.run(titulo, compilado, opcoes) do
      {:error, _} -> true
      _ -> false
    end
  end
end
