defmodule TheBandWeb.Plataforma.OperadorNaoLeDominioTest do
  @moduledoc """
  O operador não lê domínio — spec 070, T041 (SC-003, FR-007; research R10 emendado, A9).

  Toda consulta que as rotas do operador disparam é capturada pela telemetria do `Repo`, **filtrada
  pelo processo** do teste (o tick do Oban e os outros testes ficam de fora, L42). Cada rota tem a
  sua lista permitida de tabelas; `source` nulo reprova (L56), e qualquer SQL que cite `"users"`
  reprova.
  """
  use TheBandWeb.ConnCase, async: true

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.Grants
  alias TheBand.Segredo

  @da_plataforma ~w(platform_operators platform_operator_grants platform_operator_sessions
                    platform_operator_recovery_codes tenant_suspensions tenants)

  # O controle de transação do sandbox e do `Repo.transaction/1` não tem `source`, e não lê tabela.
  @controle ~r/^(begin|commit|rollback|SAVEPOINT|RELEASE SAVEPOINT|ROLLBACK TO SAVEPOINT)/i

  defp capturar(fun) do
    ref = make_ref()
    eu = self()
    id = {__MODULE__, ref}

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql} = meta, _ ->
        if self() == eu and not Regex.match?(@controle, sql),
          do: send(eu, {ref, {meta[:source], sql}})
      end,
      nil
    )

    resultado = fun.()
    :telemetry.detach(id)
    {resultado, coletar(ref, [])}
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, c} -> coletar(ref, [c | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  # O que fica fora da lista: a tabela que não é da plataforma, o `source` nulo, o SQL que cita
  # `"users"`, e a leitura de `tenants` com coluna além das quatro da FR-007 (emenda D1).
  defp fora_da_lista(consultas) do
    Enum.reject(consultas, fn {source, sql} ->
      source in @da_plataforma and not (sql =~ ~s("users")) and
        colunas_de_tenants_ok?(source, sql)
    end)
  end

  defp colunas_de_tenants_ok?("tenants", "SELECT " <> _ = sql) do
    [colunas] = Regex.run(~r/^SELECT (.*?) FROM "tenants"/, sql, capture: :all_but_first)

    colunas |> String.split(", ") |> Enum.sort() ==
      ~w(t0."id" t0."name" t0."slug" t0."status")
  end

  defp colunas_de_tenants_ok?(_source, _sql), do: true

  defp sem_dominio!(rotulo, consultas) do
    assert consultas != [], "#{rotulo}: a captura não mediu consulta nenhuma"
    assert fora_da_lista(consultas) == [], rotulo
  end

  setup do
    a = tenant_fixture()
    tenant_fixture()
    %{a: a}
  end

  test "as rotas do operador, uma a uma, só tocam tabelas da plataforma", %{conn: conn, a: a} do
    {op, segredo} = operador_pronto()

    # O navegador com AS DUAS sessões (cenário 7 da avaliação): quem opera a plataforma e também
    # administra A. A sessão de A está no cookie, e a área do operador não pode lê-la.
    {:ok, admin} =
      TheBand.Tenants.create_user(a, %{
        "email" => "admin-#{System.unique_integer([:positive])}@example.test",
        "role" => "admin"
      })

    conn = conn |> log_in(admin) |> log_in_operador(op)

    {_, c} = capturar(fn -> get(conn, ~p"/platform/organizations") end)
    sem_dominio!("GET /platform/organizations", c)

    {_, c} =
      capturar(fn -> build_conn() |> log_in_operador(op) |> delete(~p"/platform/session") end)

    sem_dominio!("DELETE /platform/session", c)

    # A entrada: o operador e a sessão; e a recusa, que também consulta.
    capture_log(fn ->
      {_, c} =
        capturar(fn ->
          post(build_conn(), ~p"/platform/session", %{
            "email" => op.email,
            "password" => senha_do_operador(),
            "second_factor_token" => totp(segredo) |> Segredo.expor()
          })
        end)

      sem_dominio!("POST /platform/session", c)

      {_, c} =
        capturar(fn ->
          post(build_conn(), ~p"/platform/session", %{"email" => op.email, "password" => "x"})
        end)

      sem_dominio!("POST /platform/session recusado", c)
    end)
  end

  test "o cadastro inteiro, passo a passo, só toca tabelas da plataforma" do
    email = "op-#{System.unique_integer([:positive])}@example.org"

    capture_log(fn ->
      {:ok, {_, _, definicao}} = Grants.conceder(email, "Op", "quem rodou")

      {p1, c} =
        capturar(fn ->
          post(build_conn(), ~p"/platform/setup", %{
            "email" => email,
            "setup_token" => Segredo.expor(definicao),
            "password" => senha_do_operador(),
            "password_confirmation" => senha_do_operador()
          })
        end)

      sem_dominio!("POST /platform/setup", c)
      html = html_response(p1, 200)
      [chave] = Regex.run(~r/secret=([A-Z2-7]+)/, html, capture: :all_but_first)

      [cadastro] =
        Regex.run(~r/name="enrollment_token" value="([^"]+)"/, html, capture: :all_but_first)

      codigo = NimbleTOTP.verification_code(Base.decode32!(chave, padding: false))

      {p2, c} =
        capturar(fn ->
          post(build_conn(), ~p"/platform/setup/second-factor", %{
            "email" => email,
            "enrollment_token" => cadastro,
            "second_factor_token" => codigo
          })
        end)

      sem_dominio!("POST /platform/setup/second-factor", c)

      [guarda] =
        Regex.run(~r/name="acknowledgement_token" value="([^"]+)"/, html_response(p2, 200),
          capture: :all_but_first
        )

      {_, c} =
        capturar(fn ->
          post(build_conn(), ~p"/platform/setup/recovery-codes", %{
            "email" => email,
            "acknowledgement_token" => guarda,
            "codes_stored" => "true"
          })
        end)

      sem_dominio!("POST /platform/setup/recovery-codes", c)
    end)
  end

  # L50: a guarda de que mediu. Sem ela, uma captura que nunca enxergasse domínio passaria tudo.
  test "a mesma captura, num membro de A em /people, registra consultas de domínio", %{
    conn: conn,
    a: a
  } do
    {:ok, membro} =
      TheBand.Tenants.create_user(a, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {_, c} = capturar(fn -> conn |> log_in(membro) |> get(~p"/people") end)
    assert fora_da_lista(c) != []
  end
end
