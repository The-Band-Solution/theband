defmodule TheBand.CowlibInalcancavelTest do
  @moduledoc """
  A GUARDA da exceção registrada em `mix.exs` para `EEF-CVE-2026-43966` e
  `EEF-CVE-2026-43969`, as duas do `cowlib` 2.20.0 — feature 062, T001, R3.

  A medição de 2026-09-24 (`specs/062-servidor-mcp/r3-cowlib-alcance.md`) concluiu que as duas
  advisories atingem **codificadores** que nada nesta aplicação chama. O endpoint é servido pelo
  Bandit, e o `ExMCP.HttpPlug` roda sob ele sem tocar em função nenhuma de
  cowlib/cowboy/ranch. O trace fez zero chamadas, e o controle, sob Cowboy, fez 85.

  **Uma exceção na auditoria sem guarda é uma data esperando ser esquecida** — é o
  `decimal_limitado_test.exs` de novo. Estes testes não testam código nosso: testam as
  **premissas** sob as quais a exceção foi escrita, e reprovam se qualquer uma cair:

  1. o adapter do endpoint é o Bandit. Sem a linha, o Phoenix volta ao Cowboy **em
     silêncio**, porque o `plug_cowboy` agora está instalado;
  2. nenhum listener Cowboy está de pé;
  3. nenhum código de `lib/` ou `config/` inicia Cowboy, fala `:cow_*` ou usa `gun`;
  4. a `ex_mcp` é a 1.5.0 medida, fixada.

  ## Por que a varredura lê a AST, e não o texto

  Esta casa já reprovou duas vezes com guarda que lia o próprio código e achava a proibição
  **na prosa que a explica**. Aqui a varredura parte de `Code.string_to_quoted/1`, que descarta
  comentários, e remove `@moduledoc` e `@doc` antes de procurar. O teste de controle, no fim,
  prova as duas metades: acha o código proibido, e ignora a menção em comentário.
  """
  use ExUnit.Case, async: true

  test "1. o endpoint é servido pelo Bandit" do
    assert TheBandWeb.Endpoint.config(:adapter) == Bandit.PhoenixAdapter, """
    O adapter do endpoint deixou de ser o Bandit.

    Sem `adapter: Bandit.PhoenixAdapter` em `config/config.exs`, o Phoenix usa o
    `Cowboy2Adapter` por padrão, e o `plug_cowboy` agora existe: a borda passaria a ser o
    Cowboy, com o `cowlib` das duas advisories. A exceção em `mix.exs` CAI com isto (condição
    1), e sai no mesmo PR.
    """
  end

  test "2. nenhum listener Cowboy está de pé" do
    iniciadas = Enum.map(Application.started_applications(), &elem(&1, 0))

    # A GUARDA DO CENÁRIO: a medição viu o `ranch` iniciado e sem listener. Se ele não
    # estiver iniciado, `:ranch.info/0` levantaria e o teste não diria nada sobre a premissa.
    assert :ranch in iniciadas, "o ranch não foi iniciado; a premissa medida era outra"

    assert :ranch.info() == %{}, """
    Há listener Cowboy de pé: #{inspect(Map.keys(:ranch.info()))}.

    A medição da R3 viu `:ranch.info() == %{}`: a aplicação `:ex_mcp` não inicia listener. Um
    listener serve pelo Cowboy, e o `cowlib` passa a estar na borda. A exceção CAI (condição 2).
    """
  end

  test "3. nenhum código de lib/ ou config/ inicia Cowboy, fala :cow_* ou usa gun" do
    arquivos = Path.wildcard("lib/**/*.{ex,exs}") ++ Path.wildcard("config/*.exs")

    # Guarda contra a varredura vazia: sem arquivo, "nenhum achado" não diria nada.
    assert length(arquivos) > 100

    achados =
      for arquivo <- arquivos, achado <- achados_em_fonte(File.read!(arquivo)) do
        "#{arquivo}: #{achado}"
      end

    assert achados == [], """
    Código que alcança o Cowboy ou o cowlib:

    #{Enum.map_join(achados, "\n", &("  " <> &1))}

    A exceção do `cowlib` em `mix.exs` vale só enquanto nada aqui o alcança. Com isto ela CAI
    (condições 2 e 3), e sai no mesmo PR.
    """
  end

  test "4. a ex_mcp é a 1.5.0 medida, e está fixada" do
    assert to_string(Application.spec(:ex_mcp, :vsn)) == "1.5.0"

    requisito =
      Enum.find_value(Mix.Project.config()[:deps], fn
        {:ex_mcp, req} when is_binary(req) -> req
        {:ex_mcp, req, _opts} when is_binary(req) -> req
        _ -> nil
      end)

    assert requisito == "== 1.5.0", """
    A `ex_mcp` está declarada como #{inspect(requisito)}, e não `== 1.5.0`.

    Com `~> 1.5`, uma 1.x nova entraria sem que a medição do `cowlib` fosse refeita. A
    exceção vale para a versão medida (condição 4).
    """
  end

  describe "a varredura mede, e não lê a prosa — o controle positivo" do
    test "acha cada uma das quatro formas proibidas, em código" do
      fonte = """
      defmodule Injetado do
        def a, do: Plug.Cowboy.http(Mod, [])
        def b, do: ExMCP.Server.Transport.start_server(1, 2, 3, 4)
        def c, do: :cow_cookie.cookie([])
        def d, do: [transport: :http]
        def e, do: :gun.open(~c"x", 80)
      end
      """

      achados = achados_em_fonte(fonte)

      for esperado <- [
            "Plug.Cowboy",
            "ExMCP.Server.Transport",
            ":cow_cookie",
            "transport: :http",
            ":gun"
          ] do
        assert Enum.any?(achados, &(&1 =~ esperado)),
               "a varredura não achou #{esperado}: #{inspect(achados)}"
      end
    end

    test "ignora a menção em comentário, @moduledoc e @doc" do
      fonte = ~S'''
      defmodule SoFala do
        @moduledoc """
        Nunca use Plug.Cowboy, :cow_cookie nem transport: :http aqui.
        """
        # Plug.Cowboy.http(Mod, []) e :gun ficam de fora — ver a R3.
        @doc "ExMCP.Server.Transport não é iniciado."
        def ok, do: :ok
      end
      '''

      assert achados_em_fonte(fonte) == []
    end
  end

  # A AST sem comentários (o `string_to_quoted` os descarta) e sem `@moduledoc`/`@doc`.
  defp achados_em_fonte(fonte) do
    {:ok, ast} = Code.string_to_quoted(fonte)

    ast =
      Macro.prewalk(ast, fn
        {:@, _, [{attr, _, _}]} when attr in [:moduledoc, :doc, :typedoc] -> :documentacao
        no -> no
      end)

    {_, achados} =
      Macro.prewalk(ast, [], fn
        {:__aliases__, _, [:Plug, :Cowboy | _]} = no, acc ->
          {no, ["Plug.Cowboy" | acc]}

        {:__aliases__, _, [:ExMCP, :Server, :Transport | _]} = no, acc ->
          {no, ["ExMCP.Server.Transport" | acc]}

        {:transport, :http} = no, acc ->
          {no, ["transport: :http" | acc]}

        atomo, acc when is_atom(atomo) ->
          nome = Atom.to_string(atomo)

          cond do
            String.starts_with?(nome, "cow_") -> {atomo, [":" <> nome | acc]}
            atomo == :gun -> {atomo, [":gun" | acc]}
            true -> {atomo, acc}
          end

        no, acc ->
          {no, acc}
      end)

    Enum.reverse(achados)
  end
end
