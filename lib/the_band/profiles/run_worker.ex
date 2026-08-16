defmodule TheBand.Profiles.RunWorker do
  @moduledoc """
  A rodada de uma organização, percorrida em sequência — feature 027, T015 e T016.

  ## Por que um job longo, e não um por pessoa

  Três requisitos empurram para cá ao mesmo tempo. A `FR-016` manda **encerrar a rodada**
  quando a credencial falha, e com um job por pessoa encerrar exigiria cancelar jobs já
  enfileirados. O `AGENTS.md` §7.5 exige checkpoint persistido, nunca só em memória. E os
  perfis são somente-acréscimo: sem guarda, a segunda tentativa do Oban gravaria um segundo
  texto sobre o mesmo material.

  ## O checkpoint é a entrada, e é o que torna a retentativa barata

  Quem já tem entrada nesta rodada não é considerado de novo. A retentativa retoma de onde
  parou em vez de recomeçar — e recomeçar, aqui, custa dinheiro.
  """

  use Oban.Worker, queue: :rodadas, max_attempts: 3

  require Logger

  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Profiles.{GenerateWorker, Regeneration, Runs}
  alias TheBand.Repo
  alias TheBand.Tenants

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "run_id" => run_id}}) do
    with {:ok, tenant} <- Tenants.fetch(tenant_id),
         {:ok, run} <- Runs.get(tenant, run_id) do
      executar(tenant, run)
    else
      # `Tenants.fetch/1` e `Runs.get/2` devolvem a mesma forma de erro; o que distingue é
      # qual das duas falhou, e por isso a rodada é buscada com o tenant já resolvido.
      {:error, :not_found} -> {:cancel, {:nao_encontrado, tenant_id, run_id}}
    end
  end

  # Rodada já fechada é trabalho já feito. Reexecutar geraria de novo, e a tabela de perfis é
  # somente-acréscimo — o job precisa ser idempotente, e é aqui que ele começa a ser.
  defp executar(_tenant, %{finished_at: fim} = run) when fim != nil do
    Logger.info("rodada #{run.id} já encerrada em #{fim}")
    :ok
  end

  defp executar(tenant, run) do
    case Regeneration.select(tenant, escopo(run)) do
      {:ok, vereditos} ->
        ja_feitas = Runs.recorded_person_ids(run)

        restantes =
          Enum.reject(vereditos, fn {pessoa, _} -> MapSet.member?(ja_feitas, pessoa.id) end)

        # O denominador da barra de progresso, regravado a cada tentativa: a elegibilidade
        # pode mudar entre elas, e um plano velho mentiria o total.
        {:ok, run} = Runs.plan(run, MapSet.size(ja_feitas) + length(restantes))

        percorrer(restantes, tenant, run)

      # Limiar ausente ou inválido não deixa a rodada escolher por conta própria — `FR-009`.
      # Encerrar com o motivo é melhor que rodar com um número que ninguém definiu.
      {:error, motivo} ->
        {:ok, _} = Runs.finish(run, {:ended_early, "limiares indisponíveis: #{inspect(motivo)}"})
        {:cancel, motivo}
    end
  end

  # A rodada manual gera para todas as pessoas com material — emenda de 2026-08-16 à
  # `FR-004`. Pedir a mão já é a decisão de escrever; a regra de mudança existe para a
  # rodada que ninguém pediu.
  defp escopo(%{trigger: "manual"}), do: :todas
  defp escopo(_), do: :mudou

  defp percorrer([], _tenant, run) do
    {:ok, _} = Runs.finish(run, :completed)
    :ok
  end

  defp percorrer([{pessoa, veredito} | resto], tenant, run) do
    case processar(tenant, run, pessoa, veredito) do
      :continua ->
        percorrer(resto, tenant, run)

      {:encerra, motivo} ->
        Logger.warning("rodada #{run.id} encerrada no meio: #{motivo}")
        {:ok, _} = Runs.finish(run, {:ended_early, motivo})
        :ok
    end
  end

  defp processar(_tenant, run, pessoa, {:skip, motivo}) do
    {:ok, _} = Runs.record(run, pessoa.id, %{outcome: "skipped", reason: to_string(motivo)})
    :continua
  end

  defp processar(tenant, run, pessoa, :generate) do
    # A condição de observação é reavaliada **agora**, e não só na seleção: uma rodada de
    # trinta pessoas leva dezenas de minutos, e a observação pode ser encerrada no meio dela.
    if observacao_encerrada?(pessoa) do
      {:ok, _} = Runs.record(run, pessoa.id, %{outcome: "skipped", reason: "observation_ended"})
      :continua
    else
      gerar(tenant, run, pessoa)
    end
  end

  defp gerar(tenant, run, pessoa) do
    case GenerateWorker.gerar(tenant, pessoa.id) do
      {:ok, perfil, tokens} ->
        {:ok, _} =
          Runs.record(run, pessoa.id, %{
            outcome: "generated",
            person_profile_id: perfil.id,
            input_tokens: tokens
          })

        :continua

      {:error, motivo} ->
        {:ok, _} =
          Runs.record(run, pessoa.id, %{
            outcome: "failed",
            failure_reason: texto(motivo)
          })

        if credencial?(motivo), do: {:encerra, texto(motivo)}, else: :continua
    end
  end

  # **Falha de credencial encerra; limite de taxa não.** A distinção não é preciosismo: com a
  # chave recusada, a próxima pessoa falharia pelo mesmo motivo, e insistir gastaria trinta
  # tentativas para chegar ao mesmo lugar. Já `429` e falha de rede são do momento.
  defp credencial?({:http, status, _}) when status in [401, 403], do: true
  defp credencial?(:missing_credential), do: true
  defp credencial?(_), do: false

  # O motivo já vem redigido pela borda — `HTTP.redigir/2` tira a chave de qualquer mensagem
  # antes de ela circular. Aqui só se garante que o que vai para a coluna é texto.
  defp texto(motivo) when is_binary(motivo), do: motivo
  defp texto(motivo), do: inspect(motivo)

  defp observacao_encerrada?(%Person{id: id}) do
    case Repo.get(Person, id) do
      nil -> true
      pessoa -> pessoa.no_longer_observed_at != nil
    end
  end
end
