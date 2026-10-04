defmodule TheBand.Telemetria.TaxonomiaTest do
  @moduledoc """
  A taxonomia da jornada, lida da base de conhecimento — spec 074, T007 (a leitura do YAML).

  O que está escrito aqui é a tabela *A régua* da spec, e não uma cópia do YAML: se o YAML
  mudar sem a spec, este teste reprova, e a diferença aparece para quem revisa.
  """
  use ExUnit.Case, async: true

  alias TheBand.Telemetria.Taxonomia

  @motivos %{
    "abrir_a_entrada" => [],
    "entrar_com_senha" => ~w(senha_errada identificador_nao_resolveu conta_sem_senha
                             conta_desativada organizacao_suspensa em_espera),
    "sair" => ~w(sessao_ja_nao_existia),
    "sessao_derrubada" => ~w(malformado inexistente resumo_errado encerrada vencida epoca_velha
                             organizacao_suspensa conta_desativada),
    "definir_a_senha" => ~w(confirmacao_diferente recusada_pela_regra fora_do_fluxo),
    "trocar_a_senha" => ~w(senha_atual_nao_confere recusada_pela_regra)
  }

  test "os seis passos da régua, e nenhum outro" do
    assert Enum.sort(Taxonomia.passos()) == Enum.sort(Map.keys(@motivos))
  end

  test "cada passo devolve exatamente os motivos da régua" do
    for {passo, motivos} <- @motivos do
      assert Enum.sort(Taxonomia.motivos(passo)) == Enum.sort(motivos), "motivos de #{passo}"
    end
  end

  test "abandonou é declarado em abrir_a_entrada, e fica FORA do que a aplicação pode emitir" do
    assert "abandonou" in Taxonomia.desfechos("abrir_a_entrada")

    for {_passo, %{desfechos: desfechos}} <- Taxonomia.regras_por_passo() do
      refute "abandonou" in desfechos
    end
  end

  test "sessao_derrubada só falha; os outros passos com motivo concluem ou falham" do
    regras = Taxonomia.regras_por_passo()
    assert regras["sessao_derrubada"].desfechos == ["falhou"]

    for passo <- ~w(entrar_com_senha sair definir_a_senha trocar_a_senha) do
      assert Enum.sort(regras[passo].desfechos) == ["concluiu", "falhou"], passo
    end
  end

  test "passo desconhecido não tem motivo nem desfecho" do
    assert Taxonomia.motivos("entrar_pelo_github") == []
    assert Taxonomia.desfechos("entrar_pelo_github") == []
  end
end
