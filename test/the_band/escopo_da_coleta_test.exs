defmodule TheBand.EscopoDaColetaTest do
  @moduledoc """
  Cada fase coleta só os repositórios da **sua** ferramenta — issue #446.

  ## Por que este arquivo existe

  A pessoa mantenedora notou que sincronizar as três organizações de uma vez dava erro.
  Investigado: `observed_repositories.connected_tool_id` é gravado desde sempre por
  `GithubWorkItems`, e as **cinco** fases seguintes ignoravam a coluna — percorriam o tenant
  inteiro.

  Medido em 2026-08-19: 3 ferramentas com 121, 25 e 14 repositórios. Sincronizar as três
  percorria **480** em vez de 160, concorrentemente, e cada coleta usava a **própria
  credencial** para repositórios das outras duas. O 404 resultante marcava o repositório como
  percorrido e vazio — **ausência de acesso lida como ausência de dado**.

  ## A pré-condição que nenhum teste criava

  Com uma ferramenta só, filtrar por tenant e filtrar por ferramenta dão o mesmo resultado, e
  todo teste passa. É a L62 na forma mais pura: o defeito só existe com **duas** ferramentas
  no mesmo tenant, e nenhuma fixture criava a segunda.

  Este arquivo cria duas e não passa por HTTP nenhum: mede **o que cada fase enxerga**, que é
  onde o defeito vive.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.{CMPO, EO}
  alias TheBand.Sources.{ConnectedTool, ToolCredential}

  setup do
    {tenant, admin} = tenant_with_admin()

    uma = ferramenta(tenant, "org-uma")
    outra = ferramenta(tenant, "org-outra")

    %{
      tenant: tenant,
      admin: admin,
      uma: uma,
      outra: outra,
      repo_da_uma: repositorio_observado(tenant, uma, "org-uma/alpha"),
      repo_da_outra: repositorio_observado(tenant, outra, "org-outra/beta")
    }
  end

  defp ferramenta(tenant, login) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: login
      })
      |> Repo.insert()

    {:ok, _} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: "de #{login}",
        secret: "token-de-#{login}",
        last_four: "ken1",
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    tool
  end

  defp repositorio_observado(tenant, tool, qualified_name) do
    [login, name] = String.split(qualified_name, "/")

    {:ok, org} =
      EO.upsert_organization_from_source(tenant, %{
        login: login,
        name: login,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "O_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: org.id,
        name: name,
        qualified_name: qualified_name,
        url: "https://github.com/#{qualified_name}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{name}",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, observado} = CMPO.observe_repository(tenant, tool.id, repo.id)
    observado.id
  end

  # O que a fase enxergaria: a mesma consulta que ela faz, com o filtro que ela usa agora.
  defp escopo(tenant, tool) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where:
          r.tenant_id == type(^tenant.id, :binary_id) and
            r.connected_tool_id == type(^tool.id, :binary_id) and is_nil(r.excluded_at),
        select: f.qualified_name
    )
  end

  test "a observação grava de qual ferramenta o repositório é", ctx do
    # É o dado que sempre existiu e que as fases ignoravam.
    assert Repo.one!(
             from r in "observed_repositories",
               where: r.id == type(^ctx.repo_da_uma, :binary_id),
               select: type(r.connected_tool_id, :binary_id)
           ) == ctx.uma.id
  end

  test "cada ferramenta enxerga só o repositório dela", ctx do
    assert escopo(ctx.tenant, ctx.uma) == ["org-uma/alpha"]
    assert escopo(ctx.tenant, ctx.outra) == ["org-outra/beta"]
  end

  test "o filtro só por tenant enxergaria os dois — é o defeito, escrito", ctx do
    # Esta é a consulta ANTIGA. O teste a mantém para deixar registrado o que mudou: com uma
    # ferramenta só, as duas consultas dão o mesmo resultado e nenhum teste veria diferença.
    todos =
      Repo.all(
        from r in "observed_repositories",
          join: f in "cmpo_source_repositories",
          on: f.id == r.source_repository_id,
          where: r.tenant_id == type(^ctx.tenant.id, :binary_id) and is_nil(r.excluded_at),
          select: f.qualified_name
      )

    assert Enum.sort(todos) == ["org-outra/beta", "org-uma/alpha"]
    # E o escopo correto é estritamente menor.
    assert length(escopo(ctx.tenant, ctx.uma)) < length(todos)
  end

  test "excluir da observação tira do escopo da ferramenta certa", ctx do
    # O autor é obrigatório, e o schema diz por quê: "exclusão é decisão, e decisão tem
    # autor". Passar `nil` é o que meu primeiro rascunho fazia, e a regra o recusou.
    {:ok, _} = CMPO.exclude_from_observation(ctx.tenant, ctx.repo_da_uma, ctx.admin.id)

    assert escopo(ctx.tenant, ctx.uma) == []
    # E não afeta a outra: exclusão é decisão sobre um repositório, não sobre o tenant.
    assert escopo(ctx.tenant, ctx.outra) == ["org-outra/beta"]
  end

  describe "as cinco fases usam o filtro" do
    test "nenhuma consulta de repositório observado filtra só por tenant", _ctx do
      # Guarda estrutural: se alguém acrescentar uma fase nova copiando a consulta antiga,
      # este teste reprova. É mais barato que descobrir pela conta de rate limit.
      fases = [
        "github_branches",
        "github_verifications",
        "github_issue_comments",
        "github_change_requests",
        "github_commit_files"
      ]

      for fase <- fases do
        fonte = File.read!("lib/the_band/ingestion/#{fase}.ex")

        assert String.contains?(fonte, "connected_tool_id"),
               "#{fase} percorre repositórios sem filtrar pela ferramenta (issue #446)"
      end
    end
  end
end
