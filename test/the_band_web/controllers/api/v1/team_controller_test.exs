defmodule TheBandWeb.Api.V1.TeamControllerTest do
  @moduledoc """
  `GET /api/v1/teams` — a primeira rota da API pública, e os quatro transversais da fatia.

  O que se confere aqui é o **contrato**: `specs/061-api-publica/contracts/api-v1-teams.md` e
  `contracts/erro.md`. Divergência é defeito.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _token, valor} = Tenants.create_api_token(tenant, admin, %{label: "teste"}, admin)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin, valor: valor}
  end

  # A equipe organizacional EXIGE organização — há um `CHECK` no banco para isso, e ele está
  # certo: equipe de organização sem organização é afirmação sem sujeito.
  defp organizacao(tenant, login) do
    {:ok, org} =
      EO.upsert_organization_from_source(tenant, %{
        login: login,
        name: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: login,
        collected_at: DateTime.utc_now(:second)
      })

    org
  end

  defp equipe(tenant, nome, attrs \\ %{}) do
    login = "org-#{tenant.id |> String.slice(0, 8)}"
    organizacao(tenant, login)

    {:ok, t} =
      EO.upsert_team_from_source(
        tenant,
        Map.merge(
          %{
            name: nome,
            slug: String.downcase(String.replace(nome, " ", "-")),
            type: "organizational_team",
            organization_external_id: login,
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "T_#{System.unique_integer([:positive])}",
            collected_at: DateTime.utc_now(:second)
          },
          attrs
        )
      )

    t
  end

  describe "a resposta" do
    test "devolve as equipes do tenant, com a marca de origem", ctx do
      equipe(ctx.tenant, "Plataforma")

      corpo = ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      assert [equipe] = corpo["data"]
      assert equipe["name"] == "Plataforma"

      assert equipe["origin"] == "observed", """
      A equipe veio sem a marca de origem, ou com a marca errada.

      A plataforma inteira existe para separar o observado do declarado, e entregar sem a
      marca destrói a distinção no ponto de entrega — com o agravante de o consumidor
      previsto ser um modelo, que afirmaria o dado sem ela.
      """

      assert equipe["source_system"] == "github"
    end

    test "a coleção NÃO traz total, e diz que não traz", ctx do
      equipe(ctx.tenant, "Uma")

      pagina = ctx.conn |> get(~p"/api/v1/teams") |> json_response(200) |> Map.fetch!("page")

      assert pagina["total"] == nil
      assert pagina["total_note"] =~ "does not count collections"
      assert pagina["has_next"] == false
    end

    test "coleção vazia é 200 com lista vazia, e nunca 404", ctx do
      corpo = ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      assert corpo["data"] == [], """
      Um tenant sem equipe recebeu outra coisa que não a lista vazia.

      Nada encontrado não é o mesmo que não coletado, e 404 diria a segunda coisa.
      """
    end
  end

  describe "SC-009 — a paginação não repete nem omite" do
    test "percorrer de dois em dois devolve cada equipe uma vez", ctx do
      for n <- 1..7, do: equipe(ctx.tenant, "Equipe #{n}")

      {ids, paginas} = percorrer(ctx.conn, 2)

      assert length(ids) == 7, "percorreu #{length(ids)} de 7"
      assert length(Enum.uniq(ids)) == 7, "houve repetição na travessia"
      assert paginas >= 4, "a página não foi respeitada"
    end

    test "page_size acima do teto é REDUZIDO, e não recusado", ctx do
      equipe(ctx.tenant, "Uma")

      assert %{"data" => [_]} =
               ctx.conn |> get(~p"/api/v1/teams?page_size=99999") |> json_response(200)
    end

    defp percorrer(conn, tamanho) do
      Enum.reduce_while(1..20, {[], 0, nil}, fn _, {ids, n, cursor} ->
        url =
          if cursor,
            do: ~p"/api/v1/teams?page_size=#{tamanho}&after=#{cursor}",
            else: ~p"/api/v1/teams?page_size=#{tamanho}"

        corpo = conn |> get(url) |> json_response(200)
        novos = ids ++ Enum.map(corpo["data"], & &1["id"])

        if corpo["page"]["has_next"],
          do: {:cont, {novos, n + 1, corpo["page"]["next_cursor"]}},
          else: {:halt, {novos, n + 1, nil}}
      end)
      |> then(fn {ids, n, _} -> {ids, n} end)
    end
  end

  describe "SC-003 e SC-004 — a recusa é uma só, e o motivo fica no log" do
    test "as quatro recusas são idênticas, exceto o identificador", %{
      conn: conn,
      tenant: tenant,
      admin: admin
    } do
      {:ok, revogado, valor_revogado} =
        Tenants.create_api_token(tenant, admin, %{label: "r"}, admin)

      {:ok, _} = Tenants.revoke_api_token(tenant, revogado.id, admin)

      {:ok, _, valor_expirado} =
        Tenants.create_api_token(tenant, admin, %{label: "e", expires_in_days: -1}, admin)

      corpos =
        for v <- ["tb_api_naoexiste_qualquercoisa", valor_revogado, valor_expirado, "lixo"] do
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer " <> v)
          |> get(~p"/api/v1/teams")
          |> json_response(401)
          |> pop_in(["error", "request_id"])
          |> elem(1)
        end

      assert Enum.uniq(corpos) |> length() == 1, """
      As recusas diferem entre si.

      Distinguir revogado de expirado de inexistente confirma a quem testa credencial
      roubada que ela existiu, e quando.
      """
    end

    test "sem cabeçalho é a mesma recusa", %{conn: conn} do
      corpo =
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> get(~p"/api/v1/teams")
        |> json_response(401)

      assert corpo["error"]["code"] == "unauthorized"
      assert corpo["error"]["request_id"]
    end

    test "o token em query string NÃO autentica", %{conn: conn, valor: valor} do
      conn
      |> Plug.Conn.delete_req_header("authorization")
      |> get(~p"/api/v1/teams?token=#{valor}")
      |> json_response(401)
    end
  end

  describe "SC-002 — os dois tenants não se veem" do
    test "nenhum identificador do outro tenant aparece", ctx do
      equipe(ctx.tenant, "Minha")

      {outro, admin_outro} = tenant_with_admin()
      alheia = equipe(outro, "Alheia")

      ids =
        ctx.conn
        |> get(~p"/api/v1/teams")
        |> json_response(200)
        |> then(& &1["data"])
        |> Enum.map(& &1["id"])

      refute alheia.id in ids
      assert admin_outro.tenant_id == outro.id
    end
  end

  describe "SC-006 — nenhum método de escrita responde" do
    test "os quatro devolvem 405, com o cabeçalho allow", ctx do
      # Escritos um a um: `post` e companhia são MACROS do `Phoenix.ConnTest`, e `apply/3`
      # não as alcança.
      conns = [
        post(ctx.conn, ~p"/api/v1/teams"),
        put(ctx.conn, ~p"/api/v1/teams"),
        patch(ctx.conn, ~p"/api/v1/teams"),
        delete(ctx.conn, ~p"/api/v1/teams")
      ]

      for conn <- conns do
        assert conn.status == 405, "#{conn.method} devolveu #{conn.status} em vez de 405"

        assert Plug.Conn.get_resp_header(conn, "allow") == ["GET, HEAD"], """
        O 405 veio sem dizer o que é permitido. Quem integra fica sem o próximo passo.
        """
      end
    end

    test "caminho inexistente continua 404, e não 405", ctx do
      # `assert_error_sent` espera EXCEÇÃO, e aqui o 404 é resposta — a pipeline da API não
      # levanta. O que importa é o código, e ele é o ponto: a recusa de método é 405 **para
      # os caminhos que existem**, e um curinga que devolvesse 405 para qualquer caminho
      # seria a mentira inversa, afirmando que há recurso onde não há.
      conn = get(ctx.conn, "/api/v1/nao-existe")

      assert conn.status == 404, "caminho inexistente devolveu #{conn.status}"
    end
  end

  describe "a descrição OpenAPI" do
    test "é servida sem credencial, porque é contrato e não dado", %{conn: conn} do
      corpo =
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> get("/api/openapi")
        |> json_response(200)

      assert corpo["openapi"] =~ "3."
      assert corpo["paths"]["/api/v1/teams"]["get"], "a rota não aparece na descrição"

      assert corpo["components"]["schemas"]["Team"]["properties"]["origin"], """
      A descrição não documenta a marca de origem.

      Quem integra precisa saber que `origin` existe **antes** de escrever o cliente — é a
      diferença entre entregar o dado e entregar o dado com a distinção preservada.
      """
    end

    test "um endpoint novo aparece sem editar documento", %{conn: conn} do
      caminhos =
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> get("/api/openapi")
        |> json_response(200)
        |> Map.fetch!("paths")
        |> Map.keys()

      rotas_declaradas =
        TheBandWeb.Router.__routes__()
        |> Enum.filter(&(&1.verb == :get and String.starts_with?(&1.path, "/api/v1")))
        |> Enum.map(& &1.path)
        |> Enum.uniq()

      assert Enum.sort(caminhos) == Enum.sort(rotas_declaradas), """
      A descrição divergiu da tabela de rotas.

      É FR-040: a descrição é GERADA do código, e a divergência tem de ser detectável — não
      descoberta por quem integra, em produção.
      """
    end
  end
end
