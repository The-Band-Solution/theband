defmodule TheBand.Profiles.GenerateWorker do
  @moduledoc """
  Gera um perfil em trabalho de fundo — feature 026.

  ## Por que não é chamada síncrona na tela

  Medido na validação de 2026-08-15: a chamada leva **de 25 a 60 segundos** com 24 mil tokens
  de entrada. Segurar o processo do LiveView por um minuto prenderia a aba inteira, e um
  `timeout` de rede derrubaria a tela em vez de reportar a falha.

  ## Nenhum caminho devolve silêncio

  Cada ramo termina em algo gravado ou em algo nomeado. Resposta vazia **não vira perfil** —
  é a `FR-022`, e é a mesma classe de defeito que a L26 do projeto: o job completa, nada é
  gravado, e ninguém percebe.
  """

  use Oban.Worker, queue: :perfis, max_attempts: 3

  require Logger

  alias TheBand.Integrations.LLM.HTTP
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.{Material, Prompt, Sanitizer}
  alias TheBand.Tenants

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{"tenant_id" => tenant_id, "person_id" => person_id} = args

    with {:ok, tenant} <- Tenants.fetch(tenant_id),
         {:ok, material} <- Material.build(tenant, person_id),
         {:ok, resposta} <- chamar(material) do
      gravar(tenant, material, resposta, args["requested_by_user_id"])
    else
      # A recusa do material **não é falha do job**: é resposta, e a tela já sabe mostrá-la
      # a partir do próprio material. Repetir três vezes o que não vai mudar gastaria
      # chamada e encheria o log de erro que não é erro.
      :error ->
        {:cancel, {:tenant_not_found, tenant_id}}

      {:error, motivo} when is_atom(motivo) or is_tuple(motivo) ->
        Logger.info("perfil não gerado para #{person_id}: #{inspect(motivo)}")
        {:cancel, motivo}
    end
  end

  defp chamar(material) do
    HTTP.impl().complete(Prompt.instrucoes(), Prompt.material(material), schema: Prompt.schema())
  end

  defp gravar(tenant, material, %{text: texto, model: modelo}, user_id) do
    case Jason.decode(texto) do
      {:ok, bruto} -> gravar_conteudo(tenant, material, bruto, modelo, user_id)
      # JSON inválido com schema estrito não deveria acontecer, e por isso mesmo é dito em
      # vez de tratado: se acontecer, mudou algo no contrato do provedor.
      {:error, e} -> {:cancel, {:invalid_json, Exception.message(e)}}
    end
  end

  defp gravar_conteudo(tenant, material, bruto, modelo, user_id) do
    {conteudo, removidas} = Sanitizer.clean_summary(bruto)

    EO.record_profile(tenant, %{
      person_id: material.person_id,
      generated_at: DateTime.utc_now(:second),
      requested_by_user_id: user_id,
      model: modelo,
      content: conteudo,
      citations_removed: removidas,
      tasks_closed: length(material.concluidas),
      tasks_open: length(material.abertas),
      tasks_with_body: material.com_corpo,
      tasks_authored_by_other: length(material.concluidas) - material.autoria_propria,
      tasks_shared: material.compartilhadas,
      period_from: mes_para_data(material.de),
      period_to: mes_para_data(material.ate),
      baseline_verdict: material.veredito
    })
    |> case do
      {:ok, perfil} ->
        Logger.info(
          "perfil gravado para #{material.login}: " <>
            "#{length(conteudo["habilidades"])} habilidades, " <>
            "#{length(conteudo["destaques"])} destaques, " <>
            "#{length(conteudo["lacunas"])} lacunas, " <>
            "#{removidas} citações tiradas do resumo"
        )

        {:ok, perfil}

      # Changeset inválido aqui é quase sempre corpo vazio, e repetir não conserta: o
      # provedor devolveria vazio de novo.
      {:error, changeset} ->
        {:cancel, {:invalid_profile, inspect(changeset.errors)}}
    end
  end

  defp mes_para_data(nil), do: nil
  defp mes_para_data(mes), do: Date.from_iso8601!(mes <> "-01")
end
