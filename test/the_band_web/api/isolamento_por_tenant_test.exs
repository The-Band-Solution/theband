defmodule TheBandWeb.Api.IsolamentoPorTenantTest do
  @moduledoc """
  **SC-002 — dois tenants não se veem pela API.** T023, e a FR-031.

  ## Duas afirmações, e a segunda é a que dura

  A primeira é o resultado: os conjuntos de identificadores que cada credencial alcança não
  se tocam. Ela prova o comportamento **de hoje**.

  A segunda é o mecanismo: **nenhuma consulta do caminho da API roda sem `tenant_id` na
  cláusula**. Ela prova que o comportamento de amanhã não depende de alguém lembrar.

  Um teste só com a primeira daria verde no dia em que uma consulta nova esquecesse o
  recorte e a base de teste, por acaso, não tivesse linha da outra organização para vazar.

  ## O controle é o PARÂMETRO, e não a palavra no SQL

  A primeira versão deste teste procurava o texto `tenant_id` no SQL. **Passava com o
  recorte removido**: `organizations_by_person/2` junta equipe e organização com
  `t.tenant_id == o.tenant_id`, e essa condição de junção contém a palavra sem filtrar coisa
  alguma. Removi o `where` do tenant de propósito, e os sete testes deram verde.

  O controle certo é o **parâmetro**: o identificador do tenant da requisição tem de estar
  entre os parâmetros da consulta, como UUID binário. Uma junção não o coloca lá; um
  `where: x.tenant_id == ^tenant_id` coloca.

  ## As exceções, e por que cada uma é legítima

  Três consultas do caminho de autenticação não carregam o tenant, e **não podem** carregar:
  elas são o que o descobre.

  | Origem | Por quê |
  |---|---|
  | `api_access_tokens` | procurada pelo id público — é assim que se chega ao tenant |
  | `tenants` | ali o tenant **é a linha**, achada pela própria chave |
  | `users` | a conta dona do token, achada pelo id que o token guarda |

  A lista é fechada de propósito. Consulta nova sem o tenant reprova aqui e obriga a uma
  decisão — que é o oposto de descobrir o vazamento em produção.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  # As três do caminho de autenticação, e a razão de cada uma está no `@moduledoc`.
  # Acrescentar nome aqui é decisão, e tem de vir com a razão escrita ao lado.
  @caminho_da_autenticacao ~w(api_access_tokens tenants users)

  defp montar(slug) do
    {tenant, admin} = tenant_with_admin(slug)
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: slug}, admin)

    org = organization_fixture(tenant, "org-#{slug}")
    equipe = team_fixture(tenant, "T_#{slug}", %{organization: org})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "pessoa-#{slug}",
        name: "Pessoa #{slug}",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{slug}",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_#{slug}",
        team_external_id: "T_#{slug}",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    %{tenant: tenant, admin: admin, token: valor, equipe: equipe, pessoa: pessoa}
  end

  defp com(conn, token) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end

  defp ids(conn, token, rota) do
    conn
    |> com(token)
    |> get(rota)
    |> json_response(200)
    |> Map.fetch!("data")
    |> Enum.map(& &1["id"])
  end

  # Captura o SQL INTEIRO — a assinatura do contador não serve aqui, porque o que se
  # examina é a cláusula, e não quantas foram.
  defp sql_da_requisicao(fun) do
    ref = make_ref()
    pai = self()

    :telemetry.attach(
      {__MODULE__, ref},
      [:the_band, :repo, :query],
      fn _e, _m, %{query: q} = meta, _c ->
        send(pai, {ref, to_string(meta[:source]), q, List.wrap(meta[:params])})
      end,
      nil
    )

    fun.()
    :telemetry.detach({__MODULE__, ref})

    drenar(ref, [])
  end

  defp drenar(ref, acc) do
    receive do
      {^ref, origem, sql, params} -> drenar(ref, [{origem, sql, params} | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  defp consultas_de_leitura(capturadas) do
    Enum.filter(capturadas, fn {_o, sql, _p} ->
      String.starts_with?(sql, "SELECT") and not String.contains?(sql, "oban_") and
        not String.starts_with?(sql, "SELECT pg_notify")
    end)
  end

  setup %{conn: conn} do
    %{conn: conn, a: montar("alfa"), b: montar("beta")}
  end

  describe "SC-002 — os conjuntos não se tocam" do
    test "equipes: cada credencial vê só as suas", ctx do
      de_a = ids(ctx.conn, ctx.a.token, ~p"/api/v1/teams")
      de_b = ids(ctx.conn, ctx.b.token, ~p"/api/v1/teams")

      # Sem estas duas, a interseção vazia poderia ser de duas listas vazias.
      assert ctx.a.equipe.id in de_a
      assert ctx.b.equipe.id in de_b

      assert MapSet.disjoint?(MapSet.new(de_a), MapSet.new(de_b)),
             "há equipe alcançada pelas duas credenciais"
    end

    test "pessoas: cada credencial vê só as suas", ctx do
      de_a = ids(ctx.conn, ctx.a.token, ~p"/api/v1/people")
      de_b = ids(ctx.conn, ctx.b.token, ~p"/api/v1/people")

      assert ctx.a.pessoa.id in de_a
      assert ctx.b.pessoa.id in de_b
      assert MapSet.disjoint?(MapSet.new(de_a), MapSet.new(de_b))
    end

    test "o detalhe de pessoa alheia é 404 — e a própria é 200", ctx do
      assert ctx.conn
             |> com(ctx.a.token)
             |> get(~p"/api/v1/people/#{ctx.b.pessoa.id}")
             |> Map.fetch!(:status) == 404

      assert ctx.conn
             |> com(ctx.a.token)
             |> get(~p"/api/v1/people/#{ctx.a.pessoa.id}")
             |> Map.fetch!(:status) == 200
    end

    test "a organização da outra não aparece dentro da pessoa desta", ctx do
      corpo =
        ctx.conn |> com(ctx.a.token) |> get(~p"/api/v1/people") |> json_response(200)

      logins =
        corpo["data"] |> Enum.flat_map(& &1["organizations"]) |> Enum.map(& &1["login"])

      assert "org-alfa" in logins, "sem isto, o `refute` abaixo passaria com a lista vazia"
      refute "org-beta" in logins
    end
  end

  describe "FR-031 — nenhuma consulta sem recorte" do
    test "toda consulta da listagem de pessoas carrega `tenant_id`", ctx do
      capturadas =
        sql_da_requisicao(fn ->
          assert ctx.conn |> com(ctx.a.token) |> get(~p"/api/v1/people") |> Map.fetch!(:status) ==
                   200
        end)

      verificar(consultas_de_leitura(capturadas), ctx.a.tenant)
    end

    test "toda consulta do detalhe de pessoa carrega `tenant_id`", ctx do
      capturadas =
        sql_da_requisicao(fn ->
          assert ctx.conn
                 |> com(ctx.a.token)
                 |> get(~p"/api/v1/people/#{ctx.a.pessoa.id}")
                 |> Map.fetch!(:status) == 200
        end)

      verificar(consultas_de_leitura(capturadas), ctx.a.tenant)
    end

    test "toda consulta da listagem de equipes carrega `tenant_id`", ctx do
      capturadas =
        sql_da_requisicao(fn ->
          assert ctx.conn |> com(ctx.a.token) |> get(~p"/api/v1/teams") |> Map.fetch!(:status) ==
                   200
        end)

      verificar(consultas_de_leitura(capturadas), ctx.a.tenant)
    end

    defp verificar(leituras, tenant) do
      assert leituras != [], "nenhuma consulta capturada — o exame está olhando para o vazio"

      binario = Ecto.UUID.dump!(tenant.id)

      de_dominio = Enum.reject(leituras, fn {o, _, _} -> o in @caminho_da_autenticacao end)

      assert de_dominio != [], """
      Toda consulta capturada é do caminho de autenticação. Então o exame não alcançou
      consulta de domínio nenhuma, e o `== []` abaixo não prova nada.
      """

      sem_o_tenant = Enum.reject(de_dominio, fn {_o, _sql, params} -> binario in params end)

      assert sem_o_tenant == [], """
      Consulta de domínio sem o identificador do tenant entre os parâmetros:

      #{Enum.map_join(sem_o_tenant, "\n\n", fn {o, sql, _} -> "  origem: #{o}\n  #{String.slice(sql, 0, 240)}" end)}

      **Procurar a palavra `tenant_id` no SQL não pegaria isto**: uma condição de junção
      como `t.tenant_id == o.tenant_id` contém a palavra e não filtra nada. O que prova o
      recorte é o tenant chegar como PARÂMETRO, e é isso que falta aqui.

      Ou a consulta esqueceu o recorte — e vaza dado de outra organização assim que a base
      tiver uma —, ou ela é do caminho que descobre o tenant. No segundo caso, acrescente a
      origem a `@caminho_da_autenticacao` **com a razão escrita**. A lista é fechada.
      """
    end
  end
end
