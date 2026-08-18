defmodule TheBand.Verification.Classification do
  @moduledoc """
  A tradução do que o GitHub entrega para o que o continuum nomeia — feature 037.

  ## O gatilho e a fase são eixos INDEPENDENTES

  O gatilho decide o **subtipo** do processo (check-in, agendado, sob demanda); o
  resultado decide a **fase**. Um processo pode ser "iniciado por check-in" e
  "bem-sucedido" ao mesmo tempo, sem contradição — e é por isso que são duas funções e
  duas colunas.

  ## Cancelado não é malsucedido, e não fica sem fase

  A definição de `ciro.unsuccessful_continuous_integration_process` exige **problema em
  algum componente**, e cancelar não é problema no código. Medido em 2026-08-18, nas
  1.051 execuções do primeiro repositório: 55 falharam e **54 foram canceladas**.
  Contá-las como falha levaria a taxa de quebra de 5,2% para 10,4% — dobrada por
  decisões humanas. Deixá-las sem fase escondia informação pelo outro lado: processo
  terminado sem fase é indistinguível de processo em andamento. Cada uma tem nome.

  **Só o processo em andamento fica sem fase.** Ele ainda não decidiu nada.

  ## Nem toda execução é integração contínua — e o dado é que disse isso

  A primeira versão mapeava **toda** execução para `ciro.continuous_integration_process`.
  O dado real derrubou isso: das 1.051 execuções, as mais frequentes são
  `Sync to GitLab` (264), `Deploy Docs to GitHub Pages` (247),
  `Deploy Backoffice and Front-office` (235), `Project 43 Sprint Rollover` (109) e
  `Release ConectaFapes` (90). **Nenhuma delas integra código** — são entrega,
  implantação e automação de quadro.

  Chamá-las de integração contínua seria afirmar processo que não ocorreu, e envenenaria
  qualquer medida de verificação com execuções que nada verificam. Então o tipo é
  **derivado dos componentes**:

    * algum de build, teste ou inspeção → `ciro.continuous_integration_process`
    * algum de entrega ou implantação → `cdro.continuous_deployment_process`
    * nenhum → **a rede não tem conceito para isso**, e a coluna fica vazia

  A lista é array pelo mesmo motivo dos componentes: o fluxo do GitHub Pages tem um job
  `build` e um `deploy` na mesma execução — ela é as duas coisas, e guardar só uma
  perderia metade do que aconteceu.
  """

  # Os padrões são deliberadamente ESTREITOS. Medido em 2026-08-18: `artifact` casava com
  # a etapa `Upload Pages artifact` de um job de build e produzia 238 entregas que não
  # existem — subir artefato para o job seguinte é o build entregando a si mesmo, não
  # entrega contínua. `package` tinha o mesmo problema com `Install npm packages`.
  # Padrão largo demais não coleta mais: inventa mais.
  @ci_componentes [
    {~r/build|compile|assets|docker|image/, "ciro.continuous_build_process"},
    {~r/test|spec|cobertura|coverage|e2e|pytest|jest/, "ciro.continuous_test_process"},
    {~r/lint|format|credo|sobelow|dialyzer|audit|gates|inspect|sast|scan/,
     "ciro.continuous_inspection_process"}
  ]

  # Entrega e implantação são atividades da CDRO, não componentes da CIRO — a distinção
  # que o dado real obrigou a fazer.
  @cd_componentes [
    {~r/deploy|implanta|rollout|helm|kubectl|argocd/, "cdro.deployment_activity"},
    {~r/release|publish|delivery|entrega/, "cdro.delivery_activity"}
  ]

  @doc """
  O subtipo pelo gatilho.

  `pull_request` NÃO tem subtipo próprio na CIRO — é check-in num ramo de proposta, e o
  mapeamento o trata como `check_in_triggered` com a divergência registrada, nunca
  criando conceito novo por conveniência.
  """
  @spec subtipo(String.t() | nil) :: String.t()
  def subtipo(evento) when evento in ["push", "pull_request", "merge_group"],
    do: "ciro.check_in_triggered_continuous_integration_process"

  def subtipo("schedule"), do: "ciro.scheduled_continuous_integration_process"

  def subtipo(evento) when evento in ["workflow_dispatch", "repository_dispatch"],
    do: "ciro.on_demand_continuous_integration_process"

  # Evento que a regra não reconhece fica no supertipo, com o valor cru preservado na
  # coluna: inventar subtipo seria afirmar gatilho que não se sabe qual é.
  def subtipo(_evento), do: "ciro.continuous_integration_process"

  @doc """
  A fase pelo resultado. `nil` enquanto o processo não termina.

      iex> alias TheBand.Verification.Classification
      iex> Classification.fase("completed", "success")
      "ciro.successful_continuous_integration_process"
      iex> Classification.fase("completed", "cancelled")
      "ciro.interrupted_continuous_integration_process"
      iex> Classification.fase("in_progress", nil)
      nil
  """
  @spec fase(String.t() | nil, String.t() | nil) :: String.t() | nil
  def fase(status, _conclusion) when status in ["queued", "in_progress", "waiting", "pending"],
    do: nil

  def fase(_status, "success"), do: "ciro.successful_continuous_integration_process"
  def fase(_status, "failure"), do: "ciro.unsuccessful_continuous_integration_process"

  # As três fases decididas em 2026-08-18. Nenhuma é malsucedida.
  def fase(_status, "cancelled"), do: "ciro.interrupted_continuous_integration_process"
  def fase(_status, "skipped"), do: "ciro.unperformed_continuous_integration_process"
  def fase(_status, "timed_out"), do: "ciro.expired_continuous_integration_process"

  # `action_required` e `neutral` existem na origem e não foram decididos: ficam sem
  # fase, com o valor cru preservado. Escolher uma seria inventar.
  def fase(_status, _outro), do: nil

  @doc """
  Os processos que um job materializa — regra `github.ci_job_routing`.

  **Devolve TODOS os reconhecidos**, e a lista vazia é ausência nomeada. Escolher um e
  descartar os outros faria a plataforma afirmar que o job só testa quando ele também
  inspeciona; e chutar "build" quando nada casa produziria medida inventada.

      iex> alias TheBand.Verification.Classification
      iex> Classification.componentes("quality-gates", ["treze quality gates"])
      ["ciro.continuous_inspection_process"]
      iex> Classification.componentes("deploy", [])
      ["cdro.deployment_activity"]
      iex> Classification.componentes("sync", [])
      []
  """
  @spec componentes(String.t() | nil, [String.t()]) :: [String.t()]
  def componentes(nome, etapas) do
    texto = [nome | etapas] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.downcase()

    (@ci_componentes ++ @cd_componentes)
    |> Enum.filter(fn {padrao, _} -> Regex.match?(padrao, texto) end)
    |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Que processos a execução inteira materializou, a partir dos componentes dos jobs.

  Lista vazia significa que **a rede não tem conceito** para o que essa execução faz —
  não que a coleta falhou. É o caso de `Sync to GitLab` e `Sprint Rollover`: automação
  real, que não é nem verificação nem implantação.

      iex> alias TheBand.Verification.Classification
      iex> Classification.tipos([["ciro.continuous_build_process"], ["cdro.deployment_activity"]])
      ["ciro.continuous_integration_process", "cdro.continuous_deployment_process"]
      iex> Classification.tipos([[], []])
      []
  """
  @spec tipos([[String.t()]]) :: [String.t()]
  def tipos(componentes_por_job) do
    todos = List.flatten(componentes_por_job)

    []
    |> entao(Enum.any?(todos, &ci?/1), "ciro.continuous_integration_process")
    |> entao(Enum.any?(todos, &cd?/1), "cdro.continuous_deployment_process")
  end

  defp entao(lista, true, valor), do: lista ++ [valor]
  defp entao(lista, false, _valor), do: lista

  defp ci?(componente), do: String.starts_with?(componente, "ciro.")
  defp cd?(componente), do: String.starts_with?(componente, "cdro.")

  @doc """
  O job é monolítico? — `ci.ap01.monolithic_job`.

  Mais de um processo do continuum no mesmo job: o script agrupou etapas, e a origem
  informa **um** resultado onde havia vários.

  **Build junto com implantação conta**, e o dado de 2026-08-18 é o que decidiu isso.
  A primeira versão excluía o par por serem ontologias diferentes — até que 502 jobs
  chamados `Deploy backoffice` e `Deploy front-office` apareceram com as etapas
  `Build production bundle` **e** `Deploy to Vercel production` no mesmo job. É
  exatamente a perda que a máxima descreve: com um único `conclusion`, ninguém sabe se
  quebrou o empacotamento ou a publicação.

  Um componente só, ou nenhum, não é monolítico — ausência de reconhecimento não é
  evidência de agrupamento.
  """
  @spec monolitico?([String.t()]) :: boolean()
  def monolitico?(componentes), do: length(componentes) > 1

  @doc """
  O job tem componentes não nomeados? — `ci.ap02.unnamed_components`.

  **Só vale para job de execução que é verificação.** Um job `sync` numa automação de
  quadro não tem componente de CI porque não é CI — reportá-lo como antipadrão produziria
  751 defeitos falsos, que foi exatamente o que o dado de 2026-08-18 mostrou.
  """
  @spec sem_nome?([String.t()], [String.t()]) :: boolean()
  def sem_nome?(componentes_do_job, tipos_da_execucao) do
    componentes_do_job == [] and "ciro.continuous_integration_process" in tipos_da_execucao
  end
end
