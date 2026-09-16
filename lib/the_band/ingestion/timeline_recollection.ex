defmodule TheBand.Ingestion.TimelineRecollection do
  @moduledoc """
  A recoleta da timeline que a origem cortou em silêncio — feature 068.

  ## O defeito, reproduzido em 2026-09-15

  Dentro de `issues(first: 50)`, a origem devolve parte da timeline de cada issue e **declara
  `totalCount` igual ao que cortou**, com `hasNextPage: false`. Não há sinal: a guarda que
  existia olhava `hasNextPage`.

  Medido na issue `#1828` do `conectafapes-project`, que tem 14 itens: pedindo 50 issues por
  página a origem declara 12; pedindo 25, declara 13; pedindo 10, devolve os 14.

  O tamanho de página já foi corrigido (`3b63587`) e vale para as próximas coletas. **Este
  módulo é o que ficou para trás**, e o corte não deixou marca: o registro truncado é
  indistinguível do completo, então não há como saber quais issues precisam sem perguntar por
  todas.

  ## Duas decisões que carregam o desenho

  **A busca é por `issue(number:)`, em lotes de 10** — o caminho medido como íntegro. A conexão
  é o caminho que cortava.

  **A conferência usa a conexão**, de propósito. Provar pelo mesmo caminho da recoleta provaria
  apenas que a origem é consistente consigo mesma, não que entregou tudo.

  ## Resolver as pessoas ANTES de gravar

  A identidade de uma atividade inclui **quem a executou**. Gravar com a pessoa não resolvida
  cria um segundo registro do mesmo evento — aconteceu ao reproduzir o defeito à mão, e custou
  11 duplicatas que tiveram de ser apagadas.
  """

  require Logger

  import Ecto.Query

  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Projects
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Tenants.Tenant

  @lote 10
  @tipos ~w(ASSIGNED_EVENT UNASSIGNED_EVENT CLOSED_EVENT REOPENED_EVENT LABELED_EVENT
            UNLABELED_EVENT PROJECT_V2_ITEM_STATUS_CHANGED_EVENT ADDED_TO_PROJECT_V2_EVENT
            CROSS_REFERENCED_EVENT SUB_ISSUE_ADDED_EVENT PARENT_ISSUE_ADDED_EVENT
            ISSUE_TYPE_ADDED_EVENT)
  @amostra 10

  @typedoc "O que a recoleta devolve. `veredito` nunca é inferido de ter terminado."
  @type relatorio :: %{
          repositorio: String.t(),
          issues_percorridas: non_neg_integer(),
          issues_com_eventos_novos: non_neg_integer(),
          eventos_inseridos: non_neg_integer(),
          eventos_promovidos: non_neg_integer(),
          issues_no_teto: non_neg_integer(),
          nao_encontradas: [integer()],
          custo: non_neg_integer(),
          conferidas: non_neg_integer(),
          divergentes: [map()],
          retomar_de: integer() | nil,
          veredito: :completa | :incompleta | :interrompida,
          limites: [String.t()],
          por_mes: %{String.t() => non_neg_integer()}
        }

  @limites [
    "Eventos que a origem nunca registrou não são recuperáveis por recoleta nenhuma — medido: " <>
      "69 dos 377 cartões do quadro 43 chegaram a Done sem gerar evento.",
    "Issue que a origem não devolve mais — apagada ou transferida — não é recolhida, e as " <>
      "atividades dela ficam sem o identificador da origem. Medido no recorte de 178 issues do " <>
      "conectafapes-project: 1 issue, 4 atividades.",
    "O identificador do evento entrou no critério de identidade em 2026-09-15, e as linhas " <>
      "anteriores a essa data não o têm. Elas o recebem quando a origem é relida — pela coleta " <>
      "normal ou por esta recoleta. Até lá, o repositório não recolhido continua com as " <>
      "ocorrências que ficaram coladas no mesmo segundo."
  ]

  @doc """
  Recolhe a timeline de **todas** as issues de um repositório observado.

  Percorre por **número de issue**, e não por cursor: cursor da origem expira e muda de
  significado entre execuções, enquanto o número é estável — é o que torna a retomada honesta.
  """
  @spec recolher(Tenant.t(), Ecto.UUID.t(), keyword()) :: {:ok, relatorio()} | {:error, term()}
  def recolher(%Tenant{} = tenant, observed_repository_id, opcoes \\ []) do
    with {:ok, repo} <- carregar_repositorio(tenant, observed_repository_id),
         {:ok, instance_url, token} <- acesso(tenant) do
      acesso = {instance_url, token}
      desde = Keyword.get(opcoes, :desde, 0)
      numeros = numeros_de_issue(tenant, observed_repository_id, desde)
      # As pessoas E os quadros resolvidos ANTES de gravar: os dois entram na ocorrência, e
      # resolver por evento seriam dezenas de milhares de idas ao banco.
      resolvidos = %{
        pessoas: pessoas_por_login(tenant),
        quadros: Projects.board_ids_by_external_id(tenant)
      }

      estado =
        numeros
        |> Enum.chunk_every(@lote)
        |> Enum.reduce_while(estado_inicial(repo), fn bloco, acc ->
          processar_bloco(tenant, acesso, repo, observed_repository_id, bloco, resolvidos, acc)
        end)

      {:ok, conferir(tenant, acesso, repo, numeros, estado)}
    end
  end

  @doc """
  Quantas issues de cada repositório ainda não foram relidas com o identificador da origem.

  **É contagem, e não indício.** Uma issue está aqui quando nenhuma das atividades dela
  carrega `source_external_id` — ou seja, quando ela não foi visitada desde 2026-09-15, o
  dia em que a consulta passou a pedir o identificador do evento. Enquanto ela estiver
  aqui, não se sabe se a timeline dela veio inteira, e as ocorrências que caíram no mesmo
  segundo continuam coladas numa linha só.

  ## A faixa de eventos foi tentada antes, e não funciona

  A primeira versão contava issues com 10 a 13 eventos, por se dizer que a distribuição
  quebrava ali. **Foi medida, e não quebra.** Sobre as 4 923 issues com pelo menos um
  evento, a contagem por issue sobe até o pico em 6 e 7 (625 e 605 issues) e desce sem
  degrau algum: 486 em 8, 419 em 9, 329 em 10, 253 em 11, 154 em 12, 144 em 13, 110 em 14,
  107 em 15. Não há assinatura de corte nessa curva.

  Contar aquela faixa marcava 880 issues sem separar truncada de inteira. Não repita.
  """
  @spec pendentes_de_recoleta(Tenant.t()) :: [map()]
  def pendentes_de_recoleta(%Tenant{id: tenant_id}) do
    %{rows: linhas} =
      Repo.query!(
        """
        WITH por_issue AS (
          SELECT ci.observed_repository_id AS repo_id, ci.id,
                 COUNT(a.id) FILTER (WHERE a.source_external_id IS NOT NULL) AS relidas
            FROM collected_issues ci
            LEFT JOIN spo_performed_project_activities a
                   ON a.subject_id = ci.id
                  AND a.subject_type = 'issue'
                  AND a.tenant_id = ci.tenant_id
           WHERE ci.tenant_id = $1
           GROUP BY 1, 2)
        SELECT s.qualified_name, o.id,
               COUNT(*) FILTER (WHERE p.relidas = 0) AS pendentes,
               COUNT(*) AS issues
          FROM por_issue p
          JOIN observed_repositories o ON o.id = p.repo_id
          JOIN cmpo_source_repositories s ON s.id = o.source_repository_id
         WHERE o.excluded_at IS NULL
         GROUP BY 1, 2
        HAVING COUNT(*) FILTER (WHERE p.relidas = 0) > 0
         ORDER BY 3 DESC
        """,
        [Ecto.UUID.dump!(tenant_id)]
      )

    for [nome, id, pendentes, issues] <- linhas do
      %{
        repositorio: nome,
        observed_repository_id: Ecto.UUID.cast!(id),
        pendentes: pendentes,
        issues: issues,
        ressalva:
          "issue sem nenhuma atividade com identificador da origem — não foi relida desde " <>
            "2026-09-15, e não se sabe se a timeline dela veio inteira"
      }
    end
  end

  # ------------------------------------------------------------------ privadas

  defp estado_inicial(repo) do
    %{
      repositorio: repo.qualified_name,
      issues_percorridas: 0,
      issues_com_eventos_novos: 0,
      eventos_inseridos: 0,
      eventos_promovidos: 0,
      issues_no_teto: 0,
      nao_encontradas: [],
      custo: 0,
      conferidas: 0,
      divergentes: [],
      retomar_de: nil,
      veredito: :completa,
      limites: @limites,
      por_mes: %{}
    }
  end

  defp processar_bloco(tenant, acesso, repo, observado_id, bloco, resolvidos, acc) do
    case buscar_timelines(acesso, repo, bloco) do
      {:ok, issues, custo} ->
        acc = %{acc | custo: acc.custo + custo}
        {:cont, Enum.reduce(issues, acc, &gravar_issue(tenant, observado_id, &1, resolvidos, &2))}

      {:error, {:rate_limited, _}} ->
        Logger.warning("recoleta interrompida por cota; retomar de ##{hd(bloco)}")
        {:halt, %{acc | veredito: :interrompida, retomar_de: hd(bloco)}}

      # Uma issue apagada na origem derruba o LOTE inteiro: a origem recusa a consulta toda
      # em vez de devolver o que existe. Sem este ramo, uma issue apagada faz a recoleta parar
      # e declarar-se interrompida — e foi o que aconteceu na primeira execução real, na #1698.
      #
      # A saída é refazer o lote **uma a uma**: quem existe é recolhido, quem não existe vira
      # `nao_encontradas`, que é o caso que a spec já previa. Custa uma consulta por issue do
      # lote, e só quando o lote falha.
      {:error, motivo} ->
        Logger.info(
          "lote recusado (#{inspect(motivo)}); refazendo uma a uma a partir de ##{hd(bloco)}"
        )

        {:cont, uma_a_uma(tenant, acesso, repo, observado_id, bloco, resolvidos, acc)}
    end
  end

  defp uma_a_uma(tenant, acesso, repo, observado_id, bloco, resolvidos, acc) do
    Enum.reduce(bloco, acc, fn numero, acc ->
      case buscar_timelines(acesso, repo, [numero]) do
        {:ok, [], custo} ->
          %{acc | custo: acc.custo + custo, nao_encontradas: [numero | acc.nao_encontradas]}

        {:ok, issues, custo} ->
          acc = %{acc | custo: acc.custo + custo}
          Enum.reduce(issues, acc, &gravar_issue(tenant, observado_id, &1, resolvidos, &2))

        {:error, _} ->
          %{acc | nao_encontradas: [numero | acc.nao_encontradas]}
      end
    end)
  end

  defp gravar_issue(tenant, observado_id, {numero, itens}, resolvidos, acc) do
    case issue_por_numero(tenant, observado_id, numero) do
      nil ->
        %{acc | nao_encontradas: [numero | acc.nao_encontradas]}

      issue ->
        antes = acc.eventos_inseridos
        acc = Enum.reduce(itens, acc, &gravar_item(tenant, issue, &1, resolvidos, &2))
        novos = acc.eventos_inseridos - antes

        %{
          acc
          | issues_percorridas: acc.issues_percorridas + 1,
            issues_com_eventos_novos: acc.issues_com_eventos_novos + if(novos > 0, do: 1, else: 0)
        }
    end
  end

  defp gravar_item(tenant, issue, item, %{pessoas: pessoas, quadros: quadros}, acc) do
    login = get_in(item, ["actor", "login"])

    attrs = %{
      activity_type: item["__typename"],
      concept_id: conceito(item["__typename"]),
      occurred_at: instante(item["createdAt"]),
      subject_type: "issue",
      subject_id: issue.id,
      # A pessoa resolvida ANTES: ela faz parte da identidade, e gravar sem resolver
      # criaria um segundo registro do mesmo evento.
      performer_id: pessoas[login],
      performer_login: login,
      source_system: "github",
      source_instance: "https://github.com",
      # O id que a origem dá ao evento — ver a nota em `github_work_items.ex`.
      source_external_id: item["id"],
      # O quadro e a coluna — ver a nota em `github_work_items.ex`.
      board_external_id: get_in(item, ["project", "id"]),
      board_id: quadros[get_in(item, ["project", "id"])],
      status_name: item["status"],
      payload: item
    }

    case SPO.record_activity(tenant, attrs) do
      {:ok, %{outcome: :created}} ->
        mes = String.slice(item["createdAt"] || "", 0, 7)

        %{
          acc
          | eventos_inseridos: acc.eventos_inseridos + 1,
            por_mes: Map.update(acc.por_mes, mes, 1, &(&1 + 1))
        }

      # A linha já existia e recebeu o identificador da origem. Não é evento novo, e
      # por isso fica fora de `por_mes` — contá-la ali inflaria o "antes e depois" com
      # ocorrências que já estavam medidas.
      {:ok, %{outcome: :promoted}} ->
        %{acc | eventos_promovidos: acc.eventos_promovidos + 1}

      _ ->
        acc
    end
  end

  # A conferência usa a CONEXÃO — o caminho que cortava —, e não a busca por número que a
  # recoleta usou. Provar pelo mesmo caminho provaria só que a origem é consistente consigo
  # mesma; a pergunta é outra: a recoleta trouxe o que existe?
  defp conferir(_tenant, _acesso, _repo, _numeros, %{veredito: :interrompida} = estado),
    do: estado

  defp conferir(tenant, acesso, repo, numeros, estado) do
    amostra = numeros |> Enum.shuffle() |> Enum.take(@amostra)

    divergentes =
      for numero <- amostra,
          {:ok, na_origem} <- [contar_pela_conexao(acesso, repo, numero)],
          no_banco = contar_no_banco(tenant, repo, numero),
          na_origem > no_banco do
        %{issue: numero, na_origem: na_origem, no_banco: no_banco}
      end

    %{
      estado
      | conferidas: length(amostra),
        divergentes: divergentes,
        veredito: if(divergentes == [], do: :completa, else: :incompleta)
    }
  end

  defp conceito(tipo)
       when tipo in ~w(AssignedEvent UnassignedEvent ClosedEvent ReopenedEvent
                       ProjectV2ItemStatusChangedEvent),
       do: "spo.performed_project_activity"

  defp conceito(_), do: nil

  defp instante(nil), do: nil

  defp instante(texto) do
    case DateTime.from_iso8601(texto) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  # ------------------------------------------------------- acesso à origem

  # A busca por `issue(number:)` em lotes — o caminho que NÃO corta.
  defp buscar_timelines({instance_url, token}, repo, numeros) do
    [owner, name] = String.split(repo.qualified_name, "/", parts: 2)

    corpo =
      Enum.map_join(numeros, " ", fn n ->
        "n#{n}: issue(number: #{n}) { number timelineItems(first: 100, itemTypes: [#{Enum.join(@tipos, ", ")}]) " <>
          "{ totalCount nodes { __typename ... on AssignedEvent { id createdAt actor { login } } " <>
          "... on UnassignedEvent { id createdAt actor { login } } ... on ClosedEvent { id createdAt actor { login } } " <>
          "... on ReopenedEvent { id createdAt actor { login } } ... on LabeledEvent { id createdAt actor { login } label { name } } " <>
          "... on UnlabeledEvent { id createdAt actor { login } label { name } } " <>
          "... on ProjectV2ItemStatusChangedEvent { id createdAt actor { login } previousStatus status project { id number title } } " <>
          "... on AddedToProjectV2Event { id createdAt actor { login } } " <>
          "... on CrossReferencedEvent { id createdAt actor { login } } " <>
          "... on SubIssueAddedEvent { id createdAt actor { login } } " <>
          "... on ParentIssueAddedEvent { id createdAt actor { login } } " <>
          "... on IssueTypeAddedEvent { id createdAt actor { login } } } } }"
      end)

    consulta =
      "query { rateLimit { cost } repository(owner: \"#{owner}\", name: \"#{name}\") { #{corpo} } }"

    case Client.graphql(instance_url, token, consulta, %{}) do
      {:ok, %{data: data}} ->
        issues =
          for {_alias, v} <-
                Map.get(data["repository"] || %{}, "issue", data["repository"] || %{}),
              is_map(v),
              v["number"] do
            {v["number"], get_in(v, ["timelineItems", "nodes"]) || []}
          end

        {:ok, issues, get_in(data, ["rateLimit", "cost"]) || 0}

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  # A conferência: pela CONEXÃO, que é o outro caminho.
  defp contar_pela_conexao({instance_url, token}, repo, numero) do
    [owner, name] = String.split(repo.qualified_name, "/", parts: 2)

    consulta =
      ~s|query { repository(owner: "#{owner}", name: "#{name}") { issue(number: #{numero}) | <>
        ~s|{ timelineItems(first: 100, itemTypes: [#{Enum.join(@tipos, ", ")}]) { totalCount } } } }|

    case Client.graphql(instance_url, token, consulta, %{}) do
      {:ok, %{data: data}} ->
        {:ok, get_in(data, ["repository", "issue", "timelineItems", "totalCount"]) || 0}

      _ ->
        :erro
    end
  end

  # ------------------------------------------------------------ banco

  defp carregar_repositorio(%Tenant{id: tenant_id}, observado_id) do
    Repo.one(
      from(o in "observed_repositories",
        join: s in "cmpo_source_repositories",
        on: s.id == o.source_repository_id,
        where:
          o.tenant_id == type(^tenant_id, :binary_id) and o.id == type(^observado_id, :binary_id),
        select: %{id: o.id, qualified_name: s.qualified_name}
      )
    )
    |> case do
      nil -> {:error, :repositorio_nao_observado}
      # Consulta sem schema devolve uuid binário; tudo que sai daqui viaja como texto.
      repo -> {:ok, %{repo | id: Ecto.UUID.cast!(repo.id)}}
    end
  end

  defp numeros_de_issue(%Tenant{id: tenant_id}, observado_id, desde) do
    Repo.all(
      from(ci in "collected_issues",
        where:
          ci.tenant_id == type(^tenant_id, :binary_id) and
            ci.observed_repository_id == type(^observado_id, :binary_id) and
            ci.number >= ^desde,
        order_by: [asc: ci.number],
        select: ci.number
      )
    )
  end

  defp issue_por_numero(%Tenant{id: tenant_id}, observado_id, numero) do
    Repo.one(
      from(ci in "collected_issues",
        where:
          ci.tenant_id == type(^tenant_id, :binary_id) and
            ci.observed_repository_id == type(^observado_id, :binary_id) and
            ci.number == ^numero,
        select: %{id: ci.id, number: ci.number}
      )
    )
    |> case do
      nil -> nil
      issue -> %{issue | id: Ecto.UUID.cast!(issue.id)}
    end
  end

  defp contar_no_banco(%Tenant{id: tenant_id}, repo, numero) do
    Repo.one(
      from(a in "spo_performed_project_activities",
        join: ci in "collected_issues",
        on: ci.id == a.subject_id,
        where:
          a.tenant_id == type(^tenant_id, :binary_id) and
            ci.observed_repository_id == type(^repo.id, :binary_id) and ci.number == ^numero,
        select: count(a.id)
      )
    ) || 0
  end

  defp pessoas_por_login(%Tenant{id: tenant_id}) do
    Repo.all(
      from(p in "eo_people",
        where: p.tenant_id == type(^tenant_id, :binary_id) and not is_nil(p.login),
        select: {p.login, p.id}
      )
    )
    # Consulta sem schema devolve o uuid em binário cru; o changeset espera o texto. Sem o
    # `cast!`, a gravação levanta — e foi o que aconteceu na primeira execução real.
    |> Map.new(fn {login, id} -> {login, Ecto.UUID.cast!(id)} end)
  end

  # A ferramenta conectada e a credencial ativa — o mesmo caminho do job de sincronização.
  # A recoleta é ato de operação e **não recebe segredo por parâmetro**: ela pede à mesma
  # porta que a coleta pede, e o segredo é decifrado ali, nunca aqui.
  defp acesso(%Tenant{} = tenant) do
    with {:ok, tool} <- ferramenta(tenant),
         %{} = credencial <- Sources.active_credential(tool),
         {:ok, token} <- Sources.fetch_secret(credencial) do
      {:ok, tool.instance_url, token}
    else
      nil -> {:error, :sem_credencial_ativa}
      {:error, :unreadable} -> {:error, :credencial_ilegivel}
      outro -> outro
    end
  end

  defp ferramenta(%Tenant{} = tenant) do
    case Sources.list_connected_tools(tenant) do
      [] -> {:error, :sem_ferramenta_conectada}
      ferramentas -> {:ok, Enum.find(ferramentas, hd(ferramentas), &(&1.tool_type == "github"))}
    end
  end
end
