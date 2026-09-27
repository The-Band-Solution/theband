defmodule TheBandWeb.MCP.ParidadeTest do
  @moduledoc """
  A paridade das três portas — feature 062, T017 e T018, FR-004 e SC-004.

  *O que a tela recusa, a API recusa e o MCP recusa, pelo mesmo veredito e pela mesma razão.*
  Três portas para o mesmo dado com três vereditos diferentes é o mesmo furo contado três vezes.

  Os **quatro caminhos de concessão** de `pode_ver_equipe/3` (`admin`, `escopo_de_equipe`,
  `escopo_da_organizacao`, `vinculo_vigente`) e a **recusa** (`fora_do_alcance`) são exercidos,
  cada um com uma conta montada só para ele, nas três portas:

  | Porta | Concede | Recusa |
  |---|---|---|
  | a tela `/teams/:id` | abre, e **não** registra recusa | abre, esconde a quebra por pessoa, e **registra** a recusa (T022) |
  | a API `GET /api/v1/teams/:id` | `200` | `404`, o mesmo de equipe inexistente |
  | o MCP, `team_roster` | `state: "checked"` | `state: "refused"`, `reason: "fora_do_alcance"` |

  A forma da recusa é de cada porta, e não precisa coincidir (FR-004 emendada). O **veredito**
  precisa.

  **A guarda contra o teste vazio**: a tabela de casos tem quatro concessões e uma recusa, e o
  teste afirma as duas coisas. Sem as concessões, "todas negam" passaria com as três portas
  quebradas; sem a recusa, "todas concedem" passaria também.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")
    equipe = team_fixture(tenant, "T_#{System.unique_integer([:positive])}", %{organization: org})
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{conn: conn, tenant: tenant, admin: admin, org: org, equipe: equipe, papel: papel}
  end

  # Uma conta por caminho, e só com o que aquele caminho exige.
  defp conta(ctx, :admin), do: ctx.admin

  defp conta(ctx, :escopo_de_equipe) do
    u = membro(ctx)
    {:ok, _} = Access.grant(ctx.tenant, u.id, :team, ctx.equipe.id, ctx.admin)
    u
  end

  defp conta(ctx, :escopo_da_organizacao) do
    u = membro(ctx)
    {:ok, _} = Access.grant(ctx.tenant, u.id, :organization, ctx.org.id, ctx.admin)
    u
  end

  defp conta(ctx, :vinculo_vigente) do
    u = membro(ctx)
    p = pessoa(ctx)
    {:ok, _} = Tenants.declare_person(ctx.tenant, u.id, p.id, ctx.admin.id)

    {:ok, _} =
      EO.declare_team_membership(
        ctx.tenant,
        ctx.equipe.id,
        p.id,
        %{
          organizational_role_id: ctx.papel.id,
          started_at: DateTime.add(DateTime.utc_now(:second), -30, :day)
        },
        ctx.admin.id
      )

    # A conta RELIDA: o elo foi declarado depois de ela ser criada, e a struct antiga não o tem.
    {:ok, relida} = Tenants.fetch_user(u.id)
    relida
  end

  defp conta(ctx, :fora_do_alcance), do: membro(ctx)

  defp membro(ctx) do
    {:ok, u} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    u
  end

  defp pessoa(ctx) do
    login = "p#{System.unique_integer([:positive])}"

    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end

  # As três portas, para a mesma conta e a mesma equipe.
  defp portas(ctx, user) do
    {:ok, _t, valor} = Tenants.create_api_token(ctx.tenant, user, %{label: "paridade"}, ctx.admin)

    api =
      ctx.conn
      |> recycle()
      |> put_req_header("authorization", "Bearer " <> valor)
      |> put_req_header("accept", "application/json")
      |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
      |> Map.fetch!(:status)

    mcp =
      Ferramentas.chamar(ctx.tenant, user, "team_roster", %{"team_id" => ctx.equipe.id}, %{
        token_public_id: "tb_paridade"
      })

    log_da_tela =
      capture_log(fn ->
        {:ok, _live, _html} =
          ctx.conn |> recycle() |> log_in(user) |> live(~p"/teams/#{ctx.equipe.id}?tab=review")
      end)

    %{
      api: api,
      mcp: mcp.state,
      mcp_razao: mcp[:reason],
      tela_recusou?: log_da_tela =~ "acesso: equipe recusada"
    }
  end

  # {caminho montado, razão que o domínio devolve, veredito}
  #
  # **O vínculo vigente concede pela razão `escopo_de_equipe`**, e não `vinculo_vigente`. Medido
  # em 2026-09-25: `Access.scopes/2` DERIVA um escopo de equipe de cada vínculo vigente
  # (`origin: :derived_team`), e em `pode_ver_equipe/3` a cláusula `escopo_de_equipe` vem antes da
  # `vinculo_vigente`. A quarta cláusula nunca é alcançada. O veredito é o mesmo, e é isso que a
  # paridade prova; a razão registrada é que não diz a verdade. Está na issue aberta junto.
  @casos [
    {:admin, :admin, :concede},
    {:escopo_de_equipe, :escopo_de_equipe, :concede},
    {:escopo_da_organizacao, :escopo_da_organizacao, :concede},
    {:vinculo_vigente, :escopo_de_equipe, :concede},
    {:fora_do_alcance, :fora_do_alcance, :recusa}
  ]

  for {caminho, razao, esperado} <- @casos do
    test "#{caminho}: as três portas dão o mesmo veredito (#{esperado})", ctx do
      user = conta(ctx, unquote(caminho))

      # A GUARDA DO CENÁRIO: o veredito do domínio é o que o caso diz. Sem ela, um cenário mal
      # montado faria as três portas concordarem sobre o caso errado.
      case unquote(esperado) do
        :concede ->
          assert {:ok, unquote(razao)} =
                   Tenants.pode_ver_equipe(ctx.tenant, user, ctx.equipe.id)

        :recusa ->
          assert {:nao, :fora_do_alcance} =
                   Tenants.pode_ver_equipe(ctx.tenant, user, ctx.equipe.id)
      end

      p = portas(ctx, user)

      case unquote(esperado) do
        :concede ->
          assert p.api == 200, "a API recusou o que o veredito concede: #{inspect(p)}"
          assert p.mcp == "checked", "o MCP recusou o que o veredito concede: #{inspect(p)}"
          refute p.tela_recusou?, "a tela recusou o que o veredito concede: #{inspect(p)}"

        :recusa ->
          assert p.api == 404, "a API concedeu o que o veredito recusa: #{inspect(p)}"
          assert p.mcp == "refused", "o MCP concedeu o que o veredito recusa: #{inspect(p)}"
          assert p.mcp_razao == "fora_do_alcance"
          assert p.tela_recusou?, "a tela não registrou a recusa: #{inspect(p)}"
      end
    end
  end

  test "T017: sem alcance, as quatro ferramentas recusam com razão, e nenhuma com lista vazia",
       ctx do
    user = conta(ctx, :fora_do_alcance)

    for f <- Ferramentas.listar() do
      r =
        Ferramentas.chamar(ctx.tenant, user, f.nome, %{"team_id" => ctx.equipe.id}, %{
          token_public_id: "tb_paridade"
        })

      assert %{state: "refused", reason: "fora_do_alcance", value: nil} = r,
             "#{f.nome} não recusou com razão: #{inspect(r)}"
    end
  end
end
