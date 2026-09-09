defmodule TheBand.Tenants.Auth do
  @moduledoc """
  Autenticação — contrato em `specs/045-autenticacao-e-acesso/contracts/auth.md`.

  ## A mensagem é uma só, e o relógio também

  Senha errada, e-mail inexistente, usuário do GitHub ambíguo, elo revogado e
  conta sem senha devolvem o MESMO `{:error, :invalid_credentials}` (FR-002).
  E quando não há conta, um hash dummy roda mesmo assim: sem ele, a recusa
  instantânea entregaria pelo tempo o que a mensagem esconde.

  ## O identificador é global, de propósito

  `authenticate/2` não recebe tenant: e-mail é único na plataforma, e o usuário
  do GitHub só identifica quando resolve para exatamente UMA conta com elo
  vigente (FR-019) — a mesma pessoa observada em dois tenants não identifica
  nenhuma, e o e-mail resolve. O tenant SAI da conta autenticada; quem loga
  nunca o escolhe.

  ## Espera crescente, nunca bloqueio (FR-016, research R4)

  Três tentativas livres; depois a janela dobra (2s, 4s, 8s…) até o teto de
  60s. Por conta e no banco: sobrevive a deploy e vale em cluster. A tela mostra
  a mensagem única; o `{:throttled, s}` existe para teste e log.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @tentativas_livres 3
  @teto_segundos 60

  @spec authenticate(String.t(), String.t()) ::
          {:ok, User.t()}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def authenticate(identificador, senha)
      when is_binary(identificador) and is_binary(senha) do
    case resolver(String.trim(identificador)) do
      nil ->
        # O custo do hash roda mesmo sem conta — tempo constante.
        Bcrypt.no_user_verify()
        recusar(nil, :identificador_nao_resolveu)

      %User{} = user ->
        verificar(user, senha)
    end
  end

  # A RECUSA REGISTRADA COM O MOTIVO INTERNO — achado H4.
  #
  # Na resposta a recusa é **única** (FR-002): motivo distinto ali seria enumeração. Aqui
  # o motivo é o que permite distinguir depois "senha errada" de "conta desativada" de
  # "organização suspensa" — a pergunta de quem reconstrói um incidente.
  #
  # E a decisão continua no RETORNO: esta função devolve o mesmo `{:error, ...}` que
  # devolvia, e só acrescenta o registro. É a L69 — defeito dentro de `Logger.info` é
  # invisível a teste, então o log nunca é o único lugar onde algo é dito.
  defp recusar(user, motivo) do
    AccessEvents.entrada_recusada(user && user.id, user && user.tenant_id, motivo)
    {:error, :invalid_credentials}
  end

  defp verificar(%User{} = user, senha) do
    with :ok <- fora_da_janela(user) do
      cond do
        # A ORGANIZAÇÃO SUSPENSA NÃO AUTENTICA — achado H3, parte A, 2026-09-09.
        #
        # `tenants.status` existia com `default: "active"`, era castável no changeset, e
        # **nenhum código o lia**. Medido: marcar um tenant como `"suspended"` e
        # autenticar — as duas coisas funcionavam, e as telas abriam. Era uma coluna que
        # parecia um controle e não era: quem a marcasse acharia que suspendeu.
        #
        # Decisão da pessoa mantenedora em 2026-09-09: passa a ser lida.
        #
        # **A recusa é a mesma**, byte a byte. Um motivo novo aqui — "organização
        # suspensa" — seria enumeração: diria a quem tenta que a conta existe e que o
        # e-mail está certo. `auth.ex` tem um ponto único de recusa de propósito.
        #
        # **E o custo do hash roda igual**, como na cláusula da conta pré-feature abaixo.
        # Recusar antes de gastar o tempo do Bcrypt criaria um oráculo de tempo que
        # distingue "organização suspensa" de "senha errada".
        #
        # **Não registra falha**, e a diferença é deliberada: a credencial pode estar
        # perfeitamente correta, e é a organização que está suspensa. Gravar tentativa
        # falha aqui afirmaria algo falso sobre a senha, e deixaria a conta em espera
        # crescente no dia em que a organização voltasse.
        not organizacao_ativa?(user.tenant_id) ->
          Bcrypt.no_user_verify()
          recusar(user, :organizacao_suspensa)

        # A CONTA DESATIVADA NÃO AUTENTICA — achado H3, parte B, 2026-09-09.
        #
        # Até esta coluna existir, o desligamento era **implícito**: quem administra
        # reiniciava a senha e não entregava a temporária. Funcionava, e o H3 mostrou por
        # que era frágil — não estava escrito em lugar nenhum, era indistinguível de um
        # reinício legítimo no histórico, e **para de funcionar no dia em que existir
        # token**, porque o token não é a senha.
        #
        # Mesma forma da cláusula acima: recusa idêntica, custo do hash pago, e **nenhuma
        # tentativa falha registrada** — a credencial pode estar correta, e é a conta que
        # está desativada.
        not User.ativa?(user) ->
          Bcrypt.no_user_verify()
          recusar(user, :conta_desativada)

        is_nil(user.password_hash) ->
          # Conta pré-feature (FR-014): recusa idêntica; a tela orienta em texto
          # público, nunca na resposta do formulário.
          Bcrypt.no_user_verify()
          registrar_falha(user)
          recusar(user, :conta_sem_senha)

        Bcrypt.verify_pass(senha, user.password_hash) ->
          {:ok, registrar_sucesso(user)}

        true ->
          registrar_falha(user)
          recusar(user, :senha_errada)
      end
    end
  end

  # Uma consulta, e só quando o identificador resolveu para uma conta. `resolver/1` não
  # pré-carrega o tenant — e pré-carregá-lo mudaria o custo de toda tentativa,
  # inclusive as que não resolvem, que é onde o tempo constante importa.
  defp organizacao_ativa?(tenant_id) do
    Repo.one(from t in Tenant, where: t.id == ^tenant_id, select: t.status) == "active"
  end

  defp fora_da_janela(%User{failed_attempts: n, last_failed_at: em}) do
    espera = espera_segundos(n)

    if espera > 0 and em != nil do
      liberacao = DateTime.add(em, espera, :second)
      restante = DateTime.diff(liberacao, DateTime.utc_now(:second), :second)

      if restante > 0 do
        {:error, {:throttled, restante}}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp espera_segundos(tentativas) when tentativas < @tentativas_livres, do: 0

  defp espera_segundos(tentativas),
    do: min(Integer.pow(2, tentativas - @tentativas_livres + 1), @teto_segundos)

  defp registrar_falha(%User{} = user) do
    user
    |> Ecto.Changeset.change(
      failed_attempts: user.failed_attempts + 1,
      last_failed_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()
  end

  defp registrar_sucesso(%User{} = user) do
    # O RASTRO ANTES DE O APAGAR — achado H4, 2026-09-09.
    #
    # `failed_attempts` e `last_failed_at` eram o **único** rastro de tentativa falha, e
    # são um contador de estado, não um histórico. Zerá-los no sucesso significava que
    # **uma campanha de adivinhação que dá certo apagava a própria evidência**.
    #
    # Registrar quantas foram apagadas transforma o contador num rastro, sem tabela nova.
    # Zero é o caso normal; número alto num sucesso é o sinal que não existia.
    AccessEvents.entrada_aceita(user.id, user.tenant_id, user.failed_attempts)

    user
    |> Ecto.Changeset.change(
      failed_attempts: 0,
      last_failed_at: nil,
      # Garante o token (conta que nunca logou); NÃO o gira — girar é ato de
      # troca de senha, e girar aqui derrubaria as outras sessões a cada login.
      session_token: user.session_token || User.novo_token(),
      logged_in_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()
    |> Repo.preload(:tenant)
  end

  # E-mail primeiro (identidade que sempre vale); senão, o usuário do GitHub
  # pelo elo vigente. Mais de uma conta = não identifica (FR-019).
  defp resolver(identificador) do
    por_email(identificador) || por_login_do_github(identificador)
  end

  # A invariante que sustenta a resolução global: `users.email` tem índice ÚNICO
  # na plataforma inteira (não por tenant). Se um dia e-mail passar a repetir
  # entre tenants, este resolvedor precisa mudar JUNTO — a regra de ambiguidade
  # do username (não identifica) passaria a valer para ele.
  defp por_email(identificador) do
    baixo = String.downcase(identificador)
    Repo.one(from u in User, where: fragment("lower(?)", u.email) == ^baixo, limit: 2)
  rescue
    # Dois e-mails diferindo só em caixa (legado): ambíguo não identifica.
    Ecto.MultipleResultsError -> nil
  end

  defp por_login_do_github(identificador) do
    contas =
      Repo.all(
        from u in User,
          join: p in Person,
          on: p.id == u.person_id and p.tenant_id == u.tenant_id,
          where:
            p.login == ^identificador and not is_nil(u.person_id) and
              is_nil(u.person_revoked_at),
          limit: 2
      )

    case contas do
      [conta] -> conta
      _ -> nil
    end
  end

  @doc "Primeira definição de senha (fluxo da temporária) — contracts/auth.md."
  @spec set_password(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def set_password(%Tenant{id: tenant_id}, user_id, senha) do
    case do_tenant(tenant_id, user_id) do
      nil -> {:error, :not_found}
      %User{} = user -> user |> User.senha_changeset(%{password: senha}) |> Repo.update()
    end
  end

  @doc """
  Troca de senha pela própria pessoa: exige a atual (FR-012) e gira o token —
  as outras sessões caem na próxima ação (FR-015).
  """
  @spec change_password(Tenant.t(), Ecto.UUID.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_current | :not_found | Ecto.Changeset.t()}
  def change_password(%Tenant{id: tenant_id}, user_id, atual, nova) do
    with %User{} = user <- do_tenant(tenant_id, user_id),
         true <- user.password_hash != nil and Bcrypt.verify_pass(atual, user.password_hash) do
      user |> User.senha_changeset(%{password: nova}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      false -> {:error, :invalid_current}
    end
  end

  @doc """
  Cadastro pelo ato da tela (feature 051): cria a conta E emite a temporária numa
  transação — tudo ou nada. Contrato em `specs/051-cadastro-por-github/contracts/
  contas-e-elo.md`: sem isto o cadastro eram dois cliques, e a falha do segundo
  deixava conta sem senha em silêncio. `create_user/2` permanece para seeds e
  fixtures; este é o caminho de quem administra.

  A temporária volta UMA vez, em claro, para a tela mostrar — nunca logada, nunca
  persistida em claro (mesmas regras do reinício abaixo).
  """
  @spec cadastrar_conta(Tenant.t(), map(), User.t()) ::
          {:ok, {User.t(), String.t()}} | {:error, Ecto.Changeset.t()}
  def cadastrar_conta(%Tenant{id: tenant_id}, attrs, %User{} = _actor) do
    Repo.transaction(fn ->
      with {:ok, user} <-
             %User{}
             |> User.changeset(Map.put(attrs, "tenant_id", tenant_id))
             |> Repo.insert(),
           {:ok, temporaria} <- gravar_temporaria(user) do
        {Repo.get!(User, user.id), temporaria}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Reinício por quem administra (FR-013): devolve a temporária UMA vez — ela não
  é gravada em claro nem logada; a primeira entrada obriga a troca.
  """
  @spec reset_password(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, String.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reset_password(%Tenant{id: tenant_id}, user_id, _actor_id) do
    case do_tenant(tenant_id, user_id) do
      nil -> {:error, :not_found}
      %User{} = user -> gravar_temporaria(user)
    end
  end

  defp gravar_temporaria(user) do
    temporaria = senha_temporaria()

    case user
         |> User.senha_changeset(%{password: temporaria}, temporary: true)
         |> Repo.update() do
      {:ok, _} -> {:ok, temporaria}
      erro -> erro
    end
  end

  defp do_tenant(tenant_id, user_id) do
    Repo.one(from u in User, where: u.id == ^user_id and u.tenant_id == ^tenant_id)
  end

  # Legível para ditar por telefone: base32 minúscula, sem ambiguidade de caixa.
  defp senha_temporaria do
    :crypto.strong_rand_bytes(10) |> Base.encode32(case: :lower, padding: false)
  end
end
