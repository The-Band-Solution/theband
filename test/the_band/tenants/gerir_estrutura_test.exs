defmodule TheBand.Tenants.GerirEstruturaTest do
  @moduledoc """
  Quem pode **declarar a estrutura de uma equipe** — feature 060, FR-006 e FR-080 a FR-082.

  Substitui `declarar_estrutura_test.exs`, que provava a regra da feature 055: administrador
  **ou** escopo `organization`/`project` **da conta**.

  ## Por que a regra mudou

  Escopo de conta é concedido para **ver**. Na prática, só a administradora escrevia — e o
  resultado foi medido em 2026-09-06: 59 participações observadas nos times do GitHub e
  **nenhum papel declarado**. Quem conhece a equipe, quem a coordena, não podia declará-la.

  Decisão da pessoa mantenedora em 2026-09-07: administrador **ou** papel organizacional com
  a concessão *gerir estrutura da equipe*. Lista fechada.

  **Ninguém perdeu poder na troca**: medido antes, no banco de desenvolvimento, zero contas
  não-administradoras escreviam por escopo de conta.

  ## O caso que decide

  Ter escopo de conta **não basta mais**. É o teste que separa esta regra da anterior, e o
  que impede alguém de reintroduzir o caminho antigo "porque também autorizava".
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.RoleStructureManagementGrant, as: Concessao
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Access

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant, "admin")
    acme = organization_fixture(tenant, "acme")
    globex = organization_fixture(tenant, "globex")

    equipe = team_fixture(tenant, "T_acme", %{organization: acme})
    equipe_irma = team_fixture(tenant, "T_acme2", %{organization: acme})
    equipe_de_fora = team_fixture(tenant, "T_globex", %{organization: globex})

    {:ok, papel} = EO.create_role(tenant, acme.id, %{code: "sm", name: "Scrum Master"}, admin.id)

    %{
      tenant: tenant,
      admin: admin,
      acme: acme,
      papel: papel,
      equipe: equipe,
      equipe_irma: equipe_irma,
      equipe_de_fora: equipe_de_fora
    }
  end

  # Uma conta ligada a uma pessoa, com vínculo vigente na equipe e o papel dado.
  defp conta_com_papel(ctx, equipe, opts \\ []) do
    {:ok, conta} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "p-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, pessoa} =
      EO.upsert_person_from_source(
        ctx.tenant,
        source_attrs("U_#{System.unique_integer([:positive])}", %{name: "Alguém"})
      )

    {:ok, conta} = Tenants.declare_person(ctx.tenant, conta.id, pessoa.id, ctx.admin.id)

    {:ok, vinculo} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        declared_by_user_id: ctx.admin.id
      })

    if opts[:encerrado],
      do: {:ok, _} = EO.end_allocation(ctx.tenant, vinculo.id, DateTime.utc_now(:second))

    %{conta: conta, pessoa: pessoa, vinculo: vinculo}
  end

  defp conceder(ctx, escopo) do
    {:ok, _} =
      %Concessao{}
      |> Concessao.changeset(%{
        tenant_id: ctx.tenant.id,
        organizational_role_id: ctx.papel.id,
        scope: escopo,
        declared_by_user_id: ctx.admin.id,
        declared_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()
  end

  describe "quem pode" do
    test "a administradora gere qualquer equipe do tenant, sem concessão nenhuma", ctx do
      assert {:ok, :admin} = Access.pode_gerir_estrutura(ctx.tenant, ctx.admin, ctx.equipe.id)

      assert {:ok, :admin} =
               Access.pode_gerir_estrutura(ctx.tenant, ctx.admin, ctx.equipe_de_fora.id)
    end

    test "papel com concessão `team` gere a equipe em que a pessoa o desempenha", ctx do
      conceder(ctx, "team")
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      assert {:ok, :gestor_da_equipe} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe.id)
    end

    test "papel com concessão `organization` gere as OUTRAS equipes da organização", ctx do
      conceder(ctx, "organization")
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      assert {:ok, :gestor_da_organizacao} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe_irma.id)
    end
  end

  describe "quem NÃO pode, e o motivo que a tela diz" do
    test "O CASO QUE DECIDE: escopo de conta não basta mais", ctx do
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      {:ok, _} =
        Tenants.grant_scope(ctx.tenant, conta.id, :organization, ctx.acme.id, ctx.admin)

      assert {:nao, :sem_concessao} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe.id),
             """
             Escopo `organization` de conta voltou a autorizar escrita na estrutura. Escopo de
             conta é concedido para VER; a decisão de 2026-09-07 fecha a escrita em
             administrador ou papel com concessão. Este é o teste que separa a regra nova da
             antiga — se ele passar a falhar, alguém reintroduziu o caminho velho.
             """
    end

    test "concessão `team` não alcança a equipe IRMÃ", ctx do
      conceder(ctx, "team")
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      assert {:nao, :sem_concessao} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe_irma.id)
    end

    test "concessão `organization` não atravessa para outra organização", ctx do
      conceder(ctx, "organization")
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      assert {:nao, :sem_concessao} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe_de_fora.id),
             "a recusa cruzada é o que separa esta regra de 'tem concessão? pode'"
    end

    test "vínculo encerrado diz VÍNCULO ENCERRADO, e não 'sem concessão'", ctx do
      conceder(ctx, "team")
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe, encerrado: true)

      assert {:nao, :vinculo_encerrado} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe.id),
             """
             Quem saiu da equipe ouviria "peça a concessão" — e ela já foi concedida. As duas
             frases levam a ações diferentes: renovar o vínculo, ou pedir a concessão.
             """
    end

    test "conta sem elo com pessoa diz isso, e não 'sem concessão'", ctx do
      conceder(ctx, "team")

      {:ok, sem_elo} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "sem-elo-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      assert {:nao, :conta_sem_pessoa_declarada} =
               Access.pode_gerir_estrutura(ctx.tenant, sem_elo, ctx.equipe.id)
    end

    test "papel sem concessão nenhuma não gere nada — nem pelo nome", ctx do
      %{conta: conta} = conta_com_papel(ctx, ctx.equipe)

      assert {:nao, :sem_concessao} =
               Access.pode_gerir_estrutura(ctx.tenant, conta, ctx.equipe.id),
             "`Scrum Master` parece coordenação; a concessão é declarada, nunca inferida do nome"
    end
  end

  describe "dois tenants" do
    test "administradora de um tenant não gere equipe do outro", ctx do
      outro = tenant_fixture()
      outra_org = organization_fixture(outro, "outra")
      equipe_de_la = team_fixture(outro, "T_outra", %{organization: outra_org})

      assert {:nao, _} = Access.pode_gerir_estrutura(outro, ctx.admin, equipe_de_la.id),
             "admin é admin do SEU tenant; fora dele não é ninguém"
    end
  end
end
