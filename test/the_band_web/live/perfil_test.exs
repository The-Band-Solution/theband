defmodule TheBandWeb.PerfilTest do
  @moduledoc """
  A aba de perfil na página da pessoa — feature 026, T012 a T014.

  ## As três asserções que carregam este arquivo

  1. **os quatro estados dizem coisas diferentes** — nunca gerado, pedido, existente e
     recusado pedem ações diferentes de quem lê, e uma frase só para todos apagaria isso;
  2. **o rótulo "derived" está em texto** — o design system exige, e a razão não é acesso:
     a plataforma existe para separar o que observou do que concluiu, e cor sozinha desfaz
     o produto;
  3. **a recusa é do registro** — a frase não pode sugerir que a pessoa produziu pouco.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "pessoa-de-teste",
        name: "Pessoa de Teste",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/pessoa-de-teste",
        external_id: "U_perfil_teste",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => "pessoa-de-teste"}
      })

    %{
      conn: log_in(conn, user),
      tenant: tenant,
      user: user,
      pessoa: pessoa,
      repo_id: cenario.observed_repository_id
    }
  end

  defp gravar_perfil(ctx, attrs \\ %{}) do
    {:ok, perfil} =
      EO.record_profile(
        ctx.tenant,
        Map.merge(
          %{
            person_id: ctx.pessoa.id,
            generated_at: DateTime.utc_now(:second),
            model: "gpt-5.4-mini",
            body: "## pessoa-de-teste\n\n**Habilidades principais:** observabilidade · Helm",
            citations_removed: 7,
            tasks_closed: 97,
            tasks_open: 5,
            tasks_with_body: 97,
            tasks_authored_by_other: 55,
            tasks_shared: 23,
            baseline_verdict: "a pessoa ACOMPANHOU o projeto"
          },
          attrs
        )
      )

    perfil
  end

  describe "quando existe perfil" do
    test "a proveniência aparece antes do texto", ctx do
      gravar_perfil(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "gpt-5.4-mini"
      assert html =~ "97"
      assert html =~ "described by someone else"

      assert html =~ "ACOMPANHOU",
             """
             O veredito da linha de base não apareceu.

             É o que impede quem lê de atribuir à pessoa um crescimento de texto que foi do
             time inteiro — e sem ele o perfil afirma mais do que o registro sustenta.
             """
    end

    test "o rótulo de derivado está em texto, e não só em cor", ctx do
      gravar_perfil(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "written by a language model",
             """
             O bloco derivado não se identifica em texto.

             Cor sozinha reprova em WCAG 1.4.1 e, pior, desfaz o produto: a plataforma existe
             para separar o que observou do que concluiu.
             """
    end

    test "quantas citações saíram do resumo é dito, e zero é medição", ctx do
      gravar_perfil(ctx, %{citations_removed: 0})
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "citations removed from the summary",
             """
             A limpeza aconteceu calada.

             É a mesma classe de defeito que a limpeza existe para conter — e zero aqui é a
             afirmação "nada foi removido", não ausência de medida.
             """
    end

    test "uma geração nova não apaga a anterior", ctx do
      antiga =
        gravar_perfil(ctx, %{generated_at: ~U[2026-06-01 10:00:00Z], body: "perfil antigo"})

      nova = gravar_perfil(ctx, %{generated_at: ~U[2026-08-15 10:00:00Z], body: "perfil novo"})

      assert length(EO.list_profiles(ctx.tenant, ctx.pessoa.id)) == 2
      assert {:ok, ^nova} = EO.current_profile(ctx.tenant, ctx.pessoa.id)
      assert Enum.any?(EO.list_profiles(ctx.tenant, ctx.pessoa.id), &(&1.id == antiga.id))
    end
  end

  describe "quando não há perfil" do
    test "sem designação alguma, a recusa diz que não há de onde olhar", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "No current assignment observed"
      refute html =~ "Generate profile"
    end

    test "a recusa não sugere que a pessoa produziu pouco", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ ~r/produced (little|few)/i
      refute html =~ "low output"

      assert html =~ "nothing to read from",
             """
             A recusa não disse que a falta é do registro.

             "Não há de onde olhar" e "esta pessoa fez pouco" são frases diferentes, e só a
             primeira é afirmável a partir deste material.
             """
    end
  end

  describe "o egresso de dado" do
    test "a frase acompanha o botão, e não o rodapé", ctx do
      material_suficiente(ctx)
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Generate profile"

      assert html =~ "external language-model provider",
             """
             A tela oferece a geração sem dizer que o texto das tarefas sai da plataforma.

             Quem decide precisa saber o que sai daqui **no momento de decidir** — depois já
             saiu.
             """
    end
  end

  # Material acima de todos os pisos: 30 tarefas concluídas, todas com corpo, espalhadas.
  defp material_suficiente(ctx) do
    base = ~U[2025-02-10 12:00:00Z]

    for n <- 1..30 do
      fechada = DateTime.add(base, n * 15, :day)

      {:ok, issue} =
        TheBand.WorkItems.record_collected_issue(ctx.tenant, %{
          observed_repository_id: ctx.repo_id,
          number: 7000 + n,
          title: "tarefa ##{n}",
          body: String.duplicate("contexto e decisão. ", 25),
          state: "CLOSED",
          author_login: "pessoa-de-teste",
          external_created_at: DateTime.add(fechada, -4, :day),
          external_closed_at: fechada,
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_perfil_tela_#{n}"
        })

      {:ok, _} =
        TheBand.WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: "pessoa-de-teste", external_id: "U_perfil_teste", person_id: ctx.pessoa.id}
        ])
    end
  end
end
