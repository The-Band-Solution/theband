defmodule TheBandWeb.EquipeCompostaTest do
  @moduledoc """
  Feature 057, US2 — a equipe composta mostra suas equipes, uma a uma.

  As asserções que carregam este arquivo:

  1. **FR-007**: uma linha por subequipe, mais a dos membros diretos;
  2. **FR-008/SC-003**: **nenhuma célula de total** — e a varredura procura pelas
     palavras que um total teria;
  3. **FR-009**: a tela **diz por que** não soma, nomeando pessoa e tarefa;
  4. **FR-010**: cada linha leva à tela daquela subequipe;
  5. **FR-011**: **nenhum gráfico** aqui;
  6. **FR-012**: subequipe sem trabalho aparece **nomeada**, nunca com zero;
  7. **SC-005**: a ordem é por trabalho parado, e não alfabética;
  8. **FR-013**: composição encerrada não aparece;
  9. **SC-012**: ver não exige administrar.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.DataCase, only: [user_fixture: 2]
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, mae} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      mae: mae,
      papel: papel,
      repo_id: cenario.observed_repository_id
    }
  end

  defp subequipe(ctx, nome) do
    {:ok, filha} = EO.declare_structural_team(ctx.tenant, ctx.org.id, nome, ctx.admin.id)
    {:ok, _} = EO.compose_teams(ctx.tenant, filha.id, ctx.mae.id, ctx.admin.id)
    filha
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

  defp vincular(ctx, equipe, pessoa) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        declared_by_user_id: ctx.admin.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -300, :day)
      })
  end

  defp issue(ctx, externo, designados, dias_atras) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(DateTime.utc_now(:second), -dias_atras, :day),
        collected_at: DateTime.utc_now(:second)
      })

    for d <- designados do
      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: d.login,
        person_id: d.id
      })
    end

    i
  end

  describe "a tela da equipe composta" do
    setup ctx do
      dados = subequipe(ctx, "Dados")
      interface = subequipe(ctx, "Interface")

      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      vincular(ctx, dados, ana)
      vincular(ctx, interface, bia)

      # Dados tem trabalho parado; Interface tem trabalho recente.
      issue(ctx, "velha", [ana], 120)
      issue(ctx, "outra-velha", [ana], 100)
      issue(ctx, "nova", [bia], 3)

      Map.merge(ctx, %{dados: dados, interface: interface, ana: ana, bia: bia})
    end

    test "FR-007/FR-010: uma linha por subequipe, mais a dos diretos, e cada uma leva à sua tela",
         ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Teams inside this one"
      assert html =~ "Dados"
      assert html =~ "Interface"
      assert html =~ "direct members"
      assert html =~ ~s|/teams/#{ctx.dados.id}|
      assert html =~ ~s|/teams/#{ctx.interface.id}|
    end

    test "FR-008/SC-003: nenhuma célula de total", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      cabecalhos =
        Regex.scan(~r|<th[^>]*>(.*?)</th>|s, html)
        |> Enum.map(&(&1 |> List.last() |> String.downcase()))

      for proibido <- ~w(total sum combined overall aggregate) do
        refute Enum.any?(cabecalhos, &String.contains?(&1, proibido)),
               "a tela tem um cabeçalho com #{proibido} — somar as linhas contaria a mesma pessoa e a mesma tarefa duas vezes"
      end
    end

    test "FR-009: a tela diz por que não soma, nomeando pessoa e tarefa", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "why these rows are not added up"
      assert html =~ "two sub-teams"
      assert html =~ "same task"
    end

    test "FR-041/FR-084: cada subequipe é um CARTÃO, com faísca, e o cartão é porta", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      # Um cartão por subequipe, mais o dos membros diretos.
      assert html =~ "One card per sub-team"
      assert html =~ "Click a card"

      # O CARTÃO É PORTA (FR-041), e a porta é a mesma do gráfico (FR-084): o cartão inteiro
      # é o link, e a faísca está dentro dele.
      #
      # A *Interface* tem trabalho de 3 dias, dentro da janela padrão de 8 semanas.
      assert has_element?(live, ~s|a[href="/teams/#{ctx.interface.id}"] svg|), """
      O cartão da subequipe tem de ser o link, com a faísca DENTRO dele — clicar no gráfico
      abre o painel daquela subequipe, e é a mesma porta do cartão (FR-084).
      """

      # A *Dados* tem trabalho de 100 e 120 dias — FORA da janela. O cartão dela é porta do
      # mesmo jeito, e no lugar da faísca diz a ausência: uma linha reta em zero afirmaria
      # "abriu zero e fechou zero", quando o que houve foi não ter o que observar nesta
      # janela. É a mesma regra da tabela, e aqui importa mais — o gráfico esconde a
      # distinção melhor que o número.
      assert has_element?(live, ~s|a[href="/teams/#{ctx.dados.id}"]|),
             "o cartão sem faísca continua porta"

      assert html =~ "Nothing opened or closed in this window", """
      A frase é sobre MOVIMENTO, e o cartão mostra estoque ao lado. Dizer "no work observed"
      num cartão com `open 2` parece contradição — e as duas coisas são verdadeiras: há dois
      itens abertos, e nenhum se moveu na janela.
      """
    end

    test "o cartão dos membros DIRETOS não é porta — já estamos nesta tela", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert has_element?(live, ~s|a[href="/teams/#{ctx.dados.id}"]|)

      # O recorte é a REGIÃO DOS CARTÕES: a aba Dashboard é, ela mesma, um link legítimo
      # para `/teams/:id` — e afirmar sobre a página inteira confundiria os dois.
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")
      [_antes, cartoes] = String.split(html, "One card per sub-team", parts: 2)
      [cartoes, _depois] = String.split(cartoes, "The same numbers, side by side", parts: 2)

      refute cartoes =~ ~s|href="/teams/#{ctx.mae.id}"|, """
      Um link para a tela em que a pessoa já está é um clique que não leva a lugar nenhum.
      """
    end

    test "os cartões e a tabela dizem os MESMOS números, e nenhum total", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      # Duas apresentações do mesmo dado: se divergirem, quem compara encontra dois números e
      # não sabe qual seguir.
      assert html =~ "The same numbers, side by side"

      cabecalhos =
        Regex.scan(~r|<th[^>]*>(.*?)</th>|s, html)
        |> Enum.map(&(&1 |> List.last() |> String.downcase()))

      for proibido <- ~w(total sum combined overall aggregate) do
        refute Enum.any?(cabecalhos, &String.contains?(&1, proibido)),
               "achei um cabeçalho com #{proibido} — FR-044 e SC-008 proíbem total"
      end

      # A RÉGUA, e não "as mesmas medidas" ao pé da letra (Design, 2026-09-09, §5): todo
      # número do cartão aparece na tabela com o mesmo valor e definição; o cartão não mostra
      # número que a tabela não tenha. Subconjunto é permitido, divergência é defeito.
      [_antes, grade] = String.split(html, "One card per sub-team", parts: 2)
      [grade, tabela] = String.split(grade, "The same numbers, side by side", parts: 2)

      rotulos_do_cartao =
        Regex.scan(~r|<dt[^>]*>(.*?)</dt>|s, grade)
        |> Enum.map(&(&1 |> List.last() |> String.trim()))
        |> Enum.uniq()

      assert rotulos_do_cartao == ["open items", "median wait"], """
      O cartão tem DOIS vãos, e são as medidas herdadas da tabela aprovada da 057 —
      `1st review` virou `median wait`. `members` subiu para o cabeçalho porque não é medida
      do trabalho, e `stopped` desceu para a tabela porque o número sem o limiar não é
      interpretável. `pipeline` não entra: não há vínculo projeto→subequipe, e a taxa seria
      "no project" em todos os cartões — a recusa já tem lugar próprio na tela.

      Achei: #{inspect(rotulos_do_cartao)}
      """

      for rotulo <- rotulos_do_cartao do
        assert tabela =~ rotulo, """
        `#{rotulo}` está no cartão e não na tabela. O cartão não pode mostrar número que a
        tabela não tenha — quem compara as duas apresentações precisa achar o mesmo.
        """
      end

      # `members` está no CABEÇALHO do cartão, não nos vãos — e continua na tabela.
      assert grade =~ "members"
      assert tabela =~ ">members<"

      # O LIMIAR viaja com o número (FR-069): "stopped" sozinho não é interpretável.
      assert tabela =~ "stopped · open &gt; 90 d"

      # E o âmbar saiu: estava ligado nas TRÊS subequipes, e condição sempre verdadeira é
      # mancha, não informação.
      [corpo, _] = String.split(tabela, "</table>", parts: 2)

      refute corpo =~ "text-warning", """
      O âmbar no número de paradas estava ligado em todas as linhas (214/183/151 no banco de
      desenvolvimento). Cor que não distingue nenhuma linha não informa nada, e gasta a matiz
      que nesta casa significa derivado/obsoleto.
      """
    end

    test "057 FR-011, EMENDADA: a TABELA continua sem gráfico, e o fluxo da equipe tem", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      # A 057 FR-011 proibia gráfico nesta tela, e a 060 FR-058 a emendou. O que ela protegia
      # continua valendo — e é o que este teste passou a medir: a **tabela** por subequipe é
      # para comparar, e comparação se faz em números alinhados.
      # O recorte é a TABELA, e não a seção: os cartões vivem na mesma seção e TÊM faísca
      # (FR-084). Cortar em "Teams inside this one" pegaria os dois.
      [_antes, tabela] = String.split(html, "The same numbers, side by side", parts: 2)
      [tabela, _depois] = String.split(tabela, "</table>", parts: 2)

      refute tabela =~ "<svg", """
      Gráfico DENTRO da tabela por subequipe contraria a decisão que a 057 tomou e a 060
      manteve: a tabela é para comparar, e comparação se faz em números alinhados. O gráfico
      pequeno por subequipe é a FR-084, e vive no CARTÃO — que existe, e está medido pelo
      teste "FR-041/FR-084" acima. Esta asserção é sobre a TABELA, e as duas convivem na
      mesma seção: uma para comparar em números alinhados, a outra para responder a forma.
      """

      # E o fluxo da equipe inteira agora existe, com a frase que a FR-060 exige.
      assert html =~ "<svg", "a equipe composta passou a ter o fluxo da equipe inteira (FR-058)"
      assert html =~ "not the sum"
      assert html =~ "whole team"
    end

    test "SC-005: a ordem é por trabalho parado, e não alfabética", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      pos_dados = :binary.match(html, "/teams/#{ctx.dados.id}") |> elem(0)
      pos_interface = :binary.match(html, "/teams/#{ctx.interface.id}") |> elem(0)

      assert pos_dados < pos_interface,
             "Dados tem 2 tarefas paradas e Interface nenhuma — sem a ordem declarada, achar a que precisa de conversa depende de sorte na ordem alfabética"
    end

    test "FR-012: subequipe sem trabalho aparece nomeada, nunca com zero", ctx do
      vazia = subequipe(ctx, "Integrações")
      carlos = pessoa(ctx, "carlos")
      vincular(ctx, vazia, carlos)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Integrações"
      assert html =~ "No work observed in the period"
      assert html =~ "not the same as zero"
    end

    test "SC-012: ver não exige administrar", ctx do
      leitor = user_fixture(ctx.tenant, "member")

      {:ok, _view, html} = live(log_in(build_conn(), leitor), ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Teams inside this one"
      assert html =~ "Dados"
    end
  end

  describe "quando a equipe não é composta" do
    test "com nenhuma parte, a seção não existe", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      refute html =~ "Teams inside this one"
    end

    # A lista de partes ("Contains:") é da aba ESTRUTURA desde a feature 060 — a seção
    # "Teams inside this one", que compara subequipes, continua no painel. Ler a estrutura
    # aqui é o que estes dois casos fazem, e por isso abrem a aba.
    test "com UMA parte só, segue como equipe simples", ctx do
      subequipe(ctx, "Dados")

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")

      refute html =~ "Teams inside this one",
             "comparar uma linha com nada não é comparação — uma parte só é composição declarada, não equipe composta"

      assert html =~ "Contains:"
    end

    test "FR-013: composição encerrada não faz a equipe ser composta", ctx do
      dados = subequipe(ctx, "Dados")
      interface = subequipe(ctx, "Interface")
      {:ok, _} = EO.decompose_teams(ctx.tenant, interface.id, ctx.mae.id, ctx.admin.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")

      refute html =~ "Teams inside this one"
      refute html =~ ~s|/teams/#{interface.id}|
      assert html =~ ~s|/teams/#{dados.id}|
    end
  end
end
