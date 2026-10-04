defmodule TheBand.Telemetria.ReguaTest do
  @moduledoc """
  A régua de entrar e sair — spec 074, tabela *A régua*; SC-001; T012 (a entrada), T016 (sair) e
  T017 (a queda de sessão).

  Cada linha da régua é um teste que faz o que a pessoa faz e lê o span **depois do filtro de
  produção** (`TheBand.Spans.ligar/0` troca só o destino). Cada teste afirma três coisas:

  1. o passo, o desfecho e o motivo certos;
  2. nada do que a pessoa digitou — senha, identificador, e-mail — está no span ou no recurso,
     em claro, Base64 ou `inspect` (FR-005);
  3. a conta só vai nos desfechos que pedem ação (FR-004, D1 de 2026-10-03).

  E o que o controller recebe continua o de sempre: `{:ok, user}`, `:invalid_credentials` ou
  `{:throttled, s}` — o motivo fica no passo, e nunca na resposta (seguranca.md, S4).
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Spans
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession

  @senha "SENTINELA-SENHA-regua-7c1e"
  @senha_errada "SENTINELA-ERRADA-regua-2b9d"

  setup do
    :ok = Spans.ligar()
    {tenant, admin} = tenant_with_admin()
    {:ok, admin} = Tenants.set_password(tenant, admin.id, @senha)

    # O `setup` emite nada da jornada; esvaziar a caixa garante que cada teste lê só o seu passo.
    Spans.recebidos(0)
    %{tenant: tenant, admin: admin}
  end

  defp conta_com_senha(tenant) do
    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "regua-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    user
  end

  defp correlator, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

  # Entra, e devolve o retorno e os atributos do ÚNICO passo `entrar_com_senha` que saiu.
  # Um segundo passo, ou nenhum, reprova aqui: a régua é "um passo por tentativa".
  defp entrar(identificador, senha, opts \\ []) do
    resultado = Tenants.authenticate(identificador, senha, opts)
    spans = Spans.recebidos()

    assert [span] = Spans.do_passo(spans, :entrar_com_senha),
           "uma tentativa produz exatamente um passo entrar_com_senha"

    sentinelas = [@senha, @senha_errada, identificador]

    assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas) == [],
           "o que a pessoa digitou saiu no traço"

    {resultado, Spans.atributos(span)}
  end

  defp assert_falhou(atributos, motivo) do
    assert atributos["journey.name"] == "entrar_e_sair"
    assert atributos["journey.step"] == "entrar_com_senha"
    assert atributos["outcome"] == "falhou"
    assert atributos["failure.reason"] == Atom.to_string(motivo)
  end

  describe "entrar_com_senha — concluiu (045/US1 #1 e #2)" do
    test "a entrada certa sai com a organização e SEM a conta", ctx do
      user = conta_com_senha(ctx.tenant)

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:ok, %{id: id}} = resultado
      assert id == user.id
      assert atributos["outcome"] == "concluiu"
      refute Map.has_key?(atributos, "failure.reason")
      assert atributos["tenant.id"] == ctx.tenant.id

      refute Map.has_key?(atributos, "user.ref"),
             "o sucesso comum não é registro de presença (FR-004, D1)"
    end

    test "pelo usuário do GitHub, com elo vigente, também conclui sem a conta", ctx do
      user = conta_com_senha(ctx.tenant)

      {:ok, _} =
        Tenants.declare_person(
          ctx.tenant,
          user.id,
          pessoa(ctx.tenant, "regua-gh").id,
          ctx.admin.id
        )

      {resultado, atributos} = entrar("regua-gh", @senha)

      assert {:ok, _} = resultado
      assert atributos["outcome"] == "concluiu"
      refute Map.has_key?(atributos, "user.ref")
    end

    test "o sucesso que apagou tentativas falhas leva a conta — a campanha que deu certo", ctx do
      user = conta_com_senha(ctx.tenant)
      {{:error, :invalid_credentials}, _} = entrar(user.email, @senha_errada)

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:ok, _} = resultado
      assert atributos["outcome"] == "concluiu"
      assert atributos["user.ref"] == user.id
    end

    test "o correlator da tentativa sai como journey.id", ctx do
      user = conta_com_senha(ctx.tenant)
      jornada_id = correlator()

      {_, atributos} = entrar(user.email, @senha, jornada_id: jornada_id)

      assert atributos["journey.id"] == jornada_id
    end
  end

  describe "entrar_com_senha — falhou, com conta conhecida (a conta vai: pede ação)" do
    test "senha errada (045/US1 #3)", ctx do
      user = conta_com_senha(ctx.tenant)

      {resultado, atributos} = entrar(user.email, @senha_errada)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :senha_errada)
      assert atributos["tenant.id"] == ctx.tenant.id
      assert atributos["user.ref"] == user.id
    end

    test "conta sem senha definida (045/US1 #8)", ctx do
      {:ok, sem_senha} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "sem-senha-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {resultado, atributos} = entrar(sem_senha.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :conta_sem_senha)
      assert atributos["user.ref"] == sem_senha.id
    end

    test "conta desativada (achado H3, parte B)", ctx do
      user = conta_com_senha(ctx.tenant)

      {:ok, _} =
        Tenants.disable_user(ctx.tenant, user.id, ctx.admin.id, %{
          "reason" => "left_the_organisation"
        })

      {resultado, atributos} = entrar(user.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :conta_desativada)
      assert atributos["user.ref"] == user.id
    end

    test "organização suspensa (achado H3, parte A)", ctx do
      user = conta_com_senha(ctx.tenant)

      # Por `update_all`: `:status` não é castável desde a 070, e o teste prova o efeito da
      # suspensão, não o ato (ver `organizacao_suspensa_test.exs`).
      {1, _} =
        Repo.update_all(from(t in Tenants.Tenant, where: t.id == ^ctx.tenant.id),
          set: [status: "suspended"]
        )

      {resultado, atributos} = entrar(user.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :organizacao_suspensa)
      assert atributos["tenant.id"] == ctx.tenant.id
      assert atributos["user.ref"] == user.id
    end

    test "a espera crescente segurou a tentativa (045 FR-016)", ctx do
      user = conta_com_senha(ctx.tenant)

      for _ <- 1..3 do
        {{:error, :invalid_credentials}, _} = entrar(user.email, @senha_errada)
      end

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:error, {:throttled, s}} = resultado
      assert is_integer(s) and s > 0
      assert_falhou(atributos, :em_espera)
      assert atributos["user.ref"] == user.id
    end
  end

  describe "entrar_com_senha — falhou, sem conta (nada do digitado sai)" do
    test "o identificador não identifica conta (045/US1 #4)" do
      digitado = "SENTINELA-IDENT-#{System.unique_integer([:positive])}@example.test"

      {resultado, atributos} = entrar(digitado, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :identificador_nao_resolveu)
      refute Map.has_key?(atributos, "user.ref")
      refute Map.has_key?(atributos, "tenant.id")
    end

    test "o elo revogado deixa o usuário do GitHub sem resolver (045/US1 #5)", ctx do
      user = conta_com_senha(ctx.tenant)
      p = pessoa(ctx.tenant, "regua-revogada")
      {:ok, _} = Tenants.declare_person(ctx.tenant, user.id, p.id, ctx.admin.id)
      {:ok, _} = Tenants.revoke_person(ctx.tenant, user.id, ctx.admin.id)
      Spans.recebidos(0)

      {resultado, atributos} = entrar("regua-revogada", @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :identificador_nao_resolveu)
      refute Map.has_key?(atributos, "user.ref")
      refute Map.has_key?(atributos, "tenant.id")
    end
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        Map.merge(source_attrs("U_#{login}_#{System.unique_integer([:positive])}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
      )

    p
  end

  # ------------------------------------------------------------------ sair e a queda (US2)

  # Entra pelo controller, como a pessoa, e devolve a conn com o cookie e a sessão gravada.
  defp sessao_aberta(conn, user) do
    conn = post(conn, ~p"/session", %{"identifier" => user.email, "password" => @senha})
    assert redirected_to(conn) == ~p"/people", "a guarda do cenário: a entrada foi aceita"
    Spans.recebidos(0)
    conn
  end

  defp cookie(conn), do: Map.take(get_session(conn), ["session_id", "session_secret"])

  defp com_cookie(cookie), do: init_test_session(build_conn(), cookie)

  defp unico_passo(spans, passo) do
    assert [span] = Spans.do_passo(spans, passo), "exatamente um passo #{passo}"
    Spans.atributos(span)
  end

  describe "sair (045/US1 #6) — T016" do
    test "sair com a sessão aberta conclui, com a organização e sem a conta", ctx do
      user = conta_com_senha(ctx.tenant)
      conn = sessao_aberta(build_conn(), user)

      conn |> recycle() |> delete(~p"/session")

      spans = Spans.recebidos()
      atributos = unico_passo(spans, :sair)
      assert atributos["outcome"] == "concluiu"
      refute Map.has_key?(atributos, "failure.reason")
      assert atributos["tenant.id"] == ctx.tenant.id
      refute Map.has_key?(atributos, "user.ref")
      assert Spans.do_passo(spans, :sessao_derrubada) == []
      assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas(conn)) == []
    end

    test "sair de novo com o cookie velho: a queda (encerrada) E sair que falhou, sem conta",
         ctx do
      user = conta_com_senha(ctx.tenant)
      conn = sessao_aberta(build_conn(), user)
      velho = cookie(conn)

      conn |> recycle() |> delete(~p"/session")
      Spans.recebidos()

      velho |> com_cookie() |> delete(~p"/session")

      spans = Spans.recebidos()
      queda = unico_passo(spans, :sessao_derrubada)
      assert queda["failure.reason"] == "encerrada"
      assert queda["user.ref"] == user.id

      sair = unico_passo(spans, :sair)
      assert sair["outcome"] == "falhou"
      assert sair["failure.reason"] == "sessao_ja_nao_existia"
      refute Map.has_key?(sair, "user.ref")
      refute Map.has_key?(sair, "tenant.id")
      assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas(conn)) == []
    end
  end

  describe "sessao_derrubada (064 S5 / 070) — T017" do
    test "o visitante sem cookie não é queda: nenhum passo" do
      get(build_conn(), ~p"/version")
      assert Spans.do_passo(Spans.recebidos(), :sessao_derrubada) == []
    end

    # Cada motivo de `Sessions.motivo()` e das duas cláusulas de `CurrentScope`, provocado como
    # acontece: o cookie adulterado, a linha que some, a senha trocada, a organização suspensa.
    @quedas [
      malformado: :sem_conta,
      inexistente: :sem_conta,
      resumo_errado: :com_conta,
      encerrada: :com_conta,
      vencida: :com_conta,
      epoca_velha: :com_conta,
      organizacao_suspensa: :com_conta,
      conta_desativada: :com_conta
    ]

    for {motivo, conta} <- @quedas do
      @motivo motivo
      @conta conta
      test "a queda por #{motivo} produz o passo, com o motivo", ctx do
        user = conta_com_senha(ctx.tenant)
        conn = sessao_aberta(build_conn(), user)
        cookie = provocar(@motivo, cookie(conn), user, ctx)

        resposta = cookie |> com_cookie() |> get(~p"/version")
        assert resposta.status == 200, "a guarda do cenário: a requisição foi atendida"

        spans = Spans.recebidos()
        atributos = unico_passo(spans, :sessao_derrubada)
        assert atributos["outcome"] == "falhou"
        assert atributos["failure.reason"] == Atom.to_string(@motivo)

        if @conta == :com_conta do
          assert atributos["user.ref"] == user.id
          assert atributos["tenant.id"] == ctx.tenant.id
        else
          refute Map.has_key?(atributos, "user.ref")
          refute Map.has_key?(atributos, "tenant.id")
        end

        assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas(conn)) == []
      end
    end
  end

  describe "sessao_derrubada pela tela aberta (#1042) — a hook do LiveView" do
    test "a conta desativada com a tela aberta produz a queda, com a conta", ctx do
      user = conta_com_senha(ctx.tenant)
      {:ok, view, _html} = build_conn() |> sessao_aberta(user) |> recycle() |> live(~p"/people")
      Spans.recebidos(0)

      {:ok, _} =
        Tenants.disable_user(ctx.tenant, user.id, ctx.admin.id, %{
          "reason" => "left_the_organisation"
        })

      assert_redirect(view, "/sign-in")

      # Desativar pelo ato encerra as sessões da conta: na tela aberta, a queda chega como
      # `encerrada`, pela hook — e não por `CurrentScope`, que esta requisição não atravessa.
      atributos = unico_passo(Spans.recebidos(), :sessao_derrubada)
      assert atributos["failure.reason"] == "encerrada"
      assert atributos["user.ref"] == user.id
    end
  end

  defp provocar(:malformado, cookie, _user, _ctx), do: %{cookie | "session_id" => "nao-e-uuid"}

  defp provocar(:inexistente, cookie, _user, _ctx),
    do: %{cookie | "session_id" => Ecto.UUID.generate()}

  defp provocar(:resumo_errado, cookie, _user, _ctx),
    do: %{cookie | "session_secret" => Base.url_encode64(:crypto.strong_rand_bytes(32))}

  defp provocar(:encerrada, cookie, _user, _ctx) do
    alterar_sessao(cookie, ended_at: DateTime.utc_now(:second))
  end

  defp provocar(:vencida, cookie, _user, _ctx) do
    alterar_sessao(cookie, inserted_at: DateTime.add(DateTime.utc_now(:second), -8, :day))
  end

  defp provocar(:epoca_velha, cookie, user, _ctx) do
    {1, _} =
      Repo.update_all(from(u in Tenants.User, where: u.id == ^user.id), inc: [password_epoch: 1])

    cookie
  end

  defp provocar(:organizacao_suspensa, cookie, _user, ctx) do
    {1, _} =
      Repo.update_all(from(t in Tenants.Tenant, where: t.id == ^ctx.tenant.id),
        set: [status: "suspended"]
      )

    cookie
  end

  # Por `update_all`, e não por `disable_user/4`: desativar pelo ato encerra as sessões da conta,
  # e a queda sairia como `encerrada`. `conta_desativada` é a sessão que ficou aberta enquanto a
  # coluna mudou — a corrida que a cláusula de `CurrentScope` existe para fechar.
  defp provocar(:conta_desativada, cookie, user, _ctx) do
    {1, _} =
      Repo.update_all(from(u in Tenants.User, where: u.id == ^user.id),
        set: [disabled_at: DateTime.utc_now(:second)]
      )

    cookie
  end

  defp alterar_sessao(%{"session_id" => id} = cookie, campos) do
    {1, _} = Repo.update_all(from(s in UserSession, where: s.id == ^id), set: campos)
    cookie
  end

  # O que a pessoa e o navegador carregam, e que não pode sair: a senha, o e-mail e o cookie.
  defp sentinelas(conn) do
    [@senha, conn |> get_session("session_secret") |> to_string()]
    |> Enum.reject(&(&1 == ""))
  end
end
