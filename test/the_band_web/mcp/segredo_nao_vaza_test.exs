defmodule TheBandWeb.MCP.SegredoNaoVazaTest do
  @moduledoc """
  SC-005 — nenhum segredo, credencial, e-mail ou `platform_access_level` sai por MCP — feature
  062, T027, FR-008, FR-030, FR-031.

  **A varredura olha a resposta inteira, serializada**, como ela sai da rota, e não os campos
  esperados: um campo novo que vazasse não estaria na lista de esperados. É feita sobre as quatro
  ferramentas, pela rota real `/mcp`, com o token.

  O consumidor é um modelo, e o que ele recebe pode ser repetido, cacheado e indexado do outro
  lado, fora do alcance de qualquer revogação (FR-032). Por isso a margem é maior que a da tela.

  **A guarda contra a varredura vazia**: a mesma busca tem de **achar** o `state: "checked"`, que
  toda resposta de ferramenta traz. Sem ela, "zero ocorrências" passaria com uma resposta vazia.
  A tarefa pedia o `team_id`, e ele não aparece em todas: `team_open_work` não o devolve.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @meta %{
    "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities" => %{},
    "io.modelcontextprotocol/clientInfo" => %{"name" => "teste", "version" => "0"}
  }

  # E-mail em qualquer forma. A plataforma não põe e-mail em resposta de ferramenta, e quem
  # declarou um vínculo (um e-mail) é o dado que a porta exclui.
  @email ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "sc005"}, admin)

    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")
    equipe = team_fixture(tenant, "T_#{System.unique_integer([:positive])}", %{organization: org})

    # Uma pessoa com vínculo OBSERVADO, que carrega `platform_access_level` na evidência. É o
    # campo que a FR-031 proíbe de sair: a tela deixou de exibi-lo.
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
        team_external_id: equipe.external_id,
        platform_access_level: "MAINTAINER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    %{conn: conn, admin: admin, valor: valor, equipe: equipe}
  end

  defp chamar(ctx, nome) do
    ctx.conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> ctx.valor)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", "2026-07-28")
    |> put_req_header("mcp-method", "tools/call")
    |> put_req_header("mcp-name", nome)
    |> post(
      "/mcp",
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => %{
          "name" => nome,
          "arguments" => %{"team_id" => ctx.equipe.id},
          "_meta" => @meta
        }
      })
    )
  end

  # A resposta sem o texto que a base escreve (as ressalvas) e sem a cópia em `content[].text`,
  # que é a serialização do mesmo objeto (provado em protocolo_test.exs).
  defp sem_texto_da_base(corpo) do
    corpo
    |> Jason.decode!()
    |> update_in(["result"], &Map.delete(&1, "content"))
    |> update_in(
      ["result", "structuredContent"],
      &Map.drop(&1, ["limitations", "misinterpretations"])
    )
    |> Jason.encode!()
  end

  test "o controle da exclusão: a palavra está nas ressalvas do roster, e só nelas", ctx do
    r = chamar(ctx, "team_roster")
    ressalvas = get_in(Jason.decode!(r.resp_body), ["result", "structuredContent", "limitations"])

    assert Enum.any?(ressalvas, &(&1 =~ "MAINTAINER")),
           "a frase da base mudou, e a exclusão pode estar escondendo outra coisa"

    refute sem_texto_da_base(r.resp_body) =~ "MAINTAINER"
  end

  test "as quatro respostas, inteiras, não trazem segredo, e-mail nem nível de acesso", ctx do
    [_, _, publico, segredo] = String.split(ctx.valor, "_", parts: 4)

    for f <- Ferramentas.listar() do
      r = chamar(ctx, f.nome)
      assert r.status == 200, "#{f.nome}: #{r.resp_body}"

      # A resposta inteira: corpo e cabeçalhos, como saíram da rota.
      tudo = r.resp_body <> inspect(r.resp_headers)

      # A GUARDA: a varredura acha o que está lá de propósito. O `team_id` não serve, porque
      # `team_open_work` não o devolve (medido em 2026-09-25): o que toda resposta de verdade
      # traz é o estado conferido.
      assert tudo =~ ~s("state":"checked"), "#{f.nome}: a resposta não é a da ferramenta"

      refute tudo =~ ctx.valor, "#{f.nome} devolveu o valor do token"
      refute tudo =~ segredo, "#{f.nome} devolveu o segredo do token"
      refute tudo =~ "platform_access_level", "#{f.nome} devolveu platform_access_level (FR-031)"
      # O VALOR observado do nível de acesso não sai. A palavra pode aparecer nas ressalvas,
      # que são texto da base: o mapeamento `github.team_member.to.eo.person` declara, como
      # limitação, que "MAINTAINER e MEMBER são níveis de acesso, não papéis". Medido em
      # 2026-09-25: a primeira versão deste teste reprovou exatamente por essa frase. Por isso
      # a busca é no que sobra da resposta sem as ressalvas, e o controle confirma que a
      # exclusão tirou só a frase da base.
      sem_ressalvas = sem_texto_da_base(r.resp_body)

      refute sem_ressalvas =~ "MAINTAINER",
             "#{f.nome} devolveu o nível de acesso observado da pessoa (FR-031)"

      refute tudo =~ ctx.admin.email, "#{f.nome} devolveu o e-mail da conta"
      refute Regex.match?(@email, r.resp_body), "#{f.nome} devolveu um e-mail: #{r.resp_body}"

      # O prefixo público do token é o único pedaço que pode aparecer, e ele não aparece
      # na resposta da ferramenta: o registro o guarda, e a resposta não o devolve.
      refute r.resp_body =~ publico, "#{f.nome} devolveu o identificador do token"
    end
  end
end
