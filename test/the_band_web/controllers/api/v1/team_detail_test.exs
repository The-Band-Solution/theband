defmodule TheBandWeb.Api.V1.TeamDetailTest do
  @moduledoc """
  `GET /api/v1/teams/:id`, `/members` e `/measures` — as três rotas que a 061 previa e a
  primeira fatia não entregou.

  ## O que este arquivo existe para impedir

  **Que a recusa diga que a equipe existe.** Fora do alcance responde `404`, igual a equipe
  inexistente e a equipe de outro tenant. Um `403` seria metade da resposta para quem varre.

  **Que duas medidas diferentes virem uma.** A espera por revisão tem dois estados —
  revisada, em horas, e em curso, em dias — e achatá-los num número só faria a mediana
  melhorar quanto pior a equipe estivesse. Medido nesta base em 2026-09-21: 23 revisadas com
  mediana de **0,2 h** e 79 aguardando com mediana de **46 dias**. Um número só diria
  "12 minutos".

  **Que a API fale duas línguas.** O domínio escreve `:declarado` e `:vigente`; a API
  devolve `declared` e `current`. A primeira versão deste controlador usou `to_string/1` e
  derramou português no corpo, ao lado de uma listagem que já dizia `declared`.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "equipe"}, admin)

    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_acme", %{organization: org})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "membro",
        name: "Membro",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_membro",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_membro",
        team_external_id: "T_acme",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin, equipe: equipe, org: org, pessoa: pessoa}
  end

  defp membro(tenant) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    u
  end

  defp com_token(conn, tenant, dono, ator) do
    {:ok, _t, valor} = Tenants.create_api_token(tenant, dono, %{label: "x"}, ator)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end

  describe "GET /api/v1/teams/:id" do
    test "traz identidade, procedência, organização e o veredito", ctx do
      d =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert d["id"] == ctx.equipe.id
      assert d["organization"]["login"] == "acme"
      assert Map.has_key?(d, "provenance")
      assert d["access"]["reason"] == "admin"
    end

    test "os três números do roster NÃO se somam, e vêm separados", ctx do
      r =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
        |> json_response(200)
        |> get_in(["data", "roster"])

      for chave <- ~w(current left mistakes), do: assert(is_integer(r[chave]))

      refute Map.has_key?(r, "total"), """
      *Saiu* e *equívoco* são afirmações diferentes: a primeira diz que o vínculo existiu e
      terminou; a segunda, que nunca devia ter sido afirmado. Um total apagaria a distinção
      que a revogação existe para manter.
      """
    end

    test "a composição diz se é composta, e o alcance que isso define", ctx do
      c =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
        |> json_response(200)
        |> get_in(["data", "composition"])

      assert c["is_composed"] == false
      assert c["parts"] == []
      assert c["note"] =~ "plus its parts"
    end
  end

  describe "GET /api/v1/teams/:id/members" do
    test "o vínculo traz a marca de origem, e ela fala INGLÊS", ctx do
      [m] =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members")
        |> json_response(200)
        |> Map.fetch!("data")

      assert m["login"] == "membro"
      assert m["situation"] == "current", "o domínio diz `:vigente`; a API diz `current`"

      [v] = m["memberships"]

      assert v["origin"] == "observed", """
      O domínio escreve `:observado`. A listagem `/api/v1/teams` já devolve `observed`, e
      duas palavras para a mesma marca na mesma API fariam quem integra casar pelas duas —
      ou, pior, por uma só.
      """
    end

    test "o corpo inteiro está em inglês — nenhum átomo do domínio vazou", ctx do
      cru =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members")
        |> Map.fetch!(:resp_body)

      for portugues <- ~w(declarado observado vigente equivoco saiu) do
        refute cru =~ ~r/"#{portugues}"/,
               "`#{portugues}` saiu cru no corpo — `to_string/1` sobre átomo do domínio"
      end
    end

    test "`ended_at` e `mistake` são campos distintos", ctx do
      [m] =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members")
        |> json_response(200)
        |> Map.fetch!("data")

      [v] = m["memberships"]

      assert Map.has_key?(v, "ended_at"), "*saiu*"
      assert Map.has_key?(v, "mistake"), "*nunca devia ter sido afirmado*"
    end

    test "e-mail de quem declarou não sai", ctx do
      cru = ctx.conn |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members") |> Map.fetch!(:resp_body)

      assert ctx.admin.email =~ "@", "o teste só vale se a conta tiver e-mail"
      refute cru =~ ctx.admin.email
      refute cru =~ "declared_by"
    end

    test "o roster TEM total, ao contrário das listagens — e diz por quê", ctx do
      p =
        ctx.conn
        |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members")
        |> json_response(200)
        |> Map.fetch!("page")

      assert p["total"] == 1
      assert p["total_note"] =~ "bounded"
    end
  end

  describe "GET /api/v1/teams/:id/measures" do
    setup ctx,
      do: %{
        medidas:
          ctx.conn
          |> get(~p"/api/v1/teams/#{ctx.equipe.id}/measures")
          |> json_response(200)
          |> Map.fetch!("data")
      }

    test "a janela é declarada — medida sem janela responde outra pergunta", ctx do
      assert ctx.medidas["window"]["days"] == 56
      assert ctx.medidas["window"]["from"]
      assert ctx.medidas["window"]["to"]
    end

    test "aberto e fechado na janela não se somam, e a nota diz isso", ctx do
      w = ctx.medidas["work"]

      for chave <- ~w(members open closed_in_window stale), do: assert(is_integer(w[chave]))
      assert w["note"] =~ "never summed"
      refute Map.has_key?(w, "total")
    end

    test "as DUAS medianas vêm lado a lado, cada uma com seu denominador", ctx do
      r = ctx.medidas["time_to_first_review"]

      assert Map.has_key?(r["reviewed"], "median_hours"), "quanto demorou o que foi revisado"
      assert Map.has_key?(r["waiting"], "median_days"), "há quanto tempo espera o que não foi"
      assert Map.has_key?(r["reviewed"], "count")
      assert Map.has_key?(r["waiting"], "count")

      refute Map.has_key?(r, "median"), """
      Uma mediana só achataria os dois estados. Medido nesta base: 23 revisadas com mediana
      de 0,2 h e 79 aguardando há 46 dias. Um número diria "12 minutos", e a medida
      melhoraria quanto pior a equipe estivesse.
      """

      assert r["medians_note"] =~ "never summed"
    end

    test "a lista de esperas diz se CORTOU, e o que isso significa", ctx do
      r = ctx.medidas["time_to_first_review"]

      assert is_boolean(r["truncated"])
      assert r["limit"] == 200

      assert r["truncated_note"] =~ "different question",
             "mediana sobre 200 de 500 é outra medida com o mesmo rótulo"
    end

    test "quem não tem perfil vem NOMEADO, nunca somado como zero", ctx do
      s = ctx.medidas["skills"]

      assert s["members"] == 1
      assert s["with_profile"] == 0
      assert [%{"person_id" => _, "name" => _}] = s["without_profile"]
      assert s["coverage_note"] =~ "floor and never a ceiling"
    end
  end

  describe "o que as rotas recusam dizer" do
    test "fora do alcance é 404 — igual a equipe que não existe", ctx do
      recusado = com_token(ctx.conn, ctx.tenant, membro(ctx.tenant), ctx.admin)

      for rota <- ["", "/members", "/measures"] do
        caminho = "/api/v1/teams/#{ctx.equipe.id}#{rota}"

        fora = recusado |> get(caminho) |> json_response(404)

        inexistente =
          ctx.conn |> get("/api/v1/teams/#{Ecto.UUID.generate()}#{rota}") |> json_response(404)

        assert fora["error"]["code"] == inexistente["error"]["code"]

        assert fora["error"]["message"] == inexistente["error"]["message"], """
        Um `403` em #{caminho} confirmaria que a equipe existe, e para quem varre isso é
        metade da resposta.
        """
      end

      # E a administração VÊ — o que prova que o 404 acima é o veredito, e não uma equipe
      # que não foi criada.
      assert ctx.conn |> get(~p"/api/v1/teams/#{ctx.equipe.id}") |> Map.fetch!(:status) == 200
    end

    test "equipe de outro tenant é 404", ctx do
      {outro, outro_admin} = tenant_with_admin("outro")

      alheia =
        team_fixture(outro, "T_alheia", %{organization: organization_fixture(outro, "beta")})

      assert ctx.conn |> get(~p"/api/v1/teams/#{alheia.id}") |> Map.fetch!(:status) == 404

      assert ctx.conn
             |> recycle()
             |> com_token(outro, outro_admin, outro_admin)
             |> get(~p"/api/v1/teams/#{alheia.id}")
             |> Map.fetch!(:status) == 200
    end

    test "id malformado é 404, e não 500", ctx do
      for rota <- ["", "/members", "/measures"] do
        assert ctx.conn |> get("/api/v1/teams/nao-e-um-uuid#{rota}") |> Map.fetch!(:status) == 404
      end
    end
  end

  test "as três rotas aparecem na descrição OpenAPI", ctx do
    caminhos =
      ctx.conn |> get(~p"/api/openapi") |> json_response(200) |> Map.fetch!("paths") |> Map.keys()

    for rota <- ~w(/api/v1/teams/{id} /api/v1/teams/{id}/members /api/v1/teams/{id}/measures) do
      assert rota in caminhos, "descrição que não traz #{rota} mente para quem integra"
    end
  end
end
