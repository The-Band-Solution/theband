defmodule TheBand.WorkItems.Axioms do
  @moduledoc """
  Os axiomas da SRO aplicados ao que foi coletado — **funções puras, um caminho só**.

  ## Por que puras, e por que aqui

  A tela de detalhe verifica uma issue; a tela do repositório verifica quatro mil. Se cada
  uma decidisse por conta, uma diria "viola" e a outra "não viola" para a mesma issue — e
  foi exatamente esse o defeito que `classification/2` existe para impedir, ao ser o único
  caminho de derivação.

  Aqui a decisão é a mesma função nos dois casos. O que muda é **como os dados chegam**:
  uma consulta por issue no detalhe, uma consulta para o grafo inteiro no repositório.

  ## `sro.rule07`

  > Uma tarefa de desenvolvimento atende a uma user story **atômica**.

  Duas formas de violar, e elas são diferentes:

    * a tarefa tem pai, e o pai é um **épico** — épico não é user story atômica, e a
      tarefa deveria atender a uma das partes dele;
    * a tarefa **não tem pai** — não há user story a que ela atenda.

  A segunda não é caso da primeira: um épico decomposto e uma tarefa solta pedem ações
  diferentes de quem escreve as issues, e somá-las esconderia isso.

  **A issue continua promovida.** O inválido é o vínculo, não a issue — e é por isso que
  estas funções devolvem aviso, e não despromoção.
  """

  @tarefa "sro.intended_scrum_development_task"
  @epico "sro.epic"

  @doc """
  Verifica `sro.rule07` para uma issue, dado o conceito dela e o do pai.

  `nil` no conceito do pai significa **não tem pai**. Issue que não é tarefa não viola
  nada — a regra fala de tarefas.
  """
  @spec rule07(String.t() | nil, String.t() | nil) ::
          :ok | {:violation, :task_parent_is_epic | :task_without_parent}
  def rule07(@tarefa, nil), do: {:violation, :task_without_parent}
  def rule07(@tarefa, @epico), do: {:violation, :task_parent_is_epic}
  def rule07(_conceito, _conceito_do_pai), do: :ok

  @doc """
  O texto do aviso, nomeando o axioma.

  Nomear `sro.rule07` não é detalhe técnico: é o que permite achar o axioma na base de
  conhecimento e conferir a formulação em vez de acreditar na tela.
  """
  @spec explicacao(:task_parent_is_epic | :task_without_parent) :: String.t()
  def explicacao(:task_parent_is_epic),
    do:
      "sro.rule07: uma tarefa atende a uma user story atômica, e o pai desta é um épico. " <>
        "A tarefa continua promovida — o inválido é o vínculo."

  def explicacao(:task_without_parent),
    do:
      "sro.rule07: uma tarefa atende a uma user story atômica, e esta não tem pai. " <>
        "A tarefa continua promovida — falta o vínculo, não a issue."
end
