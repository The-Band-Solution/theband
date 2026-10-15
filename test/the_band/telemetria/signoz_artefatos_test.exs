defmodule TheBand.Telemetria.SignozArtefatosTest do
  @moduledoc """
  O painel e o alerta da US5, versionados em `deploy/signoz/` — spec 074, T022 e T023; FR-013;
  seguranca.md, S8, S12 e S13.

  A conferência no SigNoz local (com a captura em
  `specs/074-jornada-entrar-e-sair/evidencia/`) prova que eles **funcionam**. Este teste prova que
  continuam **não vazando** quando alguém os editar:

  1. o corpo do alerta (resumo e descrição) não tem variável de modelo — `{{…}}` ou `$labels` —
     nem nome de atributo de traço que identifique alguém. Com `{{user.ref}}` na mensagem, o
     canal levaria a conta para fora do servidor (S8);
  2. nenhum quadro do painel agrupa por `user.ref` ou `journey.id`: dimensão de painel vira
     série guardada, e esses dois nunca são dimensão (S13);
  3. nenhum quadro agrupa por chave que falta em parte das linhas que ele conta, sem filtrar
     antes por ela. **Medido em 2026-10-15: agrupar por chave opcional descarta a linha que
     não a tem.** `tenant.id` sumia com a enumeração (identificador que não resolve não tem
     organização), e `failure.reason` sumia com todo sucesso;
  4. o alerta conta `identificador_nao_resolveu` **e** `limite_por_origem`. Com o limite por
     origem ligado (077), a campanha vira `limite_por_origem` depois de 10 falhas (medido: 190
     de 200), e o alerta de um motivo só ficaria cego quando o freio age.
  """
  use ExUnit.Case, async: true

  @painel "deploy/signoz/paineis/entrar-e-sair.json"
  @alerta "deploy/signoz/alertas/enumeracao.json"

  # Chaves que existem em toda linha da jornada: a enumeração da taxonomia.
  @sempre_presentes ["journey.name", "journey.step", "outcome"]
  @nunca_dimensao ["user.ref", "journey.id"]

  defp ler(caminho), do: caminho |> File.read!() |> Jason.decode!()

  defp quadros_builder do
    for w <- ler(@painel)["widgets"],
        w["query"]["queryType"] == "builder",
        q <- w["query"]["builder"]["queryData"],
        do: {w["title"], q}
  end

  defp chaves(q, campo), do: Enum.map(q[campo] || [], & &1["key"])
  defp filtradas(q), do: Enum.map(q["filters"]["items"], & &1["key"]["key"])

  test "1. o corpo do alerta não leva variável de modelo nem atributo que identifique" do
    corpo = ler(@alerta)["annotations"] |> Map.values() |> Enum.join("\n")

    refute corpo =~ ~r/\{\{|\$labels|\$value/, "o corpo do alerta tem variável de modelo"

    for nome <- @nunca_dimensao do
      refute corpo =~ "{{" <> nome, "o corpo do alerta interpola #{nome}"
    end
  end

  test "2. nenhum quadro agrupa por user.ref ou journey.id" do
    quadros = quadros_builder()
    assert length(quadros) >= 4, "a guarda leu o painel"

    for {titulo, q} <- quadros, chave <- chaves(q, "groupBy") do
      refute chave in @nunca_dimensao, "o quadro #{titulo} agrupa por #{chave}"
    end
  end

  test "3. agrupar por chave opcional só depois de filtrar por ela" do
    for {titulo, q} <- quadros_builder(),
        chave <- chaves(q, "groupBy"),
        chave not in @sempre_presentes do
      assert chave in filtradas(q), """
      O quadro "#{titulo}" agrupa por #{chave} sem filtrar por ela antes. No SigNoz, a linha que
      não tem #{chave} SOME do agrupamento, em silêncio (medido em 2026-10-15).
      """
    end
  end

  test "4. o alerta conta os dois motivos da campanha" do
    [consulta] = ler(@alerta)["condition"]["compositeQuery"]["queries"]
    filtro = consulta["spec"]["filter"]["expression"]

    assert filtro =~ "identificador_nao_resolveu"
    assert filtro =~ "limite_por_origem"
  end
end
