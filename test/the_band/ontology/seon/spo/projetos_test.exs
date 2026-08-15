defmodule TheBand.Ontology.SEON.SPO.ProjetosTest do
  @moduledoc """
  O projeto, a hierarquia e os repositórios dele — feature 025.

  ## As três asserções que carregam este arquivo

  1. **a fase é derivada, e muda sozinha** — o projeto vira complexo ao ganhar a
     primeira parte e volta a simples ao perder a última, sem ninguém alterar um campo;
  2. **o ciclo indireto é recusado, e a mensagem nomeia o caminho** — `A → B → C → A`
     tem exatamente um pai por projeto, e um pai só não impede ciclo;
  3. **as issues de subprojeto são distinguíveis das diretas** — somá-las sem avisar
     esconderia de onde o número veio.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Ontology.SEON.SPO.Schemas.ProjectRepository

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    user = user_fixture(tenant)
    cenario = cenario_real(tenant)
    %{tenant: tenant, user: user, cenario: cenario}
  end

  defp projeto(ctx, nome, attrs \\ %{}) do
    {:ok, p} = SPO.create_project(ctx.tenant, Map.merge(%{name: nome}, attrs), ctx.user.id)
    p
  end

  describe "cadastrar" do
    test "o projeto nasce simples, porque não tem partes", ctx do
      p = projeto(ctx, "Conecta Fapes")

      assert p.declared_by_user_id == ctx.user.id, """
      O projeto foi criado sem autor.

      Projeto é declaração, e não observação: nenhum caminho da coleta o cria, e decisão
      tem autor.
      """

      {:ok, lido} = SPO.fetch_project(ctx.tenant, p.id)

      assert lido.phase == :simple, """
      O projeto recém-cadastrado não consta como simples.

      A fase é consequência de ter partes, e não escolha: antes das partes a resposta é
      simples, porque não há partes.
      """
    end

    test "nome repetido no mesmo tenant é recusado, e o erro cai no nome", ctx do
      projeto(ctx, "Conecta Fapes")

      assert {:error, changeset} =
               SPO.create_project(ctx.tenant, %{name: "Conecta Fapes"}, ctx.user.id)

      assert Keyword.has_key?(changeset.errors, :name), """
      A mensagem de nome repetido não caiu no campo `:name`.

      Ninguém digita o tenant: quem preenche o formulário preenche o nome, e é lá que a
      mensagem precisa aparecer.
      """
    end

    test "fim anterior ao início é recusado", ctx do
      assert {:error, changeset} =
               SPO.create_project(
                 ctx.tenant,
                 %{name: "Errado", started_on: ~D[2026-06-01], ended_on: ~D[2026-05-01]},
                 ctx.user.id
               )

      assert Keyword.has_key?(changeset.errors, :ended_on)
    end

    test "o mesmo nome em outro tenant é aceito", ctx do
      projeto(ctx, "Conecta Fapes")
      outro = tenant_fixture()
      outro_user = user_fixture(outro)

      assert {:ok, _} = SPO.create_project(outro, %{name: "Conecta Fapes"}, outro_user.id)
    end
  end

  describe "a fase muda com a estrutura" do
    test "ganhar uma parte torna complexo; perder a última volta a simples", ctx do
      pai = projeto(ctx, "Conecta Fapes")
      filho = projeto(ctx, "Backend")

      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, pai.id)
      {:ok, lido} = SPO.fetch_project(ctx.tenant, pai.id)

      assert lido.phase == :complex, """
      O projeto que ganhou uma parte não passou a complexo.

      A fase é consequência, e não rótulo — ninguém alterou um campo de tipo.
      """

      {:ok, _} = SPO.clear_parent(ctx.tenant, filho.id)
      {:ok, de_volta} = SPO.fetch_project(ctx.tenant, pai.id)

      assert de_volta.phase == :simple, """
      O projeto que perdeu a última parte continuou complexo.

      **É por isso que a fase é `phase` e não `kind`**: kind é rígido, e o projeto teria
      de deixar de existir para mudar. Fase preserva a identidade — mesmo id, mesma
      história.
      """

      assert de_volta.id == pai.id
    end

    test "a listagem traz a fase de todos sem consultar por linha", ctx do
      pai = projeto(ctx, "Conecta Fapes")
      filho = projeto(ctx, "Backend")
      projeto(ctx, "Solto")
      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, pai.id)

      por_nome = Map.new(SPO.list_projects(ctx.tenant), &{&1.name, &1.phase})

      assert por_nome == %{"Conecta Fapes" => :complex, "Backend" => :simple, "Solto" => :simple}
    end
  end

  describe "a hierarquia" do
    test "um segundo pai é recusado, e a mensagem nomeia o pai atual", ctx do
      um = projeto(ctx, "Conecta Fapes")
      outro = projeto(ctx, "Diretoria")
      filho = projeto(ctx, "Backend")

      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, um.id)

      assert {:error, {:already_has_parent, "Conecta Fapes"}} =
               SPO.set_parent(ctx.tenant, filho.id, outro.id),
             """
             Um projeto aceitou dois pais.

             A hierarquia é árvore, e é isso que faz cada issue contar uma vez no ancestral.
             E a mensagem nomeia o pai atual: quem cadastrou precisa saber o que desfazer.
             """
    end

    test "trocar de pai é permitido — desfazer e refazer", ctx do
      um = projeto(ctx, "Conecta Fapes")
      outro = projeto(ctx, "Diretoria")
      filho = projeto(ctx, "Backend")

      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, um.id)
      {:ok, _} = SPO.clear_parent(ctx.tenant, filho.id)
      {:ok, movido} = SPO.set_parent(ctx.tenant, filho.id, outro.id)

      assert movido.parent_id == outro.id, """
      Trocar de pai não funcionou.

      A restrição é sobre **simultaneidade**, e não imutabilidade: sem isso, errar o pai
      no cadastro não teria conserto, e refazer o projeto perderia os repositórios
      associados e a história dele.
      """
    end

    test "ser pai de si mesmo é recusado", ctx do
      p = projeto(ctx, "Conecta Fapes")

      assert {:error, {:cycle, _}} = SPO.set_parent(ctx.tenant, p.id, p.id)
    end

    test "ciclo indireto de três níveis é recusado, e o caminho é nomeado", ctx do
      a = projeto(ctx, "A")
      b = projeto(ctx, "B")
      c = projeto(ctx, "C")

      {:ok, _} = SPO.set_parent(ctx.tenant, b.id, a.id)
      {:ok, _} = SPO.set_parent(ctx.tenant, c.id, b.id)

      assert {:error, {:cycle, caminho}} = SPO.set_parent(ctx.tenant, a.id, c.id), """
      Um ciclo indireto foi aceito.

      **Um pai só não impede ciclo**: em `A → B → C → A` cada projeto tem exatamente um
      pai. Sem o axioma `spo.rule01`, a travessia até as issues não termina.
      """

      assert "A" in caminho and "C" in caminho, """
      A recusa não nomeou o caminho do ciclo.

      Dizer só "há um ciclo" deixa quem cadastrou procurando onde desfazer numa árvore
      que pode ter dezenas de projetos.
      """
    end

    test "profundidade livre: A → B → C é aceito", ctx do
      a = projeto(ctx, "A")
      b = projeto(ctx, "B")
      c = projeto(ctx, "C")

      {:ok, _} = SPO.set_parent(ctx.tenant, b.id, a.id)
      assert {:ok, _} = SPO.set_parent(ctx.tenant, c.id, b.id)
    end
  end

  describe "os repositórios" do
    test "associar registra autor e data", ctx do
      p = projeto(ctx, "Conecta Fapes")

      {:ok, vinculo} =
        SPO.link_repository(ctx.tenant, p.id, ctx.cenario.observed_repository_id, ctx.user.id)

      assert vinculo.linked_by_user_id == ctx.user.id
      assert vinculo.linked_at
    end

    test "o mesmo repositório serve a dois projetos", ctx do
      um = projeto(ctx, "Conecta Fapes")
      outro = projeto(ctx, "Diretoria")
      repo = ctx.cenario.observed_repository_id

      {:ok, _} = SPO.link_repository(ctx.tenant, um.id, repo, ctx.user.id)
      {:ok, _} = SPO.link_repository(ctx.tenant, outro.id, repo, ctx.user.id)

      assert length(SPO.list_project_repositories(ctx.tenant, um.id)) == 1
      assert length(SPO.list_project_repositories(ctx.tenant, outro.id)) == 1
    end

    test "desfazer marca, e a linha continua", ctx do
      p = projeto(ctx, "Conecta Fapes")

      {:ok, vinculo} =
        SPO.link_repository(ctx.tenant, p.id, ctx.cenario.observed_repository_id, ctx.user.id)

      {:ok, desfeito} = SPO.unlink_repository(ctx.tenant, vinculo.id, ctx.user.id)

      assert desfeito.unlinked_by_user_id == ctx.user.id
      assert SPO.list_project_repositories(ctx.tenant, p.id) == []

      assert Repo.aggregate(ProjectRepository, :count) == 1, """
      O vínculo desfeito foi apagado.

      Ausência marca, nunca apaga: o repositório esteve naquele projeto, e apagar a linha
      faria a história mudar retroativamente.
      """
    end

    test "reassociar o que saiu revive o vínculo, e não cria outro", ctx do
      p = projeto(ctx, "Conecta Fapes")
      repo = ctx.cenario.observed_repository_id

      {:ok, vinculo} = SPO.link_repository(ctx.tenant, p.id, repo, ctx.user.id)
      {:ok, _} = SPO.unlink_repository(ctx.tenant, vinculo.id, ctx.user.id)
      {:ok, _} = SPO.link_repository(ctx.tenant, p.id, repo, ctx.user.id)

      assert Repo.aggregate(ProjectRepository, :count) == 2, """
      Reassociar não criou o registro novo, ou criou dois vigentes.

      O índice único é **parcial sobre os vigentes** justamente para isto: o encerrado
      continua existindo, e o novo vínculo é outro fato com sua própria data.
      """
    end
  end

  describe "as issues, pela travessia" do
    test "vêm dos repositórios do projeto", ctx do
      p = projeto(ctx, "Conecta Fapes")

      {:ok, _} =
        SPO.link_repository(ctx.tenant, p.id, ctx.cenario.observed_repository_id, ctx.user.id)

      issues = SPO.list_project_issues(ctx.tenant, p.id)

      assert issues != []
      assert Enum.all?(issues, &(&1.via == :direct))
    end

    test "as de subprojeto são distinguíveis das diretas", ctx do
      pai = projeto(ctx, "Conecta Fapes")
      filho = projeto(ctx, "Backend")
      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, pai.id)

      {:ok, _} =
        SPO.link_repository(ctx.tenant, filho.id, ctx.cenario.observed_repository_id, ctx.user.id)

      contagem = SPO.count_project_issues(ctx.tenant, pai.id)

      assert contagem.direct == 0

      assert contagem.subproject > 0, """
      As issues do subprojeto não chegaram ao ancestral.

      A travessia é recursiva: projeto → subprojetos → repositórios → issues.
      """

      todas = SPO.list_project_issues(ctx.tenant, pai.id, incluir_subprojetos: true)

      assert Enum.all?(todas, &(&1.via == :subproject)), """
      As issues vindas de subprojeto não foram marcadas como tal.

      "Veio de repositório meu" e "veio de subprojeto" são fatos diferentes, e um total
      somado esconderia de onde o número veio — FR-014.
      """
    end

    test "projeto sem repositório não devolve issue alguma", ctx do
      p = projeto(ctx, "Vazio")
      assert SPO.list_project_issues(ctx.tenant, p.id) == []
    end
  end

  describe "o isolamento entre tenants" do
    test "o projeto de um tenant não aparece no outro", ctx do
      projeto(ctx, "Conecta Fapes")
      outro = tenant_fixture()

      assert SPO.list_projects(outro) == []
    end
  end
end
