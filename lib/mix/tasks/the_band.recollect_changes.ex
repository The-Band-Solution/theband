defmodule Mix.Tasks.TheBand.RecollectChanges do
  @shortdoc "Invalida o corte incremental dos repositórios que perderam um campo novo"
  @moduledoc """
  Reabre a coleta de solicitações de mudança nos repositórios cujos PRs não têm o
  `statusCheckRollup` medido.

  ## O problema que ela resolve, e por que ele volta

  `GithubChangeRequests.collect/1` é incremental: para de paginar quando alcança
  `observed_repositories.changes_collected_at`. Isso é certo para dado que não muda.

  **Mas quando a consulta ganha um campo, o corte passa a excluir para sempre os
  registros antigos.** A feature 041 acrescentou `statusCheckRollup` à consulta, e os
  PRs coletados antes dela nunca voltam a ser visitados — não porque falharam, mas
  porque a plataforma já os considera coletados.

  Medido em 2026-08-19: **763 solicitações integradas em 10 repositórios**, e em cada um
  desses dez a fração era 100%. A assinatura é essa: repositório inteiro sem o campo é
  repositório que não foi tocado desde que o campo existe. Repositório com fração parcial
  seria outro problema.

  ## Por que zerar o corte, e não escrever consulta nova

  Zerar `changes_collected_at` faz a fase existente recoletar o repositório inteiro, com
  a paginação, o tratamento de truncamento e a gravação que já são testados. Uma consulta
  de backfill por número de PR seria mais econômica em requisições e seria **código novo
  no caminho de gravação** — o lugar onde erro custa mais. Lição L65: coleta que a rede
  já especificou custa a fração de uma que não.

  Como nesses dez repositórios a fração é 100%, a recoleta não desperdiça nada: não há
  PR já medido para revisitar.

  ## Ela reabre, e NÃO enfileira

  A task não fala com a origem e não dispara coleta. Zera o corte e diz o próximo passo.

  A primeira versão enfileirava, e para não consumir o próprio job pausava as filas com
  `Oban.pause_all_queues(local_only: true)`. **Isso pausou o servidor.**

  `Config.to_ident/1` é `inspect(name) <> "." <> to_string(node)`, e o sinal de pausa casa
  por essa identidade. O nó de um `mix` e o nó de um `mix phx.server` são **os dois**
  `nonode@nohost` quando ninguém passa `--sname`. Mesma identidade, mesmo sinal: `local_only`
  não isola nada aqui.

  E falha em silêncio. O servidor simplesmente para de consumir; nenhum log, nenhum erro. Os
  dois jobs ficaram `available` com `attempt: 0` por 23 minutos, e só voltaram com
  `resume_all_queues/0`.

  Sem pausa, a alternativa seria o nó da task pegar o job e morrer no meio — deixando
  `executing` órfão para sempre, porque esta base recusa o plugin `Lifeline` por decisão
  medida (`specs/008-destravar-sync-presa/research.md` R1). Não enfileirar remove as duas
  armadilhas: não há job para pegar, e não há fila para pausar.

  O custo é um passo manual, e ele é honesto: as duas ferramentas afetadas têm sync
  automático **desligado**, então nem o agendador periódico as pegaria. Alguém precisa
  decidir coletar de todo modo.

  ## Uso

      mix the_band.recollect_changes            # mostra o que faria, e não faz
      mix the_band.recollect_changes --apply    # zera o corte

  Sem `--apply` ela é somente leitura. Uma task que reabre coleta de 763 solicitações
  não deve ter o efeito como padrão.
  """
  use Mix.Task

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Tenants

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean])
    aplicar? = Keyword.get(opts, :apply, false)

    case pendentes() do
      [] ->
        Mix.shell().info("Nenhum repositório com solicitação integrada sem medir.")

      linhas ->
        relatar(linhas)
        if aplicar?, do: aplicar(linhas), else: avisar_simulacao()
    end
  end

  # A consulta que define "pendente": solicitação integrada e observada cujo
  # `merged_check_contexts` é nulo. **Nulo, e não zero** — zero com estado nulo significa
  # que nenhum check rodou, que é achado sobre o processo e não lacuna de coleta.
  defp pendentes do
    Repo.all(
      from c in "collected_change_requests",
        join: r in "observed_repositories",
        on: r.id == c.observed_repository_id,
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where:
          c.state == "MERGED" and is_nil(c.no_longer_observed_at) and
            is_nil(c.merged_check_contexts) and is_nil(r.excluded_at),
        group_by: [r.id, r.tenant_id, r.connected_tool_id, f.qualified_name],
        select: %{
          repositorio_id: type(r.id, :binary_id),
          tenant_id: type(r.tenant_id, :binary_id),
          tool_id: type(r.connected_tool_id, :binary_id),
          nome: f.qualified_name,
          sem_medir: count(c.id)
        },
        order_by: [desc: count(c.id)]
    )
  end

  defp relatar(linhas) do
    total = Enum.sum(Enum.map(linhas, & &1.sem_medir))

    Mix.shell().info("""
    #{total} solicitações integradas sem `statusCheckRollup` medido, em #{length(linhas)} repositórios:
    """)

    Enum.each(linhas, fn l -> Mix.shell().info("  #{l.sem_medir}\t#{l.nome}") end)
  end

  defp avisar_simulacao do
    Mix.shell().info("""

    Simulação. Nada foi alterado.

    Com `--apply`, o corte incremental desses repositórios é zerado e a sincronização de
    cada ferramenta afetada é enfileirada. A coleta acontece no job, com retentativa e
    pausa por limite de API.
    """)
  end

  defp aplicar(linhas) do
    ids = Enum.map(linhas, & &1.repositorio_id)

    # `type/2` no array, e não `in ^ids`: em consulta schemaless o Ecto não sabe que a
    # coluna é `binary_id`, e manda a string de 36 caracteres para uma coluna de 16 bytes.
    {zerados, _} =
      Repo.update_all(
        from(r in "observed_repositories",
          where: r.id in type(^ids, {:array, :binary_id})
        ),
        set: [changes_collected_at: nil]
      )

    Mix.shell().info("\nCorte zerado em #{zerados} repositórios.")
    instruir(linhas)
  end

  # **Não enfileira.** O motivo está no `@moduledoc`, e é o `nonode@nohost` compartilhado.
  # O que ela faz é dizer o próximo passo, por ferramenta, com o que a ferramenta já decidiu
  # sobre coleta automática.
  defp instruir(linhas) do
    Mix.shell().info("\nO que falta, por ferramenta:\n")

    linhas
    |> Enum.uniq_by(&{&1.tenant_id, &1.tool_id})
    |> Enum.each(&passo_da_ferramenta/1)

    Mix.shell().info("""

    A coleta acontece no job, que é onde há retentativa, pausa por limite de API e registro
    de progresso. Acompanhe em /syncs.
    """)
  end

  defp passo_da_ferramenta(%{tenant_id: tenant_id, tool_id: tool_id, nome: nome}) do
    with {:ok, tenant} <- Tenants.fetch(tenant_id),
         {:ok, tool} <- Sources.fetch_connected_tool(tenant, tool_id) do
      Mix.shell().info("  #{tool.organization_login}: #{frase_da_ferramenta(tool)}")
    else
      erro -> Mix.shell().error("  ferramenta de #{nome} não resolvida: #{inspect(erro)}")
    end
  end

  # Intervalo nulo é coleta automática **desligada**, e não intervalo zero. Dizer "o
  # agendador vai pegar" nesse caso faria alguém esperar por algo que nunca acontece.
  defp frase_da_ferramenta(%{sync_interval_minutes: nil}),
    do: "sync automático desligado — precisa de Sync na tela /syncs"

  defp frase_da_ferramenta(%{sync_interval_minutes: minutos}),
    do: "o agendador periódico pega em até #{minutos} min, ou use Sync em /syncs"
end
