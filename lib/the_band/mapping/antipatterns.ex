defmodule TheBand.Mapping.Antipatterns do
  @moduledoc """
  Detecta os antipadrões de processo declarados em `process_antipatterns.yaml`.

  ## Isto lê; nunca grava

  A coleta registra as ocorrências, e esta detecção as consome. Misturar as duas faria a
  coleta decidir o que é antipadrão, e **mudar a regra exigiria recoletar** — quando
  mudar a regra deveria só mudar a leitura.

  Nada é gravado em `spo_performed_project_activities`, e nenhuma coluna diz "isto é
  antipadrão": congelá-lo na linha teria o mesmo efeito.

  ## `enforcement: detection` — relata e nunca recusa

  Um axioma da tese diz o que o modelo não pode violar; um antipadrão diz o que o mundo
  observado fez. Estas regras são do segundo tipo, e por isso nada é bloqueado, nada é
  corrigido, e nenhuma issue é escondida.

  **E não é avaliação de pessoa.** Quem fez a tarefa e não moveu o cartão fez a tarefa; o
  que falta é o rastro, e o custo é a organização perder a medida.

  ## Zero detectados não é processo saudável

  `detect/2` devolve `{:ok, achados}` **ou** `{:nao_olhei, motivo}`, e a diferença é o
  ponto inteiro. Uma lista vazia porque não há movimentação coletada e uma lista vazia
  porque o processo está registrado direito são a mesma lista — e dizem coisas opostas.

  É o limite escrito no próprio YAML, e é a L57.
  """

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems

  @regra "process.antipatterns"
  @movimentacao "ProjectV2ItemStatusChangedEvent"

  @type achado :: %{
          id: String.t(),
          issue_id: Ecto.UUID.t(),
          issue_number: integer(),
          evidence: String.t()
        }

  @doc """
  Os antipadrões observados numa issue.

  Devolve `{:nao_olhei, :sem_movimentacao_coletada}` quando não há movimentação alguma
  para a issue — porque nesse caso **toda** máxima daria vazio, e o vazio significaria
  "não olhei" em vez de "nada encontrado".

  E `{:error, :not_found}` para issue que não é deste tenant, propagado de
  `fetch_issue/2` — a mesma resposta que a tela dá, e nunca "sem permissão": dizer isso
  confirmaria que o recurso existe.
  """
  @spec detect(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, [achado()]}
          | {:nao_olhei, :sem_movimentacao_coletada}
          | {:error, :not_found}
  def detect(%Tenant{} = tenant, issue_id) do
    with {:ok, issue} <- WorkItems.fetch_issue(tenant, issue_id) do
      evaluate(issue, SPO.list_activities(tenant, "issue", issue_id))
    end
  end

  @doc """
  A mesma avaliação, sobre uma issue e atividades **já carregadas**.

  Existe por medida: a tela da issue já tem as duas coisas em mãos, e recarregá-las aqui
  fazia o render subir de 39 para 48 consultas — o teste-guarda da feature 007 pegou.

  Não é otimização especulativa. É o mesmo defeito que aquela feature pagou com 135
  consultas por render, na forma mais fácil de cometer: uma função conveniente que
  recarrega o que quem a chama acabou de carregar.
  """
  @spec evaluate(map(), [map()]) :: {:ok, [achado()]} | {:nao_olhei, :sem_movimentacao_coletada}
  def evaluate(issue, atividades) do
    movimentacoes = Enum.filter(atividades, &(&1.activity_type == @movimentacao))

    if movimentacoes == [] do
      {:nao_olhei, :sem_movimentacao_coletada}
    else
      {:ok, avaliar(issue, atividades, movimentacoes)}
    end
  end

  # Os designados vêm de `fetch_issue/2`, que já traz os **vigentes** — quem saiu
  # continua no banco e não conta como "está nisto agora". Criar leitura própria daria
  # dois caminhos para o mesmo fato, e eles discordariam no dia em que um mudasse.
  defp avaliar(issue, atividades, movimentacoes) do
    contexto = %{
      issue: issue,
      designados: issue.assignees,
      atividades: atividades,
      movimentacoes: movimentacoes,
      # Movimentação de automação **não conta como início**. Um cartão que o robô moveu
      # para `Done` ao fechar a issue não diz que alguém trabalhou nela: diz que a issue
      # fechou. 160 das 357 movimentações medidas em 2026-08-14 são de robô, e sem esta
      # distinção quase metade dos sinais seria lida como trabalho humano — R2.
      humanas: Enum.filter(movimentacoes, &humana?/1)
    }

    @regra
    |> maximas()
    |> Enum.filter(&viola?(&1, contexto))
    |> Enum.map(&achado(&1, issue, contexto))
  end

  # As máximas vêm da base, e não de lista no código — princípio IV, e é o mesmo desenho
  # das regras de mapeamento. Acrescentar uma máxima não deveria exigir recompilar.
  defp maximas(id) do
    case KnowledgeBase.rule(id) do
      {:ok, regra} -> Map.get(regra, "antipatterns", [])
      :error -> raise "regra #{id} ausente da base de conhecimento"
    end
  end

  # Um ator sem pessoa conhecida **não** é automaticamente robô: pode ser alguém que a
  # plataforma ainda não observou. O que distingue é o login da automação, que a origem
  # nomeia.
  defp humana?(%{performer_login: login}) when is_binary(login),
    do: not String.ends_with?(login, "[bot]") and login != "github-project-automation"

  defp humana?(_movimentacao), do: false

  defp viola?(%{"id" => "process.ap01.closed_without_movement"}, ctx) do
    fechada?(ctx.issue) and ctx.designados != [] and
      not Enum.any?(ctx.humanas, &antes_do_fechamento?(&1, ctx.issue))
  end

  defp viola?(%{"id" => "process.ap02.moved_after_closing"}, ctx) do
    fechada?(ctx.issue) and
      Enum.any?(ctx.humanas, &depois_do_fechamento?(&1, ctx.issue))
  end

  defp viola?(%{"id" => "process.ap03.assigned_and_never_started"}, ctx) do
    not fechada?(ctx.issue) and ctx.designados != [] and ctx.humanas == []
  end

  defp viola?(%{"id" => "process.ap04.movement_without_assignee"}, ctx) do
    ctx.humanas != [] and ctx.designados == []
  end

  # Máxima nova no YAML sem avaliação aqui **levanta**, e não devolve `false`.
  #
  # `false` a esconderia: quem a escrevesse veria zero achados e concluiria que o
  # processo está limpo, quando ninguém a avaliou. É o defeito que este arquivo inteiro
  # existe para não cometer.
  defp viola?(%{"id" => id}, _ctx) do
    raise "máxima #{id} está declarada na base e não tem avaliação em #{inspect(__MODULE__)}"
  end

  defp fechada?(%{external_closed_at: nil}), do: false
  defp fechada?(_issue), do: true

  defp antes_do_fechamento?(movimentacao, issue),
    do: DateTime.compare(movimentacao.occurred_at, issue.external_closed_at) != :gt

  defp depois_do_fechamento?(movimentacao, issue),
    do: DateTime.compare(movimentacao.occurred_at, issue.external_closed_at) == :gt

  defp achado(maxima, issue, ctx) do
    %{
      id: maxima["id"],
      issue_id: issue.id,
      issue_number: issue.number,
      evidence: evidencia(maxima["id"], ctx)
    }
  end

  defp evidencia("process.ap01.closed_without_movement", ctx) do
    "#{length(ctx.movimentacoes)} movement(s) recorded, none by a person before the issue closed"
  end

  defp evidencia("process.ap02.moved_after_closing", _ctx),
    do: "a person moved the card after the issue was already closed"

  defp evidencia("process.ap03.assigned_and_never_started", ctx),
    do: "assigned to #{length(ctx.designados)} person(s), and no person ever moved it"

  defp evidencia("process.ap04.movement_without_assignee", _ctx),
    do: "a person moved the card, and nobody is assigned"
end
