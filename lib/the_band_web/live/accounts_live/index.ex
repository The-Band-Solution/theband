defmodule TheBandWeb.AccountsLive.Index do
  @moduledoc """
  `/accounts` — as contas do tenant, para quem administra (feature 045, US1;
  feature 051: a área única do onboarding).

  Cadastro é ato administrativo (assumption da spec): não há auto-registro. Desde a
  051 a conta nasce COM a temporária — `cadastrar_conta/3` cria e emite numa
  transação, e a temporária aparece UMA vez nesta tela, vive só no assign, e o
  próximo evento a apaga. Ela não é gravada em claro nem logada; quem administra a
  entrega por canal próprio, fora da plataforma.

  O elo conta↔pessoa do GitHub se administra AQUI (051, US2): busca entre as
  pessoas coletadas, associação pela identidade estável, revogação na linha. A
  página da pessoa continua LENDO o elo — mudou onde se administra, não onde se lê.

  A marca de administrador (`users.role`) é gestão, não visão (FR-022): dar a
  marca aqui não abre painel nenhum — escopo se concede em /access-scopes.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Accounts", temporaria: nil, erro: nil, busca: nil)
     |> carregar()}
  end

  # A lista com o elo em DUAS consultas fixas (contas + logins das vinculadas),
  # nunca uma por linha (L38) — contrato contas-e-elo.md.
  defp carregar(socket) do
    users = Tenants.list_users(socket.assigns.current_tenant)

    vinculadas =
      users
      |> Enum.filter(&(&1.person_id && is_nil(&1.person_revoked_at)))
      |> Enum.map(& &1.person_id)

    logins = EO.person_logins(socket.assigns.current_tenant, vinculadas)

    assign(socket, users: users, logins: logins)
  end

  @impl true
  def handle_event("criar", %{"email" => email, "name" => name}, socket) do
    case Tenants.cadastrar_conta(
           socket.assigns.current_tenant,
           %{"email" => email, "name" => name, "role" => "member"},
           socket.assigns.current_user
         ) do
      {:ok, {user, temporaria}} ->
        {:noreply,
         socket
         |> assign(temporaria: %{user_id: user.id, senha: temporaria}, erro: nil, busca: nil)
         |> carregar()}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           erro: dgettext("errors", "Conta não criada: %{motivo}", motivo: motivo(changeset)),
           temporaria: nil
         )}
    end
  end

  def handle_event("reset", %{"id" => user_id}, socket) do
    case Tenants.reset_password(
           socket.assigns.current_tenant,
           user_id,
           socket.assigns.current_user.id
         ) do
      {:ok, temporaria} ->
        {:noreply,
         socket
         |> assign(temporaria: %{user_id: user_id, senha: temporaria}, erro: nil)
         |> carregar()}

      {:error, _} ->
        {:noreply,
         assign(socket, erro: dgettext("errors", "Conta não encontrada."), temporaria: nil)}
    end
  end

  # ── O elo, administrado na área (051/US2) ──

  def handle_event("abrir_busca", %{"user-id" => user_id}, socket) do
    {:noreply, assign(socket, busca: %{user_id: user_id, q: "", resultados: []})}
  end

  def handle_event("fechar_busca", _params, socket) do
    {:noreply, assign(socket, busca: nil)}
  end

  # A consulta roda no EVENTO da digitação, nunca no mount (contrato). Resultado
  # traz nome, login e organização não — a busca é sobre pessoas; os homônimos se
  # separam pelo LOGIN, que é único na origem.
  def handle_event("buscar_pessoa", %{"q" => q}, socket) do
    resultados =
      if String.trim(q) == "" do
        []
      else
        EO.list_people(socket.assigns.current_tenant, search: q, limit: 8)
      end

    {:noreply, assign(socket, busca: %{socket.assigns.busca | q: q, resultados: resultados})}
  end

  def handle_event("associar", %{"user-id" => user_id, "person-id" => person_id}, socket) do
    case Tenants.declare_person(
           socket.assigns.current_tenant,
           user_id,
           person_id,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(erro: nil, busca: nil, temporaria: nil)
         |> carregar()}

      # Cenário 3 da US2: a recusa NOMEIA a conta dona — a leitura estreita roda
      # só aqui, no caminho do conflito. A garantia contra a corrida é do índice
      # único parcial; esta frase é o nome, não a defesa.
      {:error, :taken} ->
        dona = Tenants.user_of_person(socket.assigns.current_tenant, person_id)

        {:noreply,
         assign(socket,
           erro:
             dgettext("errors", "Essa pessoa já está associada à conta %{email}.",
               email: (dona && dona.email) || "?"
             ),
           temporaria: nil
         )}

      {:error, _} ->
        {:noreply,
         assign(socket, erro: dgettext("errors", "Conta não encontrada."), temporaria: nil)}
    end
  end

  def handle_event("revogar_elo", %{"user-id" => user_id}, socket) do
    case Tenants.revoke_person(
           socket.assigns.current_tenant,
           user_id,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply, socket |> assign(erro: nil, temporaria: nil) |> carregar()}

      {:error, _} ->
        {:noreply, assign(socket, erro: dgettext("errors", "Nada a revogar."), temporaria: nil)}
    end
  end

  defp motivo(changeset) do
    Enum.map_join(changeset.errors, "; ", fn {campo, {msg, _}} -> "#{campo} #{msg}" end)
  end

  defp elo_vigente?(user), do: user.person_id && is_nil(user.person_revoked_at)

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
        Accounts
        <:subtitle>
          Quem entra na plataforma, e qual conta do GitHub é de quem. Cadastro é ato
          de administração; a conta nasce com a temporária, mostrada uma única vez.
        </:subtitle>
      </.header>

      <div :if={@erro} role="alert" class="alert alert-error font-serif text-sm">{@erro}</div>

      <div
        :if={@temporaria}
        role="status"
        class="card border-2 border-warning bg-base-200 p-4 text-sm"
      >
        <p class="font-semibold">Senha temporária — aparece só agora:</p>
        <p class="font-mono text-lg">{@temporaria.senha}</p>
        <p class="opacity-70">
          Entregue por canal próprio. A primeira entrada com ela obriga a definição
          de uma senha nova.
        </p>
      </div>

      <div class="card bg-base-200 p-6">
        <h2 class="mb-3 text-sm font-semibold opacity-70">Create account</h2>
        <%!-- Nome e e-mail obrigatórios — FR-001 da 051: são os dados da pessoa. --%>
        <form phx-submit="criar" class="flex flex-wrap items-end gap-3">
          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">Name</span>
            <input type="text" name="name" required class="input input-bordered" />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-[13px] font-semibold opacity-70">E-mail</span>
            <input type="email" name="email" required class="input input-bordered" />
          </label>
          <button type="submit" class="btn btn-primary">Create</button>
        </form>
        <p class="mt-2 text-xs opacity-60">
          A conta nasce com uma senha temporária, mostrada uma única vez acima — e a
          associação do GitHub se faz na linha, logo abaixo.
        </p>
      </div>

      <div class="card bg-base-200 overflow-x-auto p-0">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>E-mail</th>
              <th>GitHub</th>
              <th>Gestão</th>
              <th>Senha</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={user <- @users}>
              <td>{user.name}</td>
              <td>{user.email}</td>
              <td>
                <%!-- O elo é DECLARADO por quem administra: marca sólida, nunca
                      hachura. Ausência nomeada, nunca célula vazia (FR-003). --%>
                <span :if={elo_vigente?(user)} class="font-mono text-xs">
                  {@logins[user.person_id] || "?"}
                </span>
                <button
                  :if={elo_vigente?(user)}
                  phx-click="revogar_elo"
                  phx-value-user-id={user.id}
                  data-confirm="Revogar a associação? A pessoa deixa de entrar pelo username do GitHub; a história do elo fica."
                  class="btn btn-ghost btn-xs"
                >
                  revoke
                </button>
                <span :if={!elo_vigente?(user)} class="text-xs opacity-60">
                  no GitHub account linked
                </span>
                <button
                  :if={!elo_vigente?(user)}
                  phx-click="abrir_busca"
                  phx-value-user-id={user.id}
                  class="btn btn-ghost btn-xs"
                >
                  link…
                </button>

                <div
                  :if={@busca && @busca.user_id == user.id}
                  class="mt-2 rounded border border-base-300 p-2"
                >
                  <form id={"busca-#{user.id}"} phx-change="buscar_pessoa" phx-submit="buscar_pessoa">
                    <input
                      type="text"
                      name="q"
                      value={@busca.q}
                      placeholder="name or GitHub login…"
                      phx-debounce="300"
                      autocomplete="off"
                      class="input input-bordered input-sm w-56"
                    />
                  </form>
                  <ul :if={@busca.resultados != []} class="mt-1 space-y-1">
                    <li :for={p <- @busca.resultados}>
                      <button
                        phx-click="associar"
                        phx-value-user-id={user.id}
                        phx-value-person-id={p.id}
                        class="btn btn-ghost btn-xs"
                      >
                        {p.name} <span class="font-mono opacity-60">{p.login}</span>
                      </button>
                    </li>
                  </ul>
                  <p
                    :if={@busca.q != "" and @busca.resultados == []}
                    class="mt-1 text-xs opacity-60"
                  >
                    nenhuma pessoa coletada bate com “{@busca.q}”
                  </p>
                  <button phx-click="fechar_busca" class="btn btn-ghost btn-xs mt-1">
                    close
                  </button>
                </div>
              </td>
              <td>
                <span :if={user.role == "admin"} class="badge badge-primary badge-sm">
                  administrador
                </span>
                <span :if={user.role != "admin"} class="opacity-50">—</span>
              </td>
              <td>
                <span :if={user.password_hash && !user.must_change_password}>definida</span>
                <span :if={user.password_hash && user.must_change_password} class="text-warning">
                  temporária pendente
                </span>
                <span :if={!user.password_hash} class="opacity-60">
                  sem senha — a entrada recusa
                </span>
              </td>
              <td class="text-right">
                <button phx-click="reset" phx-value-id={user.id} class="btn btn-ghost btn-xs">
                  Reset password
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
