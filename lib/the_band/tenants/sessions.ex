defmodule TheBand.Tenants.Sessions do
  @moduledoc """
  Abrir, conferir e encerrar sessão — feature 064, T011, FR-004. O contrato é
  `specs/064-segredo-em-repouso/contracts/sessoes.md`.

  Depende de: nenhuma ontologia. É infraestrutura de acesso, como `TheBand.Tenants.ApiTokens`.

  ## O banco guarda só o resumo

  O token tem 32 bytes aleatórios, e a linha guarda `sha256(bruto)`. É SHA-256, e não bcrypt:
  32 bytes de entropia real não têm dicionário para atacar, e o custo do bcrypt viraria
  latência em toda requisição. Também não é HMAC: contra quem **lê** o banco a pré-imagem já é
  inviável, e a chave amarraria a invalidação de toda sessão ao giro dela. É a mesma decisão da
  ADR 0010 para o token da API.

  ## O bruto viaja como `Segredo.t()`

  De `abrir/1` até o `put_session`, e de volta do cookie até `conferir/2`. Um
  `FunctionClauseError` imprime os argumentos, e foi assim que um token do GitHub ficou oito
  dias em `oban_jobs.errors` (H17). A garantia é pelo tipo (FR-006), e não pela atenção de quem
  escreve.

  ## A validade é por sessão

  Sete dias contados de `inserted_at` **desta** sessão. A regra anterior contava de
  `users.logged_in_at`, que é por conta: um login legítimo em outro aparelho estendia a sessão
  roubada (S6).
  """

  import Ecto.Query, only: [from: 2]

  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.User

  @bytes 32

  @validade_em_dias 7

  # Decisão P3 de 2026-09-28: a linha fica 90 dias depois de deixar de valer, para investigação,
  # e então sai. Guardada para sempre, seria trilha de atividade de pessoa em todo backup.
  @retencao_em_dias 90

  @type motivo ::
          :malformado | :inexistente | :resumo_errado | :encerrada | :vencida | :epoca_velha

  @doc """
  Abre uma sessão para a conta, e devolve o bruto **uma vez**.

  A época gravada é a da struct recebida, que deve ser a da mesma leitura que conferiu a senha.
  Se uma senha for definida entre essa leitura e esta gravação, a sessão nasce com a época
  velha, e já nasce recusada (S2).
  """
  @spec abrir(User.t()) :: {:ok, {UserSession.t(), Segredo.t()}} | {:error, Ecto.Changeset.t()}
  def abrir(%User{id: user_id, tenant_id: tenant_id, password_epoch: epoca}) do
    bruto = @bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    %UserSession{}
    |> UserSession.changeset(%{
      tenant_id: tenant_id,
      user_id: user_id,
      token_hash: resumo(bruto),
      password_epoch: epoca
    })
    |> Repo.insert()
    |> case do
      {:ok, sessao} -> {:ok, {sessao, Segredo.novo(bruto)}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Confere uma sessão apresentada. Quem chama trata **todo** motivo como uma recusa só; o motivo
  existe para o log interno.

  Ausência é recusa por cabeça de função, e nunca `raise` (S4): um cookie sem id, sem token, ou
  com o token como binário nu é `:malformado`.
  """
  @spec conferir(term(), term()) :: {:ok, UserSession.t(), User.t()} | {:error, motivo()}
  def conferir(id, segredo) when is_binary(id) do
    with true <- Segredo.segredo?(segredo) || :malformado,
         {:ok, uuid} <- Ecto.UUID.cast(id),
         {%UserSession{} = sessao, %User{} = user} <- por_id(uuid),
         true <- confere?(sessao, segredo) || :resumo_errado,
         :ok <- aberta(sessao),
         :ok <- no_prazo(sessao),
         :ok <- mesma_epoca(sessao, user.password_epoch) do
      {:ok, sessao, Repo.preload(user, :tenant)}
    else
      :error -> {:error, :malformado}
      nil -> {:error, :inexistente}
      motivo when is_atom(motivo) -> {:error, motivo}
    end
  end

  def conferir(_id, _segredo), do: {:error, :malformado}

  @doc """
  De quem é a sessão, para o log de uma recusa (achado H4: a queda diz de quem era).

  Só depois de uma recusa, e só pela chave primária. Nunca serve para decidir acesso: quem decide
  é `conferir/2`.
  """
  @spec dona(term()) :: {Ecto.UUID.t(), Ecto.UUID.t()} | nil
  def dona(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.one(from(s in UserSession, where: s.id == ^uuid, select: {s.user_id, s.tenant_id}))

      :error ->
        nil
    end
  end

  def dona(_), do: nil

  @doc "Encerra aquela sessão. Encerrar de novo não muda a data do primeiro encerramento."
  @spec encerrar(UserSession.t()) :: :ok
  def encerrar(%UserSession{id: id}) do
    Repo.update_all(from(s in UserSession, where: s.id == ^id and is_nil(s.ended_at)),
      set: [ended_at: agora()]
    )

    :ok
  end

  @doc """
  Apaga as sessões que deixaram de valer há mais de 90 dias — T020, decisão P3. É o **único**
  caminho que apaga.

  Duas condições, e não só a primeira: a sessão encerrada tem `ended_at`, e a que **venceu** sem
  ninguém a encerrar não tem. Sem a segunda, a vencida ficaria para sempre, que é o registro
  permanente da FR-015: foi a ausência de `cancelled_at` que tornou permanentes quatro jobs do
  Oban, um deles com segredo.
  """
  @spec apagar_as_que_deixaram_de_valer(DateTime.t()) :: {:ok, non_neg_integer()}
  def apagar_as_que_deixaram_de_valer(agora \\ DateTime.utc_now(:second)) do
    encerrada_antes = DateTime.add(agora, -@retencao_em_dias, :day)
    aberta_antes = DateTime.add(agora, -(@validade_em_dias + @retencao_em_dias), :day)

    {n, _} =
      Repo.delete_all(
        from(s in UserSession,
          where: s.ended_at < ^encerrada_antes or s.inserted_at < ^aberta_antes
        )
      )

    {:ok, n}
  end

  @doc """
  Encerra toda sessão aberta da conta, e devolve quantas encerrou.

  É chamada dentro da transação de `Tenants.disable_user/4` (S1): sem isso, reativar a conta
  devolveria toda sessão aberta antes da desativação, inclusive a que motivou desligar alguém.
  """
  @spec encerrar_da_conta(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, non_neg_integer()}
  def encerrar_da_conta(tenant_id, user_id) do
    {n, _} =
      Repo.update_all(
        from(s in UserSession,
          where: s.tenant_id == ^tenant_id and s.user_id == ^user_id and is_nil(s.ended_at)
        ),
        set: [ended_at: agora()]
      )

    {:ok, n}
  end

  @doc """
  Encerra toda sessão aberta, de todos os tenants. É o giro operacional (T016), e o passo
  **obrigatório** depois de restaurar um backup (P5): a restauração devolve as sessões
  encerradas depois da cópia, e as encerradas por segurança estão entre elas.
  """
  @spec girar_todas() :: {:ok, non_neg_integer()}
  def girar_todas do
    {n, _} =
      Repo.update_all(from(s in UserSession, where: is_nil(s.ended_at)),
        set: [ended_at: agora()]
      )

    {:ok, n}
  end

  # A conta vem na mesma consulta, e com ela a época. Duas leituras deixariam uma senha definida
  # entre elas passar. E é a conta que quem chama usa: a sessão e a decisão saem da mesma linha.
  # O tenant é pré-carregado depois, e o total fica em duas consultas por requisição, as mesmas
  # que `Tenants.fetch_user/1` fazia antes da T013.
  defp por_id(uuid) do
    Repo.one(
      from(s in UserSession,
        join: u in User,
        on: u.id == s.user_id and u.tenant_id == s.tenant_id,
        where: s.id == ^uuid,
        select: {s, u}
      )
    )
  end

  # `secure_compare` em memória, e nunca `==`. A linha foi achada pela chave primária, e não
  # pelo resumo, então esta comparação é a que decide (S8).
  defp confere?(%UserSession{token_hash: gravado}, segredo) do
    Plug.Crypto.secure_compare(gravado, resumo(Segredo.expor(segredo)))
  end

  defp aberta(%UserSession{ended_at: nil}), do: :ok
  defp aberta(%UserSession{}), do: :encerrada

  defp no_prazo(%UserSession{inserted_at: aberta_em}) do
    limite = DateTime.add(agora(), -@validade_em_dias, :day)
    if DateTime.compare(aberta_em, limite) == :gt, do: :ok, else: :vencida
  end

  defp mesma_epoca(%UserSession{password_epoch: epoca}, epoca), do: :ok
  defp mesma_epoca(%UserSession{}, _atual), do: :epoca_velha

  defp resumo(bruto), do: :crypto.hash(:sha256, bruto)

  defp agora, do: DateTime.utc_now(:second)
end
