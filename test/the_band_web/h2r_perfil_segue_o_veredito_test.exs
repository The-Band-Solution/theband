defmodule TheBandWeb.H2rPerfilSegueOVereditoTest do
  @moduledoc """
  **Achado H2-R, 2026-09-24 — o perfil escrito pelo modelo ficava fora do veredito.**

  A FR-024 da spec 045 separa três naturezas de dado sobre pessoa: **agregado**, que segue o
  veredito, e **atribuição** e **diretório**, que não seguem. O inventário do H2 distribuiu as
  naturezas por **rota**. O perfil não é rota, é seção, e ficou sem classificação. Por omissão,
  qualquer conta do tenant, e qualquer token dela, lia de qualquer pessoa o texto que um modelo
  escreveu sobre as forças, a evolução e a "atenção" dela. A listagem da API também entregava as
  competências contadas de todas as pessoas.

  **Decisão da pessoa mantenedora em 2026-09-24: o perfil é agregado, e as competências que saem
  dele também.**

  ## As três portas, e a guarda de cada uma

  Tela, detalhe da API e listagem da API. Em cada uma, **quem alcança a pessoa vê o perfil**.
  Sem essa asserção, o `refute` celebraria um perfil que simplesmente não carregou.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @marca "MARCA-FORCAS-H2R"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo-h2r",
        name: "Pessoa Alvo",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_alvo_h2r",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_profile(tenant, %{
        person_id: pessoa.id,
        generated_at: ~U[2026-09-01 10:00:00Z],
        model: "modelo-de-teste",
        tasks_closed: 0,
        tasks_open: 0,
        tasks_with_body: 0,
        tasks_authored_by_other: 0,
        tasks_shared: 0,
        content: %{
          "habilidades" => ["Elixir"],
          "lacunas" => [],
          "resumo" => %{"forcas" => @marca, "evolucao" => "E", "atencao" => "A"},
          "trajetoria" => [
            %{
              "periodo" => 1,
              "meses" => "2026-01 to 2026-06",
              "texto" => "T",
              "tarefas_citadas" => ["uma tarefa"]
            }
          ],
          "alocacao" => [
            %{
              "de" => "2026-01",
              "ate" => "2026-06",
              "dominio" => "coleta",
              "demonstrou" => "x",
              "tarefas" => 12
            }
          ],
          "recomendacoes" => ["r"],
          "destaques" => [
            %{
              "dominio" => "coleta",
              "demonstrou" => "percorreu a timeline",
              "tarefas" => 12,
              "periodos" => [1],
              "mais_recente" => "2026-06",
              "evidencia" => [101]
            }
          ]
        }
      })

    {:ok, membro} =
      Tenants.create_user(tenant, %{
        "email" => "membro-h2r-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    # A GUARDA DO CENÁRIO: o membro NÃO alcança a pessoa, e o admin alcança. Sem isto, os
    # testes abaixo poderiam passar por um veredito que concede a todos, ou a ninguém.
    assert {:nao, _} = Tenants.pode_ver(tenant, membro, pessoa.id)
    assert {:ok, :admin} = Tenants.pode_ver(tenant, admin, pessoa.id)

    %{conn: conn, tenant: tenant, admin: admin, membro: membro, pessoa: pessoa}
  end

  defp com_token(conn, tenant, dono) do
    {:ok, _t, valor} = Tenants.create_api_token(tenant, dono, %{label: "h2r"}, dono)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
    |> Plug.Conn.put_req_header("accept", "application/json")
  end

  defp da_listagem(corpo, id), do: Enum.find(corpo["data"], &(&1["id"] == id))

  describe "a tela da pessoa" do
    test "sem alcance, a seção do perfil não existe e o texto do modelo não sai", ctx do
      {:ok, live, html} = ctx.conn |> log_in(ctx.membro) |> live(~p"/people/#{ctx.pessoa.id}")

      refute html =~ @marca, "o texto do perfil saiu para quem não alcança a pessoa (H2-R)"
      refute has_element?(live, "#profile")
    end

    test "sem alcance, pedir o perfil é recusado, e não só escondido", ctx do
      {:ok, live, _html} =
        ctx.conn |> log_in(ctx.membro) |> live(~p"/people/#{ctx.pessoa.id}")

      html = render_hook(live, "gerar_perfil", %{})

      assert html =~ "This panel is not yours to see."
      refute TheBand.Profiles.pending?(ctx.tenant, ctx.pessoa.id)
    end

    test "com alcance, o perfil aparece — a guarda contra o refute vazio", ctx do
      {:ok, live, html} = ctx.conn |> log_in(ctx.admin) |> live(~p"/people/#{ctx.pessoa.id}")

      assert html =~ @marca
      assert has_element?(live, "#profile")
    end
  end

  describe "o detalhe da API" do
    test "sem alcance, `profile` é null, e a nota diz recusa, e não ausência", ctx do
      d =
        ctx.conn
        |> com_token(ctx.tenant, ctx.membro)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert d["profile"] == nil
      assert d["profile_note"] =~ "aggregate"

      refute d["profile_note"] =~ "No profile has been generated",
             "dizer 'nenhum perfil gerado' a quem não alcança mentiria sobre o registro"
    end

    test "com alcance, o perfil vem inteiro", ctx do
      corpo =
        ctx.conn
        |> com_token(ctx.tenant, ctx.admin)
        |> get(~p"/api/v1/people/#{ctx.pessoa.id}")
        |> json_response(200)

      assert corpo["data"]["profile"]
      assert Jason.encode!(corpo["data"]["profile"]) =~ @marca
    end
  end

  describe "a listagem da API" do
    test "sem alcance, as competências da pessoa não saem", ctx do
      p =
        ctx.conn
        |> com_token(ctx.tenant, ctx.membro)
        |> get(~p"/api/v1/people")
        |> json_response(200)
        |> da_listagem(ctx.pessoa.id)

      assert p, "a pessoa sumiu da listagem: o diretório não segue o veredito (FR-024)"
      assert p["competencies"] == nil
      assert p["competencies_note"] =~ "aggregate"
    end

    test "com alcance, as competências saem", ctx do
      p =
        ctx.conn
        |> com_token(ctx.tenant, ctx.admin)
        |> get(~p"/api/v1/people")
        |> json_response(200)
        |> da_listagem(ctx.pessoa.id)

      assert [%{"domain" => "coleta", "completed_tasks" => 12}] = p["competencies"]
    end
  end
end
