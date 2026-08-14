defmodule TheBand.WorkItems.Commands do
  @moduledoc "Escritas de WorkItems. A fronteira é `TheBand.WorkItems`."

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.DecompositionLink
  alias TheBand.WorkItems.Schemas.IssueAssignee
  alias TheBand.WorkItems.Schemas.IssueLabel
  alias TheBand.WorkItems.Schemas.IssuePromotion
  alias TheBand.WorkItems.Schemas.RefusedLink

  @doc """
  Grava ou atualiza a issue pela Application Reference. Idempotente.

  `issue_type` é gravado **cru**: normalizar destruiria o nome que a lacuna precisa
  mostrar.
  """
  @spec record_collected_issue(Tenant.t(), map()) ::
          {:ok, CollectedIssue.t()} | {:error, Ecto.Changeset.t()}
  def record_collected_issue(%Tenant{id: tenant_id}, attrs) do
    now = DateTime.utc_now(:second)

    base =
      Repo.get_by(CollectedIssue,
        tenant_id: tenant_id,
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        external_id: attrs[:external_id]
      ) || %CollectedIssue{}

    resultado =
      if is_nil(base.id), do: :created, else: se_mudou(base, attrs)

    base
    |> CollectedIssue.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      # Reobservar limpa a marca. Quem devolve vigência é a coleta.
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
    |> com_resultado(resultado)
  end

  # Os campos que decidem se a origem mudou alguma coisa.
  #
  # **`last_observed_at` e `collected_at` ficam de fora de propósito**: a coleta os escreve em
  # toda passada, e incluí-los faria toda issue parecer atualizada — que é o oposto do que
  # `records_updated` existe para dizer.
  #
  # `no_longer_observed_at` também fica fora: limpá-lo é reobservar, e reobservar sem mudança
  # de conteúdo não é atualização da origem. Quem quer saber que a marca saiu lê a marca.
  @comparaveis ~w(number title state state_reason body author_login author_person_id
                  milestone_title project_titles comment_count reaction_count issue_type
                  issue_type_external_id external_parent_id sub_issue_count
                  external_created_at external_updated_at external_closed_at)a

  defp se_mudou(base, attrs) do
    mudou? =
      Enum.any?(@comparaveis, fn campo ->
        Map.has_key?(attrs, campo) and Map.get(attrs, campo) != Map.get(base, campo)
      end)

    if mudou?, do: :updated, else: :unchanged
  end

  defp com_resultado({:ok, registro}, resultado), do: {:ok, %{registro | outcome: resultado}}
  defp com_resultado(outro, _resultado), do: outro

  @doc """
  Substitui os designados da issue pelos informados — **marcando** o que saiu, nunca apagando.

  ## A correção que a regra da plataforma exigiu

  A feature 006 apagava o que a origem não trouxesse mais, com a justificativa de que
  designação é atributo do agora. A pessoa mantenedora enunciou a regra — **nunca se apaga
  dados** —, que era a condição de reversão registrada naquela pesquisa.

  E a regra está certa: quem foi responsável por uma issue é parte de como o trabalho
  aconteceu. Reconstruir isso do payload bruto é arqueologia; marcar custa uma coluna e
  responde por consulta.

  Designado que **volta** a aparecer tem a marca limpa: quem devolve vigência é a coleta.

  `person_id` ausente é declaração: o login fica, o vínculo não. Criar a pessoa a partir da
  issue produziria registro sem a proveniência que a coleta de EO dá.
  """
  @spec replace_assignees(Tenant.t(), Ecto.UUID.t(), [map()]) :: {:ok, non_neg_integer()}
  def replace_assignees(%Tenant{id: tenant_id}, collected_issue_id, designados) do
    logins = Enum.map(designados, & &1.login)
    agora = DateTime.utc_now(:second)

    Repo.update_all(
      from(a in IssueAssignee,
        where:
          a.tenant_id == ^tenant_id and a.collected_issue_id == ^collected_issue_id and
            a.login not in ^logins and is_nil(a.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: agora]
    )

    for designado <- designados do
      base =
        Repo.get_by(IssueAssignee,
          collected_issue_id: collected_issue_id,
          login: designado.login
        ) || %IssueAssignee{}

      base
      |> IssueAssignee.changeset(
        designado
        |> Map.put(:tenant_id, tenant_id)
        |> Map.put(:collected_issue_id, collected_issue_id)
        # Reaparecer limpa a marca: quem devolve vigência é a coleta.
        |> Map.put(:no_longer_observed_at, nil)
      )
      |> Repo.insert_or_update()
    end

    {:ok, length(designados)}
  end

  @doc """
  Substitui os rótulos da issue pelos informados. Mesma semântica de `replace_assignees/3`:
  **marca** o que saiu, nunca apaga.

  O rótulo que a issue teve é fato sobre como o time a classificou, mesmo depois de removido.

  E o rótulo é **preservado e não promovido**: um rótulo `bug` não faz a issue um defeito.
  """
  @spec replace_labels(Tenant.t(), Ecto.UUID.t(), [map()]) :: {:ok, non_neg_integer()}
  def replace_labels(%Tenant{id: tenant_id}, collected_issue_id, rotulos) do
    nomes = Enum.map(rotulos, & &1.name)
    agora = DateTime.utc_now(:second)

    Repo.update_all(
      from(l in IssueLabel,
        where:
          l.tenant_id == ^tenant_id and l.collected_issue_id == ^collected_issue_id and
            l.name not in ^nomes and is_nil(l.no_longer_observed_at)
      ),
      set: [no_longer_observed_at: agora]
    )

    for rotulo <- rotulos do
      base =
        Repo.get_by(IssueLabel, collected_issue_id: collected_issue_id, name: rotulo.name) ||
          %IssueLabel{}

      base
      |> IssueLabel.changeset(
        rotulo
        |> Map.put(:tenant_id, tenant_id)
        |> Map.put(:collected_issue_id, collected_issue_id)
        |> Map.put(:no_longer_observed_at, nil)
      )
      |> Repo.insert_or_update()
    end

    {:ok, length(rotulos)}
  end

  @doc """
  Registra o que a regra decidiu — **inclusive quando não promove**.

  Append-only: uma issue que muda de conceito entre coletas ganha linha nova, e a
  vigente é a última. Issue sem registro de promoção é indistinguível de issue não
  processada, e é por isso que esta função é chamada sempre.
  """
  @spec record_promotion(Tenant.t(), map()) ::
          {:ok, IssuePromotion.t()} | {:error, Ecto.Changeset.t()}
  def record_promotion(%Tenant{id: tenant_id}, attrs) do
    %IssuePromotion{}
    |> IssuePromotion.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put_new(:promoted_at, DateTime.utc_now(:second))
    )
    |> Repo.insert()
  end

  @doc """
  Registra um vínculo de decomposição, **recusando ciclo antes de persistir**.

  A verificação é aqui e não no banco: `sro.rule04` diz que constraint de banco não pega
  ciclo transitivo em auto-relacionamento, e é preciso checar o caminho até a raiz.

  Devolve `{:error, {:cycle, caminho}}` com o caminho na ordem, e **persiste a recusa** —
  nomear o caminho depois da coleta exige que ele tenha sido gravado.

  As duas issues permanecem coletadas: recusa-se o vínculo, nunca a issue.
  """
  @spec record_decomposition_link(Tenant.t(), map()) ::
          {:ok, DecompositionLink.t()} | {:error, {:cycle, [String.t()]} | Ecto.Changeset.t()}
  def record_decomposition_link(%Tenant{id: tenant_id} = tenant, attrs) do
    pai = attrs[:parent_issue_id]
    parte = attrs[:child_issue_id]

    case caminho_ate_raiz(tenant_id, pai, parte) do
      {:cycle, caminho} ->
        recusar(tenant, %{
          parent_issue_id: pai,
          child_issue_id: parte,
          reason: "cycle",
          cycle_path: Enum.join(caminho, " → ")
        })

        {:error, {:cycle, caminho}}

      :ok ->
        now = DateTime.utc_now(:second)

        base =
          Repo.get_by(DecompositionLink, parent_issue_id: pai, child_issue_id: parte) ||
            %DecompositionLink{}

        base
        |> DecompositionLink.changeset(%{
          tenant_id: tenant_id,
          parent_issue_id: pai,
          child_issue_id: parte,
          observed_at: base.observed_at || now,
          last_observed_at: now,
          no_longer_observed_at: nil
        })
        |> Repo.insert_or_update()
    end
  end

  # Sobe de `pai` até a raiz. Se `parte` aparece no caminho, ligá-los fecharia o ciclo.
  defp caminho_ate_raiz(_tenant_id, pai, parte) when pai == parte,
    do: {:cycle, [pai, parte]}

  defp caminho_ate_raiz(tenant_id, pai, parte) do
    subir(tenant_id, pai, parte, [pai], 0)
  end

  # O limite existe para o caso patológico de o próprio grafo já estar cíclico no banco —
  # inserido por script ou por versão anterior sem a verificação. Sem ele, a subida não
  # terminaria.
  @profundidade_maxima 100

  defp subir(_tenant_id, _atual, _parte, caminho, @profundidade_maxima),
    do: {:cycle, Enum.reverse(caminho)}

  defp subir(tenant_id, atual, parte, caminho, nivel) do
    case Repo.one(
           from l in DecompositionLink,
             where:
               l.tenant_id == ^tenant_id and l.child_issue_id == ^atual and
                 is_nil(l.no_longer_observed_at),
             select: l.parent_issue_id,
             limit: 1
         ) do
      nil -> :ok
      ^parte -> {:cycle, Enum.reverse([parte | caminho])}
      acima -> subir(tenant_id, acima, parte, [acima | caminho], nivel + 1)
    end
  end

  @doc """
  Registra um vínculo recusado, com o motivo.

  `out_of_scope` cobre a parte que está em repositório fora do escopo observado: a
  relação existe e é registrada, e a parte não é promovida.
  """
  @spec recusar(Tenant.t(), map()) :: {:ok, RefusedLink.t()} | {:error, Ecto.Changeset.t()}
  def recusar(%Tenant{id: tenant_id}, attrs) do
    %RefusedLink{}
    |> RefusedLink.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put_new(:refused_at, DateTime.utc_now(:second))
    )
    |> Repo.insert()
  end

  @doc """
  Marca as issues do **repositório informado** que não apareceram nesta coleta.

  `repository_id` é obrigatório na assinatura, e **não existe versão de aridade 2**.
  É a L19 impedida no tipo: marcar por tenant marcaria as issues de repositórios que
  esta coleta nunca olhou — e numa organização de 14 repositórios, atingiria 13.
  """
  @spec mark_issues_no_longer_observed(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, non_neg_integer()}
  def mark_issues_no_longer_observed(%Tenant{id: tenant_id}, observed_repository_id, desde)
      when is_binary(observed_repository_id) do
    {count, _} =
      Repo.update_all(
        from(i in CollectedIssue,
          where:
            i.tenant_id == ^tenant_id and
              i.observed_repository_id == ^observed_repository_id and
              i.last_observed_at < ^desde and
              is_nil(i.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: DateTime.utc_now(:second)]
      )

    {:ok, count}
  end

  @doc """
  Marca os vínculos de decomposição **do repositório informado** que não apareceram nesta
  coleta.

  ## O escopo é o repositório do **pai**, e não é detalhe

  A origem declara a decomposição de cima para baixo: as partes vêm **dentro** da
  issue-pai, e a coleta lê essa lista uma vez por repositório. Quem afirma o vínculo é o
  pai — uma coleta do repositório da **filha** não vê a lista, e não tem como saber que o
  vínculo acabou.

  São **57** os vínculos cujo pai e filha estão em repositórios diferentes. Escopar pela
  filha os marcaria por engano toda vez que o repositório dela fosse coletado sem o do pai.

  E marcar por tenant seria a L19 no nível do vínculo: numa organização de 121
  repositórios, coletar um marcaria os vínculos dos outros 120. Por isso **não existe
  aridade 2** — a obrigatoriedade está no tipo, como na irmã de issue.

  ## Dois instantes, e eles não são o mesmo

  `desde` é o **corte** — o `started_at` da execução. A data **gravada** é o instante em
  que a ausência foi notada, que é o que `mark_issues_no_longer_observed/3`,
  `replace_assignees/3` e `replace_labels/3` já fazem. Gravar o `started_at` daria à mesma
  coluna dois significados em tabelas vizinhas.

  Cortar por "agora" em vez de pelo início da execução marcaria o vínculo que a **própria**
  execução acabou de gravar: `record_decomposition_link/2` carimba `last_observed_at` com o
  instante da escrita, sempre posterior ao início.

  ## Não reescreve marca existente

  `is_nil(no_longer_observed_at)` no `WHERE`. O que se registra é **quando deixou de ser
  visto**, não quando se olhou de novo — e uma segunda coleta sem mudança devolve `{:ok, 0}`.

  ## O escopo é o que foi olhado, e não o repositório

  Até 2026-08-14 esta função recebia o `observed_repository_id` e marcava os vínculos de
  **todos** os pais daquele repositório. Estava certa por acidente: só dizia a verdade
  enquanto a coleta era completa.

  Na coleta incremental da feature 020, reler 34 issues de um repositório com 4295 deixaria
  os outros 4261 pais sem revisão — e todos os vínculos deles com `last_observed_at` anterior
  ao corte. **A marca não pararia de funcionar: marcaria tudo.**

  Recebendo os pais efetivamente percorridos, "não apareceu" volta a significar algo em
  relação ao que foi olhado, que é a L19 — e a função passa a dizer, no tipo, o que sempre
  quis dizer.

  **Lista vazia devolve `{:ok, 0}`** e não marca nada: é o repositório pulado, e tratá-lo como
  "nenhum pai apareceu, marque tudo" é o defeito que esta assinatura existe para impedir.

  A troca é de assinatura, e não parâmetro opcional: o comportamento obtido por esquecimento
  não pode ser o que marca 4261 vínculos falsos.
  """
  @spec mark_decomposition_links_no_longer_observed(
          Tenant.t(),
          [Ecto.UUID.t()],
          DateTime.t()
        ) :: {:ok, non_neg_integer()}
  def mark_decomposition_links_no_longer_observed(%Tenant{}, [], _desde), do: {:ok, 0}

  def mark_decomposition_links_no_longer_observed(
        %Tenant{id: tenant_id},
        parent_issue_ids,
        desde
      )
      when is_list(parent_issue_ids) do
    {count, _} =
      Repo.update_all(
        from(l in DecompositionLink,
          where:
            l.tenant_id == ^tenant_id and
              l.parent_issue_id in ^parent_issue_ids and
              l.last_observed_at < ^desde and
              is_nil(l.no_longer_observed_at)
        ),
        set: [no_longer_observed_at: DateTime.utc_now(:second)]
      )

    {:ok, count}
  end
end
