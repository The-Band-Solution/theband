defmodule TheBand.MCP.FerramentasTest do
  @moduledoc """
  O registro das ferramentas, e o caminho único até elas — feature 062, T006.

  Três coisas se provam aqui:

  1. **o lastro existe** (FR-020): cada ferramenta aponta para uma pergunta de competência ou
     uma necessidade de informação que a base de conhecimento declara;
  2. **o argumento é fechado**: só `team_id`, e um `tenant_id` enviado é recusado de forma
     visível, e não ignorado;
  3. **a equipe é carregada no tenant antes do veredito** (R6): um admin de A com o id de uma
     equipe de B recebe a mesma recusa que um id inexistente, e nunca `checked` vazio.

  ## A guarda contra a recusa vazia

  As quatro ferramentas ainda não existem (T010–T013). O caminho de **concessão** é provado por
  isso mesmo: com alcance, o registro chega ao módulo da ferramenta, e a chamada levanta
  `UndefinedFunctionError` nomeando o módulo. Sem essa guarda, "todas recusam" passaria com um
  registro que recusasse tudo. O T010 troca a guarda pela resposta da ferramenta.
  """
  use TheBand.DataCase, async: true

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  describe "o registro" do
    test "tem exatamente as quatro ferramentas do primeiro corte, nesta ordem" do
      assert Enum.map(Ferramentas.listar(), & &1.nome) ==
               ~w(team_roster team_open_work team_review_wait team_stale_work)
    end

    test "cada ferramenta tem lastro que existe na base de conhecimento (FR-020)" do
      for f <- Ferramentas.listar() do
        assert Ferramentas.lastro_existe?(f), """
        #{f.nome} aponta para #{inspect(f.lastro)}, e a base não tem esse id.

        Ferramenta sem pergunta declarada na base é a plataforma afirmando o que não se
        comprometeu a afirmar (FR-020).
        """
      end
    end

    test "o controle: lastro inventado é reprovado, e não aceito por existir o campo" do
      refute Ferramentas.lastro_existe?(%{lastro: {:pergunta_de_competencia, "sro.cq999"}})
      refute Ferramentas.lastro_existe?(%{lastro: {:necessidade_de_informacao, "nao.existe"}})
      # Prefixo não casa: `sro.cq1` não é `sro.cq15`.
      refute Ferramentas.lastro_existe?(%{lastro: {:pergunta_de_competencia, "sro.cq1"}})
    end

    test "cada descrição diz o que a ferramenta não responde" do
      for f <- Ferramentas.listar() do
        assert f.descricao =~ "Does not answer", "#{f.nome} não diz o que não responde (FR-022)"
      end
    end

    test "o esquema de entrada aceita só team_id, como UUID, e nada além" do
      e = Ferramentas.esquema_de_entrada()

      assert e["required"] == ["team_id"]
      assert Map.keys(e["properties"]) == ["team_id"]
      assert e["properties"]["team_id"]["format"] == "uuid"
      assert e["additionalProperties"] == false
    end
  end

  describe "o argumento" do
    setup do
      {tenant, admin} = tenant_with_admin()
      %{tenant: tenant, admin: admin}
    end

    test "tenant_id enviado é recusado de forma visível, e não ignorado", ctx do
      assert {:error, {:argumento_invalido, "unexpected argument: tenant_id"}} =
               Ferramentas.chamar(ctx.tenant, ctx.admin, "team_roster", %{
                 "team_id" => Ecto.UUID.generate(),
                 "tenant_id" => Ecto.UUID.generate()
               })
    end

    test "team_id que não é UUID, ou ausente, é erro de argumento, e não recusa", ctx do
      assert {:error, {:argumento_invalido, _}} =
               Ferramentas.chamar(ctx.tenant, ctx.admin, "team_roster", %{"team_id" => "x"})

      assert {:error, {:argumento_invalido, "team_id is required"}} =
               Ferramentas.chamar(ctx.tenant, ctx.admin, "team_roster", %{})
    end

    test "ferramenta fora do registro não é alcançável", ctx do
      assert {:error, :ferramenta_inexistente} =
               Ferramentas.chamar(ctx.tenant, ctx.admin, "list_teams", %{
                 "team_id" => Ecto.UUID.generate()
               })
    end
  end

  describe "o caminho único: a equipe no tenant, antes do veredito (R6)" do
    setup do
      {a, admin_a} = tenant_with_admin()
      {b, _admin_b} = tenant_with_admin()

      {:ok, membro_a} =
        Tenants.create_user(a, %{
          "email" => "membro-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      %{a: a, admin_a: admin_a, membro_a: membro_a, equipe_a: equipe(a), equipe_b: equipe(b)}
    end

    test "admin de A com a equipe de B recebe fora_do_alcance, e não checked", ctx do
      # A GUARDA DO CENÁRIO: o ramo admin de `pode_ver_equipe/3` concede qualquer UUID. É
      # exatamente por isso que o `fetch_team` vem antes, e o teste só prova algo se esse
      # ramo de fato conceder.
      assert {:ok, :admin} = Tenants.pode_ver_equipe(ctx.a, ctx.admin_a, ctx.equipe_b.id)

      for f <- Ferramentas.listar() do
        assert %{state: "refused", reason: "fora_do_alcance", value: nil} =
                 Ferramentas.chamar(ctx.a, ctx.admin_a, f.nome, %{"team_id" => ctx.equipe_b.id})
      end
    end

    test "equipe inexistente recebe a mesma recusa que equipe de outro tenant", ctx do
      inexistente =
        Ferramentas.chamar(ctx.a, ctx.admin_a, "team_roster", %{"team_id" => Ecto.UUID.generate()})

      de_outro =
        Ferramentas.chamar(ctx.a, ctx.admin_a, "team_roster", %{"team_id" => ctx.equipe_b.id})

      assert inexistente == de_outro
    end

    test "conta sem alcance na própria organização é recusada", ctx do
      assert {:nao, :fora_do_alcance} =
               Tenants.pode_ver_equipe(ctx.a, ctx.membro_a, ctx.equipe_a.id)

      assert %{state: "refused", reason: "fora_do_alcance"} =
               Ferramentas.chamar(ctx.a, ctx.membro_a, "team_roster", %{
                 "team_id" => ctx.equipe_a.id
               })
    end

    test "a guarda contra a recusa vazia: com alcance, o caminho chega à ferramenta", ctx do
      erro =
        assert_raise UndefinedFunctionError, fn ->
          Ferramentas.chamar(ctx.a, ctx.admin_a, "team_roster", %{"team_id" => ctx.equipe_a.id})
        end

      assert erro.module == TheBand.MCP.Ferramentas.TeamRoster, """
      Com alcance, o registro tinha de chegar ao módulo da ferramenta. Chegou a
      #{inspect(erro.module)}. O T010 cria o módulo, e troca esta guarda pela resposta.
      """
    end
  end

  # A equipe organizacional EXIGE organização — há um `CHECK` no banco.
  defp equipe(tenant) do
    login = "org-#{String.slice(tenant.id, 0, 8)}"

    {:ok, _} =
      EO.upsert_organization_from_source(tenant, %{
        login: login,
        name: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: login,
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, t} =
      EO.upsert_team_from_source(tenant, %{
        name: "Equipe",
        slug: "equipe-#{System.unique_integer([:positive])}",
        type: "organizational_team",
        organization_external_id: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_#{System.unique_integer([:positive])}",
        collected_at: DateTime.utc_now(:second)
      })

    t
  end
end
