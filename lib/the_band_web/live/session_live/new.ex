defmodule TheBandWeb.SessionLive.New do
  @moduledoc """
  Entrada na plataforma — feature 045 (US1), protótipo aprovado no canvas.

  A lacuna declarada da entrega anterior fecha aqui: a tela NÃO lista conta
  nenhuma — pede identificador (e-mail, ou usuário do GitHub pelo elo vigente) e
  senha, e recusa com UMA frase (FR-002). O painel de marketing é decisão de
  produto: o axioma da marca em serifada, os três compromissos reais, a tagline.

  ## A copy fala pela metáfora, e não pelo vocabulário da máquina (2026-08-31)

  O painel dizia que o The Band toca as notas "segundo ontologias de referência".
  Está correto e não comunica: quem chega pela primeira vez não sabe o que é uma
  ontologia, e a palavra empurra a leitura para "ferramenta técnica" antes de
  dizer o que a plataforma entrega. A metáfora da tese diz a mesma coisa sem o
  termo — notas são o dado como a origem entregou, música é a informação — e os
  três compromissos passam a estar escritos como consequência para quem lê, não
  como propriedade do sistema. O vocabulário preciso continua onde ele decide:
  rótulo de conceito, mensagem de erro, tela de sincronização.
  """

  use TheBandWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # A copy do painel vive no CATÁLOGO, e não literal no HEEx. O locale padrão é
    # `en` e não há troca em runtime: escrita em português no template, a frase
    # ficaria em português ao lado de um formulário em inglês — que é o que estava
    # acontecendo. No catálogo, ela acompanha o idioma servido.
    {:ok,
     assign(socket,
       page_title: "Sign in",
       axioma: dgettext("sistema", "Notes aren’t music."),
       abertura:
         dgettext(
           "sistema",
           "Your tools keep loose notes: a commit here, an issue there, the same person under three different names. The Band plays those notes together — and what reaches you is music: who does what, with whom, since when."
         ),
       compromissos: [
         dgettext(
           "sistema",
           "Every note says where it came from. No number shows up without a source."
         ),
         dgettext(
           "sistema",
           "What the platform inferred is said as inference, kept apart from what it saw."
         ),
         dgettext(
           "sistema",
           "When a note is missing, it says so — it does not play zero instead."
         )
       ],
       # As duas frases de apoio do formulário estavam literais em português, ao lado
       # de rótulos em inglês, na mesma tela. Vão para o catálogo junto com a copy:
       # deixar UMA fora faria a tela voltar a falar dois idiomas.
       ajuda_do_identificador:
         dgettext(
           "sistema",
           "The GitHub username works while the link to the observed person is current."
         ),
       ajuda_da_senha:
         dgettext(
           "sistema",
           "No password yet? An administrator generates a temporary one for you."
         )
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- `grid-rows-[auto_1fr]`: no telefone a faixa ocupa o que o texto pede, e o
          resto da altura vai para o cartão. Sem isto o grid divide a sobra do
          `min-h-screen` igualmente entre as duas linhas, e a faixa aparece com um
          vazio do tamanho dela embaixo do texto. Em `sm:` volta a ser uma linha só,
          com duas colunas. --%>
    <div class="grid min-h-screen grid-rows-[auto_1fr] sm:grid-cols-2 sm:grid-rows-1">
      <%!-- No telefone o painel da esquerda não cabe, e por isso ele é `hidden`. O
            efeito medido em 390px: sumia a copy, sumiam os compromissos, sumia a
            tagline E sumia o nome — sobrava um cartão de login num fundo vazio, sem
            dizer de quem é a plataforma. Quem chega pelo telefone nunca leu nada
            disto.

            A faixa abaixo devolve o mínimo que identifica: o nome e o axioma da
            marca. Só isso, de propósito — os três compromissos empurrariam o
            formulário para fora da primeira dobra, e esta tela existe para entrar. --%>
      <div class="flex flex-col gap-1 bg-base-300 px-6 py-6 sm:hidden dark:bg-base-200">
        <span class="font-semibold">The Band</span>
        <p class="font-serif text-2xl leading-tight">{@axioma}</p>
      </div>

      <div class="hidden flex-col justify-between bg-base-300 p-12 sm:flex dark:bg-base-200">
        <span class="font-semibold">The Band</span>

        <div class="flex max-w-md flex-col gap-6">
          <h1 class="font-serif text-4xl leading-tight">{@axioma}</h1>
          <p class="text-base-content/75">{@abertura}</p>
          <%!-- Os três compromissos vêm de uma LISTA, e não de três <li> escritos à
                mão: escritos à mão, traduzir um e esquecer os outros dois deixa a
                tela com dois idiomas, e nada avisa. --%>
          <ul class="flex flex-col gap-3 text-sm text-base-content/85">
            <li :for={compromisso <- @compromissos} class="flex items-baseline gap-3">
              <span class="h-0.5 w-5 shrink-0 translate-y-[-4px] bg-primary"></span>
              {compromisso}
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
                  <span class="text-xs opacity-60">{@ajuda_do_identificador}</span>
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

          <p class="text-center text-xs opacity-60">{@ajuda_da_senha}</p>
        </div>
      </div>
    </div>
    """
  end
end
