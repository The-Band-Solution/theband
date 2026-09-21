defmodule TheBand.Segredo do
  @moduledoc """
  Um valor que não pode virar texto por acidente.

  ## Por que este módulo existe

  Em 2026-09-04 um token de acesso do GitHub foi escrito em **texto claro** dentro do
  registro de erro de um job, e lá ficou oito dias. O mecanismo não foi descuido de quem
  escreveu a chamada: o token era um `binary` nu, argumento de `Client.graphql/5`. Quando
  uma exceção sobe de uma função, a lista de argumentos vai no quadro de pilha,
  `Exception.format/3` chama `inspect/1` em cada um, e o executor de tarefas grava o texto
  resultante.

  O `redact: true` do schema **não alcança** esse caso. Ele protege o `inspect` da struct
  da credencial; não protege um valor solto que já foi decifrado e passou adiante.

  A correção, portanto, não podia ser disciplina — "lembre-se de não logar o token". Tinha
  de vir do **tipo**: um valor que, perguntado por sua forma textual, responde com uma
  marca em vez do conteúdo.

  ## Como este tipo se recusa a virar texto

  Três recusas, e as três importam por razões diferentes:

    * **`Inspect`** devolve `#Segredo<…abcd>`. É a que fecha o vazamento medido, porque é
      exatamente `inspect/1` que o formatador de exceção chama nos argumentos.

    * **`String.Chars` não é implementado**, de propósito. `"Bearer \#{segredo}"` levanta
      `Protocol.UndefinedError` — alto, imediato, no lugar certo. Implementá-lo devolvendo
      uma marca seria pior: a requisição sairia com `Bearer #Segredo<…>` e voltaria um 401
      que ninguém liga ao motivo.

    * **`Jason.Encoder` não é derivado**, também de propósito. Sem ele, tentar guardar um
      segredo nos argumentos de um job falha na serialização em vez de gravá-lo no banco.

  ## O que este módulo NÃO faz

  Não cifra nada. Quem cifra em repouso é o `TheBand.Vault`, e `tool_credentials.secret`
  já é `bytea` cifrado. Este tipo protege o valor **depois de decifrado**, enquanto ele
  circula na memória do processo — que era justamente o trecho sem proteção nenhuma.

  E ele não desfaz exposição passada: um valor que já vazou continua vazado, e o único ato
  que o invalida é a rotação.

  ## Os dois pontos onde um segredo nasce

  Um `Segredo` só deveria ser construído em dois lugares, e os dois são bordas:

    1. `TheBand.Sources.fetch_secret/1`, quando o valor sai do cofre;
    2. o formulário que registra uma credencial, quando o valor chega da pessoa.

  E só se abre em um: a montagem do cabeçalho HTTP, via `expor/1`.
  """

  @enforce_keys [:valor]
  defstruct [:valor]

  @opaque t :: %__MODULE__{valor: binary()}

  @doc """
  Embrulha um valor que a partir daqui não deve mais aparecer em texto.

  Aceita binário vazio — a validação de conteúdo é de quem registra a credencial, não
  deste tipo. O que ele garante é a recusa a se imprimir, e isso vale para qualquer valor.

  Embrulhar um `Segredo` de novo devolve o mesmo segredo, para que uma borda chamada duas
  vezes não crie um valor aninhado que `expor/1` devolveria como struct.
  """
  @spec novo(binary() | t()) :: t()
  def novo(%__MODULE__{} = segredo), do: segredo
  def novo(valor) when is_binary(valor), do: %__MODULE__{valor: valor}
  def novo(outro), do: recusa("novo/1", outro)

  @doc """
  Abre o segredo. **Único** jeito de obter o valor, e é para ser chamado no último
  instante antes do uso — a montagem do cabeçalho HTTP.

  Se a sua função precisa chamar isto, pergunte se ela não deveria receber o `Segredo`
  inteiro e repassá-lo: cada `expor/1` cria um binário nu, e binário nu foi o que vazou.
  """
  @spec expor(t()) :: binary()
  def expor(%__MODULE__{valor: valor}), do: valor
  def expor(outro), do: recusa("expor/1", outro)

  @doc """
  Os últimos quatro caracteres, que é o que permite dizer **qual** credencial falhou sem
  dizer qual é o valor dela.

  É a mesma convenção de `ToolCredential.last_four/1`, e existe aqui para que um registro
  de erro possa identificar a credencial sem abrir o segredo.

  Valores com menos de quatro caracteres devolvem `"…"`: revelar um segredo curto inteiro
  a pretexto de mostrar o fim dele seria o vazamento que este módulo existe para impedir.
  """
  @spec ultimos_quatro(t()) :: String.t()
  def ultimos_quatro(%__MODULE__{valor: valor}) when byte_size(valor) >= 4,
    do: binary_part(valor, byte_size(valor) - 4, 4)

  def ultimos_quatro(%__MODULE__{}), do: "…"
  def ultimos_quatro(outro), do: recusa("ultimos_quatro/1", outro)

  # As cláusulas de recusa existem por um motivo estreito, e não por zelo genérico.
  #
  # Sem elas, chamar qualquer função deste módulo com um binário nu levantaria
  # `FunctionClauseError` — e `FunctionClauseError` é EXATAMENTE o erro que põe a lista de
  # argumentos no quadro de pilha. O módulo que existe para impedir que um segredo vire
  # texto faria o segredo virar texto, na sua própria fronteira.
  #
  # `raise` no corpo não captura argumentos, então esta função é o caminho seguro. E ela
  # descreve o valor sem o mostrar: tipo e tamanho bastam para depurar.
  @spec recusa(String.t(), term()) :: no_return()
  defp recusa(funcao, outro) do
    raise ArgumentError,
          "TheBand.Segredo.#{funcao} recebeu #{descricao_sem_valor(outro)} em vez de um " <>
            "Segredo. O valor NÃO aparece nesta mensagem de propósito: se for um segredo " <>
            "nu, mostrá-lo seria o vazamento que este módulo existe para impedir."
  end

  defp descricao_sem_valor(outro) when is_binary(outro),
    do: "um binário de #{byte_size(outro)} bytes"

  defp descricao_sem_valor(%mod{}), do: "uma struct #{inspect(mod)}"
  defp descricao_sem_valor(outro) when is_nil(outro), do: "nil"
  defp descricao_sem_valor(outro) when is_atom(outro), do: "o átomo #{inspect(outro)}"
  defp descricao_sem_valor(outro) when is_list(outro), do: "uma lista de #{length(outro)} itens"
  defp descricao_sem_valor(outro) when is_map(outro), do: "um mapa de #{map_size(outro)} chaves"
  defp descricao_sem_valor(_outro), do: "um valor de outro tipo"

  defimpl Inspect do
    @moduledoc false

    # O valor não entra em documento de impressão nenhum, nem para ser descartado depois:
    # a marca é montada só com os quatro últimos caracteres, que já são públicos por
    # convenção (`tool_credentials.last_four` é coluna em claro).
    def inspect(segredo, _opts) do
      "#Segredo<…" <> TheBand.Segredo.ultimos_quatro(segredo) <> ">"
    end
  end
end
