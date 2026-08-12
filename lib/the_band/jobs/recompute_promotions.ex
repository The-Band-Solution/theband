defmodule TheBand.Jobs.RecomputePromotions do
  @moduledoc """
  Recalcula a promoção das issues de uma organização depois que uma regra mudou.

  ## Fila `:transformation`, que já existe

  Declarar fila nova sem configurá-la faz o job ficar `available` **para sempre** — e o
  sintoma é traiçoeiro: a interface diz "enfileirado" e nada acontece, sem erro. Já
  aconteceu nesta base com uma fila `:sync` inexistente.

  E `transformation` é semanticamente certa: recalcular promoção é transformar o que já
  foi coletado, não coletar.

  ## Assíncrono sempre, sem limite condicional

  O recálculo afeta até 3400 issues numa organização, e o número cresce. Um limite —
  síncrono até N, assíncrono acima — criaria dois caminhos, e o raro é o que quebra:
  seria testado com 10 issues e usado com 3400.

  O custo é que gravar regra não devolve o resultado na mesma requisição, e a tela resolve
  mostrando o progresso — que ela precisa mostrar de todo modo.

  **Nenhuma requisição à origem acontece aqui.** Os payloads estão preservados desde a
  feature 004, e a promoção é recalculável a partir do que já está no banco.
  """

  use Oban.Worker, queue: :transformation, max_attempts: 3, unique: [period: 30, fields: [:args]]

  alias TheBand.Mapping
  alias TheBand.Tenants

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "organization_id" => org_id}}) do
    with {:ok, tenant} <- Tenants.fetch(tenant_id) do
      {:ok, mudadas} = Mapping.recompute(tenant, org_id)

      Logger.info("recálculo concluído: #{mudadas} promoções novas na organização #{org_id}")

      Phoenix.PubSub.broadcast(
        TheBand.PubSub,
        "tenant:#{tenant_id}",
        {:promotions_recomputed, org_id, mudadas}
      )

      :ok
    end
  end

  @doc """
  Enfileira o recálculo.

  `unique` por 30 segundos: gravar três regras seguidas não enfileira três recálculos do
  mesmo lote — o último a valer já recalcula tudo.
  """
  @spec enqueue(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(tenant_id, organization_id) do
    %{tenant_id: tenant_id, organization_id: organization_id}
    |> new()
    |> Oban.insert()
  end
end
