defmodule TheBandWeb.Api.V1.TetoDeConsultasTest do
  @moduledoc """
  **O custo de uma requisição não cresce com o tamanho da coleção.** T020.

  ## Por que um teto não basta, e a igualdade basta

  Um teto (`< 15`) responde "está caro?". A pergunta que importa é outra: **"fica mais caro
  quando a base cresce?"**. Uma consulta por linha passa num teto folgado com dez linhas e
  derruba a rota com mil — e o dia em que derruba é o dia em que a coleta funcionou.

  Por isso a asserção é `dez == cem`, e não `cem < N`. O número exato pode mudar quando
  alguém acrescentar uma leitura de propósito; o que não pode mudar é a **inclinação**.

  ## O caminho que recria o problema

  É a **L38**: perguntar por item em vez de perguntar pela coleção. `access.ex` diz com
  todas as letras que `pessoas_alcancadas/2` existe para evitá-la. Na prática ela volta
  de três jeitos:

  - um `Repo.preload` dentro de um `Enum.map`;
  - `EO.organizations_by_person(tenant, [uma_pessoa])` chamado por linha;
  - `Enum.map(pagina, &EO.current_profile(tenant, &1.id))` no lugar de `current_profiles/2`.

  Os três passam em qualquer teste de corpo. Só a contagem os vê.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.ContadorDeConsultas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "custo"}, admin)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin}
  end

  # Cada equipe na sua organização: é o pior caso, e o que uma consulta por linha
  # exploraria. Equipes todas na mesma organização esconderiam o defeito.
  defp equipes(tenant, n) do
    for i <- 1..n do
      org = organization_fixture(tenant, "org#{i}-#{System.unique_integer([:positive])}")
      team_fixture(tenant, "T_#{i}_#{System.unique_integer([:positive])}", %{organization: org})
    end
  end

  # Cada pessoa com organização própria, pelo caminho real: organização → equipe →
  # evidência de vínculo. É o que faz `organizations_by_person/2` ter trabalho de verdade.
  defp pessoas(tenant, n) do
    for i <- 1..n do
      u = System.unique_integer([:positive])

      {:ok, p} =
        EO.upsert_person_from_source(tenant, %{
          login: "p#{i}-#{u}",
          name: "Pessoa #{i}",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_#{i}_#{u}",
          collected_at: DateTime.utc_now(:second)
        })

      org = organization_fixture(tenant, "po#{i}-#{u}")
      equipe = team_fixture(tenant, "PT_#{i}_#{u}", %{organization: org})

      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: p.id,
          team_id: equipe.id,
          person_external_id: p.external_id,
          team_external_id: "PT_#{i}_#{u}",
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })

      p
    end
  end

  # Mede a rota e devolve as assinaturas, para que a falha diga **o que** entrou.
  defp consultas(conn, rota) do
    ContadorDeConsultas.listar(fn ->
      assert conn |> get(rota) |> Map.fetch!(:status) == 200
    end)
  end

  defp diferenca(a, b) do
    (b -- a) |> Enum.frequencies() |> Enum.map_join(", ", fn {q, n} -> "#{q}×#{n}" end)
  end

  describe "GET /api/v1/teams" do
    test "o custo é o mesmo com 1, 10 e 100 equipes", ctx do
      rota = ~p"/api/v1/teams?page_size=200"

      equipes(ctx.tenant, 1)
      minimo = consultas(ctx.conn, rota)

      equipes(ctx.tenant, 9)
      dez = consultas(ctx.conn, rota)

      equipes(ctx.tenant, 90)
      cem = consultas(ctx.conn, rota)

      assert minimo != [], "nenhuma consulta observada — o contador está medindo o vazio"

      assert length(dez) == length(cem), """
      O custo cresceu entre dez e cem equipes: #{length(dez)} → #{length(cem)}.

      Entrou: #{diferenca(dez, cem)}

      É a L38 — pergunta por item em vez de pergunta pela coleção. Costuma voltar como um
      `Repo.preload` dentro de um `Enum.map`, ou como a forma em lote chamada com uma
      lista de um elemento.
      """

      assert length(cem) == length(minimo), """
      O custo cresceu entre o caso mínimo e cem equipes: #{length(minimo)} → #{length(cem)}.

      Entrou: #{diferenca(minimo, cem)}
      """
    end

    test "e a página realmente trouxe as cem — senão a igualdade seria de listas vazias", ctx do
      equipes(ctx.tenant, 100)

      corpo = ctx.conn |> get(~p"/api/v1/teams?page_size=200") |> json_response(200)

      assert length(corpo["data"]) == 100,
             "a medição acima percorreria uma página curta, e não a coleção"
    end
  end

  describe "GET /api/v1/people" do
    test "o custo é o mesmo com 1, 10 e 100 pessoas — cada uma com organização", ctx do
      rota = ~p"/api/v1/people?page_size=200"

      pessoas(ctx.tenant, 1)
      minimo = consultas(ctx.conn, rota)

      pessoas(ctx.tenant, 9)
      dez = consultas(ctx.conn, rota)

      pessoas(ctx.tenant, 90)
      cem = consultas(ctx.conn, rota)

      assert minimo != [], "nenhuma consulta observada — o contador está medindo o vazio"

      assert length(dez) == length(cem), """
      O custo cresceu entre dez e cem pessoas: #{length(dez)} → #{length(cem)}.

      Entrou: #{diferenca(dez, cem)}

      Esta rota lê duas coisas por página, e as duas têm forma em lote:
      `EO.organizations_by_person/2` e `EO.current_profiles/2`. Chamar qualquer uma por
      linha reintroduz a L38 e aparece aqui, e em nenhum teste de corpo.
      """

      assert length(cem) == length(minimo), """
      O custo cresceu entre o caso mínimo e cem pessoas: #{length(minimo)} → #{length(cem)}.

      Entrou: #{diferenca(minimo, cem)}
      """
    end

    test "e a página realmente trouxe as cem", ctx do
      pessoas(ctx.tenant, 100)

      corpo = ctx.conn |> get(~p"/api/v1/people?page_size=200") |> json_response(200)

      assert length(corpo["data"]) == 100

      assert Enum.all?(corpo["data"], &(&1["organizations"] != [])),
             "sem organização, a leitura em lote não teria trabalho"
    end
  end
end
