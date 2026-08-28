defmodule TheBandWeb.VerificationLive.People do
  @moduledoc """
  `/work/verifications/people` — quem propôs e quem integrou trabalho que entrou com
  verificação vermelha. Issue #439.

  ## O que esta tela mede, e o que ela recusa medir

  Mede **o que integrou vermelho** — a solicitação que entrou na branch de destino com algum
  commit cujo processo de CI foi malsucedido. É a máxima `ci.ap03`, e o que ela descreve é a
  verificação ter deixado de ser porta para ser relatório.

  **Não mede CI vermelho num ramo de proposta.** Aquilo é o processo funcionando: a verificação
  pegou o problema antes de integrar, que é para isso que ela existe. Contá-lo produziria a
  medida ao contrário — quem empurra cedo e usa o CI como rede acumularia vermelhos, e quem
  desenvolve local e empurra uma vez apareceria impecável.

  ## As duas listas são dois atos, e somá-las apontaria para a pessoa errada

  Submeter (`cmpo.stakeholder_submitted_change_request`) e integrar
  (`cmpo.stakeholder_performed_checkin`) são participações distintas. **Integrar com verificação
  vermelha é decisão de quem integra** — a definição de `cmpo.change_request` já dizia que o PR
  "não é o merge, nem a decisão de aprovação".

  Quem propôs pode ter aberto a solicitação com o CI vermelho de propósito, para pedir ajuda.
  Quem integrou decidiu que entrava assim.

  ## Mede pelo estado da PONTA, não pelo casamento por `head_sha`

  Os dois caminhos não medem a mesma coisa, e a sobreposição entre eles é pequena. Medido em
  2026-08-20 sobre as **4.878 solicitações integradas, todas medidas** — nenhuma pendente:

      casamento por head_sha    323 vermelhas
      statusCheckRollup         261 vermelhas
      nos dois                  115
      união                     469

  **O casamento por SHA superconta, e superconta exatamente o que esta tela recusa.** Das 208
  que só ele acha, **198 estão VERDES na ponta**: a vermelha estava num commit intermediário, e
  o PR foi consertado antes de entrar. Conferido no `#13` — 33 commits, três execuções vermelhas
  no meio, ponta verde com 2 contextos. Isso é o processo funcionando, e contá-lo produziria a
  medida ao contrário.

  As 146 que só o rollup acha são o que o `workflow_run` não alcança: os `check_run` da API de
  Checks e os `status` da API antiga.

  E o rollup responde o que o casamento não respondia: das 4.878, **2.024 entraram sem check
  nenhum** — 41%. Pelo caminho antigo essas apareciam como "não dá para saber", e são coisa
  oposta — achado sobre o processo, não lacuna nossa.

  ## `no check` tem coluna própria, e o motivo é o que ela evita

  Uma taxa calculada sobre `merged` faria quem trabalha em repositório sem CI aparecer
  impecável. E juntar "entrou sem verificação" com "não medimos" faria a organização parecer
  medida onde ela não é verificada — que é pior, porque ninguém procuraria o problema.

  ## Base pequena não recebe taxa

  Abaixo de dez solicitações verificáveis a tela mostra a contagem e **não** a porcentagem.
  Três de quatro é 75% e não significa nada — e foi exatamente esse erro que esta sessão
  cometeu ao anunciar "83%" a partir de três amostras (lição L64).
  """
  use TheBandWeb, :live_view

  alias TheBand.Verification

  # Abaixo disto a tela mostra contagem e omite a taxa. Dez é o mínimo em que uma porcentagem
  # começa a dizer algo — e o número vai declarado na tela, porque corte escondido faz quem lê
  # achar que é propriedade do dado.
  @minimo_para_taxa 10

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    {:ok,
     socket
     |> assign(page_title: "Who merged red")
     |> assign(minimo_para_taxa: @minimo_para_taxa)
     |> assign(papel: "author")
     |> assign(cobertura: Verification.cobertura_pela_ponta(tenant))
     |> assign(autores: Verification.red_by_person(tenant))
     |> assign(integradores: Verification.red_by_integrator(tenant))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, papel: papel_de(params["role"]))}
  end

  defp papel_de("integrator"), do: "integrator"
  defp papel_de(_), do: "author"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
    >
      <.header>
        Who merged red
        <:subtitle>
          Change requests that were <strong>integrated</strong> with a failed continuous
          integration run — the maxim <span class="font-mono">ci.ap03</span>
        </:subtitle>
      </.header>

      <%!-- A RESSALVA VEM ANTES DA TABELA, e não em nota de pé. Quem lê a tabela primeiro já
            formou juízo; quem lê isto primeiro sabe o que a tabela não diz. --%>
      <div class="alert block text-sm">
        <p>
          <strong>A red run on a proposal branch is the process working</strong>
          — the check
          caught the problem before it was integrated. This page counts only what
          <strong>went in</strong>
          red: the check became a report instead of a gate.
        </p>
        <p class="mt-2">
          Of <strong>{total_integradas(@cobertura)}</strong>
          merged requests, <strong>{@cobertura[:sem_check] || 0}</strong>
          went in with <strong>no check at all</strong>
          and <strong>{@cobertura[:vermelha] || 0}</strong>
          went in red.
          <.link navigate={~p"/work/verifications"} class="link">
            The verification page breaks it down
          </.link>
          — only {@cobertura[:nao_medido] || 0} were collected before the platform asked the
          source for the check state.
        </p>
      </div>

      <%!-- Os dois papéis são atos diferentes, e a tela obriga a escolher um: mostrá-los
            lado a lado convidaria a somar, e somar aponta para a pessoa errada. --%>
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span class="opacity-60">participation:</span>
        <.link
          patch={~p"/work/verifications/people?role=author"}
          class={["btn btn-xs", if(@papel == "author", do: "btn-primary", else: "btn-ghost")]}
        >
          who submitted it
        </.link>
        <.link
          patch={~p"/work/verifications/people?role=integrator"}
          class={["btn btn-xs", if(@papel == "integrator", do: "btn-primary", else: "btn-ghost")]}
        >
          who integrated it
        </.link>
      </div>

      <p class="text-xs opacity-70">
        {frase_do_papel(@papel)}
      </p>

      <div class="overflow-x-auto">
        <table class="table stacked table-sm">
          <thead>
            <tr>
              <th>person</th>
              <th>merged</th>
              <th>had a check</th>
              <th>no check</th>
              <th>went in red</th>
              <th>rate</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={p <- linhas(@papel, @autores, @integradores)}>
              <td data-label="person">
                <.link
                  :if={p.person_id}
                  navigate={~p"/people/#{p.person_id}"}
                  class="link link-hover"
                >
                  {p.login}
                </.link>
                <span :if={is_nil(p.person_id)}>{p.login || "—"}</span>
              </td>
              <td data-label="merged" class="font-mono text-xs tabular-nums">{p.merged}</td>
              <td data-label="had a check" class="font-mono text-xs tabular-nums">{p.verified}</td>
              <%!-- A coluna que o caminho antigo não tinha. Pelo casamento por `head_sha`, estas
                    apareciam como "não dá para saber" — e entrar sem verificação é achado sobre
                    o processo, não lacuna nossa. --%>
              <td data-label="no check" class="font-mono text-xs tabular-nums text-warning">
                {p.no_check}
              </td>
              <td data-label="went in red" class="font-mono text-xs tabular-nums text-warning">
                {p.red}
                <%!-- "Não medido" fica ao lado do vermelho porque é o que impede a taxa de ser
                      lida como completa. --%>
                <span :if={p.not_measured > 0} class="ml-1 opacity-60 italic">
                  ({p.not_measured} not measured)
                </span>
              </td>
              <td data-label="rate" class="text-xs">
                <span :if={taxa(p)} class="font-mono tabular-nums">{taxa(p)}</span>
                <%!-- Base pequena não recebe taxa: três de quatro é 75% e não significa nada. --%>
                <span :if={is_nil(taxa(p))} class="opacity-60 italic">
                  {frase_sem_taxa(p)}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="text-xs opacity-70">
        The rate is shown only from <strong>{@minimo_para_taxa}</strong>
        verifiable requests up. Below that the count is shown and the percentage is not — a
        small base produces a number that looks like a measure and is not one.
      </p>

      <%!-- A coautoria é a limitação que nenhuma coluna consegue expressar, e por isso vai
            escrita. --%>
      <p class="text-xs opacity-70">
        <strong>One more limit.</strong>
        1,203 of 16,416 collected commits have more than one author — the
        <span class="font-mono">Co-Authored-By</span>
        trailer. For those, there is no single author to attribute anything to, and the network
        declares a participation for each.
      </p>
    </Layouts.app>
    """
  end

  defp linhas("integrator", _autores, integradores), do: integradores
  defp linhas(_, autores, _integradores), do: autores

  defp frase_do_papel("integrator"),
    do:
      "Who performed the check-in. Integrating with a red run is the integrator's decision — the change request is not the merge."

  defp frase_do_papel(_),
    do:
      "Who submitted the change request. They may have opened it red on purpose, to ask for help."

  defp total_integradas(cobertura) do
    cobertura |> Map.values() |> Enum.sum()
  end

  defp taxa(%{verified: verificaveis, red: vermelhas}) when verificaveis >= @minimo_para_taxa do
    "#{Float.round(vermelhas / verificaveis * 100, 1)}%"
  end

  defp taxa(_), do: nil

  # Duas frases diferentes, porque as situações são: base pequena é "pouco para medir";
  # nenhuma verificável é "não dá para saber nada".
  defp frase_sem_taxa(%{verified: 0}), do: "nothing verifiable"
  defp frase_sem_taxa(%{verified: n}), do: "only #{n} verifiable"
end
