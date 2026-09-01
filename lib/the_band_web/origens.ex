defmodule TheBandWeb.Origens do
  @moduledoc """
  As origens aceitas para a conexão viva — feature 054, contrato em
  `specs/054-dominio-proprio/contracts/origens-aceitas.md`.

  Existe porque **duas perguntas diferentes usavam o mesmo valor**: qual endereço
  a plataforma escreve nos links, e por onde as pessoas chegam. Enquanto houve um
  endereço só, as duas coincidiram e ninguém notou. Com dois, um deles responde
  200 no HTTP e tem a conexão viva recusada — a página carrega, nenhuma tela
  atualiza, e nada diz o que houve (pendência P1 da 050, lição L85).

  A função é **pura de propósito**: não lê o ambiente. Quem lê é o
  `config/runtime.exs`. É isso que permite provar em teste o invariante que mais
  importa — **a ausência de declaração restringe, nunca libera** (FR-007). Um
  módulo que lesse `System.get_env/1` por dentro só seria testável mexendo no
  ambiente do processo de teste, e o caso que interessa é justamente o de
  ambiente vazio.

  ## O que esta lista NÃO decide

  Uma requisição que chega **sem o cabeçalho de origem** não é checada: o
  transporte do Phoenix devolve a conexão intacta antes de olhar a lista
  (verificado em `specs/054-dominio-proprio/research.md`, R3). Navegador sempre
  envia o cabeçalho no handshake; quem não envia é cliente programático — e
  contra ele a defesa é a sessão, não a origem.

  Está escrito aqui porque quem ler `origens_test.exs` sem esta ressalva
  concluiria "só quem está na lista conecta", e isso é falso. O contrato completo
  está em `specs/054-dominio-proprio/contracts/origens-aceitas.md`.
  """

  @esquema_padrao "https://"

  @doc """
  Monta a lista de origens aceitas.

  O primeiro argumento é o host principal — o mesmo que a aplicação usa para
  gerar links. O segundo é o valor cru da declaração de origens extras, como veio
  do ambiente: uma lista separada por vírgulas, ou `nil`.

  A origem principal vem sempre em primeiro lugar e nunca é omitida: uma
  declaração errada não pode derrubar o endereço que já funcionava.
  """
  @spec aceitas(String.t(), String.t() | nil) :: [String.t()]
  def aceitas(host_principal, declaracao_bruta) do
    [@esquema_padrao <> host_principal | declaradas(declaracao_bruta)]
    |> Enum.uniq()
  end

  defp declaradas(nil), do: []

  defp declaradas(bruta) when is_binary(bruta) do
    bruta
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&com_esquema/1)
  end

  # Entrada sem esquema recebe `https://` — o único que a produção serve.
  # Entrada COM esquema é preservada como veio, inclusive `http://`: reescrever o
  # explícito seria a plataforma decidindo calada o oposto do que se declarou.
  defp com_esquema(entrada) do
    if String.contains?(entrada, "://"),
      do: entrada,
      else: @esquema_padrao <> entrada
  end
end
