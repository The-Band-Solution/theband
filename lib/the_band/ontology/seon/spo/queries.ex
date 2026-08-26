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
  As atividades de **várias** entidades de uma vez, agrupadas por entidade.

  Existe porque avaliar antipadrão de 152 issues chamando `list_activities/3` uma vez por
  issue é o N+1 clássico. Aqui é uma consulta, e o agrupamento acontece em memória.

  Entidade sem atividade **não aparece no mapa** — e quem chama precisa distinguir isso de
  "avaliei e não achei nada". A chave ausente é a informação.
  """
  @spec list_activities_by_subject(Tenant.t(), String.t(), [Ecto.UUID.t()]) ::
          %{Ecto.UUID.t() => [Activity.t()]}
  def list_activities_by_subject(%Tenant{}, _subject_type, []), do: %{}

  def list_activities_by_subject(%Tenant{id: tenant_id}, subject_type, subject_ids) do
    Repo.all(
      from a in Activity,
        where:
          a.tenant_id == ^tenant_id and
            a.subject_type == ^subject_type and
            a.subject_id in ^subject_ids,
        order_by: [asc: a.occurred_at, asc: a.id]
    )
    |> Enum.group_by(& &1.subject_id)
  end

  @doc """
  O tempo entre o início do trabalho e o fim — ou a razão de não haver medida.

  **Nunca devolve lead time no lugar.** São medidas diferentes: o lead time inclui o
  tempo em que ninguém tocou na issue, e trocá-las em silêncio faria a organização
  decidir sobre um número que responde outra pergunta — FR-009.

  As causas **não se resolvem no mesmo lugar**, e por isso são valores distintos:

    * `:no_movement_collected` — a plataforma não olhou; resolve-se coletando;
    * `:no_state_means_in_progress` — o **quadro** não tem estado de andamento, e aí a
      medida é impossível para toda issue dele (`process.ap05`); resolve-se no quadro;
    * `:issue_never_reached_in_progress` — o quadro tem o estado, e **esta** issue não
      passou por ele: foi da espera direto para o fim;
    * `:no_start_rule_declared` — há movimentação por estado de andamento e ninguém
      declarou qual marca o início; a plataforma recusa escolher sozinha (FR-007).

  Achatá-las seria a L57: lacunas diferentes com a mesma cara. E a segunda contra a
  terceira é a que mais engana — afirmar que o quadro não tem estado de andamento
  porque **uma** issue não passou por um é dizer do todo o que se observou da parte.

  Aceita `(tenant, issue_id)`, que consulta, ou `(atividades, estados_do_quadro)` já
  carregados — a tela usa a segunda para não recarregar o que acabou de ler.
  """
  @spec cycle_time(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, integer()}
          | {:error,
             :no_movement_collected | :no_state_means_in_progress | :no_start_rule_declared}
  def cycle_time(%Tenant{} = tenant, issue_id) do
    cycle_time(list_activities(tenant, "issue", issue_id), count_board_states(tenant))
  end

  @spec cycle_time([Activity.t()], [%{state: String.t(), count: pos_integer()}]) ::
          {:ok, integer()}
          | {:error,
             :no_movement_collected
             | :no_state_means_in_progress
             | :issue_never_reached_in_progress
             | :no_start_rule_declared}
  def cycle_time(atividades, estados_do_quadro) when is_list(atividades) do
    movimentacoes =
      Enum.filter(atividades, &(&1.activity_type == "ProjectV2ItemStatusChangedEvent"))

    cond do
      movimentacoes == [] ->
        {:error, :no_movement_collected}

      # **A condição do quadro é avaliada com os estados do QUADRO**, e nunca com as
      # movimentações desta issue. Uma issue que percorreu `Backlog → Ready → In review
      # → Done` não passou por estado de andamento — e isso não autoriza afirmar que o
      # quadro não tem um. Medido em 2026-08-15: a issue #1 é assim, e o quadro dela
      # tem `In Progress` com 37 movimentações.
      not Enum.any?(estados_do_quadro, &andamento?(&1.state)) ->
        {:error, :no_state_means_in_progress}

      not Enum.any?(movimentacoes, &estado_de_andamento?/1) ->
        {:error, :issue_never_reached_in_progress}

      true ->
        {:error, :no_start_rule_declared}
    end
  end

  @typedoc """
  Atividade registrada de uma pessoa, por mês — issue #508.

  **Não é throughput, e o nome não pode sugerir que seja.**

  | | `flow.throughput` | isto |
  |---|---|---|
  | conta | tarefa **concluída** | **evento** ocorrido |
  | precisa de | início e fim | um carimbo só |
  | responde | quanto trabalho atravessou o sistema | quanta atividade foi registrada |

  Emprestar o nome seria o defeito: quem lê "throughput" compara com a definição da SRO e
  dimensiona sprint com ele — e este número conta comentário, movimentação de card e
  designação junto com trabalho concluído.
  """
  @type atividade_mensal :: %{
          person_id: Ecto.UUID.t(),
          login: String.t(),
          name: String.t(),
          total: non_neg_integer(),
          meses: [{String.t(), non_neg_integer()}]
        }

  @typedoc """
  O que a contagem por pessoa **não alcança**, com o tamanho da lacuna.

  `spo_performed_project_activities` guarda `performer_login`, e não o identificador da
  pessoa. Quem executou atividade mas não está em `eo_people` não pode ser classificado —
  e a plataforma **não adivinha** qual é robô.
  """
  @type nao_classificado :: %{
          atividades: non_neg_integer(),
          autores: [%{login: String.t(), atividades: non_neg_integer()}]
        }

  @doc """
  Atividade registrada por pessoa e por mês, e o que a contagem não alcança.

  ## Por que o robô não é filtrado por nome

  Na medição de 2026-08-26, os quatro autores de atividade fora de `eo_people` eram:

      github-project-automation    2.877
      MachadoVsouza                   17
      leandrocaronelanschi             6
      github-actions                   2

  Dois **parecem** robô pelo nome e dois **parecem** pessoa. Classificar por `github-*`
  publicaria a suposição como medida — e o erro cai para o lado barato: o não reconhecido
  alguém corrige, o reconhecido errado vira número.

  Por isso a divisão é por `eo_people.account_type`, que é declarado, e o que não está lá
  volta em `nao_classificado` **com os logins à vista**. Quem lê decide; a plataforma não.

  ## A ausência tem tamanho

  2.902 atividades de 4 autores ficam de fora hoje — **15% do total**. Devolver só as
  16.298 classificadas faria a soma parecer completa.
  """
  @spec activity_by_person_month(Tenant.t()) :: %{
          pessoas: [atividade_mensal()],
          nao_classificado: nao_classificado()
        }
  def activity_by_person_month(%Tenant{id: tenant_id} = tenant) do
    %{
      pessoas: atividade_das_pessoas(tenant_id),
      nao_classificado: atividade_sem_pessoa(tenant)
    }
  end

  defp atividade_das_pessoas(tenant_id) do
    Repo.all(
      from a in Activity,
        join: p in "eo_people",
        on: p.login == a.performer_login and p.tenant_id == a.tenant_id,
        where: a.tenant_id == ^tenant_id and p.account_type == "person",
        group_by: [p.id, p.login, p.name, fragment("to_char(?, 'YYYY-MM')", a.occurred_at)],
        order_by: [asc: p.name, asc: fragment("to_char(?, 'YYYY-MM')", a.occurred_at)],
        select: %{
          person_id: type(p.id, :binary_id),
          login: p.login,
          name: p.name,
          mes: fragment("to_char(?, 'YYYY-MM')", a.occurred_at),
          quantas: count(a.id)
        }
    )
    |> Enum.group_by(& &1.person_id)
    |> Enum.map(fn {person_id, linhas} ->
      %{
        person_id: person_id,
        login: hd(linhas).login,
        name: hd(linhas).name,
        total: Enum.sum(Enum.map(linhas, & &1.quantas)),
        meses: Enum.map(linhas, &{&1.mes, &1.quantas})
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  # Robô, aplicação, e quem simplesmente não foi coletado — juntos, e **sem serem
  # separados por palpite**. O que os une é o fato de não haver pessoa declarada por trás.
  defp atividade_sem_pessoa(%Tenant{id: tenant_id}) do
    autores =
      Repo.all(
        from a in Activity,
          left_join: p in "eo_people",
          on: p.login == a.performer_login and p.tenant_id == a.tenant_id,
          where:
            a.tenant_id == ^tenant_id and
              (is_nil(p.id) or p.account_type != "person"),
          group_by: a.performer_login,
          order_by: [desc: count(a.id)],
          select: %{login: a.performer_login, atividades: count(a.id)}
      )

    %{atividades: Enum.sum(Enum.map(autores, & &1.atividades)), autores: autores}
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
  @spec count_board_states(Tenant.t()) :: [
          %{state: String.t(), count: pos_integer(), variants: [String.t()]}
        ]
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
    # **Caixa não é diferença de significado.** `In Progress` e `In progress` são o
    # mesmo estado digitado de dois jeitos, e contá-los separado parte a medida: medido
    # em 2026-08-15, quem contasse "em andamento" acharia 19 onde existem 37.
    #
    # Isto é diferente do `ap06`, que compara ignorando também separador: `To Do` e
    # `Todo` continuam dois estados até alguém confirmar que são um, porque ali a
    # diferença **pode** ser real.
    |> Enum.group_by(&String.downcase/1)
    |> Enum.map(fn {_chave, grafias} -> agrupar(grafias) end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  # A grafia exibida é a mais frequente, e as outras ficam registradas: esconder que a
  # origem escreve o mesmo estado de dois jeitos apagaria um problema real do quadro.
  defp agrupar(grafias) do
    por_grafia = Enum.frequencies(grafias)
    {principal, _} = Enum.max_by(por_grafia, fn {_g, n} -> n end)

    %{
      state: principal,
      count: length(grafias),
      variants: por_grafia |> Map.keys() |> Enum.reject(&(&1 == principal)) |> Enum.sort()
    }
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
