defmodule Mix.Tasks.Mensagens.Lacunas do
  @shortdoc "Enumera as chaves sem tradução, por idioma e domínio"

  @moduledoc """
  O relatório da feature 047 (FR-006): lacuna de tradução é visível, nunca
  silenciosa. Lê os `.po` de `priv/gettext/<locale>/LC_MESSAGES/` e lista os
  msgids com msgstr vazio.

  É relatório, não gate — exit 0 sempre (a spec não exige o segundo idioma
  completo; exige que o que falta seja enumerável). Contrato em
  `specs/047-mensagens-internacionalizadas/contracts/catalogo-de-mensagens.md`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    raiz = List.first(args) || "priv/gettext"

    raiz
    |> Path.join("*/LC_MESSAGES/*.po")
    |> Path.wildcard()
    |> Enum.group_by(&locale_de/1)
    |> Enum.sort()
    |> Enum.each(fn {locale, arquivos} -> relatar(locale, arquivos) end)
  end

  defp locale_de(caminho), do: caminho |> Path.split() |> Enum.at(-3)

  # No idioma padrão o msgid É a frase (research R2): msgstr vazio não é lacuna —
  # é o desenho. Contar seria acusar falta onde nada falta (SC-003 exige 0 ali).
  defp padrao, do: Application.get_env(:gettext, :default_locale, "en")

  defp relatar(locale, arquivos) do
    if locale == padrao() do
      Mix.shell().info("#{locale}: 0 lacunas (idioma padrão — o msgid é a frase)")
    else
      lacunas =
        arquivos
        |> Enum.sort()
        |> Enum.flat_map(fn arquivo ->
          dominio = Path.basename(arquivo, ".po")
          Enum.map(sem_traducao(arquivo), &{dominio, &1})
        end)

      Mix.shell().info("#{locale}: #{length(lacunas)} lacunas")

      Enum.each(lacunas, fn {dominio, msgid} ->
        Mix.shell().info("  #{dominio}: #{msgid}")
      end)
    end
  end

  defp sem_traducao(arquivo) do
    # Expo é a biblioteca que o próprio gettext usa para ler .po — nenhuma
    # dependência nova, e nenhum parse artesanal de formato alheio.
    arquivo
    |> Expo.PO.parse_file!()
    |> Map.fetch!(:messages)
    |> Enum.filter(&vazia?/1)
    |> Enum.map(&Enum.join(&1.msgid))
  end

  defp vazia?(%Expo.Message.Singular{msgstr: msgstr}), do: Enum.join(msgstr) == ""

  defp vazia?(%Expo.Message.Plural{msgstr: msgstr}) do
    msgstr |> Map.values() |> List.flatten() |> Enum.join() == ""
  end
end
