defmodule TheBand.Ontology.SEON.EO.PromocaoDeEvidenciaTest do
  @moduledoc """
  A promoção de evidência a vínculo — feature 043, issue #317.

  ## O que estes casos protegem

  Que a promoção seja **ato de uma pessoa**, com autor. Que o nível de acesso da plataforma
  **não** chegue a quem decide. Que o papel seja da organização da equipe. E que a data de
  início seja o que alguém disse, e nunca o que a coleta viu.

  Os quatro são decisões que se desfazem sem parecer erro.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()

    org = organization_fixture(tenant, "acme")
    outra_org = organization_fixture(tenant, "outra")
    user = user_fixture(tenant)

    equipe = team_fixture(tenant, "T_a", %{organization: org})
    equipe_da_outra = team_fixture(tenant, "T_b", %{organization: outra_org})

    {:ok, pessoa} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_1", %{name: "Alguém", login: "alguem"})
      )

    {:ok, evidencia} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MAINTAINER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    %{
      tenant: tenant,
      org: org,
      outra_org: outra_org,
      user: user,
      equipe: equipe,
      equipe_da_outra: equipe_da_outra,
      pessoa: pessoa,
      evidencia: evidencia
    }
  end

  describe "promover" do
    test "cria o vínculo com autor, e a evidência aponta para ele", ctx do
      assert {:ok, vinculo} =
               EO.promote_evidence(
                 ctx.tenant,
                 ctx.evidencia.id,
                 {:catalogo, "sro.scrum_master_role"},
                 ctx.user.id
               )

      assert vinculo.declared_by_user_id == ctx.user.id, """
      **Promover é ato de uma pessoa.** Nenhuma origem fornece papel organizacional, e a
      FR-007 da feature 021 recusa observá-lo — o autor é o que torna a decisão rastreável.
      """

      {:ok, recarregada} = EO.fetch_evidence(ctx.tenant, ctx.evidencia.id)
      assert recarregada.promoted_membership_id == vinculo.id
    end

    test "o papel do catálogo é materializado na própria promoção", ctx do
      papeis_antes = EO.list_organization_roles(ctx.tenant, ctx.org.id)
      assert Enum.all?(papeis_antes, &is_nil(&1.id)), "nenhuma linha antes"

      {:ok, vinculo} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      {:ok, papel} = EO.fetch_role(ctx.tenant, vinculo.organizational_role_id)

      assert papel.catalog_concept_id == "sro.developer_role", """
      A linha nasce **dentro** da promoção. Materializar antes obrigaria a tela a fazê-lo, e
      materializar sem promover deixaria lixo se a promoção falhasse.
      """
    end

    test "a evidência já promovida não é promovida de novo", ctx do
      {:ok, _} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      assert {:error, :already_promoted} =
               EO.promote_evidence(
                 ctx.tenant,
                 ctx.evidencia.id,
                 {:catalogo, "sro.client_role"},
                 ctx.user.id
               )
    end
  end

  describe "a data de início" do
    test "o que a pessoa informa é o que fica gravado", ctx do
      quando = ~U[2026-03-01 00:00:00Z]

      {:ok, vinculo} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id,
          started_at: quando
        )

      assert DateTime.to_date(vinculo.started_at) == ~D[2026-03-01]
    end

    test "sem data informada fica NULO, e nunca a data de hoje", ctx do
      {:ok, vinculo} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      assert is_nil(vinculo.started_at), """
      **Branco é desconhecido**, não hoje. Carimbar a data corrente afirmaria que a pessoa
      assumiu o papel agora — e a origem não sabe desde quando ela está na equipe.
      """
    end

    test "a data de início NÃO vem da observação da evidência", ctx do
      {:ok, vinculo} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      refute vinculo.started_at == ctx.evidencia.observed_at, """
      `observed_at` é **quando a coleta viu**. As 101 evidências reais têm observação entre
      2026-08-09 e 2026-08-14 — que é quando a plataforma foi ligada, não quando as pessoas
      entraram nas equipes.

      Derivar o início dela carimbaria agosto em quem está lá desde janeiro. É o mesmo defeito
      do `collected_at` que a feature 042 descartou.
      """
    end
  end

  describe "o papel tem de ser da organização da equipe" do
    test "papel de outra organização é recusado", ctx do
      {:ok, papel_alheio} =
        EO.create_role(
          ctx.tenant,
          ctx.outra_org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      assert {:error, :role_from_another_organization} =
               EO.promote_evidence(
                 ctx.tenant,
                 ctx.evidencia.id,
                 {:existente, papel_alheio.id},
                 ctx.user.id
               )
    end

    test "papel da mesma organização é aceito", ctx do
      {:ok, papel} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      assert {:ok, _} =
               EO.promote_evidence(
                 ctx.tenant,
                 ctx.evidencia.id,
                 {:existente, papel.id},
                 ctx.user.id
               )
    end
  end

  describe "o nível de acesso não chega a quem decide" do
    test "pending_evidence não devolve o campo", ctx do
      assert [pendente] = EO.pending_evidence(ctx.tenant, ctx.equipe.id)

      refute Map.has_key?(pendente, :platform_access_level), """
      **A garantia está no CONTRATO, e não na tela.** Se o valor não chega à camada de
      apresentação, nenhum template pode exibi-lo por descuido.

      `MAINTAINER`, `MEMBER` e nulo afirmam a mesma coisa — que a pessoa é membro. A diferença
      é permissão na ferramenta, não função. Exibi-lo ao lado de um seletor de papel faria dele
      uma dica, por mais que o texto negasse.
      """

      assert pendente.person_name == "Alguém"
      assert pendente.organization_id == ctx.org.id
    end

    test "a evidência promovida sai da lista de pendentes", ctx do
      assert length(EO.pending_evidence(ctx.tenant, ctx.equipe.id)) == 1

      {:ok, _} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      assert EO.pending_evidence(ctx.tenant, ctx.equipe.id) == []
    end
  end

  describe "o tamanho da equipe" do
    test "uma pessoa com dois papéis conta UMA vez", ctx do
      {:ok, um} =
        EO.promote_evidence(
          ctx.tenant,
          ctx.evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.user.id
        )

      {:ok, papel_extra} =
        EO.materialize_catalog_role(ctx.tenant, ctx.org.id, "sro.scrum_master_role")

      {:ok, dois} =
        EO.allocate(ctx.tenant, %{
          person_id: ctx.pessoa.id,
          team_id: ctx.equipe.id,
          organizational_role_id: papel_extra.id,
          declared_by_user_id: ctx.user.id
        })

      refute um.id == dois.id, "são dois vínculos, e os dois valem"

      assert EO.team_size(ctx.tenant, ctx.equipe.id) == 1, """
      **A equipe tem UMA pessoa**, com dois papéis. Somar vínculos faria a equipe parecer
      maior do que é — e o erro passa despercebido porque o número fica plausível.
      """
    end
  end
end
