defmodule TheBand.SemanticIntegration do
  @moduledoc """
  Reprocessa dados já coletados aplicando mapeamentos corrigidos (FR-017).

  Contrato: `specs/001-github-eo-ingestion/contracts/reprocessing.md`.

  Um mapeamento erra, e a descoberta costuma vir semanas depois — quando alguém
  percebe que o número não bate. Sem este caminho, corrigir o YAML exigiria
  coletar tudo de novo: gastar a janela de API e depender de a origem ainda ter o
  mesmo estado, o que para dado histórico não vale.

  **Este módulo não conhece o cliente do GitHub.** A garantia de zero consultas à
  origem não é verificada por inspeção: o teste roda sem registrar expectativa no
  Mox da borda HTTP, então qualquer chamada faz o teste falhar sozinho.
  """

  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.SemanticIntegration.Mapper
  alias TheBand.Tenants.Tenant

  require Logger

  @type report :: %{
          reprocessed: non_neg_integer(),
          created: non_neg_integer(),
          updated: non_neg_integer(),
          unchanged: non_neg_integer(),
          skipped: non_neg_integer(),
          skip_reasons: %{String.t() => non_neg_integer()}
        }

  @empty %{
    reprocessed: 0,
    created: 0,
    updated: 0,
    unchanged: 0,
    skipped: 0,
    skip_reasons: %{}
  }

  @topic "syncs"

  @doc """
  Reaplica os mapeamentos aos payloads já preservados.

  `opts[:raw_entity_type]` restringe a um tipo; ausente, reprocessa todos.

  Reprocessar sem ter mudado o mapeamento devolve `updated: 0`: o upsert por
  Application Reference já compara os atributos e não escreve quando nada mudou.
  Não existe um segundo mecanismo de idempotência aqui, de propósito — seria um
  segundo lugar para discordar do primeiro.
  """
  @spec reprocess_mappings(Tenant.t(), keyword()) :: {:ok, report()} | {:error, term()}
  def reprocess_mappings(%Tenant{} = tenant, opts \\ []) do
    payloads = load_payloads(tenant, opts[:raw_entity_type])

    case payloads do
      [] -> {:error, :no_raw_payloads}
      _ -> {:ok, Enum.reduce(payloads, @empty, &apply_to(&1, &2, tenant))}
    end
  end

  @doc """
  Publica o resultado no mesmo tópico da sincronização.

  Aceita também `%{error: motivo}` para que a tela possa dizer **por que** não
  houve o que reprocessar, em vez de mostrar um relatório de zeros que se parece
  com sucesso.
  """
  @spec broadcast_report(Tenant.t(), report() | %{error: atom()}) :: :ok
  def broadcast_report(%Tenant{id: tenant_id}, report) do
    Phoenix.PubSub.broadcast(
      TheBand.PubSub,
      @topic <> ":" <> tenant_id,
      {:reprocess_finished, report}
    )
  end

  defp load_payloads(tenant, nil) do
    ~w(github.organization github.user github.team github.team_member)
    |> Enum.flat_map(&RawData.list_for_reprocessing(tenant, &1))
  end

  defp load_payloads(tenant, raw_entity_type),
    do: RawData.list_for_reprocessing(tenant, raw_entity_type)

  defp apply_to(raw, report, tenant) do
    report = %{report | reprocessed: report.reprocessed + 1}

    with {:ok, mapping_id} <- fetch_mapping_id(raw),
         {:ok, attrs} <- Mapper.apply_mapping(mapping_id, raw.payload) do
      write(tenant, raw, attrs, report)
    else
      {:error, reason} -> skip(report, reason)
    end
  end

  defp fetch_mapping_id(%{mapping_id: nil}),
    do: {:error, "payload gravado sem mapping_id — coletado antes de FR-017 existir"}

  defp fetch_mapping_id(%{mapping_id: mapping_id}), do: {:ok, mapping_id}

  defp write(tenant, raw, attrs, report) do
    attrs =
      attrs
      |> Map.merge(provenance(raw))
      # O mesmo completador que a coleta usa. Duas cópias divergiriam, e a
      # divergência apareceria como registro "atualizado" num reprocessamento que
      # não deveria mudar nada.
      |> Mapper.complete(raw.raw_entity_type, raw.payload)

    # A API pública de EO devolve changeset em toda falha de escrita; uma cláusula
    # genérica depois desta seria código morto.
    case upsert(tenant, raw.raw_entity_type, attrs) do
      {:ok, record} -> tally(report, record.outcome || :unchanged)
      {:error, changeset} -> skip(report, changeset_reason(changeset))
    end
  end

  # `collected_at` fica como estava: o reprocessamento não é uma observação nova,
  # e sobrescrevê-lo apagaria quando a plataforma de fato viu aquele dado.
  defp provenance(raw) do
    %{
      source_system: raw.source_system,
      source_instance: raw.source_instance,
      external_id: raw.external_id,
      collected_at: raw.collected_at
    }
  end

  defp upsert(tenant, "github.organization", attrs),
    do: EO.upsert_organization_from_source(tenant, attrs)

  defp upsert(tenant, "github.team", attrs), do: EO.upsert_team_from_source(tenant, attrs)
  defp upsert(tenant, _person_like, attrs), do: EO.upsert_person_from_source(tenant, attrs)

  defp tally(report, :created), do: %{report | created: report.created + 1}
  defp tally(report, :updated), do: %{report | updated: report.updated + 1}
  defp tally(report, _unchanged), do: %{report | unchanged: report.unchanged + 1}

  # Registro cujo mapeamento falha nunca derruba o lote: um mapeamento quebrado
  # não pode impedir a correção dos outros.
  defp skip(report, reason) do
    Logger.warning("reprocessamento ignorou um registro: #{reason}")

    %{
      report
      | skipped: report.skipped + 1,
        skip_reasons: Map.update(report.skip_reasons, to_string(reason), 1, &(&1 + 1))
    }
  end

  defp changeset_reason(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
