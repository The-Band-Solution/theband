defmodule TheBand.MCP.Ferramentas.TeamReviewWait do
  @moduledoc """
  `team_review_wait` — quanto o trabalho desta equipe espera pela primeira revisão humana
  (feature 062, T012).

  Responde à necessidade de informação `review.time_to_first_review`, com a medida
  `review.time_to_first_review.duration`, pelo mesmo caminho do `time_to_first_review` da rota
  `GET /api/v1/teams/:id/measures`: `Quality.team_time_to_first_review/3`, a mesma janela de
  56 dias e o mesmo limite de 200.

  ## Duas leituras, e nunca uma

  É a ferramenta que justifica a feature. Medido na equipe `LEDS - ConectaFapes` em
  2026-09-21: **23** revisadas com mediana de **0,2 h**, e **79** aguardando com mediana de
  **46 dias**. Um campo só teria dito *"12 minutos"*.

  - `reviewed` em **horas**, e `waiting` em **dias**, cada uma com o seu denominador;
  - **nenhum campo combina as duas**;
  - omitir as em curso faria a medida **melhorar quanto pior a equipe estivesse**, e contá-las
    como zero afirmaria revisão instantânea;
  - `median_hours` e `median_days` são `null` quando não há o que medir, **e nunca zero**;
  - `truncated` diz se a lista foi cortada: uma mediana sobre 200 de 500 é outra medida.
  """

  alias TheBand.Ingestion
  alias TheBand.MCP.Envelope
  alias TheBand.Quality
  alias TheBand.Tenants.Tenant

  @janela_em_dias 56
  @limite 200

  @doc "A resposta, com o envelope. A equipe chega carregada e já autorizada pelo registro."
  @spec responder(Tenant.t(), map()) :: map()
  def responder(%Tenant{} = tenant, equipe) do
    agora = DateTime.utc_now(:second)
    desde = DateTime.add(agora, -@janela_em_dias, :day)

    # UMA a mais que o limite, para saber se cortou. Sem isso o corte é silencioso.
    carregadas =
      Quality.team_time_to_first_review(tenant, equipe.id,
        desde: desde,
        ate: agora,
        limit: @limite + 1
      )

    esperas = Enum.take(carregadas, @limite)
    {aguardando, revisadas} = Enum.split_with(esperas, &match?({:aguardando, _}, &1.estado))

    [
      value: %{
        reviewed: %{count: length(revisadas), median_hours: Quality.mediana_em_horas(esperas)},
        waiting: %{
          count: length(aguardando),
          median_days: Quality.mediana_da_espera_em_dias(esperas)
        },
        truncated: length(carregadas) > @limite,
        limit: @limite
      },
      composition: %{
        is_composed: false,
        note: "Change requests opened in the window by people who belonged to the team."
      },
      window: %{days: @janela_em_dias, from: desde, to: agora},
      origin: "derived",
      ressalvas: {:medida, "review.time_to_first_review.duration"},
      collected_at: Ingestion.ultima_coleta_concluida(tenant)
    ]
    |> Envelope.montar()
    |> Map.put(:state, "checked")
  end
end
