defmodule TheBandWeb.Api.MotivoDaRecusaTest do
  @moduledoc """
  **SC-004 — o motivo real de cada recusa é recuperável no log interno.**

  ## O que estava errado

  `autenticar/1` tinha `_ -> {:error, :recusado}` no `else`, e com isso token inexistente,
  revogado e expirado produziam a **mesma** entrada: `motivo=credencial_recusada`.

  A informação já existia — `Token.estado/2` calcula `:revogado` e `:expirado` — e era
  descartada uma linha antes de chegar a quem opera.

  Medido na aceitação da 061, em 2026-09-23: três causas, **duas** palavras no log.

  ## As duas afirmações deste arquivo, e por que vão juntas

  **No log, as causas se distinguem.** Sem isso, *"alguém está tentando um token que nunca
  existiu"* — varredura — e *"alguém está usando um revogado"* — credencial que vazou antes
  da revogação — são investigações que começam iguais.

  **No corpo, as causas são indistinguíveis.** É o SC-003, e existe porque distinguir ali
  confirmaria a quem testa uma credencial roubada que ela um dia existiu.

  **Provar uma sem a outra deixaria passar o conserto que quebra a outra.** É por isso que
  os dois testes vivem no mesmo arquivo, e a falha de qualquer um aponta o outro.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog

  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.ApiAccessToken, as: Token

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    c = fn valor ->
      conn
      |> recycle()
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> valor)
      |> Plug.Conn.put_req_header("accept", "application/json")
    end

    %{conn: conn, tenant: tenant, admin: admin, c: c}
  end

  defp token(ctx, rotulo) do
    {:ok, t, valor} = Tenants.create_api_token(ctx.tenant, ctx.admin, %{label: rotulo}, ctx.admin)
    {t, valor}
  end

  defp expirar(id) do
    Repo.update_all(from(t in Token, where: t.id == ^id),
      set: [expires_at: DateTime.add(DateTime.utc_now(:second), -1, :day)]
    )
  end

  # Os cinco casos, cada um com o valor que os produz.
  defp casos(ctx) do
    {revogado, v_rev} = token(ctx, "rev")

    {:ok, _} =
      Tenants.revoke_api_token(ctx.tenant, revogado.id, ctx.admin, %{
        revocation_clause: "integracao_encerrada"
      })

    {expirado, v_exp} = token(ctx, "exp")
    expirar(expirado.id)

    {valido, v_ok} = token(ctx, "ok")
    ["tb", "api", publico, _] = String.split(v_ok, "_", parts: 4)

    [
      {:malformado, "isto-nao-e-um-token"},
      {:inexistente, "tb_api_deadbeefcafe_" <> String.duplicate("x", 43)},
      {:segredo_errado, "tb_api_" <> publico <> "_" <> String.duplicate("z", 43)},
      {:revogado, v_rev},
      {:expirado, v_exp}
    ]
    |> tap(fn _ -> assert valido end)
  end

  test "no LOG, as cinco causas se distinguem", ctx do
    casos = casos(ctx)

    log =
      capture_log(fn ->
        for {_esperado, valor} <- casos, do: ctx.c.(valor) |> get(~p"/api/v1/teams")
      end)

    for {esperado, _valor} <- casos do
      assert log =~ "motivo=#{esperado}", """
      O log não traz `motivo=#{esperado}`.

      Antes do conserto, as cinco causas chegavam como `credencial_recusada` — e a
      informação já existia, descartada pelo `_` do `else` em `autenticar/1`.
      """
    end

    distintos =
      Regex.scan(~r/motivo=(\w+)/, log) |> Enum.map(&List.last/1) |> Enum.uniq() |> length()

    assert distintos >= 5, "só #{distintos} motivos distintos no log, e são cinco causas"
  end

  test "no CORPO, as cinco são indistinguíveis — SC-003", ctx do
    corpos =
      for {_esperado, valor} <- casos(ctx) do
        ctx.c.(valor)
        |> get(~p"/api/v1/teams")
        |> Map.fetch!(:resp_body)
        |> String.replace(~r/"request_id":"[^"]+"/, ~s("request_id":"X"))
      end

    assert length(Enum.uniq(corpos)) == 1, """
    Os corpos diferem entre si:

    #{Enum.uniq(corpos) |> Enum.map_join("\n", &("  " <> &1))}

    Distinguir a causa no corpo confirma a quem testa uma credencial roubada que ela um dia
    existiu. **O conserto do log não pode ter vazado para a resposta.**
    """

    assert hd(corpos) =~ "unauthorized"
  end

  test "o corpo não nomeia o motivo interno, em nenhuma das cinco", ctx do
    for {esperado, valor} <- casos(ctx) do
      corpo = ctx.c.(valor) |> get(~p"/api/v1/teams") |> Map.fetch!(:resp_body)

      refute corpo =~ to_string(esperado),
             "a palavra `#{esperado}` saiu no corpo — ela é do log interno"
    end
  end

  test "e o request_id liga a recusa que se vê ao motivo que não se vê", ctx do
    {revogado, valor} = token(ctx, "liga")

    {:ok, _} =
      Tenants.revoke_api_token(ctx.tenant, revogado.id, ctx.admin, %{
        revocation_clause: "integracao_encerrada"
      })

    {corpo, log} =
      with_log(fn ->
        ctx.c.(valor) |> get(~p"/api/v1/teams") |> json_response(401)
      end)

    id = corpo["error"]["request_id"]

    assert id, "sem o request_id, a recusa não é rastreável"

    assert log =~ "motivo=revogado", "o motivo tem de estar no log"

    assert log =~ id, """
    O log não cita o `request_id` que o cliente recebeu. Sem esse elo, saber o motivo exige
    adivinhar qual linha do log corresponde a qual recusa.
    """
  end
end
