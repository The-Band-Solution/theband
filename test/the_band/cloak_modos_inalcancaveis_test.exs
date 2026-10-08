defmodule TheBand.CloakModosInalcancaveisTest do
  @moduledoc """
  A GUARDA da exceção registrada em `mix.exs` para `EEF-CVE-2026-95105` (`cloak` 1.1.4) e
  `EEF-CVE-2026-94206` (`cloak_ecto` 1.3.0) — issue #1418, decidida pela pessoa mantenedora em
  2026-10-06.

  As duas advisories atingem modos que esta aplicação não usa:

  - **95105**: o cipher `Cloak.Ciphers.AES.CTR` não autentica o texto cifrado. O `TheBand.Vault`
    configura só `Cloak.Ciphers.AES.GCM`, que autentica (`lib/the_band/vault.ex`);
  - **94206**: o campo `Cloak.Ecto.PBKDF2` ignora as iterações configuradas. O único tipo Ecto
    cifrado daqui é `Cloak.Ecto.Binary` (`lib/the_band/encrypted/binary.ex`).

  Estes testes não testam código nosso: testam as **premissas** sob as quais a exceção foi
  escrita, e reprovam se qualquer uma cair:

  1. nenhum código de `lib/` ou `config/` nomeia um cipher do Cloak que não seja `AES.GCM`;
  2. nenhum código nomeia `Cloak.Ecto.PBKDF2`;
  3. as versões são as medidas: `cloak` 1.1.4 e `cloak_ecto` 1.3.0. Versão nova pode trazer o
     conserto (e a exceção sai) ou outro defeito (e a medição não vale mais).

  ## Por que a varredura lê a AST, e não o texto

  Como na guarda do `cowlib`: a varredura parte de `Code.string_to_quoted/1`, que descarta
  comentários, e remove `@moduledoc` e `@doc` antes de procurar. A explicação da proibição não
  reprova a guarda. O teste de controle, no fim, prova as duas metades.
  """
  use ExUnit.Case, async: true

  @cipher_permitido [:Cloak, :Ciphers, :AES, :GCM]

  test "1. nenhum cipher do Cloak além do AES.GCM em lib/ ou config/" do
    achados = varrer(&cipher_proibido/1)

    assert achados == [], """
    Apareceu um cipher do Cloak que não é o AES.GCM: #{inspect(achados)}.

    A exceção de EEF-CVE-2026-95105 em `mix.exs` vale só enquanto todo cipher é autenticado
    (#1418). Com outro cipher, a exceção CAI, e sai no mesmo PR.
    """
  end

  test "2. nenhum campo Cloak.Ecto.PBKDF2" do
    achados = varrer(&pbkdf2/1)

    assert achados == [], """
    Apareceu `Cloak.Ecto.PBKDF2`: #{inspect(achados)}.

    A exceção de EEF-CVE-2026-94206 em `mix.exs` vale só enquanto o campo não é usado (#1418).
    """
  end

  test "3. as versões são as medidas" do
    assert to_string(Application.spec(:cloak, :vsn)) == "1.1.4"
    assert to_string(Application.spec(:cloak_ecto, :vsn)) == "1.3.0"
  end

  describe "o controle: a varredura acha o proibido, e só em código" do
    test "acha o AES.CTR, um cipher depreciado e o PBKDF2, em código" do
      fonte = """
      defmodule X do
        def a, do: {Cloak.Ciphers.AES.CTR, tag: "x"}
        def b, do: Cloak.Ciphers.Deprecated.AES.CTR
        use Cloak.Ecto.PBKDF2, vault: V
        def c, do: {Cloak.Ciphers.AES.GCM, tag: "ok"}
      end
      """

      assert length(achados_em_fonte(fonte, &cipher_proibido/1)) == 2
      assert length(achados_em_fonte(fonte, &pbkdf2/1)) == 1
    end

    test "ignora a menção em comentário, @moduledoc e @doc" do
      fonte = """
      defmodule X do
        @moduledoc "não usar Cloak.Ciphers.AES.CTR nem Cloak.Ecto.PBKDF2"
        # Cloak.Ciphers.AES.CTR
        @doc "Cloak.Ecto.PBKDF2"
        def c, do: {Cloak.Ciphers.AES.GCM, tag: "ok"}
      end
      """

      assert achados_em_fonte(fonte, &cipher_proibido/1) == []
      assert achados_em_fonte(fonte, &pbkdf2/1) == []
    end
  end

  defp cipher_proibido([:Cloak, :Ciphers | _] = partes), do: partes != @cipher_permitido
  defp cipher_proibido(_partes), do: false

  defp pbkdf2([:Cloak, :Ecto, :PBKDF2 | _]), do: true
  defp pbkdf2(_partes), do: false

  defp varrer(proibido?) do
    for caminho <- Path.wildcard("{lib,config}/**/*.{ex,exs}"),
        achado <- achados_em_fonte(File.read!(caminho), proibido?),
        do: {caminho, achado}
  end

  defp achados_em_fonte(fonte, proibido?) do
    {:ok, ast} = Code.string_to_quoted(fonte)

    ast
    |> sem_documentacao()
    |> Macro.prewalk([], fn
      {:__aliases__, _, partes} = no, acc when is_list(partes) ->
        if proibido?.(partes), do: {no, [Module.concat(partes) | acc]}, else: {no, acc}

      no, acc ->
        {no, acc}
    end)
    |> elem(1)
  end

  defp sem_documentacao(ast) do
    Macro.prewalk(ast, fn
      {:@, _, [{doc, _, _}]} when doc in [:moduledoc, :doc] -> nil
      no -> no
    end)
  end
end
