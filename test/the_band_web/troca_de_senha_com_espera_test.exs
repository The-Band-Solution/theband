defmodule TheBandWeb.TrocaDeSenhaComEsperaTest do
  @moduledoc """
  `POST /profile/password` com o contador e a espera da entrada — issue #1409, o lado da tela.

  Avaliação: `docs/seguranca/2026-10-09-1409-troca-de-senha.md`, D2 e D3, testes Q6, Q7, Q8 e
  Q10. O atacante é quem alcançou uma sessão alheia: tem o cookie, não tem a senha.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog

  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession

  @moduletag :capture_log

  @senha "atual-SENTINELA-web-1409"
  @nova "nova-SENTINELA-web-1409"
  @errada "errada-SENTINELA-web-1409"

  setup do
    {tenant, _admin} = tenant_with_admin()

    {:ok, dono} =
      Tenants.create_user(tenant, %{
        "email" => "troca-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, dono} = Tenants.set_password(tenant, dono.id, @senha)
    %{tenant: tenant, dono: dono}
  end

  defp trocar(conn, atual, nova \\ @nova),
    do: post(conn, ~p"/profile/password", %{"current" => atual, "password" => nova})

  defp flash_de_erro(conn), do: Phoenix.Flash.get(conn.assigns.flash, :error)

  # A sessão aberta por `log_in/2` vive na sessão de teste da conn; o id dela sai daqui.
  defp sessao_aberta(conn), do: Repo.get!(UserSession, conn.private.plug_session["session_id"])

  describe "a tela não distingue espera de erro (D2)" do
    test "Q6 — senha errada e espera mostram a mesma frase, sem número", ctx do
      logado = log_in(build_conn(), ctx.dono)

      errada = trocar(logado, @errada)
      assert redirected_to(errada) == ~p"/profile"

      # A espera posta pela entrada, para a sessão continuar viva e a troca cair na janela.
      for _ <- 1..3,
          do: Tenants.authenticate(ctx.dono.email, @errada, origem: TheBand.OrigemDeTeste.nova())

      em_espera = trocar(logado, @senha)
      assert redirected_to(em_espera) == ~p"/profile"

      frase = flash_de_erro(errada)
      assert is_binary(frase) and frase != ""
      assert flash_de_erro(em_espera) == frase, "a tela distinguiu a espera da senha errada"
      refute frase =~ ~r/\d/, "a frase carrega número — os segundos da espera vazaram"
    end
  end

  describe "a falha conferida que esgota as livres (D3)" do
    test "Q7 — encerra SÓ a sessão corrente; a outra sessão da conta continua", ctx do
      sessao_a = log_in(build_conn(), ctx.dono)
      sessao_b = log_in(build_conn(), ctx.dono)
      id_a = sessao_aberta(sessao_a).id
      id_b = sessao_aberta(sessao_b).id

      primeira = trocar(sessao_a, @errada)
      assert redirected_to(primeira) == ~p"/profile"
      assert redirected_to(trocar(sessao_a, @errada)) == ~p"/profile"
      terceira = trocar(sessao_a, @errada)

      assert redirected_to(terceira) == ~p"/sign-in"

      assert flash_de_erro(terceira) == flash_de_erro(primeira),
             "o esgotamento ganhou frase própria"

      assert Repo.get!(UserSession, id_a).ended_at, "a sessão corrente não foi encerrada"
      refute Repo.get!(UserSession, id_b).ended_at, "a outra sessão da conta caiu junto"

      assert redirected_to(get(sessao_a, ~p"/profile")) == ~p"/sign-in"
      assert get(sessao_b, ~p"/profile").status == 200
    end

    test "Q8 — espera posta pela entrada não desloga o dono que tenta trocar", ctx do
      logado = log_in(build_conn(), ctx.dono)
      id = sessao_aberta(logado).id

      for _ <- 1..3,
          do: Tenants.authenticate(ctx.dono.email, @errada, origem: TheBand.OrigemDeTeste.nova())

      conn = trocar(logado, @senha)

      assert redirected_to(conn) == ~p"/profile"
      refute Repo.get!(UserSession, id).ended_at, "a recusa em espera encerrou a sessão do dono"
      assert get(logado, ~p"/profile").status == 200
    end
  end

  describe "nenhum segredo no log" do
    test "Q10 — o caminho da tela não escreve a atual nem a nova", ctx do
      anterior = Logger.level()
      Logger.configure(level: :debug)

      try do
        log =
          capture_log([level: :debug], fn ->
            logado = log_in(build_conn(), ctx.dono)
            trocar(logado, @errada)
            trocar(logado, @errada)
            trocar(logado, @errada)
            trocar(log_in(build_conn(), ctx.dono), @senha)

            Repo.update_all(from(u in Tenants.User, where: u.id == ^ctx.dono.id),
              set: [last_failed_at: DateTime.add(DateTime.utc_now(:second), -120, :second)]
            )

            trocar(log_in(build_conn(), ctx.dono), @senha)
          end)

        assert log =~ "troca de senha recusada", "guarda: o log da troca foi capturado"
        refute log =~ @senha
        refute log =~ @nova
        refute log =~ @errada
      after
        Logger.configure(level: anterior)
      end
    end
  end
end
