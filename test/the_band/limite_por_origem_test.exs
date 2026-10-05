defmodule TheBand.LimitePorOrigemTest do
  @moduledoc """
  O contador por origem — spec 077, T006 e T007 (FR-008, FR-011, FR-012; seguranca.md, L6, L8,
  L10, L11; Q4, Q7, Q8, Q18, Q21, Q22).

  Síncrono porque `varrer/1` é global: com o relógio adiantado, ela apagaria as contagens de
  testes que correm ao lado.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias TheBand.LimitePorOrigem
  alias TheBand.Origem
  alias TheBand.OrigemDeTeste

  @limite 10
  @janela 300

  defp falhas(origem, n, agora \\ System.system_time(:second)) do
    for _ <- 1..n, do: LimitePorOrigem.conferir(:contas, origem, agora)
  end

  defp recusada?({:recusa, _}), do: true
  defp recusada?(_), do: false

  test "a regra da base de conhecimento é a que o teste supõe" do
    {:ok, %{"rules" => %{"failure_limit" => %{"values" => v}}}} =
      TheBand.Ontology.KnowledgeBase.rule("access.origin_limit")

    assert v["failures"] == @limite
    assert v["window_seconds"] == @janela
  end

  test "T007 — duas origens de teste nunca são a mesma" do
    refute OrigemDeTeste.nova().chave == OrigemDeTeste.nova().chave
  end

  test "dez falhas seguem; a décima primeira é a transição; as seguintes, dentro" do
    o = OrigemDeTeste.nova()
    decisoes = falhas(o, 12)

    assert Enum.take(decisoes, 10) |> Enum.all?(&match?({:segue, _}, &1))
    assert Enum.at(decisoes, 10) == {:recusa, :transicao}
    assert Enum.at(decisoes, 11) == {:recusa, :dentro}
  end

  test "outra origem e outro balde não dividem a contagem" do
    o = OrigemDeTeste.nova()
    falhas(o, 11)

    assert {:segue, _} = LimitePorOrigem.conferir(:contas, OrigemDeTeste.nova())
    assert {:segue, _} = LimitePorOrigem.conferir(:operador, o)
  end

  test "Q4 — vinte tentativas paralelas: exatamente dez seguem" do
    o = OrigemDeTeste.nova()

    decisoes =
      1..20
      |> Task.async_stream(fn _ -> LimitePorOrigem.conferir(:contas, o) end, max_concurrency: 20)
      |> Enum.map(fn {:ok, d} -> d end)

    assert Enum.count(decisoes, &match?({:segue, _}, &1)) == 10
    assert Enum.count(decisoes, &recusada?/1) == 10
    assert Enum.count(decisoes, &(&1 == {:recusa, :transicao})) == 1
  end

  test "Q7 — dez falhas, um sucesso devolvido: a próxima falha passa do limite" do
    o = OrigemDeTeste.nova()
    falhas(o, 9)
    {:segue, ficha} = LimitePorOrigem.conferir(:contas, o)
    LimitePorOrigem.devolver(ficha)

    assert {:segue, _} = LimitePorOrigem.conferir(:contas, o)
    assert {:recusa, :transicao} = LimitePorOrigem.conferir(:contas, o)
  end

  test "Q8 — devolver uma fatia já varrida não cria chave nem deixa valor negativo" do
    o = OrigemDeTeste.nova()
    agora = System.system_time(:second)
    [{:segue, ficha}] = falhas(o, 1, agora)

    LimitePorOrigem.varrer(agora + 10 * @janela)
    :ok = LimitePorOrigem.devolver(ficha)
    :ok = LimitePorOrigem.devolver(ficha)

    assert :ets.match_object(:limite_por_origem, {{:contas, o.chave, :_}, :_}) == []
    assert :ets.select_count(:limite_por_origem, [{{:_, :"$1"}, [{:<, :"$1", 0}], [true]}]) == 0
  end

  test "devolver duas vezes não deixa a fatia abaixo de zero" do
    o = OrigemDeTeste.nova()
    [{:segue, ficha}] = falhas(o, 1)

    LimitePorOrigem.devolver(ficha)
    LimitePorOrigem.devolver(ficha)

    assert [{_, 0}] = :ets.match_object(:limite_por_origem, {{:contas, o.chave, :_}, :_})
  end

  test "a janela passa e a origem volta a ser atendida" do
    o = OrigemDeTeste.nova()
    agora = System.system_time(:second)
    falhas(o, 11, agora)

    assert recusada?(LimitePorOrigem.conferir(:contas, o, agora))
    assert {:segue, _} = LimitePorOrigem.conferir(:contas, o, agora + @janela + 30)
  end

  test "Q18 — não declarada: nunca recusa, e a transição é registrada" do
    o = Origem.de_endereco(OrigemDeTeste.endereco(), :nao_declarada)

    log = capture_log(fn -> send(self(), {:decisoes, falhas(o, 12)}) end)
    assert_received {:decisoes, decisoes}

    assert Enum.take(decisoes, 10) |> Enum.all?(&match?({:observado, :abaixo, _}, &1))
    assert {:observado, :transicao, _} = Enum.at(decisoes, 10)
    assert {:observado, :dentro, _} = Enum.at(decisoes, 11)
    refute Enum.any?(decisoes, &recusada?/1)
    assert log =~ "contas passou do limite · estado=nao_declarada"
  end

  test "Q22 — a transição vai para o log com o prefixo, nunca com o endereço nem em metadado" do
    sentinela = Origem.de_endereco({198, 51, 100, 23}, :socket)
    LimitePorOrigem.varrer(System.system_time(:second) + 10 * @janela)

    log = capture_log(fn -> falhas(sentinela, 12) end)

    assert log =~ "passou do limite"
    assert log =~ "prefixo=198.51.100.0/24"
    refute log =~ "198.51.100.23"
    assert length(String.split(log, "passou do limite")) == 2, "uma linha por transição"
    refute inspect(Logger.metadata()) =~ "198.51.100"
  end

  test "Q21 — a varredura é global: origens que não voltam saem da tabela" do
    agora = System.system_time(:second)
    origens = for _ <- 1..5_000, do: OrigemDeTeste.nova()
    for o <- origens, do: LimitePorOrigem.conferir(:contas, o, agora)

    restantes = fn ->
      Enum.count(
        origens,
        &(:ets.match_object(:limite_por_origem, {{:contas, &1.chave, :_}, :_}) != [])
      )
    end

    assert restantes.() == 5_000

    apagadas = LimitePorOrigem.varrer(agora + @janela + 30)

    assert apagadas >= 5_000
    assert restantes.() == 0
  end
end
