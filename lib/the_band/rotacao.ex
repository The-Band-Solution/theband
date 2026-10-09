defmodule TheBand.Rotacao do
  @moduledoc """
  A rotação da chave mestra, num lugar só — issue #1052. Contrato no comentário da issue.

  Depende de: nenhuma ontologia. Lê e grava os campos cifrados por SQL, sem o `Ecto.Type`.

  ## Por que uma lista única

  A rotação recifrava só `tool_credentials`. `ai_provider_credentials.secret` é cifrado com a
  mesma chave, e depois de uma rotação ficava ilegível: a rodada de perfis falharia, e a
  credencial do provedor teria de ser cadastrada de novo. `campos_cifrados/0` é a lista, e
  `test/the_band/rotacao_test.exs` reprova se um schema com `TheBand.Encrypted.Binary` ficar
  de fora.

  ## Por que pelo binário cru

  Pelo schema, a primeira credencial ilegível derrubaria o carregamento com uma exceção do
  Cloak, e não haveria como dizer **quantas** ficaram para trás. Lendo o binário e decifrando
  registro a registro, a rotação para com contagens, e nunca com valores.

  ## Tudo ou nada

  Com um único registro ilegível em qualquer tabela, **nada** é gravado. Recifrar parcialmente
  deixaria credenciais órfãs, que só apareceriam quando alguém tentasse usá-las.
  """

  alias TheBand.Repo
  alias TheBand.Vault

  @campos [
    {"tool_credentials", "secret"},
    {"ai_provider_credentials", "secret"},
    # O segredo TOTP do operador da plataforma — spec 070, T021 (seguranca-totp.md, T3).
    {"platform_operators", "totp_secret"}
  ]

  @type contagens :: %{String.t() => non_neg_integer()}

  @doc "Os pares `{tabela, coluna}` cifrados com a chave mestra."
  @spec campos_cifrados() :: [{String.t(), String.t()}]
  def campos_cifrados, do: @campos

  @doc """
  Recifra todo campo da lista com o cipher padrão do `Vault`, que no meio de uma rotação é o
  da chave nova. Com `dry_run?`, só conta.
  """
  @spec recifrar(boolean()) :: {:ok, contagens()} | {:error, {:ilegiveis, contagens()}}
  def recifrar(dry_run?) do
    lidos = Enum.map(@campos, fn {tabela, coluna} -> {tabela, coluna, ler(tabela, coluna)} end)

    ilegiveis =
      for {tabela, _coluna, linhas} <- lidos,
          n = Enum.count(linhas, &match?({_id, :error}, &1)),
          n > 0,
          into: %{},
          do: {tabela, n}

    cond do
      ilegiveis != %{} -> {:error, {:ilegiveis, ilegiveis}}
      dry_run? -> {:ok, contar(lidos)}
      true -> gravar(lidos)
    end
  end

  defp ler(tabela, coluna) do
    {tabela, coluna}
    |> consultar()
    |> Map.fetch!(:rows)
    |> Enum.map(fn [id, cifrado] -> {id, decifrar(cifrado)} end)
  end

  # O SQL de cada par é LITERAL, numa cláusula por campo, e não interpolado. Tabela e coluna já
  # vinham de `@campos`, mas interpolar nome de tabela é o padrão que o Sobelow reprova, e com
  # razão: o próximo a mexer pode trocar a constante por algo vindo de fora. Um campo novo na
  # lista sem cláusula aqui levanta `FunctionClauseError` na primeira rotação, e o teste da
  # rotação de verdade passa por todos os pares.
  defp consultar({"tool_credentials", "secret"}),
    do: Repo.query!("SELECT id, secret FROM tool_credentials ORDER BY inserted_at")

  defp consultar({"ai_provider_credentials", "secret"}),
    do: Repo.query!("SELECT id, secret FROM ai_provider_credentials ORDER BY inserted_at")

  # Só os operadores com segundo fator: a coluna é nula até o primeiro passo do cadastro, e um nulo
  # não é ilegível, é ausente.
  defp consultar({"platform_operators", "totp_secret"}),
    do:
      Repo.query!(
        "SELECT id, totp_secret FROM platform_operators WHERE totp_secret IS NOT NULL " <>
          "ORDER BY inserted_at"
      )

  defp regravar({"tool_credentials", "secret"}, id, cifrado),
    do:
      Repo.query!("UPDATE tool_credentials SET secret = $1, updated_at = NOW() WHERE id = $2", [
        cifrado,
        id
      ])

  defp regravar({"ai_provider_credentials", "secret"}, id, cifrado),
    do:
      Repo.query!(
        "UPDATE ai_provider_credentials SET secret = $1, updated_at = NOW() WHERE id = $2",
        [cifrado, id]
      )

  defp regravar({"platform_operators", "totp_secret"}, id, cifrado),
    do:
      Repo.query!(
        "UPDATE platform_operators SET totp_secret = $1, updated_at = NOW() WHERE id = $2",
        [cifrado, id]
      )

  # O Cloak devolve `{:ok, :error}` quando acha o cipher pelo rótulo e a decifragem falha.
  # Exigir binário é o que conta isso como ilegível, em vez de seguir adiante como texto claro.
  defp decifrar(cifrado) do
    case Vault.decrypt(cifrado) do
      {:ok, plano} when is_binary(plano) -> {:ok, plano}
      _ -> :error
    end
  end

  defp gravar(lidos) do
    Repo.transaction(fn ->
      for {tabela, coluna, linhas} <- lidos, {id, {:ok, plano}} <- linhas do
        regravar({tabela, coluna}, id, Vault.encrypt!(plano))
      end

      contar(lidos)
    end)
  end

  defp contar(lidos),
    do: Map.new(lidos, fn {tabela, _coluna, linhas} -> {tabela, length(linhas)} end)
end
