defmodule TheBandWeb.AccountsLive.Index do
  @moduledoc """
  `/accounts` — as contas do tenant, para quem administra (feature 045, US1;
  feature 051: a área única do onboarding).

  **A tela é exatamente a do protótipo aprovado** —
  `specs/045-autenticacao-e-acesso/prototipo/accounts-disable.html`, seção 3 do
  `PROMPT.md`. Divergência é defeito, não melhoria de implementação; mudança volta ao
  protótipo antes de voltar aqui.

  ## O achado que esta tela existe para fechar

  Antes da coluna de estado, o desligamento era **implícito**: quem administra reiniciava
  a senha e não entregava a temporária. A conta desligada aparecia como `temporary
  pending` — **igual à recém-criada** —, e o ato de rotina para a segunda (reiniciar a
  senha) **reativava** a primeira. O estado de um desligamento era indistinguível do
  estado de quem acabou de entrar na organização.

  Três coisas decorrem disso, e a tela é construída sobre elas:

    * **o estado da conta e o da credencial são dois fatos, logo duas colunas** — uma
      célula só é o que fez um desligamento parecer um primeiro dia;
    * **todo ato diz o que faz e o que não faz**, no lugar do ato — porque o ato que
      parecia desligamento não era;
    * **nada é apagado** — a desativação é episódio com autor, data e razão, e reativar
      **fecha** o episódio em vez de o apagar.

  ## Cadastro, elo e a temporária

  Cadastro é ato administrativo (assumption da spec): não há auto-registro. Desde a 051 a
  conta nasce COM a temporária — `cadastrar_conta/3` cria e emite numa transação, e a
  temporária aparece UMA vez, vive só no assign, e o próximo evento a apaga. Não é gravada
  em claro nem logada.

  O elo conta↔pessoa do GitHub se administra AQUI (051, US2). A marca de administrador
  (`users.role`) é gestão, não visão (FR-022): dar a marca aqui não abre painel nenhum —
  escopo se concede em /access-scopes.

  ## A recusa fica na tela

  `Reset password` na conta desativada e `Disable` na própria linha **ficam no lugar**,
  inertes, com a razão ao lado. Botão que desaparece faz quem procura concluir que a
  plataforma não sabe fazer aquilo — e foi o que produziu o desligamento improvisado.

  ## O que esta tela NÃO consegue afirmar sozinha

  `4 can sign in today` é verdade **enquanto a organização estiver ativa**. `tenants.status`
  existe, aceita `"suspended"` e — quando este protótipo foi desenhado — não era lido em
  lugar nenhum (H3 parte A). A faixa do topo diz isso quando a organização não está ativa;
  é a recomendação (a) da pergunta aberta 14.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.AccountDisablement
  alias TheBand.Tenants.AccountLifecycle
  alias TheBand.Tenants.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Accounts",
       temporaria: nil,
       erro: nil,
       busca: nil,
       desativando: nil,
       reativando: nil,
       filtro: "all"
     )
     |> carregar()}
  end

  # A lista com o elo, o histórico e os escopos em CONSULTAS FIXAS — contas, logins das
  # vinculadas, episódios e concessões —, nunca uma por linha (L38). É a forma de
  # `esperas_dos_cartoes/3` na 060: quem chama passa o conjunto e recebe um mapa.
  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    users = Tenants.list_users(tenant)
    ids = Enum.map(users, & &1.id)

    vinculadas =
      users
      |> Enum.filter(&(&1.person_id && is_nil(&1.person_revoked_at)))
      |> Enum.map(& &1.person_id)

    assign(socket,
      users: users,
      logins: EO.person_logins(tenant, vinculadas),
      historico: Tenants.historico_de_acesso(tenant, ids),
      escopos: Tenants.concessoes_vigentes_por_conta(tenant, ids),
      autores: autores(users)
    )
  end

  # Quem desativou, quem reativou, quem emitiu a credencial — nomes, e não uuids. O mapa
  # sai da lista que já está em memória: as contas do tenant são todas conhecidas, e um
  # `Repo.get` por autoria seria uma consulta por linha.
  defp autores(users), do: Map.new(users, &{&1.id, &1.name || &1.email})

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

  def handle_event("filtrar", %{"filtro" => filtro}, socket) do
    {:noreply, assign(socket, filtro: filtro)}
  end

  # ── O elo, administrado na área (051/US2) ──

  def handle_event("abrir_busca", %{"user-id" => user_id}, socket) do
    {:noreply, assign(socket, busca: %{user_id: user_id, q: "", resultados: [], orgs: %{}})}
  end

  def handle_event("fechar_busca", _params, socket) do
    {:noreply, assign(socket, busca: nil)}
  end

  # A consulta roda no EVENTO da digitação, nunca no mount (contrato). O resultado traz
  # nome, login E organização — o edge case dos homônimos que spec/contrato/tasks sempre
  # pediram; a versão anterior divergia num comentário sem corrigir contrato nenhum, e a
  # US caiu na aceitação por isso (L82, 051/T009 #618). Duas consultas por página de
  # resultados, nunca por linha (L38). A observação terminada também é dita — gente sai
  # do GitHub sem sair da organização.
  def handle_event("buscar_pessoa", %{"q" => q}, socket) do
    tenant = socket.assigns.current_tenant

    {resultados, orgs} =
      if String.trim(q) == "" do
        {[], %{}}
      else
        pessoas = EO.list_people(tenant, search: q, limit: 8)
        {pessoas, EO.observed_org_logins_of_people(tenant, Enum.map(pessoas, & &1.id))}
      end

    {:noreply,
     assign(socket, busca: %{socket.assigns.busca | q: q, resultados: resultados, orgs: orgs})}
  end

  def handle_event("associar", %{"user-id" => user_id, "person-id" => person_id}, socket) do
    case Tenants.declare_person(
           socket.assigns.current_tenant,
           user_id,
           person_id,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply, socket |> assign(erro: nil, busca: nil, temporaria: nil) |> carregar()}

      # Cenário 3 da US2: a recusa NOMEIA a conta dona — a leitura estreita roda só aqui,
      # no caminho do conflito. A garantia contra a corrida é do índice único parcial;
      # esta frase é o nome, não a defesa.
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

  # ── O episódio: abrir e fechar, cada um com o seu formulário ──

  # O formulário abre com a primeira cláusula do vocabulário JÁ escolhida. Rádio sem
  # escolha inicial obriga a inventar um estado "nenhuma", e a razão é obrigatória: o
  # estado vazio existiria só para ser recusado.
  def handle_event("abrir_desativacao", %{"id" => user_id}, socket) do
    primeira =
      case AccountLifecycle.razoes_de_desativacao() do
        [%{"code" => codigo} | _] -> codigo
        _ -> nil
      end

    {:noreply,
     assign(socket,
       desativando: %{user_id: user_id, reason: primeira, note: ""},
       reativando: nil,
       erro: nil
     )}
  end

  def handle_event("fechar_desativacao", _params, socket) do
    {:noreply, assign(socket, desativando: nil)}
  end

  # A escolha da cláusula muda a tela: `suspected_compromise` acrescenta a lista, e ela e
  # `other` passam a exigir a nota. Por isso o `phx-change` — sem ele, a lista só
  # apareceria depois de submeter, que é depois de tarde.
  def handle_event("mudar_desativacao", %{"reason" => reason} = params, socket) do
    {:noreply,
     assign(socket,
       desativando: %{
         socket.assigns.desativando
         | reason: reason,
           note: Map.get(params, "note", "")
       }
     )}
  end

  def handle_event("desativar", %{"reason" => reason} = params, socket) do
    id = socket.assigns.desativando.user_id

    case Tenants.disable_user(
           socket.assigns.current_tenant,
           id,
           socket.assigns.current_user.id,
           %{"reason" => reason, "note" => Map.get(params, "note")}
         ) do
      {:ok, _} ->
        {:noreply, socket |> assign(erro: nil, temporaria: nil, desativando: nil) |> carregar()}

      {:error, erro} ->
        {:noreply, assign(socket, erro: recusa_de_desativacao(erro), temporaria: nil)}
    end
  end

  def handle_event("abrir_reativacao", %{"id" => user_id}, socket) do
    aberto = get_in(socket.assigns.historico, [user_id, :aberto])
    abertura = aberto && aberto.disable_reason

    primeira =
      case AccountLifecycle.reativacoes_oferecidas_contra(abertura) do
        [%{"code" => codigo} | _] -> codigo
        _ -> nil
      end

    {:noreply,
     assign(socket,
       reativando: %{user_id: user_id, reason: primeira, note: "", abertura: abertura},
       desativando: nil,
       erro: nil
     )}
  end

  def handle_event("fechar_reativacao", _params, socket) do
    {:noreply, assign(socket, reativando: nil)}
  end

  def handle_event("mudar_reativacao", %{"reason" => reason} = params, socket) do
    {:noreply,
     assign(socket,
       reativando: %{
         socket.assigns.reativando
         | reason: reason,
           note: Map.get(params, "note", "")
       }
     )}
  end

  def handle_event("reativar", %{"reason" => reason} = params, socket) do
    id = socket.assigns.reativando.user_id

    case Tenants.enable_user(
           socket.assigns.current_tenant,
           id,
           socket.assigns.current_user.id,
           %{"reason" => reason, "note" => Map.get(params, "note")}
         ) do
      {:ok, _} ->
        {:noreply, socket |> assign(erro: nil, temporaria: nil, reativando: nil) |> carregar()}

      {:error, erro} ->
        {:noreply, assign(socket, erro: recusa_de_reativacao(erro), temporaria: nil)}
    end
  end

  # As recusas têm mensagens DIFERENTES, e de propósito: aqui quem lê é quem administra o
  # próprio tenant, e cada uma tem remédio distinto. É o oposto da recusa da entrada, onde
  # a mensagem é única para não enumerar.
  defp recusa_de_desativacao(:nao_pode_desativar_a_si),
    do:
      dgettext(
        "errors",
        "This is your own account — ask another administrator."
      )

  defp recusa_de_desativacao(:ja_desativada),
    do: dgettext("errors", "This account was already disabled.")

  defp recusa_de_desativacao(:vocabulario_nao_declarado),
    do:
      dgettext(
        "errors",
        "The reasons for disabling are not declared in the knowledge base (access.account_lifecycle), so no reason could be recorded."
      )

  defp recusa_de_desativacao(%Ecto.Changeset{} = changeset),
    do: dgettext("errors", "Not disabled: %{motivo}", motivo: motivo(changeset))

  defp recusa_de_desativacao(_), do: dgettext("errors", "Account not found.")

  defp recusa_de_reativacao(:ja_ativa),
    do: dgettext("errors", "This account is already active.")

  # O estado que a transação de `disable_user/4` existe para impedir. Se aparecer, a marca
  # está contradizendo o registro, e reativar sem fechar nada pioraria — a recusa nomeia o
  # que fazer em vez de esconder.
  defp recusa_de_reativacao(:sem_episodio_aberto),
    do:
      dgettext(
        "errors",
        "This account is marked disabled and has no open episode on the record. Reactivating would leave the mark contradicting the record — ask for the access log to be checked first."
      )

  defp recusa_de_reativacao(%Ecto.Changeset{} = changeset),
    do: dgettext("errors", "Not reactivated: %{motivo}", motivo: motivo(changeset))

  defp recusa_de_reativacao(_), do: dgettext("errors", "Account not found.")

  # 047/T014 (#617): mesma classe do primeira_mensagem — o catálogo traduz o erro do
  # Ecto; montado à mão, os msgids que errors.po já tem eram descartados.
  defp motivo(changeset) do
    Enum.map_join(changeset.errors, "; ", fn {campo, erro} ->
      "#{campo} #{TheBandWeb.CoreComponents.translate_error(erro)}"
    end)
  end

  # ── O que a tela deriva, e onde a palavra mora ──

  defp elo_vigente?(user), do: user.person_id && is_nil(user.person_revoked_at)

  # A COMPOSIÇÃO do cabeçalho — e cada número responde a uma pergunta diferente.
  #
  # `can_sign_in` é a conta ativa **com** credencial: ativa sem senha não entra, e contá-la
  # como quem entra seria a tela afirmando o que a porta recusa. `no_password` é dito à
  # parte porque não é desativação — ninguém decidiu nada sobre aquela conta.
  defp composicao(users) do
    %{
      total: length(users),
      entram: Enum.count(users, &(User.ativa?(&1) and &1.password_hash != nil)),
      desativadas: Enum.count(users, &(not User.ativa?(&1))),
      sem_senha: Enum.count(users, &(&1.password_hash == nil))
    }
  end

  # Desativada por último, e NUNCA escondida. O filtro é escolha explícita de quem lê:
  # conta que não se vê é conta que não se audita.
  defp linhas(users, filtro) do
    users
    |> Enum.filter(&cabe_no_filtro?(&1, filtro))
    |> Enum.sort_by(fn user ->
      {if(User.ativa?(user), do: 0, else: 1), user.name || user.email}
    end)
  end

  defp cabe_no_filtro?(_user, "all"), do: true
  defp cabe_no_filtro?(user, "entram"), do: User.ativa?(user) and user.password_hash != nil
  defp cabe_no_filtro?(user, "desativadas"), do: not User.ativa?(user)
  defp cabe_no_filtro?(_user, _outro), do: true

  # ── A coluna `Account`: pode entrar? ──

  defp estado_da_conta(user) do
    if User.ativa?(user), do: :active, else: :disabled
  end

  # ── A coluna `Sign-in credential`: entraria com o quê? ──
  #
  # O rótulo vem da base (`access.account_lifecycle.states.credential`); o detalhe é o que
  # distingue as duas temporárias EM PALAVRAS, e não só pela cor — era a colisão do achado.
  defp detalhe_da_credencial(user, autores) do
    case User.estado_da_credencial(user) do
      :no_password ->
        "sign-in refuses · this account has never had a password"

      :password_set ->
        [
          data_curta(user.password_set_at) && "set #{data_curta(user.password_set_at)}",
          ultima_entrada(user)
        ]
        |> Enum.reject(&(&1 in [nil, false]))
        |> Enum.join(" · ")

      _temporaria ->
        [
          emissao(user, autores),
          ultima_entrada(user)
        ]
        |> Enum.reject(&(&1 in [nil, false]))
        |> Enum.join(" · ")
    end
  end

  defp emissao(user, autores) do
    quando = data_curta(user.password_set_at)
    quem = user.password_set_by_user_id && autores[user.password_set_by_user_id]

    case {quando, quem} do
      {nil, _} -> nil
      {quando, nil} -> "issued #{quando}"
      {quando, quem} -> "issued #{quando} by #{quem}"
    end
  end

  # Ausência dita: `never signed in` é o que distingue a temporária do primeiro dia da
  # temporária de um reinício, e é o que a tela precisa dizer com palavras.
  defp ultima_entrada(%User{logged_in_at: nil}), do: "never signed in"

  defp ultima_entrada(%User{logged_in_at: quando}),
    do: "last signed in #{data_e_hora(quando)}"

  # ── O histórico da linha: o aberto, o último fechado, e a contagem do resto ──
  #
  # Recomendação (b) da pergunta 15: quatro episódios leem bem, e uma conta de anos com
  # uma dúzia abriria a tabela ao meio. O que não aparece continua sendo DITO.
  defp resumo_do_historico(historico, user_id), do: Map.get(historico, user_id)

  defp episodios_mostrados(nil), do: []

  defp episodios_mostrados(resumo) do
    [resumo.aberto, resumo.ultimo_fechado]
    |> Enum.reject(&is_nil/1)
  end

  # A frase da coluna `Account` numa conta ativa: ou nunca houve episódio, ou houve e
  # fechou — e as duas coisas são diferentes.
  defp historico_em_uma_linha(nil), do: "no disablement recorded"

  defp historico_em_uma_linha(%{ultimo_fechado: nil}), do: "no disablement recorded"

  defp historico_em_uma_linha(%{ultimo_fechado: fechado} = resumo) do
    quantos =
      case resumo.anteriores do
        0 -> ""
        1 -> " · 1 earlier disablement"
        n -> " · #{n} earlier disablements"
      end

    "disabled once before, on #{data_curta(fechado.disabled_at)}#{quantos}"
  end

  defp nota_do_episodio(nil), do: AccountLifecycle.frase_sem_nota()
  defp nota_do_episodio(""), do: AccountLifecycle.frase_sem_nota()
  defp nota_do_episodio(texto), do: texto

  defp autor_do_episodio(nil, _autores), do: "the author was not recorded"
  defp autor_do_episodio(id, autores), do: autores[id] || "an account no longer listed"

  # ── A nota: obrigatória onde a base declara, e opcional no resto ──

  defp nota_obrigatoria_ao_desativar?(reason),
    do: reason in AccountLifecycle.nota_exigida_ao_desativar()

  defp nota_obrigatoria_ao_reativar?(reason),
    do: reason in AccountLifecycle.nota_exigida_ao_reativar()

  defp user_por_id(users, id), do: Enum.find(users, &(&1.id == id))

  defp escopos_de(escopos, user_id), do: Map.get(escopos, user_id, 0)

  defp frase_de_escopos(0), do: "no access scope was granted to this account"
  defp frase_de_escopos(1), do: "1 access scope, kept and inert"
  defp frase_de_escopos(n), do: "#{n} access scopes, kept and inert"

  defp plural(1, singular, _plural), do: singular
  defp plural(_n, _singular, plural), do: plural

  defp data_curta(nil), do: nil
  defp data_curta(%DateTime{} = d), do: Calendar.strftime(d, "%d %b")

  defp data_e_hora(nil), do: nil
  defp data_e_hora(%DateTime{} = d), do: Calendar.strftime(d, "%d %b %H:%M")

  # ── A tela ──

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        composicao: composicao(assigns.users),
        linhas: linhas(assigns.users, assigns.filtro)
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
      operacao_menu={assigns[:operacao_menu]}
    >
      <.faixa_da_organizacao tenant={@current_tenant} />

      <div class="space-y-2">
        <p class="font-mono text-xs uppercase tracking-wide opacity-60">Settings › Accounts</p>
        <h1 class="text-2xl font-semibold">Accounts</h1>

        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          <span class="inline-flex items-center gap-1.5">
            <span class="inline-block h-2.5 w-2.5 rounded-sm bg-info"></span>
            everything here is declared by the administration
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="inline-block h-2.5 w-2.5 rounded-sm bg-primary"></span>
            the GitHub login comes from collection
          </span>
        </div>

        <p class="font-mono text-sm tabular-nums">
          {@composicao.total} {plural(@composicao.total, "account", "accounts")} · {@composicao.entram} can sign in today · {@composicao.desativadas} disabled
          · {@composicao.sem_senha} {plural(@composicao.sem_senha, "has", "have")} no password
        </p>

        <p class="max-w-3xl font-serif text-sm opacity-80">
          Who signs in to this organisation, which GitHub account belongs to whom, and <strong>how someone's access is removed</strong>. There is no self-registration:
          an account is created here, and it is disabled here.
        </p>
      </div>

      <div :if={@erro} role="alert" class="alert alert-error font-serif text-sm">{@erro}</div>

      <.nota_da_tela />

      <.remocao_de_acesso />

      <%!-- ── Create an account ── --%>
      <div class="card bg-base-200 p-6">
        <h2 class="text-sm font-semibold">Create an account</h2>
        <p class="mb-3 font-mono text-xs opacity-60">
          creating is an administrative act — there is no self-registration
        </p>
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
          The account is born with a temporary password, shown once, below. The GitHub link
          is made on the row.
        </p>

        <div
          :if={@temporaria}
          role="status"
          class="mt-4 rounded border-2 border-warning bg-base-100 p-4 text-sm"
        >
          <p class="font-mono text-xs uppercase tracking-wide">
            temporary password — shown only now
          </p>
          <p class="my-1 font-mono text-lg">{@temporaria.senha}</p>
          <p class="opacity-70">
            Hand it over through your own channel. The first sign-in with it forces a new
            password. It is not stored in the clear and it is not written to any log — <strong>if you leave this screen it is gone, and the way back is another reset</strong>.
          </p>
        </div>
      </div>

      <%!-- ── The accounts ── --%>
      <div class="space-y-3">
        <div>
          <h2 class="text-sm font-semibold">The accounts</h2>
          <p class="font-mono text-xs opacity-60">
            {length(@linhas)} {plural(length(@linhas), "row", "rows")} · disabled last, and never hidden
          </p>
        </div>

        <p class="max-w-3xl font-serif text-sm opacity-80">
          <strong>Two columns for two facts.</strong>
          <span class="font-mono text-xs">Account</span>
          answers <em>can this person sign in at all?</em>;
          <span class="font-mono text-xs">Sign-in credential</span>
          answers <em>what would they sign in with?</em>. They used to be one cell, and one cell is
          what made a shutdown look like a first day.
        </p>

        <div class="flex flex-wrap items-center gap-2">
          <button
            :for={
              {chave, rotulo, n} <- [
                {"all", "all", @composicao.total},
                {"entram", "can sign in", @composicao.entram},
                {"desativadas", "disabled", @composicao.desativadas}
              ]
            }
            phx-click="filtrar"
            phx-value-filtro={chave}
            class={[
              "btn btn-xs font-mono",
              @filtro == chave && "btn-primary",
              @filtro != chave && "btn-ghost"
            ]}
          >
            {rotulo} {n}
          </button>
          <p class="text-xs opacity-60">
            A disabled account is never filtered out by default — an account you cannot see
            is an account you cannot audit.
          </p>
        </div>

        <div class="card bg-base-200 overflow-x-auto p-0">
          <table class="table">
            <thead>
              <tr>
                <th>Person</th>
                <th>GitHub</th>
                <th>Management</th>
                <th>Account</th>
                <th>Sign-in credential</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for user <- @linhas do %>
                <tr class={[not User.ativa?(user) && "bg-base-300/40"]}>
                  <td>
                    <p class="font-semibold">{user.name}</p>
                    <p class="font-mono text-xs opacity-60">{user.email}</p>
                  </td>

                  <td>
                    <.celula_do_elo user={user} logins={@logins} busca={@busca} />
                  </td>

                  <td>
                    <span :if={user.role == "admin"} class="badge badge-primary badge-sm">
                      administrator
                    </span>
                    <span :if={user.role != "admin"} class="opacity-50">—</span>
                  </td>

                  <%!-- A COLUNA DA CONTA: pode entrar? Só isto, e nada da credencial. --%>
                  <td>
                    <.estado_da_conta_celula
                      user={user}
                      resumo={resumo_do_historico(@historico, user.id)}
                      autores={@autores}
                    />
                  </td>

                  <%!-- A COLUNA DA CREDENCIAL: entraria com o quê? O rótulo vem da base. --%>
                  <td>
                    <p class={[
                      "font-mono text-xs",
                      User.estado_da_credencial(user) == :no_password && "opacity-70",
                      User.estado_da_credencial(user) in [
                        :temporary_from_creation,
                        :temporary_from_reset,
                        :temporary_source_not_recorded
                      ] && "text-warning"
                    ]}>
                      {AccountLifecycle.rotulo_de_credencial(User.estado_da_credencial(user))}
                    </p>
                    <p class="text-xs opacity-60">
                      <span :if={not User.ativa?(user)}>
                        kept, and it opens nothing while the account is disabled ·
                      </span>
                      {detalhe_da_credencial(user, @autores)}
                    </p>
                  </td>

                  <td class="text-right align-top">
                    <.acoes_da_linha user={user} current_user={@current_user} />
                  </td>
                </tr>

                <%!-- A LINHA DO HISTÓRICO, ligada por barra e rótulo. Nada aqui é apagado. --%>
                <tr
                  :if={episodios_mostrados(resumo_do_historico(@historico, user.id)) != []}
                  class={[not User.ativa?(user) && "bg-base-300/40"]}
                >
                  <td colspan="6" class="pt-0">
                    <.historico_da_conta
                      user={user}
                      resumo={resumo_do_historico(@historico, user.id)}
                      autores={@autores}
                      escopos={escopos_de(@escopos, user.id)}
                    />
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <.legenda />
      </div>

      <.formulario_de_desativacao
        :if={@desativando}
        desativando={@desativando}
        user={user_por_id(@users, @desativando.user_id)}
      />

      <.formulario_de_reativacao
        :if={@reativando}
        reativando={@reativando}
        user={user_por_id(@users, @reativando.user_id)}
        resumo={resumo_do_historico(@historico, @reativando.user_id)}
        autores={@autores}
        escopos={escopos_de(@escopos, @reativando.user_id)}
      />

      <.o_que_nao_muda tenant={@current_tenant} entram={@composicao.entram} />
    </Layouts.app>
    """
  end

  # A organização suspensa — pergunta aberta 14, recomendação (a).
  #
  # A porta **lê** `tenants.status` desde o H3 parte A: a entrada recusa quando a
  # organização não está ativa. A faixa existe porque a contagem do cabeçalho é sobre
  # contas, e com a organização fechada nenhuma delas entra — sem a faixa, o número
  # afirmaria o contrário da porta.
  defp faixa_da_organizacao(assigns) do
    ~H"""
    <div
      :if={@tenant.status != "active"}
      role="alert"
      class="alert alert-warning font-serif text-sm"
    >
      <div>
        <p class="font-semibold">
          This organisation is <span class="font-mono">{@tenant.status}</span> — nobody signs in
          today.
        </p>
        <p>
          The counts below are about accounts, not about the door. Sign-in refuses every
          account of a suspended organisation, whatever its own state says.
        </p>
      </div>
    </div>
    """
  end

  defp nota_da_tela(assigns) do
    ~H"""
    <div class="card border border-base-300 bg-base-200 p-5">
      <p class="font-mono text-xs uppercase tracking-wide opacity-60">
        what this screen is, and the finding it exists to close
      </p>
      <p class="mt-2 max-w-3xl font-serif text-sm">
        Before this design, the shutdown was <strong>implicit</strong>: whoever administered
        reset the password and did not hand the temporary over. The account of someone who
        had left then read <span class="font-mono text-xs">temporary pending</span>
        — <strong>the same words as an account created yesterday</strong>
        — and the routine act
        for the second one (reset the password) <strong>brought the first one back</strong>.
        The state of a shutdown was indistinguishable from the state of someone who had just
        joined the organisation.
      </p>
      <ul class="mt-3 max-w-3xl list-disc space-y-1 pl-5 font-serif text-sm opacity-80">
        <li>
          <strong>the account's state and the credential's state are two facts, so they are
          two columns</strong>;
        </li>
        <li>
          <strong>every act says what it does and what it does not do</strong>, in place,
          because the act that looked like a shutdown was not one;
        </li>
        <li>
          <strong>nothing is erased</strong> — a disablement is an episode with an author, a
          date and a reason, and bringing the account back closes the episode instead of
          deleting it.
        </li>
      </ul>
    </div>
    """
  end

  # O PROCEDIMENTO NA TELA — e a razão de ele não viver só no documento.
  #
  # `docs/producao/desligar-alguem.md` existe **porque** o ato que funcionava não estava
  # escrito. Quem administra faz o que a interface oferece: se a interface não diz qual dos
  # três atos remove acesso, a escolha sai do hábito.
  defp remocao_de_acesso(assigns) do
    ~H"""
    <div class="space-y-3">
      <div>
        <h2 class="text-sm font-semibold">Removing someone's access</h2>
        <p class="font-mono text-xs opacity-60">three acts · only one of them removes access</p>
      </div>

      <p class="max-w-3xl font-serif text-sm opacity-80">
        Someone left the organisation. These are the three acts this screen offers, side by
        side, with what each one does <strong>and what it does not do</strong>. Read this
        before acting: the act that reads like a shutdown is not the one that shuts anyone
        out.
      </p>

      <div class="grid gap-3 md:grid-cols-3">
        <.cartao_do_ato
          titulo="Disable account"
          enfase?={true}
          faz="The account stops signing in — by password today, and by API token when tokens exist. The open session drops at the next action. The row stays, with who disabled it, when, and why."
          nao_faz="Does not delete anything. Does not remove the person from the roster, from any team, or from any measure. Does not change the password."
        />
        <.cartao_do_ato
          titulo="Reset password"
          enfase?={false}
          faz="Issues a new temporary password, shown once, and drops the open sessions. It is how someone who forgot their password gets back in."
          nao_faz="This is not a shutdown. The account stays able to sign in, and the next reset — a routine act — hands it back. Not handing the temporary over is a habit, not a control."
        />
        <.cartao_do_ato
          titulo="Revoke GitHub link"
          enfase?={false}
          faz="The account stops being that observed person: their own dashboard closes, and signing in by GitHub username stops working. The history of the link stays."
          nao_faz="Does not remove access. Signing in by e-mail does not need the link, and the organisation's screens keep opening. Measured on 9 Sep."
        />
      </div>

      <div class="rounded border border-base-300 p-3 text-xs opacity-70">
        <p class="font-mono uppercase tracking-wide">
          why this panel is on the screen and not only in a document
        </p>
        <p class="mt-1 max-w-3xl font-serif">
          The written procedure exists —
          <span class="font-mono">docs/producao/desligar-alguem.md</span>
          — and it exists <em>because</em>
          the act that worked was not written anywhere. A
          procedure that lives only in the documentation is exactly what this finding proved
          does not work: whoever administers does what the interface offers. So the interface
          says it, at the point of acting, and the document keeps the long version.
        </p>
      </div>
    </div>
    """
  end

  defp cartao_do_ato(assigns) do
    ~H"""
    <div class={[
      "card border bg-base-200 p-4",
      @enfase? && "border-error/40",
      not @enfase? && "border-base-300"
    ]}>
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <span class={[
          "inline-block size-2.5 shrink-0 rounded-sm",
          @enfase? && "bg-error",
          not @enfase? && "bg-base-content/30"
        ]}></span>
        {@titulo}
      </h3>
      <p class="mt-2 font-mono text-[11px] uppercase tracking-wide opacity-60">what it does</p>
      <p class="font-serif text-sm">{@faz}</p>
      <p class="mt-2 font-mono text-[11px] uppercase tracking-wide opacity-60">
        what it does not do
      </p>
      <p class="font-serif text-sm opacity-80">{@nao_faz}</p>
    </div>
    """
  end

  # ── A célula da conta: `pode entrar?`, e só ──

  defp estado_da_conta_celula(assigns) do
    ~H"""
    <div class="space-y-1">
      <%!-- `disabled` é cinza CHEIO: a marca da casa para "acabou, e ficou no registro".
            `active` é palavra sem marca — marcar o raro, não o comum. --%>
      <span
        :if={estado_da_conta(@user) == :disabled}
        class="badge badge-neutral badge-sm font-mono"
      >
        {AccountLifecycle.rotulo_de_conta(:disabled)}
      </span>
      <span :if={estado_da_conta(@user) == :active} class="font-mono text-xs">
        {AccountLifecycle.rotulo_de_conta(:active)}
      </span>

      <%= if estado_da_conta(@user) == :disabled and @resumo && @resumo.aberto do %>
        <p class="text-xs opacity-70">
          since {data_e_hora(@resumo.aberto.disabled_at)} ·
          by {autor_do_episodio(@resumo.aberto.disabled_by_user_id, @autores)}
        </p>
        <p class="font-mono text-xs">
          {AccountLifecycle.rotulo(@resumo.aberto.disable_reason)}
        </p>
      <% else %>
        <p class="text-xs opacity-70">{historico_em_uma_linha(@resumo)}</p>
      <% end %>
    </div>
    """
  end

  # ── As ações, e as recusas que FICAM no lugar ──
  #
  # Botão que desaparece faz quem procura concluir que a plataforma não sabe fazer aquilo —
  # e foi o que produziu o desligamento improvisado. A recusa fica, inerte, com a razão.
  defp acoes_da_linha(assigns) do
    ~H"""
    <div class="flex flex-col items-end gap-1">
      <%= if User.ativa?(@user) do %>
        <button phx-click="reset" phx-value-id={@user.id} class="btn btn-ghost btn-xs">
          {if @user.password_hash, do: "Reset password", else: "Issue a temporary"}
        </button>
      <% else %>
        <button type="button" disabled class="btn btn-outline btn-dash btn-xs">
          Reset password
        </button>
        <p class="max-w-xs text-right text-[11px] opacity-70">
          Reset is unavailable while the account is disabled. Reactivate first — and
          reactivating does not hand the password back, so a reset comes after, not instead.
        </p>
      <% end %>

      <%= cond do %>
        <% not User.ativa?(@user) -> %>
          <button
            phx-click="abrir_reativacao"
            phx-value-id={@user.id}
            class="btn btn-ghost btn-xs text-info"
          >
            Reactivate…
          </button>
        <% @user.id == @current_user.id -> %>
          <%!-- A PRÓPRIA CONTA: a recusa fica na tela, e diz a razão da plataforma.
                Desativar-se a si é ficar de fora sem ter a quem pedir de volta, e num
                tenant com uma administração só isso tranca a organização inteira. O
                domínio também recusa — esconder na tela não seria a defesa. --%>
          <button type="button" disabled class="btn btn-outline btn-dash btn-xs">
            Disable
          </button>
          <p class="max-w-xs text-right text-[11px] opacity-70">
            This is your own account — ask another administrator. The platform refuses it
            too, so that one administration cannot lock the organisation out of itself.
          </p>
        <% true -> %>
          <button
            phx-click="abrir_desativacao"
            phx-value-id={@user.id}
            class="btn btn-ghost btn-xs text-error"
          >
            Disable…
          </button>
      <% end %>

      <%!-- As duas notas do protótipo: a conta sem senha que NÃO está desativada, e a
            conta de elo revogado que CONTINUA entrando. As duas são o par que o achado
            mediu, e as duas ficam escritas na linha. --%>
      <p
        :if={User.ativa?(@user) and is_nil(@user.password_hash)}
        class="max-w-xs text-right text-[11px] opacity-70"
      >
        This account cannot sign in and it is <strong>not</strong> disabled — nobody decided
        anything about it. Disabling it is how the decision gets recorded.
      </p>
      <p
        :if={(User.ativa?(@user) and @user.person_revoked_at) && @user.password_hash}
        class="max-w-xs text-right text-[11px] opacity-70"
      >
        The link was revoked and this account <strong>still signs in</strong>. That is the
        pair the finding measured — if the intent was to remove access, disable is the act.
      </p>
    </div>
    """
  end

  # ── O histórico da linha ──

  defp historico_da_conta(assigns) do
    ~H"""
    <div class="border-l border-base-300 pl-3">
      <p class="font-mono text-[11px] uppercase tracking-wide opacity-60">
        access history · {@user.name || @user.email} — nothing here is deleted
      </p>

      <ul class="mt-1 space-y-2">
        <li :for={episodio <- episodios_mostrados(@resumo)} class="text-xs">
          <%!-- O EQUÍVOCO é dito, não removido: o episódio fica e deixa de contar. --%>
          <p>
            <span class="font-mono">{data_e_hora(episodio.disabled_at)}</span>
            <span class="font-semibold">disabled</span>
            by {autor_do_episodio(episodio.disabled_by_user_id, @autores)} —
            <span class="font-mono">{AccountLifecycle.rotulo(episodio.disable_reason)}</span>
            <span :if={AccountDisablement.aberto?(episodio)} class="opacity-70">
              · open, no reactivation
            </span>
            <span
              :if={AccountDisablement.equivoco?(episodio)}
              class="badge badge-outline badge-xs ml-1"
            >
              mistake
            </span>
          </p>
          <p class="opacity-70">note: “{nota_do_episodio(episodio.disable_note)}”</p>

          <p :if={not AccountDisablement.aberto?(episodio)} class="mt-1">
            <span class="font-mono">{data_e_hora(episodio.enabled_at)}</span>
            <span class="font-semibold">reactivated</span>
            by {autor_do_episodio(episodio.enabled_by_user_id, @autores)} —
            <span class="font-mono">{AccountLifecycle.rotulo(episodio.enable_reason)}</span>
          </p>
          <p :if={not AccountDisablement.aberto?(episodio)} class="opacity-70">
            note: “{nota_do_episodio(episodio.enable_note)}”
            <span :if={AccountDisablement.equivoco?(episodio)}>
              The disablement above stays on the record and is <strong>not counted as a shutdown</strong>.
            </span>
          </p>
        </li>
      </ul>

      <%!-- O que NÃO é mostrado continua sendo DITO — recomendação (b) da pergunta 15. --%>
      <p :if={@resumo.anteriores > 0} class="mt-1 font-mono text-[11px] opacity-60">
        {@resumo.anteriores} earlier {if @resumo.anteriores == 1,
          do: "disablement",
          else: "disablements"} not shown here · {@resumo.desligamentos} counted as shutdowns
      </p>

      <p :if={not User.ativa?(@user)} class="mt-1 max-w-3xl font-serif text-xs opacity-80">
        What this account could reach is <strong>kept and inert</strong>: {frase_de_escopos(@escopos)}. Nothing was revoked, so reactivating restores exactly
        what was there — and the record says what that was.
      </p>
    </div>
    """
  end

  defp legenda(assigns) do
    ~H"""
    <div class="rounded border border-base-300 p-3 text-xs">
      <dl class="grid gap-x-6 gap-y-2 md:grid-cols-2">
        <div class="flex gap-2">
          <dt class="shrink-0">
            <span class="badge badge-neutral badge-sm font-mono">disabled</span>
          </dt>
          <dd class="opacity-70">
            the account is closed — recorded, with author, date and reason. Grey and filled,
            the same mark this house uses for anything that <em>ended and stayed on the record</em>.
          </dd>
        </div>
        <div class="flex gap-2">
          <dt class="shrink-0 font-mono">active</dt>
          <dd class="opacity-70">
            plain words, no badge: it is the common case, and a badge every row carries stops
            being a signal.
          </dd>
        </div>
        <div class="flex gap-2">
          <dt class="shrink-0"><span class="badge badge-outline badge-sm">mistake</span></dt>
          <dd class="opacity-70">
            a disablement recorded as an error of the hand. The episode stays; it stops
            counting as a shutdown.
          </dd>
        </div>
        <div class="flex gap-2">
          <dt class="shrink-0 font-mono text-warning">temporary</dt>
          <dd class="opacity-70">
            amber, and the text says <strong>which</strong> temporary — from creation, or from
            a reset. The two ask for opposite next acts.
          </dd>
        </div>
        <div class="flex gap-2">
          <dt class="shrink-0 font-mono opacity-70">no password</dt>
          <dd class="opacity-70">written absence, never an empty cell and never a zero.</dd>
        </div>
        <div class="flex gap-2">
          <dt class="shrink-0">
            <span class="btn btn-outline btn-dash btn-xs pointer-events-none">refused</span>
          </dt>
          <dd class="opacity-70">
            a refused action stays where it was, with the reason beside it. A button that
            disappears teaches nobody anything.
          </dd>
        </div>
      </dl>
      <p class="mt-2 opacity-60">
        Every state above survives being printed in black and white: the word is in its own
        column, and the mark carries a fill pattern as well as a hue.
      </p>
    </div>
    """
  end

  # ── O formulário de desativação ──
  #
  # A razão é lista fechada **e** nota, e as duas fazem trabalhos diferentes: a cláusula é
  # o que a plataforma LÊ — `suspected_compromise` muda o que a tela mostra em seguida, e é
  # a pergunta que um incidente faz por contagem; a nota é o que a pessoa ESCREVE, porque
  # uma cláusula sozinha se repete idêntica para quarenta pessoas sem dizer quem decidiu.
  defp formulario_de_desativacao(assigns) do
    ~H"""
    <div class="card border border-error/40 bg-base-200 p-5">
      <p class="font-mono text-xs uppercase tracking-wide opacity-60">Disable an account</p>
      <h2 class="mt-1 text-sm font-semibold">
        Disable {@user && @user.name}
        <span class="font-mono opacity-60">— {@user && @user.email}</span>
      </h2>
      <p class="font-serif text-sm opacity-80">
        Disabled, not deleted. The row stays, and so does everything this person did.
      </p>

      <form
        id="desativar-conta"
        phx-submit="desativar"
        phx-change="mudar_desativacao"
        class="mt-4 space-y-4"
      >
        <fieldset class="space-y-2">
          <legend class="text-[13px] font-semibold">
            Why <span class="font-mono text-xs opacity-60">— required</span>
          </legend>

          <label
            :for={razao <- AccountLifecycle.razoes_de_desativacao()}
            class="flex cursor-pointer items-start gap-2 rounded border border-base-300 p-2"
          >
            <input
              type="radio"
              name="reason"
              value={razao["code"]}
              checked={@desativando.reason == razao["code"]}
              class="radio radio-sm mt-0.5"
            />
            <span>
              <span class="text-sm font-semibold">{razao["label"]}</span>
              <span class="ml-1 font-mono text-[11px] opacity-50">{razao["code"]}</span>
              <span
                :if={razao["code"] in AccountLifecycle.nota_exigida_ao_desativar()}
                class="ml-1 font-mono text-[11px] text-warning"
              >
                a note is required
              </span>
              <span
                :if={razao["code"] == "suspected_compromise"}
                class="ml-1 font-mono text-[11px] text-warning"
              >
                · adds a checklist below
              </span>
            </span>
          </label>
        </fieldset>

        <label class="flex flex-col gap-1">
          <span class="text-[13px] font-semibold">
            Note
            <span class="font-mono text-xs opacity-60">
              <%= if nota_obrigatoria_ao_desativar?(@desativando.reason) do %>
                — required for this reason
              <% else %>
                — optional here; required for “Suspected compromise” and “Something else”
              <% end %>
            </span>
          </span>
          <textarea
            name="note"
            rows="2"
            required={nota_obrigatoria_ao_desativar?(@desativando.reason)}
            class="textarea textarea-bordered font-serif text-sm"
          >{@desativando.note}</textarea>
        </label>

        <div class="rounded border border-base-300 p-3 text-xs">
          <p class="font-mono uppercase tracking-wide opacity-60">
            what happens when you confirm
          </p>
          <ul class="mt-1 list-disc space-y-1 pl-5 font-serif">
            <li>
              The account stops signing in — by password now, and by API token when tokens
              exist.
            </li>
            <li>
              The open session drops <strong>at the next action</strong>, not seven days from
              now.
            </li>
            <li>
              The record keeps <strong>who, when, why</strong> and this note, and it stays
              after any reactivation.
            </li>
            <li class="opacity-70">
              The password is <strong>not</strong>
              changed, the GitHub link is <strong>not</strong>
              revoked, and the scopes are <strong>not</strong>
              removed —
              they are kept and inert, so that bringing the account back restores exactly
              what was there.
            </li>
            <li class="opacity-70">
              The roster, the measures and this person's history do <strong>not</strong>
              change. Disabling an account changes who signs in, not what happened.
            </li>
          </ul>
        </div>

        <%!-- A LISTA que só a suspeita de comprometimento acrescenta: é a razão que pede
              mais do que este ato, e a tela diz o que este ato NÃO fecha. --%>
        <div
          :if={@desativando.reason == "suspected_compromise"}
          class="rounded border border-warning p-3 text-xs"
        >
          <p class="font-mono uppercase tracking-wide">
            disabling closes the door — these are the things it does not close
          </p>
          <ul class="mt-1 list-disc space-y-1 pl-5 font-serif">
            <li>
              <strong>The open session</strong> — closed by this act, at the next action.
              Nothing else to do.
            </li>
            <li>
              <strong>The password</strong>
              — unchanged, and you do not know who else knows
              it. While the account is disabled it opens nothing; reset it <em>after</em>
              any reactivation, never before.
            </li>
            <li class="text-warning">
              <strong>API tokens</strong> — <strong>the platform has none yet</strong>. When
              it does (spec 061), disabling has to close them too, and until then this line
              is a promise and not a control.
            </li>
            <li>
              <strong>What was read before now</strong> — nothing here is retroactive. What
              the person saw, they know.
            </li>
            <li>
              <strong>The access record</strong> — what this account did, from the sign-in
              log. It starts on 9 Sep, when the platform began recording access events;
              before that date there is nothing, and this screen says so rather than showing
              an empty list.
            </li>
          </ul>
        </div>

        <div class="flex gap-2">
          <button type="submit" class="btn btn-error btn-sm">Disable the account</button>
          <button type="button" phx-click="fechar_desativacao" class="btn btn-ghost btn-sm">
            Cancel
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── O formulário de reativação ──
  #
  # O ato mais sensível dos dois, e o que tinha MENOS registro: `enable_user/2` recebia
  # tenant e id, e nada mais. Agora abre nomeando o episódio que vai fechar.
  defp formulario_de_reativacao(assigns) do
    ~H"""
    <div class="card border border-info/40 bg-base-200 p-5">
      <p class="font-mono text-xs uppercase tracking-wide opacity-60">Reactivate an account</p>
      <p class="max-w-3xl font-serif text-sm opacity-80">
        Disabling closes a door; reactivating <strong>opens</strong> one. It asks for the
        same author and the same reason, and it does not erase the disablement — it closes
        the episode, and both halves stay side by side on the row.
      </p>

      <h2 class="mt-3 text-sm font-semibold">
        Reactivate {@user && @user.name}
        <span :if={@resumo && @resumo.aberto} class="font-mono text-xs font-normal opacity-60">
          — disabled {data_e_hora(@resumo.aberto.disabled_at)} by {autor_do_episodio(
            @resumo.aberto.disabled_by_user_id,
            @autores
          )}, {AccountLifecycle.rotulo(@resumo.aberto.disable_reason)}
        </span>
      </h2>

      <form
        id="reativar-conta"
        phx-submit="reativar"
        phx-change="mudar_reativacao"
        class="mt-4 space-y-4"
      >
        <fieldset class="space-y-2">
          <legend class="text-[13px] font-semibold">
            Why <span class="font-mono text-xs opacity-60">— required</span>
          </legend>

          <%!-- `investigation_closed_no_compromise` só é OFERECIDA contra uma desativação
                por suspeita: oferecê-la sempre faria a plataforma sugerir que houve
                investigação onde não houve. O domínio também recusa. --%>
          <label
            :for={razao <- AccountLifecycle.reativacoes_oferecidas_contra(@reativando.abertura)}
            class="flex cursor-pointer items-start gap-2 rounded border border-base-300 p-2"
          >
            <input
              type="radio"
              name="reason"
              value={razao["code"]}
              checked={@reativando.reason == razao["code"]}
              class="radio radio-sm mt-0.5"
            />
            <span>
              <span class="text-sm font-semibold">{razao["label"]}</span>
              <span class="ml-1 font-mono text-[11px] opacity-50">{razao["code"]}</span>
              <span
                :if={razao["code"] == "disabled_by_mistake"}
                class="ml-1 font-mono text-[11px]"
              >
                · marks the episode <strong>mistake</strong>; it stops counting as a shutdown,
                without being deleted
              </span>
              <span
                :if={razao["code"] in AccountLifecycle.nota_exigida_ao_reativar()}
                class="ml-1 font-mono text-[11px] text-warning"
              >
                a note is required
              </span>
            </span>
          </label>
        </fieldset>

        <label class="flex flex-col gap-1">
          <span class="text-[13px] font-semibold">
            Note
            <span class="font-mono text-xs opacity-60">
              <%= if nota_obrigatoria_ao_reativar?(@reativando.reason) do %>
                — required for this reason
              <% else %>
                — optional here; required for “Something else”
              <% end %>
            </span>
          </span>
          <textarea
            name="note"
            rows="2"
            required={nota_obrigatoria_ao_reativar?(@reativando.reason)}
            class="textarea textarea-bordered font-serif text-sm"
          >{@reativando.note}</textarea>
        </label>

        <div class="rounded border border-base-300 p-3 text-xs">
          <p class="font-mono uppercase tracking-wide opacity-60">
            what happens when you confirm
          </p>
          <ul class="mt-1 list-disc space-y-1 pl-5 font-serif">
            <li>
              The account signs in again, with the credential it already had — <span class="font-mono">
                {@user && AccountLifecycle.rotulo_de_credencial(User.estado_da_credencial(@user))}
              </span>.
            </li>
            <li>
              The scopes it had are live again: {frase_de_escopos(@escopos)}. Nothing new is
              granted.
            </li>
            <li>
              The episode closes with <strong>your name, this instant and this reason</strong>.
              The disablement above it stays exactly as it was.
            </li>
            <li class="opacity-70">
              Reactivating does <strong>not</strong> hand the password back. If the shutdown
              was done the old way — a reset whose temporary was never delivered — the
              password is still that undelivered temporary, and a fresh reset comes after
              this act.
            </li>
          </ul>
        </div>

        <div class="flex gap-2">
          <button type="submit" class="btn btn-info btn-sm">Reactivate the account</button>
          <button type="button" phx-click="fechar_reativacao" class="btn btn-ghost btn-sm">
            Cancel
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── As duas afirmações lado a lado, e a que esta tela não consegue fazer sozinha ──

  defp o_que_nao_muda(assigns) do
    ~H"""
    <div class="space-y-3">
      <div>
        <h2 class="text-sm font-semibold">What disabling does not touch</h2>
        <p class="font-mono text-xs opacity-60">
          written on the screen, because the opposite is what people assume
        </p>
      </div>

      <div class="grid gap-3 md:grid-cols-2">
        <div class="card bg-base-200 p-4">
          <p class="font-mono text-[11px] uppercase tracking-wide opacity-60">
            the person, in the organisation's data
          </p>
          <p class="mt-1 font-serif text-sm">
            Everything this person did stays: the roster, the team memberships, the work
            items, the demonstrated profile, every measure over any period.
            <strong>Disabling an account is a statement about signing in, not about the
            past.</strong>
            Someone who worked here in July still counts in July.
          </p>
        </div>
        <div class="card bg-base-200 p-4">
          <p class="font-mono text-[11px] uppercase tracking-wide opacity-60">
            the account, on this screen
          </p>
          <p class="mt-1 font-serif text-sm">
            The row stays, the link stays, the scopes stay and go inert, the credential stays
            as it was. <strong>Nothing is deleted, ever.</strong> The one thing that changes
            is the answer to “can this person sign in?”, and it changes with an author, an
            instant and a reason attached.
          </p>
        </div>
      </div>

      <%!-- A afirmação do cabeçalho, e o seu limite.
            O protótipo escreveu que `tenants.status` não era lido em lugar nenhum (H3
            parte A, medido em 9 Sep). Desde a v0.7.0 a porta LÊ: `Auth.verificar/2` recusa
            quando a organização não está ativa. O que fica é a distinção — a contagem é
            sobre contas, e a porta é sobre a organização. A faixa do topo aparece quando as
            duas discordam. --%>
      <div class="rounded border border-base-300 p-3 text-xs">
        <p class="font-mono uppercase tracking-wide opacity-60">
          and one claim this screen makes about accounts, not about the door
        </p>
        <p class="mt-1 max-w-3xl font-serif">
          “{@entram} can sign in today”, at the top, is a statement about <strong>accounts</strong>. The door also asks whether the organisation itself is
          active: sign-in refuses every account of a suspended organisation, whatever its own
          state says. This organisation is <span class="font-mono">{@tenant.status}</span>, and the banner at the top of this
          screen appears whenever that is not <span class="font-mono">active</span>.
        </p>
      </div>
    </div>
    """
  end

  # ── A célula do elo, e o texto que passou a dizer o que ele NÃO faz ──

  defp celula_do_elo(assigns) do
    ~H"""
    <div>
      <%!-- O elo é DECLARADO por quem administra: marca sólida, nunca hachura. Ausência
            nomeada, nunca célula vazia (FR-003). --%>
      <span :if={elo_vigente?(@user)} class="font-mono text-xs">
        {@logins[@user.person_id] || "?"}
      </span>
      <button
        :if={elo_vigente?(@user)}
        phx-click="revogar_elo"
        phx-value-user-id={@user.id}
        data-confirm="Revoke the link? The account stops being that observed person and their own dashboard closes, and signing in by GitHub username stops working. It does NOT remove access: signing in by e-mail does not need the link. The history of the link stays."
        class="btn btn-ghost btn-xs"
      >
        revoke link…
      </button>

      <span :if={!elo_vigente?(@user) and is_nil(@user.person_revoked_at)} class="text-xs opacity-60">
        no GitHub account linked
      </span>
      <span :if={@user.person_revoked_at} class="text-xs opacity-60">
        link revoked {data_curta(@user.person_revoked_at)}
      </span>
      <button
        :if={!elo_vigente?(@user)}
        phx-click="abrir_busca"
        phx-value-user-id={@user.id}
        class="btn btn-ghost btn-xs"
      >
        link…
      </button>

      <div :if={@busca && @busca.user_id == @user.id} class="mt-2 rounded border border-base-300 p-2">
        <form id={"busca-#{@user.id}"} phx-change="buscar_pessoa" phx-submit="buscar_pessoa">
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
              phx-value-user-id={@user.id}
              phx-value-person-id={p.id}
              class="btn btn-ghost btn-xs"
            >
              {p.name} <span class="font-mono opacity-60">{p.login}</span>
              <span :if={@busca.orgs[p.id]} class="text-xs opacity-60">
                · {Enum.join(@busca.orgs[p.id], ", ")}
              </span>
              <span :if={p.no_longer_observed_at} class="badge badge-ghost badge-xs">
                no longer observed
              </span>
            </button>
          </li>
        </ul>
        <p :if={@busca.q != "" and @busca.resultados == []} class="mt-1 text-xs opacity-60">
          no collected person matches “{@busca.q}”
        </p>
        <button phx-click="fechar_busca" class="btn btn-ghost btn-xs mt-1">close</button>
      </div>
    </div>
    """
  end
end
