defmodule Mix.Tasks.TheBand.GenKey do
  @shortdoc "Gera uma chave mestra de 32 bytes em Base64"

  @moduledoc """
  Imprime uma chave adequada a `THE_BAND_MASTER_KEY` (FR-005).

      export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)

  A chave não é gravada em lugar nenhum: sai no stdout e cabe a quem opera
  guardá-la no ambiente ou no cofre da infraestrutura. Nunca no repositório.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> IO.puts()
  end
end
