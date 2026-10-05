defmodule TheBandWeb.SessaoPelaTabelaTest do
  @moduledoc """
  A sessão lida de `user_sessions` — feature 064, T012 e T013.

  Cada teste é um cenário de ataque de `specs/064-segredo-em-repouso/seguranca-us2.md`, contado
  pelo lado de quem ataca: um **cookie guardado** e reenviado depois, que é o que um navegador
  esquecido aberto ou um cookie copiado dão. Os cookies são os de verdade, tirados da resposta, e
  não montados à mão, com uma exceção: o forjado com a chave real, que é o ataque da R1.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.User

  @senha "uma-senha-longa-o-bastante"
  @migracao "priv/repo/migrations/20260929120000_gira_o_token_antigo_de_todas_as_contas.exs"
  @modulo TheBand.Repo.Migrations.GiraOTokenAntigoDeTodasAsContas

  setup_all do
    unless Code.ensure_loaded?(@modulo), do: Code.require_file(@migracao)
    :ok
  end

  setup do
    {tenant, admin} = tenant_with_admin()

    {:ok, alvo} =
      Tenants.create_user(tenant, %{
        "email" => "tabela-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, alvo} = Tenants.set_password(tenant, alvo.id, @senha)
    %{tenant: tenant, admin: admin, alvo: alvo}
  end

  # Entra pelo formulário e devolve o cookie assinado que a resposta pôs no navegador.
  defp entrar(email, senha \\ @senha) do
    conn = post(build_conn(), ~p"/session", %{"identifier" => email, "password" => senha})
    {conn, conn.resp_cookies["_the_band_key"].value}
  end

  # A coluna antiga, lida e escrita por SQL: ela saiu do schema na T014a e sai do banco na T014b.
  defp token_da_coluna(user_id) do
    %{rows: [[v]]} =
      Repo.query!("SELECT session_token FROM users WHERE id = $1", [Ecto.UUID.dump!(user_id)])

    v
  end

  defp token_da_coluna(user_id, valor) do
    Repo.query!("UPDATE users SET session_token = $1 WHERE id = $2", [
      valor,
      Ecto.UUID.dump!(user_id)
    ])
  end

  defp com_cookie(valor), do: put_req_header(build_conn(), "cookie", "_the_band_key=#{valor}")

  defp chave_real, do: Application.fetch_env!(:the_band, TheBandWeb.Endpoint)[:secret_key_base]

  # Como `Plug.Session.COOKIE` assina quando não há `encryption_salt` — ver
  # `cookie_de_sessao_evidencia_test.exs`.
  defp forjar(dados) do
    chave =
      KeyGenerator.generate(chave_real(), "uG5K6D7b",
        iterations: 1000,
        length: 32,
        digest: :sha256
      )

    dados |> :erlang.term_to_binary() |> MessageVerifier.sign(chave)
  end

  test "o cookie de uma entrada vale", %{alvo: alvo} do
    {_conn, cookie} = entrar(alvo.email)
    conn = get(com_cookie(cookie), ~p"/people")
    assert conn.status == 200
    assert conn.assigns.current_user.id == alvo.id
  end

  test "S5 — depois de sair, o cookie guardado não vale mais", %{alvo: alvo} do
    {conn, cookie} = entrar(alvo.email)

    conn |> recycle() |> delete(~p"/session")

    assert redirected_to(get(com_cookie(cookie), ~p"/people")) == ~p"/sign-in"
  end

  test "S3 — definir a senha com o cookie de uma sessão encerrada é recusado", ctx do
    {:ok, temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)
    {_conn, cookie} = entrar(ctx.alvo.email, temporaria)

    # Quem administra reinicia de novo: a sessão aberta com a primeira temporária cai.
    {:ok, _} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)
    hash_antes = Repo.get!(User, ctx.alvo.id).password_hash

    conn =
      post(com_cookie(cookie), ~p"/set-password", %{
        "password" => "a-senha-de-quem-ataca",
        "password_confirmation" => "a-senha-de-quem-ataca"
      })

    assert redirected_to(conn) == ~p"/sign-in"
    assert Repo.get!(User, ctx.alvo.id).password_hash == hash_antes
  end

  test "S3 — e com a sessão viva, a definição funciona", ctx do
    {:ok, temporaria} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)
    {_conn, cookie} = entrar(ctx.alvo.email, temporaria)

    conn =
      post(com_cookie(cookie), ~p"/set-password", %{
        "password" => "a-senha-nova-da-pessoa",
        "password_confirmation" => "a-senha-nova-da-pessoa"
      })

    assert redirected_to(conn) == ~p"/people"
    # Quem definiu continua dentro, por uma sessão nova; o cookie velho não vale mais.
    assert get(recycle(conn), ~p"/people").status == 200
    assert redirected_to(get(com_cookie(cookie), ~p"/people")) == ~p"/sign-in"
  end

  test "S6 — a sessão de 8 dias é recusada também fora do LiveView", %{alvo: alvo} do
    {conn, cookie} = entrar(alvo.email)
    id = get_session(conn, "session_id")

    Repo.update_all(from(s in UserSession, where: s.id == ^id),
      set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -8, :day)]
    )

    conn =
      post(com_cookie(cookie), ~p"/profile/password", %{
        "current" => @senha,
        "password" => "trocada-por-sessao-vencida"
      })

    assert redirected_to(conn) == ~p"/sign-in"

    assert {:ok, _} =
             Tenants.authenticate(alvo.email, @senha, origem: TheBand.OrigemDeTeste.nova())
  end

  test "S4 — um cookie só com user_id, assinado com a chave real, não abre nada", %{alvo: alvo} do
    cookie = forjar(%{"user_id" => alvo.id})

    assert redirected_to(get(com_cookie(cookie), ~p"/people")) == ~p"/sign-in"

    # Pela rota que não é LiveView, onde só o plug decide. Pelo `GET /people` a hook recusaria
    # sozinha, e o teste não mediria o plug: foi visto passando com o plug defeituoso.
    conn =
      post(com_cookie(cookie), ~p"/profile/password", %{
        "current" => @senha,
        "password" => "trocada-por-quem-forjou"
      })

    assert redirected_to(conn) == ~p"/sign-in"

    assert {:ok, _} =
             Tenants.authenticate(alvo.email, @senha, origem: TheBand.OrigemDeTeste.nova())
  end

  test "S1 — desativar e reativar não devolve a sessão", ctx do
    {_conn, cookie} = entrar(ctx.alvo.email)

    {:ok, _} =
      Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, %{
        "reason" => "left_the_organisation"
      })

    {:ok, _} =
      Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, %{
        "reason" => "returned_to_the_organisation"
      })

    assert redirected_to(get(com_cookie(cookie), ~p"/people")) == ~p"/sign-in"
  end

  test "trocar a própria senha mantém quem trocou e derruba as outras sessões", %{alvo: alvo} do
    {aqui, _} = entrar(alvo.email)
    {_ali, cookie_ali} = entrar(alvo.email)

    conn =
      aqui
      |> recycle()
      |> post(~p"/profile/password", %{"current" => @senha, "password" => "trocada-pela-pessoa"})

    assert redirected_to(conn) == ~p"/profile"
    assert get(recycle(conn), ~p"/people").status == 200
    assert redirected_to(get(com_cookie(cookie_ali), ~p"/people")) == ~p"/sign-in"

    # O `ended_at` registra a queda (FR-015), e não só a época.
    abertas =
      Repo.aggregate(
        from(s in UserSession, where: s.user_id == ^alvo.id and is_nil(s.ended_at)),
        :count
      )

    assert abertas == 1
  end

  test "T014a — nenhum caminho escreve mais a coluna antiga", ctx do
    # Os quatro caminhos que a giravam até a v0.11.0: entrar, definir a senha, trocar a senha e
    # desativar. A conta nasce com a coluna nula e continua nula depois de todos.
    token_da_coluna(ctx.alvo.id, nil)

    {conn, _cookie} = entrar(ctx.alvo.email)

    conn
    |> recycle()
    |> post(~p"/profile/password", %{"current" => @senha, "password" => "trocada-sem-coluna"})

    {:ok, _} = Tenants.reset_password(ctx.tenant, ctx.alvo.id, ctx.admin.id)

    {:ok, _} =
      Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, %{
        "reason" => "left_the_organisation"
      })

    assert token_da_coluna(ctx.alvo.id) == nil
  end

  describe "T012 — o token antigo girado" do
    test "o cookie de antes da troca não vale, nem pela leitura nova nem pela antiga", %{
      alvo: alvo
    } do
      # O estado de antes da T012: a conta com o token em claro na coluna. A plataforma não a
      # escreve mais desde a T014a, então o valor é gravado aqui por SQL.
      antigo = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      token_da_coluna(alvo.id, antigo)
      assert token_da_coluna(alvo.id) == antigo
      cookie_antigo = forjar(%{"user_id" => alvo.id, "session_token" => antigo})

      Repo.query!(@modulo.sql_up())

      # A leitura nova não aceita o formato antigo.
      assert redirected_to(get(com_cookie(cookie_antigo), ~p"/people")) == ~p"/sign-in"

      # A antiga, a de um rollback, comparava a coluna com o cookie: girada, não casa.
      refute token_da_coluna(alvo.id) == antigo
    end

    test "gira toda conta, inclusive a que tinha a coluna nula (S4 num rollback)", %{
      tenant: tenant
    } do
      {:ok, sem_token} =
        Tenants.create_user(tenant, %{
          "email" => "sem-token-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      assert token_da_coluna(sem_token.id) == nil

      Repo.query!(@modulo.sql_up())

      %{rows: [[nulos]]} = Repo.query!("SELECT count(*) FROM users WHERE session_token IS NULL")
      assert nulos == 0
    end
  end
end
