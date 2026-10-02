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

  attr :passo, :string, default: nil
  slot :inner_block, required: true

  # A moldura comum: a faixa do produto e a coluna do formulário. Não usa `Layouts.app`, que
  # depende de `current_tenant` e `current_user`, e o operador não tem nenhum dos dois.
  defp moldura(assigns) do
    ~H"""
    <main class="mx-auto flex min-h-screen max-w-md flex-col gap-5 px-4 py-10 sm:py-16">
      <div class="flex items-baseline gap-2">
        <span class="font-semibold">The Band</span>
        <span class="text-sm opacity-60">platform operation</span>
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
