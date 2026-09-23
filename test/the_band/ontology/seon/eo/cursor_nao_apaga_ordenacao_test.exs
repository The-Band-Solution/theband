defmodule TheBand.Ontology.SEON.EO.CursorNaoApagaOrdenacaoTest do
  @moduledoc """
  O cursor da API pública e a ordenação da tela dividem a mesma função, e por isso um pode
  apagar o outro em silêncio.

  Foi o que aconteceu: ao ligar a paginação por cursor da feature 061, `list_people/2` e
  `list_teams/2` passaram a receber só `opts[:after]`, e o `opts[:order_by]` que quatro telas
  pedem — `people_live/index`, `people_live/show`, `teams_live/index`, `teams_live/show` —
  deixou de chegar. Nada falhava: a lista continuava vindo, ordenada por nome em vez da
  coluna escolhida. Quem clicasse no cabeçalho "Coletado em" veria a ordem não mudar.

  O defeito só apareceu porque o compilador avisou que uma cláusula ficara inalcançável. Um
  aviso não é uma guarda, e na próxima vez pode não haver aviso — estes testes são a guarda.

  Cobrem as duas travessias **e o encontro delas**: ordenação sem cursor, cursor sem
  ordenação, e o que acontece quando as duas opções chegam juntas.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  setup do
    tenant = tenant_fixture()

    # Nomes e datas em ordens DIFERENTES de propósito: por nome é Ana, Bruno, Célia; por
    # `collected_at` é Célia, Bruno, Ana. Se a ordenação for ignorada e cair no padrão por
    # nome, a asserção por data reprova. Com nomes e datas na mesma ordem o teste passaria
    # dos dois jeitos, e não provaria nada.
    for {uid, nome, login, dia} <- [
          {"U_1", "Ana Souza", "ana", ~U[2026-03-01 00:00:00Z]},
          {"U_2", "Bruno Lima", "bruno", ~U[2026-02-01 00:00:00Z]},
          {"U_3", "Célia Rocha", "celia", ~U[2026-01-01 00:00:00Z]}
        ] do
      {:ok, pessoa} =
        EO.upsert_person_from_source(tenant, source_attrs(uid, %{name: nome, login: login}))

      TheBand.Repo.update_all(
        from(p in TheBand.Ontology.SEON.EO.Schemas.Person, where: p.id == ^pessoa.id),
        set: [collected_at: dia]
      )
    end

    %{tenant: tenant}
  end

  describe "sem cursor, a ordem é a que a tela pede" do
    test "por nome, ascendente", %{tenant: tenant} do
      assert nomes(tenant, order_by: {:name, :asc}) == ["Ana Souza", "Bruno Lima", "Célia Rocha"]
    end

    test "por nome, descendente", %{tenant: tenant} do
      assert nomes(tenant, order_by: {:name, :desc}) == ["Célia Rocha", "Bruno Lima", "Ana Souza"]
    end

    test "por coleta — a coluna cuja ordem NÃO coincide com a do nome", %{tenant: tenant} do
      assert nomes(tenant, order_by: {:collected_at, :asc}) ==
               ["Célia Rocha", "Bruno Lima", "Ana Souza"]
    end

    test "sem opção alguma, cai no padrão da tela", %{tenant: tenant} do
      assert nomes(tenant) == ["Ana Souza", "Bruno Lima", "Célia Rocha"]
    end
  end

  describe "com cursor, a ordem é por id — e a travessia não repete nem perde" do
    test "`:inicio` percorre a coleção inteira, uma linha por vez, sem repetir", %{
      tenant: tenant
    } do
      vistas = percorrer(tenant, :inicio, [])

      assert length(vistas) == 3, "a travessia devolveu #{length(vistas)} de 3 pessoas"
      assert length(Enum.uniq(vistas)) == 3, "a travessia repetiu alguma linha"
      assert vistas == Enum.sort(vistas), "a travessia não saiu em ordem de id"
    end

    test "cursor ilegível recomeça do princípio em vez de estourar", %{tenant: tenant} do
      assert length(EO.list_people(tenant, after: "não-é-um-uuid", limit: 10)) == 3
    end
  end

  describe "as duas opções juntas" do
    test "o cursor vence a ordenação, e a travessia continua completa", %{tenant: tenant} do
      # Pedir ordem por nome E cursor é contraditório: o cursor só é estável sobre `id`.
      # O cursor tem de vencer — se a ordem por nome vencesse, a segunda página apontaria
      # para um ponto que a primeira ordem não conhece, e linhas sumiriam.
      vistas = percorrer(tenant, :inicio, order_by: {:name, :desc})

      assert vistas == Enum.sort(vistas), "com cursor, a ordem tem de ser por id"
      assert length(vistas) == 3
    end
  end

  defp nomes(tenant, opts \\ []), do: tenant |> EO.list_people(opts) |> Enum.map(& &1.name)

  # Percorre de uma em uma, como uma integração faria, e devolve os ids na ordem em que
  # vieram. Página de tamanho 1 é de propósito: é o tamanho que expõe repetição e perda.
  defp percorrer(tenant, cursor, opts, vistas \\ []) do
    case EO.list_people(tenant, Keyword.merge(opts, after: cursor, limit: 1)) do
      [] -> Enum.reverse(vistas)
      [p] -> percorrer(tenant, p.id, opts, [p.id | vistas])
    end
  end
end
