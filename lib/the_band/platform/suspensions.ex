defmodule TheBand.Platform.Suspensions do
  @moduledoc """
  Listar, suspender e reativar organizações — spec 070. Contrato em
  `specs/070-operador-da-plataforma/contracts/suspensao.md`; a transação em research R8.

  Depende de: nenhuma ontologia. Usa `TheBand.Tenants`, `TheBand.Tenants.Sessions` e
  `TheBand.Tenants.ApiTokens` **só pelas funções públicas**: este módulo não lê nem escreve a
  tabela `tenants`, nem usa o schema `Tenant` em consulta (constituição, princípio X, letra D;
  achado D1). As tabelas que ele consulta são as da `Platform`.

  **Toda função recebe a sessão do operador e confere a autorização por dentro** (FR-014, O6).

  ## O `%Tenant{}` não sai daqui (D1-d)

  O ato lê a organização uma vez, por `Tenants.get_by_slug/1`, e entrega a struct aos passos de
  `Tenants`. Nenhum retorno, de sucesso ou de recusa, a contém: quem chama recebe o episódio ou o
  motivo.
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias TheBand.Platform.{OperatorSession, Sessions, Suspension, SuspensionReasons}
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.ApiTokens
  alias TheBand.Tenants.Sessions, as: SessoesDasOrganizacoes

  @type resumo :: %{
          id: Ecto.UUID.t(),
          name: String.t(),
          slug: String.t(),
          status: String.t(),
          ultimo_episodio_em: DateTime.t() | nil,
          ultima_razao: String.t() | nil
        }

  @type motivo ::
          :nao_autorizado
          | :not_found
          | :ja_suspensa
          | :nao_suspensa
          | :sem_episodio_aberto
          | :vocabulario_nao_declarado
          | Changeset.t()

  @doc """
  Todas as organizações, por nome, com o estado e o início do último episódio de suspensão
  (FR-007). **Duas consultas, cada uma na tabela do seu dono**, compostas em memória pelo `id`:
  os resumos de `Tenants` e o `max(suspended_at)` por organização, da `Platform`. Sem junção com
  `tenants` (D1) e sem consulta por organização. `nil` é "nunca suspensa".
  """
  @spec listar_organizacoes(OperatorSession.t()) :: {:ok, [resumo()]} | {:error, :nao_autorizado}
  def listar_organizacoes(%OperatorSession{} = sessao) do
    with :ok <- Sessions.autorizada(sessao) do
      # O último episódio de cada organização, numa consulta: `DISTINCT ON` pelo `tenant_id`, o mais
      # novo primeiro. A razão vai junto para a lista dizer o caso da migração (D-3).
      ultimos =
        Repo.all(
          from(s in Suspension,
            distinct: s.tenant_id,
            order_by: [asc: s.tenant_id, desc: s.suspended_at],
            select: {s.tenant_id, {s.suspended_at, s.suspend_reason}}
          )
        )
        |> Map.new()

      {:ok,
       Enum.map(Tenants.resumos_para_a_plataforma(), fn resumo ->
         {em, razao} = Map.get(ultimos, resumo.id, {nil, nil})
         Map.merge(resumo, %{ultimo_episodio_em: em, ultima_razao: razao})
       end)}
    end
  end

  @doc """
  Uma organização, pelo `slug`: o resumo de `Tenants` e o histórico de episódios, do mais novo ao
  mais antigo, com quem abriu e quem fechou cada um.
  """
  @spec organizacao(OperatorSession.t(), String.t()) ::
          {:ok, %{resumo: map(), episodios: [Suspension.t()]}}
          | {:error, :not_found | :nao_autorizado}
  def organizacao(%OperatorSession{} = sessao, slug) when is_binary(slug) do
    with :ok <- Sessions.autorizada(sessao),
         {:ok, resumo} <- Tenants.resumo_para_a_plataforma(slug) do
      episodios =
        Repo.all(
          from(s in Suspension,
            where: s.tenant_id == ^resumo.id,
            order_by: [desc: s.suspended_at, desc: s.inserted_at],
            preload: [:suspended_by_operator, :reactivated_by_operator]
          )
        )

      {:ok, %{resumo: resumo, episodios: episodios}}
    end
  end

  @doc """
  Suspende a organização do `slug`, numa transação: o estado, o episódio aberto, as sessões
  encerradas e os tokens revogados (FR-003, FR-004, FR-013). Depois do `commit`, e só depois, as
  telas abertas são avisadas e o ato é registrado.
  """
  @spec suspender(OperatorSession.t(), String.t(), map()) ::
          {:ok, Suspension.t()} | {:error, motivo()}
  def suspender(%OperatorSession{} = sessao, slug, attrs)
      when is_binary(slug) and is_map(attrs) do
    with :ok <- vocabulario(),
         {:ok, tenant} <- organizacao(slug) do
      Repo.transaction(fn -> suspensao(sessao, tenant, attrs) end)
      |> depois_do_commit(:organizacao_suspensa, sessao, tenant.id)
    end
    |> registrar_recusa(sessao, slug)
  end

  @doc """
  Reativa a organização do `slug`: fecha o episódio aberto, volta a `active` e encerra **de novo**
  toda sessão aberta da organização (FR-005, FR-015). **Nenhum token volta** (FR-013).
  """
  @spec reativar(OperatorSession.t(), String.t(), map()) ::
          {:ok, Suspension.t()} | {:error, motivo()}
  def reativar(%OperatorSession{} = sessao, slug, attrs) when is_binary(slug) and is_map(attrs) do
    with :ok <- vocabulario(),
         {:ok, tenant} <- organizacao(slug) do
      Repo.transaction(fn -> reativacao(sessao, tenant, attrs) end)
      |> depois_do_commit(:organizacao_reativada, sessao, tenant.id)
    end
    |> registrar_recusa(sessao, slug)
  end

  # ------------------------------------------------------------------ os passos

  defp suspensao(sessao, tenant, attrs) do
    with {:ok, _} <- passo(:autorizacao, autorizar(sessao)),
         {:ok, changeset} <- passo(:razao, abertura(sessao, tenant.id, attrs)),
         {:ok, _} <- passo(:estado, Tenants.trocar_estado(tenant, "active", "suspended")),
         {:ok, ep} <- passo(:episodio, Repo.insert(changeset)),
         {:ok, ids} <- passo(:sessoes, SessoesDasOrganizacoes.encerrar_da_organizacao(tenant)),
         {:ok, n} <- passo(:tokens, ApiTokens.revogar_por_suspensao(tenant, ep.id)) do
      %{episodio: ep, sessoes: ids, tokens: n}
    else
      {:error, nome, valor} -> Repo.rollback({nome, valor})
    end
  end

  # O estado vem antes do episódio aberto: uma organização ativa é `:nao_suspensa`, e não
  # `:sem_episodio_aberto`.
  defp reativacao(sessao, tenant, attrs) do
    with {:ok, _} <- passo(:autorizacao, autorizar(sessao)),
         {:ok, _} <- passo(:estado, Tenants.trocar_estado(tenant, "suspended", "active")),
         {:ok, aberto} <- passo(:aberto, episodio_aberto(tenant.id)),
         {:ok, changeset} <- passo(:razao, fechamento(sessao, aberto, attrs)),
         {:ok, ep} <- passo(:episodio, Repo.update(changeset)),
         {:ok, ids} <- passo(:sessoes, SessoesDasOrganizacoes.encerrar_da_organizacao(tenant)) do
      %{episodio: ep, sessoes: ids, tokens: 0}
    else
      {:error, nome, valor} -> Repo.rollback({nome, valor})
    end
  end

  # Cada passo da transação devolve o nome junto com a recusa, para quem traduz saber qual
  # recusou, como os passos nomeados de research R8. `Repo.transaction/1` e `rollback`, e não
  # `Ecto.Multi`: o Dialyzer recusa o termo opaco dele nesta versão (2026-10-02).
  defp passo(_nome, {:ok, valor}), do: {:ok, valor}
  defp passo(nome, {:error, valor}), do: {:error, nome, valor}

  defp vocabulario do
    if SuspensionReasons.vocabulario_declarado?(),
      do: :ok,
      else: {:error, :vocabulario_nao_declarado}
  end

  # A única leitura de `tenants` do ato (U1).
  defp organizacao(slug) do
    case Tenants.get_by_slug(slug) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end

  defp autorizar(sessao) do
    case Sessions.autorizada(sessao, lock: true) do
      :ok -> {:ok, sessao.operator_id}
      {:error, :nao_autorizado} -> {:error, :nao_autorizado}
    end
  end

  defp abertura(sessao, tenant_id, attrs) do
    razao = attrs[:reason]
    oferecidas = SuspensionReasons.de_suspensao() |> Enum.map(& &1["code"])

    %Suspension{
      tenant_id: tenant_id,
      suspended_at: DateTime.utc_now(:second),
      suspended_by_operator_id: sessao.operator_id
    }
    |> Changeset.cast(%{suspend_reason: razao, suspend_note: attrs[:note]}, [
      :suspend_reason,
      :suspend_note
    ])
    |> Changeset.validate_required([:suspend_reason])
    |> Changeset.validate_inclusion(:suspend_reason, oferecidas)
    |> nota(:suspend_note, SuspensionReasons.nota_obrigatoria?(:suspender, razao || ""))
    |> Changeset.unique_constraint(:tenant_id, name: :tenant_suspensions_aberto_index)
    |> valido()
  end

  defp episodio_aberto(tenant_id) do
    case Repo.one(
           from(s in Suspension,
             where: s.tenant_id == ^tenant_id and is_nil(s.reactivated_at),
             lock: "FOR UPDATE"
           )
         ) do
      nil -> {:error, :sem_episodio_aberto}
      ep -> {:ok, ep}
    end
  end

  defp fechamento(sessao, %Suspension{} = ep, attrs) do
    razao = attrs[:reason]
    oferecidas = ep.suspend_reason |> SuspensionReasons.de_reativacao() |> Enum.map(& &1["code"])

    ep
    |> Changeset.cast(%{reactivate_reason: razao, reactivate_note: attrs[:note]}, [
      :reactivate_reason,
      :reactivate_note
    ])
    |> Changeset.put_change(:reactivated_at, DateTime.utc_now(:second))
    |> Changeset.put_change(:reactivated_by_operator_id, sessao.operator_id)
    |> Changeset.validate_required([:reactivate_reason])
    |> Changeset.validate_inclusion(:reactivate_reason, oferecidas)
    |> nota(:reactivate_note, SuspensionReasons.nota_obrigatoria?(:reativar, razao || ""))
    |> valido()
  end

  defp nota(changeset, campo, true), do: Changeset.validate_required(changeset, [campo])
  defp nota(changeset, _campo, false), do: changeset

  defp valido(%Changeset{valid?: true} = changeset), do: {:ok, changeset}
  defp valido(changeset), do: {:error, changeset}

  # ------------------------------------------------------ depois da transação

  defp depois_do_commit(
         {:ok, %{episodio: ep, sessoes: ids, tokens: tokens}},
         ato,
         sessao,
         tenant_id
       ) do
    # A2: o aviso só depois do `commit`. Antes, a hook reconferiria a sessão, a acharia aberta, e a
    # tela continuaria.
    Enum.each(ids, &SessoesDasOrganizacoes.avisar_encerramento({:sessao, &1}))

    AccessEvents.ato_de_plataforma(ato, tenant_id,
      operator_id: sessao.operator_id,
      episodio_id: ep.id,
      sessoes: length(ids),
      tokens: tokens
    )

    {:ok, ep}
  end

  defp depois_do_commit({:error, {passo, valor}}, ato, _sessao, tenant_id),
    do: {:error, do_contrato(traduzir(passo, valor), ato), tenant_id}

  # `:estado_mudou` é o motivo de `Tenants`; o do contrato depende do ato.
  defp do_contrato(:estado_mudou, :organizacao_suspensa), do: :ja_suspensa
  defp do_contrato(:estado_mudou, :organizacao_reativada), do: :nao_suspensa
  defp do_contrato(motivo, _ato), do: motivo

  defp traduzir(:autorizacao, _), do: :nao_autorizado
  defp traduzir(:estado, :estado_mudou), do: :estado_mudou
  defp traduzir(:estado, :not_found), do: :not_found
  defp traduzir(:aberto, :sem_episodio_aberto), do: :sem_episodio_aberto
  defp traduzir(:razao, %Changeset{} = changeset), do: changeset

  # O índice parcial recusou o segundo episódio aberto: outra suspensão confirmou primeiro.
  defp traduzir(:episodio, %Changeset{errors: [{:tenant_id, {_, [{:constraint, :unique} | _]}}]}),
    do: :estado_mudou

  defp traduzir(:episodio, %Changeset{} = changeset), do: changeset

  # A recusa sai daqui, uma por motivo, com o `tenant_id` quando o slug resolveu. O motivo do
  # passo é traduzido para o do contrato: `:estado_mudou` é `:ja_suspensa` ou `:nao_suspensa`.
  defp registrar_recusa({:ok, _} = ok, _sessao, _slug), do: ok

  defp registrar_recusa({:error, motivo, tenant_id}, sessao, _slug),
    do: recusar(sessao, tenant_id, motivo)

  defp registrar_recusa({:error, motivo}, sessao, _slug), do: recusar(sessao, nil, motivo)

  defp recusar(sessao, tenant_id, motivo) do
    AccessEvents.operador_ato_recusado(sessao.operator_id, tenant_id, para_o_log(motivo))
    {:error, motivo}
  end

  defp para_o_log(%Changeset{}), do: :razao_invalida
  defp para_o_log(motivo), do: motivo
end
