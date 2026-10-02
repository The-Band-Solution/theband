defmodule TheBand.SaudeTest do
  @moduledoc """
  A saúde da fila, fora do Oban — issue #801. Contrato em `docs/producao/saude-da-fila.md`.

  Os jobs são gravados direto em `oban_jobs`, sem passar pelo Oban: é o estado que o verificador
  lê, e não o comportamento da dependência. Cada teste fixa `agora`, para as bordas do limiar
  não dependerem do relógio.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Release
  alias TheBand.Repo
  alias TheBand.Saude

  @agora ~U[2026-09-30 12:00:00Z]

  defp minutos_antes(m), do: @agora |> DateTime.add(-m, :minute) |> DateTime.to_naive()

  defp job(estado, colunas) do
    Repo.query!(
      """
      INSERT INTO oban_jobs (state, queue, worker, args, attempt, max_attempts,
                             inserted_at, scheduled_at, completed_at)
      VALUES ($1, 'ingestion', 'TheBand.Jobs.ReconcileStuckSyncs', '{}', 1, 3, $2, $3, $4)
      """,
      [
        estado,
        colunas[:inserido] || minutos_antes(60),
        colunas[:agendado] || minutos_antes(60),
        colunas[:completado]
      ]
    )
  end

  describe "a regra" do
    test "o último completado há 14 minutos: ok" do
      job("completed", completado: minutos_antes(14))
      assert Saude.fila(@agora, 15) == :ok
    end

    test "o último completado há 16 minutos: parada, com os minutos" do
      job("completed", completado: minutos_antes(16))
      assert Saude.fila(@agora, 15) == {:parada, 16}
    end

    test "vale o MAIS RECENTE: um antigo e um novo dá ok" do
      job("completed", completado: minutos_antes(600))
      job("completed", completado: minutos_antes(2))
      assert Saude.fila(@agora, 15) == :ok
    end

    test "nunca completou nada, e há job esperando há 20 minutos: parada" do
      # É o banco onde o Oban nunca rodou. Sem esta regra ele estaria verde para sempre.
      job("available", agendado: minutos_antes(20))
      assert Saude.fila(@agora, 15) == {:parada, 20}
    end

    test "nunca completou nada, e o que espera é recente: ok" do
      job("available", agendado: minutos_antes(3))
      assert Saude.fila(@agora, 15) == :ok
    end

    test "instalação nova, sem job nenhum: ok" do
      assert Saude.fila(@agora, 15) == :ok
    end
  end

  describe "leitura/2 — o que a tela /syncs precisa (Q3)" do
    test "andando: o último completado e a hora da conferência, sem causa" do
      job("completed", completado: minutos_antes(3))
      l = Saude.leitura(@agora, 15)

      assert l.estado == :andando
      assert l.causa == nil
      assert DateTime.compare(l.ultimo_completado_em, DateTime.add(@agora, -3, :minute)) == :eq
      assert l.conferido_em == @agora
    end

    test "parada pelo último completado: a causa e os minutos" do
      job("completed", completado: minutos_antes(47))
      l = Saude.leitura(@agora, 15)

      assert %{estado: :parada, causa: :ultimo_completado, parada_ha_minutos: 47} = l
      assert l.esperando_desde == nil
    end

    test "parada sem histórico: a causa é o job esperando mais antigo" do
      job("available", agendado: minutos_antes(20))
      l = Saude.leitura(@agora, 15)

      assert %{estado: :parada, causa: :esperando_mais_antigo, parada_ha_minutos: 20} = l
      assert l.ultimo_completado_em == nil
      assert DateTime.compare(l.esperando_desde, DateTime.add(@agora, -20, :minute)) == :eq
    end

    test "sem histórico e sem espera longa: :sem_historico, que não é parada nem andando" do
      assert %{estado: :sem_historico, causa: nil} = Saude.leitura(@agora, 15)

      job("available", agendado: minutos_antes(3))
      assert %{estado: :sem_historico, esperando_desde: %DateTime{}} = Saude.leitura(@agora, 15)
    end

    test "S3: só o agregado escalar, sem nada que identifique tenant, worker ou contagem" do
      # Dois tenants com jobs na mesma tabela, com o tenant nos `args`, como a coleta grava.
      for t <- [Ecto.UUID.generate(), Ecto.UUID.generate()] do
        Repo.query!(
          """
          INSERT INTO oban_jobs (state, queue, worker, args, attempt, max_attempts,
                                 inserted_at, scheduled_at, completed_at)
          VALUES ('completed', 'ingestion', 'TheBand.Jobs.SyncGitHubEO', $1, 1, 5, $2, $2, $2)
          """,
          [%{"tenant_id" => t}, minutos_antes(30)]
        )
      end

      l = Saude.leitura(@agora, 15)

      assert Enum.sort(Map.keys(l)) ==
               Enum.sort([
                 :estado,
                 :causa,
                 :ultimo_completado_em,
                 :esperando_desde,
                 :parada_ha_minutos,
                 :conferido_em
               ])

      texto = inspect(l)
      refute texto =~ "SyncGitHubEO"
      refute texto =~ "tenant"
      refute texto =~ "ingestion"
    end

    test "fila/2 e leitura/2 dão o mesmo veredito, porque uma sai da outra" do
      for minutos <- [1, 14, 15, 16, 600] do
        Repo.query!("DELETE FROM oban_jobs")
        job("completed", completado: minutos_antes(minutos))

        parada? = Saude.leitura(@agora, 15).estado == :parada
        assert parada? == match?({:parada, _}, Saude.fila(@agora, 15))
      end
    end
  end

  describe "as portas" do
    test "GET /health responde 200 ok com a fila andando", %{conn: conn} do
      job("completed", completado: NaiveDateTime.utc_now())
      conn = get(conn, ~p"/health")
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "GET /health responde 503, e não diz mais do que o estado", %{conn: conn} do
      job("completed", completado: NaiveDateTime.add(NaiveDateTime.utc_now(), -3600))
      conn = get(conn, ~p"/health")
      assert conn.status == 503
      # Sem minutos, fila ou worker: a rota não tem sessão.
      assert conn.resp_body == "queue stalled"
    end

    test "sem sessão, a rota responde, como /version", %{conn: conn} do
      assert get(conn, ~p"/health").status in [200, 503]
    end

    test "a função da release devolve a palavra que o healthcheck procura" do
      job("completed", completado: NaiveDateTime.utc_now())
      assert Release.saude_da_fila() == "ok"

      Repo.query!("DELETE FROM oban_jobs")
      job("completed", completado: NaiveDateTime.add(NaiveDateTime.utc_now(), -3600))
      assert Release.saude_da_fila() == "parada"
    end

    test "o HEALTHCHECK do Dockerfile chama a função, e não o Postgres" do
      # Lê o arquivo sem os comentários: o comentário cita a função e não é o comando.
      comando =
        "Dockerfile"
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.join("\n")

      assert comando =~
               ~r/HEALTHCHECK[^\n]*\\\n\s+CMD .*TheBand\.Release\.saude_da_fila\(\).*grep -qx ok/
    end
  end
end
