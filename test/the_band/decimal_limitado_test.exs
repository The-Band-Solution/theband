defmodule TheBand.DecimalLimitadoTest do
  @moduledoc """
  A GUARDA da exceção registrada em `mix.exs` para `CVE-2026-32686`.

  A avaliação de 2026-09-08 (`docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md`)
  concluiu que o aviso é falso positivo de metadado: `decimal` corrigiu o expoente ilimitado
  na 3.0.0, esta base usa 3.1.1, e o registro OSV casa versões corrigidas porque a faixa
  SEMVER não tem evento `fixed`.

  Uma exceção na auditoria sem guarda é uma data esperando ser esquecida. Estes testes são a
  guarda: se o `decimal` voltar a aceitar expoente ilimitado — por downgrade, por resolução
  transitiva ou por mudança de padrão upstream —, a suíte reprova aqui, e a exceção deixa de
  esconder um risco que passou a ser real.

  Não testam código nosso. Testam a **premissa** sob a qual a exceção foi escrita, que é
  exatamente o que ninguém revalida ao ler um `mix.exs`.
  """
  use ExUnit.Case, async: true

  describe "o decimal instalado limita o expoente (premissa da exceção em mix.exs)" do
    test "o contexto padrão tem faixa finita" do
      %Decimal.Context{emax: emax, emin: emin, precision: precisao} = Decimal.Context.get()

      assert is_integer(emax) and emax <= 6144, "emax deixou de ser finito: #{inspect(emax)}"
      assert is_integer(emin) and emin >= -6143, "emin deixou de ser finito: #{inspect(emin)}"
      assert is_integer(precisao) and precisao <= 34, "precisão sem teto: #{inspect(precisao)}"
    end

    test "parse de expoente absurdo devolve :error, e não um número gigante" do
      assert Decimal.parse("1e1000000000") == :error
      assert Decimal.parse("1e-1000000000") == :error
    end

    test "new/1 com expoente absurdo levanta em vez de alocar" do
      assert_raise Decimal.Error, fn -> Decimal.new("1e1000000000") end
    end

    test "a versão instalada é 3.0.0 ou maior — abaixo dela o aviso é real" do
      versao = Application.spec(:decimal, :vsn) |> to_string() |> Version.parse!()

      assert Version.compare(versao, Version.parse!("3.0.0")) in [:gt, :eq],
             "decimal #{versao} é ANTERIOR à correção; a exceção em mix.exs deixou de valer"
    end
  end
end
