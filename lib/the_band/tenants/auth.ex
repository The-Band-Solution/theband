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

  alias TheBand.LimitePorOrigem
  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Origem
  alias TheBand.Repo
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.PapelDeAdministrador
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @tentativas_livres 3
  @teto_segundos 60

  @doc """
  Autentica pelo identificador e pela senha.

  `opts[:origem]` é **obrigatória** (spec 077, contrato §5): a `TheBand.Origem` de quem tenta.
  Sem ela a chamada quebra, de propósito — uma porta de entrada sem o limite por origem é bug, e
  não caso de negócio.

  `opts[:jornada_id]` é o correlator da jornada (spec 074, FR-011), lido da sessão pelo
  controller; vai para o passo `entrar_com_senha`, e para nada mais. O retorno é o mesmo de
  sempre: o controller **nunca** vê o motivo (seguranca.md, S4).
  """
  @spec authenticate(String.t(), String.t(), keyword()) ::
          {:ok, User.t()}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def authenticate(identificador, senha, opts)
      when is_binary(identificador) and is_binary(senha) and is_list(opts) do
    %Origem{} = origem = Keyword.fetch!(opts, :origem)
    jornada_id = Keyword.get(opts, :jornada_id)

    # O LIMITE POR ORIGEM VEM ANTES DE TUDO — spec 077, FR-001 e FR-003; seguranca.md, L5 e L7.
    #
    # Antes de `resolver/1`: a recusa por limite não lê conta, não paga hash e não registra falha.
    # O tempo dela é menor, e isso não diz nada sobre conta, porque nada aqui dependeu do
    # identificador. Se esta conferência fosse para depois de `resolver/1`, a recusa rápida
    # passaria a dizer "esta conta existe" — a #1047 de volta.
    case LimitePorOrigem.conferir(:contas, origem) do
      {:recusa, _momento} ->
        emitir_entrada({:error, :invalid_credentials}, :limite_por_origem, nil, jornada_id)
        {:error, :invalid_credentials}

      {:segue, ficha} ->
        decidir_e_devolver(identificador, senha, jornada_id, ficha)

      {:observado, _momento, ficha} ->
        decidir_e_devolver(identificador, senha, jornada_id, ficha)
    end
  end

  # A falha já foi contada pelo `conferir/2`; o sucesso devolve a dele, e só a dele (L8).
  defp decidir_e_devolver(identificador, senha, jornada_id, ficha) do
    {resultado, motivo, conta} = decidir(identificador, senha)
    emitir_entrada(resultado, motivo, conta, jornada_id)
    if match?({:ok, _}, resultado), do: LimitePorOrigem.devolver(ficha)
    resultado
  end

  # O RELATOR INTERNO — spec 074, T012; seguranca.md, S4.
  #
  # A decisão devolve `{resultado, motivo, conta}`: o resultado é o que o controller recebe, e o
  # motivo e a conta ficam aqui dentro, para o passo. O passo é emitido por `authenticate/3`
  # DEPOIS da transação, uma vez, em todo ramo: emitido dentro dela, o custo cairia no ramo da
  # conta travada e não no do identificador que não resolve, e o tempo voltaria a distinguir os
  # motivos (FR-009).
  defp decidir(identificador, senha) do
    case resolver(String.trim(identificador)) do
      nil ->
        # O custo do hash roda mesmo sem conta — tempo constante.
        custo_do_hash(:sem_conta)
        {recusar(nil, :identificador_nao_resolveu), :identificador_nao_resolveu, nil}

      %User{} = user ->
        verificar_com_trava(user, senha)
    end
  end

  # A IDENTIDADE SÓ ONDE ALGUÉM PRECISA AGIR — D1 de 2026-10-03; FR-004; seguranca.md, S14.
  #
  # Na recusa com conta conhecida e na espera, o id da conta vai, porque é com ele que quem opera
  # age. No sucesso comum, não: seria o registro de toda entrada de toda pessoa por sete dias. Só
  # quando o sucesso apagou tentativas falhas — a campanha que deu certo, achado H4. E quando o
  # identificador não resolve, nada que dependa do digitado sai, em forma nenhuma.
  #
  # O trabalho é o mesmo em todo ramo: a decisão de incluir é uma comparação, sem consulta.
  defp emitir_entrada({:ok, _}, nil, %User{} = conta, jornada_id) do
    AccessEvents.passo(%{
      passo: :entrar_com_senha,
      desfecho: :concluiu,
      motivo: nil,
      tenant_id: conta.tenant_id,
      user_id: if(conta.failed_attempts > 0, do: conta.id),
      jornada_id: correlator(jornada_id)
    })
  end

  defp emitir_entrada({:error, _}, motivo, conta, jornada_id) do
    AccessEvents.passo(%{
      passo: :entrar_com_senha,
      desfecho: :falhou,
      motivo: motivo,
      tenant_id: conta && conta.tenant_id,
      user_id: conta && conta.id,
      jornada_id: correlator(jornada_id)
    })
  end

  defp correlator(valor) when is_binary(valor), do: valor
  defp correlator(_), do: nil

  # A TENTATIVA É SERIALIZADA POR CONTA — issue #1046, achado A1 da avaliação da 070.
  #
  # A espera lia `failed_attempts` da struct carregada por `resolver/1` e gravava `n + 1`
  # calculado em memória. Tentativas simultâneas liam o mesmo contador, e todas testavam a
  # senha: a espera crescente se contornava mandando em paralelo. A conta é relida com
  # `FOR UPDATE`, e conferir a janela, verificar a senha e registrar a tentativa acontecem com
  # a linha travada. A segunda tentativa espera a primeira e já lê o contador dela.
  defp verificar_com_trava(%User{id: id}, senha) do
    {:ok, resultado} =
      Repo.transaction(fn ->
        id
        |> conta_travada()
        |> verificar(senha)
      end)

    resultado
  end

  defp conta_travada(id), do: Repo.one!(from u in User, where: u.id == ^id, lock: "FOR UPDATE")

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

  # Cada ramo devolve o relator `{resultado, motivo, conta}`; a conta é a struct travada, ANTES
  # de `registrar_falha/1` e `registrar_sucesso/1` — é dela que sai `failed_attempts`, o número de
  # falhas que o sucesso apagou.
  defp verificar(%User{} = user, senha) do
    case fora_da_janela(user) do
      :ok -> verificar_credencial(user, senha)
      {:error, {:throttled, _}} = espera -> {espera, :em_espera, user}
    end
  end

  defp verificar_credencial(%User{} = user, senha) do
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
        custo_do_hash(:organizacao_suspensa)
        recusada(user, :organizacao_suspensa)

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
        custo_do_hash(:conta_desativada)
        recusada(user, :conta_desativada)

      is_nil(user.password_hash) ->
        # Conta pré-feature (FR-014): recusa idêntica; a tela orienta em texto
        # público, nunca na resposta do formulário.
        custo_do_hash(:conta_sem_senha)
        registrar_falha(user)
        recusada(user, :conta_sem_senha)

      senha_confere?(senha, user.password_hash) ->
        {{:ok, registrar_sucesso(user)}, nil, user}

      true ->
        registrar_falha(user)
        recusada(user, :senha_errada)
    end
  end

  defp recusada(%User{} = user, motivo), do: {recusar(user, motivo), motivo, user}

  # CADA CUSTO DE HASH DA ENTRADA PASSA POR AQUI, e emite um evento — spec 077, T008 (seguranca.md,
  # L5, Q5). É o desenho de `Platform.Credentials.custo_do_hash/1`: permite ao teste CONTAR que a
  # recusa por limite pagou zero hashes, sem cronômetro, que seria instável com o custo baixo do
  # teste.
  defp custo_do_hash(motivo) do
    Bcrypt.no_user_verify()
    :telemetry.execute([:the_band, :tenants, :custo_do_hash], %{}, %{motivo: motivo})
  end

  defp senha_confere?(senha, hash) do
    certa? = Bcrypt.verify_pass(senha, hash)
    :telemetry.execute([:the_band, :tenants, :custo_do_hash], %{}, %{motivo: :senha_conferida})
    certa?
  end

  # Uma consulta, e só quando o identificador resolveu para uma conta. `resolver/1` não
  # pré-carrega o tenant — e pré-carregá-lo mudaria o custo de toda tentativa,
  # inclusive as que não resolvem, que é onde o tempo constante importa.
  defp organizacao_ativa?(tenant_id) do
    Repo.one(from t in Tenant, where: t.id == ^tenant_id, select: t.status) == "active"
  end

  defp fora_da_janela(%User{failed_attempts: n, last_failed_at: em} = user) do
    espera = espera_segundos(n)

    if espera > 0 and em != nil do
      liberacao = DateTime.add(em, espera, :second)
      restante = DateTime.diff(liberacao, DateTime.utc_now(:second), :second)

      if restante > 0 do
        # A ESPERA REGISTRADA — achado H4, e ela faltava.
        #
        # O `{:throttled, s}` morria no retorno: quem investiga uma campanha precisa saber
        # que a espera crescente disparou, e quantas vezes. `AccessEvents.espera_acionada/3`
        # existia escrita e **nunca era chamada** — recusa do papel Product Owner na
        # avaliação da v0.7.0, e ela estava certa: função documentada e sem call site é
        # pior que ausência, porque quem faz `grep` conclui que está registrado.
        AccessEvents.espera_acionada(user.id, user.tenant_id, restante)
        # O CUSTO DO HASH NA ESPERA TAMBÉM — issue #1047, achado A3 da avaliação da 070. Sem
        # isto, a conta em espera respondia sem o Bcrypt, e o identificador que não existe
        # pagava o `no_user_verify` e nunca entrava em espera: o tempo dizia que o e-mail
        # existia e estava em espera, embora a mensagem fosse a mesma.
        custo_do_hash(:em_espera)
        {:error, {:throttled, restante}}
      else
        :ok
      end
    else
      :ok
    end
  end

  @doc false
  # A espera de 0 a 12 falhas, para o teste de paridade da spec 070 (T034) comparar as duas
  # autenticações pelos valores calculados, e não por literais copiados.
  @spec tabela_da_espera() :: [non_neg_integer()]
  def tabela_da_espera, do: Enum.map(0..12, &espera_segundos/1)

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
      nil ->
        {:error, :not_found}

      %User{} = user ->
        user
        |> User.senha_changeset(%{password: senha}, source: "self", by: user.id)
        |> Repo.update()
        |> encerrando_as_sessoes()
    end
  end

  @doc """
  Troca de senha pela própria pessoa: exige a atual (FR-012) e gira o token —
  as outras sessões caem na próxima ação (FR-015).

  A senha atual é conferida com **o mesmo contador e a mesma espera da entrada** (issue #1409,
  D1): o segredo é um só, e dois contadores dariam o dobro de tentativas por ele. Os retornos
  de recusa — contrato `specs/045-autenticacao-e-acesso/contracts/auth.md`:

  - `{:error, :invalid_current}` — a atual foi conferida, errou, e ainda há tentativas livres;
  - `{:error, :tentativas_esgotadas}` — a atual foi conferida **nesta** chamada, errou, e o
    contador chegou às tentativas livres. É o sinal para quem chama encerrar a sessão corrente
    (D3); vem no retorno, e não de releitura, para ser visível a teste (L69);
  - `{:error, {:throttled, s}}` — dentro da janela de espera: a atual **não** foi conferida.
    Os segundos são para teste e log; a tela não os mostra (D2).
  """
  @spec change_password(Tenant.t(), Ecto.UUID.t(), String.t(), String.t()) ::
          {:ok, User.t()}
          | {:error,
             :invalid_current
             | :tentativas_esgotadas
             | {:throttled, pos_integer()}
             | :not_found
             | Ecto.Changeset.t()}
  def change_password(%Tenant{id: tenant_id}, user_id, atual, nova) do
    case do_tenant(tenant_id, user_id) do
      nil ->
        {:error, :not_found}

      %User{id: id} ->
        # A CONFERÊNCIA É SERIALIZADA POR CONTA, como na entrada (#1046; avaliação da #1409, P1).
        # Janela, verificação e registro da falha com a linha em `FOR UPDATE`: dez trocas em
        # paralelo leem o contador uma da outra, e só as livres chegam a testar a senha.
        {:ok, conferencia} =
          Repo.transaction(fn ->
            id
            |> conta_travada()
            |> conferir_a_atual(atual)
          end)

        trocar_se_conferida(conferencia, nova)
    end
  end

  defp trocar_se_conferida({:ok, %User{} = user}, nova) do
    user
    |> User.senha_changeset(%{password: nova}, source: "self", by: user.id)
    |> Repo.update()
    |> encerrando_as_sessoes()
  end

  defp trocar_se_conferida(recusa, _nova), do: recusa

  # A JANELA ANTES DO BCRYPT — avaliação da #1409, D1.2. Em espera, nem a senha certa é
  # verificada, como na entrada; e `fora_da_janela/1` já paga o custo do hash e registra a
  # espera, então a recusa em espera não responde mais rápido que a conferida (P2).
  #
  # Não reusa `verificar_credencial/2` inteira, de propósito (D1.4): organização suspensa e
  # conta desativada já derrubam a sessão em `CurrentScope` antes de a requisição chegar aqui, e
  # o ramo da conta sem senha de lá registra falha — aqui não há segredo a adivinhar (P10).
  defp conferir_a_atual(%User{} = user, atual) do
    with :ok <- fora_da_janela(user) do
      cond do
        is_nil(user.password_hash) ->
          # Paga o hash e NÃO conta falha: sem senha gravada, não há o que adivinhar (P10).
          custo_do_hash(:conta_sem_senha)
          AccessEvents.troca_de_senha_recusada(user.id, user.tenant_id, :conta_sem_senha)
          {:error, :invalid_current}

        senha_confere?(atual, user.password_hash) ->
          {:ok, zerar_na_conferencia(user)}

        true ->
          user |> registrar_falha() |> recusar_a_atual()
      end
    end
  end

  # O GATILHO DO ENCERRAMENTO É O CONTADOR DEPOIS DESTA FALHA — D3.2. Só chega aqui quem foi
  # conferido nesta chamada; a recusa em espera saiu antes, pelo `with`, e não encerra nada: a
  # espera pode ter sido posta por terceiro, pela entrada, sem sessão nenhuma (C5).
  defp recusar_a_atual(%User{failed_attempts: n} = falhou) when n >= @tentativas_livres do
    AccessEvents.troca_de_senha_recusada(falhou.id, falhou.tenant_id, :tentativas_esgotadas)
    {:error, :tentativas_esgotadas}
  end

  defp recusar_a_atual(%User{} = falhou) do
    AccessEvents.troca_de_senha_recusada(falhou.id, falhou.tenant_id, :senha_errada)
    {:error, :invalid_current}
  end

  # O ZERO ACONTECE QUANDO A ATUAL CONFERE, mesmo que a nova seja recusada pela regra dos 12
  # caracteres (avaliação da #1409, D1.3): a prova de conhecimento aconteceu, e não zerar
  # deixaria o dono a uma digitação de ser deslogado por ter escolhido uma senha nova curta.
  #
  # E o rastro antes de apagar, como em `registrar_sucesso/1` (H4; P3): sem isto, a campanha que
  # acerta na troca apagaria a própria evidência.
  defp zerar_na_conferencia(%User{} = user) do
    AccessEvents.senha_atual_conferida(user.id, user.tenant_id, user.failed_attempts)

    user
    |> Ecto.Changeset.change(failed_attempts: 0, last_failed_at: nil)
    |> Repo.update!()
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
          {:ok, {User.t(), String.t()}} | {:error, :nao_autorizado | Ecto.Changeset.t()}
  def cadastrar_conta(%Tenant{id: tenant_id}, attrs, %User{} = actor) do
    # O ator relido, e não a struct da tela (072, FR-002a): o papel fica congelado no `mount`.
    with :ok <- PapelDeAdministrador.exigir_ator(tenant_id, actor.id),
         do: cadastrar_na_transacao(tenant_id, attrs, actor)
  end

  defp cadastrar_na_transacao(tenant_id, attrs, actor) do
    Repo.transaction(fn ->
      with {:ok, user} <-
             %User{}
             |> User.changeset(Map.put(attrs, "tenant_id", tenant_id))
             |> Repo.insert(),
           {:ok, temporaria} <- gravar_temporaria(user, "creation", actor.id) do
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
          {:ok, String.t()} | {:error, :nao_autorizado | :not_found | Ecto.Changeset.t()}
  def reset_password(%Tenant{id: tenant_id}, user_id, actor_id) do
    with :ok <- PapelDeAdministrador.exigir_ator(tenant_id, actor_id) do
      case do_tenant(tenant_id, user_id) do
        nil -> {:error, :not_found}
        %User{} = user -> gravar_temporaria(user, "reset", actor_id)
      end
    end
  end

  # `source` e `by` gravam a proveniência da credencial — de qual ato ela veio e quem a
  # emitiu. O `actor_id` chegava aqui e era **descartado**: a tela dizia *"issued 9 Sep by
  # Paulo"* no protótipo, e o dado não tinha o Paulo.
  #
  # No cadastro, quem emite é quem cadastra; o `user.id` da conta nova não serviria, e por
  # isso o ato passa o seu.
  defp gravar_temporaria(user, source, actor_id) do
    temporaria = senha_temporaria()

    case user
         |> User.senha_changeset(%{password: temporaria},
           temporary: true,
           source: source,
           by: actor_id
         )
         |> Repo.update()
         |> encerrando_as_sessoes() do
      {:ok, _} -> {:ok, temporaria}
      erro -> erro
    end
  end

  # DEFINIR A SENHA ENCERRA AS SESSÕES DA CONTA — 064, T013. A época já as derruba na
  # conferência seguinte; o `ended_at` é o registro de que caíram, e de quando (FR-015). A
  # sessão de quem trocou a própria senha é reaberta pelo controller.
  defp encerrando_as_sessoes({:ok, %User{} = user} = ok) do
    {:ok, _} = Sessions.encerrar_da_conta(user.tenant_id, user.id)

    # Fora de transação: o `Repo.update` acima já gravou, e a tela aberta pode reconferir (#1042).
    Sessions.avisar_encerramento({:conta, user.id})
    ok
  end

  defp encerrando_as_sessoes(erro), do: erro

  defp do_tenant(tenant_id, user_id) do
    Repo.one(from u in User, where: u.id == ^user_id and u.tenant_id == ^tenant_id)
  end

  # Legível para ditar por telefone: base32 minúscula, sem ambiguidade de caixa.
  defp senha_temporaria do
    :crypto.strong_rand_bytes(10) |> Base.encode32(case: :lower, padding: false)
  end
end
