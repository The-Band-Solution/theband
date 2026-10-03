defmodule TheBand.Credenciais.Idade do
  @moduledoc """
  A idade de uma credencial de terceiro, e se já passou da hora de pedir a troca — 064/T017,
  FR-016 e FR-019. Contrato: `specs/064-segredo-em-repouso/contracts/idade-da-credencial.md`.

  Vale para as duas credenciais que a plataforma guarda — de ferramenta
  (`TheBand.Sources.ToolCredential`) e de provedor de modelos (`TheBand.AI.ProviderCredential`) —,
  porque são o mesmo tipo de segredo (FR-002) e a política é a mesma.

  **Pedir, e não impedir.** Nenhum caminho de coleta nem de geração consulta este módulo: uma
  credencial `:vencida` continua funcionando. Expirar viraria queda de serviço num dia que
  ninguém escolheu.

  **Sem data, a idade é desconhecida — nunca "no prazo".** Ausência de data não é prova de
  juventude; é a mesma família do registro sem data de encerramento da FR-015.

  Não depende de ontologia: é regra de segurança sobre metadado de credencial.
  """

  alias TheBand.AI.ProviderCredential
  alias TheBand.Sources.ToolCredential

  @typedoc "Os três estados, e só eles: o booleano juntaria o primeiro com o último."
  @type estado :: :no_prazo | :vencida | :idade_desconhecida

  @type credencial :: ToolCredential.t() | ProviderCredential.t()

  # O prazo vive aqui, e só aqui (Feita quando da T017). Meses de calendário, e não 90 dias:
  # "registrada em 4 de setembro" vence em 4 de dezembro, que é o que a pessoa lê.
  @limite_em_meses 3

  @doc "O prazo depois do qual a troca é pedida, em meses de calendário."
  @spec limite_em_meses() :: pos_integer()
  def limite_em_meses, do: @limite_em_meses

  @doc """
  Desde quando o segredo atual vale, ou `nil` quando não se sabe.

  A credencial de ferramenta nunca troca de segredo na mesma linha — a troca é uma linha nova
  (`Sources.add_credential/3`) —, então a validação é o início. A de provedor de modelos troca
  na mesma linha, e `secret_set_at` diz quando; sem ele (linha anterior à T019), a validação é a
  data em que aquela chave foi gravada.
  """
  @spec em_uso_desde(credencial()) :: DateTime.t() | nil
  def em_uso_desde(%ToolCredential{validated_at: validada}), do: validada

  def em_uso_desde(%ProviderCredential{secret_set_at: %DateTime{} = gravada}), do: gravada
  def em_uso_desde(%ProviderCredential{validated_at: validada}), do: validada

  @doc """
  Classifica a credencial no instante `agora`.

  `agora` é argumento para a regra ser pura: a tela e o teste passam o mesmo instante.
  """
  @spec estado(credencial(), DateTime.t()) :: estado()
  def estado(credencial, %DateTime{} = agora) do
    classificar(em_uso_desde(credencial), agora)
  end

  defp classificar(nil, _agora), do: :idade_desconhecida

  defp classificar(%DateTime{} = desde, agora) do
    # "Passar de" é estrito: no instante exato do limite, ainda está no prazo. Uma data no
    # futuro (relógio adiantado de quem gravou) cai aqui como no prazo — ela existe, e tratá-la
    # como vencida pediria a troca de um segredo gravado agora.
    case DateTime.compare(agora, DateTime.shift(desde, month: @limite_em_meses)) do
      :gt -> :vencida
      _ -> :no_prazo
    end
  end
end
