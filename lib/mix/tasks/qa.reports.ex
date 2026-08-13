defmodule Mix.Tasks.Qa.Reports do
  @shortdoc "Mede a cobertura e junta os achados de Credo, Sobelow e auditoria de dependências"

  @moduledoc """
  A medida de qualidade que sobrevive a cada execução.

      mix qa.reports

  ## O SonarCloud saiu, e vale saber por quê

  Esta task nasceu para alimentá-lo. **Ele não analisa Elixir** — não há analisador oficial,
  e plugin de comunidade não roda no serviço hospedado. Medido no PR #290:
  `ncloc_language_distribution = js=24`, vinte e quatro linhas indexadas, todas JavaScript,
  num repositório de **31 312** linhas de Elixir.

  A cobertura importada apontava para arquivos que ele não conhecia, e o quality gate
  reprovava por `new_coverage = 0%` medindo o único arquivo que enxergava — o script de tema,
  que existe por causa da CSP. Desligar aquela condição exige plano pago.

  **O que sobrou é o que valia desde o começo**: os números, medidos e guardados. O CI publica
  `cover/` como artefato de cada execução; não há painel de tendência, e **isso está declarado**
  em vez de fingido.

  ## O que ela produz

  | Arquivo | Conteúdo |
  |---|---|
  | `cover/excoveralls.xml` | cobertura por linha — **80,1%** na medida de 2026-08-13 |
  | `cover/credo.json` | achados de Credo, Sobelow e auditoria de dependências, num arquivo só |

  ## As três origens de achado, e por que são três

  | Origem | O que só ela vê |
  |---|---|
  | **Credo** | estilo, complexidade, refatoração |
  | **Sobelow** | segurança de Phoenix — CSP ausente, travessia de diretório, `String.to_atom` |
  | **`mix hex.audit`** | dependência com CVE |

  **E `mix deps.audit` não substitui `mix hex.audit`**: medido em 2026-08-13, o primeiro dizia
  *"No vulnerabilities found"* enquanto o segundo apontava `EEF-CVE-2026-64941` no
  `phoenix_live_view 1.2.8`. Bases de aviso diferentes, e confiar em uma só teria escondido.

  ## O que este comando NÃO faz

  **Não substitui `mix gates`.** Credo, Sobelow e a auditoria **já são gates** — reprovam e
  bloqueiam. Aqui eles são reunidos num relatório para que o número tenha história; o veredito
  continua sendo o código de saída dos doze.
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

  # A severidade do Sobelow vem do próprio relatório — `high`, `medium`, `low` —, e é
  # traduzida sem interpretação.
  @severidade_sobelow %{"high" => "CRITICAL", "medium" => "MAJOR", "low" => "MINOR"}

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
    Mix.shell().info("→ achados: Credo, Sobelow e auditoria de dependências")

    {saida, _codigo} =
      System.cmd("mix", ["credo", "--strict", "--format", "json"], env: [{"MIX_ENV", "test"}])

    do_credo =
      saida
      |> extrair_json()
      |> Map.get("issues", [])
      |> Enum.map(&traduzir/1)

    # As três em variável, e não chamadas de novo na mensagem: cada uma dispara um processo
    # externo, e a primeira versão deste código rodava o Sobelow duas vezes só para contar.
    do_sobelow = sobelow()
    de_dependencia = dependencias()
    issues = do_credo ++ do_sobelow ++ de_dependencia

    File.write!(@saida, JSON.encode!(%{"issues" => issues}))

    Mix.shell().info(
      "  #{@saida} — #{length(issues)} achado(s): " <>
        "#{length(do_credo)} do Credo, #{length(do_sobelow)} do Sobelow, " <>
        "#{length(de_dependencia)} de dependência"
    )
  end

  defp sobelow do
    {saida, _codigo} =
      System.cmd("mix", ["sobelow", "--format", "json", "--skip"], env: [{"MIX_ENV", "test"}])

    case Regex.run(~r/\{.*\}/s, saida) do
      [json] ->
        json
        |> JSON.decode!()
        |> Map.get("findings", %{})
        |> Enum.flat_map(fn {chave, achados} ->
          nivel = chave |> String.replace("_confidence", "") |> String.downcase()
          Enum.map(achados, &traduzir_sobelow(&1, nivel))
        end)

      nil ->
        Mix.shell().error(
          "  aviso: não achei JSON na saída do Sobelow — a segurança ficou de fora"
        )

        []
    end
  end

  # `mix hex.audit` não tem saída em JSON, e o que interessa dele é binário: há aviso ou não
  # há. Um achado por linha, com o texto da própria ferramenta — inventar estrutura aqui seria
  # reescrever o que ela já diz.
  defp dependencias do
    {saida, codigo} = System.cmd("mix", ["hex.audit"], env: [{"MIX_ENV", "test"}])

    if codigo == 0 do
      []
    else
      [
        %{
          "engineId" => "hex.audit",
          "ruleId" => "dependency-advisory",
          "severity" => "CRITICAL",
          "type" => "VULNERABILITY",
          "primaryLocation" => %{
            "message" => "dependência com aviso de segurança:\n" <> String.trim(saida),
            "filePath" => "mix.lock",
            "textRange" => %{"startLine" => 1}
          }
        }
      ]
    end
  end

  defp traduzir_sobelow(achado, nivel) do
    %{
      "engineId" => "sobelow",
      "ruleId" => achado["type"] || "sobelow",
      "severity" => Map.get(@severidade_sobelow, nivel, "MAJOR"),
      "type" => "VULNERABILITY",
      "primaryLocation" => %{
        "message" => achado["type"] || "achado do Sobelow",
        "filePath" => achado["file"] || "mix.exs",
        "textRange" => %{"startLine" => achado["line"] || 1}
      }
    }
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
