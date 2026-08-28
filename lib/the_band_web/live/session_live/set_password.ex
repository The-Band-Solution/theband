defmodule TheBandWeb.SessionLive.SetPassword do
  @moduledoc """
  Definição obrigatória de senha — o destino único de quem entrou com a
  temporária (FR-013). A hook `current_scope` traz quem chegou aqui; o gate que
  IMPEDE qualquer outra tela enquanto `must_change_password` estiver de pé vive
  na hook, não aqui. O POST vai ao controller: definir senha gira o token, e a
  sessão precisa do token novo — cookie é assunto de controller.
  """

  use TheBandWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Set password")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center p-8">
      <div class="flex w-full max-w-sm flex-col gap-4">
        <div class="card bg-base-200 p-8">
          <div class="flex flex-col gap-5">
            <div>
              <h1 class="text-lg font-semibold">Set your password</h1>
              <p class="text-sm opacity-60">
                A senha temporária serviu para entrar — antes de qualquer tela, defina a sua.
              </p>
            </div>

            <p :if={erro = Phoenix.Flash.get(@flash, :error)} role="alert" class="alert alert-error font-serif text-sm">
              {erro}
            </p>

            <form action={~p"/set-password"} method="post" class="flex flex-col gap-4">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

              <label class="flex flex-col gap-1.5">
                <span class="text-[13px] font-semibold opacity-70">New password</span>
                <input
                  type="password"
                  name="password"
                  required
                  minlength="12"
                  autocomplete="new-password"
                  class="input input-bordered w-full"
                />
                <span class="text-xs opacity-60">Mínimo de 12 caracteres.</span>
              </label>

              <label class="flex flex-col gap-1.5">
                <span class="text-[13px] font-semibold opacity-70">Confirm password</span>
                <input
                  type="password"
                  name="password_confirmation"
                  required
                  minlength="12"
                  autocomplete="new-password"
                  class="input input-bordered w-full"
                />
              </label>

              <button type="submit" class="btn btn-primary w-full">Set password</button>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
