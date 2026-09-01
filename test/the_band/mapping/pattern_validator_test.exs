defmodule TheBand.Mapping.PatternValidatorTest do
  @moduledoc """
  O validador de padrão. **Cada teste é uma violação**, não um caminho feliz.

  Uma suíte que só provasse "expressão válida é aceita" deixaria passar exatamente as três
  que causam dano: a que não compila, a que casa tudo, e a que trava o processo.
  """
  use ExUnit.Case, async: true

  alias TheBand.Mapping.PatternValidator, as: V

  @titulos [
    "[TASK] Implementar a coleta de issues do repositório observado",
    "[US 1.1] Como mantenedor, quero ver o que a plataforma entende de cada issue",
    "[Devops] Subir o Postgres 17 no compose com volume nomeado"
  ]

  describe "as três recusas" do
    test "expressão que não compila é recusada com a posição do erro" do
      assert {:error, {:does_not_compile, razao, posicao}} = V.validate("regex", "[US", @titulos)
      assert is_binary(razao)
      assert is_integer(posicao)

      # 047/T014 (L71): a frase mudou de casa — do domínio para o catálogo, via
      # borda. O invariante (a POSIÇÃO entra na mensagem) agora se prova na frase
      # do catálogo, interpolada com a tupla que o domínio devolve.
      frase =
        Gettext.dgettext(
          TheBandWeb.Gettext,
          "errors",
          "the expression does not compile: %{razao}, at position %{posicao}",
          razao: razao,
          posicao: posicao
        )

      assert frase =~ "at position #{posicao}"
    end

    test "expressão que casa texto vazio é recusada" do
      assert V.validate("regex", ".*", @titulos) == {:error, :matches_empty}
      assert V.validate("regex", "(a)?", @titulos) == {:error, :matches_empty}

      assert Gettext.dgettext(
               TheBandWeb.Gettext,
               "errors",
               "the expression matches empty text, so it would match every issue in the organisation — a rule that matches everything classifies nothing"
             ) =~ "match every issue"
    end

    test "padrão vazio é recusado em qualquer forma de comparação" do
      for how <- ["equals", "starts_with", "contains", "regex"] do
        assert V.validate(how, "", @titulos) == {:error, :matches_empty}
        assert V.validate(how, nil, @titulos) == {:error, :matches_empty}
      end
    end
  end

  describe "o que é aceito" do
    test "expressão válida que não casa vazio passa" do
      assert V.validate("regex", "^\\[TASK\\]", @titulos) == :ok
      assert V.validate("regex", "^\\[US[^\\]]*\\]", @titulos) == :ok
    end

    test "comparação literal não compila nada, e por isso não recusa por sintaxe" do
      # `[US` é expressão inválida e **texto literal válido**. Recusá-lo em `starts_with`
      # seria aplicar a semântica de regex onde a pessoa pediu comparação de texto.
      assert V.validate("starts_with", "[US", @titulos) == :ok
      assert V.validate("contains", ".*", @titulos) == :ok
    end
  end

  describe "o orçamento de avaliação — issue #501" do
    test "o orçamento vem do catálogo, é em PASSOS, e a mensagem diz o número" do
      assert V.orcamento_passos() == 100_000

      mensagem =
        Gettext.dgettext(
          TheBandWeb.Gettext,
          "errors",
          "the expression exceeded the evaluation budget of %{orcamento} backtracking steps over real titles from this organisation; nested quantifiers are the usual cause",
          orcamento: 100_000
        )

      assert mensagem =~ "100000"

      assert mensagem =~ "backtracking steps", """
      **A mensagem precisa dizer a unidade.** A versão anterior dizia "took longer than
      100ms", e milissegundo depende da máquina de quem rodou — quem lia não tinha como
      conferir. Passo é o mesmo em qualquer máquina.
      """

      refute mensagem =~ "ms", "e não pode voltar a falar em tempo"
    end

    test "amostra vazia não trava nem recusa" do
      assert V.validate("regex", "^\\[TASK\\]", []) == :ok
    end

    test "expressão com quantificador aninhado é recusada, e o veredito não depende da máquina" do
      # `(a+)+$` sobre 40 `a` sem o `b` final faz o motor tentar 2⁴⁰ divisões. O orçamento
      # corta em 100.000 passos, e 100.000 passos são 100.000 passos em qualquer máquina.
      longo = String.duplicate("a", 40) <> "b"

      assert {:error, {:too_expensive, 100_000}} = V.validate("regex", "^(a+)+$", [longo])
    end

    test "o veredito é o MESMO com 40 e com 400 caracteres", ctx do
      _ = ctx

      for n <- [40, 120, 400] do
        assert {:error, {:too_expensive, _}} =
                 V.validate("regex", "^(a+)+$", [String.duplicate("a", n) <> "b"]),
               """
               **O que reprovava antes.** Com cronômetro, o tempo do motor era um platô — não
               crescia com o tamanho — e ficava a 5 ms do limite de 100. Aumentar a cadeia não
               mudava o resultado, e a máquina decidia. Com orçamento de passos, os três casos
               estouram porque o TRABALHO estoura, e n = #{n} não é o que decide.
               """
      end
    end

    test "padrão legítimo caro NÃO é recusado", ctx do
      _ = ctx

      # `.*[Ss]print.*` foi o mais caro dos seis medidos contra 300 títulos reais: 1.000
      # passos. O orçamento de 100.000 tem cem vezes de folga sobre ele.
      titulos = [
        "[TASK][Backend] Fechar o sprint 005 e consolidar as lições aprendidas do ciclo",
        String.duplicate("palavra longa ", 17) <> "sprint"
      ]

      assert V.validate("regex", ".*[Ss]print.*", titulos) == :ok, """
      **O orçamento precisa recusar o patológico sem recusar o legítimo.** Um número apertado
      demais transforma o guarda em obstáculo, e quem escreve a regra não tem como saber que
      a expressão dela era razoável.
      """
    end

    test "estourar o orçamento é distinguível de não casar" do
      # Sem `:report_errors` os dois desfechos voltam `:nomatch`, e a tela diria "sua regra
      # não pega nada" quando a verdade é "sua regra é cara demais para avaliar".
      assert V.validate("regex", "^\\[NUNCA-CASA\\]", @titulos) == :ok, """
      Não casar com título nenhum é **resposta**, e não recusa: a pessoa pode estar
      escrevendo uma regra para issues que ainda não chegaram.
      """

      assert {:error, {:too_expensive, _}} =
               V.validate("regex", "^(a+)+$", [String.duplicate("a", 40) <> "b"])
    end
  end
end
