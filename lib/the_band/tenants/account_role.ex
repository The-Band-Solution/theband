defmodule TheBand.Tenants.AccountRole do
  @moduledoc """
  O vocabulário da marca de administrador, lido da base de conhecimento — spec 072, T005 (R6).

  Os rótulos dos dois papéis, a frase da recusa do último administrador ativo e a da ausência de
  registro vivem em `access.account_role`, e **não aqui**. Este módulo é o leitor, na forma de
  `TheBand.Tenants.AccountLifecycle`.

  Depende de: nenhuma ontologia.

  Base ausente: o rótulo devolve o próprio código, e as frases devolvem `nil`. Um código na tela é
  feio e verdadeiro; uma frase de reserva no código seria a duplicata silenciosa que a FR-069 da
  060 proíbe.
  """
  alias TheBand.Ontology.KnowledgeBase

  @regra "access.account_role"

  @doc ~S(O rótulo declarado de um papel — `"administrator"` ou `"member"`.)
  @spec rotulo(String.t()) :: String.t()
  def rotulo(codigo) when is_binary(codigo) do
    case Enum.find(papeis(), &(&1["code"] == codigo)) do
      %{"label" => rotulo} when is_binary(rotulo) -> rotulo
      _ -> codigo
    end
  end

  @doc "Os códigos dos papéis declarados."
  @spec codigos() :: [String.t()]
  def codigos, do: for(%{"code" => c} when is_binary(c) <- papeis(), do: c)

  @doc "A frase da recusa do último administrador ativo."
  @spec frase_ultimo_admin() :: String.t() | nil
  def frase_ultimo_admin, do: texto("last_active_admin", "refusal")

  @doc "A frase de quando a conta não tem mudança de papel registrada."
  @spec frase_sem_registro() :: String.t() | nil
  def frase_sem_registro, do: texto("no_change_recorded", "absent_phrase")

  defp papeis do
    case ler("roles") do
      lista when is_list(lista) -> Enum.filter(lista, &is_map/1)
      _ -> []
    end
  end

  defp texto(regra, chave) do
    case ler(regra) do
      %{^chave => valor} when is_binary(valor) -> valor
      _ -> nil
    end
  end

  defp ler(regra) do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"rules" => regras}} -> get_in(regras, [regra, "values"])
      _ -> nil
    end
  end
end
