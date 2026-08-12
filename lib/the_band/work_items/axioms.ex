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
  @user_story "sro.atomic_user_story"
  @compoem [@epico, @user_story]

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
  O texto do aviso, nomeando o axioma. **Vai para a tela**, e por isso é em inglês.

  Nomear `sro.rule07` não é detalhe técnico: é o que permite achar o axioma na base de
  conhecimento e conferir a formulação em vez de acreditar na tela.
  """
  @spec explicacao(:task_parent_is_epic | :task_without_parent) :: String.t()
  def explicacao(:task_parent_is_epic),
    do:
      "sro.rule07: a task attends an atomic user story, and this one's parent is an epic. " <>
        "The task is still promoted — the link is what is invalid, not the issue."

  def explicacao(:task_without_parent),
    do:
      "sro.rule07: a task attends an atomic user story, and this one has no parent. " <>
        "The task is still promoted — the link is missing, not the issue."

  @doc """
  Qual relação o vínculo é, dado o conceito da **filha** e o do **pai**.

  ## Precondição: há pai

  A ausência de pai **não** é caso desta função — quem não tem pai não tem relação. E chamá-la
  com o pai ausente teria custo medido: `rule07/2` trata `nil` como "não tem pai", e as
  **2 091** tarefas sem pai viriam com aviso de violação, afogando as **293** que são o caso
  interessante. Essa violação continua sendo contada por `rule07_violations/2`, num painel
  separado.

  ## Dois `nil` diferentes, e é a ordem das cláusulas que os separa

  Em `rule07/2`, `nil` no conceito do pai significa **não tem pai**. Aqui significa **o pai
  existe e não foi promovido** — e por isso essa cláusula vem **antes** de o axioma ser
  chamado. Passar esse `nil` adiante faria a tela dizer *task without parent* sobre uma issue
  que tem pai.

  O mesmo vale para a filha: sem o conceito dela, a relação não é decidível — e dizer "a
  ontologia não nomeia" seria afirmar coisa diferente da verdade, que é "a plataforma não sabe
  o conceito desta issue".

  ## Quem decide é o conceito da filha

  É como a plataforma **já** decide, do outro lado da mesma relação: `list_composition/2`
  filtra filhas promovidas a épico ou user story, e `list_attendance/2` filtra filhas
  promovidas a tarefa. Decidir pela dupla faria a mesma relação ter nome diferente dependendo
  da tela por onde se olha.

  Filha promovida a **defeito** não cai em nenhuma das duas: a rede de ontologias **não
  nomeia** essa relação, e são 33 vínculos. Encaixá-la em composição daria à tela uma convicção
  que a rede não sustenta — `sro.epic_composed_of_user_story` fala de user story, e defeito é
  `osdef`.
  """
  @spec relacao(String.t() | nil, String.t() | nil) ::
          :atendimento
          | :composicao
          | :nao_nomeada
          | :filha_sem_conceito
          | :pai_sem_conceito
          | {:violacao, :task_parent_is_epic}
  def relacao(nil, _conceito_do_pai), do: :filha_sem_conceito
  def relacao(_conceito, nil), do: :pai_sem_conceito

  def relacao(conceito, conceito_do_pai) do
    case rule07(conceito, conceito_do_pai) do
      {:violation, forma} -> {:violacao, forma}
      :ok -> nomear(conceito)
    end
  end

  defp nomear(@tarefa), do: :atendimento
  defp nomear(conceito) when conceito in @compoem, do: :composicao
  defp nomear(_conceito), do: :nao_nomeada
end
