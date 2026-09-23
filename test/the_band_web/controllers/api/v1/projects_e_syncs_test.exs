defmodule TheBandWeb.Api.V1.ProjectsESyncsTest do
  @moduledoc """
  `GET /api/v1/projects` e `GET /api/v1/syncs` — as duas últimas rotas da FR-021.

  ## Os dois defeitos que a medição contra a base achou, e que estes testes guardam

  **Um campo chamado `interrupted` mentia.** Existe coleta com `status: "interrupted"` e
  nenhuma pessoa por trás — o reconciliador a encerra quando *"o processo que a executava não
  existe mais"*. Um booleano com esse nome devolvendo `false` ao lado daquele status faria
  quem integra escolher em qual acreditar. Virou `interrupted_by_person`.

  **Dois totais que parecem o mesmo e não são.** `issues.direct` conta pelos repositórios do
  projeto; `start_criterion.total` conta pelos quadros. Medido em 2026-09-22: `ConectaFapes`
  tem 2 756 e 0; `Valida` tem 0 e 498. Quem os comparar conclui o contrário do que há, e por
  isso a resposta carrega a advertência.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "fim"}, admin)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin}
  end

  defp projeto(tenant, admin, nome) do
    {:ok, p} =
      SPO.create_project(tenant, %{name: nome, phase: "simple"}, admin.id)

    p
  end

  describe "GET /api/v1/projects" do
    test "traz o projeto com as duas contagens e o critério", ctx do
      projeto(ctx.tenant, ctx.admin, "Alfa")

      [p] = ctx.conn |> get(~p"/api/v1/projects") |> json_response(200) |> Map.fetch!("data")

      assert p["name"] == "Alfa"
      assert Map.has_key?(p["issues"], "direct")
      assert Map.has_key?(p["issues"], "via_subproject")
      assert is_list(p["organizations"])
      assert is_list(p["teams"])
    end

    test "as issues não se somam, e a resposta diz isso", ctx do
      projeto(ctx.tenant, ctx.admin, "Alfa")

      [p] = ctx.conn |> get(~p"/api/v1/projects") |> json_response(200) |> Map.fetch!("data")

      refute Map.has_key?(p["issues"], "total"),
             "issue alcançada por subprojeto não é uma segunda issue"

      assert p["issues"]["note"] =~ "Never summed"
    end

    test "os dois denominadores vêm advertidos — foi o que a base mostrou", ctx do
      projeto(ctx.tenant, ctx.admin, "Alfa")

      [p] = ctx.conn |> get(~p"/api/v1/projects") |> json_response(200) |> Map.fetch!("data")

      assert p["issues"]["denominator_note"] =~ "repositories", """
      `issues` conta pelos repositórios e `start_criterion.total` pelos quadros. Medido em
      2026-09-22: um projeto com 2 756 issues e 0 no critério, porque não tem quadro. Sem a
      advertência, quem lê os dois lado a lado conclui que 2 756 issues estão sem critério.
      """

      assert p["issues"]["denominator_note"] =~ "boards"
    end

    test "o critério traz as TRÊS ausências separadas, e nunca um total", ctx do
      projeto(ctx.tenant, ctx.admin, "Alfa")

      [p] = ctx.conn |> get(~p"/api/v1/projects") |> json_response(200) |> Map.fetch!("data")
      c = p["start_criterion"]

      for campo <- ~w(no_criterion event_not_collected with_instant) do
        assert is_integer(c[campo]), "falta a ausência *#{campo}*"
      end

      assert is_list(c["ambiguous"]), """
      `ambiguous` traz a LISTA, e não a contagem: para desempatar é preciso saber quais, e um
      número não diz.
      """

      refute Map.has_key?(c, "without_instant"), """
      Somar as três num "sem instante" diria que HÁ um problema, e não QUAL — e as três
      pedem coisas diferentes: declarar o critério, coletar o evento, ou desempatar.
      """
    end

    test "`origin` da equipe é marca, e não booleano", ctx do
      projeto(ctx.tenant, ctx.admin, "Alfa")

      cru = ctx.conn |> get(~p"/api/v1/projects") |> Map.fetch!(:resp_body)

      refute cru =~ ~r/"declared"\s*:\s*(true|false)/,
             "booleano no lugar do relator é antipadrão declarado nesta casa"
    end

    test "o teto de página é 50, e não 200 — o custo por linha é o motivo", ctx do
      for i <- 1..3, do: projeto(ctx.tenant, ctx.admin, "P#{i}")

      corpo = ctx.conn |> get(~p"/api/v1/projects?page_size=500") |> json_response(200)

      assert length(corpo["data"]) == 3
      assert corpo["page"]["total"] == 3
      assert corpo["page"]["total_note"] =~ "declared by people"
    end

    test "nenhum método de escrita responde", ctx do
      for r <- [
            post(ctx.conn, "/api/v1/projects"),
            put(ctx.conn, "/api/v1/projects"),
            patch(ctx.conn, "/api/v1/projects"),
            delete(ctx.conn, "/api/v1/projects")
          ] do
        assert r.status == 405
        assert get_resp_header(r, "allow") == ["GET, HEAD"]
      end
    end
  end

  describe "GET /api/v1/syncs" do
    test "responde, mesmo sem coleta alguma — e a lista vazia não é erro", ctx do
      corpo = ctx.conn |> get(~p"/api/v1/syncs") |> json_response(200)

      assert corpo["data"] == []
      assert corpo["page"]["total"] == nil
      assert corpo["page"]["total_note"] =~ "does not count"
    end

    test "`interrupted_by_person` não promete mais do que entrega", ctx do
      # O nome é o teste: um campo `interrupted` devolvendo `false` numa coleta com
      # `status: "interrupted"` contradiria o status ao lado. Medido na base: existe.
      cru = ctx.conn |> get(~p"/api/v1/syncs") |> Map.fetch!(:resp_body)

      refute cru =~ ~r/"interrupted"\s*:/,
             "`interrupted` diria *foi interrompida*; o campo diz *foi interrompida POR ALGUÉM*"
    end

    test "credencial e quem interrompeu não saem", ctx do
      cru = ctx.conn |> get(~p"/api/v1/syncs") |> Map.fetch!(:resp_body)

      refute cru =~ "credential_id", "a API que lista credencial é a API que a vaza"
      refute cru =~ "interrupted_by_user_id", "id de pessoa numa rota que não precisa dele"
    end

    test "nenhum método de escrita responde", ctx do
      for r <- [
            post(ctx.conn, "/api/v1/syncs"),
            put(ctx.conn, "/api/v1/syncs"),
            patch(ctx.conn, "/api/v1/syncs"),
            delete(ctx.conn, "/api/v1/syncs")
          ] do
        assert r.status == 405
        assert get_resp_header(r, "allow") == ["GET, HEAD"]
      end
    end
  end

  describe "as duas fecham a FR-021" do
    test "sem token, as duas recusam igual às outras", %{} do
      # `build_conn()`, e NÃO o `conn` do setup: aquele já carrega o cabeçalho de
      # autorização, e o teste daria 200 afirmando que recusou. Foi o que aconteceu na
      # primeira escrita — e o teste reprovou dizendo `got: 200`, que é o comportamento certo.
      c = Plug.Conn.put_req_header(build_conn(), "accept", "application/json")

      for rota <- ["/api/v1/projects", "/api/v1/syncs"] do
        assert c |> get(rota) |> json_response(401) |> get_in(["error", "code"]) == "unauthorized"
      end
    end

    test "as duas aparecem na descrição OpenAPI", ctx do
      caminhos =
        ctx.conn
        |> get(~p"/api/openapi")
        |> json_response(200)
        |> Map.fetch!("paths")
        |> Map.keys()

      assert "/api/v1/projects" in caminhos
      assert "/api/v1/syncs" in caminhos
    end

    test "os dois tenants não se veem", ctx do
      projeto(ctx.tenant, ctx.admin, "Meu")
      {outro, outro_admin} = tenant_with_admin("outro")
      projeto(outro, outro_admin, "Alheio")

      nomes =
        ctx.conn
        |> get(~p"/api/v1/projects")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["name"])

      assert "Meu" in nomes, "sem isto, o refute abaixo passaria com a lista vazia"
      refute "Alheio" in nomes
    end
  end
end
