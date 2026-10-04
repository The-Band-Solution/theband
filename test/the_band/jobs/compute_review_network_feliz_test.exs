defmodule TheBand.Jobs.ComputeReviewNetworkFelizTest do
  @moduledoc """
  O caminho feliz do job da rede de revisão — feature 073, T019 (FR-011, FR-021; A10, A11, A16).

  ## As asserções que carregam este arquivo

  1. **A10, controle positivo**: com tenant e organização válidos, o job grava as três janelas — é
     o que dá sentido ao "nenhuma leitura gravada" dos casos de cancelamento;
  2. **A16**: o registro, capturado com o Logger **de fato** em `:info` (L69: `capture_log` com
     `level:` só filtra, e o `config/test.exs` desliga o nível antes de avaliar o argumento), não
     tem nome, login, par nem `person_id` — com nomes de teste óbvios;
  3. **A11**: a mensagem recebida pelo assinante tem só a organização e os ids das leituras.

  `async: false` porque o nível do Logger é global.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.ReviewNetworkFixtures

  alias TheBand.Jobs.ComputeReviewNetwork
  alias TheBand.ReviewNetwork
  alias TheBand.ReviewNetwork.Schemas.Reading

  setup do
    nivel = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: nivel) end)

    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)
    ana = pessoa(tenant, "Anastacia Nomeobvio")
    bia = pessoa(tenant, "Bianca Nomeobvio")
    agora = DateTime.utc_now(:second)
    cr = solicitacao(tenant, org.observed_repository_id, bia, DateTime.add(agora, -5 * 86_400))
    revisao(tenant, cr, ana, DateTime.add(agora, -4 * 86_400))

    %{tenant: tenant, org: org, ana: ana, bia: bia}
  end

  defp executar(ctx),
    do:
      ComputeReviewNetwork.perform(%Oban.Job{
        args: %{"tenant_id" => ctx.tenant.id, "organization_id" => ctx.org.organization.id}
      })

  test "A10, controle positivo: o caminho feliz grava as três janelas", ctx do
    assert executar(ctx) == :ok

    janelas =
      Repo.all(from r in Reading, where: r.tenant_id == ^ctx.tenant.id, select: r.window_days)

    assert Enum.sort(janelas) == [30, 90, 180]
  end

  test "A16: o registro tem contagens, e nem nome, nem login, nem par, nem person_id", ctx do
    log = capture_log(fn -> assert executar(ctx) == :ok end)

    assert log =~ "rede de revisão calculada"
    assert log =~ "window_days=90 reviews=1"

    for proibido <- [
          "Anastacia",
          "Bianca",
          "Nomeobvio",
          ctx.ana.login,
          ctx.bia.login,
          ctx.ana.id,
          ctx.bia.id
        ] do
      refute log =~ proibido, "o registro contém #{proibido}"
    end
  end

  test "A11: o aviso leva só a organização e os ids das leituras", ctx do
    :ok = ReviewNetwork.subscribe(ctx.tenant)
    assert executar(ctx) == :ok

    assert_receive {:review_network_ready, org_id, ids}
    assert org_id == ctx.org.organization.id
    assert length(ids) == 3

    gravados = Repo.all(from r in Reading, where: r.tenant_id == ^ctx.tenant.id, select: r.id)
    assert Enum.sort(ids) == Enum.sort(gravados)

    mensagem = inspect({:review_network_ready, org_id, ids})
    refute mensagem =~ ctx.ana.id
    refute mensagem =~ "Anastacia"
  end
end
