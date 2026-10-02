defmodule TheBand.Platform.Grants do
  @moduledoc """
  A concessão do papel de operador da plataforma — spec 070, T030 (FR-001, FR-002, FR-014).
  Contrato em `specs/070-operador-da-plataforma/contracts/concessao-do-operador.md`.

  Depende de: nenhuma ontologia.

  Só o comando de release chama este módulo (`TheBand.Release`, T032): **nenhuma tela concede nem
  revoga o papel** (FR-001), e quem tomar uma conta pela web não consegue se promover. O comando não
  acrescenta poder a ninguém — quem o roda já tem o banco —; ele é o caminho **registrado**.

  `declarado_por` é texto **declarado** por quem rodou o comando, e não autor autenticado (O11).
  """
  import Ecto.Query

  alias TheBand.Platform.{Credentials, Grant, Operator, OperatorSession, RecoveryCode, Sessions}
  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.AccessEvents

  @doc """
  Concede o papel: cria o operador se não existir, abre a concessão e emite o código de
  definição. Com concessão vigente, `{:error, :ja_concedido}`.

  **Conceder de novo nunca devolve credencial antiga (A6)**: se o operador já existe sem concessão
  vigente, a credencial e o segundo fator são apagados, a época sobe e as sessões caem.
  """
  @spec conceder(String.t(), String.t(), String.t()) ::
          {:ok, {Operator.t(), Grant.t(), Segredo.t()}}
          | {:error, :ja_concedido}
          | {:error, Ecto.Changeset.t()}
  def conceder(email, nome, declarado_por) when is_binary(declarado_por) do
    Repo.transaction(fn ->
      op = operador_novo_ou_reiniciado(email, nome)

      grant =
        %Grant{}
        |> Ecto.Changeset.change(
          operator_id: op.id,
          granted_at: DateTime.utc_now(:second),
          granted_via: "release_command",
          granted_by_declared: declarado_por,
          email_at_grant: op.email
        )
        |> Ecto.Changeset.unique_constraint(:operator_id,
          name: :platform_operator_grants_vigente_index
        )
        |> Repo.insert()
        |> case do
          {:ok, grant} -> grant
          {:error, _} -> Repo.rollback(:ja_concedido)
        end

      {:ok, codigo} = Credentials.emitir_codigo(op)
      AccessEvents.operador_concedido(op.id, declarado_por)
      {op, grant, codigo}
    end)
  end

  defp operador_novo_ou_reiniciado(email, nome) do
    case operador_travado(email) do
      nil ->
        %Operator{}
        |> Ecto.Changeset.change(email: String.trim(email), name: nome)
        |> Ecto.Changeset.unique_constraint(:email, name: :platform_operators_email_index)
        |> Repo.insert()
        |> case do
          {:ok, op} -> op
          {:error, changeset} -> Repo.rollback(changeset)
        end

      op ->
        if vigente?(op.id), do: Repo.rollback(:ja_concedido), else: zerar_credencial(op)
    end
  end

  @doc """
  Reinicia a credencial de um operador com concessão vigente: apaga a senha e o segundo fator,
  sobe a época, encerra as sessões e emite um código de definição novo.
  """
  @spec reiniciar_credencial(String.t(), String.t()) :: {:ok, Segredo.t()} | {:error, :not_found}
  def reiniciar_credencial(email, declarado_por) when is_binary(declarado_por) do
    Repo.transaction(fn ->
      with %Operator{} = op <- operador_travado(email),
           true <- vigente?(op.id) do
        # A15: trava as sessões abertas antes de encerrá-las, para serializar com o `FOR SHARE`
        # que a suspensão em voo faz na linha da sessão.
        Repo.all(
          from(s in OperatorSession,
            where: s.operator_id == ^op.id and is_nil(s.ended_at),
            lock: "FOR UPDATE",
            select: s.id
          )
        )

        op = zerar_credencial(op)
        {:ok, codigo} = Credentials.emitir_codigo(op)
        AccessEvents.operador_credencial_reiniciada(op.id, declarado_por)
        codigo
      else
        _ -> Repo.rollback(:not_found)
      end
    end)
  end

  @doc """
  Revoga a concessão vigente, encerra as sessões do operador e anula os códigos pendentes, na
  mesma transação (FR-014, A14). A revogação é definitiva: concede-se de novo.
  """
  @spec revogar(String.t(), String.t(), String.t() | nil) ::
          {:ok, Grant.t()} | {:error, :not_found}
  def revogar(email, declarado_por, nota) when is_binary(declarado_por) do
    Repo.transaction(fn ->
      with %Operator{} = op <- operador_travado(email),
           {1, [grant]} <-
             Repo.update_all(
               from(g in Grant,
                 where: g.operator_id == ^op.id and is_nil(g.revoked_at),
                 select: g
               ),
               set: [
                 revoked_at: DateTime.utc_now(:second),
                 revoked_via: "release_command",
                 revoked_by_declared: declarado_por,
                 revoke_note: nota
               ]
             ) do
        {:ok, sessoes} = Sessions.encerrar_do_operador(op)
        anular_codigos_pendentes(op)
        AccessEvents.operador_revogado(op.id, declarado_por, sessoes)
        grant
      else
        _ -> Repo.rollback(:not_found)
      end
    end)
  end

  @doc "O operador tem concessão vigente?"
  @spec vigente?(Ecto.UUID.t()) :: boolean()
  def vigente?(operator_id),
    do:
      Repo.exists?(from g in Grant, where: g.operator_id == ^operator_id and is_nil(g.revoked_at))

  defp operador_travado(email) do
    Repo.one(
      from o in Operator,
        where: fragment("lower(?)", o.email) == ^String.downcase(String.trim(email)),
        lock: "FOR UPDATE"
    )
  end

  # O que `conceder/3` de novo (A6) e `reiniciar_credencial/2` fazem igual: nenhuma credencial de
  # antes sobrevive. Os códigos de recuperação vigentes ficam `invalidated_at`, e não apagados nem
  # `used_at`, que é só para o uso (T8).
  defp zerar_credencial(%Operator{} = op) do
    # UM `update_all`, e não um changeset, por duas razões medidas no teste:
    # - `totp_secret` tem `load_in_query: false`: a struct carrega `nil`, e `change(totp_secret:
    #   nil)` não é mudança nenhuma — o segredo antigo ficava no banco (A6, defeito pego por T031);
    # - os `CHECK`s do código de guarda: limpar o segundo fator e o código em escritas separadas
    #   passa por um estado que o banco recusa.
    {1, _} =
      Repo.update_all(from(o in Operator, where: o.id == ^op.id),
        inc: [password_epoch: 1],
        set: [
          password_hash: nil,
          totp_secret: nil,
          totp_confirmed_at: nil,
          totp_last_used_step: nil,
          second_factor_failures: 0,
          failed_attempts: 0,
          last_failed_at: nil,
          setup_code_hash: nil,
          setup_code_expires_at: nil,
          enrollment_code_hash: nil,
          enrollment_code_expires_at: nil,
          ack_code_hash: nil,
          ack_code_expires_at: nil
        ]
      )

    Repo.update_all(
      from(r in RecoveryCode,
        where: r.operator_id == ^op.id and is_nil(r.used_at) and is_nil(r.invalidated_at)
      ),
      set: [invalidated_at: DateTime.utc_now(:second)]
    )

    {:ok, _} = Sessions.encerrar_do_operador(op)
    Repo.get!(Operator, op.id)
  end

  defp anular_codigos_pendentes(%Operator{id: id}) do
    Repo.update_all(from(o in Operator, where: o.id == ^id),
      set: [
        setup_code_hash: nil,
        setup_code_expires_at: nil,
        enrollment_code_hash: nil,
        enrollment_code_expires_at: nil,
        ack_code_hash: nil,
        ack_code_expires_at: nil
      ]
    )
  end
end
