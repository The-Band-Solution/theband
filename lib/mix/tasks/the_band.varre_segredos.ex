defmodule Mix.Tasks.TheBand.VarreSegredos do
  @shortdoc "Procura segredo em claro num dump ou no banco, com controle positivo"

  @moduledoc """
  Procura segredo em claro — feature 064, T002 a T004.

      mix the_band.varre_segredos --dump CAMINHO [--saida DIRETORIO]
      mix the_band.varre_segredos --banco [--saida DIRETORIO]

  Exatamente **um** de `--dump` e `--banco`. Sem nenhum, ou com os dois, recusa: varrer "o que
  estiver por aí" é o padrão que acha o lugar errado.

  `--saida DIRETORIO` grava o relatório também num arquivo datado dentro do diretório, para a
  FR-010: sem o registro, ninguém sabe se a varredura anterior aconteceu.

  | código | significa |
  |---|---|
  | `0` | limpo, **e o controle positivo achou cada plantio** |
  | `1` | achou pelo menos um segredo |
  | `2` | o controle positivo falhou: a varredura não enxerga, e o resultado não vale |
  | `3` | erro de uso |

  O contrato é `specs/064-segredo-em-repouso/contracts/varre-segredos.md`.
  """
  use Mix.Task

  alias TheBand.Segredo.Padroes
  alias TheBand.Segredo.Varredura

  @opcoes [dump: :string, banco: :boolean, saida: :string]

  @impl Mix.Task
  def run(args) do
    args |> executar() |> encerrar()
  end

  @doc false
  # Devolve `{codigo, texto}`, e não sai: é o que o teste chama. `run/1` é quem sai.
  @spec executar([String.t()], [Padroes.t()] | nil) :: {0..3, String.t()}
  def executar(args, padroes \\ nil) do
    case OptionParser.parse(args, strict: @opcoes) do
      {opts, [], []} -> escolher(opts, padroes)
      _ -> uso("argumento não reconhecido")
    end
  end

  defp escolher(opts, padroes) do
    case {opts[:dump], opts[:banco]} do
      {nil, nil} -> uso("diga o que varrer: --dump CAMINHO ou --banco")
      {caminho, true} when is_binary(caminho) -> uso("--dump e --banco juntos: escolha um")
      {caminho, _} when is_binary(caminho) -> varrer({:dump, caminho}, opts[:saida], padroes)
      {nil, true} -> varrer(:banco, opts[:saida], padroes)
    end
  end

  defp varrer(alvo, saida, padroes) do
    padroes = padroes || Padroes.todos()

    case rodar(alvo, padroes) do
      {:ok, relatorio} ->
        texto = Varredura.formatar(relatorio)
        codigo = Varredura.codigo(relatorio)
        gravar(saida, texto)
        {codigo, texto}

      {:error, :arquivo_ausente} ->
        uso("o arquivo do --dump não existe")
    end
  end

  defp rodar({:dump, caminho}, padroes), do: Varredura.dump(caminho, padroes)

  defp rodar(:banco, padroes) do
    Mix.Task.run("app.start")
    Varredura.banco(padroes)
  end

  defp gravar(nil, _texto), do: :ok

  defp gravar(diretorio, texto) do
    File.mkdir_p!(diretorio)
    nome = "varredura-" <> (DateTime.utc_now() |> DateTime.to_iso8601(:basic)) <> ".txt"
    File.write!(Path.join(diretorio, nome), texto)
  end

  defp uso(motivo) do
    {3,
     "varredura de segredos: #{motivo}\n\n" <>
       "  mix the_band.varre_segredos --dump CAMINHO [--saida DIRETORIO]\n" <>
       "  mix the_band.varre_segredos --banco [--saida DIRETORIO]\n"}
  end

  defp encerrar({codigo, texto}) do
    IO.write(texto)
    if codigo != 0, do: exit({:shutdown, codigo})
  end
end
