defmodule TheBand.Tenants.TrocaDeSenhaComEsperaTest do
  @moduledoc """
  A troca de senha confere a atual com o contador e a espera da entrada — issue #1409.

  Avaliação de segurança, feita antes do código: `docs/seguranca/2026-10-09-1409-troca-de-senha.md`.
  Cada teste é uma linha da tabela Q da avaliação, e o identificador vai no nome. A violação
  vem primeiro (L03): metade das asserções é `refute`.

  Antes da #1409, `change_password/4` chamava `Bcrypt.verify_pass/2` direto: quem alcançasse uma
  sessão alheia testava senhas sem espera, sem contador e sem registro, e a certa lhe dava a conta.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  @moduletag :capture_log

  @senha "senha-atual-SENTINELA-1409"
  @nova "senha-nova-SENTINELA-1409"
  @errada "errada-SENTINELA-1409-x"

  setup do
    tenant = tenant_fixture()
    %{tenant: tenant, user: conta_com_senha(tenant)}
  end

  defp conta_com_senha(tenant) do
    user = user_fixture(tenant, "member")
    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    user
  end

  defp origem, do: TheBand.OrigemDeTeste.nova()
  defp relida(user), do: Repo.get!(User, user.id)

  defp trocar(ctx, atual, nova \\ @nova),
    do: Tenants.change_password(ctx.tenant, ctx.user.id, atual, nova)

  # Os custos de hash, contados por motivo — o mesmo evento que a 077 usa para contar sem
  # cronômetro.
  defp contando_hashes(fun) do
    ref = make_ref()
    eu = self()
    id = "hash-1409-#{inspect(ref)}"

    :telemetry.attach(
      id,
      [:the_band, :tenants, :custo_do_hash],
      fn _e, _m, %{motivo: motivo}, _ -> send(eu, {ref, motivo}) end,
      nil
    )

    try do
      resultado = fun.()
      {resultado, coletar(ref, [])}
    after
      :telemetry.detach(id)
    end
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, motivo} -> coletar(ref, [motivo | acc])
    after
      0 -> acc
    end
  end

  defp contar(motivos, motivo), do: Enum.count(motivos, &(&1 == motivo))

  defp recuar_a_janela(user) do
    Repo.update_all(from(u in User, where: u.id == ^user.id),
      set: [last_failed_at: DateTime.add(DateTime.utc_now(:second), -120, :second)]
    )
  end

  describe "um contador só para o mesmo segredo (D1)" do
    test "Q1 — três falhas na troca põem a entrada em espera", ctx do
      assert {:error, :invalid_current} = trocar(ctx, @errada)
      assert {:error, :invalid_current} = trocar(ctx, @errada)
      assert {:error, :tentativas_esgotadas} = trocar(ctx, @errada)

      assert relida(ctx.user).failed_attempts == 3

      assert {:error, {:throttled, s}} =
               Tenants.authenticate(ctx.user.email, @senha, origem: origem())

      assert s > 0 and s <= 60
    end

    test "Q2 — três falhas na entrada põem a troca em espera, e nem a senha certa troca", ctx do
      for _ <- 1..3,
          do:
            {:error, :invalid_credentials} =
              Tenants.authenticate(ctx.user.email, @errada, origem: origem())

      assert {:error, {:throttled, _}} = trocar(ctx, @senha)

      depois = relida(ctx.user)

      refute Bcrypt.verify_pass(@nova, depois.password_hash),
             "a senha foi trocada durante a espera"

      assert Bcrypt.verify_pass(@senha, depois.password_hash)
      assert depois.failed_attempts == 3, "a recusa em espera não confere, e não conta falha"
    end

    test "Q3 — em espera a senha não é conferida, mas o custo do hash é pago", ctx do
      for _ <- 1..3, do: trocar(ctx, @errada)

      {resultado, motivos} = contando_hashes(fn -> trocar(ctx, @senha) end)

      assert {:error, {:throttled, _}} = resultado
      assert contar(motivos, :senha_conferida) == 0, "a senha foi conferida dentro da janela"
      assert contar(motivos, :em_espera) == 1, "a recusa em espera respondeu sem pagar o hash"
    end

    test "Q4 — a atual certa zera o contador e registra quantas falhas apagou", ctx do
      for _ <- 1..2, do: {:error, :invalid_current} = trocar(ctx, @errada)
      assert relida(ctx.user).failed_attempts == 2, "guarda: as duas falhas foram contadas"

      log = capture_log(fn -> assert {:ok, _} = trocar(ctx, @senha) end)

      depois = relida(ctx.user)
      assert depois.failed_attempts == 0
      assert depois.last_failed_at == nil
      assert log =~ "senha atual conferida"
      assert log =~ "falhas_apagadas=2", "o acerto apagou o rastro sem registrá-lo (H4)"
    end

    test "Q12 — atual certa com nova curta também zera: a prova de conhecimento aconteceu", ctx do
      for _ <- 1..2, do: {:error, :invalid_current} = trocar(ctx, @errada)
      assert relida(ctx.user).failed_attempts == 2

      assert {:error, %Ecto.Changeset{}} = trocar(ctx, @senha, "curta")

      depois = relida(ctx.user)
      assert depois.failed_attempts == 0
      assert Bcrypt.verify_pass(@senha, depois.password_hash), "a nova curta não pode ser gravada"
    end

    test "a falha que esgota as livres é distinta da que não esgota, e a espera não é nenhuma das duas",
         ctx do
      assert {:error, :invalid_current} = trocar(ctx, @errada)
      assert {:error, :invalid_current} = trocar(ctx, @errada)
      assert {:error, :tentativas_esgotadas} = trocar(ctx, @errada)
      assert {:error, {:throttled, _}} = trocar(ctx, @errada)

      # Vencida a janela, a próxima conferida que erra esgota de novo: o contador já está acima.
      recuar_a_janela(ctx.user)
      assert {:error, :tentativas_esgotadas} = trocar(ctx, @errada)
      assert relida(ctx.user).failed_attempts == 4
    end
  end

  describe "a corrida entre abas (P1, #1046)" do
    test "Q5 — dez trocas erradas em paralelo não contornam a espera", ctx do
      {resultados, motivos} =
        contando_hashes(fn ->
          1..10
          |> Task.async_stream(fn _ -> trocar(ctx, @errada) end,
            max_concurrency: 10,
            ordered: false
          )
          |> Enum.map(fn {:ok, r} -> r end)
        end)

      conferidas = contar(motivos, :senha_conferida)
      assert conferidas > 0, "a captura não mediu conferência nenhuma"

      assert conferidas <= 3, "#{conferidas} tentativas paralelas testaram a senha"
      assert relida(ctx.user).failed_attempts == conferidas
      assert Enum.count(resultados, &match?({:error, {:throttled, _}}, &1)) == 10 - conferidas
    end

    test "a conta é relida com FOR UPDATE antes de conferir a atual", ctx do
      ref = make_ref()
      eu = self()
      id = "trava-1409-#{inspect(ref)}"

      :telemetry.attach(
        id,
        [:the_band, :repo, :query],
        fn _e, _m, %{query: sql}, _ -> send(eu, {ref, sql}) end,
        nil
      )

      try do
        trocar(ctx, @errada)
      after
        :telemetry.detach(id)
      end

      consultas = coletar(ref, [])
      assert consultas != [], "a captura não mediu consulta nenhuma"
      assert Enum.any?(consultas, &(&1 =~ ~s(FROM "users") and &1 =~ "FOR UPDATE"))
    end
  end

  describe "isolamento entre organizações" do
    test "Q9 — a falha conta na conta da sessão, e outro tenant não alcança a conta", ctx do
      outro = tenant_fixture()
      vizinha = conta_com_senha(outro)

      for _ <- 1..3, do: trocar(ctx, @errada)

      assert relida(ctx.user).failed_attempts == 3, "guarda: as falhas foram registradas"
      assert relida(vizinha).failed_attempts == 0

      assert {:error, :not_found} = Tenants.change_password(outro, ctx.user.id, @errada, @nova)
      assert {:error, :not_found} = Tenants.change_password(outro, ctx.user.id, @senha, @nova)
      assert relida(ctx.user).failed_attempts == 3, "o tenant errado contou falha na conta alheia"
      refute Bcrypt.verify_pass(@nova, relida(ctx.user).password_hash)
    end
  end

  describe "nenhum segredo no log" do
    test "Q10 — falha, espera, esgotamento e acerto não escrevem a atual nem a nova", ctx do
      anterior = Logger.level()
      Logger.configure(level: :debug)

      try do
        log =
          capture_log([level: :debug], fn ->
            trocar(ctx, @errada)
            trocar(ctx, @errada)
            trocar(ctx, @errada)
            trocar(ctx, @senha)
            recuar_a_janela(ctx.user)
            trocar(ctx, @senha)
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
