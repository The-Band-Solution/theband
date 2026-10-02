defmodule TheBand.ContadorDeConsultasUnicoTest do
  @moduledoc """
  O contador de consultas é UM — issue #978, e a #372 antes dela.

  Uma cópia local ligada à telemetria **global** conta toda consulta do BEAM na janela, inclusive
  o tick do `Oban.Stager`, e reprova por sorte com o código certo (L42). As exclusões aprendidas
  vivem em `TheBand.ContadorDeConsultas`, e só lá.

  Este teste reprova se um arquivo de teste se ligar ao evento de consulta do `Repo` fora do
  contador, a menos que esteja na lista abaixo, com a razão.

  **Lê o código sem os comentários**: um comentário que cite o evento não é uma cópia do contador
  (a lição de que guarda que lê código reprova a prosa).
  """
  use ExUnit.Case, async: true

  # Os que CAPTURAM uma consulta, e não CONTAM. Não sofrem com o tick do Oban, porque filtram.
  @capturas %{
    "test/the_band/platform/espera_paralela_test.exs" =>
      "captura o SELECT … FOR UPDATE da linha do operador (070/T024), pelo conteúdo",
    "test/the_band/tenants/resumos_para_a_plataforma_test.exs" =>
      "captura o SQL das leituras de tenants da área do operador (070/T038a), para ler as colunas",
    "test/the_band_web/plataforma/operador_nao_le_dominio_test.exs" =>
      "captura o source e o SQL das rotas do operador (070/T041), contra a lista permitida por rota",
    "test/the_band_web/plataforma/cookie_do_operador_em_dominio_test.exs" =>
      "captura o SQL das portas do domínio com o cookie do operador (070/T042), atrás de platform_",
    "test/the_band/platform/suspender_test.exs" =>
      "captura os SELECT em tenants do ato de suspender (070/T049, U1), pelo conteúdo",
    "test/the_band_web/plataforma/historico_e_ato_test.exs" =>
      "conta os SELECT em tenants de cada POST de ato (070/T056, U1 e U3), pelo conteúdo",
    "test/the_band/tenants/ultimo_admin_ativo_test.exs" =>
      "captura o SELECT … FOR UPDATE das contas admin ativas, pelo conteúdo",
    "test/the_band/tenants/auth_test.exs" =>
      "captura o SELECT … FOR UPDATE da conta no login (#1046), pelo conteúdo",
    "test/the_band/work_items/custo_da_vigente_test.exs" =>
      "captura a consulta que toca issue_promotions, pelo conteúdo",
    "test/the_band_web/api/isolamento_por_tenant_test.exs" =>
      "captura o SQL inteiro para examinar a cláusula de tenant, e já exclui o Oban",
    "test/the_band_web/live/fila_parada_test.exs" =>
      "captura só as consultas de Saude.leitura/2 em oban_jobs, que o contador único ignora de propósito"
  }

  @contador "test/support/contador_de_consultas.ex"

  defp sem_comentarios(fonte) do
    fonte
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
    |> Enum.join("\n")
  end

  test "nenhum teste se liga ao evento de consulta fora do contador único" do
    copias =
      for arquivo <- Path.wildcard("test/**/*.{ex,exs}"),
          arquivo != @contador,
          # Este arquivo contém as duas strings que procura.
          arquivo != "test/contador_de_consultas_unico_test.exs",
          not Map.has_key?(@capturas, arquivo),
          codigo = arquivo |> File.read!() |> sem_comentarios(),
          String.contains?(codigo, ":telemetry.attach"),
          String.contains?(codigo, "[:the_band, :repo, :query]"),
          do: arquivo

    assert copias == [], """
    Estes arquivos contam consultas por conta própria: #{inspect(copias)}.

    Use `TheBand.ContadorDeConsultas.contar/1`. Se o arquivo CAPTURA uma consulta específica, e
    não conta, acrescente-o a @capturas com a razão.
    """
  end

  test "as capturas permitidas ainda existem e ainda se ligam ao evento" do
    # Sem isto, a lista viraria permissão para um arquivo que não existe mais, e ninguém notaria.
    for {arquivo, _razao} <- @capturas do
      assert arquivo |> File.read!() |> sem_comentarios() =~ ":telemetry.attach", arquivo
    end
  end
end
