defmodule TheBandWeb.AccessScopesLive.Index do
  @moduledoc """
  `/access-scopes` — a gestão dos escopos de acesso (feature 045, US2).

  A visão de cada conta é a UNIÃO dos escopos, e a tela mostra todos com a
  origem: derivado vem com hachura e a relação que o sustenta — e SEM botão de
  revogar, porque ninguém o concedeu (FR-021: fecha com o fato); concedido vem
  com quem/quando e Revoke. O piso person não vira linha: é nota, porque toda
  conta com elo o tem.

  ## O custo desta tela

  `Tenants.scopes/2` roda por conta listada. São contas de plataforma — meia
  dúzia no piloto —, não pessoas observadas; se um tenant real passar de
  dezenas de contas, paginar AQUI (e agregar scopes) vira tarefa própria.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    {:ok,
     socket
     |> assign(
       page_title: "Access scopes",
       nivel: "team",
       erro: nil,
       ok: nil,
       equipes: EO.list_teams(tenant),
       projetos: SPO.list_projects(tenant),
       organizacoes: EO.list_organizations(tenant)
     )
     |> carregar()}
  end

  # A tela dizia "já existe concessão vigente" para QUALQUER erro de changeset —
  # falta de campo, nível inválido e unicidade caíam na mesma frase. Afirmar a
  # causa sem conferir é a forma de sucesso silencioso ao contrário: um erro que
  # mente sobre si mesmo manda quem lê procurar no lugar errado.
  #
  # Encontrado em 2026-09-01, quando a mensagem fez parecer que só uma pessoa
  # podia ter escopo de organização. Podem várias: o índice é por
  # (tenant, conta, nível, alvo).
  defp motivo_da_recusa(%Ecto.Changeset{} = changeset) do
    if ja_concedido?(changeset) do
      dgettext("errors", "Esta conta já vê este alvo. Nada a fazer.")
    else
      dgettext("errors", "Concessão recusada: %{motivo}.", motivo: erros_legiveis(changeset))
    end
  end

  defp ja_concedido?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_campo, {_msg, opts}} ->
      Keyword.get(opts, :constraint) == :unique
    end)
  end

  defp erros_legiveis(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {campo, msgs} -> "#{campo} #{Enum.join(msgs, ", ")}" end)
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant

    contas =
      for user <- Tenants.list_users(tenant) do
        %{user: user, escopos: Tenants.scopes(tenant, user)}
      end

    assign(socket, contas: contas)
  end

  @impl true
  def handle_event("nivel", %{"level" => nivel}, socket) do
    {:noreply, assign(socket, nivel: nivel, erro: nil, ok: nil)}
  end

  def handle_event("grant", %{"user_id" => user_id, "level" => nivel} = params, socket) do
    case Map.get(params, "target_id", "") do
      "" ->
        artigo = %{
          "team" => "a equipe",
          "project" => "o projeto",
          "organization" => "a organização"
        }

        {:noreply,
         assign(socket,
           erro:
             dgettext("errors", "Escolha %{artigo} — escopo %{nivel} não existe sem alvo.",
               artigo: artigo[nivel],
               nivel: nivel
             ),
           ok: nil
         )}

      target_id ->
        case Tenants.grant_scope(
               socket.assigns.current_tenant,
               user_id,
               String.to_existing_atom(nivel),
               target_id,
               socket.assigns.current_user
             ) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(
               ok: dgettext("sistema", "Escopo %{nivel} concedido.", nivel: nivel),
               erro: nil
             )
             |> carregar()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, erro: motivo_da_recusa(changeset), ok: nil)}

          {:error, motivo} ->
            {:noreply,
             assign(socket,
               erro: dgettext("errors", "Concessão recusada: %{motivo}.", motivo: motivo),
               ok: nil
             )}
        end
    end
  end

  def handle_event("revoke", %{"id" => grant_id}, socket) do
    case Tenants.revoke_scope(
           socket.assigns.current_tenant,
           grant_id,
           socket.assigns.current_user
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(ok: dgettext("sistema", "Escopo revogado."), erro: nil)
         |> carregar()}

      {:error, motivo} ->
        {:noreply,
         assign(socket,
           erro: dgettext("errors", "Revogação recusada: %{motivo}.", motivo: motivo),
           ok: nil
         )}
    end
  end

  defp alvos(assigns) do
    case assigns.nivel do
      "team" -> Enum.map(assigns.equipes, &{&1.id, &1.name})
      "project" -> Enum.map(assigns.projetos, &{&1.id, &1.name})
      "organization" -> Enum.map(assigns.organizacoes, &{&1.id, &1.name})
    end
  end

  defp origem_rotulo(:floor), do: "piso do elo"
  defp origem_rotulo(:derived_team), do: "vínculo pessoa-equipe"
  defp origem_rotulo(:derived_project), do: "equipe→projeto declarado"
  defp origem_rotulo(:granted), do: "concedido"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
      operacao_menu={assigns[:operacao_menu]}
    >
      <.header>
        Access scopes
        <:subtitle>
          <span class="font-serif text-[15px] text-base-content">
            A pessoa tem acesso aos dados com os quais está relacionada.
          </span>
          O escopo segue as relações — elo, vínculo, ligação declarada — e a concessão
          cobre o que a relação não cobre. Não é o papel na organização: Developer Role
          e Tech Leader vivem em Roles.
        </:subtitle>
      </.header>

      <div :if={@erro} role="alert" class="alert alert-error font-serif text-sm">{@erro}</div>
      <div :if={@ok} role="status" class="alert alert-success text-sm">{@ok}</div>

      <div class="card bg-base-200 p-6">
        <h2 class="mb-3 text-sm font-semibold opacity-70">Grant a scope</h2>
        <form phx-submit="grant" class="flex flex-wrap items-end gap-3">
          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">Account</span>
            <select name="user_id" required class="select select-bordered">
              <option :for={conta <- @contas} value={conta.user.id}>{conta.user.email}</option>
            </select>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">Scope</span>
            <select name="level" phx-change="nivel" class="select select-bordered">
              <option value="team" selected={@nivel == "team"}>team</option>
              <option value="project" selected={@nivel == "project"}>project</option>
              <option value="organization" selected={@nivel == "organization"}>organization</option>
            </select>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">Target</span>
            <select name="target_id" class="select select-bordered min-w-44">
              <option value="">—</option>
              <option :for={{id, nome} <- alvos(assigns)} value={id}>{nome}</option>
            </select>
          </label>

          <button type="submit" class="btn btn-primary">Grant</button>
        </form>
        <p class="mt-2 text-xs opacity-60">
          person não se concede — é o piso de toda conta com elo vigente. Administrador
          é marca de gestão, noutro eixo: mexer, não ver.
        </p>
      </div>

      <section :for={conta <- @contas} class="card bg-base-200 p-6">
        <div class="mb-2 flex items-baseline gap-3">
          <h2 class="font-semibold">{conta.user.email}</h2>
          <span :if={conta.user.role == "admin"} class="badge badge-primary badge-sm">
            administrador
          </span>
        </div>

        <p :if={conta.escopos == []} class="text-sm opacity-60">
          Nenhum escopo: sem elo declarado e sem concessão, esta conta não vê painel
          nenhum — e a recusa dela diz isso.
        </p>

        <ul class="flex flex-col gap-2">
          <li :for={escopo <- conta.escopos} class="flex flex-wrap items-center gap-2 text-sm">
            <span
              :if={escopo.origin in [:derived_team, :derived_project]}
              class="badge badge-outline badge-info badge-sm gap-1.5"
            >
              <%!-- A mesma gramática da marca de evidência (TheBandWeb.UI): derivado é
                    hachurado, e a hachura segue a cor do texto por currentColor. --%>
              <span
                class="size-2 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
                aria-hidden="true"
              ></span>
              {escopo.level} · derivado
            </span>
            <span :if={escopo.origin == :floor} class="badge badge-ghost badge-sm">
              person · piso
            </span>
            <span :if={escopo.origin == :granted} class="badge badge-info badge-sm">
              {escopo.level}
            </span>

            <span :if={escopo.target_name}>{escopo.target_name}</span>
            <span :if={escopo.origin == :granted and is_nil(escopo.target_name)} class="text-error">
              alvo não existe mais — concessão órfã
            </span>

            <span class="opacity-60">· {origem_rotulo(escopo.origin)}</span>

            <span :if={escopo.grant} class="opacity-60">
              · por {escopo.grant.granted_by_user_id &&
                autor(@contas, escopo.grant.granted_by_user_id)} em {Calendar.strftime(
                escopo.grant.granted_at,
                "%Y-%m-%d"
              )}
            </span>

            <button
              :if={escopo.grant}
              phx-click="revoke"
              phx-value-id={escopo.grant.id}
              class="btn btn-ghost btn-xs text-error"
            >
              Revoke
            </button>
            <span
              :if={escopo.origin in [:derived_team, :derived_project]}
              class="text-xs opacity-50"
            >
              fecha com o fato
            </span>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  defp autor(contas, user_id) do
    case Enum.find(contas, &(&1.user.id == user_id)) do
      %{user: user} -> user.email
      nil -> "conta removida"
    end
  end
end
