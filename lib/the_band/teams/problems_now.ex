defmodule TheBand.Teams.ProblemsNow do
  @moduledoc """
  *Problemas agora* — os oito fatos que o painel da equipe conta antes das medidas.

  Spec 060, FR-065 a FR-069 (US8).

  ## Um cartão é uma CONTAGEM sobre fato, nunca uma inferência

  Cada cartão devolve `{:contado, n, detalhe}` ou `{:nao_conferido, o_que_falta}`, e a
  diferença entre os dois é a razão de este módulo existir.

  **`{:contado, 0, _}`** significa *conferido, nada encontrado*: a plataforma tinha o insumo,
  olhou, e não achou. **`{:nao_conferido, _}`** significa que o insumo **não é coletado** ou a
  medida não é calculável — e o cartão diz o que falta.

  Os dois são zero na tela se apresentados como número. São afirmações opostas: o primeiro é
  informação, o segundo é lacuna. A FR-067 os obriga a serem distinguíveis em texto, e é a
  razão de nenhum deles ser um inteiro solto.

  ## Nenhum limiar vive aqui

  Os três limiares desta seção vêm da base de conhecimento — `team.dashboard.thresholds` para
  a idade da issue (30 dias) e a espera por revisão (7 dias), e
  `profile.thresholds.stale_open_work` para a parada (90 dias), que **já existia e é
  reusado**.

  A FR-069 o exige por escrito, e a razão é operacional: em constante de módulo, o limiar
  muda num diff de template, e ninguém percebe que a plataforma passou a afirmar outra coisa.
  Aqui, mudá-lo é mudar um YAML versionado com a decisão que o apoia.

  ## Cinco dos oito cartões NÃO consultam o banco

  A primeira versão consultava tudo por conta própria, e o teto de consultas da tela acusou:
  **32 acrescentadas contra as 21 declaradas**, e — pior — o número **crescia com o número de
  pessoas**, duas consultas por pessoa.

  A causa não era desempenho: era **duplicação**. O painel já carrega as tarefas por pessoa,
  as anomalias de estrutura, a espera por revisão e a contagem de vínculos sem papel. Contá-los
  de novo aqui produziria dois caminhos para o mesmo número — e dois caminhos divergem.

  Então este módulo recebe o que a tela já tem, em `insumos`, e **só consulta o que ninguém
  carregou**: as issues antigas. É uma consulta a mais na página, e o teto voltou a caber.

  ## O que este módulo NÃO faz

  Não ordena os cartões por gravidade, não soma, e não decide o que é urgente. Contar é o que
  a plataforma pode fazer com fato coletado; priorizar é julgamento de quem gerencia, e a
  tela não o toma emprestado.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Profiles.Material
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  @typedoc """
  O resultado de um cartão.

  `{:contado, n, detalhe}` — a plataforma olhou. `n` pode ser zero, e zero é resposta.
  `{:nao_conferido, o_que_falta}` — o insumo não existe, e o cartão diz o quê.
  """
  @type cartao ::
          {:contado, non_neg_integer(), map()}
          | {:nao_conferido, String.t()}

  @doc """
  Os oito cartões de *Problemas agora*, para uma equipe e um conjunto de equipes.

  `escopo` é a lista de equipes do conjunto — a própria mais as partes vigentes, como o
  roster (FR-056). Passá-la de fora evita que este módulo tenha uma segunda definição de
  "quem é desta equipe".
  """
  @spec cartoes(Tenant.t(), [Ecto.UUID.t()], map(), keyword()) :: [map()]
  def cartoes(%Tenant{} = tenant, escopo, insumos, opts \\ []) do
    agora = Keyword.get(opts, :agora, DateTime.utc_now())
    janela = Keyword.get(opts, :janela_em_dias, 56)

    [
      %{
        id: :issues_antigas,
        titulo: "Issues open beyond the threshold",
        limiar: "open for more than #{issue_open_days()} days",
        origem: "team.dashboard.thresholds · open_issue_age",
        destino: nil,
        resultado: issues_antigas(tenant, escopo, agora)
      },
      %{
        id: :revisoes_esperando,
        titulo: "Code changes waiting for a first human review",
        limiar: "waiting for more than #{review_wait_days()} days",
        origem: "team.dashboard.thresholds · review_wait",
        destino: "#espera-por-revisao",
        resultado: revisoes_esperando(insumos, janela)
      },
      %{
        id: :pipeline_falhando,
        titulo: "Pipeline failing now on the default branch",
        limiar: "the latest completed check, per repository",
        origem: "spec 060 · FR-071",
        destino: "#taxa-do-pipeline",
        resultado: pipeline_falhando()
      },
      %{
        id: :tarefas_paradas,
        titulo: "Assigned tasks past the stop threshold",
        limiar: "open for more than #{Material.stale_days()} days",
        origem: "profile.thresholds · stale_open_work",
        destino: nil,
        resultado: tarefas_paradas(insumos)
      },
      %{
        id: :sem_tarefa,
        titulo: "People with no open task",
        limiar: "no threshold — it is a count of people",
        origem: "spec 057 · FR-021",
        destino: nil,
        resultado: sem_tarefa(insumos)
      },
      %{
        id: :sem_papel,
        titulo: "Members with no declared role",
        limiar: "no threshold — it is a count of links",
        origem: "spec 055 · FR-018",
        destino: "?tab=structure",
        resultado: sem_papel(insumos)
      },
      %{
        id: :fora_de_projeto,
        titulo: "Work outside any declared project",
        limiar: "repository or board with no declared project of this team",
        origem: "spec 060 · FR-053",
        destino: nil,
        resultado: fora_de_projeto()
      },
      %{
        id: :anomalias,
        titulo: "Structure anomalies",
        limiar: "declared in structure_antipatterns.yaml",
        origem: "spec 058 · FR-025",
        destino: "#estrutura-anomala",
        resultado: anomalias(insumos)
      }
    ]
  end

  # ------------------------------------------------------------------ os limiares

  @doc """
  A idade a partir da qual uma issue aberta entra na contagem — da base.

  `nil` quando a regra **não está** na base de conhecimento, e é retorno legítimo: é o que faz
  o cartão dizer *não conferido* em vez de contar com um limiar inventado. O dialyzer apanhou
  o `@spec` anterior, que dizia `pos_integer()` e tornava o ramo do `nil` inalcançável — o
  spec é que mentia, não o código.
  """
  @spec issue_open_days() :: pos_integer() | nil
  def issue_open_days, do: limiar("open_issue_age", "open_days")

  @doc """
  A espera a partir da qual uma revisão pendente entra na contagem — da base.

  `nil` pela mesma razão de `issue_open_days/0`: sem a regra declarada, o cartão recusa em vez
  de contar.
  """
  @spec review_wait_days() :: pos_integer() | nil
  def review_wait_days, do: limiar("review_wait", "wait_days")

  defp limiar(regra, chave) do
    case KnowledgeBase.rule("team.dashboard.thresholds") do
      {:ok, %{"rules" => regras}} -> get_in(regras, [regra, "values", chave])
      _ -> nil
    end
  end

  # ------------------------------------------------------------------ os cartões

  # (a) Issues ABERTAS há mais que o limiar, do conjunto da equipe.
  #
  # A idade conta da abertura na ferramenta, e não da designação: a origem não registra
  # quando a atribuição aconteceu, e derivá-la de outra coluna seria inventá-la.
  defp issues_antigas(%Tenant{id: tenant_id}, escopo, agora) do
    case issue_open_days() do
      nil ->
        {:nao_conferido, "the threshold is not declared in the knowledge base"}

      dias ->
        corte = DateTime.add(agora, -dias, :day)

        n =
          CollectedIssue
          |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
          |> join(:inner, [i, a], m in TeamMembership, on: m.person_id == a.person_id)
          |> where([i, _a, m], i.tenant_id == ^tenant_id and m.team_id in ^escopo)
          |> where([_i, _a, m], is_nil(m.ended_at) and is_nil(m.invalidated_at))
          |> where([i], is_nil(i.external_closed_at))
          |> where([i], i.external_created_at < ^corte)
          |> select([i], count(i.id, :distinct))
          |> Repo.one()

        {:contado, n, %{desde: corte}}
    end
  end

  # (b) Solicitações de mudança de código esperando a PRIMEIRA revisão HUMANA.
  #
  # A lista vem da seção *espera por revisão*, que a tela já carrega — `Quality.
  # team_time_to_first_review/3`, que exclui revisão de robô. Contá-la aqui de novo daria
  # dois números com o mesmo rótulo na mesma página.
  #
  # `{:aguardando, dias}` é o relator do que **ainda não foi revisado**. Só isso conta: o que
  # já foi revisado teve a espera medida, e medir não é esperar.
  defp revisoes_esperando(insumos, janela) do
    case {review_wait_days(), Map.get(insumos, :esperas)} do
      {nil, _} ->
        {:nao_conferido, "the threshold is not declared in the knowledge base"}

      {_dias, nil} ->
        {:nao_conferido, "the review wait section did not load"}

      {dias, esperas} ->
        n = Enum.count(esperas, &aguardando_ha_mais_de?(&1, dias))
        {:contado, n, %{janela_em_dias: janela}}
    end
  end

  defp aguardando_ha_mais_de?(%{estado: {:aguardando, dias}}, limiar), do: dias > limiar
  defp aguardando_ha_mais_de?(_outro, _limiar), do: false

  # (c) Pipeline falhando AGORA na branch padrão.
  #
  # `ci.pipeline_success_rate.ratio` é taxa sobre uma janela; "falhando agora" é a **última
  # verificação concluída** na branch padrão de cada repositório — outra afirmação, com outro
  # nome, e a spec 060 (Impacto) registra que a consulta não existe.
  #
  # Os insumos existem (`source_repository.default_branch`, `collected_verification.
  # head_branch`). O que falta é a consulta e o nome dela na base. Enquanto isso, o cartão diz
  # **não conferido** — que é diferente de zero, e é o que a FR-067 obriga.
  defp pipeline_falhando do
    {:nao_conferido,
     "the query does not exist yet — the inputs are collected (default branch and check " <>
       "branch), and the measure needs a name in the knowledge base before the card counts"}
  end

  # (d) Tarefas designadas além do limiar de PARADA — o limiar já declarado, reusado.
  #
  # As tarefas vêm de `@detalhe.pessoas`, que a tela já carrega com `parada?` calculado. O
  # `uniq_by` é a diferença que importa: item de dois responsáveis conta **uma** vez no
  # cartão, como conta uma vez na equipe (057 FR-008).
  defp tarefas_paradas(insumos) do
    case Map.get(insumos, :pessoas) do
      nil ->
        {:nao_conferido, "the people section did not load"}

      pessoas ->
        n =
          pessoas
          |> Enum.flat_map(& &1.tarefas)
          |> Enum.filter(& &1.parada?)
          |> Enum.uniq_by(& &1.issue_id)
          |> Enum.count()

        {:contado, n, %{limiar_em_dias: Material.stale_days()}}
    end
  end

  # (e) Pessoas do conjunto SEM tarefa aberta — da mesma lista.
  #
  # Lista vazia significa "pertence e não tem tarefa"; a pessoa que não pertence não está na
  # lista. É a distinção que torna esta contagem possível sem uma segunda consulta.
  defp sem_tarefa(insumos) do
    case Map.get(insumos, :pessoas) do
      nil -> {:nao_conferido, "the people section did not load"}
      pessoas -> {:contado, Enum.count(pessoas, &(&1.tarefas == [])), %{}}
    end
  end

  # (f) Vínculos vigentes sem papel declarado — o número que o cabeçalho já mostra.
  defp sem_papel(insumos) do
    case Map.get(insumos, :pending_role) do
      nil -> {:nao_conferido, "the header count did not load"}
      n -> {:contado, n, %{}}
    end
  end

  # (g) Trabalho fora de projeto declarado.
  #
  # A spec 060 (Impacto) registra que a consulta não existe. É o cartão que separa "a
  # plataforma não sabe" de "a organização não declarou", e por isso não pode ser omitido nem
  # mostrado como zero: zero afirmaria que todo o trabalho está dentro de projeto declarado.
  defp fora_de_projeto do
    {:nao_conferido,
     "the query does not exist yet — it needs the rule that names work in a repository or " <>
       "board with no declared project of this team (FR-053)"}
  end

  # (h) Anomalias de estrutura — já detectadas pela 058 e carregadas pela tela.
  defp anomalias(insumos) do
    case Map.get(insumos, :antipadroes) do
      nil -> {:nao_conferido, "the structure anomalies did not load"}
      lista -> {:contado, Enum.count(lista), %{}}
    end
  end
end
