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
