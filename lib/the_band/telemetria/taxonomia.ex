defmodule TheBand.Telemetria.Taxonomia do
  @moduledoc """
  A taxonomia da jornada de entrar e sair, lida da base de conhecimento — spec 074, T007.

  Depende de: nenhuma ontologia. Lê a regra `journey.entrar_e_sair`
  (`priv/knowledge_base/rules/journey_entrar_e_sair.yaml`) pela `KnowledgeBase`.

  Este módulo é o **leitor**: nenhuma lista de passo ou de motivo está escrita aqui. Quem decide
  o que pode sair é o YAML, e quem aplica é `TheBand.Telemetria.Exportador`.

  ## Base ausente: nada sai

  Sem a regra declarada, as listas voltam **vazias**, e o exportador descarta todo span — e
  conta o descarte. É a mesma forma de `TheBand.Tenants.AccountLifecycle`: uma lista de reserva
  no código seria a duplicata silenciosa que deixaria a telemetria afirmando com a base fora do
  ar.
  """

  alias TheBand.Ontology.KnowledgeBase

  @regra "journey.entrar_e_sair"

  @doc "O nome da jornada, como sai em `journey.name`."
  @spec jornada() :: String.t()
  def jornada, do: "entrar_e_sair"

  @doc "Os passos declarados, na ordem do YAML."
  @spec passos() :: [String.t()]
  def passos, do: Enum.map(passos_declarados(), & &1["id"])

  @doc "Os desfechos declarados para um passo. `abandonou` aparece aqui, e nunca é emitido."
  @spec desfechos(String.t()) :: [String.t()]
  def desfechos(passo), do: passo |> declarado() |> Map.get("outcomes", []) |> strings()

  @doc "Os motivos de falha declarados para um passo."
  @spec motivos(String.t()) :: [String.t()]
  def motivos(passo) do
    passo
    |> declarado()
    |> Map.get("failure_reasons", [])
    |> lista()
    |> Enum.map(fn
      %{"id" => id} when is_binary(id) -> id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Tudo o que o exportador precisa, numa leitura: para cada passo, os desfechos que a aplicação
  **pode emitir** (sem `abandonou`, que é derivado na consulta) e os motivos.
  """
  @spec regras_por_passo() :: %{String.t() => %{desfechos: [String.t()], motivos: [String.t()]}}
  def regras_por_passo do
    Map.new(passos_declarados(), fn passo ->
      id = passo["id"]
      {id, %{desfechos: desfechos(id) -- ["abandonou"], motivos: motivos(id)}}
    end)
  end

  defp declarado(passo) do
    Enum.find(passos_declarados(), %{}, &(&1["id"] == passo))
  end

  defp passos_declarados do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"steps" => passos}} when is_list(passos) ->
        Enum.filter(passos, &match?(%{"id" => id} when is_binary(id), &1))

      _ ->
        []
    end
  end

  defp lista(valor) when is_list(valor), do: valor
  defp lista(_), do: []

  defp strings(valor), do: valor |> lista() |> Enum.filter(&is_binary/1)
end
