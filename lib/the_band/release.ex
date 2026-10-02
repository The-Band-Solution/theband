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

  alias TheBand.Papeis
  alias TheBand.Tenants.Bootstrap
  alias TheBand.Tenants.Sessions

  @app :the_band

  @doc """
  Aplica todas as migrações pendentes e concede os privilégios ao papel que serve. Chamado pelo
  entrypoint, antes do boot, com o `DATABASE_URL` **da credencial que migra** naquela linha só
  (spec 071, FR-004 e FR-005).

  O papel que serve é o usuário de `THE_BAND_URL_QUE_SERVE`, que o entrypoint passa junto. Sem ela
  (o entrypoint antigo, ou um `eval` à mão), a concessão é pulada, e a linha diz isso.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      com_url_redigida(fn ->
        {:ok, linha, _} = Ecto.Migrator.with_repo(repo, &migrar_e_conceder/1)
        IO.puts(linha)
      end)
    end
  end

  defp migrar_e_conceder(repo) do
    Ecto.Migrator.run(repo, :up, all: true)
    conceder_a_quem_serve(repo, System.get_env("THE_BAND_URL_QUE_SERVE"))
  end

  defp conceder_a_quem_serve(_repo, nil),
    do: "papéis: THE_BAND_URL_QUE_SERVE ausente, concessão pulada"

  defp conceder_a_quem_serve(repo, url) do
    case URI.parse(url).userinfo do
      nil ->
        "papéis: a URL de quem serve não traz usuário, concessão pulada"

      userinfo ->
        papel = userinfo |> String.split(":", parts: 2) |> hd() |> URI.decode()
        :ok = Papeis.conceder(repo, papel)
        "papéis: privilégios de quem serve concedidos"
    end
  end

  @doc """
  O deploy sem a credencial que migra: os três estados de `TheBand.Papeis.estado_sem_credencial/1`
  (spec 071, FR-008). Imprime a linha do relator, e levanta **só** quando há migração pendente e
  quem serve não consegue migrar, para o `set -e` do entrypoint não deixar servir sobre esquema
  pela metade.
  """
  def migrar_sem_credencial do
    load_app()

    for repo <- repos() do
      com_url_redigida(fn ->
        {:ok, linha, _} = Ecto.Migrator.with_repo(repo, &sem_credencial/1)
        IO.puts(linha)
      end)
    end
  end

  defp sem_credencial(repo) do
    case Papeis.estado_sem_credencial(repo) do
      :migra_como_hoje ->
        Ecto.Migrator.run(repo, :up, all: true)

        "papéis: separação NÃO em vigor (credencial_que_migra_ausente); migrado com a credencial que serve"

      :sobe_sem_migrar ->
        Papeis.frase(Papeis.conferir(repo)) <> "; DATABASE_MIGRATION_URL ausente, nada a migrar"

      {:nao_sobe, pendentes} ->
        raise "papéis: #{length(pendentes)} migração(ões) pendente(s) e DATABASE_MIGRATION_URL " <>
                "ausente; configure-a no painel (runbook §14) e reimplante"
    end
  end

  @doc """
  A conferência dos papéis, por `rpc`, dentro do nó que serve (spec 071, FR-009):

      /app/bin/the_band rpc 'IO.puts(TheBand.Release.conferir_papeis())'

  Por `eval` ela mediria o papel daquela VM, e não o do processo que serve.
  """
  def conferir_papeis, do: Papeis.frase(Papeis.conferir(TheBand.Repo))

  @doc false
  # S6 de `specs/071-papeis-do-banco/seguranca.md`: `Ecto.InvalidURLError` imprime a URL, com a
  # senha, quando ela tem caractere reservado. A frase nomeia a variável, e nunca o valor.
  def com_url_redigida(fun) do
    fun.()
  rescue
    Ecto.InvalidURLError ->
      reraise RuntimeError,
              [
                message:
                  "URL de banco malformada: confira DATABASE_URL ou DATABASE_MIGRATION_URL " <>
                    "(senha só com 0-9a-f, gerada por openssl rand -hex 32)"
              ],
              []
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
  **Encerra a sessão de todo mundo, em todas as organizações** — feature 064, T016.

      /app/bin/the_band eval 'TheBand.Release.encerrar_todas_as_sessoes()'

  Todas as pessoas, inclusive quem roda o comando, precisam entrar de novo. Os casos, e o
  procedimento, estão em `docs/producao/runbook.md` §10. Depois de restaurar um backup, este
  passo é **obrigatório** (decisão P5): a restauração devolve as sessões encerradas depois da
  cópia, e as encerradas por segurança estão entre elas.

  Escreve `ended_at` e não apaga nada. Diz quantas encerrou, e só o número: nem conta, nem
  token.
  """
  def encerrar_todas_as_sessoes do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _ ->
          {:ok, n} = Sessions.girar_todas()
          IO.puts("#{n} sessão(ões) encerrada(s). Todas as pessoas precisam entrar de novo.")

          # O aviso às telas abertas não sai desta VM (#1050). Com a aplicação no ar, o caminho
          # é `girar_sessoes/0` por `rpc`; este é o da aplicação parada, depois de restaurar.
          IO.puts(
            "Se a aplicação está no ar, as telas abertas não caem por este caminho. " <>
              "Use: /app/bin/the_band rpc 'IO.puts(TheBand.Release.girar_sessoes())'"
          )
        end)
    end

    :ok
  end

  @doc """
  **Encerra a sessão de todo mundo, e derruba as telas abertas** — issue #1050.

      /app/bin/the_band rpc 'IO.puts(TheBand.Release.girar_sessoes())'

  Roda por `rpc`, **dentro do nó que está servindo**, como `saude_da_fila/0`. É o caminho com a
  aplicação no ar: `Sessions.girar_todas/0` avisa as telas pelo PubSub do nó (#1042), e cada
  LiveView aberta reconfere a sessão e cai em `/sign-in`. Pelo `eval` de
  `encerrar_todas_as_sessoes/0`, o aviso sai em outra VM e não chega a ninguém.

  Devolve a frase com o número, e só o número.
  """
  @spec girar_sessoes() :: String.t()
  def girar_sessoes do
    {:ok, n} = Sessions.girar_todas()

    "#{n} sessão(ões) encerrada(s), e as telas abertas foram avisadas. " <>
      "Todas as pessoas precisam entrar de novo."
  end

  @doc """
  A saúde da fila, para o healthcheck do contêiner — issue #801.

      /app/bin/the_band rpc 'IO.puts(TheBand.Release.saude_da_fila())'

  Roda por `rpc`, **dentro do nó que está servindo**, e por isso não carrega a aplicação nem
  abre `Repo` próprio: usa os que já estão no ar. Devolve `"ok"` ou `"parada"`, e **nunca**
  derruba o nó: quem decide é o `grep` do `HEALTHCHECK`, do lado de fora. Uma função chamada
  por `rpc` que parasse o nó transformaria o verificador num defeito.
  """
  @spec saude_da_fila() :: String.t()
  def saude_da_fila do
    case TheBand.Saude.fila() do
      :ok -> "ok"
      {:parada, _minutos} -> "parada"
    end
  end

  @doc """
  **Recifra todos os campos cifrados com a chave mestra nova** — issue #1052.

      /app/bin/the_band rpc 'IO.puts(TheBand.Release.rotacionar_chave())'

  A release não tem `mix`, e `mix the_band.rotate_key` não existe em produção. Roda por `rpc`,
  **dentro do nó que serve**, porque o `TheBand.Vault` dele já subiu com as duas chaves do
  ambiente: a nova em `THE_BAND_MASTER_KEY` e a antiga em `THE_BAND_PREVIOUS_MASTER_KEY`. Os
  passos estão no runbook §12.

  Devolve a frase com as contagens por tabela, e nunca um valor. Com qualquer registro ilegível,
  não grava nada e diz quantos, por tabela.
  """
  @spec rotacionar_chave() :: String.t()
  def rotacionar_chave do
    case TheBand.Rotacao.recifrar(false) do
      {:ok, contagens} ->
        "recifradas: " <> por_tabela(contagens) <> ". Agora remova THE_BAND_PREVIOUS_MASTER_KEY."

      {:error, {:ilegiveis, por}} ->
        "NADA FOI GRAVADO. Ilegíveis com as chaves configuradas: " <>
          por_tabela(por) <> ". Confira THE_BAND_PREVIOUS_MASTER_KEY."
    end
  end

  defp por_tabela(contagens),
    do: Enum.map_join(contagens, ", ", fn {tabela, n} -> "#{n} em #{tabela}" end)

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
