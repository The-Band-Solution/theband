defmodule TheBand.Ontology.SEON.EO.AlocacaoTest do
  @moduledoc """
  Alocar uma pessoa a um papel, dentro de uma equipe, com período (T003, T009, T010).

  ## Os dois casos que validam decisões de desenho

  **Dois papéis diferentes na mesma equipe são aceitos.** Acumular Developer e Scrum Master é
  comum em Scrum, e um índice único sem o papel na chave reprovaria — a plataforma ficaria
  incapaz de descrever times reais.

  **O mesmo papel com períodos distintos produz duas linhas.** Quem saiu e voltou tem
  histórico, e um índice único simples proibiria — apagar a linha antiga para permitir a nova
  seria apagar dado. É o que o índice **parcial** resolve.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO

  setup do
    tenant = tenant_fixture()
    {:ok, papel} = EO.create_role(tenant, %{code: "developer", name: "Desenvolvedor"})
    {:ok, outro_papel} = EO.create_role(tenant, %{code: "scrum_master", name: "Scrum Master"})

    organizacao = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_a", %{organization: organizacao})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("U_1", %{name: "Alguém"}))

    %{
      tenant: tenant,
      papel: papel,
      outro_papel: outro_papel,
      equipe: equipe,
      pessoa: pessoa
    }
  end

  describe "alocar" do
    test "o vínculo passa a existir", ctx do
      assert EO.count_memberships(ctx.tenant) == 0

      assert {:ok, vinculo} = alocar(ctx, ctx.papel)

      assert vinculo.organizational_role_id == ctx.papel.id
      assert EO.count_memberships(ctx.tenant) == 1
    end

    test "dois papéis diferentes na mesma equipe são aceitos", ctx do
      {:ok, _} = alocar(ctx, ctx.papel)

      assert {:ok, _} = alocar(ctx, ctx.outro_papel), """
      **Este caso valida a FR-006a**, e um índice único sem o papel na chave o reprovaria.

      Acumular Developer e Scrum Master é comum em Scrum. Recusar produziria uma plataforma
      incapaz de descrever times reais.
      """

      assert EO.count_memberships(ctx.tenant) == 2
    end

    test "o mesmo papel vigente duas vezes é recusado", ctx do
      {:ok, _} = alocar(ctx, ctx.papel)

      assert {:error, :already_allocated} = alocar(ctx, ctx.papel)
      assert EO.count_memberships(ctx.tenant) == 1
    end

    test "o mesmo papel com períodos distintos produz duas linhas", ctx do
      {:ok, primeiro} = alocar(ctx, ctx.papel)
      {:ok, _} = EO.end_allocation(ctx.tenant, primeiro.id, ~U[2026-06-30 00:00:00Z])

      assert {:ok, _} = alocar(ctx, ctx.papel), """
      **Este caso valida o índice parcial.** Quem saiu do papel e voltou tem duas linhas, com
      períodos distintos — um único simples proibiria, e apagar a primeira para permitir a
      segunda seria apagar dado.
      """

      assert EO.count_memberships(ctx.tenant) == 2
    end

    test "sem data de início, grava nulo e não a data de hoje", ctx do
      assert {:ok, vinculo} = alocar(ctx, ctx.papel)

      assert is_nil(vinculo.started_at), """
      Inventar a data de hoje afirmaria que a alocação **começou agora**, e o que se sabe é
      que ninguém disse quando. Nulo é a informação; hoje seria uma afirmação falsa.
      """
    end

    test "fim antes do início é recusado", ctx do
      assert {:error, :period_inverted} =
               EO.allocate(ctx.tenant, %{
                 person_id: ctx.pessoa.id,
                 team_id: ctx.equipe.id,
                 organizational_role_id: ctx.papel.id,
                 started_at: ~U[2026-08-01 00:00:00Z],
                 ended_at: ~U[2026-07-01 00:00:00Z]
               })

      assert EO.count_memberships(ctx.tenant) == 0
    end

    test "a evidência informada passa a apontar para o vínculo", ctx do
      evidencia = evidencia(ctx)

      {:ok, vinculo} =
        EO.allocate(ctx.tenant, %{
          person_id: ctx.pessoa.id,
          team_id: ctx.equipe.id,
          organizational_role_id: ctx.papel.id,
          evidence_id: evidencia.id
        })

      assert recarregar_evidencia(evidencia).promoted_membership_id == vinculo.id
    end
  end

  describe "encerrar" do
    test "grava a data e não reduz a contagem", ctx do
      {:ok, vinculo} = alocar(ctx, ctx.papel)
      antes = EO.count_memberships(ctx.tenant)

      assert {:ok, encerrado} =
               EO.end_allocation(ctx.tenant, vinculo.id, ~U[2026-08-01 00:00:00Z])

      assert encerrado.ended_at == ~U[2026-08-01 00:00:00Z]

      assert EO.count_memberships(ctx.tenant) == antes, """
      **A asserção é a contagem, e não a existência da linha.** "O vínculo existe" passaria
      mesmo se a operação tivesse apagado outro.

      A pessoa desempenhou aquele papel, e isso continua verdade depois de ela sair.
      """
    end

    test "encerrar de novo não reescreve a data da primeira vez", ctx do
      {:ok, vinculo} = alocar(ctx, ctx.papel)
      {:ok, _} = EO.end_allocation(ctx.tenant, vinculo.id, ~U[2026-08-01 00:00:00Z])

      assert {:error, :already_ended} =
               EO.end_allocation(ctx.tenant, vinculo.id, ~U[2026-08-20 00:00:00Z])

      {:ok, intacto} = EO.fetch_membership(ctx.tenant, vinculo.id)

      assert intacto.ended_at == ~U[2026-08-01 00:00:00Z], """
      A segunda tentativa é engano de quem opera. Sobrescrever perderia **quando de fato
      terminou**, que é a única coisa que o registro guarda.
      """
    end

    test "vínculo de outro tenant é não encontrado", ctx do
      {:ok, vinculo} = alocar(ctx, ctx.papel)
      vizinho = tenant_fixture()

      assert {:error, :not_found} =
               EO.end_allocation(vizinho, vinculo.id, ~U[2026-08-01 00:00:00Z])
    end
  end

  # ---------------------------------------------------------------- montagem

  defp alocar(ctx, papel) do
    EO.allocate(ctx.tenant, %{
      person_id: ctx.pessoa.id,
      team_id: ctx.equipe.id,
      organizational_role_id: papel.id
    })
  end

  defp evidencia(ctx) do
    {:ok, evidencia} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: ctx.pessoa.id,
        team_id: ctx.equipe.id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    evidencia
  end

  defp recarregar_evidencia(evidencia) do
    Repo.get!(TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence, evidencia.id)
  end
end
