defmodule TheBandWeb.Router do
  use TheBandWeb, :router

  import TheBandWeb.Plugs.CurrentScope, only: [require_user: 2, require_admin: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TheBandWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug TheBandWeb.Plugs.CurrentScope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TheBandWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/entrar", SessionLive.New, :new
    post "/sessao", SessionController, :create
    delete "/sessao", SessionController, :delete
  end

  # Consulta — qualquer pessoa autenticada, sempre restrita ao próprio tenant.
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user]

    live_session :autenticado, on_mount: {TheBandWeb.Live.Hooks, :current_scope} do
      live "/pessoas", PeopleLive.Index, :index
      live "/equipes", TeamsLive.Index, :index
      live "/equipes/:id", TeamsLive.Show, :show
      live "/sincronizacoes", SyncLive.Index, :index
      live "/trabalho", WorkItemLive.Index, :index
      live "/trabalho/issues/:id", WorkItemLive.Show, :show
      live "/trabalho/repositorios/:id", RepositoryLive.Show, :show
    end
  end

  # Ferramentas e credenciais — só administradores (Assumptions da spec).
  scope "/", TheBandWeb do
    pipe_through [:browser, :require_user, :require_admin]

    live_session :admin, on_mount: {TheBandWeb.Live.Hooks, :require_admin} do
      live "/ferramentas", SourceLive.Index, :index
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
