defmodule TheBand.Repo.Migrations.IdentidadeDaAtividadeV2 do
  @moduledoc """
  O sujeito entra na identidade da atividade executada — emenda de 2026-09-15.

  ## O que estava errado

  O critério (`spo/modules/processes_and_activities.yaml`) hashava
  `tenant | organization | project | activity_type | performer | occurred_at | source_external_id`.
  **O sujeito não entrava.**

  Para commits isso bastava: o `sha` vem em `source_external_id` e individua a ocorrência. Para
  eventos de timeline, que a origem **não identifica**, o hash caía em tipo, ator e instante — e
  duas issues que mudam de coluna no mesmo segundo, pelo mesmo ator, viravam a mesma atividade.
  A segunda era descartada como duplicata, em silêncio.

  Medido: a issue `#2539` do `conectafapes-project` tem **12** eventos na origem e **7** no
  banco. O de `2026-08-12 15:12:16` não entrou porque a identidade estava ocupada pela `#2536`,
  que mudou de coluna no mesmo instante, pelo mesmo ator. Depois de uma recoleta que inseriu
  9 248 eventos, **9 de 10** issues conferidas continuavam divergindo por esta causa.

  ## O que esta migração faz

  Recalcula `internal_id` de **toda** atividade executada, com o sujeito incluído. Nada é
  apagado: o identificador muda, as linhas ficam.

  ## Por que não há risco de colisão nova

  O hash novo é **mais específico** que o antigo: dois registros que hoje têm `internal_id`
  distinto continuam distintos, porque todos os componentes antigos seguem no cálculo. A
  colisão só podia acontecer no sentido oposto — e é ela que esta emenda desfaz.

  ## O que a migração NÃO recupera

  Os eventos descartados no passado **não voltam** por recálculo: eles nunca foram gravados. O
  que ela devolve é a **possibilidade** de gravá-los — e quem os traz é a recoleta
  (`docs/backlog/timeline-truncada-na-origem.md` e a spec 068), que passa a completar.
  """
  use Ecto.Migration

  import Ecto.Query

  # O MESMO valor do schema (`performed_project_activity.ex`). Escrevê-lo diferente aqui
  # produziria hashes que o código de produção nunca reproduz — e foi o que aconteceu na
  # primeira execução desta migração, pega pela verificação antes do commit.
  @ausente "\x00"

  def up do
    repo().transaction(
      fn ->
        from(a in "spo_performed_project_activities",
          select: %{
            id: a.id,
            tenant_id: a.tenant_id,
            organization_id: a.organization_id,
            project_id: a.project_id,
            activity_type: a.activity_type,
            performer_id: a.performer_id,
            occurred_at: a.occurred_at,
            source_external_id: a.source_external_id,
            subject_type: a.subject_type,
            subject_id: a.subject_id
          }
        )
        |> repo().stream(max_rows: 500)
        |> Stream.each(fn linha ->
          novo = hash(linha)

          from(a in "spo_performed_project_activities", where: a.id == ^linha.id)
          |> repo().update_all(set: [internal_id: novo])
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  # Voltar atrás é recalcular sem o sujeito — a mesma operação, o critério antigo. Nenhum dado
  # é perdido nos dois sentidos, e é por isso que esta migração é reversível.
  def down do
    repo().transaction(
      fn ->
        from(a in "spo_performed_project_activities",
          select: %{
            id: a.id,
            tenant_id: a.tenant_id,
            organization_id: a.organization_id,
            project_id: a.project_id,
            activity_type: a.activity_type,
            performer_id: a.performer_id,
            occurred_at: a.occurred_at,
            source_external_id: a.source_external_id
          }
        )
        |> repo().stream(max_rows: 500)
        |> Stream.each(fn linha ->
          antigo =
            hash(Map.merge(linha, %{subject_type: :sem_componente, subject_id: :sem_componente}))

          from(a in "spo_performed_project_activities", where: a.id == ^linha.id)
          |> repo().update_all(set: [internal_id: antigo])
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  # O cálculo vive aqui, e não no schema, de propósito: uma migração precisa produzir o mesmo
  # resultado daqui a um ano, e chamar o código de produção a faria mudar de comportamento
  # quando o critério mudasse de novo.
  defp hash(linha) do
    [
      linha.tenant_id,
      linha.organization_id,
      linha.project_id,
      linha.activity_type,
      linha.performer_id,
      linha.occurred_at,
      linha.source_external_id,
      Map.get(linha, :subject_type),
      Map.get(linha, :subject_id)
    ]
    |> Enum.reject(&(&1 == :sem_componente))
    |> Enum.map_join("|", &canonico/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp canonico(nil), do: @ausente
  defp canonico(%DateTime{} = at), do: DateTime.to_iso8601(DateTime.truncate(at, :second))
  defp canonico(%NaiveDateTime{} = at), do: at |> DateTime.from_naive!("Etc/UTC") |> canonico()
  defp canonico(<<_::128>> = uuid), do: Ecto.UUID.cast!(uuid)
  defp canonico(valor), do: to_string(valor)
end
