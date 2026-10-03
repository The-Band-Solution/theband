defmodule TheBand.Changes.ChangeRequestAuthorsTest do
  @moduledoc """
  `Changes.change_request_authors/3` — feature 073, T009. Quem abriu solicitação na janela, com
  pessoa ligada: é o que põe na rede quem abriu e ninguém revisou (US2, cenário 2).
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.Changes

  @desde ~U[2026-07-01 00:00:00Z]

  test "o autor sem revisão aparece; o de outro tenant e o sem pessoa ligada, não" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    org1 = organizacao_com_repositorio(t1)
    org2 = organizacao_com_repositorio(t2)
    caio = pessoa(t1, "Caio")
    de_fora = pessoa(t2, "Fora")

    solicitacao(t1, org1.observed_repository_id, caio, ~U[2026-09-01 10:00:00Z])
    solicitacao(t1, org1.observed_repository_id, caio, ~U[2026-09-04 10:00:00Z])
    solicitacao(t1, org1.observed_repository_id, {:login, "sem-pessoa"}, ~U[2026-09-01 10:00:00Z])
    solicitacao(t1, org1.observed_repository_id, pessoa(t1, "Antiga"), ~U[2026-05-01 10:00:00Z])
    solicitacao(t2, org2.observed_repository_id, de_fora, ~U[2026-09-01 10:00:00Z])

    autores =
      Changes.change_request_authors(
        t1,
        [org1.observed_repository_id, org2.observed_repository_id],
        since: @desde
      )

    assert autores == [%{author_person_id: caio.id, last_opened_at: ~U[2026-09-04 10:00:00Z]}]
  end
end
