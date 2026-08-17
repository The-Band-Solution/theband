defmodule TheBand.Profiles.Material do
  @moduledoc """
  O recorte de trabalho de uma pessoa, montado para virar perfil — feature 026.

  **Não fala com a rede.** É testável com o banco só, e é aqui que mora o defeito mais caro
  se estiver errado: um recorte torto produz um texto plausível sobre a pessoa errada.

  ## Três períodos por volume, e não por duração

  Períodos de mesma duração comparariam quatro tarefas com noventa, e a comparação diria mais
  sobre quando a pessoa entrou do que sobre como ela mudou. Os tercis são por contagem.

  ## O veredito da linha de base é calculado aqui

  Na validação de 2026-08-15 o modelo recebeu a série `415, 428, 814` do projeto e escreveu
  que ela ficara *"perto de estável"*. É o dobro — e é justamente a conta que decide se a
  mudança pode ser atribuída à pessoa (`profile.thresholds`, `baseline_comparison`).

  Conta que decide requisito não se delega a quem só lê texto: a plataforma calcula, e o
  modelo recebe a frase pronta.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Profiles.Baseline
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type tarefa :: %{
          number: integer(),
          data: Date.t(),
          titulo: String.t(),
          corpo: String.t(),
          repositorio: String.t(),
          tipo: String.t(),
          autoria_propria: boolean(),
          designados: pos_integer(),
          dias_aberta: integer() | nil
        }

  # `de` e `ate` são anuláveis, e não por descuido: um período vazio não tem mês, e o tipo
  # tem de dizer isso. O Dialyzer pegou a versão anterior, que declarava `String.t()` e
  # deixava a cláusula `nil` inalcançável — contrato que mente é pior que contrato ausente.
  @type periodo :: %{
          indice: 1..3,
          de: String.t() | nil,
          ate: String.t() | nil,
          tarefas: [tarefa()],
          corpo_mediano: non_neg_integer(),
          autoria_propria: non_neg_integer(),
          base: map()
        }

  @type t :: %{
          login: String.t() | nil,
          person_id: binary(),
          de: String.t() | nil,
          ate: String.t() | nil,
          concluidas: [tarefa()],
          abertas: [tarefa()],
          com_corpo: non_neg_integer(),
          autoria_propria: non_neg_integer(),
          compartilhadas: non_neg_integer(),
          por_mes: [{String.t(), non_neg_integer(), non_neg_integer()}],
          repositorios: [{String.t(), non_neg_integer()}],
          tipos: [{String.t(), non_neg_integer()}],
          periodos: [periodo()],
          veredito: String.t(),
          paradas: [tarefa()]
        }

  @doc """
  Monta o recorte de uma pessoa.

  Os quatro erros são distintos de propósito, porque os quatro fatos são:

  | erro | o que aconteceu | o que quem lê deveria fazer |
  |---|---|---|
  | `:no_assignment` | não há de onde olhar | conferir se a pessoa tem designação vigente |
  | `:below_floor` | há material, e é pouco | esperar mais trabalho registrado |
  | `:period_too_thin` | há material, e não dá para falar de evolução | ler o painel de trabalho |
  | `:no_text_to_compare` | há tarefa, e não há texto nela | o registro é que precisa melhorar |

  Um `:error` genérico faria a tela dizer a mesma frase para os quatro, e cada um pede uma
  ação diferente — em especial o último, que aponta para o hábito do time e não para a pessoa.
  """
  @spec build(Tenant.t(), binary(), :normal | :primeira) ::
          {:ok, t()}
          | {:error, :no_assignment}
          | {:error, {:below_floor, %{com_corpo: non_neg_integer(), piso: pos_integer()}}}
          | {:error, {:period_too_thin, %{contagens: [non_neg_integer()], piso: pos_integer()}}}
          | {:error, {:no_text_to_compare, %{medianas: [non_neg_integer()]}}}
  def build(%Tenant{} = tenant, person_id, modo \\ :normal) do
    concluidas = tarefas(tenant, person_id, "CLOSED")
    abertas = tarefas(tenant, person_id, "OPEN")

    limiares = limiares()
    piso = limiares["evidence_floor"]["values"]["tasks_with_body"]
    piso_periodo = limiares["evidence_floor"]["values"]["tasks_per_period"]
    com_corpo = Enum.count(concluidas, &(String.trim(&1.corpo) != ""))

    # O piso mede TEXTO suficiente, e título é texto — decisão de 2026-08-16: sem corpo,
    # o título vale. `com_corpo` continua contando corpos reais (é a estatística que o
    # perfil grava e a tela mostra); o piso conta o que dá para ler.
    com_texto = Enum.count(concluidas, &(texto_da_tarefa(&1) > 0))

    grupos = tercis(concluidas)
    contagens = Enum.map(grupos, &length/1)

    cond do
      concluidas == [] and abertas == [] ->
        {:error, :no_assignment}

      # **A primeira geração não tem o que comparar** — decisão da pessoa mantenedora em
      # 2026-08-16: sem perfil anterior, pega-se tudo que existe, títulos e descrições.
      # Os três pisos abaixo protegem a COMPARAÇÃO temporal (evolução entre períodos), e
      # quem nunca teve perfil ainda não está comparando nada. Da segunda geração em
      # diante eles voltam a valer inteiros.
      modo == :primeira and com_texto > 0 ->
        {:ok, montar(tenant, person_id, concluidas, abertas, grupos, com_corpo, limiares)}

      com_texto < piso ->
        {:error, {:below_floor, %{com_corpo: com_texto, piso: piso}}}

      Enum.any?(contagens, &(&1 < piso_periodo)) ->
        {:error, {:period_too_thin, %{contagens: contagens, piso: piso_periodo}}}

      true ->
        material = montar(tenant, person_id, concluidas, abertas, grupos, com_corpo, limiares)
        sem_texto?(material) || {:ok, material}
    end
  end

  # **A quarta recusa, e ela veio da implementação.** `costabeber` tem 41 tarefas com corpo
  # — acima do piso de 15 — e mediana **zero** em dois dos três períodos: metade das
  # descrições está vazia.
  #
  # Sem corpo mediano não há razão de crescimento, e sem razão não há como cumprir a
  # `FR-010`: a plataforma não conseguiria dizer se a mudança é da pessoa ou do time. Deixar
  # passar produziria um perfil com a comparação faltando, e um texto que afirma sobre a
  # pessoa sem o contrapeso que torna a afirmação honesta.
  #
  # Recusar aqui é o oposto de degradar em silêncio.
  defp texto_da_tarefa(%{corpo: corpo, titulo: titulo}) do
    case String.length(corpo) do
      0 -> String.length(titulo || "")
      n -> n
    end
  end

  defp sem_texto?(%{periodos: periodos}) do
    medianas = Enum.map(periodos, & &1.corpo_mediano)

    if Enum.any?(medianas, &(&1 == 0)) do
      {:error, {:no_text_to_compare, %{medianas: medianas}}}
    else
      false
    end
  end

  # -- montagem ----------------------------------------------------------------

  defp montar(tenant, person_id, concluidas, abertas, grupos, com_corpo, limiares) do
    base = Baseline.load(tenant)
    periodos = periodos(grupos, base)
    dias = limiares["stale_open_work"]["values"]["stale_days"]
    limiar = limiares["baseline_comparison"]["values"]["ratio_threshold"]

    %{
      login: login(concluidas, abertas),
      person_id: person_id,
      de: primeiro_mes(concluidas),
      ate: ultimo_mes(concluidas),
      concluidas: concluidas,
      abertas: abertas,
      com_corpo: com_corpo,
      autoria_propria: Enum.count(concluidas, & &1.autoria_propria),
      compartilhadas: Enum.count(concluidas, &(&1.designados > 1)),
      por_mes: por_mes(concluidas, base),
      repositorios: frequencias(concluidas, & &1.repositorio),
      tipos: frequencias(concluidas, & &1.tipo),
      periodos: periodos,
      veredito: veredito(periodos, limiar),
      paradas: Enum.filter(abertas, &(&1.dias_aberta > dias))
    }
  end

  @doc """
  Divide as tarefas em três períodos **por volume**, e não por duração.

  Períodos de mesma duração comparariam quatro tarefas com noventa, e a comparação diria mais
  sobre quando a pessoa entrou do que sobre como ela mudou.

  `chunk_every` deixa sobra quando a contagem não é múltipla de três, e ela volta para o
  último período em vez de virar um quarto — quatro períodos quebrariam a comparação que a
  feature inteira faz.

  Pública porque a forma da divisão é decisão de domínio, e o teste dela não depende do banco.
  """
  @spec tercis([tarefa()]) :: [[tarefa()]]
  def tercis(concluidas) when length(concluidas) < 3, do: [concluidas, [], []]

  def tercis(concluidas) do
    tamanho = max(div(length(concluidas), 3), 1)

    case Enum.chunk_every(concluidas, tamanho) do
      [a, b, c | resto] -> [a, b, c ++ List.flatten(resto)]
      partes -> partes ++ List.duplicate([], 3 - length(partes))
    end
  end

  defp periodos(grupos, base) do
    grupos
    |> Enum.with_index(1)
    |> Enum.map(fn {tarefas, indice} ->
      de = primeiro_mes(tarefas)
      ate = ultimo_mes(tarefas)

      %{
        indice: indice,
        de: de,
        ate: ate,
        tarefas: tarefas,
        # **Sem corpo, o título é o texto** — decisão da pessoa mantenedora em
        # 2026-08-16. Antes, um período onde a maioria das tarefas não tinha corpo dava
        # mediana zero e recusava o perfil inteiro por :no_text_to_compare — foi o caso
        # real de MateusLannes: 246 fechadas, e o primeiro terço com 44% de corpo. O
        # título sempre existe e sempre foi parte do material; medi-lo como texto quando
        # o corpo falta é ler o que há, em vez de recusar pelo que falta.
        corpo_mediano: mediana(Enum.map(tarefas, &texto_da_tarefa/1)),
        autoria_propria: Enum.count(tarefas, & &1.autoria_propria),
        base: Baseline.fatia(base, de, ate)
      }
    end)
  end

  # -- o veredito --------------------------------------------------------------

  @doc """
  Compara o crescimento do texto da pessoa com o do projeto nos mesmos meses, e devolve a
  frase pronta.

  Abaixo do limiar de diferença entre as duas razões, a mudança é da convenção do time. Ver
  `profile.thresholds`, regra `baseline_comparison`.
  """
  @spec veredito([periodo()], float()) :: String.t()
  def veredito(periodos, limiar) do
    pessoa = Enum.map(periodos, & &1.corpo_mediano)
    projeto = Enum.map(periodos, & &1.base.corpo_mediano)

    rp = razao(pessoa)
    rj = razao(projeto)

    frase =
      cond do
        is_nil(rp) or is_nil(rj) ->
          "não calculável — algum período sem corpo medido"

        rp / rj >= limiar ->
          "a pessoa cresceu ACIMA do projeto: a mudança é dela"

        rj / rp >= limiar ->
          "a pessoa cresceu ABAIXO do projeto: mudança na direção oposta, e vale registrar"

        true ->
          "a pessoa ACOMPANHOU o projeto: a mudança é da convenção do time, e NÃO dela"
      end

    "pessoa #{Enum.join(pessoa, " → ")} (#{fmt(rp)}) · " <>
      "projeto #{Enum.join(projeto, " → ")} (#{fmt(rj)}) — #{frase}"
  end

  defp razao(serie) do
    primeiro = List.first(serie)
    if primeiro in [0, nil], do: nil, else: List.last(serie) / primeiro
  end

  defp fmt(nil), do: "—"
  defp fmt(r), do: "#{Float.round(r, 1)}×"

  @doc """
  Responde se **haveria** material, sem montar o material.

  A tela chama isto a cada render, e `build/2` carrega todas as tarefas com corpo mais a
  linha de base do tenant — quatro consultas e muito texto para decidir se um botão aparece.
  Aqui vai **uma** consulta, e ela traz só o que os pisos precisam: a data de fechamento e o
  **tamanho** de cada corpo, não o corpo.

  Devolve os mesmos erros de `build/2`, com as mesmas formas, porque a tela usa a mesma
  frase para os dois caminhos.
  """
  @spec check(Tenant.t(), binary(), :normal | :primeira) :: :ok | {:error, term()}
  def check(%Tenant{id: tenant_id}, person_id, modo \\ :normal) do
    tamanhos =
      from(i in "collected_issues",
        join: a in "issue_assignees",
        on: a.collected_issue_id == i.id and is_nil(a.no_longer_observed_at),
        where:
          i.tenant_id == type(^tenant_id, :binary_id) and
            a.person_id == type(^person_id, :binary_id),
        order_by: [asc: coalesce(i.external_closed_at, i.external_created_at)],
        select:
          {i.state,
           fragment(
             "case when length(coalesce(?, '')) > 0 then length(?) else length(coalesce(?, '')) end",
             i.body,
             i.body,
             i.title
           )}
      )
      |> Repo.all()

    avaliar(tamanhos, limiares(), modo)
  end

  defp avaliar([], _limiares, _modo), do: {:error, :no_assignment}

  defp avaliar(tamanhos, limiares, modo) do
    piso = limiares["evidence_floor"]["values"]["tasks_with_body"]
    piso_periodo = limiares["evidence_floor"]["values"]["tasks_per_period"]

    fechadas = for {"CLOSED", n} <- tamanhos, do: n
    com_corpo = Enum.count(fechadas, &(&1 > 0))
    grupos = tercis(fechadas)
    contagens = Enum.map(grupos, &length/1)
    medianas = Enum.map(grupos, &mediana/1)

    cond do
      # A primeira geração pega tudo que tem texto — os pisos protegem a comparação, e
      # quem nunca teve perfil não está comparando nada (decisão de 2026-08-16).
      modo == :primeira and com_corpo > 0 ->
        :ok

      com_corpo < piso ->
        {:error, {:below_floor, %{com_corpo: com_corpo, piso: piso}}}

      Enum.any?(contagens, &(&1 < piso_periodo)) ->
        {:error, {:period_too_thin, %{contagens: contagens, piso: piso_periodo}}}

      Enum.any?(medianas, &(&1 == 0)) ->
        {:error, {:no_text_to_compare, %{medianas: medianas}}}

      true ->
        :ok
    end
  end

  @doc "As tarefas abertas com designação vigente, com a idade de cada uma."
  @spec open_tasks(Tenant.t(), binary()) :: [tarefa()]
  def open_tasks(%Tenant{} = tenant, person_id), do: tarefas(tenant, person_id, "OPEN")

  @doc "A idade a partir da qual uma tarefa aberta vira ação — `profile.thresholds`."
  @spec stale_days() :: pos_integer()
  def stale_days, do: limiares()["stale_open_work"]["values"]["stale_days"]

  # -- consultas ---------------------------------------------------------------

  defp tarefas(%Tenant{id: tenant_id}, person_id, estado) do
    ordem = if estado == "CLOSED", do: :external_closed_at, else: :external_created_at

    from(i in "collected_issues",
      join: a in "issue_assignees",
      on: a.collected_issue_id == i.id and is_nil(a.no_longer_observed_at),
      join: o in "observed_repositories",
      on: o.id == i.observed_repository_id,
      join: sr in "cmpo_source_repositories",
      on: sr.id == o.source_repository_id,
      where:
        i.tenant_id == type(^tenant_id, :binary_id) and
          a.person_id == type(^person_id, :binary_id) and
          i.state == ^estado and not is_nil(field(i, ^ordem)),
      order_by: [asc: field(i, ^ordem)],
      select: %{
        # O id existe para a tela ligar a tarefa à página dela — o prompt não o usa, e um
        # UUID no material seria ruído que o modelo poderia citar.
        #
        # O `type/2` é obrigatório: a consulta é schemaless, e sem ele o id vem como os
        # dezesseis bytes crus — a URL montada com eles é lixo, e foi exatamente o defeito
        # observado no primeiro clique (2026-08-16).
        id: type(i.id, :binary_id),
        number: i.number,
        data: fragment("?::date", field(i, ^ordem)),
        titulo: i.title,
        corpo: fragment("coalesce(?, '')", i.body),
        repositorio: sr.name,
        tipo: fragment("coalesce(?, '—')", i.issue_type),
        login: a.login,
        autoria_propria: i.author_login == a.login,
        designados:
          fragment(
            "(select count(*) from issue_assignees x where x.collected_issue_id = ? and x.no_longer_observed_at is null)",
            i.id
          ),
        dias_aberta:
          fragment(
            "extract(day from (coalesce(?, now()) - ?))::int",
            i.external_closed_at,
            i.external_created_at
          )
      }
    )
    |> Repo.all()
  end

  # -- utilidades --------------------------------------------------------------

  defp limiares do
    case KnowledgeBase.rule("profile.thresholds") do
      {:ok, regra} ->
        Map.fetch!(regra, "rules")

      # Base não carregada **não** vira piso zero lido como "pode descrever qualquer um":
      # isso produziria perfil sobre quem a plataforma decidiu não descrever. Levanta.
      :error ->
        raise "regra profile.thresholds ausente da base de conhecimento"
    end
  end

  defp login([], []), do: nil
  defp login([t | _], _), do: t.login
  defp login([], [t | _]), do: t.login

  # `Enum.sort/1` sobre `%Date{}` compara o struct campo a campo em ordem alfabética de
  # chave — `calendar, day, month, year` — e ordena **pelo dia**. O módulo como sorter é o
  # que faz `Date.compare/2` ser usado.
  defp primeiro_mes([]), do: nil
  defp primeiro_mes(tarefas), do: tarefas |> datas() |> List.first() |> mes()

  defp ultimo_mes([]), do: nil
  defp ultimo_mes(tarefas), do: tarefas |> datas() |> List.last() |> mes()

  defp datas(tarefas),
    do: tarefas |> Enum.map(& &1.data) |> Enum.reject(&is_nil/1) |> Enum.sort(Date)

  defp mes(nil), do: nil
  defp mes(%Date{} = d), do: d |> Date.to_iso8601() |> String.slice(0, 7)

  defp por_mes(concluidas, base) do
    concluidas
    |> Enum.frequencies_by(&mes(&1.data))
    |> Enum.sort()
    |> Enum.map(fn {m, n} -> {m, n, get_in(base, [m, :concluidas]) || 0} end)
  end

  defp frequencias(tarefas, fun) do
    tarefas |> Enum.frequencies_by(fun) |> Enum.sort_by(&(-elem(&1, 1)))
  end

  defp mediana([]), do: 0
  defp mediana(valores), do: Enum.at(Enum.sort(valores), div(length(valores), 2))
end
