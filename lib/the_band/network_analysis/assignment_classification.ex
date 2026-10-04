defmodule TheBand.NetworkAnalysis.AssignmentClassification do
  @moduledoc """
  Cada par (issue, conta responsável) da rede de designação cai em **exatamente um** destino —
  feature 076, T024 (FR-005 a FR-007; research.md R12, R13; regra `assignment.network.edge`).

  ## A ordem é a da regra

  `assignment.network.edge` → `exclusions.values.order`, conferida por `Parameters` contra
  `@ordem_implementada` (se a base mudar a ordem, o cálculo levanta antes de classificar):

  1. `:bot_or_app` — qualquer lado é máquina. Pessoa ligada: o `account_type` de EO. Conta não
     ligada: o tipo **gravado** na coleta (R13), que já é o de `Mapper.account_type/1`;
  2. `:organization_account` — qualquer lado é conta declarada da organização (R14). Depois de
     máquina porque uma conta pode ser as duas, e a contagem não pode dobrar;
  3. `:unlinked_person` — qualquer lado sem pessoa ligada. Tipo gravado **nulo** (linha anterior à
     T021 sem payload, ou autor apagado) cai aqui e é marcado `unknown_type?`, para a leitura dizer
     quantos (`account_type_unknown`): a limitação medida, e não presumida;
  4. `:self_assignment` — autor e responsável são a mesma pessoa;
  5. `{:aresta, autor, responsavel}`.

  A issue sem responsável vigente não é par: é `:no_assignee`, e conta só em
  `issues_without_assignee`.

  ## O peso, e o invariante

  O peso de uma aresta é o número de issues **distintas** do par. Invariante da regra: soma dos
  pesos + as quatro exclusões = pares da janela (`pairs`), com os de aresta deduplicados por
  pessoa. Conferido em teste.

  **Nenhum login entra nem sai daqui** (R9): os pares chegam só com ids e tipos.

  Puro: sem `Repo`, sem relógio, sem `Logger`. Depende de: EO (pelo mapa de tipos que recebe) e
  Tenants (pelo conjunto de contas declaradas que recebe).
  """

  @maquina ~w(bot app)

  # A ordem que o código abaixo implementa, conferida contra a base por `Parameters`.
  @ordem_implementada ~w(bot_or_app organization_account unlinked_person self_assignment)

  @type destino ::
          {:aresta, Ecto.UUID.t(), Ecto.UUID.t()}
          | :bot_or_app
          | :organization_account
          | :unlinked_person
          | :self_assignment
          | :no_assignee

  @type par :: %{
          collected_issue_id: Ecto.UUID.t(),
          opened_at: DateTime.t(),
          assigned: boolean(),
          author_person_id: Ecto.UUID.t() | nil,
          author_account_type: String.t() | nil,
          assignee_person_id: Ecto.UUID.t() | nil,
          assignee_account_type: String.t() | nil
        }

  @type classificado :: %{
          collected_issue_id: Ecto.UUID.t(),
          opened_at: DateTime.t(),
          destino: destino(),
          unknown_type?: boolean()
        }

  @type resumo :: %{
          edges: [%{source: Ecto.UUID.t(), target: Ecto.UUID.t(), weight: pos_integer()}],
          exclusions: %{String.t() => non_neg_integer()},
          account_type_unknown: non_neg_integer()
        }

  @doc "A ordem das exclusões que esta classificação implementa (para `Parameters` conferir)."
  @spec order() :: [String.t()]
  def order, do: @ordem_implementada

  @doc """
  Classifica os pares de `WorkItems.assignment_pairs/3` com os tipos de `EO.account_types/2` e as
  contas declaradas de `Tenants.organization_account_ids/1`.
  """
  @spec classify([par()], %{Ecto.UUID.t() => String.t()}, MapSet.t()) :: [classificado()]
  def classify(pares, tipos, contas_da_organizacao) do
    Enum.map(pares, fn par ->
      {destino, desconhecido?} = destino(par, tipos, contas_da_organizacao)

      %{
        collected_issue_id: par.collected_issue_id,
        opened_at: par.opened_at,
        destino: destino,
        unknown_type?: desconhecido?
      }
    end)
  end

  @doc """
  As arestas e as contagens dos pares abertos a partir de `inicio` (a janela entra pelo instante de
  abertura da issue, regra `window`).

  `exclusions` leva os códigos da base em texto, mais `pairs`, `issues` (issues distintas da
  janela) e `issues_without_assignee`.
  """
  @spec summarize([classificado()], DateTime.t()) :: resumo()
  def summarize(classificados, %DateTime{} = inicio) do
    na_janela = Enum.filter(classificados, &(DateTime.compare(&1.opened_at, inicio) != :lt))
    {sem_responsavel, pares} = Enum.split_with(na_janela, &(&1.destino == :no_assignee))

    # Deduplicado por pessoa: dois logins da mesma pessoa na mesma issue são um par só.
    arestas_por_issue =
      for %{destino: {:aresta, a, r}, collected_issue_id: i} <- pares, uniq: true, do: {a, r, i}

    arestas =
      arestas_por_issue
      |> Enum.frequencies_by(fn {a, r, _i} -> {a, r} end)
      |> Enum.map(fn {{a, r}, peso} -> %{source: a, target: r, weight: peso} end)
      |> Enum.sort_by(&{&1.source, &1.target})

    excluidos = Enum.reject(pares, &match?({:aresta, _, _}, &1.destino))
    por_motivo = Enum.frequencies_by(excluidos, &Atom.to_string(&1.destino))

    exclusoes =
      @ordem_implementada
      |> Map.new(&{&1, Map.get(por_motivo, &1, 0)})
      |> Map.merge(%{
        "pairs" => length(arestas_por_issue) + length(excluidos),
        "issues" => na_janela |> Enum.map(& &1.collected_issue_id) |> Enum.uniq() |> length(),
        "issues_without_assignee" =>
          sem_responsavel |> Enum.map(& &1.collected_issue_id) |> Enum.uniq() |> length()
      })

    %{
      edges: arestas,
      exclusions: exclusoes,
      account_type_unknown: Enum.count(excluidos, & &1.unknown_type?)
    }
  end

  defp destino(%{assigned: false}, _tipos, _contas), do: {:no_assignee, false}

  defp destino(par, tipos, contas) do
    autor = lado(par.author_person_id, par.author_account_type, tipos, contas)
    responsavel = lado(par.assignee_person_id, par.assignee_account_type, tipos, contas)
    lados = [autor, responsavel]
    algum? = fn fato -> Enum.any?(lados, &Map.get(&1, fato, false)) end

    cond do
      algum?.(:maquina) -> {:bot_or_app, false}
      algum?.(:organizacao) -> {:organization_account, false}
      algum?.(:sem_tipo) -> {:unlinked_person, true}
      algum?.(:sem_pessoa) -> {:unlinked_person, false}
      autor.pessoa == responsavel.pessoa -> {:self_assignment, false}
      true -> {{:aresta, autor.pessoa, responsavel.pessoa}, false}
    end
  end

  # Cada lado diz os fatos que tem, e a ORDEM de `destino/3` decide qual pesa: uma conta pode ser
  # máquina em EO e declarada da organização ao mesmo tempo, e conta uma vez só, como máquina.
  defp lado(person_id, _gravado, tipos, contas) when is_binary(person_id) do
    organizacao? = MapSet.member?(contas, person_id)

    case Map.fetch(tipos, person_id) do
      {:ok, tipo} when tipo in @maquina -> %{maquina: true, organizacao: organizacao?}
      {:ok, "person"} -> %{pessoa: person_id, organizacao: organizacao?}
      # De outro tenant, ou apagada de EO depois da coleta: falha fechada.
      _ -> %{sem_pessoa: true}
    end
  end

  # Conta não ligada: o tipo gravado na coleta. Nulo é "não se sabe", e nunca "pessoa".
  defp lado(nil, tipo, _tipos, _contas) when tipo in @maquina, do: %{maquina: true}
  defp lado(nil, nil, _tipos, _contas), do: %{sem_tipo: true}
  defp lado(nil, _pessoa, _tipos, _contas), do: %{sem_pessoa: true}
end
