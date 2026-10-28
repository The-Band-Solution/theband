defmodule TheBand.DependenciasConsertadasTest do
  @moduledoc """
  Os pisos de versão da issue #1439 e a lista exata das exceções da auditoria — guardas G2, G5
  e G9 da avaliação de 2026-10-27
  (`docs/seguranca/2026-10-27-avisos-bandit-jose-plug-crypto-ex-mcp.md`).

  O piso existe porque o `mix.lock` muda por resolução transitiva sem ninguém ler o diff: um
  `deps.update` de outra coisa pode trazer de volta a versão com aviso, e o `hex.audit` só a
  acusaria se o aviso continuasse publicado do mesmo jeito.

  A lista exata existe porque entrada obsoleta em `ignore_advisories` **não reprova** o
  `hex.audit` (achado M1): ela só avisa, e fica ali esperando o mesmo identificador voltar a
  casar.
  """
  use ExUnit.Case, async: true

  defp versao(app), do: app |> Application.spec(:vsn) |> to_string() |> Version.parse!()

  # G2. EEF-CVE-2026-105963: o `secret_key_base` no frame do erro de tipo.
  test "plug_crypto é 2.2.1 ou maior" do
    assert Version.match?(versao(:plug_crypto), ">= 2.2.1"),
           "plug_crypto #{versao(:plug_crypto)} é anterior ao conserto do EEF-CVE-2026-105963"
  end

  # G5. Cobre os avisos de memória e CPU (-114213, -111101, -113436), cujo teste de
  # comportamento dependeria de medir memória e tempo, e seria instável na suíte.
  test "bandit é 1.14.0 ou maior" do
    assert Version.match?(versao(:bandit), ">= 1.14.0"),
           "bandit #{versao(:bandit)} é anterior aos consertos de 2026-10 (issue #1439)"
  end

  # G9. Cada entrada é um risco aceito com guarda própria; entrada a mais é exceção sem dono.
  test "as exceções da auditoria são exatamente as aceitas e ainda vigentes" do
    ignoradas = Mix.Project.config()[:hex][:ignore_advisories]

    assert Enum.sort(ignoradas) ==
             Enum.sort(["EEF-CVE-2026-43966", "EEF-CVE-2026-95105", "EEF-CVE-2026-94206"]),
           """
           ignore_advisories é #{inspect(ignoradas)}.

           Entrada nova precisa de medição, decisão da pessoa mantenedora e guarda em teste
           (AGENTS.md §14.0). Entrada consertada sai: o hex.audit só AVISA que ela ficou
           obsoleta, e não reprova.
           """
  end
end
