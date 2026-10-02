defmodule TheBandWeb.FilaParadaTest do
  @moduledoc """
  O estado da fila em `/syncs` — issue #801, parte 3. Protótipo aprovado em 2026-10-01
  (`docs/producao/prototipo-fila-parada/`), com a avaliação de segurança ao lado.

  Os jobs são gravados direto em `oban_jobs`: é o estado que a tela lê, e não o comportamento
  do Oban.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Repo

  # CAPTURA, e não contagem: o `ContadorDeConsultas` ignora de propósito as tabelas do Oban, e a
  # reconferência consulta justamente `oban_jobs`. Conta só as consultas de `Saude.leitura/2`
  # (o `max(completed_at)` e o `min(scheduled_at)`). Registrado em
  # `test/contador_de_consultas_unico_test.exs`, na lista de capturas.
  defp conferencias_em(fun) do
    ref = make_ref()
    pai = self()

    :telemetry.attach(
      {__MODULE__, ref},
      [:the_band, :repo, :query],
      fn _e, _m, %{query: q}, _c ->
        if q =~ "oban_jobs" and (q =~ "max(" or q =~ "min("), do: send(pai, {ref, :conferencia})
      end,
      nil
    )

    fun.()
    :telemetry.detach({__MODULE__, ref})
    drenar(ref, 0)
  end

  defp drenar(ref, n) do
    receive do
      {^ref, :conferencia} -> drenar(ref, n + 1)
    after
      0 -> n
    end
  end

  setup %{conn: conn} do
    {_tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin)}
  end

  defp completado_ha(minutos) do
    em = NaiveDateTime.add(NaiveDateTime.utc_now(), -minutos * 60)

    Repo.query!(
      """
      INSERT INTO oban_jobs (state, queue, worker, args, attempt, max_attempts,
                             inserted_at, scheduled_at, completed_at)
      VALUES ('completed', 'manutencao', 'TheBand.Jobs.ReconcileStuckSyncs', '{}', 1, 3, $1, $1, $1)
      """,
      [em]
    )

    em
  end

  defp esperando_ha(minutos) do
    em = NaiveDateTime.add(NaiveDateTime.utc_now(), -minutos * 60)

    Repo.query!(
      """
      INSERT INTO oban_jobs (state, queue, worker, args, attempt, max_attempts, inserted_at, scheduled_at)
      VALUES ('available', 'ingestion', 'TheBand.Jobs.SyncGitHubEO', '{}', 0, 5, $1, $1)
      """,
      [em]
    )
  end

  test "fila andando: a linha discreta, sem o horário do último job (S2)", %{conn: conn} do
    em = completado_ha(2)
    {:ok, _live, html} = live(conn, ~p"/syncs")

    assert html =~ "Job queue moving"
    assert html =~ "checked"
    # O horário do último job pode ser de outra organização: não aparece com a fila andando.
    refute html =~ Calendar.strftime(em, "%H:%M")
    refute html =~ "The job queue has not moved"
  end

  test "instalação nova: a marca de ausência, sem aviso", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/syncs")
    assert html =~ "no job has run yet"
    refute html =~ "The job queue has not moved"
  end

  test "fila parada: o aviso com a duração, e Sync e Reprocess desabilitados com a razão (Q2)", %{
    conn: conn
  } do
    completado_ha(47)
    {:ok, _live, html} = live(conn, ~p"/syncs")

    assert html =~ "The job queue has not moved for 47 min"
    assert html =~ "What this means here"
    assert html =~ "What you can do"
    assert html =~ "why the queue stopped."
    assert html =~ "paused: reprocessing runs in the stalled queue"

    assert html =~
             ~r/<button[^>]*disabled[^>]*phx-click="reprocess"|phx-click="reprocess"[^>]*disabled/s

    # D3: nada que identifique fila, worker ou contagem.
    refute html =~ "ReconcileStuckSyncs"
    refute html =~ "manutencao"
  end

  test "nunca completou, e há job esperando há 20 min: o outro título", %{conn: conn} do
    esperando_ha(20)
    {:ok, _live, html} = live(conn, ~p"/syncs")

    assert html =~ "No job has ever finished here, and work has waited 20 min"
    assert html =~ "none on this installation"
    assert html =~ "why the queue never started."
  end

  describe "a reconferência (D4, achado S4)" do
    setup do
      Application.put_env(:the_band, :reconferir_fila_ms, 40)
      on_exit(fn -> Application.delete_env(:the_band, :reconferir_fila_ms) end)
    end

    test "o aviso some sozinho quando um job completa", %{conn: conn} do
      completado_ha(47)
      {:ok, live, html} = live(conn, ~p"/syncs")
      assert html =~ "The job queue has not moved"

      completado_ha(0)
      Process.sleep(120)
      refute render(live) =~ "The job queue has not moved"
      assert render(live) =~ "Job queue moving"
    end

    test "eventos da coleta não multiplicam o timer: a conferência continua custando o mesmo", %{
      conn: conn
    } do
      completado_ha(1)
      {:ok, live, _html} = live(conn, ~p"/syncs")

      # Vinte eventos que fazem a tela recarregar. Se cada um armasse um timer, a janela abaixo
      # veria dezenas de conferências, e não duas ou três.
      for _ <- 1..20, do: send(live.pid, {:sync_finished, Ecto.UUID.generate()})
      _ = render(live)

      n = conferencias_em(fn -> Process.sleep(130) end)

      # Com UM timer de 40 ms, 130 ms dão três conferências, cada uma com até duas consultas.
      assert n > 0, "nenhuma conferência observada: o teste não mediu nada"

      assert n <= 8,
             "#{n} consultas da conferência em 130 ms: o timer está sendo rearmado fora do handle_info"
    end
  end
end
