defmodule TheBand.ReviewNetwork.SliceTest do
  @moduledoc """
  O alcance aplicado à leitura — feature 073, T015 (US1), T023 (US2), T025 (US3).

  ## As asserções que carregam este arquivo (violação primeiro)

  1. **R1**: com Ana fora do alcance, a concentração não conta as revisões dela, e nenhum valor dela
     carrega id;
  2. **A7**: a visão de alcance parcial não tem campo que conte o que ficou fora;
  3. a amostra mínima: abaixo de 10 revisões, a concentração é ausente e as contagens ficam;
  4. **A5**: a linha da pessoa alcançada mostra o total dela, e o par de fora não vira linha nem
     número;
  5. **A6** (reescrito pela Q4): grupos de gente de fora não aparecem, nem em número nem em tamanho;
  6. **Q5**: exclusões, bot inclusive, só com alcance total.
  """
  use ExUnit.Case, async: true

  import TheBand.ReviewNetworkFixtures, only: [parametros: 0]

  alias TheBand.ReviewNetwork.Slice

  defp leitura(arestas, pessoas) do
    %{
      organization_id: "org",
      window_days: 90,
      window_start: ~U[2026-07-05 12:00:00Z],
      window_end: ~U[2026-10-03 12:00:00Z],
      computed_at: ~U[2026-10-03 12:00:00Z],
      edges:
        Enum.map(arestas, fn {r, a, n} ->
          %{"reviewer" => r, "author" => a, "change_requests" => n}
        end),
      people:
        Enum.map(pessoas, fn {id, recebidas} ->
          %{"id" => id, "received_change_requests" => recebidas}
        end),
      excluded_self_review: 2,
      excluded_bot_or_app: 3,
      excluded_unlinked: 1,
      # 076, T027: a leitura da versão 2 da regra avalia a conta da organização.
      excluded_organization_account: 4,
      knowledge_versions: %{"review.network.parameters" => 1}
    }
  end

  defp algumas(ids), do: {:algumas, MapSet.new(ids)}

  # Ana revisa 30 de Bia; Ciro revisa 6 de Bia e 4 de Ana; Dani revisa 5 de Bia.
  defp us1 do
    leitura(
      [{"ana", "bia", 30}, {"ciro", "bia", 6}, {"ciro", "ana", 4}, {"dani", "bia", 5}],
      [{"ana", 4}, {"bia", 36}, {"ciro", nil}, {"dani", nil}]
    )
  end

  describe "US1 — a concentração pelo recorte" do
    test "com alcance total, a rede inteira: 30 de 45, sem nome" do
      v = Slice.view(us1(), :todas, parametros(), [])

      assert v.reach == :total
      assert {v.reviews, v.reviewers, v.authors} == {{:ok, 45}, {:ok, 3}, {:ok, 2}}

      assert {:ok, [%{k: 1, value: {:ok, %{reviews: 30, of: 45}}} | _]} = v.concentration
      refute inspect(v.concentration) =~ "ana"
    end

    test "R1: Ana fora do alcance não entra na concentração" do
      v = Slice.view(us1(), algumas(~w(bia ciro dani)), parametros(), [])

      assert v.reach == :parcial
      # Só Ciro→Bia (6) e Dani→Bia (5): 11 revisões, e a primeira é 6.
      assert v.reviews == {:ok, 11}
      assert {:ok, [%{k: 1, value: {:ok, %{reviews: 6, of: 11}}} | _]} = v.concentration
      refute inspect(v.concentration) =~ "ana"
    end

    test "A7: a visão de alcance parcial não tem campo que conte o que ficou fora" do
      v = Slice.view(us1(), algumas(~w(bia ciro dani)), parametros(), [])

      assert Map.keys(v) |> Enum.sort() ==
               Enum.sort([
                 :organization_id,
                 :window_days,
                 :window_start,
                 :window_end,
                 :computed_at,
                 :reach,
                 :reviews,
                 :reviewers,
                 :authors,
                 :concentration,
                 :people,
                 :groups,
                 :people_without_review_activity,
                 :exclusions,
                 :provenance
               ])

      refute inspect(v) =~ "ana"
    end

    test "abaixo da amostra mínima a concentração é ausente, e as contagens ficam" do
      v =
        Slice.view(leitura([{"ana", "bia", 5}, {"ciro", "bia", 4}], []), :todas, parametros(), [])

      assert v.reviews == {:ok, 9}
      assert v.concentration == {:ausente, {:sample_below_minimum, 10}}
    end

    test "com dois revisores, k = 3 é ausente, e não 100%" do
      v =
        Slice.view(leitura([{"ana", "bia", 6}, {"ciro", "bia", 4}], []), :todas, parametros(), [])

      assert {:ok, [_, %{k: 2}, %{k: 3, value: {:ausente, :fewer_reviewers_than_k}}]} =
               v.concentration
    end

    test "recorte sem revisão é ausente, e nunca 0%" do
      v = Slice.view(us1(), algumas(["bia"]), parametros(), [])

      # SC-002: ausência, e nunca 0, nas três contagens.
      assert v.reviews == {:ausente, :no_review_in_window}
      assert v.reviewers == {:ausente, :no_review_in_window}
      assert v.authors == {:ausente, :no_review_in_window}
      assert v.concentration == {:ausente, :no_review_in_window}
      assert v.groups == {:ausente, :no_review_in_window}
    end

    test "Q5: exclusões, as três, só com alcance total" do
      assert Slice.view(us1(), :todas, parametros(), []).exclusions ==
               {:ok,
                %{self_review: 2, bot_or_app: 3, organization_account: 4, unlinked_person: 1}}

      assert Slice.view(us1(), algumas(~w(ana bia)), parametros(), []).exclusions ==
               {:recortado, :regra}
    end

    test "#1308 (a): janela sem revisão nenhuma, nem excluída — exclusões ausentes, e não 0, 0, 0" do
      vazia =
        Map.merge(leitura([], []), %{
          excluded_self_review: 0,
          excluded_bot_or_app: 0,
          excluded_unlinked: 0,
          excluded_organization_account: 0
        })

      assert Slice.view(vazia, :todas, parametros(), []).exclusions ==
               {:ausente, :no_review_in_window}

      # Com revisão na janela, só que toda excluída, o zero de um motivo é contagem de verdade.
      so_bot = %{vazia | excluded_bot_or_app: 2}

      assert Slice.view(so_bot, :todas, parametros(), []).exclusions ==
               {:ok,
                %{self_review: 0, bot_or_app: 2, organization_account: 0, unlinked_person: 0}}
    end
  end

  describe "US2 — a linha da pessoa" do
    # Bia revisou 12 solicitações de 4 pessoas; teve 5 revisadas por 2. Pedro está fora do alcance.
    defp bia do
      leitura(
        [
          {"bia", "p1", 3},
          {"bia", "p2", 3},
          {"bia", "p3", 3},
          {"bia", "pedro", 3},
          {"r1", "bia", 3},
          {"r2", "bia", 2}
        ],
        [
          {"bia", 5},
          {"p1", 3},
          {"p2", 3},
          {"p3", 3},
          {"pedro", 3},
          {"r1", nil},
          {"r2", nil},
          {"caio", nil}
        ]
      )
    end

    test "Bia: o total dela é o verdadeiro, mesmo com um par fora do alcance (A5)" do
      v = Slice.view(bia(), algumas(~w(bia p1 p2 p3 r1 r2 caio)), parametros(), [])
      linha = Enum.find(v.people, &(&1.person_id == "bia"))

      assert linha.given == {:ok, %{reviews: 12, people: 4}}
      assert linha.received == {:ok, %{change_requests: 5, people: 2}}
      assert Enum.map(linha.reviews_of, & &1.person_id) == ~w(p1 p2 p3)
      assert linha.pairs_outside_reach? == true
      # #1308 (3.8): o par de fora é do lado de quem Bia revisou, e só dele.
      assert linha.reviews_of_outside_reach? == true
      assert linha.reviewed_by_outside_reach? == false
      refute inspect(linha) =~ "pedro"
      refute Enum.any?(v.people, &(&1.person_id == "pedro"))
    end

    test "Caio abriu e ninguém revisou: ausências, e não 0" do
      v = Slice.view(bia(), :todas, parametros(), [])
      caio = Enum.find(v.people, &(&1.person_id == "caio"))

      assert caio.given == {:ausente, :did_not_review_in_window}
      assert caio.received == {:ausente, :no_change_request_reviewed_in_window}
      assert caio.pairs_outside_reach? == false
    end

    test "pessoas sem atividade: só as alcançadas, fora da lista" do
      da_org = ~w(bia p1 zeca yuri)
      assert Slice.view(bia(), :todas, parametros(), da_org).people_without_review_activity == 2

      assert Slice.view(bia(), algumas(~w(bia zeca)), parametros(), da_org).people_without_review_activity ==
               1
    end
  end

  describe "US3 — os grupos do recorte" do
    defp grupos do
      leitura(
        [
          {"ana", "bia", 2},
          {"bia", "ciro", 2},
          {"ciro", "dani", 1},
          {"x", "y", 1},
          {"w", "z", 1},
          {"z", "v", 1}
        ],
        []
      )
    end

    test "com alcance total, todos os tamanhos" do
      assert Slice.view(grupos(), :todas, parametros(), []).groups == {:ok, [4, 3, 2]}
    end

    test "A6: grupos de gente de fora não aparecem, nem em número nem em tamanho" do
      v = Slice.view(grupos(), algumas(~w(ana bia ciro dani)), parametros(), [])
      assert v.groups == {:ok, [4]}
    end

    test "a pessoa que liga dois colegas, fora do alcance, os separa" do
      v = Slice.view(grupos(), algumas(~w(ana bia dani)), parametros(), [])
      assert v.groups == {:ok, [2]}
    end
  end
end
