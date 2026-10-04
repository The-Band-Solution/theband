defmodule TheBandWeb.VerificationLive.PeopleRecorteTest do
  @moduledoc """
  O aviso de recorte de *"Who merged red"* diz a regra que o recorte aplica — feature 076, T005
  (DS4 decidida em (a) em 2026-10-04; issue #1185).

  ## O defeito

  O aviso prometia *"whoever you lead by declared role"*, e a lista é recortada por
  `Tenants.pessoas_alcancadas/2`, que não aplica a liderança declarada (quem a aplica é
  `pode_ver/3`). Quem lidera por papel e não tem escopo lia que veria os liderados, e não os via.

  ## O cenário

  A líder está na equipe Delivery com um papel que tem concessão de escopo `organization`; a
  pessoa liderada está na Discovery, da mesma organização, e integrou uma solicitação vermelha.
  `pode_ver/3` alcança a liderada pela liderança declarada; `pessoas_alcancadas/2`, não.

  ## As asserções que carregam este arquivo

  1. **controle**: a administração vê o login da liderada na lista, e `pode_ver/3` diz que a líder
     a alcança pela liderança — sem os dois, o `refute` abaixo não mediria nada (L50);
  2. a líder **não** vê o login da liderada, e a frase não promete que veria: nem *"declared
     role"*, e sim a regra de `pessoas_alcancadas/2`.

  A mesma frase estava em `/process` (`ProcessLive.Index`), sobre o mesmo recorte; corrigida junto.

  **Defeito a injetar**: devolver a frase antiga; a asserção da frase reprova.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    repo_id = cenario_real(tenant).observed_repository_id
    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")

    lider = pessoa(tenant, "lidernomeobvio")
    liderada = pessoa(tenant, "lideradanomeobvio")

    delivery = equipe(tenant, admin, "Delivery", org.id)
    discovery = equipe(tenant, admin, "Discovery", org.id)
    {:ok, lideranca} = EO.create_role(tenant, org.id, %{code: "head", name: "Head"}, admin.id)
    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    aloca(tenant, admin, lider, delivery, lideranca)
    aloca(tenant, admin, liderada, discovery, dev)
    {:ok, _} = EO.declare_grant(tenant, lideranca.id, "organization", admin.id)

    {:ok, conta_lider} =
      Tenants.create_user(tenant, %{
        "email" => "lider-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    conta_lider = elo_de_identidade(tenant, conta_lider, lider)
    integrou_vermelho(tenant, repo_id, liderada)

    %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      conta_lider: conta_lider,
      liderada: liderada
    }
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_#{login}", %{name: login, login: login, account_type: "person"})
      )

    p
  end

  defp equipe(tenant, admin, nome, organization_id) do
    {:ok, t} = EO.create_declared_team(tenant, nome, admin.id)

    # `create_declared_team/3` não recebe organização; o escopo `organization` sobe por ela.
    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^t.id, :binary_id),
        update: [set: [organization_id: type(^organization_id, :binary_id)]]
      ),
      []
    )

    t
  end

  defp aloca(tenant, admin, pessoa, equipe, papel) do
    {:ok, _} =
      EO.allocate(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -86_400),
        declared_by_user_id: admin.id
      })
  end

  defp integrou_vermelho(tenant, repo_id, pessoa) do
    n = System.unique_integer([:positive])

    {:ok, _} =
      ChangeCommands.record_change_request(tenant, %{
        observed_repository_id: repo_id,
        number: n,
        title: "pr #{n}",
        state: "MERGED",
        author_login: pessoa.login,
        author_person_id: pessoa.id,
        merged_check_state: "FAILURE",
        merged_check_contexts: 1,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{n}"
      })
  end

  test "controle: a administração vê a liderada, e a liderança declarada a alcança", ctx do
    {:ok, _live, html} = live(log_in(ctx.conn, ctx.admin), ~p"/work/verifications/people")
    assert html =~ ctx.liderada.login

    assert {:ok, _motivo} = Tenants.pode_ver(ctx.tenant, ctx.conta_lider, ctx.liderada.id)
  end

  test "a líder sem escopo não vê a liderada, e a frase não promete que veria", ctx do
    {:ok, _live, html} = live(log_in(ctx.conn, ctx.conta_lider), ~p"/work/verifications/people")
    # A frase quebra linha no markup; o que se lê é o texto corrido.
    html = String.replace(html, ~r/\s+/, " ")

    assert html =~ "This list shows only the people you reach."
    assert html =~ "the people on the teams in your scope"
    assert html =~ "the teams of an organization in your scope"
    assert html =~ "Leading a team through a role does not add people to this list"
    refute html =~ "declared role"
    refute html =~ ctx.liderada.login
  end

  # O mesmo defeito, na mesma frase, em `/process` (a tabela de atividade por pessoa nomeada).
  test "a frase de /process também diz a regra do recorte", ctx do
    {:ok, _live, html} = live(log_in(ctx.conn, ctx.conta_lider), ~p"/process")
    html = String.replace(html, ~r/\s+/, " ")

    assert html =~ "This table shows only the people you reach."
    assert html =~ "the people on the teams in your scope"
    assert html =~ "Leading a team through a role does not add people to this table"
    refute html =~ "declared role"
  end
end
