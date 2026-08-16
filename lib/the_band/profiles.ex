defmodule TheBand.Profiles do
  @moduledoc """
  Perfil de competências e evolução de uma pessoa — feature 026.

  ## O que este contexto faz, e o que ele recusa fazer

  Lê as tarefas designadas a alguém, monta um recorte, e pede a um modelo de linguagem que
  escreva sobre ele. **Não afirma competência**: a rede de ontologias não ganhou conceito de
  habilidade, e a razão está em `research.md` R1 da feature — criar um faria a plataforma
  dizer que a pessoa *tem* a habilidade, a partir de texto que em 44% dos casos foi escrito
  por outra pessoa.

  ## O caminho

      Material.build/2   →   Prompt   →   LLM.HTTP   →   Sanitizer   →   EO.record_profile/2
      recusa aqui,           regras       borda          limpa o        somente
      com quatro             que são      única com      resumo         acréscimo
      motivos distintos      requisito    Mox
  """

  alias TheBand.Profiles.{GenerateWorker, Material}
  alias TheBand.Tenants.Tenant

  @doc """
  Verifica se há material, sem montar o material e sem gastar chamada.

  A tela chama isto **antes** de oferecer o botão: pedir uma geração que vai ser recusada
  gasta um job e devolve a mesma recusa mais tarde, com a pessoa esperando à toa.

  Uma consulta, e ela traz só tamanho de corpo — ver `Material.check/2`. A versão anterior
  chamava `build/2` aqui, e o guard de consultas da página da pessoa pegou: quatro consultas
  e todo o texto das tarefas, a cada render, para decidir se um botão aparece.
  """
  defdelegate check(tenant, person_id), to: Material

  @doc """
  Enfileira uma geração.

  Devolve o job, e **não** o perfil: quem chama não espera. A chamada leva de 25 a 60
  segundos, medidos.
  """
  @spec request(Tenant.t(), binary(), binary() | nil) ::
          {:ok, Oban.Job.t()} | {:error, term()}
  def request(%Tenant{id: tenant_id}, person_id, user_id \\ nil) do
    %{tenant_id: tenant_id, person_id: person_id, requested_by_user_id: user_id}
    |> GenerateWorker.new()
    |> Oban.insert()
  end

  @doc """
  Quantas tarefas concluíram **depois** do recorte que gerou o perfil exibido.

  É a `FR-016`, e existe porque um perfil de dezembro parece atual em junho: quem lê decide
  com texto velho sem saber que é velho. Sai da diferença entre `tasks_closed` gravado e o
  que existe hoje — e é para isso que o recorte é coluna, e não JSON.

  Sem perfil, zero: não há de que contar a distância.
  """
  @spec tasks_since(Tenant.t(), binary(), map() | nil) :: non_neg_integer()
  def tasks_since(_tenant, _person_id, nil), do: 0

  def tasks_since(%Tenant{id: tenant_id}, person_id, %{tasks_closed: gravadas}) do
    import Ecto.Query

    hoje =
      from(i in "collected_issues",
        join: a in "issue_assignees",
        on: a.collected_issue_id == i.id and is_nil(a.no_longer_observed_at),
        where:
          i.tenant_id == type(^tenant_id, :binary_id) and
            a.person_id == type(^person_id, :binary_id) and i.state == "CLOSED",
        select: count(i.id)
      )
      |> TheBand.Repo.one()

    max(hoje - gravadas, 0)
  end

  @doc """
  As tarefas designadas e abertas há mais tempo que o limiar declarado.

  **Observadas, e recalculadas a cada leitura.** Guardá-las no perfil faria uma tarefa que
  fechou depois da geração continuar aparecendo como parada — a tela mostraria uma pendência
  que já não existe, e quem lê agiria sobre ela.

  O limiar vem de `profile.thresholds`, regra `stale_open_work`.
  """
  @spec stale_open(Tenant.t(), binary()) :: [map()]
  def stale_open(%Tenant{} = tenant, person_id) do
    tenant
    |> Material.open_tasks(person_id)
    |> Enum.filter(&(&1.dias_aberta > Material.stale_days()))
    |> Enum.sort_by(& &1.dias_aberta, :desc)
  end

  @doc """
  Há geração pendente para esta pessoa?

  É o terceiro estado da tela — *pedido, ainda não pronto* —, e ele precisa ser distinguível
  de *nunca gerado* e de *falhou*.
  """
  @spec pending?(Tenant.t(), binary()) :: boolean()
  def pending?(%Tenant{id: tenant_id}, person_id) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.worker == "TheBand.Profiles.GenerateWorker" and
          j.state in ["available", "scheduled", "executing", "retryable"] and
          fragment("? ->> 'tenant_id' = ?", j.args, ^tenant_id) and
          fragment("? ->> 'person_id' = ?", j.args, ^person_id)
    )
    |> TheBand.Repo.exists?()
  end
end
