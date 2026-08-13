defmodule Mix.Tasks.Qa.Reports do
  @shortdoc "Gera os relatórios que a análise externa importa: cobertura e achados do Credo"

  @moduledoc """
  Os relatórios que o SonarCloud importa, num comando.

      mix qa.reports

  ## Por que importar, e não deixar o Sonar analisar

  **O SonarCloud não analisa Elixir.** Não há analisador oficial, e plugin de
  comunidade não roda no serviço hospedado. Este repositório tem **31 312** linhas de
  Elixir contra 1 388 de Python e 9 631 de JavaScript — dos quais quase tudo é
  `assets/vendor`.

  Sem importação, o painel analisaria menos de 5% do que a plataforma é, e mostraria
  um selo verde por isso. **Um painel que aprova o que não olhou é pior que painel
  nenhum**: ele produz confiança sem cobertura, que é o defeito que esta base chama de
  sucesso silencioso.

  Então o Elixir entra pelos dois formatos genéricos que o Sonar aceita:

  | Relatório | De onde vem | O que o Sonar faz com ele |
  |---|---|---|
  | `cover/excoveralls.xml` | `mix coveralls.xml` | cobertura por linha |
  | `cover/credo.json` | `mix credo --format json`, convertido aqui | achados como *external issues* |

  ## O que este comando NÃO faz

  **Não substitui `mix gates`**, e não é um décimo primeiro gate. Os gates decidem se
  o código entra; o Sonar mede tendência ao longo do tempo. Um gate que depende de
  rede e de token é um gate que reprova por indisponibilidade — e a constituição já
  proíbe enfraquecer gate por conveniência, o que vale também para fortalecê-lo com
  algo que ninguém controla.

  ## Severidade, e por que ela não é inventada aqui

  O mapa abaixo traduz a categoria do Credo para o vocabulário do Sonar. Ele é
  **declarado**, e não derivado de heurística de nome: quem discordar muda uma linha e
  vê o efeito, em vez de descobrir a regra lendo código.
  """

  use Mix.Task

  @severidade %{
    "consistency" => "MINOR",
    "design" => "MAJOR",
    "readability" => "MINOR",
    "refactor" => "MAJOR",
    "warning" => "CRITICAL"
  }

  @saida "cover/credo.json"

  @impl Mix.Task
  def run(_args) do
    File.mkdir_p!("cover")

    cobertura()
    achados()

    :ok
  end

  defp cobertura do
    Mix.shell().info("→ cobertura")

    {_saida, codigo} =
      System.cmd("mix", ["coveralls.xml"], env: [{"MIX_ENV", "test"}], into: IO.stream())

    if codigo != 0, do: Mix.raise("mix coveralls.xml reprovou — código de saída #{codigo}")

    # O excoveralls escreve o caminho com barra inicial — `/lib/the_band/…` —, e o Sonar
    # resolve caminho **relativo à raiz do projeto**. Com a barra, nenhum arquivo casa, e o
    # painel mostra 0% de cobertura sem dizer que não achou os arquivos.
    caminho = "cover/excoveralls.xml"

    caminho
    |> File.read!()
    |> String.replace(~s(<file path="/), ~s(<file path="))
    |> then(&File.write!(caminho, &1))

    Mix.shell().info("  #{caminho}")
  end

  defp achados do
    Mix.shell().info("→ achados do Credo")

    {saida, _codigo} =
      System.cmd("mix", ["credo", "--strict", "--format", "json"], env: [{"MIX_ENV", "test"}])

    issues =
      saida
      |> extrair_json()
      |> Map.get("issues", [])
      |> Enum.map(&traduzir/1)

    File.write!(@saida, JSON.encode!(%{"issues" => issues}))
    Mix.shell().info("  #{@saida} — #{length(issues)} achado(s)")
  end

  # O Credo imprime o JSON depois de linhas de aviso quando há configuração a comentar. Casar
  # do primeiro `{` em diante é o que separa o relatório do ruído — e falhar aqui é melhor que
  # escrever um arquivo vazio, que o Sonar leria como "nenhum achado".
  defp extrair_json(saida) do
    case Regex.run(~r/\{.*\}/s, saida) do
      [json] -> JSON.decode!(json)
      nil -> Mix.raise("não achei JSON na saída do Credo — o relatório sairia vazio")
    end
  end

  defp traduzir(issue) do
    %{
      "engineId" => "credo",
      "ruleId" => issue["check"],
      "severity" => Map.get(@severidade, issue["category"], "MAJOR"),
      "type" => "CODE_SMELL",
      "primaryLocation" => %{
        "message" => issue["message"],
        "filePath" => issue["filename"],
        "textRange" => %{"startLine" => issue["line_no"] || 1}
      }
    }
  end
end
