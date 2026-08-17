defmodule TheBand.Profiles.TeamSkillsTest do
  @moduledoc """
  As competências da equipe, contadas — feature 029, SC-001 a SC-004 e FR-006a.

  ## As asserções que carregam este arquivo

  1. **SC-002**: o número por competência = pessoas distintas com ela no perfil vigente;
  2. **SC-003**: membro sem perfil é nomeado, e nenhuma contagem o trata como zero;
  3. **SC-004/FR-003**: a evolução usa o perfil vigente em cada mês com geração —
     mês sem geração não existe na série;
  4. **FR-006a**: pessoas em ordem alfabética, nunca por total — a matriz não é placar;
  5. **SC-001**: número fixo de consultas, provado pelo contador único.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.TeamSkills

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    {:ok, equipe} = EO.create_declared_team(tenant, "Plataforma", admin.id)

    %{tenant: tenant, admin: admin, equipe: equipe}
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  defp membro(tenant, equipe, pessoa) do
    agora = DateTime.utc_now(:second)

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        team_id: equipe.id,
        person_id: pessoa.id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        person_external_id: "U_#{pessoa.login}",
        team_external_id: "T_#{equipe.id}",
        collected_at: agora,
        observed_at: agora,
        last_observed_at: agora
      })
  end

  defp perfil(tenant, pessoa, destaques, gerado_em) do
    {:ok, _} =
      EO.record_profile(tenant, %{
        person_id: pessoa.id,
        generated_at: gerado_em,
        model: "m1",
        content: %{
          "habilidades" => Enum.map(destaques, &elem(&1, 0)),
          "destaques" =>
            Enum.map(destaques, fn {dominio, tarefas} ->
              %{
                "dominio" => dominio,
                "demonstrou" => "x",
                "tarefas" => tarefas,
                "periodos" => [1],
                "mais_recente" => "2026-08",
                "evidencia" => [1]
              }
            end),
          "lacunas" => [],
          "resumo" => %{"forcas" => "f", "evolucao" => "e", "atencao" => "a"},
          "trajetoria" => [],
          "alocacao" => [],
          "recomendacoes" => []
        },
        tasks_closed: 30,
        tasks_open: 0,
        tasks_with_body: 30,
        tasks_authored_by_other: 0,
        tasks_shared: 0
      })
  end

  defp agora_menos(dias),
    do: DateTime.utc_now(:second) |> DateTime.add(-dias, :day)

  test "SC-002: o número por competência é pessoas distintas no perfil vigente", ctx do
    ana = pessoa(ctx.tenant, "ana")
    bia = pessoa(ctx.tenant, "bia")
    membro(ctx.tenant, ctx.equipe, ana)
    membro(ctx.tenant, ctx.equipe, bia)

    perfil(ctx.tenant, ana, [{"observabilidade", 14}, {"kubernetes", 9}], agora_menos(2))
    # O perfil ANTIGO da bia tinha kubernetes; o vigente não tem mais — só o vigente conta.
    perfil(ctx.tenant, bia, [{"kubernetes", 5}], agora_menos(10))
    perfil(ctx.tenant, bia, [{"observabilidade", 8}], agora_menos(1))

    cobertura = TeamSkills.coverage(ctx.tenant, ctx.equipe.id)

    obs = Enum.find(cobertura.competencias, &(&1.nome == "observabilidade"))
    k8s = Enum.find(cobertura.competencias, &(&1.nome == "kubernetes"))

    assert obs.total_pessoas == 2
    assert obs.tarefas_somadas == 22

    assert k8s.total_pessoas == 1,
           "o perfil antigo contou — a cobertura é do VIGENTE, e o histórico é da evolução"
  end

  test "SC-003: membro sem perfil é nomeado, nunca zero", ctx do
    ana = pessoa(ctx.tenant, "ana")
    sem = pessoa(ctx.tenant, "zulmira")
    membro(ctx.tenant, ctx.equipe, ana)
    membro(ctx.tenant, ctx.equipe, sem)

    perfil(ctx.tenant, ana, [{"observabilidade", 14}], agora_menos(1))

    cobertura = TeamSkills.coverage(ctx.tenant, ctx.equipe.id)

    assert cobertura.membros == 2
    assert cobertura.com_perfil == 1
    assert [%{name: "zulmira"}] = cobertura.sem_perfil

    frases = TeamSkills.summary(cobertura)

    assert Enum.any?(frases, &(&1.tipo == :sem_perfil and &1.frase =~ "1 de 2")),
           "o resumo não nomeou quem falta — ausência virou silêncio"
  end

  test "SC-004/FR-003: a evolução reconta com o vigente de cada mês com geração", ctx do
    ana = pessoa(ctx.tenant, "ana")
    membro(ctx.tenant, ctx.equipe, ana)

    # Duas gerações em meses diferentes; entre elas há meses SEM geração.
    perfil(ctx.tenant, ana, [{"kubernetes", 5}], agora_menos(95))
    perfil(ctx.tenant, ana, [{"kubernetes", 9}, {"helm", 4}], agora_menos(2))

    serie = TeamSkills.evolution(ctx.tenant, ctx.equipe.id)

    assert length(serie) == 2, "mês sem geração entrou na série — interpolação proibida"

    [antigo, novo] = serie
    assert antigo.cobertura == %{"kubernetes" => 1}
    assert novo.cobertura == %{"kubernetes" => 1, "helm" => 1}
    assert Map.get(antigo.cobertura, "helm", 0) == 0, "helm apareceu antes de existir"
  end

  test "FR-006a: pessoas em ordem alfabética, nunca por total", ctx do
    # zana tem MAIS tarefas que ana — se a ordenação fosse por total, zana viria primeiro.
    ana = pessoa(ctx.tenant, "ana")
    zana = pessoa(ctx.tenant, "zana")
    membro(ctx.tenant, ctx.equipe, ana)
    membro(ctx.tenant, ctx.equipe, zana)

    perfil(ctx.tenant, ana, [{"observabilidade", 3}], agora_menos(2))
    perfil(ctx.tenant, zana, [{"observabilidade", 30}], agora_menos(1))

    cobertura = TeamSkills.coverage(ctx.tenant, ctx.equipe.id)
    [obs] = cobertura.competencias

    assert Enum.map(obs.pessoas, & &1.name) == ["ana", "zana"],
           """
           As pessoas saíram ordenadas por contagem.

           FR-006a: a matriz junta leituras individuais e nunca produz ranking — 30 tarefas
           de quem fecha tarefas pequenas não valem mais que 3 de quem fecha grandes.
           """
  end

  test "SC-001: número fixo de consultas, com muitos membros", ctx do
    for i <- 1..8 do
      p = pessoa(ctx.tenant, "pessoa-#{i}")
      membro(ctx.tenant, ctx.equipe, p)
      perfil(ctx.tenant, p, [{"observabilidade", i}], agora_menos(i))
    end

    consultas =
      TheBand.ContadorDeConsultas.contar(fn ->
        TeamSkills.coverage(ctx.tenant, ctx.equipe.id)
      end)

    assert consultas <= 4, """
    A cobertura fez #{consultas} consultas com 8 membros — ela consulta por pessoa.

    SC-001: o número é fixo. É o defeito das 135 consultas da feature 007, numa roupa nova.
    """
  end
end
