defmodule TheBand.Tenants.AccessEventsPassoTest do
  # Spec 074, T011 — a função única que emite o passo, e a terceira camada de S1: só passam
  # átomo da lista, id binário e o correlator.
  use ExUnit.Case, async: false

  alias TheBand.Spans
  alias TheBand.Tenants.AccessEvents

  @uuid "0b6d6a3e-1f6c-4b8e-9a51-3c1d2e4f5a6b"
  @correlator "AAAAAAAAAAAAAAAAAAAAAA"

  defp valido(extra \\ %{}) do
    Map.merge(
      %{
        passo: :entrar_com_senha,
        desfecho: :falhou,
        motivo: :senha_errada,
        tenant_id: @uuid,
        user_id: @uuid
      },
      extra
    )
  end

  test "com passo, desfecho e motivo válidos, um span chega com os mesmos valores" do
    :ok = Spans.ligar()

    assert AccessEvents.passo(valido(%{jornada_id: @correlator})) == :ok

    [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)

    assert Spans.atributos(span) == %{
             "journey.name" => "entrar_e_sair",
             "journey.step" => "entrar_com_senha",
             "journey.id" => @correlator,
             "outcome" => "falhou",
             "failure.reason" => "senha_errada",
             "tenant.id" => @uuid,
             "user.ref" => @uuid
           }
  end

  test "o concluído vai sem motivo, e o motivo nil só cabe no concluído" do
    assert AccessEvents.passo(valido(%{desfecho: :concluiu, motivo: nil})) == :ok

    assert_raise FunctionClauseError, fn ->
      AccessEvents.passo(valido(%{desfecho: :concluiu, motivo: :senha_errada}))
    end

    assert_raise FunctionClauseError, fn -> AccessEvents.passo(valido(%{motivo: nil})) end
  end

  test "uma string no motivo levanta: o texto livre não cabe na assinatura" do
    assert_raise FunctionClauseError, fn ->
      AccessEvents.passo(valido(%{motivo: "#Ecto.Changeset<password: ...>"}))
    end
  end

  test "uma struct no lugar do id, uma chave a mais ou um passo fora da lista levantam" do
    assert_raise FunctionClauseError, fn ->
      AccessEvents.passo(valido(%{user_id: %{id: @uuid, email: "a@b.c"}}))
    end

    assert_raise FunctionClauseError, fn -> AccessEvents.passo(valido(%{senha: "x"})) end

    assert_raise FunctionClauseError, fn ->
      AccessEvents.passo(valido(%{passo: :entrar_pelo_github}))
    end

    assert_raise FunctionClauseError, fn ->
      AccessEvents.passo(valido(%{desfecho: :abandonou}))
    end

    assert_raise FunctionClauseError, fn -> AccessEvents.passo(valido(%{jornada_id: 123})) end
    assert_raise FunctionClauseError, fn -> AccessEvents.passo(sem(:user_id)) end
  end

  # `Map.reject/2`, e não `Map.delete/2`: com `delete`, o verificador de tipos do compilador
  # prova que a chave falta e avisa já na compilação — o aviso é exatamente o que este caso
  # quer provar em tempo de execução.
  defp sem(chave), do: Map.reject(valido(), fn {k, _} -> k == chave end)
end
