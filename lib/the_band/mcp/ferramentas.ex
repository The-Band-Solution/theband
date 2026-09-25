defmodule TheBand.MCP.Ferramentas do
  @moduledoc """
  O registro das ferramentas MCP — a **lista fechada**, casada uma a uma (feature 062, FR-023).

  Nenhuma ferramenta genérica, nenhum filtro livre, nenhum campo de ordenação vindo de
  argumento. O protocolo exige `tools/list`, e é este módulo que o responde. Acrescentar uma
  ferramenta exige tocar aqui, e isso é intencional: não se liga uma por configuração.

  ## O lastro de cada ferramenta (FR-020)

  Cada entrada nomeia **a pergunta que a base declara** e que a ferramenta responde: uma
  pergunta de competência ou uma necessidade de informação. A necessidade vale desde 2026-09-24,
  por decisão da pessoa mantenedora: `team_open_work` e `team_review_wait` não têm pergunta de
  competência, e têm necessidade de informação, que é a pergunta do GQM respondida pelas medidas.
  Ferramenta sem lastro na base é a plataforma afirmando o que não se comprometeu a afirmar.

  ## O caminho único (T006, R6 da revisão independente)

  `chamar/4` é o único caminho até uma ferramenta, e a ordem nele é fixa:

  1. **o argumento**: só `team_id`, e um UUID. Qualquer outra chave, inclusive `tenant_id`, é
     recusada de forma visível, e não ignorada;
  2. **a equipe, carregada no tenant do token**, antes do veredito. O ramo `admin` de
     `pode_ver_equipe/3` concede qualquer UUID, e sem este passo um admin que passasse o id de
     uma equipe de outro tenant receberia `checked` com resultado vazio;
  3. **o veredito**, `pode_ver_equipe/3`. Equipe inexistente, de outro tenant ou fora do alcance
     produzem **a mesma** recusa, `fora_do_alcance`: distinguir diria a quem chama o que existe;
  4. **a ferramenta**, com a equipe **carregada**, e nunca com o argumento cru.

  O registro de leitura (T021) e o de recusa (T022) entram nos passos 3 e 4, **aqui**, e não em
  cada ferramenta.

  ## A fronteira

  Nada em `lib/the_band/mcp/` referencia `TheBandWeb` nem a biblioteca do protocolo, e nada
  fala com o banco direto. As guardas estão em `test/the_band/mcp/fronteira_test.exs`.
  """

  alias TheBand.MCP.Ausencia
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.{Tenant, User}

  # **Constante, e nunca dado** — complemento 1 ao A3. O modelo lê a descrição como instrução
  # da plataforma, e um nome de equipe aqui seria um canal de injeção com a autoridade dela.
  @esquema_de_entrada %{
    "type" => "object",
    "properties" => %{
      "team_id" => %{
        "type" => "string",
        "format" => "uuid",
        "description" => "The team's id, as returned by the platform."
      }
    },
    "required" => ["team_id"],
    "additionalProperties" => false
  }

  @ferramentas [
    %{
      nome: "team_roster",
      modulo: TheBand.MCP.Ferramentas.TeamRoster,
      lastro: {:pergunta_de_competencia, "sro.cq15"},
      descricao:
        "Who belongs to this team, and by which claim — observed by the source or declared " <>
          "by someone. Does not answer how much each person worked, nor who leads: belonging " <>
          "and performing are different things."
    },
    %{
      nome: "team_open_work",
      modulo: TheBand.MCP.Ferramentas.TeamOpenWork,
      lastro: {:necessidade_de_informacao, "flow.work_in_progress"},
      descricao:
        "What each person on the team has open right now, and for how long. Does not answer " <>
          "how much each one delivered, nor compare people: the rows do not share a " <>
          "denominator, and ordering by them produces a ranking the platform refuses."
    },
    %{
      nome: "team_review_wait",
      modulo: TheBand.MCP.Ferramentas.TeamReviewWait,
      lastro: {:necessidade_de_informacao, "review.time_to_first_review"},
      descricao:
        "How long this team's work waits for its first human review, as two readings that " <>
          "are never summed: the reviewed ones, and the ones still waiting. Does not answer " <>
          "whether the review was good, nor who reviews most."
    },
    %{
      nome: "team_stale_work",
      modulo: TheBand.MCP.Ferramentas.TeamStaleWork,
      lastro: {:pergunta_de_competencia, "cmo.cq03"},
      descricao:
        "What is stalled on the team, and for how long, by the declared threshold in days. " <>
          "Does not answer whose fault it is, nor whether the stall is a problem: a stalled " <>
          "task may be waiting on a decision from outside."
    }
  ]

  @typedoc "Uma entrada do registro."
  @type ferramenta :: %{
          nome: String.t(),
          modulo: module(),
          lastro: {:pergunta_de_competencia | :necessidade_de_informacao, String.t()},
          descricao: String.t()
        }

  @doc "As ferramentas do registro, na ordem declarada. É o que `tools/list` responde."
  @spec listar() :: [ferramenta()]
  def listar, do: @ferramentas

  @doc "O esquema de entrada, o mesmo para as quatro: só `team_id`, e nada além."
  @spec esquema_de_entrada() :: map()
  def esquema_de_entrada, do: @esquema_de_entrada

  @doc "Se o lastro existe na base de conhecimento. É o que a FR-020 exige de cada entrada."
  @spec lastro_existe?(ferramenta()) :: boolean()
  def lastro_existe?(%{lastro: {:pergunta_de_competencia, id}}),
    do: match?({:ok, _}, KnowledgeBase.competency_question(id))

  def lastro_existe?(%{lastro: {:necessidade_de_informacao, id}}),
    do: match?({:ok, _}, KnowledgeBase.information_need(id))

  @doc """
  O caminho único até uma ferramenta. Devolve a resposta dela, a recusa como resposta
  (`Ausencia.recusado/1`), ou `{:error, {:argumento_invalido, motivo}}` quando o argumento não
  cabe no esquema. Argumento inválido é erro de quem chamou, e não veredito: vira erro de
  parâmetro no protocolo, e não recusa.
  """
  @spec chamar(Tenant.t(), User.t(), String.t(), map()) ::
          map() | {:error, :ferramenta_inexistente | {:argumento_invalido, String.t()}}
  def chamar(%Tenant{} = tenant, %User{} = user, nome, argumentos) when is_map(argumentos) do
    with {:ok, ferramenta} <- buscar(nome),
         {:ok, team_id} <- team_id(argumentos) do
      com_equipe(tenant, user, ferramenta, team_id)
    end
  end

  defp buscar(nome) do
    case Enum.find(@ferramentas, &(&1.nome == nome)) do
      nil -> {:error, :ferramenta_inexistente}
      ferramenta -> {:ok, ferramenta}
    end
  end

  defp team_id(%{"team_id" => id} = argumentos) when map_size(argumentos) == 1 do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, {:argumento_invalido, "team_id is not a UUID"}}
    end
  end

  defp team_id(%{"team_id" => _} = argumentos) do
    extras = argumentos |> Map.keys() |> List.delete("team_id") |> Enum.sort() |> Enum.join(", ")
    {:error, {:argumento_invalido, "unexpected argument: #{extras}"}}
  end

  defp team_id(_argumentos), do: {:error, {:argumento_invalido, "team_id is required"}}

  defp com_equipe(tenant, user, ferramenta, team_id) do
    with {:ok, equipe} <- EO.fetch_team(tenant, team_id),
         {:ok, _caminho} <- Tenants.pode_ver_equipe(tenant, user, equipe.id) do
      ferramenta.modulo.responder(tenant, equipe)
    else
      _nao_existe_ou_fora_do_alcance -> Ausencia.recusado(:fora_do_alcance)
    end
  end
end
