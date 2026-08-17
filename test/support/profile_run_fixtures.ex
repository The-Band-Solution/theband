defmodule TheBand.ProfileRunFixtures do
  @moduledoc """
  Cenário mínimo para exercitar a rodada de perfis — feature 027.

  Monta uma pessoa com material acima dos pisos da feature 026, porque é a única forma de
  chegar aos ramos que interessam: sem material, toda pessoa é pulada por `:no_material` e os
  outros cinco ramos da `due?/3` nunca rodam.
  """

  import TheBand.WorkItemsFixtures

  alias TheBand.AI
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  @doc "Tenant com cenário de coleta e credencial de provedor gravada."
  def tenant_com_credencial(tenant) do
    Mox.expect(TheBand.LLMHTTPMock, :verify, fn _s, _o -> {:ok, ["gpt-5.4-mini"]} end)
    {:ok, cred} = AI.put(tenant, %{"secret" => "sk-chave-de-teste-com-mais-de-vinte-caracteres"})
    cred
  end

  @doc """
  Uma pessoa com N tarefas concluídas com corpo, distribuídas no tempo.

  `desde:` é o primeiro índice da numeração, e existe para a **segunda** chamada com o mesmo
  login acrescentar tarefas em vez de reescrevê-las. O `external_id` é `I_<login>_<n>`, e a
  coleta faz upsert por ele: uma segunda chamada começando de 1 não cria tarefas novas —
  **move as antigas no tempo**, e o início do histórico anda junto. Foi exatamente assim que
  o teste do recorte reprovou no CI com o produto certo.
  """
  def pessoa_com_material(tenant, repo_id, login, opts \\ []) do
    quantas = Keyword.get(opts, :tarefas, 30)
    base = Keyword.get(opts, :base, ~U[2025-02-10 12:00:00Z])
    desde = Keyword.get(opts, :desde, 1)
    estado = Keyword.get(opts, :estado, "CLOSED")

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
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

    for n <- desde..(desde + quantas - 1) do
      fechada = DateTime.add(base, (n - desde + 1) * 15, :day)

      {:ok, issue} =
        WorkItems.record_collected_issue(tenant, %{
          observed_repository_id: repo_id,
          number: :erlang.unique_integer([:positive]),
          title: "tarefa #{login} ##{n}",
          body: String.duplicate("contexto. ", 30),
          state: estado,
          author_login: login,
          external_created_at: DateTime.add(fechada, -4, :day),
          external_closed_at: if(estado == "CLOSED", do: fechada),
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_#{login}_#{n}"
        })

      {:ok, _} =
        WorkItems.replace_assignees(tenant, issue.id, [
          %{login: login, external_id: "U_#{login}", person_id: pessoa.id}
        ])
    end

    pessoa
  end

  @doc "Cenário completo: tenant, repositório observado e uma pessoa com material."
  def cenario(tenant, login \\ "gerada") do
    cenario = cenario_real(tenant)
    pessoa = pessoa_com_material(tenant, cenario.observed_repository_id, login)
    %{repo_id: cenario.observed_repository_id, pessoa: pessoa}
  end
end
