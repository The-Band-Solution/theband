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

  ## Os dois números são diferentes, e o job informa os dois

  `Mapping.recompute/2` devolve `%{written:, concept_changed:}`. Uma issue pode manter o
  conceito e mudar a **proveniência** — passar a ser decidida pela regra da organização em
  vez da global. Isso é linha gravada e não é mudança de conceito.

  Este job interpolava o mapa numa string como se fosse um inteiro, e estourava
  `Protocol.UndefinedError` **depois** de o recálculo já ter acontecido. Resultado: o
  trabalho era feito três vezes, o job terminava `discarded`, e a tela não recebia nada.
  Nenhum teste pegou porque nenhum exercitava o job com o contrato atual.
  """

  use Oban.Worker, queue: :transformation, max_attempts: 3, unique: [period: 30, fields: [:args]]

  alias TheBand.Mapping
  alias TheBand.Tenants

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "organization_id" => org_id}}) do
    with {:ok, tenant} <- Tenants.fetch(tenant_id) do
      {:ok, %{written: escritas, concept_changed: conceito} = resultado} =
        Mapping.recompute(tenant, org_id)

      Logger.info(
        "recálculo concluído na organização #{org_id}: " <>
          "#{escritas} linhas gravadas, #{conceito} issues mudaram de conceito"
      )

      Mapping.broadcast(tenant_id, {:promotions_recomputed, org_id, resultado})

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
