defmodule Mix.Tasks.TheBand.RotateKey do
  @shortdoc "Recifra todos os campos cifrados com a chave mestra atual"

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

  Desde a #1052, o trabalho está em `TheBand.Rotacao`, que recifra **todos** os campos cifrados
  (`Rotacao.campos_cifrados/0`), e não só `tool_credentials`. Em produção, onde a release não
  tem `mix`, o caminho é `TheBand.Release.rotacionar_chave/0` por `rpc`.

  A rotação lê `secret` por SQL, sem o `Ecto.Type` cifrado. Se usasse o schema, a
  primeira credencial ilegível derrubaria o carregamento inteiro com uma exceção
  do Cloak, e não haveria como dizer **quantas** ficaram para trás nem quais. Ler
  o binário e decifrar registro a registro é o que permite parar com um
  diagnóstico útil em vez de um stacktrace.

  A task reporta contagens, nunca valores.
  """

  use Mix.Task

  alias TheBand.Rotacao

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    dry_run? = "--dry-run" in args

    case Rotacao.recifrar(dry_run?) do
      {:ok, contagens} -> Mix.shell().info(relatar(contagens, dry_run?))
      {:error, {:ilegiveis, por_tabela}} -> interromper(por_tabela)
    end
  end

  defp relatar(contagens, true), do: "seriam recifradas (--dry-run): " <> por_tabela(contagens)
  defp relatar(contagens, false), do: "recifradas: " <> por_tabela(contagens)

  defp por_tabela(contagens),
    do: Enum.map_join(contagens, ", ", fn {tabela, n} -> "#{n} em #{tabela}" end)

  # Sempre levanta: recifrar parcialmente é pior que não recifrar.
  @spec interromper(map()) :: no_return()
  defp interromper(por_tabela) do
    Mix.shell().error("""

    Registros que não puderam ser lidos com nenhuma das chaves configuradas: #{por_tabela(por_tabela)}.
    **Nada foi gravado.**

    Confira THE_BAND_PREVIOUS_MASTER_KEY antes de tentar de novo. Recifrar
    parcialmente deixaria credenciais órfãs, que só apareceriam quando alguém
    tentasse usá-las — no meio de uma coleta.
    """)

    Mix.raise("rotação interrompida")
  end
end
