defmodule TheBandWeb.Plataforma.TelasHTML do
  @moduledoc """
  As telas da área do operador — spec 070, T039. Exatamente as do protótipo aprovado em 2026-10-01
  (`specs/070-operador-da-plataforma/prototipo/platform-operator.html`, telas 1 a 3).

  Depende de: nenhuma ontologia.

  **A interface fala inglês** (AGENTS.md §11.1): toda frase daqui vai para a tela, e não deve ser
  traduzida de volta. As frases são as do protótipo; mudar uma é voltar ao protótipo.

  **Sem script**: a CSP de `/platform` é `script-src 'self'` sem `'unsafe-inline'`, e nenhuma destas
  telas precisa de um. Toda recusa é a página re-renderizada pelo controller.
  """
  use TheBandWeb, :html

  attr :operador, :any, default: nil, doc: "o `%Operator{}` da sessão, nas telas de quem entrou"
  attr :largura, :string, default: "max-w-md"
  slot :inner_block, required: true

  # A moldura comum: a faixa do produto e a coluna do conteúdo. Não usa `Layouts.app`, que
  # depende de `current_tenant` e `current_user`, e o operador não tem nenhum dos dois.
  defp moldura(assigns) do
    ~H"""
    <main class={["mx-auto flex min-h-screen flex-col gap-5 px-4 py-10 sm:py-16", @largura]}>
      <div class="flex flex-col gap-1 sm:flex-row sm:items-baseline sm:justify-between">
        <div class="flex items-baseline gap-2">
          <span class="font-semibold">The Band</span>
          <span class="text-sm opacity-60">platform operation</span>
        </div>
        <div :if={@operador} class="flex flex-wrap items-baseline gap-2 text-sm">
          <span>{@operador.name}</span>
          <span class="opacity-60 break-all">· {@operador.email}</span>
          <form action={~p"/platform/session"} method="post" class="inline">
            <input type="hidden" name="_method" value="delete" />
            <.csrf />
            <button type="submit" class="link">Sign out</button>
          </form>
        </div>
      </div>
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :titulo, :string, required: true
  slot :inner_block, required: true

  defp recusa(assigns) do
    ~H"""
    <p role="alert" class="alert alert-error text-sm">
      <span><b>{@titulo}</b> {render_slot(@inner_block)}</span>
    </p>
    """
  end

  attr :titulo, :string, required: true
  slot :inner_block, required: true

  # "Shown once" vem ANTES do segredo e dos códigos (D2 do protótipo): quem lê depois já copiou.
  defp uma_vez(assigns) do
    ~H"""
    <div class="alert alert-warning text-sm">
      <span class="font-mono">1×</span>
      <span><b>{@titulo}</b> {render_slot(@inner_block)}</span>
    </div>
    """
  end

  attr :passo, :string, required: true
  slot :inner_block, required: true

  defp passo(assigns) do
    ~H"""
    <p><b>{@passo}</b> {render_slot(@inner_block)}</p>
    """
  end

  attr :name, :string, required: true
  attr :value, :string, required: true

  defp oculto(assigns) do
    ~H"""
    <input type="hidden" name={@name} value={@value} />
    """
  end

  defp csrf(assigns) do
    ~H"""
    <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
    """
  end

  attr :rotulo, :string, required: true
  attr :dica, :string, default: nil
  slot :inner_block, required: true

  defp campo(assigns) do
    ~H"""
    <label class="flex flex-col gap-1.5">
      <span class="text-[13px] font-semibold opacity-70">
        {@rotulo} <span :if={@dica} class="font-normal opacity-70">{@dica}</span>
      </span>
      {render_slot(@inner_block)}
    </label>
    """
  end

  # ----------------------------------------------------------------- tela 1 · entrada

  @doc "Tela 1: a entrada, com senha e código num formulário só."
  def entrada(assigns) do
    ~H"""
    <.moldura>
      <%!-- D1: uma frase para todo motivo, nenhum campo marcado. Marcar um diria qual estava
            certo; "in a moment" cobre a espera sem ser uma segunda mensagem (A3). --%>
      <.recusa :if={@recusada} titulo="Not signed in.">
        Check the email, password and code, then try again in a moment.
      </.recusa>

      <form action={~p"/platform/session"} method="post" class="flex flex-col gap-4">
        <.csrf />
        <.campo rotulo="Email">
          <input
            type="email"
            name="email"
            value={@email}
            autocomplete="username"
            class="input input-bordered w-full"
          />
        </.campo>
        <.campo rotulo="Password">
          <input
            type="password"
            name="password"
            autocomplete="current-password"
            class="input input-bordered w-full"
          />
        </.campo>
        <.campo rotulo="Authenticator code" dica="or a recovery code">
          <input
            type="text"
            name="second_factor_token"
            inputmode="text"
            autocomplete="one-time-code"
            placeholder="6 digits, or xxxx-xxxx-xxxx-xxxx"
            class="input input-bordered w-full font-mono"
          />
        </.campo>
        <button type="submit" class="btn btn-primary">Sign in</button>
      </form>

      <p class="text-sm opacity-70">
        Lost the password or the authenticator? Ask whoever runs the server for a new setup code.
        There is no reset by e-mail.
      </p>
    </.moldura>
    """
  end

  # ------------------------------------------------------- tela 2 · definição da senha

  @doc "Tela 2: definir a senha com o código de definição."
  def definicao(assigns) do
    ~H"""
    <.moldura>
      <.recusa :if={@recusa == :codigo} titulo="Password not set.">
        The email or setup code was not accepted. A setup code works once and lasts 30 minutes; if
        it has expired, ask for a new one.
      </.recusa>
      <.recusa :if={@recusa == :senha} titulo="Password not set.">
        The password needs 12 to 128 characters. Your setup code still works.
      </.recusa>
      <%!-- Fora do protótipo: ele não desenhou a confirmação diferente da senha. Conferida no
            controller, ANTES do contexto, então o código de definição não é gasto. --%>
      <.recusa :if={@recusa == :confirmacao} titulo="Password not set.">
        The two passwords do not match. Your setup code still works.
      </.recusa>

      <.passo passo="Step 1 of 3.">
        Set your password. Step 2 adds your authenticator, and step 3 asks you to store the
        recovery codes. You cannot sign in until all three are done.
      </.passo>

      <form action={~p"/platform/setup"} method="post" class="flex flex-col gap-4">
        <.csrf />
        <.campo rotulo="Email">
          <input
            type="email"
            name="email"
            value={@email}
            autocomplete="username"
            class="input input-bordered w-full"
          />
        </.campo>
        <.campo rotulo="Setup code" dica="from the release command, valid 30 minutes">
          <input
            type="text"
            name="setup_token"
            autocomplete="off"
            spellcheck="false"
            class="input input-bordered w-full font-mono"
          />
        </.campo>
        <.campo rotulo="New password" dica="12 to 128 characters">
          <input
            type="password"
            name="password"
            autocomplete="new-password"
            class="input input-bordered w-full"
          />
        </.campo>
        <.campo rotulo="Repeat the new password">
          <input
            type="password"
            name="password_confirmation"
            autocomplete="new-password"
            class="input input-bordered w-full"
          />
        </.campo>
        <button type="submit" class="btn btn-primary">Set password and continue</button>
      </form>

      <p class="text-sm opacity-70">
        Setting the password signs out every open operator session and replaces any authenticator
        enrolled before.
      </p>
    </.moldura>
    """
  end

  # ------------------------------------------------- tela 3 · cadastro do autenticador

  @doc """
  Tela 3, o segundo passo: o segredo e a URI, **só na resposta do `POST` que os produziu** (T5).
  Sem `@segredo`, é a recusa do código, que não mostra a chave de novo.
  """
  def cadastro(assigns) do
    ~H"""
    <.moldura>
      <%= if @segredo do %>
        <.passo passo="Step 2 of 3.">
          Password set. Now add The Band to your authenticator app.
        </.passo>
        <.uma_vez titulo="This secret is shown once.">
          It is not shown again after this page, even if the code below is refused. If you leave
          before confirming, ask for a new setup code. This step expires at <span class="font-mono">{hora(@expira_em)}</span>, ten minutes after the password was set.
        </.uma_vez>
        <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
          <dt class="opacity-60">issuer</dt>
          <dd>The Band Platform</dd>
          <dt class="opacity-60">account</dt>
          <dd class="break-all">{@email}</dd>
          <dt class="opacity-60">type</dt>
          <dd>time-based, 6 digits, every 30 seconds</dd>
        </dl>
        <div class="flex flex-col gap-1.5">
          <span class="text-[13px] font-semibold opacity-70">
            Setup key <span class="font-normal opacity-70">type it into the app</span>
          </span>
          <div class="font-mono text-lg break-all" aria-label="setup key">
            {em_grupos(@segredo)}
          </div>
        </div>
        <div class="flex flex-col gap-1.5">
          <span class="text-[13px] font-semibold opacity-70">
            Or copy the address <span class="font-normal opacity-70">some apps accept it whole</span>
          </span>
          <div class="font-mono text-xs break-all">{TheBand.Segredo.expor(@uri)}</div>
        </div>
      <% else %>
        <.recusa titulo="Authenticator not confirmed.">
          The code was not accepted. Wait for the next code and try again; if the app's clock is
          off, codes will keep failing. The setup key is not shown again: if it never reached your
          app, ask for a new setup code.
        </.recusa>
      <% end %>

      <form action={~p"/platform/setup/second-factor"} method="post" class="flex flex-col gap-4">
        <.csrf />
        <.oculto name="email" value={@email} />
        <.oculto name="enrollment_token" value={TheBand.Segredo.expor(@enrollment_token)} />
        <.campo rotulo="Code from the app">
          <input
            type="text"
            name="second_factor_token"
            inputmode="numeric"
            autocomplete="one-time-code"
            placeholder="6 digits"
            class="input input-bordered w-full font-mono"
          />
        </.campo>
        <button type="submit" class="btn btn-primary">Confirm authenticator</button>
      </form>
    </.moldura>
    """
  end

  @doc """
  Tela 3, o terceiro passo: os dez códigos de recuperação, **só na resposta do `POST` que os
  produziu** (T5). Sem `@codigos`, é a recusa da caixa, que não os mostra de novo.
  """
  def codigos(assigns) do
    ~H"""
    <.moldura>
      <%= if @codigos do %>
        <.passo passo="Step 3 of 3.">Code accepted. Store your recovery codes to finish.</.passo>
        <.uma_vez titulo="Store these ten recovery codes now. They are shown once and never again.">
          Each one replaces the authenticator code for one sign-in, then stops working. The platform
          keeps only a fingerprint of each, so nobody can show them to you later. Lose both the app
          and the codes, and the way back is a new setup code from whoever runs the server.
        </.uma_vez>
        <ol class="grid grid-cols-1 gap-1 font-mono sm:grid-cols-2" aria-label="recovery codes">
          <li :for={{codigo, n} <- Enum.with_index(@codigos, 1)}>
            <span class="opacity-50">{n}</span> {TheBand.Segredo.expor(codigo)}
          </li>
        </ol>
      <% else %>
        <.recusa titulo="Setup not finished.">
          Tick the box to confirm you stored the recovery codes. The codes are not shown again: if
          you did not store them, ask whoever runs the server for a new setup code. Nothing changed.
        </.recusa>
      <% end %>

      <form action={~p"/platform/setup/recovery-codes"} method="post" class="flex flex-col gap-4">
        <.csrf />
        <.oculto name="email" value={@email} />
        <.oculto name="acknowledgement_token" value={TheBand.Segredo.expor(@acknowledgement_token)} />
        <label class="flex items-start gap-3">
          <input type="checkbox" name="codes_stored" value="true" required class="checkbox mt-1" />
          <span class="flex flex-col gap-1">
            <span>I stored these ten recovery codes somewhere other than this page.</span>
            <span :if={@codigos} class="text-sm opacity-70">
              Until you finish, neither your authenticator nor these codes can be used to sign in.
              This step expires at <span class="font-mono">{hora(@expira_em)}</span>, ten minutes
              after the code was accepted.
            </span>
          </span>
        </label>
        <button type="submit" class="btn btn-primary">Finish setup</button>
      </form>
    </.moldura>
    """
  end

  @doc "O fim do cadastro, e a recusa do passo vencido ou usado."
  def concluido(assigns) do
    ~H"""
    <.moldura>
      <%= if @concluido do %>
        <div class="alert alert-success text-sm">
          <span>
            <b>Setup finished.</b>
            Your authenticator and your recovery codes are now valid. Every open operator session
            was signed out.
          </span>
        </div>
      <% else %>
        <.recusa titulo="Setup not finished.">
          The step was not accepted; ask for a new setup code.
        </.recusa>
      <% end %>
      <.link href={~p"/platform/sign-in"} class="btn btn-primary">Go to sign in</.link>
    </.moldura>
    """
  end

  # ------------------------------------------------------- tela 4 · as organizações

  @doc """
  Tela 4: toda organização, com o estado e nada do que ela tem (FR-007). A linha acima da tabela
  diz o que o operador **não** vê (D5): a regra visível, e não uma lacuna que pareça defeito.
  """
  def organizacoes(assigns) do
    ~H"""
    <.moldura operador={@operador} largura="max-w-4xl">
      <h1 class="text-xl font-semibold">Organisations</h1>
      <p class="text-sm opacity-70">
        You see each organisation's name, slug, state and suspension history. You do not see its
        people, teams, work or numbers. Operating the platform does not open any organisation.
      </p>

      <table class="table table-sm stacked">
        <thead>
          <tr>
            <th>organisation</th>
            <th>slug</th>
            <th>state</th>
            <th>last suspended</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={o <- @organizacoes}>
            <td data-label="organisation">
              <.link href={~p"/platform/organizations/#{o.slug}"} class="link">{o.name}</.link>
            </td>
            <td data-label="slug" class="font-mono">{o.slug}</td>
            <td data-label="state"><.estado status={o.status} /></td>
            <td data-label="last suspended">
              <%= if o.ultimo_episodio_em do %>
                <span class="font-mono">{Calendar.strftime(o.ultimo_episodio_em, "%Y-%m-%d")}</span>
              <% else %>
                <%!-- A ausência é da plataforma: nenhum episódio registrado. Escrita, nunca `—`. --%>
                <.absent reason="never suspended" />
              <% end %>
            </td>
          </tr>
        </tbody>
      </table>
    </.moldura>
    """
  end

  # ------------------------------------------------- tela 5 · o histórico e o ato

  @doc """
  Tela 5: o histórico e o ato que cabe ao estado (D3: o outro não aparece, nem desabilitado). Cada
  episódio tem duas metades, e a que falta é escrita (D4). A recusa re-renderiza esta página, com o
  formulário como a pessoa o deixou e o aviso acima dele.
  """
  def organizacao(assigns) do
    # `Map.merge`, e não `assign/2`: o controller entrega um mapa simples, sem o rastreio de mudança
    # que `assign/2` exige.
    assigns =
      Map.merge(assigns, %{
        suspensa?: assigns.resumo.status == "suspended",
        aberto: Enum.find(assigns.episodios, &is_nil(&1.reactivated_at))
      })

    ~H"""
    <.moldura operador={@operador} largura="max-w-3xl">
      <.link href={~p"/platform/organizations"} class="link text-sm">← Organisations</.link>

      <div>
        <h1 class="text-xl font-semibold">{@resumo.name}</h1>
        <div class="flex flex-wrap items-baseline gap-2 text-sm">
          <span class="font-mono">{@resumo.slug}</span>
          <span>·</span>
          <.estado status={@resumo.status} />
          <span :if={@aberto}>since {Calendar.strftime(@aberto.suspended_at, "%Y-%m-%d")}</span>
        </div>
      </div>

      <p :if={@sucesso} class="alert alert-success text-sm">{@sucesso}</p>

      <h2 class="font-semibold">Suspension history</h2>
      <%= if @episodios == [] do %>
        <.absent reason="never suspended" />
      <% end %>
      <div
        :for={ep <- @episodios}
        class="grid grid-cols-1 gap-3 rounded border border-base-300 p-3 sm:grid-cols-2"
      >
        <div class="flex flex-col gap-1 text-sm">
          <span class="text-xs uppercase tracking-wider opacity-60">suspended</span>
          <span class="font-mono">
            {hora_completa(ep.suspended_at)}<span :if={ep.suspended_by_operator}> · by {ep.suspended_by_operator.name}</span>
          </span>
          <.absent
            :if={is_nil(ep.suspended_by_operator)}
            reason="by: not recorded — suspended by hand before this record existed"
          />
          <span>
            {TheBand.Platform.SuspensionReasons.rotulo(ep.suspend_reason)}
            <span class="font-mono text-xs opacity-60">{ep.suspend_reason}</span>
          </span>
          <.nota texto={ep.suspend_note} />
        </div>
        <div class="flex flex-col gap-1 text-sm">
          <span class="text-xs uppercase tracking-wider opacity-60">reactivated</span>
          <%= if ep.reactivated_at do %>
            <span class="font-mono">
              {hora_completa(ep.reactivated_at)} · by {ep.reactivated_by_operator &&
                ep.reactivated_by_operator.name}
            </span>
            <span>
              {TheBand.Platform.SuspensionReasons.rotulo(ep.reactivate_reason)}
              <span class="font-mono text-xs opacity-60">{ep.reactivate_reason}</span>
            </span>
            <.nota texto={ep.reactivate_note} />
          <% else %>
            <.absent reason="not reactivated — still suspended" />
          <% end %>
        </div>
      </div>

      <.recusa :if={@recusa} titulo={elem(@recusa, 0)}>{elem(@recusa, 1)}</.recusa>

      <%= if @suspensa? do %>
        <.formulario_do_ato
          acao={~p"/platform/organizations/#{@resumo.slug}/reactivation"}
          titulo={"Reactivate #{@resumo.name}"}
          razoes={TheBand.Platform.SuspensionReasons.de_reativacao(@aberto && @aberto.suspend_reason)}
          ato={:reativar}
          aberto={@aberto}
          slug={@resumo.slug}
          valores={@valores}
          botao={"Reactivate #{@resumo.name}"}
          perigo={false}
        >
          <:consequencias>
            <li>People in {@resumo.name} can sign in again, each one from the start.</li>
            <li>No session comes back. Any session recorded while it was suspended is ended too.</li>
            <li>No API token comes back. Each one must be issued again by the organisation.</li>
            <li>Collection resumes on its normal schedule; reactivating does not start one.</li>
            <li>
              The suspension above stays on the record; this closes it with your name, this moment
              and this reason.
            </li>
          </:consequencias>
        </.formulario_do_ato>
      <% else %>
        <.formulario_do_ato
          acao={~p"/platform/organizations/#{@resumo.slug}/suspension"}
          titulo={"Suspend #{@resumo.name}"}
          razoes={TheBand.Platform.SuspensionReasons.de_suspensao()}
          ato={:suspender}
          aberto={nil}
          slug={@resumo.slug}
          valores={@valores}
          botao="Suspend, sign everyone out, revoke all tokens"
          perigo={true}
        >
          <:consequencias>
            <li>Every person in {@resumo.name} is signed out, on every device.</li>
            <li>Every API token of {@resumo.name} is revoked.</li>
            <li>Nobody in it can sign in, and no collection or background job runs for it.</li>
            <li>Its data stays as it is. Nothing is deleted.</li>
            <li>
              Reactivating later does <b>not</b> bring sessions or tokens back: each person signs in
              again, and each token is issued again.
            </li>
          </:consequencias>
        </.formulario_do_ato>
      <% end %>
    </.moldura>
    """
  end

  attr :texto, :string, default: nil

  # A nota, ou a ausência dela escrita com a frase da base.
  defp nota(assigns) do
    ~H"""
    <q :if={@texto} class="italic">{@texto}</q>
    <.absent :if={is_nil(@texto)} reason={TheBand.Platform.SuspensionReasons.frase_sem_nota()} />
    """
  end

  attr :acao, :string, required: true
  attr :titulo, :string, required: true
  attr :razoes, :list, required: true
  attr :ato, :atom, required: true
  attr :aberto, :any, required: true
  attr :slug, :string, required: true
  attr :valores, :map, required: true
  attr :botao, :string, required: true
  attr :perigo, :boolean, required: true
  slot :consequencias, required: true

  defp formulario_do_ato(assigns) do
    ~H"""
    <form action={@acao} method="post" class="flex flex-col gap-4 rounded border border-base-300 p-4">
      <.csrf />
      <h2 class="font-semibold">{@titulo}</h2>
      <fieldset class="flex flex-col gap-2">
        <legend class="text-[13px] font-semibold opacity-70">Reason — required</legend>
        <label :for={r <- @razoes} class="flex items-start gap-2 text-sm">
          <input
            type="radio"
            name="reason"
            value={r["code"]}
            checked={@valores["reason"] == r["code"]}
            class="radio radio-sm mt-0.5"
          />
          <span class="flex flex-col">
            <span>
              {r["label"]}
              <span
                :if={TheBand.Platform.SuspensionReasons.nota_obrigatoria?(@ato, r["code"])}
                class="text-xs opacity-70"
              >
                note required
              </span>
              <span class="font-mono text-xs opacity-60">{r["code"]}</span>
            </span>
            <span :if={r["offered_only_against"]} class="text-xs opacity-70">
              Offered because the open suspension's reason is {TheBand.Platform.SuspensionReasons.rotulo(
                r["offered_only_against"]
              )}; it is the answer to that reason.
            </span>
          </span>
        </label>
      </fieldset>
      <.campo rotulo="Note" dica={dica_da_nota(@ato)}>
        <textarea name="note" class="textarea textarea-bordered w-full">{@valores["note"]}</textarea>
      </.campo>
      <p class="text-sm font-semibold">
        {if @ato == :suspender,
          do: "What suspending does, at once and in one step",
          else: "What reactivating does, and what it does not"}
      </p>
      <ul class="list-disc pl-5 text-sm">{render_slot(@consequencias)}</ul>
      <.campo rotulo={"Type #{@slug} to confirm"}>
        <input
          type="text"
          name="confirm_slug"
          value={@valores["confirm_slug"]}
          autocomplete="off"
          spellcheck="false"
          class="input input-bordered w-full font-mono"
        />
      </.campo>
      <button type="submit" class={["btn", if(@perigo, do: "btn-error", else: "btn-primary")]}>
        {@botao}
      </button>
    </form>
    """
  end

  defp dica_da_nota(:suspender),
    do: "required for Suspected compromise and Other; optional otherwise. Kept with the episode."

  defp dica_da_nota(:reativar),
    do: "required for Other; optional otherwise. Kept with the episode."

  defp hora_completa(%DateTime{} = t), do: Calendar.strftime(t, "%Y-%m-%d %H:%M UTC")

  attr :status, :string, required: true

  # O estado em texto, sempre: a cor acompanha, e nunca carrega sozinha (WCAG 1.4.1).
  defp estado(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5">
      <span
        class={[
          "size-2 shrink-0 rounded-full",
          @status == "active" && "bg-success",
          @status != "active" && "bg-warning"
        ]}
        aria-hidden="true"
      ></span>
      {@status}
    </span>
    """
  end

  defp hora(%DateTime{} = t), do: Calendar.strftime(t, "%H:%M UTC")

  # A chave em grupos de quatro, para ser digitada no aplicativo sem perder o lugar.
  # O segredo é o binário cru de `SegundoFator.gerar_segredo/0`; o aplicativo recebe o base32 sem
  # padding, que é o que a URI `otpauth://` também leva (RFC 4648 §6). Mostrar o cru punha bytes
  # ilegíveis na tela (pego pelo teste de T039).
  defp em_grupos(segredo) do
    segredo
    |> TheBand.Segredo.expor()
    |> Base.encode32(padding: false)
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.map_join(" ", &Enum.join/1)
  end
end
