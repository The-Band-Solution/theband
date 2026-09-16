defmodule TheBand.Ontology.SEON.SPO.Commands do
  @moduledoc """
  Escritas de SPO. Implementação; a fronteira é `TheBand.Ontology.SEON.SPO`.
  """

  import Ecto.Query, only: [where: 2, where: 3]

  alias TheBand.Ontology.SEON.SPO.Schemas.IntendedProjectProcess
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Registra uma ocorrência de atividade executada.

  **Nunca atualiza.** Se o critério de identidade já existe, devolve o registro com
  `outcome: :unchanged` sem tocar na linha — uma ocorrência não muda, ela aconteceu.
  É o que faz reprocessar a mesma origem produzir uma linha (FR-003).

  ## Duas exceções aparentes, e por que não são

  As duas escrevem em linha existente, e nenhuma muda o que aconteceu. A ocorrência é a
  mesma — mesmo tipo, mesmo ator, mesmo instante, mesmo sujeito. O que muda é o que
  sabemos escrever sobre ela.

  A **complementação** preenche campo nulo com o que a origem sempre disse e a consulta
  não pedia. Nulo é pergunta sem resposta; preencher é responder pela primeira vez, e
  trocar valor existente segue proibido. Sem ela, acrescentar campo à consulta não alcança
  o histórico: em 2026-09-16 uma recoleta de 25 repositórios passou inteira sem gravar um
  único quadro, porque toda ocorrência já existia e `:unchanged` não escreve nada.

  ## A promoção, e por que ela não é uma exceção à frase acima

  Até 2026-09-15 a coleta não pedia à origem o identificador do evento de timeline,
  por acreditar que ele não existia. Ele existe. As 41 863 linhas já gravadas estão
  sem ele, e o identificador entrou no critério de identidade — então a mesma
  ocorrência, relida da origem, calcularia um hash diferente do que está no banco e
  entraria de novo. Seriam 41 863 duplicatas.

  A promoção evita isso: quando a ocorrência não é achada pela identidade nova, ela é
  procurada pela identidade que teria sem o identificador; se a linha existe e está
  sem identificador, ela **recebe o identificador que a origem sempre deu** e passa a
  valer pela identidade nova. Nada do que aconteceu muda — mesmo tipo, mesmo ator,
  mesmo instante, mesmo sujeito. O que muda é o que sabemos escrever sobre a linha.

  A promoção também é o que separa as ocorrências que estavam coladas: dois rótulos
  postos na mesma issue, no mesmo segundo, pelo mesmo ator dividiam uma linha só. O
  primeiro a chegar promove a linha; o segundo não a acha mais pela identidade antiga,
  e é inserido. Duas linhas para dois atos.

  **É transitória.** O ramo só alcança linha sem identificador, e some sozinho quando
  não houver mais nenhuma. Para saber se chegou a hora de apagá-lo:

      select count(*) from spo_performed_project_activities where source_external_id is null

  Enquanto esse número não for o das origens que legitimamente não identificam seus
  eventos, a promoção ainda tem trabalho.
  """
  @spec record_activity(Tenant.t(), map()) ::
          {:ok, Activity.t()} | {:error, Ecto.Changeset.t()}
  def record_activity(%Tenant{id: tenant_id}, attrs) do
    attrs =
      attrs
      |> normalizar()
      |> Map.put(:tenant_id, tenant_id)

    internal_id = Activity.internal_id(attrs)
    attrs = Map.put(attrs, :internal_id, internal_id)

    case Repo.get_by(Activity, tenant_id: tenant_id, internal_id: internal_id) do
      nil -> promover_ou_inserir(attrs)
      existente -> completar(existente, attrs)
    end
  end

  # Observações da origem que a consulta pode passar a pedir depois de a ocorrência já
  # estar gravada. Só entram campos que a ORIGEM diz — nada derivado por nós.
  @completaveis [:board_id, :board_external_id, :status_name]

  # **Nulo é pergunta sem resposta, e não resposta.** Preencher um campo nulo com o que a
  # origem sempre disse é responder pela primeira vez; trocar um valor existente seria
  # mudar uma resposta, e isso segue proibido — por isso a lista de campos é fechada e a
  # condição exige `is_nil` dos dois lados da comparação.
  #
  # Sem isto, acrescentar campo à consulta não alcança o histórico. Medido em 2026-09-16:
  # a recoleta de 25 repositórios passou inteira sem gravar um único quadro, porque toda
  # ocorrência já existia e `:unchanged` não escreve nada.
  defp completar(existente, attrs) do
    faltando =
      for campo <- @completaveis,
          is_nil(Map.get(existente, campo)),
          valor = attrs[campo],
          not is_nil(valor),
          do: {campo, valor}

    if faltando == [] do
      {:ok, %{existente | outcome: :unchanged}}
    else
      {1, _} =
        Activity
        |> where(id: ^existente.id)
        |> Repo.update_all(set: [{:updated_at, DateTime.utc_now(:second)} | faltando])

      {:ok, %{struct(existente, faltando) | outcome: :completed}}
    end
  end

  # Transitória — ver a nota em `record_activity/2`.
  defp promover_ou_inserir(attrs) do
    case identidade_sem_identificador(attrs) do
      nil -> inserir(attrs)
      antiga -> promover(attrs, antiga)
    end
  end

  # A identidade que esta ocorrência teria se a origem não a identificasse. É o hash
  # que está gravado nas linhas anteriores a 2026-09-15.
  defp identidade_sem_identificador(attrs) do
    if attrs[:source_external_id] do
      attrs |> Map.put(:source_external_id, nil) |> Activity.internal_id()
    end
  end

  # O `where` carrega a corrida: duas gravações concorrentes disputam a mesma linha
  # antiga, e só uma a promove. A outra recebe zero linhas afetadas e segue para o
  # insert, onde o índice único dá a resposta certa.
  defp promover(attrs, antiga) do
    {afetadas, _} =
      Activity
      |> where(tenant_id: ^attrs[:tenant_id], internal_id: ^antiga)
      |> where([a], is_nil(a.source_external_id))
      |> Repo.update_all(
        set: [
          internal_id: attrs[:internal_id],
          source_external_id: attrs[:source_external_id],
          updated_at: DateTime.utc_now(:second)
        ]
      )

    if afetadas == 1 do
      Activity
      |> Repo.get_by(tenant_id: attrs[:tenant_id], internal_id: attrs[:internal_id])
      |> case do
        nil -> inserir(attrs)
        promovida -> {:ok, %{promovida | outcome: :promoted}}
      end
    else
      inserir(attrs)
    end
  end

  # A corrida entre a checagem e o insert é real — duas coletas simultâneas da mesma
  # issue chegariam aqui juntas. O índice único a resolve, e o `:unchanged` no
  # tratamento da violação é a mesma resposta que o caminho sem corrida daria.
  defp inserir(attrs) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, activity} -> {:ok, %{activity | outcome: :created}}
      {:error, changeset} -> resolver_colisao(attrs, changeset)
    end
  end

  # A violação do índice único só pode significar que outra escrita gravou a mesma
  # ocorrência entre a checagem e o insert. Devolver o registro dela é a mesma
  # resposta que o caminho sem corrida daria — e engolir qualquer outro erro aqui
  # seria fallback silencioso, então só esta violação é tratada.
  defp resolver_colisao(attrs, %Ecto.Changeset{errors: errors} = changeset) do
    if Keyword.has_key?(errors, :internal_id) do
      Activity
      |> Repo.get_by(tenant_id: attrs[:tenant_id], internal_id: attrs[:internal_id])
      |> case do
        nil -> {:error, changeset}
        existente -> {:ok, %{existente | outcome: :unchanged}}
      end
    else
      {:error, changeset}
    end
  end

  defp normalizar(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  @doc """
  Grava um processo pretendido — `spo.specific_intended_project_process`, FR-030.

  É a iteração futura do quadro: planejamento que não foi feito. Idempotente pela
  Application Reference; reobservar limpa a marca de ausência.
  """
  @spec record_intended_process(Tenant.t(), map()) ::
          {:ok, IntendedProjectProcess.t()} | {:error, Ecto.Changeset.t()}
  def record_intended_process(%Tenant{id: tenant_id}, attrs) do
    base =
      Repo.get_by(IntendedProjectProcess,
        tenant_id: tenant_id,
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        source_external_id: attrs[:source_external_id]
      ) || %IntendedProjectProcess{}

    agora = DateTime.utc_now(:second)

    base
    |> IntendedProjectProcess.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || attrs[:collected_at] || agora)
      |> Map.put(:last_observed_at, agora)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end
end
