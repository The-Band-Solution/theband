defmodule TheBandWeb.ApiTokenLive.View do
  @moduledoc """
  O render de `/api-tokens`, separado do `Index` porque a régua do QA tem 60 itens e a tela
  ficaria ilegível com a lógica junto.

  **A gramática das marcas**: sólido é observado, hachurado é derivado, tracejado é ausente,
  e **cor nunca é canal único** — toda marca tem forma e texto (R6.2).
  """
  use TheBandWeb, :html

  @mascara String.duplicate("•", 16)

  def pagina(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
      operacao_menu={assigns[:operacao_menu]}
    >
      <.header>
        API tokens
        <:subtitle>
          A token <strong>carries no permission of its own</strong>. What it reaches is read from
          the owner account <strong>on every call</strong> — so it shrinks when that person leaves
          a team, without anyone touching the token.
        </:subtitle>
      </.header>

      <div :if={@erro} class="alert alert-error mt-4" role="alert">{@erro}</div>

      <.valor_em_claro :if={@valor_em_claro} {assigns} />
      <.linha_quieta :if={is_nil(@valor_em_claro) and @rotulo_criado} {assigns} />

      <.novo_token {assigns} />
      <.lista {assigns} />
      <.confirmacao :if={@confirmando} {assigns} />
      <.recusas />
    </Layouts.app>
    """
  end

  # ─────────────────────────────────────────────── o valor, mostrado uma vez

  defp valor_em_claro(assigns) do
    ~H"""
    <section class="card mt-4 border-2 border-primary bg-base-100 p-4" id="valor-do-token">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-lg font-semibold">Token created · {@rotulo_criado}</h3>
        <span class="badge badge-primary badge-sm">shown only now</span>
      </div>

      <p class="mt-3 break-all rounded border border-base-300 bg-base-200 p-3 font-mono text-sm">
        {@valor_em_claro}
      </p>

      <div class="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          class="btn btn-sm btn-primary"
          phx-click={
            JS.dispatch("the_band:copy", to: "#valor-do-token", detail: %{text: @valor_em_claro})
          }
        >
          Copy value
        </button>
        <button type="button" class="btn btn-sm btn-ghost" phx-click="dispensar_valor">
          I have stored it
        </button>
      </div>

      <div class="mt-4 grid gap-3 sm:grid-cols-2">
        <div class="rounded border border-base-300 p-3">
          <p class="text-xs font-semibold uppercase tracking-wide">do this now</p>
          <p class="mt-1 text-sm">
            Store it in a <strong>secret manager</strong> or in the deploy environment of whatever
            will call the API. Hand it over the channel you would use for a password — never in a
            ticket, a chat message or a commit.
          </p>
        </div>
        <div class="rounded border border-warning p-3">
          <p class="text-xs font-semibold uppercase tracking-wide">it will not come back</p>
          <p class="mt-1 text-sm">
            Leaving this screen erases the value. The platform kept a <strong>hash</strong>
            and the last four characters — nothing that returns it. There is
            <strong>no screen, no export, no endpoint and no support request</strong>
            that recovers it. The way back is to revoke this token and create another.
          </p>
        </div>
      </div>

      <div class="mt-4">
        <p class="text-xs font-semibold uppercase tracking-wide">the three parts</p>
        <div class="mt-2 grid gap-2 sm:grid-cols-3">
          <div class="rounded border border-base-300 p-2">
            <p class="font-mono text-xs">tb_api_</p>
            <p class="mt-1 text-xs text-base-content/70">
              public prefix — lets secret scanners recognise a leak without knowing the value
            </p>
          </div>
          <div class="rounded border border-base-300 p-2">
            <p class="font-mono text-xs">public id</p>
            <p class="mt-1 text-xs text-base-content/70">
              indexed — how the row is found, so the hash is never compared by the database
            </p>
          </div>
          <div class="rounded border border-base-300 p-2">
            <p class="font-mono text-xs">secret</p>
            <p class="mt-1 text-xs text-base-content/70">
              32 bytes — compared in memory, in constant time
            </p>
          </div>
        </div>
      </div>

      <div class="mt-4">
        <p class="text-xs font-semibold uppercase tracking-wide">calling with it</p>
        <pre class="mt-1 overflow-x-auto rounded bg-base-300 p-3 font-mono text-xs"><code>curl -H "Authorization: Bearer $TB_API_TOKEN" \
    https://app.theband.dev/api/v1/teams</code></pre>
        <p class="mt-1 text-xs text-base-content/70">
          From an environment variable, never inline. The token is
          <strong>only read from the <code>Authorization</code> header</strong>
          — a query string lands in proxy logs and in browser history.
        </p>
      </div>
    </section>
    """
  end

  # A linha quieta que substitui o painel — R3.9. A tela não volta em branco, e não finge
  # que o valor está em algum lugar.
  defp linha_quieta(assigns) do
    ~H"""
    <p class="mt-4 rounded border border-dashed border-base-300 p-3 text-sm text-base-content/70">
      <strong>{@rotulo_criado}</strong>
      was created {distancia(@criado_em)}. The value was shown once and
      <strong>cannot be shown again</strong>
      — the platform never stored it. If it was lost, revoke this token and create another.
    </p>
    """
  end

  # ────────────────────────────────────────────────────── o formulário

  defp novo_token(assigns) do
    ~H"""
    <section class="card mt-6 bg-base-200 p-4">
      <h3 class="text-base font-semibold">New token</h3>

      <form phx-submit="criar" class="mt-3 grid gap-3 sm:grid-cols-3" id="novo-token">
        <label class="form-control">
          <span class="label-text text-xs">Label · required</span>
          <input
            type="text"
            name="label"
            id="novo-token-label"
            required
            placeholder="e.g. director dashboard"
            class="input input-sm input-bordered"
          />
        </label>

        <label class="form-control">
          <span class="label-text text-xs">Owner account</span>
          <select
            name="user_id"
            id="novo-token-dono"
            class="select select-sm select-bordered"
            phx-change="escolher_dono"
          >
            <option :for={c <- @contas} value={c.id} selected={c.id == @dono_id}>{c.email}</option>
          </select>
        </label>

        <label class="form-control">
          <span class="label-text text-xs">Expires in</span>
          <select
            name="expires_in_days"
            id="novo-token-prazo"
            class="select select-sm select-bordered"
          >
            <option :for={{dias, texto} <- @prazos} value={dias || ""}>{texto}</option>
          </select>
        </label>

        <div class="sm:col-span-3">
          <.alcance_previsto alcance={@alcance_previsto} />
        </div>

        <p class="text-xs text-base-content/70 sm:col-span-3">
          The platform stores the label, a <strong>hash</strong>
          of the token, its last four characters, who created it, when, and when it expires. It <strong>does not store the value</strong>.
        </p>

        <div class="sm:col-span-3">
          <button type="submit" class="btn btn-sm btn-primary">Create token</button>
        </div>
      </form>

      <div class="mt-3 rounded border border-dashed border-warning p-3">
        <p class="text-xs font-semibold">
          &ldquo;No expiration&rdquo; is offered, and it is a choice with a cost
        </p>
        <p class="mt-1 text-xs text-base-content/70">
          {@prazo_maximo} days is the suggested term (<code>api.access.token_lifetime</code>);
          choosing <em>no expiration</em> is explicit, never the easy default.
        </p>
        <p class="mt-2 text-xs text-base-content/70">
          A token with no end <strong>leaves circulation only by deliberate revocation</strong>.
          No job ends it, and nothing announces that it exists — this screen is the only surface.
          Two things limit the damage, and both still hold: the reach is the <strong>owner account&rsquo;s</strong>, read again on every call, and a disabled account
          has every call refused.
        </p>
        <p class="mt-2 font-mono text-[0.6875rem] text-base-content/60">
          reverted on 23 Sep 2026 · the rule previously read &ldquo;a maximum you can opt out of is not a maximum&rdquo;
        </p>
      </div>
    </section>
    """
  end

  defp alcance_previsto(%{alcance: nil} = assigns) do
    ~H"""
    <p class="text-sm"><.absent reason="no account selected — nothing to preview" /></p>
    """
  end

  defp alcance_previsto(assigns) do
    ~H"""
    <div class="rounded border border-base-300 bg-base-100 p-3">
      <p class="text-xs font-semibold uppercase tracking-wide">
        what this token will see today
        <span class="ml-1 font-normal normal-case text-base-content/60">· derived</span>
      </p>
      <.duas_origens alcance={@alcance} />
      <p class="mt-2 text-xs text-base-content/70">
        This is <strong>today's reach of the account</strong>, not of the token. If that person
        leaves a team, the token returns <strong>less</strong>
        on the next call. If the account is disabled, <strong>every call is refused</strong>.
      </p>
    </div>
    """
  end

  # As duas origens, SEPARADAS e nunca somadas — R2.4.
  defp duas_origens(assigns) do
    ~H"""
    <div class="mt-1 space-y-1 text-sm">
      <p :if={@alcance.sem_pessoa?}>
        <.absent reason="sees nothing today — no person declared for this account" />
        <span class="ml-1 text-xs text-base-content/70">
          A call with this token is <strong>accepted</strong>
          and returns an <strong>empty collection</strong>.
        </span>
      </p>
      <p :if={@alcance.sem_pessoa? and @alcance.admin?} class="text-xs text-base-content/70">
        <strong>Administering is not seeing.</strong>
        The admin role opens management, never visibility.
      </p>
      <p :if={not @alcance.sem_pessoa?}>
        <span class="font-mono text-xs opacity-60">derived</span>
        {Enum.join(@alcance.derivados, " · ")}
      </p>
      <p :if={not @alcance.sem_pessoa?}>
        <span class="font-mono text-xs opacity-60">granted</span>
        <span :if={@alcance.concedidos != []}>{Enum.join(@alcance.concedidos, " · ")}</span>
        <.absent :if={@alcance.concedidos == []} reason="no granted scope" />
      </p>
    </div>
    """
  end

  # ───────────────────────────────────────────────────────────── a lista

  defp lista(assigns) do
    ~H"""
    <section class="mt-6">
      <div class="flex flex-wrap items-baseline gap-3">
        <h3 class="text-base font-semibold">Tokens</h3>
        <span class="font-mono text-xs tabular-nums opacity-70">
          all {@contagens.todos} · active {@contagens.ativos} · expired {@contagens.expirados} · revoked {@contagens.revogados}
        </span>
      </div>
      <p class="mt-1 text-xs text-base-content/70">
        <strong>These counts do not add up to a whole.</strong>
        {@contagens.recusados} of the active ones {if @contagens.recusados == 1, do: "is", else: "are"} refused today
        because the owner account is disabled. Revoked and expired are <strong>never hidden</strong>.
      </p>

      <div :if={@linhas == []} class="card mt-3 bg-base-200 p-4">
        <.absent reason="No token created yet — the API answers nobody until one exists." />
      </div>

      <table :if={@linhas != []} class="table table-sm stacked mt-3">
        <thead>
          <tr>
            <th>label</th>
            <th>token</th>
            <th>owner account · what it sees today</th>
            <th>created</th>
            <th>last used</th>
            <th>expires</th>
            <th>state</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={l <- @linhas}>
            <td data-label="label">{l.token.label}</td>
            <td data-label="token" class="font-mono text-xs whitespace-nowrap">
              {mascara(l.token)}
            </td>
            <td data-label="owner account">
              <p class="text-sm">{l.dono && l.dono.email}</p>
              <.duas_origens :if={l.alcance} alcance={l.alcance} />
            </td>
            <td data-label="created" class="text-xs tabular-nums">
              {instante(l.token.inserted_at)}
              <span class="block opacity-70">by {l.criador && l.criador.email}</span>
            </td>
            <td data-label="last used" class="text-xs tabular-nums">
              <.absent :if={is_nil(l.token.last_used_at)} reason="never used" />
              <span :if={l.token.last_used_at}>
                <span class="mr-1 inline-block size-2.5 rounded-[1px] bg-current align-middle opacity-60"></span>
                {instante(l.token.last_used_at)}
              </span>
            </td>
            <td data-label="expires" class="text-xs tabular-nums">
              <.absent :if={is_nil(l.token.expires_at)} reason="no expiration" />
              <span
                :if={l.token.expires_at}
                class={vence_logo?(l.token, @aviso_dias) && "text-warning"}
              >
                {instante(l.token.expires_at)}
                <span class="block">{distancia(l.token.expires_at)}</span>
              </span>
            </td>
            <td data-label="state" class="text-xs">
              <.estado linha={l} />
            </td>
            <td data-label="">
              <button
                :if={l.estado == :ativo}
                type="button"
                class="btn btn-xs btn-ghost"
                phx-click="confirmar_revogacao"
                phx-value-id={l.token.id}
              >
                Revoke
              </button>
              <span :if={l.estado == :revogado} class="text-xs opacity-60">no way back</span>
              <span :if={l.estado == :expirado} class="text-xs opacity-60">expired — create another</span>
              <button
                type="button"
                class="btn btn-xs btn-ghost"
                phx-click="abrir_uso"
                phx-value-id={l.token.id}
              >
                Usage
              </button>
            </td>
          </tr>
        </tbody>
      </table>

      <div class="mt-3 rounded border border-success p-3">
        <p class="text-xs font-semibold">the gap this list used to declare, and no longer has</p>
        <p class="mt-1 text-xs text-base-content/70">
          <strong>Until 23 Sep 2026 this said: what each integration read is not recorded.</strong>
          It is now — one row per accepted call, with the credential, the route, the target and
          the instant. The <em>body</em>
          of the response is not kept: the record says who read what, never what was read.
        </p>
        <p class="mt-2 text-xs text-base-content/70">
          The row opens a <strong>usage panel</strong>
          instead of a ninth column. And the record is kept <strong>indefinitely</strong>
          (<code>api.access.access_log_retention</code>): nothing prunes it, so it can
          reconstruct, with no time limit, that one person consulted another person&rsquo;s panel.
        </p>
      </div>

      <.painel_de_uso :if={@uso_de} {assigns} />
    </section>
    """
  end

  # ─────────────────────────────────────────────── o painel de uso

  # **Abre na linha, e não é nona coluna** — R2.20. As oito da R2.1 são a régua do QA, e o uso
  # é coisa que alguém abre para investigar, não para varrer entre seis linhas.
  defp painel_de_uso(assigns) do
    ~H"""
    <div class="mt-4 rounded border-2 border-base-300 bg-base-100 p-4">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h4 class="text-sm font-semibold">
          {@uso_de.token.label} · what it read
        </h4>
        <button type="button" class="btn btn-xs btn-ghost" phx-click="fechar_uso">Close</button>
      </div>

      <div class="mt-2 flex flex-wrap items-baseline gap-2">
        <div class="join">
          <button
            :for={{segundos, texto} <- @janelas_de_uso}
            type="button"
            class={["btn btn-xs join-item", segundos == @uso_janela && "btn-active"]}
            phx-click="janela_do_uso"
            phx-value-janela={segundos}
          >
            {texto}
          </button>
        </div>
        <span class="text-xs text-base-content/70">
          The window is <strong>chosen and shown</strong>. A count without a window is a number
          without a denominator.
        </span>
      </div>

      <p :if={@uso == []} class="mt-3 text-sm">
        <.absent reason="no accepted call in the chosen window — this is not zero calls ever" />
      </p>

      <table :if={@uso != []} class="mt-3 w-full text-sm">
        <thead>
          <tr class="text-left text-xs uppercase tracking-wide">
            <th scope="col">route</th>
            <th scope="col">reads</th>
            <th scope="col">last one</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={u <- @uso} class="border-t border-base-200">
            <td data-label="route"><code class="text-xs">{u.route}</code></td>
            <td data-label="reads" class="tabular-nums">{u.reads}</td>
            <td data-label="last one" class="text-xs">
              {instante(u.last_one)}
              <span class="ml-1 opacity-60">· observed</span>
            </td>
          </tr>
        </tbody>
      </table>

      <p :if={@uso != []} class="mt-2 text-xs text-base-content/70">
        <strong>By route, never one total.</strong>
        A single number says nothing; the split says where the integration actually goes — and an
        anomaly on one route is a different fact from volume spread across all of them.
      </p>

      <div class="mt-3 rounded border border-dashed border-base-300 p-3">
        <p class="text-xs font-semibold">what this panel does not show, and why</p>
        <p class="mt-1 text-xs text-base-content/70">
          <strong>Not what was read.</strong>
          The record keeps the route and the target, never the body of the response — keeping it
          would make a second copy of the data, with the same sensitivity and without the verdict
          in front of it.
        </p>
        <p class="mt-1 text-xs text-base-content/70">
          <strong>Not a refused call.</strong>
          Refusals are already in the internal log, with the reason. This panel is about access
          that was <em>granted</em>, which is what left no trace at all before.
        </p>
      </div>

      <div class="mt-2 rounded border border-warning p-3">
        <p class="text-xs font-semibold">why this panel exists</p>
        <p class="mt-1 text-xs text-base-content/70">
          Four calls that each respect the verdict can, together, answer a question none of them
          would answer alone. <strong>The verdict cannot see accumulation; this panel can.</strong>
        </p>
      </div>

      <div class="mt-2 rounded border border-error p-3">
        <p class="text-xs font-semibold">and this panel is itself a record about people</p>
        <p class="mt-1 text-xs text-base-content/70">
          It shows that <strong>one person&rsquo;s credential read another person&rsquo;s panel</strong>,
          when, and how often. The record is kept <strong>indefinitely</strong>
          — decided 23 Sep 2026. Who may open this panel is the same door as the rest of this
          screen: <code>require_admin</code>.
        </p>
      </div>
    </div>
    """
  end

  # `active` e `expired` são DERIVADOS — hachura. `revoked` é DECLARADO — sólido, com autor
  # e instante. R2.13 e R2.14.
  defp estado(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5">
      <span
        class={[
          "size-2.5 shrink-0 rounded-[1px]",
          @linha.estado == :revogado && "bg-current",
          @linha.estado != :revogado &&
            "bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
        ]}
        aria-hidden="true"
      ></span>
      {@linha.estado}
      <span :if={@linha.estado != :revogado} class="opacity-60">· derived from the clock</span>
    </span>
    <span :if={@linha.estado == :revogado} class="mt-0.5 block opacity-70">
      declared {instante(@linha.token.revoked_at)} by {@linha.revogador && @linha.revogador.email}
    </span>
    <span :if={@linha.estado == :revogado} class="block text-[11px] opacity-70">
      <strong :if={@linha.clausula}>{@linha.clausula}</strong>
      <span :if={@linha.clausula && @linha.token.revocation_note}>
        — “{@linha.token.revocation_note}”
      </span>
      <.absent
        :if={is_nil(@linha.clausula)}
        reason="no reason recorded · revoked before 23 Sep 2026"
      />
    </span>
    <span :if={@linha.recusado_por_conta?} class="mt-1 flex items-center gap-1.5 text-warning">
      <span class="size-2.5 shrink-0 rounded-[1px] border border-current" aria-hidden="true"></span>
      calls refused · owner account disabled
    </span>
    <span :if={@linha.recusado_por_conta?} class="block text-[11px] opacity-70">
      Two statements, and one does not summarise the other: the token is fine, the account is not.
    </span>
    """
  end

  # ─────────────────────────────────────────────────── a confirmação

  defp confirmacao(assigns) do
    ~H"""
    <div class="card mt-6 border-2 border-warning bg-base-100 p-4" role="alertdialog">
      <h3 class="text-lg font-semibold">Revoke “{@confirmando.token.label}”?</h3>

      <p class="mt-1 font-mono text-xs">
        {mascara(@confirmando.token)} · {@confirmando.dono && @confirmando.dono.email} · created {instante(
          @confirmando.token.inserted_at
        )}
      </p>

      <p class="mt-2 text-sm">
        <span :if={@confirmando.token.last_used_at}>
          Last accepted call {distancia(@confirmando.token.last_used_at)} — <strong>something is calling with it</strong>.
        </span>
        <.absent :if={is_nil(@confirmando.token.last_used_at)} reason="never used" />
      </p>

      <div class="mt-3 grid gap-3 sm:grid-cols-3">
        <div class="rounded border border-base-300 p-3">
          <p class="text-xs font-semibold uppercase tracking-wide">what it does</p>
          <p class="mt-1 text-xs">
            The next call is refused <strong>immediately</strong>
            — no cache, no delay. The row <strong>stays</strong>
            in this list, marked, with the instant and who revoked it.
          </p>
        </div>
        <div class="rounded border border-base-300 p-3">
          <p class="text-xs font-semibold uppercase tracking-wide">what it does not do</p>
          <p class="mt-1 text-xs">
            It deletes nothing. It does not affect other tokens of the same account. It <strong>cannot be undone</strong>: there is no reactivate, and the way forward is to
            create another.
          </p>
        </div>
        <div class="rounded border border-base-300 p-3">
          <p class="text-xs font-semibold uppercase tracking-wide">what the client sees</p>
          <p class="mt-1 text-xs">
            The same <code>401</code>
            a token that never existed would get. The real reason stays in the internal log,
            findable by the request id.
          </p>
        </div>
      </div>

      <form phx-submit="revogar" class="mt-3 border-t border-dashed border-base-300 pt-3">
        <input type="hidden" name="token_id" value={@confirmando.token.id} />

        <div class="grid gap-3 sm:grid-cols-3">
          <label class="form-control">
            <span class="label-text text-xs">Why — the clause</span>
            <select
              name="revocation_clause"
              id="revogacao-clausula"
              class="select select-sm select-bordered"
              required
            >
              <option :for={{id, texto} <- @clausulas} value={id}>{texto}</option>
            </select>
          </label>

          <label class="form-control sm:col-span-2">
            <span class="label-text text-xs">Note — optional, in your own words</span>
            <input
              type="text"
              name="revocation_note"
              id="revogacao-nota"
              maxlength="500"
              class="input input-sm input-bordered"
            />
          </label>
        </div>

        <p class="mt-2 text-xs text-base-content/70">
          <strong>The clause that earns this field is <em>suspected leak</em></strong>
          — it is the one case where the next act changes: rotate everything that account reaches,
          not just replace the integration. The list is closed so the answer to
          <em>&ldquo;how many revocations were suspected leaks this quarter?&rdquo;</em>
          is a count and not a reading of free text.
        </p>
        <p class="mt-1 text-xs text-base-content/70">
          Until 23 Sep 2026 revocation recorded only <em>who</em>
          and <em>when</em>
          — and that was an <strong>omission, not a decision</strong>: nobody
          had been asked.
        </p>

        <div class="mt-3 flex flex-wrap gap-2">
          <button type="submit" class="btn btn-sm btn-warning">
            Revoke “{@confirmando.token.label}”
          </button>
          <button type="button" class="btn btn-sm btn-ghost" phx-click="cancelar">Cancel</button>
        </div>
      </form>
    </div>
    """
  end

  # ────────────────────────────────────────────── o que a tela recusa

  defp recusas(assigns) do
    ~H"""
    <section class="mt-8 border-t border-base-300 pt-4">
      <h3 class="text-base font-semibold">What this screen refuses, and why</h3>
      <dl class="mt-3 grid gap-3 sm:grid-cols-2">
        <div>
          <dt class="text-sm font-medium">“Let me generate my own token.”</dt>
          <dd class="text-xs text-base-content/70">
            <strong>Only administration generates.</strong>
            Self-service is a later decision, not a missing button.
          </dd>
        </div>
        <div>
          <dt class="text-sm font-medium">“Let me rename it or extend the expiry.”</dt>
          <dd class="text-xs text-base-content/70">
            Extending a live token grants access without issuing a credential. Create another
            and revoke this one.
          </dd>
        </div>
        <div>
          <dt class="text-sm font-medium">
            “Show me what this integration read.”
            <span class="ml-1 text-xs font-normal opacity-70">· now answered</span>
          </dt>
          <dd class="text-xs text-base-content/70">
            This card used to be a refusal — it said <em>only when, never what</em>. That stopped
            being true on <strong>23 Sep 2026</strong>: every accepted call is now recorded —
            which credential, which route, which target, when. Open <strong>Usage</strong>
            on the row. The body of the response is <em>not</em>
            recorded: the log says who read what, never what was read.
          </dd>
        </div>
        <div>
          <dt class="text-sm font-medium">“Reactivate the one I revoked by mistake.”</dt>
          <dd class="text-xs text-base-content/70">
            Revocation is final. A reactivate button would turn it into a pause, and whoever
            revokes on suspicion of a leak does not want a pause.
          </dd>
        </div>
        <div>
          <dt class="text-sm font-medium">“Give this token its own permissions.”</dt>
          <dd class="text-xs text-base-content/70">
            Access is granted <strong>to the account</strong>, in
            <.link navigate={~p"/access-scopes"} class="link">Access scopes</.link>
            . Scope inside the token would be a second truth, and it <strong>ages in the pocket of whoever left</strong>.
          </dd>
        </div>
        <div>
          <dt class="text-sm font-medium">“Let me see the value again.”</dt>
          <dd class="text-xs text-base-content/70">
            The guard is a <strong>one-way hash</strong>, not an encrypted copy — <strong>because the platform never needs the value back</strong>. It only checks
            what arrives.
          </dd>
        </div>
      </dl>
    </section>
    """
  end

  # ─────────────────────────────────────────────────────── auxiliares

  # DEZESSEIS bullets de largura fixa, mais os quatro últimos — R2.2. O `masked/1` da casa
  # usa quatro e varia com o comprimento; reusá-lo revelaria o tamanho do valor.
  defp mascara(token), do: @mascara <> token.last_four

  # Uma cláusula só: o template já só chama isto com expiração presente, e uma segunda
  # cláusula para o nulo nunca seria alcançada.
  defp vence_logo?(%{expires_at: %DateTime{} = expira}, dias) when is_integer(dias) do
    falta = DateTime.diff(expira, DateTime.utc_now(), :day)
    falta >= 0 and falta <= dias
  end

  defp vence_logo?(_token, _dias), do: false

  defp instante(nil), do: nil
  defp instante(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp distancia(nil), do: nil

  defp distancia(dt) do
    segundos = DateTime.diff(dt, DateTime.utc_now(), :second)
    dias = div(abs(segundos), 86_400)

    cond do
      segundos > 0 and dias == 0 -> "in less than a day"
      segundos > 0 -> "in #{dias} #{plural(dias)}"
      dias == 0 -> "less than a day ago"
      true -> "#{dias} #{plural(dias)} ago"
    end
  end

  defp plural(1), do: "day"
  defp plural(_), do: "days"
end
