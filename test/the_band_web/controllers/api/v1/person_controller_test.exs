defmodule TheBandWeb.Api.V1.PersonControllerTest do
  @moduledoc """
  `GET /api/v1/people` — a segunda rota da API pública.

  O que muda em relação a equipes: `account_type` é a palavra da origem, e
  `no_longer_observed_at` distingue *deixou de ser observada* de *nunca existiu*.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "teste"}, admin)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin}
  end

  defp pessoa(tenant, login, attrs \\ %{}) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        Map.merge(
          %{
            login: login,
            name: String.capitalize(login),
            account_type: "person",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "U_#{login}_#{System.unique_integer([:positive])}",
            collected_at: DateTime.utc_now(:second)
          },
          attrs
        )
      )

    p
  end

  # Dá organização a uma pessoa pelo caminho REAL: organização → equipe → evidência de
  # vínculo. Não há laço direto pessoa→organização nesta ontologia, e um atalho no teste
  # provaria um caminho que a aplicação não percorre.
  defp com_organizacao(tenant, pessoa, login_da_org) do
    org = organization_fixture(tenant, login_da_org)
    equipe = team_fixture(tenant, "T_#{login_da_org}", %{organization: org})

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: pessoa.external_id,
        team_external_id: "T_#{login_da_org}",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    org
  end

  describe "o corpo carrega o que a tela mostra" do
    test "as seis colunas da tela estão todas no corpo", ctx do
      ana = pessoa(ctx.tenant, "ana")
      com_organizacao(ctx.tenant, ana, "acme")

      assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

      # Coluna a coluna, na ordem em que `people_live/index` as desenha.
      assert p["name"] == "Ana", "coluna *name*"
      assert p["login"] == "ana", "coluna *name*, segunda linha"
      assert p["account_type"] == "person", "coluna *account type*"
      assert [%{"login" => "acme"}] = p["organizations"], "coluna *organisations*"
      assert p["source_system"] == "github", "coluna *source*"
      assert p["source_instance"] == "https://github.com", "coluna *source*, segunda linha"
      assert p["external_id"] == ana.external_id, "coluna *identifier at source*"
      assert p["collected_at"], "coluna *collected at*"
    end

    test "o email NÃO sai — a tela não o mostra, e ninguém o pediu", ctx do
      ana = pessoa(ctx.tenant, "ana", %{email: "ana@exemplo.org"})

      # Sem esta linha o teste passaria por vacuidade: se o upsert descartasse o email, não
      # haveria o que vazar, e o teste diria que o corpo o protege quando ele nem existe.
      assert ana.email == "ana@exemplo.org", "a pessoa precisa TER email para o teste valer"

      assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

      refute Map.has_key?(p, "email"),
             "dado pessoal que nenhum requisito pediu não pode vazar pelo corpo"
    end

    test "quem está em mais de uma organização sai UMA vez, com todas", ctx do
      ana = pessoa(ctx.tenant, "ana")
      com_organizacao(ctx.tenant, ana, "acme")
      com_organizacao(ctx.tenant, ana, "globex")

      assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

      assert Enum.map(p["organizations"], & &1["login"]) |> Enum.sort() == ["acme", "globex"]
    end

    test "quem não está em equipe alguma sai com a RAZÃO escrita, não com lista muda", ctx do
      pessoa(ctx.tenant, "sozinha")

      assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

      assert p["organizations"] == []

      assert p["organizations_note"] == "no team — organisation unknown",
             "lista vazia sem razão leria como *não tem organização*, e o que houve foi que " <>
               "o vínculo vem das equipes e ela não está em nenhuma"
    end

    test "quem TEM organização não carrega razão de ausência", ctx do
      ana = pessoa(ctx.tenant, "ana")
      com_organizacao(ctx.tenant, ana, "acme")

      assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

      assert p["organizations_note"] == nil
    end

    # Lição L38: a organização de cada linha não pode custar uma consulta por linha. Com 50
    # pessoas por página isso seriam 50 idas ao banco para desenhar uma resposta, e o custo
    # cresce com a coleta — foi o defeito que a função em lote existe para evitar.
    test "as organizações da página inteira custam UMA consulta", ctx do
      for i <- 1..10 do
        p = pessoa(ctx.tenant, "p#{i}")
        com_organizacao(ctx.tenant, p, "org#{i}")
      end

      {:ok, agente} = Agent.start_link(fn -> 0 end)

      :telemetry.attach(
        "conta-consultas-pessoas",
        [:the_band, :repo, :query],
        fn _e, _m, _md, _cfg -> Agent.update(agente, &(&1 + 1)) end,
        nil
      )

      ctx.conn |> get(~p"/api/v1/people") |> json_response(200)
      :telemetry.detach("conta-consultas-pessoas")

      consultas = Agent.get(agente, & &1)

      # PRIMEIRO: o contador contou alguma coisa. Se o nome do evento estiver errado ele
      # fica em zero, e `0 < 15` passaria para sempre, medindo nada. Um teto sozinho é a
      # forma mais fácil de escrever uma guarda que nunca reprova.
      assert consultas > 0,
             "nenhuma consulta observada — o evento de telemetria não é este, e o teto abaixo " <>
               "estaria medindo o vazio"

      # Teto, não número exato: autenticação e listagem também consultam. O que o teto pega
      # é o crescimento por linha — 10 pessoas em 10 organizações passariam de 20.
      assert consultas < 15,
             "#{consultas} consultas para 10 pessoas — sinal de consulta por linha"
    end
  end

  test "devolve as pessoas com a marca de origem e o tipo de conta", ctx do
    pessoa(ctx.tenant, "ana")

    assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

    assert p["login"] == "ana"
    assert p["origin"] == "observed"
    assert p["account_type"] == "person"
  end

  test "o tipo de conta é a PALAVRA DA ORIGEM, e robô não vira pessoa", ctx do
    pessoa(ctx.tenant, "ana")
    pessoa(ctx.tenant, "dependabot", %{account_type: "bot"})

    tipos =
      ctx.conn
      |> get(~p"/api/v1/people")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.map(& &1["account_type"])
      |> Enum.sort()

    assert tipos == ["bot", "person"], """
    O tipo de conta foi traduzido, achatado ou inferido.

    Contar robô como pessoa inflaria toda medida de quem fez o trabalho — numa coleta
    medida, 160 de 357 movimentações eram de robô. A origem diz o que a conta é, e a API
    repassa a palavra dela.
    """
  end

  test "nulo em no_longer_observed_at significa AINDA observada", ctx do
    pessoa(ctx.tenant, "ana")

    assert [p] = ctx.conn |> get(~p"/api/v1/people") |> json_response(200) |> Map.fetch!("data")

    assert Map.has_key?(p, "no_longer_observed_at"), """
    O campo sumiu da resposta.

    Omiti-lo faria *ainda observada* e *deixou de ser observada* chegarem iguais ao cliente,
    e a segunda é informação sobre a origem, não sobre a pessoa.
    """

    assert p["no_longer_observed_at"] == nil
  end

  test "a paginação percorre cada pessoa uma vez", ctx do
    for n <- 1..7, do: pessoa(ctx.tenant, "pessoa#{n}")

    ids =
      Enum.reduce_while(1..20, {[], nil}, fn _, {acc, cursor} ->
        url =
          if cursor,
            do: ~p"/api/v1/people?page_size=2&after=#{cursor}",
            else: ~p"/api/v1/people?page_size=2"

        corpo = ctx.conn |> get(url) |> json_response(200)
        novos = acc ++ Enum.map(corpo["data"], & &1["id"])

        if corpo["page"]["has_next"],
          do: {:cont, {novos, corpo["page"]["next_cursor"]}},
          else: {:halt, {novos, nil}}
      end)
      |> elem(0)

    assert length(ids) == 7
    assert length(Enum.uniq(ids)) == 7, "houve repetição na travessia"
  end

  test "os dois tenants não se veem", ctx do
    pessoa(ctx.tenant, "minha")
    {outro, _} = tenant_with_admin()
    alheia = pessoa(outro, "alheia")

    ids =
      ctx.conn
      |> get(~p"/api/v1/people")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.map(& &1["id"])

    refute alheia.id in ids
  end

  test "nenhum método de escrita responde", ctx do
    for conn <- [
          post(ctx.conn, ~p"/api/v1/people"),
          put(ctx.conn, ~p"/api/v1/people"),
          patch(ctx.conn, ~p"/api/v1/people"),
          delete(ctx.conn, ~p"/api/v1/people")
        ] do
      assert conn.status == 405
      assert Plug.Conn.get_resp_header(conn, "allow") == ["GET, HEAD"]
    end
  end

  test "sem token é a mesma recusa das outras rotas", %{conn: conn} do
    corpo =
      conn
      |> Plug.Conn.delete_req_header("authorization")
      |> get(~p"/api/v1/people")
      |> json_response(401)

    assert corpo["error"]["code"] == "unauthorized"
  end

  test "a rota aparece na descrição OpenAPI", %{conn: conn} do
    corpo =
      conn
      |> Plug.Conn.delete_req_header("authorization")
      |> get("/api/openapi")
      |> json_response(200)

    assert corpo["paths"]["/api/v1/people"]["get"], """
    A rota não entrou na descrição.

    É FR-040: a descrição é gerada do código, e um endpoint que não aparece nela é um
    endpoint que quem integra não encontra.
    """

    assert corpo["components"]["schemas"]["Person"]["properties"]["account_type"]
  end
end
