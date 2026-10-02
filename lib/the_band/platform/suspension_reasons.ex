defmodule TheBand.Platform.SuspensionReasons do
  @moduledoc """
  As razões de suspender e de reativar uma organização, lidas da base — spec 070, T048 (FR-003;
  research R5). Regra `platform.tenant_suspension`
  (`priv/knowledge_base/rules/platform_tenant_suspension.yaml`).

  Depende de: nenhuma ontologia. Na forma de `TheBand.Tenants.AccountLifecycle`.

  **Base ausente devolve lista vazia, e o ato recusa** com `:vocabulario_nao_declarado`: a tela diz
  por quê, em vez de oferecer um formulário sem opção nenhuma.
  """
  alias TheBand.Ontology.KnowledgeBase

  @regra "platform.tenant_suspension"

  # A regra lida pode ser trocada por ambiente SÓ para o teste da base sem ela, que não tem como
  # apagar a linha da ETS (protegida, do processo da base). Em produção ninguém configura isso.
  defp regra, do: Application.get_env(:the_band, __MODULE__, [])[:regra] || @regra

  @type razao :: %{required(String.t()) => term()}

  @doc "As razões de suspender que a tela oferece. `not_recorded` não está entre elas."
  @spec de_suspensao() :: [razao()]
  def de_suspensao, do: valores("suspend_reasons", "offered")

  @doc """
  As razões de reativar que cabem contra uma suspensão aberta por `razao_da_suspensao`. Uma razão
  com `offered_only_against` só aparece contra aquela: `investigation_closed_no_compromise` sugeriria
  investigação onde não houve.
  """
  @spec de_reativacao(String.t()) :: [razao()]
  def de_reativacao(razao_da_suspensao) do
    "reactivate_reasons"
    |> valores("offered")
    |> Enum.filter(&(&1["offered_only_against"] in [nil, razao_da_suspensao]))
  end

  @doc "Os códigos que só a migração escreve, e que a tela nunca oferece."
  @spec so_registradas() :: [String.t()]
  def so_registradas, do: "suspend_reasons" |> valores("recorded_only") |> codigos()

  @doc "A nota é obrigatória para esta razão neste ato?"
  @spec nota_obrigatoria?(:suspender | :reativar, String.t()) :: boolean()
  def nota_obrigatoria?(:suspender, codigo), do: codigo in lista("note_required", "on_suspend")
  def nota_obrigatoria?(:reativar, codigo), do: codigo in lista("note_required", "on_reactivate")

  @doc "A frase de quando não há nota: ausência dita, nunca célula vazia."
  @spec frase_sem_nota() :: String.t()
  def frase_sem_nota do
    case ler("note_required", "absent_phrase") do
      frase when is_binary(frase) -> frase
      _ -> "no note"
    end
  end

  @doc """
  O rótulo de tela de um código, de qualquer das listas. Código sem rótulo declarado imprime o
  próprio código: feio de propósito, para alguém reparar e declarar o que falta.
  """
  @spec rotulo(String.t()) :: String.t()
  def rotulo(codigo) do
    todas =
      valores("suspend_reasons", "offered") ++
        valores("suspend_reasons", "recorded_only") ++ valores("reactivate_reasons", "offered")

    case Enum.find(todas, &(&1["code"] == codigo)) do
      %{"label" => rotulo} when is_binary(rotulo) -> rotulo
      _ -> codigo
    end
  end

  @doc "O vocabulário está declarado? Sem ele, os dois atos recusam."
  @spec vocabulario_declarado?() :: boolean()
  def vocabulario_declarado?, do: de_suspensao() != [] and de_reativacao("other") != []

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

  defp ler(regra, chave) do
    case KnowledgeBase.rule(regra()) do
      {:ok, %{"rules" => regras}} -> get_in(regras, [regra, "values", chave])
      _ -> nil
    end
  end

  defp codigos(razoes), do: razoes |> Enum.map(& &1["code"]) |> Enum.filter(&is_binary/1)
end
