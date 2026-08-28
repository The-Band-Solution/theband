defmodule TheBandWeb.SessionLive.New do
  @moduledoc """
  Entrada na plataforma — feature 045 (US1), protótipo aprovado no canvas.

  A lacuna declarada da entrega anterior fecha aqui: a tela NÃO lista conta
  nenhuma — pede identificador (e-mail, ou usuário do GitHub pelo elo vigente) e
  senha, e recusa com UMA frase (FR-002). O painel de marketing é decisão de
  produto: o axioma da marca em serifada, os três compromissos reais, a tagline.
  """

  use TheBandWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sign in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid min-h-screen sm:grid-cols-2">
      <div class="hidden flex-col justify-between bg-base-300 p-12 sm:flex dark:bg-base-200">
        <span class="font-semibold">The Band</span>

        <div class="flex max-w-md flex-col gap-6">
          <h1 class="font-serif text-4xl leading-tight">Notas não são<br />música.</h1>
          <p class="text-base-content/75">
            Commits, issues e vínculos são as notas. O The Band as toca segundo
            ontologias de referência — e o que chega até você é música: informação
            com proveniência, pronta para decidir.
          </p>
          <ul class="flex flex-col gap-3 text-sm text-base-content/85">
            <li class="flex items-baseline gap-3">
              <span class="h-0.5 w-5 shrink-0 translate-y-[-4px] bg-primary"></span>
              Observado distinto de derivado — todo número calculado se declara.
            </li>
            <li class="flex items-baseline gap-3">
              <span class="h-0.5 w-5 shrink-0 translate-y-[-4px] bg-primary"></span>
              Ausência nomeada, nunca zero.
            </li>
            <li class="flex items-baseline gap-3">
              <span class="h-0.5 w-5 shrink-0 translate-y-[-4px] bg-primary"></span>
              Proveniência registro a registro, do GitHub à decisão.
            </li>
          </ul>
        </div>

        <p class="text-xs text-base-content/50">
          Orchestrating data into information organisations can act on
        </p>
      </div>

      <div class="flex items-center justify-center p-8">
        <div class="flex w-full max-w-sm flex-col gap-4">
          <div class="card bg-base-200 p-8">
            <div class="flex flex-col gap-5">
              <div>
                <h2 class="text-lg font-semibold">Sign in</h2>
                <p class="text-sm opacity-60">Enter your e-mail or GitHub username, and password.</p>
              </div>

              <p
                :if={erro = Phoenix.Flash.get(@flash, :error)}
                role="alert"
                class="alert alert-error font-serif text-sm"
              >
                {erro}
              </p>

              <form action={~p"/session"} method="post" class="flex flex-col gap-4">
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

                <label class="flex flex-col gap-1.5">
                  <span class="text-[13px] font-semibold opacity-70">E-mail or GitHub username</span>
                  <input
                    type="text"
                    name="identifier"
                    required
                    autocomplete="username"
                    class="input input-bordered w-full"
                  />
                  <span class="text-xs opacity-60">
                    O usuário do GitHub vale enquanto o elo com a pessoa observada estiver vigente.
                  </span>
                </label>

                <label class="flex flex-col gap-1.5">
                  <span class="text-[13px] font-semibold opacity-70">Password</span>
                  <input
                    type="password"
                    name="password"
                    required
                    autocomplete="current-password"
                    class="input input-bordered w-full"
                  />
                </label>

                <button type="submit" class="btn btn-primary w-full">Sign in</button>
              </form>
            </div>
          </div>

          <p class="text-center text-xs opacity-60">
            Sem senha definida? Quem administra gera uma senha temporária para você.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
