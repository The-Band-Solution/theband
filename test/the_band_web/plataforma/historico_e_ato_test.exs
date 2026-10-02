defmodule TheBandWeb.Plataforma.HistoricoEAtoTest do
  @moduledoc """
  A tela do histórico e do ato — spec 070, T056 (FR-003, FR-006; U1, U3, U4; tela 5 do protótipo).
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.Suspension
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  setup %{conn: conn} do
    {op, _} = operador_pronto(name: "Rui Operador")
    tenant = tenant_fixture()
    %{conn: log_in_operador(conn, op), op: op, tenant: tenant}
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
          do: send(eu, {ref, :select})
      end,
      nil
    )

    resultado = fun.()
    :telemetry.detach(id)
    {resultado, contar(ref, 0)}
  end

  defp contar(ref, n) do
    receive do
      {^ref, :select} -> contar(ref, n + 1)
    after
      0 -> n
    end
  end

  defp agir(conn, t, ato, params) do
    caminho = "/platform/organizations/#{t.slug}/#{ato}"
    {r, _log} = with_log(fn -> post(conn, caminho, params) end)
    r
  end

  defp estado(t), do: Repo.get!(Tenant, t.id).status

  test "a organização ativa oferece só suspender; suspender pela tela redireciona e o histórico mostra quem",
       %{conn: conn, tenant: t} do
    html = conn |> get(~p"/platform/organizations/#{t.slug}") |> html_response(200)
    assert html =~ "Suspend #{t.name}"
    refute html =~ "Reactivate #{t.name}"
    assert html =~ "never suspended"

    {resposta, selects} =
      selects_em_tenants(fn ->
        agir(conn, t, "suspension", %{
          "reason" => "contract_ended",
          "note" => "",
          "confirm_slug" => t.slug
        })
      end)

    assert redirected_to(resposta, 302) == ~p"/platform/organizations/#{t.slug}"
    assert selects == 1, "o sucesso lê tenants uma vez (U1)"
    assert estado(t) == "suspended"

    html =
      resposta |> recycle() |> get(~p"/platform/organizations/#{t.slug}") |> html_response(200)

    assert html =~ "Reactivate #{t.name}"
    refute html =~ "Suspend, sign everyone out"
    assert html =~ "by Rui Operador"
    assert html =~ "The contract ended"
    assert html =~ "not reactivated — still suspended"
    assert html =~ "no note"
    assert html =~ "Suspended. Every session was ended"
  end

  test "reativar pela tela fecha o episódio, com as duas metades escritas", %{
    conn: conn,
    tenant: t
  } do
    agir(conn, t, "suspension", %{
      "reason" => "other",
      "note" => "motivo",
      "confirm_slug" => t.slug
    })

    r =
      agir(conn, t, "reactivation", %{
        "reason" => "contract_resumed",
        "note" => "renovado",
        "confirm_slug" => t.slug
      })

    assert redirected_to(r, 302) == ~p"/platform/organizations/#{t.slug}"
    assert estado(t) == "active"

    html = conn |> get(~p"/platform/organizations/#{t.slug}") |> html_response(200)
    assert html =~ "The contract resumed" and html =~ "renovado" and html =~ "motivo"
    assert html =~ "Suspend #{t.name}"
  end

  test "a razão fora da lista é recusada, nada muda, e a recusa lê tenants duas vezes (U3)", %{
    conn: conn,
    tenant: t
  } do
    {r, selects} =
      selects_em_tenants(fn ->
        agir(conn, t, "suspension", %{"reason" => "inventada", "confirm_slug" => t.slug})
      end)

    assert html_response(r, 422) =~ "Not suspended. Choose a reason from the list."
    assert selects == 2
    assert estado(t) == "active"
    assert Repo.all(from s in Suspension, where: s.tenant_id == ^t.id) == []
  end

  test "a nota obrigatória ausente tem a frase da tela 5c", %{conn: conn, tenant: t} do
    r =
      agir(conn, t, "suspension", %{"reason" => "suspected_compromise", "confirm_slug" => t.slug})

    html = html_response(r, 422)
    assert html =~ "Not suspended. A note is required for this reason"
    assert html =~ "(Suspected compromise)"
  end

  test "a confirmação diferente: 422, o ato não é chamado, nenhum evento, um SELECT", %{
    conn: conn,
    tenant: t
  } do
    {{r, log}, selects} =
      selects_em_tenants(fn ->
        with_log(fn ->
          post(conn, "/platform/organizations/#{t.slug}/suspension", %{
            "reason" => "contract_ended",
            "confirm_slug" => t.slug <> "x",
            "note" => "o que a pessoa escreveu"
          })
        end)
      end)

    html = html_response(r, 422)
    assert html =~ "Not suspended. The confirmation did not match."
    assert html =~ "Type #{t.slug} exactly. Nothing changed."
    # O formulário volta como a pessoa o deixou.
    assert html =~ "o que a pessoa escreveu"
    assert selects == 1
    refute log =~ "operador ato recusado"
    assert estado(t) == "active"
  end

  test "já suspensa: a frase diz desde quando e por quem", %{conn: conn, tenant: t} do
    agir(conn, t, "suspension", %{"reason" => "contract_ended", "confirm_slug" => t.slug})
    r = agir(conn, t, "suspension", %{"reason" => "contract_ended", "confirm_slug" => t.slug})

    html = html_response(r, 422)
    assert html =~ "Not suspended. #{t.name} is already suspended, since"
    assert html =~ "by Rui Operador"
  end

  test "slug inexistente dá 404, inclusive com a confirmação diferente (U4)", %{conn: conn} do
    assert conn |> get(~p"/platform/organizations/nao-existe") |> html_response(404)

    r =
      agir(conn, %{slug: "nao-existe"}, "suspension", %{
        "reason" => "other",
        "confirm_slug" => "outra-coisa"
      })

    assert html_response(r, 404)
  end

  test "o episódio da migração: o rótulo da base e a ausência do autor escritos", %{
    conn: conn,
    tenant: t
  } do
    Repo.update_all(from(x in Tenant, where: x.id == ^t.id), set: [status: "suspended"])

    Repo.insert!(%Suspension{
      tenant_id: t.id,
      suspended_at: DateTime.utc_now(:second),
      suspend_reason: "not_recorded"
    })

    html = conn |> get(~p"/platform/organizations/#{t.slug}") |> html_response(200)
    assert html =~ "The reason was not recorded"
    assert html =~ "by: not recorded — suspended by hand before this record existed"
  end

  test "a lista mostra a data da última suspensão", %{conn: conn, tenant: t} do
    agir(conn, t, "suspension", %{"reason" => "contract_ended", "confirm_slug" => t.slug})
    html = conn |> get(~p"/platform/organizations") |> html_response(200)
    assert html =~ Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d")
  end

  # D-9 da conferência (T060): na corrida de duas abas, a recusa troca o formulário para o OUTRO
  # ato, e ele não pode vir com a razão, a nota e a confirmação já digitadas.
  test "depois de 'already suspended', o formulário de reativar vem vazio", %{
    conn: conn,
    tenant: t
  } do
    agir(conn, t, "suspension", %{"reason" => "other", "note" => "x", "confirm_slug" => t.slug})

    r =
      agir(conn, t, "suspension", %{
        "reason" => "other",
        "note" => "a nota da segunda aba",
        "confirm_slug" => t.slug
      })

    html = html_response(r, 422)
    assert html =~ "Reactivate #{t.name}"
    refute html =~ "a nota da segunda aba"
    refute html =~ ~s(value="#{t.slug}")
    refute html =~ "checked"
  end

  test "a lista diz quando a última suspensão foi a da migração", %{conn: conn, tenant: t} do
    Repo.update_all(from(x in Tenant, where: x.id == ^t.id), set: [status: "suspended"])

    Repo.insert!(%Suspension{
      tenant_id: t.id,
      suspended_at: DateTime.utc_now(:second),
      suspend_reason: "not_recorded"
    })

    html = conn |> get(~p"/platform/organizations") |> html_response(200)
    assert html =~ "reason not recorded"
  end

  # S-US1-1 de `seguranca-us1.md`: a corrida chega também pelas recusas que não passam pelo passo
  # `:estado` (razão, nota, confirmação). O formulário desenhado é o do estado relido; se não for o
  # do ato enviado, ele vem vazio e a frase diz que o estado mudou.
  defp mudar_por_fora(t, para) do
    Repo.update_all(from(x in Tenant, where: x.id == ^t.id), set: [status: para])
  end

  for {nome, ato, para, params, frase} <- [
        {"suspender sem a nota, já suspensa por outro", "suspension", "suspended",
         %{"reason" => "other", "note" => ""}, "is already suspended"},
        {"suspender com a confirmação errada, já suspensa por outro", "suspension", "suspended",
         %{"reason" => "other", "note" => "nota digitada", "confirm_slug" => "errado"},
         "is already suspended"},
        {"reativar com razão fora da lista, já reativada por outro", "reactivation", "active",
         %{"reason" => "inventada", "note" => "nota digitada"}, "is not suspended"},
        {"reativar com a confirmação errada, já reativada por outro", "reactivation", "active",
         %{"reason" => "contract_resumed", "note" => "nota digitada", "confirm_slug" => "errado"},
         "is not suspended"}
      ] do
    @ato ato
    @para para
    @params params
    @frase frase
    test "corrida: #{nome} — o outro formulário vem vazio, e a frase diz o estado", %{
      conn: conn,
      tenant: t
    } do
      # O estado de partida é o oposto do que outro operador deixou.
      if @para == "active" do
        agir(conn, t, "suspension", %{"reason" => "contract_ended", "confirm_slug" => t.slug})
        # outro operador reativa, por fora
        Repo.update_all(
          from(s in Suspension, where: s.tenant_id == ^t.id and is_nil(s.reactivated_at)),
          set: [
            reactivated_at: DateTime.utc_now(:second),
            reactivated_by_operator_id: ctx_op(t),
            reactivate_reason: "contract_resumed"
          ]
        )
      end

      mudar_por_fora(t, @para)
      params = Map.put_new(@params, "confirm_slug", t.slug)

      html = html_response(agir(conn, t, @ato, params), 422)
      assert html =~ @frase
      refute html =~ "nota digitada"
      refute html =~ ~s(value="#{t.slug}")
      refute html =~ "checked"
    end
  end

  defp ctx_op(t) do
    Repo.one!(
      from(s in Suspension,
        where: s.tenant_id == ^t.id,
        order_by: [desc: s.suspended_at],
        limit: 1,
        select: s.suspended_by_operator_id
      )
    )
  end

  test "controle: sem corrida, a recusa da nota mantém o formulário como a pessoa o deixou", %{
    conn: conn,
    tenant: t
  } do
    html =
      conn
      |> agir(t, "suspension", %{
        "reason" => "other",
        "note" => "",
        "confirm_slug" => t.slug
      })
      |> html_response(422)

    assert html =~ "A note is required for this reason"
    assert html =~ ~s(value="#{t.slug}")
    assert html =~ "checked"
  end
end
