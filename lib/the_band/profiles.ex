defmodule TheBand.Profiles do
  @moduledoc """
  Perfil de competências e evolução de uma pessoa — feature 026.

  ## O que este contexto faz, e o que ele recusa fazer

  Lê as tarefas designadas a alguém, monta um recorte, e pede a um modelo de linguagem que
  escreva sobre ele. **Não afirma competência**: a rede de ontologias não ganhou conceito de
  habilidade, e a razão está em `research.md` R1 da feature — criar um faria a plataforma
  dizer que a pessoa *tem* a habilidade, a partir de texto que em 44% dos casos foi escrito
  por outra pessoa.

  ## O caminho

      Material.build/2   →   Prompt   →   LLM.HTTP   →   Sanitizer   →   EO.record_profile/2
      recusa aqui,           regras       borda          limpa o        somente
      com quatro             que são      única com      resumo         acréscimo
      motivos distintos      requisito    Mox
  """

  alias TheBand.Communication.Discussions
  alias TheBand.Profiles.{GenerateWorker, Material}
  alias TheBand.Tenants.Tenant

  @topic "profiles"

  @doc """
  Assina as conclusões de geração de uma pessoa, para a tela recarregar sozinha.

  O tópico é por **pessoa**, e não por tenant: a aba aberta é de uma pessoa só, e um tópico
  de tenant faria toda aba recarregar quando qualquer perfil terminasse.
  """
  @spec subscribe(Tenant.t(), binary()) :: :ok | {:error, term()}
  defdelegate team_coverage(tenant, team_id), to: TheBand.Profiles.TeamSkills, as: :coverage
  defdelegate team_evolution(tenant, team_id), to: TheBand.Profiles.TeamSkills, as: :evolution
  defdelegate team_summary(coverage), to: TheBand.Profiles.TeamSkills, as: :summary

  defdelegate team_skills_by_person(coverage),
    to: TheBand.Profiles.TeamSkills,
    as: :por_pessoa

  def subscribe(%Tenant{id: tenant_id}, person_id),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, topico(tenant_id, person_id))

  @doc """
  Anuncia o fim de uma geração — **de qualquer desfecho**.

  `{:perfil, :pronto, person_id}` e `{:perfil, {:falhou, motivo}, person_id}`. Os dois
  existem porque anunciar só o sucesso transformaria falha em espera infinita, e espera
  infinita é indistinguível de "ainda rodando" na tela. É a mesma família do defeito que
  mais reincide neste repositório.
  """
  @spec broadcast(binary(), binary(), :pronto | {:falhou, term()}) :: :ok
  def broadcast(tenant_id, person_id, desfecho),
    do:
      Phoenix.PubSub.broadcast(
        TheBand.PubSub,
        topico(tenant_id, person_id),
        {:perfil, desfecho, person_id}
      )

  defp topico(tenant_id, person_id), do: "#{@topic}:#{tenant_id}:#{person_id}"

  @doc """
  Verifica se há material, sem montar o material e sem gastar chamada.

  A tela chama isto **antes** de oferecer o botão: pedir uma geração que vai ser recusada
  gasta um job e devolve a mesma recusa mais tarde, com a pessoa esperando à toa.

  Uma consulta, e ela traz só tamanho de corpo — ver `Material.check/2`. A versão anterior
  chamava `build/2` aqui, e o guard de consultas da página da pessoa pegou: quatro consultas
  e todo o texto das tarefas, a cada render, para decidir se um botão aparece.
  """
  defdelegate check(tenant, person_id), to: Material

  @doc """
  Enfileira uma geração.

  Devolve o job, e **não** o perfil: quem chama não espera. A chamada leva de 25 a 60
  segundos, medidos.

  Recusa `{:error, :sem_chave}` quando não há chave nenhuma — nem do tenant, nem do
  ambiente (feature 048, contrato `estado-da-chave.md`). Antes disso o job entrava na
  fila condenado e falhava no worker, deixando a tela em "pendente" para sempre — o
  sucesso silencioso de sempre. A chave do ambiente segue valendo NESTE caminho (é
  como o desenvolvimento roda); a rodada mensal continua mais estrita (tenant-only,
  FR-011 da 044, `Runs.credencial/1`).
  """
  @spec request(Tenant.t(), binary(), binary() | nil) ::
          {:ok, Oban.Job.t()} | {:error, :sem_chave} | {:error, term()}
  def request(%Tenant{id: tenant_id} = tenant, person_id, user_id \\ nil) do
    case TheBand.AI.origem_da_chave(tenant) do
      :nenhuma ->
        {:error, :sem_chave}

      _tenant_ou_ambiente ->
        %{tenant_id: tenant_id, person_id: person_id, requested_by_user_id: user_id}
        |> GenerateWorker.new()
        |> Oban.insert()
    end
  end

  @doc """
  Quantas tarefas concluíram **depois** do recorte que gerou o perfil exibido.

  É a `FR-016`, e existe porque um perfil de dezembro parece atual em junho: quem lê decide
  com texto velho sem saber que é velho. Sai da diferença entre `tasks_closed` gravado e o
  que existe hoje — e é para isso que o recorte é coluna, e não JSON.

  Sem perfil, zero: não há de que contar a distância.
  """
  @spec tasks_since(Tenant.t(), binary(), map() | nil) :: non_neg_integer()
  def tasks_since(_tenant, _person_id, nil), do: 0

  def tasks_since(%Tenant{id: tenant_id}, person_id, %{tasks_closed: gravadas}) do
    import Ecto.Query

    hoje =
      from(i in "collected_issues",
        join: a in "issue_assignees",
        on: a.collected_issue_id == i.id and is_nil(a.no_longer_observed_at),
        where:
          i.tenant_id == type(^tenant_id, :binary_id) and
            a.person_id == type(^person_id, :binary_id) and i.state == "CLOSED",
        select: count(i.id)
      )
      |> TheBand.Repo.one()

    max(hoje - gravadas, 0)
  end

  @doc """
  As tarefas designadas e abertas há mais tempo que o limiar declarado.

  **Observadas, e recalculadas a cada leitura.** Guardá-las no perfil faria uma tarefa que
  fechou depois da geração continuar aparecendo como parada — a tela mostraria uma pendência
  que já não existe, e quem lê agiria sobre ela.

  O limiar vem de `profile.thresholds`, regra `stale_open_work`.
  """
  @spec stale_open(Tenant.t(), binary()) :: [map()]
  def stale_open(%Tenant{} = tenant, person_id) do
    tenant
    |> Material.open_tasks(person_id)
    |> Enum.filter(&(&1.dias_aberta > Material.stale_days()))
    |> Enum.sort_by(& &1.dias_aberta, :desc)
  end

  @doc """
  As paradas, **com o estado da conversa em cada uma** — o que a tela mostra.

  `stale_open/2` diz *quais* estão paradas. Esta diz *se alguém falou nelas*, e a distinção
  tem três casos que uma lista de issues achataria:

  | `conversa` | Significa |
  |---|---|
  | `:nao_coletada` | o repositório ainda não teve comentário coletado — **lacuna da coleta** |
  | `:silencio` | foi coletado, e não houve ato nenhum |
  | `:recente` | houve ato dentro do limiar |
  | `:antiga` | houve ato, antes do limiar |

  Sem os dois primeiros separados, lacuna da coleta leria como silêncio da equipe — e alguém
  cobraria uma pessoa por uma conversa que a plataforma não olhou.

  Vive aqui, e não na tela, porque a rota `GET /api/v1/people/:id` mostra a mesma coisa.
  Duas cópias divergiriam, e a divergência apareceria como dado.
  """
  @spec stale_open_with_conversation(Tenant.t(), binary()) :: [map()]
  def stale_open_with_conversation(%Tenant{} = tenant, person_id) do
    com_conversa(tenant, stale_open(tenant, person_id))
  end

  defp com_conversa(_tenant, []), do: []

  defp com_conversa(tenant, paradas) do
    conversas = conversa_das_issues(tenant, Enum.map(paradas, & &1.id))
    Enum.map(paradas, &Map.merge(&1, conversas[&1.id]))
  end

  @doc """
  O estado da conversa de cada issue, pelo id — a mesma classificação de
  `stale_open_with_conversation/2`, sem o recorte por pessoa. Feature 062, T013.

  Existe porque a ferramenta MCP `team_stale_work` pergunta pela **equipe**, e a classificação
  tem de ser a mesma da tela e da API: uma segunda cópia divergiria, e a divergência apareceria
  como dado. Os quatro estados estão na documentação de `stale_open_with_conversation/2`.
  """
  @spec conversa_das_issues(Tenant.t(), [binary()]) :: %{binary() => map()}
  def conversa_das_issues(_tenant, []), do: %{}

  def conversa_das_issues(%Tenant{} = tenant, issue_ids) do
    ultimos = Discussions.last_act_for_issues(tenant, issue_ids)
    corte = DateTime.add(DateTime.utc_now(:second), -Material.stale_days(), :day)
    coletados = com_comentarios_coletados(tenant, issue_ids)

    Map.new(issue_ids, fn id ->
      {id, classificar(ultimos[id], corte, MapSet.member?(coletados, id))}
    end)
  end

  defp classificar(nil, _corte, false), do: %{conversa: :nao_coletada, atos: 0, ultimo_ato: nil}
  defp classificar(nil, _corte, true), do: %{conversa: :silencio, atos: 0, ultimo_ato: nil}

  defp classificar(%{atos: atos, ultimo: ultimo}, corte, _coletado) do
    forma = if DateTime.compare(ultimo, corte) == :gt, do: :recente, else: :antiga
    %{conversa: forma, atos: atos, ultimo_ato: ultimo}
  end

  # Quais dessas issues estão em repositório cuja coleta de comentários já passou.
  defp com_comentarios_coletados(tenant, ids) do
    import Ecto.Query

    from(i in "collected_issues",
      join: o in "observed_repositories",
      on: o.id == i.observed_repository_id,
      where:
        i.tenant_id == type(^tenant.id, :binary_id) and
          i.id in type(^ids, {:array, :binary_id}) and
          not is_nil(o.comments_collected_at),
      select: type(i.id, :binary_id)
    )
    |> TheBand.Repo.all()
    |> MapSet.new()
  end

  @doc """
  Há geração pendente para esta pessoa?

  É o terceiro estado da tela — *pedido, ainda não pronto* —, e ele precisa ser distinguível
  de *nunca gerado* e de *falhou*.
  """
  @spec pending?(Tenant.t(), binary()) :: boolean()
  def pending?(%Tenant{id: tenant_id}, person_id) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.worker == "TheBand.Profiles.GenerateWorker" and
          j.state in ["available", "scheduled", "executing", "retryable"] and
          fragment("? ->> 'tenant_id' = ?", j.args, ^tenant_id) and
          fragment("? ->> 'person_id' = ?", j.args, ^person_id)
    )
    |> TheBand.Repo.exists?()
  end
end
