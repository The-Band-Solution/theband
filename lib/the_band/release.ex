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

  alias TheBand.Tenants.Bootstrap

  @app :the_band

  @doc "Aplica todas as migrações pendentes. Chamado pelo entrypoint, antes do boot."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Cria a organização e o primeiro administrador a partir do ambiente — feature 052.

  Chamada pelo entrypoint, DEPOIS de `migrate/0`. A decisão inteira vive em
  `TheBand.Tenants.Bootstrap`; aqui só se traduz o relator em frase.

  **Nunca sai diferente de zero.** O `set -e` do entrypoint derruba o contêiner em
  qualquer passo que falhe, e a ausência das variáveis é caso previsto: derrubar
  por variável esquecida transformaria um esquecimento em produção fora do ar.

  É o contraste deliberado com `DATABASE_URL`, cuja ausência DERRUBA. Sem banco,
  subir significaria servir zero em toda tela — indistinguível de "ainda não
  coletamos nada". Sem primeira conta, a plataforma está correta e apenas vazia.
  """
  def semear_primeira_conta do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _ ->
          Bootstrap.criar_primeira_conta() |> dizer()
        end)
    end

    :ok
  end

  defp dizer({:ok, :criada, %{email: email, slug: slug}}),
    do: IO.puts("primeira conta criada: #{email}, admin de #{slug}.")

  defp dizer({:ok, :ja_existe}), do: IO.puts("já existe administrador — nada a criar.")

  defp dizer({:error, {:faltando, variaveis}}) do
    nomes = Enum.map_join(variaveis, ", ", &nome_da_variavel/1)
    IO.puts("sem #{nomes} — nenhuma conta criada. A plataforma sobe vazia.")
  end

  defp dizer({:error, %Ecto.Changeset{} = changeset}) do
    motivos =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
      |> Enum.map_join("; ", fn {campo, msgs} -> "#{campo} #{Enum.join(msgs, ", ")}" end)

    IO.puts("primeira conta recusada: #{motivos}. A plataforma sobe vazia.")
  end

  defp nome_da_variavel(:nome), do: "THE_BAND_TENANT_NOME"
  defp nome_da_variavel(:slug), do: "THE_BAND_TENANT_SLUG"
  defp nome_da_variavel(:email), do: "THE_BAND_ADMIN_EMAIL"
  defp nome_da_variavel(:senha), do: "THE_BAND_ADMIN_SENHA"

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
