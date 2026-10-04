defmodule TheBand.Spans do
  @moduledoc """
  Suporte de teste para ler os spans que **saíram** — spec 074, T008; research R4;
  seguranca.md, S15.

  O teste troca **só o destino**: o exportador configurado é sempre
  `TheBand.Telemetria.Exportador`, o filtro de produção, e o destino é o processo do teste.
  `ligar/0` confere isso depois de configurar, e levanta se o módulo no caminho for outro — um
  teste que capturasse o span antes do filtro provaria que o handler é cuidadoso, e não que nada
  sai.

  Os testes que usam este módulo são `async: false`: o processador simples do SDK é um só, e o
  destino é global.
  """

  import ExUnit.Assertions

  require Record

  alias TheBand.Telemetria.Exportador

  Record.defrecord(
    :span,
    Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  )

  @processador :otel_simple_processor_global

  defmodule Destino do
    @moduledoc """
    O destino do teste: entrega ao processo cada span **e o recurso** que o exportador entregou.

    É o `:otel_exporter_pid` do SDK, mais o recurso — que ele descarta, e que o teste das
    sentinelas precisa varrer (S1: o recurso é um canal).
    """
    @behaviour :otel_exporter_traces

    @impl true
    def init(pid), do: {:ok, pid}

    @impl true
    def export(_tabela, _recurso, :ninguem), do: :ok

    def export(tabela, recurso, pid) do
      :ets.foldl(fn span, _ -> send(pid, {:span, span}) end, :ok, tabela)
      send(pid, {:recurso, recurso})
      :ok
    end

    @impl true
    def shutdown(_), do: :ok
  end

  @doc """
  Liga o filtro real com destino no processo `pid`, e confere que o filtro está no caminho.
  No fim do teste, o destino volta a ser ninguém.
  """
  @spec ligar(pid()) :: :ok
  def ligar(pid \\ self()) do
    configurar(Exportador, %{destino: {Destino, pid}})
    ExUnit.Callbacks.on_exit(&desligar/0)
    conferir_o_filtro!()
  end

  @doc "O filtro continua no caminho, e o destino passa a ser ninguém."
  @spec desligar() :: :ok
  def desligar, do: configurar(Exportador, %{destino: {Destino, :ninguem}})

  defp configurar(modulo, opcoes), do: :otel_simple_processor.set_exporter(modulo, opcoes)

  @doc "Levanta se o exportador no caminho não for `TheBand.Telemetria.Exportador`."
  @spec conferir_o_filtro!() :: :ok
  def conferir_o_filtro! do
    {_estado, dados} = :sys.get_state(@processador)

    case elem(dados, 1) do
      {Exportador, _} ->
        :ok

      outro ->
        raise "o exportador no caminho não é o filtro de produção: #{inspect(elem_ou(outro))}"
    end
  end

  defp elem_ou({modulo, _}), do: modulo
  defp elem_ou(outro), do: outro

  @doc "Os spans que chegaram até agora (sem esperar mais que `espera` ms pelo primeiro)."
  @spec recebidos(non_neg_integer()) :: [tuple()]
  def recebidos(espera \\ 200), do: coletar(:span, espera, [])

  @doc "Os recursos que chegaram até agora."
  @spec recursos(non_neg_integer()) :: [term()]
  def recursos(espera \\ 0), do: coletar(:recurso, espera, [])

  defp coletar(etiqueta, espera, acc) do
    receive do
      {^etiqueta, valor} -> coletar(etiqueta, 0, [valor | acc])
    after
      espera -> Enum.reverse(acc)
    end
  end

  @doc "O nome do span, como texto."
  @spec nome(tuple()) :: String.t()
  def nome(s), do: to_string(span(s, :name))

  @doc "Os atributos do span, num mapa de texto para valor."
  @spec atributos(tuple()) :: map()
  def atributos(s) do
    case span(s, :attributes) do
      :undefined -> %{}
      attrs -> Map.new(:otel_attributes.map(attrs), fn {k, v} -> {to_string(k), v} end)
    end
  end

  @doc "As chaves do recurso, ordenadas."
  @spec chaves_do_recurso(term()) :: [String.t()]
  def chaves_do_recurso(recurso) do
    recurso
    |> :otel_resource.attributes()
    |> :otel_attributes.map()
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  @doc "Os spans de um passo (pelo nome)."
  @spec do_passo([tuple()], atom()) :: [tuple()]
  def do_passo(spans, passo),
    do: Enum.filter(spans, &(nome(&1) == "the_band.acesso.#{passo}"))

  @doc """
  As sentinelas encontradas em qualquer parte dos termos — nome, atributo, evento, status, link
  e recurso —, em claro, em Base64 e em `inspect`. A lista vazia é o que se espera.
  """
  @spec sentinelas_encontradas([term()], [String.t()]) :: [String.t()]
  def sentinelas_encontradas(termos, sentinelas) do
    texto = inspect(termos, limit: :infinity, printable_limit: :infinity, structs: false)

    for s <- sentinelas,
        forma <- [s, Base.encode64(s), Base.url_encode64(s, padding: false), inspect(s)],
        String.contains?(texto, forma),
        uniq: true,
        do: s
  end

  @doc "Afirma que pelo menos um span de cada passo chegou — antes de qualquer `refute`."
  @spec assert_passos!([tuple()], [atom()]) :: :ok
  def assert_passos!(spans, passos) do
    for passo <- passos do
      assert do_passo(spans, passo) != [],
             "nenhum span de #{passo} chegou: a varredura não mediria nada"
    end

    :ok
  end
end
