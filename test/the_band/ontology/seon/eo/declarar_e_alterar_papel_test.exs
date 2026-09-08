defmodule TheBand.Ontology.SEON.EO.DeclararEAlterarPapelTest do
  @moduledoc """
  Declarar e alterar o papel — feature 060, T018: FR-015 a FR-018.

  ## As quatro asserções que carregam este arquivo

  1. **declarar num vínculo observado COMPLETA o mesmo vínculo** — mesmo `id` (ADR 0008). Se
     inserisse um segundo, a pessoa contaria duas vezes na equipe e a evidência apontaria para
     o vínculo errado;
  2. **alterar deixa DOIS registros**, e o histórico é a linha encerrada. Não há tabela de
     histórico de papel, e a pergunta "que papel em março" se responde lendo os vínculos;
  3. **um segundo papel é aceito** (FR-018) — declarar não é trocar. É o caso que fazia
     `Repo.one` levantar antes da T014/T016;
  4. **papel de outra organização é recusado com nome**, porque a garantia atravessa duas
     tabelas e não pode ser `CHECK`.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo

  @dia_1 ~U[2026-01-01 00:00:00Z]
  @dia_30 ~U[2026-01-30 00:00:00Z]

  setup do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, autor.id)
    {:ok, sm} = EO.create_role(tenant, org.id, %{code: "sm", name: "Scrum Master"}, autor.id)

    %{tenant: tenant, autor: autor, org: org, equipe: equipe, ana: ana, dev: dev, sm: sm}
  end

  defp vinculos(ctx) do
    Repo.all(
      from m in TeamMembership,
        where: m.tenant_id == ^ctx.tenant.id and m.team_id == ^ctx.equipe.id,
        order_by: m.inserted_at
    )
  end

  defp observar(ctx) do
    {:ok, evidencia} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: ctx.ana.id,
        team_id: ctx.equipe.id,
        person_external_id: ctx.ana.external_id,
        team_external_id: ctx.equipe.external_id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: @dia_1
      })

    evidencia
  end

  describe "declarar o papel (FR-015, FR-016)" do
    test "num vínculo OBSERVADO, completa o mesmo vínculo — mesmo id", ctx do
      observar(ctx)
      assert [observado] = vinculos(ctx)
      assert is_nil(observado.organizational_role_id)

      assert {:ok, declarado} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:existente, ctx.dev.id},
                 ctx.autor.id
               )

      assert declarado.id == observado.id, """
      Declarar tem de COMPLETAR o vínculo observado, e não inserir um segundo. Com dois, a
      pessoa conta duas vezes na equipe e a evidência aponta para o vínculo errado (ADR 0008).
      """

      assert [so_um] = vinculos(ctx)
      assert so_um.organizational_role_id == ctx.dev.id
      assert so_um.declared_by_user_id == ctx.autor.id
      refute is_nil(so_um.declared_at), "a declaração precisa do instante junto do autor"
    end

    test "sem vínculo nenhum, insere a declaração", ctx do
      assert {:ok, novo} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:existente, ctx.dev.id},
                 ctx.autor.id
               )

      assert [so_um] = vinculos(ctx)
      assert so_um.id == novo.id
      assert so_um.organizational_role_id == ctx.dev.id
    end

    test "início vazio FICA vazio, e nunca vira hoje (FR-016)", ctx do
      {:ok, sem_data} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      assert is_nil(sem_data.started_at), """
      Campo vazio é DESCONHECIDO, nunca hoje. Preencher com hoje afirmaria que a pessoa assumiu
      o papel agora, e o que se sabe é que ninguém disse quando.
      """
    end

    test "início informado é respeitado", ctx do
      {:ok, com_data} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id,
          started_at: @dia_1
        )

      assert com_data.started_at == @dia_1
    end

    test "um SEGUNDO papel é aceito — declarar não é trocar (FR-018)", ctx do
      {:ok, _} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id,
          started_at: @dia_1
        )

      assert {:ok, _} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:existente, ctx.sm.id},
                 ctx.autor.id,
                 started_at: @dia_1
               )

      assert length(vinculos(ctx)) == 2, "o segundo papel não foi aceito"

      # E a pessoa continua contando UMA vez: dois papéis não são duas pessoas.
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, @dia_30) == 1
    end

    test "o MESMO papel de novo é recusado com nome", ctx do
      {:ok, _} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      assert {:error, :already_allocated} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:existente, ctx.dev.id},
                 ctx.autor.id
               )

      assert length(vinculos(ctx)) == 1
    end

    test "papel de OUTRA organização é recusado", ctx do
      outra = organization_fixture(ctx.tenant, "outra")

      {:ok, alheio} =
        EO.create_role(ctx.tenant, outra.id, %{code: "dev", name: "Dev"}, ctx.autor.id)

      assert {:error, :role_from_another_organization} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:existente, alheio.id},
                 ctx.autor.id
               )

      assert vinculos(ctx) == []
    end

    test "papel do CATÁLOGO é materializado na organização da equipe", ctx do
      assert {:ok, declarado} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:catalogo, "sro.scrum_master_role"},
                 ctx.autor.id
               )

      refute is_nil(declarado.organizational_role_id)

      {:ok, papel} = EO.fetch_role(ctx.tenant, declarado.organizational_role_id)

      assert papel.organization_id == ctx.org.id, """
      O papel do catálogo nasce na organização DA EQUIPE. Numa outra, a próxima declaração o
      recusaria por `:role_from_another_organization` — e o papel ficaria órfão.
      """
    end

    test "conceito fora do catálogo é recusado, e nada é materializado", ctx do
      assert {:error, motivo} =
               EO.declare_role(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 {:catalogo, "sro.papel_inventado"},
                 ctx.autor.id
               )

      assert motivo in [:not_in_catalog, :not_found]
      assert vinculos(ctx) == []
    end
  end

  describe "alterar o papel (FR-017)" do
    test "deixa DOIS registros: o antigo encerrado e o novo a partir da mesma data", ctx do
      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id,
          started_at: @dia_1
        )

      assert {:ok, %{encerrado: encerrado, novo: novo}} =
               EO.change_role(
                 ctx.tenant,
                 antigo.id,
                 {:existente, ctx.sm.id},
                 ctx.autor.id,
                 desde: @dia_30
               )

      assert encerrado.id == antigo.id
      assert encerrado.ended_at == @dia_30
      assert encerrado.ended_by_user_id == ctx.autor.id

      assert novo.organizational_role_id == ctx.sm.id
      assert novo.started_at == @dia_30, "o novo papel começa onde o antigo terminou"

      # O HISTÓRICO É A LINHA ENCERRADA. Duas linhas, e a pergunta "que papel em 15 de janeiro"
      # tem resposta sem tabela de histórico.
      assert length(vinculos(ctx)) == 2

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z]) == 1,
             "a troca de papel não pode mudar quantas pessoas estavam na equipe antes dela"
    end

    test "sem data, a troca é agora", ctx do
      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      antes = DateTime.utc_now(:second)

      {:ok, %{encerrado: encerrado, novo: novo}} =
        EO.change_role(ctx.tenant, antigo.id, {:existente, ctx.sm.id}, ctx.autor.id)

      assert DateTime.compare(encerrado.ended_at, antes) != :lt
      assert encerrado.ended_at == novo.started_at, "as duas datas têm de ser a mesma"
    end

    test "trocar para o papel que a pessoa já tem é recusado, e NADA muda", ctx do
      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      assert {:error, :already_allocated} =
               EO.change_role(ctx.tenant, antigo.id, {:existente, ctx.dev.id}, ctx.autor.id)

      # A TRANSAÇÃO desfez o encerramento. Sem ela, a pessoa ficaria na equipe sem papel —
      # indistinguível de um vínculo observado, que significa outra coisa.
      assert [so_um] = vinculos(ctx)
      assert is_nil(so_um.ended_at), "o encerramento não foi desfeito pelo rollback"
      assert so_um.organizational_role_id == ctx.dev.id
    end

    test "vínculo já encerrado é recusado", ctx do
      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      {:ok, _} = EO.end_allocation(ctx.tenant, antigo.id, @dia_30, ctx.autor.id)

      assert {:error, :already_ended} =
               EO.change_role(ctx.tenant, antigo.id, {:existente, ctx.sm.id}, ctx.autor.id)
    end

    test "papel de outra organização é recusado, e o antigo continua vigente", ctx do
      outra = organization_fixture(ctx.tenant, "outra")

      {:ok, alheio} =
        EO.create_role(ctx.tenant, outra.id, %{code: "x", name: "X"}, ctx.autor.id)

      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      assert {:error, :role_from_another_organization} =
               EO.change_role(ctx.tenant, antigo.id, {:existente, alheio.id}, ctx.autor.id)

      assert [so_um] = vinculos(ctx)
      assert is_nil(so_um.ended_at)
    end

    test "vínculo de outro tenant não é encontrado", ctx do
      vizinho = tenant_fixture()

      {:ok, antigo} =
        EO.declare_role(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          {:existente, ctx.dev.id},
          ctx.autor.id
        )

      assert {:error, :not_found} =
               EO.change_role(vizinho, antigo.id, {:existente, ctx.sm.id}, ctx.autor.id)
    end
  end
end
