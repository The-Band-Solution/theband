defmodule TheBandWeb.IdadeDaCredencial do
  @moduledoc """
  A idade da credencial na tela que a administra — 064/T018, FR-016, FR-017 e FR-019.

  Contrato: `specs/064-segredo-em-repouso/contracts/pedido-de-troca.md`. Protótipo aprovado:
  `specs/064-segredo-em-repouso/prototipo/credential-age.html`, versão 2, 2026-10-03.

  **Exibe, e não decide.** O estado vem de `TheBand.Credenciais.Idade.estado/2`, e o prazo de
  `Idade.limite_em_meses/0` — o "3" de toda frase sai dali (F.4). Usado por `/tools` e `/ai`,
  porque a regra de formato escrita duas vezes diverge na primeira mudança, e uma das telas
  passaria a dizer `within` para o que a outra chama de `age unknown`.

  **Os três estados, um a um.** Nenhuma cláusula-coringa sobre o estado (achado 4 da avaliação
  de segurança): um `_ ->` no fim é por onde `:idade_desconhecida` vira "no prazo" sem ninguém
  notar.

  Todo texto daqui vai para a tela, e por isso é **inglês de propósito** (AGENTS.md §11.1).
  Não traduzir de volta.

  Depende de: `TheBand.Credenciais.Idade` (regra de segurança, sem ontologia).
  """
  use Phoenix.Component

  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade

  @doc """
  A marca do estado, legível sem cor: a forma **e** o texto carregam o estado (G.1, WCAG 1.4.1).

  `data-estado` leva o átomo, para quem testa não depender da frase.
  """
  attr :estado, :atom, required: true, values: [:no_prazo, :vencida, :idade_desconhecida]
  attr :meses, :integer, default: nil, doc: "meses em uso; só a marca vencida o mostra"
  attr :ativa?, :boolean, default: true

  def marca(assigns) do
    assigns = assign(assigns, limite: Idade.limite_em_meses())

    # Texto de tela: inglês de propósito.
    case assigns.estado do
      :no_prazo ->
        ~H"""
        <span
          data-estado="no_prazo"
          class="inline-flex w-fit items-center gap-1 whitespace-nowrap rounded-sm border border-current px-1.5 font-mono text-xs text-success"
        >
          within {@limite} months
        </span>
        """

      :vencida ->
        ~H"""
        <span
          data-estado="vencida"
          class="inline-flex w-fit items-center gap-1 whitespace-nowrap rounded-sm border-[3px] border-double border-current px-1.5 font-mono text-xs font-semibold text-warning"
        >
          <span aria-hidden="true" class="font-bold">!</span>
          <%= if @ativa? do %>
            replace · {plural(@meses, "month")} in use
          <% else %>
            past {@limite} months · inactive
          <% end %>
        </span>
        """

      :idade_desconhecida ->
        ~H"""
        <span
          data-estado="idade_desconhecida"
          class="inline-flex w-fit items-center gap-1 whitespace-nowrap rounded-sm border border-dashed border-current px-1.5 font-mono text-xs italic text-base-content/70"
        >
          age unknown
        </span>
        """
    end
  end

  @doc """
  A célula da idade: data, intervalo, marca e, no prazo, quando o pedido começa (F.1, F.2, F.5).

  A chave do modelo sem `secret_set_at` tem a data **inferida** de `validated_at`
  (`Idade.em_uso_desde/1`), e a célula diz isso com a marca hachurada (D7): é derivado, e não
  registrado.
  """
  attr :credencial, :any, required: true
  attr :agora, :any, required: true
  attr :ativa?, :boolean, default: true
  attr :sem_data, :string, required: true, doc: "de quem é a ausência, quando não há data"

  def idade(assigns) do
    desde = Idade.em_uso_desde(assigns.credencial)

    assigns =
      assign(assigns,
        desde: desde,
        estado: Idade.estado(assigns.credencial, assigns.agora),
        inferida?: inferida?(assigns.credencial),
        meses: desde && meses(desde, assigns.agora)
      )

    ~H"""
    <div class="flex flex-col gap-0.5" data-idade>
      <%= case @estado do %>
        <% :no_prazo -> %>
          <span class="font-mono text-xs tabular-nums">{data(@desde)}</span>
          <span class="text-sm">{intervalo(@desde, @agora)}</span>
          <.inferida :if={@inferida?} />
          <.marca estado={:no_prazo} />
          <span class="font-serif text-xs opacity-70">
            replacement asked from {data(DateTime.shift(@desde, month: Idade.limite_em_meses()))}
          </span>
        <% :vencida -> %>
          <span class="font-mono text-xs tabular-nums">{data(@desde)}</span>
          <span :if={!@ativa?} class="text-sm">{intervalo(@desde, @agora)}</span>
          <.inferida :if={@inferida?} />
          <.marca estado={:vencida} meses={@meses} ativa?={@ativa?} />
        <% :idade_desconhecida -> %>
          <.marca estado={:idade_desconhecida} />
          <span class="font-serif text-xs opacity-70">{@sem_data}</span>
      <% end %>
      <span :if={@inferida?} class="font-serif text-xs opacity-70">
        This key was saved before the platform recorded replacement dates. The date is the last
        check against the provider, which is when this key was saved.
      </span>
    </div>
    """
  end

  # A hachura é a marca de "derivado" do design system (§1): a data existe, mas foi inferida.
  defp inferida(assigns) do
    ~H"""
    <span
      data-estado="inferida"
      class="inline-flex w-fit items-center gap-1.5 whitespace-nowrap rounded-sm border border-current px-1.5 font-mono text-xs text-warning"
    >
      <span
        class="size-2.5 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
        aria-hidden="true"
      ></span>
      inferred from the last check
    </span>
    """
  end

  defp inferida?(%ProviderCredential{secret_set_at: nil, validated_at: %DateTime{}}), do: true
  defp inferida?(_credencial), do: false

  @doc """
  O aviso: o pedido de troca (`:vencida`, borda dupla e `!`) ou a idade que não se sabe
  (`:desconhecida`, tracejado e `?`). Nenhuma ação, nenhum "dismiss" (F.7, D4).
  """
  attr :forma, :atom, required: true, values: [:vencida, :desconhecida]
  attr :titulo, :string, required: true
  attr :id, :string, default: nil
  slot :inner_block, required: true
  slot :quem

  def aviso(assigns) do
    ~H"""
    <div
      id={@id}
      role="note"
      data-aviso={@forma}
      class={[
        "flex items-start gap-3 rounded-lg bg-base-100 px-3 py-2.5",
        @forma == :vencida && "border-[3px] border-double border-warning",
        @forma == :desconhecida && "border-[1.5px] border-dashed border-base-content/60"
      ]}
    >
      <span
        aria-hidden="true"
        class={[
          "inline-flex size-6 flex-none items-center justify-center rounded-full font-mono text-sm font-bold",
          @forma == :vencida && "border-[1.5px] border-warning text-warning",
          @forma == :desconhecida && "border-[1.5px] border-dashed border-base-content/60"
        ]}
      >
        {if @forma == :vencida, do: "!", else: "?"}
      </span>
      <div class="flex min-w-0 flex-col gap-1.5">
        <div class="text-sm font-semibold">{@titulo}</div>
        <div class="flex flex-col gap-1.5 font-serif text-sm leading-relaxed">
          {render_slot(@inner_block)}
        </div>
        <div :for={quem <- @quem} class="text-xs opacity-70">{render_slot(quem)}</div>
      </div>
    </div>
    """
  end

  @doc """
  `"replace"` quando alguma credencial **ativa** da lista está vencida; `nil` quando nenhuma (A.1).

  A ausência da marca é "nenhuma ativa vencida", e não "tudo no prazo": a de idade
  desconhecida não acende a marca, e não é contada como no prazo em lugar nenhum.
  """
  @spec marca_da_aba([Idade.credencial()], DateTime.t()) :: String.t() | nil
  def marca_da_aba(credenciais, agora) do
    if Enum.any?(credenciais, &(ativa?(&1) and Idade.estado(&1, agora) == :vencida)),
      # Texto de tela: inglês de propósito.
      do: "replace",
      else: nil
  end

  # A chave do modelo não tem `active`: existe, e está em uso.
  defp ativa?(%ProviderCredential{}), do: true
  defp ativa?(%{active: active}), do: active == true

  @doc """
  O intervalo desde `desde`, como a tela o diz (F.2): `today`, `N days ago` abaixo de um mês,
  `N months ago` a partir de um — meses de calendário inteiros, arredondados para baixo.
  """
  @spec intervalo(DateTime.t(), DateTime.t()) :: String.t()
  def intervalo(desde, agora) do
    # Texto de tela: inglês de propósito.
    case dias(desde, agora) do
      dias when dias <= 0 -> "today"
      _dias -> duracao(desde, agora) <> " ago"
    end
  end

  @doc """
  Quanto tempo vai de `desde` a `ate`, sem o "ago": `N days` abaixo de um mês, `N months` a
  partir de um. É o "in use for N months" da chave anterior (2.7).
  """
  @spec duracao(DateTime.t(), DateTime.t()) :: String.t()
  def duracao(desde, ate) do
    # Texto de tela: inglês de propósito.
    case meses(desde, ate) do
      0 -> plural(max(dias(desde, ate), 0), "day")
      meses -> plural(meses, "month")
    end
  end

  defp dias(desde, ate), do: Date.diff(DateTime.to_date(ate), DateTime.to_date(desde))

  @doc """
  Os meses de calendário inteiros de `desde` até `agora`, pela data. Data no futuro dá `0`.

  Pela data, e não pelo instante: é a data que a tela mostra ao lado, e o número tem de fechar
  com o calendário de quem lê.
  """
  @spec meses(DateTime.t(), DateTime.t()) :: non_neg_integer()
  def meses(desde, agora), do: contar_meses(DateTime.to_date(desde), DateTime.to_date(agora), 0)

  defp contar_meses(desde, ate, n) do
    case Date.compare(Date.shift(desde, month: n + 1), ate) do
      :gt -> n
      _menor_ou_igual -> contar_meses(desde, ate, n + 1)
    end
  end

  @doc "A data como a tela a mostra: `AAAA-MM-DD` (F.1)."
  @spec data(DateTime.t()) :: String.t()
  def data(%DateTime{} = instante), do: instante |> DateTime.to_date() |> Date.to_iso8601()

  defp plural(1, palavra), do: "1 " <> palavra
  defp plural(n, palavra), do: "#{n} #{palavra}s"
end
