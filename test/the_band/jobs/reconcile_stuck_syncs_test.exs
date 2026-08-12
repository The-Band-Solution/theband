defmodule TheBand.Jobs.ReconcileStuckSyncsTest do
  @moduledoc """
  O gatilho periódico (T007), e a configuração que o sustenta.

  Os testes de configuração existem porque **presumir configuração já custou caro**: um worker
  declarado numa fila `:sync` inexistente ficou `available` para sempre, e ninguém viu.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ingestion
  alias TheBand.Ingestion.Sync
  alias TheBand.Jobs.ReconcileStuckSyncs
  alias TheBand.Sources.ConnectedTool

  describe "o worker" do
    setup do
      tenant = tenant_fixture()

      {:ok, tool} =
        %ConnectedTool{}
        |> ConnectedTool.changeset(%{
          tenant_id: tenant.id,
          tool_type: "github",
          instance_url: "https://github.com",
          organization_login: "acme"
        })
        |> Repo.insert()

      %{tenant: tenant, tool: tool}
    end

    test "encerra a execução presa sem ninguém abrir a tela", ctx do
      {:ok, sync} =
        %Sync{}
        |> Sync.changeset(%{
          tenant_id: ctx.tenant.id,
          connected_tool_id: ctx.tool.id,
          status: "running",
          started_at: DateTime.add(DateTime.utc_now(:second), -600, :second)
        })
        |> Repo.insert()

      assert :ok = ReconcileStuckSyncs.perform(%Oban.Job{args: %{}})

      assert Ingestion.reload(sync).status == "interrupted", """
      É o SC-002: o bloqueio precisa sair sem depender de alguém abrir a interface. Uma
      verificação que só roda ao carregar a tela deixa a ferramenta bloqueada até alguém
      olhar.
      """
    end

    test "não levanta quando não há nada preso", _ctx do
      assert :ok = ReconcileStuckSyncs.perform(%Oban.Job{args: %{}})
    end
  end

  describe "a configuração" do
    test "o worker está numa fila configurada" do
      filas = Keyword.keys(Application.get_env(:the_band, Oban)[:queues])

      assert ReconcileStuckSyncs.__opts__()[:queue] in filas, """
      O worker está na fila #{inspect(ReconcileStuckSyncs.__opts__()[:queue])}, e as filas
      configuradas são #{inspect(filas)}.

      Declarar worker em fila não configurada deixa o job `available` para sempre — sem erro,
      sem log, sem execução. Já aconteceu neste projeto com uma fila `:sync` inexistente.
      """
    end

    test "o Cron agenda a reconciliação" do
      plugins = Application.get_env(:the_band, Oban)[:plugins]

      crontab =
        Enum.find_value(plugins, fn
          {Oban.Plugins.Cron, opts} -> opts[:crontab]
          _ -> nil
        end)

      assert crontab,
             "o Oban.Plugins.Cron não está configurado, e sem ele nada roda periodicamente"

      assert Enum.any?(crontab, fn {_expr, worker} -> worker == ReconcileStuckSyncs end), """
      A reconciliação não está no crontab: #{inspect(crontab)}.

      Sem agendamento, a decisão existe e nunca é chamada — e o bloqueio só sai quando alguém
      abre a tela.
      """
    end

    test "o Lifeline NÃO está nos plugins" do
      plugins = Application.get_env(:the_band, Oban)[:plugins]

      nomes =
        Enum.map(plugins, fn
          {mod, _opts} -> mod
          mod -> mod
        end)

      refute Oban.Plugins.Lifeline in nomes, """
      `Oban.Plugins.Lifeline` voltou à configuração.

      O resgate dele é `state == "executing" and attempted_at < cut`, **sem nenhuma
      verificação de processo vivo** — lido em deps/oban/lib/oban/engines/basic.ex:189. O
      `rescue_after` é uma constante que envelhece com o crescimento da coleta: a mais longa
      medida leva 16 min 25 s e cresce com o número de repositórios.

      No dia em que a coleta passar do valor, o plugin resgata coleta VIVA e ela roda duas
      vezes. É a L02, onde 32 registros apareceram no lugar de 16 e o número pareceu correto.

      Trabalho órfão é ENCERRADO pela reconciliação, e a coleta nova recoleta sem duplicar
      linha. Se alguém quiser retomar em vez de recoletar, o caminho é proteger o resgate com
      claim do sync — desenho novo, declarado como recusado em research.md R1.
      """
    end
  end
end
