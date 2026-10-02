defmodule TheBand.Platform.MigracaoDoEpisodioTest do
  @moduledoc """
  A migração do episódio — spec 070, T044 (`data-model.md` §4 e §7; SC-002). O round trip
  `migrate` / `rollback` é medido fora do sandbox, numa base própria (registrado no PR); aqui, a
  conferência de dados que o `up` roda.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Platform.Suspension
  alias TheBand.Tenants.Tenant

  @migracao TheBand.Repo.Migrations.EpisodioDeSuspensao

  setup do
    unless Code.ensure_loaded?(@migracao),
      do: Code.require_file("priv/repo/migrations/20261002140000_episodio_de_suspensao.exs")

    :ok
  end

  defp sc002 do
    Repo.query!("""
    SELECT count(*) FROM tenants t
    WHERE t.status = 'suspended'
      AND NOT EXISTS (SELECT 1 FROM tenant_suspensions s
                      WHERE s.tenant_id = t.id AND s.reactivated_at IS NULL)
    """).rows
  end

  test "a organização suspensa antes da feature ganha um episódio not_recorded, sem autor" do
    suspensa = tenant_fixture()
    ativa = tenant_fixture()

    # À mão, como estava em produção: sem episódio. O trigger adiado de T044a não confere no
    # sandbox, que nunca faz COMMIT.
    Repo.update_all(from(t in Tenant, where: t.id == ^suspensa.id), set: [status: "suspended"])
    assert sc002() == [[1]]

    assert @migracao.registrar_nao_registradas!(Repo) == 1
    assert sc002() == [[0]]

    [episodio] = Repo.all(from s in Suspension, where: s.tenant_id == ^suspensa.id)
    assert episodio.suspend_reason == "not_recorded"
    assert episodio.suspended_by_operator_id == nil
    assert episodio.reactivated_at == nil

    assert Repo.all(from s in Suspension, where: s.tenant_id == ^ativa.id) == []

    # Rodar de novo não duplica: a organização já tem o episódio aberto.
    assert @migracao.registrar_nao_registradas!(Repo) == 0
  end
end
