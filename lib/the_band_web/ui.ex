defmodule TheBandWeb.UI do
  @moduledoc """
  Os componentes que carregam a gramática do produto — evidência, lacuna e medida.

  ## Cor nunca é o único canal (WCAG 2.0, critério 1.4.1)

  A plataforma distingue **observado** de **derivado** em toda tela, e a distinção precisa
  sobreviver ao daltonismo, ao monocromático e à impressão. Aqui ela viaja em três canais
  ao mesmo tempo:

  | canal | observado | derivado | ausente |
  |---|---|---|---|
  | preenchimento | sólido | hachurado | tracejado |
  | texto | sempre presente | sempre presente | sempre presente |
  | leitor de tela | `title` na marca | idem | idem |

  Tirar a cor de qualquer uma delas não tira a informação. É o teste que a suíte faz: a
  marca renderiza a classe do padrão **e** o texto.

  ## Por que aqui, e não em `core_components`

  `core_components` é o que o Phoenix gera — botão, entrada, tabela. Isto é vocabulário do
  **produto**: uma marca de evidência não faz sentido fora de uma plataforma que distingue
  o que observou do que concluiu.

  Manter os dois separados é o princípio X aplicado a componentes: um módulo faz uma coisa.

  ## Mobile-first

  Todo componente aqui empilha por padrão e ganha colunas a partir de `sm:`. O caminho
  inverso — desenhar para a mesa e quebrar para baixo — produz a tabela de seis colunas que
  ninguém lê no telefone.
  """
  use Phoenix.Component

  alias TheBandWeb.ConceptLabel

  @doc """
  A marca de evidência: o conceito, com a origem dele legível sem cor.

  `source` é `"declared_type"`, `"title"`, `"structure"` ou `nil`. `nil` significa que a
  promoção é anterior à feature que passou a registrar proveniência — e a marca diz isso
  em vez de fingir que veio de algum lugar.
  """
  attr :concept, :string, default: nil
  attr :source, :string, default: nil
  attr :confidence, :string, default: nil
  attr :skip_reason, :string, default: nil
  attr :skip_detail, :string, default: nil
  attr :class, :string, default: nil

  def evidence(assigns) do
    assigns = assign(assigns, :shape, shape(assigns[:concept], assigns[:source]))

    ~H"""
    <span
      class={["inline-flex items-center gap-1.5 text-sm", @class]}
      title={evidence_title(@concept, @source, @confidence)}
    >
      <span
        class={[
          "size-2.5 shrink-0 rounded-[1px]",
          @shape == :solid && "evidence-solid text-success",
          @shape == :hatched && "evidence-hatched text-success",
          @shape == :dashed && "evidence-dashed text-base-content/50"
        ]}
        aria-hidden="true"
      ></span>
      <span :if={@concept}>{ConceptLabel.rotulo(@concept)}</span>
      <span :if={is_nil(@concept)} class="text-base-content/60">
        {ConceptLabel.indefinida(@skip_reason, @skip_detail)}
      </span>
      <%!-- A confiança vem por extenso, e não como número: um número seria inventado, e
            viraria meta. Só aparece quando NÃO é a mais alta — dizer "high" em toda linha
            gastaria a atenção que "low" precisa ter. --%>
      <span :if={@confidence in ["medium", "low"]} class="text-xs text-base-content/60">
        {ConceptLabel.confianca(@confidence)}
      </span>
    </span>
    """
  end

  @doc """
  Um valor ausente, **nomeado**.

  Existe porque o travessão é a mentira mais barata que uma tabela conta: ele ocupa o lugar
  de um número e não diz de quem é a ausência — da origem, ou da plataforma.
  """
  attr :reason, :string, required: true
  attr :class, :string, default: nil

  def absent(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-1.5 text-sm text-base-content/60", @class]}>
      <span class="size-2.5 shrink-0 rounded-[1px] evidence-dashed" aria-hidden="true"></span>
      {@reason}
    </span>
    """
  end

  @doc """
  Um número que decide, com o rótulo acima e a unidade legível.

  `sub` carrega a composição quando o número tem uma: "1,023 observed · 3,451 derived" dito
  embaixo do total é o que impede alguém ler 4.474 como uma coisa só.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :sub, :string, default: nil

  def metric(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5">
      <span class="text-xs uppercase tracking-wider text-base-content/60">{@label}</span>
      <span class="text-2xl font-semibold tabular">{@value}</span>
      <span :if={@sub} class="text-xs text-base-content/70">{@sub}</span>
    </div>
    """
  end

  @doc """
  Linha de rótulo e valor, empilhada no telefone e em duas colunas a partir de `sm:`.
  """
  attr :label, :string, required: true
  slot :inner_block, required: true

  def field(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5 border-b border-base-300 py-1.5 last:border-0 sm:flex-row sm:items-baseline sm:justify-between sm:gap-4">
      <dt class="text-xs uppercase tracking-wider text-base-content/60 sm:text-sm sm:normal-case sm:tracking-normal">
        {@label}
      </dt>
      <dd class="text-sm sm:text-right">{render_slot(@inner_block)}</dd>
    </div>
    """
  end

  @doc """
  Um aviso que diz **o que aconteceu** e **o que a plataforma fez a respeito**.

  `kind` decide o tom, e os três são fato sobre o dado — não erro do sistema:

    * `:gap` — lacuna de conhecimento; a plataforma não sabe;
    * `:divergence` — o rótulo e a estrutura discordam;
    * `:refused` — a plataforma recusou um vínculo, e as duas pontas continuam coletadas.

  Cada um carrega um ícone **além** da cor, porque a cor sozinha reprova em 1.4.1.
  """
  attr :kind, :atom, values: [:gap, :divergence, :refused], required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def notice(assigns) do
    ~H"""
    <div
      role="note"
      class={[
        "flex gap-3 rounded border-l-4 p-3 sm:p-4",
        @kind == :gap && "border-base-content/40 border border-dashed",
        @kind == :divergence && "border-warning bg-warning/10",
        @kind == :refused && "border-error bg-error/10"
      ]}
    >
      <span
        class={[
          "mt-0.5 size-5 shrink-0",
          @kind == :gap && "hero-question-mark-circle text-base-content/60",
          @kind == :divergence && "hero-exclamation-triangle text-warning",
          @kind == :refused && "hero-no-symbol text-error"
        ]}
        aria-hidden="true"
      ></span>
      <div class="flex flex-col gap-1">
        <strong class="text-sm font-semibold">{@title}</strong>
        <div class="text-sm text-base-content/80">{render_slot(@inner_block)}</div>
      </div>
    </div>
    """
  end

  @doc """
  O estado vazio, com a razão da ausência e o que fazer sobre ela.

  Três vazios diferentes precisam de três textos diferentes: "ainda não coletamos", "a
  coleta ocorreu e não achou nada" e "paramos de olhar" pedem ações opostas.
  """
  attr :title, :string, required: true
  slot :inner_block, required: true
  slot :action

  def empty(assigns) do
    ~H"""
    <div class="flex flex-col items-start gap-2 rounded border border-dashed border-base-300 p-4 sm:p-6">
      <strong class="text-base font-semibold">{@title}</strong>
      <p class="max-w-prose text-sm text-base-content/70">{render_slot(@inner_block)}</p>
      <div :if={@action != []} class="mt-1">{render_slot(@action)}</div>
    </div>
    """
  end

  @doc """
  Barra de progresso de uma fase, com o padrão dizendo se o número é observado ou derivado.

  `total` `nil` significa que a origem não informou o denominador — e aí a barra mostra
  **estado**, não percentual: inventar o total produziria número que parece informação.
  """
  attr :label, :string, required: true
  attr :done, :integer, default: nil
  attr :total, :integer, default: nil
  attr :state, :atom, values: [:done, :running, :pending], default: :pending
  attr :derived, :boolean, default: false

  def phase(assigns) do
    assigns = assign(assigns, :width, phase_width(assigns))

    ~H"""
    <div class="grid grid-cols-[7rem_1fr_5rem] items-center gap-2 text-xs sm:grid-cols-[10rem_1fr_7rem] sm:gap-3">
      <span class="truncate text-base-content/70">{@label}</span>
      <div
        class="h-2 overflow-hidden rounded-[1px] bg-base-300"
        role="progressbar"
        aria-label={phase_aria(@label, @done, @total, @state)}
        aria-valuenow={@done || 0}
        aria-valuemax={@total || @done || 0}
      >
        <div
          class={[
            "h-full",
            @state == :running && "motion-safe:animate-pulse",
            @derived && "bar-hatched",
            not @derived && @state != :pending && "bar-solid",
            @state == :pending && "bg-transparent"
          ]}
          style={"width: #{@width}%"}
        >
        </div>
      </div>
      <span class="text-right tabular text-base-content/70">{phase_count(@done, @total)}</span>
    </div>
    """
  end

  # ------------------------------------------------------------------- privados

  # Observado é sólido; derivado é hachurado; sem conceito é tracejado. A decisão é do
  # `source`, e não do conceito: a mesma user story pode vir das duas origens.
  defp shape(nil, _source), do: :dashed
  defp shape(_concept, "structure"), do: :hatched
  defp shape(_concept, "title"), do: :hatched
  defp shape(_concept, _declared_or_nil), do: :solid

  defp evidence_title(nil, _source, _confidence), do: "No concept assigned"

  defp evidence_title(concept, source, confidence) do
    "#{ConceptLabel.rotulo(concept)} — #{ConceptLabel.fonte(source)}#{confidence && ", #{ConceptLabel.confianca(confidence)} confidence"}"
  end

  defp phase_width(%{state: :pending}), do: 0
  defp phase_width(%{done: nil}), do: 0

  defp phase_width(%{done: done, total: total}) when is_integer(total) and total > 0,
    do: min(round(done / total * 100), 100)

  defp phase_width(_assigns), do: 100

  defp phase_count(nil, _total), do: "—"
  defp phase_count(done, nil), do: to_string(done)
  defp phase_count(done, total), do: "#{done} / #{total}"

  # O rótulo do leitor de tela diz o estado por extenso: a cor e o pulso não chegam nele.
  defp phase_aria(label, _done, _total, :pending), do: "#{label}: not started"
  defp phase_aria(label, done, nil, _state), do: "#{label}: #{done} records"
  defp phase_aria(label, done, total, _state), do: "#{label}: #{done} of #{total}"
end
