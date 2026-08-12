defmodule TheBand.Ontology.SEON.CMPO.InaccessibleTest do
  @moduledoc """
  A marca de inacessível: desde quando, por quê, e o que a limpa (T001, T004, T005, T006).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Sources.ConnectedTool

  setup do
    tenant = tenant_fixture()
    org = organization_fixture(tenant, "acme")
    tool = ferramenta(tenant)
    %{tenant: tenant, org: org, tool: tool, observado: observar(tenant, org, tool, "repo-a")}
  end

  describe "desde quando" do
    test "a data é gravada na primeira falha e preservada na segunda", ctx do
      {:ok, primeira} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, "DNS não resolveu")
      assert primeira.inaccessible_since

      {:ok, segunda} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, "outra falha, depois")

      assert segunda.inaccessible_since == primeira.inaccessible_since, """
      A data se moveu na segunda falha.

      Ela responde **desde quando** a plataforma não alcança, e não "quando alguém tentou por
      último". Com a coleta tentando de novo a cada execução, sobrescrever a data faria um
      repositório inacessível há dez dias parecer novo em toda coleta — e ninguém distinguiria
      problema crônico de falha de agora.
      """

      assert segunda.inaccessible_reason == "outra falha, depois", """
      O motivo precisa carregar a **última** falha: é ele que decide se alguém age. Preservar os
      dois campos seria o defeito oposto.
      """
    end

    test "motivo longo é gravado sem levantar", ctx do
      longo = String.duplicate("m", 500)

      assert {:ok, marcado} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, longo), """
      Gravar um motivo de 500 caracteres levantou.

      A coluna era `varchar(255)`, e sem `validate_length` o valor longo vai ao banco e levanta —
      o tratamento de erro da coleta cobre changeset inválido, não exceção do driver, então a
      fase cai. É a L05: coluna de diagnóstico não tem limite arbitrário.
      """

      assert String.length(marcado.inaccessible_reason) == 500
    end
  end

  describe "o que a coleta deve consultar" do
    test "o inacessível volta para a lista", ctx do
      {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, "DNS não resolveu")

      ids =
        ctx.tenant |> CMPO.list_collectable(ctx.tool.id) |> Enum.map(& &1.observed_repository_id)

      assert ctx.observado in ids, """
      O repositório inacessível ficou fora da lista, e é o defeito inteiro da issue #213: ele é
      filtrado antes da fase que limparia a marca, então a cura declarada — "alcançou, limpa" —
      nunca é alcançada.
      """
    end

    test "o excluído fica fora", ctx do
      user = user_fixture(ctx.tenant)
      {:ok, _} = CMPO.exclude_from_observation(ctx.tenant, ctx.observado, user.id)

      ids =
        ctx.tenant |> CMPO.list_collectable(ctx.tool.id) |> Enum.map(& &1.observed_repository_id)

      refute ctx.observado in ids
    end

    test "excluído E inacessível fica fora: a exclusão vence", ctx do
      user = user_fixture(ctx.tenant)
      {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, "DNS não resolveu")
      {:ok, _} = CMPO.exclude_from_observation(ctx.tenant, ctx.observado, user.id)

      ids =
        ctx.tenant |> CMPO.list_collectable(ctx.tool.id) |> Enum.map(& &1.observed_repository_id)

      refute ctx.observado in ids, """
      A exclusão é decisão de **alguém**; a inacessibilidade é inferência da plataforma. Tentar
      um repositório que o tenant excluiu desfaria a decisão dele — e é o que FR-004 proíbe.
      """
    end

    test "sem marca nenhuma, está na lista", ctx do
      ids =
        ctx.tenant |> CMPO.list_collectable(ctx.tool.id) |> Enum.map(& &1.observed_repository_id)

      assert ctx.observado in ids
    end
  end

  describe "limpar a marca" do
    test "limpa os dois campos", ctx do
      {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, ctx.observado, "DNS não resolveu")
      {:ok, limpo} = CMPO.clear_inaccessible(ctx.tenant, ctx.observado)

      assert is_nil(limpo.inaccessible_since)

      assert is_nil(limpo.inaccessible_reason), """
      O motivo ficou para trás, e a tela passaria a exibir o motivo de um repositório que está
      acessível — afirmação falsa sobre o estado atual.
      """
    end
  end

  defp observar(tenant, org, tool, nome) do
    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: org.id,
        name: nome,
        qualified_name: "acme/#{nome}",
        url: "https://github.com/acme/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{nome}"
      })

    {:ok, observado} = CMPO.observe_repository(tenant, tool.id, repo.id)
    observado.id
  end

  defp ferramenta(tenant) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    tool
  end
end
