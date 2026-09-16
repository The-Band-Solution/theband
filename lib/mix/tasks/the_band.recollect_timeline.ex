defmodule Mix.Tasks.TheBand.RecollectTimeline do
  @shortdoc "Recolhe a timeline das issues que a origem cortou em silêncio"
  @moduledoc """
  Percorre **todas** as issues de um repositório observado e relê a timeline de cada uma
  pelo caminho que não corta.

  ## O corte, e por que ele não deixou marca

  Dentro de `issues(first: 50)` o GitHub devolve só parte da timeline de cada issue e
  **declara `totalCount` igual ao que cortou**, com `hasNextPage: false`. A guarda que
  existia olhava `hasNextPage`, e por isso nunca disparou.

  Reproduzido em 2026-09-15 na issue #1828 do `conectafapes-project`, que tem 14 itens:
  pedindo 50 issues por página a origem declara 12; pedindo 25, declara 13; pedindo 10,
  devolve os 14. O corte é proporcional aos nós pedidos, e não um teto fixo.

  As próximas coletas já vão de 10 em 10. Esta task trata do que ficou no banco.

  ## Por que percorre tudo, e não só o que parece faltar

  O corte não deixou marca. Contar eventos por issue não separa truncada de inteira: a
  distribuição foi medida sobre as 4 923 issues com evento e desce sem degrau algum do
  pico em 6 e 7 até a cauda. Não há como saber quais issues perderam evento sem perguntar
  por todas.

  O que a listagem sem argumento mostra não é um palpite, é uma contagem: quantas issues
  ainda não têm nenhuma atividade com identificador da origem, ou seja, não foram
  visitadas desde 2026-09-15.

  ## Ela não apaga, e pode ser repetida

  Cada evento é gravado pelo critério de identidade que já existe. O que já estava
  continua; o que faltava entra; a linha gravada antes de 2026-09-15 recebe o
  identificador que a origem sempre deu, em vez de virar duplicata — ver
  `TheBand.Ontology.SEON.SPO.Commands.record_activity/2`.

  ## O relatório não termina em "pronto"

  Ele diz quantas issues continuam com a resposta no teto **depois** da recoleta, e
  quais limites não foram vencidos. Um número que não chega a zero é informação, e o
  veredito `incompleta` devolve código de saída diferente de zero.

  ## Uso

      mix the_band.recollect_timeline                        # o que falta, por repositório
      mix the_band.recollect_timeline leds-x/projeto         # o que faria, e não faz
      mix the_band.recollect_timeline leds-x/projeto --apply # recolhe
      mix the_band.recollect_timeline leds-x/projeto --apply --desde 2607

  Sem `--apply` ela não fala com a origem. Uma task que relê milhares de issues não deve
  ter o efeito como padrão.

  `--desde` retoma de um número de issue — é o que o relatório imprime quando a cota
  acaba no meio.
  """
  use Mix.Task

  import Ecto.Query

  alias TheBand.Ingestion.TimelineRecollection
  alias TheBand.Repo
  alias TheBand.Tenants

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, nomes, _} = OptionParser.parse(args, strict: [apply: :boolean, desde: :integer])

    case nomes do
      [] -> listar()
      [nome] -> um_repositorio(nome, opts)
      muitos -> Mix.raise("Um repositório por vez. Recebi #{length(muitos)}.")
    end
  end

  # ------------------------------------------------------------------ o estrago

  defp listar do
    Enum.each(Tenants.list_tenants(), fn tenant ->
      case TimelineRecollection.pendentes_de_recoleta(tenant) do
        [] ->
          Mix.shell().info("#{tenant.name}: todas as issues já foram relidas.")

        linhas ->
          Mix.shell().info("\n#{tenant.name} — issues ainda não relidas, por repositório:\n")
          Enum.each(linhas, &linha_do_estrago/1)
          Mix.shell().info("\n  #{hd(linhas).ressalva}")
      end
    end)

    Mix.shell().info("""

    Para recolher um deles:

        mix the_band.recollect_timeline <repositório> --apply
    """)
  end

  defp linha_do_estrago(l) do
    Mix.shell().info(
      "  #{String.pad_leading(to_string(l.pendentes), 5)} de #{String.pad_leading(to_string(l.issues), 5)}\t#{l.repositorio}"
    )
  end

  # ------------------------------------------------------------------ a recoleta

  defp um_repositorio(nome, opts) do
    {tenant, repo_id, issues} = resolver!(nome)

    if Keyword.get(opts, :apply, false) do
      recolher(tenant, repo_id, nome, opts)
    else
      simular(nome, issues, opts)
    end
  end

  defp recolher(tenant, repo_id, nome, opts) do
    desde = Keyword.get(opts, :desde, 0)

    case TimelineRecollection.recolher(tenant, repo_id, desde: desde) do
      {:ok, relatorio} ->
        relatar(relatorio)
        encerrar(relatorio)

      {:error, motivo} ->
        Mix.raise("A recoleta de #{nome} não começou: #{inspect(motivo)}")
    end
  end

  # A conta é de pedidos, e não de pontos: cada lote é um pedido, e a conferência faz um
  # por issue amostrada. O custo em pontos sai medido no relatório, porque só a origem sabe.
  defp simular(nome, issues, opts) do
    desde = Keyword.get(opts, :desde, 0)
    alcancadas = if desde > 0, do: "a partir da ##{desde}", else: "todas"

    Mix.shell().info("""

    Simulação. Nada foi lido da origem, nada foi gravado.

    #{nome}: #{issues} issues coletadas, #{alcancadas} seriam percorridas em lotes de 10,
    mais 10 conferências por um caminho diferente do que a recoleta usou.

    Com `--apply`, a recoleta acontece aqui mesmo, no processo da task — e não num job.
    Se a cota acabar no meio, o relatório imprime o número de onde retomar.
    """)
  end

  defp relatar(r) do
    Mix.shell().info("""

    #{r.repositorio}

      issues percorridas ........ #{r.issues_percorridas}
      com eventos novos ......... #{r.issues_com_eventos_novos}
      eventos inseridos ......... #{r.eventos_inseridos}
      eventos promovidos ........ #{r.eventos_promovidos}
      issues não encontradas .... #{length(r.nao_encontradas)}
      issues ainda no teto ...... #{r.issues_no_teto}
      custo em pontos de cota ... #{r.custo}
      conferidas por amostra .... #{r.conferidas}
      divergentes na amostra .... #{length(r.divergentes)}
      veredito .................. #{r.veredito}
    """)

    por_mes(r.por_mes)
    divergentes(r.divergentes)
    Enum.each(r.limites, &Mix.shell().info("  · #{&1}"))
  end

  # Ausência escrita, e não silêncio: recoleta que não achou evento novo é resultado.
  defp por_mes(vazio) when map_size(vazio) == 0,
    do: Mix.shell().info("  Nenhum evento novo — nada a distribuir por mês.\n")

  defp por_mes(mapa) do
    Mix.shell().info("  Eventos novos por mês de ocorrência:\n")
    mapa |> Enum.sort() |> Enum.each(fn {mes, n} -> Mix.shell().info("    #{mes}  #{n}") end)
    Mix.shell().info("")
  end

  defp divergentes([]), do: :ok

  defp divergentes(lista) do
    Mix.shell().error("  A amostra diverge — a recoleta não trouxe tudo:\n")
    Enum.each(lista, fn d -> Mix.shell().error("    #{inspect(d)}") end)
    Mix.shell().info("")
  end

  defp encerrar(%{veredito: :completa}), do: :ok

  defp encerrar(%{veredito: :interrompida, retomar_de: numero}) do
    Mix.raise("""
    A recoleta parou antes do fim. Retome com:

        mix the_band.recollect_timeline <repositório> --apply --desde #{numero}
    """)
  end

  defp encerrar(%{veredito: :incompleta}) do
    Mix.raise("""
    A conferência por amostra divergiu do que a recoleta trouxe.

    Código de saída diferente de zero é o ponto: um relatório que termina em "incompleta"
    não deve passar por verde em pipeline nenhum.
    """)
  end

  # ------------------------------------------------------------------ resolução

  defp resolver!(nome) do
    linhas =
      Repo.all(
        from r in "observed_repositories",
          join: f in "cmpo_source_repositories",
          on: f.id == r.source_repository_id,
          left_join: i in "collected_issues",
          on: i.observed_repository_id == r.id,
          where: f.qualified_name == ^nome and is_nil(r.excluded_at),
          group_by: [r.id, r.tenant_id],
          select: %{
            repo_id: type(r.id, :binary_id),
            tenant_id: type(r.tenant_id, :binary_id),
            issues: count(i.id)
          }
      )

    case linhas do
      [] -> Mix.raise("Repositório observado não encontrado: #{nome}")
      [uma] -> {tenant!(uma.tenant_id), uma.repo_id, uma.issues}
      muitas -> Mix.raise("#{nome} está observado em #{length(muitas)} organizações.")
    end
  end

  defp tenant!(id) do
    case Tenants.fetch(id) do
      {:ok, tenant} -> tenant
      erro -> Mix.raise("Organização não resolvida: #{inspect(erro)}")
    end
  end
end
