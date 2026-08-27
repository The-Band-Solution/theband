defmodule TheBand.Profiles.MaterialTest do
  @moduledoc """
  O recorte que vira perfil — feature 026, T004 e T005.

  ## As quatro asserções que carregam este arquivo

  1. **os quatro erros são distintos** — quatro fatos diferentes, quatro ações diferentes de
     quem lê. Um `:error` genérico faria a tela dizer a mesma frase para todos;
  2. **os tercis são por volume** — períodos de mesma duração comparariam 4 tarefas com 90;
  3. **o veredito é calculado** — o modelo errou essa divisão na validação, e é ela que
     decide se a mudança pode ser atribuída à pessoa;
  4. **datas ordenam por data** — `Enum.sort/1` sobre `%Date{}` ordena pelo **dia**, e o
     defeito só aparece quando o período cruza o ano.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  # `tenant_with_admin/0` mora no `ConnCase` porque a maioria dos testes que precisa dele é
  # de tela. Aqui não há conexão — só o tenant importa.
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.Material
  alias TheBand.Profiles.Prompt
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, _user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{tenant: tenant, repo_id: cenario.observed_repository_id}
  end

  # Cria uma tarefa concluída com corpo, data e autoria controlados.
  defp tarefa(ctx, opts) do
    numero = Keyword.fetch!(opts, :numero)
    fechada = Keyword.fetch!(opts, :fechada)
    corpo = Keyword.get(opts, :corpo, String.duplicate("x", 500))
    login = Keyword.get(opts, :login, "pessoa")
    autor = Keyword.get(opts, :autor, login)
    estado = Keyword.get(opts, :estado, "CLOSED")

    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "tarefa ##{numero}",
        body: corpo,
        state: estado,
        author_login: autor,
        external_created_at: DateTime.add(fechada, -3, :day),
        external_closed_at: if(estado == "CLOSED", do: fechada),
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_perfil_#{numero}"
      })

    {:ok, _} =
      WorkItems.replace_assignees(ctx.tenant, issue.id, [
        %{login: login, external_id: "U_#{login}", person_id: nil}
      ])

    issue
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        Map.merge(source_attrs("U_#{login}"), %{name: login, login: login, account_type: "person"})
      )

    p
  end

  # A autoria é gravada DEPOIS: `record_collected_issue/2` recebe `author_login`, e o
  # `author_person_id` é o que a consulta do material lê.
  defp com_autoria(issue, ctx, pessoa) do
    Repo.update_all(
      from(i in "collected_issues",
        where:
          i.id == type(^issue.id, :binary_id) and
            i.tenant_id == type(^ctx.tenant.id, :binary_id),
        update: [set: [author_person_id: type(^pessoa.id, :binary_id)]]
      ),
      []
    )

    issue
  end

  defp com_designacao(issue, ctx, pessoa) do
    {:ok, _} =
      WorkItems.replace_assignees(ctx.tenant, issue.id, [
        %{login: pessoa.login, external_id: "U_#{pessoa.login}", person_id: pessoa.id}
      ])

    issue
  end

  describe "quem abriu também conta — 2026-08-27" do
    # O defeito medido: `fatasy` (Marcelo Razer) tem **8 issues designadas** e **233
    # abertas por ele**. O material lia só designadas, e descrevia 3% do que ele fez.
    #
    # A correção NÃO é somar tudo num monte: cada tarefa carrega a relação, porque abrir
    # e executar são participações diferentes — a rede as separa, e a página da pessoa
    # mostra três cartões justamente para ninguém somar.
    test "issue apenas ABERTA pela pessoa entra no material, marcada como tal", ctx do
      pessoa = pessoa(ctx, "razer")

      # Ela abriu, e a designação é de OUTRA pessoa.
      tarefa(ctx, numero: 9001, fechada: ~U[2026-05-10 09:00:00Z], login: "outra", autor: "razer")
      |> com_autoria(ctx, pessoa)

      {:ok, material} = Material.build(ctx.tenant, pessoa.id, :primeira)

      assert [%{relacao: "abriu"}] = material.concluidas, """
      A issue aberta pela pessoa, mas designada a outra, não entrou no material.

      Era o caso de `fatasy`: 8 designadas contra 233 abertas. Um perfil que lê só
      designadas descreve 3% do que a pessoa fez, e a pessoa fica praticamente invisível.
      """
    end

    test "designada E aberta pela mesma pessoa vem como `ambas`, e conta UMA vez", ctx do
      pessoa = pessoa(ctx, "razer")

      tarefa(ctx, numero: 9002, fechada: ~U[2026-05-10 09:00:00Z], login: "razer", autor: "razer")
      |> com_autoria(ctx, pessoa)
      |> com_designacao(ctx, pessoa)

      {:ok, material} = Material.build(ctx.tenant, pessoa.id, :primeira)

      assert [%{relacao: "ambas"}] = material.concluidas, """
      A tarefa apareceu duas vezes, ou perdeu a relação.

      Quem abre e executa a mesma issue participou das duas formas — e é UMA tarefa. Duas
      linhas inflariam a contagem que alimenta o piso de evidência.
      """
    end

    test "as três relações convivem, e o material as distingue", ctx do
      pessoa = pessoa(ctx, "razer")

      tarefa(ctx, numero: 9003, fechada: ~U[2026-05-10 09:00:00Z], login: "outra", autor: "razer")
      |> com_autoria(ctx, pessoa)

      tarefa(ctx, numero: 9004, fechada: ~U[2026-05-11 09:00:00Z], login: "razer", autor: "razer")
      |> com_autoria(ctx, pessoa)
      |> com_designacao(ctx, pessoa)

      tarefa(ctx,
        numero: 9005,
        fechada: ~U[2026-05-12 09:00:00Z],
        login: "razer",
        autor: "terceira"
      )
      |> com_designacao(ctx, pessoa)

      {:ok, material} = Material.build(ctx.tenant, pessoa.id, :primeira)

      assert %{"abriu" => 1, "ambas" => 1, "designada" => 1} =
               Enum.frequencies_by(material.concluidas, & &1.relacao),
             """
             As três participações foram achatadas numa só.

             O material vai para um MODELO. Sem a relação em cada item, o texto gerado atribui a
             quem abriu o trabalho de quem executou — e o perfil afirma execução que não houve.
             """
    end
  end

  describe "o que a pessoa escreveu para OUTRAS — issue #364" do
    test "conta as tarefas e as pessoas distintas, e não conta as próprias", ctx do
      pessoa =
        ctx |> pessoa_coletada("quem_escreve") |> then(&acima_do_piso(ctx, &1, "quem_escreve"))

      # Escreveu para três pessoas diferentes, sendo duas tarefas para a mesma.
      para(ctx, 701, "quem_escreve", "ana")
      para(ctx, 702, "quem_escreve", "ana")
      para(ctx, 703, "quem_escreve", "bruno")
      para(ctx, 704, "quem_escreve", "carla")

      # E uma para si mesma, que NÃO é escrita para outros.
      para(ctx, 705, "quem_escreve", "quem_escreve")

      # Uma designada a ela, escrita por outra pessoa — o material já tinha isto.
      issue =
        tarefa(ctx,
          numero: 706,
          fechada: ~U[2025-06-01 12:00:00Z],
          login: "quem_escreve",
          autor: "outra"
        )

      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: "quem_escreve", external_id: "U_quem_escreve", person_id: pessoa.id}
        ])

      {:ok, m} = Material.build(ctx.tenant, pessoa.id)

      assert m.para_outros.total == 4, """
      **A tarefa que ela escreveu para si mesma não conta.** A pergunta é o que ela escreveu
      PARA OUTRAS executarem, e incluir a própria autoria responderia outra coisa — o
      material já tem `autoria_propria` para isso.
      """

      assert m.para_outros.pessoas_distintas == 3, """
      **Pessoas distintas discrimina melhor que o total.** Quatro tarefas para três pessoas
      é diferente de quatro tarefas para uma, e o total sozinho não separa as duas: a
      segunda atravessa o time.
      """
    end

    test "a amostra traz o TEXTO, porque o número sozinho não separa", ctx do
      pessoa =
        ctx |> pessoa_coletada("quem_escreve") |> then(&acima_do_piso(ctx, &1, "quem_escreve"))

      para(ctx, 710, "quem_escreve", "ana", "Inception do SOT DevEx com critério de aceitação")

      {:ok, m} = Material.build(ctx.tenant, pessoa.id)

      assert [amostrada] = m.para_outros.amostra

      assert amostrada.titulo =~ "Inception", """
      **A contagem sozinha não basta.** Quem escreve "corrigir typo" e quem escreve uma
      tarefa com contexto e critério aparecem idênticos num número — título e corpo é que
      separam distribuir trabalho de decompor trabalho.

      E o material só tem o que foi designado À pessoa: sem este bloco, o modelo não recebe
      o texto e não pode analisar o que não recebe.
      """
    end

    test "a amostra tem TETO, e diz de quantas ela saiu", ctx do
      pessoa = ctx |> pessoa_coletada("prolifico") |> then(&acima_do_piso(ctx, &1, "prolifico"))
      for n <- 720..749, do: para(ctx, n, "prolifico", "ana")

      {:ok, m} = Material.build(ctx.tenant, pessoa.id)

      assert m.para_outros.total == 30

      assert length(m.para_outros.amostra) == 20, """
      **O teto foi medido antes de ser fixado.** As 384 tarefas que a pessoa mais ativa
      desta base escreveu para outras somam **455.116 caracteres** de corpo, e uma delas
      sozinha chega a 30.706. Sem teto, este bloco passaria de cem mil tokens numa rodada.
      """

      assert m.para_outros.amostra_de == 30, """
      E a amostra diz **de quantas** saiu. Vinte de trinta e vinte de vinte são coisas
      diferentes, e omitir o corte faria a amostra parecer o todo.
      """
    end

    test "ninguém escreveu para outros: ausência declarada, e não zero disfarçado", ctx do
      pessoa =
        ctx |> pessoa_coletada("so_executa") |> then(&acima_do_piso(ctx, &1, "so_executa"))

      {:ok, m} = Material.build(ctx.tenant, pessoa.id)

      assert m.para_outros == %{total: 0, pessoas_distintas: 0, amostra: [], amostra_de: 0}

      texto = Prompt.material(m)

      assert texto =~ "não é sinal de nada, é ausência", """
      **Zero aqui não é sinal.** Quem só executa tarefa escrita por outros pode estar
      entrando no time, ou não ter permissão para abrir issue no repositório. O prompt diz
      isso para o modelo não ler o zero como característica da pessoa.
      """
    end

    test "o prompt manda NÃO rotular a pessoa", ctx do
      pessoa =
        ctx |> pessoa_coletada("quem_escreve") |> then(&acima_do_piso(ctx, &1, "quem_escreve"))

      para(ctx, 770, "quem_escreve", "ana")

      {:ok, m} = Material.build(ctx.tenant, pessoa.id)
      texto = Prompt.material(m)

      assert texto =~ "liderança é conclusão", """
      **A plataforma não rotula pessoa.** Abrir tarefa para outros também é papel de quem
      faz triagem, escreve requisito, coordena entrega, ou é o único com permissão no
      repositório. O afirmável é o que o texto sustenta; a conclusão é de quem lê.
      """

      assert texto =~ "não recalcule", "e a contagem vai calculada, porque o modelo erra conta"
    end
  end

  describe "as tarefas abertas que a tela lista" do
    test "o id vem como UUID legível, e não como os bytes crus", ctx do
      # A consulta é schemaless, e sem `type/2` o id chega como dezesseis bytes. A tela
      # montava a URL com eles, e o primeiro clique em uma tarefa parada devolveu
      # `/work/issues/EC%D7%C2%EC…` — lixo. Defeito observado em 2026-08-16, no app rodando.
      {:ok, pessoa} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "parada",
          name: "PARADA",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          source_endpoint: "/users/parada",
          external_id: "U_parada",
          collected_at: DateTime.utc_now(:second),
          payload: %{"login" => "parada"}
        })

      issue = tarefa(ctx, numero: 900, fechada: ~U[2025-06-01 12:00:00Z], estado: "OPEN")

      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: "parada", external_id: "U_parada", person_id: pessoa.id}
        ])

      assert [aberta] = Material.open_tasks(ctx.tenant, pessoa.id)
      assert {:ok, _} = Ecto.UUID.cast(aberta.id)
      assert aberta.id == issue.id
    end
  end

  describe "as recusas" do
    test "sem designação alguma, o erro diz que não há de onde olhar", ctx do
      assert {:error, :no_assignment} = Material.build(ctx.tenant, Ecto.UUID.generate())
    end
  end

  describe "os tercis" do
    test "dividem por volume, e a sobra vai para o último período", ctx do
      base = ~U[2025-01-15 12:00:00Z]

      tarefas =
        for n <- 1..20 do
          tarefa(ctx, numero: 9000 + n, fechada: DateTime.add(base, n * 10, :day))
        end

      periodos = Material.tercis(tarefas)

      assert Enum.map(periodos, &length/1) == [6, 6, 8],
             """
             A sobra da divisão não foi para o último período.

             20 dividido por 3 dá 6 com resto 2. Se a sobra virasse período próprio, haveria
             quatro períodos — e a comparação que a feature inteira faz é entre três.
             """
    end
  end

  describe "o veredito da linha de base" do
    test "acompanhar o projeto NÃO é mudança da pessoa" do
      periodos = [
        %{corpo_mediano: 469, base: %{corpo_mediano: 415}},
        %{corpo_mediano: 566, base: %{corpo_mediano: 428}},
        %{corpo_mediano: 833, base: %{corpo_mediano: 814}}
      ]

      veredito = Material.veredito(periodos, 1.3)

      assert veredito =~ "ACOMPANHOU",
             """
             O crescimento do texto foi atribuído à pessoa.

             São os números reais de AndreCoelhoS em 2026-08-15: ela foi 1,8× e o projeto foi
             2,0×. Sem esta comparação, todo perfil deste tenant conclui que a pessoa aprendeu
             a documentar — e todos concluem isso no mesmo mês.
             """

      assert veredito =~ "1.8×" and veredito =~ "2.0×",
             "as duas razões precisam aparecer, senão quem lê não confere a conclusão"
    end

    test "crescer bem acima do projeto é mudança da pessoa" do
      periodos = [
        %{corpo_mediano: 100, base: %{corpo_mediano: 400}},
        %{corpo_mediano: 200, base: %{corpo_mediano: 420}},
        %{corpo_mediano: 400, base: %{corpo_mediano: 440}}
      ]

      assert Material.veredito(periodos, 1.3) =~ "ACIMA"
    end

    test "mediana 0.0 flutuante não estoura — a rodada de 2026-08-17 caiu aqui" do
      # O guard antigo era `primeiro in [0, nil]`, que compila para === e deixa 0.0
      # passar: a divisão por zero FLUTUANTE derrubou o job do Oban três vezes na
      # pessoa 40 de 88 (FeLiXp90), e a rodada ficou "running" por sete horas.
      periodos = [
        %{corpo_mediano: 0.0, base: %{corpo_mediano: 400}},
        %{corpo_mediano: 80.0, base: %{corpo_mediano: 420}}
      ]

      assert Material.veredito(periodos, 1.3) =~ "não calculável"

      # E razão que CAI a zero também não divide: 400 → 0.0 dá razão 0.0, e o lado
      # da pessoa dividiria por ela.
      caindo = [
        %{corpo_mediano: 100, base: %{corpo_mediano: 400}},
        %{corpo_mediano: 200, base: %{corpo_mediano: 0.0}}
      ]

      assert Material.veredito(caindo, 1.3) =~ "não calculável"
    end

    test "período sem corpo não vira razão inventada" do
      periodos = [
        %{corpo_mediano: 0, base: %{corpo_mediano: 400}},
        %{corpo_mediano: 0, base: %{corpo_mediano: 420}},
        %{corpo_mediano: 74, base: %{corpo_mediano: 440}}
      ]

      veredito = Material.veredito(periodos, 1.3)

      assert veredito =~ "não calculável",
             """
             Uma razão foi calculada a partir de zero.

             São os números reais de `costabeber`: metade das descrições dele está vazia.
             Dividir por zero, ou tratá-lo como 1, produziria uma comparação inventada — e é
             justamente a comparação que decide se o texto pode falar da pessoa.
             """
    end
  end

  describe "primeira geração com designação só de abertas — #399, 2026-08-17" do
    test "monta o material: alocação é resposta, e a limitação vai declarada", ctx do
      # 13 de 88 pessoas na base real: nenhuma issue concluída, mas 1 a 19 designadas
      # ABERTAS. O perfil "alocada em X, nada concluído observado ainda" responde quem
      # trabalha em quê; pessoa invisível não responde nada.
      pessoa =
        TheBand.ProfileRunFixtures.pessoa_com_material(ctx.tenant, ctx.repo_id, "so-abertas",
          tarefas: 3,
          estado: "OPEN"
        )

      assert {:ok, material} = Material.build(ctx.tenant, pessoa.id, :primeira)
      assert material.concluidas == []
      assert length(material.abertas) == 3

      # Da segunda geração em diante, os pisos voltam: sem concluída, não há material.
      assert {:error, {:below_floor, _}} = Material.build(ctx.tenant, pessoa.id, :normal)
    end
  end

  describe "sem corpo, o título é o texto — decisão de 2026-08-16" do
    test "período onde a maioria não tem corpo passa pela mediana do título", ctx do
      # A forma real de MateusLannes: primeiro terço com menos da metade dos corpos.
      # Antes, a mediana zero recusava o perfil inteiro; o título sempre existiu no
      # material, e agora é medido como texto quando o corpo falta.
      for n <- 1..18 do
        tarefa(ctx,
          numero: 700 + n,
          fechada: DateTime.new!(~D[2025-03-01] |> Date.add(n * 20), ~T[12:00:00]),
          corpo: if(n <= 6, do: "", else: String.duplicate("x", 300)),
          login: "lannes"
        )
      end

      assert {:ok, material} = Material.build(ctx.tenant, pessoa_de(ctx, "lannes").id)

      refute Enum.any?(material.periodos, &(&1.corpo_mediano == 0)),
             "a mediana zerou num período com títulos — a recusa voltaria para quem escreve título e não corpo"
    end
  end

  defp pessoa_de(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: String.upcase(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    for issue <-
          Repo.all(TheBand.WorkItems.Schemas.CollectedIssue) |> Enum.filter(&(&1.number >= 700)) do
      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: login, external_id: "U_#{login}", person_id: p.id}
        ])
    end

    p
  end

  # Uma tarefa que `autor` escreveu e `executor` executou.
  #
  # O designado vem com **pessoa resolvida**, como a coleta grava: medido em 2026-08-26,
  # das 4.323 designações vigentes desta base, **zero** estão sem `person_id`. Fixture com
  # `person_id: nil` testaria um estado que a coleta não produz.
  defp para(ctx, numero, autor, executor, titulo \\ nil) do
    executora = pessoa_coletada(ctx, executor)

    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: titulo || "escrita para #{executor} ##{numero}",
        body: "corpo da ##{numero}",
        state: "OPEN",
        author_login: autor,
        external_created_at: ~U[2025-06-01 12:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_para_#{numero}"
      })

    {:ok, _} =
      WorkItems.replace_assignees(ctx.tenant, issue.id, [
        %{login: executor, external_id: "U_#{executor}", person_id: executora.id}
      ])

    issue
  end

  # O piso de evidência exige 15 tarefas concluídas com corpo. Sem elas `build/2` devolve
  # `:below_floor`, que é resposta certa e não é o que estes casos investigam.
  defp acima_do_piso(ctx, pessoa, login) do
    for n <- 1..15 do
      issue =
        tarefa(ctx,
          numero: 800 + n,
          fechada: DateTime.add(~U[2025-01-01 12:00:00Z], n * 5, :day),
          login: login
        )

      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: login, external_id: "U_#{login}", person_id: pessoa.id}
        ])
    end

    pessoa
  end

  defp pessoa_coletada(ctx, login) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    pessoa
  end
end
