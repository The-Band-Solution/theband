defmodule TheBandWeb.ConnCase do
  @moduledoc "Base dos testes de interface."

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.User

  using do
    quote do
      use TheBandWeb, :verified_routes

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn

      import TheBand.DataCase,
        only: [
          tenant_fixture: 0,
          tenant_fixture: 1,
          source_attrs: 1,
          source_attrs: 2,
          organization_fixture: 1,
          organization_fixture: 2,
          team_fixture: 2,
          team_fixture: 3
        ]

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

  @doc """
  Abre sessão para uma pessoa usuária do tenant.

  Atalho DE TESTE, e continua legítimo depois da feature 045 (research R10): o
  formulário de login tem testes próprios; os demais não pagam bcrypt por setup.
  Desde a 064 (T013), o atalho abre uma sessão **de verdade** por `Sessions.abrir/1`, e o
  cookie leva o que o de produção leva. Um atalho que só pusesse campos no cookie deixaria os
  testes passarem por um caminho que produção não tem. A conta é relida para a sessão nascer
  com a época atual: um teste que trocar a senha no meio precisa relogar, como um navegador
  precisaria.
  """
  def log_in(conn, user) do
    user = Repo.get!(User, user.id)
    {:ok, {sessao, segredo}} = Sessions.abrir(user)

    Plug.Test.init_test_session(conn, %{
      "session_id" => sessao.id,
      "session_secret" => Segredo.expor(segredo)
    })
  end

  @doc """
  Declara que esta conta É esta pessoa observada — issue #369.

  Sem o elo, a aba de trabalho fecha para todo mundo, inclusive para a própria pessoa: a
  plataforma não sabe qual das pessoas observadas é a conta logada, e não adivinha. Todo
  teste que abre a aba de trabalho de alguém precisa dizer quem a conta é.

  Chamar isto NÃO é contornar a regra: é declarar o que a organização declararia. O que
  contornaria seria afrouxar a verificação, e o que a mantém honesta é este passo aparecer
  no setup de cada teste que depende dele.
  """
  def elo_de_identidade(tenant, user, pessoa) do
    {:ok, ligada} = TheBand.Tenants.declare_person(tenant, user.id, pessoa.id, user.id)
    ligada
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
