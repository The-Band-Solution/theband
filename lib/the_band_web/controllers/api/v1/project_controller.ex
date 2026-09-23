defmodule TheBandWeb.Api.V1.ProjectController do
  @moduledoc """
  `GET /api/v1/projects` — os projetos declarados (feature 061, FR-021).

  ## Projeto é DECLARADO, e não coletado

  Alguém o cria nesta plataforma e liga a ele repositórios, quadros, organizações e equipes.
  A coleção não cresce com a coleta: cresce com decisões de gente. Medido em 2026-09-22 nesta
  base: **2** projetos.

  Isso muda o que é razoável fazer por linha — ver o custo, abaixo.

  ## As três ausências do critério de início, e por que não viram um total

  Uma issue pode estar sem instante de início por três razões, e cada uma pede coisa
  diferente: ninguém declarou o critério; o critério existe e o evento nunca foi coletado; ou
  mais de um instante casou.

  Somar as três num "sem instante" diria a quem integra que **há** um problema, e não **qual**.
  É a FR-004/FR-009 da spec que criou a tela, e ela vale igual aqui.

  ## O custo, e por que ele é aceito

  **Cada projeto custa ~6 consultas** — issues, critério, organizações, equipes, repositórios
  e quadros —, e a rota não as faz em lote. Contraria a L38 na letra.

  As seis são agregações **por projeto**, e não junções: a forma em lote exigiria seis funções
  novas de domínio para uma coleção de dois elementos, que é abstrair para um caso que não
  existe. O teto de página é **50**, e não 200 como nas outras rotas — é o reconhecimento do
  custo.

  **O que fica pior**: se um tenant declarar centenas de projetos, esta rota degrada
  linearmente. Há teste que mede o custo por projeto, para que o crescimento seja decidido e
  não descoberto.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Ontology.SEON.SPO
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 25
  @teto 50

  @nota_das_issues "Never summed. An issue reached through a subproject is not a second issue."

  # **Os dois totais NÃO compartilham denominador**, e medi a diferença: nesta base,
  # `ConectaFapes` tem 2 756 issues e `start_criterion.total: 0`, porque não tem quadro
  # declarado; `Valida` tem 0 issues diretas e 498 no critério. Quem somar ou comparar os
  # dois conclui o contrário do que há.
  @nota_dos_denominadores "`issues` counts through the project's **repositories**; " <>
                            "`start_criterion.total` counts through its **boards**. They do " <>
                            "not share a denominator and must not be compared: a project " <>
                            "with repositories and no board shows issues here and zero there."

  @nota_do_criterio "Three distinct absences, never one total. *No criterion declared*, " <>
                      "*criterion declared and the event was never collected*, and *more " <>
                      "than one instant matched* need different things done about them — " <>
                      "an aggregate would tell nobody what to do."

  @nota_do_total "Counted, unlike the collection listings: projects are declared by people, " <>
                   "not collected, so the collection is bounded by decisions and not by " <>
                   "ingestion."

  tags(["projects"])

  operation(:index,
    summary: "Projects declared on this platform",
    description: """
    Mirrors the `/projects` screen. A project is **declared** here, never collected: someone
    creates it and links repositories, boards, organisations and teams to it.

    `start_criterion` carries **three distinct absences** and never one total: an issue with
    no start instant may lack a declared criterion, may have one whose event was never
    collected, or may have matched more than one instant. Each needs a different thing done.

    `page_size` is capped at 50 here, and not 200: each project costs about six readings, and
    the cap is the acknowledgement of that cost.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description: "Default 25, maximum 50 — lower than other routes, on purpose.",
        required: false
      ]
    ],
    responses: [
      ok: {"The projects", "application/json", Schemas.Projects},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    tamanho = tamanho_da_pagina(params)
    projetos = SPO.list_projects(tenant)
    {pagina, tem_proxima?} = cortar(projetos, tamanho)

    # Os nomes dos projetos-pai vêm da coleção JÁ carregada, e não de uma consulta por linha:
    # o pai de um projeto é outro projeto do mesmo tenant, e ele está aqui.
    nomes = Map.new(projetos, &{&1.id, &1.name})

    json(conn, %{
      data: Enum.map(pagina, &serializar(tenant, &1, nomes)),
      page: %{
        has_next: tem_proxima?,
        next_cursor: nil,
        total: length(projetos),
        total_note: @nota_do_total
      }
    })
  end

  operation(:nao_permitido, false)

  @doc "A recusa de escrita — FR-017. Ver `TeamController.nao_permitido/2`."
  def nao_permitido(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:method_not_allowed))
    |> put_resp_header("allow", "GET, HEAD")
    |> json(Erro.corpo(:method_not_allowed, id))
  end

  defp tamanho_da_pagina(params) do
    case Integer.parse(to_string(params["page_size"] || "")) do
      {n, _} when n > 0 -> min(n, @teto)
      _ -> @padrao
    end
  end

  defp cortar(lista, tamanho) do
    if length(lista) > tamanho,
      do: {Enum.take(lista, tamanho), true},
      else: {lista, false}
  end

  defp serializar(tenant, p, nomes) do
    contagem = SPO.count_project_issues(tenant, p.id)
    inicio = SPO.start_status(tenant, p.id)

    %{
      id: p.id,
      name: p.name,
      phase: p.phase,
      parent: p.parent_id && %{id: p.parent_id, name: nomes[p.parent_id]},
      started_on: p.started_on,
      ended_on: p.ended_on,
      issues: %{
        direct: contagem.direct,
        via_subproject: contagem.subproject,
        note: @nota_das_issues,
        denominator_note: @nota_dos_denominadores
      },
      start_criterion: criterio(inicio),
      organizations: Enum.map(SPO.list_project_organizations(tenant, p.id), &organizacao/1),
      teams: Enum.map(SPO.list_project_teams(tenant, p.id), &equipe/1),
      repositories:
        Enum.map(
          SPO.list_project_repositories(tenant, p.id),
          &%{repository_id: &1.observed_repository_id, linked_at: &1.linked_at}
        ),
      boards: Enum.map(SPO.list_project_boards(tenant, p.id), &quadro/1)
    }
  end

  # **As três ausências, separadas.** `ambiguous` vem com a LISTA e não com a contagem: para
  # desempatar é preciso saber quais, e um número não diz.
  defp criterio(i) do
    %{
      total: i.total,
      with_instant: i.com_instante,
      no_criterion: i.sem_criterio,
      event_not_collected: i.evento_nao_coletado,
      ambiguous: i.ambiguas,
      note: @nota_do_criterio
    }
  end

  defp organizacao(o),
    do: %{id: o.organization_id, login: o.login, name: o.name}

  # **`origin` é marca, e não booleano.** A consulta guarda `declared: true|false`; booleano
  # no lugar do relator é antipadrão declarado nesta casa, e ele fica na fronteira de dentro.
  defp equipe(e),
    do: %{
      team_id: e.team_id,
      name: e.name,
      origin: if(e.declared, do: "declared", else: "observed")
    }

  defp quadro(q), do: %{board_id: q.observed_project_id, name: Map.get(q, :name)}
end
