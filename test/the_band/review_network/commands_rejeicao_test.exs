defmodule TheBand.ReviewNetwork.CommandsRejeicaoTest do
  @moduledoc """
  A leitura da 073 recusada pelo banco não leva par de pessoas a lugar nenhum — feature 076, T004
  (R10 da segurança, cenário A18; L105).

  ## A corrida, reproduzida

  O caminho realista é a organização apagada **entre** a busca do job e a inserção da leitura. O
  teste o reproduz com um gatilho `BEFORE INSERT` que apaga a organização quando a primeira leitura
  vai ser gravada: a busca do job já passou, as arestas já foram montadas, e a chave estrangeira
  recusa a linha — a mesma violação que a corrida produz, sem depender de dois processos.

  O gatilho é DDL dentro da transação do sandbox, e some com ela. `async: false` porque o DDL
  trava a tabela até o fim do teste.

  ## As asserções que carregam este arquivo

  1. **controle**: a rede tem arestas, e os `person_id` delas estão no que seria gravado — sem
     isso, o `refute` não provaria nada (L50);
  2. `compute/4` devolve `{:error, {:reading_rejected, campos}}`, e o texto formatado do retorno não
     tem nenhum `person_id`;
  3. o job, executado pelo Oban, **cancela**, e o erro gravado em `oban_jobs.errors` não tem
     nenhum `person_id`.

  **Defeito a injetar**: voltar o `Repo.insert!` em `Commands.substituir/3`. O changeset recusado
  levanta `Ecto.InvalidChangesetError`, cuja mensagem traz os parâmetros — as arestas —, e as duas
  últimas asserções reprovam.
  """
  use TheBand.DataCase, async: false

  import TheBand.ReviewNetworkFixtures

  alias TheBand.Jobs.ComputeReviewNetwork
  alias TheBand.ReviewNetwork.Commands
  alias TheBand.ReviewNetwork.Schemas.Reading

  setup do
    Repo.query!("""
    CREATE FUNCTION pg_temp.apaga_organizacao_076_t004() RETURNS trigger AS $$
    BEGIN
      -- Só a linha da organização: os repositórios dela a referenciam sem cascata, e a corrida
      -- que importa é a da leitura. Desligar os gatilhos de FK vale só para este DELETE.
      PERFORM set_config('session_replication_role', 'replica', true);
      DELETE FROM eo_organizations WHERE id = NEW.organization_id;
      PERFORM set_config('session_replication_role', 'origin', true);
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER apaga_organizacao_076_t004 BEFORE INSERT ON review_network_readings
    FOR EACH ROW EXECUTE FUNCTION pg_temp.apaga_organizacao_076_t004()
    """)

    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)
    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    agora = DateTime.utc_now(:second)
    cr = solicitacao(tenant, org.observed_repository_id, bia, DateTime.add(agora, -5 * 86_400))
    revisao(tenant, cr, ana, DateTime.add(agora, -4 * 86_400))

    %{tenant: tenant, org: org, ids: [ana.id, bia.id], agora: agora}
  end

  defp sem_person_id(texto, ids) do
    for id <- ids, do: refute(texto =~ id, "o texto do erro contém o person_id #{id}")
  end

  test "controle: sem o gatilho, a leitura grava as arestas com os dois person_id", ctx do
    Repo.query!("DROP TRIGGER apaga_organizacao_076_t004 ON review_network_readings")

    assert {:ok, _} = Commands.compute(ctx.tenant, ctx.org.organization, ctx.agora, parametros())

    gravado = inspect(Repo.all(from r in Reading, select: r.edges))
    for id <- ctx.ids, do: assert(gravado =~ id)
  end

  test "A18: compute/4 devolve só os nomes dos campos recusados", ctx do
    resultado =
      try do
        Commands.compute(ctx.tenant, ctx.org.organization, ctx.agora, parametros())
      rescue
        e -> {:levantou, Exception.format(:error, e, __STACKTRACE__)}
      end

    texto =
      case resultado do
        {:levantou, formatado} -> formatado
        outro -> Exception.format(:error, outro, [])
      end

    sem_person_id(texto, ctx.ids)
    assert resultado == {:error, {:reading_rejected, [:organization_id]}}
  end

  test "A18: o job cancela, e o erro em oban_jobs.errors não tem person_id", ctx do
    {:ok, job} = ComputeReviewNetwork.enqueue(ctx.tenant.id, ctx.org.organization.id)

    resumo = Oban.drain_queue(queue: :transformation, with_safety: true)

    %Oban.Job{state: estado, errors: erros} = Repo.get!(Oban.Job, job.id)
    texto = inspect(erros)

    assert erros != [], "o Oban não gravou erro: a asserção abaixo não mediria nada"
    sem_person_id(texto, ctx.ids)
    assert estado == "cancelled"
    assert %{cancelled: 1} = resumo
    assert texto =~ "reading_rejected"
  end
end
