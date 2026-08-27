defmodule TheBand.WorkItems.PersonWork do
  @moduledoc """
  O trabalho de uma pessoa — o que está com ela, o que ela concluiu, e **o quanto disso a
  plataforma observou**.

  ## A cobertura não é rodapé, é o requisito

  Medido em 2026-08-15: 53 repositórios têm issues coletadas e **5** têm timeline. As 152
  issues abertas de uma pessoa podiam estar todas em repositório sem timeline — e uma tela
  que mostrasse `0 atividades` ali estaria dizendo que ela não trabalhou, quando a mesma
  pessoa concluiu 199 issues no histórico.

  Por isso `timeline_coverage/2` existe e vem antes de qualquer número derivado: sem ela,
  todo zero da tela é ambíguo, e a ambiguidade recai sobre uma pessoa.

  ## Estas medidas não dependem da timeline

  `closed_by_month/2` e `open_age_buckets/2` saem das datas da própria issue —
  `external_closed_at` e `external_created_at` —, que têm cobertura completa. É o que torna
  o painel útil mesmo onde a timeline não chegou.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  # Ordem fixa, e as vazias vêm junto: faixa ausente faria o eixo mudar por pessoa, e
  # comparar duas pessoas viraria ilusão.
  @faixas ["até 7d", "7–30d", "30–90d", "90–180d", "mais de 180d"]

  @doc """
  Quantas issues estão designadas à pessoa e **ainda abertas**.

  Designação encerrada não conta: a pergunta é "o que está com ela agora".
  """
  @spec assigned_open_count(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def assigned_open_count(%Tenant{id: tenant_id}, person_id) do
    Repo.aggregate(abertas(tenant_id, person_id), :count)
  end

  @doc """
  Quantas das issues abertas da pessoa estão em repositório **cuja timeline foi coletada**.

  A pergunta é por repositório, e não por issue: a timeline vem junto da issue, então um
  repositório percorrido depois da feature 022 tem timeline de todas as dele.

  Devolve `{observadas, total}` — e quem chama precisa dos dois: `0 de 152` e `0 de 0`
  dizem coisas diferentes.
  """
  @spec timeline_coverage(Tenant.t(), Ecto.UUID.t()) :: {non_neg_integer(), non_neg_integer()}
  def timeline_coverage(%Tenant{id: tenant_id} = tenant, person_id) do
    com_timeline =
      from i in CollectedIssue,
        join: a in Activity,
        on: a.subject_id == i.id,
        where: i.tenant_id == ^tenant_id,
        select: i.observed_repository_id,
        distinct: true

    # **Uma consulta, dois números.** Contar as observadas e depois o total seriam duas idas
    # ao banco para responder uma pergunta só, e o teste-guarda de custo da página da pessoa
    # conta consultas por render.
    _ = tenant

    %{observadas: observadas, total: total} =
      from(i in abertas(tenant_id, person_id),
        select: %{
          observadas: filter(count(i.id), i.observed_repository_id in subquery(com_timeline)),
          total: count(i.id)
        }
      )
      |> Repo.one()

    {observadas, total}
  end

  @escalas ~w(semana mes ano)a

  # Quantos períodos a série devolve, no máximo. Não é estética: 570 barras não são um
  # gráfico, e a consulta que as monta não cresce com o dado, mas a página que as desenha
  # cresce. O corte é declarado na tela.
  @maximo_de_periodos 60

  # Quantos períodos a projeção olha. Curto de propósito: o ritmo de dois anos atrás não
  # prevê o do mês que vem.
  @janela_da_projecao 6

  @doc "As escalas que a tela oferece. Uma lista só — a tela lê daqui."
  @spec escalas() :: [atom()]
  def escalas, do: @escalas

  @doc """
  Issues **criadas** e **concluídas** por período, na escala pedida.

  ## O que este número é, e o que ele NÃO é

  Não é `flow.throughput.rate`. Aquela medida exige critério de início declarado e fim
  registrado, e responde quanto trabalho **atravessou** o sistema. Esta conta duas
  transições de estado sobre as issues designadas à pessoa, e responde outra coisa: quantas
  entraram e quantas saíram naquele período.

  As duas séries **não se subtraem**. Uma issue criada em janeiro e fechada em março aparece
  uma vez em cada, e a diferença entre as barras de um período não é o saldo de trabalho
  aberto — para isso existe `open_age_buckets/2`, que olha o agora.

  ## Sem data de designação, a issue é da pessoa

  `issue_assignees` **não guarda quando a designação aconteceu** — a origem não fornece.
  Decisão da pessoa mantenedora em 2026-08-27: **sem essa data, a issue é da pessoa**, e o
  período dela é o da própria issue.

  Isto NÃO é uma aproximação a corrigir depois. É a definição em vigor: a série responde
  "das issues desta pessoa, quantas nasceram e quantas fecharam em cada período". Se a
  origem passar a fornecer a data de designação, a pergunta pode mudar — e será outra
  decisão, e não um conserto.

  ## Períodos vazios aparecem

  Semana, mês ou ano sem nenhuma das duas transições vem com zero nas duas, e não é omitido:
  pular comprimiria o tempo e faria a série mentir sobre o ritmo.

  ## Uma consulta, e não duas

  As duas séries saem de colunas diferentes da mesma tabela, e agrupá-las juntas exigiria
  duas idas ao banco — a página da pessoa está EXATAMENTE no teto de consultas por render
  medido em `person_detail_test.exs`. A união de dois agrupamentos resolve em uma, e cada
  lado devolve no máximo uma linha por período.
  """
  @spec state_changes_by_period(Tenant.t(), Ecto.UUID.t(), atom()) ::
          [%{periodo: String.t(), criadas: integer(), fechadas: integer()}]
  def state_changes_by_period(%Tenant{id: tenant_id}, person_id, escala)
      when escala in @escalas do
    forma = formato(escala)

    criadas =
      from(i in CollectedIssue,
        join: a in IssueAssignee,
        on: a.collected_issue_id == i.id,
        where:
          i.tenant_id == ^tenant_id and a.person_id == ^person_id and
            not is_nil(i.external_created_at),
        # `GROUP BY 1`, e não a expressão repetida: o Postgres compara as duas
        # estruturalmente, e `to_char(col, $1)` no select contra `to_char(col, $4)` no
        # group by não casam — os parâmetros ocupam posições diferentes.
        group_by: fragment("1"),
        select: {fragment("to_char(?, ?)", i.external_created_at, ^forma), count(i.id), 0}
      )

    fechadas =
      from(i in CollectedIssue,
        join: a in IssueAssignee,
        on: a.collected_issue_id == i.id,
        where:
          i.tenant_id == ^tenant_id and a.person_id == ^person_id and
            not is_nil(i.external_closed_at),
        group_by: fragment("1"),
        select: {fragment("to_char(?, ?)", i.external_closed_at, ^forma), 0, count(i.id)}
      )

    criadas
    |> union_all(^fechadas)
    |> Repo.all()
    |> Enum.reduce(%{}, fn {periodo, c, f}, acc ->
      Map.update(acc, periodo, {c, f}, fn {c0, f0} -> {c0 + c, f0 + f} end)
    end)
    |> Enum.map(fn {periodo, {c, f}} -> %{periodo: periodo, criadas: c, fechadas: f} end)
    |> Enum.sort_by(& &1.periodo)
    |> preencher_periodos_vazios(escala)
  end

  @doc """
  Até quando o trabalho aberto desta pessoa foi planejado — o `data_end` do burn-down.

  Decisão da pessoa mantenedora em 2026-08-27: **a finalização é `data_end`.** O alvo do
  burn-down é uma data DECLARADA, e não uma extrapolação do ritmo.

  ## Qual data, e por que esta

  Medido no mesmo dia, entre as três candidatas do banco:

      spo_projects.ended_on ............ 1 projeto, e NULO
      collected_issues.milestone_due_on . 0 (a coleta do `dueOn` é da #368, ainda não rodou)
      sro_sprints.ended_on ............. 212 caixas, a última em 2026-09-27

  A única com dado é o fim da caixa de tempo. O alvo é o **maior** `ended_on` entre as
  caixas que contêm as issues ainda abertas da pessoa: é a data até a qual aquele trabalho
  foi planejado para acontecer.

  ## A caixa pode não ser sprint

  Depois da #514, o campo de iteração pode ter sido declarado horizonte de planejamento. O
  fim de um horizonte é o limite do período para o qual o trabalho **havia sido planejado**,
  e não o fim de uma caixa de execução — os dois são devolvidos com a origem junto, e a tela
  os nomeia diferente. Somá-los diria que trimestre e sprint são a mesma promessa.

  ## Issue aberta fora de caixa nenhuma

  Devolvida como contagem separada, e nunca somada ao prazo: trabalho sem caixa não tem
  data planejada, e atribuir-lhe a data de outra caixa inventaria uma promessa. Zero ali é
  diferente de ausência, e a tela diz qual é.
  """
  @spec prazo_do_trabalho_aberto(Tenant.t(), Ecto.UUID.t()) ::
          %{
            prazo: Date.t() | nil,
            origem: :sprint | :planning_horizon | nil,
            sem_caixa: integer()
          }
  def prazo_do_trabalho_aberto(%Tenant{id: tenant_id}, person_id) do
    from(i in CollectedIssue,
      join: a in IssueAssignee,
      on: a.collected_issue_id == i.id,
      left_join: si in "sro_sprint_issues",
      on: si.collected_issue_id == i.id and is_nil(si.no_longer_observed_at),
      left_join: s in "sro_sprints",
      on: s.id == si.sprint_id,
      left_join: o in "observed_projects",
      on: o.number == s.board_number and o.tenant_id == s.tenant_id,
      left_join: p in "smpo_iteration_field_roles",
      on:
        p.observed_project_id == o.id and p.field_name == s.field_name and
          p.tenant_id == s.tenant_id and is_nil(p.revoked_at),
      where:
        i.tenant_id == ^tenant_id and a.person_id == ^person_id and
          is_nil(i.external_closed_at),
      select: %{
        prazo: max(s.ended_on),
        # `filter` numa consulta só: contar as sem caixa à parte seria uma segunda ida ao
        # banco, e a página da pessoa está no teto medido.
        sem_caixa: filter(count(i.id, :distinct), is_nil(si.id)),
        horizontes: filter(count(si.id), p.role == ^"planning_horizon"),
        sprints: filter(count(si.id), is_nil(p.role) or p.role != ^"planning_horizon")
      }
    )
    |> Repo.one()
    |> com_origem()
  end

  # A origem do prazo: se TODA caixa do trabalho aberto é horizonte, o prazo é de
  # planejamento. Havendo qualquer sprint, o prazo é de execução — e é ele que aperta.
  defp com_origem(%{prazo: nil} = r), do: %{prazo: nil, origem: nil, sem_caixa: r.sem_caixa}

  defp com_origem(%{sprints: 0} = r),
    do: %{prazo: r.prazo, origem: :planning_horizon, sem_caixa: r.sem_caixa}

  defp com_origem(r), do: %{prazo: r.prazo, origem: :sprint, sem_caixa: r.sem_caixa}

  @doc """
  Burn-up e burn-down desta pessoa, a partir da série de períodos.

  ## Derivado, e não consultado

  Recebe a série de `state_changes_by_period/3` e acumula em memória. **Nenhuma consulta
  nova**: a página da pessoa está exatamente no teto medido em `person_detail_test.exs`, e
  um burn que custasse uma consulta empurraria a página para fora dele.

  ## Três linhas, e a terceira é a diferença das duas

    * `escopo` — criadas acumuladas. É o burn-**up**: quanto trabalho existe;
    * `feito` — fechadas acumuladas. A segunda linha do burn-up;
    * `aberto` — `escopo - feito`. É o burn-**down**: o que resta.

  Desenhar as três juntas é o que mostra o que um burn-down sozinho esconde: **quando a
  linha de resta não desce, é porque a de escopo está subindo**, e não porque ninguém
  fechou nada.

  ## O acumulado começa no primeiro período da série, e não em zero absoluto

  A série já vem cortada nos últimos períodos. O acumulado dentro dela é o acumulado
  **daquela janela**, e a tela diz isso — chamar de "total" um acumulado de janela faria
  o escopo parecer menor do que é para quem tem histórico longo.
  """
  @spec burn(list()) :: [
          %{periodo: String.t(), escopo: integer(), feito: integer(), aberto: integer()}
        ]
  def burn(serie) do
    serie
    |> Enum.scan(%{escopo: 0, feito: 0}, fn d, acc ->
      %{periodo: d.periodo, escopo: acc.escopo + d.criadas, feito: acc.feito + d.fechadas}
    end)
    |> Enum.map(&Map.put(&1, :aberto, &1.escopo - &1.feito))
  end

  @doc """
  Quando o trabalho aberto chegaria a zero, **se** o ritmo recente continuasse.

  ## A projeção recusa responder quando a premissa é falsa

  Extrapolar exige que o fechamento supere a abertura. Medido em 2026-08-27: das 63 pessoas
  com issue designada, **59 ainda têm trabalho aberto**, e para boa parte delas o escopo
  cresce mais rápido do que fecha.

  Nesse caso a resposta NÃO é uma data distante — é `{:nao_converge, criadas, fechadas}`. Um
  gráfico que projetasse 2039 estaria dividindo por um número quase zero e apresentando o
  resultado como previsão; a plataforma diz que no ritmo atual não termina, e mostra os dois
  números que sustentam a frase.

  ## A janela é curta de propósito

  Só os últimos #{@janela_da_projecao} períodos. O ritmo de dois anos atrás não prevê o do
  mês que vem, e usar a série inteira faria a projeção reagir com meses de atraso a uma
  mudança de ritmo.

  ## E não se projeta além do que se observou

  Medido em 2026-08-27: no ritmo dos últimos seis meses, `CaioLessaSimao` fecharia em **78
  meses** e `tadeuaugustovs` em **171**. Os dois "convergem" pela conta, e nenhum dos dois
  números é informação: são 13 e 57 issues divididas por um líquido de 0,17 e 0,33 por mês
  — divisão por quase-zero apresentada como previsão.

  O corte não é um número escolhido a dedo. **Projetar mais períodos do que a série
  observou é extrapolar além da evidência**, e a resposta vira `{:alem_do_observado, n,
  observados}` — que a tela mostra como o que é: um ritmo perto do empate, e não uma data.
  """
  @spec projecao(list()) ::
          {:converge, non_neg_integer()}
          | {:alem_do_observado, non_neg_integer(), non_neg_integer()}
          | {:nao_converge, non_neg_integer(), non_neg_integer()}
          | :sem_trabalho_aberto
          | :sem_dados
  def projecao([]), do: :sem_dados

  def projecao(serie) do
    aberto = List.last(burn(serie)).aberto
    janela = Enum.take(serie, -@janela_da_projecao)
    criadas = Enum.sum(Enum.map(janela, & &1.criadas))
    fechadas = Enum.sum(Enum.map(janela, & &1.fechadas))
    liquido = fechadas - criadas

    cond do
      aberto <= 0 -> :sem_trabalho_aberto
      liquido <= 0 -> {:nao_converge, criadas, fechadas}
      true -> dentro_do_observado(aberto, liquido, length(janela), length(serie))
    end
  end

  defp dentro_do_observado(aberto, liquido, janela, observados) do
    periodos = ceil(aberto / (liquido / janela))

    if periodos <= observados,
      do: {:converge, periodos},
      else: {:alem_do_observado, periodos, observados}
  end

  # `IYYY` é o ano ISO, e não o civil: a semana de 29/12/2025 pertence a 2026 pela ISO, e
  # `YYYY` ali produziria `2025-W01` no fim de dezembro — duas semanas com o mesmo rótulo.
  defp formato(:semana), do: ~S(IYYY-"W"IW)
  defp formato(:mes), do: "YYYY-MM"
  defp formato(:ano), do: "YYYY"

  @doc """
  Issues concluídas por mês, em ordem cronológica.

  **Meses sem fechamento aparecem com zero**, e não são omitidos: pular um mês comprimiria
  o tempo e faria a série mentir sobre o ritmo.

  Sai de `external_closed_at`, e por isso **não depende da timeline**.
  """
  @spec closed_by_month(Tenant.t(), Ecto.UUID.t()) :: [%{month: String.t(), count: integer()}]
  def closed_by_month(%Tenant{id: tenant_id}, person_id) do
    from(i in CollectedIssue,
      join: a in IssueAssignee,
      on: a.collected_issue_id == i.id,
      where:
        i.tenant_id == ^tenant_id and a.person_id == ^person_id and
          not is_nil(i.external_closed_at),
      group_by: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
      order_by: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
      select: %{
        month: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
        count: count(i.id)
      }
    )
    |> Repo.all()
    |> preencher_meses_vazios()
  end

  @doc """
  Quantas issues abertas estão em cada faixa de idade, desde a criação.

  As faixas vêm em ordem **fixa**, e as vazias vêm junto: uma faixa ausente da lista faria a
  tela desenhar um eixo diferente por pessoa, e comparar duas pessoas viraria ilusão.

  É a única medida prospectiva do painel — as outras contam o passado, esta mostra o que
  está parado agora.
  """
  @spec open_age_buckets(Tenant.t(), Ecto.UUID.t()) :: [%{label: String.t(), count: integer()}]
  def open_age_buckets(%Tenant{id: tenant_id}, person_id) do
    contagem =
      from(i in abertas(tenant_id, person_id),
        group_by: fragment("1"),
        select: {
          fragment(
            """
            case
              when now() - ? < interval '7 days'   then 'até 7d'
              when now() - ? < interval '30 days'  then '7–30d'
              when now() - ? < interval '90 days'  then '30–90d'
              when now() - ? < interval '180 days' then '90–180d'
              else 'mais de 180d'
            end
            """,
            i.external_created_at,
            i.external_created_at,
            i.external_created_at,
            i.external_created_at
          ),
          count(i.id)
        }
      )
      |> Repo.all()
      |> Map.new()

    for faixa <- @faixas, do: %{label: faixa, count: Map.get(contagem, faixa, 0)}
  end

  @doc """
  O tempo entre a criação e o fechamento das issues concluídas.

  **Isto é lead time, e não cycle time.** Inclui o tempo em que ninguém tocou na issue, e
  trocar um pelo outro faria alguém decidir sobre um número que responde outra pergunta.

  Mediana e p85, **nunca média**: uma issue parada por 422 dias move a média e não move a
  mediana. Devolve `nil` quando não há issue concluída — e `nil` não é zero dias.
  """
  @spec lead_time(Tenant.t(), Ecto.UUID.t()) ::
          %{median: integer(), p85: integer(), count: integer()} | nil
  def lead_time(%Tenant{id: tenant_id}, person_id) do
    resultado =
      from(i in CollectedIssue,
        join: a in IssueAssignee,
        on: a.collected_issue_id == i.id,
        where:
          i.tenant_id == ^tenant_id and a.person_id == ^person_id and
            not is_nil(i.external_closed_at),
        select: %{
          median:
            fragment(
              "percentile_disc(0.5) within group (order by extract(day from ? - ?))",
              i.external_closed_at,
              i.external_created_at
            ),
          p85:
            fragment(
              "percentile_disc(0.85) within group (order by extract(day from ? - ?))",
              i.external_closed_at,
              i.external_created_at
            ),
          count: count(i.id)
        }
      )
      |> Repo.one()

    case resultado do
      %{count: 0} -> nil
      nil -> nil
      %{median: m, p85: p, count: c} -> %{median: dias(m), p85: dias(p), count: c}
    end
  end

  # `percentile_disc` devolve `Decimal`, como `sum/1` — e um `Decimal` chegando na tela
  # compararia struct com número sem ninguém perceber. Já mordeu neste repositório.
  defp dias(nil), do: 0
  defp dias(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d, 0))
  defp dias(n) when is_number(n), do: trunc(n)

  @doc """
  As issues designadas à pessoa, com os designados vigentes de cada uma.

  Os designados vêm junto porque a avaliação de antipadrão precisa deles, e buscá-los por
  issue seria a segunda metade do N+1 que `detect_for_person/2` existe para evitar.
  """
  @spec issues_assigned_to(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def issues_assigned_to(%Tenant{id: tenant_id}, person_id) do
    issues =
      Repo.all(
        from i in CollectedIssue,
          join: a in IssueAssignee,
          on: a.collected_issue_id == i.id,
          where:
            i.tenant_id == ^tenant_id and a.person_id == ^person_id and
              is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at),
          select: %{id: i.id, number: i.number, external_closed_at: i.external_closed_at}
      )

    designados =
      Repo.all(
        from a in IssueAssignee,
          where:
            a.tenant_id == ^tenant_id and is_nil(a.no_longer_observed_at) and
              a.collected_issue_id in ^Enum.map(issues, & &1.id),
          select: {a.collected_issue_id, %{login: a.login, person_id: a.person_id}}
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    Enum.map(issues, &Map.put(&1, :assignees, Map.get(designados, &1.id, [])))
  end

  # ------------------------------------------------------------------------ privadas

  defp abertas(tenant_id, person_id) do
    from i in CollectedIssue,
      join: a in IssueAssignee,
      on: a.collected_issue_id == i.id,
      where:
        i.tenant_id == ^tenant_id and a.person_id == ^person_id and
          is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at) and
          is_nil(i.external_closed_at)
  end

  # O mês sem fechamento é um zero real, e precisa existir na série. Sem ele, quatro meses
  # parados viram um salto visual de um mês para o outro.
  # ── Preenchimento dos períodos vazios ────────────────────────────────────────────────
  #
  # Gerar por DATA, e não somando 1 ao rótulo. `2026-W52 + 1` não é `2026-W53` em todo ano —
  # a ISO tem anos de 52 e de 53 semanas —, e nem `2026-W53 + 1` é `2027-W01`. Iterar em
  # `Date` e reformatar com a MESMA regra do Postgres é o que garante que os rótulos
  # gerados aqui existam lá.
  defp preencher_periodos_vazios([], _escala), do: []
  defp preencher_periodos_vazios([_unico] = serie, _escala), do: serie

  defp preencher_periodos_vazios(serie, escala) do
    por_periodo = Map.new(serie, &{&1.periodo, &1})
    primeiro = List.first(serie).periodo
    ultimo = List.last(serie).periodo

    primeiro
    |> periodos_ate(ultimo, escala)
    |> Enum.map(&Map.get(por_periodo, &1, %{periodo: &1, criadas: 0, fechadas: 0}))
  end

  defp periodos_ate(de, ate, escala) do
    de
    |> primeira_data(escala)
    |> Stream.iterate(&proxima_data(&1, escala))
    |> Stream.map(&rotulo(&1, escala))
    |> Stream.take_while(&(&1 <= ate))
    # Limite explícito: uma pessoa com issue de 2015 e outra de 2026 daria 570 semanas, e
    # 570 barras não são um gráfico. O corte pelo FIM, e não pelo começo: o passado remoto
    # importa menos que o ritmo recente, e cortar o começo é o que a tela diz fazer.
    |> Enum.take(-@maximo_de_periodos)
  end

  # A semana ISO tem uma armadilha: `Date.new(ano_iso, 1, 4)` cai SEMPRE na semana 1 pela
  # definição da norma — 4 de janeiro é o primeiro dia do ano que necessariamente pertence à
  # semana 1. A partir dele, somar semanas é aritmética simples.
  defp primeira_data(<<ano::binary-4, "-W", semana::binary-2>>, :semana) do
    base = Date.new!(String.to_integer(ano), 1, 4)
    inicio = Date.beginning_of_week(base, :monday)
    Date.add(inicio, (String.to_integer(semana) - 1) * 7)
  end

  defp primeira_data(<<ano::binary-4, "-", mes::binary-2>>, :mes),
    do: Date.new!(String.to_integer(ano), String.to_integer(mes), 1)

  defp primeira_data(<<ano::binary-4>>, :ano), do: Date.new!(String.to_integer(ano), 1, 1)

  defp proxima_data(data, :semana), do: Date.add(data, 7)
  defp proxima_data(data, :mes), do: data |> Date.end_of_month() |> Date.add(1)
  defp proxima_data(data, :ano), do: Date.new!(data.year + 1, 1, 1)

  defp rotulo(data, :semana) do
    {ano_iso, semana} = :calendar.iso_week_number(Date.to_erl(data))
    "#{ano_iso}-W#{String.pad_leading("#{semana}", 2, "0")}"
  end

  defp rotulo(data, :mes),
    do: "#{data.year}-#{String.pad_leading("#{data.month}", 2, "0")}"

  defp rotulo(data, :ano), do: "#{data.year}"

  defp preencher_meses_vazios([]), do: []
  defp preencher_meses_vazios([_unico] = serie), do: serie

  defp preencher_meses_vazios(serie) do
    por_mes = Map.new(serie, &{&1.month, &1.count})
    primeiro = List.first(serie).month
    ultimo = List.last(serie).month

    primeiro
    |> meses_ate(ultimo)
    |> Enum.map(&%{month: &1, count: Map.get(por_mes, &1, 0)})
  end

  defp meses_ate(de, ate) do
    Stream.iterate(de, &proximo_mes/1)
    |> Enum.take_while(&(&1 <= ate))
  end

  defp proximo_mes(<<ano::binary-4, "-", mes::binary-2>>) do
    {a, m} = {String.to_integer(ano), String.to_integer(mes)}
    if m == 12, do: "#{a + 1}-01", else: "#{a}-#{String.pad_leading("#{m + 1}", 2, "0")}"
  end
end
