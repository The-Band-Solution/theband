defmodule TheBandWeb.AILive.Index do
  @moduledoc """
  `/ai` — a chave do provedor de modelo de linguagem desta organização.

  **Operacional, e não só de admin** (R2 de `specs/064-segredo-em-repouso/seguranca-c1-mesma-chave.md`).
  A rota está na `live_session :operacao` (`router.ex`), como `/tools`: entra quem administra e
  quem tem concessão `organization` vigente. A pessoa mantenedora decidiu assim em 2026-08-28 —
  a chave é uma só do tenant, e o recorte por organização não a divide. Quem avalia a
  superfície desta tela avalia essa, e não "só admin".

  ## A idade da chave, e o pedido de troca (064/T018)

  `key registered` mostra desde quando a chave em uso vale, com a marca de
  `TheBand.Credenciais.Idade` (protótipo aprovado em 2026-10-03, régua 2.1–2.10). Pedir, e não
  impedir: nada aqui desabilita a gravação nem a geração. A chave do ambiente é sempre
  **idade desconhecida** — ela não tem linha nem data (achado 3 da avaliação de segurança).

  ## A tela nomeia de onde a chave vem, e não só se existe

  São três fatos, e não dois. Gravada para este tenant é uma coisa; herdada do `API_KEY` do
  processo é outra — ela é **compartilhada por toda instalação**, e numa com dois tenants a
  conta de um pagaria pelo outro. Mostrar as duas como "configurado" esconderia isso.

  ## Nada é gravado sem ter sido conferido

  A chave é conferida contra `/models` **antes** de qualquer escrita, e cada recusa tem
  frase própria — recusada, provedor inalcançável, e chave aceita sem modelo algum. As três
  pedem ação diferente de quem lê: gerar outra chave, tentar de novo, e olhar a conta.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.IdadeDaCredencial, only: [idade: 1, marca: 1, aviso: 1]

  alias TheBand.AI
  alias TheBand.AI.ProviderCredential
  alias TheBand.Credenciais.Idade
  alias TheBand.Sources
  alias TheBandWeb.IdadeDaCredencial

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "AI provider") |> carregar()}
  end

  @impl true
  def handle_event("save", params, socket) do
    tenant = socket.assigns.current_tenant
    # A data em uso ANTES, lida do banco no tenant corrente e no mesmo evento — é dela, e não
    # de nada que o formulário mande, que sai a frase da mesma chave (C.1, condição 2).
    antes = data_em_uso(tenant)

    case AI.put(tenant, params, socket.assigns.current_user.id) do
      {:ok, cred} ->
        {:noreply,
         socket
         |> put_flash(:info, frase_gravada(antes, cred))
         |> carregar()}

      # Cada recusa diz o que fazer em seguida, e todas terminam em "nothing was saved" —
      # sem isso, quem lê fica sem saber se a chave anterior sobreviveu.
      {:error, {:rejeitada, motivo}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "The provider refused the key: %{motivo}. Nothing was saved.",
             motivo: motivo
           )
         )}

      {:error, {:indisponivel, motivo}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext(
             "errors",
             "Could not reach the provider: %{motivo}. The key was not checked, so nothing was saved — it may well be valid.",
             motivo: motivo
           )
         )}

      {:error, {:sem_modelos, motivo}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext(
             "errors",
             "%{motivo}. A key that reaches no model would fail on the first generation, an hour later and for somebody else. Nothing was saved.",
             motivo: motivo
           )
         )}

      {:error, {:modelo_desconhecido, pedido, disponiveis}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext(
             "errors",
             "This key does not reach the model %{pedido}. It reaches: %{disponiveis}. Nothing was saved.",
             pedido: pedido,
             disponiveis: Enum.join(Enum.take(disponiveis, 8), ", ")
           )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "Could not save: %{errors}", errors: errors(changeset))
         )}
    end
  end

  def handle_event("delete", _params, socket) do
    case AI.delete(socket.assigns.current_tenant) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           dgettext("sistema", "Key removed. The secret is gone — there is no history of it.")
         )
         |> carregar()}

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "There is no key saved for this organisation.")
         )}
    end
  end

  # Três frases, e cada uma vem de comparar a data em uso antes com a de depois (2.7, 2.8 e C.1).
  # A comparação é de DATA, não de segredo: a do segredo é de `AI.put/3`, só depois de o
  # provedor aceitar a chave (condição 1), e não sai de lá.
  defp frase_gravada(:nenhuma, cred) do
    dgettext("sistema", "Key checked against the provider and saved (%{masked}).",
      masked: masked(cred)
    )
  end

  # Sem data anterior, a tela não afirma troca nem mesma chave: não tem como saber qual foi.
  defp frase_gravada({:antes, nil, _anterior_da_anterior}, cred),
    do: frase_gravada(:nenhuma, cred)

  defp frase_gravada({:antes, %DateTime{} = antes, anterior_da_anterior}, cred) do
    # As DUAS datas, e não só a de início: uma troca no mesmo segundo da gravação anterior
    # deixa `secret_set_at` igual ao de antes, e só `previous_secret_set_at` a denuncia — a
    # mesma chave não o toca (`AI.put/3`, contrato da T019).
    if mesma_data?(antes, Idade.em_uso_desde(cred)) and
         mesma_data?(anterior_da_anterior, cred.previous_secret_set_at) do
      dgettext(
        "sistema",
        "Key checked against the provider and saved (%{masked}). It is the key already registered, so it still counts from %{data}.",
        masked: masked(cred),
        data: IdadeDaCredencial.data(antes)
      )
    else
      dgettext(
        "sistema",
        "Key checked against the provider and saved (%{masked}). It replaces the key registered on %{data}; the count starts again today.",
        masked: masked(cred),
        data: IdadeDaCredencial.data(antes)
      )
    end
  end

  defp mesma_data?(%DateTime{} = antes, %DateTime{} = depois),
    do: DateTime.compare(antes, depois) == :eq

  defp mesma_data?(nil, nil), do: true
  defp mesma_data?(_antes, _depois), do: false

  defp data_em_uso(tenant) do
    case AI.fetch_sem_segredo(tenant) do
      {:ok, cred} -> {:antes, Idade.em_uso_desde(cred), cred.previous_secret_set_at}
      {:error, :not_found} -> :nenhuma
    end
  end

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
      <%!-- Reunidas na navegação (#428): quem procura "com que conta a plataforma
            trabalha" acha aqui, sem precisar saber que existe um endereço /ai. As telas
            continuam separadas — cada uma faz uma coisa. --%>
      <.abas abas={[
        %{rotulo: "Connected tools", destino: ~p"/tools", atual?: false, marca: @marca_tools},
        %{rotulo: "AI provider", destino: ~p"/ai", atual?: true, marca: @marca_ai}
      ]} />
      <.header>
        Language model provider
        <:subtitle>
          Which account this organisation uses to generate competence profiles.
        </:subtitle>
      </.header>

      <div class="card bg-base-200 p-6 space-y-3">
        <div class="text-sm font-semibold">Key in use</div>

        <div :if={match?({:tenant, _}, @origem)} class="space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <span class="badge badge-success">saved for this organisation</span>
            <span class="font-mono text-sm">{masked(elem(@origem, 1))}</span>
          </div>

          <.pedido_da_chave credencial={elem(@origem, 1)} agora={@agora} />

          <dl class="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
            <div>
              <dt class="opacity-70">provider</dt>
              <dd class="font-mono">{elem(@origem, 1).provider}</dd>
            </div>
            <div>
              <dt class="opacity-70">model</dt>
              <dd class="font-mono">
                <span :if={elem(@origem, 1).default_model}>{elem(@origem, 1).default_model}</span>
                <%!-- Modelo em branco é escolha, e não falta: significa o padrão do provedor.
                      Um travessão aqui faria parecer que alguém esqueceu de preencher. --%>
                <.absent
                  :if={is_nil(elem(@origem, 1).default_model)}
                  reason="the provider default, because none was chosen"
                />
              </dd>
            </div>
            <div id="key-registered">
              <dt class="opacity-70">key registered</dt>
              <dd>
                <.idade
                  credencial={elem(@origem, 1)}
                  agora={@agora}
                  sem_data="the platform has no date for this key"
                />
              </dd>
            </div>
            <div>
              <dt class="opacity-70">checked against the provider at</dt>
              <dd class="font-mono">{elem(@origem, 1).validated_at}</dd>
            </div>
            <%!-- FR-018: a data da chave anterior não se perde; o segredo, sim (D6, 2.7). --%>
            <div
              :if={elem(@origem, 1).previous_secret_set_at && elem(@origem, 1).secret_set_at}
              id="previous-key"
            >
              <dt class="opacity-70">previous key</dt>
              <dd class="flex flex-col gap-0.5">
                <span class="font-mono text-xs tabular-nums">
                  {IdadeDaCredencial.data(elem(@origem, 1).previous_secret_set_at)} → {IdadeDaCredencial.data(
                    elem(@origem, 1).secret_set_at
                  )}
                </span>
                <span class="text-sm">
                  in use for {IdadeDaCredencial.duracao(
                    elem(@origem, 1).previous_secret_set_at,
                    elem(@origem, 1).secret_set_at
                  )}
                </span>
                <span class="font-serif text-xs opacity-70">
                  the date is kept; the secret is gone
                </span>
              </dd>
            </div>
            <div :if={elem(@origem, 1).last_failure_at}>
              <dt class="opacity-70">last failure</dt>
              <dd class="font-mono">
                {elem(@origem, 1).last_failure_at} — {elem(@origem, 1).last_failure_reason}
              </dd>
            </div>
          </dl>

          <button
            class="btn btn-xs btn-outline btn-error"
            phx-click="delete"
            data-confirm="Remove this key? The secret stops existing, and this cannot be undone. Generation falls back to the server environment key, if there is one."
          >
            remove the key
          </button>
        </div>

        <%!-- O aviso não é sobre a chave estar errada: ela funciona. É sobre ela ser do
              **processo**, e não desta organização — e isso só aparece na fatura. --%>
        <div :if={match?({:ambiente, _}, @origem)} class="alert alert-warning block text-sm">
          <div class="font-semibold">
            Coming from the server environment (••••{elem(@origem, 1)}), not from this
            organisation.
          </div>
          <p class="mt-1 opacity-90">
            Generation works. But this key belongs to the installation: every organisation on
            this server uses it, and one organisation's usage lands on another's bill. Saving a
            key below makes this organisation use its own account.
          </p>
        </div>

        <%!-- A chave do ambiente é SEMPRE idade desconhecida, e nunca no prazo: ela é do
              processo, não tem linha nem data (achado 3; D8, 2.6). A marca é escrita aqui, e
              não calculada, porque esta chave fica fora de `Idade` por contrato. --%>
        <div :if={match?({:ambiente, _}, @origem)} id="env-key-age" class="space-y-3">
          <dl class="text-sm">
            <dt class="opacity-70">key registered</dt>
            <dd class="flex flex-col gap-0.5">
              <.marca estado={:idade_desconhecida} />
              <span class="font-serif text-xs opacity-70">
                The key was set in the server environment, and the platform never recorded when.
                The absence is the platform's, not the provider's.
              </span>
            </dd>
          </dl>
          <.aviso
            forma={:desconhecida}
            titulo={"This key's age is unknown, so it is not counted as within #{@limite} months."}
          >
            <p>
              Whoever runs the server replaces it, in the server's environment settings. Or save
              a key for this organisation below: its age is recorded from the day it is saved.
            </p>
          </.aviso>
        </div>

        <div :if={@origem == :nenhuma}>
          <.absent reason="No key saved, and none in the server environment — profile generation cannot run." />
        </div>
      </div>

      <div class="card bg-base-200 p-6">
        <form id="ai-credential" phx-submit="save" class="space-y-4">
          <label class="fieldset">
            <span class="label-text">API key</span>
            <input
              type="password"
              name="secret"
              class="input input-bordered"
              autocomplete="off"
              placeholder="sk-..."
            />
            <span class="label-text-alt opacity-70">
              Checked against the provider before being written, encrypted at rest, and never
              shown again — only the last four characters, so one key can be told from another.
            </span>
          </label>

          <label class="fieldset">
            <span class="label-text">Model (optional)</span>
            <input
              name="default_model"
              class="input input-bordered"
              autocomplete="off"
              placeholder="leave empty for the provider default"
            />
            <span class="label-text-alt opacity-70">
              Only accepted if the provider lists it for this key. A name it does not list is
              refused here, and not silently replaced.
            </span>
          </label>

          <.button type="submit" variant="primary">Check and save</.button>
        </form>

        <p class="text-xs opacity-60 mt-4">
          Saving a different key replaces the previous one and starts the count again; the date
          the previous key was registered is kept, the secret is not. Saving the same key again
          keeps its date.
        </p>
      </div>
    </Layouts.app>
    """
  end

  # O pedido da chave (2.2, 2.5 e Q2): um estado por cláusula, sem coringa (achado 4). Todo o
  # texto vai para a tela, e por isso é inglês de propósito.
  attr :credencial, ProviderCredential, required: true
  attr :agora, DateTime, required: true

  defp pedido_da_chave(assigns) do
    assigns =
      assign(assigns,
        estado: Idade.estado(assigns.credencial, assigns.agora),
        desde: Idade.em_uso_desde(assigns.credencial),
        limite: Idade.limite_em_meses()
      )

    case assigns.estado do
      :vencida ->
        ~H"""
        <.aviso forma={:vencida} titulo="Replace this key." id="key-request">
          <p>
            It was registered <b>{IdadeDaCredencial.intervalo(@desde, @agora)}</b>, on {IdadeDaCredencial.data(
              @desde
            )}. The platform asks for a new key {@limite} months after one is saved.
          </p>
          <p>Profile generation goes on with this key meanwhile. Nothing stops and nothing is blocked.</p>
          <p>
            Generate a new key at the provider, paste it in the form below, then revoke the old one
            at the provider.
          </p>
          <:quem>
            Who can replace it: an administrator, or anyone with access to Connected tools. The key
            is one for the whole organisation.
          </:quem>
        </.aviso>
        """

      :idade_desconhecida ->
        ~H"""
        <.aviso forma={:desconhecida} titulo="The age of this key is unknown." id="key-request">
          <p>
            The platform has no record of when it was saved, so it cannot tell whether it is due.
            Replacing it starts a dated count.
          </p>
        </.aviso>
        """

      :no_prazo ->
        ~H""
    end
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    agora = DateTime.utc_now(:second)
    origem = AI.origem_da_chave(tenant)

    # A marca da aba "Connected tools" olha só as ferramentas DO RECORTE: quem responde por uma
    # organização não fica sabendo, nem por marca, de credencial vencida de outra (4.2).
    credenciais_das_ferramentas =
      tenant
      |> Sources.list_connected_tools()
      |> TheBandWeb.Operacao.filtrar_tools(socket.assigns.operacao, tenant)
      |> Enum.flat_map(& &1.credentials)

    assign(socket,
      origem: origem,
      agora: agora,
      limite: Idade.limite_em_meses(),
      marca_tools: IdadeDaCredencial.marca_da_aba(credenciais_das_ferramentas, agora),
      marca_ai: marca_da_chave(origem, agora)
    )
  end

  # A do ambiente não acende a marca: ela não tem data, e "replace" afirmaria um prazo vencido
  # que ninguém mediu. O aviso dela é outro (2.6).
  defp marca_da_chave({:tenant, cred}, agora), do: IdadeDaCredencial.marca_da_aba([cred], agora)
  defp marca_da_chave({:ambiente, _ultimos}, _agora), do: nil
  defp marca_da_chave(:nenhuma, _agora), do: nil

  defp masked(cred), do: ProviderCredential.masked(cred)

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
