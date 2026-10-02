defmodule TheBandWeb.Plataforma.EntradaEDefinicaoTest do
  @moduledoc """
  As telas de entrada, definição e cadastro — spec 070, T039 (FR-011, FR-016; T5, C8 e C17 de
  `seguranca-totp.md`). Pelo `Phoenix.ConnTest`, do código de definição à entrada com TOTP.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.Grants
  alias TheBand.Segredo

  @senha senha_do_operador()
  @recusa_da_entrada "Check the email, password and code, then try again in a moment."

  setup do
    email = "op-#{System.unique_integer([:positive])}@example.org"
    {:ok, {_op, _grant, definicao}} = Grants.conceder(email, "Op", "quem rodou")
    %{email: email, definicao: Segredo.expor(definicao)}
  end

  defp passo1(email, definicao, senha \\ @senha, confirmacao \\ nil) do
    post(build_conn(), ~p"/platform/setup", %{
      "email" => email,
      "setup_token" => definicao,
      "password" => senha,
      "password_confirmation" => confirmacao || senha
    })
  end

  defp segredo_da_pagina(html) do
    [segredo] = Regex.run(~r/secret=([A-Z2-7]+)/, html, capture: :all_but_first)
    segredo
  end

  defp campo_oculto(html, nome) do
    [valor] = Regex.run(~r/name="#{nome}" value="([^"]+)"/, html, capture: :all_but_first)
    valor
  end

  defp codigo(segredo, t \\ System.os_time(:second)),
    do: NimbleTOTP.verification_code(Base.decode32!(segredo, padding: false), time: t)

  defp entrar(email, segundo_fator) do
    post(build_conn(), ~p"/platform/session", %{
      "email" => email,
      "password" => @senha,
      "second_factor_token" => segundo_fator
    })
  end

  test "o fluxo inteiro: definição, cadastro, guarda dos códigos e entrada com TOTP", %{
    email: email,
    definicao: definicao
  } do
    capture_log(fn ->
      # Passo 1: a resposta traz o segredo e a URI, uma vez.
      p1 = passo1(email, definicao)
      html1 = html_response(p1, 200)
      segredo = segredo_da_pagina(html1)
      assert html1 =~ "This secret is shown once."
      # A chave na tela é a mesma da URI, em grupos de quatro.
      assert html1 =~
               segredo
               |> String.graphemes()
               |> Enum.chunk_every(4)
               |> Enum.map_join(" ", &Enum.join/1)

      assert get_resp_header(p1, "cache-control") == ["no-store"]
      refute Map.has_key?(p1.resp_cookies, "_the_band_operator")

      # Passo 2: os dez códigos, uma vez; a resposta já não traz o segredo.
      p2 =
        post(build_conn(), ~p"/platform/setup/second-factor", %{
          "email" => email,
          "enrollment_token" => campo_oculto(html1, "enrollment_token"),
          "second_factor_token" => codigo(segredo)
        })

      html2 = html_response(p2, 200)
      refute html2 =~ segredo

      codigos =
        Regex.scan(
          ~r/[a-z2-7]{4}-[a-z2-7]{4}-[a-z2-7]{4}-[a-z2-7]{4}-[a-z2-7]{4}-[a-z2-7]{4}-[a-z2-7]{2}/,
          html2
        )

      assert length(codigos) == 10

      # Antes do passo 3, a entrada é recusada, com a frase única.
      antes = entrar(email, codigo(segredo, System.os_time(:second) + 30))
      assert html_response(antes, 422) =~ @recusa_da_entrada

      # Passo 3: sem a caixa, a recusa, sem os códigos e sem consumir o passo.
      guarda = campo_oculto(html2, "acknowledgement_token")
      [[um_codigo] | _] = codigos

      sem_caixa =
        post(build_conn(), ~p"/platform/setup/recovery-codes", %{
          "email" => email,
          "acknowledgement_token" => guarda
        })

      html_sem = html_response(sem_caixa, 422)
      assert html_sem =~ "Tick the box to confirm you stored the recovery codes."
      refute html_sem =~ um_codigo
      assert campo_oculto(html_sem, "acknowledgement_token") == guarda

      # Com a caixa, o mesmo código de guarda ainda vale: a recusa da caixa não o gastou.
      p3 =
        post(build_conn(), ~p"/platform/setup/recovery-codes", %{
          "email" => email,
          "acknowledgement_token" => guarda,
          "codes_stored" => "true"
        })

      html3 = html_response(p3, 200)
      assert html3 =~ "Setup finished."
      refute html3 =~ um_codigo
      refute html3 =~ segredo

      # A entrada, com o código do passo seguinte (o do cadastro já foi gasto).
      dentro = entrar(email, codigo(segredo, System.os_time(:second) + 30))
      assert redirected_to(dentro) == ~p"/platform/organizations"
      assert %{"_the_band_operator" => _} = dentro.resp_cookies

      # Nem o segredo nem os códigos aparecem nas telas que vêm depois.
      for caminho <- [~p"/platform/sign-in", ~p"/platform/setup"] do
        html = html_response(get(build_conn(), caminho), 200)
        refute html =~ segredo
        refute html =~ um_codigo
      end
    end)
  end

  test "a recusa da entrada é uma frase só, com o mesmo status, e o e-mail fica", %{email: email} do
    {respostas, _log} =
      with_log(fn ->
        [
          entrar(email, "123456"),
          entrar("ninguem@example.org", "123456"),
          post(build_conn(), ~p"/platform/session", %{})
        ]
      end)

    assert Enum.uniq(Enum.map(respostas, & &1.status)) == [422]

    for c <- respostas,
        do: assert(c.resp_body =~ "Not signed in." and c.resp_body =~ @recusa_da_entrada)

    [primeira | _] = respostas
    assert primeira.resp_body =~ ~s(value="#{email}")
  end

  test "passo 1: código errado, senha curta e confirmação diferente têm frases próprias", %{
    email: email,
    definicao: definicao
  } do
    capture_log(fn ->
      assert html_response(passo1(email, "codigo-errado"), 422) =~
               "The email or setup code was not accepted."

      assert html_response(passo1(email, definicao, "curta", "curta"), 422) =~
               "The password needs 12 to 128 characters. Your setup code still works."

      assert html_response(passo1(email, definicao, @senha, @senha <> "x"), 422) =~
               "The two passwords do not match. Your setup code still works."

      # As duas últimas não gastaram o código: ele ainda define a senha.
      assert html_response(passo1(email, definicao), 200) =~ "This secret is shown once."
    end)
  end

  test "passo 2 recusado: a chave não aparece de novo, e o código de cadastro volta no campo", %{
    email: email,
    definicao: definicao
  } do
    capture_log(fn ->
      html1 = html_response(passo1(email, definicao), 200)
      segredo = segredo_da_pagina(html1)
      cadastro = campo_oculto(html1, "enrollment_token")

      recusa =
        post(build_conn(), ~p"/platform/setup/second-factor", %{
          "email" => email,
          "enrollment_token" => cadastro,
          "second_factor_token" => codigo(segredo, System.os_time(:second) + 600)
        })

      html = html_response(recusa, 422)
      assert html =~ "The setup key is not shown again"
      refute html =~ segredo
      assert campo_oculto(html, "enrollment_token") == cadastro
    end)
  end

  test "sair encerra a sessão no servidor e solta o cookie", %{conn: conn} do
    {op, _} = operador_pronto()

    conn = conn |> log_in_operador(op) |> delete(~p"/platform/session")
    assert redirected_to(conn) == ~p"/platform/sign-in"

    sessao = TheBand.Repo.get_by!(TheBand.Platform.OperatorSession, operator_id: op.id)
    assert sessao.ended_at

    [cookie] = get_resp_header(conn, "set-cookie")
    assert cookie =~ "_the_band_operator=;" and cookie =~ "max-age=0"
  end
end
