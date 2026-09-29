defmodule TheBand.Jobs.ApagaSessoesAntigasTest do
  @moduledoc """
  A retenção das sessões — feature 064, T020, decisão P3. Contrato em
  `specs/064-segredo-em-repouso/contracts/retencao-de-sessoes.md`.

  As quatro bordas: 89 e 91 dias depois de encerrada; 96 e 98 dias depois de aberta, para a
  sessão que venceu sem ninguém a encerrar. É a segunda que a FR-015 exige: sem ela, a vencida
  seria permanente.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Jobs.ApagaSessoesAntigas
  alias TheBand.Repo
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.User
  alias TheBandWeb.ConnCase

  @agora ~U[2026-12-31 12:00:00Z]

  setup do
    {_tenant, admin} = ConnCase.tenant_with_admin()
    %{user: Repo.get!(User, admin.id)}
  end

  defp dias_antes(dias), do: DateTime.add(@agora, -dias, :day)

  # Uma sessão com os carimbos que o teste pede.
  defp sessao(user, carimbos) do
    {:ok, {s, _segredo}} = Sessions.abrir(user)

    Repo.update_all(from(x in UserSession, where: x.id == ^s.id), set: carimbos)
    s.id
  end

  defp existe?(id), do: Repo.get(UserSession, id) != nil

  test "encerrada há 91 dias sai; há 89 fica", %{user: user} do
    velha = sessao(user, inserted_at: dias_antes(95), ended_at: dias_antes(91))
    recente = sessao(user, inserted_at: dias_antes(95), ended_at: dias_antes(89))

    assert {:ok, 1} = Sessions.apagar_as_que_deixaram_de_valer(@agora)
    refute existe?(velha)
    assert existe?(recente)
  end

  test "vencida sem encerramento: aberta há 98 dias sai; há 96 fica", %{user: user} do
    velha = sessao(user, inserted_at: dias_antes(98))
    recente = sessao(user, inserted_at: dias_antes(96))

    assert {:ok, 1} = Sessions.apagar_as_que_deixaram_de_valer(@agora)
    refute existe?(velha)
    assert existe?(recente)
  end

  test "a sessão aberta e válida nunca é apagada", %{user: user} do
    viva = sessao(user, inserted_at: dias_antes(1))

    assert {:ok, 0} = Sessions.apagar_as_que_deixaram_de_valer(@agora)
    assert existe?(viva)
  end

  test "o worker roda a mesma regra, e o Cron o agenda todo dia" do
    assert :ok = ApagaSessoesAntigas.perform(%Oban.Job{args: %{}})

    crontab =
      "config/config.exs"
      |> Config.Reader.read!(env: :prod)
      |> get_in([:the_band, Oban, :plugins])
      |> Enum.find_value(fn
        {Oban.Plugins.Cron, opts} -> opts[:crontab]
        _ -> nil
      end)

    assert {"0 4 * * *", ApagaSessoesAntigas} in crontab
  end
end
