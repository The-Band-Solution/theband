defmodule TheBand.Platform.SuspenderTest do
  @moduledoc """
  Suspender uma organização numa transação — spec 070, T049 (FR-003, FR-004, FR-013, FR-014;
  research R8; U1, D1-d, O5).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.SuspensaoFixtures

  alias TheBand.Platform
  alias TheBand.Platform.{Grant, Suspension, SuspensionReasons}
  alias TheBand.Tenants.Schemas.{ApiAccessToken, UserSession}
  alias TheBand.Tenants.Tenant

  @razao %{reason: "contract_ended", note: nil}

  setup do
    {op, sessao} = sessao_de_operador()
    Map.merge(organizacao_povoada(), %{op: op, sessao: sessao, b: organizacao_povoada()})
  end

  defp nada_mudou!(tenant) do
    assert Repo.get!(Tenant, tenant.id).status == "active"
    assert Repo.all(from s in Suspension, where: s.tenant_id == ^tenant.id) == []
  end

  defp suspender(ctx, slug \\ nil, razao \\ @razao) do
    {r, _log} = with_log(fn -> Platform.suspender(ctx.sessao, slug || ctx.tenant.slug, razao) end)
    refute tem_tenant?(r), "o retorno carrega %Tenant{} (D1-d)"
    r
  end

  defp selects_em_tenants(fun) do
    ref = make_ref()
    eu = self()
    id = {__MODULE__, ref}

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ ->
        if self() == eu and String.starts_with?(sql, "SELECT") and sql =~ ~s(FROM "tenants"),
          do: send(eu, {ref, sql})
      end,
      nil
    )

    resultado = fun.()
    :telemetry.detach(id)

    {resultado,
     Stream.repeatedly(fn -> receive(do: ({^ref, s} -> s), after: (0 -> nil)) end)
     |> Enum.take_while(& &1)}
  end

  test "o sucesso: suspended, episódio aberto, sessões encerradas, tokens revogados, um SELECT",
       ctx do
    {r, selects} = selects_em_tenants(fn -> suspender(ctx) end)
    assert {:ok, %Suspension{} = ep} = r
    assert length(selects) == 1, "o ato lê tenants uma vez (U1): #{inspect(selects)}"

    assert Repo.get!(Tenant, ctx.tenant.id).status == "suspended"
    assert ep.suspend_reason == "contract_ended" and ep.suspended_by_operator_id == ctx.op.id
    for s <- ctx.sessoes, do: assert(Repo.get!(UserSession, s.id).ended_at)

    t = Repo.get!(ApiAccessToken, ctx.token.id)
    assert t.revocation_clause == "organizacao_suspensa" and t.revoked_by_suspension_id == ep.id

    # B continua.
    for s <- ctx.b.sessoes, do: assert(is_nil(Repo.get!(UserSession, s.id).ended_at))
    assert is_nil(Repo.get!(ApiAccessToken, ctx.b.token.id).revoked_at)

    # O trigger adiado de T044a, conferido como no COMMIT.
    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
  end

  test ":nao_autorizado com a concessão revogada, e nada muda", ctx do
    Repo.update_all(from(g in Grant, where: g.operator_id == ^ctx.op.id),
      set: [
        revoked_at: DateTime.utc_now(:second),
        revoked_via: "release_command",
        revoked_by_declared: "x"
      ]
    )

    assert suspender(ctx) == {:error, :nao_autorizado}
    nada_mudou!(ctx.tenant)
    for s <- ctx.sessoes, do: assert(is_nil(Repo.get!(UserSession, s.id).ended_at))
  end

  test ":not_found para slug que não existe", ctx do
    assert suspender(ctx, "nao-existe-#{System.unique_integer()}") == {:error, :not_found}
  end

  test ":ja_suspensa na segunda vez, pelo passo :estado", ctx do
    {:ok, _} = suspender(ctx)
    assert suspender(ctx) == {:error, :ja_suspensa}
  end

  test ":ja_suspensa também quando o índice parcial recusa o episódio", ctx do
    Repo.insert!(%Suspension{
      tenant_id: ctx.tenant.id,
      suspended_at: DateTime.utc_now(:second),
      suspended_by_operator_id: ctx.op.id,
      suspend_reason: "other",
      suspend_note: "aberto à mão"
    })

    assert suspender(ctx) == {:error, :ja_suspensa}
    assert Repo.get!(Tenant, ctx.tenant.id).status == "active"
  end

  test "razão fora da lista, ou sem a nota que a base exige: changeset, e nada muda", ctx do
    for razao <- [
          %{reason: "inventada", note: nil},
          %{reason: "not_recorded", note: nil},
          %{reason: "suspected_compromise", note: nil},
          %{reason: "other", note: ""}
        ] do
      assert {:error, %Ecto.Changeset{valid?: false}} = suspender(ctx, nil, razao), inspect(razao)
      nada_mudou!(ctx.tenant)
    end
  end

  test ":vocabulario_nao_declarado sem a regra na base", ctx do
    Application.put_env(:the_band, SuspensionReasons, regra: "platform.regra_que_nao_existe")
    on_exit(fn -> Application.delete_env(:the_band, SuspensionReasons) end)

    assert suspender(ctx) == {:error, :vocabulario_nao_declarado}
    nada_mudou!(ctx.tenant)
  end

  test "o aviso às telas sai depois do commit, uma por sessão encerrada", ctx do
    for s <- ctx.sessoes, do: Phoenix.PubSub.subscribe(TheBand.PubSub, "sessao:" <> s.id)
    {:ok, _} = suspender(ctx)
    for _ <- ctx.sessoes, do: assert_received(:sessao_encerrada)
  end

  # O5: o "pelo menos um, e só Suspensions" que saiu de T046a.
  test "trocar_estado/3 tem um chamador, e é TheBand.Platform.Suspensions" do
    {:ok, xref} =
      :xref.start(:"xref_#{System.unique_integer([:positive])}", xref_mode: :functions)

    chamadores =
      try do
        ebin = :the_band |> :code.lib_dir() |> Path.join("ebin") |> to_charlist()
        {:ok, _} = :xref.add_directory(xref, ebin, warnings: false)

        {:ok, mods} =
          :xref.q(xref, ~c"(Mod) (E || 'Elixir.TheBand.Tenants':trocar_estado/3)")

        mods |> Enum.map(&elem(&1, 0)) |> Enum.reject(&(&1 == TheBand.Tenants))
      after
        :xref.stop(xref)
      end

    assert chamadores == [TheBand.Platform.Suspensions]
  end

  test "a recusa vai ao log com o motivo, e o sucesso com as contagens", ctx do
    log = capture_log(fn -> Platform.suspender(ctx.sessao, "nao-existe", @razao) end)
    assert log =~ "operador ato recusado" and log =~ "motivo=:not_found"

    log = capture_log(fn -> Platform.suspender(ctx.sessao, ctx.tenant.slug, @razao) end)
    assert log =~ "ato de plataforma" and log =~ "ato=:organizacao_suspensa"
    assert log =~ "sessoes=2" and log =~ "tokens=1"
  end

  # S-US1-3: o aviso às telas sai depois do `commit` real só se o ato abrir a própria transação.
  test "dentro da transação de quem chama, o ato levanta, e nada muda", ctx do
    assert_raise ArgumentError, ~r/abre a própria transação/, fn ->
      Repo.transaction(fn -> Platform.suspender(ctx.sessao, ctx.tenant.slug, @razao) end)
    end

    nada_mudou!(ctx.tenant)
  end

  # S-US1-4: a tela recebe de quem agiu só o id e o nome, e não os hashes da credencial.
  test "o histórico traz de quem agiu só o id e o nome", ctx do
    {:ok, _} = suspender(ctx)
    {:ok, %{episodios: [ep]}} = Platform.organizacao(ctx.sessao, ctx.tenant.slug)

    assert ep.suspended_by_operator.name
    assert ep.suspended_by_operator.password_hash == nil
    assert ep.suspended_by_operator.email == nil
  end
end
