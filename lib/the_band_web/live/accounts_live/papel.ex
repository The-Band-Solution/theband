defmodule TheBandWeb.AccountsLive.Papel do
  @moduledoc """
  A marca de administrador na tela de contas — spec 072, T011, exatamente como
  `specs/072-papel-de-administrador/prototipo/accounts-admin-role.html` (aprovado em 2026-10-03).

  Depende de: nenhuma ontologia. Lê `TheBand.Tenants.AccountRole` (a base) para os rótulos e as
  frases que são afirmação da plataforma.

  Componentes e frases, e nenhum evento: os atos ficam em `TheBandWeb.AccountsLive.Index`, que é
  quem tem o socket. Separado porque a tela de contas já fazia o ciclo de vida da conta, e o papel
  é o outro fato da linha (D1: "two columns for two facts").

  ## Duas divergências do protótipo, e a razão de cada uma

  - **Sem episódio, a célula diz só "no role change recorded".** O protótipo escreve "since the
    organisation was created" na primeira conta e "never an administrator" no membro. As duas são
    afirmações sobre o tempo antes do registro, que começa com a 072, e a Q6 aprovada (nenhuma
    entrada fabricada) as recusa: uma conta promovida antes da 072 diria o falso.
  - **Frases sem pronome.** O protótipo escreve "her" e "his". A tela não sabe o pronome de
    ninguém, e usa o nome ou a forma neutra.

  A tela fala inglês, e as frases nascem aqui em inglês de propósito: não traduza de volta.
  """
  use Phoenix.Component
  use Gettext, backend: TheBandWeb.Gettext

  import TheBandWeb.UI, only: [absent: 1]

  alias TheBand.Tenants.AccountRole
  alias TheBand.Tenants.User

  # ── as frases ──

  @doc "O nome que a tela mostra de uma conta."
  @spec nome(User.t() | nil) :: String.t()
  def nome(nil), do: "an account no longer listed"
  def nome(%{name: nome}) when is_binary(nome) and nome != "", do: nome
  def nome(%{email: email}), do: email

  @doc "A frase do sucesso, no lugar do painel (item 17)."
  @spec sucesso(:promover | :rebaixar, User.t(), DateTime.t()) :: String.t()
  def sucesso(:promover, user, quando),
    do:
      dgettext("sistema", "%{nome} is now an administrator. Recorded at %{quando}, by you.",
        nome: nome(user),
        quando: data_e_hora(quando)
      )

  def sucesso(:rebaixar, user, quando),
    do:
      dgettext(
        "sistema",
        "%{nome} is no longer an administrator, and keeps signing in as a member. Recorded at %{quando}, by you.",
        nome: nome(user),
        quando: data_e_hora(quando)
      )

  @doc "A frase de quem deixou o próprio papel, já em `/people` (item 31)."
  @spec deixou(String.t(), DateTime.t(), User.t() | nil) :: String.t()
  def deixou(organizacao, quando, quem_devolve) do
    base =
      dgettext("sistema", "You stepped down as administrator of %{org}. Recorded at %{quando}.",
        org: organizacao,
        quando: data_e_hora(quando)
      )

    case quem_devolve do
      nil -> base
      u -> base <> " " <> dgettext("sistema", "%{nome} can give the role back.", nome: nome(u))
    end
  end

  @doc "A recusa do e-mail digitado errado (item 25)."
  @spec email_errado() :: String.t()
  def email_errado,
    do:
      dgettext(
        "errors",
        "Not changed. That is not the e-mail of your account. You are still an administrator."
      )

  @doc """
  A recusa do último administrador (itens 27 e 28). Nomeia quem agiu antes, quando há mudança
  registrada, e diz que o papel de quem tentou não mudou.
  """
  @spec ultimo_admin(map() | nil, String.t()) :: String.t()
  def ultimo_admin(antes, de_quem) do
    [
      dgettext("errors", "Not changed: the organisation would have no active administrator."),
      antes && quem_agiu(antes),
      de_quem
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp quem_agiu(%{to_role: "member"} = ep),
    do:
      dgettext("errors", "%{autor} removed the administrator role from %{conta} at %{hora}.",
        autor: nome(ep.changed_by_user),
        conta: nome(ep.user),
        hora: hora(ep.inserted_at)
      )

  defp quem_agiu(ep),
    do:
      dgettext("errors", "%{autor} made %{conta} administrator at %{hora}.",
        autor: nome(ep.changed_by_user),
        conta: nome(ep.user),
        hora: hora(ep.inserted_at)
      )

  @doc "A recusa de quem chegou atrasado (item 29). O episódio vem do contexto, ou é `nil`."
  @spec ja_mudou(User.t(), String.t(), map() | nil, %{optional(Ecto.UUID.t()) => String.t()}) ::
          String.t()
  def ja_mudou(user, "admin", ep, autores) do
    frase =
      dgettext("errors", "Not changed: %{nome} is already an administrator.", nome: nome(user))

    if ep,
      do:
        frase <>
          " " <>
          dgettext("errors", "%{autor} made the change at %{hora}.",
            autor: autores[ep.changed_by_user_id] || nome(nil),
            hora: hora(ep.inserted_at)
          ),
      else: frase
  end

  def ja_mudou(user, "member", ep, autores) do
    frase = dgettext("errors", "Not changed: %{nome} is already a member.", nome: nome(user))

    if ep,
      do:
        frase <>
          " " <>
          dgettext("errors", "%{autor} removed the role at %{hora}.",
            autor: autores[ep.changed_by_user_id] || nome(nil),
            hora: hora(ep.inserted_at)
          ),
      else: frase
  end

  @doc "A recusa de promover conta desativada."
  @spec conta_desativada(User.t()) :: String.t()
  def conta_desativada(user),
    do:
      dgettext(
        "errors",
        "Not changed: %{nome}'s account is disabled. Role changes wait for reactivation.",
        nome: nome(user)
      )

  # ── a contagem e o bloco do cabeçalho (itens 1 e 2) ──

  @doc "Quantos administradores ativos a organização tem."
  @spec admins_ativos([User.t()]) :: non_neg_integer()
  def admins_ativos(users), do: Enum.count(users, &(User.admin?(&1) and User.ativa?(&1)))

  @doc false
  def quem_administra(assigns) do
    ~H"""
    <div class="rounded border border-info/40 bg-base-200 p-4">
      <h2 class="text-sm font-semibold">Who administers this organisation</h2>
      <p class="mt-1 max-w-3xl font-serif text-sm opacity-80">
        An administrator connects tools, manages their credentials, runs syncs, and creates, disables
        and reactivates accounts on this screen, including making someone else an administrator or
        removing the role.
        <strong>The organisation always keeps at least one active administrator:</strong>
        the last one cannot step down or be disabled until someone else is made administrator.
      </p>
    </div>
    """
  end

  # ── a célula Management (itens 4, 5, 6 e 26) ──

  attr :user, User, required: true
  attr :current_user, User, required: true
  attr :resumo, :map, default: nil
  attr :autores, :map, required: true
  attr :admins_ativos, :integer, required: true

  @doc false
  def celula(assigns) do
    assigns =
      assign(assigns,
        eu?: assigns.user.id == assigns.current_user.id,
        unico?:
          User.admin?(assigns.user) and User.ativa?(assigns.user) and assigns.admins_ativos <= 1
      )

    ~H"""
    <div class="flex flex-col items-end gap-1 sm:items-start">
      <%= if User.admin?(@user) do %>
        <span class="badge badge-info badge-sm font-mono">{AccountRole.rotulo("admin")}</span>
      <% else %>
        <span class="font-mono text-xs">{AccountRole.rotulo("member")}</span>
      <% end %>

      <p class="text-xs opacity-70">
        <.linha_do_papel user={@user} resumo={@resumo} autores={@autores} />
        <span :if={User.admin?(@user) and not User.ativa?(@user)}>
          · <strong>not counted while the account is disabled</strong>
        </span>
        <span :if={@unico?}>· <strong>the only active administrator</strong></span>
      </p>

      <%= cond do %>
        <% not User.ativa?(@user) -> %>
          <p class="text-xs opacity-70">Role changes wait for reactivation.</p>
        <% @unico? -> %>
          <span
            class="btn btn-outline btn-dash btn-xs pointer-events-none"
            aria-disabled="true"
          >
            {if @eu?, do: "Step down…", else: "Remove admin role…"}
          </span>
          <p class="max-w-xs text-[11px] opacity-70">
            The organisation would have no active administrator. Make someone else administrator first.
          </p>
        <% User.admin?(@user) -> %>
          <button
            phx-click="abrir_papel"
            phx-value-id={@user.id}
            phx-value-acao={if @eu?, do: "deixar", else: "rebaixar"}
            class="btn btn-ghost btn-xs text-error"
          >
            {if @eu?, do: "Step down…", else: "Remove admin role…"}
          </button>
        <% true -> %>
          <button
            phx-click="abrir_papel"
            phx-value-id={@user.id}
            phx-value-acao="promover"
            class="btn btn-ghost btn-xs text-info"
          >
            Make administrator…
          </button>
      <% end %>
    </div>
    """
  end

  attr :user, User, required: true
  attr :resumo, :map, default: nil
  attr :autores, :map, required: true

  defp linha_do_papel(assigns) do
    ~H"""
    <%= case {User.admin?(@user), @resumo} do %>
      <% {true, %{ate_admin: %{} = ep}} -> %>
        since {data_curta(ep.inserted_at)} · by {@autores[ep.changed_by_user_id] || nome(nil)}
      <% {false, %{ate_membro: %{} = saida} = r} -> %>
        {periodo(r[:ate_admin], saida)} · {if saida.changed_by_user_id == @user.id,
          do: "stepped down",
          else: "removed by #{@autores[saida.changed_by_user_id] || nome(nil)}"}
      <% _ -> %>
        <.absent
          reason={AccountRole.frase_sem_registro() || "no role change recorded"}
          class="text-xs"
        />
    <% end %>
    """
  end

  # O período de administrador que terminou. Sem a promoção registrada (anterior à 072), só o fim.
  defp periodo(%{inserted_at: de}, %{inserted_at: ate}) when de < ate,
    do: "administrator #{data_curta(de)} – #{data_curta(ate)}"

  defp periodo(_entrada, %{inserted_at: ate}), do: "administrator until #{data_curta(ate)}"

  # ── o painel (itens 10 a 16, 18 a 24) ──

  attr :papel, :map, required: true
  attr :user, User, required: true
  attr :tenant, :map, required: true
  attr :outros_admins, :list, required: true

  @doc false
  def painel(assigns) do
    ~H"""
    <form
      id="painel-do-papel"
      phx-submit="confirmar_papel"
      phx-change="mudar_papel"
      class={[
        "card max-w-3xl gap-3 bg-base-200 p-5",
        @papel.acao == "promover" && "border border-info/50",
        @papel.acao != "promover" && "border border-error/40"
      ]}
    >
      <p class="font-mono text-xs uppercase tracking-wide opacity-60">
        {case @papel.acao do
          "promover" -> "Make an account administrator"
          "rebaixar" -> "Remove an administrator role"
          "deixar" -> "Step down as administrator"
        end}
      </p>
      <p class="text-sm font-semibold">
        <%= case @papel.acao do %>
          <% "promover" -> %>
            Make {nome(@user)} administrator
            <span class="font-mono font-normal opacity-60">— {@user.email}</span>
          <% "rebaixar" -> %>
            Remove the administrator role from {nome(@user)}
            <span class="font-mono font-normal opacity-60">— {@user.email}</span>
          <% "deixar" -> %>
            Step down as administrator of {@tenant.name}
            <span class="font-mono font-normal opacity-60">— your account, {@user.email}</span>
        <% end %>
      </p>

      <p class="flex items-center gap-2">
        <%= if @papel.acao == "promover" do %>
          <span class="font-mono text-xs">member</span>
          <span aria-hidden="true">→</span>
          <span class="badge badge-info badge-sm font-mono">administrator</span>
        <% else %>
          <span class="badge badge-info badge-sm font-mono">administrator</span>
          <span aria-hidden="true">→</span>
          <span class="font-mono text-xs">member</span>
        <% end %>
      </p>

      <div class="rounded border border-base-300 p-3 text-sm">
        <p class="font-mono text-[11px] uppercase tracking-wide opacity-60">
          what happens when you confirm
        </p>
        <ul class="ml-4 list-disc space-y-1">
          <%= case @papel.acao do %>
            <% "promover" -> %>
              <li>
                {nome(@user)} can connect and disconnect tools, manage their credentials, run
                syncs, and manage the accounts on this screen. That includes removing
                <strong>your</strong>
                administrator role.
              </li>
              <li>It takes effect at their next action. They do not need to sign in again.</li>
              <li>
                The change is recorded with <strong>your name, this instant</strong>
                and the note below, under “Administrator changes”.
              </li>
            <% "rebaixar" -> %>
              <li>
                {nome(@user)} stops managing tools, credentials, syncs and accounts. A screen
                they have open stops acting as administrator <strong>at their next action</strong>, without waiting for them to reconnect.
              </li>
              <li>{quantos_ficam(@outros_admins)}</li>
              <li>
                The change is recorded with <strong>your name, this instant</strong>
                and the note below.
              </li>
            <% "deixar" -> %>
              <li>
                You stop managing tools, credentials, syncs and accounts, and this screen closes
                for you at once.
              </li>
              <li>
                <strong>You cannot give the role back yourself.</strong> {quem_pode_devolver(
                  @outros_admins
                )}
              </li>
              <li>The change is recorded with your name, this instant and the note below.</li>
          <% end %>
        </ul>
        <p class="mt-2 font-mono text-[11px] uppercase tracking-wide opacity-60">
          what it does not do
        </p>
        <ul class="ml-4 list-disc space-y-1 opacity-80">
          <%= case @papel.acao do %>
            <% "promover" -> %>
              <li>Their password, their GitHub link and their open sessions do not change.</li>
              <li>
                Their teams, their work and every measure about them do not change. This is
                about what they can manage, not about what they did.
              </li>
            <% "rebaixar" -> %>
              <li>
                <strong>It does not remove access.</strong>
                {nome(@user)} keeps signing in, as a member. If they left the organisation,
                disabling the account is the act.
              </li>
              <li>
                Their sessions, password and GitHub link do not change. Nothing they did is erased.
              </li>
            <% "deixar" -> %>
              <li>You keep signing in, as a member. Your sessions and password do not change.</li>
          <% end %>
        </ul>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-[13px] font-semibold">
          Note
          <span class="font-normal opacity-60">— optional · kept on the record, not written to the log</span>
        </span>
        <textarea name="note" class="textarea textarea-bordered" rows="2">{@papel.note}</textarea>
      </label>

      <label :if={@papel.acao == "deixar"} class="flex flex-col gap-1">
        <span class="text-[13px] font-semibold">
          Type your e-mail to confirm
          <span class="font-mono font-normal opacity-60">— {@user.email}</span>
        </span>
        <input
          type="email"
          name="email"
          value={@papel.email}
          autocomplete="off"
          class="input input-bordered font-mono"
        />
      </label>

      <div class="flex flex-wrap gap-2">
        <button
          type="submit"
          class={[
            "btn btn-sm",
            @papel.acao == "promover" && "btn-info",
            @papel.acao != "promover" && "btn-error"
          ]}
        >
          <%= case @papel.acao do %>
            <% "promover" -> %>
              Make {nome(@user)} administrator
            <% "rebaixar" -> %>
              Remove {nome(@user)}'s administrator role
            <% "deixar" -> %>
              Step down as administrator
          <% end %>
        </button>
        <button type="button" phx-click="fechar_papel" class="btn btn-ghost btn-sm">Cancel</button>
      </div>
    </form>
    """
  end

  defp quantos_ficam([unico]),
    do: "The organisation keeps 1 active administrator: #{nome(unico)}."

  defp quantos_ficam(outros),
    do:
      "The organisation keeps #{length(outros)} active administrators: #{Enum.map_join(outros, ", ", &nome/1)}."

  defp quem_pode_devolver([unico]), do: "#{nome(unico)}, the administrator who remains, can."

  defp quem_pode_devolver(outros),
    do: "#{Enum.map_join(outros, ", ", &nome/1)}, the administrators who remain, can."

  # ── os avisos (itens 17, 25, 27, 29) ──

  attr :aviso, :string, default: nil
  attr :recusa, :string, default: nil

  @doc false
  def avisos(assigns) do
    ~H"""
    <div :if={@aviso} role="status" class="alert alert-success max-w-3xl text-sm">
      <span aria-hidden="true">✓</span>
      <span>{@aviso}</span>
    </div>
    <%!-- Hachurado, a marca da recusa da casa: lê em escala de cinza, e o texto diz o resto. --%>
    <div
      :if={@recusa}
      role="alert"
      class="alert max-w-3xl border border-error text-sm bg-[repeating-linear-gradient(135deg,color-mix(in_oklab,var(--color-error)_12%,transparent)_0_6px,transparent_6px_12px)]"
    >
      <span aria-hidden="true">!</span>
      <span>{@recusa}</span>
    </div>
    """
  end

  # ── a legenda (item 7) ──

  @doc false
  def legenda(assigns) do
    ~H"""
    <div class="flex gap-2">
      <dt class="shrink-0">
        <span class="badge badge-info badge-sm font-mono">{AccountRole.rotulo("admin")}</span>
      </dt>
      <dd class="opacity-70">
        declared by the administration, blue and filled like everything the administration declares.
      </dd>
    </div>
    <div class="flex gap-2">
      <dt class="shrink-0 font-mono">{AccountRole.rotulo("member")}</dt>
      <dd class="opacity-70">plain words: a member has a role, and nothing is missing there.</dd>
    </div>
    <div class="flex gap-2">
      <dt class="shrink-0">
        <span class="btn btn-outline btn-dash btn-xs pointer-events-none">Step down…</span>
      </dt>
      <dd class="opacity-70">
        the last active administrator cannot step down or be removed — make someone else
        administrator first.
      </dd>
    </div>
    """
  end

  # ── o registro das mudanças (itens 8 e 9) ──

  attr :mudancas, :map, required: true

  @doc false
  def mudancas(assigns) do
    assigns =
      assign(assigns, :antigas, assigns.mudancas.total - length(assigns.mudancas.mudancas))

    ~H"""
    <section id="mudancas-de-papel" class="space-y-2">
      <div>
        <h2 class="text-sm font-semibold">Administrator changes</h2>
        <p class="font-mono text-xs opacity-60">
          every time someone was made administrator or had the role removed · newest first · nothing here is deleted
        </p>
      </div>

      <%= if @mudancas.mudancas == [] do %>
        <.absent reason={AccountRole.frase_sem_registro() || "no role change recorded"} />
      <% else %>
        <ul
          aria-label="Administrator changes"
          class="divide-y divide-base-300 rounded border border-base-300"
        >
          <li
            :for={ep <- @mudancas.mudancas}
            class="flex flex-col gap-1 p-3 text-sm sm:flex-row sm:gap-4"
          >
            <span class="shrink-0 font-mono text-xs tabular-nums opacity-70">
              {data_e_hora(ep.inserted_at)}
            </span>
            <div>
              <%= if ep.to_role == "admin" do %>
                <strong>{nome(ep.changed_by_user)}</strong>
                made <strong>{nome(ep.user)}</strong>
                administrator ·
                <span class="font-mono text-xs">{AccountRole.rotulo(ep.from_role)} → {AccountRole.rotulo(
                  ep.to_role
                )}</span>
              <% else %>
                <strong>{nome(ep.changed_by_user)}</strong>
                removed the administrator role from <strong>{nome(ep.user)}</strong>
                ·
                <span class="font-mono text-xs">{AccountRole.rotulo(ep.from_role)} → {AccountRole.rotulo(
                  ep.to_role
                )}</span>
              <% end %>
              <br />
              <q :if={ep.note} class="font-serif">{ep.note}</q>
              <em :if={is_nil(ep.note)} class="opacity-60">no note</em>
            </div>
          </li>
        </ul>
        <p :if={@antigas > 0} class="font-mono text-xs opacity-60">
          {@antigas} earlier {if @antigas == 1, do: "change", else: "changes"}, all kept
        </p>
      <% end %>

      <p class="max-w-3xl font-serif text-sm opacity-70">
        An account that was an administrator before this record began has no entry here, and its
        row says so instead of inventing one: the first account of an organisation is created
        administrator, and that is not a role change. Disabling and reactivating are not role changes
        either; they stay in each row's access history.
      </p>
    </section>
    """
  end

  defp data_curta(%DateTime{} = d), do: Calendar.strftime(d, "%d %b")
  defp data_e_hora(%DateTime{} = d), do: Calendar.strftime(d, "%d %b %H:%M")
  defp hora(%DateTime{} = d), do: Calendar.strftime(d, "%H:%M")
end
