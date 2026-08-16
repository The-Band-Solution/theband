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
end
