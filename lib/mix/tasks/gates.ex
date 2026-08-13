defmodule Mix.Tasks.Gates do
  @shortdoc "Roda os treze quality gates, na ordem do CI, abortando no primeiro que reprovar"

  @moduledoc """
  Os treze quality gates da constituição, num comando.

      mix gates

  ## Por que uma task e não uma lista no README

  Porque a lista no README divergia do CI, e a divergência produzia **verde falso**
  local. O caso concreto: o validador Python só valida a forma dos YAML quando
  `jsonschema` está instalado. Sem o venv ele avisa, registra a falha e **sai
  diferente de zero** — e quem rodasse `python3 scripts/... | tail -2` leria o aviso
  como nota de ambiente e concluiria que passou. Foi o que aconteceu, dez vezes
  seguidas, até o CI reprovar seis mapeamentos por erro de forma
  ([L23](../../../docs/sprints/licoes-aprendidas.md)).

  Esta task é a **única definição** dos gates. O CI a chama, então não há duas listas
  para manter em acordo, e a paridade não pode apodrecer sem alguém notar.

  ## Por que provisiona o venv

  Um gate que se auto-declara pulado é um gate reprovado, e a forma de não pular é
  ter a dependência. A task cria `.venv` na primeira execução e reusa depois. Sem
  isso a paridade dependeria de cada pessoa lembrar de um passo que o README pedia e
  o CI fazia sozinho.

  ## Por que aborta no primeiro

  Mesmo motivo do CI: um gate que reprova invalida a leitura dos seguintes. Rodar
  `dialyzer` sobre código que não compila sem avisos produz uma segunda mensagem de
  erro que não é um segundo problema.

  ## Opções

    * `--from GATE` — começa a partir do gate nomeado, para retomar sem repetir o
      que já passou. `mix gates --from testes`
    * `--list` — só lista os gates, na ordem, sem rodar
  """

  use Mix.Task

  @requirements []

  @venv ".venv"

  # A ordem é a do CI, e não é arbitrária: forma antes de compilação, compilação
  # antes de análise, análise antes de teste. Cada um pressupõe o anterior.
  @gates [
    {"format", {:mix, ["format", "--check-formatted"]}},
    {"compile", {:mix, ["compile", "--warnings-as-errors"]}},
    {"credo", {:mix, ["credo", "--strict"]}},
    # A CVE do `phoenix_live_view 1.2.8` só apareceu porque alguém rodou `mix hex.audit` à
    # mão. Como gate, ela aparece sozinha — e o repositório está limpo hoje, então o gate
    # nasce **verde**, e o que ele impede é a regressão.
    #
    # `mix deps.audit` **não** substitui: em 2026-08-13 ele dizia "No vulnerabilities found"
    # para a mesma dependência que este apontava. Bases de aviso diferentes.
    #
    {"auditoria de dependências", {:mix, ["hex.audit"]}},
    # **Segurança, e ela nasce verde.** Os seis achados da primeira execução foram tratados um
    # a um, e nenhum por desligar a verificação:
    #
    #   CSP ausente        corrigida — o script de tema saiu do HTML para `theme.js`
    #   String.to_atom ×3  corrigido — `to_existing_atom`, que também faz YAML errado falhar
    #   File.read! ×2      anotado com `@sobelow_skip` **na função**, com o motivo escrito
    #
    # `--skip` é o que faz as anotações valerem; sem ela, elas são comentário decorativo.
    {"sobelow", {:mix, ["sobelow", "--exit", "low", "--skip"]}},
    {"dialyzer", {:mix, ["dialyzer"]}},
    # Subprocesso, e não `Mix.Task.run`: `mix test` exige `MIX_ENV=test`, e mudar o
    # ambiente no meio de uma execução recompilaria tudo com as outras tasks já
    # rodadas em dev. O CI roda o job inteiro em test; aqui o isolamento é do gate.
    # O binário do Tailwind é cacheado no CI **pela versão dele**, e não por `mix.lock` —
    # issue #232. Mudar dependência Elixir não pode obrigar a baixar binário de novo, porque
    # falha de rede de um instante reprovava a execução inteira.
    #
    # Os assets são compilados **antes** dos testes porque o teste dos tokens do design
    # system mede o CSS **compilado** — "apliquei a paleta" é afirmação sobre o build, e o
    # Tailwind poda o que não encontra no markup.
    #
    # Sem este passo o teste passava na máquina de quem já tinha buildado e falhava no CI
    # limpo. É a L24, e a correção é a mesma dela: o caminho do ambiente limpo tem de ser
    # o caminho que roda.
    {"assets", {:cmd, "mix", ["assets.build"], [{"MIX_ENV", "test"}]}},
    {"testes", {:cmd, "mix", ["test"], [{"MIX_ENV", "test"}]}},
    {"knowledge.validate", {:mix, ["knowledge.validate"]}},
    {"knowledge.graph", {:mix, ["knowledge.graph"]}},
    {"validador Python", {:python, ["scripts/validate_knowledge_base.py"]}},
    {"derivação reproduzível", {:fun, :derivation_is_reproducible}},
    # Os dois validadores sobre a mesma base. Vem **depois** do gate do Python porque é ele
    # quem provisiona o `.venv`.
    {"validadores concordam", {:fun, :validators_agree}}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [from: :string, list: :boolean])

    if opts[:list] do
      Enum.each(@gates, fn {name, _} -> Mix.shell().info("  #{name}") end)
    else
      @gates
      |> skip_until(opts[:from])
      |> run_gates()
    end
  end

  defp skip_until(gates, nil), do: gates

  defp skip_until(gates, from) do
    case Enum.split_while(gates, fn {name, _} -> name != from end) do
      {_, []} ->
        Mix.raise("gate desconhecido: #{from}. `mix gates --list` mostra os nomes.")

      {_, resto} ->
        resto
    end
  end

  defp run_gates(gates) do
    total = length(gates)

    gates
    |> Enum.with_index(1)
    |> Enum.each(fn {{name, command}, i} ->
      Mix.shell().info([:bright, "\n── #{i}/#{total} #{name}", :reset])
      command |> execute() |> abort_if_failed(name)
    end)

    Mix.shell().info([:green, "\n#{total} gates verdes.", :reset])
  end

  # Aborta em vez de acumular: um gate reprovado invalida a leitura dos seguintes, e
  # uma lista de doze falhas esconde qual delas é a causa.
  defp abort_if_failed(:ok, _name), do: :ok
  defp abort_if_failed({:error, nil}, name), do: Mix.raise("gate reprovou: #{name}")

  defp abort_if_failed({:error, motivo}, name),
    do: Mix.raise("gate reprovou: #{name} — #{motivo}")

  # **Subprocesso, e o veredito é o código de saída.** A versão anterior chamava
  # `Mix.Task.run/2` e **descartava o retorno**, devolvendo `:ok` a menos que a task
  # levantasse `Mix.Error` ou saísse.
  #
  # `mix compile --warnings-as-errors` **não levanta**: ele devolve `{:error, diagnostics}`.
  # Então o gate de compilação nunca reprovava por aviso — e um `@doc` órfão entrou em `main`
  # com os gates todos verdes, o aviso impresso **três vezes** na saída, e código de saída zero.
  #
  # É a L22 na própria definição dos gates: *gate conferido por texto não é gate*. O que ela
  # dizia sobre `| tail` vale aqui para o valor de retorno.
  #
  # Custo medido em 2026-08-12: cada gate passa a subir um VM próprio.
  defp execute({:mix, args}), do: execute({:cmd, "mix", args, []})

  defp execute({:cmd, program, args, env}) do
    case System.cmd(program, args, env: env, into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, code} -> {:error, "código de saída #{code}"}
    end
  end

  defp execute({:python, [script | args]}) do
    python = ensure_venv()

    case System.cmd(python, [script | args], into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, code} -> {:error, "código de saída #{code}"}
    end
  end

  defp execute({:fun, name}), do: apply(__MODULE__, name, [])

  @doc """
  A derivação é função da ontologia: duas execuções iguais dão a mesma saída.

  Confere também o **código de saída** de cada execução, e não só o `diff`. Uma
  derivação que falha igual nas duas vezes produz saídas idênticas, e um gate que só
  compara passaria — foi assim que este gate ficou vermelho por semanas sem ninguém
  ver ([L22](../../../docs/sprints/licoes-aprendidas.md)).
  """
  def derivation_is_reproducible do
    python = ensure_venv()
    script = "scripts/derive_information_model.py"

    Enum.reduce_while(~w(eo sro cmpo spo), :ok, fn ontology, _ ->
      case derive_twice(python, script, ontology) do
        :ok ->
          Mix.shell().info("   #{ontology} — reproduzível")
          {:cont, :ok}

        {:error, _} = erro ->
          {:halt, erro}
      end
    end)
  end

  @doc """
  Os dois validadores dão o mesmo veredito sobre a mesma base.

  Duas implementações da mesma regra divergem no dia em que uma muda, e a divergência aparece
  como aprovação de um lado — que é o modo silencioso de falhar. O gate injeta um erro que
  **os dois** têm de achar, e confere que os dois reprovam; depois confere que os dois aprovam
  a base íntegra.

  Comparar a lista de problemas palavra por palavra não serviria: as mensagens são escritas em
  cada linguagem, e igualá-las obrigaria a manter texto sincronizado sem ganho. O que precisa
  bater é o **veredito**.
  """
  def validators_agree do
    python = ensure_venv()

    with :ok <- verdicts_match(python, :integra, nil),
         :ok <- verdicts_match(python, :com_segredo, ~s(measurement:\n  id: v\n  t: "ghp_x")),
         :ok <-
           verdicts_match(
             python,
             :com_conceito_inexistente,
             ~s(module:\n  id: x.mod\n  ontology: x\nconcepts:\n  - id: x.a\n    classification:\n      parent: x.nunca_existiu\n)
           ) do
      Mix.shell().info("   os dois validadores concordam nos três casos")
      :ok
    end
  end

  defp verdicts_match(python, caso, conteudo) do
    base = Path.join(System.tmp_dir!(), "theband-gate-#{caso}")
    File.rm_rf!(base)
    File.cp_r!("priv/knowledge_base", base)
    if conteudo, do: File.write!(Path.join(base, "injetado.yaml"), conteudo)

    elixir_aprova? = match?({:ok, _}, TheBand.Ontology.KnowledgeBase.load(base))

    {saida, code} =
      System.cmd(python, ["scripts/validate_knowledge_base.py", "--kb", base],
        stderr_to_stdout: true
      )

    File.rm_rf!(base)
    python_aprova? = code == 0
    esperado = caso == :integra

    cond do
      elixir_aprova? != python_aprova? ->
        Mix.shell().error(saida)

        {:error,
         "os validadores discordam em #{caso}: Elixir #{veredito(elixir_aprova?)}, " <>
           "Python #{veredito(python_aprova?)}"}

      elixir_aprova? != esperado ->
        Mix.shell().error(saida)

        {:error,
         "em #{caso} os dois deram #{veredito(elixir_aprova?)}, e o esperado era o oposto"}

      true ->
        :ok
    end
  end

  defp veredito(true), do: "aprovou"
  defp veredito(false), do: "reprovou"

  defp derive_twice(python, script, ontology) do
    args = [script, "--ontology", ontology]

    with {saida1, 0} <- System.cmd(python, args, stderr_to_stdout: true),
         {saida2, 0} <- System.cmd(python, args, stderr_to_stdout: true) do
      if saida1 == saida2,
        do: :ok,
        else: {:error, "derivação de #{ontology} não é reproduzível"}
    else
      {saida, code} ->
        Mix.shell().error(saida)
        {:error, "derivação de #{ontology} falhou com código #{code}"}
    end
  end

  # Cria o venv na primeira execução e reusa depois. Devolve o caminho do Python
  # dele — nunca o do sistema, que é justamente o que pula a validação de forma.
  defp ensure_venv do
    # Caminho ABSOLUTO: `System.cmd` não resolve caminho relativo, e o erro que ele
    # dá — `:enoent` — parece dizer que o venv não existe quando ele existe. Foi o
    # que aconteceu aqui: `.venv` estava no repositório desde agosto, com
    # `jsonschema` instalado, e eu chamava o `python3` do sistema, que não o tem.
    python = Path.expand(Path.join([@venv, "bin", "python"]))

    if File.exists?(python) do
      python
    else
      Mix.shell().info("   criando #{@venv} (uma vez)")
      {_, 0} = System.cmd("python3", ["-m", "venv", @venv])

      # `-m pip` em vez do executável `pip`: um caminho a expandir em vez de dois, e
      # é o próprio interpretador do venv que resolve o módulo. A versão anterior
      # chamava `.venv/bin/pip` relativo e falhava com `:enoent` — só no CI, porque
      # aqui o venv já existia e este ramo nunca rodava.
      {_, 0} =
        System.cmd(python, ["-m", "pip", "install", "-q", "-r", "scripts/requirements.txt"])

      python
    end
  end
end
