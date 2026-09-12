defmodule TheBand.Ontology.SEON.EO.VinculoPossivelTest do
  @moduledoc """
  O veredito antes do botão — feature 055, FR-003.

  Seis situações, seis consequências diferentes. Sem o veredito, duas delas seriam erro na
  cara de quem clica — e uma quarta seria pior: vínculo direto numa equipe composta **não
  muda a contagem de membros**, e descobrir isso depois do ato é ver o número não mexer sem
  saber por quê.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.VinculoPossivel

  setup do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant)
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{tenant: tenant, admin: admin, org: org, equipe: equipe, papel: papel}
  end

  defp pessoa(ctx, login, opts \\ []) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    # A marca é gravada direto: o caminho de coleta a põe ao fim de uma coleta inteira, e o
    # que este teste precisa é do ESTADO, não do caminho que o produz.
    if Keyword.get(opts, :sumiu?, false) do
      {:ok, marcada} =
        p
        |> Ecto.Changeset.change(no_longer_observed_at: DateTime.utc_now(:second))
        |> TheBand.Repo.update()

      marcada
    else
      p
    end
  end

  defp vincular(ctx, equipe, p) do
    {:ok, v} =
      EO.declare_team_membership(
        ctx.tenant,
        equipe.id,
        p.id,
        %{organizational_role_id: ctx.papel.id},
        ctx.admin.id
      )

    v
  end

  defp veredito(ctx, pessoas, equipe \\ nil) do
    alvo = equipe || ctx.equipe
    VinculoPossivel.vereditos(ctx.tenant, alvo.id, List.wrap(pessoas))
  end

  test "1 · pessoa sem nada nesta equipe: permitido", ctx do
    p = pessoa(ctx, "ana")
    assert {:permitido, %{}} = veredito(ctx, [p])[p.id]
  end

  test "2 · já é membro: RECUSA, e aponta o vínculo que falta papel", ctx do
    p = pessoa(ctx, "ana")
    v = vincular(ctx, ctx.equipe, p)

    assert {:recusado_ja_e_membro, ctx_v} = veredito(ctx, [p])[p.id]

    assert ctx_v.membership_id == v.id, """
    A recusa APONTA o vínculo: o ato certo é declarar o papel DAQUELE vínculo, e não criar um
    segundo. Sem o id, a tela diria "já é membro" e deixaria a pessoa procurar onde.
    """
  end

  test "3 · vínculo numa SUBEQUIPE: permitido, e é outro fato", ctx do
    {:ok, squad} = EO.declare_subteam(ctx.tenant, ctx.equipe, "Squad Azul", ctx.admin.id)
    p = pessoa(ctx, "ana")
    vincular(ctx, squad, p)

    assert {:permitido_fato_diferente, %{squads: squads}} = veredito(ctx, [p])[p.id]

    assert "Squad Azul" in squads, """
    A tela nomeia a squad. Direto e via squad são afirmações diferentes — e a contagem de
    membros da equipe composta NÃO muda, porque a pessoa já era contada pela parte.
    """
  end

  test "4 · SAIU daqui: vínculo novo, e os dois períodos coexistem", ctx do
    p = pessoa(ctx, "ana")
    vincular(ctx, ctx.equipe, p)

    {:ok, _} =
      EO.record_team_departure(
        ctx.tenant,
        ctx.equipe.id,
        p.id,
        DateTime.utc_now(:second),
        ctx.admin.id
      )

    assert {:permitido_vinculo_novo, _} = veredito(ctx, [p])[p.id]
  end

  test "5 · EQUÍVOCO aqui: permitido, e o equívoco fica", ctx do
    p = pessoa(ctx, "ana")
    vincular(ctx, ctx.equipe, p)

    {:ok, _} =
      EO.record_team_membership_mistake(
        ctx.tenant,
        ctx.equipe.id,
        p.id,
        "linha errada",
        ctx.admin.id
      )

    assert {:permitido_equivoco_fica, _} = veredito(ctx, [p])[p.id], """
    *Equívoco* e *saída* nunca colapsam num só: um diz que o vínculo NUNCA existiu, o outro
    que ele existiu e terminou. Um veredito só para os dois apagaria a diferença.
    """
  end

  test "6 · a origem deixou de mostrar: permitido, LEIA A MARCA", ctx do
    p = pessoa(ctx, "sumida", sumiu?: true)

    assert {:permitido_leia_a_marca, %{desde: desde}} = veredito(ctx, [p])[p.id]
    assert not is_nil(desde)
  end

  test "a ordem: quem já é membro E sumiu da origem lê RECUSA, e não a marca", ctx do
    p = pessoa(ctx, "ana", sumiu?: true)
    vincular(ctx, ctx.equipe, p)

    assert {:recusado_ja_e_membro, _} = veredito(ctx, [p])[p.id], """
    A marca de não-observada é sobre a PESSOA; o que ela tem NESTA equipe é o fato mais
    específico, e é o que decide o que o botão faz.
    """
  end

  test "oito resultados custam DUAS consultas, e não oito vereditos", ctx do
    pessoas = for n <- 1..8, do: pessoa(ctx, "p#{n}")

    uma = contar(fn -> veredito(ctx, [hd(pessoas)]) end)
    oito = contar(fn -> veredito(ctx, pessoas) end)

    assert oito == uma, """
    A busca roda no EVENTO da digitação. Um veredito por pessoa custaria oito idas ao banco
    por tecla — com 6 pessoas: #{uma}, com 8: #{oito}.
    """
  end

  test "lista vazia não vai ao banco", ctx do
    assert %{} == veredito(ctx, [])
    assert contar(fn -> veredito(ctx, []) end) == 0
  end

  defp contar(fun) do
    ref = make_ref()
    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], &__MODULE__.marcar/4, self())

    try do
      fun.()
      drenar(0)
    after
      :telemetry.detach({__MODULE__, ref})
    end
  end

  @doc false
  def marcar(_e, _m, _md, destino), do: send(destino, :q)

  defp drenar(n) do
    receive do
      :q -> drenar(n + 1)
    after
      0 -> n
    end
  end
end
