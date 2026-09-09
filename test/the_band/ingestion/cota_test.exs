defmodule TheBand.Ingestion.CotaTest do
  @moduledoc """
  O gestor de cotas — ADR 0007, parte 2.

  Nenhum teste aqui fala com o GitHub: o gestor não faz HTTP. O que se prova é a regra de
  concessão, o que ele acredita depois de cada leitura, e o que faz quando o reset passa.
  Cada teste usa uma identidade própria, porque o processo é nomeado pela chave e viveria
  de um teste para o outro.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ingestion.Cota

  defp chave(nome),
    do: {"https://github.com", "dono-#{nome}-#{System.unique_integer([:positive])}"}

  defp daqui_a(segundos), do: DateTime.add(DateTime.utc_now(), segundos, :second)

  describe "a regra de concessão" do
    test "sem leitura nenhuma, concede: recusar no escuro pararia a coleta sem motivo" do
      chave = chave("escuro")
      assert :ok = Cota.pedir(chave, :core)
      assert :ok = Cota.pedir(chave, :graphql)
    end

    test "concede enquanto remaining − em_voo − custo ≥ margem, e recusa a partir daí" do
      chave = chave("margem")
      margem = Cota.teto_em_voo()

      # A origem disse: sobram margem + 2. Com nada em voo, cabem exatamente duas
      # requisições antes de bater na margem.
      :ok = Cota.pedir(chave, :core)
      Cota.observar(chave, :core, %{remaining: margem + 2, reset: daqui_a(1800)})

      assert :ok = Cota.pedir(chave, :core), "sobram #{margem + 2}, nada em voo: cabe a primeira"

      assert :ok = Cota.pedir(chave, :core),
             "uma em voo: #{margem + 2} − 1 − 1 = #{margem}, cabe a segunda"

      assert {:espera, %{segundos: segundos, reset: %DateTime{}}} = Cota.pedir(chave, :core),
             """
             Duas em voo: #{margem + 2} − 2 − 1 < #{margem}. Conceder aqui é o que produzia o 403 —
             as tarefas em voo gastam o que sobrou, e a próxima requisição bate na cota.
             """

      assert segundos >= 60, "a espera carrega a folga de um minuto sobre o reset"
    end

    test "a margem é a concorrência, e não o dobro: em_voo já está na conta" do
      chave = chave("em-voo")
      margem = Cota.teto_em_voo()

      :ok = Cota.pedir(chave, :graphql)
      Cota.observar(chave, :graphql, %{remaining: margem + 1, reset: daqui_a(1800)})

      assert :ok = Cota.pedir(chave, :graphql)

      # Devolvida a que estava em voo, sem leitura nova (falha de transporte): o saldo
      # conhecido continua o mesmo, e a conta volta a caber.
      Cota.observar(chave, :graphql, nil)

      assert :ok = Cota.pedir(chave, :graphql),
             "em_voo voltou a zero; a mesma margem cabe de novo"
    end
  end

  describe "a GraphQL conta em pontos" do
    test "o custo visto na identidade entra na conta, e não o 1 que o cliente estima" do
      chave = chave("pontos")
      teto = Cota.teto_em_voo()

      :ok = Cota.pedir(chave, :graphql)
      # A consulta custou 100 pontos e sobram 150 — o caso do teste do job (FR-016).
      Cota.observar(chave, :graphql, %{remaining: 150, cost: 100, reset: daqui_a(1800)})

      assert {:espera, _} = Cota.pedir(chave, :graphql), """
      Sobram 150 pontos e cada consulta custa 100: com o teto de #{teto} em voo, a conta é
      100 × (0 + 1 + #{teto}) = #{100 * (1 + teto)} > 150. Conceder aqui é contar pontos como
      se fossem requisições — a próxima página consumiria dois terços do que resta.
      """
    end

    test "com pontos de sobra, concede" do
      chave = chave("pontos-sobrando")

      :ok = Cota.pedir(chave, :graphql)
      Cota.observar(chave, :graphql, %{remaining: 4000, cost: 100, reset: daqui_a(1800)})

      assert :ok = Cota.pedir(chave, :graphql)
    end
  end

  describe "o que ele acredita" do
    test "a verdade é a leitura, e não a contagem própria" do
      chave = chave("leitura")

      for _ <- 1..3, do: :ok = Cota.pedir(chave, :core)
      # Três em voo, e a origem diz que sobram 4 000: o gestor não tem opinião própria.
      Cota.observar(chave, :core, %{remaining: 4000, reset: daqui_a(1800), limit: 5000})

      assert %{core: %{remaining: 4000, limit: 5000, em_voo: 2}} = Cota.estado(chave), """
      O gestor deveria acreditar no cabeçalho (4 000) e ter devolvido UMA das três em voo.
      Contar sozinho erraria sempre que o dono do token usasse a cota fora do The Band.
      """
    end

    test "o MENOR remaining da mesma janela vence: respostas concorrentes chegam fora de ordem" do
      chave = chave("ordem")
      reset = daqui_a(1800)

      :ok = Cota.pedir(chave, :core)
      :ok = Cota.pedir(chave, :core)
      # A resposta que saiu depois volta primeiro, com o saldo menor...
      Cota.observar(chave, :core, %{remaining: 100, reset: reset})
      # ...e a que saiu antes volta depois, com um saldo maior que já não existe.
      Cota.observar(chave, :core, %{remaining: 101, reset: reset})

      assert %{core: %{remaining: 100}} = Cota.estado(chave), """
      O saldo só cai dentro de uma janela. Acreditar na leitura que chegou por último
      (101) faria o gestor conceder uma requisição que a origem já não tem.
      """
    end

    test "leitura de janela NOVA substitui, e não compara" do
      chave = chave("janela-nova")

      # Duas em voo ANTES da leitura baixa: depois dela nenhum pedido seria concedido, e é
      # justamente a segunda resposta — da janela nova — que precisa reabrir.
      :ok = Cota.pedir(chave, :core)
      :ok = Cota.pedir(chave, :core)
      Cota.observar(chave, :core, %{remaining: 3, reset: daqui_a(10)})
      Cota.observar(chave, :core, %{remaining: 4999, reset: daqui_a(3610)})

      assert %{core: %{remaining: 4999}} = Cota.estado(chave), """
      A janela virou: o reset é outro. Manter o mínimo (3) da janela anterior deixaria o
      gestor recusando com a cota inteira disponível.
      """
    end

    test "os dois baldes são separados: esgotar a REST não fecha a GraphQL" do
      chave = chave("baldes")

      :ok = Cota.pedir(chave, :core)
      Cota.observar(chave, :core, %{remaining: 0, reset: daqui_a(1800)})

      assert {:espera, _} = Cota.pedir(chave, :core)
      assert :ok = Cota.pedir(chave, :graphql), "a GraphQL tem saldo próprio de 5 000 pontos"
    end
  end

  describe "quando o reset passa" do
    test "o saldo volta a desconhecido e concede: a primeira resposta corrige" do
      chave = chave("reset")

      :ok = Cota.pedir(chave, :core)
      # Reset no passado: a janela em que o saldo era zero já virou.
      Cota.observar(chave, :core, %{remaining: 0, reset: daqui_a(-5)})

      assert :ok = Cota.pedir(chave, :core), """
      A janela reabriu e o gestor continuou recusando com o saldo velho. A coleta ficaria
      parada com a cota inteira disponível — até alguém reiniciar o processo.
      """
    end

    test "sem reset conhecido, a espera é o padrão de quinze minutos" do
      chave = chave("sem-reset")

      :ok = Cota.pedir(chave, :graphql)
      # A GraphQL recusa por cota sem dizer quando volta.
      Cota.observar(chave, :graphql, %{remaining: 0, reset: nil})

      assert {:espera, %{reset: nil, segundos: 900}} = Cota.pedir(chave, :graphql)
    end
  end

  describe "a identidade" do
    test "é o dono do token, e não a credencial, quando o dono é conhecido" do
      tool = %{instance_url: "https://github.com"}

      assert {"https://github.com", "paulo"} = Cota.chave(tool, %{owner_login: "paulo", id: "c1"})

      assert {"https://github.com", {:credencial, "c1"}} =
               Cota.chave(tool, %{owner_login: nil, id: "c1"}),
             "sem dono descoberto, cai para a credencial — menos correto, e declarado"
    end

    test "Verificação 2 da ADR 0007: dois tokens do mesmo dono são UM saldo" do
      dono = "mesmo-dono-#{System.unique_integer([:positive])}"
      ferramenta_a = %{instance_url: "https://github.com"}
      ferramenta_b = %{instance_url: "https://github.com"}

      chave_a = Cota.chave(ferramenta_a, %{owner_login: dono, id: "cred-a"})
      chave_b = Cota.chave(ferramenta_b, %{owner_login: dono, id: "cred-b"})

      assert chave_a == chave_b, "duas credenciais, um usuário: a origem conta num saldo só"

      :ok = Cota.pedir(chave_a, :core)
      Cota.observar(chave_a, :core, %{remaining: 3, reset: daqui_a(1800)})

      assert {:espera, _} = Cota.pedir(chave_b, :core), """
      A ferramenta B pediu e foi concedida com o saldo que a ferramenta A já viu acabar.
      Um processo por TOKEN concederia o dobro do que existe.
      """
    end

    test "quem nunca pediu não tem estado" do
      assert Cota.estado(chave("nunca")) == nil
    end

    test "o estado é publicado a cada observação, para a tela" do
      chave = chave("tela")
      :ok = Cota.subscribe(chave)

      :ok = Cota.pedir(chave, :core)
      Cota.observar(chave, :core, %{remaining: 42, reset: daqui_a(100)})

      assert_receive {:cota, ^chave, %{core: %{remaining: 42}}}, 500
    end
  end
end
