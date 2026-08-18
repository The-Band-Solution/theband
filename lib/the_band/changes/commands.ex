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
  Substitui os vínculos com issues pelo conjunto reconhecido agora.

  A origem é sempre `closing_reference`: é o que o GitHub reconheceu das closing
  keywords. Vínculo que sumiu de lá é marcado — o PR pode ter tido a keyword removida, e
  isso é fato sobre o registro, não apagamento.
  """
  @spec replace_attended_issues(Tenant.t(), Ecto.UUID.t(), [Ecto.UUID.t()]) :: :ok
  def replace_attended_issues(%Tenant{id: tenant_id}, change_request_id, issue_ids) do
    now = DateTime.utc_now(:second)

    Enum.each(issue_ids, fn issue_id ->
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
    end)

    marcar_vinculos_sumidos(tenant_id, change_request_id, issue_ids, now)
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
