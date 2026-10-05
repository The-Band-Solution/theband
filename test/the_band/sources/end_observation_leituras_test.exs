defmodule TheBand.Sources.EndObservationLeiturasTest do
  @moduledoc """
  Encerrar a observação apaga as leituras derivadas da organização — feature 076, T052 (R18 de
  `seguranca.md`; `contracts/fronteiras.md`, `Sources`).

  As leituras da rede de revisão (073) e da análise de rede (076) guardam ids de pessoa. Desde a
  T028 elas são gravadas em `development`; a observação encerrada não pode deixá-las para trás.

  - só as da organização encerrada, e só daquele tenant: outra organização do mesmo tenant e a
    organização de mesmo login de outro tenant mantêm as suas (L19);
  - uma falha dentro da transação do encerramento não apaga nada.

  **Defeito a injetar**: apagar por `tenant_id` só; a leitura da outra organização do mesmo tenant
  some e o primeiro caso reprova.

  `async: false`: o caso da falha cria um gatilho em `tool_credentials`, e o gatilho não
  confirmado prende a tabela até o fim do teste.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.ReviewNetworkFixtures

  alias TheBand.NetworkAnalysis.Commands, as: AnalysisCommands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Schemas.Reading, as: AnalysisReading
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.ReviewNetwork
  alias TheBand.ReviewNetwork.Schemas.Reading, as: ReviewReading
  alias TheBand.Sources

  setup do
    {:ok, _} = KnowledgeBase.load()
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    login = "org-#{System.unique_integer([:positive])}"

    encerrada = observada_com_leituras(t1, login)
    vizinha = observada_com_leituras(t1, nil)
    outro_tenant = observada_com_leituras(t2, login)

    %{t1: t1, t2: t2, login: login, encerrada: encerrada, vizinha: vizinha, outra: outro_tenant}
  end

  # Uma organização observada, com as leituras das duas features gravadas pelos seus comandos.
  defp observada_com_leituras(tenant, login) do
    %{organization: org, tool: tool} = organizacao_com_repositorio(tenant, login)
    [ana, bia] = for n <- ~w(Ana Bia), do: pessoa(tenant, "#{n} Encerra")
    agora = DateTime.utc_now(:second)

    {:ok, _} = ReviewNetwork.compute(tenant, org, agora)

    entrada = %{
      edges: [%{source: ana.id, target: bia.id, weight: 1}],
      exclusions: %{"issues" => 1},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, [_ | _]} =
      AnalysisCommands.compute(tenant, org, agora, Parameters.fetch!(), fn _, _, _ ->
        {:ok, entrada}
      end)

    %{org: org, tool: tool}
  end

  defp leituras(tenant, org) do
    {
      Repo.aggregate(
        from(r in ReviewReading,
          where: r.tenant_id == ^tenant.id and r.organization_id == ^org.id
        ),
        :count
      ),
      Repo.aggregate(
        from(r in AnalysisReading,
          where: r.tenant_id == ^tenant.id and r.organization_id == ^org.id
        ),
        :count
      )
    }
  end

  test "apaga as leituras das duas features só da organização encerrada, e só deste tenant",
       ctx do
    {revisao, analise} = leituras(ctx.t1, ctx.encerrada.org)

    assert revisao > 0 and analise > 0,
           "o teste precisa de leituras gravadas para provar alguma coisa"

    antes_vizinha = leituras(ctx.t1, ctx.vizinha.org)
    antes_outra = leituras(ctx.t2, ctx.outra.org)

    {:ok, resultado} =
      Sources.end_observation(ctx.t1, ctx.encerrada.tool, %{"confirmation" => ctx.login})

    assert resultado.readings_discarded == %{review_network: revisao, network_analysis: analise}
    assert leituras(ctx.t1, ctx.encerrada.org) == {0, 0}
    assert leituras(ctx.t1, ctx.vizinha.org) == antes_vizinha
    assert leituras(ctx.t2, ctx.outra.org) == antes_outra
  end

  test "uma falha na transação do encerramento não apaga nada", ctx do
    antes = leituras(ctx.t1, ctx.encerrada.org)
    assert antes != {0, 0}

    # A destruição das credenciais vem depois das leituras; o gatilho a faz falhar, e a transação
    # inteira precisa ser desfeita.
    Repo.query!("""
    CREATE FUNCTION t052_recusa() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 't052: falha injetada'; END $$
    """)

    Repo.query!("""
    CREATE TRIGGER t052_recusa BEFORE DELETE ON tool_credentials
    FOR EACH STATEMENT EXECUTE FUNCTION t052_recusa()
    """)

    assert_raise Postgrex.Error, ~r/t052: falha injetada/, fn ->
      Sources.end_observation(ctx.t1, ctx.encerrada.tool, %{"confirmation" => ctx.login})
    end

    assert leituras(ctx.t1, ctx.encerrada.org) == antes
    refute Sources.observation_ended?(ctx.encerrada.tool)
  end
end
