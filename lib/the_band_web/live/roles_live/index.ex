defmodule TheBandWeb.RolesLive.Index do
  @moduledoc """
  `/roles` — o catálogo de papéis que a organização reconhece.

  ## Por que esta tela existe

  Medido em 2026-08-14: **101 evidências de vínculo pessoa-equipe, zero vínculos, zero
  papéis**. Os três números são o mesmo fato — o vínculo da ontologia exige papel, e nenhum
  havia sido cadastrado.

  ## Os quatro do Scrum estão sempre lá — issue #317

  A versão anterior os mostrava como **sugestão de preenchimento**: a pessoa clicava e a
  plataforma preenchia o formulário. Custava um passo antes de poder promover, e a `FR-002`
  diz "sem cadastro prévio".

  Agora eles **estão disponíveis**, compostos da rede a cada leitura — e só viram linha quando
  alguém os usa. Ver `EO.RoleCatalog` para por que não são semeados.

  O que não mudou: a plataforma continua não reconhecendo no lugar da organização. Ela oferece
  o que a SRO nomeia; quem usa decide.

  ## Por organização, e não por tenant

  O cadastro passou a ter `organization_id`. Antes, um papel cadastrado vazava para as três
  organizações do tenant — que não compartilham vocabulário nenhum. Mesma classe do defeito de
  escopo da issue #446.

  ## O estado vazio diz o que está esperando

  Uma tela vazia que diz "nenhum papel cadastrado" informa metade. A outra metade é **quantas
  evidências dependem disso** — sem ela, ninguém sabe que a lista vazia é um bloqueio e não uma
  escolha.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 25

  @tabelas [{"roles", [:code, :name], nil}]

  @impl true
  def mount(_params, _session, socket) do
    organizacoes = EO.list_organizations(socket.assigns.current_tenant)

    {:ok,
     assign(socket,
       page_title: "Roles",
       renaming: nil,
       organizacoes: organizacoes,
       # A primeira como padrão. Com zero organizações a tela não tem o que mostrar, e o
       # estado vazio diz isso em vez de estourar.
       organizacao_id: organizacoes |> List.first() |> then(&(&1 && &1.id))
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  def handle_event("trocar_organizacao", %{"organization_id" => id}, socket),
    do: {:noreply, socket |> assign(organizacao_id: id, renaming: nil) |> load()}

  def handle_event("create", %{"code" => code, "name" => name}, socket) do
    case EO.create_role(
           socket.assigns.current_tenant,
           socket.assigns.organizacao_id,
           %{code: code, name: name},
           socket.assigns.current_user.id
         ) do
      {:ok, papel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role #{papel.code} registered in this organisation.")
         |> load()}

      # Erro previsto de negócio chega nomeado, e a frase diz o escopo: o mesmo código em
      # outra organização é aceito, e quem lê precisa saber disso para não achar que é global.
      {:error, :code_taken} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This organisation already has a role with this code. Another organisation may."
         )}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Could not register: #{errors(changeset)}")}
    end
  end

  def handle_event("ask_rename", %{"id" => id}, socket),
    do: {:noreply, assign(socket, renaming: id)}

  def handle_event("cancel_rename", _params, socket),
    do: {:noreply, assign(socket, renaming: nil)}

  def handle_event("rename", %{"role_id" => id, "name" => name}, socket) do
    case EO.rename_role(
           socket.assigns.current_tenant,
           id,
           name,
           socket.assigns.current_user.id
         ) do
      {:ok, papel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Renamed to #{papel.name}. The code is unchanged.")
         |> assign(renaming: nil)
         |> load()}

      {:error, :blank_name} ->
        {:noreply, put_flash(socket, :error, "The name cannot be empty.")}

      # Nome de papel do catálogo vem da rede. Editá-lo aqui produziria divergência silenciosa
      # com o YAML — a mesma razão de o catálogo ser composto e não semeado.
      {:error, :from_catalog} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This role comes from the ontology. Its name is defined there, not here."
         )
         |> assign(renaming: nil)}

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Role not found.") |> assign(renaming: nil)}
    end
  end

  # **Ocultar, e nunca apagar.** Papel do catálogo vem da rede e não é apagável; papel
  # declarado com histórico também não deveria sumir. Ocultar tira da escolha e preserva.
  def handle_event("hide", %{"id" => id}, socket) do
    case EO.hide_role(socket.assigns.current_tenant, id, socket.assigns.current_user.id) do
      {:ok, papel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role #{papel.code} hidden from this organisation.")
         |> load()}

      # A recusa diz **quantos**, e não só que não pode: quem lê precisa saber o tamanho do
      # que a impede, como no impacto exibido antes de encerrar uma observação.
      {:error, {:in_use, quantos}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "#{quantos} membership(s) use this role. Hiding it would leave them pointing at a role no one can see."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Role not found.")}
    end
  end

  def handle_event("unhide", %{"id" => id}, socket) do
    case EO.unhide_role(socket.assigns.current_tenant, id, socket.assigns.current_user.id) do
      {:ok, papel} ->
        {:noreply, socket |> put_flash(:info, "Role #{papel.code} is back.") |> load()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Role not found.")}
    end
  end

  defp caminho(socket, id, mudancas), do: ~p"/roles?#{Tabela.query(socket, id, mudancas)}"

  # Mesma forma que `SourceLive.Index` usa: a mensagem do changeset chega à tela nomeando o
  # campo, e não como `inspect` de estrutura.
  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    estado = socket.assigns.tabelas["roles"]

    papeis =
      if socket.assigns.organizacao_id,
        do: EO.list_organization_roles(tenant, socket.assigns.organizacao_id),
        else: []

    filtrados =
      Enum.filter(papeis, fn p ->
        estado.busca == "" or
          String.contains?(String.downcase("#{p.code} #{p.name}"), String.downcase(estado.busca))
      end)

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(roles: Enum.take(filtrados, @por_pagina))
    |> assign(encontrados: length(filtrados))
    # Quantas evidências esperam por um papel — é o que transforma "lista vazia" em
    # "bloqueio", e sem ele ninguém sabe que a ausência tem custo.
    |> assign(evidencias_pendentes: EO.count_evidence_pending_role(tenant))

    # `sugestoes` deixou de existir: os quatro do Scrum agora vêm **na lista**, compostos, e
    # não como preenchimento de formulário. A `FR-002` pede disponibilidade, não sugestão.
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Roles
        <:subtitle>
          What this organisation recognises as an organisational role
        </:subtitle>
      </.header>

      <%!-- O escopo é a ORGANIZAÇÃO. Antes era o tenant, e um papel vazava para as três —
            que não compartilham vocabulário nenhum. Issue #317. --%>
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span class="opacity-60">organisation:</span>
        <button
          :for={org <- @organizacoes}
          class={[
            "btn btn-xs",
            if(@organizacao_id == org.id, do: "btn-primary", else: "btn-ghost")
          ]}
          phx-click="trocar_organizacao"
          phx-value-organization_id={org.id}
        >
          {org.login}
        </button>
      </div>

      <div :if={@organizacoes == []} class="alert block">
        <p>
          No organisation observed yet. Roles belong to an organisation, so there is nothing to show.
        </p>
      </div>

      <%!-- O aviso mudou de sentido. Antes a lista vinha vazia e as evidências ficavam
            bloqueadas; agora os quatro do Scrum estão sempre lá, então o que resta é o
            trabalho de confirmar. --%>
      <div :if={@evidencias_pendentes > 0} class="alert block">
        <p class="font-semibold">
          {@evidencias_pendentes} observed participations are waiting for confirmation.
        </p>
        <p class="text-sm">
          The roles below are available — the four from the ontology need no registration. Each
          participation becomes a membership when someone confirms it on the team's page.
        </p>
      </div>

      <div class="card bg-base-200 p-4 space-y-3">
        <div class="text-sm font-semibold">Register a role</div>

        <form phx-submit="create" class="flex flex-wrap gap-2 items-end">
          <label class="fieldset">
            <span class="label-text text-xs">Code</span>
            <input name="code" class="input input-bordered input-sm" placeholder="developer" />
          </label>
          <label class="fieldset">
            <span class="label-text text-xs">Name</span>
            <input name="name" class="input input-bordered input-sm" placeholder="Developer" />
          </label>
          <.button type="submit" variant="primary">Register</.button>
        </form>

        <%!-- Os quatro do Scrum NÃO estão aqui. Eles vivem na lista abaixo, disponíveis sem
              cadastro — a FR-002 pede disponibilidade, e um botão de preencher formulário
              seria cadastro prévio com outro nome. --%>
        <div class="text-xs opacity-70">
          The four Scrum roles are already available below. Register here what the ontology does
          not name — <span class="font-mono">tech_lead</span>, <span class="font-mono">designer</span>,
          whatever this organisation uses. It will exist <strong>only here</strong>.
        </div>
      </div>

      <.data_table
        id="roles"
        rows={@roles}
        estado={@tabelas["roles"]}
        por_pagina={@por_pagina}
        total={@encontrados}
        onde="code and name"
        vazio="No role matches this search."
      >
        <:col :let={papel} field={:code} label="code" class="font-mono text-xs">
          {papel.code}
        </:col>
        <%!-- A origem fica VISÍVEL, e não inferida do nome. Sem ela, em seis meses ninguém
              sabe se `scrum_master` veio da rede ou alguém digitou. FR-003. --%>
        <:col :let={papel} label="origin">
          <span :if={elem(papel.origem, 0) == :catalogo} class="badge badge-outline badge-sm gap-1">
            ontology <span class="font-mono text-[0.65rem] opacity-60">{elem(papel.origem, 1)}</span>
          </span>
          <span
            :if={elem(papel.origem, 0) == :catalogo_removido}
            class="badge badge-warning badge-sm"
            title="A rede não nomeia mais este conceito. Os vínculos continuam válidos."
          >
            no longer in the ontology
          </span>
          <span :if={elem(papel.origem, 0) == :declarado} class="badge badge-ghost badge-sm">
            declared here
          </span>
          <span :if={papel.hidden_at} class="badge badge-sm ml-1 italic opacity-60">hidden</span>
        </:col>
        <:col :let={papel} field={:name} label="name">
          <%!-- `@renaming == papel.id` é armadilha aqui: papel do catálogo tem `id` NULO, e
                `nil == nil` é verdadeiro. Sem o `papel.id &&`, os quatro do catálogo
                renderizam o formulário ao mesmo tempo, todos com `id="rename-"` — IDs
                duplicados que o LiveView recusa, e com razão. --%>
          <form
            :if={not is_nil(papel.id) and @renaming == papel.id}
            id={"rename-#{papel.id}"}
            phx-submit="rename"
            class="flex items-center gap-1"
          >
            <input type="hidden" name="role_id" value={papel.id} />
            <input
              type="text"
              name="name"
              value={papel.name}
              class="input input-xs input-bordered w-40"
            />
            <button type="submit" class="btn btn-xs btn-primary">save</button>
            <button type="button" class="btn btn-xs btn-ghost" phx-click="cancel_rename">
              cancel
            </button>
          </form>
          <span :if={is_nil(papel.id) or @renaming != papel.id}>{papel.name}</span>
        </:col>
        <:col :let={papel} label="">
          <%!-- Renomear só o declarado: o nome do papel de catálogo vem da rede, e editá-lo
                aqui produziria divergência silenciosa com o YAML. --%>
          <button
            :if={
              not is_nil(papel.id) and @renaming != papel.id and elem(papel.origem, 0) == :declarado
            }
            class="btn btn-xs btn-ghost"
            phx-click="ask_rename"
            phx-value-id={papel.id}
          >
            rename
          </button>
          <%!-- Ocultar, nunca apagar. E só há o que ocultar depois de a linha existir — papel
                do catálogo sem uso tem `id` nulo. --%>
          <button
            :if={not is_nil(papel.id) and is_nil(papel.hidden_at)}
            class="btn btn-xs btn-ghost text-error"
            phx-click="hide"
            phx-value-id={papel.id}
            data-confirm="Hide this role from this organisation? Existing memberships keep it."
          >
            hide
          </button>
          <button
            :if={not is_nil(papel.id) and not is_nil(papel.hidden_at)}
            class="btn btn-xs btn-ghost"
            phx-click="unhide"
            phx-value-id={papel.id}
          >
            unhide
          </button>
        </:col>
      </.data_table>

      <p class="text-xs opacity-60">
        The <strong>code</strong>
        is the identity: memberships reference it, and renaming changes only the label — there is
        no way to change a code. Roles from the ontology cannot be renamed or deleted here; they
        can be <strong>hidden</strong>
        from this organisation. A role in use cannot be hidden, and the refusal says how many
        memberships hold it.
      </p>
    </Layouts.app>
    """
  end
end
