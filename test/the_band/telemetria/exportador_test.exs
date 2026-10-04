defmodule TheBand.Telemetria.ExportadorTest do
  # Spec 074, T009 — o filtro do que sai (seguranca.md, S1; contrato §6). Os spans são criados
  # direto pela API do OpenTelemetry, como um código descuidado criaria, e atravessam o SDK e o
  # filtro de produção até o processo do teste.
  use ExUnit.Case, async: false

  alias TheBand.Spans
  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Exportador

  require TheBand.Spans

  @uuid "0b6d6a3e-1f6c-4b8e-9a51-3c1d2e4f5a6b"
  @sentinela "SENTINELA-EXPORTADOR-9f3c"

  setup do
    :ok = Spans.ligar()
    :ok
  end

  defp emitir(nome, atributos, fun \\ fn _ -> :ok end) do
    tracer = :opentelemetry.get_application_tracer(__MODULE__)

    ctx =
      :otel_tracer.start_span(:otel_ctx.new(), tracer, nome, %{
        kind: :server,
        attributes: atributos
      })

    fun.(ctx)
    :otel_span.end_span(ctx)
  end

  defp passo_valido(extra \\ %{}) do
    Map.merge(
      %{
        "journey.name" => "entrar_e_sair",
        "journey.step" => "entrar_com_senha",
        "outcome" => "falhou",
        "failure.reason" => "senha_errada",
        "tenant.id" => @uuid,
        "user.ref" => @uuid
      },
      extra
    )
  end

  test "um atributo fora da lista não sai, e o descarte é contado pelo NOME do atributo" do
    antes = Contadores.valor(:atributo_descartado, "depuracao")

    emitir("the_band.acesso.entrar_com_senha", passo_valido(%{"depuracao" => @sentinela}))

    [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    refute Map.has_key?(Spans.atributos(span), "depuracao")
    assert Spans.atributos(span)["failure.reason"] == "senha_errada"
    assert Contadores.valor(:atributo_descartado, "depuracao") == antes + 1
  end

  test "failure.reason com valor fora da enumeração DO PASSO não sai, mesmo com o nome permitido" do
    antes = Contadores.valor(:atributo_descartado, "failure.reason")
    changeset = "#Ecto.Changeset<changes: %{password: \"#{@sentinela}\"}>"

    emitir("the_band.acesso.entrar_com_senha", passo_valido(%{"failure.reason" => changeset}))
    # `sessao_ja_nao_existia` é motivo declarado — mas de `sair`, e não de `entrar_com_senha`.
    emitir(
      "the_band.acesso.entrar_com_senha",
      passo_valido(%{"failure.reason" => "sessao_ja_nao_existia"})
    )

    spans = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    assert length(spans) == 2
    assert Enum.all?(spans, &(not Map.has_key?(Spans.atributos(&1), "failure.reason")))
    assert Spans.sentinelas_encontradas(spans, [@sentinela]) == []
    assert Contadores.valor(:atributo_descartado, "failure.reason") == antes + 2
  end

  test "valores fora da forma — id que não é UUID, correlator de outro tamanho — não saem" do
    emitir(
      "the_band.acesso.entrar_com_senha",
      passo_valido(%{
        "tenant.id" => "fulana@example.com",
        "user.ref" => @sentinela,
        "journey.id" => String.duplicate("a", 23),
        "journey.step" => "sair"
      })
    )

    [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    atributos = Spans.atributos(span)

    for nome <- ~w(tenant.id user.ref journey.id journey.step),
        do: refute(Map.has_key?(atributos, nome), "#{nome} saiu fora da forma")
  end

  test "um evento de exceção e a descrição do status não saem" do
    antes = Contadores.valor(:evento_descartado, nil)

    emitir("the_band.acesso.entrar_com_senha", passo_valido(), fn ctx ->
      :otel_span.record_exception(ctx, :error, %RuntimeError{message: @sentinela}, [], %{})
      :otel_span.add_event(ctx, "depuracao", %{"senha" => @sentinela})
      :otel_span.set_status(ctx, :error, @sentinela)
    end)

    [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    assert :otel_events.list(Spans.span(span, :events)) == []
    assert elem(Spans.span(span, :status), 1) == :error
    assert elem(Spans.span(span, :status), 2) == ""
    assert Spans.sentinelas_encontradas([span], [@sentinela]) == []
    assert Contadores.valor(:evento_descartado, nil) == antes + 2
  end

  test "um span de nome fora da enumeração dos passos é descartado inteiro (FR-012)" do
    antes = Contadores.valor(:span_descartado, nil)

    emitir("SELECT * FROM users WHERE email = $1", %{"db.statement" => @sentinela})
    emitir("the_band.acesso.passo_inventado", passo_valido())

    assert Spans.recebidos() == []
    assert Contadores.valor(:span_descartado, nil) == antes + 2
  end

  test "o recurso sai reconstruído com as três chaves, e nada do recurso detectado" do
    {:ok, estado} = Exportador.init(%{destino: {Spans.Destino, self()}, ambiente: "teste"})
    detectado = :otel_resource.create(%{"host.name" => @sentinela, "service.name" => "x"})

    emitir("the_band.acesso.sair", %{
      "journey.name" => "entrar_e_sair",
      "journey.step" => "sair",
      "outcome" => "concluiu"
    })

    [original] = Spans.recebidos()
    tabela = :ets.new(:teste_recurso, [:duplicate_bag, :public])
    :ets.insert(tabela, original)

    assert Exportador.export(tabela, detectado, estado) == :ok
    recurso = List.last(Spans.recursos(100))

    assert Spans.chaves_do_recurso(recurso) ==
             ["deployment.environment", "service.name", "service.version"]

    assert Spans.sentinelas_encontradas([recurso], [@sentinela]) == []
  end

  test "a lista do que pode sair tem os sete nomes do contrato §3, e nenhum outro" do
    assert Enum.sort(Exportador.atributos_permitidos()) ==
             Enum.sort(
               ~w(journey.name journey.step journey.id outcome failure.reason tenant.id user.ref)
             )
  end
end
