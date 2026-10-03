defmodule TheBandWeb.MesmaChaveTest do
  @moduledoc """
  O aviso da mesma chave em `/ai` — 064/T018, item C.1 da régua, decisão Q4 (a).

  O flash "It is the key already registered, so it still counts from <data>" só entra com as
  **seis condições** do parecer `specs/064-segredo-em-repouso/seguranca-c1-mesma-chave.md`. Cada
  teste abaixo é uma delas, na ordem do parecer, e cada um foi visto reprovando com o defeito
  injetado antes de ser aceito (AGENTS.md §14.0).

  O Mox substitui só a borda HTTP do provedor.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import Mox
  import Phoenix.LiveViewTest

  alias TheBand.AI
  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade
  alias TheBand.Repo
  alias TheBandWeb.IdadeDaCredencial

  setup :verify_on_exit!

  @k "sk-a-chave-k-de-teste-com-mais-de-vinte-caracteres-3b9d"
  @j "sk-a-chave-j-de-teste-com-mais-de-vinte-caracteres-0a1b"
  @mesma "already registered"

  setup %{conn: conn} do
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")

    on_exit(fn ->
      if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
    end)

    {tenant, admin} = tenant_with_admin()
    agora = DateTime.utc_now(:second)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      quatro_meses: DateTime.shift(agora, month: -4),
      dois_meses: DateTime.shift(agora, month: -2)
    }
  end

  defp aceita, do: expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:ok, ["gpt-5.4"]} end)

  defp gravada(tenant, chave, datas) do
    aceita()
    {:ok, cred} = AI.put(tenant, %{"secret" => chave})

    {1, _} = Repo.update_all(from(c in ProviderCredential, where: c.id == ^cred.id), set: datas)

    {:ok, cred} = AI.fetch(tenant)
    cred
  end

  defp salvar(live, params), do: live |> form("#ai-credential", params) |> render_submit()

  defp data(instante), do: IdadeDaCredencial.data(instante)

  test "condição 1 — conferir antes de comparar: chave recusada não ouve 'already registered'",
       ctx do
    antes = gravada(ctx.tenant, @k, secret_set_at: ctx.quatro_meses)

    # O provedor recusa o PRÓPRIO valor guardado (revogado na origem, por exemplo).
    expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
      {:error, {:rejeitada, "HTTP 401 — Incorrect API key provided"}}
    end)

    {:ok, live, _} = live(ctx.conn, ~p"/ai")
    html = salvar(live, %{"secret" => @k, "default_model" => ""})

    assert html =~ "refused the key"
    refute html =~ @mesma

    {:ok, depois} = AI.fetch(ctx.tenant)
    assert depois.secret_set_at == antes.secret_set_at
    assert depois.validated_at == antes.validated_at
  end

  test "condição 2 — a frase vem do estado do servidor, nunca de parâmetro do formulário", ctx do
    gravada(ctx.tenant, @k, secret_set_at: ctx.quatro_meses)
    aceita()

    {:ok, live, _} = live(ctx.conn, ~p"/ai")

    # Parâmetros hostis, que o formulário não tem, enviados junto com uma chave DIFERENTE.
    html =
      render_submit(live, "save", %{
        "secret" => @j,
        "default_model" => "",
        "same_key" => "true",
        "secret_set_at" => "2026-01-01T00:00:00Z"
      })

    refute html =~ @mesma
    assert html =~ "It replaces the key registered on #{data(ctx.quatro_meses)}"

    {:ok, depois} = AI.fetch(ctx.tenant)
    refute depois.secret_set_at == ~U[2026-01-01 00:00:00Z]
    assert depois.previous_secret_set_at == ctx.quatro_meses
    assert Idade.estado(depois, DateTime.utc_now(:second)) == :no_prazo
  end

  test "condição 3 — a linha legada regravada com a mesma chave não zera, e a frase cita a data antiga",
       ctx do
    gravada(ctx.tenant, @k, secret_set_at: nil, validated_at: ctx.quatro_meses)
    aceita()

    {:ok, live, _} = live(ctx.conn, ~p"/ai")
    html = salvar(live, %{"secret" => @k, "default_model" => ""})

    assert html =~
             "It is the key already registered, so it still counts from #{data(ctx.quatro_meses)}."

    {:ok, depois} = AI.fetch(ctx.tenant)
    assert Idade.em_uso_desde(depois) == ctx.quatro_meses
    assert Idade.estado(depois, DateTime.utc_now(:second)) == :vencida
    # O cartão e o pedido não mudam (2.8): a cobrança segue de pé.
    assert has_element?(live, "#key-request", "Replace this key.")
  end

  test "condição 4 — nenhuma parte do segredo na tela nem no log, em nenhum dos três ramos",
       ctx do
    nivel = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: nivel) end)

    {:ok, live, _} = live(ctx.conn, ~p"/ai")

    log =
      capture_log([level: :debug], fn ->
        # primeira, mesma, troca
        for chave <- [@k, @k, @j] do
          aceita()
          html = salvar(live, %{"secret" => chave, "default_model" => ""})

          for segredo <- [@k, @j] do
            refute html =~ segredo
            refute html =~ String.slice(segredo, 0, 8)
          end
        end
      end)

    for segredo <- [@k, @j] do
      refute log =~ segredo
      refute log =~ String.slice(segredo, 0, 12)
    end
  end

  test "condição 5 — a comparação não atravessa tenants", ctx do
    {tenant_b, _admin_b} = tenant_with_admin("vizinho")
    b_antes = gravada(tenant_b, @k, secret_set_at: ctx.dois_meses)
    gravada(ctx.tenant, @j, secret_set_at: ctx.quatro_meses)

    # As duas linhas existem antes de qualquer asserção.
    assert {:ok, _} = AI.fetch(tenant_b)
    assert {:ok, _} = AI.fetch(ctx.tenant)

    aceita()
    {:ok, live, _} = live(ctx.conn, ~p"/ai")
    html = salvar(live, %{"secret" => @k, "default_model" => ""})

    refute html =~ @mesma, "a chave K é a do vizinho, e não a deste tenant"
    assert html =~ "It replaces the key registered on #{data(ctx.quatro_meses)}"

    {:ok, a} = AI.fetch(ctx.tenant)
    assert a.previous_secret_set_at == ctx.quatro_meses
    refute a.secret_set_at == ctx.quatro_meses

    {:ok, b_depois} = AI.fetch(tenant_b)

    assert Map.take(b_depois, [:secret_set_at, :previous_secret_set_at, :validated_at, :secret]) ==
             Map.take(b_antes, [:secret_set_at, :previous_secret_set_at, :validated_at, :secret])
  end

  test "condição 6 — a frase só aparece quando a chave é a mesma", ctx do
    {:ok, live, _} = live(ctx.conn, ~p"/ai")

    aceita()
    primeira = salvar(live, %{"secret" => @k, "default_model" => ""})
    refute primeira =~ @mesma
    assert primeira =~ "Key checked against the provider and saved (••••3b9d)."

    {:ok, gravada} = AI.fetch(ctx.tenant)
    desde = Idade.em_uso_desde(gravada)

    aceita()
    mesma = salvar(live, %{"secret" => @k, "default_model" => ""})
    assert mesma =~ "It is the key already registered, so it still counts from #{data(desde)}."

    aceita()
    troca = salvar(live, %{"secret" => @j, "default_model" => ""})
    refute troca =~ @mesma
    assert troca =~ "It replaces the key registered on #{data(desde)}"
  end
end
