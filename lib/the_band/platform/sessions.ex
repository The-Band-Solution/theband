defmodule TheBand.Platform.Sessions do
  @moduledoc """
  A sessão do operador da plataforma — spec 070, T029. Contrato em
  `specs/070-operador-da-plataforma/contracts/sessao-do-operador.md`.

  Depende de: nenhuma ontologia. Tabela própria (`platform_operator_sessions`), lida só aqui, e
  nunca por `TheBand.Tenants.Sessions` nem por `TheBandWeb.Sessao`. Nenhuma função aceita `%User{}`.

  Na forma de `TheBand.Tenants.Sessions`: o banco guarda o `sha256` do token, o cookie leva o bruto,
  e a conferência compara em tempo constante. A diferença é a da conta mais poderosa: validade
  curta, inatividade que derruba, e a concessão relida a cada conferência.
  """
  import Ecto.Query

  alias TheBand.Platform.{Grant, Operator, OperatorSession}
  alias TheBand.Repo
  alias TheBand.Segredo

  @bytes 32

  # 8 horas: um turno. A sessão do operador alcança todas as organizações, e uma sessão roubada
  # vale pelo tempo que dura; as de organização duram 7 dias.
  @validade_s 8 * 3600

  # 30 minutos sem uso derrubam a sessão (A11; ASVS V3.3.2). Uma aba esquecida aberta não fica
  # suspendendo organizações pela tarde.
  @inatividade_s 30 * 60

  # `last_seen_at` é gravado no máximo uma vez por minuto: escrever a cada requisição seria uma
  # escrita por clique, e a granularidade da inatividade é de minutos.
  @intervalo_de_registro_s 60

  @retencao_em_dias 90

  @type motivo ::
          :malformado
          | :inexistente
          | :resumo_errado
          | :encerrada
          | :vencida
          | :inativa
          | :epoca_velha
          | :sem_concessao

  @doc """
  Abre uma sessão e devolve o bruto **uma vez**. A época gravada é a da struct recebida, que deve
  ser a da leitura que conferiu a senha.
  """
  @spec abrir(Operator.t()) ::
          {:ok, {OperatorSession.t(), Segredo.t()}} | {:error, Ecto.Changeset.t()}
  def abrir(%Operator{id: id, password_epoch: epoca}) do
    bruto = @bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    agora = DateTime.utc_now(:second)

    %OperatorSession{}
    |> Ecto.Changeset.change(
      operator_id: id,
      token_hash: resumo(bruto),
      password_epoch: epoca,
      last_seen_at: agora
    )
    |> Repo.insert()
    |> case do
      {:ok, sessao} -> {:ok, {sessao, Segredo.novo(bruto)}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Confere uma sessão apresentada. Quem chama trata **todo** motivo como uma recusa só; o motivo é
  para o log. Ausência é recusa por cabeça de função, nunca `raise`.

  A concessão vigente é lida **na mesma consulta** que a sessão: revogar o papel derruba a
  próxima conferência, sem cache que a deixe sobreviver.
  """
  @spec conferir(term(), term()) :: {:ok, OperatorSession.t(), Operator.t()} | {:error, motivo()}
  def conferir(id, segredo) when is_binary(id) do
    agora = DateTime.utc_now(:second)

    with true <- Segredo.segredo?(segredo) || :malformado,
         {:ok, uuid} <- Ecto.UUID.cast(id),
         {%OperatorSession{} = sessao, %Operator{} = op, concessao?} <- por_id(uuid),
         true <- confere?(sessao, segredo) || :resumo_errado,
         true <- is_nil(sessao.ended_at) || :encerrada,
         true <- DateTime.diff(agora, sessao.inserted_at) < @validade_s || :vencida,
         true <- DateTime.diff(agora, sessao.last_seen_at) < @inatividade_s || :inativa,
         true <- sessao.password_epoch == op.password_epoch || :epoca_velha,
         true <- concessao? || :sem_concessao do
      {:ok, registrar_uso(sessao, agora), op}
    else
      :error -> {:error, :malformado}
      nil -> {:error, :inexistente}
      motivo when is_atom(motivo) -> {:error, motivo}
    end
  end

  def conferir(_id, _segredo), do: {:error, :malformado}

  defp por_id(uuid) do
    Repo.one(
      from(s in OperatorSession,
        join: o in Operator,
        on: o.id == s.operator_id,
        left_join: g in Grant,
        on: g.operator_id == o.id and is_nil(g.revoked_at),
        where: s.id == ^uuid,
        select: {s, o, not is_nil(g.id)}
      )
    )
  end

  defp registrar_uso(sessao, agora) do
    corte = DateTime.add(agora, -@intervalo_de_registro_s, :second)

    case Repo.update_all(
           from(s in OperatorSession, where: s.id == ^sessao.id and s.last_seen_at < ^corte),
           set: [last_seen_at: agora]
         ) do
      {1, _} -> %{sessao | last_seen_at: agora}
      {0, _} -> sessao
    end
  end

  defp confere?(%OperatorSession{token_hash: gravado}, segredo),
    do: Plug.Crypto.secure_compare(gravado, resumo(Segredo.expor(segredo)))

  defp resumo(bruto), do: :crypto.hash(:sha256, bruto)

  @doc """
  A sessão ainda autoriza? Relida do banco, e não da struct: aberta, no prazo, na época da senha e
  com a concessão vigente (FR-014, O6). É o que toda função de `TheBand.Platform` confere **por
  dentro**, porque ter passado pelo plug não basta: a revogação pode ter vindo entre os dois.

  O `FOR SHARE` do ato (A15) entra com `suspender/3`, em T049.
  """
  @spec autorizada(OperatorSession.t()) :: :ok | {:error, :nao_autorizado}
  def autorizada(%OperatorSession{id: id}) do
    agora = DateTime.utc_now(:second)
    aberta_depois = DateTime.add(agora, -@validade_s, :second)
    usada_depois = DateTime.add(agora, -@inatividade_s, :second)

    consulta =
      from(s in OperatorSession,
        join: o in Operator,
        on: o.id == s.operator_id,
        join: g in Grant,
        on: g.operator_id == o.id and is_nil(g.revoked_at),
        where:
          s.id == ^id and is_nil(s.ended_at) and s.inserted_at > ^aberta_depois and
            s.last_seen_at > ^usada_depois and s.password_epoch == o.password_epoch,
        select: s.id
      )

    if Repo.exists?(consulta), do: :ok, else: {:error, :nao_autorizado}
  end

  @doc "Encerra aquela sessão. Encerrar de novo não muda a data do primeiro encerramento."
  @spec encerrar(OperatorSession.t()) :: :ok
  def encerrar(%OperatorSession{id: id}) do
    Repo.update_all(from(s in OperatorSession, where: s.id == ^id and is_nil(s.ended_at)),
      set: [ended_at: DateTime.utc_now(:second)]
    )

    :ok
  end

  @doc """
  Encerra toda sessão aberta do operador e devolve quantas. Roda **dentro da transação de quem
  chama**, e não abre a sua.
  """
  @spec encerrar_do_operador(Operator.t()) :: {:ok, non_neg_integer()}
  def encerrar_do_operador(%Operator{id: id}) do
    {n, _} =
      Repo.update_all(
        from(s in OperatorSession, where: s.operator_id == ^id and is_nil(s.ended_at)),
        set: [ended_at: DateTime.utc_now(:second)]
      )

    {:ok, n}
  end

  @doc "Encerra toda sessão de operador aberta. Só para o giro operacional de `TheBand.Release`."
  @spec encerrar_todas() :: {:ok, non_neg_integer()}
  def encerrar_todas do
    {n, _} =
      Repo.update_all(from(s in OperatorSession, where: is_nil(s.ended_at)),
        set: [ended_at: DateTime.utc_now(:second)]
      )

    {:ok, n}
  end

  @doc """
  Apaga as sessões que deixaram de valer há mais de 90 dias. É o **único** caminho que apaga. A
  encerrada tem `ended_at`; a que venceu sem ninguém a encerrar, não — as duas condições contam.
  """
  @spec apagar_as_que_deixaram_de_valer(DateTime.t()) :: {:ok, non_neg_integer()}
  def apagar_as_que_deixaram_de_valer(agora \\ DateTime.utc_now(:second)) do
    encerrada_antes = DateTime.add(agora, -@retencao_em_dias, :day)
    aberta_antes = DateTime.add(agora, -(@validade_s + @retencao_em_dias * 86_400), :second)

    {n, _} =
      Repo.delete_all(
        from(s in OperatorSession,
          where: s.ended_at < ^encerrada_antes or s.inserted_at < ^aberta_antes
        )
      )

    {:ok, n}
  end
end
