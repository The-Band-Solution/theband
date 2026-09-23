defmodule TheBandWeb.Api.RegistroELimiteTest do
  @moduledoc """
  Os dois achados altos da avaliação de segurança da feature 062, corrigidos na API.

  ## A1 — nenhuma leitura bem-sucedida era registrada

  `AccessEvents` tem seis funções e nenhuma é *"leu o dado de alguém"*. O plug registrava só
  a **recusa**. E `api_access_tokens.last_used_at` é um carimbo **sobrescrito**.

  A FR-024 da spec 045 aceita o risco de agregação e aponta o registro de acesso como o
  caminho para percebê-lo. Esse caminho não existia: à pergunta *"esta credencial leu o
  painel de quem, e quantas vezes?"*, a resposta era **"não se sabe"**.

  ## A2 — não havia limite de taxa

  E a spec do MCP decidia herdar *"o limite da 061"*, que não existia. Herdar um controle
  inexistente é herdar zero.

  ## O defeito que estes testes existem para pegar

  A primeira versão do registro passava o UUID já convertido em binário para `insert_all`,
  que com um schema converte sozinho. **As 120 gravações falharam**, todas resgatadas pelo
  `rescue` que protege a resposta, todas invisíveis para quem chamava.

  O `rescue` está certo — derrubar a requisição que se observa trocaria auditoria por
  disponibilidade. Mas ele esconde, e por isso **estes testes afirmam que a linha EXISTE**,
  nunca que nada levantou.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.ApiAccessLog

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, token, valor} = Tenants.create_api_token(tenant, admin, %{label: "registro"}, admin)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin, token: token, valor: valor}
  end

  defp linhas(tenant), do: ApiAccessLog.listar_por_token(tenant, hd(publicos(tenant)))

  defp publicos(tenant) do
    import Ecto.Query
    Repo.all(from r in ApiAccessLog, where: r.tenant_id == ^tenant.id, select: r.token_public_id)
  end

  describe "A1 — a leitura bem-sucedida fica registrada" do
    test "uma chamada com sucesso deixa UMA linha", ctx do
      assert Repo.aggregate(ApiAccessLog, :count) == 0

      ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      assert Repo.aggregate(ApiAccessLog, :count) == 1, """
      Nenhuma linha gravada. A gravação é resgatada por um `rescue` que protege a resposta,
      e por isso ela falha **em silêncio** — foi exatamente assim que 120 gravações se
      perderam na primeira versão. Este teste afirma a linha, e não a ausência de exceção.
      """

      [r] = linhas(ctx.tenant)
      assert r.route == "/api/v1/teams"
      assert r.token_public_id == ctx.token.public_id
      assert r.occurred_at
    end

    test "o alvo é gravado quando há, e nulo quando não há", ctx do
      {:ok, pessoa} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "alvo",
          name: "Alvo",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_alvo",
          collected_at: DateTime.utc_now(:second)
        })

      ctx.conn |> get(~p"/api/v1/people") |> json_response(200)

      ctx.conn
      |> recycle_com_token(ctx.valor)
      |> get(~p"/api/v1/people/#{pessoa.id}")
      |> json_response(200)

      por_rota = Map.new(linhas(ctx.tenant), &{&1.route, &1.target_id})

      assert por_rota["/api/v1/people"] == nil, "listagem não tem alvo, e nulo é a ausência dita"
      assert por_rota["/api/v1/people/:id"] == pessoa.id

      refute Map.has_key?(por_rota, "/api/v1/people/#{pessoa.id}"), """
      A rota é gravada como MOLDE, e não como caminho concreto: um caminho por pessoa lida
      seria contagem por alvo disfarçada de contagem por rota.
      """
    end

    test "a RECUSA não é registrada — o registro é de acesso concedido", ctx do
      build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(~p"/api/v1/teams")
      |> json_response(401)

      ctx.conn |> get("/api/v1/people/nao-e-um-uuid") |> json_response(404)

      assert Repo.aggregate(ApiAccessLog, :count) == 0, """
      A recusa já é registrada por `ApiAuth` e por `AccessEvents`. Duplicá-la aqui encheria a
      tabela do que já está no log — e o que faltava era o outro lado.
      """
    end

    test "o corpo da resposta NÃO é gravado", ctx do
      ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      campos = ApiAccessLog.__schema__(:fields)

      assert campos == [:id, :tenant_id, :token_public_id, :route, :target_id, :occurred_at], """
      Campo novo na tabela: confira que ele não carrega dado lido. Gravar o corpo criaria uma
      segunda cópia do dado, com a mesma sensibilidade e sem o veredito na frente.
      """
    end

    test "o segredo do token não está na tabela", ctx do
      ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      ["tb", "api", publico, segredo] = String.split(ctx.valor, "_", parts: 4)
      [r] = linhas(ctx.tenant)

      refute inspect(r) =~ segredo, "o segredo não entra em registro algum"

      assert r.token_public_id == publico, """
      E o id público ENTRA, de propósito: é por ele que se investiga, e é o que a tela de
      tokens mostra. Sem esta asserção o teste acima passaria com a coluna vazia.
      """
    end

    test "a contagem responde *quantas leituras nesta janela*, por rota", ctx do
      for _ <- 1..3, do: ctx.conn |> recycle_com_token(ctx.valor) |> get(~p"/api/v1/teams")
      ctx.conn |> recycle_com_token(ctx.valor) |> get(~p"/api/v1/people")

      contagem = ApiAccessLog.contar_por_rota(ctx.tenant, ctx.token.public_id, 300)

      assert contagem == %{"/api/v1/teams" => 3, "/api/v1/people" => 1}, """
      Por ROTA, e não um total: volume anômalo numa rota é fato diferente de volume
      distribuído entre todas, e um número só não distingue os dois.
      """
    end

    test "janela curta não vê leitura antiga, e o mapa vazio não é zero", ctx do
      ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      antiga = DateTime.add(DateTime.utc_now(), -3600, :second)
      Repo.update_all(ApiAccessLog, set: [occurred_at: antiga])

      assert ApiAccessLog.contar_por_rota(ctx.tenant, ctx.token.public_id, 60) == %{}, """
      Mapa vazio: rota que ninguém chamou na janela **não** é rota chamada zero vezes.
      """
    end

    test "dois tenants não se veem no registro", ctx do
      {outro, outro_admin} = tenant_with_admin("outro")

      {:ok, _t, outro_valor} =
        Tenants.create_api_token(outro, outro_admin, %{label: "x"}, outro_admin)

      ctx.conn |> get(~p"/api/v1/teams") |> json_response(200)

      build_conn()
      |> recycle_com_token(outro_valor)
      |> get(~p"/api/v1/teams")
      |> json_response(200)

      assert length(ApiAccessLog.listar_por_token(ctx.tenant, ctx.token.public_id)) == 1
      assert Repo.aggregate(ApiAccessLog, :count) == 2, "as duas gravaram, cada uma no seu tenant"
    end
  end

  describe "A2 — o limite de taxa existe, e diz o que é" do
    test "os números vêm da base de conhecimento, não de constante", %{} do
      assert {:ok, regra} = KnowledgeBase.rule("api.access.thresholds")
      v = regra["rules"]["rate_limit"]["values"]

      assert is_integer(v["requests_per_minute"]) and v["requests_per_minute"] > 0
      assert is_integer(v["window_seconds"]) and v["window_seconds"] > 0

      assert regra["rules"]["rate_limit"]["note"]["pt-BR"] =~ "proposta", """
      O número é decisão de quem manda, e a regra tem de dizer isso — senão alguém o lê como
      medida e não como escolha.
      """
    end

    test "a resposta traz quanto resta da janela", ctx do
      conn = get(ctx.conn, ~p"/api/v1/teams")

      assert [limite] = get_resp_header(conn, "x-ratelimit-limit")
      assert [resta] = get_resp_header(conn, "x-ratelimit-remaining")
      assert String.to_integer(resta) == String.to_integer(limite) - 1
    end

    test "acima do limite recusa com 429, e a recusa DIZ o limite", ctx do
      %{limite: limite, janela: janela} = limiares()

      ultima =
        Enum.reduce(1..(limite + 1), nil, fn _, _ ->
          ctx.conn |> recycle_com_token(ctx.valor) |> get(~p"/api/v1/teams")
        end)

      assert ultima.status == 429
      corpo = json_response(ultima, 429)

      assert corpo["error"]["code"] == "too_many_requests"
      assert corpo["error"]["message"] =~ to_string(limite)
      assert corpo["error"]["message"] =~ to_string(janela)

      assert [_] = get_resp_header(ultima, "retry-after"), """
      Recusa muda faria quem integra tentar de novo imediatamente, que é o contrário do que
      o limite quer.
      """
    end

    test "a chamada recusada por limite NÃO vira leitura registrada", ctx do
      %{limite: limite} = limiares()

      for _ <- 1..(limite + 5),
          do: ctx.conn |> recycle_com_token(ctx.valor) |> get(~p"/api/v1/teams")

      assert Repo.aggregate(ApiAccessLog, :count) == limite, """
      Exatamente o limite: as que passaram. As recusadas por taxa não são leitura, e
      registrá-las inflaria a contagem que serve para detectar abuso — com o próprio abuso.
      """
    end

    test "a contagem é por TOKEN, e um não gasta o limite do outro", ctx do
      %{limite: limite} = limiares()

      {:ok, _t2, segundo} =
        Tenants.create_api_token(ctx.tenant, ctx.admin, %{label: "b"}, ctx.admin)

      for _ <- 1..(limite + 1),
          do: ctx.conn |> recycle_com_token(ctx.valor) |> get(~p"/api/v1/teams")

      do_segundo = build_conn() |> recycle_com_token(segundo) |> get(~p"/api/v1/teams")

      assert do_segundo.status == 200, """
      Por tenant, uma integração ruidosa derrubaria as outras da mesma organização. O token
      é a identidade que a API conhece, e é a que se revoga.
      """
    end
  end

  defp limiares do
    {:ok, regra} = KnowledgeBase.rule("api.access.thresholds")
    v = regra["rules"]["rate_limit"]["values"]
    %{limite: v["requests_per_minute"], janela: v["window_seconds"]}
  end

  defp recycle_com_token(conn, valor) do
    conn
    |> recycle()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end
end
