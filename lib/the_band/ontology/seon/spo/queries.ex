defmodule TheBand.Ontology.SEON.SPO.Queries do
  @moduledoc """
  Leituras de SPO. Implementação; a fronteira é `TheBand.Ontology.SEON.SPO`.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  As atividades de uma entidade, em ordem **crescente** de `occurred_at`.

  A ordem não é preferência: é a sequência do que aconteceu, e invertê-la faria a tela
  contar a história de trás para frente.
  """
  @spec list_activities(Tenant.t(), String.t(), Ecto.UUID.t()) :: [Activity.t()]
  def list_activities(%Tenant{id: tenant_id}, subject_type, subject_id) do
    Repo.all(
      from a in Activity,
        where:
          a.tenant_id == ^tenant_id and
            a.subject_type == ^subject_type and
            a.subject_id == ^subject_id,
        order_by: [asc: a.occurred_at, asc: a.id]
    )
  end

  @doc """
  O tempo entre o início do trabalho e o fim — ou a razão de não haver medida.

  **Nunca devolve lead time no lugar.** São medidas diferentes: o lead time inclui o
  tempo em que ninguém tocou na issue, e trocá-las em silêncio faria a organização
  decidir sobre um número que responde outra pergunta — FR-009.

  As três causas de `:no_start_signal` **não se resolvem no mesmo lugar**, e por isso
  são valores distintos:

    * `:no_movement_collected` — a plataforma não olhou; resolve-se coletando;
    * `:no_state_means_in_progress` — o quadro não tem estado de andamento, e aí a
      medida é impossível para **toda** issue dele (`process.ap05`); resolve-se no quadro;
    * `:no_start_rule_declared` — há movimentação e ninguém declarou qual marca o
      início; resolve-se declarando, e a plataforma recusa escolher sozinha (FR-007).

  Achatá-las numa só seria a L57: três lacunas diferentes com a mesma cara.
  """
  @spec cycle_time(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, integer()}
          | {:error,
             :no_movement_collected | :no_state_means_in_progress | :no_start_rule_declared}
  def cycle_time(%Tenant{} = tenant, issue_id) do
    movimentacoes =
      tenant
      |> list_activities("issue", issue_id)
      |> Enum.filter(&(&1.activity_type == "ProjectV2ItemStatusChangedEvent"))

    cond do
      movimentacoes == [] ->
        {:error, :no_movement_collected}

      not Enum.any?(movimentacoes, &estado_de_andamento?/1) ->
        {:error, :no_state_means_in_progress}

      true ->
        {:error, :no_start_rule_declared}
    end
  end

  defp estado_de_andamento?(%{payload: payload}) do
    andamento?(payload["status"]) or andamento?(payload["previousStatus"])
  end

  @doc """
  Se o nome de um estado é reconhecido como trabalho em andamento.

  **Os nomes vêm da base de conhecimento**, e não de lista no código — princípio IV. A
  regra `process.antipatterns` os declara sob o `ap05`, junto do motivo de a lista ser
  curta: ela erra para o lado de sinalizar, e o erro contrário silenciaria o antipadrão.

  Isto **não** é a declaração da FR-007. Aquela escolhe **qual** movimentação marca o
  começo, e a plataforma recusa fazê-la sozinha. Esta responde uma pergunta mais fraca —
  existe **algum** estado que signifique trabalho acontecendo? — e não reconhecer nenhum
  é o que afirma o `process.ap05`.
  """
  @spec andamento?(String.t() | nil) :: boolean()
  def andamento?(nil), do: false

  def andamento?(estado) do
    normalizado = normalizar_estado(estado)
    normalizado != "" and Enum.any?(estados_de_andamento(), &(&1 == normalizado))
  end

  defp estados_de_andamento do
    case KnowledgeBase.rule("process.antipatterns") do
      {:ok, regra} ->
        regra
        |> Map.get("structural_antipatterns", [])
        |> Enum.find(%{}, &(&1["id"] == "process.ap05.board_without_in_progress"))
        |> get_in(["recognized_in_progress_states", "values"])
        |> Kernel.||([])
        |> Enum.map(&normalizar_estado/1)

      # A base não carregada **não** é lista vazia lida como "nenhum estado reconhecido":
      # isso faria todo quadro ser sinalizado por causa de uma falha de carga. Levanta,
      # porque a regra é obrigatória para a resposta ter sentido.
      :error ->
        raise "regra process.antipatterns ausente da base de conhecimento"
    end
  end

  defp normalizar_estado(estado) do
    estado
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/u, "")
  end

  @doc """
  Os estados de quadro observados, com a frequência de cada um.

  É o que torna visível o `process.ap05`: um quadro cujos estados não incluem nenhum
  que signifique "em andamento" não permite medir cycle time de **nenhuma** issue dele.

  O estado vem do `payload` da movimentação, e não de coluna própria: ele é dado da
  origem, e promovê-lo a coluna exigiria decidir o vocabulário — que é justamente a
  decisão que a plataforma recusa tomar sozinha.
  """
  @spec count_board_states(Tenant.t()) :: [%{state: String.t(), count: pos_integer()}]
  def count_board_states(%Tenant{id: tenant_id}) do
    Repo.all(
      from a in Activity,
        where:
          a.tenant_id == ^tenant_id and
            a.activity_type == "ProjectV2ItemStatusChangedEvent",
        select: a.payload
    )
    |> Enum.map(& &1["status"])
    # A string vazia é o estado ANTERIOR da primeira transição vindo no lugar do novo;
    # descartá-la aqui é correto, e é diferente de descartar o evento — ele já está
    # gravado inteiro.
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.frequencies()
    |> Enum.map(fn {estado, contagem} -> %{state: estado, count: contagem} end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  @doc """
  Os tipos de atividade observados, com a frequência de cada um.

  **É o que permite a decisão da FR-007.** Quem vai declarar qual movimentação marca o
  início precisa saber quais tipos existem e com que frequência.

  Inclui os de `concept_id` nulo, e é o ponto: são eles que dizem o que a rede ainda
  não nomeia. Filtrá-los esconderia exatamente a informação que a lista existe para dar.
  """
  @spec count_activity_types(Tenant.t()) :: [
          %{type: String.t(), concept: String.t() | nil, count: pos_integer()}
        ]
  def count_activity_types(%Tenant{id: tenant_id}) do
    Repo.all(
      from a in Activity,
        where: a.tenant_id == ^tenant_id,
        group_by: [a.activity_type, a.concept_id],
        order_by: [desc: count(a.id), asc: a.activity_type],
        select: %{type: a.activity_type, concept: a.concept_id, count: count(a.id)}
    )
  end
end
