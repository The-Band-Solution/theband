defmodule TheBand.Changes.Commands do
  @moduledoc """
  Gravação das mudanças coletadas — feature 032.

  O mesmo contrato das demais coletas: upsert idempotente por identidade externa,
  reobservar limpa a marca, sumir marca e nunca apaga.
  """

  import Ecto.Query

  alias TheBand.Changes.Schemas.{
    ChangeRequestIssue,
    CollectedChangeRequest,
    CollectedCommit,
    CommitAuthor,
    CommitFile
  }

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc "Grava (ou reobserva) uma solicitação de mudança."
  @spec record_change_request(Tenant.t(), map()) ::
          {:ok, CollectedChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def record_change_request(%Tenant{id: tenant_id}, attrs) do
    upsert(CollectedChangeRequest, tenant_id, attrs[:external_id], attrs)
  end

  @doc "Grava (ou reobserva) um commit."
  @spec record_commit(Tenant.t(), map()) ::
          {:ok, CollectedCommit.t()} | {:error, Ecto.Changeset.t()}
  def record_commit(%Tenant{id: tenant_id}, attrs) do
    upsert(CollectedCommit, tenant_id, attrs[:external_id], attrs)
  end

  defp upsert(schema, tenant_id, external_id, attrs) do
    now = DateTime.utc_now(:second)
    base = Repo.get_by(schema, tenant_id: tenant_id, external_id: external_id) || struct(schema)

    base
    |> schema.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end

  @doc """
  Substitui os autores de um commit pelo conjunto observado agora.

  **Substitui, e não acrescenta**: a lista de autores é o que a origem entrega junto do
  commit, e um autor que sumiu de lá não deve continuar vigente aqui. Quem sumiu é
  marcado, nunca apagado — a regra da casa vale para vínculo também.
  """
  @spec replace_commit_authors(Tenant.t(), Ecto.UUID.t(), [map()]) :: :ok
  def replace_commit_authors(%Tenant{id: tenant_id} = tenant, commit_id, autores) do
    now = DateTime.utc_now(:second)

    Enum.each(autores, fn autor ->
      base = autor_existente(tenant_id, commit_id, autor) || %CommitAuthor{}

      {:ok, _} =
        base
        |> CommitAuthor.changeset(
          autor
          |> Map.put(:tenant_id, tenant_id)
          |> Map.put(:collected_commit_id, commit_id)
          |> Map.put(:collected_at, base.collected_at || now)
          |> Map.put(:last_observed_at, now)
          |> Map.put(:no_longer_observed_at, nil)
        )
        |> Repo.insert_or_update()
    end)

    marcar_autores_sumidos(tenant, commit_id, Enum.map(autores, & &1[:author_login]), now)
  end

  # Autor sem conta no GitHub tem login nulo (o "ghost", e commits importados) — e
  # comparar com nil no Ecto é proibido, com razão: `= NULL` nunca casa em SQL. A
  # identificação cai para o e-mail, que é o que resta de identidade nesse caso.
  defp autor_existente(tenant_id, commit_id, %{author_login: nil, author_email: email}) do
    Repo.one(
      from a in CommitAuthor,
        where:
          a.tenant_id == ^tenant_id and a.collected_commit_id == ^commit_id and
            is_nil(a.author_login) and a.author_email == ^email,
        limit: 1
    )
  end

  defp autor_existente(tenant_id, commit_id, %{author_login: login}) do
    Repo.one(
      from a in CommitAuthor,
        where:
          a.tenant_id == ^tenant_id and a.collected_commit_id == ^commit_id and
            a.author_login == ^login,
        limit: 1
    )
  end

  # **Marca quem NÃO está na lista, e não quem tem timestamp antigo.** Comparar
  # `last_observed_at < now` falha quando as duas gravações caem no mesmo segundo —
  # `utc_now(:second)` trunca, e um teste pegou isso. O conjunto observado é a verdade.
  defp marcar_autores_sumidos(%Tenant{id: tenant_id}, commit_id, [], now) do
    Repo.update_all(
      from(a in CommitAuthor,
        where:
          a.tenant_id == ^tenant_id and a.collected_commit_id == ^commit_id and
            is_nil(a.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: now]
    )

    :ok
  end

  defp marcar_autores_sumidos(%Tenant{id: tenant_id}, commit_id, logins, now) do
    Repo.update_all(
      from(a in CommitAuthor,
        where:
          a.tenant_id == ^tenant_id and a.collected_commit_id == ^commit_id and
            is_nil(a.no_longer_observed_at) and
            (is_nil(a.author_login) or a.author_login not in ^logins)
      ),
      set: [no_longer_observed_at: now]
    )

    :ok
  end

  @doc """
  Grava os arquivos de um commit e marca o commit como percorrido.

  Substitui o conjunto: arquivo que a origem não trouxe de volta é marcado, nunca
  apagado. E `files_collected_at` no commit distingue "não coletado" de "commit sem
  arquivo" — as duas coisas não são a mesma frase na tela.
  """
  @spec replace_commit_files(Tenant.t(), Ecto.UUID.t(), [map()]) :: :ok
  def replace_commit_files(%Tenant{id: tenant_id}, commit_id, arquivos) do
    now = DateTime.utc_now(:second)

    Enum.each(arquivos, &gravar_arquivo(tenant_id, commit_id, &1, now))
    marcar_arquivos_sumidos(tenant_id, commit_id, Enum.map(arquivos, & &1.path), now)

    Repo.update_all(
      from(c in CollectedCommit, where: c.tenant_id == ^tenant_id and c.id == ^commit_id),
      set: [files_collected_at: now]
    )

    :ok
  end

  defp gravar_arquivo(tenant_id, commit_id, arquivo, now) do
    base =
      Repo.one(
        from f in CommitFile,
          where:
            f.tenant_id == ^tenant_id and f.collected_commit_id == ^commit_id and
              f.path == ^arquivo.path,
          limit: 1
      ) || %CommitFile{}

    {:ok, _} =
      base
      |> CommitFile.changeset(
        arquivo
        |> Map.put(:tenant_id, tenant_id)
        |> Map.put(:collected_commit_id, commit_id)
        |> Map.put(:collected_at, base.collected_at || now)
        |> Map.put(:last_observed_at, now)
        |> Map.put(:no_longer_observed_at, nil)
      )
      |> Repo.insert_or_update()
  end

  # Marca por CONJUNTO observado, nunca por timestamp: comparar `last_observed_at < now`
  # falha quando as duas gravações caem no mesmo segundo — foi o defeito que um teste
  # pegou na 032, e a lição vale aqui de saída.
  defp marcar_arquivos_sumidos(tenant_id, commit_id, [], now) do
    Repo.update_all(
      from(f in CommitFile,
        where:
          f.tenant_id == ^tenant_id and f.collected_commit_id == ^commit_id and
            is_nil(f.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: now]
    )
  end

  defp marcar_arquivos_sumidos(tenant_id, commit_id, caminhos, now) do
    Repo.update_all(
      from(f in CommitFile,
        where:
          f.tenant_id == ^tenant_id and f.collected_commit_id == ^commit_id and
            is_nil(f.no_longer_observed_at) and f.path not in ^caminhos
      ),
      set: [no_longer_observed_at: now]
    )
  end

  @doc """
  Preenche a proveniência das issues atendidas a partir do payload preservado — **local**.

  As colunas nasceram na migração de 2026-08-19 e vieram nulas: as 5.035 solicitações já
  coletadas não tinham como saber o que a origem havia dito. Recoletá-las custaria milhares
  de chamadas.

  **Não precisou.** `raw_payload` guarda o nó inteiro, `closingIssuesReferences` incluído —
  e é exatamente para isto que `preserve_raw_payload: true` existe no mapeamento. O
  backfill lê de lá, resolve o que casa com issue já coletada, e deixa o resto em
  `attended_issues_unresolved` para a reconciliação pegar depois.

  Devolve o que mudou. Roda uma vez; depois disso a coleta grava sozinha.
  """
  @spec backfill_attended_provenance(Tenant.t()) ::
          {:ok, %{visited: integer(), linked: integer(), pending: integer()}}
  def backfill_attended_provenance(%Tenant{id: tenant_id} = tenant) do
    solicitacoes =
      Repo.all(
        from c in "collected_change_requests",
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and
              is_nil(c.no_longer_observed_at) and is_nil(c.attended_issues_total),
          select: %{id: type(c.id, :binary_id), payload: c.raw_payload}
      )

    Enum.reduce(solicitacoes, {:ok, %{visited: 0, linked: 0, pending: 0}}, fn cr, {:ok, acc} ->
      referencias = get_in(cr.payload, ["closingIssuesReferences"]) || %{}
      externos = Enum.map(referencias["nodes"] || [], & &1["id"])
      # `totalCount` e não `length(nodes)`: a conexão pagina, e só o total revela
      # truncamento da própria consulta.
      total = referencias["totalCount"] || length(externos)
      mapa = ids_de_issues(externos, tenant_id)
      pendentes = Enum.reject(externos, &Map.has_key?(mapa, &1))
      agora = DateTime.utc_now(:second)

      Enum.each(Map.values(mapa), &upsert_vinculo(tenant_id, cr.id, &1, agora))

      :ok = record_attended_provenance(tenant, cr.id, %{total: total, pendentes: pendentes})

      {:ok,
       %{
         visited: acc.visited + 1,
         linked: acc.linked + map_size(mapa),
         pending: acc.pending + length(pendentes)
       }}
    end)
  end

  @doc """
  Resolve os vínculos pendentes — **local, sem tocar na API**.

  A pendência existe porque a coleta de issues fica atrás da de solicitações, e a
  solicitação já mergeada não volta a ser percorrida. Sem esta função o vínculo nunca
  apareceria, mesmo depois da issue chegar ao banco.

  Devolve quantos vínculos passaram a existir. Zero significa que nenhuma das issues
  pendentes chegou ainda — é resposta, não falha.
  """
  @spec reconcile_attended_issues(Tenant.t()) ::
          {:ok, %{resolved: integer(), still_pending: integer()}}
  def reconcile_attended_issues(%Tenant{id: tenant_id}) do
    pendentes =
      Repo.all(
        from c in "collected_change_requests",
          where:
            c.tenant_id == type(^tenant_id, :binary_id) and
              is_nil(c.no_longer_observed_at) and
              fragment("array_length(?, 1) > 0", c.attended_issues_unresolved),
          select: %{
            id: type(c.id, :binary_id),
            unresolved: c.attended_issues_unresolved
          }
      )

    # Uma consulta para TODOS os externos pendentes, e não uma por solicitação: são
    # milhares de solicitações, e consultar por linha seria o defeito da feature 007.
    mapa =
      pendentes
      |> Enum.flat_map(& &1.unresolved)
      |> Enum.uniq()
      |> ids_de_issues(tenant_id)

    Enum.reduce(pendentes, {:ok, %{resolved: 0, still_pending: 0}}, fn cr, {:ok, acc} ->
      {chegaram, faltam} = Enum.split_with(cr.unresolved, &Map.has_key?(mapa, &1))
      novos = Enum.map(chegaram, &mapa[&1])

      agora = DateTime.utc_now(:second)
      Enum.each(novos, &upsert_vinculo(tenant_id, cr.id, &1, agora))

      # A lista pendente encolhe para o que ainda falta — nunca é zerada por otimismo.
      Repo.update_all(
        from(c in "collected_change_requests", where: c.id == type(^cr.id, :binary_id)),
        set: [attended_issues_unresolved: faltam]
      )

      {:ok,
       %{
         resolved: acc.resolved + length(novos),
         still_pending: acc.still_pending + length(faltam)
       }}
    end)
  end

  defp ids_de_issues([], _tenant_id), do: %{}

  defp ids_de_issues(externos, tenant_id) do
    Repo.all(
      from i in "collected_issues",
        where: i.tenant_id == type(^tenant_id, :binary_id) and i.external_id in ^externos,
        select: {i.external_id, type(i.id, :binary_id)}
    )
    |> Map.new()
  end

  @doc """
  Grava a proveniência das issues atendidas — o que a origem disse, e o que não resolveu.

  Separado de `replace_attended_issues/3` de propósito: aquela grava o **vínculo**, esta
  grava o **que faltou do vínculo**. Juntar as duas faria a segunda parecer detalhe de
  implementação da primeira, e foi exatamente por ser detalhe que o buraco ficou invisível
  (issue #438).
  """
  @spec record_attended_provenance(Tenant.t(), Ecto.UUID.t(), map()) :: :ok
  def record_attended_provenance(%Tenant{id: tenant_id}, change_request_id, %{
        total: total,
        pendentes: pendentes
      }) do
    Repo.update_all(
      from(c in "collected_change_requests",
        where:
          c.tenant_id == type(^tenant_id, :binary_id) and
            c.id == type(^change_request_id, :binary_id)
      ),
      set: [attended_issues_total: total, attended_issues_unresolved: pendentes]
    )

    :ok
  end

  @doc """
  Substitui os vínculos com issues pelo conjunto reconhecido agora.

  A origem é sempre `closing_reference`: é o que o GitHub reconheceu das closing
  keywords. Vínculo que sumiu de lá é marcado — o PR pode ter tido a keyword removida, e
  isso é fato sobre o registro, não apagamento.
  """
  @spec replace_attended_issues(Tenant.t(), Ecto.UUID.t(), [Ecto.UUID.t()]) :: :ok
  def replace_attended_issues(%Tenant{id: tenant_id}, change_request_id, issue_ids) do
    now = DateTime.utc_now(:second)

    Enum.each(issue_ids, &upsert_vinculo(tenant_id, change_request_id, &1, now))

    marcar_vinculos_sumidos(tenant_id, change_request_id, issue_ids, now)
  end

  # Um vínculo, sem marcar nada. **A reconciliação depende de ser ACRESCENTAR e não
  # SUBSTITUIR**: ela conhece só os pendentes que chegaram, e usar `replace_*` marcaria
  # como sumidos os vínculos que já existiam e não estavam na lista.
  defp upsert_vinculo(tenant_id, change_request_id, issue_id, now) do
    base =
      Repo.get_by(ChangeRequestIssue,
        tenant_id: tenant_id,
        collected_change_request_id: change_request_id,
        collected_issue_id: issue_id
      ) || %ChangeRequestIssue{}

    {:ok, _} =
      base
      |> ChangeRequestIssue.changeset(%{
        tenant_id: tenant_id,
        collected_change_request_id: change_request_id,
        collected_issue_id: issue_id,
        source: "closing_reference",
        collected_at: base.collected_at || now,
        last_observed_at: now,
        no_longer_observed_at: nil
      })
      |> Repo.insert_or_update()
  end

  # Mesma razão dos autores: o conjunto observado decide, nunca o timestamp.
  defp marcar_vinculos_sumidos(tenant_id, change_request_id, [], now) do
    Repo.update_all(
      from(v in ChangeRequestIssue,
        where:
          v.tenant_id == ^tenant_id and
            v.collected_change_request_id == ^change_request_id and
            is_nil(v.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: now]
    )

    :ok
  end

  defp marcar_vinculos_sumidos(tenant_id, change_request_id, issue_ids, now) do
    Repo.update_all(
      from(v in ChangeRequestIssue,
        where:
          v.tenant_id == ^tenant_id and
            v.collected_change_request_id == ^change_request_id and
            is_nil(v.no_longer_observed_at) and
            v.collected_issue_id not in type(^issue_ids, {:array, :binary_id})
      ),
      set: [no_longer_observed_at: now]
    )

    :ok
  end
end
