defmodule TheBandWeb.Router do
  use TheBandWeb, :router

  import TheBandWeb.Plugs.CurrentScope, only: [require_user: 2, require_admin: 2]

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
  end

  scope "/", TheBandWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/sign-in", SessionLive.New, :new
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete
  end

  # Consulta — qualquer pessoa autenticada, sempre restrita ao próprio tenant.
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user]

    live_session :autenticado, on_mount: {TheBandWeb.Live.Hooks, :current_scope} do
      live "/people", PeopleLive.Index, :index
      live "/people/:id", PeopleLive.Show, :show
      live "/teams", TeamsLive.Index, :index
      live "/teams/:id", TeamsLive.Show, :show
      live "/syncs", SyncLive.Index, :index
      live "/process", ProcessLive.Index, :index
      live "/work", WorkItemLive.Index, :index
      live "/work/issues/:id", WorkItemLive.Show, :show
      live "/work/repositories/:id", RepositoryLive.Show, :show
    end
  end

  # Ferramentas e credenciais — só administradores (Assumptions da spec).
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user, :require_admin]

    live_session :admin, on_mount: {TheBandWeb.Live.Hooks, :require_admin} do
      live "/tools", SourceLive.Index, :index

      # O catálogo de papéis é decisão da organização, e não consulta: quem o cadastra
      # declara o que a organização reconhece — FR-017, feature 021.
      live "/roles", RolesLive.Index, :index
    end
  end

  if Application.compile_env(:the_band, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TheBandWeb.Telemetry
    end
  end
end
