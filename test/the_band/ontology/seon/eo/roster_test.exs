defmodule TheBand.Ontology.SEON.EO.RosterTest do
  @moduledoc """
  O roster da equipe — feature 060, T009: FR-008 a FR-013.

  ## Por que este arquivo existe, e o que ele repara

  A feature foi construída sem ele. Delegado no início da sessão de 2026-09-08 e nunca
  entregue, e o Product Owner o encontrou na aceitação: a US1 ficou **aceita com pendência**
  porque o caso **central da FR-009** estava sem prova.

  O que a suíte já provava era o caso vizinho: uma pessoa com **dois papéis na mesma equipe**
  conta uma vez. Isso exercita a deduplicação por **papel** — o alcance tem um `team_id` só.

  O caso da FR-009 é outro: a pessoa tem vínculos em equipes **diferentes** — a própria e uma
  parte —, e o alcance tem dois ou mais ids. É a deduplicação por **equipe**, e o primeiro
  caso passa com este quebrado. Nenhum teste da suíte punha uma pessoa numa parte para lê-la
  pelo roster da mãe.

  ## As cinco asserções que carregam este arquivo

  1. **uma linha por pessoa**, com os vínculos das equipes diferentes dentro dela (FR-009);
  2. **os chips**: `squads` traz o nome das partes, `direta?` diz se há vínculo na própria
     equipe. São o que a tela desenha, e nunca foram afirmados;
  3. **os três números do cabeçalho batem com a listagem** (FR-012). É a afirmação mais
     desconfortável da tela — o argumento de que não se contradizem é "saem da mesma
     agregação", e ninguém o verificava;
  4. **composição encerrada não entra**: a parte saiu do todo, e listar os membros dela
     afirmaria uma estrutura que não existe mais;
  5. **as três formas de fim** são distinguidas (FR-022), inclusive a que a tela precisa
     nomear em palavras — o fim constatado pela coleta.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo

  @dia_1 ~U[2026-01-01 00:00:00Z]
  @dia_30 ~U[2026-01-30 00:00:00Z]

  setup do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})
    parte = team_fixture(tenant, "T_dados", %{organization: org, name: "DADOS"})

    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, autor.id)
    {:ok, sm} = EO.create_role(tenant, org.id, %{code: "sm", name: "Scrum Master"}, autor.id)

    %{
      tenant: tenant,
      autor: autor,
      org: org,
      equipe: equipe,
      parte: parte,
      dev: dev,
      sm: sm
    }
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        source_attrs("U_#{login}", %{login: login, name: String.capitalize(login)})
      )

    p
  end

  defp compor(ctx),
    do: {:ok, _} = EO.compose_teams(ctx.tenant, ctx.parte.id, ctx.equipe.id, ctx.autor.id)

  defp declarar(ctx, pessoa, papel, equipe, desde \\ @dia_1) do
    {:ok, v} =
      EO.declare_role(ctx.tenant, equipe.id, pessoa.id, {:existente, papel.id}, ctx.autor.id,
        started_at: desde
      )

    v
  end

  defp observar(ctx, pessoa, equipe, quando) do
    {:ok, e} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: pessoa.external_id,
        team_external_id: equipe.external_id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: quando
      })

    e
  end

  describe "UMA linha por pessoa, com os vínculos de equipes diferentes dentro (FR-009)" do
    test "direta na equipe E numa subequipe: uma linha, dois vínculos", ctx do
      compor(ctx)
      ana = pessoa(ctx, "ana")

      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, ana, ctx.sm, ctx.parte)

      # Dois vínculos no banco, em equipes diferentes.
      assert Repo.aggregate(TeamMembership, :count) == 2

      linhas = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      assert [uma] = linhas, """
      É o caso CENTRAL da FR-009, e o que o roster foi desenhado para corrigir: a versão
      anterior listava evidências, e quem tinha vínculo direto e numa subequipe aparecia duas
      vezes numa tela cuja pergunta é "quem está nesta equipe".

      Achei #{length(linhas)} linhas.

      Note que dois papéis na MESMA equipe não provam isto: ali o alcance tem um `team_id` só,
      e a deduplicação é por papel. Aqui o alcance tem dois ids, e é por equipe.
      """

      assert uma.person_id == ana.id
      assert length(uma.vinculos) == 2, "os dois vínculos têm de vir dentro da linha"
      assert uma.situacao == :vigente
    end

    test "os chips: squads traz a PARTE, e direct diz que há vínculo na própria equipe", ctx do
      compor(ctx)
      ana = pessoa(ctx, "ana")

      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, ana, ctx.sm, ctx.parte)

      [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      assert uma.direta? == true

      assert uma.squads == ["DADOS"], """
      `squads` é o nome das PARTES onde a pessoa tem vínculo vigente, e a equipe da própria
      tela nunca é chip — ela é a tela. Achei #{inspect(uma.squads)}.
      """
    end

    test "só na subequipe: aparece no roster da mãe, sem o chip direct", ctx do
      compor(ctx)
      bia = pessoa(ctx, "bia")
      declarar(ctx, bia, ctx.dev, ctx.parte)

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert uma.person_id == bia.id
      assert uma.direta? == false, "ela não tem vínculo na própria equipe"
      assert uma.squads == ["DADOS"]
    end

    test "só na equipe: nenhum chip de subequipe", ctx do
      compor(ctx)
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert uma.direta? == true
      assert uma.squads == []
    end

    test "dois papéis na MESMA equipe também dão uma linha — e dois vínculos", ctx do
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, ana, ctx.sm, ctx.equipe)

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert length(uma.vinculos) == 2
      assert Enum.all?(uma.vinculos, & &1.direta?)
      assert uma.squads == []
    end
  end

  describe "os três números do cabeçalho batem com a listagem (FR-012)" do
    test "vigentes, saíram e equívocos somam o total de pessoas do roster", ctx do
      compor(ctx)

      # Uma vigente na equipe, uma vigente na parte, uma que saiu, uma por engano.
      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      cida = pessoa(ctx, "cida")
      dora = pessoa(ctx, "dora")

      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, bia, ctx.dev, ctx.parte)

      declarar(ctx, cida, ctx.dev, ctx.equipe)

      {:ok, 1} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, cida.id, @dia_30, ctx.autor.id)

      declarar(ctx, dora, ctx.dev, ctx.equipe)

      {:ok, 1} =
        EO.record_team_membership_mistake(
          ctx.tenant,
          ctx.equipe.id,
          dora.id,
          "login errado",
          ctx.autor.id
        )

      totais = EO.team_roster_totals(ctx.tenant, ctx.equipe.id)
      quantas = EO.count_team_roster(ctx.tenant, ctx.equipe.id)
      linhas = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      assert totais == %{vigentes: 2, sairam: 1, equivocos: 1}

      assert totais.vigentes + totais.sairam + totais.equivocos == quantas, """
      Os três números do cabeçalho têm de somar o total do roster. É a afirmação mais
      desconfortável da tela — o argumento de que cabeçalho e lista não se contradizem é que
      "saem da mesma agregação", e ninguém o verificava.

      totais=#{inspect(totais)} · count=#{quantas} · linhas=#{length(linhas)}
      """

      assert length(linhas) == quantas, "a listagem e a contagem discordaram"

      # E a situação de cada linha bate com o número que a soma.
      por_situacao = Enum.frequencies_by(linhas, & &1.situacao)
      assert por_situacao[:vigente] == totais.vigentes
      assert por_situacao[:saiu] == totais.sairam
      assert por_situacao[:equivoco] == totais.equivocos
    end

    test "a pessoa com um vínculo invalidado E um vigente conta como VIGENTE", ctx do
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)
      declarar(ctx, ana, ctx.sm, ctx.equipe)

      # Invalida um só, direto — o comando alcançaria os dois.
      um = Repo.all(TeamMembership) |> hd()
      agora = DateTime.utc_now(:second)

      {1, _} =
        Repo.update_all(
          Ecto.Query.from(m in TeamMembership, where: m.id == ^um.id),
          set: [
            invalidated_at: agora,
            invalidated_by_user_id: ctx.autor.id,
            invalidation_reason: "engano num dos papéis",
            updated_at: agora
          ]
        )

      assert EO.team_roster_totals(ctx.tenant, ctx.equipe.id) == %{
               vigentes: 1,
               sairam: 0,
               equivocos: 0
             }

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      assert uma.situacao == :vigente, """
      `:equivoco` exige que TODOS os vínculos da pessoa tenham sido invalidados — é a mesma
      regra de `membership_disagreements/2`, e existe para os dois números da tela não se
      contradizerem. Com um vigente, a pessoa está na equipe.
      """
    end

    test "equipe sem ninguém: três zeros, e a listagem vazia", ctx do
      assert EO.team_roster_totals(ctx.tenant, ctx.equipe.id) == %{
               vigentes: 0,
               sairam: 0,
               equivocos: 0
             }

      assert EO.list_team_roster(ctx.tenant, ctx.equipe.id) == []
      assert EO.count_team_roster(ctx.tenant, ctx.equipe.id) == 0
    end
  end

  describe "composição ENCERRADA sai do alcance" do
    test "os membros da parte deixam o roster da mãe quando a composição termina", ctx do
      compor(ctx)
      bia = pessoa(ctx, "bia")
      declarar(ctx, bia, ctx.dev, ctx.parte)

      assert [_uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      {:ok, _} = EO.decompose_teams(ctx.tenant, ctx.parte.id, ctx.equipe.id, ctx.autor.id)

      assert EO.list_team_roster(ctx.tenant, ctx.equipe.id) == [], """
      A parte saiu do todo. Continuar listando os membros dela afirmaria uma estrutura que não
      existe mais — e o vínculo da Bia com a PARTE continua vigente, o que é outra coisa.
      """

      assert EO.count_team_roster(ctx.tenant, ctx.equipe.id) == 0

      # E o vínculo dela com a parte continua de pé, lido pela tela da parte.
      assert [_ainda] = EO.list_team_roster(ctx.tenant, ctx.parte.id)
    end
  end

  describe "as três formas de fim são distinguidas (FR-022)" do
    test "fim DECLARADO traz autor e o instante do registro", ctx do
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)

      {:ok, 1} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, ana.id, @dia_30, ctx.autor.id)

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = uma.vinculos

      assert {:declarado, autor, registrado, quando} = v.fim
      assert autor == ctx.autor.email
      assert quando == @dia_30
      refute is_nil(registrado)
    end

    test "fim constatado pela COLETA vem sem autor, e a tela precisa dizer isso", ctx do
      ana = pessoa(ctx, "ana")
      observar(ctx, ana, ctx.equipe, @dia_1)

      # A origem deixa de mostrar a pessoa: a coleta encerra o vínculo OBSERVADO, sem autor.
      {:ok, 1} =
        EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, DateTime.utc_now(:second))

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = uma.vinculos

      assert {:coleta, quando} = v.fim, """
      Fim sem autor num vínculo OBSERVADO é a coleta constatando ausência, e a data é **quando
      a plataforma parou de ver** — não quando a pessoa saiu. A tela tem de dizer isso com
      palavras, porque a data sozinha se passa por data de saída.
      """

      refute is_nil(quando)
      assert v.origem == :observado
      assert uma.situacao == :saiu
    end

    test "fim de vínculo DECLARADO sem autor lê 'sem autor' — registro antigo", ctx do
      ana = pessoa(ctx, "ana")
      vinculo = declarar(ctx, ana, ctx.dev, ctx.equipe)

      # Grava só `ended_at`, como fazia `record_team_departure/5` antes da migração de
      # 2026-09-08. Por `update_all`: o changeset hoje exigiria o par.
      {1, _} =
        Repo.update_all(
          Ecto.Query.from(m in TeamMembership, where: m.id == ^vinculo.id),
          set: [ended_at: @dia_30, updated_at: DateTime.utc_now(:second)]
        )

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = uma.vinculos

      assert {:sem_autor, @dia_30} = v.fim, """
      O vínculo tem papel e autor de declaração, então não é observado — mas o fim não tem
      autor. É registro anterior à migração, e a tela diz "author not recorded" em vez de
      atribuir a alguém: inventar seria pior que a lacuna.
      """
    end

    test "o equívoco traz razão, autor e instante", ctx do
      ana = pessoa(ctx, "ana")
      declarar(ctx, ana, ctx.dev, ctx.equipe)

      {:ok, 1} =
        EO.record_team_membership_mistake(
          ctx.tenant,
          ctx.equipe.id,
          ana.id,
          "homônima",
          ctx.autor.id
        )

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = uma.vinculos

      assert v.equivoco.razao == "homônima"
      assert v.equivoco.por == ctx.autor.email
      refute is_nil(v.equivoco.em)
      assert uma.situacao == :equivoco
    end
  end

  describe "a busca e a origem" do
    test "acha por login e por nome", ctx do
      ana = pessoa(ctx, "ana")
      _bia = pessoa(ctx, "bia")
      declarar(ctx, ana, ctx.dev, ctx.equipe)

      assert [_] = EO.list_team_roster(ctx.tenant, ctx.equipe.id, search: "ana")
      assert [_] = EO.list_team_roster(ctx.tenant, ctx.equipe.id, search: "Ana")
      assert [] = EO.list_team_roster(ctx.tenant, ctx.equipe.id, search: "zeca")

      # E a contagem usa o MESMO filtro — cabeçalho dizendo 64 sobre uma lista de 10 é o
      # defeito que a paginação sempre produz quando os dois lados divergem.
      assert EO.count_team_roster(ctx.tenant, ctx.equipe.id, search: "ana") == 1
      assert EO.count_team_roster(ctx.tenant, ctx.equipe.id, search: "zeca") == 0
    end

    test "a origem sai do AUTOR da declaração, e não do papel", ctx do
      ana = pessoa(ctx, "ana")
      observar(ctx, ana, ctx.equipe, @dia_1)

      assert [observada] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = observada.vinculos
      assert v.origem == :observado
      assert is_nil(v.role), "vínculo observado tem papel declaradamente ausente"
      assert is_nil(v.started_at), "a origem não diz desde quando"

      # Declarar o papel completa o MESMO vínculo, e a origem vira declarada.
      declarar(ctx, ana, ctx.dev, ctx.equipe)

      assert [declarada] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)
      assert [v] = declarada.vinculos
      assert v.membership_id == observada.vinculos |> hd() |> Map.get(:membership_id)
      assert v.origem == :declarado
      assert v.declared_by == ctx.autor.email
    end

    test "nível de acesso da plataforma NÃO sai do roster (FR-008, SC-004)", ctx do
      ana = pessoa(ctx, "ana")
      observar(ctx, ana, ctx.equipe, @dia_1)

      assert [uma] = EO.list_team_roster(ctx.tenant, ctx.equipe.id)

      # A evidência guarda `MAINTAINER`/`MEMBER`; o roster não o seleciona. Inspecionar a
      # linha inteira é o que prova — uma asserção sobre a página provaria só a página.
      texto = inspect(uma, limit: :infinity)

      refute texto =~ "MEMBER", """
      `platform_access_level` é permissão de administração na ferramenta, não papel na
      organização. Se ele aparece na linha, alguém o trouxe por outro caminho — e a coluna
      volta à tela no próximo template que iterar sobre a linha.
      """

      refute texto =~ "MAINTAINER"
      refute texto =~ "platform_access_level"
    end
  end
end
