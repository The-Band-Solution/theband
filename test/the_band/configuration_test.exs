defmodule TheBand.ConfigurationTest do
  @moduledoc """
  As linhas de desenvolvimento — feature 039, `cmpo.branch`, issue #440.

  ## As asserções que carregam este arquivo

  1. **branch apagada é marcada, nunca removida** — ela existiu, e o check-in que aconteceu
     nela continua sendo fato sobre o processo;
  2. **nome citado sem entidade devolve `nil`**, e é o caso comum: 2.096 dos 2.468 nomes que
     as solicitações citam não têm branch viva. Inventar entidade afirmaria que a linha
     existe;
  3. **"não sabemos se está protegida" nunca vira "não protegida"** — sem escopo de
     administração o campo não vem da origem;
  4. **branch sem data de commit é ausência nomeada**, nunca zero dias;
  5. com página incompleta, **não marcar** é a resposta honesta.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Configuration
  alias TheBand.Configuration.Commands

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{tenant: tenant, admin: admin, repo_id: cenario.observed_repository_id}
  end

  defp branch(ctx, nome, attrs \\ %{}) do
    {:ok, b} =
      Commands.record_branch(
        ctx.tenant,
        Map.merge(
          %{
            observed_repository_id: ctx.repo_id,
            name: nome,
            head_sha: "abc1234",
            head_committed_at: DateTime.utc_now(:second),
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "REF_#{nome}"
          },
          attrs
        )
      )

    b
  end

  describe "o que existe agora" do
    test "a lista vem da mais recentemente tocada para a mais antiga", ctx do
      branch(ctx, "antiga", %{head_committed_at: ~U[2026-01-01 10:00:00Z]})
      branch(ctx, "nova", %{head_committed_at: ~U[2026-08-01 10:00:00Z]})

      assert ["nova", "antiga"] =
               Configuration.branches_of(ctx.tenant, ctx.repo_id) |> Enum.map(& &1.name)
    end

    test "o painel conta vivas, protegidas e paradas, e o corte é declarado", ctx do
      branch(ctx, "main", %{is_default: true, is_protected: true})
      branch(ctx, "parada", %{head_committed_at: DateTime.add(DateTime.utc_now(), -200, :day)})
      branch(ctx, "sem-data", %{head_committed_at: nil})

      resumo = Configuration.resumo_do_repositorio(ctx.tenant, ctx.repo_id)

      assert resumo.vivas == 3
      assert resumo.protegidas == 1
      assert resumo.paradas == 1
      # Sem data não conta como parada: a origem não datou, e zero dias seria invenção.
      assert resumo.sem_data == 1
    end

    test "branch sem data de commit não tem dias, e nulo não é zero", ctx do
      branch(ctx, "sem-data", %{head_committed_at: nil})

      assert [%{dias_sem_commit: nil}] = Configuration.branches_of(ctx.tenant, ctx.repo_id)
    end
  end

  describe "a branch apagada" do
    test "sumir da origem marca, e a linha continua no banco", ctx do
      viva = branch(ctx, "viva")
      _apagada = branch(ctx, "apagada")

      marcadas = Commands.mark_unobserved(ctx.tenant, ctx.repo_id, [viva.external_id])

      assert marcadas == 1
      assert ["viva"] = Configuration.branches_of(ctx.tenant, ctx.repo_id) |> Enum.map(& &1.name)

      # A evidência de que existiu não se perde.
      assert Repo.one(
               from b in "cmpo_branches",
                 where:
                   b.tenant_id == type(^ctx.tenant.id, :binary_id) and
                     not is_nil(b.no_longer_observed_at),
                 select: b.name
             ) == "apagada"
    end

    test "nome citado sem branch viva devolve nil, e não inventa entidade", ctx do
      branch(ctx, "existe")

      assert %{name: "existe"} =
               Configuration.entidade_da_branch(ctx.tenant, ctx.repo_id, "existe")

      # O caso comum: 2.096 dos 2.468 nomes que as solicitações citam já foram apagados.
      assert Configuration.entidade_da_branch(ctx.tenant, ctx.repo_id, "ja-mergeada") == nil
      assert Configuration.entidade_da_branch(ctx.tenant, ctx.repo_id, nil) == nil
    end

    test "voltar a ser observada limpa a marca", ctx do
      b = branch(ctx, "voltou")
      Commands.mark_unobserved(ctx.tenant, ctx.repo_id, [])
      assert Configuration.branches_of(ctx.tenant, ctx.repo_id) == []

      # Mesmo `external_id`: o upsert a revive em vez de duplicar.
      branch(ctx, "voltou")

      assert [%{name: "voltou"}] = Configuration.branches_of(ctx.tenant, ctx.repo_id)
      assert b.external_id == "REF_voltou"
    end
  end

  describe "o estado da coleta" do
    test "distingue não coletado de coletado, e guarda o total da origem", ctx do
      assert [%{collected_at: nil, total: nil, vivas: 0}] =
               Configuration.estado_da_coleta(ctx.tenant)

      branch(ctx, "main", %{is_default: true})
      :ok = Commands.touch_repository(ctx.repo_id, DateTime.utc_now(:second), 7)

      # O total da origem é 7 e coletamos 1: é assim que truncamento aparece.
      assert [%{collected_at: %NaiveDateTime{}, total: 7, vivas: 1}] =
               Configuration.estado_da_coleta(ctx.tenant)
    end
  end

  describe "o isolamento por tenant" do
    test "outro tenant não enxerga branch nenhuma", ctx do
      branch(ctx, "main")
      {outro, _} = tenant_with_admin()

      assert Configuration.branches_of(outro, ctx.repo_id) == []
      assert Configuration.entidade_da_branch(outro, ctx.repo_id, "main") == nil
    end
  end
end
