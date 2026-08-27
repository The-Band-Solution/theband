defmodule TheBand.ChangesTest do
  @moduledoc """
  A leitura das mudanças — feature 032.

  ## As asserções que carregam este arquivo

  1. **autoria é plural**: um commit com dois autores devolve dois, e a co-autoria é
     distinguível da autoria principal (`is_primary`);
  2. as três leituras da pessoa **nunca são somadas** — abrir, integrar e commitar são
     atos distintos, e a mesma pessoa pode fazer os três no mesmo PR;
  3. o vínculo com issue é o que a origem reconheceu, e sumir dele **marca**, nunca apaga;
  4. os commits de uma solicitação custam **duas** consultas, com um ou com vinte.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Changes
  alias TheBand.Changes.Commands
  alias TheBand.ContadorDeConsultas
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{
      tenant: tenant,
      admin: admin,
      repo_id: cenario.observed_repository_id,
      cenario: cenario
    }
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: String.upcase(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    p
  end

  defp solicitacao(ctx, numero, attrs \\ %{}) do
    {:ok, cr} =
      Commands.record_change_request(
        ctx.tenant,
        Map.merge(
          %{
            observed_repository_id: ctx.repo_id,
            number: numero,
            title: "mudança #{numero}",
            state: "MERGED",
            source_branch: "feature-#{numero}",
            target_branch: "main",
            external_created_at: ~U[2026-06-01 10:00:00Z],
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "PR_#{numero}"
          },
          attrs
        )
      )

    cr
  end

  defp commit(ctx, cr, sha, autores) do
    {:ok, c} =
      Commands.record_commit(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        change_request_id: cr && cr.id,
        sha: sha,
        message_headline: "commit #{sha}",
        external_committed_at: ~U[2026-06-01 11:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: sha
      })

    :ok = Commands.replace_commit_authors(ctx.tenant, c.id, autores)
    c
  end

  test "autoria é plural, e a co-autoria é distinguível da autoria principal", ctx do
    ana = pessoa(ctx.tenant, "ana")
    bia = pessoa(ctx.tenant, "bia")
    cr = solicitacao(ctx, 1)

    commit(ctx, cr, "sha-a", [
      %{author_login: "ana", author_person_id: ana.id, author_name: "ANA", is_primary: true},
      %{author_login: "bia", author_person_id: bia.id, author_name: "BIA", is_primary: false}
    ])

    assert [c] = Changes.commits_of(ctx.tenant, cr.id)

    assert length(c.autores) == 2, """
    O commit devolveu #{length(c.autores)} autor(es).

    Todo commit deste repositório tem dois — quem escreveu e o agente, pelo trailer
    Co-Authored-By. Coletar um só atribuiria a mudança a uma pessoa quando o registro
    nomeia duas.
    """

    principal = Enum.find(c.autores, & &1.is_primary)
    coautor = Enum.find(c.autores, &(not &1.is_primary))

    assert principal.login == "ana"
    assert coautor.login == "bia", "a co-autoria virou autoria principal, ou sumiu"
  end

  test "as três leituras da pessoa não se somam — a mesma pessoa pode fazer os três", ctx do
    ana = pessoa(ctx.tenant, "ana")

    # Abriu E integrou o próprio PR: acontece no dado real, e é achado de processo.
    cr = solicitacao(ctx, 2, %{author_person_id: ana.id, merged_by_person_id: ana.id})
    commit(ctx, cr, "sha-b", [%{author_login: "ana", author_person_id: ana.id, is_primary: true}])

    mudancas = Changes.by_person(ctx.tenant, ana.id)

    assert length(mudancas.abertas) == 1
    assert length(mudancas.integradas) == 1
    assert length(mudancas.commits) == 1

    assert hd(mudancas.abertas).number == hd(mudancas.integradas).number, """
    A mesma solicitação apareceu em listas diferentes.

    Abrir e integrar são atos distintos, e a mesma pessoa fazendo os dois é o que mostra
    que ninguém revisou. Somar as três leituras produziria "3 contribuições" onde houve
    uma mudança.
    """
  end

  test "o co-autor aparece nos commits dele mesmo sem ter aberto solicitação", ctx do
    ana = pessoa(ctx.tenant, "ana")
    agente = pessoa(ctx.tenant, "agente")
    cr = solicitacao(ctx, 3, %{author_person_id: ana.id})

    commit(ctx, cr, "sha-c", [
      %{author_login: "ana", author_person_id: ana.id, is_primary: true},
      %{author_login: "agente", author_person_id: agente.id, is_primary: false}
    ])

    mudancas = Changes.by_person(ctx.tenant, agente.id)

    assert mudancas.abertas == []
    assert mudancas.integradas == []

    assert [c] = mudancas.commits, """
    Quem só participa como co-autor ficou invisível.

    É o mesmo defeito dos 24 no_assignment: a pessoa trabalha, e a plataforma não mostra.
    """

    refute c.is_primary, "a co-autoria foi apresentada como autoria principal"
  end

  test "o vínculo com issue segue a origem, e sumir dele marca — nunca apaga", ctx do
    cr = solicitacao(ctx, 4)
    %{pai: issue} = ctx.cenario.issues[3]

    :ok = Commands.replace_attended_issues(ctx.tenant, cr.id, [issue.id])
    assert [i] = Changes.attended_issues(ctx.tenant, cr.id)
    assert i.id == issue.id

    # A closing keyword foi removida do PR: o vínculo sai da leitura...
    :ok = Commands.replace_attended_issues(ctx.tenant, cr.id, [])
    assert Changes.attended_issues(ctx.tenant, cr.id) == []

    # ...e continua no banco, marcado.
    assert Repo.aggregate(
             from(v in "change_request_issues",
               where: v.collected_change_request_id == type(^cr.id, :binary_id)
             ),
             :count
           ) == 1,
           "a marca virou DELETE — marca nunca apaga"
  end

  test "os commits de uma solicitação custam duas consultas, com um ou com vinte", ctx do
    ana = pessoa(ctx.tenant, "ana")
    cr = solicitacao(ctx, 5)

    for n <- 1..20 do
      commit(ctx, cr, "sha-#{n}", [
        %{author_login: "ana", author_person_id: ana.id, is_primary: true}
      ])
    end

    consultas =
      TheBand.ContadorDeConsultas.contar(fn -> Changes.commits_of(ctx.tenant, cr.id) end)

    assert consultas == 2, """
    Vinte commits custaram #{consultas} consultas.

    São duas, sempre: os commits, e os autores em lote. Uma consulta de autores por
    commit é o defeito das 135 por render da feature 007 numa roupa nova — e commits com
    dois autores são o caso comum aqui.
    """
  end

  describe "a busca lê a forma do que foi digitado" do
    test "sete hexadecimais são SHA; menos que isso, não", _ctx do
      assert {:sha, "17e4f16"} = Changes.interpretar_busca("17e4f16")
      assert {:sha, "17e4f16d21a3"} = Changes.interpretar_busca("17E4F16D21A3")

      # Seis caracteres viram palavra: a chance de colidir com número ou termo é alta
      # demais para a plataforma decidir sozinha.
      assert {:palavras, ["abc123"]} = Changes.interpretar_busca("abc123")
    end

    test "número, pessoa e palavras têm formas próprias", _ctx do
      assert {:numero, 427} = Changes.interpretar_busca("#427")
      assert {:numero, 427} = Changes.interpretar_busca("427")
      assert {:pessoa, "ana"} = Changes.interpretar_busca("@ana")
      assert {:palavras, ["rastreio", "commit"]} = Changes.interpretar_busca("rastreio commit")
      assert {:vazia, nil} = Changes.interpretar_busca("   ")
    end

    test "duas palavras ESTREITAM, nunca alargam", ctx do
      solicitacao(ctx, 20, %{title: "rastreio das mudanças declaradas"})
      solicitacao(ctx, 21, %{title: "rastreio de outra coisa"})

      assert Changes.count(ctx.tenant, search: "rastreio") == 2

      assert Changes.count(ctx.tenant, search: "rastreio declaradas") == 1, """
      Duas palavras devolveram mais resultados, ou os mesmos.

      Quem digita a segunda palavra está estreitando. `OU` devolveria MAIS a cada palavra
      digitada — o contrário do que quem busca espera.
      """
    end

    test "SHA na lista de solicitações acha a que CARREGA o commit", ctx do
      ana = pessoa(ctx.tenant, "ana")
      cr = solicitacao(ctx, 22)

      commit(ctx, cr, "abcdef1234567", [
        %{author_login: "ana", author_person_id: ana.id, is_primary: true}
      ])

      assert [encontrada] = Changes.list(ctx.tenant, search: "abcdef1")

      assert encontrada.number == 22, """
      A busca por SHA devolveu vazio na lista de solicitações.

      Vazio aqui diria que o commit não existe, quando ele só não é uma solicitação — e a
      pergunta de quem cola um SHA é "de onde veio isto?".
      """
    end

    test "a busca por pessoa nos commits inclui quem é CO-autor", ctx do
      ana = pessoa(ctx.tenant, "ana")
      agente = pessoa(ctx.tenant, "agente")
      cr = solicitacao(ctx, 23)

      commit(ctx, cr, "sha-co", [
        %{author_login: "ana", author_person_id: ana.id, is_primary: true},
        %{author_login: "agente", author_person_id: agente.id, is_primary: false}
      ])

      assert Changes.count_commits(ctx.tenant, search: "@agente") == 1, """
      Quem é co-autor não foi encontrado pela busca.

      É o mesmo defeito de somar autoria numa coluna: a participação existe, e a busca
      precisa alcançá-la.
      """

      assert Changes.count_commits(ctx.tenant, person_id: agente.id) == 1
    end
  end

  test "solicitação de outro tenant devolve not_found, nunca o registro", ctx do
    cr = solicitacao(ctx, 6)
    {outro_tenant, _} = tenant_with_admin()

    assert {:error, :not_found} = Changes.get(outro_tenant, cr.id)
    assert {:ok, _} = Changes.get(ctx.tenant, cr.id)
  end

  describe "o resumo das telas" do
    test "as quatro frases sobre escopo nunca são somadas", ctx do
      # Somá-las foi o defeito #438: um quadro só, com 4.177, que juntava fato sobre o
      # processo (a origem não reconheceu issue) com lacuna nossa (a issue não foi
      # coletada). Medido depois de separar: 4.168 e 9 — o primeiro era quase todo o
      # número, e a amostra de três que eu tirei não media nada.
      pr_com = pr_de_teste(ctx, 9001)
      %{pai: issue} = ctx.cenario.issues |> Map.values() |> List.first()

      :ok = Commands.replace_attended_issues(ctx.tenant, pr_com.id, [issue.id])

      :ok =
        Commands.record_attended_provenance(ctx.tenant, pr_com.id, %{total: 1, pendentes: []})

      pr_sem = pr_de_teste(ctx, 9002)
      :ok = Commands.record_attended_provenance(ctx.tenant, pr_sem.id, %{total: 0, pendentes: []})

      pr_pendente = pr_de_teste(ctx, 9003)

      :ok =
        Commands.record_attended_provenance(ctx.tenant, pr_pendente.id, %{
          total: 1,
          pendentes: ["I_nao_coletada"]
        })

      # E uma que nunca foi medida: nulo é desconhecido, nunca zero.
      pr_de_teste(ctx, 9004)

      resumo = Changes.resumo(ctx.tenant)

      assert resumo[:com_escopo] == 1
      assert resumo[:sem_escopo] == 1
      assert resumo[:escopo_pendente] == 1
      assert resumo[:nao_sabemos] == 1
    end

    test "o pendente é resolvido quando a issue chega, sem tocar na origem", ctx do
      %{pai: issue} = ctx.cenario.issues |> Map.values() |> List.first()
      externo = external_id_da_issue(ctx.tenant, issue.id)
      pr = pr_de_teste(ctx, 9101)

      :ok =
        Commands.record_attended_provenance(ctx.tenant, pr.id, %{total: 1, pendentes: [externo]})

      assert Changes.resumo(ctx.tenant)[:escopo_pendente] == 1

      {:ok, r} = Commands.reconcile_attended_issues(ctx.tenant)

      assert r.resolved == 1
      assert r.still_pending == 0
      # O vínculo passou a existir, e o quadro mudou de coluna.
      assert [%{id: _}] = Changes.attended_issues(ctx.tenant, pr.id)
      assert Changes.resumo(ctx.tenant)[:com_escopo] == 1
    end

    test "a reconciliação não apaga vínculo que já existia", ctx do
      # `replace_attended_issues` marca o que não está na lista; a reconciliação conhece
      # só os pendentes que chegaram, e usá-la aqui destruiria o resto.
      [%{pai: i1}, %{pai: i2}] = ctx.cenario.issues |> Map.values() |> Enum.take(2)
      pr = pr_de_teste(ctx, 9102)

      :ok = Commands.replace_attended_issues(ctx.tenant, pr.id, [i1.id])

      :ok =
        Commands.record_attended_provenance(ctx.tenant, pr.id, %{
          total: 2,
          pendentes: [external_id_da_issue(ctx.tenant, i2.id)]
        })

      {:ok, _} = Commands.reconcile_attended_issues(ctx.tenant)

      assert length(Changes.attended_issues(ctx.tenant, pr.id)) == 2
    end

    test "o resumo de arquivos conta caminhos e cópias separados", ctx do
      resumo = Changes.resumo_de_arquivos(ctx.tenant)

      # Caminhos é "quantos arquivos a plataforma conhece"; cópias é quantas vezes foram
      # tocados. Confundi-los faria a tela dizer que há 87 mil arquivos onde há 17 mil.
      assert Map.has_key?(resumo, :caminhos)
      assert Map.has_key?(resumo, :copias)
      assert Map.has_key?(resumo, :commits)
    end

    test "cada resumo custa uma consulta, e não uma por linha", ctx do
      um = ContadorDeConsultas.contar(fn -> Changes.resumo_de_arquivos(ctx.tenant) end)
      assert um == 1
    end
  end

  defp pr_de_teste(ctx, numero) do
    {:ok, pr} =
      Commands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "MERGED",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    pr
  end

  defp external_id_da_issue(tenant, issue_id) do
    TheBand.Repo.one!(
      from i in "collected_issues",
        where:
          i.tenant_id == type(^tenant.id, :binary_id) and i.id == type(^issue_id, :binary_id),
        select: i.external_id
    )
  end

  describe "os três papéis na solicitação — feature 044" do
    test "conta abriu, revisou e integrou em UMA consulta", ctx do
      autora = pessoa_044(ctx, "autora")
      revisora = pessoa_044(ctx, "revisora")

      cr = solicitacao(ctx, 9001, %{author_person_id: autora.id, merged_by_person_id: autora.id})
      avaliar(ctx, cr, revisora, "APPROVED")

      consultas =
        ContadorDeConsultas.contar(fn ->
          Changes.participacao_da_pessoa(ctx.tenant, autora.id)
        end)

      assert consultas == 1, """
      A participação custou #{consultas} consultas, e tem de custar UMA.

      São seis contagens, e seis consultas levariam a página da pessoa de 23 para 29 por
      render — o teste-guarda de custo reprova em 24. `filter (where ...)` responde as seis
      numa passagem.
      """

      assert %{abriu: 1, integrou: 1, revisou: 0} =
               Changes.participacao_da_pessoa(ctx.tenant, autora.id)

      assert %{abriu: 0, integrou: 0, revisou: 1, endossou: 1} =
               Changes.participacao_da_pessoa(ctx.tenant, revisora.id)
    end

    test "quem revisou DUAS vezes a mesma solicitação revisou UMA", ctx do
      p = pessoa_044(ctx, "revisora")
      cr = solicitacao(ctx, 9002)

      avaliar(ctx, cr, p, "COMMENTED", "R_a")
      avaliar(ctx, cr, p, "APPROVED", "R_b")

      assert %{revisou: 1, endossou: 1, absteve: 1} =
               Changes.participacao_da_pessoa(ctx.tenant, p.id),
             """
             As unidades foram achatadas.

             `revisou` conta SOLICITAÇÕES distintas — quem revisou a mesma mudança duas vezes
             revisou uma mudança. Os vereditos contam AVALIAÇÕES, porque são posições tomadas.

             Medido em 2026-08-27: `vinicius-je` revisou 627 solicitações com 721 avaliações, e a
             tela é obrigada a explicar a diferença.
             """
    end

    test "revisão RETIRADA conta como revisão, e não como veredito", ctx do
      p = pessoa_044(ctx, "revisora")
      cr = solicitacao(ctx, 9003)

      avaliar(ctx, cr, p, "DISMISSED")

      assert %{revisou: 1, endossou: 0, objetou: 0, absteve: 0} =
               Changes.participacao_da_pessoa(ctx.tenant, p.id),
             """
             A revisão retirada sumiu de "revisou", ou entrou num veredito.

             Ela aconteceu — alguém leu a mudança e tomou posição —, e depois foi tirada de
             circulação. Apagá-la de "revisou" nega o trabalho; contá-la como veredito afirma uma
             posição que não vale mais.

             O erro foi cometido ao implementar, em 2026-08-27: filtrar `revisou` pelos estados de
             veredito devolvia 626 onde o certo é 627.
             """
    end

    test "revisão de ROBÔ não entra em contagem de pessoa", ctx do
      p = pessoa_044(ctx, "revisora")
      cr = solicitacao(ctx, 9004)

      # Bot: `author_person_id` nulo, que é o que a coleta grava.
      avaliar(ctx, cr, nil, "APPROVED", "R_bot", "Bot")

      assert %{revisou: 0, endossou: 0} = Changes.participacao_da_pessoa(ctx.tenant, p.id), """
      A revisão do robô entrou na contagem de uma pessoa.

      Bot não tem pessoa, e forçar uma inventaria participação. São 85 de 4.233 no banco de
      desenvolvimento.
      """
    end

    # DUAS revisões na mesma solicitação, e não uma: com uma só, a junção não produz
    # linha repetida e o `distinct` nunca é exercitado — em branco ele passa por qualquer
    # defeito.
    test "a solicitação revisada aparece UMA vez, mesmo com duas revisões", ctx do
      p = pessoa_044(ctx, "revisora")
      cr = solicitacao(ctx, 9005, %{title: "a que ela revisou"})
      avaliar(ctx, cr, p, "COMMENTED", "R_1")
      avaliar(ctx, cr, p, "APPROVED", "R_2")

      r = Changes.by_person(ctx.tenant, p.id)

      assert [%{title: "a que ela revisou"}] = r.revisadas, """
      A solicitação apareceu duas vezes na listagem.

      A junção com as avaliações produz uma linha por revisão. Sem `distinct`, quem revisou
      a mesma mudança duas vezes a veria repetida na tela — e a lista de 20 mostraria 10
      mudanças.
      """

      assert r.abertas == []
      assert r.integradas == []
    end

    test "outro tenant não alcança participação nenhuma daqui", ctx do
      p = pessoa_044(ctx, "autora")
      solicitacao(ctx, 9006, %{author_person_id: p.id})

      outro = TheBand.DataCase.tenant_fixture("outra-044")

      assert %{abriu: 0, integrou: 0, revisou: 0} =
               Changes.participacao_da_pessoa(outro, p.id),
             """
             A participação vazou entre tenants.

             Consulta sem filtro de tenant é bug de segurança, não de correção — princípio V.
             """
    end
  end

  defp pessoa_044(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        Map.merge(source_attrs("U_044_#{login}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
      )

    p
  end

  # Grava a avaliação direto, e não pela ingestão: o teste é da LEITURA, e passar pela
  # borda HTTP para produzir uma linha tornaria o teste sobre o conector.
  defp avaliar(ctx, cr, pessoa, estado, external_id \\ nil, tipo \\ "User") do
    {:ok, _} =
      TheBand.Quality.Commands.record_evaluation(ctx.tenant, %{
        collected_change_request_id: cr.id,
        state: estado,
        body: "corpo",
        external_submitted_at: ~U[2026-06-02 10:00:00Z],
        author_login: (pessoa && pessoa.login) || "robo",
        author_type: tipo,
        author_person_id: pessoa && pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: external_id || "R_#{cr.number}",
        raw_payload: %{}
      })
  end
end
