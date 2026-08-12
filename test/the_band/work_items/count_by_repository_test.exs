defmodule TheBand.WorkItems.CountByRepositoryTest do
  @moduledoc """
  `count_collected_by_repository/2` — a consulta que a marca de trabalho lê (T001).

  As duas asserções que importam não são sobre o número certo: são sobre **o que a
  ausência significa**. Repositório sem issue tem de ficar **fora** do mapa, porque quem
  chama precisa poder distinguir "nenhuma issue vigente" de "nunca consultado" — e um
  zero gravado no mapa apagaria a diferença antes de a tela poder decidir.
  """
  use TheBand.DataCase, async: true

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    %{tenant: tenant, cenario: cenario_real(tenant)}
  end

  test "conta as issues vigentes do repositório", %{tenant: tenant, cenario: c} do
    id = c.observed_repository_id

    mapa = WorkItems.count_collected_by_repository(tenant, [id])

    assert Map.fetch!(mapa, id) == WorkItems.count_collected(tenant, observed_repository_id: id)
  end

  test "repositório sem issue não é chave do mapa", %{tenant: tenant, cenario: c} do
    vazio = repositorio_observado(tenant, c, "sem-issue")

    mapa = WorkItems.count_collected_by_repository(tenant, [c.observed_repository_id, vazio])

    refute Map.has_key?(mapa, vazio), """
    O repositório sem nenhuma issue apareceu no mapa.

    Devolver `0` aqui parece inofensivo e não é: quem chama precisa distinguir "a coleta
    rodou e não achou nada" de "a coleta nunca rodou", e essa distinção mora em
    `issues_collected_at`. Um zero gravado pela consulta faria a tela decidir com um dado
    que a consulta não tem como saber — e ela mostraria "collected, no issues" sobre
    repositório que a plataforma nunca consultou.

    Quem chama usa `Map.get(mapa, id, 0)`. O zero é decisão de quem lê, não da consulta.
    """
  end

  test "issue marcada como não mais observada não é contada", %{tenant: tenant, cenario: c} do
    id = c.observed_repository_id
    antes = WorkItems.count_collected_by_repository(tenant, [id]) |> Map.fetch!(id)

    # Um segundo à frente, de propósito: `mark_issues_no_longer_observed/3` marca o que foi
    # observado **antes** de `desde`, e a granularidade da coluna é o segundo. Passar o
    # instante atual não marcaria nada quando o cenário foi gravado no mesmo segundo — e o
    # teste passaria por não medir.
    depois = DateTime.add(DateTime.utc_now(:second), 1, :second)

    {:ok, marcadas} = WorkItems.mark_issues_no_longer_observed(tenant, id, depois)

    assert marcadas > 0, "o cenário não marcou nada, e o teste não mediria nada"

    depois = WorkItems.count_collected_by_repository(tenant, [id])

    refute Map.has_key?(depois, id), """
    Todas as #{antes} issues foram marcadas como não mais observadas, e o repositório
    continuou no mapa com contagem.

    A marca resume trabalho **vigente**. Contar issue ausente diria que há trabalho onde
    a plataforma já registrou que não há — e é a distinção que `no_longer_observed_at`
    existe para carregar.
    """
  end

  test "lista de ids vazia devolve mapa vazio sem consultar", %{tenant: tenant} do
    assert WorkItems.count_collected_by_repository(tenant, []) == %{}
  end

  test "não conta issue de outro tenant", %{tenant: tenant, cenario: c} do
    outro = tenant_fixture()

    assert WorkItems.count_collected_by_repository(outro, [c.observed_repository_id]) == %{}, """
    A consulta devolveu contagem de repositório de outro tenant.

    Consulta sem filtro de tenant é bug de segurança, não de correção — AGENTS.md §14.
    """
  end

  defp repositorio_observado(tenant, cenario, nome) do
    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: cenario.organization.id,
        name: nome,
        qualified_name: "The-Band-Solution/#{nome}",
        url: "https://github.com/The-Band-Solution/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{nome}"
      })

    {:ok, observado} = CMPO.observe_repository(tenant, cenario.tool.id, repo.id)
    observado.id
  end
end
