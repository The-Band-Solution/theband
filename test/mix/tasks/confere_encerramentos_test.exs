defmodule Mix.Tasks.TheBand.ConfereEncerramentosTest do
  @moduledoc """
  O registro encerrado carrega a data do encerramento — feature 064, T007 e T008.

  Os dois lados são testados contra o mesmo defeito: um job `cancelled` sem `cancelled_at`, a
  forma exata dos quatro medidos no banco de desenvolvimento. A migração o conserta, a tarefa o
  denuncia — e a reinjeção prova que a tarefa não é um verificador que nunca falha.
  """
  use TheBand.DataCase, async: false

  alias Mix.Tasks.Gates
  alias Mix.Tasks.TheBand.ConfereEncerramentos, as: Tarefa
  alias TheBand.Repo

  @migracao "priv/repo/migrations/20260928200000_preenche_datas_de_encerramento.exs"
  @modulo TheBand.Repo.Migrations.PreencheDatasDeEncerramento

  # Com a forma de um token do GitHub, montado para não existir como literal no repositório.
  @token "gh" <> "p_" <> String.duplicate("E", 32) <> "fim!"

  setup_all do
    # O `mix test` roda `ecto.migrate` antes, e o módulo pode já estar carregado.
    unless Code.ensure_loaded?(@modulo), do: Code.require_file(@migracao)
    :ok
  end

  # Grava direto na tabela, como o cancelamento feito por fora que produziu os quatro.
  defp job(estado, colunas) do
    base = %{
      "cancelled_at" => nil,
      "discarded_at" => nil,
      "attempted_at" => ~N[2026-09-04 09:29:02],
      "scheduled_at" => ~N[2026-09-04 09:29:01]
    }

    c = Map.merge(base, colunas)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO oban_jobs (state, queue, worker, args, errors, attempt, max_attempts,
                               inserted_at, scheduled_at, attempted_at, cancelled_at, discarded_at)
        VALUES ($1, 'ingestion', 'TheBand.Jobs.SyncGitHubEO', $2, $3, 1, 5,
                '2026-09-04 03:57:37', $4, $5, $6, $7)
        RETURNING id
        """,
        [
          estado,
          %{"token" => @token},
          [%{"error" => "graphql(#{@token})"}],
          c["scheduled_at"],
          c["attempted_at"],
          c["cancelled_at"],
          c["discarded_at"]
        ]
      )

    id
  end

  defp coluna(id, nome) do
    %{rows: [[v]]} = Repo.query!("SELECT #{nome} FROM oban_jobs WHERE id = $1", [id])
    v
  end

  defp nulos do
    %{rows: [[n]]} =
      Repo.query!("""
      SELECT count(*) FROM oban_jobs
       WHERE (state = 'cancelled' AND cancelled_at IS NULL)
          OR (state = 'discarded' AND discarded_at IS NULL)
      """)

    n
  end

  defp migrar(direcao) do
    sqls = if direcao == :up, do: @modulo.sql_up(), else: @modulo.sql_down()
    Enum.each(sqls, &Repo.query!/1)
  end

  describe "a tarefa (T008)" do
    test "sem registro terminal faltando data, sai com 0" do
      job("cancelled", %{"cancelled_at" => ~N[2026-09-04 09:30:00]})
      assert {0, _} = Tarefa.executar()
    end

    test "com um cancelado sem data, sai com 1 e diz qual, sem imprimir o segredo" do
      id = job("cancelled", %{})

      assert {1, texto} = Tarefa.executar()
      assert texto =~ "job #{id} · TheBand.Jobs.SyncGitHubEO · cancelled · cancelled_at nula"
      assert texto =~ "não serão apagados nunca"
      refute texto =~ @token, "o verificador virou mais uma cópia do segredo"
    end

    test "com um descartado sem data, também sai com 1" do
      id = job("discarded", %{})
      assert {1, texto} = Tarefa.executar()
      assert texto =~ "job #{id} · TheBand.Jobs.SyncGitHubEO · discarded · discarded_at nula"
    end

    test "reinjeção: anular a data faz sair 1, e devolvê-la faz voltar a 0" do
      id = job("cancelled", %{"cancelled_at" => ~N[2026-09-04 09:30:00]})
      assert {0, _} = Tarefa.executar()

      Repo.query!("UPDATE oban_jobs SET cancelled_at = NULL WHERE id = $1", [id])
      assert {1, _} = Tarefa.executar()

      Repo.query!("UPDATE oban_jobs SET cancelled_at = '2026-09-04 09:30:00' WHERE id = $1", [id])
      assert {0, _} = Tarefa.executar()
    end

    test "mais de 20 achados: mostra 20 e diz quantos faltam" do
      for _ <- 1..22, do: job("cancelled", %{})
      assert {1, texto} = Tarefa.executar()
      assert texto =~ "22 registro(s)"
      assert texto =~ "… e mais 2"
    end
  end

  describe "a migração (T007)" do
    test "ida e volta: zera os nulos, e o rollback devolve exatamente os que havia" do
      sem_data = job("cancelled", %{})
      descartado = job("discarded", %{})
      com_data = job("cancelled", %{"cancelled_at" => ~N[2026-09-04 08:00:00]})
      antes = nulos()
      assert antes == 2

      migrar(:up)
      assert nulos() == 0
      # A data mais tardia que o registro tem: attempted_at, e não inserted_at.
      assert coluna(sem_data, "cancelled_at") == ~N[2026-09-04 09:29:02.000000]
      assert coluna(descartado, "discarded_at") == ~N[2026-09-04 09:29:02.000000]
      # A data que já existia não é tocada, nem marcada.
      assert coluna(com_data, "cancelled_at") == ~N[2026-09-04 08:00:00.000000]
      refute Map.has_key?(coluna(com_data, "meta"), "064_preencheu")

      migrar(:down)
      assert nulos() == antes
      assert coluna(sem_data, "cancelled_at") == nil
      assert coluna(com_data, "cancelled_at") == ~N[2026-09-04 08:00:00.000000]
      refute Map.has_key?(coluna(sem_data, "meta"), "064_preencheu")
    end

    test "é idempotente: a segunda ida não muda nada" do
      id = job("cancelled", %{})
      migrar(:up)
      primeira = coluna(id, "cancelled_at")

      migrar(:up)
      assert coluna(id, "cancelled_at") == primeira
    end

    test "um job agendado no futuro e cancelado antes de rodar não ganha encerramento no futuro" do
      futuro = NaiveDateTime.add(NaiveDateTime.utc_now(), 30, :day)
      id = job("cancelled", %{"scheduled_at" => futuro, "attempted_at" => nil})

      migrar(:up)
      assert NaiveDateTime.compare(coluna(id, "cancelled_at"), NaiveDateTime.utc_now()) != :gt
    end
  end

  test "a tarefa está em `mix gates`, depois dos testes" do
    nomes = Enum.map(Gates.gates(), &elem(&1, 0))
    assert "encerramentos com data" in nomes

    assert Enum.find_index(nomes, &(&1 == "encerramentos com data")) >
             Enum.find_index(nomes, &(&1 == "testes"))
  end
end
