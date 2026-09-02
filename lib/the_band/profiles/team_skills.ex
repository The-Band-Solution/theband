defmodule TheBand.Profiles.TeamSkills do
  @moduledoc """
  As competências de uma equipe, contadas dos perfis individuais — feature 029.

  ## Contar, nunca gerar de novo

  Tudo aqui é **agregação calculada** sobre os perfis vigentes dos membros. Rodar um
  segundo modelo sobre textos de modelo empilharia derivação sobre derivação; contar é
  auditável, e cada número desce até as tarefas-evidência que o sustentam.

  A célula da matriz é `destaques[].tarefas`: **tarefas concluídas** que evidenciam o
  domínio — entrega, nunca promessa. Tarefa aberta é intenção, e não demonstra nada.

  ## O que "vigente" significa, e por que a evolução funciona

  A tabela de perfis é somente-acréscimo. O perfil vigente de hoje é o mais recente; o
  vigente **numa data** é o mais recente até ela — e é isso que `evolution/2` reconta em
  cada mês que teve geração. Mês sem geração não entra na série: interpolar afirmaria
  observação que não houve (FR-003).

  ## Quem não tem perfil

  Vem **nomeado**, nunca somado como zero (FR-004). Ausência de perfil é ausência de
  leitura — a cobertura da equipe é um piso, não um teto.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type pessoa :: %{person_id: Ecto.UUID.t(), name: String.t(), tarefas: pos_integer()}
  @type competencia :: %{
          nome: String.t(),
          pessoas: [pessoa()],
          total_pessoas: pos_integer(),
          tarefas_somadas: pos_integer()
        }
  @type coverage :: %{
          membros: non_neg_integer(),
          com_perfil: non_neg_integer(),
          sem_perfil: [%{person_id: Ecto.UUID.t(), name: String.t()}],
          competencias: [competencia()]
        }

  @doc """
  A fotografia de hoje: cobertura por competência, com quem demonstra o quê.

  Competências por cobertura desc; **pessoas em ordem alfabética** dentro de cada uma —
  a matriz junta leituras individuais, nunca produz ranking (FR-006a).

  Número fixo de consultas (SC-001): uma para membros, uma para os perfis vigentes.
  """
  @spec coverage(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: coverage()
  def coverage(%Tenant{} = tenant, team_id, quando \\ DateTime.utc_now()) do
    membros = membros(tenant, team_id, quando)
    vigentes = perfis_vigentes(tenant, Enum.map(membros, & &1.person_id))

    montar_cobertura(membros, vigentes)
  end

  @doc """
  A evolução: um ponto por mês que teve geração de algum membro, com a cobertura
  recontada a partir dos perfis vigentes no fim daquele mês.
  """
  @spec evolution(Tenant.t(), Ecto.UUID.t()) :: [
          %{mes: Date.t(), cobertura: %{String.t() => non_neg_integer()}}
        ]
  def evolution(%Tenant{} = tenant, team_id) do
    # O universo é quem JÁ ESTEVE na equipe, e não quem está hoje. Montar a série
    # a partir dos membros de hoje faz quem saiu desaparecer de TODOS os meses,
    # inclusive daqueles em que pertencia — que é o defeito do SC-002 aparecendo
    # do outro lado. O recorte por mês vem depois, em `membros_em/3`.
    historico = perfis_todos(tenant, EO.team_member_ids_ever(tenant, team_id))

    historico
    |> Enum.map(&Date.beginning_of_month(data(&1.generated_at)))
    |> Enum.uniq()
    |> Enum.sort(Date)
    |> Enum.map(fn mes ->
      corte = Date.end_of_month(mes)
      do_mes = MapSet.new(membros_em(tenant, team_id, corte), & &1.person_id)

      vigentes_na_data =
        historico
        |> Enum.filter(
          &(Date.compare(data(&1.generated_at), corte) != :gt and
              MapSet.member?(do_mes, &1.person_id))
        )
        |> Enum.group_by(& &1.person_id)
        |> Enum.map(fn {_pid, gens} -> Enum.max_by(gens, & &1.generated_at, NaiveDateTime) end)

      cobertura =
        vigentes_na_data
        |> Enum.flat_map(fn perfil ->
          Enum.map(dominios(perfil), &{&1.nome, perfil.person_id})
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {nome, pids} -> {nome, pids |> Enum.uniq() |> length()} end)

      %{mes: mes, cobertura: cobertura}
    end)
  end

  @doc """
  O resumo, montado das contagens — frases calculadas, nunca texto de modelo (FR-007).

  Determinístico: o mesmo `coverage` produz as mesmas frases, na mesma ordem.
  """
  @spec summary(coverage()) :: [%{tipo: atom(), frase: String.t()}]
  def summary(%{competencias: competencias} = cobertura) do
    fortes =
      for c <- Enum.take(competencias, 3), c.total_pessoas >= 2 do
        c
      end

    pontos_unicos = Enum.filter(competencias, &(&1.total_pessoas == 1))

    frases = []

    frases =
      if fortes != [] do
        nomes = Enum.map_join(fortes, ", ", & &1.nome)
        tarefas = fortes |> Enum.map(& &1.tarefas_somadas) |> Enum.sum()
        pico = fortes |> Enum.map(& &1.total_pessoas) |> Enum.max()

        frases ++
          [
            %{
              tipo: :forte,
              frase:
                "Forte em #{nomes}: até #{pico} pessoas com evidência, " <>
                  "#{tarefas} tarefas-evidência somadas."
            }
          ]
      else
        frases
      end

    frases =
      case pontos_unicos do
        [] ->
          frases

        muitos when length(muitos) > 5 ->
          # Com domínios hiperespecíficos, QUASE TUDO é ponto único — e uma frase com 40
          # nomes não é leitura, é despejo. O teto mantém a frase útil; o número inteiro
          # continua dito. Visto no dado real em 2026-08-16: 40+ domínios em 1/18.
          nomes = muitos |> Enum.take(3) |> Enum.map_join(", ", & &1.nome)

          frases ++
            [
              %{
                tipo: :ponto_unico,
                frase:
                  "Ponto único de falha em #{length(muitos)} domínios — entre eles " <>
                    "#{nomes} — cada um com evidência em 1 pessoa só."
              }
            ]

        poucos ->
          nomes = Enum.map_join(poucos, ", ", & &1.nome)

          frases ++
            [
              %{
                tipo: :ponto_unico,
                frase: "Ponto único de falha: #{nomes} — evidência em 1 pessoa só."
              }
            ]
      end

    # Quando NENHUM domínio alcança duas pessoas, o problema não é o time — é a
    # granularidade: os perfis nomeiam domínios específicos demais para agregar. Dizer
    # isso é o que impede a tela de parecer "time sem sobreposição nenhuma". A agregação
    # por área é a #363.
    frases =
      if competencias != [] and Enum.all?(competencias, &(&1.total_pessoas == 1)) do
        frases ++
          [
            %{
              tipo: :granularidade,
              frase:
                "Nenhum domínio aparece em duas pessoas — os perfis nomeiam domínios " <>
                  "específicos demais para agregar. É limite da granularidade do registro, " <>
                  "não ausência de sobreposição no time."
            }
          ]
      else
        frases
      end

    if cobertura.sem_perfil != [] do
      frases ++
        [
          %{
            tipo: :sem_perfil,
            frase:
              "#{length(cobertura.sem_perfil)} de #{cobertura.membros} membros ainda sem " <>
                "perfil — a cobertura real pode ser maior, nunca menor."
          }
        ]
    else
      frases
    end
  end

  # ------------------------------------------------------------------- privados

  # A consulta é schemaless, e o banco devolve NaiveDateTime — normalizar aqui evita que
  # cada chamador descubra isso do jeito difícil.
  defp data(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp data(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)

  # O conjunto de membros vem do VÍNCULO DECLARADO vigente na data, e não da
  # evidência que a origem lista hoje — feature 057, FR-001.
  #
  # Antes desta correção, `list_team_members(include_no_longer_observed: false)`
  # devolvia quem o GitHub mostra AGORA, e o resultado era aplicado a qualquer
  # período. Duas consequências, e a segunda é a grave:
  #
  #   * quem saiu continuava contando depois da saída, se a origem ainda o lista;
  #   * o conjunto de HOJE era aplicado a todos os meses passados, de modo que o
  #     número de um mês fechado mudava hoje.
  #
  # A segunda é o mesmo defeito que o SC-003 da feature 055 proíbe no vínculo,
  # acontecendo na medida.
  # O conjunto de membros no FIM de um mês fechado. Uma consulta por ponto da
  # série, e não uma para a série inteira — é o que faz um mês passado devolver
  # sempre o mesmo número, por mais saídas que se registrem depois (SC-002).
  #
  # `corte` é uma Date; a vigência compara DateTime. O fim do dia é a borda
  # certa: o vínculo encerrado NAQUELE dia ainda vigeu no mês.
  defp membros_em(tenant, team_id, %Date{} = corte) do
    {:ok, fim} = DateTime.new(corte, ~T[23:59:59], "Etc/UTC")
    EO.team_members_at(tenant, team_id, fim)
  end

  defp membros(tenant, team_id, quando) do
    tenant
    |> EO.team_members_at(team_id, quando)
    |> Enum.map(fn m -> %{person_id: m.person_id, name: m.name || m.login} end)
    |> Enum.uniq_by(& &1.person_id)
  end

  # O perfil vigente de cada pessoa numa consulta só — DISTINCT ON, nunca uma por membro.
  defp perfis_vigentes(_tenant, []), do: []

  defp perfis_vigentes(%Tenant{id: tenant_id}, person_ids) do
    Repo.all(
      from p in "eo_person_profiles",
        distinct: p.person_id,
        order_by: [asc: p.person_id, desc: p.generated_at],
        where:
          p.tenant_id == type(^tenant_id, :binary_id) and
            p.person_id in type(^person_ids, {:array, :binary_id}),
        select: %{
          person_id: type(p.person_id, :binary_id),
          generated_at: p.generated_at,
          content: p.content
        }
    )
  end

  defp perfis_todos(_tenant, []), do: []

  defp perfis_todos(%Tenant{id: tenant_id}, person_ids) do
    Repo.all(
      from p in "eo_person_profiles",
        where:
          p.tenant_id == type(^tenant_id, :binary_id) and
            p.person_id in type(^person_ids, {:array, :binary_id}),
        select: %{
          person_id: type(p.person_id, :binary_id),
          generated_at: p.generated_at,
          content: p.content
        }
    )
  end

  defp montar_cobertura(membros, vigentes) do
    por_pessoa = Map.new(vigentes, &{&1.person_id, &1})
    nomes = Map.new(membros, &{&1.person_id, &1.name})

    sem_perfil =
      membros
      |> Enum.reject(&Map.has_key?(por_pessoa, &1.person_id))
      |> Enum.sort_by(& &1.name)

    competencias =
      vigentes
      |> Enum.flat_map(fn perfil ->
        for d <- dominios(perfil) do
          %{nome: d.nome, person_id: perfil.person_id, tarefas: d.tarefas}
        end
      end)
      |> Enum.group_by(& &1.nome)
      |> Enum.map(fn {nome, linhas} ->
        pessoas =
          linhas
          |> Enum.map(fn l ->
            %{person_id: l.person_id, name: nomes[l.person_id], tarefas: l.tarefas}
          end)
          |> Enum.uniq_by(& &1.person_id)
          # FR-006a: alfabética, nunca por total — a ordenação por contagem viraria placar.
          |> Enum.sort_by(& &1.name)

        %{
          nome: nome,
          pessoas: pessoas,
          total_pessoas: length(pessoas),
          tarefas_somadas: pessoas |> Enum.map(& &1.tarefas) |> Enum.sum()
        }
      end)
      |> Enum.sort_by(&{-&1.total_pessoas, -&1.tarefas_somadas, &1.nome})

    %{
      membros: length(membros),
      com_perfil: map_size(por_pessoa),
      sem_perfil: sem_perfil,
      competencias: competencias
    }
  end

  # A unidade é o destaque: domínio nomeado + contagem de tarefas concluídas que o
  # evidenciam. `habilidades` (strings soltas) fica de fora: sem contagem, viraria
  # competência sem lastro — e a #363 vai unificar as duas estruturas.
  defp dominios(%{content: content}) do
    for d <- content["destaques"] || [],
        is_binary(d["dominio"]),
        is_integer(d["tarefas"]) and d["tarefas"] > 0 do
      %{nome: d["dominio"], tarefas: d["tarefas"]}
    end
  end
end
