defmodule TheBand.Platform.Credentials do
  @moduledoc """
  A entrada do operador da plataforma — spec 070, T023. Contrato em
  `specs/070-operador-da-plataforma/contracts/credenciais-do-operador.md`.

  Depende de: nenhuma ontologia. É infraestrutura de acesso, como `TheBand.Tenants.Auth`.

  ## Por que duplicado de `Tenants.Auth`, e não extraído

  É a **segunda** ocorrência, e a regra da casa é duplicar na segunda e abstrair na terceira
  (AGENTS §7.7; research R2). As constantes da espera e a forma da trava são as de `Tenants.Auth`
  **depois** das correções da #1046 (a tentativa serializada com `FOR UPDATE`, PR #1048) e da #1047
  (o custo do hash também na espera, PR #1049). Mudou lá, muda aqui: o teste de paridade de T024
  afirma isso.

  ## As regras que valem aqui

  - **Tentativa serializada (A1)**: a linha do operador é lida com `FOR UPDATE` antes da espera e
    antes do hash, e a falha ou o sucesso são registrados na mesma transação.
  - **A recusa confirma a falha (A1, T008)**: a recusa é devolvida **de dentro** de uma transação
    bem-sucedida, e não por `Repo.rollback/1`, que desfaria o `failed_attempts + 1`.
  - **O custo do hash roda sempre (A3)**: quem não existe, quem está em espera, quem não tem
    concessão e quem não tem senha pagam o mesmo Bcrypt de quem errou a senha.
  - **Recusa única**: o motivo interno vai só para `AccessEvents`.
  - **O segredo TOTP só é lido aqui, por `select` explícito, da linha travada (T4)**, e embrulhado
    em `Segredo` na mesma expressão.
  """

  import Ecto.Query

  alias TheBand.Platform.{Grant, Operator, RecoveryCode, SegundoFator, Sessions}
  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.AccessEvents

  # As mesmas de `Tenants.Auth`: três tentativas livres, e a espera dobra até o teto de 60 s.
  @tentativas_livres 3
  @teto_segundos 60

  # O limite do segundo fator (seguranca-totp.md, T1). Com a senha CERTA e o segundo fator errado,
  # a espera de 60 s sozinha deixava ~1 440 tentativas por dia, para sempre (≈12 % de acerto em 30
  # dias). Em 10 o segundo fator trava até o reinício pelo comando de release. Só quem já tem a
  # senha chega a este contador, e quem tem a senha é o incidente.
  @limite_do_segundo_fator 10

  @doc """
  Confere e-mail, senha e segundo fator num formulário só, e devolve o operador.

  Todo caso de falha é `{:error, :invalid_credentials}`, ou `{:error, {:throttled, s}}` na espera,
  que a tela mostra igual à primeira (A3, T008).
  """
  @spec autenticar(String.t(), Segredo.t(), Segredo.t()) ::
          {:ok, Operator.t()}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def autenticar(email, senha, segundo_fator) when is_binary(email) do
    case operador_por_email(email) do
      nil ->
        custo_do_hash(:sem_senha_a_conferir)
        recusar(nil, :identificador_nao_resolveu)

      id ->
        {:ok, resultado} =
          Repo.transaction(fn -> conferir(travado(id), senha, segundo_fator) end)

        resultado
    end
  end

  defp operador_por_email(email) do
    Repo.one(
      from o in Operator,
        where: fragment("lower(?)", o.email) == ^String.downcase(String.trim(email)),
        select: o.id
    )
  end

  defp travado(id), do: Repo.one!(from o in Operator, where: o.id == ^id, lock: "FOR UPDATE")

  defp conferir(%Operator{} = op, senha, segundo_fator) do
    with :ok <- fora_da_janela(op),
         :ok <- com_concessao(op),
         :ok <- senha_certa(op, senha),
         :ok <- segundo_fator_cadastrado(op),
         :ok <- segundo_fator_destravado(op) do
      segundo_fator(op, segundo_fator)
    end
  end

  # A espera, com o custo do hash antes da recusa (A3, #1047).
  defp fora_da_janela(%Operator{failed_attempts: n, last_failed_at: em} = op) do
    espera = espera_segundos(n)

    restante =
      if espera > 0 and em != nil,
        do: DateTime.diff(DateTime.add(em, espera, :second), DateTime.utc_now(:second), :second),
        else: 0

    if restante > 0 do
      AccessEvents.operador_espera_acionada(op.id, restante)
      custo_do_hash(:sem_senha_a_conferir)
      {:error, {:throttled, restante}}
    else
      :ok
    end
  end

  defp espera_segundos(tentativas) when tentativas < @tentativas_livres, do: 0

  defp espera_segundos(tentativas),
    do: min(Integer.pow(2, tentativas - @tentativas_livres + 1), @teto_segundos)

  # Sem concessão vigente, NÃO registra falha: a credencial pode estar certa, e é o papel que caiu.
  defp com_concessao(%Operator{id: id} = op) do
    if Repo.exists?(from g in Grant, where: g.operator_id == ^id and is_nil(g.revoked_at)) do
      :ok
    else
      custo_do_hash(:sem_senha_a_conferir)
      recusar(op, :sem_concessao)
    end
  end

  defp senha_certa(%Operator{password_hash: nil} = op, _senha) do
    custo_do_hash(:sem_senha_a_conferir)
    falhar(op, :sem_senha, false)
  end

  defp senha_certa(%Operator{password_hash: hash} = op, senha) do
    if conferir_senha(senha, hash),
      do: :ok,
      else: falhar(op, :senha_errada, false)
  end

  # Enquanto o terceiro passo do cadastro não acontece, o segundo fator não vale — nem o TOTP certo,
  # nem um código de recuperação, que já tem o hash gravado desde o passo 2. A recusa vem ANTES de
  # classificar e de qualquer consumo, e não sobe `second_factor_failures`: não há segundo fator a
  # forçar. O hash já foi pago pela senha.
  defp segundo_fator_cadastrado(%Operator{totp_confirmed_at: nil} = op),
    do: recusar(op, :sem_segundo_fator)

  defp segundo_fator_cadastrado(%Operator{}), do: :ok

  defp segundo_fator_destravado(%Operator{second_factor_failures: n} = op)
       when n >= @limite_do_segundo_fator,
       do: recusar(op, :segundo_fator_travado)

  defp segundo_fator_destravado(%Operator{}), do: :ok

  defp segundo_fator(op, codigo) do
    case SegundoFator.classificar(codigo) do
      :totp -> totp(op, codigo)
      :recuperacao -> recuperacao(op, codigo)
      :malformado -> falhar(op, :segundo_fator_errado, true)
    end
  end

  defp totp(op, codigo) do
    case SegundoFator.conferir(
           segredo_totp(op),
           codigo,
           op.totp_last_used_step,
           DateTime.utc_now()
         ) do
      {:ok, passo} -> aceitar(op, totp_last_used_step: passo)
      {:error, :reusado} -> falhar(op, :segundo_fator_reusado, true)
      {:error, :codigo_errado} -> falhar(op, :segundo_fator_errado, true)
    end
  end

  # Por `select` explícito, da linha já travada, e embrulhado na mesma expressão (T4).
  defp segredo_totp(%Operator{id: id}),
    do: Segredo.novo(Repo.one!(from o in Operator, where: o.id == ^id, select: o.totp_secret))

  # O consumo atômico: exatamente um envio do mesmo código passa (A5).
  defp recuperacao(%Operator{id: id} = op, codigo) do
    resumo = SegundoFator.resumo(codigo)
    agora = DateTime.utc_now(:second)

    {usados, _} =
      Repo.update_all(
        from(r in RecoveryCode,
          where:
            r.operator_id == ^id and r.code_hash == ^resumo and is_nil(r.used_at) and
              is_nil(r.invalidated_at)
        ),
        set: [used_at: agora]
      )

    if usados == 1 do
      restantes =
        Repo.aggregate(
          from(r in RecoveryCode,
            where: r.operator_id == ^id and is_nil(r.used_at) and is_nil(r.invalidated_at)
          ),
          :count
        )

      AccessEvents.operador_recuperacao_usada(id, restantes)
      aceitar(op, [])
    else
      falhar(op, :recuperacao_usada, true)
    end
  end

  defp aceitar(%Operator{} = op, extra) do
    AccessEvents.operador_entrada_aceita(op.id, op.failed_attempts)

    {:ok,
     op
     |> Ecto.Changeset.change(
       [
         failed_attempts: 0,
         last_failed_at: nil,
         second_factor_failures: 0,
         logged_in_at: DateTime.utc_now(:second)
       ] ++ extra
     )
     |> Repo.update!()}
  end

  # A falha é registrada na transação, e a recusa volta de dentro dela (A1, T008). Com a senha
  # certa e o segundo fator errado, sobe também o contador do segundo fator (T1), e o evento de
  # travado sai uma vez, na transição.
  defp falhar(%Operator{} = op, motivo, segundo_fator?) do
    falhas_do_segundo_fator =
      if segundo_fator?, do: op.second_factor_failures + 1, else: op.second_factor_failures

    op
    |> Ecto.Changeset.change(
      failed_attempts: op.failed_attempts + 1,
      last_failed_at: DateTime.utc_now(:second),
      second_factor_failures: falhas_do_segundo_fator
    )
    |> Repo.update!()

    if segundo_fator? and falhas_do_segundo_fator == @limite_do_segundo_fator,
      do: AccessEvents.operador_segundo_fator_travado(op.id)

    recusar(op, motivo)
  end

  # ------------------------------------------------------ os três passos do cadastro (T026)
  #
  # O fluxo está em `contracts/segundo-fator-do-operador.md`, "O fluxo de cadastro" (emenda T012):
  # o passo 1 define a senha e entrega o segredo, o passo 2 confere o TOTP e entrega os códigos
  # de recuperação, e o passo 3, depois de a pessoa declarar que os guardou, é o ÚNICO que habilita
  # a entrada. Os três exigem concessão vigente (A14) e consomem o seu código de forma atômica, na
  # transação com a linha travada (A5).

  # 10 minutos para o código de cadastro e para o de guarda; 30 para o de definição, que sai do
  # comando de release e precisa caber no tempo de alguém abrir a tela.
  @validade_curta_s 600
  @validade_da_definicao_s 1800

  @doc """
  O primeiro passo: confere o código de definição, define a senha e entrega o segredo TOTP
  pendente, a URI e o código de cadastro. **Não habilita a entrada.**
  """
  @spec definir_senha(String.t(), Segredo.t(), Segredo.t()) ::
          {:ok,
           {Operator.t(),
            %{segredo: Segredo.t(), uri: Segredo.t(), enrollment_token: Segredo.t()}}}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
          | {:error, Ecto.Changeset.t()}
  def definir_senha(email, setup_token, senha) when is_binary(email) do
    passo(email, &AccessEvents.operador_definicao_recusada/2, fn op ->
      with :ok <-
             codigo_vale(
               op,
               :setup_code_hash,
               :setup_code_expires_at,
               setup_token,
               :codigo,
               &AccessEvents.operador_definicao_recusada/2
             ),
           do: definir_se_a_senha_vale(op, senha)
    end)
  end

  # A política de senha roda ANTES de gravar: um `{:error, changeset}` desfaz a transação, e o
  # código de definição continua valendo.
  defp definir_se_a_senha_vale(op, senha) do
    case Operator.validar_senha(Segredo.expor(senha)) do
      {:ok, hash} -> definir(op, hash)
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp definir(op, hash) do
    segredo = SegundoFator.gerar_segredo()
    {cadastro, resumo} = novo_codigo()
    agora = DateTime.utc_now(:second)

    {1, _} = Repo.update_all(from(o in Operator, where: o.id == ^op.id), inc: [password_epoch: 1])

    op =
      op
      |> Ecto.Changeset.change(
        password_hash: hash,
        totp_secret: Segredo.expor(segredo),
        totp_confirmed_at: nil,
        totp_last_used_step: nil,
        second_factor_failures: 0,
        failed_attempts: 0,
        last_failed_at: nil,
        setup_code_hash: nil,
        setup_code_expires_at: nil,
        enrollment_code_hash: resumo,
        enrollment_code_expires_at: DateTime.add(agora, @validade_curta_s, :second),
        ack_code_hash: nil,
        ack_code_expires_at: nil
      )
      |> Repo.update!()

    # Relido: a época subiu por `update_all`, e a struct do changeset ainda traz a de antes. Uma
    # sessão aberta com ela nasceria recusada por `:epoca_velha`.
    op = Repo.get!(Operator, op.id)

    # Os códigos de recuperação anteriores deixam de valer; os já usados guardam o `used_at` (T8).
    Repo.update_all(
      from(r in RecoveryCode,
        where: r.operator_id == ^op.id and is_nil(r.used_at) and is_nil(r.invalidated_at)
      ),
      set: [invalidated_at: agora]
    )

    {:ok, _} = Sessions.encerrar_do_operador(op)
    AccessEvents.operador_senha_definida(op.id)

    {:ok,
     {op,
      %{segredo: segredo, uri: SegundoFator.uri(segredo, op.email), enrollment_token: cadastro}}}
  end

  @doc """
  O segundo passo: confere o código de cadastro e o TOTP contra o segredo pendente, e entrega os
  dez códigos de recuperação e o código de guarda. **Não habilita a entrada**: `totp_confirmed_at`
  continua nulo, e só `concluir_cadastro/2` o grava.
  """
  @spec confirmar_segundo_fator(String.t(), Segredo.t(), Segredo.t()) ::
          {:ok, {Operator.t(), [Segredo.t()], Segredo.t()}}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def confirmar_segundo_fator(email, enrollment_token, codigo) when is_binary(email) do
    passo(email, &AccessEvents.operador_cadastro_recusado/2, fn op ->
      with :ok <-
             codigo_vale(
               op,
               :enrollment_code_hash,
               :enrollment_code_expires_at,
               enrollment_token,
               :codigo_de_cadastro,
               &AccessEvents.operador_cadastro_recusado/2
             ),
           do: confirmar_se_o_totp_vale(op, codigo)
    end)
  end

  # O TOTP errado NÃO consome o código de cadastro, e conta só em `failed_attempts` (T12).
  defp confirmar_se_o_totp_vale(op, codigo) do
    case SegundoFator.conferir(segredo_totp(op), codigo, nil, DateTime.utc_now()) do
      {:ok, passo} -> confirmar(op, passo)
      {:error, _} -> falhar_passo(op, :totp_errado, &AccessEvents.operador_cadastro_recusado/2)
    end
  end

  defp confirmar(op, passo) do
    codigos = SegundoFator.gerar_codigos_de_recuperacao()
    {guarda, resumo} = novo_codigo()
    agora = DateTime.utc_now(:second)

    Repo.insert_all(
      RecoveryCode,
      Enum.map(
        codigos,
        &%{
          id: Ecto.UUID.generate(),
          operator_id: op.id,
          code_hash: SegundoFator.resumo(&1),
          inserted_at: agora
        }
      )
    )

    op =
      op
      |> Ecto.Changeset.change(
        totp_last_used_step: passo,
        failed_attempts: 0,
        last_failed_at: nil,
        enrollment_code_hash: nil,
        enrollment_code_expires_at: nil,
        ack_code_hash: resumo,
        ack_code_expires_at: DateTime.add(agora, @validade_curta_s, :second)
      )
      |> Repo.update!()

    {:ok, {op, codigos, guarda}}
  end

  @doc """
  O terceiro passo: a pessoa declarou que guardou os códigos de recuperação (a caixa, que o
  controller confere). Consome o código de guarda, grava `totp_confirmed_at`, sobe a época e encerra
  as sessões. **É a única função que habilita a entrada.** Nunca devolve os códigos.
  """
  @spec concluir_cadastro(String.t(), Segredo.t()) ::
          {:ok, Operator.t()}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def concluir_cadastro(email, acknowledgement_token) when is_binary(email) do
    passo(email, &AccessEvents.operador_cadastro_recusado/2, fn op ->
      with :ok <-
             codigo_vale(
               op,
               :ack_code_hash,
               :ack_code_expires_at,
               acknowledgement_token,
               :codigo_de_guarda,
               &AccessEvents.operador_cadastro_recusado/2
             ) do
        {1, _} =
          Repo.update_all(from(o in Operator, where: o.id == ^op.id), inc: [password_epoch: 1])

        op =
          op
          |> Ecto.Changeset.change(
            totp_confirmed_at: DateTime.utc_now(:second),
            failed_attempts: 0,
            last_failed_at: nil,
            ack_code_hash: nil,
            ack_code_expires_at: nil
          )
          |> Repo.update!()

        # Relido, pela mesma razão do passo 1: a época subiu por `update_all`.
        op = Repo.get!(Operator, op.id)
        {:ok, _} = Sessions.encerrar_do_operador(op)
        AccessEvents.operador_segundo_fator_cadastrado(op.id)
        {:ok, op}
      end
    end)
  end

  @doc """
  Emite o código de definição (interna ao contexto: só `TheBand.Platform.Grants` chama). 20 bytes
  aleatórios em base32 minúscula; grava o `sha256` e a validade de 30 minutos, **substituindo** o
  anterior, e devolve o bruto **uma vez**. Roda na transação de quem chama.
  """
  @spec emitir_codigo(Operator.t()) :: {:ok, Segredo.t()}
  def emitir_codigo(%Operator{} = op) do
    {codigo, resumo} = novo_codigo()

    op
    |> Ecto.Changeset.change(
      setup_code_hash: resumo,
      setup_code_expires_at:
        DateTime.add(DateTime.utc_now(:second), @validade_da_definicao_s, :second)
    )
    |> Repo.update!()

    {:ok, codigo}
  end

  # O esqueleto dos três passos: o e-mail resolve, a linha é travada, a espera e a concessão são
  # conferidas, e só então o passo roda. A recusa volta de dentro da transação (A1).
  defp passo(email, evento, fun) do
    case operador_por_email(email) do
      nil ->
        custo_do_hash(:sem_senha_a_conferir)
        evento.(nil, :identificador_nao_resolveu)
        {:error, :invalid_credentials}

      id ->
        transacao_do_passo(id, evento, fun)
    end
  end

  defp transacao_do_passo(id, evento, fun) do
    case Repo.transaction(fn -> dentro_do_passo(travado(id), evento, fun) end) do
      {:ok, resultado} -> resultado
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  defp dentro_do_passo(op, evento, fun) do
    with :ok <- fora_da_janela(op),
         :ok <- concessao_do_passo(op, evento),
         do: fun.(op)
  end

  # Sem concessão vigente, a recusa única com o custo do hash, e SEM contar falha (A14).
  defp concessao_do_passo(%Operator{id: id} = op, evento) do
    if Repo.exists?(from g in Grant, where: g.operator_id == ^id and is_nil(g.revoked_at)) do
      :ok
    else
      custo_do_hash(:sem_senha_a_conferir)
      evento.(op.id, :sem_concessao)
      {:error, :invalid_credentials}
    end
  end

  # O código do passo vale? Ausente, vencido ou errado é a mesma recusa, com o custo do hash, e
  # conta falha. A comparação é em tempo constante, sobre o `sha256`.
  defp codigo_vale(op, coluna_hash, coluna_validade, bruto, prefixo, evento) do
    guardado = Map.fetch!(op, coluna_hash)
    validade = Map.fetch!(op, coluna_validade)

    cond do
      is_nil(guardado) ->
        falhar_passo(op, :sem_codigo, evento)

      DateTime.compare(validade, DateTime.utc_now(:second)) != :gt ->
        falhar_passo(op, :"#{prefixo}_vencido", evento)

      not Plug.Crypto.secure_compare(resumo_do_codigo(bruto), guardado) ->
        falhar_passo(op, :"#{prefixo}_errado", evento)

      true ->
        :ok
    end
  end

  defp falhar_passo(op, motivo, evento) do
    custo_do_hash(:sem_senha_a_conferir)

    op
    |> Ecto.Changeset.change(
      failed_attempts: op.failed_attempts + 1,
      last_failed_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()

    evento.(op.id, motivo)
    {:error, :invalid_credentials}
  end

  defp novo_codigo do
    bruto = :crypto.strong_rand_bytes(20) |> Base.encode32(case: :lower, padding: false)
    {Segredo.novo(bruto), :crypto.hash(:sha256, bruto)}
  end

  defp resumo_do_codigo(bruto), do: :crypto.hash(:sha256, Segredo.expor(bruto))

  # Cada custo de hash passa por aqui, e emite um evento de telemetria — seguranca-autenticacao.md,
  # cenário 2 (A3). É o que permite ao teste CONTAR que a recusa por espera e a do e-mail
  # inexistente pagaram o hash, sem cronômetro, que seria instável com o custo baixo do teste.
  defp custo_do_hash(motivo) do
    Bcrypt.no_user_verify()
    :telemetry.execute([:the_band, :platform, :custo_do_hash], %{}, %{motivo: motivo})
  end

  defp conferir_senha(senha, hash) do
    certa? = Bcrypt.verify_pass(Segredo.expor(senha), hash)
    :telemetry.execute([:the_band, :platform, :custo_do_hash], %{}, %{motivo: :senha_conferida})
    certa?
  end

  defp recusar(op, motivo) do
    AccessEvents.operador_entrada_recusada(op && op.id, motivo)
    {:error, :invalid_credentials}
  end
end
