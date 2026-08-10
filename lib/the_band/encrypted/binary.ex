defmodule TheBand.Encrypted.Binary do
  @moduledoc """
  Campo cifrado em repouso (FR-005).

  Ler a tabela diretamente devolve texto cifrado. A cifragem acontece aqui, no
  tipo Ecto, e não no changeset — um campo declarado com este tipo não tem como
  ser gravado em claro por esquecimento de quem escreve o comando.
  """

  use Cloak.Ecto.Binary, vault: TheBand.Vault
end
