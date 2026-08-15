defmodule TheBand.Ontology.SEON.SPO.AtividadeTest do
  @moduledoc """
  A ocorrência de atividade executada — identidade, gravação e leitura (T002, T003, T004).

  A primeira materialização de `spo.performed_project_activity`. O que este arquivo
  afirma vale para commits e implantações também, porque a ontologia diz que elas
  compartilham o mesmo princípio de identidade.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity

  setup do
    %{tenant: tenant_fixture(), issue_id: Ecto.UUID.generate()}
  end

  defp evento(issue_id, extra \\ %{}) do
    Map.merge(
      %{
        activity_type: "ClosedEvent",
        occurred_at: ~U[2026-08-12 20:54:47Z],
        subject_type: "issue",
        subject_id: issue_id,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "CE_evento_1"
      },
      extra
    )
  end

  describe "a identidade, e a ausência dentro dela" do
    test "dois nulos no mesmo componente produzem o mesmo hash", ctx do
      base = evento(ctx.issue_id, %{tenant_id: ctx.tenant.id, performer_id: nil})

      assert Activity.internal_id(base) == Activity.internal_id(base), """
      O hash não é determinístico com componente ausente.

      A ontologia exige representação canônica para a ausência justamente por isso:
      sem ela, o mesmo evento recoletado geraria identidade diferente, e a segunda
      coleta duplicaria a linha em vez de reconhecê-la.
      """
    end

    test "nulo e string vazia não são a mesma identidade", ctx do
      sem_id = evento(ctx.issue_id, %{tenant_id: ctx.tenant.id, source_external_id: nil})
      vazio = evento(ctx.issue_id, %{tenant_id: ctx.tenant.id, source_external_id: ""})

      refute Activity.internal_id(sem_id) == Activity.internal_id(vazio), """
      A origem que **não deu** identidade ao evento colidiu com a que deu uma vazia.

      São coisas diferentes, e achatá-las juntaria duas ocorrências distintas numa
      linha só. É o motivo de o marcador de ausência não ser a string vazia.
      """
    end

    test "instantes diferentes não colidem, mesmo com executor nulo", ctx do
      um = evento(ctx.issue_id, %{tenant_id: ctx.tenant.id, performer_id: nil})

      outro =
        evento(ctx.issue_id, %{
          tenant_id: ctx.tenant.id,
          performer_id: nil,
          occurred_at: ~U[2026-08-14 13:01:06Z]
        })

      refute Activity.internal_id(um) == Activity.internal_id(outro)
    end
  end

  describe "gravar a ocorrência" do
    test "a segunda gravação não duplica, e diz :unchanged", ctx do
      {:ok, primeira} = SPO.record_activity(ctx.tenant, evento(ctx.issue_id))
      assert primeira.outcome == :created

      {:ok, segunda} = SPO.record_activity(ctx.tenant, evento(ctx.issue_id))
      assert segunda.outcome == :unchanged

      assert Repo.aggregate(Activity, :count) == 1, """
      A segunda coleta do mesmo evento criou uma linha nova.

      É a FR-003, e a asserção é a **contagem** — não o `outcome`. Um `:unchanged`
      devolvido junto de uma linha extra passaria numa asserção sobre o retorno, e a
      tabela estaria errada do mesmo jeito.
      """
    end

    test "o evento de automação é gravado, com login e sem pessoa", ctx do
      {:ok, atividade} =
        SPO.record_activity(
          ctx.tenant,
          evento(ctx.issue_id, %{
            activity_type: "ProjectV2ItemStatusChangedEvent",
            performer_id: nil,
            performer_login: "github-project-automation"
          })
        )

      assert atividade.outcome == :created
      assert is_nil(atividade.performer_id)

      assert atividade.performer_login == "github-project-automation", """
      A movimentação de robô perdeu o login.

      160 das 357 movimentações medidas em 2026-08-14 são de automação. Sem o login,
      a detecção de antipadrão não distingue um cartão que alguém moveu de um que o
      robô moveu ao fechar a issue — e essa distinção é o `ap02`.
      """
    end

    test "não atualiza: a ocorrência gravada não é reescrita", ctx do
      {:ok, primeira} = SPO.record_activity(ctx.tenant, evento(ctx.issue_id))

      {:ok, segunda} =
        SPO.record_activity(ctx.tenant, evento(ctx.issue_id, %{concept_id: "spo.inventado"}))

      assert segunda.id == primeira.id

      assert is_nil(segunda.concept_id), """
      Um segundo registro reescreveu a ocorrência.

      Uma atividade não muda — ela aconteceu. Deixar a recoleta sobrescrever faria o
      passado depender da última execução da coleta.
      """
    end
  end

  describe "ler a sequência" do
    test "sai em ordem crescente, que é a ordem em que aconteceu", ctx do
      for at <- [~U[2026-08-14 13:01:06Z], ~U[2026-08-10 09:00:00Z], ~U[2026-08-12 20:54:47Z]] do
        {:ok, _} =
          SPO.record_activity(
            ctx.tenant,
            evento(ctx.issue_id, %{occurred_at: at, source_external_id: "ev-#{at}"})
          )
      end

      instantes =
        ctx.tenant
        |> SPO.list_activities("issue", ctx.issue_id)
        |> Enum.map(& &1.occurred_at)

      assert instantes == Enum.sort(instantes, DateTime), """
      A sequência saiu fora de ordem cronológica.

      É a história do que aconteceu com a issue, e invertê-la faria a tela contá-la de
      trás para frente.
      """
    end

    test "a contagem por tipo inclui os que a rede não nomeia", ctx do
      {:ok, _} =
        SPO.record_activity(
          ctx.tenant,
          evento(ctx.issue_id, %{
            activity_type: "ClosedEvent",
            concept_id: "spo.performed_project_activity",
            source_external_id: "a"
          })
        )

      {:ok, _} =
        SPO.record_activity(
          ctx.tenant,
          evento(ctx.issue_id, %{
            activity_type: "LabeledEvent",
            concept_id: nil,
            source_external_id: "b"
          })
        )

      tipos = SPO.count_activity_types(ctx.tenant)

      assert Enum.any?(tipos, &(&1.type == "LabeledEvent" and is_nil(&1.concept))), """
      O tipo sem conceito sumiu da contagem.

      São exatamente eles que dizem **o que a rede ainda não nomeia**, e é essa lista
      que permite decidir o que mapear a seguir. Filtrá-los esconderia a informação que
      a contagem existe para dar.
      """

      assert Enum.sum(Enum.map(tipos, & &1.count)) == 2
    end
  end

  describe "o isolamento entre tenants" do
    test "a atividade de um tenant não aparece no outro", ctx do
      outro = tenant_fixture()

      {:ok, _} = SPO.record_activity(ctx.tenant, evento(ctx.issue_id))

      assert SPO.list_activities(outro, "issue", ctx.issue_id) == []
      assert SPO.count_activity_types(outro) == []
    end

    test "o mesmo evento em dois tenants produz duas linhas", ctx do
      outro = tenant_fixture()

      {:ok, um} = SPO.record_activity(ctx.tenant, evento(ctx.issue_id))
      {:ok, dois} = SPO.record_activity(outro, evento(ctx.issue_id))

      assert um.outcome == :created

      assert dois.outcome == :created, """
      O segundo tenant recebeu `:unchanged` de um evento que ele nunca viu.

      `tenant_id` é o primeiro componente do critério de identidade, e sem ele dois
      tenants que observam a mesma organização pública dividiriam ocorrências.
      """

      assert Repo.aggregate(Activity, :count) == 2
    end
  end
end
