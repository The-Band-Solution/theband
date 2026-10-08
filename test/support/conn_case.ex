defmodule TheBandWeb.ConnCase do
  @moduledoc "Base dos testes de interface."

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.User
  alias TheBandWeb.Plataforma.SessaoDoOperador

  using do
    quote do
      use TheBandWeb, :verified_routes

      # O `build_conn/0` é o da casa (spec 077, T007): cada conexão com origem própria.
      import Phoenix.ConnTest, except: [build_conn: 0]
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
    {:ok, conn: build_conn()}
  end

  @doc """
  `Phoenix.ConnTest.build_conn/0` com uma origem própria — spec 077, T007.

  O de fábrica dá `127.0.0.1` a toda conexão, e com o limite por origem os testes assíncronos que
  entram e erram dividiriam um contador. Aqui cada conexão nova é um visitante novo, de um `/64`
  de documentação; `recycle/1` preserva o endereço, então as requisições seguintes da mesma
  conversa contam juntas, como as de um navegador.
  """
  def build_conn do
    %{Phoenix.ConnTest.build_conn() | remote_ip: TheBand.OrigemDeTeste.endereco()}
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
  Entra como operador da plataforma — spec 070. Abre uma sessão **de verdade** por
  `SessaoDoOperador.abrir/2` e põe na requisição o cookie cifrado que a resposta gravaria, como o
  navegador faria. Sem bcrypt nem TOTP: a entrada pelo formulário tem testes próprios.
  """
  def log_in_operador(conn, op) do
    resposta =
      Phoenix.ConnTest.build_conn()
      |> Map.put(:secret_key_base, TheBandWeb.Endpoint.config(:secret_key_base))
      |> SessaoDoOperador.abrir(op)
      |> Plug.Conn.send_resp(200, "")

    %{value: valor} = resposta.resp_cookies["_the_band_operator"]
    Plug.Test.put_req_cookie(conn, "_the_band_operator", valor)
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
    # Quem declara é um administrador ativo da organização, como na tela: desde a 072 (R2), o
    # ato confere o ator relido, e a própria conta, se for membro, não se declara.
    import Ecto.Query, only: [from: 2]

    admin_id =
      TheBand.Repo.one(
        from(u in TheBand.Tenants.User,
          where: u.tenant_id == ^tenant.id and u.role == "admin" and is_nil(u.disabled_at),
          order_by: u.inserted_at,
          limit: 1,
          select: u.id
        )
      ) || user.id

    {:ok, ligada} = TheBand.Tenants.declare_person(tenant, user.id, pessoa.id, admin_id)
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
