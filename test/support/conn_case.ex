defmodule TheBandWeb.ConnCase do
  @moduledoc "Base dos testes de interface."

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use TheBandWeb, :verified_routes

      import Phoenix.ConnTest
      import Plug.Conn

      import TheBand.DataCase,
        only: [tenant_fixture: 0, tenant_fixture: 1, source_attrs: 1, source_attrs: 2]

      import TheBandWeb.ConnCase

      alias TheBand.Repo

      @endpoint TheBandWeb.Endpoint
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(TheBand.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Abre sessão para uma pessoa usuária do tenant."
  def log_in(conn, user) do
    Plug.Test.init_test_session(conn, %{"user_id" => user.id})
  end

  @doc "Cria tenant e usuário admin, e devolve os dois."
  def tenant_with_admin(slug \\ nil) do
    tenant = TheBand.DataCase.tenant_fixture(slug)

    {:ok, user} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "admin-#{System.unique_integer([:positive])}@example.test",
        "role" => "admin"
      })

    {tenant, user}
  end
end
