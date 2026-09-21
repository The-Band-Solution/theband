defmodule TheBandWeb.Api.V1.PersonController do
  @moduledoc """
  `GET /api/v1/people` — as pessoas observadas (feature 061, FR-021).

  ## O recorte é o da tela, e a assimetria com o detalhe fica dita

  A tela `/people` **não filtra por `Access`**: ela lista as pessoas do tenant. Quem filtra é
  o **detalhe**, `/people/:id`, que chama `pode_ver/3` antes de mostrar o painel.

  Esta rota espelha a **listagem**, e por isso também não filtra. A rota de detalhe, quando
  existir, precisará do veredito — e é decisão própria, não extensão desta.

  ## `account_type` é a palavra da origem, e não um palpite

  O GitHub diz se a conta é pessoa, robô ou aplicação. Contar robô como pessoa inflaria toda
  medida de quem fez o trabalho — 160 de 357 movimentações medidas numa coleta eram de robô.

  ## `no_longer_observed_at` nulo significa ainda observada

  E **não** que a pessoa sumiu. Ausência escrita, nunca remoção silenciosa.

  ## O corpo carrega o que a tela mostra, e nada além

  Cada campo aqui é uma coluna de `/people`: nome e login, tipo de conta, organizações,
  fonte e instância, identificador na origem, data de coleta. Quem integra vê o mesmo que
  quem abre a tela — duas respostas diferentes para a mesma pergunta seriam duas verdades.

  **`email` fica de fora de propósito.** A tela não o mostra, e ele é dado pessoal que
  ninguém pediu: acrescentá-lo porque a coluna existe no banco alargaria o alcance da rota
  sem que nenhum requisito o justificasse.

  ## A organização de uma pessoa vem das equipes dela, e por isso pode faltar

  Não há vínculo direto entre pessoa e organização nesta ontologia. Quem não está em equipe
  alguma sai com `organizations` vazio **e com a razão escrita** em `organizations_note` —
  ausência escrita, nunca lista vazia sem explicação, que faria parecer que a busca foi
  feita e não achou nada.

  Quem está em mais de uma sai **uma vez**, com todas listadas. A consequência é que somar
  pessoas por organização dá mais que o total de pessoas, e isso está certo.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 50
  @teto 200

  # A razão da ausência, na mesma frase que a tela usa. Ela não é decoração: sem ela, uma
  # lista vazia diria "esta pessoa não tem organização", quando o que houve foi que o
  # vínculo não existe — ele viria das equipes, e a pessoa não está em nenhuma.
  @sem_organizacao "no team — organisation unknown"

  tags(["people"])

  operation(:index,
    summary: "People observed at connected tools",
    description: """
    Everyone the platform observed, with the mark of where it learned about them and the
    source's own word for what kind of account it is.

    Mirrors the `/people` screen, which lists the tenant and does not narrow by access. The
    **detail** of a person does narrow — that is a different endpoint, and it does not exist
    yet.

    Every field here is a column of that screen. A person's organisations come from their
    teams: there is no direct link between person and organisation, so whoever is in no team
    comes back with an empty `organizations` and the reason in `organizations_note`. Whoever
    is in more than one comes back **once**, with all of them listed — so people counted per
    organisation add up to more than the total, and that is correct.

    `email` is not returned. The screen does not show it and no requirement asks for it.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description: "Default 50, maximum 200. A larger value is reduced, not refused.",
        required: false
      ],
      after: [
        in: :query,
        type: :string,
        description: "Opaque cursor from the previous page's `next_cursor`.",
        required: false
      ]
    ],
    responses: [
      ok: {"The people", "application/json", Schemas.People},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tamanho = tamanho_da_pagina(params)
    cursor = params["after"] || :inicio

    tenant = conn.assigns.current_tenant
    pessoas = EO.list_people(tenant, limit: tamanho + 1, after: cursor)
    {pagina, tem_proxima?} = cortar(pessoas, tamanho)

    # UMA consulta para a página inteira, nunca uma por pessoa (lição L38). É a mesma
    # função que a tela usa, e é de propósito: duas maneiras de responder "de que
    # organização é esta pessoa" divergiriam, e a divergência apareceria como dado.
    orgs = EO.organizations_by_person(tenant, Enum.map(pagina, & &1.id))

    json(conn, %{
      data: Enum.map(pagina, &serializar(&1, orgs)),
      page: %{
        has_next: tem_proxima?,
        next_cursor: if(tem_proxima?, do: List.last(pagina).id),
        total: nil,
        total_note:
          "This API does not count collections. An estimated total is worse than an absent one."
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

  defp cortar(pessoas, tamanho) do
    if length(pessoas) > tamanho,
      do: {Enum.take(pessoas, tamanho), true},
      else: {pessoas, false}
  end

  defp serializar(pessoa, orgs) do
    # `Map.get(orgs, id, [])` e não `orgs[id]`: quem não tem equipe **não está no mapa**, e
    # a consulta em lote documenta isso — a chave ausente não é erro, é o caso comum.
    organizacoes = Map.get(orgs, pessoa.id, [])

    %{
      id: pessoa.id,
      name: pessoa.name,
      login: pessoa.login,
      account_type: pessoa.account_type,
      origin: if(pessoa.source_system, do: "observed", else: "declared"),
      source_system: pessoa.source_system,
      source_instance: pessoa.source_instance,
      external_id: pessoa.external_id,
      organizations: Enum.map(organizacoes, &%{id: &1.id, login: &1.login, name: &1.name}),
      organizations_note: if(organizacoes == [], do: @sem_organizacao),
      collected_at: pessoa.collected_at,
      no_longer_observed_at: pessoa.no_longer_observed_at
    }
  end
end
