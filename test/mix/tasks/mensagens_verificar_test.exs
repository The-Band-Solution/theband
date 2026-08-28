defmodule Mix.Tasks.Mensagens.VerificarTest do
  @moduledoc """
  O verificador da 047, começando pela violação (L03): literal plantado reprova
  com arquivo e linha; gettext, variável e chamada de função passam.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @fixtures Path.join(System.tmp_dir!(), "mensagens_verificar_fixtures")

  setup do
    File.rm_rf!(@fixtures)
    File.mkdir_p!(@fixtures)
    on_exit(fn -> File.rm_rf!(@fixtures) end)
    :ok
  end

  defp escrever(nome, corpo) do
    caminho = Path.join(@fixtures, nome)
    File.write!(caminho, corpo)
    caminho
  end

  defp rodar do
    capture_io(fn ->
      capture_io(:stderr, fn ->
        try do
          Mix.Tasks.Mensagens.Verificar.run([@fixtures])
          send(self(), :passou)
        rescue
          e in Mix.Error -> send(self(), {:reprovou, e.message})
        end
      end)
      |> then(&send(self(), {:stderr, &1}))
    end)

    veredito =
      receive do
        :passou -> :passou
        {:reprovou, msg} -> {:reprovou, msg}
      end

    stderr =
      receive do
        {:stderr, s} -> s
      after
        0 -> ""
      end

    {veredito, stderr}
  end

  test "a violação: literal plantado reprova com arquivo e linha" do
    escrever("plantado.ex", """
    defmodule Plantado do
      def f(socket) do
        put_flash(socket, :error, "mensagem plantada")
      end
    end
    """)

    {veredito, stderr} = rodar()

    assert {:reprovou, mensagem} = veredito
    assert mensagem =~ "1 literais"
    assert stderr =~ "plantado.ex:3"
  end

  test "interpolação e concatenação também reprovam" do
    escrever("interpolado.ex", """
    defmodule Interpolado do
      def f(socket, x) do
        socket
        |> put_flash(:info, "feito: \#{x}")
        |> put_flash(:error, "prefixo " <> x)
      end
    end
    """)

    {veredito, stderr} = rodar()

    assert {:reprovou, mensagem} = veredito
    assert mensagem =~ "2 literais"
    assert stderr =~ "interpolado.ex:4"
    assert stderr =~ "interpolado.ex:5"
  end

  test "a forma qualificada também é ralo — foi por ela que o plug escapou" do
    escrever("qualificado.ex", """
    defmodule Qualificado do
      def f(conn) do
        Phoenix.Controller.put_flash(conn, :error, "escapou do primeiro pente")
      end
    end
    """)

    {veredito, stderr} = rodar()

    assert {:reprovou, _} = veredito
    assert stderr =~ "qualificado.ex:3"
  end

  test "gettext, variável e chamada de função passam" do
    escrever("limpo.ex", """
    defmodule Limpo do
      def f(socket, motivo) do
        socket
        |> put_flash(:error, dgettext("errors", "Board not found."))
        |> put_flash(:info, dgettext("sistema", "Renamed to %{nome}.", nome: motivo))
        |> put_flash(:error, frase(motivo))
        |> put_flash(:info, motivo)
      end
    end
    """)

    {veredito, _stderr} = rodar()
    assert veredito == :passou
  end
end
