defmodule TheBand.Release do
  @moduledoc """
  Tarefas que rodam **dentro do release**, onde `mix` não existe.

  ## Por que isto existe

  Num release não há `Mix`, e `mix ecto.migrate` não é uma opção. Sem este módulo o
  primeiro boot em produção subiria com o banco vazio — e a plataforma não falharia:
  ela mostraria zero em toda tela, que é indistinguível de "ainda não coletamos nada".

  É a mesma classe do defeito que este projeto persegue em toda parte: **ausência
  silenciosa lida como resultado.**

  ## A migração roda ANTES do supervisor

  Chamada pelo `entrypoint` do contêiner, e não por um processo dentro da árvore. Uma
  migração que roda em paralelo com a aplicação já servindo deixa uma janela em que
  requisições veem o esquema pela metade.

  ## `load` e não `start`

  `Application.load/1` traz a configuração sem subir supervisor nenhum: a migração
  precisa do `Repo`, e não do endpoint HTTP nem dos coletores. Subir a aplicação
  inteira para migrar faria os workers do Oban começarem a puxar trabalho contra um
  esquema em movimento.
  """

  @app :the_band

  @doc "Aplica todas as migrações pendentes. Chamado pelo entrypoint, antes do boot."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Desfaz até a versão dada. **Não é chamado automaticamente em lugar nenhum.**

  Reverter migração apaga coluna, e apagar coluna apaga dado. Fica aqui para existir
  o caminho, e fora do entrypoint para exigir a decisão de quem digitar.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # `:ssl` explícito: o release não sobe a árvore da aplicação, e a conexão com um
    # Postgres gerenciado costuma exigir TLS. Sem isto o erro é de conexão, e não de
    # dependência — e leva a procurar no lugar errado.
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
