defmodule TheBand.ReviewNetwork.Classification do
  @moduledoc """
  Cada par (conta revisora, solicitação) cai em **exatamente um** destino — feature 073, T011
  (research.md R3; R9 da segurança).

  A ordem é a da regra de exclusões da base, e a razão dela é decidibilidade: *não é pessoa* →
  *é pessoa, mas não sabemos qual* → *é a mesma pessoa*. A auto-revisão só é decidível com as duas
  pontas ligadas, e por isso vem por último.

  1. `:bot_or_app` — qualquer lado é máquina. Pessoa ligada: o `account_type` de EO. Conta
     não ligada: `Mapper.account_type/1`, **chamado e nunca reimplementado** (o `__typename` e o
     sufixo `[bot]`). Nunca o `author_type == "User"` de `Quality`, que deixa passar `algo[bot]`
     com `__typename` `User` (A14);
  2. `:unlinked_person` — qualquer lado sem pessoa ligada. **A conta apagada na origem** (login nulo)
     cai aqui, e não em bot: *"não sei quem é"* não é *"é máquina"* (decidido em 2026-10-03). Pessoa
     ligada que não está no mapa de tipos (de outro tenant) também: falha fechada;
  3. `:self_review` — revisor e autor são a mesma pessoa;
  4. `{:aresta, revisor, autor}`.

  **Os logins não saem daqui.** O par classificado leva só ids de pessoa, a solicitação e o
  instante (data-model.md §2.1).

  Puro: sem `Repo`, sem relógio, sem `Logger`. Depende de: EO (pelo mapa de tipos que recebe) e
  `SemanticIntegration.Mapper` (só `account_type/1`).
  """

  alias TheBand.SemanticIntegration.Mapper

  @type destino ::
          {:aresta, Ecto.UUID.t(), Ecto.UUID.t()}
          | :self_review
          | :bot_or_app
          | :unlinked_person

  @type par_classificado :: %{
          change_request_id: Ecto.UUID.t(),
          last_submitted_at: DateTime.t(),
          destino: destino()
        }

  @maquina ~w(bot app)

  @doc """
  Classifica os pares de `Quality.review_pairs/3` com o mapa de `EO.account_types/2`.
  """
  @spec classify([map()], %{Ecto.UUID.t() => String.t()}) :: [par_classificado()]
  def classify(pares, tipos) do
    Enum.map(pares, fn par ->
      %{
        change_request_id: par.change_request_id,
        last_submitted_at: par.last_submitted_at,
        destino: destino(par, tipos)
      }
    end)
  end

  defp destino(par, tipos) do
    revisor = lado(par.reviewer_person_id, par.reviewer_login, par.reviewer_type, tipos)

    # O lado do autor da solicitação não tem `__typename` gravado (`collected_change_requests` só
    # guarda login e pessoa): para autor não ligado, a classificação usa só o login. É limitação
    # declarada na regra, e não lacuna escondida (research.md R3).
    autor = lado(par.author_person_id, par.author_login, nil, tipos)

    case {revisor, autor} do
      {:maquina, _} -> :bot_or_app
      {_, :maquina} -> :bot_or_app
      {:unlinked_person, _} -> :unlinked_person
      {_, :unlinked_person} -> :unlinked_person
      {{:pessoa, mesma}, {:pessoa, mesma}} -> :self_review
      {{:pessoa, r}, {:pessoa, a}} -> {:aresta, r, a}
    end
  end

  defp lado(person_id, _login, _tipo, tipos) when is_binary(person_id) do
    case Map.fetch(tipos, person_id) do
      {:ok, "person"} -> {:pessoa, person_id}
      {:ok, tipo} when tipo in @maquina -> :maquina
      # De outro tenant, ou apagada de EO depois da coleta: falha fechada.
      :error -> :unlinked_person
    end
  end

  # Conta apagada na origem: `author` nulo, sem login nem tipo.
  defp lado(nil, nil, nil, _tipos), do: :unlinked_person

  defp lado(nil, login, tipo, _tipos) do
    no = %{"login" => login} |> then(&if tipo, do: Map.put(&1, "__typename", tipo), else: &1)

    if Mapper.account_type(no) in @maquina, do: :maquina, else: :unlinked_person
  end
end
