defmodule TheBand.Jobs.FilaDoCronTest do
  @moduledoc """
  Os jobs do `Cron` não dividem fila com a coleta — issue #801, achado S1 da avaliação de
  segurança de 2026-10-01.

  O verificador da fila (`TheBand.Saude`) diz "parada" quando nenhum job completa por 15
  minutos, e conta com o `Cron` completando algo a cada 5. Se os jobs do `Cron` estiverem na
  fila da coleta, cinco coletas longas ocupam as vagas, o `Cron` não roda, e o verificador
  acusa parada com a fila trabalhando. O healthcheck marcaria o contêiner `unhealthy`, e
  reiniciá-lo derrubaria as coletas.
  """
  use ExUnit.Case, async: true

  alias TheBand.Jobs.SyncGitHubEO

  defp oban_declarado do
    "config/config.exs"
    |> Config.Reader.read!(env: :prod)
    |> get_in([:the_band, Oban])
  end

  defp workers_do_cron do
    Enum.find_value(oban_declarado()[:plugins], fn
      {Oban.Plugins.Cron, opts} -> for {_expr, worker} <- opts[:crontab], do: worker
      _ -> nil
    end)
  end

  test "nenhum worker do Cron está na fila da coleta" do
    fila_da_coleta = SyncGitHubEO.__opts__()[:queue]
    workers = workers_do_cron()
    assert workers != [], "o crontab está vazio: o teste não mediria nada"

    na_fila_da_coleta =
      Enum.filter(workers, fn w ->
        Code.ensure_loaded!(w) && w.__opts__()[:queue] == fila_da_coleta
      end)

    assert na_fila_da_coleta == [], """
    Estes workers do Cron estão na fila da coleta (#{inspect(fila_da_coleta)}): #{inspect(na_fila_da_coleta)}.

    Com as vagas ocupadas por coletas longas, eles não rodam, e o verificador da fila acusa
    parada com a fila trabalhando. Ponha-os numa fila própria.
    """
  end

  test "toda fila usada pelo Cron está configurada, com pelo menos uma vaga" do
    filas = oban_declarado()[:queues]

    for w <- workers_do_cron() do
      fila = w.__opts__()[:queue]

      assert Keyword.get(filas, fila, 0) >= 1,
             "#{inspect(w)} está na fila #{inspect(fila)}, que não tem vaga"
    end
  end
end
