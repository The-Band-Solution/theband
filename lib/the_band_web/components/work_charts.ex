defmodule TheBandWeb.WorkCharts do
  @moduledoc """
  Os dois gráficos do painel da pessoa — feature 023.

  ## Por que SVG à mão, e não uma biblioteca

  São duas formas simples — barras verticais numa série, barras horizontais em faixas
  ordenadas — e nenhuma precisa de escala contínua, zoom ou eixo secundário. Uma biblioteca
  traria peso de carregamento e um vocabulário de configuração para desenhar retângulos.

  O custo está nomeado: eixos e rótulos são cálculo aqui dentro, e um terceiro gráfico com
  forma diferente pediria a decisão de novo.

  ## O que estes gráficos recusam fazer

  **Nenhuma barra é colorida por valor.** Nas faixas de idade a posição já codifica a idade,
  e uma rampa de cor por cima seria redundância — o validador de paleta chegou a reprovar a
  tentativa: chroma abaixo do piso e contraste insuficiente nos passos claros.

  **Rótulo direto só onde informa** — o máximo e o último mês. Número em toda barra vira
  ruído e o olho para de ler.

  **Mês sem fechamento aparece**, com marca na base. Omiti-lo comprimiria o tempo e faria a
  série mentir sobre o ritmo.
  """
  use Phoenix.Component

  @doc """
  Barras verticais: contagem por mês, em ordem cronológica.
  """
  attr :serie, :list, required: true, doc: "lista de %{month: \"YYYY-MM\", count: inteiro}"
  attr :rotulo, :string, default: "Issues concluídas por mês"

  def por_mes(assigns) do
    serie = assigns.serie
    max = serie |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end) |> max(1)
    largura = max(560, length(serie) * 30)
    bw = if serie == [], do: 0, else: (largura - 26) / length(serie)

    i_max =
      serie
      |> Enum.with_index()
      |> Enum.max_by(fn {d, _} -> d.count end, fn -> {nil, -1} end)
      |> elem(1)

    assigns =
      assign(assigns,
        serie: Enum.with_index(serie),
        max: max,
        largura: largura,
        bw: bw,
        i_max: i_max,
        ultimo: length(serie) - 1
      )

    ~H"""
    <div class="overflow-x-auto">
      <svg
        viewBox={"0 0 #{@largura} 168"}
        width={@largura}
        height="168"
        role="img"
        aria-label={@rotulo}
        class="block"
      >
        <line
          :for={t <- [0, div(@max, 2), @max]}
          x1="26"
          x2={@largura}
          y1={y(t, @max)}
          y2={y(t, @max)}
          class="stroke-base-300"
          stroke-width="1"
        />
        <text
          :for={t <- [0, div(@max, 2), @max]}
          x="0"
          y={y(t, @max) + 3}
          class="fill-base-content/50 tabular"
          font-size="10"
        >
          {t}
        </text>

        <g :for={{d, i} <- @serie}>
          <rect
            x={26 + i * @bw + 2}
            y={if d.count > 0, do: y(d.count, @max), else: 137}
            width={max(@bw - 4, 1)}
            height={if d.count > 0, do: max(138 - y(d.count, @max), 2), else: 1}
            rx={if d.count > 0, do: 3, else: 0}
            class="fill-primary"
            tabindex="0"
          >
            <title>{d.count} em {d.month}</title>
          </rect>
          <text
            :if={(i == @i_max or i == @ultimo) and d.count > 0}
            x={26 + i * @bw + (@bw - 4) / 2}
            y={y(d.count, @max) - 4}
            text-anchor="middle"
            class="fill-base-content/70 tabular"
            font-size="10"
            font-weight="600"
          >
            {d.count}
          </text>
          <text
            :if={rem(i, 3) == 0 or i == @ultimo}
            x={26 + i * @bw + (@bw - 4) / 2}
            y="156"
            text-anchor="middle"
            class="fill-base-content/50"
            font-size="10"
          >
            {String.slice(d.month, 2..-1//1)}
          </text>
        </g>
      </svg>
    </div>
    """
  end

  @doc """
  Duas séries por período: criadas e fechadas, barras lado a lado.

  ## Por que agrupadas, e não empilhadas

  Empilhar somaria criadas com fechadas, e a soma **não significa nada**: uma issue criada
  em janeiro e fechada em março apareceria duas vezes numa pilha que ninguém pode ler como
  total. Lado a lado, cada barra é uma contagem completa em si.

  ## Por que não há linha de saldo

  A diferença entre as duas barras de um período NÃO é o trabalho que ficou aberto: as
  issues fechadas em março não são as criadas em março. Desenhar a diferença convidaria à
  leitura errada, e o que responde "o que está parado agora" é o gráfico de faixas de idade.

  ## Legenda sempre, e cor nunca sozinha

  Duas séries exigem legenda, e as duas barras diferem também em **posição** dentro do
  grupo — quem não distingue as cores lê pela ordem, que é estável em todos os períodos.
  """
  attr :serie, :list,
    required: true,
    doc: "lista de %{periodo: texto, criadas: inteiro, fechadas: inteiro}"

  attr :rotulo, :string, default: "Criadas e fechadas por período"

  def por_periodo(assigns) do
    serie = assigns.serie

    max =
      serie
      |> Enum.flat_map(&[&1.criadas, &1.fechadas])
      |> Enum.max(fn -> 1 end)
      |> max(1)

    largura = max(560, length(serie) * 34)
    grupo = if serie == [], do: 0, else: (largura - 26) / length(serie)
    # Dois marcos por grupo, com 2px de superfície entre eles: colados, o olho lê uma barra
    # só de cor variável.
    bw = max((grupo - 6) / 2, 1)

    assigns =
      assign(assigns,
        serie: Enum.with_index(serie),
        max: max,
        largura: largura,
        grupo: grupo,
        bw: bw,
        passo: passo_do_rotulo(length(serie)),
        ultimo: length(serie) - 1
      )

    ~H"""
    <div>
      <div class="mb-1 flex flex-wrap items-center gap-4 text-xs">
        <span class="flex items-center gap-1.5">
          <%!-- "created", e NUNCA "opened": a página usa "opened by" para AUTORIA, e são
                perguntas diferentes. Medido em 2026-08-27, `fatasy` tem 8 designadas e
                233 abertas por ele — com a mesma palavra nos dois lugares, o gráfico
                parecia contradizer o número abaixo dele. --%>
          <span class="size-2.5 shrink-0 rounded-[1px] bg-primary" aria-hidden="true"></span> created
        </span>
        <span class="flex items-center gap-1.5">
          <span class="size-2.5 shrink-0 rounded-[1px] bg-secondary" aria-hidden="true"></span> closed
        </span>
      </div>

      <div class="overflow-x-auto">
        <svg
          viewBox={"0 0 #{@largura} 168"}
          width={@largura}
          height="168"
          role="img"
          aria-label={@rotulo}
          class="block"
        >
          <line
            :for={t <- [0, div(@max, 2), @max]}
            x1="26"
            x2={@largura}
            y1={y(t, @max)}
            y2={y(t, @max)}
            class="stroke-base-300"
            stroke-width="1"
          />
          <text
            :for={t <- [0, div(@max, 2), @max]}
            x="0"
            y={y(t, @max) + 3}
            class="fill-base-content/50 tabular"
            font-size="10"
          >
            {t}
          </text>

          <g :for={{d, i} <- @serie}>
            <rect
              x={26 + i * @grupo + 2}
              y={if d.criadas > 0, do: y(d.criadas, @max), else: 137}
              width={@bw}
              height={if d.criadas > 0, do: max(138 - y(d.criadas, @max), 2), else: 1}
              rx={if d.criadas > 0, do: 3, else: 0}
              class="fill-primary"
              tabindex="0"
            >
              <title>{d.criadas} created in {d.periodo}</title>
            </rect>
            <rect
              x={26 + i * @grupo + 4 + @bw}
              y={if d.fechadas > 0, do: y(d.fechadas, @max), else: 137}
              width={@bw}
              height={if d.fechadas > 0, do: max(138 - y(d.fechadas, @max), 2), else: 1}
              rx={if d.fechadas > 0, do: 3, else: 0}
              class="fill-secondary"
              tabindex="0"
            >
              <title>{d.fechadas} closed in {d.periodo}</title>
            </rect>
            <%!-- Rótulo do eixo a cada `passo`, e sempre no último: com 60 semanas, um
                  rótulo por barra vira uma faixa preta ilegível. --%>
            <text
              :if={rem(i, @passo) == 0 or i == @ultimo}
              x={26 + i * @grupo + @grupo / 2}
              y="156"
              text-anchor="middle"
              class="fill-base-content/50"
              font-size="10"
            >
              {String.slice(d.periodo, 2..-1//1)}
            </text>
          </g>
        </svg>
      </div>
    </div>
    """
  end

  @doc """
  Burn-up e burn-down juntos: escopo, feito e o que resta.

  ## Por que as três linhas, e não só a de resta

  Um burn-down sozinho esconde a causa: quando a linha de resta não desce, ela não diz se
  ninguém fechou nada ou se o escopo cresceu junto. Com as três, a resposta é visível — a
  distância entre `escopo` e `feito` **é** o que resta, e o teste é olhar qual das duas se
  moveu.

  Medido em 2026-08-27: das 63 pessoas com issue designada, **59 ainda têm trabalho
  aberto**, e para a maioria delas o escopo é o que sobe.

  ## Área entre as linhas, e não uma quarta série

  O que resta é desenhado como o preenchimento ENTRE escopo e feito, e não como uma linha
  própria: uma terceira linha convidaria a lê-la contra o eixo como se fosse independente,
  quando ela é exatamente a diferença das outras duas.
  """
  attr :serie, :list,
    required: true,
    doc: "lista de %{periodo: texto, escopo: inteiro, feito: inteiro, aberto: inteiro}"

  attr :rotulo, :string, default: "Trabalho acumulado e o que resta"

  def burn(assigns) do
    serie = assigns.serie
    max = serie |> Enum.map(& &1.escopo) |> Enum.max(fn -> 1 end) |> max(1)
    largura = max(560, length(serie) * 24)
    passo = if length(serie) <= 1, do: 0, else: (largura - 26 - 8) / (length(serie) - 1)

    pontos = fn campo ->
      serie
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {d, i} -> "#{26 + i * passo},#{y(Map.fetch!(d, campo), max)}" end)
    end

    assigns =
      assign(assigns,
        serie: Enum.with_index(serie),
        max: max,
        largura: largura,
        passo: passo,
        escopo: pontos.(:escopo),
        feito: pontos.(:feito),
        # A área entre as duas: escopo na ida, feito na volta.
        area:
          pontos.(:escopo) <>
            " " <>
            (serie
             |> Enum.with_index()
             |> Enum.reverse()
             |> Enum.map_join(" ", fn {d, i} -> "#{26 + i * passo},#{y(d.feito, max)}" end)),
        passo_rotulo: passo_do_rotulo(length(serie)),
        ultimo: length(serie) - 1
      )

    ~H"""
    <div>
      <div class="mb-1 flex flex-wrap items-center gap-4 text-xs">
        <span class="flex items-center gap-1.5">
          <span class="h-0.5 w-4 shrink-0 bg-primary" aria-hidden="true"></span> scope (created)
        </span>
        <span class="flex items-center gap-1.5">
          <span class="h-0.5 w-4 shrink-0 bg-secondary" aria-hidden="true"></span> done (closed)
        </span>
        <span class="flex items-center gap-1.5">
          <span
            class="size-2.5 shrink-0 rounded-[1px] bg-primary/20 outline outline-1 -outline-offset-1 outline-primary/40"
            aria-hidden="true"
          ></span>
          still open
        </span>
      </div>

      <div class="overflow-x-auto">
        <svg
          viewBox={"0 0 #{@largura} 168"}
          width={@largura}
          height="168"
          role="img"
          aria-label={@rotulo}
          class="block"
        >
          <line
            :for={t <- [0, div(@max, 2), @max]}
            x1="26"
            x2={@largura}
            y1={y(t, @max)}
            y2={y(t, @max)}
            class="stroke-base-300"
            stroke-width="1"
          />
          <text
            :for={t <- [0, div(@max, 2), @max]}
            x="0"
            y={y(t, @max) + 3}
            class="fill-base-content/50 tabular"
            font-size="10"
          >
            {t}
          </text>

          <polygon points={@area} class="fill-primary/20" />
          <polyline points={@escopo} fill="none" class="stroke-primary" stroke-width="2" />
          <polyline points={@feito} fill="none" class="stroke-secondary" stroke-width="2" />

          <%!-- Ponto no fim de cada linha: dá âncora ao olho e alvo ao toque. --%>
          <g :for={{d, i} <- @serie}>
            <circle
              :if={i == @ultimo}
              cx={26 + i * @passo}
              cy={y(d.escopo, @max)}
              r="3.5"
              class="fill-primary"
            />
            <circle
              :if={i == @ultimo}
              cx={26 + i * @passo}
              cy={y(d.feito, @max)}
              r="3.5"
              class="fill-secondary"
            />
            <rect
              x={26 + i * @passo - max(@passo / 2, 4)}
              y="16"
              width={max(@passo, 8)}
              height="122"
              fill="transparent"
              tabindex="0"
            >
              <title>
                {d.periodo}: {d.escopo} created, {d.feito} closed, {d.aberto} still open
              </title>
            </rect>
            <text
              :if={rem(i, @passo_rotulo) == 0 or i == @ultimo}
              x={26 + i * @passo}
              y="156"
              text-anchor="middle"
              class="fill-base-content/50"
              font-size="10"
            >
              {String.slice(d.periodo, 2..-1//1)}
            </text>
          </g>
        </svg>
      </div>
    </div>
    """
  end

  # Alvo de ~12 rótulos no eixo, qualquer que seja a escala: 2 anos, 16 meses e 60 semanas
  # não podem ter a mesma densidade de texto.
  defp passo_do_rotulo(n) when n <= 12, do: 1
  defp passo_do_rotulo(n), do: ceil(n / 12)

  @doc """
  Barras horizontais em faixas **ordenadas** — a ordem é a informação, e reordenar por valor
  a destruiria.
  """
  attr :faixas, :list, required: true, doc: "lista de %{label: texto, count: inteiro}"
  attr :rotulo, :string, default: "Idade do trabalho aberto"

  def por_faixa(assigns) do
    faixas = assigns.faixas
    max = faixas |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end) |> max(1)
    total = faixas |> Enum.map(& &1.count) |> Enum.sum()

    assigns =
      assign(assigns,
        faixas: Enum.with_index(faixas),
        max: max,
        total: total,
        altura: length(faixas) * 30 + 12,
        ultima: length(faixas) - 1
      )

    ~H"""
    <svg
      viewBox={"0 0 320 #{@altura}"}
      width="100%"
      height={@altura}
      role="img"
      aria-label={"#{@rotulo}, #{@total} no total"}
      class="block"
    >
      <g :for={{f, i} <- @faixas}>
        <text x="88" y={i * 30 + 20} text-anchor="end" class="fill-base-content/50" font-size="10">
          {f.label}
        </text>
        <%!-- A faixa mais velha é a acionável, e por isso é a única com ênfase. Não é cor
              por valor: é a posição fixa do fim da escala. --%>
        <rect
          x="96"
          y={i * 30 + 10}
          width={max(190 * f.count / @max, if(f.count > 0, do: 2, else: 0))}
          height="14"
          rx="3"
          class={if i == @ultima and f.count > 0, do: "fill-warning", else: "fill-primary"}
          tabindex="0"
        >
          <title>{f.count} de {@total} abertas há {f.label}</title>
        </rect>
        <text
          x={96 + max(190 * f.count / @max, 2) + 7}
          y={i * 30 + 21}
          class="fill-base-content/70 tabular"
          font-size="10"
          font-weight="600"
        >
          {f.count}
        </text>
      </g>
    </svg>
    """
  end

  # O topo do gráfico é 16 e a base 138; um valor de zero encosta na base.
  defp y(valor, max), do: 16 + (138 - 16) * (1 - valor / max)
end
