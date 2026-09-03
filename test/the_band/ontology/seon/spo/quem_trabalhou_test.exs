defmodule TheBand.Ontology.SEON.SPO.QuemTrabalhouTest do
  @moduledoc """
  Quem trabalhou neste projeto, e quando — feature 058, US2.

  As asserções que carregam este arquivo:

  1. **SC-004**: a interseção dos **três** períodos devolve exatamente quem estava
     nos dois ao mesmo tempo — montada à mão, sem confiar no acaso;
  2. **FR-008**: desligar **não apaga** — o intervalo em que vigeu continua
     contando;
  3. **FR-010/SC-006**: pessoa que alcança o projeto por duas equipes aparece
     **uma vez**;
  4. **FR-009/SC-005**: borda desconhecida vira `{:parcial, _}`, e o veredito mais
     **fraco** vence quando há dois caminhos;
  5. **SC-010**: nada atravessa a fronteira do tenant.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    {:ok, projeto} = SPO.create_project(tenant, %{name: "Alfa"}, admin.id)
    org = organization_fixture(tenant, "acme")
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{tenant: tenant, admin: admin, projeto: projeto, org: org, papel: papel}
  end

  # Datas nomeadas: os testes falam em meses, e ler `~U[...]` no corpo esconde a
  # intenção do caso.
  defp mes(n), do: DateTime.new!(Date.new!(2026, n, 1), ~T[00:00:00], "Etc/UTC")

  defp equipe(ctx, nome) do
    {:ok, t} = EO.create_declared_team(ctx.tenant, nome, ctx.admin.id)
    t
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
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

  defp vincular(ctx, equipe, pessoa, desde, ate) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: desde,
        ended_at: ate
      })
  end

  # `link_team/4` grava `linked_at` como agora; para controlar o período o teste
  # ajusta a coluna direto — é o que permite montar a matriz de datas à mão.
  # `spo_project_teams.linked_at` é NOT NULL — conferido na migração depois de o
  # teste falhar (R2a). A dúvida de borda só nasce do vínculo de PESSOA, cujo
  # `started_at` é anulável de propósito.
  defp ligar(ctx, equipe, desde, ate) do
    {:ok, v} = SPO.link_team(ctx.tenant, ctx.projeto.id, equipe.id, ctx.admin.id)

    TheBand.Repo.update_all(
      from(x in "spo_project_teams", where: x.id == type(^v.id, :binary_id)),
      set: [linked_at: desde, unlinked_at: ate]
    )

    v
  end

  defp quem(ctx, de, ate) do
    SPO.who_worked_on(ctx.tenant, ctx.projeto.id, %{inicio: de, fim: ate})
  end

  describe "a interseção dos três períodos" do
    setup ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      # equipe no projeto de janeiro a junho; ana na equipe de março a dezembro
      ligar(ctx, time, mes(1), mes(6))
      vincular(ctx, time, ana, mes(3), mes(12))
      Map.merge(ctx, %{time: time, ana: ana})
    end

    test "SC-004: fevereiro não devolve a pessoa — ela ainda não estava na equipe", ctx do
      assert quem(ctx, mes(2), mes(3)) == []
    end

    test "SC-004: abril devolve a pessoa — os três períodos se sobrepõem", ctx do
      assert [%{login: "ana", periodo: :intersecta}] = quem(ctx, mes(4), mes(5))
    end

    test "SC-004: agosto não devolve — a equipe já saiu do projeto", ctx do
      assert quem(ctx, mes(8), mes(9)) == []
    end

    test "FR-012: a janela que começa no fim do vínculo não intersecta", ctx do
      assert quem(ctx, mes(6), mes(7)) == []
    end
  end

  describe "desligar não apaga" do
    test "FR-008: perguntando pelo intervalo em que a equipe esteve ligada, as pessoas aparecem",
         ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      ligar(ctx, time, mes(1), mes(4))
      vincular(ctx, time, ana, mes(1), nil)

      assert [%{login: "ana"}] = quem(ctx, mes(2), mes(3))
      assert quem(ctx, mes(5), mes(6)) == []
    end
  end

  describe "uma pessoa, uma linha" do
    test "FR-010/SC-006: quem chega por duas equipes aparece uma vez, com as duas nomeadas",
         ctx do
      a = equipe(ctx, "Dados")
      b = equipe(ctx, "Interface")
      ana = pessoa(ctx, "ana")
      ligar(ctx, a, mes(1), nil)
      ligar(ctx, b, mes(1), nil)
      vincular(ctx, a, ana, mes(1), nil)
      vincular(ctx, b, ana, mes(1), nil)

      assert [linha] = quem(ctx, mes(2), mes(3))
      assert length(linha.equipes) == 2
      assert Enum.map(linha.equipes, & &1.name) |> Enum.sort() == ["Dados", "Interface"]
    end
  end

  describe "a borda desconhecida" do
    test "FR-009/SC-005: pessoa sem data de início devolve o veredito parcial", ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      ligar(ctx, time, mes(1), nil)
      # `started_at` nulo: entrou, e não se sabe quando
      vincular(ctx, time, ana, nil, nil)

      assert [%{periodo: {:parcial, bordas}}] = quem(ctx, mes(2), mes(3))
      assert :inicio_desconhecido in bordas
    end

    test "vínculo em curso NÃO é dúvida — `ended_at` nulo é vigente", ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      ligar(ctx, time, mes(1), nil)
      vincular(ctx, time, ana, mes(1), nil)

      assert [%{periodo: :intersecta}] = quem(ctx, mes(2), mes(3)),
             "marcar todo vínculo em curso como parcial poria a dúvida em quase toda linha"
    end

    test "o veredito mais FRACO vence quando há dois caminhos", ctx do
      a = equipe(ctx, "Certa")
      b = equipe(ctx, "Duvidosa")
      ana = pessoa(ctx, "ana")
      ligar(ctx, a, mes(1), mes(12))
      ligar(ctx, b, mes(1), mes(12))
      vincular(ctx, a, ana, mes(1), mes(12))
      vincular(ctx, b, ana, nil, mes(12))

      assert [%{periodo: {:parcial, _}}] = quem(ctx, mes(2), mes(3)),
             "dizer :intersecta porque um dos caminhos é certo esconderia a dúvida do outro"
    end
  end

  describe "isolamento entre tenants" do
    test "SC-010: o projeto de outro tenant não devolve pessoa nenhuma", ctx do
      time = equipe(ctx, "Dados")
      ana = pessoa(ctx, "ana")
      ligar(ctx, time, mes(1), nil)
      vincular(ctx, time, ana, mes(1), nil)

      {outro, outro_admin} = tenant_with_admin()
      {:ok, projeto_alheio} = SPO.create_project(outro, %{name: "Alfa"}, outro_admin.id)

      assert SPO.who_worked_on(outro, projeto_alheio.id, %{inicio: mes(1), fim: mes(12)}) == []
    end
  end
end
