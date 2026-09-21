defmodule TheBand.Tenants.AccountLifecycle do
  @moduledoc """
  O vocabulário do ciclo de vida da conta, lido da base de conhecimento.

  As cláusulas de razão — cinco para desativar, quatro para reativar —, quais exigem nota
  escrita e os estados que a tela nomeia vivem em `access.account_lifecycle`, e **não
  aqui**. Este módulo é o leitor: nenhuma lista está escrita neste arquivo.

  ## Por que na base, e não em constante

  Uma cláusula de razão é decisão sobre o que a plataforma **afirma** sobre uma pessoa. Em
  constante de módulo, a lista muda num diff de template e ninguém percebe que a
  plataforma passou a afirmar outra coisa — é a FR-069 da 060 pela mesma razão, e o
  precedente é `team.dashboard.thresholds`.

  ## Base ausente: recusa, nunca invenção

  Sem a regra declarada, as listas voltam **vazias** e o ato de desativar recusa. É a forma
  de `ProblemsNow.issue_open_days/0`: sem o limiar, o cartão recusa em vez de contar. A
  alternativa — uma lista de reserva no código — é a duplicata silenciosa que a FR-069
  proíbe, e faria a plataforma continuar afirmando com a base fora do ar.

  ## Os dois vocabulários de estado, e por que são dois

  O estado da **conta** responde *pode entrar?*; o da **credencial**, *entraria com o quê?*.
  Eram uma célula só, e uma célula só é o que fez um desligamento parecer um primeiro dia.
  """

  alias TheBand.Ontology.KnowledgeBase

  @regra "access.account_lifecycle"

  @doc """
  As cláusulas **oferecidas** no formulário de desativação, com rótulo e significado.

  `not_recorded` não está aqui: existe no registro, para as desativações feitas antes de a
  razão ser pedida, e ninguém a escolhe.
  """
  @spec razoes_de_desativacao() :: [map()]
  def razoes_de_desativacao, do: valores("disable_reasons", "offered")

  @doc "As cláusulas oferecidas no formulário de reativação."
  @spec razoes_de_reativacao() :: [map()]
  def razoes_de_reativacao, do: valores("enable_reasons", "offered")

  @doc """
  Cada código que o registro aceita ao desativar — os oferecidos **e** os só-registrados.

  O changeset valida contra esta lista, e não contra a oferecida: `not_recorded` é escrita
  pela migração e precisa ser válida, sem por isso aparecer na tela.
  """
  @spec codigos_de_desativacao() :: [String.t()]
  def codigos_de_desativacao do
    codigos(valores("disable_reasons", "offered") ++ valores("disable_reasons", "recorded_only"))
  end

  @doc "Os códigos que o registro aceita ao reativar."
  @spec codigos_de_reativacao() :: [String.t()]
  def codigos_de_reativacao, do: codigos(razoes_de_reativacao())

  @doc "As razões de desativação que exigem nota escrita."
  @spec nota_exigida_ao_desativar() :: [String.t()]
  def nota_exigida_ao_desativar, do: lista("note_required", "on_disable")

  @doc "As razões de reativação que exigem nota escrita."
  @spec nota_exigida_ao_reativar() :: [String.t()]
  def nota_exigida_ao_reativar, do: lista("note_required", "on_enable")

  @doc """
  A frase que o registro escreve quando não há nota — ausência dita, nunca célula vazia.
  """
  @spec frase_sem_nota() :: String.t()
  def frase_sem_nota do
    case escalar("note_required", "absent_phrase") do
      texto when is_binary(texto) -> texto
      _ -> "no note"
    end
  end

  @doc """
  Esta razão de reativação exige que a abertura tenha sido de qual cláusula?

  `nil` quando a razão serve para qualquer abertura. `investigation_closed_no_compromise`
  devolve `"suspected_compromise"` — e é o único caso hoje.
  """
  @spec abertura_exigida_pela_reativacao(String.t() | nil) :: String.t() | nil
  def abertura_exigida_pela_reativacao(codigo) when is_binary(codigo) do
    razoes_de_reativacao()
    |> Enum.find(&(&1["code"] == codigo))
    |> case do
      %{"offered_only_against" => abertura} when is_binary(abertura) -> abertura
      _ -> nil
    end
  end

  def abertura_exigida_pela_reativacao(_), do: nil

  @doc """
  As razões de reativação oferecidas **contra este episódio**.

  Filtra as que só existem contra uma abertura específica. Recebe a cláusula da abertura;
  `nil` ou desconhecida deixa fora todas as condicionais.
  """
  @spec reativacoes_oferecidas_contra(String.t() | nil) :: [map()]
  def reativacoes_oferecidas_contra(abertura) do
    Enum.filter(razoes_de_reativacao(), fn razao ->
      case razao["offered_only_against"] do
        nil -> true
        exigida -> exigida == abertura
      end
    end)
  end

  @doc """
  O rótulo declarado de um código de razão — de desativar ou de reativar.

  Devolve o próprio código quando a base não o conhece: um código na tela é feio e é
  verdadeiro; um rótulo inventado é bonito e não é.
  """
  @spec rotulo(String.t() | nil) :: String.t() | nil
  def rotulo(nil), do: nil

  def rotulo(codigo) when is_binary(codigo) do
    todas =
      valores("disable_reasons", "offered") ++
        valores("disable_reasons", "recorded_only") ++ valores("enable_reasons", "offered")

    case Enum.find(todas, &(&1["code"] == codigo)) do
      %{"label" => rotulo} when is_binary(rotulo) -> rotulo
      _ -> codigo
    end
  end

  @doc ~S(O rótulo declarado de um estado de credencial — `"temporary · from a reset"` e afins.)
  @spec rotulo_de_credencial(atom() | String.t()) :: String.t()
  def rotulo_de_credencial(codigo) do
    codigo = to_string(codigo)

    case Enum.find(valores("states", "credential"), &(&1["code"] == codigo)) do
      %{"label" => rotulo} when is_binary(rotulo) -> rotulo
      _ -> codigo
    end
  end

  @doc ~S(O rótulo declarado de um estado de conta — `"active"` ou `"disabled"`.)
  @spec rotulo_de_conta(atom() | String.t()) :: String.t()
  def rotulo_de_conta(codigo) do
    codigo = to_string(codigo)

    case Enum.find(valores("states", "account"), &(&1["code"] == codigo)) do
      %{"label" => rotulo} when is_binary(rotulo) -> rotulo
      _ -> codigo
    end
  end

  @doc """
  O vocabulário está declarado? — a pergunta que a tela faz antes de oferecer o ato.

  Sem ele, desativar recusa, e a tela **diz por quê** em vez de mostrar formulário sem
  opção nenhuma.
  """
  @spec vocabulario_declarado?() :: boolean()
  def vocabulario_declarado?, do: razoes_de_desativacao() != []

  # ------------------------------------------------------------------ a leitura

  defp valores(regra, chave) do
    case ler(regra, chave) do
      lista when is_list(lista) -> Enum.filter(lista, &is_map/1)
      _ -> []
    end
  end

  defp lista(regra, chave) do
    case ler(regra, chave) do
      lista when is_list(lista) -> Enum.filter(lista, &is_binary/1)
      _ -> []
    end
  end

  defp escalar(regra, chave), do: ler(regra, chave)

  defp ler(regra, chave) do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"rules" => regras}} -> get_in(regras, [regra, "values", chave])
      _ -> nil
    end
  end

  defp codigos(razoes) do
    razoes
    |> Enum.map(& &1["code"])
    |> Enum.filter(&is_binary/1)
  end
end
