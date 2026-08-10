defmodule Mix.Tasks.TheBand.RotateKey do
  @shortdoc "Recifra as credenciais com a chave mestra atual"

  @moduledoc """
  Rotação da chave mestra (FR-005b).

  Contrato: `specs/001-github-eo-ingestion/contracts/credential-rotation.md`.

      export THE_BAND_PREVIOUS_MASTER_KEY=$THE_BAND_MASTER_KEY
      export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)
      mix the_band.rotate_key

  Depois de recifrar, **remova** `THE_BAND_PREVIOUS_MASTER_KEY` do ambiente e
  reinicie. Manter a chave antiga publicada mantém viva justamente a chave que se
  quis aposentar.

  ## Por que passa pelo binário cru

  A task lê `secret` por SQL, sem o `Ecto.Type` cifrado. Se usasse o schema, a
  primeira credencial ilegível derrubaria o carregamento inteiro com uma exceção
  do Cloak, e não haveria como dizer **quantas** ficaram para trás nem quais. Ler
  o binário e decifrar registro a registro é o que permite parar com um
  diagnóstico útil em vez de um stacktrace.

  A task reporta contagens, nunca valores.
  """

  use Mix.Task

  alias TheBand.Repo
  alias TheBand.Vault

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    rows = Repo.query!("SELECT id, tenant_id, secret FROM tool_credentials ORDER BY inserted_at")

    {legiveis, ilegiveis} =
      rows.rows
      |> Enum.map(fn [id, tenant_id, secret] -> {id, tenant_id, decifrar(secret)} end)
      |> Enum.split_with(fn {_id, _tenant_id, resultado} -> match?({:ok, _}, resultado) end)

    case ilegiveis do
      [] -> recifrar(legiveis, "--dry-run" in args)
      _ -> interromper(length(ilegiveis), length(rows.rows))
    end
  end

  # O Cloak devolve `{:ok, :error}` quando encontra o cipher pelo rótulo mas a
  # decifragem falha — forma que engana quem só casa `{:ok, _}` e faz o valor
  # `:error` seguir adiante como se fosse texto claro. Exigir binário aqui é o
  # que transforma isso num registro contado como ilegível em vez de numa exceção
  # de criptografia dez frames adiante.
  defp decifrar(secret) do
    case Vault.decrypt(secret) do
      {:ok, plano} when is_binary(plano) -> {:ok, plano}
      _ -> :error
    end
  end

  defp recifrar(credenciais, true = _dry_run?) do
    Mix.shell().info("#{length(credenciais)} credenciais seriam recifradas (--dry-run)")
  end

  defp recifrar(credenciais, false) do
    Enum.each(credenciais, fn {id, _tenant_id, {:ok, plano}} ->
      # Cifrar de novo usa sempre o cipher marcado como padrão — que, no meio de
      # uma rotação, é o da chave nova.
      Repo.query!("UPDATE tool_credentials SET secret = $1, updated_at = NOW() WHERE id = $2", [
        Vault.encrypt!(plano),
        id
      ])
    end)

    organizacoes =
      credenciais |> Enum.map(fn {_id, tenant_id, _} -> tenant_id end) |> Enum.uniq() |> length()

    Mix.shell().info(
      "recifradas #{length(credenciais)} credenciais de #{organizacoes} organizações"
    )
  end

  # Sempre levanta: recifrar parcialmente é pior que não recifrar.
  @spec interromper(non_neg_integer(), non_neg_integer()) :: no_return()
  defp interromper(ilegiveis, total) do
    Mix.shell().error("""

    #{ilegiveis} de #{total} credenciais não puderam ser lidas com nenhuma das chaves
    configuradas. **Nada foi gravado.**

    Confira THE_BAND_PREVIOUS_MASTER_KEY antes de tentar de novo. Recifrar
    parcialmente deixaria credenciais órfãs, que só apareceriam quando alguém
    tentasse usá-las — no meio de uma coleta.
    """)

    Mix.raise("rotação interrompida")
  end
end
