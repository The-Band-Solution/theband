defmodule TheBand.Teams.FlowPerPerson do
  @moduledoc """
  As medidas da aba *Flow per person* — feature 060, o protótipo aprovado em 2026-09-08.

  Uma linha por membro, e **nenhum gráfico na linha**: tabela é para comparar, e comparação
  se faz em número alinhado. Este módulo devolve os números; a tela desenha.

  ## Três consultas para qualquer número de membros

  A forma óbvia — chamar `PersonWork.state_changes_by_period/3` por linha — custa três
  consultas **por pessoa**. Numa equipe de 48 membros são 144, e é o padrão 1+N que o teto de
  consultas desta tela existe para pegar (L38).

  Aqui são três, para qualquer número de pessoas:

    1. as **criadas** por pessoa e período, agrupadas no banco;
    2. as **fechadas**, idem;
    3. quantos itens cada pessoa tinha em aberto **no início da janela**.

  A série de *abertos* de cada período não é uma quarta consulta: sai da **identidade do
  burn**, que esta casa já declara — `aberto(t) = aberto(0) + criadas(t) − fechadas(t)`,
  acumuladas. É a mesma identidade do painel da equipe, e usá-la aqui é o que permite dizer
  *"9 at the first sample · +2 across the window"* sem uma consulta por amostra.

  ## O que estes números NÃO são

  **Nenhuma coluna soma ao fluxo da equipe.** Item com dois responsáveis conta **uma vez para
  cada** — o `count(distinct)` roda dentro do grupo da pessoa, e é o que a regra da 057 FR-008
  pede. Somar as linhas daria outro número, e a tela diz isso em palavras.

  **O *working in progress* daqui não é `flow.wip.count`.** A fórmula declarada exige começo e
  fim da tarefa executada, e **o critério de fim não existe** no que se coleta (issue #506). O
  que se computa é a substituição que o burn da equipe já faz: um item está **aberto** quando
  `external_created_at` está presente e `external_closed_at` é nulo no instante amostrado.

  Duas consequências, e as duas vão para a tela: o relógio começa quando o **item** foi
  aberto, não quando a pessoa o assumiu — a origem não registra isso —, e **não há limite de
  WIP** em lugar nenhum, porque nenhum está declarado.

  **Nenhuma média e nenhuma taxa por pessoa.** Um número único por pessoa é exatamente a
  figura de produtividade que a plataforma não guarda, e este módulo não a calcula — nem para
  quem quiser somar depois.

  ## Sem data de designação, o item é da pessoa

  `issue_assignees` não guarda quando a designação aconteceu — a origem não fornece. Decisão
  da pessoa mantenedora em 2026-08-27: **sem essa data, o item é da pessoa**, e o período dele
  é o do próprio item. Não é aproximação a corrigir: é a definição em vigor.
  """

  import Ecto.Query

  alias TheBand.Forecast
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  @escalas [:semana, :mes, :ano]

  @typedoc """
  A linha de uma pessoa. `abertos` é a série derivada da identidade do burn: um valor por
  período, e o último é o `open now` da coluna 2.
  """
  @type linha :: %{
          person_id: Ecto.UUID.t(),
          serie: [%{periodo: String.t(), criadas: non_neg_integer(), fechadas: non_neg_integer()}],
          abertos: [%{periodo: String.t(), aberto: integer()}],
          aberto_inicial: non_neg_integer(),
          criadas_na_janela: non_neg_integer(),
          fechadas_na_janela: non_neg_integer(),
          periodos_com_fechamento: non_neg_integer(),
          periodos: non_neg_integer()
        }

  @doc """
  As linhas de todas as pessoas do conjunto, na escala e janela pedidas.

  Devolve `%{person_id => linha()}`, com **todos** os períodos da janela em cada série,
  inclusive os vazios: pular período comprimiria o tempo e faria a série mentir sobre o ritmo.

  Pessoa sem item nenhum recebe linha com séries em zero — e é diferente de não estar no mapa.
  A tela distingue as duas coisas, porque *nada observado para esta pessoa* e *tem itens, mas
  nenhum aberto agora* são ausências diferentes (item 25 da régua).
  """
  @spec linhas(Tenant.t(), [Ecto.UUID.t()], atom(), keyword()) :: %{Ecto.UUID.t() => linha()}
  def linhas(%Tenant{} = tenant, pessoas, escala, opts)
      when escala in @escalas and is_list(pessoas) do
    if pessoas == [] do
      %{}
    else
      forma = formato(escala)
      desde = Keyword.fetch!(opts, :desde)
      ate = Keyword.fetch!(opts, :ate)

      criadas = por_evento_e_pessoa(tenant, pessoas, :external_created_at, forma, desde, ate)
      fechadas = por_evento_e_pessoa(tenant, pessoas, :external_closed_at, forma, desde, ate)
      iniciais = abertos_em(tenant, pessoas, desde)

      periodos = periodos_da_janela(escala, desde, ate)

      Map.new(pessoas, fn person_id ->
        serie =
          juntar(
            Map.get(criadas, person_id, %{}),
            Map.get(fechadas, person_id, %{}),
            periodos
          )

        {person_id, montar(person_id, serie, Map.get(iniciais, person_id, 0))}
      end)
    end
  end

  @doc """
  Quantos itens cada pessoa tinha em aberto naquele instante — uma consulta.

  Pessoa sem item aberto **não** entra no mapa, e quem lê usa `Map.get(.., id, 0)`: uma
  entrada com zero seria uma linha inventada para dizer o que a ausência já diz. É a forma de
  `TeamWork.open_at_by_team/3`.
  """
  @spec abertos_em(Tenant.t(), [Ecto.UUID.t()], DateTime.t()) :: %{
          Ecto.UUID.t() => non_neg_integer()
        }
  def abertos_em(%Tenant{id: tenant_id}, pessoas, quando) do
    CollectedIssue
    |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
    |> where([i, a], i.tenant_id == ^tenant_id and a.person_id in ^pessoas)
    |> where([i], not is_nil(i.external_created_at) and i.external_created_at <= ^quando)
    |> where([i], is_nil(i.external_closed_at) or i.external_closed_at > ^quando)
    |> group_by([_i, a], a.person_id)
    |> select([i, a], {type(a.person_id, :binary_id), count(i.id, :distinct)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  A variação de abertos ao longo da janela, **em palavras** — item 7 da régua.

  Nunca um número solto: *"no change across the 8 samples"* diz que se conferiu, e
  *"9 at the first sample · +2 across the window"* diz de onde para onde. Um `+2` sozinho não
  responde nem uma nem outra.
  """
  @spec variacao(linha()) ::
          {:sem_amostra, 0}
          | {:sem_mudanca, non_neg_integer()}
          | {:mudou, integer(), integer(), non_neg_integer()}
  def variacao(%{abertos: []}), do: {:sem_amostra, 0}

  def variacao(%{abertos: abertos}) do
    primeiro = List.first(abertos).aberto
    ultimo = List.last(abertos).aberto
    amostras = length(abertos)

    if primeiro == ultimo,
      do: {:sem_mudanca, amostras},
      else: {:mudou, primeiro, ultimo - primeiro, amostras}
  end

  @doc """
  O `open now` da coluna 2 — o valor no **último** instante amostrado, e não o de agora.

  A distinção importa: a coluna diz *"and the change across the window"*, e a variação se lê
  entre a primeira e a última amostra. Misturar o último período com o instante da requisição
  faria a variação não fechar com o número ao lado.
  """
  @spec aberto_agora(linha()) :: non_neg_integer()
  def aberto_agora(%{abertos: []}), do: 0
  def aberto_agora(%{abertos: abertos}), do: max(List.last(abertos).aberto, 0)

  @doc """
  A previsão de entrega da pessoa — **três estados, e a ordem entre eles importa**.

  A coluna do protótipo é **coluna de estado, não de valor** (item 11 da régua):

    * `{:ok, previsao}` — tem previsão; a tela mostra o p50, diz quando não há p85, e mostra
      a proporção das rodadas que nunca zeraram;
    * `{:nada_a_prever, _}` — a pessoa **não tem item aberto**. O piso **não** é a razão
      aqui, e dizer *"below the floor"* nesse caso culparia o método por uma ausência de
      trabalho;
    * `{:sem_historico, faltando}` — abaixo do piso, com os **quatro** números:
      `history a of 6 met · closed b of 10 short`. As palavras *met* e *short* carregam a
      diferença, e são dois modos de bloqueio distintos — um pode estar atendido e o outro
      não.

  **A ordem é a decisão.** `nada_a_prever` é conferido **antes** do piso: quem não tem item
  aberto não tem o que prever, e o piso é sobre a história, não sobre o trabalho de agora.
  Inverter a ordem faria a tela dizer que falta história a quem só não tem tarefa.

  **A história é da própria pessoa, sempre.** Emprestar a série da equipe para prever quem não
  tem história é atribuir a alguém um ritmo que não é dela — e é proibido pelo protótipo.
  """
  @spec previsao(linha(), keyword()) ::
          {:ok, map()} | {:nada_a_prever, non_neg_integer()} | {:sem_historico, map()}
  def previsao(linha, opts \\ []) do
    aberto = aberto_agora(linha)

    if aberto == 0 do
      {:nada_a_prever, linha.fechadas_na_janela}
    else
      Forecast.monte_carlo(linha.serie, Keyword.put(opts, :aberto, aberto))
    end
  end

  @doc """
  Quantas pessoas do conjunto têm previsão, e de quantas — a linha da FR-100.

  Aparece **inclusive** quando nenhuma tem e quando todas têm: *"produced for 0 of 5"* diz que
  se conferiu, e é diferente de a linha não existir. E o piso é do **método**, nunca das
  pessoas abaixo dele.
  """
  @spec quantas_com_previsao(%{Ecto.UUID.t() => linha()}, keyword()) ::
          {non_neg_integer(), non_neg_integer()}
  def quantas_com_previsao(linhas, opts \\ []) do
    valores = Map.values(linhas)

    com =
      Enum.count(valores, fn linha ->
        match?({:ok, _}, previsao(linha, opts))
      end)

    {com, length(valores)}
  end

  # ------------------------------------------------------------------ a montagem

  defp montar(person_id, serie, aberto_inicial) do
    abertos = acumular(serie, aberto_inicial)

    %{
      person_id: person_id,
      serie: serie,
      abertos: abertos,
      aberto_inicial: aberto_inicial,
      criadas_na_janela: Enum.sum(Enum.map(serie, & &1.criadas)),
      fechadas_na_janela: Enum.sum(Enum.map(serie, & &1.fechadas)),
      periodos_com_fechamento: Enum.count(serie, &(&1.fechadas > 0)),
      periodos: length(serie)
    }
  end

  # A IDENTIDADE DO BURN, e não uma quarta consulta.
  #
  # `aberto(t) = aberto(0) + criadas acumuladas até t − fechadas acumuladas até t`. É a mesma
  # identidade que o painel da equipe usa, e é o que permite a série de abertos por período
  # sem uma consulta por amostra.
  #
  # O `max(.., 0)` não é defesa contra a identidade: é defesa contra a janela. Um item fechado
  # dentro dela e aberto **antes** dela entra em `fechadas` e nunca entrou em `criadas`, e a
  # conta pode passar de zero para baixo. Zero é o piso do que a coluna afirma.
  defp acumular(serie, aberto_inicial) do
    serie
    |> Enum.scan({aberto_inicial, nil}, fn periodo, {aberto, _} ->
      {aberto + periodo.criadas - periodo.fechadas, periodo.periodo}
    end)
    |> Enum.map(fn {aberto, periodo} -> %{periodo: periodo, aberto: max(aberto, 0)} end)
  end

  defp juntar(criadas, fechadas, periodos) do
    Enum.map(periodos, fn periodo ->
      %{
        periodo: periodo,
        criadas: Map.get(criadas, periodo, 0),
        fechadas: Map.get(fechadas, periodo, 0)
      }
    end)
  end

  # Como `TeamWork.por_evento_e_equipe/6`, com a PESSOA no `GROUP BY`.
  #
  # O `count(distinct)` dentro do grupo é o que faz o item de dois responsáveis contar uma vez
  # para cada pessoa — e é por isso que nenhuma coluna soma ao fluxo da equipe.
  defp por_evento_e_pessoa(%Tenant{id: tenant_id}, pessoas, campo, forma, desde, ate) do
    CollectedIssue
    |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
    |> where([i, a], i.tenant_id == ^tenant_id and a.person_id in ^pessoas)
    |> where([i], not is_nil(field(i, ^campo)))
    |> where([i], field(i, ^campo) >= ^desde and field(i, ^campo) <= ^ate)
    |> group_by([_i, a], [a.person_id, fragment("2")])
    |> select(
      [i, a],
      {type(a.person_id, :binary_id), fragment("to_char(?, ?)", field(i, ^campo), ^forma),
       count(i.id, :distinct)}
    )
    |> Repo.all()
    |> Enum.group_by(fn {person_id, _p, _n} -> person_id end, fn {_id, p, n} -> {p, n} end)
    |> Map.new(fn {person_id, pares} -> {person_id, Map.new(pares)} end)
  end

  # Os períodos da janela, todos, inclusive os vazios — a mesma forma que
  # `PersonWork.preencher_periodos_vazios/2` usa, e pela mesma razão.
  defp periodos_da_janela(escala, desde, ate) do
    passo =
      case escala do
        :semana -> 7
        :mes -> 28
        :ano -> 365
      end

    desde
    |> Stream.iterate(&DateTime.add(&1, passo, :day))
    |> Stream.take_while(&(DateTime.compare(&1, ate) != :gt))
    |> Enum.map(&rotulo(&1, escala))
    |> Enum.uniq()
  end

  # O rótulo é o MESMO que o Postgres produz, e é o que faz o `Map.get` casar. `%G`/`%V` não
  # existem no `Calendar.strftime` do Elixir, e a semana ISO tem armadilha própria: o ano da
  # semana 1 de janeiro pode ser o ano anterior. `:calendar.iso_week_number/1` resolve, e é a
  # forma que `PersonWork.rotulo/2` já usa — duas grafias para a mesma semana seriam duas
  # séries que nunca se encontram.
  defp rotulo(quando, :semana) do
    {ano_iso, semana} = :calendar.iso_week_number(Date.to_erl(DateTime.to_date(quando)))
    "#{ano_iso}-W#{String.pad_leading("#{semana}", 2, "0")}"
  end

  defp rotulo(quando, :mes),
    do: "#{quando.year}-#{String.pad_leading("#{quando.month}", 2, "0")}"

  defp rotulo(quando, :ano), do: "#{quando.year}"

  defp formato(:semana), do: "IYYY-\"W\"IW"
  defp formato(:mes), do: "YYYY-MM"
  defp formato(:ano), do: "YYYY"
end
