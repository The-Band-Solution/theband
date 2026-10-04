defmodule TheBand.Quality.ReviewPairsTest do
  @moduledoc """
  `Quality.review_pairs/3` — feature 073, T008 (`contracts/fronteiras.md`; R3, R4, R12 da
  segurança; cenários A1 e A2).

  ## As asserções que carregam este arquivo (violação primeiro)

  1. **A1**: nada de outro tenant entra, com dois tenants povoados nas mesmas datas;
  2. **A2**: a avaliação de T2 apontando para a solicitação de T1 (a FK simples permite) não entra;
  3. a lista de estados é de **inclusão**: estado fora dela e rascunho não entram;
  4. três avaliações da mesma conta na mesma solicitação são **um** par.

  Toda asserção de ausência vem depois de uma de presença: um `refute` sobre lista vazia passaria
  com a consulta quebrada (L50).
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.Quality

  @estados ~w(APPROVED CHANGES_REQUESTED COMMENTED DISMISSED)
  @desde ~U[2026-07-01 00:00:00Z]
  @dia ~U[2026-09-01 10:00:00Z]

  defp cenario do
    tenant = tenant_fixture()
    org = organizacao_com_repositorio(tenant)
    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    cr = solicitacao(tenant, org.observed_repository_id, bia, ~U[2026-08-30 10:00:00Z])
    revisao(tenant, cr, ana, @dia)
    %{tenant: tenant, org: org, ana: ana, bia: bia, cr: cr}
  end

  defp pares(%{tenant: tenant, org: org}),
    do:
      Quality.review_pairs(tenant, [org.observed_repository_id], since: @desde, states: @estados)

  test "A1: nada de outro tenant entra" do
    t1 = cenario()
    t2 = cenario()

    assert [%{reviewer_person_id: ana, author_person_id: bia}] = pares(t1)
    assert {ana, bia} == {t1.ana.id, t1.bia.id}

    # Uma avaliação gravada em T1 sobre a solicitação de T2 (a FK simples permite): a solicitação
    # é de outro tenant, e só o filtro de `c.tenant_id` a segura.
    revisao(t1.tenant, t2.cr, t1.ana, ~U[2026-09-02 10:00:00Z])

    # A leitura de T1 pedindo o repositório de T2 não devolve nada de T2.
    misturado =
      Quality.review_pairs(
        t1.tenant,
        [t1.org.observed_repository_id, t2.org.observed_repository_id],
        since: @desde,
        states: @estados
      )

    assert length(misturado) == 1
    refute Enum.any?(misturado, &(&1.reviewer_person_id == t2.ana.id))
  end

  test "A2: a avaliação de outro tenant que aponta para a solicitação deste não entra" do
    t1 = cenario()
    t2 = cenario()

    # A FK de avaliação para solicitação é simples: nada no banco impede isto.
    revisao(t2.tenant, t1.cr, t2.ana, ~U[2026-09-02 10:00:00Z])

    assert [par] = pares(t1)
    assert par.reviewer_person_id == t1.ana.id
  end

  test "estados são lista de inclusão, e rascunho não entra" do
    c = cenario()
    carla = pessoa(c.tenant, "Carla")
    dani = pessoa(c.tenant, "Dani")
    revisao(c.tenant, c.cr, carla, @dia, %{state: "ESTADO_NOVO_DA_ORIGEM"})
    revisao(c.tenant, c.cr, dani, nil, %{state: "PENDING"})

    assert [%{reviewer_person_id: id}] = pares(c)
    assert id == c.ana.id
  end

  test "três avaliações da mesma conta na mesma solicitação são um par, com o envio mais recente" do
    c = cenario()
    revisao(c.tenant, c.cr, c.ana, ~U[2026-09-03 10:00:00Z], %{state: "COMMENTED"})
    revisao(c.tenant, c.cr, c.ana, ~U[2026-09-05 10:00:00Z], %{state: "CHANGES_REQUESTED"})

    assert [%{last_submitted_at: ~U[2026-09-05 10:00:00Z]}] = pares(c)
  end

  test "a avaliação antes da janela não entra, e a conta não ligada vem com o login" do
    c = cenario()
    revisao(c.tenant, c.cr, pessoa(c.tenant, "Velha"), ~U[2026-06-01 10:00:00Z])
    revisao(c.tenant, c.cr, {:login, "prestador", "User"}, @dia)

    linhas = pares(c)
    assert length(linhas) == 2

    assert Enum.any?(
             linhas,
             &(&1.reviewer_login == "prestador" and is_nil(&1.reviewer_person_id))
           )
  end

  test "lista de repositórios vazia devolve vazio" do
    assert Quality.review_pairs(tenant_fixture(), [], since: @desde, states: @estados) == []
  end
end
