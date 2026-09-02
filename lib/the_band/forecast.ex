defmodule TheBand.Forecast do
  @moduledoc """
  Previsão de entrega por simulação sobre o histórico da própria equipe — feature 057.

  **Função pura.** Recebe a série já consultada e o número de itens em aberto; não
  toca no banco. É o que a torna testável com igualdade em vez de tolerância.

  ## Por que simulação, e não a extrapolação que a pessoa já tem

  `WorkItems.projecao/1` devolve um ponto e **recusa** quando o fechamento não
  supera a abertura — medido em 2026-08-27, 59 das 63 pessoas com trabalho aberto
  caem nessa recusa.

  Recusar é correto para um ponto. Mas a pergunta *qual a chance de terminar* tem
  resposta mesmo quando a maioria das rodadas não termina: é uma **proporção**, e
  é justamente ela que informa a decisão. Uma equipe que abre 9,5 por semana e
  fecha 7,1 não precisa trabalhar mais rápido — precisa que menos coisa entre.

  ## As duas hipóteses respondem perguntas diferentes

    * `congelado` — nada novo entra. Isola a **capacidade**: quanto tempo levaria
      para limpar o que já existe;
    * `vivo` — cada semana também sorteia uma abertura do histórico. Responde se o
      ritmo **se sustenta**.

  As duas são verdadeiras ao mesmo tempo, e a distância entre elas é o achado.

  ## Determinismo não é detalhe de implementação

  A previsão é lida numa reunião e conferida depois. Duas leituras diferentes do
  mesmo dado destroem a confiança mais rápido do que uma previsão larga — e a
  semente derivada dos dados é também o que impede refazer a simulação até sair um
  número melhor.

  ## O piso, e por que recusar é melhor que uma faixa larga

  Menos de #{6} períodos **ou** menos de #{10} fechadas devolve `{:sem_historico, _}`.
  Com três semanas e quatro fechamentos, a reamostragem cobre quase todo o
  horizonte: uma faixa de 2 a 11 semanas não informa, e rotulá-la de 85%
  empresta autoridade a ruído.
  """

  @rodadas 10_000
  @horizonte 12
  @periodos_minimos 6
  @fechadas_minimas 10

  @type hipotese :: %{
          p50: pos_integer() | nil,
          p85: pos_integer() | nil,
          p95: pos_integer() | nil,
          nao_concluiram: non_neg_integer()
        }

  @type previsao :: %{
          congelado: hipotese(),
          vivo: hipotese(),
          rodadas: pos_integer(),
          horizonte_semanas: pos_integer(),
          ritmo: %{abre_por_semana: float(), fecha_por_semana: float()}
        }

  @type faltando :: %{
          semanas: non_neg_integer(),
          semanas_exigidas: pos_integer(),
          fechadas: non_neg_integer(),
          fechadas_exigidas: pos_integer()
        }

  @doc """
  A previsão, ou a recusa explicada.

  `opts`: `:aberto` (obrigatório), `:rodadas`, `:horizonte_semanas`, `:semente`.

  Sem `:semente`, ela é derivada da entrada — a mesma série e o mesmo aberto
  produzem exatamente a mesma saída.
  """
  @spec monte_carlo([map()], keyword()) :: {:ok, previsao()} | {:sem_historico, faltando()}
  def monte_carlo(serie, opts) do
    aberto = Keyword.fetch!(opts, :aberto)
    fechadas = Enum.map(serie, & &1.fechadas)
    criadas = Enum.map(serie, & &1.criadas)
    soma_fechadas = Enum.sum(fechadas)

    if length(serie) < @periodos_minimos or soma_fechadas < @fechadas_minimas do
      {:sem_historico,
       %{
         semanas: length(serie),
         semanas_exigidas: @periodos_minimos,
         fechadas: soma_fechadas,
         fechadas_exigidas: @fechadas_minimas
       }}
    else
      simular(serie, criadas, fechadas, aberto, opts)
    end
  end

  @doc "O piso declarado, para a tela poder dizer o que falta sem duplicar o número."
  @spec piso() :: %{periodos: pos_integer(), fechadas: pos_integer()}
  def piso, do: %{periodos: @periodos_minimos, fechadas: @fechadas_minimas}

  # ------------------------------------------------------------------ privados

  defp simular(serie, criadas, fechadas, aberto, opts) do
    rodadas = Keyword.get(opts, :rodadas, @rodadas)
    horizonte = Keyword.get(opts, :horizonte_semanas, @horizonte)
    semente = Keyword.get_lazy(opts, :semente, fn -> semente_de(serie, aberto) end)
    n = length(serie)

    {:ok,
     %{
       congelado: rodar(semente, rodadas, horizonte, aberto, fechadas, nil),
       vivo: rodar(semente + 1, rodadas, horizonte, aberto, fechadas, criadas),
       rodadas: rodadas,
       horizonte_semanas: horizonte,
       ritmo: %{
         abre_por_semana: Enum.sum(criadas) / n,
         fecha_por_semana: Enum.sum(fechadas) / n
       }
     }}
  end

  # A semente roda num processo isolado por chamada, para não alterar o estado do
  # gerador do processo chamador — uma previsão não pode mudar o comportamento de
  # quem a pediu.
  defp rodar(semente, rodadas, horizonte, aberto, fechadas, criadas) do
    tarefa =
      Task.async(fn ->
        :rand.seed(:exsss, {semente, semente + 7, semente + 13})

        Enum.map(1..rodadas, fn _ ->
          uma_rodada(aberto, horizonte, fechadas, criadas)
        end)
      end)

    percentis(Task.await(tarefa, 30_000), rodadas)
  end

  defp uma_rodada(aberto, horizonte, fechadas, criadas) do
    Enum.reduce_while(1..horizonte, aberto, fn semana, resta ->
      novo = resta - sortear(fechadas) + if(criadas, do: sortear(criadas), else: 0)

      cond do
        novo <= 0 -> {:halt, semana}
        semana == horizonte -> {:halt, nil}
        true -> {:cont, max(novo, 0)}
      end
    end)
  end

  defp sortear(lista), do: Enum.at(lista, :rand.uniform(length(lista)) - 1)

  # Percentil de hipótese cujas rodadas não concluíram vem NULO, nunca um número
  # grande: nulo diz desconhecido, e um número grande diria uma data.
  defp percentis(resultados, rodadas) do
    concluidas = resultados |> Enum.reject(&is_nil/1) |> Enum.sort()

    %{
      p50: percentil(concluidas, 50, rodadas),
      p85: percentil(concluidas, 85, rodadas),
      p95: percentil(concluidas, 95, rodadas),
      nao_concluiram: rodadas - length(concluidas)
    }
  end

  # O percentil é sobre TODAS as rodadas, e não só sobre as que concluíram. Se
  # 40% não terminou, não existe p85 — o valor na posição 85% do total caiu fora
  # das concluídas, e afirmá-lo usando só as concluídas inventaria uma data.
  defp percentil(concluidas, p, rodadas) do
    posicao = ceil(p / 100 * rodadas)

    if posicao <= length(concluidas), do: Enum.at(concluidas, posicao - 1)
  end

  # Derivada dos dados de entrada: a mesma série e o mesmo aberto produzem a mesma
  # semente, e por consequência a mesma previsão.
  defp semente_de(serie, aberto) do
    :erlang.phash2({serie, aberto}, 1_000_000_007)
  end
end
