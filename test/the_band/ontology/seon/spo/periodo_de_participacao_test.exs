defmodule TheBand.Ontology.SEON.SPO.PeriodoDeParticipacaoTest do
  @moduledoc """
  A interseção pessoa → equipe → projeto — issue #505.

  ## As três asserções que carregam este arquivo

  1. **a interseção é a interseção** — quem entrou na equipe em janeiro e saiu em junho,
     com a equipe no projeto de março a dezembro, esteve no projeto de março a junho, e
     nenhuma das duas colunas diz isso sozinha;
  2. **os dois nulos têm sentidos opostos** — fim nulo é *em curso*, começo nulo é
     *desconhecido*, e colapsá-los faria a tela afirmar uma data que ninguém declarou;
  3. **janelas não são fundidas, e pessoas não são somadas duas vezes** — pessoa em duas
     equipes do mesmo projeto tem duas janelas e continua sendo uma pessoa.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo

  setup do
    tenant = tenant_fixture()
    user = user_fixture(tenant)
    organization = organization_fixture(tenant)
    {:ok, projeto} = SPO.create_project(tenant, %{name: "Conecta Fapes"}, user.id)

    %{tenant: tenant, user: user, organization: organization, projeto: projeto}
  end

  describe "a interseção" do
    test "janeiro-junho na equipe, março-dezembro no projeto, dá março-junho", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      ana = pessoa(ctx.tenant, "ana")

      membro(ctx, ana, equipe, ~U[2026-01-01 00:00:00Z], ~U[2026-06-30 00:00:00Z])
      vincular(ctx, equipe, ~U[2026-03-01 00:00:00Z], ~U[2026-12-31 00:00:00Z])

      assert [%{name: "ana", janelas: [janela]}] =
               SPO.project_participation(ctx.tenant, ctx.projeto.id)

      assert janela.started_at == ~U[2026-03-01 00:00:00Z], """
      **O começo é o MAIS TARDE dos dois.** Ana estava na equipe desde janeiro, mas a equipe
      só entrou no projeto em março — antes disso ela não estava no projeto, estava na
      equipe. Usar a data da equipe afirmaria dois meses de participação que não houve.
      """

      assert janela.ended_at == ~U[2026-06-30 00:00:00Z], """
      **O fim é o MAIS CEDO dos dois.** A equipe seguiu no projeto até dezembro; Ana saiu em
      junho. Usar a data do projeto afirmaria seis meses que não houve.
      """
    end

    test "quem saiu da equipe ANTES de ela entrar no projeto não aparece", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      bruno = pessoa(ctx.tenant, "bruno")

      membro(ctx, bruno, equipe, ~U[2026-01-01 00:00:00Z], ~U[2026-02-01 00:00:00Z])
      vincular(ctx, equipe, ~U[2026-03-01 00:00:00Z], nil)

      assert SPO.project_participation(ctx.tenant, ctx.projeto.id) == [], """
      **Interseção vazia é ausência de participação, e não uma janela de duração zero.**
      Bruno saiu da equipe um mês antes de ela entrar no projeto. Devolvê-lo com uma janela
      vazia faria a contagem de participantes incluir quem nunca participou.
      """
    end
  end

  describe "os dois nulos, e por que não são o mesmo nulo" do
    test "fim nulo é EM CURSO, e a janela não é encurtada por ele", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      ana = pessoa(ctx.tenant, "ana")

      membro(ctx, ana, equipe, ~U[2026-01-01 00:00:00Z], nil)
      vincular(ctx, equipe, ~U[2026-03-01 00:00:00Z], nil)

      assert [%{janelas: [janela]}] = SPO.project_participation(ctx.tenant, ctx.projeto.id)
      assert janela.started_at == ~U[2026-03-01 00:00:00Z]

      assert janela.ended_at == nil, """
      **Aberto dos dois lados continua aberto.** `LEAST` do PostgreSQL ignora nulo, e é isso
      que o torna certo aqui: o lado que não terminou não encurta a janela.
      """
    end

    test "começo nulo é DESCONHECIDO, e não vira a data do vínculo", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      ana = pessoa(ctx.tenant, "ana")

      # `eo_team_memberships.started_at` é anulável: a promoção da 043 nem sempre sabe desde
      # quando a pessoa está na equipe.
      membro(ctx, ana, equipe, nil, nil)
      vincular(ctx, equipe, ~U[2026-03-01 00:00:00Z], nil)

      assert [%{janelas: [janela]}] = SPO.project_participation(ctx.tenant, ctx.projeto.id)

      assert janela.started_at == nil, """
      **`GREATEST` do PostgreSQL ignora nulo**, e aqui isso seria o defeito: ele devolveria
      2026-03-01, e a tela mostraria uma data de entrada que ninguém declarou.

      Fim nulo e começo nulo são coisas diferentes — *em curso* e *desconhecido* — e o
      retorno tem que distinguir porque a tela precisa distinguir.
      """
    end
  end

  describe "janelas e pessoas" do
    test "duas equipes do mesmo projeto dão DUAS janelas, e UMA pessoa", ctx do
      uma = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      outra = team_fixture(ctx.tenant, "T2", %{organization: ctx.organization})
      ana = pessoa(ctx.tenant, "ana")

      membro(ctx, ana, uma, ~U[2026-01-01 00:00:00Z], ~U[2026-03-31 00:00:00Z])
      membro(ctx, ana, outra, ~U[2026-07-01 00:00:00Z], ~U[2026-09-30 00:00:00Z])
      vincular(ctx, uma, ~U[2026-01-01 00:00:00Z], nil)
      vincular(ctx, outra, ~U[2026-01-01 00:00:00Z], nil)

      assert [%{name: "ana", janelas: janelas}] =
               SPO.project_participation(ctx.tenant, ctx.projeto.id)

      assert length(janelas) == 2, """
      **As janelas NÃO são fundidas.** Fundir jan–mar com jul–set em jan–set afirmaria
      presença em abril, maio e junho — meses em que ela não esteve.
      """

      assert Enum.map(janelas, & &1.team_name) |> Enum.sort() == ["Time T1", "Time T2"], """
      E cada janela diz **por qual equipe**, que é a pergunta seguinte de quem lê.
      """
    end

    test "duas pessoas na mesma equipe são duas pessoas", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      membro(ctx, pessoa(ctx.tenant, "ana"), equipe, ~U[2026-01-01 00:00:00Z], nil)
      membro(ctx, pessoa(ctx.tenant, "bruno"), equipe, ~U[2026-02-01 00:00:00Z], nil)
      vincular(ctx, equipe, ~U[2026-01-01 00:00:00Z], nil)

      assert [%{name: "ana"}, %{name: "bruno"}] =
               SPO.project_participation(ctx.tenant, ctx.projeto.id)
    end
  end

  describe "o isolamento entre tenants" do
    test "a participação de outro tenant não vaza", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.organization})
      membro(ctx, pessoa(ctx.tenant, "ana"), equipe, ~U[2026-01-01 00:00:00Z], nil)
      vincular(ctx, equipe, ~U[2026-01-01 00:00:00Z], nil)

      outro = tenant_fixture()
      outro_user = user_fixture(outro)
      {:ok, outro_projeto} = SPO.create_project(outro, %{name: "Conecta Fapes"}, outro_user.id)

      assert SPO.project_participation(outro, outro_projeto.id) == []
      assert SPO.project_participation(outro, ctx.projeto.id) == []
    end
  end

  # ------------------------------------------------------------------ apoio

  defp pessoa(tenant, login) do
    agora = NaiveDateTime.utc_now(:second)
    id = Ecto.UUID.bingenerate()

    Repo.insert_all("eo_people", [
      %{
        id: id,
        tenant_id: Ecto.UUID.dump!(tenant.id),
        internal_id: "p-#{login}",
        record_version: 1,
        name: login,
        login: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: agora,
        inserted_at: agora,
        updated_at: agora
      }
    ])

    Ecto.UUID.load!(id)
  end

  defp membro(ctx, person_id, equipe, comeco, fim) do
    agora = NaiveDateTime.utc_now(:second)

    Repo.insert_all("eo_team_memberships", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(ctx.tenant.id),
        internal_id: "m-#{System.unique_integer([:positive])}",
        record_version: 1,
        person_id: Ecto.UUID.dump!(person_id),
        team_id: Ecto.UUID.dump!(equipe.id),
        organizational_role_id: Ecto.UUID.dump!(papel(ctx)),
        started_at: comeco && DateTime.to_naive(comeco),
        ended_at: fim && DateTime.to_naive(fim),
        inserted_at: agora,
        updated_at: agora
      }
    ])
  end

  defp papel(ctx) do
    case Process.get(:papel) do
      nil ->
        agora = NaiveDateTime.utc_now(:second)
        id = Ecto.UUID.bingenerate()

        Repo.insert_all("eo_organizational_roles", [
          %{
            id: id,
            tenant_id: Ecto.UUID.dump!(ctx.tenant.id),
            internal_id: "r-dev",
            record_version: 1,
            code: "developer",
            name: "Developer",
            organization_id: Ecto.UUID.dump!(ctx.organization.id),
            # A `papel_tem_uma_origem_so` da feature 043: o papel vem do catálogo OU foi
            # declarado por alguém, nunca os dois nem nenhum.
            declared_by_user_id: Ecto.UUID.dump!(ctx.user.id),
            inserted_at: agora,
            updated_at: agora
          }
        ])

        carregado = Ecto.UUID.load!(id)
        Process.put(:papel, carregado)
        carregado

      id ->
        id
    end
  end

  # A data do vínculo é gravada pela API; sobrescrevê-la depois é o que permite montar o
  # cenário sem esperar meses.
  defp vincular(ctx, equipe, comeco, fim) do
    {:ok, v} = SPO.link_team(ctx.tenant, ctx.projeto.id, equipe.id, ctx.user.id)

    Repo.update_all(
      from(t in "spo_project_teams", where: t.id == type(^v.id, :binary_id)),
      set: [
        linked_at: comeco && DateTime.to_naive(comeco),
        unlinked_at: fim && DateTime.to_naive(fim)
      ]
    )
  end
end
