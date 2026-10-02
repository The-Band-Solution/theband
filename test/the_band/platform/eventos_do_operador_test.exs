defmodule TheBand.Platform.EventosDoOperadorTest do
  @moduledoc """
  Os eventos de acesso do operador — spec 070, T033 (FR-010, O14, A7; cenário 12 de
  `seguranca-autenticacao.md`). Chamados direto em `AccessEvents`, sem `Credentials`.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TheBand.Tenants.AccessEvents

  @op "00000000-0000-0000-0000-0000000000aa"
  @org "00000000-0000-0000-0000-0000000000bb"
  @codigo "codigo-de-definicao-de-fixture-7Q2K"

  defp linha(fun), do: capture_log(fun)

  test "cada evento sai em :warning, com o nome e o motivo" do
    casos = [
      {fn ->
         AccessEvents.ato_de_plataforma(:organizacao_suspensa, @org,
           episodio_id: "e1",
           razao: "contract_ended",
           sessoes_encerradas: 3,
           tokens_revogados: 1
         )
       end, ~r/ato de plataforma .*organizacao_suspensa.*tokens_revogados=1/},
      {fn ->
         AccessEvents.ato_de_plataforma(:organizacao_reativada, @org,
           episodio_id: "e1",
           razao: "other",
           sessoes_encerradas: 0
         )
       end, ~r/organizacao_reativada/},
      {fn -> AccessEvents.operador_concedido(@op, "quem rodou") end,
       ~r/operador concedido .*via=:release_command/},
      {fn -> AccessEvents.operador_revogado(@op, "quem rodou", 2) end,
       ~r/operador revogado .*sessoes_encerradas=2/},
      {fn -> AccessEvents.operador_credencial_reiniciada(@op, "quem rodou") end,
       ~r/credencial reiniciada/},
      {fn -> AccessEvents.operador_entrada_aceita(@op, 4) end,
       ~r/entrada aceita .*falhas_apagadas=4/},
      {fn -> AccessEvents.operador_entrada_recusada(nil, :segundo_fator_travado) end,
       ~r/entrada recusada .*motivo=:segundo_fator_travado/},
      {fn -> AccessEvents.operador_senha_definida(@op) end, ~r/senha definida/},
      {fn -> AccessEvents.operador_definicao_recusada(@op, :codigo_errado) end,
       ~r/definição recusada .*motivo=:codigo_errado/},
      {fn -> AccessEvents.operador_segundo_fator_cadastrado(@op) end,
       ~r/segundo fator cadastrado/},
      {fn -> AccessEvents.operador_cadastro_recusado(@op, :codigo_de_guarda_vencido) end,
       ~r/cadastro recusado .*codigo_de_guarda_vencido/},
      {fn -> AccessEvents.operador_recuperacao_usada(@op, 7) end,
       ~r/recuperação usada .*restantes=7/},
      {fn -> AccessEvents.operador_segundo_fator_travado(@op) end, ~r/segundo fator travado/},
      {fn -> AccessEvents.operador_espera_acionada(@op, 8) end, ~r/espera acionada .*segundos=8/},
      {fn -> AccessEvents.operador_sessao_derrubada(@op, :inativa) end,
       ~r/sessão derrubada .*motivo=:inativa/},
      {fn -> AccessEvents.operador_ato_recusado(@op, nil, :not_found) end,
       ~r/ato recusado .*tenant_id=nil .*motivo=:not_found/}
    ]

    for {fun, padrao} <- casos do
      log = linha(fun)
      assert log =~ "[warning]", "não saiu em warning: #{inspect(padrao)}"
      assert log =~ padrao
    end
  end

  test "nenhuma assinatura que recebe motivo aceita um código no lugar dele" do
    for fun <- [
          &AccessEvents.operador_entrada_recusada/2,
          &AccessEvents.operador_definicao_recusada/2,
          &AccessEvents.operador_cadastro_recusado/2,
          &AccessEvents.operador_sessao_derrubada/2
        ] do
      log =
        linha(fn ->
          assert_raise FunctionClauseError, fn -> fun.(@op, @codigo) end
        end)

      refute log =~ @codigo
    end

    log =
      linha(fn ->
        assert_raise FunctionClauseError, fn ->
          AccessEvents.operador_ato_recusado(@op, @org, @codigo)
        end
      end)

    refute log =~ @codigo
  end
end
