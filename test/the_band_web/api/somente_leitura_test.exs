defmodule TheBandWeb.Api.SomenteLeituraTest do
  @moduledoc """
  **SC-006 — `/api/v1` aceita apenas `GET` e `HEAD`.** T021, FR-017.

  Não há autor honesto para a proveniência de uma escrita por token: a credencial diz de
  quem é a conta, e não quem decidiu. Uma escrita gravaria um ato sem responsável, que é
  precisamente o que esta plataforma existe para não fazer.

  ## Percorre a TABELA DE ROTAS, e não uma lista escrita à mão

  A tarefa pede isso com todas as letras — *"e não uma lista escrita à mão que envelhece"* —
  e a lista escrita à mão já envelheceu: quando `GET /api/v1/people/:id` entrou, o teste de
  405 dela teve de ser lembrado e escrito à parte. Rota nova sem recusa de escrita passava.

  Aqui, rota nova entra na varredura sozinha. Se alguém acrescentar um endpoint e esquecer
  o `match :*`, este arquivo reprova sem que ninguém precise se lembrar dele.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @metodos ~w(POST PUT PATCH DELETE)

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "leitura"}, admin)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo",
        name: "Alvo",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_alvo",
        collected_at: DateTime.utc_now(:second)
      })

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, tenant: tenant, admin: admin, pessoa: pessoa}
  end

  # As rotas de leitura de `/api/v1`, com os parâmetros preenchidos por valores reais.
  # `:id` vira o id de uma pessoa que existe: um id inventado daria 404 e o teste passaria
  # sem nunca ter chegado ao controlador.
  defp rotas(pessoa) do
    TheBandWeb.Router.__routes__()
    |> Enum.filter(&(&1.verb == :get and String.starts_with?(&1.path, "/api/v1")))
    |> Enum.map(&String.replace(&1.path, ":id", pessoa.id))
    |> Enum.uniq()
  end

  test "a varredura encontra as rotas — senão ela percorreria o vazio", ctx do
    rotas = rotas(ctx.pessoa)

    assert length(rotas) >= 3, "só #{length(rotas)} rotas encontradas na tabela"
    assert "/api/v1/teams" in rotas
    assert "/api/v1/people" in rotas
  end

  test "e cada rota da varredura RESPONDE a GET — senão o 405 abaixo não diz nada", ctx do
    for rota <- rotas(ctx.pessoa) do
      assert ctx.conn |> get(rota) |> Map.fetch!(:status) == 200,
             "#{rota} não responde 200 a GET; um 405 nela não provaria recusa de escrita"
    end
  end

  test "os quatro métodos de escrita devolvem 405 em TODA rota de /api/v1", ctx do
    for rota <- rotas(ctx.pessoa) do
      respostas = [
        {"POST", post(ctx.conn, rota)},
        {"PUT", put(ctx.conn, rota)},
        {"PATCH", patch(ctx.conn, rota)},
        {"DELETE", delete(ctx.conn, rota)}
      ]

      assert Enum.map(respostas, fn {m, _} -> m end) == @metodos,
             "a lista de métodos divergiu de @metodos"

      for {metodo, conn} <- respostas do
        assert conn.status == 405, "#{metodo} #{rota} devolveu #{conn.status} em vez de 405"

        assert get_resp_header(conn, "allow") == ["GET, HEAD"],
               "#{metodo} #{rota} recusou sem dizer o que aceita"
      end
    end
  end

  test "a recusa sai no formato único de erro, e não em HTML", ctx do
    for rota <- rotas(ctx.pessoa) do
      corpo = ctx.conn |> post(rota) |> json_response(405)

      assert corpo["error"]["code"] == "method_not_allowed"
      assert corpo["error"]["request_id"], "sem o id do pedido, a recusa não é rastreável"
    end
  end

  test "HEAD responde os mesmos cabeçalhos de GET, com corpo vazio", ctx do
    for rota <- rotas(ctx.pessoa) do
      de_get = get(ctx.conn, rota)
      de_head = head(ctx.conn, rota)

      assert de_head.status == de_get.status, "HEAD #{rota} divergiu de GET no código"

      assert get_resp_header(de_head, "content-type") == get_resp_header(de_get, "content-type"),
             "HEAD #{rota} divergiu de GET no tipo do conteúdo"

      assert de_head.resp_body == "", "HEAD #{rota} devolveu corpo"
      assert de_get.resp_body != "", "e o GET tem de ter corpo, senão a asserção acima é vazia"
    end
  end
end
