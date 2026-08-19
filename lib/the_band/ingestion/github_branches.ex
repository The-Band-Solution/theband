defmodule TheBand.Ingestion.GithubBranches do
  @moduledoc """
  Coleta as linhas de desenvolvimento — feature 039, `cmpo.branch`, issue #440.

  Instancia pelo mapeamento `github.ref.to.cmpo.branch`, que estava escrito desde a versão 1
  e nunca havia sido coletado.

  ## Não é incremental, e a razão é o que a coleta mede

  Toda a outra coleta desta plataforma é incremental. Esta **não pode ser**: a pergunta é
  "que branches existem agora", e a resposta exige ver o conjunto inteiro para saber o que
  **deixou** de existir. Um filtro por data traria só as novas, e branch apagada nunca seria
  marcada.

  O custo é baixo e medido: os repositórios do piloto têm 6, 63 e 47 branches, e cabem numa
  página de 100.

  ## O que a coleta acrescenta ao que já se sabia

  As solicitações coletadas já mencionam **2.461 branches de origem** como texto. Mas branch
  mergeada é apagada, então esse é o histórico — e a API dá o **presente**. É a diferença
  entre "por onde a mudança passou" e "que linha está aberta agora, e há quanto tempo
  ninguém a toca".
  """

  require Logger

  # O atributo precisa ser registrado, ou o compilador o trata como esquecido e reprova em
  # `--warnings-as-errors`.
  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  alias TheBand.Configuration.Commands
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Repo

  import Ecto.Query

  @por_pagina 100

  @doc """
  Coleta as branches, repositório a repositório. Mesmo `ctx` das demais fases.

  Nunca devolve erro: falha num repositório vira `unreachable` no resumo e log — os demais
  seguem, e a próxima coleta tenta de novo (L29).
  """
  @spec collect(map()) :: {:ok, map()}
  def collect(ctx) do
    repositorios = repositorios_observados(ctx.tenant.id)
    resultados = Enum.map(repositorios, &coletar_repositorio(ctx, &1))

    {:ok,
     %{
       repositories: length(repositorios),
       branches: soma(resultados, :branches),
       protected: soma(resultados, :protegidas),
       # Nunca zero disfarçando "acabou": é quanto a plataforma não soube dizer se está
       # protegida, por falta de escopo de administração na credencial.
       protection_unknown: soma(resultados, :protecao_desconhecida),
       marked_unobserved: soma(resultados, :marcadas),
       truncated: soma(resultados, :truncadas),
       unreachable: Enum.count(resultados, &(&1.alcancado == false))
     }}
  end

  defp repositorios_observados(tenant_id) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where: r.tenant_id == type(^tenant_id, :binary_id) and is_nil(r.excluded_at),
        select: %{id: type(r.id, :binary_id), qualified_name: f.qualified_name}
    )
  end

  defp coletar_repositorio(ctx, repo) do
    inicio = DateTime.utc_now(:second)
    [owner, name] = String.split(repo.qualified_name, "/", parts: 2)

    case paginar(ctx, %{owner: owner, name: name}) do
      {:ok, %{nodes: nodes, total: total, padrao: padrao}} ->
        resultado = gravar(ctx, repo, nodes, padrao)
        completa? = length(nodes) >= total

        Map.merge(
          %{
            alcancado: true,
            truncadas: if(completa?, do: 0, else: 1),
            marcadas: marcar_sumidas(ctx, repo, nodes, completa?)
          },
          resultado
        )
        |> tap(fn _ -> Commands.touch_repository(repo.id, inicio, total) end)

      {:error, reason} ->
        Logger.warning("branches de #{repo.qualified_name} não coletadas: #{inspect(reason)}")

        %{
          alcancado: false,
          branches: 0,
          protegidas: 0,
          protecao_desconhecida: 0,
          marcadas: 0,
          truncadas: 0
        }
    end
  end

  # **Com página incompleta, NÃO marcar é a resposta honesta**: marcar afirmaria que a branch
  # foi apagada quando ela só ficou na página seguinte.
  defp marcar_sumidas(_ctx, _repo, _nodes, false), do: 0

  defp marcar_sumidas(ctx, repo, nodes, true) do
    Commands.mark_unobserved(ctx.tenant, repo.id, Enum.map(nodes, & &1["id"]))
  end

  defp gravar(ctx, repo, nodes, padrao) do
    Enum.reduce(
      nodes,
      %{branches: 0, protegidas: 0, protecao_desconhecida: 0},
      fn node, acc ->
        protegida = node["branchProtectionRule"]

        {:ok, _} =
          Commands.record_branch(ctx.tenant, %{
            observed_repository_id: repo.id,
            name: node["name"],
            head_sha: get_in(node, ["target", "oid"]),
            head_committed_at: data(get_in(node, ["target", "committedDate"])),
            is_default: node["name"] == padrao,
            # Nulo da origem vira `false`, e o payload preservado guarda a diferença: sem
            # escopo de administração o campo não vem, e "não sabemos" não é "não
            # protegida". O contador `protection_unknown` é o que impede a leitura errada.
            is_protected: protegida != nil,
            source_system: "github",
            source_instance: ctx.tool.instance_url,
            external_id: node["id"],
            raw_payload: node
          })

        %{
          branches: acc.branches + 1,
          protegidas: acc.protegidas + if(protegida != nil, do: 1, else: 0),
          protecao_desconhecida:
            acc.protecao_desconhecida +
              if(Map.has_key?(node, "branchProtectionRule"), do: 0, else: 1)
        }
      end
    )
  end

  defp soma(resultados, chave), do: Enum.sum(Enum.map(resultados, &Map.get(&1, chave, 0)))

  defp data(nil), do: nil

  defp data(valor) do
    case DateTime.from_iso8601(valor) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp paginar(ctx, variables, cursor \\ nil, acumulado \\ [], total \\ nil, padrao \\ nil) do
    vars = Map.merge(variables, %{page_size: @por_pagina, after: cursor})

    case Client.graphql(ctx.tool.instance_url, ctx.token, consulta(), vars) do
      # O ENVELOPE, nunca `{:ok, data}` direto — L26: casar largo devolvia lista vazia sem
      # erro, e o job completava com zero coletados.
      {:ok, %{data: data}} ->
        pagina = extrair(data, acumulado, total, padrao)

        if pagina.proxima do
          paginar(ctx, variables, pagina.proxima, pagina.nodes, pagina.total, pagina.padrao)
        else
          {:ok, Map.take(pagina, [:nodes, :total, :padrao])}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extrai a página do envelope. Separado de `paginar/6` porque a soma dos dois passava do
  # limite de complexidade — e a leitura fica melhor: uma função navega o payload, a outra
  # decide se continua.
  defp extrair(data, acumulado, total, padrao) do
    repo = data["repository"] || %{}
    refs = repo["refs"] || %{}
    nodes = refs["nodes"] || []
    info = refs["pageInfo"] || %{}

    %{
      nodes: acumulado ++ nodes,
      total: total || refs["totalCount"] || 0,
      padrao: padrao || get_in(repo, ["defaultBranchRef", "name"]),
      proxima: if(info["hasNextPage"], do: info["endCursor"])
    }
  end

  # O caminho é literal do próprio código, e nunca entrada externa. A anotação **nomeia** o
  # achado em vez de desligar a verificação, e deixa de valer no dia em que alguém passar
  # valor vindo de fora — é a mesma postura dos outros módulos de ingestão.
  @sobelow_skip ["Traversal.FileModule"]
  defp consulta do
    Application.app_dir(:the_band, "priv/connectors/github/queries/branches.graphql")
    |> File.read!()
  end
end
