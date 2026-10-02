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

  alias TheBand.Platform.{Grant, Operator, RecoveryCode, SegundoFator}
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
        Bcrypt.no_user_verify()
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
      Bcrypt.no_user_verify()
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
      Bcrypt.no_user_verify()
      recusar(op, :sem_concessao)
    end
  end

  defp senha_certa(%Operator{password_hash: nil} = op, _senha) do
    Bcrypt.no_user_verify()
    falhar(op, :sem_senha, false)
  end

  defp senha_certa(%Operator{password_hash: hash} = op, senha) do
    if Bcrypt.verify_pass(Segredo.expor(senha), hash),
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

  defp recusar(op, motivo) do
    AccessEvents.operador_entrada_recusada(op && op.id, motivo)
    {:error, :invalid_credentials}
  end
end
