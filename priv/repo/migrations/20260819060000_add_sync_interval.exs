defmodule TheBand.Repo.Migrations.AddSyncInterval do
  @moduledoc """
  O intervalo de sincronização automática, escolhido por quem administra — issue #443.

  ## Por que a coluna, e não uma entrada no cron

  A sincronização **nunca foi agendada**: o `crontab` tem o reconciliador e a rodada mensal
  de perfis, e nada mais. O único disparo era o botão na tela.

  Isso é metade do defeito que a issue #443 descreve. A outra metade é que, sem
  periodicidade, **ninguém esperava** que houvesse coleta — e a ausência de coleta ficava
  indistinguível de "ninguém clicou". Medido em 2026-08-19: os dois maiores tenants estavam
  há **cinco dias** sem nenhuma coleta completa, e nada avisou.

  Uma entrada fixa no `crontab` não resolveria, por três razões:

    * o intervalo é **decisão de quem administra o tenant**, e cada organização tem volume
      diferente — 160 repositórios não se coletam no mesmo ritmo que 5;
    * `crontab` é configuração de aplicação: mudá-la exige implantar, e a pessoa que decide o
      ritmo não é a que implanta;
    * uma entrada por ferramenta cresceria com o número de tenants, e o arquivo de
      configuração passaria a ser dado.

  O intervalo mora aqui, e um trabalho periódico olha **estado** para decidir quem está
  vencido. É o mesmo padrão de `ReconcileStuckSyncs`, cujo moduledoc explica a razão: estado
  sobrevive a reinício da aplicação e a nó que morre sem avisar; evento não.

  ## Nulo é manual, e é o padrão

  Ferramenta sem intervalo **não** é sincronizada automaticamente. Escolher um padrão
  diferente de nulo ligaria coleta automática em toda ferramenta já cadastrada, sem que
  ninguém tivesse pedido — e a primeira surpresa seria a janela de rate limit.
  """
  use Ecto.Migration

  def change do
    alter table(:connected_tools) do
      # Em minutos, e nulo significa **manual**. Minutos e não um enum de rótulos porque a
      # tela oferece opções e o dado guarda o número: acrescentar "a cada 2 horas" depois não
      # deve exigir migração.
      add :sync_interval_minutes, :integer
    end

    # A pergunta do agendador é "quem tem intervalo e está vencido", e ela filtra por esta
    # coluna antes de olhar `last_sync_at`. Índice parcial porque a maioria das ferramentas
    # fica em manual, e indexar nulo não serve a ninguém.
    create index(:connected_tools, [:sync_interval_minutes],
             where: "sync_interval_minutes IS NOT NULL",
             name: :connected_tools_auto_sync_index
           )
  end
end
