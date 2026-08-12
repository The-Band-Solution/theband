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

      assert V.explicar({:does_not_compile, razao, posicao}) =~ "at position"
    end

    test "expressão que casa texto vazio é recusada" do
      assert V.validate("regex", ".*", @titulos) == {:error, :matches_empty}
      assert V.validate("regex", "(a)?", @titulos) == {:error, :matches_empty}

      assert V.explicar(:matches_empty) =~ "match every issue"
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

  describe "o limite de tempo" do
    test "o limite vem do catálogo e é dito na mensagem" do
      assert V.limite_ms() == 100
      assert V.explicar({:too_slow, 100}) =~ "100ms"
    end

    test "amostra vazia não trava nem recusa" do
      assert V.validate("regex", "^\\[TASK\\]", []) == :ok
    end

    test "expressão com quantificador aninhado sobre título longo é recusada" do
      # O caso patológico clássico: `(a+)+$` sobre uma cadeia de `a` sem o `b` final faz
      # o motor tentar todas as partições. Com 40 caracteres já passa de 100ms.
      longo = String.duplicate("a", 40) <> "b"

      assert {:error, {:too_slow, 100}} = V.validate("regex", "^(a+)+$", [longo])
    end
  end
end
