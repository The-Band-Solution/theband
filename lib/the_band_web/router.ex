defmodule TheBandWeb.Router do
  use TheBandWeb, :router

  import TheBandWeb.Plugs.CurrentScope,
    only: [require_user: 2, require_admin: 2, require_operacao: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TheBandWeb.Layouts, :root}
    plug :protect_from_forgery
    # ------------------------------------------------------------------------
    # Content-Security-Policy — achado `Config.CSP` do Sobelow, issue #288.
    #
    # Cada diretiva está aqui porque algo concreto precisa dela, e não por lista copiada:
    #
    #   script-src 'self'     o tema saiu do HTML para `theme.js` por causa desta linha
    #   style-src  'unsafe-inline'  o LiveView escreve `style` inline em transição; sem isso,
    #                               animação e `phx-click-away` param de funcionar
    #   connect-src ws: wss:  é por onde o socket do LiveView vive
    #   img-src data:         ícones embutidos como data URI
    #   frame-ancestors 'none'  esta aplicação nunca é enquadrada
    #
    # **`'unsafe-inline'` em `style-src` é concessão declarada**, não descuido: removê-la
    # exige `'unsafe-hashes'` com hash por atributo, que o LiveView gera em tempo de execução.
    # ------------------------------------------------------------------------
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; " <>
          "script-src 'self'; " <>
          "style-src 'self' 'unsafe-inline'; " <>
          "img-src 'self' data:; " <>
          "font-src 'self' data:; " <>
          "connect-src 'self' ws: wss:; " <>
          "base-uri 'self'; " <>
          "form-action 'self'; " <>
          "frame-ancestors 'none'"
    }

    plug TheBandWeb.Plugs.CurrentScope
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: TheBandWeb.ApiSpec
  end

  # A pipeline que EXIGE token — feature 061. Separada da `:api` porque a descrição OpenAPI
  # é servida sem credencial: ela não traz dado, e quem vai integrar precisa lê-la antes de
  # ter um token.
  pipeline :api_autenticada do
    plug TheBandWeb.Plugs.ApiAuth
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # A API pública — feature 061. É a primeira rota a passar pela pipeline `:api`,
  # declarada desde o gerador e até aqui sem uso.
  #
  # **Só leitura.** Nenhum método de escrita é declarado, e por isso o Phoenix
  # devolve 405 para todos eles — não há autor honesto para a proveniência de uma
  # escrita feita por token (FR-017).
  # ─────────────────────────────────────────────────────────────────────────────
  scope "/api/v1", TheBandWeb.Api.V1 do
    pipe_through [:api, :api_autenticada]

    get "/teams", TeamController, :index

    # **405, e não o 404 que o Phoenix daria sozinho.** Um `POST` sem rota declarada cai no
    # 404 genérico, e 404 afirma que o recurso NÃO EXISTE — manda quem integra procurar
    # outra URL para uma que está certa. 405 diz a verdade: o recurso existe, o método não é
    # permitido, e não vai ser.
    #
    # Uma linha por recurso, e não um curinga sobre `/*path`: o curinga transformaria
    # caminho inexistente em 405, que é a mentira inversa.
    match :*, "/teams", TeamController, :nao_permitido

    get "/people", PersonController, :index
    match :*, "/people", PersonController, :nao_permitido
  end

  # A descrição OpenAPI, em JSON. **Sem credencial**, de propósito: ela descreve a forma da
  # API e não devolve dado nenhum, e exigir token para ler o contrato obrigaria quem integra
  # a pedir credencial antes de saber se a API serve.
  scope "/api" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  # O NONCE do Swagger — a segunda metade do conserto de 2026-09-21.
  #
  # Servir os três ativos do próprio domínio resolveu o `script-src` externo. Mas o plug
  # ainda emite um **script inline** de ~1,3 KB que inicializa a página, e `script-src 'self'`
  # bloqueia inline — a página vinha 200, vazia, sem erro visível no corpo.
  #
  # O nonce é a saída que NÃO afrouxa nada: um valor aleatório por requisição, presente na
  # diretiva e no atributo do script. `'unsafe-inline'` liberaria qualquer script injetado;
  # o nonce libera exatamente aquele bloco, naquela resposta.
  defp nonce_do_swagger(conn, _opts) do
    nonce = 16 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:script_src_nonce, nonce)
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'nonce-#{nonce}'; " <>
        "style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; " <>
        "connect-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
    )
  end

  # A INTERFACE DO SWAGGER, atrás de sessão — decisão Q7 da spec 061.
  #
  # Quem integra tem conta, e o mapa completo da superfície não precisa ser público: ele é
  # útil a quem varre. A DESCRIÇÃO em si (`/api/openapi`) fica aberta, porque é o contrato e
  # não traz dado nenhum.
  #
  # **Escopo próprio, e sem o alias `TheBandWeb`**: dentro dele o roteador prefixaria o
  # módulo e procuraria `TheBandWeb.OpenApiSpex.Plug.SwaggerUI`, que não existe.
  #
  # O ativo é servido do PRÓPRIO DOMÍNIO. A CSP do endpoint é `script-src 'self'`, e
  # afrouxá-la para aceitar CDN contrariaria um achado do Sobelow já tratado (issue #288).
  scope "/api" do
    pipe_through [:browser, :require_user, :nonce_do_swagger]

    # Os três ativos saem de `priv/static/vendor/swagger-ui/`, e NÃO do CDN que o plug usa
    # por padrão. Sem isto a página carrega, devolve 200, e o navegador bloqueia o script
    # em silêncio — restando uma tela em branco. Foi o que aconteceu em 2026-09-21: conferi
    # o código HTTP e não que a página funciona.
    get "/docs", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/openapi",
      swagger_ui_css_url: "/vendor/swagger-ui/swagger-ui.css",
      swagger_ui_js_bundle_url: "/vendor/swagger-ui/swagger-ui-bundle.js",
      swagger_ui_js_standalone_preset_url: "/vendor/swagger-ui/swagger-ui-standalone-preset.js",
      csp_nonce_assign_key: %{script: :script_src_nonce}
  end

  scope "/", TheBandWeb do
    pipe_through :browser

    get "/", PageController, :home

    # A VERSÃO QUE ESTA INSTÂNCIA SERVE — achado H7, e a lacuna que toda release desta base
    # teve de declarar à mão: o webhook responde `deployed successfully` e nada prova que o
    # container subiu a versão publicada. A CD passou a perguntar aqui e a FALHAR quando a
    # resposta não for a do merge.
    #
    # Sem autenticação, de propósito: a versão já é pública na tag git, no registro da release
    # e no nome da imagem — e o único consumidor da rota roda antes de haver sessão.
    get "/version", VersionController, :show

    live "/sign-in", SessionLive.New, :new
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete

    # Definição forçada de senha (FR-013): exige sessão — o gate vive na hook e
    # no controller, que validam o token; fora da pipeline require_user porque a
    # conta nesse estado é recusada em toda OUTRA tela, não nesta.
    live "/set-password", SessionLive.SetPassword, :new
    post "/set-password", SessionController, :set_password
  end

  # Consulta — qualquer pessoa autenticada, sempre restrita ao próprio tenant.
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user]

    live_session :autenticado, on_mount: {TheBandWeb.Live.Hooks, :current_scope} do
      live "/people", PeopleLive.Index, :index
      live "/people/:id", PeopleLive.Show, :show
      live "/teams", TeamsLive.Index, :index
      live "/teams/:id", TeamsLive.Show, :show
      live "/organizations", OrganizationLive.Index, :index
      live "/profile", ProfileLive.Index, :index
      live "/process", ProcessLive.Index, :index
      live "/projects", ProjectsLive.Index, :index
      live "/boards", BoardLive.Index, :index
      live "/boards/:id", BoardLive.Index, :show
      live "/work", WorkItemLive.Index, :index
      live "/work/issues/:id", WorkItemLive.Show, :show
      # A solicitação de mudança (cmpo.change_request) — feature 032. Vive sob /work
      # porque é trabalho, e não sob /projects: o PR realiza mudança, não é empreendimento.
      live "/people/:id/commits", ChangeLive.Commits, :index
      # O caminho vem na query string, e não no path: caminho de arquivo tem barras, e
      # um `:path` no roteador não casaria `lib/the_band/changes.ex`.
      live "/work/files", ChangeLive.File, :index
      live "/work/verifications", VerificationLive.Index, :index
      # ANTES da rota com `:id`, ou "people" seria lido como identificador.
      live "/work/verifications/people", VerificationLive.People, :index
      live "/work/verifications/:id", VerificationLive.Show, :show
      live "/work/changes", ChangeLive.Index, :index
      live "/work/changes/:id", ChangeLive.Show, :show
      live "/work/repositories/:id", RepositoryLive.Show, :show
    end

    # Trocar senha gira o token, e cookie é assunto de controller (FR-015) — por
    # isso um POST clássico na pipeline autenticada, fora da live_session.
    post "/profile/password", SessionController, :update_password
  end

  # Operacionais — FR-023 (feature 045): administrador OU concessão organization
  # vigente, com recorte pelas organizações concedidas. Syncs e Tools respondem
  # "a plataforma está funcionando"; quem responde por uma organização opera o
  # que pertence a ela.
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user, :require_operacao]

    live_session :operacao, on_mount: {TheBandWeb.Live.Hooks, :require_operacao} do
      live "/syncs", SyncLive.Index, :index
      live "/tools", SourceLive.Index, :index

      # Aba de /syncs (#428). A geração escreve por tenant; o gate é o mesmo das
      # operacionais, e o recorte fino por organização não se aplica a rodada.
      live "/profiles", ProfileRunLive.Index, :index

      # Aba de /tools (#428). A leitura anterior deixava /ai só para admin ("chave
      # de modelo é credencial do tenant; credencial é gestão") — a aceitação do
      # sprint 023 a levou à pessoa mantenedora, que decidiu o contrário em
      # 2026-08-28: AI é OPERACIONAL (FR-023 vale como escrito), e quem responde
      # por uma organização também opera o provedor — a chave é uma só do tenant,
      # e isso o recorte não muda.
      live "/ai", AILive.Index, :index
    end
  end

  # Gestão — só administradores: credencial de modelo é do TENANT (a chave LLM
  # não pertence a organização nenhuma — credencial é gestão, não operação; é a
  # leitura registrada de FR-023 para o AI), contas e concessões idem.
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user, :require_admin]

    live_session :admin, on_mount: {TheBandWeb.Live.Hooks, :require_admin} do
      live "/accounts", AccountsLive.Index, :index
      live "/access-scopes", AccessScopesLive.Index, :index

      # A credencial da API pública — feature 061, FR-045. Vive na área administrativa
      # porque credencial é GESTÃO, e não operação: quem gera um token concede acesso a
      # tudo o que a conta dona alcança, e isso é o mesmo eixo de `/accounts`.
      live "/api-tokens", ApiTokenLive.Index, :index

      # O catálogo de papéis é decisão da organização, e não consulta: quem o cadastra
      # declara o que a organização reconhece — FR-017, feature 021.
      live "/roles", RolesLive.Index, :index
    end
  end

  if Application.compile_env(:the_band, :dev_routes) do
    # Só em desenvolvimento: ver a página de 403 e a de 500 sem provocar erro real. A de 404
    # aparece sozinha em qualquer caminho inexistente.
    get "/dev/erro/:codigo", TheBandWeb.PageController, :erro_de_exemplo

    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TheBandWeb.Telemetry
    end
  end
end
